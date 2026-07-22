//
//  SiriRemoteTilt.swift
//
//

#if os(tvOS)
import Foundation
import GameController
import SwiftUI

/// Tracks the thumb's position on the Siri Remote's touch surface, so a focused card
/// can tilt to follow it — the tactile parallax the stock tvOS apps give artwork.
/// `reportsAbsoluteDpadValues` turns the touch surface into a joystick-like x/y
/// position (-1...1, centred at rest) instead of discrete swipe events; the system's
/// own D-pad focus navigation reads the same hardware independently and keeps working.
public final class SiriRemoteTilt: ObservableObject {
  public static let shared = SiriRemoteTilt()

  /// -1...1 on each axis, centred at rest.
  @Published public private(set) var position: CGSize = .zero

  private init() {
    GCController.controllers().forEach(attach)
    NotificationCenter.default.addObserver(
      forName: .GCControllerDidConnect, object: nil, queue: .main
    ) { [weak self] note in
      guard let controller = note.object as? GCController else { return }
      self?.attach(controller)
    }
    NotificationCenter.default.addObserver(
      forName: .GCControllerDidDisconnect, object: nil, queue: .main
    ) { [weak self] _ in
      self?.position = .zero
    }
  }

  private func attach(_ controller: GCController) {
    guard let microGamepad = controller.microGamepad else { return }
    microGamepad.reportsAbsoluteDpadValues = true
    microGamepad.dpad.valueChangedHandler = { [weak self] _, x, y in
      DispatchQueue.main.async {
        self?.position = CGSize(width: CGFloat(x), height: CGFloat(y))
      }
    }
  }
}
#endif
