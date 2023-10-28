//
//  SettingsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.10.2023.
//

import Foundation
import SwiftUI

import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var windowSettings: WindowSettings
  @AppStorage("alwaysOnTop") var alwaysOnTop: Bool = false
  
  var body: some View {
    Form {
      Toggle("AlwaysOnTop", isOn: $windowSettings.alwaysOnTop)
    }
    .padding()
    .frame(width: 300, height: 200)
  }
}
