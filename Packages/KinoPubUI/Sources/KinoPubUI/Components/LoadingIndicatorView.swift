//
//  LoadingIndicatorView.swift
//
//

import SwiftUI

/// The spinner every loading surface uses, held back for a beat so a fast response
/// shows content instead of a flash of chrome. The Apple TV app does the same: an
/// empty screen first, a spinner only once the wait becomes noticeable.
public struct LoadingIndicatorView: View {

  private let delay: Duration

  @State private var isVisible: Bool = false

  /// - Parameter delay: how long the screen stays empty before the spinner appears.
  public init(delay: Duration = .milliseconds(300)) {
    self.delay = delay
  }

  public var body: some View {
    ProgressView()
#if !os(tvOS)
      .tint(Color.KinoPub.text)
#endif
      .controlSize(.large)
      .opacity(isVisible ? 1 : 0)
      .animation(.easeIn(duration: 0.2), value: isVisible)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .task {
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled else { return }
        isVisible = true
      }
  }
}

#Preview {
  LoadingIndicatorView()
    .background(Color.KinoPub.background)
}
