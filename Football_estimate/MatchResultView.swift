import SwiftUI

// ============================================================
// MARK: - MATCH RESULT VIEW（試合結果画面）
// ============================================================

struct MatchResultView: View {
    let match: Match
    var sortedPlayers: [Player] { match.players.filter{$0.isStarter}.sorted{$0.rating>$1.rating} }
    var avgRating: Double {
        guard !sortedPlayers.isEmpty else { return 0 }
        return sortedPlayers.reduce(0.0){$0+$1.rating}/Double(sortedPlayers.count)
    }
    var body: some View {
        List {
            Section {
                VStack(spacing:10) {
                    Text("チーム平均レーティング").font(.subheadline).foregroundColor(.secondary)
                    Text(String(format:"%.2f",avgRating))
                        .font(.system(size:64,weight:.black,design:.rounded)).foregroundColor(ratingColor(avgRating))
                    Text(ratingLabel(avgRating)).font(.subheadline.weight(.semibold)).foregroundColor(ratingColor(avgRating).opacity(0.8))
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
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    MatchStatsDetailView(match: match)
                } label: {
                    Label("詳細スタッツ", systemImage: "list.bullet.rectangle.portrait")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }
}
