//
//  Double+Formatting.swift
//
//
//  Created by Kirill Kunst on 28.07.2023.
//

import Foundation

extension Double {
  var scoreFormatted: String {
    String(format: "%.1f", self)
  }
}
