import SwiftUI

struct OfflineBanner: View {
  let isOnline: Bool

  var body: some View {
    if !isOnline {
      HStack(spacing: 8) {
        Image(systemName: "wifi.slash")
        Text("Offline")
          .font(.footnote)
          .fontWeight(.semibold)
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.red.opacity(0.15))
      .overlay(alignment: .bottom) {
        Divider()
      }
    }
  }
}

