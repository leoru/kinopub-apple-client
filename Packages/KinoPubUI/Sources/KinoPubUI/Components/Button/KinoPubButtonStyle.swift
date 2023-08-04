//
//  KinoPubButtonStyle.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

public struct KinoPubButtonStyle: ButtonStyle {

  var buttonColor: KinoPubButton.ButtonColor
  
  public init(buttonColor: KinoPubButton.ButtonColor) {
    self.buttonColor = buttonColor
  }

  public func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .foregroundColor(.white)
      .background(buttonColor.color)
      .cornerRadius(6.0)
  }

}
