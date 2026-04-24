import SwiftUI
import Combine

// ============================================================
// MARK: - MODELS
// ============================================================

enum Position: Int, CaseIterable, Identifiable {
    case fw = 1, mf = 2, df = 3
    var id: Int { rawValue }
    var label: String { switch self { case .fw: return "FW"; case .mf: return "MF"; case .df: return "DF" } }
    var fullLabel: String { switch self { case .fw: return "フォワード"; case .mf: return "ミッドフィールダー"; case .df: return "ディフェンダー" } }
    var color: Color { switch self { case .fw: return .orange; case .mf: return .cyan; case .df: return .indigo } }
    var icon: String { switch self { case .fw: return "flame.fill"; case .mf: return "arrow.left.arrow.right.circle.fill"; case .df: return "shield.fill" } }
    // フィールド上の縦位置（0=上, 1=下）
    var fieldYRatio: CGFloat { switch self { case .fw: return 0.20; case .mf: return 0.50; case .df: return 0.78 } }
}

enum Foot: String, CaseIterable { case right = "右足"; case left = "左足"; case both = "両足" }

// スタッツカテゴリ
enum StatCategory: String, CaseIterable, Identifiable {
    case attack  = "攻撃"
    case defense = "守備"
    case passing = "展開/ミス"
    var id: String { rawValue }
    var icon: String { switch self { case .attack: return "flame.fill"; case .defense: return "shield.fill"; case .passing: return "arrow.triangle.swap" } }
    var color: Color { switch self { case .attack: return .orange; case .defense: return .indigo; case .passing: return .teal } }
    var items: [StatItemDef] { switch self { case .attack: return attackItems; case .defense: return defenseItems; case .passing: return passingItems } }
}

struct StatItemDef: Identifiable {
    let id = UUID()
    let label: String
    let shortLabel: String
    let icon: String
    let keyPath: WritableKeyPath<PlayerStats, Int>
    let isNegative: Bool
}

let attackItems: [StatItemDef] = [
    StatItemDef(label: "ゴール",       shortLabel: "Goal",   icon: "soccerball",                keyPath: \.goals,   isNegative: false),
    StatItemDef(label: "アシスト",     shortLabel: "Assist", icon: "arrow.turn.up.right",        keyPath: \.assists, isNegative: false),
    StatItemDef(label: "シュート",     shortLabel: "Shot",   icon: "arrow.up.right.circle.fill", keyPath: \.spg,     isNegative: false),
    StatItemDef(label: "ドリブル突破", shortLabel: "Drb↑",  icon: "figure.run",                 keyPath: \.drbOff,  isNegative: false),
    StatItemDef(label: "キーパス",     shortLabel: "KeyP",   icon: "key.fill",                   keyPath: \.keyP,    isNegative: false),
]
let defenseItems: [StatItemDef] = [
    StatItemDef(label: "タックル",       shortLabel: "Tackle", icon: "shield.fill",              keyPath: \.tackles, isNegative: false),
    StatItemDef(label: "インターセプト", shortLabel: "Inter",  icon: "hand.raised.fill",         keyPath: \.inter,   isNegative: false),
    StatItemDef(label: "クリア",         shortLabel: "Clear",  icon: "arrow.up.to.line.compact", keyPath: \.clear,   isNegative: false),
    StatItemDef(label: "ブロック",       shortLabel: "Block",  icon: "rectangle.fill",           keyPath: \.blocks,  isNegative: false),
    StatItemDef(label: "ドリブル被",     shortLabel: "Drb↓",  icon: "figure.run.circle.fill",   keyPath: \.drbDef,  isNegative: false),
]
let passingItems: [StatItemDef] = [
    StatItemDef(label: "パス数",       shortLabel: "Pass",   icon: "arrow.triangle.swap",  keyPath: \.avgP,   isNegative: false),
    StatItemDef(label: "ロングボール", shortLabel: "LongB",  icon: "arrow.up.forward",     keyPath: \.longB,  isNegative: false),
    StatItemDef(label: "ボール喪失",   shortLabel: "Disp",   icon: "minus.circle.fill",    keyPath: \.disp,   isNegative: true),
    StatItemDef(label: "ミスタッチ",   shortLabel: "MisTch", icon: "xmark.circle.fill",    keyPath: \.unsTch, isNegative: true),
]

struct PlayerStats {
    var goals: Int = 0;  var assists: Int = 0; var spg: Int = 0
    var drbOff: Int = 0; var keyP: Int = 0;    var tackles: Int = 0
    var inter: Int = 0;  var clear: Int = 0;   var blocks: Int = 0
    var drbDef: Int = 0; var avgP: Int = 0;    var longB: Int = 0
    var disp: Int = 0;   var unsTch: Int = 0

    func calculateRating(for position: Position) -> Double {
        let g=Double(goals); let a=Double(assists); let s=Double(spg)
        let do_=Double(drbOff); let kp=Double(keyP); let tk=Double(tackles)
        let it=Double(inter); let bl=Double(blocks); let dd=Double(drbDef)
        let ap=Double(avgP); let lb=Double(longB); let di=Double(disp); let ut=Double(unsTch)
        var r: Double
        switch position {
        case .fw: r = 5.58+(0.41*g)+(0.61*a)+(0.22*s)+(0.12*do_)+(0.01*ap)-(0.05*di)-(0.04*ut)
        case .mf: r = 5.61+(0.50*g)+(0.68*a)+(0.16*kp)+(0.15*it)+(0.13*tk)+(0.10*do_)+(0.004*ap)+(0.08*lb)
        case .df: r = 5.81+(0.30*it)+(0.15*tk)+(0.67*g)+(0.50*a)+(0.17*kp)+(0.01*ap)+(0.21*bl)-(0.10*dd)
        }
        return min(10.0, max(1.0, r))
    }
}

struct Player: Identifiable {
    let id: UUID = UUID()
    var rosterId: UUID? = nil     // マスターロスターとの紐付け（nil=一回限り）
    var name: String
    var position: Position
    var height: String = ""
    var foot: Foot = .right
    var isStarter: Bool = true
    var stats: PlayerStats = PlayerStats()
    var rating: Double { stats.calculateRating(for: position) }
}

// マスターロスター選手（全試合で使い回せる基本情報・スタッツは持たない）
struct RosterPlayer: Identifiable, Equatable {
    let id: UUID
    var name: String
    var position: Position
    var height: String
    var foot: Foot

    init(id: UUID = UUID(), name: String, position: Position,
         height: String = "", foot: Foot = .right) {
        self.id = id
        self.name = name
        self.position = position
        self.height = height
        self.foot = foot
    }
}

extension Player {
    // ロスターから試合用Playerを生成（スナップショット）
    static func from(roster r: RosterPlayer, isStarter: Bool = true) -> Player {
        var p = Player(name: r.name, position: r.position)
        p.rosterId = r.id
        p.height = r.height
        p.foot = r.foot
        p.isStarter = isStarter
        return p
    }
}

struct Match: Identifiable {
    let id: UUID = UUID()
    var date: Date = Date()
    var opponent: String
    var players: [Player] = []
    var isFinished: Bool = false
    var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP"); return f.string(from: date)
    }
}

func ratingColor(_ r: Double) -> Color {
    r >= 7.0 ? .green : r >= 6.0 ? Color(red:0.9,green:0.75,blue:0) : .red
}
func ratingLabel(_ r: Double) -> String {
    switch r { case 8.5...: return "🌟 MOM級"; case 7.5...: return "⭐️ 優秀"; case 7.0...: return "👍 良好"; case 6.0...: return "😐 平均"; case 5.0...: return "👎 低調"; default: return "❌ 不調" }
}

// ============================================================
// MARK: - APP STATE
// ============================================================

class AppState: ObservableObject {
    @Published var matches: [Match] = []
    @Published var roster: [RosterPlayer] = []   // マスターロスター

    // ── Match管理 ──
    func addMatch(_ m: Match) { matches.insert(m, at: 0) }
    func updateMatch(_ m: Match) { if let i = matches.firstIndex(where:{$0.id==m.id}) { matches[i]=m } }
    func finishMatch(_ id: UUID) { if let i = matches.firstIndex(where:{$0.id==id}) { matches[i].isFinished=true } }

    // ── Roster管理（スナップショット方式：既存試合には影響しない） ──
    func addRosterPlayer(_ p: RosterPlayer) { roster.append(p) }
    func updateRosterPlayer(_ p: RosterPlayer) {
        if let i = roster.firstIndex(where: { $0.id == p.id }) { roster[i] = p }
    }
    func deleteRosterPlayer(id: UUID) {
        roster.removeAll { $0.id == id }
    }
    // ポジション順・名前順でソート
    var sortedRoster: [RosterPlayer] {
        roster.sorted { a, b in
            if a.position.rawValue != b.position.rawValue { return a.position.rawValue < b.position.rawValue }
            return a.name < b.name
        }
    }
}

// ============================================================
// MARK: - ROOT
// ============================================================

struct ContentView: View {
    @StateObject private var appState = AppState()
    var body: some View { HomeView().environmentObject(appState) }
}

// ============================================================
// MARK: - NAVIGATION ROUTE（型安全な画面遷移）
// ============================================================

enum NavRoute: Hashable {
    case registration(UUID)     // 選手登録画面
    case statsCollection(UUID)  // スタッツ収集画面
    case result(UUID)           // 試合結果画面
    case rosterManagement       // ロスター管理画面
}

// ============================================================
// MARK: - HOME VIEW
// ============================================================

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNewMatch = false
    @State private var navPath = NavigationPath()
    @State private var editingRosterPlayer: RosterPlayer? = nil
    @State private var showAddRosterSheet: Bool = false

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    // ── ヘッダー ──
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("⚽️ SoccerRating").font(.largeTitle.weight(.black))
                            Text("試合スタッツ管理").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button { showNewMatch = true } label: {
                            Label("新しい試合", systemImage: "plus.circle.fill")
                                .font(.headline.weight(.bold))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.green).foregroundColor(.white).clipShape(Capsule())
                                .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 20) {
                            // ── 選手ロスターセクション ──
                            rosterSection

                            // ── 試合一覧セクション ──
                            matchListSection
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationDestination(for: NavRoute.self) { route in
                switch route {
                case .registration(let id):
                    PlayerRegistrationView(matchId: id, navPath: $navPath)
                        .environmentObject(appState)
                case .statsCollection(let id):
                    StatsCollectionView(matchId: id)
                        .environmentObject(appState)
                case .result(let id):
                    if let match = appState.matches.first(where: { $0.id == id }) {
                        MatchResultView(match: match)
                    }
                case .rosterManagement:
                    RosterManagementView()
                        .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showNewMatch) {
                NewMatchSheet { opponent, date in
                    let m = Match(date: date, opponent: opponent)
                    appState.addMatch(m)
                    showNewMatch = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        navPath.append(NavRoute.registration(m.id))
                    }
                }
            }
            .sheet(isPresented: $showAddRosterSheet) {
                RosterEditorSheet(editing: nil) { newPlayer in
                    appState.addRosterPlayer(newPlayer)
                }
            }
            .sheet(item: $editingRosterPlayer) { target in
                RosterEditorSheet(editing: target) { updated in
                    appState.updateRosterPlayer(updated)
                } onDelete: {
                    appState.deleteRosterPlayer(id: target.id)
                }
            }
        }
    }

    // ── ロスターセクション（ホーム上部） ──
    private var rosterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.blue)
                Text("選手ロスター")
                    .font(.headline.weight(.bold))
                Text("\(appState.roster.count)名")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                Spacer()
                Button { navPath.append(NavRoute.rosterManagement) } label: {
                    HStack(spacing: 3) {
                        Text("管理").font(.caption.weight(.bold))
                        Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)

            if appState.roster.isEmpty {
                // 空状態
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.blue.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("選手を登録しよう").font(.subheadline.weight(.semibold))
                        Text("一度登録すれば、どの試合でも使い回せます")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button { showAddRosterSheet = true } label: {
                        Text("追加")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.blue).foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)
            } else {
                // 横スクロールチップ
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.sortedRoster) { rp in
                            RosterChip(player: rp)
                                .onTapGesture { editingRosterPlayer = rp }
                        }
                        // ＋追加ボタン
                        Button { showAddRosterSheet = true } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle().fill(Color.blue.opacity(0.12))
                                        .frame(width: 50, height: 50)
                                    Image(systemName: "plus")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.blue)
                                }
                                Text("追加")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // ── 試合一覧セクション ──
    private var matchListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sportscourt.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.green)
                Text("試合一覧")
                    .font(.headline.weight(.bold))
                Text("\(appState.matches.count)試合")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 20)

            if appState.matches.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "sportscourt.fill").font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.25))
                    Text("試合がまだありません").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                    Text("「新しい試合」ボタンから試合を作成しましょう")
                        .font(.caption).foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .padding(.horizontal, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.matches) { match in
                        Button {
                            if match.isFinished {
                                navPath.append(NavRoute.result(match.id))
                            } else {
                                navPath.append(NavRoute.registration(match.id))
                            }
                        } label: {
                            MatchRowCard(match: match)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// ── ロスター選手チップ（横スクロール用コンパクトカード） ──
struct RosterChip: View {
    let player: RosterPlayer
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [player.position.color, player.position.color.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 50, height: 50)
                    .shadow(color: player.position.color.opacity(0.4), radius: 4, x: 0, y: 2)
                Image(systemName: player.position.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                // ポジションバッジ
                VStack {
                    HStack {
                        Spacer()
                        Text(player.position.label)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .offset(x: 4, y: -4)
                    }
                    Spacer()
                }
                .frame(width: 50, height: 50)
            }
            Text(player.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 66)
        }
        .frame(width: 70)
    }
}

// ============================================================
// MARK: - ROSTER EDITOR SHEET（追加 / 編集 / 削除）
// ============================================================

struct RosterEditorSheet: View {
    // editing=nil → 新規追加、editing=有 → 編集
    let editing: RosterPlayer?
    let onSave: (RosterPlayer) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var position: Position
    @State private var height: String
    @State private var foot: Foot
    @State private var showDeleteConfirm: Bool = false
    @FocusState private var focusedField: String?

    init(editing: RosterPlayer?,
         onSave: @escaping (RosterPlayer) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.editing = editing
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: editing?.name ?? "")
        _position = State(initialValue: editing?.position ?? .fw)
        _height = State(initialValue: editing?.height ?? "")
        _foot = State(initialValue: editing?.foot ?? .right)
    }

    private var isEditing: Bool { editing != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // ── ヘッダー ──
            HStack {
                Button("キャンセル") { dismiss() }
                    .foregroundColor(.secondary)
                Spacer()
                Text(isEditing ? "選手を編集" : "選手を追加")
                    .font(.headline.weight(.bold))
                Spacer()
                Button(isEditing ? "保存" : "登録") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    let saved = RosterPlayer(
                        id: editing?.id ?? UUID(),
                        name: trimmed,
                        position: position,
                        height: height.trimmingCharacters(in: .whitespaces),
                        foot: foot
                    )
                    onSave(saved)
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(canSave ? .blue : .secondary)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
            Divider()

            Form {
                Section("基本情報") {
                    HStack {
                        Label("名前", systemImage: "person.fill")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("田中 一郎", text: $name)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: "name")
                    }
                    HStack {
                        Label("ポジション", systemImage: "sportscourt")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $position) {
                            ForEach(Position.allCases) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }

                Section("身体情報") {
                    HStack {
                        Label("身長", systemImage: "ruler")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("175", text: $height)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .focused($focusedField, equals: "height")
                        Text("cm").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("利き足", systemImage: "figure.soccer")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $foot) {
                            ForEach(Foot.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }

                if isEditing, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("この選手を削除", systemImage: "trash.fill")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("削除してもこれまでの試合データには影響しません（スナップショット方式）")
                            .font(.caption2)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if !isEditing { focusedField = "name" }
        }
        .confirmationDialog(
            "「\(name)」を削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ロスターから削除されます。過去の試合データは保持されます。")
        }
    }
}

// ============================================================
// MARK: - ROSTER MANAGEMENT VIEW（一覧・編集・削除）
// ============================================================

struct RosterManagementView: View {
    @EnvironmentObject var appState: AppState
    @State private var editingPlayer: RosterPlayer? = nil
    @State private var showAddSheet: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if appState.roster.isEmpty {
                // ── 空状態 ──
                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 56))
                        .foregroundColor(.blue.opacity(0.55))
                    Text("登録された選手はいません")
                        .font(.headline.weight(.bold))
                    Text("「追加」ボタンから選手を登録すると、\nどの試合でも使い回せるようになります。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("選手を追加", systemImage: "plus.circle.fill")
                            .font(.headline.weight(.bold))
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(Color.blue).foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: .blue.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 40)
            } else {
                List {
                    Section {
                        ForEach(appState.sortedRoster) { rp in
                            Button { editingPlayer = rp } label: {
                                RosterListRow(player: rp)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deletePlayers)
                    } header: {
                        HStack {
                            Text("登録選手 \(appState.roster.count)名")
                            Spacer()
                            Text("行タップで編集 / スワイプで削除")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } footer: {
                        Text("ここでの編集・削除は過去の試合データに影響しません（スナップショット方式）")
                            .font(.caption2)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("選手ロスター管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.bold))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RosterEditorSheet(editing: nil) { newPlayer in
                appState.addRosterPlayer(newPlayer)
            }
        }
        .sheet(item: $editingPlayer) { target in
            RosterEditorSheet(editing: target) { updated in
                appState.updateRosterPlayer(updated)
            } onDelete: {
                appState.deleteRosterPlayer(id: target.id)
            }
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        let sorted = appState.sortedRoster
        let ids = offsets.map { sorted[$0].id }
        for id in ids { appState.deleteRosterPlayer(id: id) }
    }
}

// ── ロスター管理画面用の行 ──
struct RosterListRow: View {
    let player: RosterPlayer
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [player.position.color, player.position.color.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: player.position.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name).font(.headline)
                HStack(spacing: 6) {
                    Text(player.position.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(player.position.color.opacity(0.15))
                        .foregroundColor(player.position.color)
                        .clipShape(Capsule())
                    if !player.height.isEmpty {
                        Text("\(player.height)cm")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text(player.foot.rawValue)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// ============================================================
// MARK: - MATCH ROW CARD
// ============================================================

struct MatchRowCard: View {
    let match: Match
    var avgRating: Double {
        let s = match.players.filter{$0.isStarter}; guard !s.isEmpty else { return 0 }
        return s.reduce(0.0){$0+$1.rating}/Double(s.count)
    }
    var body: some View {
        HStack(spacing:16) {
            RoundedRectangle(cornerRadius:4).fill(match.isFinished ? Color.green : Color.orange).frame(width:5)
            VStack(alignment:.leading,spacing:6) {
                HStack {
                    Text("vs \(match.opponent)").font(.headline.weight(.bold))
                    Spacer()
                    if match.isFinished && !match.players.isEmpty {
                        Text(String(format:"平均 %.2f",avgRating)).font(.subheadline.weight(.semibold)).foregroundColor(ratingColor(avgRating))
                    }
                }
                HStack(spacing:8) {
                    Text(match.dateString).font(.caption).foregroundColor(.secondary)
                    Text("·").foregroundColor(.secondary)
                    Text("\(match.players.count)名").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Text(match.isFinished ? "終了" : "進行中")
                        .font(.caption.weight(.semibold)).padding(.horizontal,10).padding(.vertical,4)
                        .background(match.isFinished ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                        .foregroundColor(match.isFinished ? .green : .orange).clipShape(Capsule())
                }
            }
            Image(systemName:"chevron.right").font(.caption.weight(.semibold)).foregroundColor(.secondary.opacity(0.4))
        }
        .padding(16).background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius:16,style:.continuous))
        .shadow(color:.black.opacity(0.06),radius:8,x:0,y:3)
    }
}

// ============================================================
// MARK: - NEW MATCH SHEET
// ============================================================

struct NewMatchSheet: View {
    let onConfirm: (String, Date) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var opponent = ""
    @State private var date = Date()
    @FocusState private var focused: Bool
    var canCreate: Bool { !opponent.trimmingCharacters(in:.whitespaces).isEmpty }

    var body: some View {
        VStack(spacing:0) {
            HStack {
                Button("キャンセル") { dismiss() }.foregroundColor(.secondary)
                Spacer()
                Text("新しい試合").font(.headline.weight(.bold))
                Spacer()
                Button("作成") { onConfirm(opponent,date) }.fontWeight(.bold)
                    .foregroundColor(canCreate ? .green : .secondary).disabled(!canCreate)
            }.padding(.horizontal,20).padding(.top,20).padding(.bottom,16)
            Divider()

            ScrollView {
                VStack(spacing:28) {
                    ZStack {
                        Circle().fill(Color.green.opacity(0.12)).frame(width:90,height:90)
                        Image(systemName:"sportscourt.fill").font(.system(size:40)).foregroundColor(.green)
                    }.padding(.top,24)

                    VStack(spacing:16) {
                        VStack(alignment:.leading,spacing:8) {
                            Label("対戦相手",systemImage:"person.2.fill").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                            TextField("例: FC東京",text:$opponent).font(.title3).padding(14)
                                .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius:12)).focused($focused)
                        }
                        VStack(alignment:.leading,spacing:8) {
                            Label("試合日時",systemImage:"calendar").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                            DatePicker("",selection:$date,displayedComponents:[.date,.hourAndMinute])
                                .datePickerStyle(.compact).labelsHidden().padding(14)
                                .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius:12))
                        }
                    }.padding(.horizontal,24)

                    Button { guard canCreate else { return }; onConfirm(opponent,date) } label: {
                        Text("試合を作成して選手登録へ →").font(.headline.weight(.bold)).frame(maxWidth:.infinity).padding(.vertical,18)
                            .background(canCreate ? Color.green : Color.gray).foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius:14))
                    }.disabled(!canCreate).padding(.horizontal,24).padding(.bottom,32)
                }
            }
        }
        .presentationDetents([.medium,.large]).onAppear { focused = true }
    }
}

// ============================================================
// MARK: - PLAYER REGISTRATION VIEW
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
// MARK: - ADD PLAYER SHEET
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

// ============================================================
// MARK: - STATS COLLECTION VIEW（サッカーコート画面）
// ============================================================

struct StatsCollectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let matchId: UUID

    @State private var selectedPlayerId: UUID? = nil
    @State private var showFinishAlert = false
    // 選手ごとのドラッグオフセット [Player.id : CGSize]
    @State private var dragOffsets: [UUID: CGSize] = [:]

    var matchIndex: Int? { appState.matches.firstIndex(where:{$0.id==matchId}) }
    var match: Match { appState.matches.first(where:{$0.id==matchId}) ?? Match(opponent:"") }
    var starters: [Player] { match.players.filter{$0.isStarter} }
    var avgRating: Double {
        guard !starters.isEmpty else { return 0 }
        return starters.reduce(0.0){$0+$1.rating}/Double(starters.count)
    }

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
                            // ドラッグ中はタップ無効
                            guard dragOffsets[player.id] == .zero || dragOffsets[player.id] == nil else { return }
                            withAnimation(.spring(response:0.3,dampingFraction:0.7)) {
                                selectedPlayerId = (selectedPlayerId == player.id) ? nil : player.id
                            }
                        },
                        onDragChanged: { drag in
                            // ドラッグ中はラジアル非表示
                            selectedPlayerId = nil
                            let cur = dragOffsets[player.id] ?? .zero
                            dragOffsets[player.id] = CGSize(
                                width:  cur.width  + drag.translation.width,
                                height: cur.height + drag.translation.height
                            )
                        },
                        onDragEnded: { drag in
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
                }

                // ─── 上部ヘッダー ───
                VStack {
                    HStack {
                        VStack(alignment:.leading,spacing:2) {
                            Text("vs \(match.opponent)").font(.headline.weight(.bold)).foregroundColor(.white)
                                .shadow(color:.black.opacity(0.6),radius:2)
                            Text(match.dateString).font(.caption).foregroundColor(.white.opacity(0.85))
                                .shadow(color:.black.opacity(0.6),radius:2)
                        }
                        Spacer()
                        VStack(alignment:.trailing,spacing:1) {
                            Text("チーム平均").font(.caption2).foregroundColor(.white.opacity(0.8))
                            Text(String(format:"%.2f",avgRating)).font(.title2.weight(.black))
                                .foregroundColor(ratingColor(avgRating))
                                .shadow(color:.black.opacity(0.5),radius:3)
                        }
                    }
                    .padding(.horizontal,20).padding(.top,8).padding(.bottom,12)
                    .background(.ultraThinMaterial.opacity(0.85))
                    Spacer()
                }

                // ─── 6角フリック入力メニューオーバーレイ ───
                if let pid = selectedPlayerId,
                   let mi = matchIndex,
                   let pi = appState.matches[mi].players.firstIndex(where:{$0.id==pid}) {

                    Color.black.opacity(0.70).ignoresSafeArea()
                        .onTapGesture { withAnimation { selectedPlayerId = nil } }

                    HexButtonMenu(
                        player: $appState.matches[mi].players[pi],
                        onClose: { withAnimation { selectedPlayerId = nil } }
                    )
                    .transition(.asymmetric(
                        insertion:.scale(scale:0.4).combined(with:.opacity),
                        removal:.scale(scale:0.4).combined(with:.opacity)
                    ))
                }
            }
        }
        .navigationTitle("スタッツ収集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement:.navigationBarTrailing) {
                Button { showFinishAlert = true } label: {
                    Label("試合終了",systemImage:"flag.checkered").font(.subheadline.weight(.bold)).foregroundColor(.red)
                }
            }
        }
        .alert("試合を終了しますか？",isPresented:$showFinishAlert) {
            Button("終了する",role:.destructive) { appState.finishMatch(matchId); dismiss(); dismiss() }
            Button("キャンセル",role:.cancel) {}
        } message: { Text("結果はホームに保存されます。") }
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

// Comparable クランプ拡張
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// ============================================================
// MARK: - SOCCER FIELD VIEW（SVGスタイルのコート描画）
// ============================================================

struct SoccerFieldView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 芝の色
                LinearGradient(
                    colors: [Color(red:0.13,green:0.55,blue:0.13), Color(red:0.10,green:0.45,blue:0.10)],
                    startPoint:.top, endPoint:.bottom
                )

                // ストライプ模様
                FieldStripes(width:w, height:h)
                    .opacity(0.12)

                // ライン描画
                Canvas { ctx, size in
                    let lc = Color.white.opacity(0.85)
                    let lw: CGFloat = 2.0

                    func line(_ x1:CGFloat,_ y1:CGFloat,_ x2:CGFloat,_ y2:CGFloat) {
                        var p = Path(); p.move(to:CGPoint(x:x1,y:y1)); p.addLine(to:CGPoint(x:x2,y:y2))
                        ctx.stroke(p, with:.color(lc), lineWidth:lw)
                    }
                    func rect(_ x:CGFloat,_ y:CGFloat,_ rw:CGFloat,_ rh:CGFloat) {
                        let r = CGRect(x:x,y:y,width:rw,height:rh)
                        ctx.stroke(Path(r), with:.color(lc), lineWidth:lw)
                    }

                    let W = size.width, H = size.height
                    let padX: CGFloat = 18, padY: CGFloat = 60

                    // 外枠
                    rect(padX, padY, W-padX*2, H-padY*2)

                    // センターライン
                    line(padX, H/2, W-padX, H/2)

                    // センターサークル
                    let cr: CGFloat = min(W,H)*0.12
                    var circle = Path(); circle.addEllipse(in:CGRect(x:W/2-cr,y:H/2-cr,width:cr*2,height:cr*2))
                    ctx.stroke(circle, with:.color(lc), lineWidth:lw)

                    // センタースポット
                    var spot = Path(); spot.addEllipse(in:CGRect(x:W/2-3,y:H/2-3,width:6,height:6))
                    ctx.fill(spot, with:.color(lc))

                    // ペナルティエリア（上）
                    let paw = W * 0.52, pah = H * 0.14
                    rect((W-paw)/2, padY, paw, pah)

                    // ゴールエリア（上）
                    let gaw = W * 0.26, gah = H * 0.06
                    rect((W-gaw)/2, padY, gaw, gah)

                    // ゴール枠（上）
                    let goalW = W * 0.14, goalH: CGFloat = 14
                    rect((W-goalW)/2, padY-goalH, goalW, goalH)

                    // ペナルティエリア（下）
                    rect((W-paw)/2, H-padY-pah, paw, pah)

                    // ゴールエリア（下）
                    rect((W-gaw)/2, H-padY-gah, gaw, gah)

                    // ゴール枠（下）
                    rect((W-goalW)/2, H-padY, goalW, goalH)

                    // コーナーアーク（4隅）
                    let cr2: CGFloat = 12
                    for (cx,cy,sa,ea): (CGFloat,CGFloat,CGFloat,CGFloat) in [
                        (padX, padY, 0, CGFloat.pi/2),
                        (W-padX, padY, CGFloat.pi/2, CGFloat.pi),
                        (W-padX, H-padY, CGFloat.pi, 3*CGFloat.pi/2),
                        (padX, H-padY, 3*CGFloat.pi/2, 2*CGFloat.pi)
                    ] {
                        var arc = Path(); arc.addArc(center:CGPoint(x:cx,y:cy),radius:cr2,startAngle:.radians(sa),endAngle:.radians(ea),clockwise:false)
                        ctx.stroke(arc, with:.color(lc), lineWidth:lw)
                    }

                    // ペナルティスポット（上・下）
                    for sy: CGFloat in [padY + H*0.10, H-padY-H*0.10] {
                        var ps = Path(); ps.addEllipse(in:CGRect(x:W/2-3,y:sy-3,width:6,height:6))
                        ctx.fill(ps, with:.color(lc))
                    }

                    // ペナルティアーク（上・下）
                    let parc: CGFloat = min(W,H)*0.10
                    var topArc = Path()
                    topArc.addArc(center:CGPoint(x:W/2,y:padY+H*0.10),radius:parc,startAngle:.degrees(30),endAngle:.degrees(150),clockwise:false)
                    ctx.stroke(topArc, with:.color(lc), lineWidth:lw)
                    var botArc = Path()
                    botArc.addArc(center:CGPoint(x:W/2,y:H-padY-H*0.10),radius:parc,startAngle:.degrees(210),endAngle:.degrees(330),clockwise:false)
                    ctx.stroke(botArc, with:.color(lc), lineWidth:lw)
                }
            }
        }
    }
}

struct FieldStripes: View {
    let width: CGFloat; let height: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let stripeH: CGFloat = size.height / 10
            for i in 0..<10 {
                if i % 2 == 0 {
                    let r = CGRect(x:0, y:stripeH*CGFloat(i), width:size.width, height:stripeH)
                    ctx.fill(Path(r), with:.color(.white))
                }
            }
        }.frame(width:width, height:height)
    }
}

// ============================================================
// MARK: - PLAYER FIELD ICON
// ============================================================

struct PlayerFieldIcon: View {
    let player: Player
    let isSelected: Bool
    let onTap: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded:   (DragGesture.Value) -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if isSelected {
                    Circle().stroke(Color.white, lineWidth: 3)
                        .frame(width: 66, height: 66)
                        .shadow(color: player.position.color.opacity(0.9), radius: 10)
                }
                Circle()
                    .fill(isSelected
                          ? LinearGradient(colors:[player.position.color, player.position.color.opacity(0.7)],
                                           startPoint:.top, endPoint:.bottom)
                          : LinearGradient(colors:[Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                                           startPoint:.top, endPoint:.bottom))
                    .frame(width: 58, height: 58)
                    .shadow(color: isSelected ? player.position.color.opacity(0.6) : .black.opacity(0.35),
                            radius: isSelected ? 12 : 6, x:0, y:3)
                    .overlay(
                        // ドラッグ中の視覚フィードバック
                        Circle().stroke(Color.white.opacity(isDragging ? 0.6 : 0), lineWidth: 2)
                    )

                Image(systemName: player.position.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .white : player.position.color)
            }
            .scaleEffect(isSelected ? 1.12 : (isDragging ? 1.18 : 1.0))

            Text(player.name)
                .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.black.opacity(isDragging ? 0.8 : 0.6))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.4), radius: 2)

            Text(String(format: "%.2f", player.rating))
                .font(.system(size: 10, weight: .black))
                .foregroundColor(ratingColor(player.rating))
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
        .animation(.spring(response:0.3,dampingFraction:0.65), value: isSelected)
        .animation(.spring(response:0.2,dampingFraction:0.7), value: isDragging)
        // タップ
        .onTapGesture { onTap() }
        // ドラッグ（長押し後に開始してもOK、閾値5pt）
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { val in
                    if !isDragging {
                        withAnimation(.spring(response:0.2)) { isDragging = true }
                    }
                    onDragChanged(val)
                }
                .onEnded { val in
                    withAnimation(.spring(response:0.3)) { isDragging = false }
                    onDragEnded(val)
                }
        )
    }
}

// ============================================================
// MARK: - HEX BUTTON FLICK MENU（6角形フリック入力UI）
// ============================================================

// スタッツ効果：どのスタッツを±いくつ変動させるか
struct StatEffect {
    let keyPath: WritableKeyPath<PlayerStats, Int>
    let delta: Int
}

// フリック選択肢
struct FlickOption: Identifiable {
    let id = UUID()
    let label: String
    let angleDeg: Double         // 0°=右, 90°=上, 180°=左, 270°/-90°=下
    let effects: [StatEffect]    // 付随して発生するスタッツ更新
    let color: Color
}

// 6角形の母体ボタン設定
struct HexButtonConfig: Identifiable {
    let id: String
    let label: String
    let subtitle: String
    let icon: String
    let positionAngleDeg: Double // 中央から見たボタンの配置角度
    let color: Color
    let tapEffects: [StatEffect]?    // nil = タップ無効（フリック必須）
    let tapIsShootMenu: Bool         // true = SHOOTボタン（Goal/Missサブメニュー展開）
    let flickOptions: [FlickOption]
}

struct HexButtonMenu: View {
    @Binding var player: Player
    let onClose: () -> Void

    @State private var activeButtonId: String? = nil
    @State private var shootMenuOpen: Bool = false
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var appeared: Bool = false

    // 6ボタンの構成
    private var buttonConfigs: [HexButtonConfig] {
        [
            // ① SHOOT（上）
            HexButtonConfig(
                id: "shoot", label: "SHOOT", subtitle: "シュート",
                icon: "soccerball",
                positionAngleDeg: 90,
                color: Color(red:0.95, green:0.25, blue:0.30),
                tapEffects: nil,
                tapIsShootMenu: true,
                flickOptions: []
            ),
            // ② PASS（右上）
            HexButtonConfig(
                id: "pass", label: "PASS", subtitle: "パス",
                icon: "arrow.triangle.swap",
                positionAngleDeg: 30,
                color: Color(red:0.20, green:0.55, blue:0.95),
                tapEffects: [StatEffect(keyPath:\.avgP, delta:1)],
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"Key Pass", angleDeg:90, effects:[
                        StatEffect(keyPath:\.avgP, delta:1),
                        StatEffect(keyPath:\.keyP, delta:1)
                    ], color:Color.cyan),
                    FlickOption(label:"Assist", angleDeg:0, effects:[
                        StatEffect(keyPath:\.avgP,    delta:1),
                        StatEffect(keyPath:\.keyP,    delta:1),
                        StatEffect(keyPath:\.assists, delta:1)
                    ], color:Color.yellow)
                ]
            ),
            // ③ DRIBBLE（右下）
            HexButtonConfig(
                id: "dribble", label: "DRIBBLE", subtitle: "ドリブル",
                icon: "figure.run",
                positionAngleDeg: -30,
                color: Color(red:0.20, green:0.75, blue:0.40),
                tapEffects: nil,
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"成功 (drbOff)", angleDeg:90, effects:[
                        StatEffect(keyPath:\.drbOff, delta:1)
                    ], color:Color.green),
                    FlickOption(label:"失敗 (Disp)", angleDeg:-90, effects:[
                        StatEffect(keyPath:\.disp, delta:1)
                    ], color:Color.red)
                ]
            ),
            // ⑥ MISS（下）※目立つ赤系
            HexButtonConfig(
                id: "miss", label: "MISS", subtitle: "ロスト",
                icon: "xmark.circle.fill",
                positionAngleDeg: -90,
                color: Color(red:0.85, green:0.10, blue:0.40),
                tapEffects: nil,
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"MisTouch", angleDeg:180, effects:[
                        StatEffect(keyPath:\.unsTch, delta:1)
                    ], color:Color.orange),
                    FlickOption(label:"Dish (ロスト)", angleDeg:0, effects:[
                        StatEffect(keyPath:\.disp, delta:1)
                    ], color:Color(red:1.0, green:0.35, blue:0.35))
                ]
            ),
            // ④ DEFENSE（左下）
            HexButtonConfig(
                id: "defense", label: "DEFENSE", subtitle: "守備",
                icon: "shield.fill",
                positionAngleDeg: -150,
                color: Color(red:0.45, green:0.30, blue:0.85),
                tapEffects: nil,
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"Tackle", angleDeg:90, effects:[
                        StatEffect(keyPath:\.tackles, delta:1)
                    ], color:Color.indigo),
                    FlickOption(label:"Inter", angleDeg:180, effects:[
                        StatEffect(keyPath:\.inter, delta:1)
                    ], color:Color.blue),
                    FlickOption(label:"Block", angleDeg:-90, effects:[
                        StatEffect(keyPath:\.blocks, delta:1)
                    ], color:Color.cyan)
                ]
            ),
            // ⑤ CLEAR（左上）
            HexButtonConfig(
                id: "clear", label: "CLEAR", subtitle: "クリア",
                icon: "arrow.up.to.line",
                positionAngleDeg: 150,
                color: Color(red:0.95, green:0.55, blue:0.15),
                tapEffects: [StatEffect(keyPath:\.clear, delta:1)],
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"Long Ball", angleDeg:90, effects:[
                        StatEffect(keyPath:\.longB, delta:1)
                    ], color:Color.yellow)
                ]
            ),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2
            let buttonRadius: CGFloat = 125

            ZStack {
                // ── 6角形ボタン群 ──
                ForEach(buttonConfigs) { config in
                    let rad = config.positionAngleDeg * .pi / 180
                    let dx = buttonRadius * cos(CGFloat(rad))
                    let dy = -buttonRadius * sin(CGFloat(rad))

                    HexButton(
                        config: config,
                        isActive: activeButtonId == config.id,
                        onPressStart: {
                            activeButtonId = config.id
                            UIImpactFeedbackGenerator(style:.light).impactOccurred()
                        },
                        onFlickCommit: { effects, label in
                            applyEffects(effects, toast: label)
                            activeButtonId = nil
                        },
                        onTapCommit: {
                            if config.tapIsShootMenu {
                                withAnimation(.spring(response:0.3,dampingFraction:0.65)) {
                                    shootMenuOpen = true
                                }
                            } else if let tap = config.tapEffects {
                                applyEffects(tap, toast: config.label)
                            }
                            activeButtonId = nil
                        },
                        onCancel: {
                            activeButtonId = nil
                        }
                    )
                    .position(x: centerX + dx, y: centerY + dy)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response:0.42, dampingFraction:0.62)
                            .delay(Double(buttonConfigs.firstIndex(where:{$0.id==config.id}) ?? 0) * 0.04),
                        value: appeared
                    )
                    .zIndex(activeButtonId == config.id ? 100 : 1)
                }

                // ── 中央：選手パネル ──
                CenterPlayerPanel(player: player, onClose: onClose)
                    .position(x: centerX, y: centerY)
                    .zIndex(5)

                // ── SHOOTサブメニュー（Goal/Miss） ──
                if shootMenuOpen {
                    ShootSubmenuView(
                        onGoal: {
                            applyEffects([
                                StatEffect(keyPath:\.spg,   delta:1),
                                StatEffect(keyPath:\.goals, delta:1)
                            ], toast: "⚽️ GOAL!")
                            withAnimation { shootMenuOpen = false }
                        },
                        onMiss: {
                            applyEffects([
                                StatEffect(keyPath:\.spg, delta:1)
                            ], toast: "🎯 Shoot (外れ)")
                            withAnimation { shootMenuOpen = false }
                        },
                        onCancel: {
                            withAnimation { shootMenuOpen = false }
                        }
                    )
                    .position(x: centerX, y: centerY - 190)
                    .zIndex(200)
                    .transition(.scale(scale:0.3).combined(with:.opacity))
                }

                // ── トースト通知 ──
                if showToast {
                    VStack {
                        Text(toastMessage)
                            .font(.system(size:15, weight:.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(
                                Capsule().fill(Color.black.opacity(0.88))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth:1))
                            )
                            .shadow(color:.black.opacity(0.5), radius:10)
                        Spacer()
                    }
                    .padding(.top, 70)
                    .frame(maxWidth:.infinity)
                    .transition(.move(edge:.top).combined(with:.opacity))
                    .zIndex(300)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response:0.45, dampingFraction:0.65)) { appeared = true }
        }
    }

    private func applyEffects(_ effects: [StatEffect], toast: String) {
        for e in effects {
            player.stats[keyPath: e.keyPath] += e.delta
        }
        UIImpactFeedbackGenerator(style:.medium).impactOccurred()
        toastMessage = toast
        withAnimation(.spring(response:0.3, dampingFraction:0.7)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline:.now() + 1.2) {
            withAnimation(.easeOut(duration:0.2)) { showToast = false }
        }
    }
}

// ── 6角形ボタン（タップ／フリック両対応、扇状ガイド表示） ──
struct HexButton: View {
    let config: HexButtonConfig
    let isActive: Bool
    let onPressStart: () -> Void
    let onFlickCommit: ([StatEffect], String) -> Void
    let onTapCommit: () -> Void
    let onCancel: () -> Void

    @State private var highlightedOptionId: UUID? = nil
    @State private var hasStarted: Bool = false

    private let buttonSize: CGFloat = 82
    private let flickThreshold: CGFloat = 32
    private let fanRadius: CGFloat = 78

    var body: some View {
        ZStack {
            // ── 扇状ガイド（アクティブ時のみ表示） ──
            if isActive {
                ForEach(config.flickOptions) { option in
                    let rad = option.angleDeg * .pi / 180
                    let ox = fanRadius * cos(CGFloat(rad))
                    let oy = -fanRadius * sin(CGFloat(rad))
                    let isHL = highlightedOptionId == option.id

                    // ガイドライン
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: ox, y: oy))
                    }
                    .stroke(
                        isHL ? option.color : option.color.opacity(0.35),
                        style: StrokeStyle(lineWidth: isHL ? 3 : 2, lineCap:.round, dash:[4,4])
                    )

                    // ラベルバブル
                    Text(option.label)
                        .font(.system(size:11, weight:.heavy))
                        .foregroundColor(isHL ? .black : .white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(
                            Capsule().fill(isHL ? option.color : Color.black.opacity(0.88))
                        )
                        .overlay(
                            Capsule().stroke(option.color, lineWidth: isHL ? 0 : 1.5)
                        )
                        .scaleEffect(isHL ? 1.18 : 1.0)
                        .shadow(color: option.color.opacity(isHL ? 0.9 : 0.4), radius: isHL ? 10 : 5)
                        .offset(x: ox, y: oy)
                        .animation(.spring(response:0.2, dampingFraction:0.7), value: isHL)
                }
            }

            // ── 6角形ボタン本体 ──
            ZStack {
                HexagonShape()
                    .fill(LinearGradient(
                        colors:[
                            config.color,
                            config.color.opacity(0.55)
                        ],
                        startPoint:.topLeading, endPoint:.bottomTrailing
                    ))
                    .overlay(
                        HexagonShape().stroke(
                            isActive ? Color.white : Color.white.opacity(0.35),
                            lineWidth: isActive ? 3 : 1.5
                        )
                    )
                    .shadow(color: config.color.opacity(isActive ? 0.85 : 0.45),
                            radius: isActive ? 18 : 8, x:0, y:4)
                VStack(spacing:1) {
                    Image(systemName: config.icon)
                        .font(.system(size:22, weight:.bold))
                        .foregroundColor(.white)
                    Text(config.label)
                        .font(.system(size:11, weight:.heavy))
                        .foregroundColor(.white)
                    Text(config.subtitle)
                        .font(.system(size:8, weight:.semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(width: buttonSize, height: buttonSize * 0.92)
            .scaleEffect(isActive ? 1.10 : 1.0)
            .animation(.spring(response:0.22, dampingFraction:0.65), value: isActive)
        }
        .frame(width: buttonSize * 1.15, height: buttonSize * 1.15)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !hasStarted {
                        hasStarted = true
                        onPressStart()
                    }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let dist = sqrt(dx*dx + dy*dy)

                    if dist > flickThreshold && !config.flickOptions.isEmpty {
                        // 指の移動方向の角度（画面座標→数学座標に反転）
                        let userAngle = atan2(-Double(dy), Double(dx))
                        var bestId: UUID? = nil
                        var bestDiff: Double = .pi / 3  // 最大±60°以内
                        for option in config.flickOptions {
                            let optRad = option.angleDeg * .pi / 180
                            var diff = abs(userAngle - optRad)
                            if diff > .pi { diff = 2 * .pi - diff }
                            if diff < bestDiff {
                                bestDiff = diff
                                bestId = option.id
                            }
                        }
                        if highlightedOptionId != bestId {
                            highlightedOptionId = bestId
                            if bestId != nil {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    } else {
                        if highlightedOptionId != nil {
                            highlightedOptionId = nil
                        }
                    }
                }
                .onEnded { value in
                    defer {
                        hasStarted = false
                        highlightedOptionId = nil
                    }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let dist = sqrt(dx*dx + dy*dy)

                    if dist < flickThreshold {
                        // タップ扱い
                        if config.tapIsShootMenu || config.tapEffects != nil {
                            onTapCommit()
                        } else {
                            // タップ無効ボタン（DRIBBLE, DEFENSE, MISS）
                            onCancel()
                        }
                    } else if let hlId = highlightedOptionId,
                              let opt = config.flickOptions.first(where: { $0.id == hlId }) {
                        onFlickCommit(opt.effects, opt.label)
                    } else {
                        onCancel()
                    }
                }
        )
    }
}

// 6角形シェイプ（ポイントトップ）
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to:    CGPoint(x: w*0.5,  y: 0))
        path.addLine(to: CGPoint(x: w,      y: h*0.25))
        path.addLine(to: CGPoint(x: w,      y: h*0.75))
        path.addLine(to: CGPoint(x: w*0.5,  y: h))
        path.addLine(to: CGPoint(x: 0,      y: h*0.75))
        path.addLine(to: CGPoint(x: 0,      y: h*0.25))
        path.closeSubpath()
        return path
    }
}

// ── 中央選手パネル ──
struct CenterPlayerPanel: View {
    let player: Player
    let onClose: () -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(player.position.color.opacity(0.18))
                .frame(width:130, height:130)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration:1.5).repeatForever(autoreverses:true), value: pulse)
            Circle()
                .fill(LinearGradient(
                    colors:[player.position.color, player.position.color.opacity(0.65)],
                    startPoint:.topLeading, endPoint:.bottomTrailing
                ))
                .frame(width: 112, height: 112)
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                .shadow(color: player.position.color.opacity(0.7), radius: 20)

            VStack(spacing:3) {
                Text(player.position.label)
                    .font(.system(size:10, weight:.black))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.3)))
                Text(player.name)
                    .font(.system(size:12, weight:.bold))
                    .foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 92)
                Text(String(format:"%.2f", player.rating))
                    .font(.system(size:26, weight:.black, design:.rounded))
                    .foregroundColor(.white)
                    .shadow(color:.black.opacity(0.4), radius: 2)
                Text(ratingLabel(player.rating))
                    .font(.system(size:8, weight:.heavy))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 112, height: 112)

            // ×ボタン
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.5)).frame(width: 30, height: 30)
                            Image(systemName:"xmark")
                                .font(.system(size:11, weight:.bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                Spacer()
            }
            .frame(width: 112, height: 112)
        }
        .onAppear { pulse = true }
    }
}

// ── SHOOTサブメニュー（Goal / Miss 二択） ──
struct ShootSubmenuView: View {
    let onGoal: () -> Void
    let onMiss: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("GOAL? / MISS?")
                .font(.system(size:13, weight:.black))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color:.black.opacity(0.6), radius:2)

            HStack(spacing: 14) {
                // GOAL
                Button(action: onGoal) {
                    VStack(spacing: 3) {
                        Image(systemName:"soccerball")
                            .font(.system(size:28, weight:.bold))
                        Text("GOAL")
                            .font(.system(size:13, weight:.heavy))
                    }
                    .foregroundColor(.white)
                    .frame(width: 88, height: 88)
                    .background(
                        Circle().fill(LinearGradient(
                            colors:[Color(red:0.2,green:0.85,blue:0.35), Color(red:0.1,green:0.6,blue:0.25)],
                            startPoint:.top, endPoint:.bottom
                        ))
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .green.opacity(0.8), radius: 18)
                }
                .buttonStyle(.plain)

                // MISS（外れ）
                Button(action: onMiss) {
                    VStack(spacing: 3) {
                        Image(systemName:"xmark")
                            .font(.system(size:26, weight:.bold))
                        Text("MISS")
                            .font(.system(size:13, weight:.heavy))
                    }
                    .foregroundColor(.white)
                    .frame(width: 88, height: 88)
                    .background(
                        Circle().fill(LinearGradient(
                            colors:[Color(red:0.95,green:0.30,blue:0.30), Color(red:0.7,green:0.15,blue:0.2)],
                            startPoint:.top, endPoint:.bottom
                        ))
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .red.opacity(0.8), radius: 18)
                }
                .buttonStyle(.plain)
            }

            Button(action: onCancel) {
                Text("キャンセル")
                    .font(.system(size:11, weight:.semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Capsule().stroke(Color.white.opacity(0.45), lineWidth:1))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style:.continuous)
                .fill(Color.black.opacity(0.80))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style:.continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color:.black.opacity(0.5), radius: 14)
        )
    }
}

// ============================================================
// MARK: - MATCH RESULT VIEW
// ============================================================

struct MatchResultView: View {
    let match: Match
    var sortedPlayers: [Player] { match.players.filter{$0.isStarter}.sorted{$0.rating>$1.rating} }
    var avgRating: Double {
        guard !sortedPlayers.isEmpty else { return 0 }
        return sortedPlayers.reduce(0.0){$0+$1.rating}/Double(sortedPlayers.count)
    }
    var body: some View {
        List {
            Section {
                VStack(spacing:10) {
                    Text("チーム平均レーティング").font(.subheadline).foregroundColor(.secondary)
                    Text(String(format:"%.2f",avgRating))
                        .font(.system(size:64,weight:.black,design:.rounded)).foregroundColor(ratingColor(avgRating))
                    Text(ratingLabel(avgRating)).font(.subheadline.weight(.semibold)).foregroundColor(ratingColor(avgRating).opacity(0.8))
                }
                .frame(maxWidth:.infinity).padding(.vertical,16).listRowBackground(Color(.secondarySystemBackground))
            }
            Section("選手ランキング") {
                ForEach(Array(sortedPlayers.enumerated()),id:\.element.id) { idx, player in
                    HStack(spacing:14) {
                        Text(idx<3 ? ["🥇","🥈","🥉"][idx] : "\(idx+1)").font(.title3.weight(.bold)).frame(width:36)
                        ZStack {
                            Circle().fill(player.position.color.opacity(0.15)).frame(width:40,height:40)
                            Image(systemName:player.position.icon).foregroundColor(player.position.color).font(.system(size:16,weight:.semibold))
                        }
                        VStack(alignment:.leading,spacing:2) {
                            Text(player.name).font(.headline)
                            HStack(spacing:6) {
                                Text(player.position.fullLabel).font(.caption).foregroundColor(.secondary)
                                if !player.height.isEmpty { Text("\(player.height)cm").font(.caption).foregroundColor(.secondary) }
                                Text(player.foot.rawValue).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text(String(format:"%.2f",player.rating)).font(.title2.weight(.black)).foregroundColor(ratingColor(player.rating))
                    }.padding(.vertical,4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("vs \(match.opponent) 結果")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ============================================================
// MARK: - PREVIEW
// ============================================================

#Preview {
    ContentView()
}
