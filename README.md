# kino.pub Apple Cross-Platform Client

This is the iOS, iPadOS and macOS client for the kino.pub service built with SwiftUI. 

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