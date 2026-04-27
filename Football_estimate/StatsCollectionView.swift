import SwiftUI
import Combine

// ============================================================
// MARK: - STATS COLLECTION VIEW（試合進行・スタッツ収集）
//   フェーズ: setup → firstHalf → halfTime → secondHalf → finished
// ============================================================

struct StatsCollectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let matchId: UUID

    @State private var selectedPlayerId: UUID? = nil
    @State private var showHalfEndAlert = false
    @State private var showFinishAlert  = false
    // 選手ごとのドラッグオフセット [Player.id : CGSize]
    @State private var dragOffsets: [UUID: CGSize] = [:]
    // タイマー再描画用
    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var matchIndex: Int? { appState.matches.firstIndex(where:{$0.id==matchId}) }
    var match: Match { appState.matches.first(where:{$0.id==matchId}) ?? Match(opponent:"") }
    var phase: MatchPhase { match.phase }
    var starters: [Player] { match.players.filter{$0.isStarter} }
    /// チーム平均レーティング（試合中はライブ計算でタイムロスを反映）
    var avgRating: Double {
        guard !starters.isEmpty else { return 0 }
        return starters.reduce(0.0){ $0 + $1.liveRating(now: now, phase: phase) } / Double(starters.count)
    }
    /// 現在フェーズの経過時間
    var elapsedString: String { formatMMSS(match.elapsedSeconds(now: now)) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ─── サッカーコート背景 ───
                SoccerFieldView().ignoresSafeArea(edges:.bottom)

                // ─── 選手アイコン（ポジション固定＋ドラッグ微調整） ───
                ForEach(starters) { player in
                    let basePos  = basePosition(for: player, in: geo.size)
                    let offset   = dragOffsets[player.id] ?? .zero
                    let isSelected = selectedPlayerId == player.id

                    PlayerFieldIcon(
                        player: player,
                        isSelected: isSelected,
                        onTap: {
                            // 進行中のみラジアルメニューを開く
                            // (ドラッグとタップは PlayerFieldIcon 内のジェスチャ合成
                            //  DragGesture(minimumDistance:5) によって自動的に区別される)
                            guard phase.isPlaying else { return }
                            withAnimation(.spring(response:0.3,dampingFraction:0.7)) {
                                selectedPlayerId = (selectedPlayerId == player.id) ? nil : player.id
                            }
                        },
                        onDragChanged: { drag in
                            selectedPlayerId = nil
                            let cur = dragOffsets[player.id] ?? .zero
                            dragOffsets[player.id] = CGSize(
                                width:  cur.width  + drag.translation.width,
                                height: cur.height + drag.translation.height
                            )
                        },
                        onDragEnded: { _ in
                            // 画面端クランプ
                            let cur = dragOffsets[player.id] ?? .zero
                            let newX = (basePos.x + cur.width).clamped(to: 40...(geo.size.width  - 40))
                            let newY = (basePos.y + cur.height).clamped(to: 80...(geo.size.height - 80))
                            withAnimation(.spring(response:0.35,dampingFraction:0.75)) {
                                dragOffsets[player.id] = CGSize(
                                    width:  newX - basePos.x,
                                    height: newY - basePos.y
                                )
                            }
                        }
                    )
                    .position(x: basePos.x + offset.width,
                              y: basePos.y + offset.height)
                    .zIndex(isSelected ? 10 : 1)
                    .opacity(phase == .halfTime ? 0.55 : 1.0)  // ハーフタイム中は淡く
                }

                // ─── 上部ヘッダー（フェーズ・タイマー・チーム平均） ───
                VStack {
                    headerBar
                    Spacer()
                    bottomCTA(width: geo.size.width)
                }

                // ─── ラジアルメニュー（進行中のみ） ───
                if phase.isPlaying,
                   let pid = selectedPlayerId,
                   let mi = matchIndex,
                   let pi = appState.matches[mi].players.firstIndex(where:{$0.id==pid}) {

                    Color.black.opacity(0.70).ignoresSafeArea()
                        .onTapGesture { withAnimation { selectedPlayerId = nil } }
                        .zIndex(900)

                    HexButtonMenu(
                        player: $appState.matches[mi].players[pi],
                        bench: appState.matches[mi].players.filter {
                            !$0.isStarter && !$0.wasSubstituted && $0.stats.redCards == 0
                        },
                        displayRating: appState.matches[mi].players[pi].liveRating(now: now, phase: phase),
                        onSubstitute: { benchId in
                            appState.substitutePlayer(matchId: matchId, outId: pid, inId: benchId)
                            withAnimation { selectedPlayerId = nil }
                        },
                        onClose: { withAnimation { selectedPlayerId = nil } }
                    )
                    .transition(.asymmetric(
                        insertion:.scale(scale:0.4).combined(with:.opacity),
                        removal:.scale(scale:0.4).combined(with:.opacity)
                    ))
                    .zIndex(1000)
                }
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onReceive(tick) { now = $0 }
        .sheet(isPresented: Binding(
            get: { phase == .halfTime },
            set: { _ in /* 自前制御 */ }
        )) {
            HalfTimeReviewView(
                match: match,
                onStartSecondHalf: {
                    appState.startSecondHalf(matchId: matchId)
                    now = Date()
                }
            )
            .interactiveDismissDisabled(true)
        }
        // 前半終了確認
        .alert("前半を終了しますか？", isPresented: $showHalfEndAlert) {
            Button("前半終了", role: .destructive) {
                appState.endFirstHalf(matchId: matchId)
                selectedPlayerId = nil
                now = Date()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ピッチ上選手の前半出場時間を確定し、ハーフタイムへ移ります。")
        }
        // 試合終了確認
        .alert("試合を終了しますか？", isPresented: $showFinishAlert) {
            Button("試合終了", role: .destructive) {
                appState.endSecondHalf(matchId: matchId)
                dismiss(); dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("結果はホームに保存されます。")
        }
    }

    // MARK: - ナビゲーションタイトル
    private var navTitle: String {
        switch phase {
        case .setup:      return "セットアップ"
        case .firstHalf:  return "前半"
        case .halfTime:   return "ハーフタイム"
        case .secondHalf: return "後半"
        case .finished:   return "試合終了"
        }
    }

    // MARK: - 上部ヘッダー
    @ViewBuilder
    private var headerBar: some View {
        HStack {
            VStack(alignment:.leading, spacing:2) {
                Text("vs \(match.opponent)")
                    .font(.headline.weight(.bold)).foregroundColor(.white)
                    .shadow(color:.black.opacity(0.6),radius:2)
                if phase.isPlaying {
                    HStack(spacing:6) {
                        Image(systemName:"timer")
                            .font(.system(size:11, weight:.bold))
                        Text("\(phase.label)  \(elapsedString)")
                            .font(.system(size:13, weight:.heavy, design:.monospaced))
                    }
                    .foregroundColor(.white)
                    .shadow(color:.black.opacity(0.6), radius:2)
                } else {
                    Text(phase.label)
                        .font(.caption).foregroundColor(.white.opacity(0.85))
                        .shadow(color:.black.opacity(0.6),radius:2)
                }
            }
            Spacer()
            VStack(alignment:.trailing, spacing:1) {
                Text("チーム平均").font(.caption2).foregroundColor(.white.opacity(0.8))
                Text(String(format:"%.2f", avgRating))
                    .font(.title2.weight(.black))
                    .foregroundColor(ratingColor(avgRating))
                    .shadow(color:.black.opacity(0.5),radius:3)
            }
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
        .background(.ultraThinMaterial.opacity(0.85))
    }

    // MARK: - 下部 CTA（前半開始 / 後半開始）
    @ViewBuilder
    private func bottomCTA(width: CGFloat) -> some View {
        if phase == .setup {
            Button {
                appState.startFirstHalf(matchId: matchId)
                now = Date()
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            } label: {
                Label("前半開始 (キックオフ)", systemImage: "play.circle.fill")
                    .font(.title3.weight(.heavy))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(
                        LinearGradient(colors:[.green, Color(red:0.10,green:0.55,blue:0.20)],
                                       startPoint:.top, endPoint:.bottom)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style:.continuous))
                    .shadow(color:.black.opacity(0.35), radius:10, y:4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        // halfTime 時は sheet で受け持つので何も表示しない
    }

    // MARK: - ツールバー
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            switch phase {
            case .firstHalf:
                Button { showHalfEndAlert = true } label: {
                    Label("前半終了", systemImage: "pause.circle.fill")
                        .font(.subheadline.weight(.bold)).foregroundColor(.orange)
                }
            case .secondHalf:
                Button { showFinishAlert = true } label: {
                    Label("試合終了", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.bold)).foregroundColor(.red)
                }
            default:
                EmptyView()
            }
        }
    }

    // ポジション別・人数別の固定ベース座標
    private func basePosition(for player: Player, in size: CGSize) -> CGPoint {
        let byPosition = Dictionary(grouping: starters) { $0.position }
        let group = byPosition[player.position] ?? []
        let idx   = group.firstIndex(where:{$0.id==player.id}) ?? 0
        let count = group.count

        let headerH: CGFloat = 60
        let fieldH = size.height - headerH
        let y = headerH + fieldH * player.position.fieldYRatio

        let totalWidth = size.width * 0.80
        let startX = (size.width - totalWidth) / 2
        let x: CGFloat = count == 1
            ? size.width / 2
            : startX + (totalWidth / CGFloat(count - 1)) * CGFloat(idx)

        return CGPoint(x: x, y: y)
    }
}

// ============================================================
// MARK: - HALF TIME REVIEW VIEW（ハーフタイム復習画面）
// ============================================================

struct HalfTimeReviewView: View {
    let match: Match
    let onStartSecondHalf: () -> Void
    @Environment(\.dismiss) var dismiss

    private var sortedPlayers: [Player] {
        match.players.filter { $0.firstHalfMinutes > 0 || $0.isStarter }
            .sorted { $0.rating > $1.rating }
    }
    private var avg: Double {
        let onField = match.players.filter { $0.firstHalfMinutes > 0 }
        guard !onField.isEmpty else { return 0 }
        return onField.reduce(0.0){$0+$1.rating}/Double(onField.count)
    }

    var body: some View {
        NavigationStack {
            List {
                // ── サマリー ──
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                Text("前半時間").font(.caption).foregroundColor(.secondary)
                                Text(formatMMSS(match.firstHalfEnd?.timeIntervalSince(match.firstHalfStart ?? Date()) ?? 0))
                                    .font(.title3.weight(.heavy).monospacedDigit())
                            }
                            Divider().frame(height: 36)
                            VStack(spacing: 2) {
                                Text("チーム平均").font(.caption).foregroundColor(.secondary)
                                Text(String(format:"%.2f", avg))
                                    .font(.title3.weight(.heavy))
                                    .foregroundColor(ratingColor(avg))
                            }
                            Divider().frame(height: 36)
                            VStack(spacing: 2) {
                                Text("ゴール").font(.caption).foregroundColor(.secondary)
                                Text("\(match.players.reduce(0){$0+$1.stats.goals})")
                                    .font(.title3.weight(.heavy)).foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxWidth: .infinity)
                } header: {
                    HStack {
                        Image(systemName: "pause.circle.fill").foregroundColor(.orange)
                        Text("ハーフタイム — 前半の振り返り")
                    }
                }

                // ── ランキング ──
                Section("選手別レーティング") {
                    ForEach(Array(sortedPlayers.enumerated()), id:\.element.id) { idx, player in
                        HStack(spacing: 12) {
                            Text(idx<3 ? ["🥇","🥈","🥉"][idx] : "\(idx+1)")
                                .font(.subheadline.weight(.bold)).frame(width: 28)
                            ZStack {
                                Circle().fill(player.position.color.opacity(0.18)).frame(width: 32, height: 32)
                                Image(systemName: player.position.icon)
                                    .foregroundColor(player.position.color)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(player.name).font(.subheadline.weight(.semibold))
                                HStack(spacing: 4) {
                                    Text(player.position.label).font(.caption2).foregroundColor(.secondary)
                                    Text("·").foregroundColor(.secondary).font(.caption2)
                                    Text("\(formatMinutes(player.firstHalfMinutes)) 出場")
                                        .font(.caption2).foregroundColor(.secondary)
                                    if player.stats.yellowCards > 0 {
                                        Rectangle().fill(Color.yellow).frame(width:7, height:10).cornerRadius(1)
                                    }
                                    if player.stats.redCards > 0 {
                                        Rectangle().fill(Color.red).frame(width:7, height:10).cornerRadius(1)
                                    }
                                }
                            }
                            Spacer()
                            Text(String(format:"%.2f", player.rating))
                                .font(.headline.weight(.heavy)).foregroundColor(ratingColor(player.rating))
                        }
                        .padding(.vertical, 2)
                    }
                }

                // ── 主要スタッツ集計 ──
                Section("主要スタッツ（チーム合計）") {
                    halfTeamStatRow("シュート",  match.players.reduce(0){$0+$1.stats.spg},     icon: "soccerball")
                    halfTeamStatRow("ゴール",    match.players.reduce(0){$0+$1.stats.goals},   icon: "soccerball.inverse")
                    halfTeamStatRow("アシスト",  match.players.reduce(0){$0+$1.stats.assists}, icon: "arrow.turn.up.right")
                    halfTeamStatRow("パス数",    match.players.reduce(0){$0+$1.stats.avgP},    icon: "arrow.triangle.swap")
                    halfTeamStatRow("Inter",     match.players.reduce(0){$0+$1.stats.inter},   icon: "hand.raised.fill")
                    halfTeamStatRow("Tackle",    match.players.reduce(0){$0+$1.stats.tackles}, icon: "shield.fill")
                    halfTeamStatRow("Block",     match.players.reduce(0){$0+$1.stats.blocks},  icon: "rectangle.fill")
                    halfTeamStatRow("被ドリブル", match.players.reduce(0){$0+$1.stats.drbDef}, icon: "figure.run.circle.fill")
                }

                Section { Color.clear.frame(height: 70) }
                    .listRowBackground(Color.clear).listSectionSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("ハーフタイム")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onStartSecondHalf()
                    dismiss()
                } label: {
                    Label("後半開始 (キックオフ)", systemImage: "play.circle.fill")
                        .font(.title3.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(
                            LinearGradient(colors:[.green, Color(red:0.10,green:0.55,blue:0.20)],
                                           startPoint:.top, endPoint:.bottom)
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius:16, style:.continuous))
                        .shadow(color:.black.opacity(0.35), radius:8, y:3)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    @ViewBuilder
    private func halfTeamStatRow(_ label: String, _ value: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.secondary).frame(width: 20)
            Text(label).font(.subheadline)
            Spacer()
            Text("\(value)").font(.subheadline.weight(.bold).monospacedDigit())
        }
    }
}
