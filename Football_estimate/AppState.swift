import SwiftUI
import Combine

// ============================================================
// MARK: - APP STATE（アプリ全体の状態管理）
// ============================================================

class AppState: ObservableObject {
    // バインディング互換のため matches / roster を @Published で保持
    @Published var matches: [Match] = [] {
        didSet { guard !isLoading else { return }; syncToCurrentTeam(); saveTeams() }
    }
    @Published var roster: [RosterPlayer] = [] {
        didSet { guard !isLoading else { return }; syncToCurrentTeam(); saveTeams() }
    }

    @Published var teams: [Team] = []
    @Published var currentTeamId: UUID? = nil

    private var isLoading = false
    private let teamsKey = "saved_teams_v2"

    init() {
        isLoading = true
        loadTeams()
        isLoading = false

        if teams.isEmpty {
            let sample = Team(name: "〇〇高校サッカー部",
                              roster: AppState.sampleRoster())
            teams.append(sample)
            saveTeams()
        }
    }

    // MARK: - チーム選択
    func selectTeam(_ id: UUID) {
        guard let t = teams.first(where: { $0.id == id }) else { return }
        isLoading = true
        currentTeamId = id
        matches = t.matches
        roster  = t.roster
        isLoading = false
    }

    func deselectTeam() {
        isLoading = true
        currentTeamId = nil
        matches = []
        roster  = []
        isLoading = false
    }

    var currentTeam: Team? {
        guard let id = currentTeamId else { return nil }
        return teams.first(where: { $0.id == id })
    }

    // MARK: - チーム CRUD
    func addTeam(_ t: Team) {
        teams.append(t)
        saveTeams()
    }

    func updateTeamName(id: UUID, name: String) {
        if let i = teams.firstIndex(where: { $0.id == id }) {
            teams[i].name = name
            saveTeams()
        }
    }

    func deleteTeam(id: UUID) {
        if currentTeamId == id { deselectTeam() }
        teams.removeAll { $0.id == id }
        saveTeams()
    }

    // MARK: - 永続化
    private func syncToCurrentTeam() {
        guard let id = currentTeamId,
              let i = teams.firstIndex(where: { $0.id == id }) else { return }
        teams[i].matches = matches
        teams[i].roster  = roster
    }

    private func saveTeams() {
        if let data = try? JSONEncoder().encode(teams) {
            UserDefaults.standard.set(data, forKey: teamsKey)
        }
    }

    private func loadTeams() {
        // v2 キーから読み込み
        if let data = UserDefaults.standard.data(forKey: teamsKey),
           let decoded = try? JSONDecoder().decode([Team].self, from: data) {
            teams = decoded
            return
        }
        // 旧キーからマイグレーション
        let oldMatchesKey = "saved_matches"
        let oldRosterKey  = "saved_roster"
        var migratedMatches: [Match] = []
        var migratedRoster: [RosterPlayer] = []
        if let data = UserDefaults.standard.data(forKey: oldMatchesKey),
           let decoded = try? JSONDecoder().decode([Match].self, from: data) {
            migratedMatches = decoded
        }
        if let data = UserDefaults.standard.data(forKey: oldRosterKey),
           let decoded = try? JSONDecoder().decode([RosterPlayer].self, from: data) {
            migratedRoster = decoded
        }
        if !migratedMatches.isEmpty || !migratedRoster.isEmpty {
            let migrated = Team(name: "マイチーム",
                                matches: migratedMatches,
                                roster: migratedRoster)
            teams = [migrated]
            saveTeams()
            UserDefaults.standard.removeObject(forKey: oldMatchesKey)
            UserDefaults.standard.removeObject(forKey: oldRosterKey)
        }
    }

    // MARK: - スタッツ修正（詳細画面の編集モード用）
    func updatePlayerStat(matchId: UUID, playerId: UUID,
                          _ key: WritableKeyPath<PlayerStats, Int>, delta: Int) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }),
              let pi = matches[mi].players.firstIndex(where: { $0.id == playerId }) else { return }
        let current = matches[mi].players[pi].stats[keyPath: key]
        matches[mi].players[pi].stats[keyPath: key] = max(0, current + delta)
    }
    func updatePlayerCards(matchId: UUID, playerId: UUID, yellowDelta: Int, redDelta: Int) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }),
              let pi = matches[mi].players.firstIndex(where: { $0.id == playerId }) else { return }
        matches[mi].players[pi].stats.yellowCards =
            max(0, matches[mi].players[pi].stats.yellowCards + yellowDelta)
        matches[mi].players[pi].stats.redCards =
            max(0, matches[mi].players[pi].stats.redCards + redDelta)
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

    func updateOpponentScore(matchId: UUID, score: Int) {
        if let i = matches.firstIndex(where: { $0.id == matchId }) {
            matches[i].opponentScore = max(0, score)
        }
    }

    // ── Match管理 ──
    func addMatch(_ m: Match) { matches.insert(m, at: 0) }
    func updateMatch(_ m: Match) { if let i = matches.firstIndex(where:{$0.id==m.id}) { matches[i]=m } }
    func finishMatch(_ id: UUID) { if let i = matches.firstIndex(where:{$0.id==id}) { matches[i].isFinished=true } }

    // ── 試合フェーズ遷移 ──
    func startFirstHalf(matchId: UUID) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }) else { return }
        let now = Date()
        matches[mi].phase = .firstHalf
        matches[mi].firstHalfStart = now
        for i in matches[mi].players.indices where matches[mi].players[i].isStarter {
            matches[mi].players[i].lastFieldEnterAt = now
        }
    }

    func endFirstHalf(matchId: UUID) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }) else { return }
        let now = Date()
        matches[mi].firstHalfEnd = now
        for i in matches[mi].players.indices {
            if let s = matches[mi].players[i].lastFieldEnterAt {
                matches[mi].players[i].firstHalfMinutes += max(0, now.timeIntervalSince(s) / 60.0)
                matches[mi].players[i].lastFieldEnterAt = nil
            }
        }
        matches[mi].phase = .halfTime
    }

    func startSecondHalf(matchId: UUID) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }) else { return }
        let now = Date()
        matches[mi].phase = .secondHalf
        matches[mi].secondHalfStart = now
        for i in matches[mi].players.indices where matches[mi].players[i].isStarter {
            matches[mi].players[i].lastFieldEnterAt = now
        }
    }

    func endSecondHalf(matchId: UUID) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }) else { return }
        let now = Date()
        matches[mi].secondHalfEnd = now
        for i in matches[mi].players.indices {
            if let s = matches[mi].players[i].lastFieldEnterAt {
                matches[mi].players[i].secondHalfMinutes += max(0, now.timeIntervalSince(s) / 60.0)
                matches[mi].players[i].lastFieldEnterAt = nil
            }
        }
        matches[mi].phase = .finished
        matches[mi].isFinished = true
    }

    // ── 選手交代 ──
    func substitutePlayer(matchId: UUID, outId: UUID, inId: UUID) {
        guard let mi = matches.firstIndex(where: { $0.id == matchId }) else { return }
        let now = Date()
        let phase = matches[mi].phase

        if let oi = matches[mi].players.firstIndex(where: { $0.id == outId }) {
            if let s = matches[mi].players[oi].lastFieldEnterAt {
                let mins = max(0, now.timeIntervalSince(s) / 60.0)
                if phase == .firstHalf {
                    matches[mi].players[oi].firstHalfMinutes += mins
                } else if phase == .secondHalf {
                    matches[mi].players[oi].secondHalfMinutes += mins
                }
                matches[mi].players[oi].lastFieldEnterAt = nil
            }
            matches[mi].players[oi].isStarter = false
            matches[mi].players[oi].wasSubstituted = true
        }

        if let ii = matches[mi].players.firstIndex(where: { $0.id == inId }) {
            matches[mi].players[ii].isStarter = true
            if phase.isPlaying {
                matches[mi].players[ii].lastFieldEnterAt = now
            }
        }
    }

    // MARK: - 通算スタッツ（終了試合を全集計）
    func seasonStats(for rosterId: UUID) -> PlayerSeasonStats? {
        guard let rp = roster.first(where: { $0.id == rosterId }) else { return nil }
        let entries: [(Date, String, Player)] = matches
            .filter { $0.isFinished }
            .compactMap { m in
                guard let p = m.players.first(where: { $0.rosterId == rosterId }),
                      p.totalMinutes > 0 else { return nil }
                return (m.date, m.opponent, p)
            }
            .sorted { $0.0 < $1.0 }
        guard !entries.isEmpty else { return nil }

        var totals = PlayerStats()
        var totalMinutes: Double = 0
        let ratings = entries.enumerated().map { i, e -> RatingEntry in
            totals.add(e.2.stats)
            totalMinutes += e.2.totalMinutes
            return RatingEntry(index: i + 1, opponent: e.1, date: e.0, rating: e.2.rating)
        }
        let avg = ratings.map(\.rating).reduce(0, +) / Double(ratings.count)
        return PlayerSeasonStats(rosterPlayer: rp, matchCount: entries.count,
                                 totalMinutes: totalMinutes, avgRating: avg,
                                 ratings: ratings, totals: totals)
    }

    var allSeasonStats: [PlayerSeasonStats] {
        roster.compactMap { seasonStats(for: $0.id) }
              .sorted { $0.avgRating > $1.avgRating }
    }

    // ── Roster管理 ──
    func addRosterPlayer(_ p: RosterPlayer) { roster.append(p) }
    func updateRosterPlayer(_ p: RosterPlayer) {
        if let i = roster.firstIndex(where: { $0.id == p.id }) { roster[i] = p }
    }
    func deleteRosterPlayer(id: UUID) {
        roster.removeAll { $0.id == id }
    }
    var sortedRoster: [RosterPlayer] {
        roster.sorted { a, b in
            if a.position.rawValue != b.position.rawValue { return a.position.rawValue < b.position.rawValue }
            return a.name < b.name
        }
    }
}
