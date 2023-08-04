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
//      .animation(type: .)
      .appearance(type: .solid(color: Color.KinoPub.skeleton))
      .shape(type: .rounded(.radius(6, style: .continuous)))
  }
  
  func multilineSkeleton(enabled: Bool, size: CGSize? = nil) -> some View {
    self.skeleton(with: enabled)
//      .animation(type: .none)
      .appearance(type: .solid(color: Color.KinoPub.skeleton))
      .shape(type: .rounded(.radius(6, style: .continuous)))
      .multiline(lines: 3, scales: [1: 0.8, 2: 0.5])
  }
}
