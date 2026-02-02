import SwiftUI

extension Color {
  init?(hex: String?) {
    guard var s = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
    if s.hasPrefix("#") { s.removeFirst() }
    if s.hasPrefix("0x") || s.hasPrefix("0X") { s = String(s.dropFirst(2)) }

    guard s.count == 6 || s.count == 8 else { return nil }
    var value: UInt64 = 0
    guard Scanner(string: s).scanHexInt64(&value) else { return nil }

    let r, g, b, a: Double
    if s.count == 8 {
      r = Double((value >> 24) & 0xFF) / 255.0
      g = Double((value >> 16) & 0xFF) / 255.0
      b = Double((value >> 8) & 0xFF) / 255.0
      a = Double(value & 0xFF) / 255.0
    } else {
      r = Double((value >> 16) & 0xFF) / 255.0
      g = Double((value >> 8) & 0xFF) / 255.0
      b = Double(value & 0xFF) / 255.0
      a = 1.0
    }

    self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}

