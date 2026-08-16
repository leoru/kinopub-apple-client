//
//  NetworkActivityOverlay.swift
//  KinoPubUI
//
//  "What are we waiting for", on screen, while we wait for it.
//
//  Diagnostics, not product chrome: it is off unless switched on, and it does not decide
//  anything about how a loading state should look. The launch-status label the 2026-08-10
//  plan sketched is a separate, product decision that has not been taken — this is the
//  channel that makes the question answerable in the meantime.
//

import SwiftUI
import Combine
import KinoPubLogging

public struct NetworkActivityOverlay: View {
  @StateObject private var activity = NetworkActivity.shared
  /// Redrawn on a timer because the interesting number — how long a request has been
  /// outstanding — changes with the clock and not with any state we publish.
  @State private var now = Date()

  private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

  public init() {}

  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(activity.inFlight) { entry in
        HStack(spacing: 8) {
          // The path, not the friendly name: this overlay is for whoever is debugging,
          // and "Activity_Catalog" three times says less than three distinct paths.
          Text(entry.detail.isEmpty ? entry.nameKey : entry.detail)
            .fontWeight(.medium)
            .lineLimit(1)
            .truncationMode(.head)
          Spacer(minLength: 12)
          Text(elapsed(entry.elapsed(at: now)))
            .monospacedDigit()
            .foregroundStyle(entry.elapsed(at: now) > 3 ? .orange : .secondary)
        }
      }
    }
    .font(.caption)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .foregroundStyle(.white)
    .frame(maxWidth: 360, alignment: .leading)
    .opacity(activity.inFlight.isEmpty ? 0 : 1)
    .animation(.easeOut(duration: 0.15), value: activity.inFlight.count)
    .allowsHitTesting(false)
    .onReceive(timer) { now = $0 }
  }

  private func elapsed(_ interval: TimeInterval) -> String {
    String(format: "%.1fs", interval)
  }
}

public extension View {
  /// Pins the in-flight readout to a corner of the whole app. One call site, at the root.
  func networkActivityOverlay(isEnabled: Bool) -> some View {
    overlay(alignment: .topTrailing) {
      if isEnabled {
        NetworkActivityOverlay()
          .padding(.top, 8)
          .padding(.trailing, 12)
      }
    }
  }
}

#Preview("In flight") {
  ZStack {
    Color.KinoPub.background
    NetworkActivityOverlay()
  }
  .task {
    _ = NetworkActivity.begin(nameKey: "Activity_History", detail: "/v1/history")
    _ = NetworkActivity.begin(nameKey: "Activity_Watching", detail: "/v1/watching/serials")
    _ = NetworkActivity.begin(nameKey: "Activity_Session", detail: "/v1/user")
  }
  .preferredColorScheme(.dark)
}
