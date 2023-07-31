//
//  KinoPubButtonStyle.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

public struct KinoPubButtonStyle: ButtonStyle {

  public func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .foregroundColor(.white)
      .background(Color.KinoPub.accent)
      .cornerRadius(8.0)
  }

}
