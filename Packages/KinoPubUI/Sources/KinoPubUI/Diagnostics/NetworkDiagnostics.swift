//
//  NetworkDiagnostics.swift
//  KinoPubUI
//
//  The network log: every API request, with headers, full bodies, timing and errors,
//  kept across launches and readable on the device.
//
//  This exists because the previous answer to "what did kino.pub actually reply" was
//  `ResponseLoggingPlugin`, which logs one line — status, URL, byte count — and says in
//  its own doc comment that bodies are not dumped. On an Apple TV, with no Xcode
//  attached, that is not enough to tell a slow launch from a failing one.
//
//  **Not telemetry.** Nothing leaves the device unless streaming is switched on by hand:
//  a local store the user reads or exports. The AGENTS.md rule against third-party
//  telemetry SDKs is about sending data somewhere, and is untouched by this.
//
//  Capture is by swizzling `URLSession` (`NetworkLogger.enableProxy`), which is what
//  catches tasks while they are still in flight and covers every client in the app in one
//  call. **Artwork and media are then filtered back out** — see `configuration`.
//

import Foundation
import Pulse
import PulseProxy

public enum NetworkDiagnostics {

  private static var isStarted = false

  /// Call once, as early in launch as possible — requests made before this are not
  /// recorded. Safe to call again; the second call does nothing.
  public static func start() {
    guard !isStarted else { return }
    isStarted = true
    NetworkLogger.enableProxy(logger: NetworkLogger(store: store, configuration: configuration))
  }

  // MARK: - The store

  /// Our own store rather than `LoggerStore.shared`, which is created with Pulse's
  /// defaults and cannot be reconfigured afterwards. Those defaults are why log files
  /// reached tens of megabytes: **256 MB** of store and **8 MB** per response body.
  ///
  /// An API log does not need that. The largest thing kino.pub returns is a history page
  /// at roughly 96 KB, so half a megabyte per body is already generous, and 32 MB of
  /// store holds far more history than anyone reads.
  ///
  /// Lives in `Caches/`: it is regenerable diagnostic data, and on tvOS that is the only
  /// place an app may put a file of this size — the system purges it between runs, which
  /// is the documented tvOS trade and not a bug to chase.
  public static let store: LoggerStore = {
    var configuration = LoggerStore.Configuration()
    configuration.sizeLimit = 32 * 1024 * 1024
    configuration.responseBodySizeLimit = 512 * 1024

    let url = URL.cachesDirectory.appending(path: "kinopub-network-log", directoryHint: .isDirectory)
    guard let store = try? LoggerStore(storeURL: url, options: [.create, .sweep], configuration: configuration)
    else {
      // Falling back means the limits above do not apply. Better a log with Pulse's
      // defaults than no log, but say so rather than pretending the cap held.
      assertionFailure("Network log store could not be created at \(url); falling back to Pulse defaults")
      return .shared
    }
    return store
  }()

  // MARK: - What is worth recording

  /// Two jobs: redact credentials, and keep bytes we would never read out of the store.
  ///
  /// **Artwork and media are excluded at capture.** The proxy sees every `URLSession`
  /// task, so a single Home screen buried the API calls under dozens of poster requests,
  /// and their bodies are what made the store enormous. A picture in a log answers no
  /// question that its status line has not already answered, and an HLS playlist or
  /// segment answers none at all.
  ///
  /// Both host and extension patterns are here on purpose: hosts catch artwork served
  /// without a file extension, extensions catch a CDN we have not met yet. Patterns are
  /// anchored wildcards (`^…$`), hence the trailing `*` — without it a query string
  /// defeats the match.
  private static var configuration: NetworkLogger.Configuration {
    var configuration = NetworkLogger.Configuration()

    // The store is exportable and gets shared, so credentials are redacted at capture
    // rather than at export — a redaction you have to remember to apply is one you will
    // forget.
    configuration.sensitiveHeaders = ["Authorization", "Cookie", "Set-Cookie"]
    configuration.sensitiveQueryItems = ["access_token", "refresh_token", "api_key"]
    configuration.sensitiveDataFields = ["access_token", "refresh_token", "password"]

    // kino.pub serves the same artwork from several domains and adds new ones over time
    // (`m.staticpop.net`, `m.boramoraboom.ru`, `m.pushbr.com` seen so far), so this list
    // is *known incomplete* — the extension patterns below are the real safety net.
    // See `docs/providers/kinopub/intro.md`.
    configuration.excludedHosts = [
      "*.staticpop.net",
      "*.boramoraboom.ru",
      "*.pushbr.com",
      "image.tmdb.org",
      "*.mds.yandex.net"     // Kinopoisk stills, via the proxy
    ]
    configuration.excludedURLs = [
      "*.jpg*", "*.jpeg*", "*.png*", "*.webp*", "*.gif*", "*.avif*",
      "*.m3u8*", "*.ts*", "*.mp4*", "*.mkv*", "*.m4s*"
    ]
    return configuration
  }

  // MARK: - Streaming to the Pulse app on a Mac

  /// Live-streams this store to the Pulse macOS app over Bonjour (`_pulse._tcp`).
  ///
  /// This is the **only** reader on macOS, where `PulseUI` ships no console — and it is
  /// the better one on tvOS too, since reading a log on a television with a remote is
  /// nobody's idea of a good time.
  ///
  /// Off by default and never called at launch unless the user left it on: discovery asks
  /// for local-network permission, and a diagnostic must not spend the user's first-run
  /// prompts. Auto-connect is on once enabled — picking a server needs
  /// `RemoteLoggerSettingsView`, which Pulse keeps internal, so "first one found, then
  /// remembered" is the whole selection model available to us. Re-probe if that view
  /// becomes public.
  ///
  /// - Note: `RemoteLogger` is `@MainActor`, so this is too.
  @MainActor
  public static func setRemoteLoggingEnabled(_ isEnabled: Bool) {
    guard isEnabled else {
      RemoteLogger.shared.disable()
      return
    }
    RemoteLogger.shared.initialize(store: store)
    RemoteLogger.shared.isAutomaticConnectionEnabled = true
    RemoteLogger.shared.enable()
  }

  // MARK: - What Settings shows

  /// Walks the store directory, so call it off a hot path.
  public static func storeBytes() async -> Int64 {
    (try? await store.info().totalStoreSize) ?? 0
  }

  public static func clear() {
    store.removeAll()
  }

  /// A `.pulse` file for the Pulse macOS app. Written to a temporary URL the caller is
  /// expected to hand to a share sheet; it is not cleaned up here.
  public static func exportStore() async throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("kinopub-\(Int(Date().timeIntervalSince1970)).pulse")
    try? FileManager.default.removeItem(at: url)
    try await store.export(to: url)
    return url
  }
}
