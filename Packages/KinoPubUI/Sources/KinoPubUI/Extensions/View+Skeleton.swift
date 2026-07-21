//
//  View+Skeleton.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation
import SwiftUI
import SkeletonUI

private let skeletonAppearance: AppearanceType = .gradient(.linear,
                                                           color: Color.KinoPub.skeleton,
                                                           background: Color.KinoPub.skeleton.opacity(0.8),
                                                           radius: 2.0,
                                                           angle: .radians(2.0))

private let skeletonShape: ShapeType = .rounded(.radius(6, style: .continuous))

public extension View {
  func skeleton(enabled: Bool, size: CGSize? = nil) -> some View {
    self.skeleton(with: enabled,
                  size: size,
                  animation: .linear(),
                  appearance: skeletonAppearance,
                  shape: skeletonShape)
  }

  func multilineSkeleton(enabled: Bool, size: CGSize? = nil) -> some View {
    self.skeleton(with: enabled,
                  size: size,
                  animation: .linear(),
                  appearance: skeletonAppearance,
                  shape: skeletonShape,
                  lines: 3,
                  scales: [1: 0.8, 2: 0.5])
  }
}
