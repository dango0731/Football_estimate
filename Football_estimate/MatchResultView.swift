import SwiftUI

// ============================================================
// MARK: - MATCH RESULT VIEW（試合結果画面）
// ============================================================

struct MatchResultView: View {
    let matchId: UUID
    @EnvironmentObject var appState: AppState

    private var match: Match {
        appState.matches.first(where: { $0.id == matchId }) ?? Match(opponent: "")
    }

    var sortedPlayers: [Player] {
        match.players
            .filter { $0.isStarter || $0.totalMinutes > 0 }
            .sorted { $0.rating > $1.rating }
    }
    var avgRating: Double {
        guard !sortedPlayers.isEmpty else { return 0 }
        return sortedPlayers.reduce(0.0){$0+$1.rating}/Double(sortedPlayers.count)
    }
    private var firstHalfDuration: String {
        guard let s = match.firstHalfStart, let e = match.firstHalfEnd else { return "—" }
        return formatMMSS(e.timeIntervalSince(s))
    }
    private var secondHalfDuration: String {
        guard let s = match.secondHalfStart, let e = match.secondHalfEnd else { return "—" }
        return formatMMSS(e.timeIntervalSince(s))
    }

    var body: some View {
        List {
            // ── スコアセクション ──
            Section {
                scoreInputRow
                    .listRowBackground(Color(.secondarySystemBackground))
            }

            Section {
                VStack(spacing:10) {
                    Text("チーム平均レーティング").font(.subheadline).foregroundColor(.secondary)
                    Text(String(format:"%.2f",avgRating))
                        .font(.system(size:64,weight:.black,design:.rounded)).foregroundColor(ratingColor(avgRating))
                    Text(ratingLabel(avgRating)).font(.subheadline.weight(.semibold)).foregroundColor(ratingColor(avgRating).opacity(0.8))

                    HStack(spacing:14) {
                        VStack(spacing:2) {
                            Text("前半").font(.caption2).foregroundColor(.secondary)
                            Text(firstHalfDuration).font(.subheadline.weight(.heavy).monospacedDigit())
                        }
                        Divider().frame(height: 28)
                        VStack(spacing:2) {
                            Text("後半").font(.caption2).foregroundColor(.secondary)
                            Text(secondHalfDuration).font(.subheadline.weight(.heavy).monospacedDigit())
                        }
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth:.infinity).padding(.vertical,16).listRowBackground(Color(.secondarySystemBackground))
            }
            Section("選手ランキング") {
                ForEach(Array(sortedPlayers.enumerated()),id:\.element.id) { idx, player in
                    HStack(spacing:14) {
                        Text(idx<3 ? ["🥇","🥈","🥉"][idx] : "\(idx+1)").font(.title3.weight(.bold)).frame(width:36)
                        ZStack {
                            Circle().fill(player.position.color.opacity(0.15)).frame(width:40,height:40)
                            Image(systemName:player.position.icon).foregroundColor(player.position.color).font(.system(size:16,weight:.semibold))
                        }
                        VStack(alignment:.leading,spacing:2) {
                            Text(player.name).font(.headline)
                            HStack(spacing:6) {
                                Text(player.position.fullLabel).font(.caption).foregroundColor(.secondary)
                                if !player.height.isEmpty { Text("\(player.height)cm").font(.caption).foregroundColor(.secondary) }
                                Text(player.foot.rawValue).font(.caption).foregroundColor(.secondary)
                            }
                            HStack(spacing:6) {
                                Image(systemName:"timer").font(.caption2).foregroundColor(.secondary)
                                Text("\(formatMinutes(player.totalMinutes))").font(.caption.monospacedDigit()).foregroundColor(.secondary)
                                Text("(前\(formatMinutes(player.firstHalfMinutes)) / 後\(formatMinutes(player.secondHalfMinutes)))")
                                    .font(.caption2.monospacedDigit()).foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                        Spacer()
                        Text(String(format:"%.2f",player.rating)).font(.title2.weight(.black)).foregroundColor(ratingColor(player.rating))
                    }.padding(.vertical,4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("vs \(match.opponent) 結果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ShareLink(
                    item: generateCSV(),
                    subject: Text("スタッツデータ"),
                    message: Text("vs \(match.opponent) のスタッツデータです")
                ) {
                    Label("書き出し", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                }
                NavigationLink {
                    MatchStatsDetailView(matchId: matchId)
                } label: {
                    Label("詳細スタッツ", systemImage: "list.bullet.rectangle.portrait")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    // MARK: - スコア入力行
    @ViewBuilder
    private var scoreInputRow: some View {
        let our = match.ourScore
        let opp = match.opponentScore
        let resultColor: Color = {
            guard let o = opp else { return .secondary }
            return our > o ? .green : our < o ? .red : Color(red: 0.9, green: 0.75, blue: 0)
        }()
        let resultText: String = {
            guard let o = opp else { return "未入力" }
            return our > o ? "WIN 🎉" : our < o ? "LOSE" : "DRAW"
        }()

        VStack(spacing: 12) {
            // 勝敗ラベル
            Text(resultText)
                .font(.caption.weight(.bold))
                .foregroundColor(resultColor)

            // スコア表示
            HStack(spacing: 0) {
                // 自チーム（ゴール合計・読み取り専用）
                VStack(spacing: 4) {
                    Text("自チーム").font(.caption2).foregroundColor(.secondary)
                    Text("\(our)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)

                Text("-")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)

                // 相手チーム（入力可能）
                VStack(spacing: 4) {
                    Text(match.opponent).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    Text(opp.map { "\($0)" } ?? "?")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(opp == nil ? .secondary.opacity(0.4) : .primary)
                }
                .frame(maxWidth: .infinity)
            }

            // 相手スコア +/- ボタン
            HStack(spacing: 16) {
                Button {
                    let current = match.opponentScore ?? 0
                    appState.updateOpponentScore(matchId: matchId, score: current - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor((opp ?? 0) > 0 ? .red : .secondary.opacity(0.3))
                }
                .disabled((opp ?? 0) <= 0)

                Text("相手スコアを入力")
                    .font(.caption).foregroundColor(.secondary)

                Button {
                    let current = match.opponentScore ?? 0
                    appState.updateOpponentScore(matchId: matchId, score: current + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    // MARK: - CSV 生成
    private func generateCSV() -> String {
        let header = "選手名,ポジション,出場時間(分),レーティング,Goal,Assist,Shot,Drb↑,KeyP,Tackle,Inter,Clear,Block,Drb↓,Pass,LongB,Disp,MisTch,Fouled,Foul,YC,RC"
        let rows = sortedPlayers.map { p -> String in
            let s = p.stats
            let mins = String(format: "%.1f", p.totalMinutes)
            let rating = String(format: "%.2f", p.rating)
            let fields = [
                escape(p.name), p.position.label, mins, rating,
                "\(s.goals)", "\(s.assists)", "\(s.spg)", "\(s.drbOff)", "\(s.keyP)",
                "\(s.tackles)", "\(s.inter)", "\(s.clear)", "\(s.blocks)", "\(s.drbDef)",
                "\(s.avgP)", "\(s.longB)", "\(s.disp)", "\(s.unsTch)", "\(s.fouled)",
                "\(s.fouls)", "\(s.yellowCards)", "\(s.redCards)"
            ]
            return fields.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func escape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
