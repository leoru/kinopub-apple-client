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
//  * **Under the tile** — one line, the system's own `text`, in its own space below the
//    artwork. `S2 E4 • Episode Name` in Continue Watching, `7. "Episode Name"` in a
//    season rail. `secondaryText` renders nothing for us, so there is no second line.
//  * **Inside the artwork** — a progress bar whenever there is progress, drawn by our
//    overlay rather than by `playbackProgress`, because the system's only paints on the
//    focused tile and an idle rail still has to say "you did not finish this". Else the
//    runtime bottom-trailing. A play/checkmark glyph sits bottom-leading. Neither sits
//    on a pill; a drop shadow carries their legibility. No SF Symbol floats in the
//    middle of the tile, and no dates appear down here.
//  * **Top-leading badge** — an announced episode's date goes through the *system*
//    badge (`configuration.badgeText`, the same chip as 4K / HDR) and outranks a
//    capability badge. "Watched" stays on our overlay, paired with its scrim and
//    checkmark. `badgeText` takes a `String`, so no glyph can ride along with the date.
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

  /// Both state badges live on **our** overlay, not on `configuration.badgeText`. The
  /// system chip only paints on the focused tile, and "airs in 3 days" is exactly the
  /// thing an idle rail has to say — same reason the progress bar moved here. Named
  /// distinctly from `TVUIKitMediaItem.badgeText` (the capability badge) so a call site
  /// reading either name says which one it means.
  var overlayBadgeText: String? {
    switch self {
    case .watched: String(localized: "TVMediaItem_Watched")
    case .upcoming(let dateText): dateText
    case .ready, .inProgress, .unavailable: nil
    }
  }

  /// An upcoming date gets a clock beside it — the reason this badge is ours and not
  /// the system's is partly that `badgeText` is a `String` with no room for a glyph.
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
              caption: TVUIKitCardText.caption(for: card),
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
    // `card.progress` is already `WatchProgress.resumeFraction`. Re-thresholding
    // 0.02 / 0.95 here invented a second credits window.
    if let progress = card.progress {
      return .inProgress(progress)
    }
    return .ready
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
  private let entryItemID: Int?
  private let animatesEntryScroll: Bool
  private let onSelect: (Int) -> Void
  private let onNearEnd: ((Int) -> Void)?
  private let onFocusedItem: ((Int) -> Void)?
  private let contextMenuProvider: ((Int) -> [MediaCardContextEntry])?

  /// - Parameters:
  ///   - contentInset: leading/trailing inset, so the rail lines up with the section
  ///     header above it. Vertical spacing stays the system's.
  ///   - entryItemID: where the rail should sit and where focus should land when it
  ///     arrives — the resume episode, or the first episode of a season the user just
  ///     picked. Changing it scrolls the rail; it is *not* a focus binding, because the
  ///     focus engine owns focus once the rail has it.
  ///   - onFocusedItem: which item the engine focused, so a caller can follow it (the
  ///     season tabs track the episode you are standing on).
  ///   - onSelect / onNearEnd / contextMenuProvider: all keyed by `TVUIKitMediaItem.id`.
  public init(items: [TVUIKitMediaItem],
              contentInset: CGFloat = 0,
              entryItemID: Int? = nil,
              animatesEntryScroll: Bool = true,
              onSelect: @escaping (Int) -> Void,
              onNearEnd: ((Int) -> Void)? = nil,
              onFocusedItem: ((Int) -> Void)? = nil,
              contextMenuProvider: ((Int) -> [MediaCardContextEntry])? = nil) {
    self.items = items
    self.contentInset = contentInset
    self.entryItemID = entryItemID
    self.animatesEntryScroll = animatesEntryScroll
    self.onSelect = onSelect
    self.onNearEnd = onNearEnd
    self.onFocusedItem = onFocusedItem
    self.contextMenuProvider = contextMenuProvider
  }

  public func makeUIViewController(context: Context) -> TVUIKitMediaItemRailController {
    let controller = TVUIKitMediaItemRailController(contentInset: contentInset)
    controller.apply(items: items,
                     entryItemID: entryItemID,
                     animatesEntryScroll: animatesEntryScroll,
                     onSelect: onSelect,
                     onNearEnd: onNearEnd,
                     onFocusedItem: onFocusedItem,
                     contextMenuProvider: contextMenuProvider)
    return controller
  }

  public func updateUIViewController(_ controller: TVUIKitMediaItemRailController, context: Context) {
    controller.apply(items: items,
                     entryItemID: entryItemID,
                     animatesEntryScroll: animatesEntryScroll,
                     onSelect: onSelect,
                     onNearEnd: onNearEnd,
                     onFocusedItem: onFocusedItem,
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

  private var entryItemID: Int?
  private var onSelect: ((Int) -> Void)?
  private var onNearEnd: ((Int) -> Void)?
  private var onFocusedItem: ((Int) -> Void)?
  private var contextMenuProvider: ((Int) -> [MediaCardContextEntry])?

  private lazy var collectionView: UICollectionView = {
    let inset = contentInset
    let layout = UICollectionViewCompositionalLayout { _, environment in
      TVUIKitMediaItemMetrics.section(width: environment.container.contentSize.width, inset: inset)
    }
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.backgroundColor = .clear
    view.clipsToBounds = false
    // Deliberately OFF. `remembersLastFocusedIndexPath` restores by *index*, and this
    // rail's contents grow underneath it — TMDB schedules arrive after the kino.pub
    // episodes and insert unaired entries, so the remembered index silently becomes a
    // different, later episode. That is how opening a series you have never watched
    // landed on episode 7. `indexPathForPreferredFocusedView` below does the same job
    // by identity, from `entryItemID`.
    view.remembersLastFocusedIndexPath = false
    view.showsHorizontalScrollIndicator = false
    view.showsVerticalScrollIndicator = false
    view.dataSource = self
    view.delegate = self
    view.prefetchDataSource = self
    view.register(TVUIKitMediaItemCell.self, forCellWithReuseIdentifier: TVUIKitMediaItemCell.reuseID)
    return view
  }()

  init(contentInset: CGFloat) {
    self.contentInset = contentInset
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  /// Reported once per layout pass so the "edge cells are clipped / the next card only
  /// loads on focus" question has measurements behind it rather than screenshots.
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    FocusLog.railGeometry(collectionView, section: "wide-rail")
  }

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
             entryItemID: Int?,
             animatesEntryScroll: Bool,
             onSelect: @escaping (Int) -> Void,
             onNearEnd: ((Int) -> Void)?,
             onFocusedItem: ((Int) -> Void)?,
             contextMenuProvider: ((Int) -> [MediaCardContextEntry])?) {
    let changed = self.items != items
    let entryMoved = self.entryItemID != entryItemID
    self.items = items
    self.entryItemID = entryItemID
    self.onSelect = onSelect
    self.onNearEnd = onNearEnd
    self.onFocusedItem = onFocusedItem
    self.contextMenuProvider = contextMenuProvider
    if changed { collectionView.reloadData() }
    if changed || entryMoved { scrollToEntry(animated: animatesEntryScroll && !changed) }
  }

  private func index(of id: Int?) -> Int? {
    guard let id else { return nil }
    return items.firstIndex { $0.id == id }
  }

  /// Park the rail on its entry item. Scrolling only — focus is asked for through
  /// `indexPathForPreferredFocusedView`, which is the hook the engine consults when it
  /// enters this rail; moving focus from here instead would fight it.
  private func scrollToEntry(animated: Bool) {
    guard let index = index(of: entryItemID) else { return }
    let path = IndexPath(item: index, section: 0)
    // After a reload the layout has no attributes yet, so the scroll has to wait a
    // pass or it silently no-ops on the first appearance — the case that matters most.
    collectionView.layoutIfNeeded()
    guard collectionView.numberOfItems(inSection: 0) > index else { return }
    FocusLog.railScroll(section: "wide-rail", toIndex: index, of: items.count, animated: animated)
    collectionView.scrollToItem(at: path, at: .left, animated: animated)
  }
}

extension TVUIKitMediaItemRailController: UICollectionViewDataSourcePrefetching {
  public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    TVUIKitRemoteImage.prefetch(imageURLs(at: indexPaths))
  }

  public func collectionView(_ collectionView: UICollectionView,
                             cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
    TVUIKitRemoteImage.cancelPrefetch(imageURLs(at: indexPaths))
  }

  private func imageURLs(at indexPaths: [IndexPath]) -> [URL?] {
    indexPaths.compactMap { path in
      items.indices.contains(path.item) ? items[path.item].imageURL : nil
    }
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

  /// Where focus lands when the engine enters this rail. This is the native hook for
  /// "start here" — the alternative is pushing focus programmatically from outside,
  /// which fights the engine and loses.
  public func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
    guard let index = index(of: entryItemID) else { return nil }
    return IndexPath(item: index, section: 0)
  }

  public func collectionView(_ collectionView: UICollectionView,
                             didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    let name: (IndexPath?) -> String? = { [weak self] path in
      guard let self, let path, self.items.indices.contains(path.item) else { return nil }
      return self.items[path.item].caption
    }
    FocusLog.engine(section: "wide-rail",
                    from: name(context.previouslyFocusedIndexPath),
                    to: name(context.nextFocusedIndexPath))

    guard let path = context.nextFocusedIndexPath, items.indices.contains(path.item) else { return }
    onFocusedItem?(items[path.item].id)
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
    // One line, on purpose. Setting `secondaryText` here produced nothing visible on
    // screen (2026-08-11), so the tile is treated as having a single caption and
    // everything worth saying is packed into `text`. The one lead never tried: Apple's
    // sample builds the configuration as `wideCell().updatedConfiguration(for: state)`
    // and we do not — if the second line is ever wanted back, start there.
    config.secondaryText = nil
    // Zero on purpose: the system's bar only appears on the focused tile, and "you
    // started this and did not finish it" is exactly what an *idle* rail has to say.
    // Ours lives in the overlay below, where we control when it shows.
    config.playbackProgress = 0
    // One corner, one chip. A state badge (Watched / a release date) is drawn by our
    // overlay and outranks the capability badge — 4K on something you cannot watch yet
    // is not the useful fact.
    if item.status.overlayBadgeText == nil, let badge = item.badgeText, !badge.isEmpty {
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
    guard let url = item.imageURL else {
      ArtworkLog.skipped(by: "wide", reason: "no artwork URL")
      return
    }
    // Already decoded — take it now so a recycled tile never shows the tint fallback
    // in place of art it had a moment ago.
    let size = contentView.bounds.size
    if let hit = TVUIKitRemoteImage.cached(url: url, size: size) {
      artwork = hit
      loadedURL = url
      ArtworkLog.servedFromMemory(url, by: "wide")
      return
    }
    ArtworkLog.requested(url, by: "wide")
    imageTask = Task { [weak self] in
      let image = await TVUIKitRemoteImage.load(url: url, size: size)
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
  /// Ours, not the configuration's. `playbackProgress` only paints on the focused tile,
  /// and "started, not finished" is precisely what an idle rail has to say — so the bar
  /// moved here, where it is on whenever there is progress.
  private let progressTrack = UIView()
  private let progressFill = UIView()
  private var progressFillWidth: NSLayoutConstraint!

  /// Keeps the corner chrome clear of the bar along the very bottom edge.
  private static let cornerInset: CGFloat = 22
  private static let glyphSize: CGFloat = 22
  private static let badgeIconSize: CGFloat = 14
  /// Fraction of the tile height the legibility gradient covers, from the bottom up.
  private static let gradientHeightFraction: CGFloat = 0.4
  private var progressFraction: CGFloat = 0

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
    TVUIKitChromeSupport.applyLegibilityShadow(to: glyphView.layer)
    addSubview(glyphView)

    runtimeLabel.translatesAutoresizingMaskIntoConstraints = false
    runtimeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 19, weight: .semibold)
    runtimeLabel.textColor = .white
    runtimeLabel.textAlignment = .right
    TVUIKitChromeSupport.applyLegibilityShadow(to: runtimeLabel.layer)
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

    progressTrack.translatesAutoresizingMaskIntoConstraints = false
    progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.28)
    progressTrack.layer.cornerRadius = 3
    progressTrack.isHidden = true
    addSubview(progressTrack)

    progressFill.translatesAutoresizingMaskIntoConstraints = false
    progressFill.backgroundColor = .white
    progressFill.layer.cornerRadius = 3
    progressTrack.addSubview(progressFill)

    badgeIconWidth = badgeIcon.widthAnchor.constraint(equalToConstant: Self.badgeIconSize)
    progressFillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)

    NSLayoutConstraint.activate([
      progressTrack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      progressTrack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
      progressTrack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
      progressTrack.heightAnchor.constraint(equalToConstant: 6),

      progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
      progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
      progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
      progressFillWidth,

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
    progressFillWidth.constant = max(progressTrack.bounds.width, 0) * progressFraction
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

    progressFraction = CGFloat(status.progress)
    progressTrack.isHidden = status.progress <= 0
    setNeedsLayout()

    let showsRuntime = status.showsRuntime && timeLabel?.isEmpty == false
    runtimeLabel.text = timeLabel
    runtimeLabel.isHidden = !showsRuntime

    if let text = status.overlayBadgeText {
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

}
#endif
