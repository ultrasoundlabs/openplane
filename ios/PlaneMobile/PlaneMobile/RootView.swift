import SwiftUI

struct RootView: View {
  @StateObject private var session = SessionStore()

  var body: some View {
    Group {
      if session.isConfigured {
        MainTabView()
          .environmentObject(session)
      } else {
        NavigationStack {
          SettingsView(onSaved: { await session.bootstrap() })
            .environmentObject(session)
        }
      }
    }
    .task { await session.bootstrap() }
  }
}

