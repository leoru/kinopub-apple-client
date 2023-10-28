# kino.pub Apple Cross-Platform Client

This is the iOS, iPadOS and macOS client for the kino.pub service built with SwiftUI. 

# Requirements

- macOS 13.0.
- Xcode 15.0.
- Swift 5.8.

# Supported Platforms

- iOS 16.0.
- macOS 13.0.

## App Structure

The app is structured using the Swift Package Manager with the following packages:

- `KinoPubAppleClient` - The main app target containing shared code across platforms.
- `KinoPubUI` - Reusable SwiftUI components.
- `KinoPubKit` - Shared business logic.
- `KinoPubBackend` - Networking layer.

The main app target KinoPubAppleClient contains the following folders:

- App - Application lifecycle code like app delegates.
- Resources - Resources like GoogleService-Info.plist.
- Views - SwiftUI view code organized by feature.
- Services - Services for things like analytics and networking.
- States - app states e.g. navigation, auth.
- Custom - various custom classes.
- Context - dependencies context e.g. services, managers.

## Third Party Libraries

The following third party libraries are used:

- [Firebase](https://firebase.google.com) - For authentication, analytics, crash reporting.
- [PopupView](https://github.com/exyte/PopupView) - For displaying popups and overlays.
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - For storing data in the keychain.
- [SkeletonUI](https://github.com/CSolanaM/SkeletonUI) - For rendering loading states.


## Packages

- `KinoPubUI` - Contains reusable SwiftUI components like buttons, texts, etc.
- `KinoPubKit` - Shared business logic for things like authentication and data models.
- `KinoPubBackend` - Networking layer that interfaces with the kino.pub API.
- `KinoPubLogging` - Small package containing extensions for OSLog.

# Contributing

- Suggest your idea as a [feature request](https://github.com/leoru/kinopub-apple-client/issues/new?assignees=&labels=&template=feature_request.md&title=) for this project.
- Create a [bug report](https://github.com/leoru/kinopub-apple-client/issues/new?assignees=&labels=&template=bug_report.md&title=) to help us improve.
- Propose your own fixes, suggestions and open a pull request with the changes.