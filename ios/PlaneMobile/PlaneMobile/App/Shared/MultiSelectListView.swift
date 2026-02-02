import SwiftUI

struct MultiSelectListView<Item: Identifiable & Hashable>: View {
  let title: String
  let items: [Item]
  @Binding var selected: Set<String>
  let identity: (Item) -> (id: String, label: String)

  var body: some View {
    List(items, id: \.id) { item in
      let info = identity(item)
      Button {
        if selected.contains(info.id) {
          selected.remove(info.id)
        } else {
          selected.insert(info.id)
        }
      } label: {
        HStack {
          Text(info.label)
          Spacer()
          if selected.contains(info.id) {
            Image(systemName: "checkmark")
              .foregroundStyle(.tint)
          }
        }
      }
    }
    .navigationTitle(title)
  }
}

