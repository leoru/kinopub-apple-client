//
//  File.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

public struct KinoPubButton: View {

  public enum ButtonColor {
    /// The primary action colour — white, as on Apple TV. Named for its role rather
    /// than its shade so it can be restyled without lying about it.
    case accent
    case gray
    case red
    case blue

    internal var color: Color {
      switch self {
      case .accent:
        return Color.KinoPub.accent
      case .red:
        return Color.KinoPub.accentRed
      case .gray:
        return Color.KinoPub.selectionBackground
      case .blue:
        return Color.KinoPub.accentBlue
      }
    }

    /// Label colour that stays legible on `color`.
    internal var foreground: Color {
      switch self {
      case .accent:
        return .black
      case .red, .gray, .blue:
        return .white
      }
    }
  }

  public var title: String
  public var color: ButtonColor
  public var action: () -> Void

  public init(title: String, color: ButtonColor, action: @escaping () -> Void) {
    self.title = title
    self.action = action
    self.color = color
  }

  public var body: some View {
    Button(action: action) {
      Text(title)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 40)
        .font(TypeScale.actionLabel)
    }
    .buttonStyle(KinoPubButtonStyle(buttonColor: color))

  }
}

struct KinoPubButton_Previews: PreviewProvider {
  static var previews: some View {
    KinoPubButton(title: "Watch", color: .accent, action: {

    })
  }
}
