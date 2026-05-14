import SwiftUI

// ============================================================
// MARK: - HOME VIEW（ホーム画面：ロスター＋試合一覧）
// ============================================================

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showNewMatch = false
    @State private var navPath = NavigationPath()
    @State private var editingRosterPlayer: RosterPlayer? = nil
    @State private var showAddRosterSheet: Bool = false
    @State private var showFormula = false

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    // ── ヘッダー ──
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.currentTeam?.name ?? "SoccerRating")
                                .font(.title2.weight(.black))
                                .lineLimit(1)
                            Text("試合スタッツ管理").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        // チーム変更
                        Button {
                            appState.deselectTeam()
                        } label: {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.blue)
                                .frame(width: 40, height: 40)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Circle())
                        }
                        // 評価式
                        Button { showFormula = true } label: {
                            Image(systemName: "function")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.purple)
                                .frame(width: 40, height: 40)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(Circle())
                        }
                        // 新規試合
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
                            rosterSection
                            matchListSection
                            seasonRankingCard
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
                    MatchResultView(matchId: id)
                        .environmentObject(appState)
                case .rosterManagement:
                    RosterManagementView()
                        .environmentObject(appState)
                case .seasonStats(let rosterId):
                    SeasonStatsView(rosterId: rosterId)
                        .environmentObject(appState)
                case .seasonRanking:
                    SeasonRankingView()
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
            .sheet(isPresented: $showFormula) {
                FormulaView()
            }
        }
    }

    // ── ロスターセクション ──
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(appState.sortedRoster) { rp in
                            RosterChip(player: rp)
                                .onTapGesture { editingRosterPlayer = rp }
                        }
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

    // ── 通算ランキングカード（タップで画面遷移） ──
    private var seasonRankingCard: some View {
        let stats = appState.allSeasonStats
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.bold)).foregroundColor(.purple)
                Text("通算ランキング").font(.headline.weight(.bold))
                Text("\(stats.count)名")
                    .font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                Spacer()
                if !stats.isEmpty {
                    Button {
                        navPath.append(NavRoute.seasonRanking)
                    } label: {
                        HStack(spacing: 3) {
                            Text("すべて見る").font(.caption.weight(.bold))
                            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                        }
                        .foregroundColor(.purple)
                    }
                }
            }
            .padding(.horizontal, 20)

            if stats.isEmpty {
                Text("試合を終了すると通算スタッツが表示されます")
                    .font(.caption).foregroundColor(.secondary)
                    .padding(.horizontal, 20).padding(.vertical, 12)
            } else {
                // 上位3名をプレビュー表示
                LazyVStack(spacing: 8) {
                    ForEach(Array(stats.prefix(3).enumerated()), id: \.element.rosterPlayer.id) { idx, s in
                        Button {
                            navPath.append(NavRoute.seasonStats(s.rosterPlayer.id))
                        } label: {
                            SeasonRankRow(rank: idx + 1, stats: s)
                        }
                        .buttonStyle(.plain)
                    }
                    if stats.count > 3 {
                        Button {
                            navPath.append(NavRoute.seasonRanking)
                        } label: {
                            HStack {
                                Spacer()
                                Text("他 \(stats.count - 3) 名を見る")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.purple)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.purple)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.purple.opacity(0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// ── 通算ランキング行 ──
struct SeasonRankRow: View {
    let rank: Int
    let stats: PlayerSeasonStats
    var body: some View {
        HStack(spacing: 12) {
            Text(rank <= 3 ? ["🥇","🥈","🥉"][rank-1] : "\(rank)")
                .font(.subheadline.weight(.bold)).frame(width: 28)
            ZStack {
                Circle().fill(stats.rosterPlayer.position.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: stats.rosterPlayer.position.icon)
                    .foregroundColor(stats.rosterPlayer.position.color)
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(stats.rosterPlayer.name).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(stats.rosterPlayer.position.label)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(stats.rosterPlayer.position.color.opacity(0.15)))
                        .foregroundColor(stats.rosterPlayer.position.color)
                    Text("\(stats.matchCount)試合")
                        .font(.caption2).foregroundColor(.secondary)
                    Text(String(format: "%.0f分", stats.totalMinutes))
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.2f", stats.avgRating))
                    .font(.title3.weight(.black))
                    .foregroundColor(ratingColor(stats.avgRating))
                Text("平均").font(.caption2).foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
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
