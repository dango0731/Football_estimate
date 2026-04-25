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
    let tapIsSubMenu: Bool           // true = 交代/カード サブメニューを開く
    let flickOptions: [FlickOption]
}

// ============================================================
// MARK: - HEX BUTTON MENU (全体)
// ============================================================

struct HexButtonMenu: View {
    @Binding var player: Player
    let bench: [Player]
    let onSubstitute: (UUID) -> Void
    let onClose: () -> Void

    @State private var activeButtonId: String? = nil
    @State private var subMenuOpen: Bool = false
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var appeared: Bool = false

    // 6ボタンの構成
    private var buttonConfigs: [HexButtonConfig] {
        [
            // ① SHOOT（上） — タップ=シュート、フリック上=GOAL
            HexButtonConfig(
                id: "shoot", label: "SHOOT", subtitle: "シュート",
                icon: "soccerball",
                positionAngleDeg: 90,
                color: Color(red:0.95, green:0.25, blue:0.30),
                tapEffects: [StatEffect(keyPath:\.spg, delta:1)],
                tapIsSubMenu: false,
                flickOptions: [
                    FlickOption(label:"⚽️ GOAL!", angleDeg:90, effects:[
                        StatEffect(keyPath:\.spg,   delta:1),
                        StatEffect(keyPath:\.goals, delta:1)
                    ], color:Color.green)
                ]
            ),
            // ② PASS（右上） — タップ=パスのみ、フリック=Assist/KeyPass/LongPass（全てパス+1）
            HexButtonConfig(
                id: "pass", label: "PASS", subtitle: "パス",
                icon: "arrow.triangle.swap",
                positionAngleDeg: 30,
                color: Color(red:0.20, green:0.55, blue:0.95),
                tapEffects: [StatEffect(keyPath:\.avgP, delta:1)],
                tapIsSubMenu: false,
                flickOptions: [
                    FlickOption(label:"Assist", angleDeg:90, effects:[
                        StatEffect(keyPath:\.avgP,    delta:1),
                        StatEffect(keyPath:\.keyP,    delta:1),
                        StatEffect(keyPath:\.assists, delta:1)
                    ], color:Color.yellow),
                    FlickOption(label:"Key Pass", angleDeg:180, effects:[
                        StatEffect(keyPath:\.avgP, delta:1),
                        StatEffect(keyPath:\.keyP, delta:1)
                    ], color:Color.cyan),
                    FlickOption(label:"Long Pass", angleDeg:0, effects:[
                        StatEffect(keyPath:\.avgP,  delta:1),
                        StatEffect(keyPath:\.longB, delta:1)
                    ], color:Color.orange)
                ]
            ),
            // ③ DRIBBLE（右下） — フリック3択：成功 / ロスト / ミスタッチ
            HexButtonConfig(
                id: "dribble", label: "DRIBBLE", subtitle: "ドリブル",
                icon: "figure.run",
                positionAngleDeg: -30,
                color: Color(red:0.20, green:0.75, blue:0.40),
                tapEffects: nil,
                tapIsSubMenu: false,
                flickOptions: [
                    FlickOption(label:"成功", angleDeg:90, effects:[
                        StatEffect(keyPath:\.drbOff, delta:1)
                    ], color:Color.green),
                    FlickOption(label:"ロスト", angleDeg:-90, effects:[
                        StatEffect(keyPath:\.disp, delta:1)
                    ], color:Color.red),
                    FlickOption(label:"ミスタッチ", angleDeg:180, effects:[
                        StatEffect(keyPath:\.unsTch, delta:1)
                    ], color:Color.orange)
                ]
            ),
            // ④ BLOCK（下） — フリック2択：Block / Clear
            HexButtonConfig(
                id: "block", label: "BLOCK", subtitle: "ブロック",
                icon: "rectangle.fill",
                positionAngleDeg: -90,
                color: Color(red:0.45, green:0.65, blue:0.95),
                tapEffects: nil,
                tapIsSubMenu: false,
                flickOptions: [
                    FlickOption(label:"Block", angleDeg:90, effects:[
                        StatEffect(keyPath:\.blocks, delta:1)
                    ], color:Color.cyan),
                    FlickOption(label:"Clear", angleDeg:180, effects:[
                        StatEffect(keyPath:\.clear, delta:1)
                    ], color:Color.yellow)
                ]
            ),
            // ⑤ DEFENSE（左下） — タップ=Inter単独、フリック=Inter+追加（タックル/抜かれ）
            HexButtonConfig(
                id: "defense", label: "DEFENSE", subtitle: "守備",
                icon: "shield.fill",
                positionAngleDeg: -150,
                color: Color(red:0.45, green:0.30, blue:0.85),
                tapEffects: [StatEffect(keyPath:\.inter, delta:1)],
                tapIsSubMenu: false,
                flickOptions: [
                    FlickOption(label:"+ Tackle", angleDeg:90, effects:[
                        StatEffect(keyPath:\.inter,   delta:1),
                        StatEffect(keyPath:\.tackles, delta:1)
                    ], color:Color.indigo),
                    FlickOption(label:"+ 抜かれ", angleDeg:-90, effects:[
                        StatEffect(keyPath:\.inter,  delta:1),
                        StatEffect(keyPath:\.drbDef, delta:1)
                    ], color:Color.red)
                ]
            ),
            // ⑥ SUB（左上） — タップで「交代/カード」サブメニュー
            HexButtonConfig(
                id: "sub", label: "SUB", subtitle: "交代/カード",
                icon: "arrow.triangle.2.circlepath",
                positionAngleDeg: 150,
                color: Color(red:0.70, green:0.30, blue:0.55),
                tapEffects: [],   // タップ可だが、効果なし（サブメニューを開くだけ）
                tapIsSubMenu: true,
                flickOptions: []
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
                            if config.tapIsSubMenu {
                                withAnimation(.spring(response:0.3,dampingFraction:0.65)) {
                                    subMenuOpen = true
                                }
                            } else if let tap = config.tapEffects, !tap.isEmpty {
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

                // ── SUB+カードサブメニュー ──
                if subMenuOpen {
                    SubstitutionMenuView(
                        player: $player,
                        bench: bench,
                        onSubstitute: { benchId in
                            onSubstitute(benchId)
                            withAnimation { subMenuOpen = false }
                        },
                        onCardChange: { isYellow, delta in
                            let kp: WritableKeyPath<PlayerStats, Int> = isYellow ? \.yellowCards : \.redCards
                            let maxVal = isYellow ? 2 : 1   // イエロー上限2、レッド上限1
                            let proposed = player.stats[keyPath: kp] + delta
                            let newVal = max(0, min(maxVal, proposed))
                            player.stats[keyPath: kp] = newVal
                            UISelectionFeedbackGenerator().selectionChanged()
                        },
                        onCancel: {
                            withAnimation { subMenuOpen = false }
                        }
                    )
                    .position(x: centerX, y: centerY)
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
                        if config.tapIsSubMenu || (config.tapEffects != nil) {
                            onTapCommit()
                        } else {
                            // タップ無効ボタン（DRIBBLE, DEFENSE, BLOCK）
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
                // カード警告（持っていれば表示）
                if player.stats.yellowCards > 0 || player.stats.redCards > 0 {
                    HStack(spacing: 4) {
                        if player.stats.yellowCards > 0 {
                            HStack(spacing:1) {
                                Rectangle().fill(Color.yellow).frame(width:6, height:9).cornerRadius(1)
                                Text("\(player.stats.yellowCards)").font(.system(size:8, weight:.heavy)).foregroundColor(.white)
                            }
                        }
                        if player.stats.redCards > 0 {
                            HStack(spacing:1) {
                                Rectangle().fill(Color.red).frame(width:6, height:9).cornerRadius(1)
                                Text("\(player.stats.redCards)").font(.system(size:8, weight:.heavy)).foregroundColor(.white)
                            }
                        }
                    }
                }
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
// MARK: - SUBSTITUTION MENU VIEW（選手交代＋カード管理オーバーレイ）
// ============================================================

struct SubstitutionMenuView: View {
    @Binding var player: Player
    let bench: [Player]
    let onSubstitute: (UUID) -> Void
    let onCardChange: (Bool, Int) -> Void   // (isYellow, delta)
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // タイトル
            HStack {
                Image(systemName:"arrow.triangle.2.circlepath")
                    .foregroundColor(.white.opacity(0.85))
                Text("交代 / カード")
                    .font(.system(size:14, weight:.heavy))
                    .foregroundColor(.white.opacity(0.95))
            }

            // ── カード（イエロー上限2 / レッド上限1） ──
            HStack(spacing: 18) {
                cardCounter(isYellow: true,  count: player.stats.yellowCards, maxCount: 2)
                cardCounter(isYellow: false, count: player.stats.redCards,    maxCount: 1)
            }

            Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1)

            // ── 選手交代 ──
            VStack(alignment: .leading, spacing: 6) {
                Text("選手交代（ベンチ → \(player.name) と入れ替え）")
                    .font(.system(size:11, weight:.semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1).minimumScaleFactor(0.7)
                if player.wasSubstituted {
                    // この画面のplayerは交代でINしてきた選手等。OUT済みの選手はそもそもベンチ表示しない仕様だが念のため。
                    HStack {
                        Image(systemName:"lock.fill").foregroundColor(.orange)
                        Text("この選手は既に交代済みのため再交代できません")
                            .font(.system(size:11))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity)
                } else if bench.isEmpty {
                    Text("ベンチに交代可能な選手がいません")
                        .font(.system(size:11))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(bench) { b in
                                Button { onSubstitute(b.id) } label: {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            Circle().fill(b.position.color.opacity(0.25)).frame(width: 28, height: 28)
                                            Image(systemName: b.position.icon)
                                                .font(.system(size: 12, weight:.semibold))
                                                .foregroundColor(b.position.color)
                                        }
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(b.name).font(.system(size:12, weight:.bold)).foregroundColor(.white)
                                            Text(b.position.label).font(.system(size:9)).foregroundColor(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        Image(systemName:"arrow.left.arrow.right")
                                            .font(.system(size:11, weight:.bold))
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 9, style:.continuous)
                                            .fill(Color.white.opacity(0.10))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            // 閉じる
            Button(action: onCancel) {
                Text("閉じる")
                    .font(.system(size:11, weight:.semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(Capsule().stroke(Color.white.opacity(0.45), lineWidth:1))
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 20, style:.continuous)
                .fill(Color.black.opacity(0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style:.continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color:.black.opacity(0.5), radius: 14)
        )
    }

    @ViewBuilder
    private func cardCounter(isYellow: Bool, count: Int, maxCount: Int) -> some View {
        let isAtMax = count >= maxCount
        let isAtMin = count <= 0
        VStack(spacing: 4) {
            Rectangle()
                .fill(isYellow ? Color.yellow : Color.red)
                .frame(width: 22, height: 30)
                .cornerRadius(2)
                .shadow(color:.black.opacity(0.4), radius:2)
                .overlay(
                    Text("\(count)/\(maxCount)")
                        .font(.system(size:8, weight:.heavy))
                        .foregroundColor(.black.opacity(0.7))
                        .offset(y: 18)
                )
            HStack(spacing: 6) {
                Button { onCardChange(isYellow, -1) } label: {
                    Image(systemName:"minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(isAtMin ? 0.25 : 0.85))
                }
                .disabled(isAtMin)
                Text("\(count)")
                    .font(.system(size: 18, weight:.heavy, design:.rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 22)
                Button { onCardChange(isYellow, 1) } label: {
                    Image(systemName:"plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(isAtMax ? 0.25 : 0.95))
                }
                .disabled(isAtMax)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 10)
        .padding(.top, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style:.continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
