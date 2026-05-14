import SwiftUI

// ============================================================
// MARK: - FORMULA VIEW（評価式の説明）
// ============================================================

struct FormulaView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // ── 概要 ──
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("評価式の概要")
                            .font(.headline.weight(.bold))
                        formulaBox("score = 6.00 − TimeLoss(pos) × 出場分 + StatBonus(pos)")
                        Text("重回帰分析によりポジションごとに有意なスタッツ項目を選定し、各係数を算出。90分フル出場時の切片はFW=5.58、MF=5.61、DF=5.81。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // ── 時間減点 ──
                Section("TimeLoss（時間減点）") {
                    infoRow("出場分数に比例して評価を減点。出場していない時間は評価に影響しない。", icon: "clock.fill", color: .orange)
                    timeLossTable
                }

                // ── ポジション別係数 ──
                Section("StatBonus — FW（フォワード）") {
                    fwBonusRows
                }
                Section("StatBonus — MF（ミッドフィールダー）") {
                    mfBonusRows
                }
                Section("StatBonus — DF（ディフェンダー）") {
                    dfBonusRows
                }

                // ── カード減点 ──
                Section("カード減点") {
                    infoRow("カード減点は上限 −1.0（YC2枚 = RC1枚 換算）", icon: "exclamationmark.triangle.fill", color: .red)
                    coeffRow(item: "イエローカード 1枚", coeff: "−0.50", tint: .yellow)
                    coeffRow(item: "レッドカード 1枚", coeff: "−1.00", tint: .red)
                }

                // ── 評価ラベル対照表 ──
                Section("評価ラベル対照表") {
                    ratingLabelTable
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("評価式の説明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    // MARK: - TimeLoss テーブル
    @ViewBuilder
    private var timeLossTable: some View {
        let rows: [(Position, Double, Double)] = [
            (.fw, 0.42, 0.42 / 90 * 90),
            (.mf, 0.39, 0.39 / 90 * 90),
            (.df, 0.19, 0.19 / 90 * 90),
        ]
        VStack(spacing: 0) {
            tableHeader(["ポジション", "係数(/90分)", "90分時の減点"])
            ForEach(rows, id: \.0.rawValue) { pos, rate, loss in
                Divider()
                HStack {
                    Label(pos.fullLabel, systemImage: pos.icon)
                        .font(.subheadline).foregroundColor(pos.color).frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.4f", rate / 90))
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(String(format: "−%.2f", loss))
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - FW 係数行
    @ViewBuilder
    private var fwBonusRows: some View {
        coeffRow(item: "ゴール (G)",          coeff: "+0.41", tint: .red)
        coeffRow(item: "アシスト (A)",        coeff: "+0.61", tint: .yellow)
        coeffRow(item: "シュート (Shot)",     coeff: "+0.22", tint: .orange)
        coeffRow(item: "ドリブル突破 (Drb↑)", coeff: "+0.12", tint: .green)
        coeffRow(item: "パス数 (Pass)",       coeff: "+0.01", tint: .blue)
        coeffRow(item: "被ファウル (Fouled)", coeff: "+0.05", tint: .teal)
        coeffRow(item: "ボール喪失 (Disp)",   coeff: "−0.05", tint: .red, negative: true)
        coeffRow(item: "ミスタッチ (MisTch)", coeff: "−0.04", tint: .orange, negative: true)
    }

    // MARK: - MF 係数行
    @ViewBuilder
    private var mfBonusRows: some View {
        coeffRow(item: "ゴール (G)",           coeff: "+0.50", tint: .red)
        coeffRow(item: "アシスト (A)",         coeff: "+0.68", tint: .yellow)
        coeffRow(item: "キーパス (KeyP)",      coeff: "+0.16", tint: .cyan)
        coeffRow(item: "インターセプト (Inter)", coeff: "+0.15", tint: .blue)
        coeffRow(item: "タックル (Tackle)",    coeff: "+0.13", tint: .indigo)
        coeffRow(item: "ドリブル突破 (Drb↑)", coeff: "+0.10", tint: .green)
        coeffRow(item: "パス数 (Pass)",        coeff: "+0.004", tint: .blue)
    }

    // MARK: - DF 係数行
    @ViewBuilder
    private var dfBonusRows: some View {
        coeffRow(item: "インターセプト (Inter)", coeff: "+0.30", tint: .blue)
        coeffRow(item: "ゴール (G)",            coeff: "+0.67", tint: .red)
        coeffRow(item: "アシスト (A)",          coeff: "+0.50", tint: .yellow)
        coeffRow(item: "キーパス (KeyP)",       coeff: "+0.17", tint: .cyan)
        coeffRow(item: "パス数 (Pass)",         coeff: "+0.01", tint: .blue)
        coeffRow(item: "ブロック (Block)",      coeff: "+0.21", tint: .cyan)
        coeffRow(item: "被ドリブル (Drb↓)",    coeff: "−0.10", tint: .red, negative: true)
    }

    // MARK: - 評価ラベル対照表
    @ViewBuilder
    private var ratingLabelTable: some View {
        let labels: [(String, String, Color)] = [
            ("8.5 〜 10.0", "🌟 MOM級",  .yellow),
            ("7.5 〜 8.49", "⭐️ 優秀",   .green),
            ("7.0 〜 7.49", "👍 良好",    .green),
            ("6.0 〜 6.99", "😐 平均",    Color(red:0.9,green:0.75,blue:0)),
            ("5.0 〜 5.99", "👎 低調",    .orange),
            ("1.0 〜 4.99", "❌ 不調",    .red),
        ]
        VStack(spacing: 0) {
            tableHeader(["スコア範囲", "ラベル"])
            ForEach(labels, id: \.0) { range, label, color in
                Divider()
                HStack {
                    Text(range)
                        .font(.system(.subheadline, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(label)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(color)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 5)
            }
        }
    }

    // MARK: - 共通パーツ
    @ViewBuilder
    private func formulaBox(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.purple.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.purple.opacity(0.25), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func coeffRow(item: String, coeff: String, tint: Color, negative: Bool = false) -> some View {
        HStack {
            Text(item).font(.subheadline).foregroundColor(.primary)
            Spacer()
            Text(coeff)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundColor(negative ? .red : tint)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill((negative ? Color.red : tint).opacity(0.1)))
        }
    }

    @ViewBuilder
    private func infoRow(_ text: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundColor(color).font(.caption)
            Text(text).font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func tableHeader(_ cols: [String]) -> some View {
        HStack {
            ForEach(cols, id: \.self) { col in
                Text(col)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: cols.first == col ? .leading : (cols.last == col ? .trailing : .center))
            }
        }
        .padding(.vertical, 4)
    }
}
