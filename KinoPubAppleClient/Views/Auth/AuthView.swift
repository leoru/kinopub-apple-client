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
/// error toasts; a failure just keeps the spinner going while the code is fetched again.
struct AuthView: View {

  @StateObject var model: AuthModel

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
        codeView
        footer
      }
      .padding(.horizontal, Metrics.horizontalPadding)
      .frame(maxWidth: Metrics.contentWidth)
    }
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

#if os(tvOS)
      if !model.verificationURL.isEmpty {
        Text(model.verificationURL)
          .font(Metrics.urlFont)
          .foregroundStyle(.primary)
      }
#endif
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var codeView: some View {
    HStack(spacing: Metrics.tileSpacing) {
      ForEach(Array(model.deviceCode.enumerated()), id: \.offset) { _, character in
        Text(String(character))
          .font(.system(size: Metrics.tileFontSize, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary)
          .frame(width: Metrics.tileSize.width, height: Metrics.tileSize.height)
          // Quaternary fill, not a material: with a static backdrop a material has nothing to blur
          // and the tiles sink into the background.
          .background(.quaternary, in: RoundedRectangle(cornerRadius: Metrics.tileCornerRadius,
                                                        style: .continuous))
      }
    }
    .animation(.default, value: model.deviceCode)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Auth_DeviceCode"))
    .accessibilityValue(Text(model.deviceCode.map(String.init).joined(separator: " ")))
  }

  /// A spinner while the next code is on its way, the system button everywhere a browser exists.
  /// Fixed height so the layout does not jump when the two swap.
  private var footer: some View {
    ZStack {
      if model.isRefreshing {
        ProgressView()
#if os(tvOS)
          .scaleEffect(1.5)
#endif
      } else {
#if !os(tvOS)
        Button("Auth_Activate") {
          model.openActivationURL()
        }
#endif
      }
    }
    .frame(height: Metrics.footerHeight)
    .animation(.default, value: model.isRefreshing)
  }
}

private enum Metrics {
#if os(tvOS)
  static let blockSpacing: CGFloat = 44
  static let headerSpacing: CGFloat = 14
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
#else
  static let blockSpacing: CGFloat = 28
  static let headerSpacing: CGFloat = 10
  static let horizontalPadding: CGFloat = 24
  static let contentWidth: CGFloat = 460
  static let titleFont: Font = .title2.weight(.semibold)
  static let descriptionFont: Font = .footnote
  static let urlFont: Font = .subheadline.weight(.semibold)
  static let tileSpacing: CGFloat = 8
  static let tileSize = CGSize(width: 48, height: 64)
  static let tileCornerRadius: CGFloat = 10
  static let tileFontSize: CGFloat = 32
  static let footerHeight: CGFloat = 44
#endif
}
