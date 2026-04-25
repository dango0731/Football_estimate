import SwiftUI

// ============================================================
// MARK: - SOCCER FIELD VIEW（コート描画）
// ============================================================

struct SoccerFieldView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 芝の色
                LinearGradient(
                    colors: [Color(red:0.13,green:0.55,blue:0.13), Color(red:0.10,green:0.45,blue:0.10)],
                    startPoint:.top, endPoint:.bottom
                )

                // ストライプ模様
                FieldStripes(width:w, height:h)
                    .opacity(0.12)

                // ライン描画
                Canvas { ctx, size in
                    let lc = Color.white.opacity(0.85)
                    let lw: CGFloat = 2.0

                    func line(_ x1:CGFloat,_ y1:CGFloat,_ x2:CGFloat,_ y2:CGFloat) {
                        var p = Path(); p.move(to:CGPoint(x:x1,y:y1)); p.addLine(to:CGPoint(x:x2,y:y2))
                        ctx.stroke(p, with:.color(lc), lineWidth:lw)
                    }
                    func rect(_ x:CGFloat,_ y:CGFloat,_ rw:CGFloat,_ rh:CGFloat) {
                        let r = CGRect(x:x,y:y,width:rw,height:rh)
                        ctx.stroke(Path(r), with:.color(lc), lineWidth:lw)
                    }

                    let W = size.width, H = size.height
                    let padX: CGFloat = 18, padY: CGFloat = 60

                    // 外枠
                    rect(padX, padY, W-padX*2, H-padY*2)

                    // センターライン
                    line(padX, H/2, W-padX, H/2)

                    // センターサークル
                    let cr: CGFloat = min(W,H)*0.12
                    var circle = Path(); circle.addEllipse(in:CGRect(x:W/2-cr,y:H/2-cr,width:cr*2,height:cr*2))
                    ctx.stroke(circle, with:.color(lc), lineWidth:lw)

                    // センタースポット
                    var spot = Path(); spot.addEllipse(in:CGRect(x:W/2-3,y:H/2-3,width:6,height:6))
                    ctx.fill(spot, with:.color(lc))

                    // ペナルティエリア（上）
                    let paw = W * 0.52, pah = H * 0.14
                    rect((W-paw)/2, padY, paw, pah)

                    // ゴールエリア（上）
                    let gaw = W * 0.26, gah = H * 0.06
                    rect((W-gaw)/2, padY, gaw, gah)

                    // ゴール枠（上）
                    let goalW = W * 0.14, goalH: CGFloat = 14
                    rect((W-goalW)/2, padY-goalH, goalW, goalH)

                    // ペナルティエリア（下）
                    rect((W-paw)/2, H-padY-pah, paw, pah)

                    // ゴールエリア（下）
                    rect((W-gaw)/2, H-padY-gah, gaw, gah)

                    // ゴール枠（下）
                    rect((W-goalW)/2, H-padY, goalW, goalH)

                    // コーナーアーク（4隅）
                    let cr2: CGFloat = 12
                    for (cx,cy,sa,ea): (CGFloat,CGFloat,CGFloat,CGFloat) in [
                        (padX, padY, 0, CGFloat.pi/2),
                        (W-padX, padY, CGFloat.pi/2, CGFloat.pi),
                        (W-padX, H-padY, CGFloat.pi, 3*CGFloat.pi/2),
                        (padX, H-padY, 3*CGFloat.pi/2, 2*CGFloat.pi)
                    ] {
                        var arc = Path(); arc.addArc(center:CGPoint(x:cx,y:cy),radius:cr2,startAngle:.radians(sa),endAngle:.radians(ea),clockwise:false)
                        ctx.stroke(arc, with:.color(lc), lineWidth:lw)
                    }

                    // ペナルティスポット（上・下）
                    for sy: CGFloat in [padY + H*0.10, H-padY-H*0.10] {
                        var ps = Path(); ps.addEllipse(in:CGRect(x:W/2-3,y:sy-3,width:6,height:6))
                        ctx.fill(ps, with:.color(lc))
                    }

                    // ペナルティアーク（上・下）
                    let parc: CGFloat = min(W,H)*0.10
                    var topArc = Path()
                    topArc.addArc(center:CGPoint(x:W/2,y:padY+H*0.10),radius:parc,startAngle:.degrees(30),endAngle:.degrees(150),clockwise:false)
                    ctx.stroke(topArc, with:.color(lc), lineWidth:lw)
                    var botArc = Path()
                    botArc.addArc(center:CGPoint(x:W/2,y:H-padY-H*0.10),radius:parc,startAngle:.degrees(210),endAngle:.degrees(330),clockwise:false)
                    ctx.stroke(botArc, with:.color(lc), lineWidth:lw)
                }
            }
        }
    }
}

struct FieldStripes: View {
    let width: CGFloat; let height: CGFloat
    var body: some View {
        Canvas { ctx, size in
            let stripeH: CGFloat = size.height / 10
            for i in 0..<10 {
                if i % 2 == 0 {
                    let r = CGRect(x:0, y:stripeH*CGFloat(i), width:size.width, height:stripeH)
                    ctx.fill(Path(r), with:.color(.white))
                }
            }
        }.frame(width:width, height:height)
    }
}

// ============================================================
// MARK: - PLAYER FIELD ICON（コート上の選手アイコン）
// ============================================================

struct PlayerFieldIcon: View {
    let player: Player
    let isSelected: Bool
    let onTap: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded:   (DragGesture.Value) -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if isSelected {
                    Circle().stroke(Color.white, lineWidth: 3)
                        .frame(width: 66, height: 66)
                        .shadow(color: player.position.color.opacity(0.9), radius: 10)
                }
                Circle()
                    .fill(isSelected
                          ? LinearGradient(colors:[player.position.color, player.position.color.opacity(0.7)],
                                           startPoint:.top, endPoint:.bottom)
                          : LinearGradient(colors:[Color(.secondarySystemBackground), Color(.tertiarySystemBackground)],
                                           startPoint:.top, endPoint:.bottom))
                    .frame(width: 58, height: 58)
                    .shadow(color: isSelected ? player.position.color.opacity(0.6) : .black.opacity(0.35),
                            radius: isSelected ? 12 : 6, x:0, y:3)
                    .overlay(
                        // ドラッグ中の視覚フィードバック
                        Circle().stroke(Color.white.opacity(isDragging ? 0.6 : 0), lineWidth: 2)
                    )

                Image(systemName: player.position.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(isSelected ? .white : player.position.color)
            }
            .scaleEffect(isSelected ? 1.12 : (isDragging ? 1.18 : 1.0))

            Text(player.name)
                .font(.system(size: 10, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.black.opacity(isDragging ? 0.8 : 0.6))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.4), radius: 2)

            Text(String(format: "%.2f", player.rating))
                .font(.system(size: 10, weight: .black))
                .foregroundColor(ratingColor(player.rating))
                .shadow(color: .black.opacity(0.6), radius: 2)
        }
        .animation(.spring(response:0.3,dampingFraction:0.65), value: isSelected)
        .animation(.spring(response:0.2,dampingFraction:0.7), value: isDragging)
        // タップ
        .onTapGesture { onTap() }
        // ドラッグ（長押し後に開始してもOK、閾値5pt）
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { val in
                    if !isDragging {
                        withAnimation(.spring(response:0.2)) { isDragging = true }
                    }
                    onDragChanged(val)
                }
                .onEnded { val in
                    withAnimation(.spring(response:0.3)) { isDragging = false }
                    onDragEnded(val)
                }
        )
    }
}
