# OpenPlane (iOS)

Minimal SwiftUI client for the Plane Community Edition REST API using Personal Access Tokens.

## Requirements

- macOS with Xcode installed (this repo currently assumes Xcode is available)
- A Plane instance (self-hosted or Plane Cloud) and a Personal Access Token

## Generate the Xcode project

From repo root:

```sh
cd ios/OpenPlane
xcodegen generate
open OpenPlane.xcodeproj
```

## Configure in-app

In the app, add a profile and set:

- **API Base URL**: Your Plane server base (e.g. `https://plane.example.com` or `https://api.plane.so`)
- **Web Base URL**: Your Plane UI base (e.g. `https://plane.example.com` or `https://app.plane.so`)
- **Workspace slug**: The slug in your Plane URL (e.g. `my-team`)
- **Personal Access Token**: Your token (the app sends it as `X-API-Key`)
- (Optional) **Work item path template**: For deep links. Example: `/{workspaceSlug}/work-items/{identifier}`

## Troubleshooting (Simulator)

If `xcodebuild` logs a CoreSimulator version mismatch (e.g. “CoreSimulator is out of date”), it usually means Xcode’s first-launch tasks (which install/update `/Library/Developer/...` components) haven’t been run with admin privileges.

Run:

```sh
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch -checkForNewerComponents
```

Then re-try:

```sh
xcrun simctl list devices
```
