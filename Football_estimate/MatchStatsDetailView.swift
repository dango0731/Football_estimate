import SwiftUI

// ============================================================
// MARK: - MATCH STATS DETAIL VIEW（試合終了後の選手別詳細スタッツ）
// ============================================================

struct MatchStatsDetailView: View {
    let matchId: UUID
    @EnvironmentObject var appState: AppState
    @State private var isEditing = false

    private var match: Match {
        appState.matches.first(where: { $0.id == matchId }) ?? Match(opponent: "")
    }

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
                                    Text(player.isStarter ? "出場中" : (player.wasSubstituted ? "途中OUT" : "ベンチ"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(player.isStarter ? .green : (player.wasSubstituted ? .orange : .secondary))
                                    if !player.height.isEmpty {
                                        Text("\(player.height)cm").font(.caption2).foregroundColor(.secondary)
                                    }
                                    Text(player.foot.rawValue).font(.caption2).foregroundColor(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Image(systemName:"timer").font(.caption2).foregroundColor(.secondary)
                                    Text("計\(formatMinutes(player.totalMinutes))")
                                        .font(.caption2.weight(.semibold).monospacedDigit())
                                        .foregroundColor(.secondary)
                                    Text("(前\(formatMinutes(player.firstHalfMinutes)) / 後\(formatMinutes(player.secondHalfMinutes)))")
                                        .font(.system(size: 10).monospacedDigit())
                                        .foregroundColor(.secondary.opacity(0.75))
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
                        statsGrid(player.stats, playerId: player.id)

                        // ── カード ──
                        cardsSection(player)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("詳細スタッツ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "完了" : "編集") {
                    withAnimation { isEditing.toggle() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isEditing ? .green : .blue)
            }
        }
    }

    // MARK: - スタッツグリッド
    @ViewBuilder
    private func statsGrid(_ s: PlayerStats, playerId: UUID) -> some View {
        VStack(spacing: 6) {
            statRow3(playerId: playerId,
                c1: ("⚽️ Goal", s.goals, Color.red,     \.goals),
                c2: ("Assist",   s.assists, Color.yellow, \.assists),
                c3: ("Shot",     s.spg,     Color.orange, \.spg))
            statRow3(playerId: playerId,
                c1: ("Drb↑",   s.drbOff, Color.green,  \.drbOff),
                c2: ("KeyP",    s.keyP,   Color.cyan,   \.keyP),
                c3: ("Pass",    s.avgP,   Color.blue,   \.avgP))
            statRow3(playerId: playerId,
                c1: ("Tackle",  s.tackles, Color.indigo, \.tackles),
                c2: ("Inter",   s.inter,   Color.blue,   \.inter),
                c3: ("Block",   s.blocks,  Color.cyan,   \.blocks))
            statRow3(playerId: playerId,
                c1: ("Clear",   s.clear,   Color.yellow, \.clear),
                c2: ("LongB",   s.longB,   Color.orange, \.longB),
                c3: ("Drb↓",   s.drbDef,  Color.red,    \.drbDef))
            statRow3(playerId: playerId,
                c1: ("Disp",    s.disp,    Color.red,    \.disp),
                c2: ("MisTch",  s.unsTch,  Color.orange, \.unsTch),
                c3: ("Fouled",  s.fouled,  Color.green,  \.fouled))
            HStack(spacing: 8) {
                statCell("Foul", value: s.fouls, tint: .red, playerId: playerId, key: \.fouls)
                Color.clear.frame(maxWidth: .infinity)
                Color.clear.frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func statRow3(
        playerId: UUID,
        c1: (String, Int, Color, WritableKeyPath<PlayerStats, Int>),
        c2: (String, Int, Color, WritableKeyPath<PlayerStats, Int>),
        c3: (String, Int, Color, WritableKeyPath<PlayerStats, Int>)
    ) -> some View {
        HStack(spacing: 8) {
            statCell(c1.0, value: c1.1, tint: c1.2, playerId: playerId, key: c1.3)
            statCell(c2.0, value: c2.1, tint: c2.2, playerId: playerId, key: c2.3)
            statCell(c3.0, value: c3.1, tint: c3.2, playerId: playerId, key: c3.3)
        }
    }

    @ViewBuilder
    private func statCell(
        _ label: String, value: Int, tint: Color,
        playerId: UUID, key: WritableKeyPath<PlayerStats, Int>
    ) -> some View {
        if isEditing {
            VStack(spacing: 3) {
                Text(label).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                HStack(spacing: 6) {
                    Button {
                        appState.updatePlayerStat(matchId: matchId, playerId: playerId, key, delta: -1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(value > 0 ? .secondary : .secondary.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .disabled(value == 0)

                    Text("\(value)")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundColor(value > 0 ? tint : .secondary.opacity(0.5))
                        .frame(minWidth: 22)

                    Button {
                        appState.updatePlayerStat(matchId: matchId, playerId: playerId, key, delta: +1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(tint.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1))
        } else {
            HStack(spacing: 4) {
                Text(label).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                Spacer(minLength: 2)
                Text("\(value)")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .foregroundColor(value > 0 ? tint : .secondary.opacity(0.6))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(.tertiarySystemBackground)))
        }
    }

    // MARK: - カードセクション
    @ViewBuilder
    private func cardsSection(_ player: Player) -> some View {
        let s = player.stats
        if s.yellowCards > 0 || s.redCards > 0 || isEditing {
            HStack(spacing: 20) {
                cardControl(
                    color: .yellow, count: s.yellowCards,
                    playerId: player.id,
                    onMinus: { appState.updatePlayerCards(matchId: matchId, playerId: player.id, yellowDelta: -1, redDelta: 0) },
                    onPlus:  { appState.updatePlayerCards(matchId: matchId, playerId: player.id, yellowDelta: +1, redDelta: 0) }
                )
                cardControl(
                    color: .red, count: s.redCards,
                    playerId: player.id,
                    onMinus: { appState.updatePlayerCards(matchId: matchId, playerId: player.id, yellowDelta: 0, redDelta: -1) },
                    onPlus:  { appState.updatePlayerCards(matchId: matchId, playerId: player.id, yellowDelta: 0, redDelta: +1) }
                )
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func cardControl(
        color: Color, count: Int, playerId: UUID,
        onMinus: @escaping () -> Void, onPlus: @escaping () -> Void
    ) -> some View {
        HStack(spacing: isEditing ? 6 : 4) {
            if isEditing {
                Button(action: onMinus) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(count > 0 ? .secondary : .secondary.opacity(0.25))
                }
                .buttonStyle(.plain).disabled(count == 0)
            }
            Rectangle().fill(color).frame(width: 12, height: 16).cornerRadius(2)
            Text("× \(count)").font(.caption.weight(.bold))
            if isEditing {
                Button(action: onPlus) {
                    Image(systemName: "plus.circle.fill").foregroundColor(color.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
