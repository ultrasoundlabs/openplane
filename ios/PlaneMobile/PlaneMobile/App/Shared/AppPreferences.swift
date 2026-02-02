import SwiftUI

final class AppPreferences: ObservableObject {
  @AppStorage("pref.compactRows") var compactRows: Bool = false
}

