import SwiftUI

struct ErrorStateView: View {
  let title: String
  let message: String
  let retry: () -> Void

  var body: some View {
    VStack(spacing: 16) {
      ContentUnavailableView(title, systemImage: "exclamationmark.triangle", description: Text(message))
      Button("Retry", action: retry)
    }
    .padding()
  }
}

