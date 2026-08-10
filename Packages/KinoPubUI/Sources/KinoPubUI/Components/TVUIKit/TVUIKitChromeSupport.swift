#if os(tvOS)
//
//  TVUIKitChromeSupport.swift
//  KinoPubUI
//
//  Shared blur band + UIKit context-menu bridge for TVUIKit Home cells.
//

import UIKit
import SwiftUI
import KinoPubUI

public enum TVUIKitChromeSupport {
  /// A drop shadow instead of a pill behind small white chrome over artwork. Used by
  /// every glyph and chip we draw on a tile, so they carry the same weight — a second
  /// copy of these numbers is how two tiles start looking subtly different.
  public static func applyLegibilityShadow(to layer: CALayer) {
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.9
    layer.shadowRadius = 5
    layer.shadowOffset = .zero
  }
}

/// Bottom-quarter blur with a soft top fade (Rivulet / ATV+ legibility band).
@MainActor
public final class TVUIKitBottomInfoBlurView: UIView {
  private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
  private let fadeMask = CAGradientLayer()
  private let blurStrength: CGFloat = 0.85

  public override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    clipsToBounds = true
    layer.cornerRadius = TVUIKitPosterMetrics.cornerRadius
    layer.cornerCurve = .continuous
    layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

    blurView.alpha = blurStrength
    blurView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(blurView)
    NSLayoutConstraint.activate([
      blurView.topAnchor.constraint(equalTo: topAnchor),
      blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
      blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
      blurView.trailingAnchor.constraint(equalTo: trailingAnchor)
    ])

    fadeMask.colors = [
      UIColor.clear.cgColor,
      UIColor.black.cgColor,
      UIColor.black.cgColor
    ]
    fadeMask.locations = [0, 0.45, 1]
    fadeMask.startPoint = CGPoint(x: 0.5, y: 0)
    fadeMask.endPoint = CGPoint(x: 0.5, y: 1)
    layer.mask = fadeMask
  }

  public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  public override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    fadeMask.frame = bounds
    CATransaction.commit()
  }
}

public enum TVUIKitContextMenuBuilder {
  public static func menu(from entries: [MediaCardContextEntry]) -> UIMenu {
    var children: [UIMenuElement] = []
    var pending: [UIMenuElement] = []

    func flush() {
      if !pending.isEmpty {
        children.append(contentsOf: pending)
        pending.removeAll()
      }
    }

    for entry in entries {
      switch entry {
      case .divider:
        flush()
        if !children.isEmpty {
          // UIMenu separators between groups via nested menus.
          let group = UIMenu(title: "", options: .displayInline, children: children)
          children = [group]
        }
      case .action(let action):
        let uiAction = UIAction(
          title: action.title,
          image: UIImage(systemName: action.systemImage),
          attributes: action.role == .destructive ? .destructive : [],
          state: action.isSelection ? (action.isOn ? .on : .off) : .off
        ) { _ in
          action.handler()
        }
        pending.append(uiAction)
      case .submenu(_, let title, let systemImage, let submenuChildren, let footer):
        flush()
        var nested: [UIMenuElement] = submenuChildren.map { child in
          UIAction(
            title: child.title,
            image: UIImage(systemName: child.systemImage),
            state: child.isSelection ? (child.isOn ? .on : .off) : .off
          ) { _ in child.handler() }
        }
        if !footer.isEmpty {
          nested.append(UIMenu(
            title: "",
            options: .displayInline,
            children: footer.map { foot in
              UIAction(
                title: foot.title,
                image: UIImage(systemName: foot.systemImage)
              ) { _ in foot.handler() }
            }
          ))
        }
        children.append(UIMenu(
          title: title,
          image: UIImage(systemName: systemImage),
          children: nested
        ))
      }
    }
    flush()
    return UIMenu(title: "", children: children)
  }
}
#endif
