//
//  KinoPubButtonTextStyle.swift
//
//
//  Created by Kirill Kunst on 4.08.2023.
//

import Foundation
import SwiftUI

public struct KinoPubButtonTextStyle: ViewModifier {
  
  public init() {}
  
  public func body(content: Content) -> some View {
    content
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity, maxHeight: 40)
      .font(.system(size: 16, weight: .semibold))
  }
}
