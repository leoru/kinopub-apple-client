//
//  File.swift
//
//
//  Created by Kirill Kunst on 31.07.2023.
//

import Foundation
import SwiftUI

public struct KinoPubButton: View {
  
  public var title: String
  public var action: () -> Void
  
  public init(title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }
  
  public var body: some View {
    Button(action: action) {
      Text(title)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: 40)
        .font(.system(size: 16, weight: .semibold))
    }
    .buttonStyle(KinoPubButtonStyle())
    
  }
}

struct KinoPubButton_Previews: PreviewProvider {
  static var previews: some View {
    KinoPubButton(title: "Watch", action: {
      
    })
  }
}
