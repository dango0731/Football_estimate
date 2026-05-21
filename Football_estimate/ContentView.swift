import SwiftUI

// ============================================================
// MARK: - ROOT（アプリのエントリポイント）
// ============================================================

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        if appState.currentTeamId == nil {
            TeamListView().environmentObject(appState)
        } else {
            HomeView().environmentObject(appState)
        }
    }
}

// ============================================================
// MARK: - NAVIGATION ROUTE（型安全な画面遷移）
// ============================================================

enum NavRoute: Hashable {
    case registration(UUID)     // 選手登録画面
    case statsCollection(UUID)  // スタッツ収集画面
    case result(UUID)           // 試合結果画面
    case rosterManagement       // ロスター管理画面
    case seasonStats(UUID)      // 選手通算スタッツ（rosterId）
    case seasonRanking          // 通算ランキング画面
}

// ============================================================
// MARK: - PREVIEW
// ============================================================

#Preview {
    ContentView()
}
