//
//  Color+Extension.swift
//
//
//  Created by Kirill Kunst on 22.07.2023.
//

import Foundation
import SwiftUI

extension Color {
  public struct KinoPub {
    public static let accent = Color("accent_color", bundle: .module)
    public static let accentRed = Color("accent_red_color", bundle: .module)
    public static let background = Color("background_color", bundle: .module)
    public static let text = Color("text_color", bundle: .module)
    public static let subtitle = Color("subtitle_text_color", bundle: .module)
    public static let selectionBackground = Color("selection_background_color", bundle: .module)
    public static let skeleton = Color("skeleton_color", bundle: .module)
  }
}
