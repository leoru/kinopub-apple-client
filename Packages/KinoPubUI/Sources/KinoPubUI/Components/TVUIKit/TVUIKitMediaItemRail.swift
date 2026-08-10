#if os(tvOS)
//
//  TVUIKitMediaItemRail.swift
//  KinoPubUI
//
//  Horizontal wide rails drawn by the system's own media-item cell:
//  `TVMediaItemContentConfiguration.wideCell()` laid out from
//  `NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems()`.
//
//  This is the one 16:9 rail for Continue Watching, episodes, trailers, Up Next, and
//  genre / category tiles. Posters stay on `TVPosterView` — the media-item
//  configuration ships a 16:9 `wideCellConfiguration` only, there is no 2:3 variant.
//
//  One deliberately simple look, not a set of options:
//
//  * **Under the tile** — the name: a movie's title, or "S2, E11" plus the show's
//    title for an episode. Always visible, not just on focus — this is the system's
//    own `text`, in its own space below the artwork, so it never collides with
//    anything drawn over the artwork itself.
//  * **Inside the artwork** — the system's progress bar when there is progress, else
//    the runtime bottom-trailing: exactly one of the two, both shown immediately, never
//    gated by focus. A play/checkmark glyph sits bottom-leading, always on. Neither
//    sits on a pill; a drop shadow carries their legibility instead. No SF Symbol
//    floats in the middle of the tile.
//  * **Top-leading badge** carries what the corner can't: "Watched", or an upcoming
//    episode's date behind a small clock glyph. It replaces the capability badge
//    (4K / HDR) for exactly those two states — the corner has room for one badge, and
//    the state wins.
//  * **Progress is never a series completion ratio.** A card with no specific episode
//    pinned to it cannot be "in progress" here, however its `progress` field reads —
//    that number would be "6 of 12 episodes watched", not a resume point.
//

import SwiftUI
import UIKit
import TVUIKit
import KinoPubBackend

// MARK: - Status

/// What this tile can do, which drives the glyph, the bottom-trailing runtime, and the
/// top badge. Episodes need all five: a rail spans "watched it", "half-way through",
/// "not uploaded yet", and "airs in three days" side by side.
public enum TVUIKitMediaItemStatus: Equatable {
  /// Nothing watched yet. Play glyph + runtime, no bar.
  case ready
  /// Part-watched, 0…1. Progress bar instead of the runtime — the two never show
  /// together, the bar already says "how far in".
  case inProgress(Double)
  /// Finished. Dark scrim, checkmark, "Watched" badge, runtime still shown (it is a
  /// fact about the episode, not about where playback is).
  case watched
  /// On a schedule but not on kino.pub. **No** play glyph — the absence is the signal.
  /// Dimming and disabling is not how we say this; the missing glyph and the caption are.
  case unavailable
  /// Announced, not yet on kino.pub. Associated text is the badge's date — "in 3 days"
  /// or "Mar 13, 2026" — computed by the caller, since only the caller knows today's
  /// date and the app's date-formatting rules (see `SeasonsRailView.airDateLabel`).
  case upcoming(String)

  var glyph: String? {
    switch self {
    case .ready, .inProgress: "play.fill"
    case .watched: "checkmark"
    case .unavailable, .upcoming: nil
    }
  }

  var progress: Double {
    if case .inProgress(let fraction) = self { return min(max(fraction, 0), 1) }
    return 0
  }

  /// Whether the bottom-trailing corner shows the episode's own runtime. Progress and
  /// an upcoming release both already say "how long until you can watch this" some
  /// other way — a bar, or the badge's date — so the runtime only appears where
  /// nothing else is already carrying that story.
  var showsRuntime: Bool {
    switch self {
    case .ready, .watched: true
    case .inProgress, .unavailable, .upcoming: false
    }
  }

  /// Top-leading badge text, for the two states that need one of their own instead of
  /// the corner going to a capability badge (4K / HDR / LIVE). Named distinctly from
  /// `TVUIKitMediaItem.badgeText` (the capability badge) so a call site reading either
  /// name says which one it means.
  var stateBadgeText: String? {
    switch self {
    case .watched: String(localized: "TVMediaItem_Watched")
    case .upcoming(let dateText): dateText
    case .ready, .inProgress, .unavailable: nil
    }
  }

  var badgeShowsClock: Bool {
    if case .upcoming = self { return true }
    return false
  }

  /// Watched tiles sit back so the unwatched ones beside them read first.
  var dimsArtwork: Bool { self == .watched }
}

// MARK: - Model

/// One wide media item — everything the configuration and our overlay can draw.
public struct TVUIKitMediaItem: Identifiable, Equatable {
  public let id: Int
  public let imageURL: URL?
  /// Drawn when there is no artwork URL, or until one loads. Genre / category tiles
  /// have no photograph at all and use this as their real artwork.
  public let tint: UIColor?
  public let symbol: String?
  /// The line under the tile — always visible: a movie's title, or "S2, E11 · Show".
  public let caption: String?
  public let status: TVUIKitMediaItemStatus
  /// Chip text beside the glyph, inside the artwork — runtime, or time left.
  public let timeLabel: String?
  public let badgeText: String?
  /// Live content gets the system's own red badge treatment.
  public let badgeIsLive: Bool

  public init(id: Int,
              imageURL: URL? = nil,
              tint: UIColor? = nil,
              symbol: String? = nil,
              caption: String? = nil,
              status: TVUIKitMediaItemStatus = .ready,
              timeLabel: String? = nil,
              badgeText: String? = nil,
              badgeIsLive: Bool = false) {
    self.id = id
    self.imageURL = imageURL
    self.tint = tint
    self.symbol = symbol
    self.caption = caption
    self.status = status
    self.timeLabel = timeLabel
    self.badgeText = badgeText
    self.badgeIsLive = badgeIsLive
  }

  /// A coloured tile with a glyph and nothing else — genres, categories, anything with
  /// no artwork of its own. Colour is derived from the name so it is stable per genre.
  public init(id: Int, genre: String, symbol: String, tint: UIColor? = nil) {
    self.init(id: id,
              tint: tint ?? TVUIKitTileArtwork.tint(for: genre),
              symbol: symbol,
              caption: genre,
              status: .unavailable)
  }
}

public extension TVUIKitMediaItem {
  /// The app's card model in media-item terms.
  init(card: MediaCard) {
    let art = card.landscapeImageURL ?? card.backdropURL ?? card.posterURL
    let status = Self.status(for: card)
    self.init(id: card.id,
              imageURL: URL(string: art),
              caption: Self.caption(for: card),
              status: status,
              timeLabel: Self.timeLabel(for: card, status: status),
              badgeText: Self.badgeText(for: card))
  }

  /// A fraction only means something pinned to one episode or one movie. A
  /// series-level card (`isSeries` with no specific `video` chosen) can carry
  /// `WatchingItem.progress` — "6 of 12 episodes watched" — and that must never
  /// paint a resume bar here: it is not a point to seek back to.
  static func status(for card: MediaCard) -> TVUIKitMediaItemStatus {
    if card.isWatched { return .watched }
    guard card.video != nil || !card.isSeries else { return .ready }
    if let progress = card.progress, progress > 0.02, progress < 0.95 {
      return .inProgress(progress)
    }
    return .ready
  }

  /// The name: a movie's title alone, or "S2, E11" ahead of the show's title for an
  /// episode. `overlayLabel` already carries the season/episode piece (History and
  /// Continue Watching both format it identically); this only decides whether the
  /// title rides along with it.
  static func caption(for card: MediaCard) -> String? {
    if let overlay = card.overlayLabel, !overlay.isEmpty {
      return card.title.isEmpty ? overlay : "\(overlay) · \(card.title)"
    }
    return card.title.isEmpty ? nil : card.title
  }

  /// The runtime, for the statuses that show one (`TVUIKitMediaItemStatus.showsRuntime`
  /// — not `.inProgress`, where the bar already says "how far along", nor `.upcoming`,
  /// where nothing is known yet). Nil when the payload never told us how long the thing
  /// is — better an empty corner than a made-up number.
  static func timeLabel(for card: MediaCard, status: TVUIKitMediaItemStatus) -> String? {
    guard status.showsRuntime, let duration = card.durationSeconds, duration >= 60 else { return nil }
    let label = Duration.compact(seconds: duration)
    return label.isEmpty ? nil : label
  }

  /// Capability only. `MediaCard.badge` deliberately does **not** feed this — on Home it
  /// carries kino.pub's "+10 new episodes" counter, which is noise in a corner chip.
  static func badgeText(for card: MediaCard) -> String? {
    if card.is4K { return "4K" }
    if card.isHDR { return "HDR" }
    return nil
  }
}

// MARK: - SwiftUI entry point

/// Horizontal rail of system media-item cells. Sizes itself — callers must not pin a
/// `.frame(height:)` guess on top of it.
public struct TVUIKitMediaItemRail: UIViewControllerRepresentable {
  private let items: [TVUIKitMediaItem]
  private let contentInset: CGFloat
  private let onSelect: (Int) -> Void
  private let onNearEnd: ((Int) -> Void)?
  private let contextMenuProvider: ((Int) -> [MediaCardContextEntry])?

  /// - Parameters:
  ///   - contentInset: leading/trailing inset, so the rail lines up with the section
  ///     header above it. Vertical spacing stays the system's.
  ///   - onSelect / onNearEnd / contextMenuProvider: all keyed by `TVUIKitMediaItem.id`.
  public init(items: [TVUIKitMediaItem],
              contentInset: CGFloat = 0,
              onSelect: @escaping (Int) -> Void,
              onNearEnd: ((Int) -> Void)? = nil,
              contextMenuProvider: ((Int) -> [MediaCardContextEntry])? = nil) {
    self.items = items
    self.contentInset = contentInset
    self.onSelect = onSelect
    self.onNearEnd = onNearEnd
    self.contextMenuProvider = contextMenuProvider
  }

  public func makeUIViewController(context: Context) -> TVUIKitMediaItemRailController {
    let controller = TVUIKitMediaItemRailController(contentInset: contentInset)
    controller.apply(items: items,
                     onSelect: onSelect,
                     onNearEnd: onNearEnd,
                     contextMenuProvider: contextMenuProvider)
    return controller
  }

  public func updateUIViewController(_ controller: TVUIKitMediaItemRailController, context: Context) {
    controller.apply(items: items,
                     onSelect: onSelect,
                     onNearEnd: onNearEnd,
                     contextMenuProvider: contextMenuProvider)
  }

  public func sizeThatFits(_ proposal: ProposedViewSize,
                           uiViewController: TVUIKitMediaItemRailController,
                           context: Context) -> CGSize? {
    guard let width = proposal.width, width > 1 else { return nil }
    guard !items.isEmpty else { return CGSize(width: width, height: 0) }
    return CGSize(width: width, height: TVUIKitMediaItemMetrics.railHeight(width: width))
  }
}

// MARK: - Sizing

public enum TVUIKitMediaItemMetrics {
  /// Multiplier on the system's own tile size. 1.0 is exactly Apple's row; that reads
  /// small in our shelves, so the shipping tile is a notch above it.
  public static let scale: CGFloat = 1.18

  /// Used only when the probe comes back with nothing — roughly the system row.
  public static let fallback = SystemMetrics(itemSize: CGSize(width: 500, height: 340),
                                             interGroupSpacing: 40,
                                             verticalPadding: 40)

  public struct SystemMetrics: Equatable {
    public var itemSize: CGSize
    public var interGroupSpacing: CGFloat
    /// The section's own top + bottom insets, which we do not scale.
    public var verticalPadding: CGFloat
  }

  @MainActor
  public static func railHeight(width: CGFloat) -> CGFloat {
    let metrics = systemMetrics(width: width)
    return metrics.itemSize.height * scale + metrics.verticalPadding
  }

  /// A section with the system's proportions at our size. `orthogonalLayoutSectionForMediaItems()`
  /// cannot be resized — it exposes neither its group nor its item — so we measure what
  /// it produces once per width and rebuild an equivalent section scaled up. Keeping the
  /// measurement means the tile stays whatever shape Apple ships, not a shape we guessed.
  @MainActor
  public static func section(width: CGFloat, inset: CGFloat) -> NSCollectionLayoutSection {
    let metrics = systemMetrics(width: width)
    let size = NSCollectionLayoutSize(
      widthDimension: .absolute(metrics.itemSize.width * scale),
      heightDimension: .absolute(metrics.itemSize.height * scale)
    )
    let item = NSCollectionLayoutItem(layoutSize: size)
    let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.orthogonalScrollingBehavior = .continuous
    section.interGroupSpacing = metrics.interGroupSpacing * scale
    section.contentInsets = NSDirectionalEdgeInsets(top: metrics.verticalPadding / 2,
                                                    leading: 0,
                                                    bottom: metrics.verticalPadding / 2,
                                                    trailing: 0)
    if inset > 0 {
      // Only the horizontal edges, so the first tile starts under the section title.
      section.contentInsets.leading = inset
      section.contentInsets.trailing = inset
    }
    return section
  }

  /// What `orthogonalLayoutSectionForMediaItems()` lays out at this width. Deterministic
  /// for a given width, so it is measured once with a throwaway collection view.
  @MainActor
  public static func systemMetrics(width: CGFloat) -> SystemMetrics {
    let key = width.rounded()
    guard key > 1 else { return fallback }
    if let cached = cache[key] { return cached }

    let layout = UICollectionViewCompositionalLayout { _, _ in
      .orthogonalLayoutSectionForMediaItems()
    }
    let probe = UICollectionView(
      frame: CGRect(x: 0, y: 0, width: key, height: 4000),
      collectionViewLayout: layout
    )
    probe.register(UICollectionViewCell.self, forCellWithReuseIdentifier: ProbeSource.reuseID)
    probe.dataSource = probeSource
    probe.layoutIfNeeded()

    let first = frame(of: 0, in: probe)
    let second = frame(of: 1, in: probe)
    var metrics = fallback
    if let first, first.width > 1, first.height > 1 {
      metrics.itemSize = first.size
      if let second, second.minX > first.maxX {
        metrics.interGroupSpacing = second.minX - first.maxX
      }
      let content = layout.collectionViewContentSize.height
      if content > first.height {
        metrics.verticalPadding = content - first.height
      }
    }
    cache[key] = metrics
    return metrics
  }

  private static func frame(of index: Int, in probe: UICollectionView) -> CGRect? {
    let path = IndexPath(item: index, section: 0)
    if let attributes = probe.layoutAttributesForItem(at: path) { return attributes.frame }
    return probe.cellForItem(at: path)?.frame
  }

  @MainActor private static var cache: [CGFloat: SystemMetrics] = [:]
  @MainActor private static let probeSource = ProbeSource()

  /// Two cells is enough to read both the tile size and the gap between tiles.
  private final class ProbeSource: NSObject, UICollectionViewDataSource {
    static let reuseID = "TVUIKitMediaItemProbeCell"

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
      collectionView.dequeueReusableCell(withReuseIdentifier: Self.reuseID, for: indexPath)
    }
  }
}

// MARK: - Controller

@MainActor
public final class TVUIKitMediaItemRailController: UIViewController {
  private var items: [TVUIKitMediaItem] = []
  private let contentInset: CGFloat

  private var onSelect: ((Int) -> Void)?
  private var onNearEnd: ((Int) -> Void)?
  private var contextMenuProvider: ((Int) -> [MediaCardContextEntry])?

  private lazy var collectionView: UICollectionView = {
    let inset = contentInset
    let layout = UICollectionViewCompositionalLayout { _, environment in
      TVUIKitMediaItemMetrics.section(width: environment.container.contentSize.width, inset: inset)
    }
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.backgroundColor = .clear
    view.clipsToBounds = false
    view.remembersLastFocusedIndexPath = true
    view.showsHorizontalScrollIndicator = false
    view.showsVerticalScrollIndicator = false
    view.dataSource = self
    view.delegate = self
    view.register(TVUIKitMediaItemCell.self, forCellWithReuseIdentifier: TVUIKitMediaItemCell.reuseID)
    return view
  }()

  init(contentInset: CGFloat) {
    self.contentInset = contentInset
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.clipsToBounds = false
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(collectionView)
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
  }

  func apply(items: [TVUIKitMediaItem],
             onSelect: @escaping (Int) -> Void,
             onNearEnd: ((Int) -> Void)?,
             contextMenuProvider: ((Int) -> [MediaCardContextEntry])?) {
    let changed = self.items != items
    self.items = items
    self.onSelect = onSelect
    self.onNearEnd = onNearEnd
    self.contextMenuProvider = contextMenuProvider
    if changed { collectionView.reloadData() }
  }
}

extension TVUIKitMediaItemRailController: UICollectionViewDataSource, UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView,
                             numberOfItemsInSection section: Int) -> Int {
    items.count
  }

  public func collectionView(_ collectionView: UICollectionView,
                             cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: TVUIKitMediaItemCell.reuseID,
      for: indexPath
    ) as! TVUIKitMediaItemCell
    cell.configure(items[indexPath.item])
    return cell
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    guard items.indices.contains(indexPath.item) else { return }
    onSelect?(items[indexPath.item].id)
  }

  public func collectionView(_ collectionView: UICollectionView,
                             willDisplay cell: UICollectionViewCell,
                             forItemAt indexPath: IndexPath) {
    guard items.indices.contains(indexPath.item) else { return }
    onNearEnd?(items[indexPath.item].id)
  }

  // tvOS routes long-press-Select to the focused view and up its responder chain, so an
  // interaction installed inside the cell never fires — the collection view's own
  // delegate hook is the one UIKit wires to the focus engine, and on tvOS only the
  // plural `…ForItemsAt indexPaths:` variant exists.
  public func collectionView(_ collectionView: UICollectionView,
                             contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
                             point: CGPoint) -> UIContextMenuConfiguration? {
    guard let indexPath = indexPaths.first,
          items.indices.contains(indexPath.item),
          let entries = contextMenuProvider?(items[indexPath.item].id),
          !entries.isEmpty
    else { return nil }

    return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { _ in
      TVUIKitContextMenuBuilder.menu(from: entries)
    }
  }
}

// MARK: - Cell

@MainActor
final class TVUIKitMediaItemCell: UICollectionViewCell {
  static let reuseID = "TVUIKitMediaItemCell"

  private var item: TVUIKitMediaItem?
  private var artwork: UIImage?
  private var loadedURL: URL?
  private var imageTask: Task<Void, Never>?
  private let overlay = TVUIKitMediaItemOverlayView()

  func configure(_ item: TVUIKitMediaItem) {
    let keepsArtwork = self.item?.imageURL == item.imageURL && loadedURL == item.imageURL
    self.item = item
    if !keepsArtwork {
      artwork = nil
      loadArtwork(for: item)
    }
    setNeedsUpdateConfiguration()
  }

  override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)
    guard let item else {
      contentConfiguration = nil
      return
    }

    var config = TVMediaItemContentConfiguration.wideCell()
    config.image = artwork ?? fallbackImage(for: item)
    // `text` is the line *under* the tile, always visible.
    config.text = item.caption
    // `secondaryText` is not a second caption line — the system draws it *over* the
    // artwork's bottom-leading corner, which is where our glyph + time chip lives.
    config.secondaryText = nil
    // Shown immediately, not gated by focus — an idle rail should already tell you
    // what is worth resuming.
    config.playbackProgress = Float(item.status.progress)
    // The state badge (Watched / upcoming date) and the capability badge (4K / HDR /
    // LIVE) share the same top-leading corner — only one can show. The state wins.
    if item.status.stateBadgeText == nil, let badge = item.badgeText, !badge.isEmpty {
      config.badgeText = badge
      config.badgeProperties = item.badgeIsLive ? .liveContent() : .default()
    }

    overlay.apply(status: item.status, timeLabel: item.timeLabel)
    config.overlayView = overlay

    contentConfiguration = config
  }

  private func fallbackImage(for item: TVUIKitMediaItem) -> UIImage {
    guard let tint = item.tint else { return TVUIKitTileArtwork.placeholder() }
    return TVUIKitTileArtwork.wide(tint: tint, symbol: item.symbol)
  }

  private func loadArtwork(for item: TVUIKitMediaItem) {
    imageTask?.cancel()
    imageTask = nil
    loadedURL = nil
    guard let url = item.imageURL else { return }
    imageTask = Task { [weak self] in
      let image = await TVUIKitRemoteImage.load(url: url)
      guard let self, !Task.isCancelled, self.item?.imageURL == url else { return }
      self.artwork = image
      self.loadedURL = image == nil ? nil : url
      self.setNeedsUpdateConfiguration()
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    imageTask?.cancel()
    imageTask = nil
    item = nil
    artwork = nil
    loadedURL = nil
    contentConfiguration = nil
  }

  override var canBecomeFocused: Bool { true }
}

// MARK: - Overlay

/// Sits on `TVMediaItemContentConfiguration.overlayView`, which the system pins over the
/// artwork and resizes with it. Carries what the configuration has no property for: a
/// light bottom gradient, a play/checkmark glyph in the bottom-leading corner, the
/// runtime in the bottom-trailing corner, a top-leading state badge (Watched / an
/// upcoming release date), and the watched scrim. The progress bar underneath is the
/// system's.
///
/// No pill behind the glyph or the runtime — a drop shadow carries their legibility
/// instead, so the corner reads as part of the tile rather than a plate glued onto it.
/// Everything here is shown immediately, never gated by focus: the bar and the runtime
/// are mutually exclusive (exactly one of them says "how far along"), so neither needs
/// to wait for a look to appear.
@MainActor
final class TVUIKitMediaItemOverlayView: UIView {
  private let gradientLayer = CAGradientLayer()
  private let scrim = UIView()
  private let glyphView = UIImageView()
  private let runtimeLabel = UILabel()
  private let badge = UIView()
  private let badgeIcon = UIImageView()
  private let badgeLabel = UILabel()
  private var badgeIconWidth: NSLayoutConstraint!

  /// The system draws `playbackProgress` along the very bottom edge — this clears it.
  private static let cornerInset: CGFloat = 22
  private static let glyphSize: CGFloat = 22
  private static let badgeIconSize: CGFloat = 14
  /// Fraction of the tile height the legibility gradient covers, from the bottom up.
  private static let gradientHeightFraction: CGFloat = 0.4

  init() {
    super.init(frame: .zero)
    isUserInteractionEnabled = false

    // A light bottom-up fade, not a hard band — just enough for the glyph and runtime to
    // read over bright or busy artwork, since the system's own bottom gradient (under
    // its own text) does not reach up over the artwork itself.
    gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.5).cgColor]
    gradientLayer.locations = [0, 1]
    layer.addSublayer(gradientLayer)

    scrim.translatesAutoresizingMaskIntoConstraints = false
    scrim.backgroundColor = UIColor.black.withAlphaComponent(0.5)
    scrim.isHidden = true
    addSubview(scrim)

    glyphView.translatesAutoresizingMaskIntoConstraints = false
    glyphView.tintColor = .white
    glyphView.contentMode = .scaleAspectFit
    glyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
    Self.applyLegibilityShadow(to: glyphView.layer)
    addSubview(glyphView)

    runtimeLabel.translatesAutoresizingMaskIntoConstraints = false
    runtimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 19, weight: .semibold)
    runtimeLabel.textColor = .white
    runtimeLabel.textAlignment = .right
    Self.applyLegibilityShadow(to: runtimeLabel.layer)
    addSubview(runtimeLabel)

    // A real pill, unlike the bottom corner — this is a badge (Watched / a release
    // date), a different kind of chrome from "what Select does", and Apple's own
    // capability badges (4K / HDR) it stands in for are pills too.
    badge.translatesAutoresizingMaskIntoConstraints = false
    badge.backgroundColor = UIColor.black.withAlphaComponent(0.6)
    badge.layer.cornerCurve = .continuous
    badge.isHidden = true
    addSubview(badge)

    badgeIcon.translatesAutoresizingMaskIntoConstraints = false
    badgeIcon.tintColor = .white
    badgeIcon.contentMode = .scaleAspectFit
    badgeIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
    badge.addSubview(badgeIcon)

    badgeLabel.translatesAutoresizingMaskIntoConstraints = false
    badgeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
    badgeLabel.textColor = .white
    badge.addSubview(badgeLabel)

    badgeIconWidth = badgeIcon.widthAnchor.constraint(equalToConstant: Self.badgeIconSize)

    NSLayoutConstraint.activate([
      scrim.topAnchor.constraint(equalTo: topAnchor),
      scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrim.trailingAnchor.constraint(equalTo: trailingAnchor),

      glyphView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      glyphView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.cornerInset),
      glyphView.widthAnchor.constraint(equalToConstant: Self.glyphSize),
      glyphView.heightAnchor.constraint(equalToConstant: Self.glyphSize),

      runtimeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      runtimeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: glyphView.trailingAnchor, constant: 8),
      runtimeLabel.centerYAnchor.constraint(equalTo: glyphView.centerYAnchor),

      badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      badge.topAnchor.constraint(equalTo: topAnchor, constant: 16),
      badge.heightAnchor.constraint(equalToConstant: 28),

      badgeIcon.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 10),
      badgeIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
      badgeIconWidth,

      badgeLabel.leadingAnchor.constraint(equalTo: badgeIcon.trailingAnchor, constant: 5),
      badgeLabel.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -10),
      badgeLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor)
    ])
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    badge.layer.cornerRadius = badge.bounds.height / 2
    gradientLayer.frame = CGRect(x: 0,
                                 y: bounds.height * (1 - Self.gradientHeightFraction),
                                 width: bounds.width,
                                 height: bounds.height * Self.gradientHeightFraction)
    CATransaction.commit()
  }

  func apply(status: TVUIKitMediaItemStatus, timeLabel: String?) {
    scrim.isHidden = !status.dimsArtwork

    let glyph = status.glyph
    glyphView.image = glyph.flatMap { UIImage(systemName: $0) }
    glyphView.isHidden = glyph == nil

    let showsRuntime = status.showsRuntime && timeLabel?.isEmpty == false
    runtimeLabel.text = timeLabel
    runtimeLabel.isHidden = !showsRuntime

    if let text = status.stateBadgeText {
      badge.isHidden = false
      badgeLabel.text = text
      let showsIcon = status.badgeShowsClock
      badgeIcon.isHidden = !showsIcon
      badgeIcon.image = showsIcon ? UIImage(systemName: "clock") : nil
      badgeIconWidth.constant = showsIcon ? Self.badgeIconSize : 0
    } else {
      badge.isHidden = true
    }

    gradientLayer.isHidden = !(glyph != nil || showsRuntime)
  }

  private static func applyLegibilityShadow(to layer: CALayer) {
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.9
    layer.shadowRadius = 5
    layer.shadowOffset = .zero
  }
}
#endif
