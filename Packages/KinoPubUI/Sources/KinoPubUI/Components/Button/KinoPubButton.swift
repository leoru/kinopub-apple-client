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
    case green
    case gray
    case red

    internal var color: Color {
      switch self {
      case .green:
        return Color.KinoPub.accent
      case .red:
        return Color.KinoPub.accentRed
      case .gray:
        return Color.KinoPub.selectionBackground
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
        .frame(maxWidth: .infinity, maxHeight: 40)
        .font(.system(size: 16, weight: .semibold))
    }
    .buttonStyle(KinoPubButtonStyle(buttonColor: color))

  }
}

struct KinoPubButton_Previews: PreviewProvider {
  static var previews: some View {
    KinoPubButton(title: "Watch", color: .green, action: {

    })
  }
}
