//
//  HudToast.swift
//  KinoPubUI
//
//  Apple Music / system HUD confirmation: centered Glyph + Title in a plain
//  squircle. Overlay on every platform — only macOS can host a real
//  `.windowStyle(.plain)` floating window, and tvOS has no secondary windows.
//

import SwiftUI

/// Transient confirmation shown after a library action (watchlist, bookmark,
/// watched, clear). Replacing the value while one is up restarts the timer.
public struct HudToast: Identifiable, Equatable {
  public let id: UUID
  public let systemImage: String
  public let title: String

  public init(systemImage: String, title: String) {
    self.id = UUID()
    self.systemImage = systemImage
    self.title = title
  }
}

/// Visual atom: SF Symbol over a short title, matching Apple's Alerts / Light /
/// Glyph + Title composition.
public struct HudToastView: View {
  private let systemImage: String
  private let title: String

  public init(systemImage: String, title: String) {
    self.systemImage = systemImage
    self.title = title
  }

  public var body: some View {
    VStack(spacing: Metrics.hudGlyphTitleSpacing) {
      Image(systemName: systemImage)
        .font(.system(size: Metrics.hudGlyphPointSize, weight: .medium))
        .symbolRenderingMode(.monochrome)
      Text(title)
        .font(TypeScale.actionLabel)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
    }
    .foregroundStyle(Color.KinoPub.text)
    .padding(.horizontal, Metrics.hudContentInset)
    .padding(.vertical, Metrics.hudContentInset)
    .frame(width: Metrics.hudSide, height: Metrics.hudSide)
    .kinoPlayerGlass(in: RoundedRectangle(cornerRadius: Metrics.hudCornerRadius,
                                          style: .continuous))
    .shadow(color: .black.opacity(0.35), radius: 24, y: 10)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isStaticText)
  }
}

public extension View {
  /// Centers a non-interactive Glyph + Title HUD over the receiver and auto-hides
  /// it. Hit-testing is off so tvOS focus stays on the control that fired it.
  func hudToast(_ item: Binding<HudToast?>) -> some View {
    modifier(HudToastModifier(item: item))
  }
}

private struct HudToastModifier: ViewModifier {
  @Binding var item: HudToast?
  @State private var visible: HudToast?
  @State private var dismissTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .overlay {
        ZStack {
          if let visible {
            HudToastView(systemImage: visible.systemImage, title: visible.title)
              .transition(.opacity.combined(with: .scale(scale: 0.92)))
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
      }
      .animation(.easeOut(duration: 0.22), value: visible?.id)
      .onChange(of: item?.id) { _, _ in
        present(item)
      }
#if os(iOS)
      .sensoryFeedback(.success, trigger: visible?.id) { _, id in id != nil }
#endif
  }

  private func present(_ toast: HudToast?) {
    guard let toast else { return }
    dismissTask?.cancel()
    visible = toast
    item = nil
    AccessibilityNotification.Announcement(toast.title).post()
    dismissTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(1.6))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.2)) {
        visible = nil
      }
    }
  }
}

#Preview("HUD") {
  ZStack {
    Color.KinoPub.background.ignoresSafeArea()
    HudToastView(systemImage: "checkmark", title: "Removed")
  }
}
