#if os(tvOS)
//
//  TVUIKitPersonAvatar.swift
//  KinoPubUI
//
//  A single person circle, outside a collection — the person page's hero.
//
//  Same component as the cast rail, deliberately: `TVMonogramContentConfiguration` is
//  what draws a person on tvOS, and the page you land on after selecting a face in the
//  rail must not show that face in a different shape. Title and subtitle stay nil here
//  because the hero already prints the name and role beside the circle; the
//  configuration draws the circle, the photo, and the initials fallback.
//

import SwiftUI
import UIKit
import TVUIKit

public struct TVUIKitPersonAvatar: UIViewRepresentable {
  public let name: String
  public let photoURL: URL?
  public let diameter: CGFloat

  public init(name: String, photoURL: URL?, diameter: CGFloat) {
    self.name = name
    self.photoURL = photoURL
    self.diameter = diameter
  }

  public func makeUIView(context: Context) -> TVUIKitPersonAvatarView {
    let view = TVUIKitPersonAvatarView()
    view.configure(name: name, photoURL: photoURL)
    return view
  }

  public func updateUIView(_ view: TVUIKitPersonAvatarView, context: Context) {
    view.configure(name: name, photoURL: photoURL)
  }

  public func sizeThatFits(_ proposal: ProposedViewSize,
                           uiView: TVUIKitPersonAvatarView,
                           context: Context) -> CGSize? {
    CGSize(width: diameter, height: diameter)
  }
}

@MainActor
public final class TVUIKitPersonAvatarView: UIView {
  /// Built through `makeContentView()` rather than an initializer: that is the
  /// `UIContentConfiguration` contract, and it works the same whether or not the
  /// framework exposes a Swift init for the content view itself.
  private let content: UIView & UIContentView
  private var imageTask: Task<Void, Never>?
  private var currentURL: URL?

  public override init(frame: CGRect) {
    content = TVMonogramContentConfiguration.cell().makeContentView()
    super.init(frame: frame)
    content.translatesAutoresizingMaskIntoConstraints = false
    addSubview(content)
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: topAnchor),
      content.bottomAnchor.constraint(equalTo: bottomAnchor),
      content.leadingAnchor.constraint(equalTo: leadingAnchor),
      content.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])
  }

  public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  public func configure(name: String, photoURL: URL?) {
    imageTask?.cancel()
    imageTask = nil
    currentURL = photoURL

    var config = TVMonogramContentConfiguration.cell()
    config.personNameComponents = TVUIKitPerson.nameComponents(from: name)
    config.image = TVUIKitRemoteImage.cached(url: photoURL)
    content.configuration = config

    guard let url = photoURL else {
      ArtworkLog.skipped(by: "person-hero/\(name)", reason: "no photo URL")
      return
    }
    if config.image != nil {
      ArtworkLog.servedFromMemory(url, by: "person-hero/\(name)")
      return
    }
    ArtworkLog.requested(url, by: "person-hero/\(name)")
    imageTask = Task { [weak self] in
      let image = await TVUIKitRemoteImage.load(url: url)
      await MainActor.run {
        guard let self, self.currentURL == url, let image,
              var config = self.content.configuration as? TVMonogramContentConfiguration
        else { return }
        config.image = image
        self.content.configuration = config
      }
    }
  }

  deinit {
    imageTask?.cancel()
  }
}
#endif
