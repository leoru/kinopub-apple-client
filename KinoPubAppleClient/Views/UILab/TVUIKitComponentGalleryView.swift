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

        section("Media items — badges & progress", note: "TVMediaItemContentConfiguration, .wideCellConfiguration(), NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems(). Same API `TVUIKitMediaCollection` could ride instead of hand-rolled cells.") {
          MediaItemGalleryRow()
            .frame(height: 260)
        }

        section("Posters", note: "TVPosterView — what our TVUIKitPosterCell wraps. Optimal focusSizeIncrease is computed from the image; we don't set our own.") {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 40) {
              ForEach(GalleryContent.posters) { item in
                TVPosterViewRepresentable(item: item)
                  .frame(width: 260, height: 390)
              }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
          }
        }

        section("Cards", note: "TVCardView — a floating lockup. Custom content goes in .contentView; the system handles the focus motion for everything inside it as one unit.") {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 40) {
              ForEach(GalleryContent.cards) { item in
                TVCardViewRepresentable(item: item)
                  .frame(width: 320, height: 200)
              }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
          }
        }

        section("Caption buttons", note: "TVCaptionButtonView — a button-shaped lockup with a title/subtitle footer. The system adds a knock-out floating effect on focus.") {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 40) {
              ForEach(GalleryContent.captionButtons) { item in
                TVCaptionButtonViewRepresentable(item: item)
                  .frame(width: 240, height: 240)
              }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
          }
        }

        section("Bare lockups (header + footer)", note: "TVLockupView with no specialization — plain colored contentView plus TVLockupHeaderFooterView above and below. This is the primitive the specialized views (poster, card, caption button) are all built from.") {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 40) {
              ForEach(GalleryContent.lockups) { item in
                TVLockupViewRepresentable(item: item)
                  .frame(width: 260, height: 260)
              }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
          }
        }

        section("Monograms", note: "TVMonogramContentConfiguration — person initials composed by the system from personNameComponents when no image is set. A wide row of many, to see how the focus engine behaves with a lot of same-size, same-shape neighbors.") {
          MonogramGalleryRow()
            .frame(height: 200)
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
        TVCardViewRepresentable(item: item)
          .frame(width: 220, height: 140)
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

  static let palette: [UIColor] = [
    .systemRed, .systemOrange, .systemYellow, .systemGreen,
    .systemTeal, .systemBlue, .systemIndigo, .systemPurple, .systemPink
  ]

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

// MARK: - TVPosterView

private struct TVPosterViewRepresentable: UIViewRepresentable {
  let item: GalleryItem

  func makeUIView(context: Context) -> TVPosterView {
    let view = TVPosterView(image: GalleryContent.image(tint: item.tint, symbol: item.symbol, size: CGSize(width: 520, height: 780)))
    view.title = item.title
    view.subtitle = item.subtitle
    return view
  }

  func updateUIView(_ view: TVPosterView, context: Context) {}
}

// MARK: - TVCardView

private struct TVCardViewRepresentable: UIViewRepresentable {
  let item: GalleryItem

  func makeUIView(context: Context) -> TVCardView {
    let card = TVCardView()
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
}

// MARK: - TVCaptionButtonView

private struct TVCaptionButtonViewRepresentable: UIViewRepresentable {
  let item: GalleryItem

  func makeUIView(context: Context) -> TVCaptionButtonView {
    let button = TVCaptionButtonView()
    button.contentImage = UIImage(systemName: item.symbol)?.withRenderingMode(.alwaysTemplate)
    button.title = item.title
    button.subtitle = item.subtitle
    return button
  }

  func updateUIView(_ view: TVCaptionButtonView, context: Context) {}
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
}

// MARK: - TVMediaItemContentConfiguration row (needs a real UICollectionView)

/// `TVMediaItemContentConfiguration` backs a collection-view cell's `contentConfiguration`
/// — it is not a standalone focusable view, so unlike the lockup-family views above this
/// one genuinely needs a `UICollectionView` host. Uses the system's own
/// `orthogonalLayoutSectionForMediaItems()` rather than hand-rolled sizing.
private struct MediaItemGalleryRow: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UICollectionViewController {
    let layout = UICollectionViewCompositionalLayout { _, _ in
      .orthogonalLayoutSectionForMediaItems()
    }
    let controller = UICollectionViewController(collectionViewLayout: layout)
    controller.collectionView.backgroundColor = .clear
    let registration = UICollectionView.CellRegistration<UICollectionViewCell, Int> { cell, _, index in
      var config = TVMediaItemContentConfiguration.wideCell()
      let entry = Self.entries[index % Self.entries.count]
      config.image = GalleryContent.image(tint: entry.tint, symbol: entry.symbol, size: CGSize(width: 640, height: 360))
      config.text = entry.title
      config.secondaryText = entry.subtitle
      config.playbackProgress = entry.progress
      if let badgeText = entry.badgeText {
        config.badgeText = badgeText
        config.badgeProperties = entry.badgeProperties
      }
      cell.contentConfiguration = config
    }
    let dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: controller.collectionView) { collectionView, indexPath, item in
      collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
    }
    var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
    snapshot.appendSections([0])
    snapshot.appendItems(Array(0..<Self.entries.count))
    dataSource.apply(snapshot, animatingDifferences: false)
    context.coordinator.dataSource = dataSource
    return controller
  }

  func updateUIViewController(_ controller: UICollectionViewController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator() }
  final class Coordinator {
    var dataSource: UICollectionViewDiffableDataSource<Int, Int>?
  }

  private struct Entry {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: UIColor
    let progress: Float
    let badgeText: String?
    let badgeProperties: TVMediaItemContentConfiguration.BadgeProperties
  }

  private static let entries: [Entry] = [
    Entry(title: "No badge, no progress", subtitle: "Baseline", symbol: "film", tint: .systemBlue, progress: 0, badgeText: nil, badgeProperties: .default()),
    Entry(title: "4K badge", subtitle: "Default badge style", symbol: "4k.tv", tint: .systemIndigo, progress: 0, badgeText: "4K", badgeProperties: .default()),
    Entry(title: "30% watched", subtitle: "playbackProgress = 0.3", symbol: "play.circle", tint: .systemTeal, progress: 0.3, badgeText: nil, badgeProperties: .default()),
    Entry(title: "LIVE badge", subtitle: "liveContentBadgeProperties", symbol: "dot.radiowaves.left.and.right", tint: .systemRed, progress: 0.7, badgeText: "LIVE", badgeProperties: .liveContent()),
    Entry(title: "Fully watched", subtitle: "playbackProgress = 1.0", symbol: "checkmark.circle", tint: .systemGreen, progress: 1.0, badgeText: nil, badgeProperties: .default()),
    Entry(title: "HDR badge", subtitle: "Default badge style", symbol: "sun.max", tint: .systemOrange, progress: 0.55, badgeText: "HDR", badgeProperties: .default())
  ]
}

// MARK: - TVMonogramContentConfiguration row

private struct MonogramGalleryRow: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UICollectionViewController {
    let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(160), heightDimension: .absolute(160))
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
