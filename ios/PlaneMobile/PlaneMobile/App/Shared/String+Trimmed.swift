import Foundation

extension String {
  var trimmedNonEmpty: String? {
    let s = trimmingCharacters(in: .whitespacesAndNewlines)
    return s.isEmpty ? nil : s
  }
}

