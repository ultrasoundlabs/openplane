import SwiftUI
import Foundation

@main
struct OpenPlaneApp: App {
  init() {
    let env = ProcessInfo.processInfo.environment
    let secrets: SecretStoring = env["OPENPLANE_UI_TESTS"] == "1" ? UserDefaultsSecretStore() : Keychain.shared

    if env["OPENPLANE_UI_TESTS"] == "1" {
      // Ensure UI tests start from a clean slate.
      UserDefaults.standard.removeObject(forKey: "plane.selectedProfileID")
      UserDefaults.standard.removeObject(forKey: "plane.profiles")
      Keychain.shared.deleteAll(service: "OpenPlane")
      secrets.deleteAll(service: "OpenPlane")
      secrets.deleteAll(service: "PlaneMobile")
    }

    if env["OPENPLANE_UI_SEED_PROFILE"] == "1" {
      // Seed a known-good profile for UI tests + local demos.
      let profile = PlaneProfile(
        name: "Stubbed",
        apiBaseURLString: "https://example.test",
        webBaseURLString: "https://example.test",
        workspaceSlug: "my-team",
        workItemPathTemplate: "/{workspaceSlug}/work-items/{identifier}"
      )
      if let data = try? JSONEncoder().encode([profile]) {
        UserDefaults.standard.set(data, forKey: "plane.profiles")
        UserDefaults.standard.set(profile.id.uuidString, forKey: "plane.selectedProfileID")
        _ = secrets.save(service: "OpenPlane", account: "apiKey.\(profile.id.uuidString)", secret: "plane_api_test")
      }
    }

    UIStubServer.installIfEnabled()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
    }
  }
}
