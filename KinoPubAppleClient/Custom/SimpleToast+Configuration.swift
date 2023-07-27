//
//  SimpleToast+Configuration.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import SimpleToast
import KinoPubUI
import SwiftUI

extension SimpleToastOptions {
  static var error: SimpleToastOptions {
    SimpleToastOptions(alignment: .bottom,
                       hideAfter: 3.0,
                       backdrop: Color.KinoPub.accentRed)
  }
}
