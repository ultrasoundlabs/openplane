import SwiftUI

struct RootView: View {
  @StateObject private var profiles = ProfilesStore()
  @StateObject private var session: SessionStore
  @StateObject private var preferences = AppPreferences()
  @StateObject private var networkMonitor = NetworkMonitor()
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let profiles = ProfilesStore()
    _profiles = StateObject(wrappedValue: profiles)
    _session = StateObject(wrappedValue: SessionStore(profiles: profiles))
  }

  var body: some View {
    Group {
      if session.isConfigured {
        MainTabView()
          .environmentObject(profiles)
          .environmentObject(session)
          .environmentObject(preferences)
          .environmentObject(networkMonitor)
      } else {
        NavigationStack {
          ProfilesView()
            .environmentObject(profiles)
            .environmentObject(session)
            .environmentObject(preferences)
            .environmentObject(networkMonitor)
        }
      }
    }
    .task { await session.bootstrap() }
    .onChange(of: profiles.selectedProfileID) { _, _ in
      Task { await session.bootstrap() }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        if networkMonitor.isOnline {
          Task { await session.bootstrap() }
        }
      }
    }
  }
}
