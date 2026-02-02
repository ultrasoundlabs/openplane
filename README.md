# OpenPlane ✈️

Native, tiny & open-source iOS app for Plane.so Community Edition, including cloud and self-hosted instances.

## What

OpenPlane is a simple SwiftUI iOS app that acts as a client to [Plane Community Edition's REST API](https://developers.plane.so/api-reference/introduction). Plane is an open-source alternative to Jira, Linear, and such productivity-maxxing corpoapps. You can self-host Plane on your server and then use OpenPlane to access it via mobile.

## Why

Plane's official mobile app is closed-source and [only works with the Commercial Edition](https://docs.plane.so/devices/mobile) (i.e. paid enterprise offering). For the free Community Edition, you have to use their web UI. It works ugly on mobile. OpenPlane lets you work with any instance of the Community Edition from mobile using Personal Access Tokens.

## How

1. Self-host Plane on a cheap VPS via Docker Compose or Kubernetes [(link)](https://developers.plane.so/self-hosting/overview). It also needs an S3-compatible client. RustFS and SeaweedFS work, others should too.
2. Optionally hide it behind Tailscale. OpenPlane allows HTTP connections via Tailscale.
3. Enter the dashboard, sign up, create a PAT. Any duration works.
4. Clone this repo, enter it in Xcode, and sideload on your iPhone.
5. Enter the app, insert the workspace title, REST API and web UI URLs, and the PAT.
6. Done. You can browse your Plane workspace in a snappy & minimal mobile interface without web UI.

## Note

This app is fully vibecoded. [There are extensive E2E tests here](https://github.com/ultrasoundlabs/openplane/tree/main/ios/OpenPlane), so it's probably not terrible bugs-wise, but still treat this app as you would any other vibecoded app
