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
    StatItemDef(label: "被ファウル",   shortLabel: "Fouled", icon: "hand.raised.fill",     keyPath: \.fouled, isNegative: false),
    StatItemDef(label: "ファウル",     shortLabel: "Foul",   icon: "exclamationmark.triangle.fill", keyPath: \.fouls,  isNegative: true),
]

struct PlayerStats {
    var goals: Int = 0;  var assists: Int = 0; var spg: Int = 0
    var drbOff: Int = 0; var keyP: Int = 0;    var tackles: Int = 0
    var inter: Int = 0;  var clear: Int = 0;   var blocks: Int = 0
    var drbDef: Int = 0; var avgP: Int = 0;    var longB: Int = 0
    var disp: Int = 0;   var unsTch: Int = 0
    // ── 反則 ──
    var fouled: Int = 0  // 被ファウル（FW評価で +0.05）
    var fouls:  Int = 0  // ファウル（評価式非影響、記録のみ）
    // ── カード（レーティング非影響） ──
    var yellowCards: Int = 0
    var redCards: Int = 0

    /// 新評価式：score_new = 6.00 − Time_Loss(pos) × mins + Stat_Bonus(pos)
    /// - Time_Loss(FW)=0.42/90, (MF)=0.39/90, (DF)=0.19/90 を mins に乗じて減点
    /// - Stat_Bonus はポジション別に有意項目のみ加算
    func calculateRating(for position: Position, mins: Double) -> Double {
        let g  = Double(goals);  let a  = Double(assists); let s  = Double(spg)
        let do_ = Double(drbOff); let kp = Double(keyP);    let tk = Double(tackles)
        let it = Double(inter);  let bl = Double(blocks);  let dd = Double(drbDef)
        let ap = Double(avgP)
        let fd = Double(fouled); let di = Double(disp);    let ut = Double(unsTch)

        // ── 時間減点（出場分数に比例、初期値 6.00 から差し引き） ──
        let timeLossRate: Double
        switch position {
        case .fw: timeLossRate = 0.42 / 90.0
        case .mf: timeLossRate = 0.39 / 90.0
        case .df: timeLossRate = 0.19 / 90.0
        }
        let timeLoss = timeLossRate * max(0, mins)

        // ── スタッツ加点（ポジション別の重回帰係数） ──
        // 90分プレー時は元の切片(FW=5.58, MF=5.61, DF=5.81)と完全一致
        let statBonus: Double
        switch position {
        case .fw:
            // FW: 0.41G + 0.61A + 0.22SpG + 0.12Drb_Off + 0.01AvgP + 0.05Fouled − 0.05Disp − 0.04UnsTch
            statBonus = 0.41*g + 0.61*a + 0.22*s + 0.12*do_ + 0.01*ap
                      + 0.05*fd - 0.05*di - 0.04*ut
        case .mf:
            // MF: 0.50G + 0.68A + 0.16KeyP + 0.15Inter + 0.13Tackles + 0.10Drb_Off + 0.004AvgP
            statBonus = 0.50*g + 0.68*a + 0.16*kp + 0.15*it + 0.13*tk
                      + 0.10*do_ + 0.004*ap
        case .df:
            // DF: 0.30Inter + 0.67G + 0.50A + 0.17KeyP + 0.01AvgP + 0.21Blocks − 0.10Drb_Def
            statBonus = 0.30*it + 0.67*g + 0.50*a + 0.17*kp + 0.01*ap
                      + 0.21*bl - 0.10*dd
        }

        var r = 6.00 - timeLoss + statBonus

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

    // ── 出場時間トラッキング ──
    // 現在ピッチに立ち始めた時刻（nil = 控え/退場中）
    var lastFieldEnterAt: Date? = nil
    // 確定済み出場分数（交代/前半終了時点で加算）
    var firstHalfMinutes: Double = 0
    var secondHalfMinutes: Double = 0

    var totalMinutes: Double { firstHalfMinutes + secondHalfMinutes }

    /// 確定済みの出場分数で計算したレーティング（試合終了後・履歴表示用）
    var rating: Double {
        stats.calculateRating(for: position, mins: totalMinutes)
    }

    /// 現在進行中フェーズの経過分数を含む出場分数
    func playMinutes(now: Date, phase: MatchPhase) -> Double {
        var total = firstHalfMinutes + secondHalfMinutes
        if phase.isPlaying, let s = lastFieldEnterAt {
            total += max(0, now.timeIntervalSince(s) / 60.0)
        }
        return total
    }

    /// 試合中の進行込みレーティング（タイマー連動）
    func liveRating(now: Date, phase: MatchPhase) -> Double {
        stats.calculateRating(for: position, mins: playMinutes(now: now, phase: phase))
    }

    /// 現在進行中の前半分数（既存呼び出し互換）
    func currentFirstHalfMinutes(now: Date, phase: MatchPhase) -> Double {
        guard phase == .firstHalf, let s = lastFieldEnterAt else { return firstHalfMinutes }
        return firstHalfMinutes + max(0, now.timeIntervalSince(s) / 60.0)
    }
    func currentSecondHalfMinutes(now: Date, phase: MatchPhase) -> Double {
        guard phase == .secondHalf, let s = lastFieldEnterAt else { return secondHalfMinutes }
        return secondHalfMinutes + max(0, now.timeIntervalSince(s) / 60.0)
    }
}

// ── 試合フェーズ ──
enum MatchPhase: Int, Codable {
    case setup        = 0   // セットアップ（位置調整）
    case firstHalf    = 1   // 前半進行中
    case halfTime     = 2   // ハーフタイム（復習）
    case secondHalf   = 3   // 後半進行中
    case finished     = 4   // 試合終了

    var label: String {
        switch self {
        case .setup:      return "セットアップ"
        case .firstHalf:  return "前半"
        case .halfTime:   return "ハーフタイム"
        case .secondHalf: return "後半"
        case .finished:   return "試合終了"
        }
    }
    var isPlaying: Bool { self == .firstHalf || self == .secondHalf }
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

    // ── 試合進行 ──
    var phase: MatchPhase = .setup
    var firstHalfStart: Date? = nil
    var firstHalfEnd:   Date? = nil
    var secondHalfStart: Date? = nil
    var secondHalfEnd:   Date? = nil

    var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP"); return f.string(from: date)
    }

    /// 現在のフェーズの経過秒（再生中はリアルタイム、それ以外は確定値）
    func elapsedSeconds(now: Date) -> TimeInterval {
        switch phase {
        case .firstHalf:
            guard let s = firstHalfStart else { return 0 }
            return now.timeIntervalSince(s)
        case .halfTime:
            if let s = firstHalfStart, let e = firstHalfEnd { return e.timeIntervalSince(s) }
            return 0
        case .secondHalf:
            guard let s = secondHalfStart else { return 0 }
            return now.timeIntervalSince(s)
        case .finished:
            if let s = secondHalfStart, let e = secondHalfEnd { return e.timeIntervalSince(s) }
            return 0
        case .setup:
            return 0
        }
    }
}

// MM:SS フォーマット（出場時間/タイマー表示用）
func formatMMSS(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
// 分（小数）→ MM:SS フォーマット
func formatMinutes(_ minutes: Double) -> String {
    formatMMSS(minutes * 60.0)
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
