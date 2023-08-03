//
//  String+Localization.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Foundation

extension String {
  var localized: String {
    NSLocalizedString(self, comment: "")
  }
}
