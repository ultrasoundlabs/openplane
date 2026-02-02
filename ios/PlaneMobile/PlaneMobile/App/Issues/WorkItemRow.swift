import SwiftUI

struct WorkItemRow: View {
  let item: PlaneWorkItem
  let projectIdentifier: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(displayIdentifier)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        if let stateName = item.stateName {
          Text(stateName)
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
      if let snippet = item.descriptionText?.trimmedNonEmpty {
        Text(snippet)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(.vertical, 2)
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

