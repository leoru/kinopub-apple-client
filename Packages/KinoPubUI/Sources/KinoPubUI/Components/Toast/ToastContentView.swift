//
//  ToastContentView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 27.07.2023.
//

import Foundation
import SwiftUI

public struct ToastContentView: View {
  
  public var text: String
  
  public init(text: String) {
    self.text = text
  }
  
  public var body: some View {
    Text(text)
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
      .foregroundColor(Color.white)
      .background(Color.KinoPub.accentRed)
      .cornerRadius(16)
      .frame(minHeight: 60)
  }
}
