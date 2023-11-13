//
//  PlayerContinueWatchingView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 13.11.2023.
//

import Foundation
import SwiftUI
import KinoPubUI

struct PlayerContinueWatchingView: View {
  
  var time: TimeInterval
  var onContinueWatching: () -> Void
  var onCancelContinueWatching: () -> Void
  
  var body: some View {
    VStack {
      Text("Continue Watching")
        .font(Font.KinoPub.small)
      Text(formatTimeInterval(time))
        .font(Font.KinoPub.small)
      HStack {
        KinoPubButton(title: "Yes".localized, color: .blue) {
          onContinueWatching()
        }.frame(width: 60, height: 30)
        KinoPubButton(title: "\("No".localized)", color: .green) {
          onCancelContinueWatching()
        }.frame(width: 60, height: 30)
      }
    }
  }
  
  func formatTimeInterval(_ interval: TimeInterval) -> String {
      let formatter = DateComponentsFormatter()
      formatter.allowedUnits = [.hour, .minute, .second]
      formatter.unitsStyle = .positional
      formatter.zeroFormattingBehavior = .pad
      return formatter.string(from: interval) ?? "00:00:00"
  }
  
}
