import SwiftUI

// ============================================================
// MARK: - MODELS（データモデル定義）
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
    // ── カード（レーティング非影響） ──
    var yellowCards: Int = 0
    var redCards: Int = 0

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
        // ── カード減点（上限 -1.0：2Y=R 換算のため） ──
        // 1Y → -0.5、2Y or 1R → -1.0、それ以上は加算されない
        let cardPenalty = min(1.0, 0.5 * Double(yellowCards) + 1.0 * Double(redCards))
        r -= cardPenalty
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
    var wasSubstituted: Bool = false   // 交代でOUTした選手（再投入不可）
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

// ── レーティング表示用ヘルパー ──
func ratingColor(_ r: Double) -> Color {
    r >= 7.0 ? .green : r >= 6.0 ? Color(red:0.9,green:0.75,blue:0) : .red
}
func ratingLabel(_ r: Double) -> String {
    switch r { case 8.5...: return "🌟 MOM級"; case 7.5...: return "⭐️ 優秀"; case 7.0...: return "👍 良好"; case 6.0...: return "😐 平均"; case 5.0...: return "👎 低調"; default: return "❌ 不調" }
}

// ── Comparable クランプ拡張（汎用ユーティリティ） ──
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
