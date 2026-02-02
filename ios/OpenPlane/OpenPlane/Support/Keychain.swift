import Foundation
import Security

protocol SecretStoring: Sendable {
  @discardableResult
  func save(service: String, account: String, secret: String) -> Bool
  func read(service: String, account: String) -> String?
  func delete(service: String, account: String)
  func deleteAll(service: String)
}

final class Keychain: @unchecked Sendable {
  static let shared = Keychain()
  private init() {}

  func save(service: String, account: String, secret: String) -> Bool {
    guard let data = secret.data(using: .utf8) else { return false }

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let attributes: [String: Any] = [
      kSecValueData as String: data,
      // Hardened default: stored in Keychain, non-migrating, available after first unlock.
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecSuccess { return true }

    var create = query
    create[kSecValueData as String] = data
    create[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(create as CFDictionary, nil)
    return addStatus == errSecSuccess
  }

  func read(service: String, account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  func delete(service: String, account: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }

  func deleteAll(service: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

extension Keychain: SecretStoring {}
