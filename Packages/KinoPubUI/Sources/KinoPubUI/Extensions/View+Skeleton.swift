//
//  View+Skeleton.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import SwiftUI
import SkeletonUI

public extension View {
  func skeleton(enabled: Bool, size: CGSize? = nil) -> some View {
    self.skeleton(with: enabled, size: size)
      .appearance(type: .gradient(.linear, color: Color.KinoPub.skeleton, background: Color.KinoPub.skeleton.opacity(0.8), radius: 2.0, angle: 2.0))
      .animation(type: .linear())
      .shape(type: .rounded(.radius(6, style: .continuous)))
  }

  func multilineSkeleton(enabled: Bool, size: CGSize? = nil) -> some View {
    self.skeleton(with: enabled)
      .appearance(type: .gradient(.linear, color: Color.KinoPub.skeleton, background: Color.KinoPub.skeleton.opacity(0.8), radius: 2.0, angle: 2.0))
      .animation(type: .linear())
      .shape(type: .rounded(.radius(6, style: .continuous)))
      .multiline(lines: 3, scales: [1: 0.8, 2: 0.5])
  }
}
