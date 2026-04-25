import SwiftUI

// ============================================================
// MARK: - ROSTER EDITOR SHEET（追加 / 編集 / 削除）
// ============================================================

struct RosterEditorSheet: View {
    // editing=nil → 新規追加、editing=有 → 編集
    let editing: RosterPlayer?
    let onSave: (RosterPlayer) -> Void
    var onDelete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var position: Position
    @State private var height: String
    @State private var foot: Foot
    @State private var showDeleteConfirm: Bool = false
    @FocusState private var focusedField: String?

    init(editing: RosterPlayer?,
         onSave: @escaping (RosterPlayer) -> Void,
         onDelete: (() -> Void)? = nil) {
        self.editing = editing
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: editing?.name ?? "")
        _position = State(initialValue: editing?.position ?? .fw)
        _height = State(initialValue: editing?.height ?? "")
        _foot = State(initialValue: editing?.foot ?? .right)
    }

    private var isEditing: Bool { editing != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // ── ヘッダー ──
            HStack {
                Button("キャンセル") { dismiss() }
                    .foregroundColor(.secondary)
                Spacer()
                Text(isEditing ? "選手を編集" : "選手を追加")
                    .font(.headline.weight(.bold))
                Spacer()
                Button(isEditing ? "保存" : "登録") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    let saved = RosterPlayer(
                        id: editing?.id ?? UUID(),
                        name: trimmed,
                        position: position,
                        height: height.trimmingCharacters(in: .whitespaces),
                        foot: foot
                    )
                    onSave(saved)
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(canSave ? .blue : .secondary)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
            Divider()

            Form {
                Section("基本情報") {
                    HStack {
                        Label("名前", systemImage: "person.fill")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("田中 一郎", text: $name)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: "name")
                    }
                    HStack {
                        Label("ポジション", systemImage: "sportscourt")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $position) {
                            ForEach(Position.allCases) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 180)
                    }
                }

                Section("身体情報") {
                    HStack {
                        Label("身長", systemImage: "ruler")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("175", text: $height)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .focused($focusedField, equals: "height")
                        Text("cm").foregroundColor(.secondary)
                    }
                    HStack {
                        Label("利き足", systemImage: "figure.soccer")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $foot) {
                            ForEach(Foot.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                }

                if isEditing, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("この選手を削除", systemImage: "trash.fill")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("削除してもこれまでの試合データには影響しません（スナップショット方式）")
                            .font(.caption2)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if !isEditing { focusedField = "name" }
        }
        .confirmationDialog(
            "「\(name)」を削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                onDelete?()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ロスターから削除されます。過去の試合データは保持されます。")
        }
    }
}

// ============================================================
// MARK: - ROSTER MANAGEMENT VIEW（一覧・編集・削除）
// ============================================================

struct RosterManagementView: View {
    @EnvironmentObject var appState: AppState
    @State private var editingPlayer: RosterPlayer? = nil
    @State private var showAddSheet: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if appState.roster.isEmpty {
                // ── 空状態 ──
                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 56))
                        .foregroundColor(.blue.opacity(0.55))
                    Text("登録された選手はいません")
                        .font(.headline.weight(.bold))
                    Text("「追加」ボタンから選手を登録すると、\nどの試合でも使い回せるようになります。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("選手を追加", systemImage: "plus.circle.fill")
                            .font(.headline.weight(.bold))
                            .padding(.horizontal, 20).padding(.vertical, 12)
                            .background(Color.blue).foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: .blue.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 40)
            } else {
                List {
                    Section {
                        ForEach(appState.sortedRoster) { rp in
                            Button { editingPlayer = rp } label: {
                                RosterListRow(player: rp)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deletePlayers)
                    } header: {
                        HStack {
                            Text("登録選手 \(appState.roster.count)名")
                            Spacer()
                            Text("行タップで編集 / スワイプで削除")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } footer: {
                        Text("ここでの編集・削除は過去の試合データに影響しません（スナップショット方式）")
                            .font(.caption2)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("選手ロスター管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3.weight(.bold))
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            RosterEditorSheet(editing: nil) { newPlayer in
                appState.addRosterPlayer(newPlayer)
            }
        }
        .sheet(item: $editingPlayer) { target in
            RosterEditorSheet(editing: target) { updated in
                appState.updateRosterPlayer(updated)
            } onDelete: {
                appState.deleteRosterPlayer(id: target.id)
            }
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        let sorted = appState.sortedRoster
        let ids = offsets.map { sorted[$0].id }
        for id in ids { appState.deleteRosterPlayer(id: id) }
    }
}

// ── ロスター管理画面用の行 ──
struct RosterListRow: View {
    let player: RosterPlayer
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [player.position.color, player.position.color.opacity(0.7)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 44, height: 44)
                Image(systemName: player.position.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name).font(.headline)
                HStack(spacing: 6) {
                    Text(player.position.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(player.position.color.opacity(0.15))
                        .foregroundColor(player.position.color)
                        .clipShape(Capsule())
                    if !player.height.isEmpty {
                        Text("\(player.height)cm")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text(player.foot.rawValue)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
