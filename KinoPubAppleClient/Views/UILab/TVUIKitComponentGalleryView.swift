//
//  TVUIKitComponentGalleryView.swift
//  KinoPubAppleClient
//
//  DEBUG-only, tvOS-only. Every native TVUIKit component, bare — no custom focus code,
//  no custom scale/highlight/shadow, nothing borrowed from the rest of the app. The
//  point is to see what "native" actually looks and feels like on a real remote before
//  judging our own hand-built chrome against it, and to A/B how `.focusSection()`
//  groups rows that are shaped very differently (a wide media rail vs. a row of six
//  cards vs. a single button).
//
//  Reached from Settings → Diagnostics → "TVUIKit Gallery" (`TVProfileSettingsView`).
//

#if os(tvOS) && DEBUG
import SwiftUI
import TVUIKit
import UIKit
import KinoPubUI

struct TVUIKitComponentGalleryView: View {
  @State private var showsDigitEntry = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 56) {
        header

        section("Episode states", note: "The shipping TVUIKitMediaItemRail, one look, one tile per state — including two upcoming tiles to compare a relative date badge against an absolute one. Under the tile: the name, always visible. In the artwork: progress bar OR runtime bottom-trailing, never both, never gated by focus — the bar already says \"how far in\", so the two are mutually exclusive. A bare glyph sits bottom-leading (no pill, a drop shadow carries it). Watched and upcoming get a top-leading badge instead of the corner glyph telling the whole story; a missing episode simply has no glyph at all — no fade, no disable.") {
          TVUIKitMediaItemRail(items: GalleryContent.episodeStates, contentInset: 60, onSelect: { _ in })
        }

        section("Badges", note: "badgeText is a corner chip, not a spec sheet — one token. kino.pub's \"+10 new episodes\" counter deliberately does not feed it.") {
          TVUIKitMediaItemRail(items: GalleryContent.badgeStates, contentInset: 60, onSelect: { _ in })
        }

        section("Genre tiles", note: "The same media-item cell with no photograph: a flat tint plus an SF Symbol, colour derived from the genre name so it is stable across launches. Caption only — no glyph, no chip, no progress.") {
          TVUIKitMediaItemRail(items: GalleryContent.genreItems, contentInset: 60, onSelect: { _ in })
        }

        section("Posters", note: "TVPosterView — what our TVUIKitPosterCell wraps. Optimal focusSizeIncrease is computed from the image; we don't set our own. Each view sizes itself from its contentSize; SwiftUI must not pin a frame on it or the lockup renders inside a stretched box.") {
          lockupRow {
            ForEach(GalleryContent.posters) { item in
              TVPosterViewRepresentable(item: item)
            }
          }
        }

        section("Cards", note: "TVCardView — a floating lockup. Custom content goes in .contentView; the system handles the focus motion for everything inside it as one unit.") {
          lockupRow {
            ForEach(GalleryContent.cards) { item in
              TVCardViewRepresentable(item: item)
            }
          }
        }

        section("Caption buttons", note: "TVCaptionButtonView — a button-shaped lockup with a title/subtitle footer. The system adds a knock-out floating effect on focus.") {
          lockupRow {
            ForEach(GalleryContent.captionButtons) { item in
              TVCaptionButtonViewRepresentable(item: item)
            }
          }
        }

        section("Bare lockups (header + footer)", note: "TVLockupView with no specialization — plain colored contentView plus TVLockupHeaderFooterView above and below. This is the primitive the specialized views (poster, card, caption button) are all built from.") {
          lockupRow {
            ForEach(GalleryContent.lockups) { item in
              TVLockupViewRepresentable(item: item)
            }
          }
        }

        section("Monograms", note: "TVMonogramContentConfiguration — person initials composed by the system from personNameComponents when no image is set. A wide row of many, to see how the focus engine behaves with a lot of same-size, same-shape neighbors.") {
          MonogramGalleryRow()
            .frame(height: MonogramGalleryRow.rowHeight)
        }

        fullScreenLayoutSection

        focusSectionComparisonSection

        section("Digit entry", note: "TVDigitEntryViewController — the system PIN-entry screen, presented full-screen. Whole view controller, not embeddable as a row item.") {
          Button("Show Digit Entry") { showsDigitEntry = true }
            .buttonStyle(.card)
            .padding(.horizontal, 60)
        }
      }
      .padding(.vertical, 60)
    }
    .background(Color.KinoPub.background)
    .platformNavigationTitle("TVUIKit Gallery")
    .fullScreenCover(isPresented: $showsDigitEntry) {
      TVDigitEntryRepresentable {
        showsDigitEntry = false
      }
      .ignoresSafeArea()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("TVUIKit Component Gallery")
        .font(TypeScale.settingsTitle)
      Text("Every row below is a real TVUIKit view, bare. No custom scale, highlight, shadow, or focus code anywhere on this page — whatever motion and chrome you see is entirely system-owned.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 900, alignment: .leading)
    }
    .padding(.horizontal, 60)
  }

  /// A row of self-sizing lockups. No `.frame` on the items — a `TVLockupView` lays out
  /// from its own `contentSize`, so forcing a SwiftUI frame stretches the outer control
  /// and leaves the real content sitting in a corner of an over-large box. The scroll
  /// view also has to stop clipping, or the focus lift is sheared off at the row edges.
  @ViewBuilder
  private func lockupRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .center, spacing: 40) {
        content()
      }
      .padding(.horizontal, 60)
      .padding(.vertical, 40)
    }
    .scrollClipDisabled()
  }

  @ViewBuilder
  private func section<Content: View>(
    _ title: String,
    note: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(TypeScale.detailSection)
        Text(note)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: 1200, alignment: .leading)
      }
      .padding(.horizontal, 60)

      content()
    }
    .focusSection()
  }

  // MARK: - Full-screen layout

  /// Rough demo — `TVCollectionViewFullScreenLayout` is designed to own the whole
  /// screen (an autoplay hero carousel), and squeezing it into a fixed-height row here
  /// is not how Apple intends it to be used. Good enough to see the parallax/mask/paging
  /// feel; not a template to copy for the real thing.
  private var fullScreenLayoutSection: some View {
    section("Full-screen layout (rough demo)", note: "TVCollectionViewFullScreenLayout — parallax, masking, centered-cell paging. Meant to own the whole screen (an autoplay hero carousel); boxed into a fixed height here just to see the motion. Left/Right to page.") {
      FullScreenLayoutGalleryRow()
        .frame(height: 500)
    }
  }

  // MARK: - focusSection comparison

  /// Two identically-shaped groups of two short rows each, one wrapped as a single
  /// `.focusSection()` and one left as two separate adjacent sections — the exact
  /// question asked: does Up/Down inside a merged section behave differently from
  /// crossing between two sibling ones.
  private var focusSectionComparisonSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("focusSection() comparison")
          .font(TypeScale.detailSection)
        Text("Left: two rows merged into ONE .focusSection(). Right: the same two rows as TWO separate, adjacent .focusSection()s. Move Up/Down between the rows on each side and compare.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: 1200, alignment: .leading)
      }
      .padding(.horizontal, 60)

      HStack(alignment: .top, spacing: 80) {
        VStack(alignment: .leading, spacing: 24) {
          Text("Merged").font(.caption).foregroundStyle(.tertiary)
          comparisonRow(GalleryContent.comparisonTopRow)
          comparisonRow(GalleryContent.comparisonBottomRow)
        }
        .focusSection()

        VStack(alignment: .leading, spacing: 24) {
          Text("Separate").font(.caption).foregroundStyle(.tertiary)
          comparisonRow(GalleryContent.comparisonTopRow)
            .focusSection()
          comparisonRow(GalleryContent.comparisonBottomRow)
            .focusSection()
        }
      }
      .padding(.horizontal, 60)
    }
  }

  private func comparisonRow(_ items: [GalleryItem]) -> some View {
    HStack(spacing: 24) {
      ForEach(items) { item in
        TVCardViewRepresentable(item: item, contentSize: CGSize(width: 220, height: 140))
      }
    }
  }
}

// MARK: - Content

private struct GalleryItem: Identifiable {
  let id: Int
  let title: String
  let subtitle: String?
  let symbol: String
  let tint: UIColor
}

private enum GalleryContent {
  static let posters: [GalleryItem] = (0..<8).map { i in
    GalleryItem(id: i, title: "Poster \(i + 1)", subtitle: "Subtitle", symbol: "film", tint: palette[i % palette.count])
  }
  static let cards: [GalleryItem] = (0..<6).map { i in
    GalleryItem(id: i, title: "Card \(i + 1)", subtitle: nil, symbol: "square.stack", tint: palette[i % palette.count])
  }
  static let captionButtons: [GalleryItem] = (0..<5).map { i in
    GalleryItem(id: i, title: "Action \(i + 1)", subtitle: "Footer line", symbol: "play.fill", tint: palette[i % palette.count])
  }
  static let lockups: [GalleryItem] = (0..<4).map { i in
    GalleryItem(id: i, title: "Lockup \(i + 1)", subtitle: "Footer", symbol: "square.dashed", tint: palette[i % palette.count])
  }
  static let comparisonTopRow: [GalleryItem] = (0..<3).map { i in
    GalleryItem(id: 100 + i, title: "Top \(i + 1)", subtitle: nil, symbol: "arrow.up", tint: palette[i % palette.count])
  }
  static let comparisonBottomRow: [GalleryItem] = (0..<3).map { i in
    GalleryItem(id: 200 + i, title: "Bottom \(i + 1)", subtitle: nil, symbol: "arrow.down", tint: palette[(i + 2) % palette.count])
  }

  static let palette: [UIColor] = TVUIKitTileArtwork.palette

  /// One tile per state a rail of episodes actually contains. Caption is exactly what
  /// ships: "S# E# · Show" for an episode, the bare title for a movie. No network
  /// behind any of them — flat tint artwork, so this page stays pure layout.
  static let episodeStates: [TVUIKitMediaItem] = [
    TVUIKitMediaItem(id: 1, tint: .systemTeal, symbol: "film",
                     caption: "S1 E1 · Futurama",
                     status: .ready, timeLabel: "22m"),
    TVUIKitMediaItem(id: 2, tint: .systemBlue, symbol: "film",
                     caption: "S1 E2 · Futurama",
                     status: .inProgress(0.35)),
    TVUIKitMediaItem(id: 3, tint: .systemIndigo, symbol: "film",
                     caption: "S1 E3 · Futurama",
                     status: .watched, timeLabel: "22m"),
    TVUIKitMediaItem(id: 4, tint: .systemGray, symbol: "film",
                     caption: "S1 E4 · Futurama",
                     status: .unavailable),
    TVUIKitMediaItem(id: 5, tint: .systemGray, symbol: "calendar",
                     caption: "S1 E5 · Futurama",
                     status: .upcoming("in 3 days")),
    TVUIKitMediaItem(id: 6, tint: .systemGray, symbol: "calendar",
                     caption: "S1 E6 · Futurama",
                     status: .upcoming("Mar 13, 2026"))
  ]

  static let badgeStates: [TVUIKitMediaItem] = [
    TVUIKitMediaItem(id: 301, tint: .systemBlue, symbol: "film",
                     caption: "Arrival", status: .ready, timeLabel: "1h 56m"),
    TVUIKitMediaItem(id: 302, tint: .systemIndigo, symbol: "4k.tv",
                     caption: "Dune", status: .ready, timeLabel: "2h 35m", badgeText: "4K"),
    TVUIKitMediaItem(id: 303, tint: .systemOrange, symbol: "sun.max",
                     caption: "Chernobyl", status: .inProgress(0.55), badgeText: "HDR"),
    TVUIKitMediaItem(id: 304, tint: .systemRed, symbol: "dot.radiowaves.left.and.right",
                     caption: "Channel One", status: .ready,
                     badgeText: "LIVE", badgeIsLive: true)
  ]

  static let genreItems: [TVUIKitMediaItem] = [
    ("Action", "flame"), ("Comedy", "theatermasks"), ("Drama", "drop"),
    ("Sci-Fi", "sparkles"), ("Documentary", "globe"), ("Horror", "moon.stars"),
    ("Animation", "pawprint"), ("Thriller", "bolt")
  ].enumerated().map { index, entry in
    TVUIKitMediaItem(id: 400 + index, genre: entry.0, symbol: entry.1)
  }

  /// Synchronous solid-color image so every component has real artwork to focus-scale
  /// without a network fetch — this page is meant to be pure layout, no loading state.
  static func image(tint: UIColor, symbol: String, size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      tint.withAlphaComponent(0.85).setFill()
      UIRectFill(CGRect(origin: .zero, size: size))
      let config = UIImage.SymbolConfiguration(pointSize: min(size.width, size.height) * 0.35, weight: .semibold)
      if let glyph = UIImage(systemName: symbol, withConfiguration: config)?.withTintColor(.white.withAlphaComponent(0.9), renderingMode: .alwaysOriginal) {
        let origin = CGPoint(x: (size.width - glyph.size.width) / 2, y: (size.height - glyph.size.height) / 2)
        glyph.draw(at: origin)
      }
    }
  }
}

// MARK: - Self-sizing

/// Every lockup here reports the size it actually wants, so SwiftUI proposes that
/// instead of stretching the control to fill a hand-picked frame — a stretched
/// `TVLockupView` keeps laying its content out at `contentSize` and leaves the rest of
/// the box empty, which is what made these rows look cropped.
///
/// `contentSize` alone is not the answer: the header/footer and the focus headroom sit
/// outside it, so the view is asked what it actually wants. The fallback covers a
/// lockup that reports nothing rather than collapsing the tile to a hairline.
private extension UIViewRepresentable where UIViewType: TVLockupView {
  func lockupSize(_ view: UIViewType, fallback: CGSize) -> CGSize {
    let fitted = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    guard fitted.width > 1, fitted.height > 1 else { return fallback }
    return fitted
  }
}

// MARK: - TVPosterView

private struct TVPosterViewRepresentable: UIViewRepresentable {
  let item: GalleryItem

  func makeUIView(context: Context) -> TVPosterView {
    let view = TVPosterView(image: GalleryContent.image(tint: item.tint, symbol: item.symbol, size: CGSize(width: 520, height: 780)))
    view.title = item.title
    view.subtitle = item.subtitle
    // Without this the poster's natural size is the image's own 520×780.
    view.contentSize = CGSize(width: 260, height: 390)
    return view
  }

  func updateUIView(_ view: TVPosterView, context: Context) {}

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: TVPosterView, context: Context) -> CGSize? {
    lockupSize(uiView, fallback: CGSize(width: 260, height: 440))
  }
}

// MARK: - TVCardView

private struct TVCardViewRepresentable: UIViewRepresentable {
  let item: GalleryItem
  var contentSize = CGSize(width: 320, height: 200)

  func makeUIView(context: Context) -> TVCardView {
    let card = TVCardView()
    card.contentSize = contentSize
    let imageView = UIImageView(image: GalleryContent.image(tint: item.tint, symbol: item.symbol, size: CGSize(width: 640, height: 400)))
    imageView.contentMode = .scaleAspectFill
    imageView.clipsToBounds = true
    imageView.translatesAutoresizingMaskIntoConstraints = false
    card.contentView.addSubview(imageView)
    NSLayoutConstraint.activate([
      imageView.topAnchor.constraint(equalTo: card.contentView.topAnchor),
      imageView.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor),
      imageView.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor),
      imageView.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor)
    ])

    let footer = TVLockupHeaderFooterView()
    footer.titleLabel?.text = item.title
    card.footerView = footer
    return card
  }

  func updateUIView(_ view: TVCardView, context: Context) {}

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: TVCardView, context: Context) -> CGSize? {
    lockupSize(uiView, fallback: CGSize(width: contentSize.width, height: contentSize.height + 50))
  }
}

// MARK: - TVCaptionButtonView

private struct TVCaptionButtonViewRepresentable: UIViewRepresentable {
  let item: GalleryItem

  func makeUIView(context: Context) -> TVCaptionButtonView {
    let button = TVCaptionButtonView()
    button.contentImage = UIImage(systemName: item.symbol)?.withRenderingMode(.alwaysTemplate)
    button.title = item.title
    button.subtitle = item.subtitle
    button.contentSize = CGSize(width: 240, height: 160)
    return button
  }

  func updateUIView(_ view: TVCaptionButtonView, context: Context) {}

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: TVCaptionButtonView, context: Context) -> CGSize? {
    lockupSize(uiView, fallback: CGSize(width: 240, height: 250))
  }
}

// MARK: - Bare TVLockupView

/// Conforms to `TVLockupViewComponent`, so it is one of the few things on this page that
/// *does* react to the lockup's state — a straight opacity bump on focus/highlight, to
/// show what a component participating (vs. `TVCardView`'s `contentView`, which the
/// system animates on its own with no protocol needed) looks like.
private final class LockupComponentBox: UIView, TVLockupViewComponent {
  func updateAppearance(forLockupViewState state: UIControl.State) {
    UIView.animate(withDuration: 0.2) {
      self.alpha = state.contains(.focused) ? 1 : 0.6
    }
  }
}

private struct TVLockupViewRepresentable: UIViewRepresentable {
  let item: GalleryItem

  func makeUIView(context: Context) -> TVLockupView {
    let lockup = TVLockupView()
    lockup.contentSize = CGSize(width: 220, height: 140)

    let box = LockupComponentBox()
    box.backgroundColor = item.tint.withAlphaComponent(0.85)
    box.layer.cornerRadius = 14
    box.layer.cornerCurve = .continuous
    box.translatesAutoresizingMaskIntoConstraints = false
    lockup.contentView.addSubview(box)
    NSLayoutConstraint.activate([
      box.topAnchor.constraint(equalTo: lockup.contentView.topAnchor),
      box.bottomAnchor.constraint(equalTo: lockup.contentView.bottomAnchor),
      box.leadingAnchor.constraint(equalTo: lockup.contentView.leadingAnchor),
      box.trailingAnchor.constraint(equalTo: lockup.contentView.trailingAnchor)
    ])

    let header = TVLockupHeaderFooterView()
    header.titleLabel?.text = item.title
    lockup.headerView = header

    let footer = TVLockupHeaderFooterView()
    footer.titleLabel?.text = item.subtitle
    footer.showsOnlyWhenAncestorFocused = true
    lockup.footerView = footer

    return lockup
  }

  func updateUIView(_ view: TVLockupView, context: Context) {}

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: TVLockupView, context: Context) -> CGSize? {
    lockupSize(uiView, fallback: CGSize(width: 220, height: 240))
  }
}

// MARK: - TVMonogramContentConfiguration row

private struct MonogramGalleryRow: UIViewControllerRepresentable {
  /// The circle is 160, but the cell also stacks `text` + `secondaryText` under it and
  /// grows on focus — sizing the item to the circle alone clips both.
  static let itemHeight: CGFloat = 260
  static let rowHeight: CGFloat = itemHeight + 40

  func makeUIViewController(context: Context) -> UICollectionViewController {
    let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(160),
                                          heightDimension: .absolute(Self.itemHeight))
    let item = NSCollectionLayoutItem(layoutSize: itemSize)
    let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
    let section = NSCollectionLayoutSection(group: group)
    section.orthogonalScrollingBehavior = .continuous
    section.interGroupSpacing = 32
    section.contentInsets = .init(top: 20, leading: 60, bottom: 20, trailing: 60)
    let layout = UICollectionViewCompositionalLayout(section: section)

    let controller = UICollectionViewController(collectionViewLayout: layout)
    controller.collectionView.backgroundColor = .clear
    let registration = UICollectionView.CellRegistration<UICollectionViewCell, Int> { cell, _, index in
      var config = TVMonogramContentConfiguration.cell()
      let name = Self.names[index % Self.names.count]
      config.personNameComponents = name
      config.text = name.givenName
      config.secondaryText = name.familyName
      cell.contentConfiguration = config
    }
    let dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: controller.collectionView) { collectionView, indexPath, item in
      collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
    }
    var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
    snapshot.appendSections([0])
    snapshot.appendItems(Array(0..<Self.names.count))
    dataSource.apply(snapshot, animatingDifferences: false)
    context.coordinator.dataSource = dataSource
    return controller
  }

  func updateUIViewController(_ controller: UICollectionViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator() }
  final class Coordinator {
    var dataSource: UICollectionViewDiffableDataSource<Int, Int>?
  }

  private static let names: [PersonNameComponents] = {
    let pairs = [("Ada", "Lovelace"), ("Grace", "Hopper"), ("Alan", "Turing"), ("Katherine", "Johnson"),
                 ("Margaret", "Hamilton"), ("Dennis", "Ritchie"), ("Barbara", "Liskov"), ("Donald", "Knuth"),
                 ("Radia", "Perlman"), ("Linus", "Torvalds")]
    return pairs.map { given, family in
      var components = PersonNameComponents()
      components.givenName = given
      components.familyName = family
      return components
    }
  }()
}

// MARK: - TVCollectionViewFullScreenLayout row

private struct FullScreenLayoutGalleryRow: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UICollectionViewController {
    let layout = TVCollectionViewFullScreenLayout()
    let controller = UICollectionViewController(collectionViewLayout: layout)
    controller.collectionView.backgroundColor = .clear
    controller.collectionView.register(FullScreenGalleryCell.self, forCellWithReuseIdentifier: FullScreenGalleryCell.reuseID)
    controller.collectionView.dataSource = context.coordinator
    context.coordinator.tints = GalleryContent.palette
    return controller
  }

  func updateUIViewController(_ controller: UICollectionViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator() }

  final class Coordinator: NSObject, UICollectionViewDataSource {
    var tints: [UIColor] = []

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      tints.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FullScreenGalleryCell.reuseID, for: indexPath) as! FullScreenGalleryCell
      cell.configure(tint: tints[indexPath.item], label: "Slide \(indexPath.item + 1)")
      return cell
    }
  }
}

/// Minimal `TVCollectionViewFullScreenCell` — a solid-tint background (what the layout
/// parallaxes) and a centered label (what gets focused/masked).
private final class FullScreenGalleryCell: TVCollectionViewFullScreenCell {
  static let reuseID = "FullScreenGalleryCell"
  private let label = UILabel()

  override init(frame: CGRect) {
    super.init(frame: frame)
    let background = UIView()
    background.translatesAutoresizingMaskIntoConstraints = false
    maskedBackgroundView.addSubview(background)
    NSLayoutConstraint.activate([
      background.topAnchor.constraint(equalTo: maskedBackgroundView.topAnchor),
      background.bottomAnchor.constraint(equalTo: maskedBackgroundView.bottomAnchor),
      background.leadingAnchor.constraint(equalTo: maskedBackgroundView.leadingAnchor),
      background.trailingAnchor.constraint(equalTo: maskedBackgroundView.trailingAnchor)
    ])
    tintBackground = background

    label.font = .systemFont(ofSize: 48, weight: .bold)
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    maskedContentView.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: maskedContentView.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: maskedContentView.centerYAnchor)
    ])
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private weak var tintBackground: UIView?

  func configure(tint: UIColor, label text: String) {
    tintBackground?.backgroundColor = tint.withAlphaComponent(0.85)
    label.text = text
  }
}

// MARK: - TVDigitEntryViewController

private struct TVDigitEntryRepresentable: UIViewControllerRepresentable {
  var onComplete: () -> Void

  func makeUIViewController(context: Context) -> TVDigitEntryViewController {
    let controller = TVDigitEntryViewController()
    controller.titleText = "TVDigitEntryViewController"
    controller.promptText = "Any 4 digits dismiss this"
    controller.numberOfDigits = 4
    controller.entryCompletionHandler = { _ in
      DispatchQueue.main.async(execute: onComplete)
    }
    return controller
  }

  func updateUIViewController(_ controller: TVDigitEntryViewController, context: Context) {}
}
#endif
