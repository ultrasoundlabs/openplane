# PlaneMobile (iOS)

Minimal SwiftUI client for the Plane Community Edition REST API using Personal Access Tokens.

## Requirements

- macOS with Xcode installed (this repo currently assumes Xcode is available)
- A Plane instance (self-hosted or Plane Cloud) and a Personal Access Token

## Generate the Xcode project

From repo root:

```sh
cd ios/PlaneMobile
xcodegen generate
open PlaneMobile.xcodeproj
```

## Configure in-app

In the app, set:

- **Base URL**: Your Plane server base (e.g. `https://plane.example.com` or `https://api.plane.so`)
- **Workspace slug**: The slug in your Plane URL (e.g. `my-team`)
- **Personal Access Token**: Your token (the app sends it as `X-API-Key`)

