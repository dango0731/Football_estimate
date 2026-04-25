import SwiftUI

// ============================================================
// MARK: - HEX BUTTON FLICK MENU（6角形フリック入力UI）
// ============================================================

// スタッツ効果：どのスタッツを±いくつ変動させるか
struct StatEffect {
    let keyPath: WritableKeyPath<PlayerStats, Int>
    let delta: Int
}

// フリック選択肢
struct FlickOption: Identifiable {
    let id = UUID()
    let label: String
    let angleDeg: Double         // 0°=右, 90°=上, 180°=左, 270°/-90°=下
    let effects: [StatEffect]    // 付随して発生するスタッツ更新
    let color: Color
}

// 6角形の母体ボタン設定
struct HexButtonConfig: Identifiable {
    let id: String
    let label: String
    let subtitle: String
    let icon: String
    let positionAngleDeg: Double // 中央から見たボタンの配置角度
    let color: Color
    let tapEffects: [StatEffect]?    // nil = タップ無効（フリック必須）
    let tapIsShootMenu: Bool         // true = SHOOTボタン（Goal/Missサブメニュー展開）
    let flickOptions: [FlickOption]
}

// ============================================================
// MARK: - HEX BUTTON MENU (全体)
// ============================================================

struct HexButtonMenu: View {
    @Binding var player: Player
    let onClose: () -> Void

    @State private var activeButtonId: String? = nil
    @State private var shootMenuOpen: Bool = false
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var appeared: Bool = false

    // 6ボタンの構成
    private var buttonConfigs: [HexButtonConfig] {
        [
            // ① SHOOT（上）
            HexButtonConfig(
                id: "shoot", label: "SHOOT", subtitle: "シュート",
                icon: "soccerball",
                positionAngleDeg: 90,
                color: Color(red:0.95, green:0.25, blue:0.30),
                tapEffects: nil,
                tapIsShootMenu: true,
                flickOptions: []
            ),
            // ② PASS（右上）
            HexButtonConfig(
                id: "pass", label: "PASS", subtitle: "パス",
                icon: "arrow.triangle.swap",
                positionAngleDeg: 30,
                color: Color(red:0.20, green:0.55, blue:0.95),
                tapEffects: [StatEffect(keyPath:\.avgP, delta:1)],
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"Key Pass", angleDeg:90, effects:[
                        StatEffect(keyPath:\.avgP, delta:1),
                        StatEffect(keyPath:\.keyP, delta:1)
                    ], color:Color.cyan),
                    FlickOption(label:"Assist", angleDeg:0, effects:[
                        StatEffect(keyPath:\.avgP,    delta:1),
                        StatEffect(keyPath:\.keyP,    delta:1),
                        StatEffect(keyPath:\.assists, delta:1)
                    ], color:Color.yellow)
                ]
            ),
            // ③ DRIBBLE（右下）
            HexButtonConfig(
                id: "dribble", label: "DRIBBLE", subtitle: "ドリブル",
                icon: "figure.run",
                positionAngleDeg: -30,
                color: Color(red:0.20, green:0.75, blue:0.40),
                tapEffects: nil,
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"成功 (drbOff)", angleDeg:90, effects:[
                        StatEffect(keyPath:\.drbOff, delta:1)
                    ], color:Color.green),
                    FlickOption(label:"失敗 (Disp)", angleDeg:-90, effects:[
                        StatEffect(keyPath:\.disp, delta:1)
                    ], color:Color.red)
                ]
            ),
            // ⑥ MISS（下）※目立つ赤系
            HexButtonConfig(
                id: "miss", label: "MISS", subtitle: "ロスト",
                icon: "xmark.circle.fill",
                positionAngleDeg: -90,
                color: Color(red:0.85, green:0.10, blue:0.40),
                tapEffects: nil,
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"MisTouch", angleDeg:180, effects:[
                        StatEffect(keyPath:\.unsTch, delta:1)
                    ], color:Color.orange),
                    FlickOption(label:"Dish (ロスト)", angleDeg:0, effects:[
                        StatEffect(keyPath:\.disp, delta:1)
                    ], color:Color(red:1.0, green:0.35, blue:0.35))
                ]
            ),
            // ④ DEFENSE（左下）
            HexButtonConfig(
                id: "defense", label: "DEFENSE", subtitle: "守備",
                icon: "shield.fill",
                positionAngleDeg: -150,
                color: Color(red:0.45, green:0.30, blue:0.85),
                tapEffects: nil,
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"Tackle", angleDeg:90, effects:[
                        StatEffect(keyPath:\.tackles, delta:1)
                    ], color:Color.indigo),
                    FlickOption(label:"Inter", angleDeg:180, effects:[
                        StatEffect(keyPath:\.inter, delta:1)
                    ], color:Color.blue),
                    FlickOption(label:"Block", angleDeg:-90, effects:[
                        StatEffect(keyPath:\.blocks, delta:1)
                    ], color:Color.cyan)
                ]
            ),
            // ⑤ CLEAR（左上）
            HexButtonConfig(
                id: "clear", label: "CLEAR", subtitle: "クリア",
                icon: "arrow.up.to.line",
                positionAngleDeg: 150,
                color: Color(red:0.95, green:0.55, blue:0.15),
                tapEffects: [StatEffect(keyPath:\.clear, delta:1)],
                tapIsShootMenu: false,
                flickOptions: [
                    FlickOption(label:"Long Ball", angleDeg:90, effects:[
                        StatEffect(keyPath:\.longB, delta:1)
                    ], color:Color.yellow)
                ]
            ),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2
            let buttonRadius: CGFloat = 125

            ZStack {
                // ── 6角形ボタン群 ──
                ForEach(buttonConfigs) { config in
                    let rad = config.positionAngleDeg * .pi / 180
                    let dx = buttonRadius * cos(CGFloat(rad))
                    let dy = -buttonRadius * sin(CGFloat(rad))

                    HexButton(
                        config: config,
                        isActive: activeButtonId == config.id,
                        onPressStart: {
                            activeButtonId = config.id
                            UIImpactFeedbackGenerator(style:.light).impactOccurred()
                        },
                        onFlickCommit: { effects, label in
                            applyEffects(effects, toast: label)
                            activeButtonId = nil
                        },
                        onTapCommit: {
                            if config.tapIsShootMenu {
                                withAnimation(.spring(response:0.3,dampingFraction:0.65)) {
                                    shootMenuOpen = true
                                }
                            } else if let tap = config.tapEffects {
                                applyEffects(tap, toast: config.label)
                            }
                            activeButtonId = nil
                        },
                        onCancel: {
                            activeButtonId = nil
                        }
                    )
                    .position(x: centerX + dx, y: centerY + dy)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response:0.42, dampingFraction:0.62)
                            .delay(Double(buttonConfigs.firstIndex(where:{$0.id==config.id}) ?? 0) * 0.04),
                        value: appeared
                    )
                    .zIndex(activeButtonId == config.id ? 100 : 1)
                }

                // ── 中央：選手パネル ──
                CenterPlayerPanel(player: player, onClose: onClose)
                    .position(x: centerX, y: centerY)
                    .zIndex(5)

                // ── SHOOTサブメニュー（Goal/Miss） ──
                if shootMenuOpen {
                    ShootSubmenuView(
                        onGoal: {
                            applyEffects([
                                StatEffect(keyPath:\.spg,   delta:1),
                                StatEffect(keyPath:\.goals, delta:1)
                            ], toast: "⚽️ GOAL!")
                            withAnimation { shootMenuOpen = false }
                        },
                        onMiss: {
                            applyEffects([
                                StatEffect(keyPath:\.spg, delta:1)
                            ], toast: "🎯 Shoot (外れ)")
                            withAnimation { shootMenuOpen = false }
                        },
                        onCancel: {
                            withAnimation { shootMenuOpen = false }
                        }
                    )
                    .position(x: centerX, y: centerY - 190)
                    .zIndex(200)
                    .transition(.scale(scale:0.3).combined(with:.opacity))
                }

                // ── トースト通知 ──
                if showToast {
                    VStack {
                        Text(toastMessage)
                            .font(.system(size:15, weight:.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(
                                Capsule().fill(Color.black.opacity(0.88))
                                    .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth:1))
                            )
                            .shadow(color:.black.opacity(0.5), radius:10)
                        Spacer()
                    }
                    .padding(.top, 70)
                    .frame(maxWidth:.infinity)
                    .transition(.move(edge:.top).combined(with:.opacity))
                    .zIndex(300)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response:0.45, dampingFraction:0.65)) { appeared = true }
        }
    }

    private func applyEffects(_ effects: [StatEffect], toast: String) {
        for e in effects {
            player.stats[keyPath: e.keyPath] += e.delta
        }
        UIImpactFeedbackGenerator(style:.medium).impactOccurred()
        toastMessage = toast
        withAnimation(.spring(response:0.3, dampingFraction:0.7)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline:.now() + 1.2) {
            withAnimation(.easeOut(duration:0.2)) { showToast = false }
        }
    }
}

// ============================================================
// MARK: - HEX BUTTON（6角形ボタン、タップ／フリック両対応）
// ============================================================

struct HexButton: View {
    let config: HexButtonConfig
    let isActive: Bool
    let onPressStart: () -> Void
    let onFlickCommit: ([StatEffect], String) -> Void
    let onTapCommit: () -> Void
    let onCancel: () -> Void

    @State private var highlightedOptionId: UUID? = nil
    @State private var hasStarted: Bool = false

    private let buttonSize: CGFloat = 82
    private let flickThreshold: CGFloat = 32
    private let fanRadius: CGFloat = 78

    var body: some View {
        ZStack {
            // ── 扇状ガイド（アクティブ時のみ表示） ──
            if isActive {
                ForEach(config.flickOptions) { option in
                    let rad = option.angleDeg * .pi / 180
                    let ox = fanRadius * cos(CGFloat(rad))
                    let oy = -fanRadius * sin(CGFloat(rad))
                    let isHL = highlightedOptionId == option.id

                    // ガイドライン
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: ox, y: oy))
                    }
                    .stroke(
                        isHL ? option.color : option.color.opacity(0.35),
                        style: StrokeStyle(lineWidth: isHL ? 3 : 2, lineCap:.round, dash:[4,4])
                    )

                    // ラベルバブル
                    Text(option.label)
                        .font(.system(size:11, weight:.heavy))
                        .foregroundColor(isHL ? .black : .white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(
                            Capsule().fill(isHL ? option.color : Color.black.opacity(0.88))
                        )
                        .overlay(
                            Capsule().stroke(option.color, lineWidth: isHL ? 0 : 1.5)
                        )
                        .scaleEffect(isHL ? 1.18 : 1.0)
                        .shadow(color: option.color.opacity(isHL ? 0.9 : 0.4), radius: isHL ? 10 : 5)
                        .offset(x: ox, y: oy)
                        .animation(.spring(response:0.2, dampingFraction:0.7), value: isHL)
                }
            }

            // ── 6角形ボタン本体 ──
            ZStack {
                HexagonShape()
                    .fill(LinearGradient(
                        colors:[
                            config.color,
                            config.color.opacity(0.55)
                        ],
                        startPoint:.topLeading, endPoint:.bottomTrailing
                    ))
                    .overlay(
                        HexagonShape().stroke(
                            isActive ? Color.white : Color.white.opacity(0.35),
                            lineWidth: isActive ? 3 : 1.5
                        )
                    )
                    .shadow(color: config.color.opacity(isActive ? 0.85 : 0.45),
                            radius: isActive ? 18 : 8, x:0, y:4)
                VStack(spacing:1) {
                    Image(systemName: config.icon)
                        .font(.system(size:22, weight:.bold))
                        .foregroundColor(.white)
                    Text(config.label)
                        .font(.system(size:11, weight:.heavy))
                        .foregroundColor(.white)
                    Text(config.subtitle)
                        .font(.system(size:8, weight:.semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(width: buttonSize, height: buttonSize * 0.92)
            .scaleEffect(isActive ? 1.10 : 1.0)
            .animation(.spring(response:0.22, dampingFraction:0.65), value: isActive)
        }
        .frame(width: buttonSize * 1.15, height: buttonSize * 1.15)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !hasStarted {
                        hasStarted = true
                        onPressStart()
                    }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let dist = sqrt(dx*dx + dy*dy)

                    if dist > flickThreshold && !config.flickOptions.isEmpty {
                        // 指の移動方向の角度（画面座標→数学座標に反転）
                        let userAngle = atan2(-Double(dy), Double(dx))
                        var bestId: UUID? = nil
                        var bestDiff: Double = .pi / 3  // 最大±60°以内
                        for option in config.flickOptions {
                            let optRad = option.angleDeg * .pi / 180
                            var diff = abs(userAngle - optRad)
                            if diff > .pi { diff = 2 * .pi - diff }
                            if diff < bestDiff {
                                bestDiff = diff
                                bestId = option.id
                            }
                        }
                        if highlightedOptionId != bestId {
                            highlightedOptionId = bestId
                            if bestId != nil {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                    } else {
                        if highlightedOptionId != nil {
                            highlightedOptionId = nil
                        }
                    }
                }
                .onEnded { value in
                    defer {
                        hasStarted = false
                        highlightedOptionId = nil
                    }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let dist = sqrt(dx*dx + dy*dy)

                    if dist < flickThreshold {
                        // タップ扱い
                        if config.tapIsShootMenu || config.tapEffects != nil {
                            onTapCommit()
                        } else {
                            // タップ無効ボタン（DRIBBLE, DEFENSE, MISS）
                            onCancel()
                        }
                    } else if let hlId = highlightedOptionId,
                              let opt = config.flickOptions.first(where: { $0.id == hlId }) {
                        onFlickCommit(opt.effects, opt.label)
                    } else {
                        onCancel()
                    }
                }
        )
    }
}

// ============================================================
// MARK: - HEXAGON SHAPE（6角形シェイプ・ポイントトップ）
// ============================================================

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to:    CGPoint(x: w*0.5,  y: 0))
        path.addLine(to: CGPoint(x: w,      y: h*0.25))
        path.addLine(to: CGPoint(x: w,      y: h*0.75))
        path.addLine(to: CGPoint(x: w*0.5,  y: h))
        path.addLine(to: CGPoint(x: 0,      y: h*0.75))
        path.addLine(to: CGPoint(x: 0,      y: h*0.25))
        path.closeSubpath()
        return path
    }
}

// ============================================================
// MARK: - CENTER PLAYER PANEL（中央の選手情報表示）
// ============================================================

struct CenterPlayerPanel: View {
    let player: Player
    let onClose: () -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(player.position.color.opacity(0.18))
                .frame(width:130, height:130)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration:1.5).repeatForever(autoreverses:true), value: pulse)
            Circle()
                .fill(LinearGradient(
                    colors:[player.position.color, player.position.color.opacity(0.65)],
                    startPoint:.topLeading, endPoint:.bottomTrailing
                ))
                .frame(width: 112, height: 112)
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
                .shadow(color: player.position.color.opacity(0.7), radius: 20)

            VStack(spacing:3) {
                Text(player.position.label)
                    .font(.system(size:10, weight:.black))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.3)))
                Text(player.name)
                    .font(.system(size:12, weight:.bold))
                    .foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 92)
                Text(String(format:"%.2f", player.rating))
                    .font(.system(size:26, weight:.black, design:.rounded))
                    .foregroundColor(.white)
                    .shadow(color:.black.opacity(0.4), radius: 2)
                Text(ratingLabel(player.rating))
                    .font(.system(size:8, weight:.heavy))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 112, height: 112)

            // ×ボタン
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.5)).frame(width: 30, height: 30)
                            Image(systemName:"xmark")
                                .font(.system(size:11, weight:.bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                Spacer()
            }
            .frame(width: 112, height: 112)
        }
        .onAppear { pulse = true }
    }
}

// ============================================================
// MARK: - SHOOT SUBMENU VIEW（Goal / Miss 二択）
// ============================================================

struct ShootSubmenuView: View {
    let onGoal: () -> Void
    let onMiss: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("GOAL? / MISS?")
                .font(.system(size:13, weight:.black))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color:.black.opacity(0.6), radius:2)

            HStack(spacing: 14) {
                // GOAL
                Button(action: onGoal) {
                    VStack(spacing: 3) {
                        Image(systemName:"soccerball")
                            .font(.system(size:28, weight:.bold))
                        Text("GOAL")
                            .font(.system(size:13, weight:.heavy))
                    }
                    .foregroundColor(.white)
                    .frame(width: 88, height: 88)
                    .background(
                        Circle().fill(LinearGradient(
                            colors:[Color(red:0.2,green:0.85,blue:0.35), Color(red:0.1,green:0.6,blue:0.25)],
                            startPoint:.top, endPoint:.bottom
                        ))
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .green.opacity(0.8), radius: 18)
                }
                .buttonStyle(.plain)

                // MISS（外れ）
                Button(action: onMiss) {
                    VStack(spacing: 3) {
                        Image(systemName:"xmark")
                            .font(.system(size:26, weight:.bold))
                        Text("MISS")
                            .font(.system(size:13, weight:.heavy))
                    }
                    .foregroundColor(.white)
                    .frame(width: 88, height: 88)
                    .background(
                        Circle().fill(LinearGradient(
                            colors:[Color(red:0.95,green:0.30,blue:0.30), Color(red:0.7,green:0.15,blue:0.2)],
                            startPoint:.top, endPoint:.bottom
                        ))
                    )
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .red.opacity(0.8), radius: 18)
                }
                .buttonStyle(.plain)
            }

            Button(action: onCancel) {
                Text("キャンセル")
                    .font(.system(size:11, weight:.semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Capsule().stroke(Color.white.opacity(0.45), lineWidth:1))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style:.continuous)
                .fill(Color.black.opacity(0.80))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style:.continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color:.black.opacity(0.5), radius: 14)
        )
    }
}
