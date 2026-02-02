import SwiftUI

struct RootView: View {
  @StateObject private var profiles: ProfilesStore
  @StateObject private var session: SessionStore
  @StateObject private var preferences = AppPreferences()
  @StateObject private var networkMonitor = NetworkMonitor()
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let env = ProcessInfo.processInfo.environment
    let secrets: SecretStoring = env["OPENPLANE_UI_TESTS"] == "1" ? UserDefaultsSecretStore() : Keychain.shared
    let profiles = ProfilesStore(secretStore: secrets)
    _profiles = StateObject(wrappedValue: profiles)
    if ProcessInfo.processInfo.environment["OPENPLANE_UI_STUBS"] == "1" {
      let config = URLSessionConfiguration.ephemeral
      config.protocolClasses = [OpenPlaneStubURLProtocol.self]
      config.timeoutIntervalForRequest = 20
      config.timeoutIntervalForResource = 20
      let session = URLSession(configuration: config)
      _session = StateObject(wrappedValue: SessionStore(profiles: profiles, clientProvider: DefaultPlaneAPIClientProvider(session: session)))
    } else {
      _session = StateObject(wrappedValue: SessionStore(profiles: profiles))
    }
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
