import SwiftUI
import Charts

// ============================================================
// MARK: - SEASON STATS VIEW（選手通算スタッツ）
// ============================================================

struct SeasonStatsView: View {
    let rosterId: UUID
    @EnvironmentObject var appState: AppState

    private var season: PlayerSeasonStats? {
        appState.seasonStats(for: rosterId)
    }

    var body: some View {
        Group {
            if let s = season {
                content(s)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 48)).foregroundColor(.secondary.opacity(0.3))
                    Text("終了した試合がまだありません")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(season.map { "\($0.rosterPlayer.name) 通算" } ?? "通算スタッツ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - メインコンテンツ
    @ViewBuilder
    private func content(_ s: PlayerSeasonStats) -> some View {
        List {
            // ── サマリーヘッダー ──
            Section {
                VStack(spacing: 14) {
                    HStack(spacing: 20) {
                        summaryBadge("試合数", value: "\(s.matchCount)", unit: "試合", color: .blue)
                        Divider().frame(height: 44)
                        summaryBadge("出場時間", value: String(format: "%.0f", s.totalMinutes), unit: "分", color: .teal)
                        Divider().frame(height: 44)
                        summaryBadge("平均評価", value: String(format: "%.2f", s.avgRating), unit: ratingLabel(s.avgRating), color: ratingColor(s.avgRating))
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 16) {
                        statBadge("G", value: s.totals.goals, color: .red)
                        statBadge("A", value: s.totals.assists, color: .yellow)
                        statBadge("Shot", value: s.totals.spg, color: .orange)
                        statBadge("Tackle", value: s.totals.tackles, color: .indigo)
                        statBadge("Inter", value: s.totals.inter, color: .blue)
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(.secondarySystemBackground))
            }

            // ── レーティング推移チャート ──
            if s.ratings.count >= 2 {
                Section("レーティング推移") {
                    ratingChart(s)
                        .frame(height: 200)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
            }

            // ── ポジション別スタッツ比較 ──
            Section("ポジション内比較（チーム平均との差）") {
                positionCompareChart(s)
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            // ── 全スタッツ詳細 ──
            Section("通算スタッツ詳細") {
                totalStatsGrid(s.totals)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            }

            // ── 試合別ログ ──
            Section("試合別レーティング") {
                ForEach(s.ratings.reversed()) { entry in
                    matchLogRow(entry)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - レーティング推移（折れ線＋バー）
    @ViewBuilder
    private func ratingChart(_ s: PlayerSeasonStats) -> some View {
        Chart(s.ratings) { entry in
            BarMark(
                x: .value("試合", entry.index),
                y: .value("評価", entry.rating)
            )
            .foregroundStyle(ratingColor(entry.rating).opacity(0.25))
            .cornerRadius(4)

            LineMark(
                x: .value("試合", entry.index),
                y: .value("評価", entry.rating)
            )
            .foregroundStyle(ratingColor(s.avgRating))
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("試合", entry.index),
                y: .value("評価", entry.rating)
            )
            .foregroundStyle(ratingColor(entry.rating))
            .annotation(position: .top, spacing: 4) {
                Text(String(format: "%.1f", entry.rating))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(ratingColor(entry.rating))
            }

            RuleMark(y: .value("平均", s.avgRating))
                .foregroundStyle(.secondary.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .annotation(position: .trailing, alignment: .leading) {
                    Text(String(format: "avg %.2f", s.avgRating))
                        .font(.caption2).foregroundColor(.secondary)
                }
        }
        .chartXAxis {
            AxisMarks(values: s.ratings.map(\.index)) { val in
                AxisValueLabel {
                    if let idx = val.as(Int.self),
                       let entry = s.ratings.first(where: { $0.index == idx }) {
                        Text("vs\n\(entry.opponent)")
                            .font(.system(size: 8))
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .chartYScale(domain: {
            let lo = max(1.0, (s.ratings.map(\.rating).min() ?? 4.0) - 0.5)
            let hi = min(10.0, (s.ratings.map(\.rating).max() ?? 8.0) + 0.5)
            return lo...hi
        }())
        .chartYAxisLabel("レーティング")
    }

    // MARK: - ポジション内比較（棒グラフ）
    private func makeCompareData(_ s: PlayerSeasonStats) -> [CompareBarEntry] {
        let pos = s.rosterPlayer.position
        let posPlayers = appState.allSeasonStats.filter { $0.rosterPlayer.position == pos }
        let posAvgRating = posPlayers.isEmpty ? 0.0 :
            posPlayers.map(\.avgRating).reduce(0, +) / Double(posPlayers.count)
        let mins = max(1.0, s.totalMinutes)
        let defs: [(String, Double, Double)] = [
            ("評価",     s.avgRating,                             posAvgRating),
            ("G/90",    Double(s.totals.goals)   / mins * 90,   posAvgGoals(pos: pos, key: \.goals)),
            ("A/90",    Double(s.totals.assists) / mins * 90,   posAvgGoals(pos: pos, key: \.assists)),
            ("Shot/90", Double(s.totals.spg)     / mins * 90,   posAvgGoals(pos: pos, key: \.spg)),
        ]
        return defs.flatMap { label, myVal, avgVal in [
            CompareBarEntry(label: label, value: myVal,  kind: "選手"),
            CompareBarEntry(label: label, value: avgVal, kind: "ポジ平均"),
        ]}
    }

    @ViewBuilder
    private func positionCompareChart(_ s: PlayerSeasonStats) -> some View {
        let pos = s.rosterPlayer.position
        let barData = makeCompareData(s)
        Chart(barData) { item in
            BarMark(
                x: .value("スタッツ", item.label),
                y: .value("値", item.value)
            )
            .foregroundStyle(by: .value("種別", item.kind))
            .position(by: .value("種別", item.kind))
            .cornerRadius(4)
        }
        .chartForegroundStyleScale([
            "選手": pos.color,
            "ポジ平均": Color.secondary.opacity(0.4),
        ])
        .chartLegend(position: .bottom, alignment: .center)
    }

    private func posAvgGoals(pos: Position, key: KeyPath<PlayerStats, Int>) -> Double {
        let players = appState.allSeasonStats.filter { $0.rosterPlayer.position == pos }
        guard !players.isEmpty else { return 0 }
        let total = players.reduce(0.0) { acc, s in
            let mins = max(1, s.totalMinutes)
            return acc + Double(s.totals[keyPath: key]) / mins * 90
        }
        return total / Double(players.count)
    }

    // MARK: - 通算スタッツグリッド
    @ViewBuilder
    private func totalStatsGrid(_ t: PlayerStats) -> some View {
        let rows: [[(String, Int, Color)]] = [
            [("⚽️ Goal", t.goals, .red), ("Assist", t.assists, .yellow), ("Shot", t.spg, .orange)],
            [("Drb↑", t.drbOff, .green), ("KeyP", t.keyP, .cyan), ("Pass", t.avgP, .blue)],
            [("Tackle", t.tackles, .indigo), ("Inter", t.inter, .blue), ("Block", t.blocks, .cyan)],
            [("Clear", t.clear, .yellow), ("LongB", t.longB, .orange), ("Drb↓", t.drbDef, .red)],
            [("Disp", t.disp, .red), ("MisTch", t.unsTch, .orange), ("Fouled", t.fouled, .green)],
            [("Foul", t.fouls, .red), ("YC", t.yellowCards, .yellow), ("RC", t.redCards, .red)],
        ]
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { ri in
                HStack(spacing: 8) {
                    ForEach(rows[ri].indices, id: \.self) { ci in
                        let cell = rows[ri][ci]
                        HStack(spacing: 4) {
                            Text(cell.0).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                            Spacer(minLength: 2)
                            Text("\(cell.1)")
                                .font(.system(.callout, design: .rounded).weight(.bold))
                                .foregroundColor(cell.1 > 0 ? cell.2 : .secondary.opacity(0.5))
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(.tertiarySystemBackground)))
                    }
                }
            }
        }
    }

    // MARK: - 試合別ログ行
    @ViewBuilder
    private func matchLogRow(_ entry: RatingEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("vs \(entry.opponent)").font(.subheadline.weight(.semibold))
                Text(entry.date, style: .date).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(String(format: "%.2f", entry.rating))
                .font(.headline.weight(.black))
                .foregroundColor(ratingColor(entry.rating))
        }
        .padding(.vertical, 2)
    }

    // MARK: - パーツ
    @ViewBuilder
    private func summaryBadge(_ title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.title2.weight(.black)).foregroundColor(color)
            Text(unit).font(.caption2.weight(.semibold)).foregroundColor(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statBadge(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.subheadline.weight(.black)).foregroundColor(color)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(.secondary)
        }
        .frame(minWidth: 32)
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.10)))
    }
}

private struct CompareBarEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let kind: String
}
