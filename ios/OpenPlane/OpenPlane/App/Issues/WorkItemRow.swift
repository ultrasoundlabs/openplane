import SwiftUI

struct WorkItemRow: View {
  @EnvironmentObject private var preferences: AppPreferences

  let item: PlaneWorkItem
  let projectIdentifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: preferences.compactRows ? 4 : 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(displayIdentifier)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        if let stateName = item.stateName {
          HStack(spacing: 6) {
            if let c = Color(hex: item.state?.color) {
              Circle()
                .fill(c)
                .frame(width: 8, height: 8)
            }
            Text(stateName)
          }
          .font(.caption2)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.thinMaterial)
          .clipShape(Capsule())
        }
      }
      Text(item.name ?? "Untitled")
        .font(.headline)
        .lineLimit(2)
      if let assignees = item.assignees, !assignees.isEmpty {
        Text(assignees.map(\.bestName).joined(separator: ", "))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if let labels = item.labels, !labels.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(labels.prefix(6), id: \.id) { label in
              HStack(spacing: 6) {
                if let c = Color(hex: label.color) {
                  Circle()
                    .fill(c)
                    .frame(width: 6, height: 6)
                }
                Text(label.name ?? "Label")
              }
              .font(.caption2)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.primary.opacity(0.06))
              .clipShape(Capsule())
            }
          }
        }
      }
      if let snippet = item.descriptionText?.trimmedNonEmpty {
        Text(snippet)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(preferences.compactRows ? 1 : 2)
      }
    }
    .padding(.vertical, preferences.compactRows ? 0 : 2)
  }

  private var displayIdentifier: String {
    if let identifier = item.identifier, !identifier.isEmpty {
      return identifier
    }
    if let sequenceID = item.sequenceID {
      return "\(projectIdentifier)-\(sequenceID)"
    }
    return "Work item"
  }
}
