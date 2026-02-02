import SwiftUI

struct MainTabView: View {
  @EnvironmentObject private var session: SessionStore

  var body: some View {
    TabView {
      NavigationStack {
        ProjectsView()
      }
      .tabItem { Label("Projects", systemImage: "square.grid.2x2") }

      NavigationStack {
        IssuesView()
      }
      .tabItem { Label("Work", systemImage: "checklist") }

      NavigationStack {
        SettingsView(onSaved: { await session.bootstrap() })
      }
      .tabItem { Label("Settings", systemImage: "gear") }
    }
  }
}

