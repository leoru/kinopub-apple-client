//
//  File.swift
//
//
//  Created by Kirill Kunst on 8.08.2023.
//

import Foundation
import SwiftUI

public struct ProgressButton: View {
  
  public enum ProgressState {
    case pause
    case resume
  }
  
  private var action: (ProgressState) -> Void
  @Binding var progress: Float
  
  public init(progress: Binding<Float>, action: @escaping (ProgressState) -> Void) {
    self.action = action
    self._progress = progress
  }
  
  @State private var progressState = ProgressState.resume
  
  public var body: some View {
    ZStack {
      // Progress Ring
      
      Circle()
        .trim(from: 0.0, to: 1.0)
        .stroke(Color.KinoPub.accent.opacity(0.2), lineWidth: 3)
        .background(Color.clear)
        .frame(width: 35, height: 35)
        .rotationEffect(.degrees(-90))
      
      Circle()
        .trim(from: 0.0, to: CGFloat(progress))
        .stroke(Color.KinoPub.accent, lineWidth: 3)
        .background(Color.clear)
        .frame(width: 40, height: 40)
        .rotationEffect(.degrees(-90))
      
      Button(action: {
        progressState = progressState == .pause ? .resume : .pause
        action(progressState)
      }) {
        Image(systemName: progressState == .resume ? "pause.fill" : "play.fill")
          .foregroundColor(Color.KinoPub.accent)
          .font(.headline)
          .frame(width: 20, height: 20)
          .background(Color.clear)
          .clipShape(Circle())
      }
    }
  }
}
