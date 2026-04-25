import SwiftUI

// ============================================================
// MARK: - MATCH STATS DETAIL VIEW（試合終了後の選手別詳細スタッツ）
// ============================================================

struct MatchStatsDetailView: View {
    let match: Match

    // スタメン優先 → レーティング降順
    private var sortedPlayers: [Player] {
        match.players.sorted { a, b in
            if a.isStarter != b.isStarter { return a.isStarter && !b.isStarter }
            return a.rating > b.rating
        }
    }

    var body: some View {
        List {
            ForEach(sortedPlayers) { player in
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        // ── ヘッダー行 ──
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(player.position.color.opacity(0.18)).frame(width: 40, height: 40)
                                Image(systemName: player.position.icon)
                                    .foregroundColor(player.position.color)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name).font(.headline)
                                HStack(spacing: 6) {
                                    Text(player.position.label)
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(player.position.color.opacity(0.15)))
                                        .foregroundColor(player.position.color)
                                    Text(player.isStarter ? "スタメン" : "ベンチ")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(player.isStarter ? .green : .secondary)
                                    if !player.height.isEmpty {
                                        Text("\(player.height)cm").font(.caption2).foregroundColor(.secondary)
                                    }
                                    Text(player.foot.rawValue).font(.caption2).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(String(format:"%.2f", player.rating))
                                    .font(.title2.weight(.black))
                                    .foregroundColor(ratingColor(player.rating))
                                Text(ratingLabel(player.rating))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(ratingColor(player.rating).opacity(0.8))
                            }
                        }

                        Divider()

                        // ── スタッツグリッド ──
                        statsGrid(player.stats)

                        // ── カード（あれば表示） ──
                        if player.stats.yellowCards > 0 || player.stats.redCards > 0 {
                            HStack(spacing: 16) {
                                if player.stats.yellowCards > 0 {
                                    HStack(spacing: 4) {
                                        Rectangle().fill(Color.yellow).frame(width: 12, height: 16).cornerRadius(2)
                                        Text("× \(player.stats.yellowCards)").font(.caption.weight(.bold))
                                    }
                                }
                                if player.stats.redCards > 0 {
                                    HStack(spacing: 4) {
                                        Rectangle().fill(Color.red).frame(width: 12, height: 16).cornerRadius(2)
                                        Text("× \(player.stats.redCards)").font(.caption.weight(.bold))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("詳細スタッツ")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ── スタッツの3列グリッド ──
    @ViewBuilder
    private func statsGrid(_ s: PlayerStats) -> some View {
        VStack(spacing: 6) {
            statRow([
                StatCell(label: "⚽️ Goal",  value: s.goals,   tint: .red),
                StatCell(label: "Assist",   value: s.assists, tint: .yellow),
                StatCell(label: "Shot",     value: s.spg,     tint: .orange),
            ])
            statRow([
                StatCell(label: "Drb↑",    value: s.drbOff,  tint: .green),
                StatCell(label: "KeyP",     value: s.keyP,    tint: .cyan),
                StatCell(label: "Pass",     value: s.avgP,    tint: .blue),
            ])
            statRow([
                StatCell(label: "Tackle",   value: s.tackles, tint: .indigo),
                StatCell(label: "Inter",    value: s.inter,   tint: .blue),
                StatCell(label: "Block",    value: s.blocks,  tint: .cyan),
            ])
            statRow([
                StatCell(label: "Clear",    value: s.clear,   tint: .yellow),
                StatCell(label: "LongB",    value: s.longB,   tint: .orange),
                StatCell(label: "Drb↓",    value: s.drbDef,  tint: .red),
            ])
            statRow([
                StatCell(label: "Disp",     value: s.disp,    tint: .red),
                StatCell(label: "MisTch",   value: s.unsTch,  tint: .orange),
                nil,
            ])
        }
    }

    @ViewBuilder
    private func statRow(_ cells: [StatCell?]) -> some View {
        HStack(spacing: 8) {
            ForEach(cells.indices, id: \.self) { i in
                if let cell = cells[i] {
                    HStack(spacing: 4) {
                        Text(cell.label)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("\(cell.value)")
                            .font(.system(.callout, design: .rounded).weight(.bold))
                            .foregroundColor(cell.value > 0 ? cell.tint : .secondary.opacity(0.6))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// 内部用：スタッツ1セルのデータ
private struct StatCell {
    let label: String
    let value: Int
    let tint: Color
}
