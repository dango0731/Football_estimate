import SwiftUI

// ============================================================
// MARK: - SEASON RANKING VIEW（通算ランキング画面）
// ============================================================

struct SeasonRankingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let stats = appState.allSeasonStats
        Group {
            if stats.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("試合を終了すると\n通算スタッツが表示されます")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        // トップ3バナー
                        if stats.count >= 1 {
                            podiumBanner(stats: stats)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }

                    Section("全選手ランキング") {
                        ForEach(Array(stats.enumerated()), id: \.element.rosterPlayer.id) { idx, s in
                            NavigationLink(value: NavRoute.seasonStats(s.rosterPlayer.id)) {
                                SeasonRankRow(rank: idx + 1, stats: s)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("通算ランキング")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - 表彰台バナー（上位3人）
    @ViewBuilder
    private func podiumBanner(stats: [PlayerSeasonStats]) -> some View {
        HStack(alignment: .bottom, spacing: 0) {
            // 2位
            if stats.count >= 2 {
                podiumCard(stats[1], rank: 2, height: 80)
            } else {
                Spacer()
            }
            // 1位
            podiumCard(stats[0], rank: 1, height: 110)
            // 3位
            if stats.count >= 3 {
                podiumCard(stats[2], rank: 3, height: 64)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func podiumCard(_ s: PlayerSeasonStats, rank: Int, height: CGFloat) -> some View {
        let medals = ["🥇", "🥈", "🥉"]
        let medal = medals[rank - 1]
        let colors: [Color] = [.yellow, Color(white: 0.75), .orange]
        let col = colors[rank - 1]

        VStack(spacing: 6) {
            Text(medal).font(.system(size: rank == 1 ? 28 : 22))
            ZStack {
                Circle()
                    .fill(s.rosterPlayer.position.color.opacity(0.2))
                    .frame(width: rank == 1 ? 56 : 46, height: rank == 1 ? 56 : 46)
                Image(systemName: s.rosterPlayer.position.icon)
                    .font(.system(size: rank == 1 ? 22 : 18, weight: .bold))
                    .foregroundColor(s.rosterPlayer.position.color)
            }
            Text(s.rosterPlayer.name)
                .font(.system(size: rank == 1 ? 13 : 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(String(format: "%.2f", s.avgRating))
                .font(.system(size: rank == 1 ? 20 : 16, weight: .black))
                .foregroundColor(ratingColor(s.avgRating))

            // 台座
            Rectangle()
                .fill(col.opacity(0.25))
                .frame(height: height)
                .overlay(
                    Rectangle()
                        .fill(col.opacity(0.5))
                        .frame(height: 3),
                    alignment: .top
                )
        }
        .frame(maxWidth: .infinity)
    }
}
