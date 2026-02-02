import Foundation
@testable import OpenPlane

final class InMemorySecretStore: SecretStoring, @unchecked Sendable {
  private let lock = NSLock()
  private var byServiceAndAccount: [String: String] = [:]

  @discardableResult
  func save(service: String, account: String, secret: String) -> Bool {
    let key = "\(service)|\(account)"
    lock.lock()
    byServiceAndAccount[key] = secret
    lock.unlock()
    return true
  }

  func read(service: String, account: String) -> String? {
    let key = "\(service)|\(account)"
    lock.lock()
    let value = byServiceAndAccount[key]
    lock.unlock()
    return value
  }

  func delete(service: String, account: String) {
    let key = "\(service)|\(account)"
    lock.lock()
    byServiceAndAccount.removeValue(forKey: key)
    lock.unlock()
  }

  func deleteAll(service: String) {
    lock.lock()
    byServiceAndAccount = byServiceAndAccount.filter { !$0.key.hasPrefix("\(service)|") }
    lock.unlock()
  }
}

