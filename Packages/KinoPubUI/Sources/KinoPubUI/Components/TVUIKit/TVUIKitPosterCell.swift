#if os(tvOS)
//
//  TVUIKitPosterCell.swift
//  KinoPubUI
//
//  Rivulet-style `TVPosterView` wrapper: native focus motion, caption nil (TVUIKit
//  reserves footer space that crops 2:3 art), overlays in a sibling that mirrors
//  focus scale + stale-appearance reset.
//

import UIKit
import TVUIKit
import KinoPubUI

@MainActor
public final class TVUIKitPosterCell: UICollectionViewCell {
  public static let reuseID = "TVUIKitPosterCell"

  private let posterView = TVPosterView()
  private let overlayContainer = UIView()
  private let placeholderPanel = UIView()
  private let progressTrack = UIView()
  private let progressFill = UIView()
  private var bottomInfoBlur: TVUIKitBottomInfoBlurView?
  private let watchedGlyph = UIImageView()
  private let captionLabel = UILabel()

  private var imageTask: Task<Void, Never>?
  private var currentURL: URL?
  private var tileWidth: CGFloat = 296
  private var posterWidthConstraint: NSLayoutConstraint!
  private var posterHeightConstraint: NSLayoutConstraint!
  private var progressFillWidth: NSLayoutConstraint!

  public var contextMenuEntries: (() -> [MediaCardContextEntry])?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func setUp() {
    contentView.clipsToBounds = false
    clipsToBounds = false

    // Nil caption — TVPosterView otherwise reserves a footer and crops the poster.
    posterView.title = nil
    posterView.subtitle = nil
    posterView.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(posterView)

    overlayContainer.translatesAutoresizingMaskIntoConstraints = false
    overlayContainer.isUserInteractionEnabled = false
    overlayContainer.clipsToBounds = true
    overlayContainer.layer.cornerRadius = TVUIKitPosterMetrics.cornerRadius
    overlayContainer.layer.cornerCurve = .continuous
    contentView.addSubview(overlayContainer)

    placeholderPanel.translatesAutoresizingMaskIntoConstraints = false
    placeholderPanel.backgroundColor = UIColor(white: 0.12, alpha: 1)
    placeholderPanel.layer.cornerRadius = TVUIKitPosterMetrics.cornerRadius
    placeholderPanel.layer.cornerCurve = .continuous
    overlayContainer.addSubview(placeholderPanel)

    progressTrack.translatesAutoresizingMaskIntoConstraints = false
    progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.28)
    progressTrack.layer.cornerRadius = 3
    progressTrack.isHidden = true
    overlayContainer.addSubview(progressTrack)

    progressFill.translatesAutoresizingMaskIntoConstraints = false
    progressFill.backgroundColor = .white
    progressFill.layer.cornerRadius = 3
    progressTrack.addSubview(progressFill)

    watchedGlyph.translatesAutoresizingMaskIntoConstraints = false
    watchedGlyph.image = UIImage(systemName: "checkmark.circle.fill")
    watchedGlyph.tintColor = .white
    watchedGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
    watchedGlyph.isHidden = true
    overlayContainer.addSubview(watchedGlyph)

    captionLabel.translatesAutoresizingMaskIntoConstraints = false
    captionLabel.font = .preferredFont(forTextStyle: .callout)
    captionLabel.textColor = .white
    captionLabel.numberOfLines = 1
    captionLabel.textAlignment = .center
    captionLabel.enablesMarqueeWhenAncestorFocused = true
    captionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    captionLabel.alpha = 0
    contentView.addSubview(captionLabel)

    posterWidthConstraint = posterView.widthAnchor.constraint(equalToConstant: 296)
    posterHeightConstraint = posterView.heightAnchor.constraint(equalToConstant: 444)
    progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)

    NSLayoutConstraint.activate([
      posterView.topAnchor.constraint(equalTo: contentView.topAnchor),
      posterView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      posterWidthConstraint,
      posterHeightConstraint,

      overlayContainer.topAnchor.constraint(equalTo: posterView.imageView.topAnchor),
      overlayContainer.bottomAnchor.constraint(equalTo: posterView.imageView.bottomAnchor),
      overlayContainer.leadingAnchor.constraint(equalTo: posterView.imageView.leadingAnchor),
      overlayContainer.trailingAnchor.constraint(equalTo: posterView.imageView.trailingAnchor),

      placeholderPanel.topAnchor.constraint(equalTo: overlayContainer.topAnchor),
      placeholderPanel.bottomAnchor.constraint(equalTo: overlayContainer.bottomAnchor),
      placeholderPanel.leadingAnchor.constraint(equalTo: overlayContainer.leadingAnchor),
      placeholderPanel.trailingAnchor.constraint(equalTo: overlayContainer.trailingAnchor),

      progressTrack.leadingAnchor.constraint(equalTo: overlayContainer.leadingAnchor, constant: 16),
      progressTrack.trailingAnchor.constraint(equalTo: overlayContainer.trailingAnchor, constant: -16),
      progressTrack.bottomAnchor.constraint(equalTo: overlayContainer.bottomAnchor, constant: -15),
      progressTrack.heightAnchor.constraint(equalToConstant: 6),

      progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
      progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
      progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
      progressFillWidth,

      watchedGlyph.leadingAnchor.constraint(equalTo: overlayContainer.leadingAnchor, constant: 16),
      watchedGlyph.bottomAnchor.constraint(equalTo: overlayContainer.bottomAnchor, constant: -15),

      captionLabel.topAnchor.constraint(equalTo: posterView.bottomAnchor, constant: TVUIKitPosterMetrics.captionTopPadding),
      captionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      captionLabel.trailingAnchor.constraint(equalTo: posterView.trailingAnchor),
      captionLabel.heightAnchor.constraint(lessThanOrEqualToConstant: TVUIKitPosterMetrics.captionHeight)
    ])

    contentView.addInteraction(UIContextMenuInteraction(delegate: self))
  }

  public func configure(card: MediaCard, size: CGSize) {
    tileWidth = size.width
    posterWidthConstraint.constant = size.width
    posterHeightConstraint.constant = size.height
    captionLabel.text = card.title
    configureProgress(card)
    configureWatched(card)
    loadImage(from: URL(string: card.posterURL))
  }

  private func configureProgress(_ card: MediaCard) {
    guard let progress = card.progress, progress > 0, progress < 1 else {
      progressTrack.isHidden = true
      bottomInfoBlur?.isHidden = true
      return
    }
    progressTrack.isHidden = false
    ensureBottomInfoBlur().isHidden = false
    let trackWidth = max(tileWidth - 32, 1)
    progressFillWidth.constant = trackWidth * CGFloat(progress)
  }

  private func configureWatched(_ card: MediaCard) {
    let inProgress = (card.progress ?? 0) > 0 && (card.progress ?? 0) < 1
    watchedGlyph.isHidden = !(card.isWatched && !inProgress)
  }

  private func ensureBottomInfoBlur() -> TVUIKitBottomInfoBlurView {
    if let existing = bottomInfoBlur { return existing }
    let blur = TVUIKitBottomInfoBlurView()
    blur.translatesAutoresizingMaskIntoConstraints = false
    overlayContainer.insertSubview(blur, belowSubview: progressTrack)
    NSLayoutConstraint.activate([
      blur.leadingAnchor.constraint(equalTo: overlayContainer.leadingAnchor),
      blur.trailingAnchor.constraint(equalTo: overlayContainer.trailingAnchor),
      blur.bottomAnchor.constraint(equalTo: overlayContainer.bottomAnchor),
      blur.heightAnchor.constraint(equalTo: overlayContainer.heightAnchor, multiplier: 0.25)
    ])
    bottomInfoBlur = blur
    return blur
  }

  private func loadImage(from url: URL?) {
    imageTask?.cancel()
    guard let url else {
      posterView.image = nil
      currentURL = nil
      placeholderPanel.isHidden = false
      return
    }
    if currentURL == url, posterView.image != nil {
      placeholderPanel.isHidden = true
      return
    }
    currentURL = url
    placeholderPanel.isHidden = false
    imageTask = Task { [weak self] in
      let image = await TVUIKitRemoteImage.load(url: url)
      await MainActor.run {
        guard let self, self.currentURL == url else { return }
        self.posterView.image = image
        self.placeholderPanel.isHidden = image != nil
      }
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()
    imageTask?.cancel()
    imageTask = nil
    currentURL = nil
    posterView.image = nil
    placeholderPanel.isHidden = false
    progressTrack.isHidden = true
    bottomInfoBlur?.isHidden = true
    watchedGlyph.isHidden = true
    captionLabel.alpha = 0
    contextMenuEntries = nil
    resetStaleFocusAppearance()
  }

  public override func didUpdateFocus(in context: UIFocusUpdateContext,
                               with coordinator: UIFocusAnimationCoordinator) {
    super.didUpdateFocus(in: context, with: coordinator)
    let nowFocused = context.nextFocusedView === self
      || context.nextFocusedView?.isDescendant(of: self) == true
    coordinator.addCoordinatedAnimations({
      self.overlayContainer.transform = nowFocused
        ? CGAffineTransform(scaleX: 1.1, y: 1.1)
        : .identity
      self.captionLabel.alpha = nowFocused ? 1 : 0
    }, completion: { [weak self] in
      guard let self, !nowFocused else { return }
      self.resetStaleFocusAppearance()
    })
  }

  /// TVPosterView sometimes strands enlarged after focus leaves the collection.
  public func resetStaleFocusAppearance() {
    guard !isFocused else { return }
    func clear(_ view: UIView) {
      if !view.transform.isIdentity { view.transform = .identity }
      if !CATransform3DIsIdentity(view.layer.transform) {
        view.layer.transform = CATransform3DIdentity
      }
      view.motionEffects.forEach { view.removeMotionEffect($0) }
      view.subviews.forEach(clear)
    }
    clear(posterView)
    overlayContainer.transform = .identity
    captionLabel.alpha = 0
  }

  public override var canBecomeFocused: Bool { true }
}

extension TVUIKitPosterCell: UIContextMenuInteractionDelegate {
  public func contextMenuInteraction(
    _ interaction: UIContextMenuInteraction,
    configurationForMenuAtLocation location: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let entries = contextMenuEntries?(), !entries.isEmpty else { return nil }
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      TVUIKitContextMenuBuilder.menu(from: entries)
    }
  }
}
#endif
