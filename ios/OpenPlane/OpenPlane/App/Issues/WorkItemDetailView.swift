import SwiftUI

struct WorkItemDetailView: View {
  @EnvironmentObject private var session: SessionStore
  let project: PlaneProject
  let itemID: String

  @State private var isLoading = false
  @State private var errorMessage: String?

  @State private var item: PlaneWorkItem?

  @State private var name: String = ""
  @State private var descriptionText: String = ""
  @State private var selectedStateID: String?
  @State private var selectedPriority: PlanePriority = .none
  @State private var selectedAssigneeIDs: Set<String> = []
  @State private var selectedLabelIDs: Set<String> = []
  @State private var selectedTypeID: String?
  @State private var startDate: Date?
  @State private var targetDate: Date?
  @State private var hasStartDate: Bool = false
  @State private var hasTargetDate: Bool = false
  @State private var startDateTouched: Bool = false
  @State private var targetDateTouched: Bool = false

  var body: some View {
    Group {
      if let item = item ?? session.workItem(projectID: project.id, itemID: itemID) {
        Form {
          Section {
            TextField("Title", text: $name)
              .font(.headline)
            if let identifier = item.identifier {
              Text(identifier)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }

          Section("Status") {
            if session.statesByProject[project.id] == nil {
              ProgressView("Loading states…")
            } else {
              Picker("State", selection: Binding(get: { selectedStateID ?? item.stateID }, set: { selectedStateID = $0 })) {
                Text("Unassigned").tag(Optional<String>.none)
                ForEach(session.statesByProject[project.id] ?? []) { state in
                  Text(state.name).tag(Optional(state.id))
                }
              }
            }

            Picker("Priority", selection: $selectedPriority) {
              ForEach(PlanePriority.allCases, id: \.self) { p in
                Text(p.displayName).tag(p)
              }
            }

            Button("Save changes") {
              Task { await saveUpdates() }
            }
            .disabled(isLoading)
          }

          Section("Description") {
            TextEditor(text: $descriptionText)
              .frame(minHeight: 140)
          }

          Section("People") {
            NavigationLink {
              MultiSelectListView(
                title: "Assignees",
                items: members,
                selected: $selectedAssigneeIDs
              ) { member in
                (member.id, member.bestName)
              }
            } label: {
              LabeledContent("Assignees") {
                Text(assigneeSummary).foregroundStyle(.secondary)
              }
            }
          }

          Section("Classification") {
            NavigationLink {
              MultiSelectListView(
                title: "Labels",
                items: labels,
                selected: $selectedLabelIDs
              ) { label in
                (label.id, label.name ?? label.id)
              }
            } label: {
              LabeledContent("Labels") {
                Text(labelSummary).foregroundStyle(.secondary)
              }
            }

            Picker("Type", selection: $selectedTypeID) {
              Text("Unassigned").tag(Optional<String>.none)
              ForEach(types, id: \.id) { t in
                Text(t.name ?? t.id).tag(Optional(t.id))
              }
            }
          }

          Section("Dates") {
            Toggle("Start date", isOn: $hasStartDate)
            if hasStartDate {
              DatePicker(
                "Start",
                selection: Binding(
                  get: { startDate ?? Date() },
                  set: { startDate = $0; startDateTouched = true }
                ),
                displayedComponents: .date
              )
            }

            Toggle("Target date", isOn: $hasTargetDate)
            if hasTargetDate {
              DatePicker(
                "Target",
                selection: Binding(
                  get: { targetDate ?? Date() },
                  set: { targetDate = $0; targetDateTouched = true }
                ),
                displayedComponents: .date
              )
            }

            if (originalStartDate != nil && !hasStartDate) || (originalTargetDate != nil && !hasTargetDate) {
              Text("Dates will be cleared when you save.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }

          if let profile = session.currentProfile {
            Section {
              Button("Open in Plane") {
                if let item = item ?? session.workItem(projectID: project.id, itemID: itemID) {
                  openInPlane(profile: profile, project: project, item: item)
                } else {
                  openInPlaneWorkspace(profile: profile)
                }
              }
            }
          }
        }
      } else {
        ProgressView("Loading…")
          .task { await load() }
      }
    }
    .navigationTitle("Work item")
    .navigationBarTitleDisplayMode(.inline)
    .alert("Update failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
    .task {
      session.hydrateProjectCaches(project: project)
      if session.statesByProject[project.id] == nil { await session.loadStates(project: project) }
      if session.labelsByProject[project.id] == nil { await session.loadLabels(project: project) }
      if session.workItemTypesByProject[project.id] == nil { await session.loadWorkItemTypes(project: project) }
      if session.currentUser == nil { await session.bootstrap() }
      if session.membersByWorkspace[session.currentProfile?.workspaceSlug ?? ""] == nil { await session.loadMembers() }

      if item == nil {
        await load()
      } else {
        syncFromItem(item)
      }
    }
  }

  private func load() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let detail = try await session.fetchWorkItemDetail(project: project, workItemID: itemID)
      item = detail
      syncFromItem(detail)
    } catch {
      let apiError = error as? PlaneAPIError ?? .unknown(error)
      errorMessage = apiError.userFacingMessage
    }
  }

  private func saveUpdates() async {
    isLoading = true
    defer { isLoading = false }
    do {
      let body = UpdateWorkItemRequest(
        name: name.trimmedNonEmpty,
        descriptionHTML: descriptionText.trimmedNonEmpty.map { PlaneHTML.simpleParagraph($0) },
        state: selectedStateID,
        priority: selectedPriority,
        assignees: selectedAssigneeIDs.isEmpty ? nil : Array(selectedAssigneeIDs),
        labels: selectedLabelIDs.isEmpty ? nil : Array(selectedLabelIDs),
        type: selectedTypeID,
        startDate: startDatePatchField,
        targetDate: targetDatePatchField
      )
      let updated = try await session.updateWorkItem(project: project, workItemID: itemID, body: body)
      item = updated
      syncFromItem(updated)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private var members: [PlaneMember] {
    guard let slug = session.currentProfile?.workspaceSlug else { return [] }
    return session.membersByWorkspace[slug] ?? []
  }

  private var labels: [PlaneLabel] {
    session.labelsByProject[project.id] ?? []
  }

  private var types: [PlaneWorkItemType] {
    session.workItemTypesByProject[project.id] ?? []
  }

  private var assigneeSummary: String {
    if selectedAssigneeIDs.isEmpty { return "None" }
    let map = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.bestName) })
    return selectedAssigneeIDs.compactMap { map[$0] }.sorted().joined(separator: ", ")
  }

  private var labelSummary: String {
    if selectedLabelIDs.isEmpty { return "None" }
    let map = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0.name ?? $0.id) })
    return selectedLabelIDs.compactMap { map[$0] }.sorted().joined(separator: ", ")
  }

  private func syncFromItem(_ item: PlaneWorkItem?) {
    guard let item else { return }
    name = item.name ?? ""
    descriptionText = item.descriptionText ?? ""
    selectedStateID = item.stateID
    selectedPriority = item.priority
    selectedAssigneeIDs = Set((item.assignees ?? []).map(\.id))
    selectedLabelIDs = Set((item.labels ?? []).map(\.id))
    selectedTypeID = item.typeID
    startDate = item.startDate.flatMap(PlaneDateFormatter.api.date(from:))
    targetDate = item.targetDate.flatMap(PlaneDateFormatter.api.date(from:))
    hasStartDate = startDate != nil
    hasTargetDate = targetDate != nil
    startDateTouched = false
    targetDateTouched = false
  }

  @Environment(\.openURL) private var openURL
  private func openInPlaneWorkspace(profile: ValidatedProfile) {
    let url = profile.webBaseURL.appending(path: "\(profile.workspaceSlug)/projects/")
    openURL(url)
  }

  private func openInPlane(profile: ValidatedProfile, project: PlaneProject, item: PlaneWorkItem) {
    if let url = buildWorkItemURL(profile: profile, project: project, item: item) {
      openURL(url)
      return
    }
    openInPlaneWorkspace(profile: profile)
  }

  private func buildWorkItemURL(profile: ValidatedProfile, project: PlaneProject, item: PlaneWorkItem) -> URL? {
    guard let template = profile.workItemPathTemplate?.trimmedNonEmpty else { return nil }

    let identifier = item.identifier ?? {
      if let seq = item.sequenceID { return "\(project.identifier)-\(seq)" }
      return nil
    }()

    var path = template
    path = path.replacingOccurrences(of: "{workspace}", with: profile.workspaceSlug)
    path = path.replacingOccurrences(of: "{workspaceSlug}", with: profile.workspaceSlug)
    path = path.replacingOccurrences(of: "{projectIdentifier}", with: project.identifier)
    path = path.replacingOccurrences(of: "{projectId}", with: project.id)
    path = path.replacingOccurrences(of: "{workItemId}", with: item.id)
    if let identifier {
      path = path.replacingOccurrences(of: "{identifier}", with: identifier)
    }
    if let seq = item.sequenceID {
      path = path.replacingOccurrences(of: "{sequenceId}", with: String(seq))
    }

    if let absolute = URL(string: path), absolute.scheme != nil {
      return absolute
    }

    let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
    return profile.webBaseURL.appending(path: trimmed)
  }

  private var originalStartDate: String? {
    (item ?? session.workItem(projectID: project.id, itemID: itemID))?.startDate
  }

  private var originalTargetDate: String? {
    (item ?? session.workItem(projectID: project.id, itemID: itemID))?.targetDate
  }

  private var startDatePatchField: PlanePatchField<String> {
    if hasStartDate {
      guard startDateTouched else { return .unset }
      return startDate.map { .value(PlaneDateFormatter.api.string(from: $0)) } ?? .unset
    }
    // toggle off: clear if there was a value
    if originalStartDate != nil { return .null }
    return .unset
  }

  private var targetDatePatchField: PlanePatchField<String> {
    if hasTargetDate {
      guard targetDateTouched else { return .unset }
      return targetDate.map { .value(PlaneDateFormatter.api.string(from: $0)) } ?? .unset
    }
    if originalTargetDate != nil { return .null }
    return .unset
  }
}
