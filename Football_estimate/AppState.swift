import SwiftUI
import Combine

// ============================================================
// MARK: - APP STATE（アプリ全体の状態管理）
// ============================================================

class AppState: ObservableObject {
    @Published var matches: [Match] = []
    @Published var roster: [RosterPlayer] = []   // マスターロスター

    init() {
        // 起動時、ロスターが空なら時短用のサンプル15人を投入。
        // 不要になったらロスター管理画面から自由に削除できる。
        if roster.isEmpty {
            roster = AppState.sampleRoster()
        }
    }

    // ── サンプルロスター（FW4 / MF6 / DF5 = 15人） ──
    static func sampleRoster() -> [RosterPlayer] {
        [
            // ── FW（4人） ──
            RosterPlayer(name: "田中 翔",   position: .fw, height: "178", foot: .right),
            RosterPlayer(name: "山田 蓮",   position: .fw, height: "175", foot: .left),
            RosterPlayer(name: "鈴木 大輝", position: .fw, height: "182", foot: .right),
            RosterPlayer(name: "高橋 颯",   position: .fw, height: "173", foot: .both),
            // ── MF（6人） ──
            RosterPlayer(name: "佐藤 陸",   position: .mf, height: "172", foot: .right),
            RosterPlayer(name: "中村 海斗", position: .mf, height: "170", foot: .left),
            RosterPlayer(name: "伊藤 颯太", position: .mf, height: "174", foot: .right),
            RosterPlayer(name: "渡辺 悠真", position: .mf, height: "168", foot: .both),
            RosterPlayer(name: "小林 蒼",   position: .mf, height: "176", foot: .right),
            RosterPlayer(name: "加藤 樹",   position: .mf, height: "171", foot: .left),
            // ── DF（5人） ──
            RosterPlayer(name: "山本 健",   position: .df, height: "183", foot: .right),
            RosterPlayer(name: "吉田 大樹", position: .df, height: "180", foot: .right),
            RosterPlayer(name: "松本 涼",   position: .df, height: "178", foot: .left),
            RosterPlayer(name: "井上 拓海", position: .df, height: "185", foot: .right),
            RosterPlayer(name: "木村 隼人", position: .df, height: "177", foot: .both),
        ]
    }

    // ── Match管理 ──
    func addMatch(_ m: Match) { matches.insert(m, at: 0) }
    func updateMatch(_ m: Match) { if let i = matches.firstIndex(where:{$0.id==m.id}) { matches[i]=m } }
    func finishMatch(_ id: UUID) { if let i = matches.firstIndex(where:{$0.id==id}) { matches[i].isFinished=true } }

    // ── 選手交代（スタメンとベンチを入れ替え） ──
    // OUT した選手は wasSubstituted=true になり、その試合では再投入不可。
    // IN した選手は通常通り後で交代できる。
    func substitutePlayer(matchId: UUID, outId: UUID, inId: UUID) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }) else { return }
        if let oi = matches[mi].players.firstIndex(where: { $0.id == outId }) {
            matches[mi].players[oi].isStarter = false
            matches[mi].players[oi].wasSubstituted = true
        }
        if let ii = matches[mi].players.firstIndex(where: { $0.id == inId }) {
            matches[mi].players[ii].isStarter = true
        }
    }

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
