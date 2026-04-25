import SwiftUI

// ============================================================
// MARK: - STATS COLLECTION VIEW（サッカーコート画面・スタッツ収集）
// ============================================================

struct StatsCollectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let matchId: UUID

    @State private var selectedPlayerId: UUID? = nil
    @State private var showFinishAlert = false
    // 選手ごとのドラッグオフセット [Player.id : CGSize]
    @State private var dragOffsets: [UUID: CGSize] = [:]

    var matchIndex: Int? { appState.matches.firstIndex(where:{$0.id==matchId}) }
    var match: Match { appState.matches.first(where:{$0.id==matchId}) ?? Match(opponent:"") }
    var starters: [Player] { match.players.filter{$0.isStarter} }
    var avgRating: Double {
        guard !starters.isEmpty else { return 0 }
        return starters.reduce(0.0){$0+$1.rating}/Double(starters.count)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ─── サッカーコート背景 ───
                SoccerFieldView().ignoresSafeArea(edges:.bottom)

                // ─── 選手アイコン（ポジション固定＋ドラッグ微調整） ───
                ForEach(starters) { player in
                    let basePos  = basePosition(for: player, in: geo.size)
                    let offset   = dragOffsets[player.id] ?? .zero
                    let isSelected = selectedPlayerId == player.id

                    PlayerFieldIcon(
                        player: player,
                        isSelected: isSelected,
                        onTap: {
                            // ドラッグ中はタップ無効
                            guard dragOffsets[player.id] == .zero || dragOffsets[player.id] == nil else { return }
                            withAnimation(.spring(response:0.3,dampingFraction:0.7)) {
                                selectedPlayerId = (selectedPlayerId == player.id) ? nil : player.id
                            }
                        },
                        onDragChanged: { drag in
                            // ドラッグ中はラジアル非表示
                            selectedPlayerId = nil
                            let cur = dragOffsets[player.id] ?? .zero
                            dragOffsets[player.id] = CGSize(
                                width:  cur.width  + drag.translation.width,
                                height: cur.height + drag.translation.height
                            )
                        },
                        onDragEnded: { drag in
                            // 画面端クランプ
                            let cur = dragOffsets[player.id] ?? .zero
                            let newX = (basePos.x + cur.width).clamped(to: 40...(geo.size.width  - 40))
                            let newY = (basePos.y + cur.height).clamped(to: 80...(geo.size.height - 80))
                            withAnimation(.spring(response:0.35,dampingFraction:0.75)) {
                                dragOffsets[player.id] = CGSize(
                                    width:  newX - basePos.x,
                                    height: newY - basePos.y
                                )
                            }
                        }
                    )
                    .position(x: basePos.x + offset.width,
                              y: basePos.y + offset.height)
                    .zIndex(isSelected ? 10 : 1)
                }

                // ─── 上部ヘッダー ───
                VStack {
                    HStack {
                        VStack(alignment:.leading,spacing:2) {
                            Text("vs \(match.opponent)").font(.headline.weight(.bold)).foregroundColor(.white)
                                .shadow(color:.black.opacity(0.6),radius:2)
                            Text(match.dateString).font(.caption).foregroundColor(.white.opacity(0.85))
                                .shadow(color:.black.opacity(0.6),radius:2)
                        }
                        Spacer()
                        VStack(alignment:.trailing,spacing:1) {
                            Text("チーム平均").font(.caption2).foregroundColor(.white.opacity(0.8))
                            Text(String(format:"%.2f",avgRating)).font(.title2.weight(.black))
                                .foregroundColor(ratingColor(avgRating))
                                .shadow(color:.black.opacity(0.5),radius:3)
                        }
                    }
                    .padding(.horizontal,20).padding(.top,8).padding(.bottom,12)
                    .background(.ultraThinMaterial.opacity(0.85))
                    Spacer()
                }

                // ─── 6角フリック入力メニューオーバーレイ ───
                if let pid = selectedPlayerId,
                   let mi = matchIndex,
                   let pi = appState.matches[mi].players.firstIndex(where:{$0.id==pid}) {

                    Color.black.opacity(0.70).ignoresSafeArea()
                        .onTapGesture { withAnimation { selectedPlayerId = nil } }

                    HexButtonMenu(
                        player: $appState.matches[mi].players[pi],
                        onClose: { withAnimation { selectedPlayerId = nil } }
                    )
                    .transition(.asymmetric(
                        insertion:.scale(scale:0.4).combined(with:.opacity),
                        removal:.scale(scale:0.4).combined(with:.opacity)
                    ))
                }
            }
        }
        .navigationTitle("スタッツ収集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement:.navigationBarTrailing) {
                Button { showFinishAlert = true } label: {
                    Label("試合終了",systemImage:"flag.checkered").font(.subheadline.weight(.bold)).foregroundColor(.red)
                }
            }
        }
        .alert("試合を終了しますか？",isPresented:$showFinishAlert) {
            Button("終了する",role:.destructive) { appState.finishMatch(matchId); dismiss(); dismiss() }
            Button("キャンセル",role:.cancel) {}
        } message: { Text("結果はホームに保存されます。") }
    }

    // ポジション別・人数別の固定ベース座標
    private func basePosition(for player: Player, in size: CGSize) -> CGPoint {
        let byPosition = Dictionary(grouping: starters) { $0.position }
        let group = byPosition[player.position] ?? []
        let idx   = group.firstIndex(where:{$0.id==player.id}) ?? 0
        let count = group.count

        let headerH: CGFloat = 60
        let fieldH = size.height - headerH
        let y = headerH + fieldH * player.position.fieldYRatio

        let totalWidth = size.width * 0.80
        let startX = (size.width - totalWidth) / 2
        let x: CGFloat = count == 1
            ? size.width / 2
            : startX + (totalWidth / CGFloat(count - 1)) * CGFloat(idx)

        return CGPoint(x: x, y: y)
    }
}
