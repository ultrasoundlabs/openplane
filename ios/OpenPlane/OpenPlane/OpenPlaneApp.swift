import SwiftUI
import Foundation

@main
struct OpenPlaneApp: App {
  init() {
    let env = ProcessInfo.processInfo.environment
    let defaults = OpenPlaneRuntime.defaults(env)
    let secrets = OpenPlaneRuntime.secretStore(defaults: defaults, env: env)

    if OpenPlaneRuntime.isUITestRun(env) {
      // Ensure UI tests start from a clean slate without polluting the simulator's normal app data.
      defaults.removePersistentDomain(forName: OpenPlaneRuntime.uiTestDefaultsSuiteName)
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
        defaults.set(data, forKey: "plane.profiles")
        defaults.set(profile.id.uuidString, forKey: "plane.selectedProfileID")
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
