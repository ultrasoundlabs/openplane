import SwiftUI

struct EditProfileView: View {
  @EnvironmentObject private var profiles: ProfilesStore
  @Environment(\.dismiss) private var dismiss

  let initial: PlaneProfile
  let isNew: Bool
  let onSave: (PlaneProfile, String?) throws -> Void

  @State private var name: String = ""
  @State private var apiBaseURLString: String = ""
  @State private var webBaseURLString: String = ""
  @State private var workspaceSlug: String = ""
  @State private var workItemPathTemplate: String = ""
  @State private var apiKey: String = ""

  @State private var errorMessage: String?

  var body: some View {
    Form {
      Section("Profile") {
        TextField("Name", text: $name)
        TextField("Workspace slug (e.g. my-team)", text: $workspaceSlug)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }

      Section("Base URLs") {
        TextField("API Base URL (https://plane.example.com)", text: $apiBaseURLString)
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
          .autocorrectionDisabled()
        TextField("Web Base URL (https://plane.example.com)", text: $webBaseURLString)
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
          .autocorrectionDisabled()

        Text("For Plane Cloud, API is `https://api.plane.so` and web is `https://app.plane.so`.")
          .font(.footnote)
          .foregroundStyle(.secondary)

        if apiBaseURLString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("http://") {
          Label("HTTP URLs are usually blocked by iOS App Transport Security. Prefer HTTPS (reverse proxy/TLS) for self-hosted Plane.", systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }

      Section("Deep Links") {
        TextField("Work item path template (optional)", text: $workItemPathTemplate)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        Text("Example: `/{workspaceSlug}/work-items/{identifier}`. Placeholders: `{workspaceSlug}`, `{projectIdentifier}`, `{identifier}`, `{workItemId}`.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }

      Section("Authentication") {
        SecureField("Personal Access Token", text: $apiKey)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
        if isNew {
          Text("Sent as `X-API-Key`.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          Text("Sent as `X-API-Key`. Leave blank to keep the existing token.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
    .navigationTitle(isNew ? "New Profile" : "Edit Profile")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") { dismiss() }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button("Save") { save() }
      }
    }
    .onAppear {
      name = initial.name
      apiBaseURLString = initial.apiBaseURLString
      webBaseURLString = initial.webBaseURLString
      workspaceSlug = initial.workspaceSlug
      workItemPathTemplate = initial.workItemPathTemplate ?? ""

      if webBaseURLString.isEmpty {
        webBaseURLString = apiBaseURLString.replacingOccurrences(of: "https://api.plane.so", with: "https://app.plane.so")
      }
    }
    .alert("Couldn’t save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
  }

  private func save() {
    do {
      let profile = PlaneProfile(
        id: initial.id,
        name: name,
        apiBaseURLString: apiBaseURLString,
        webBaseURLString: webBaseURLString,
        workspaceSlug: workspaceSlug,
        workItemPathTemplate: workItemPathTemplate.trimmedNonEmpty
      )
      let keyToSave: String?
      if isNew {
        keyToSave = apiKey
      } else {
        keyToSave = apiKey.trimmedNonEmpty
      }
      try onSave(profile, keyToSave)
      profiles.selectProfile(profile)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
