//
//  LoadFailedView.swift
//

import SwiftUI

/// Empty state when a screen failed to load: short copy and a focusable retry button.
/// Pair with `LoadingIndicatorView` — spinner while waiting, this once the request fails.
public struct LoadFailedView: View {

  private let title: LocalizedStringKey
  private let message: LocalizedStringKey
  private let retryTitle: LocalizedStringKey
  private let onRetry: () -> Void
  private let secondaryTitle: LocalizedStringKey?
  private let onSecondary: (() -> Void)?

  @FocusState private var retryFocused: Bool

  public init(
    title: LocalizedStringKey = "Couldn't Load",
    message: LocalizedStringKey = "Check your connection and try again.",
    retryTitle: LocalizedStringKey = "Try Again",
    onRetry: @escaping () -> Void,
    secondaryTitle: LocalizedStringKey? = nil,
    onSecondary: (() -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.retryTitle = retryTitle
    self.onRetry = onRetry
    self.secondaryTitle = secondaryTitle
    self.onSecondary = onSecondary
  }

  public var body: some View {
    VStack(spacing: 20) {
      Text(title)
        .font(.title2.weight(.semibold))
        .foregroundStyle(Color.KinoPub.text)
        .multilineTextAlignment(.center)

      Text(message)
        .font(.body)
        .foregroundStyle(Color.KinoPub.subtitle)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 480)

      HStack(spacing: 16) {
        Button(retryTitle, action: onRetry)
          .focused($retryFocused)

        if let secondaryTitle, let onSecondary {
          Button(secondaryTitle, action: onSecondary)
        }
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      retryFocused = true
    }
  }
}

#Preview {
  LoadFailedView(onRetry: {})
    .background(Color.KinoPub.background)
}
