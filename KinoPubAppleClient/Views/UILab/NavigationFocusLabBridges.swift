//
//  NavigationFocusLabBridges.swift
//  KinoPubAppleClient
//
//  DEBUG-only, tvOS-only. The UIKit half of the navigation / focus lab: a probe that
//  reads what the system actually thinks, and one collection that hosts several rails
//  as sections rather than as siblings.
//
//  Why a probe at all: the tab bar's expand / collapse and its background are driven by
//  `-[UIViewController contentScrollViewForEdge:]`, and the header for
//  `setContentScrollView:forEdge:` says in as many words that when it is nil "UIKit uses
//  a heuristic to search for a UIScrollView to track". We never call it, and a Home page
//  offers that heuristic a vertical scroll view plus one horizontal scroll view per
//  shelf. Which one it picked is not visible from SwiftUI, and guessing it from
//  behaviour is how two passes of this work already went wrong — so read it instead.
//

#if os(tvOS) && DEBUG
import SwiftUI
import UIKit
import TVUIKit

// MARK: - Probe

/// One sample of the live hierarchy. Everything here is read, never inferred.
struct NavLabReading: Equatable {
  var tabBarHidden: Bool?
  /// Class + address of whatever `contentScrollViewForEdge(.top)` resolves to. The
  /// address is the point: if it changes across a push/pop, the bar is tracking a
  /// different scroll view than it was before, which is the suspected cause of the bar
  /// not coming back.
  var observedScrollView: String?
  /// Non-nil only when the app set it explicitly rather than letting the heuristic run.
  var explicitScrollView: String?
  var stackDepth: Int?
  var tabBarClass: String?
}

@MainActor
final class NavLabProbe: ObservableObject {
  @Published private(set) var reading = NavLabReading()
  /// Set by `NavLabAnchor` once it is in the hierarchy.
  weak var anchor: UIViewController?
  /// Set by the collection bridge when a variant hands its scroll view over.
  weak var handedOver: UIScrollView?

  func sample() {
    guard let anchor, anchor.viewIfLoaded?.window != nil else {
      reading = NavLabReading()
      return
    }
    let tabBarController = anchor.tabBarController
    let navigationController = anchor.navigationController
    let top = navigationController?.topViewController ?? anchor

    var next = NavLabReading()
    next.tabBarHidden = tabBarController?.isTabBarHidden
    next.tabBarClass = tabBarController.map { String(describing: type(of: $0)) }
    next.stackDepth = navigationController?.viewControllers.count
    next.observedScrollView = Self.describe(top.contentScrollView(for: .top))
    next.explicitScrollView = Self.describe(handedOver)
    if next != reading { reading = next }
  }

  private static func describe(_ scrollView: UIScrollView?) -> String? {
    guard let scrollView else { return nil }
    let address = UInt(bitPattern: ObjectIdentifier(scrollView))
    let axis = scrollView.contentSize.width > scrollView.bounds.width ? "H" : "V"
    return "\(type(of: scrollView)) \(axis) 0x\(String(address, radix: 16, uppercase: false).suffix(6))"
  }
}

/// An empty view controller planted in the hierarchy purely so the probe has somewhere
/// to stand and walk up from.
struct NavLabAnchor: UIViewControllerRepresentable {
  let probe: NavLabProbe

  func makeUIViewController(context: Context) -> UIViewController {
    let controller = UIViewController()
    controller.view.backgroundColor = .clear
    controller.view.isUserInteractionEnabled = false
    probe.anchor = controller
    return controller
  }

  func updateUIViewController(_ controller: UIViewController, context: Context) {
    probe.anchor = controller
  }
}

// MARK: - One collection, several sections

struct NavLabItem: Identifiable, Hashable {
  let id: Int
  let title: String
  let hue: Double
}

enum NavLabContent {
  static func rail(_ section: Int, count: Int = 8) -> [NavLabItem] {
    (0..<count).map { index in
      NavLabItem(id: section * 100 + index,
                 title: "S\(section + 1) · \(index + 1)",
                 hue: Double((section * 7 + index * 3) % 12) / 12)
    }
  }

  static let sections: [[NavLabItem]] = (0..<5).map { rail($0) }

  /// Flat tint stands in for artwork: the lab is about focus and scroll ownership, and
  /// a network image would put loading timing into a measurement that has none.
  static func image(hue: Double, size: CGSize = CGSize(width: 480, height: 270)) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { context in
      UIColor(hue: hue, saturation: 0.45, brightness: 0.55, alpha: 1).setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
  }
}

/// Every rail of the page inside **one** `UICollectionView`, as sections of a
/// compositional layout — the shape `.claude/skills/tvos-surface/SKILL.md` asks for
/// ("one `UICollectionView` per page region, with several sections in it — not one
/// bridged representable per rail stacked in a `VStack`").
///
/// `handsOverScrollView` is the single variable this bridge exists to flip: with it on,
/// the enclosing controller is told which scroll view to track instead of being left to
/// the heuristic.
struct NavLabSectionedCollection: UIViewControllerRepresentable {
  let probe: NavLabProbe
  let handsOverScrollView: Bool
  let onSelect: (NavLabItem) -> Void

  func makeUIViewController(context: Context) -> NavLabCollectionController {
    let controller = NavLabCollectionController()
    controller.onSelect = onSelect
    return controller
  }

  func updateUIViewController(_ controller: NavLabCollectionController, context: Context) {
    controller.onSelect = onSelect
    controller.handsOverScrollView = handsOverScrollView
    probe.handedOver = handsOverScrollView ? controller.collectionView : nil
    controller.applyScrollViewHandover()
  }
}

final class NavLabCollectionController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

  var onSelect: ((NavLabItem) -> Void)?
  var handsOverScrollView = false

  private(set) lazy var collectionView: UICollectionView = {
    let layout = UICollectionViewCompositionalLayout { _, _ in
      // The system's own media rail: item size, gutters, insets and focus room come
      // from here rather than from hand-tuned flow-layout constants.
      NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems()
    }
    let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
    view.backgroundColor = .clear
    view.remembersLastFocusedIndexPath = true
    view.dataSource = self
    view.delegate = self
    view.register(NavLabCell.self, forCellWithReuseIdentifier: NavLabCell.reuseID)
    return view
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(collectionView)
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: view.topAnchor),
      collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
    applyScrollViewHandover()
  }

  /// Hands the collection to whichever controller owns the bars — the parent chain, not
  /// just self, because the tab bar asks the tab's *top-level* view controller.
  func applyScrollViewHandover() {
    guard isViewLoaded else { return }
    let target: UIScrollView? = handsOverScrollView ? collectionView : nil
    setContentScrollView(target, for: .top)
    var parent = self.parent
    while let current = parent {
      current.setContentScrollView(target, for: .top)
      parent = current.parent
    }
  }

  func numberOfSections(in collectionView: UICollectionView) -> Int {
    NavLabContent.sections.count
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    NavLabContent.sections[section].count
  }

  func collectionView(_ collectionView: UICollectionView,
                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NavLabCell.reuseID, for: indexPath)
    let item = NavLabContent.sections[indexPath.section][indexPath.item]
    var configuration = TVMediaItemContentConfiguration.wideCell()
    configuration.image = NavLabContent.image(hue: item.hue)
    configuration.text = item.title
    cell.contentConfiguration = configuration
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    onSelect?(NavLabContent.sections[indexPath.section][indexPath.item])
  }
}

final class NavLabCell: UICollectionViewCell {
  static let reuseID = "NavLabCell"
}
#endif
