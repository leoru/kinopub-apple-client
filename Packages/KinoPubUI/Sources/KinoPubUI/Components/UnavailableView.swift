//
//  UnavailableView.swift
//

import SwiftUI

/// The one unavailable-content state, built on the system `ContentUnavailableView`:
/// symbol, title, optional description, optional actions. Used for load failures
/// (retry button included), empty lists and empty searches alike — same look
/// everywhere, no hand-styled stand-ins.
///
/// Full-screen only when there is no content to show. A failed page deep in a
/// paginated grid never swaps loaded items for this view — it surfaces as a toast
/// plus an inline retry at the bottom of the grid.
public struct UnavailableView: View {

  private let title: LocalizedStringKey
  private let systemImage: String
  private let message: String?
  private let retryTitle: LocalizedStringKey?
  private let onRetry: (() -> Void)?
  private let secondaryTitle: LocalizedStringKey?
  private let onSecondary: (() -> Void)?

  /// The remote needs somewhere to land when this is the only thing on screen.
  @FocusState private var retryFocused: Bool

  public init(
    title: LocalizedStringKey,
    systemImage: String,
    message: String? = nil,
    retryTitle: LocalizedStringKey? = nil,
    onRetry: (() -> Void)? = nil,
    secondaryTitle: LocalizedStringKey? = nil,
    onSecondary: (() -> Void)? = nil
  ) {
    self.title = title
    self.systemImage = systemImage
    self.message = message
    self.retryTitle = retryTitle
    self.onRetry = onRetry
    self.secondaryTitle = secondaryTitle
    self.onSecondary = onSecondary
  }

  public var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
    } description: {
      if let message {
        Text(message)
      }
    } actions: {
      HStack(spacing: 16) {
        if let retryTitle, let onRetry {
          Button(retryTitle, action: onRetry)
            .focused($retryFocused)
#if !os(tvOS)
            .buttonStyle(.glass)
            .controlSize(.large)
#endif
        }

        if let secondaryTitle, let onSecondary {
          Button(secondaryTitle, action: onSecondary)
#if !os(tvOS)
            .buttonStyle(.glass)
            .controlSize(.large)
#endif
        }
      }
    }
    .onAppear {
      retryFocused = true
    }
  }
}

#Preview {
  UnavailableView(title: "Couldn't Load",
                  systemImage: "wifi.exclamationmark",
                  message: "Check your connection and try again.",
                  retryTitle: "Try Again",
                  onRetry: {})
    .background(Color.KinoPub.background)
}
