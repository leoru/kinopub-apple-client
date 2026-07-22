//
//  SubtitleTrackPickerView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

/// Picks the two tracks to show. The first line is the one being watched with, the
/// second is the safety net under it — either can be any language the item offers.
struct SubtitleTrackPickerView: View {

  let tracks: [SubtitleTrack]
  let primary: SubtitleTrack?
  let secondary: SubtitleTrack?
  let selectPrimary: (SubtitleTrack?) -> Void
  let selectSecondary: (SubtitleTrack?) -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("First subtitles")) {
          trackRows(selected: primary, select: selectPrimary)
        }

        Section(header: Text("Second subtitles"),
                footer: Text("Shown on a second line under the first.")) {
          trackRows(selected: secondary, select: selectSecondary)
        }
      }
#if !os(tvOS)
      .scrollContentBackground(.hidden)
#endif
      .background(Color.KinoPub.background)
      .platformNavigationTitle("Subtitles")
#if !os(tvOS)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
#endif
    }
  }

  @ViewBuilder
  private func trackRows(selected: SubtitleTrack?, select: @escaping (SubtitleTrack?) -> Void) -> some View {
    row(title: Text("Off"), isSelected: selected == nil) { select(nil) }
    ForEach(tracks) { track in
      row(title: Text(track.displayName), isSelected: selected == track) { select(track) }
    }
  }

  private func row(title: Text, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        title
        Spacer()
        if isSelected {
          Image(systemName: "checkmark")
            .foregroundStyle(Color.KinoPub.accent)
        }
      }
      .contentShape(Rectangle())
    }
#if os(macOS)
    .buttonStyle(PlainButtonStyle())
#endif
  }
}

#Preview {
  SubtitleTrackPickerView(
    tracks: SubtitleTracks.catalog([
      Subtitle(lang: "eng", shift: 0, embed: false, url: "https://x/s01e01.eng.srt"),
      Subtitle(lang: "eng", shift: 0, embed: false, url: "https://x/s01e01.eng.sdh.srt"),
      Subtitle(lang: "rus", shift: 0, embed: false, url: "https://x/s01e01.rus.srt")
    ]),
    primary: nil,
    secondary: nil,
    selectPrimary: { _ in },
    selectSecondary: { _ in }
  )
}
