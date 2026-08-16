//
//  NetworkConsoleView.swift
//  KinoPubUI
//
//  The on-device reader for `NetworkDiagnostics` — request list, filters, and a full
//  inspector with headers, bodies and cURL.
//
//  **Adapter — third-party API limitation.** `PulseUI.ConsoleView` does not exist on
//  macOS in Pulse 5.2.3: the module ships `ConsoleView-ios`, `-tvos` and `-watchos`
//  only, and its public initialiser is fenced `#if !os(macOS)`. Capture still runs on
//  the Mac, so the Mac path is export — the `.pulse` file opens in the standalone Pulse
//  app, which is the reader Pulse intends there. Re-probe on the next Pulse major.
//

import SwiftUI
#if !os(macOS)
import PulseUI
#endif

public struct NetworkConsoleView: View {
  public init() {}

  public var body: some View {
#if os(macOS)
    MacNetworkConsolePlaceholder()
#else
    // Our store, not `LoggerStore.shared` — that is the one with the size caps.
    ConsoleView(store: NetworkDiagnostics.store)
#endif
  }
}

#if os(macOS)
/// Not a dead end: the export is the whole feature on this platform, so it is the
/// button, not a footnote under an apology.
private struct MacNetworkConsolePlaceholder: View {
  @State private var exported: URL?
  @State private var failure: String?

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.badge.arrow.up")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("The log reader is not available on macOS")
        .font(.headline)
      Text("Requests are still recorded here. Export the store and open it in the Pulse app.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button("Export log…") {
        Task {
          do { exported = try await NetworkDiagnostics.exportStore() }
          catch { failure = error.localizedDescription }
        }
      }
      .buttonStyle(.borderedProminent)

      if let exported {
        Text(exported.path)
          .font(.caption)
          .textSelection(.enabled)
          .foregroundStyle(.secondary)
      }
      if let failure {
        Text(failure)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
#endif
