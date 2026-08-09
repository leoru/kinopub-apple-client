#if os(tvOS)
//
//  TVUIKitContinueWatchingCell.swift
//  KinoPubUI
//
//  Landscape Continue Watching tile wrapped in `TVCardView` for native focus motion.
//

import UIKit
import TVUIKit
import KinoPubUI

@MainActor
public final class TVUIKitContinueWatchingCell: UICollectionViewCell {
  public static let reuseID = "TVUIKitContinueWatchingCell"

  private let card = TVCardView()
  private let artworkImageView = UIImageView()
  private let placeholderView = UIView()
  private let titleLabel = UILabel()
  private let metaLabel = UILabel()
  private let bottomInfoBlur = TVUIKitBottomInfoBlurView()
  private let progressTrack = UIView()
  private let progressFill = UIView()

  private var imageTask: Task<Void, Never>?
  private var currentURL: URL?
  private var cardWidthConstraint: NSLayoutConstraint!
  private var cardHeightConstraint: NSLayoutConstraint!
  private var progressFillWidth: NSLayoutConstraint!
  private var tileWidth: CGFloat = 357

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setUp()
  }

  public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func setUp() {
    contentView.clipsToBounds = false
    clipsToBounds = false

    card.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(card)

    placeholderView.translatesAutoresizingMaskIntoConstraints = false
    placeholderView.backgroundColor = UIColor(white: 0.15, alpha: 1)
    card.contentView.addSubview(placeholderView)

    artworkImageView.translatesAutoresizingMaskIntoConstraints = false
    artworkImageView.contentMode = .scaleAspectFill
    artworkImageView.clipsToBounds = true
    card.contentView.addSubview(artworkImageView)

    bottomInfoBlur.translatesAutoresizingMaskIntoConstraints = false
    card.contentView.addSubview(bottomInfoBlur)

    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.font = .preferredFont(forTextStyle: .headline)
    titleLabel.textColor = .white
    titleLabel.numberOfLines = 1
    titleLabel.enablesMarqueeWhenAncestorFocused = true
    titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    card.contentView.addSubview(titleLabel)

    metaLabel.translatesAutoresizingMaskIntoConstraints = false
    metaLabel.font = .preferredFont(forTextStyle: .caption1)
    metaLabel.textColor = UIColor.white.withAlphaComponent(0.85)
    metaLabel.numberOfLines = 1
    card.contentView.addSubview(metaLabel)

    progressTrack.translatesAutoresizingMaskIntoConstraints = false
    progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.28)
    progressTrack.layer.cornerRadius = 3
    card.contentView.addSubview(progressTrack)

    progressFill.translatesAutoresizingMaskIntoConstraints = false
    progressFill.backgroundColor = .white
    progressFill.layer.cornerRadius = 3
    progressTrack.addSubview(progressFill)

    cardWidthConstraint = card.widthAnchor.constraint(equalToConstant: 357)
    cardHeightConstraint = card.heightAnchor.constraint(equalToConstant: 200)
    progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)

    NSLayoutConstraint.activate([
      card.topAnchor.constraint(equalTo: contentView.topAnchor),
      card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      cardWidthConstraint,
      cardHeightConstraint,

      placeholderView.topAnchor.constraint(equalTo: card.contentView.topAnchor),
      placeholderView.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor),
      placeholderView.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
      placeholderView.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),

      artworkImageView.topAnchor.constraint(equalTo: card.contentView.topAnchor),
      artworkImageView.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor),
      artworkImageView.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
      artworkImageView.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),

      bottomInfoBlur.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
      bottomInfoBlur.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor),
      bottomInfoBlur.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor),
      bottomInfoBlur.heightAnchor.constraint(equalTo: card.contentView.heightAnchor, multiplier: 0.35),

      progressTrack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
      progressTrack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
      progressTrack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -15),
      progressTrack.heightAnchor.constraint(equalToConstant: 6),

      progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
      progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
      progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
      progressFillWidth,

      metaLabel.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
      metaLabel.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
      metaLabel.bottomAnchor.constraint(equalTo: progressTrack.topAnchor, constant: -8),

      titleLabel.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -16),
      titleLabel.bottomAnchor.constraint(equalTo: metaLabel.topAnchor, constant: -4)
    ])
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    card.contentView.layer.cornerRadius = TVUIKitPosterMetrics.cornerRadius
    card.contentView.layer.cornerCurve = .continuous
    card.contentView.clipsToBounds = true
    CATransaction.commit()
  }

  public func configure(card model: MediaCard, size: CGSize) {
    tileWidth = size.width
    cardWidthConstraint.constant = size.width
    cardHeightConstraint.constant = size.height
    card.contentSize = size
    titleLabel.text = model.title
    metaLabel.text = model.overlayLabel
    metaLabel.isHidden = (model.overlayLabel ?? "").isEmpty

    if let progress = model.progress, progress > 0, progress < 1 {
      progressTrack.isHidden = false
      progressFillWidth.constant = max(tileWidth - 32, 1) * CGFloat(progress)
    } else {
      progressTrack.isHidden = true
      progressFillWidth.constant = 0
    }

    let urlString = model.landscapeImageURL ?? model.backdropURL ?? model.posterURL
    loadImage(from: URL(string: urlString))
  }

  private func loadImage(from url: URL?) {
    imageTask?.cancel()
    guard let url else {
      artworkImageView.image = nil
      currentURL = nil
      placeholderView.isHidden = false
      return
    }
    if currentURL == url, artworkImageView.image != nil {
      placeholderView.isHidden = true
      return
    }
    currentURL = url
    placeholderView.isHidden = false
    imageTask = Task { [weak self] in
      let image = await TVUIKitRemoteImage.load(url: url)
      await MainActor.run {
        guard let self, self.currentURL == url else { return }
        self.artworkImageView.image = image
        self.placeholderView.isHidden = image != nil
      }
    }
  }

  public override func prepareForReuse() {
    super.prepareForReuse()
    imageTask?.cancel()
    imageTask = nil
    currentURL = nil
    artworkImageView.image = nil
    placeholderView.isHidden = false
    titleLabel.text = nil
    metaLabel.text = nil
    progressTrack.isHidden = true
  }

  public override var canBecomeFocused: Bool { true }
}
#endif
