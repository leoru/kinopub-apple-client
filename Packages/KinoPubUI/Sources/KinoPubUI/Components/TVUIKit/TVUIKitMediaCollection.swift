#if os(tvOS)
//
//  TVUIKitMediaCollection.swift
//  KinoPubUI
//
//  One UICollectionView for both Home shelves (horizontal) and catalog grids
//  (vertical). Same `TVUIKitPosterCell` / `TVUIKitContinueWatchingCell` either way.
//

import SwiftUI
import UIKit

public enum TVUIKitCollectionAxis {
  case horizontal
  case vertical
}

public struct TVUIKitMediaCollection: UIViewControllerRepresentable {
  public let cards: [MediaCard]
  public let axis: TVUIKitCollectionAxis
  public let containerWidth: CGFloat
  public let typeSize: DynamicTypeSize
  public let onSelect: (MediaCard) -> Void
  public let onNearEnd: ((MediaCard) -> Void)?
  public let contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])?

  public init(cards: [MediaCard],
              axis: TVUIKitCollectionAxis,
              containerWidth: CGFloat,
              typeSize: DynamicTypeSize = .large,
              onSelect: @escaping (MediaCard) -> Void,
              onNearEnd: ((MediaCard) -> Void)? = nil,
              contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])? = nil) {
    self.cards = cards
    self.axis = axis
    self.containerWidth = containerWidth
    self.typeSize = typeSize
    self.onSelect = onSelect
    self.onNearEnd = onNearEnd
    self.contextMenuProvider = contextMenuProvider
  }

  public func makeUIViewController(context: Context) -> TVUIKitMediaCollectionController {
    let vc = TVUIKitMediaCollectionController()
    vc.apply(cards: cards,
             axis: axis,
             containerWidth: containerWidth,
             typeSize: typeSize,
             onSelect: onSelect,
             onNearEnd: onNearEnd,
             contextMenuProvider: contextMenuProvider)
    return vc
  }

  public func updateUIViewController(_ vc: TVUIKitMediaCollectionController, context: Context) {
    vc.apply(cards: cards,
             axis: axis,
             containerWidth: containerWidth,
             typeSize: typeSize,
             onSelect: onSelect,
             onNearEnd: onNearEnd,
             contextMenuProvider: contextMenuProvider)
  }
}

@MainActor
public final class TVUIKitMediaCollectionController: UIViewController {
  private var cards: [MediaCard] = []
  private var axis: TVUIKitCollectionAxis = .horizontal
  private var containerWidth: CGFloat = 1920
  private var typeSize: DynamicTypeSize = .large
  private var isLandscape = false
  private var tileSize: CGSize = .zero
  private var itemSize: CGSize = .zero
  private var gutter: CGFloat = 20
  private var inset: CGFloat = 40

  private var onSelect: ((MediaCard) -> Void)?
  private var onNearEnd: ((MediaCard) -> Void)?
  private var contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])?

  private lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.scrollDirection = .horizontal
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.backgroundColor = .clear
    view.showsHorizontalScrollIndicator = false
    view.showsVerticalScrollIndicator = false
    view.remembersLastFocusedIndexPath = true
    view.clipsToBounds = false
    view.dataSource = self
    view.delegate = self
    view.register(TVUIKitPosterCell.self, forCellWithReuseIdentifier: TVUIKitPosterCell.reuseID)
    view.register(
      TVUIKitContinueWatchingCell.self,
      forCellWithReuseIdentifier: TVUIKitContinueWatchingCell.reuseID
    )
    return view
  }()

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

  func apply(cards: [MediaCard],
             axis: TVUIKitCollectionAxis,
             containerWidth: CGFloat,
             typeSize: DynamicTypeSize,
             onSelect: @escaping (MediaCard) -> Void,
             onNearEnd: ((MediaCard) -> Void)?,
             contextMenuProvider: ((MediaCard) -> [MediaCardContextEntry])?) {
    let width = max(containerWidth, 1)
    let landscape = cards.first?.isLandscape == true
    let metrics = TVUIKitPosterMetrics.shelfMetrics(
      isLandscape: landscape,
      containerWidth: width,
      typeSize: typeSize
    )
    let tile = landscape
      ? TVUIKitPosterMetrics.landscapeSize(containerWidth: width, typeSize: typeSize)
      : TVUIKitPosterMetrics.posterSize(containerWidth: width, typeSize: typeSize)
    let item = TVUIKitPosterMetrics.itemSize(
      isLandscape: landscape,
      containerWidth: width,
      typeSize: typeSize
    )

    let cardsChanged = self.cards.map(\.id) != cards.map(\.id)
      || self.cards.map(\.progress) != cards.map(\.progress)
      || self.cards.map(\.isWatched) != cards.map(\.isWatched)
    let layoutChanged = abs(self.containerWidth - width) > 0.5
      || self.axis != axis
      || isLandscape != landscape
      || abs(itemSize.width - item.width) > 0.5
      || abs(itemSize.height - item.height) > 0.5

    self.cards = cards
    self.axis = axis
    self.containerWidth = width
    self.typeSize = typeSize
    self.isLandscape = landscape
    self.tileSize = tile
    self.itemSize = item
    self.gutter = metrics.gutter
    self.inset = metrics.inset
    self.onSelect = onSelect
    self.onNearEnd = onNearEnd
    self.contextMenuProvider = contextMenuProvider

    if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
      layout.scrollDirection = axis == .horizontal ? .horizontal : .vertical
      layout.minimumLineSpacing = gutter
      layout.minimumInteritemSpacing = gutter
      layout.sectionInset = UIEdgeInsets(
        top: landscape ? Metrics.landscapeFocusPadding : Metrics.focusPadding,
        left: inset,
        bottom: landscape ? Metrics.landscapeFocusPadding : Metrics.focusPadding,
        right: inset
      )
      layout.itemSize = item
    }

    collectionView.alwaysBounceHorizontal = axis == .horizontal
    collectionView.alwaysBounceVertical = axis == .vertical

    if cardsChanged || layoutChanged {
      collectionView.reloadData()
    }
  }
}

extension TVUIKitMediaCollectionController: UICollectionViewDataSource, UICollectionViewDelegate {
  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    cards.count
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    cellForItemAt indexPath: IndexPath
  ) -> UICollectionViewCell {
    let card = cards[indexPath.item]
    if isLandscape {
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: TVUIKitContinueWatchingCell.reuseID,
        for: indexPath
      ) as! TVUIKitContinueWatchingCell
      cell.configure(card: card, size: tileSize)
      return cell
    }

    let cell = collectionView.dequeueReusableCell(
      withReuseIdentifier: TVUIKitPosterCell.reuseID,
      for: indexPath
    ) as! TVUIKitPosterCell
    cell.configure(card: card, size: tileSize)
    return cell
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    onSelect?(cards[indexPath.item])
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    willDisplay cell: UICollectionViewCell,
    forItemAt indexPath: IndexPath
  ) {
    onNearEnd?(cards[indexPath.item])
  }

  // MARK: - Context menu
  //
  // tvOS routes the long-press-Select gesture to the *focused* view and up its
  // responder chain, so an interaction installed on a cell's `contentView` (a
  // descendant of the focus item) never fires. The collection view's own delegate
  // hook is the path UIKit wires to the focus engine — and on tvOS only the
  // `…ForItemsAt indexPaths:` variant exists; the single-indexPath one is
  // `API_UNAVAILABLE(tvos)`.

  public func collectionView(
    _ collectionView: UICollectionView,
    contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
    point: CGPoint
  ) -> UIContextMenuConfiguration? {
    guard let indexPath = indexPaths.first,
          cards.indices.contains(indexPath.item),
          let entries = contextMenuProvider?(cards[indexPath.item]),
          !entries.isEmpty
    else { return nil }

    return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { _ in
      TVUIKitContextMenuBuilder.menu(from: entries)
    }
  }

  public func collectionView(
    _ collectionView: UICollectionView,
    willEndContextMenuInteractionWith configuration: UIContextMenuConfiguration,
    animator: (any UIContextMenuInteractionAnimating)?
  ) {
    // Same TVPosterView stranding as after a focus change — the lifted poster can
    // stay enlarged once the menu's preview hands the cell back.
    let reset: () -> Void = { [weak self] in
      guard let self else { return }
      collectionView.visibleCells
        .compactMap { $0 as? TVUIKitPosterCell }
        .forEach { $0.resetStaleFocusAppearance() }
    }
    if let animator {
      animator.addCompletion(reset)
    } else {
      reset()
    }
  }
}
#endif
