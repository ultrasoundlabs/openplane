import Foundation

enum OpenPlaneRuntime {
  static let uiTestDefaultsSuiteName = "com.openplane.OpenPlane.ui-tests"

  static func isUITestRun(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
    env["OPENPLANE_UI_TESTS"] == "1"
  }

  static func defaults(_ env: [String: String] = ProcessInfo.processInfo.environment) -> UserDefaults {
    guard isUITestRun(env) else { return .standard }
    return UserDefaults(suiteName: uiTestDefaultsSuiteName) ?? .standard
  }

  static func secretStore(defaults: UserDefaults, env: [String: String] = ProcessInfo.processInfo.environment) -> SecretStoring {
    guard isUITestRun(env) else { return Keychain.shared }
    return UserDefaultsSecretStore(defaults: defaults)
  }
}

