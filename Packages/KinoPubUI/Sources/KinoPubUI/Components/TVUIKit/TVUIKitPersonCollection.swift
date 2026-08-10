#if os(tvOS)
//
//  TVUIKitPersonCollection.swift
//  KinoPubUI
//
//  Circular person rail — `TVMonogramContentConfiguration` (system-drawn initials
//  from `personNameComponents` when there's no photo, native focus motion) instead of
//  a hand-rolled avatar view. Same shape as `TVUIKitMediaCollection`, much smaller:
//  the system content configuration owns focus scale/motion itself, so unlike
//  `TVUIKitPosterCell` there is no custom `didUpdateFocus`/stale-appearance reset here.
//

import SwiftUI
import UIKit
import TVUIKit

/// One row entry for `TVUIKitPersonCollection` — cast/crew today, any person rail later.
public struct TVUIKitPerson: Identifiable, Hashable {
  public let id: String
  public let name: String
  public let nameComponents: PersonNameComponents
  /// Character or role, shown under the name.
  public let caption: String?
  public let photoURL: URL?

  public init(id: String,
              name: String,
              nameComponents: PersonNameComponents,
              caption: String?,
              photoURL: URL?) {
    self.id = id
    self.name = name
    self.nameComponents = nameComponents
    self.caption = caption
    self.photoURL = photoURL
  }

  /// kino.pub credits are one flat string, so the split is positional: first word is
  /// the given name, the rest the family name. `TVMonogramContentConfiguration` uses
  /// these only to compose the initials it draws when there is no photo — which is why
  /// the rail and the person page must parse a name the same way, or the same person
  /// gets different initials on two screens.
  public static func nameComponents(from name: String) -> PersonNameComponents {
    var components = PersonNameComponents()
    let parts = name.split(separator: " ", omittingEmptySubsequences: true)
    components.givenName = parts.first.map(String.init)
    if parts.count > 1 {
      components.familyName = parts.dropFirst().joined(separator: " ")
    }
    return components
  }
}

public struct TVUIKitPersonCollection: UIViewControllerRepresentable {
  public let people: [TVUIKitPerson]
  public let onSelect: (TVUIKitPerson) -> Void
  /// Fired when focus lands on any cell. SwiftUI's `@Environment(\.isFocused)` does
  /// not cross into UIKit cells, so a caller that needs "this section is current"
  /// (the detail page's backdrop wash) has to be told from the focus engine directly.
  public let onCellFocused: (() -> Void)?
  public let contextMenuProvider: ((TVUIKitPerson) -> [MediaCardContextEntry])?

  public init(people: [TVUIKitPerson],
              onSelect: @escaping (TVUIKitPerson) -> Void,
              onCellFocused: (() -> Void)? = nil,
              contextMenuProvider: ((TVUIKitPerson) -> [MediaCardContextEntry])? = nil) {
    self.people = people
    self.onSelect = onSelect
    self.onCellFocused = onCellFocused
    self.contextMenuProvider = contextMenuProvider
  }

  public func makeUIViewController(context: Context) -> TVUIKitPersonCollectionController {
    let vc = TVUIKitPersonCollectionController()
    vc.apply(people: people,
             onSelect: onSelect,
             onCellFocused: onCellFocused,
             contextMenuProvider: contextMenuProvider)
    return vc
  }

  public func updateUIViewController(_ vc: TVUIKitPersonCollectionController, context: Context) {
    vc.apply(people: people,
             onSelect: onSelect,
             onCellFocused: onCellFocused,
             contextMenuProvider: contextMenuProvider)
  }
}

@MainActor
public final class TVUIKitPersonCollectionController: UIViewController {
  private var people: [TVUIKitPerson] = []
  private var onSelect: ((TVUIKitPerson) -> Void)?
  private var onCellFocused: (() -> Void)?
  private var contextMenuProvider: ((TVUIKitPerson) -> [MediaCardContextEntry])?

  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    layout.minimumLineSpacing = Self.spacing
    layout.minimumInteritemSpacing = Self.spacing
    layout.itemSize = Self.itemSize
    layout.sectionInset = UIEdgeInsets(top: Self.focusRoom,
                                       left: Self.inset,
                                       bottom: Self.focusRoom,
                                       right: Self.inset)
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.backgroundColor = .clear
    view.showsHorizontalScrollIndicator = false
    view.remembersLastFocusedIndexPath = true
    view.clipsToBounds = false
    view.dataSource = self
    view.delegate = self
    view.prefetchDataSource = self
    view.register(TVUIKitPersonCell.self, forCellWithReuseIdentifier: TVUIKitPersonCell.reuseID)
    view.accessibilityIdentifier = "cast-rail"
    return view
  }()

  /// Reported once per layout pass so the "edge cells are clipped / the next card only
  /// loads on focus" question has measurements behind it rather than screenshots.
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    FocusLog.railGeometry(collectionView, section: "cast-rail")
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

  func apply(people: [TVUIKitPerson],
             onSelect: @escaping (TVUIKitPerson) -> Void,
             onCellFocused: (() -> Void)?,
             contextMenuProvider: ((TVUIKitPerson) -> [MediaCardContextEntry])?) {
    let changed = self.people.map(\.id) != people.map(\.id)
    self.people = people
    self.onSelect = onSelect
    self.onCellFocused = onCellFocused
    self.contextMenuProvider = contextMenuProvider
    if changed {
      collectionView.reloadData()
    }
  }

  /// Circle + two lines of text under it — sized generously (native TVUIKit monogram
  /// cells read small at portrait-poster scale); proportioned against the app's other
  /// tvOS landscape/poster rail metrics rather than the DEBUG gallery's own numbers.
  static let circleDiameter: CGFloat = 168
  static let itemSize = CGSize(width: circleDiameter + 32, height: circleDiameter + 96)
  /// Spacing and focus room from the same rule the poster rails use: a focused circle
  /// grows into its neighbour's half of the gap, so a constant that looks right at rest
  /// has the avatars overlapping the moment one of them lights up.
  static var spacing: CGFloat { ShelfMetrics.tvGutter(cardWidth: itemSize.width) }
  static var focusRoom: CGFloat {
    TVUIKitPosterMetrics.focusGrowthPadding(tileHeight: itemSize.height)
  }
  static let inset: CGFloat = 80
  /// Item plus the focus-lift room the section insets reserve above and below.
  public static var railHeight: CGFloat { itemSize.height + focusRoom * 2 }
}

extension TVUIKitPersonCollectionController: UICollectionViewDataSourcePrefetching {
  public func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    TVUIKitRemoteImage.prefetch(indexPaths.compactMap { path in
      people.indices.contains(path.item) ? people[path.item].photoURL : nil
    })
  }
}

extension TVUIKitPersonCollectionController: UICollectionViewDataSource, UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    people.count
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: TVUIKitPersonCell.reuseID,
      for: indexPath
    ) as! TVUIKitPersonCell
    cell.configure(person: people[indexPath.item])
    return cell
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    onSelect?(people[indexPath.item])
  }

  public func collectionView(_ collectionView: UICollectionView,
                             didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                             with coordinator: UIFocusAnimationCoordinator) {
    let name: (IndexPath?) -> String? = { [weak self] path in
      guard let self, let path, self.people.indices.contains(path.item) else { return nil }
      return self.people[path.item].name
    }
    FocusLog.engine(section: "cast-rail",
                    from: name(context.previouslyFocusedIndexPath),
                    to: name(context.nextFocusedIndexPath))

    guard context.nextFocusedIndexPath != nil else { return }
    onCellFocused?()
  }

  // Same tvOS long-press-Select routing as `TVUIKitMediaCollectionController` — the
  // gesture goes to the collection view's delegate hook, not a per-cell interaction.
  public func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let indexPath = indexPaths.first,
          people.indices.contains(indexPath.item),
          let entries = contextMenuProvider?(people[indexPath.item]),
          !entries.isEmpty
    else { return nil }

    return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { _ in
      TVUIKitContextMenuBuilder.menu(from: entries)
    }
  }
}

/// `TVMonogramContentConfiguration` on a plain `UICollectionViewListCell` — the system
/// draws the circle, the focus scale, and the initials-from-name fallback; this only
/// owns fetching the photo (when there is one) and re-applying the configuration once
/// it arrives, same async-load-with-cancellation shape as `TVUIKitPosterCell`.
@MainActor
final class TVUIKitPersonCell: UICollectionViewCell {
  static let reuseID = "TVUIKitPersonCell"

  private var imageTask: Task<Void, Never>?
  private var currentURL: URL?

  func configure(person: TVUIKitPerson) {
    imageTask?.cancel()
    imageTask = nil
    currentURL = person.photoURL

    var config = TVMonogramContentConfiguration.cell()
    config.text = person.name
    config.secondaryText = person.caption
    config.personNameComponents = person.nameComponents
    // Decoded art up front. The monogram is the *fallback* for someone we have no
    // portrait of — a recycled cell must not flash initials over a face that was on
    // screen a moment ago, which is what rebuilding the configuration empty did.
    config.image = TVUIKitRemoteImage.cached(url: person.photoURL)
    contentConfiguration = config

    guard let url = person.photoURL else {
      ArtworkLog.skipped(by: "cast/\(person.name)", reason: "no photo URL")
      return
    }
    if config.image != nil {
      ArtworkLog.servedFromMemory(url, by: "cast/\(person.name)")
      return
    }
    ArtworkLog.requested(url, by: "cast/\(person.name)")
    imageTask = Task { [weak self] in
      let image = await TVUIKitRemoteImage.load(url: url)
      await MainActor.run {
        guard let self, !Task.isCancelled, self.currentURL == url,
              let image, var config = self.contentConfiguration as? TVMonogramContentConfiguration
        else { return }
        config.image = image
        self.contentConfiguration = config
      }
    }
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    imageTask?.cancel()
    imageTask = nil
    currentURL = nil
  }
}
#endif
