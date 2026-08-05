//
//  AuthView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 24.07.2023.
//
import SwiftUI
import KinoPubUI

/// Full-screen device activation, modelled on the system AirPlay-code screen: system type styles,
/// a material background, the code split into per-character tiles. There is no way out of it — the
/// app is unusable until the device is activated — so it carries no dismiss affordance and no
/// error toasts; a failure just keeps fetching a new code.
///
/// Layout never moves. The tiles are always on screen at their final size — empty while a code is
/// in flight — and the characters blur in when it lands, instead of a spinner that pushes the page
/// around every time the code is replaced.
struct AuthView: View {

  @StateObject var model: AuthModel
  @State private var isCodeHovered = false
  @FocusState private var activateFocused: Bool

  init(model: @autoclosure @escaping () -> AuthModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
    ZStack {
      // Static backdrop, not the live app behind glass: the catalog underneath used to blink
      // through the blur every time a poster or the hero swapped.
      Color.KinoPub.background
        .ignoresSafeArea()
      Rectangle()
        .fill(.ultraThinMaterial)
        .ignoresSafeArea()

      VStack(spacing: Metrics.blockSpacing) {
        header
        VStack(spacing: Metrics.codeBlockSpacing) {
          codeView
          expiryRing
        }
        footer
      }
      .padding(.horizontal, Metrics.horizontalPadding)
      .frame(maxWidth: Metrics.contentWidth)
    }
    .hudToast($model.hudToast)
    .task {
      await model.run()
    }
  }

  private var header: some View {
    VStack(spacing: Metrics.headerSpacing) {
      Text("Auth_CodeActivationTitle")
        .font(Metrics.titleFont)
        .foregroundStyle(.primary)

      Text("Auth_CodeActivationText")
        .font(Metrics.descriptionFont)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      // Where to type it, on every platform. Even next to an Activate button that opens
      // the page for you, the address is what tells you where you are being sent — and
      // it is the only route left when the button opens the wrong browser.
      if !model.verificationURL.isEmpty {
        Text(model.verificationURL)
          .font(Metrics.urlFont)
          .foregroundStyle(.primary)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  // MARK: - Code

  /// The whole block is the copy target — there is no Copy button. Hovering lifts every
  /// tile at once (one gesture over the block, not per character), and a click copies.
  @ViewBuilder
  private var codeView: some View {
#if os(tvOS)
    codeTiles
#else
    Button {
      model.copyCode()
    } label: {
      codeTiles
    }
    .buttonStyle(.plain)
    .disabled(!model.canCopyCode)
    .onHover { isCodeHovered = $0 }
    .animation(.easeOut(duration: 0.15), value: isCodeHovered)
    .help("Copy")
#endif
  }

  private var codeTiles: some View {
    HStack(spacing: Metrics.tileSpacing) {
      ForEach(0..<max(model.deviceCode.count, Metrics.placeholderTiles), id: \.self) { index in
        tile(character(at: index))
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Auth_DeviceCode"))
    .accessibilityValue(Text(model.deviceCode.map(String.init).joined(separator: " ")))
  }

  private func tile(_ character: Character?) -> some View {
    ZStack {
      if let character {
        Text(String(character))
          .font(.system(size: Metrics.tileFontSize, weight: .semibold, design: .rounded))
          // Characters swap in place: the tile is already there at full size, so a new
          // code dissolves through blur instead of relaying the screen out.
          .transition(.blurReplace)
      }
    }
    // The code is the point of this screen — it is never dimmed. Hover lifts the tile
    // behind it, not the glyph.
    .foregroundStyle(.primary)
    .frame(width: Metrics.tileSize.width, height: Metrics.tileSize.height)
    // Quaternary fill, not a material: with a static backdrop a material has nothing to blur
    // and the tiles sink into the background.
    .background(tileFill, in: RoundedRectangle(cornerRadius: Metrics.tileCornerRadius,
                                               style: .continuous))
    .animation(.easeOut(duration: 0.25), value: model.deviceCode)
  }

  private var tileFill: AnyShapeStyle {
    isCodeHovered ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary)
  }

  private func character(at index: Int) -> Character? {
    let code = model.deviceCode
    guard index < code.count else { return nil }
    return code[code.index(code.startIndex, offsetBy: index)]
  }

  /// Width the code block occupies, so the Activate button can match it exactly.
  private var codeWidth: CGFloat {
    let count = CGFloat(max(model.deviceCode.count, Metrics.placeholderTiles))
    return count * Metrics.tileSize.width + (count - 1) * Metrics.tileSpacing
  }

  // MARK: - Expiry

  /// Draining ring plus the remaining time in figures. The ring alone reads as a
  /// spinner — it says something is running, not how long is left — so it is the
  /// glanceable half and the number is the precise half.
  @ViewBuilder
  private var expiryRing: some View {
    ZStack {
      if let range = model.codeValidRange {
        TimelineView(.periodic(from: range.lowerBound, by: 1)) { context in
          let total = range.upperBound.timeIntervalSince(range.lowerBound)
          let left = max(0, range.upperBound.timeIntervalSince(context.date))
          let fraction = total > 0 ? left / total : 0

          HStack(spacing: Metrics.ringSpacing) {
            ZStack {
              Circle()
                .stroke(.quaternary, lineWidth: Metrics.ringLineWidth)
              Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.KinoPub.accent,
                        style: StrokeStyle(lineWidth: Metrics.ringLineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            }
            .frame(width: Metrics.ringSize, height: Metrics.ringSize)

            Text(Duration.seconds(left).formatted(.time(pattern: .minuteSecond)))
              .font(Metrics.expiryFont)
              .monospacedDigit()
              .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel(Text("Auth_DeviceCode"))
          .accessibilityValue(Text(Duration.seconds(left).formatted(.time(pattern: .minuteSecond))))
        }
      }
    }
    .frame(height: Metrics.ringRowHeight)
  }

  // MARK: - Footer

  /// Always present at a fixed size — the code arriving must not move it. Activation
  /// copies the code on the way out, so the site opens with it already on the clipboard.
  @ViewBuilder
  private var footer: some View {
#if !os(tvOS)
    Button {
      model.activate()
    } label: {
      Text("Auth_Activate")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.glassProminent)
    .controlSize(.large)
    .keyboardShortcut(.defaultAction)
    .focused($activateFocused)
    .disabled(model.deviceCode.isEmpty)
    .frame(width: codeWidth, height: Metrics.footerHeight)
    .onAppear { activateFocused = true }
#else
    Color.clear
      .frame(height: Metrics.footerHeight)
#endif
  }
}

private enum Metrics {
#if os(tvOS)
  static let blockSpacing: CGFloat = 44
  static let headerSpacing: CGFloat = 14
  static let codeBlockSpacing: CGFloat = 20
  static let horizontalPadding: CGFloat = 90
  static let contentWidth: CGFloat = 820
  static let titleFont: Font = .title2.weight(.semibold)
  static let descriptionFont: Font = .caption
  static let urlFont: Font = .body.weight(.semibold)
  static let tileSpacing: CGFloat = 16
  static let tileSize = CGSize(width: 92, height: 120)
  static let tileCornerRadius: CGFloat = 18
  static let tileFontSize: CGFloat = 60
  static let footerHeight: CGFloat = 60
  static let ringSize: CGFloat = 22
  static let ringLineWidth: CGFloat = 3
  static let ringSpacing: CGFloat = 10
  static let ringRowHeight: CGFloat = 30
  static let expiryFont: Font = .caption
#else
  static let blockSpacing: CGFloat = 28
  static let headerSpacing: CGFloat = 10
  static let codeBlockSpacing: CGFloat = 16
  static let horizontalPadding: CGFloat = 24
  static let contentWidth: CGFloat = 460
  static let titleFont: Font = .largeTitle.weight(.semibold)
  static let descriptionFont: Font = .body
  static let urlFont: Font = .body.weight(.medium)
  static let tileSpacing: CGFloat = 8
  static let tileSize = CGSize(width: 48, height: 64)
  static let tileCornerRadius: CGFloat = 10
  static let tileFontSize: CGFloat = 32
  static let footerHeight: CGFloat = 44
  static let ringSize: CGFloat = 13
  static let ringLineWidth: CGFloat = 2
  static let ringSpacing: CGFloat = 6
  static let ringRowHeight: CGFloat = 18
  static let expiryFont: Font = .caption
#endif

  /// kino.pub device codes are five characters. Drawing that many empty tiles up front
  /// is what keeps the first code from resizing the screen when it lands.
  static let placeholderTiles = 5
}
