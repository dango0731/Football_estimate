import SwiftUI

// ============================================================
// MARK: - PLAYER REGISTRATION VIEW（試合に選手を追加）
// ============================================================

struct PlayerRegistrationView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let matchId: UUID
    @Binding var navPath: NavigationPath
    @State private var showAddPlayer = false
    @State private var showFinishAlert = false
    // ロスター選手タップ時の「スタメン/ベンチ」選択用
    @State private var pendingRosterPlayer: RosterPlayer? = nil

    var match: Match { appState.matches.first(where:{$0.id==matchId}) ?? Match(opponent:"") }
    var starters: [Player] { match.players.filter{$0.isStarter} }
    var bench:    [Player] { match.players.filter{!$0.isStarter} }

    // 既に試合に追加済みのロスター選手を除外して、追加可能なロスターを返す
    var availableRoster: [RosterPlayer] {
        let addedRosterIds = Set(match.players.compactMap { $0.rosterId })
        return appState.sortedRoster.filter { !addedRosterIds.contains($0.id) }
    }

    var body: some View {
        ZStack(alignment:.bottom) {
            List {
                Section {
                    VStack(spacing:12) {
                        HStack {
                            VStack(alignment:.leading,spacing:4) {
                                Text("vs \(match.opponent)").font(.title3.weight(.bold))
                                Text(match.dateString).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(match.players.count)名").font(.subheadline).foregroundColor(.secondary)
                        }
                        if !starters.isEmpty {
                            Button {
                                navPath.append(NavRoute.statsCollection(matchId))
                            } label: {
                                Label("スタッツ収集を開始", systemImage: "play.circle.fill")
                                    .font(.headline.weight(.bold)).frame(maxWidth:.infinity).padding(.vertical,12)
                                    .background(Color.green).foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius:12))
                            }
                            .buttonStyle(.plain)
                        }
                    }.padding(.vertical,4).listRowBackground(Color(.secondarySystemBackground))
                }

                // ── ロスターから追加セクション ──
                if !availableRoster.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availableRoster) { rp in
                                    Button {
                                        pendingRosterPlayer = rp
                                    } label: {
                                        RosterPickerChip(player: rp)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    } header: {
                        Label("ロスターから追加 (\(availableRoster.count)名)", systemImage: "person.3.fill")
                            .foregroundColor(.blue)
                    } footer: {
                        Text("タップしてスタメン/ベンチを選択")
                            .font(.caption2)
                    }
                }

                Section {
                    if starters.isEmpty { Text("先発選手を追加してください").foregroundColor(.secondary).italic() }
                    else { ForEach(starters) { PlayerRegRow(player:$0) }.onDelete { deletePlayer(at:$0,isStarter:true) } }
                } header: { Label("スタメン (\(starters.count)/11名)",systemImage:"star.fill").foregroundColor(.orange) }

                Section {
                    if bench.isEmpty { Text("ベンチ選手を追加してください").foregroundColor(.secondary).italic() }
                    else { ForEach(bench) { PlayerRegRow(player:$0) }.onDelete { deletePlayer(at:$0,isStarter:false) } }
                } header: { Label("ベンチ (\(bench.count)名)",systemImage:"person.2.fill").foregroundColor(.secondary) }

                Section { Color.clear.frame(height:80) }.listRowBackground(Color.clear).listSectionSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("選手登録")
            .navigationBarTitleDisplayMode(.inline)

            HStack(spacing:12) {
                Button { showAddPlayer = true } label: {
                    Label("新規選手を追加",systemImage:"person.badge.plus").font(.headline.weight(.bold)).padding(.vertical,16)
                        .frame(maxWidth:.infinity).background(.blue).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius:14))
                }
                Button { showFinishAlert = true } label: {
                    Label("試合終了",systemImage:"flag.checkered").font(.headline.weight(.bold)).padding(.vertical,16)
                        .frame(maxWidth:160).background(.red).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius:14))
                }
            }.padding(.horizontal,20).padding(.vertical,12).background(.ultraThinMaterial)
        }
        .sheet(isPresented:$showAddPlayer) {
            AddPlayerSheet { name,pos,height,foot,isStarter in
                // ① ロスターにも自動登録（スナップショット方式）
                let rosterPlayer = RosterPlayer(
                    name: name,
                    position: pos,
                    height: height,
                    foot: foot
                )
                appState.addRosterPlayer(rosterPlayer)

                // ② 試合にも追加（rosterIdで紐付け）
                let p = Player.from(roster: rosterPlayer, isStarter: isStarter)
                var m = match; m.players.append(p); appState.updateMatch(m)
            }
        }
        .confirmationDialog(
            "「\(pendingRosterPlayer?.name ?? "")」を追加",
            isPresented: Binding(
                get: { pendingRosterPlayer != nil },
                set: { if !$0 { pendingRosterPlayer = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("スタメンに追加") {
                if let rp = pendingRosterPlayer {
                    addRosterPlayerToMatch(rp, isStarter: true)
                }
                pendingRosterPlayer = nil
            }
            Button("ベンチに追加") {
                if let rp = pendingRosterPlayer {
                    addRosterPlayerToMatch(rp, isStarter: false)
                }
                pendingRosterPlayer = nil
            }
            Button("キャンセル", role: .cancel) { pendingRosterPlayer = nil }
        }
        .alert("試合を終了しますか？",isPresented:$showFinishAlert) {
            Button("終了する",role:.destructive) { appState.finishMatch(matchId); dismiss() }
            Button("キャンセル",role:.cancel) {}
        } message: { Text("試合終了後はスタッツの編集ができません") }
    }

    private func addRosterPlayerToMatch(_ rp: RosterPlayer, isStarter: Bool) {
        let p = Player.from(roster: rp, isStarter: isStarter)
        var m = match
        m.players.append(p)
        appState.updateMatch(m)
    }

    private func deletePlayer(at offsets:IndexSet, isStarter:Bool) {
        let group = isStarter ? starters : bench
        let ids = offsets.map { group[$0].id }
        var m = match; m.players.removeAll { ids.contains($0.id) }; appState.updateMatch(m)
    }
}

// ── ロスター選手ピッカー用チップ（選手登録画面の横スクロール） ──
struct RosterPickerChip: View {
    let player: RosterPlayer
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [player.position.color, player.position.color.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 46, height: 46)
                    .shadow(color: player.position.color.opacity(0.35), radius: 3, x: 0, y: 2)
                Image(systemName: player.position.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                // + 追加の小バッジ
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(Color.blue)
                                .frame(width: 16, height: 16)
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white)
                        }
                        .offset(x: 4, y: -4)
                    }
                    Spacer()
                }
                .frame(width: 46, height: 46)
            }
            Text(player.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 62)
            Text(player.position.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(player.position.color)
        }
        .frame(width: 66)
        .padding(.vertical, 4)
    }
}

// ── 選手登録画面の1行 ──
struct PlayerRegRow: View {
    let player: Player
    var body: some View {
        HStack(spacing:12) {
            ZStack {
                Circle().fill(player.position.color.opacity(0.15)).frame(width:44,height:44)
                Image(systemName:player.position.icon).foregroundColor(player.position.color).font(.system(size:18,weight:.semibold))
            }
            VStack(alignment:.leading,spacing:3) {
                Text(player.name).font(.headline)
                HStack(spacing:6) {
                    Text(player.position.label).font(.caption.weight(.semibold))
                        .padding(.horizontal,6).padding(.vertical,2)
                        .background(player.position.color.opacity(0.15)).foregroundColor(player.position.color).clipShape(Capsule())
                    if !player.height.isEmpty { Text("\(player.height)cm").font(.caption).foregroundColor(.secondary) }
                    Text(player.foot.rawValue).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
        }.padding(.vertical,4)
    }
}

// ============================================================
// MARK: - ADD PLAYER SHEET（新規選手入力シート）
// ============================================================

struct AddPlayerSheet: View {
    let onConfirm: (String, Position, String, Foot, Bool) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""; @State private var position: Position = .fw
    @State private var height = ""; @State private var foot: Foot = .right
    @State private var isStarter = true
    @FocusState private var focusedField: String?
    var canRegister: Bool { !name.trimmingCharacters(in:.whitespaces).isEmpty }

    var body: some View {
        VStack(spacing:0) {
            HStack {
                Button("キャンセル") { dismiss() }.foregroundColor(.secondary)
                Spacer()
                Text("選手を追加").font(.headline.weight(.bold))
                Spacer()
                Button("登録") { onConfirm(name,position,height,foot,isStarter); dismiss() }
                    .fontWeight(.bold).foregroundColor(canRegister ? .blue : .secondary).disabled(!canRegister)
            }.padding(.horizontal,20).padding(.top,20).padding(.bottom,16)
            Divider()
            Form {
                Section("基本情報") {
                    HStack {
                        Label("名前",systemImage:"person.fill").foregroundColor(.secondary); Spacer()
                        TextField("田中 一郎",text:$name).multilineTextAlignment(.trailing).focused($focusedField,equals:"name")
                    }
                    HStack {
                        Label("ポジション",systemImage:"sportscourt").foregroundColor(.secondary); Spacer()
                        Picker("",selection:$position) { ForEach(Position.allCases) { p in Text(p.label).tag(p) } }
                            .pickerStyle(.segmented).frame(width:180)
                    }
                }
                Section("身体情報") {
                    HStack {
                        Label("身長",systemImage:"ruler").foregroundColor(.secondary); Spacer()
                        TextField("175",text:$height).multilineTextAlignment(.trailing).keyboardType(.numberPad)
                            .frame(width:60).focused($focusedField,equals:"height")
                        Text("cm").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("利き足",systemImage:"figure.soccer").foregroundColor(.secondary); Spacer()
                        Picker("",selection:$foot) { ForEach(Foot.allCases,id:\.self) { Text($0.rawValue).tag($0) } }
                            .pickerStyle(.segmented).frame(width:200)
                    }
                }
                Section("出場区分") {
                    Picker("区分",selection:$isStarter) { Text("スタメン").tag(true); Text("ベンチ").tag(false) }.pickerStyle(.segmented)
                }
            }
        }
        .presentationDetents([.medium,.large]).onAppear { focusedField="name" }
    }
}
