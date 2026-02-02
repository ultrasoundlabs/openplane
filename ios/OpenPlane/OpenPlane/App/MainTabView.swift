import SwiftUI

struct MainTabView: View {
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var networkMonitor: NetworkMonitor

  var body: some View {
    TabView {
      NavigationStack {
        VStack(spacing: 0) {
          OfflineBanner(isOnline: networkMonitor.isOnline)
          ProjectsView()
        }
      }
      .tabItem { Label("Projects", systemImage: "square.grid.2x2") }

      NavigationStack {
        VStack(spacing: 0) {
          OfflineBanner(isOnline: networkMonitor.isOnline)
          IssuesView()
        }
      }
      .tabItem { Label("Work", systemImage: "checklist") }

      NavigationStack {
        VStack(spacing: 0) {
          OfflineBanner(isOnline: networkMonitor.isOnline)
          ProfilesView()
        }
      }
      .tabItem { Label("Settings", systemImage: "gear") }
    }
  }
}
