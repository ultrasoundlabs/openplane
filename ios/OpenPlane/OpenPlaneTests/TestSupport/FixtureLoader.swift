import Foundation

private final class FixtureLoaderToken {}

enum FixtureLoader {
  static func data(_ name: String) -> Data {
    let bundle = Bundle(for: FixtureLoaderToken.self)
    let (base, ext) = split(name)

    let candidates: [URL?] = [
      bundle.url(forResource: base, withExtension: ext, subdirectory: "Fixtures"),
      bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"),
      bundle.url(forResource: base, withExtension: ext),
      bundle.url(forResource: name, withExtension: nil),
    ]

    for url in candidates.compactMap({ $0 }) {
      if let data = try? Data(contentsOf: url) {
        return data
      }
    }
    return Data()
  }

  private static func split(_ name: String) -> (String, String?) {
    let parts = name.split(separator: ".", omittingEmptySubsequences: false)
    if parts.count >= 2 {
      let ext = String(parts.last!)
      let base = parts.dropLast().joined(separator: ".")
      return (String(base), ext)
    }
    return (name, nil)
  }
}
