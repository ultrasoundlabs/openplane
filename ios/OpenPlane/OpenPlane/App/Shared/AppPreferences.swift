import SwiftUI

final class AppPreferences: ObservableObject {
  @AppStorage("pref.compactRows") var compactRows: Bool = false
  @AppStorage("pref.autoRefreshEnabled") var autoRefreshEnabled: Bool = true
  @AppStorage("pref.autoRefreshIntervalSeconds") var autoRefreshIntervalSeconds: Double = 120
}
