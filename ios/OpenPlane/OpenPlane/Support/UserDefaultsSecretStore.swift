import Foundation

final class UserDefaultsSecretStore: SecretStoring, @unchecked Sendable {
  private let defaults: UserDefaults
  private let keyPrefix = "openplane.secrets."

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  @discardableResult
  func save(service: String, account: String, secret: String) -> Bool {
    defaults.set(secret, forKey: key(for: service, account: account))
    return true
  }

  func read(service: String, account: String) -> String? {
    defaults.string(forKey: key(for: service, account: account))
  }

  func delete(service: String, account: String) {
    defaults.removeObject(forKey: key(for: service, account: account))
  }

  func deleteAll(service: String) {
    let prefix = keyPrefix + service + "."
    for (k, _) in defaults.dictionaryRepresentation() where k.hasPrefix(prefix) {
      defaults.removeObject(forKey: k)
    }
  }

  private func key(for service: String, account: String) -> String {
    keyPrefix + service + "." + account
  }
}

