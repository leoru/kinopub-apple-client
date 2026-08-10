#if os(tvOS)
//
//  TVUIKitPosterCell.swift
//  KinoPubUI
//
//  Rivulet-style `TVPosterView` wrapper: native focus motion, `title`/`subtitle` nil
//  (TVUIKit reserves footer space that crops 2:3 art — we draw our own two lines).
//
//  The card is a fixed 2:3 rectangle and the artwork fills it. `TVPosterView` sizes
//  itself from the image's natural size unless told otherwise, so a rail of posters with
//  slightly different source aspects used to jump in height, and — because the overlay
//  is a child of the image view — the overlay visibly stopped short of the card's edges
//  on placeholder tiles. `contentSize` plus an aspect-fill image view is what pins it.
//

import UIKit
import TVUIKit
import KinoPubUI
import KinoPubBackend

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
  /// Focus-only chrome: what you can do with this tile, once you are on it.
  private let playGlyph = UIImageView()
  private let durationLabel = UILabel()
  private let captionLabel = UILabel()
  /// The second line. `TVPosterView.subtitle` would have done this, but setting either
  /// of its labels makes the lockup reserve footer space and crop 2:3 art (see the nil
  /// assignments in `setUp`), so the pair is ours — same two lines the wide cell gets
  /// from the system, built from the same `TVUIKitCardText`.
  private let subtitleLabel = UILabel()

  private var imageTask: Task<Void, Never>?
  private var currentURL: URL?
  private var tileWidth: CGFloat = 296
  private var posterWidthConstraint: NSLayoutConstraint!
  private var posterHeightConstraint: NSLayoutConstraint!
  private var progressFillWidth: NSLayoutConstraint!
  private var focusRowBottom: NSLayoutConstraint!
  private var focusRowAboveProgress: NSLayoutConstraint!

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
    // Fill the 2:3 card rather than letterboxing to whatever aspect the source happens
    // to be. Rounding lives here too: the corners used to come from the overlay while it
    // was a sibling covering the image, and moving it inside left the artwork square.
    posterView.imageView.contentMode = .scaleAspectFill
    posterView.imageView.clipsToBounds = true
    posterView.imageView.layer.cornerRadius = TVUIKitPosterMetrics.cornerRadius
    posterView.imageView.layer.cornerCurve = .continuous
    contentView.addSubview(posterView)

    overlayContainer.translatesAutoresizingMaskIntoConstraints = false
    overlayContainer.isUserInteractionEnabled = false
    overlayContainer.clipsToBounds = true
    overlayContainer.layer.cornerRadius = TVUIKitPosterMetrics.cornerRadius
    overlayContainer.layer.cornerCurve = .continuous
    // Inside the poster's own image view, not a sibling of it. A sibling has to be
    // scaled by hand to keep up with the system's focus growth, and hand-scaling is
    // what we are not doing any more: as a child it simply rides whatever transform
    // `TVPosterView` applies, exactly and for free.
    posterView.imageView.addSubview(overlayContainer)

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

    // Shown on focus only. The cover already says what the title is; a play glyph and a
    // runtime on every idle tile is clutter over artwork this small. Progress is the
    // exception — see `configureProgress`.
    playGlyph.translatesAutoresizingMaskIntoConstraints = false
    playGlyph.image = UIImage(systemName: "play.fill")
    playGlyph.tintColor = .white
    playGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
    playGlyph.alpha = 0
    TVUIKitChromeSupport.applyLegibilityShadow(to: playGlyph.layer)
    overlayContainer.addSubview(playGlyph)

    durationLabel.translatesAutoresizingMaskIntoConstraints = false
    durationLabel.font = .preferredFont(forTextStyle: .caption2)
    durationLabel.textColor = .white
    durationLabel.numberOfLines = 1
    durationLabel.alpha = 0
    TVUIKitChromeSupport.applyLegibilityShadow(to: durationLabel.layer)
    overlayContainer.addSubview(durationLabel)

    captionLabel.translatesAutoresizingMaskIntoConstraints = false
    captionLabel.font = .preferredFont(forTextStyle: .callout)
    captionLabel.textColor = .label
    captionLabel.numberOfLines = 1
    captionLabel.textAlignment = .center
    captionLabel.enablesMarqueeWhenAncestorFocused = true
    captionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    captionLabel.alpha = 0
    contentView.addSubview(captionLabel)

    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    // A step down in size *and* in colour — the two lines have to read as title and
    // metadata, not as one wrapped sentence.
    subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.numberOfLines = 1
    subtitleLabel.textAlignment = .center
    subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    subtitleLabel.alpha = 0
    contentView.addSubview(subtitleLabel)

    posterWidthConstraint = posterView.widthAnchor.constraint(equalToConstant: 296)
    posterHeightConstraint = posterView.heightAnchor.constraint(equalToConstant: 444)
    progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
    // The focus row sits at the bottom of the artwork, and steps up out of the way when
    // a progress bar is there — the bar is always on, the row only appears on focus, so
    // they must not share the same strip.
    focusRowBottom = playGlyph.bottomAnchor.constraint(equalTo: overlayContainer.bottomAnchor,
                                                       constant: -15)
    focusRowAboveProgress = playGlyph.bottomAnchor.constraint(equalTo: progressTrack.topAnchor,
                                                              constant: -10)
    focusRowBottom.isActive = true

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

      playGlyph.leadingAnchor.constraint(equalTo: overlayContainer.leadingAnchor, constant: 16),
      durationLabel.trailingAnchor.constraint(equalTo: overlayContainer.trailingAnchor, constant: -16),
      durationLabel.centerYAnchor.constraint(equalTo: playGlyph.centerYAnchor),
      durationLabel.leadingAnchor.constraint(greaterThanOrEqualTo: playGlyph.trailingAnchor, constant: 8),

      captionLabel.topAnchor.constraint(equalTo: posterView.bottomAnchor, constant: TVUIKitPosterMetrics.captionTopPadding),
      captionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      captionLabel.trailingAnchor.constraint(equalTo: posterView.trailingAnchor),

      subtitleLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor,
                                         constant: TVUIKitPosterMetrics.captionLineSpacing),
      subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      subtitleLabel.trailingAnchor.constraint(equalTo: posterView.trailingAnchor)
    ])
  }

  public func configure(card: MediaCard, size: CGSize) {
    tileWidth = size.width
    posterWidthConstraint.constant = size.width
    posterHeightConstraint.constant = size.height
    captionLabel.text = TVUIKitCardText.primary(for: card)
    let subtitle = TVUIKitCardText.secondary(for: card)
    subtitleLabel.text = subtitle
    subtitleLabel.isHidden = (subtitle ?? "").isEmpty
    configureProgress(card)
    configureWatched(card)
    configureFocusRow(card)
    // The card is a fixed 2:3 rectangle: without this the lockup takes the image's own
    // proportions and the rail's tiles no longer share a baseline.
    posterView.contentSize = size
    loadImage(from: URL(string: card.posterURL))
  }

  /// Progress is the one piece of chrome that is **not** focus-gated: "you started this
  /// and did not finish it" is a fact about the tile, and a rail you are not standing on
  /// still has to say it.
  private func configureProgress(_ card: MediaCard) {
    guard let progress = card.progress, progress > 0, progress < 1 else {
      progressTrack.isHidden = true
      bottomInfoBlur?.isHidden = true
      return
    }
    progressTrack.isHidden = false
    // Blur band commented out 2026-08-09: it is our invention, not TVUIKit's, and behind
    // a bare progress track (no label) it reads as a smudge rather than a legibility
    // treatment. `ensureBottomInfoBlur()` and `TVUIKitBottomInfoBlurView` are still here
    // — put this line back if the bar turns out to need a floor over pale artwork.
    // ensureBottomInfoBlur().isHidden = false
    let trackWidth = max(tileWidth - 32, 1)
    progressFillWidth.constant = trackWidth * CGFloat(progress)
  }

  private func configureFocusRow(_ card: MediaCard) {
    let hasProgress = !progressTrack.isHidden
    focusRowBottom.isActive = !hasProgress
    focusRowAboveProgress.isActive = hasProgress

    let duration = MediaCardDisplayPreferences.showDuration ? card.durationSeconds : nil
    let label = duration.flatMap { $0 >= 60 ? Duration.compact(seconds: $0) : nil }
    durationLabel.text = label
    durationLabel.isHidden = (label ?? "").isEmpty
    // No play glyph on something already finished — the checkmark is the whole story
    // there, and two glyphs in one corner is not a state, it is a collision.
    playGlyph.isHidden = card.isWatched && !hasProgress
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
    imageTask = nil
    currentURL = url
    guard let url else {
      posterView.image = nil
      placeholderPanel.isHidden = false
      ArtworkLog.skipped(by: "poster", reason: "no artwork URL")
      return
    }
    // Recycled tiles repaint in this frame instead of showing the placeholder and
    // re-downloading art that was on screen a moment ago.
    if let hit = TVUIKitRemoteImage.cached(url: url) {
      posterView.image = hit
      placeholderPanel.isHidden = true
      ArtworkLog.servedFromMemory(url, by: "poster")
      return
    }
    posterView.image = nil
    placeholderPanel.isHidden = false
    ArtworkLog.requested(url, by: "poster")
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
    subtitleLabel.alpha = 0
    playGlyph.alpha = 0
    durationLabel.alpha = 0
    resetStaleFocusAppearance()
  }

  /// Only the caption is ours to animate. Scale, lift, specular and tilt belong to
  /// `TVPosterView`, and the overlay rides its transform as a child of the image view.
  public override func didUpdateFocus(in context: UIFocusUpdateContext,
                               with coordinator: UIFocusAnimationCoordinator) {
    super.didUpdateFocus(in: context, with: coordinator)
    let nowFocused = context.nextFocusedView === self
      || context.nextFocusedView?.isDescendant(of: self) == true
    coordinator.addCoordinatedAnimations({
      self.captionLabel.alpha = nowFocused ? 1 : 0
      self.subtitleLabel.alpha = nowFocused ? 1 : 0
      self.playGlyph.alpha = nowFocused ? 1 : 0
      self.durationLabel.alpha = nowFocused ? 1 : 0
    }, completion: { [weak self] in
      guard let self, !nowFocused else { return }
      self.resetStaleFocusAppearance()
    })
  }

  /// TVPosterView sometimes strands enlarged after focus leaves the collection. This
  /// undoes *the system's* leftover motion, not any of ours — we no longer apply any.
  /// Keep it: it is the workaround `FocusLog.stranded` was written to catch.
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
    captionLabel.alpha = 0
    subtitleLabel.alpha = 0
    playGlyph.alpha = 0
    durationLabel.alpha = 0
  }

  public override var canBecomeFocused: Bool { true }
}
#endif
