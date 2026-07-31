//
//  DownloadNotificationManager.swift
//  KinoPubKit
//
//  Local notifications for finished / failed downloads. iOS only — on macOS the type is a no-op
//  stub so call sites stay platform-agnostic.
//

import Foundation
import OSLog
import KinoPubLogging

public extension Notification.Name {
  /// Posted when the user taps a download notification, so the UI can open the Downloads screen.
  static let openDownloads = Notification.Name("com.kinopub.openDownloads")
}

#if os(iOS)
import UserNotifications

/// Posts a local notification when a background download finishes or fails, so the user is told
/// even when the app isn't in the foreground. Hook it up via `DownloadManager.onDownloadFinished`.
public final class DownloadNotificationManager: NSObject, ObservableObject {

  @Published public private(set) var permissionGranted: Bool = false

  private let center = UNUserNotificationCenter.current()

  public override init() {
    super.init()
    center.delegate = self
    refreshPermission()
  }

  /// Asks the user for permission to post download notifications. Safe to call repeatedly.
  @discardableResult
  public func requestPermission() async -> Bool {
    do {
      let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
      await MainActor.run { self.permissionGranted = granted }
      return granted
    } catch {
      Logger.kit.error("[NOTIFICATIONS] Authorization request failed: \(error)")
      return false
    }
  }

  /// Notifies the user that a download finished. `title` is a human-readable label (e.g. "S1E3 · Title").
  public func notifyFinished(title: String, identifier: String) {
    let content = UNMutableNotificationContent()
    content.title = NSLocalizedString("Download complete", comment: "")
    content.body = title
    content.sound = .default
    post(content, identifier: "download_done_\(identifier)")
  }

  /// Notifies the user that a download failed.
  public func notifyFailed(title: String, identifier: String) {
    let content = UNMutableNotificationContent()
    content.title = NSLocalizedString("Download failed", comment: "")
    content.body = title
    content.sound = .default
    post(content, identifier: "download_failed_\(identifier)")
  }

  /// Notifies the user that a whole season finished downloading.
  public func notifySeasonFinished(title: String, identifier: String) {
    let content = UNMutableNotificationContent()
    content.title = NSLocalizedString("Season downloaded", comment: "")
    content.body = title
    content.sound = .default
    post(content, identifier: "season_done_\(identifier)")
  }

  private func post(_ content: UNMutableNotificationContent, identifier: String) {
    guard permissionGranted else { return }
    let request = UNNotificationRequest(identifier: identifier,
                                        content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false))
    center.add(request) { error in
      if let error { Logger.kit.error("[NOTIFICATIONS] Failed to post \(identifier): \(error)") }
    }
  }

  private func refreshPermission() {
    center.getNotificationSettings { [weak self] settings in
      DispatchQueue.main.async {
        self?.permissionGranted = settings.authorizationStatus == .authorized ||
                                  settings.authorizationStatus == .provisional
      }
    }
  }
}

extension DownloadNotificationManager: UNUserNotificationCenterDelegate {
  // Show the banner even when the app is in the foreground.
  public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  // Tapping a download notification opens the Downloads screen.
  public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     didReceive response: UNNotificationResponse,
                                     withCompletionHandler completionHandler: @escaping () -> Void) {
    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .openDownloads, object: nil)
    }
    completionHandler()
  }
}

#else

/// macOS no-op stub so shared code can reference the manager without platform checks.
public final class DownloadNotificationManager: NSObject, ObservableObject {
  @Published public private(set) var permissionGranted: Bool = false
  public override init() { super.init() }
  @discardableResult public func requestPermission() async -> Bool { false }
  public func notifyFinished(title: String, identifier: String) {}
  public func notifyFailed(title: String, identifier: String) {}
  public func notifySeasonFinished(title: String, identifier: String) {}
}

#endif
