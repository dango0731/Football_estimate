import SwiftUI

// ============================================================
// MARK: - TEAM LIST VIEW（チーム選択画面）
// ============================================================

struct TeamListView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAddTeam = false
    @State private var newTeamName = ""
    @State private var editingTeam: Team? = nil
    @State private var editName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    // ── ヘッダー ──
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("⚽️ SoccerRating").font(.largeTitle.weight(.black))
                            Text("チームを選択").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            newTeamName = ""
                            showAddTeam = true
                        } label: {
                            Label("チーム追加", systemImage: "plus.circle.fill")
                                .font(.headline.weight(.bold))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.blue).foregroundColor(.white).clipShape(Capsule())
                                .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)

                    if appState.teams.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "person.3.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.blue.opacity(0.3))
                            Text("チームを追加しよう").font(.title3.weight(.bold))
                            Text("チームごとに選手・試合を管理できます")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(appState.teams) { team in
                                    TeamCard(team: team) {
                                        appState.selectTeam(team.id)
                                    } onEdit: {
                                        editName = team.name
                                        editingTeam = team
                                    } onDelete: {
                                        appState.deleteTeam(id: team.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTeam) {
                addTeamSheet
            }
            .sheet(item: $editingTeam) { team in
                editTeamSheet(team: team)
            }
        }
    }

    // MARK: - シート
    @ViewBuilder
    private var addTeamSheet: some View {
        NavigationStack {
            Form {
                Section("チーム名") {
                    TextField("例: 〇〇高校サッカー部", text: $newTeamName)
                }
            }
            .navigationTitle("チームを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { showAddTeam = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        guard !newTeamName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        let t = Team(name: newTeamName.trimmingCharacters(in: .whitespaces))
                        appState.addTeam(t)
                        showAddTeam = false
                    }
                    .fontWeight(.bold)
                    .disabled(newTeamName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }

    @ViewBuilder
    private func editTeamSheet(team: Team) -> some View {
        NavigationStack {
            Form {
                Section("チーム名") {
                    TextField("チーム名", text: $editName)
                }
            }
            .navigationTitle("チームを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { editingTeam = nil }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let name = editName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        appState.updateTeamName(id: team.id, name: name)
                        editingTeam = nil
                    }
                    .fontWeight(.bold)
                    .disabled(editName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.fraction(0.35)])
    }
}

// ── チームカード ──
private struct TeamCard: View {
    let team: Team
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(team.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                    HStack(spacing: 12) {
                        Label("\(team.roster.count)名", systemImage: "person.fill")
                            .font(.caption).foregroundColor(.secondary)
                        Label("\(team.matches.count)試合", systemImage: "sportscourt.fill")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: { Label("名前を変更", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("削除", systemImage: "trash") }
        }
    }
}
