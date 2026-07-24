//
//  StreamSurveyView.swift
//  KinoPubAppleClient
//
//  Created by Sasha Romanov on 24.07.2026.
//

#if DEBUG
import SwiftUI

/// Debug-only. Answers "what does kino.pub actually send us?" — the question behind
/// whether an FFmpeg-backed player would buy us anything. See `StreamSurvey.swift`.
struct StreamSurveyView: View {

  @Environment(\.appContext) private var appContext
  @StateObject private var model = StreamSurveyModel()

  var body: some View {
    ZStack {
      Color.KinoPub.background.edgesIgnoringSafeArea(.all)
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Button {
            Task { await model.run(service: appContext.contentService) }
          } label: {
            Text(model.isRunning ? "Scanning…" : "Scan 40 items")
          }
          .disabled(model.isRunning)

          Text(model.status)
            .foregroundStyle(Color.KinoPub.subtitle)

          if !model.report.isEmpty {
            Text(model.report)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Color.KinoPub.text)
#if os(tvOS)
              // Nothing else in the report is focusable, and a tvOS ScrollView with no
              // focusable content simply refuses to scroll.
              .focusable()
#else
              .textSelection(.enabled)
#endif
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
      }
    }
    .platformNavigationTitle("Stream survey")
  }
}

#Preview {
  StreamSurveyView()
}
#endif
