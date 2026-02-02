import SwiftUI

struct ProfilesView: View {
  @EnvironmentObject private var profiles: ProfilesStore
  @EnvironmentObject private var session: SessionStore
  @EnvironmentObject private var preferences: AppPreferences

  @State private var isPresentingNew = false
  @State private var editingProfile: PlaneProfile?
  @State private var isTestingConnection = false
  @State private var testResult: ConnectionTestResult?

  var body: some View {
    List {
      Section("Profiles") {
        if profiles.profiles.isEmpty {
          ContentUnavailableView("No profiles", systemImage: "person.crop.circle.badge.plus", description: Text("Add a Plane profile to get started."))
        } else {
          ForEach(profiles.profiles) { profile in
            Button {
              profiles.selectProfile(profile)
            } label: {
              HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(profile.name)
                    .font(.headline)
                  Text("\(profile.workspaceSlug) • \(profile.apiBaseURLString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                Spacer()
                if profiles.selectedProfileID == profile.id {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                }
              }
            }
            .contextMenu {
              Button("Edit") { editingProfile = profile }
              Button("Delete", role: .destructive) { profiles.deleteProfile(profile) }
            }
          }
          .onDelete { indices in
            for idx in indices {
              profiles.deleteProfile(profiles.profiles[idx])
            }
          }
        }

        Button {
          isPresentingNew = true
        } label: {
          Label("Add Profile", systemImage: "plus")
        }
      }

      Section("Connection") {
        Button {
          Task { await testConnection() }
        } label: {
          if isTestingConnection {
            HStack { ProgressView(); Text("Testing…") }
          } else {
            Text("Test Connection")
          }
        }
        .disabled(!session.isConfigured || isTestingConnection)

        if let result = testResult {
          VStack(alignment: .leading, spacing: 6) {
            Text(result.title)
              .font(.headline)
            Text(result.message)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
      }

      Section("Security") {
        Button(role: .destructive) {
          profiles.clearAllSecrets()
        } label: {
          Text("Clear Stored Tokens")
        }
      }

      Section("Appearance") {
        Toggle("Compact rows", isOn: $preferences.compactRows)
      }
    }
    .navigationTitle("Settings")
    .sheet(isPresented: $isPresentingNew) {
      NavigationStack {
        EditProfileView(
          initial: PlaneProfile(
            name: "",
            apiBaseURLString: "",
            webBaseURLString: "",
            workspaceSlug: ""
          ),
          isNew: true
        ) { profile, apiKey in
          try profiles.upsertProfile(profile, apiKey: apiKey)
          isPresentingNew = false
        }
      }
      .environmentObject(profiles)
    }
    .sheet(item: $editingProfile) { profile in
      NavigationStack {
        EditProfileView(initial: profile, isNew: false) { updated, apiKey in
          try profiles.upsertProfile(updated, apiKey: apiKey)
          editingProfile = nil
        }
      }
      .environmentObject(profiles)
    }
  }

  private func testConnection() async {
    isTestingConnection = true
    defer { isTestingConnection = false }
    do {
      let user = try await session.testConnection()
      testResult = .success(user: user)
    } catch {
      let apiError = error as? PlaneAPIError ?? .unknown(error)
      testResult = .failure(message: apiError.userFacingMessage)
    }
  }
}

struct ConnectionTestResult: Hashable, Identifiable {
  let id = UUID()
  let title: String
  let message: String

  static func success(user: PlaneUser) -> ConnectionTestResult {
    let who = user.displayName ?? user.email ?? user.id
    return ConnectionTestResult(title: "Connected", message: "Authenticated as \(who).")
  }

  static func failure(message: String) -> ConnectionTestResult {
    ConnectionTestResult(title: "Failed", message: message)
  }
}
