import SwiftUI
import Combine

// ============================================================
// MARK: - APP STATE（アプリ全体の状態管理）
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
