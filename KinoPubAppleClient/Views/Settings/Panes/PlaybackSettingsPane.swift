//
//  PlaybackSettingsPane.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend

#if !os(tvOS)
struct PlaybackSettingsPane: View {
  @AppStorage(SubtitlePreferences.preferEnglishKey) private var preferEnglishSubtitles = true
  @AppStorage(SubtitlePreferences.preferNonCCKey) private var preferNonCCSubtitles = true
  @AppStorage(SubtitlePreferences.dualSubtitlesKey) private var dualSubtitlesEnabled = false
  @AppStorage(SubtitlePreferences.secondSubtitleLanguageKey) private var secondSubtitleLanguage = "ru"
  @AppStorage(StreamQuality.userDefaultsKey) private var streamQualityRaw = StreamQuality.auto.rawValue

  var body: some View {
    Form {
      Section {
        Picker("Stream quality", selection: $streamQualityRaw) {
          ForEach(StreamQuality.allCases) { quality in
            Text(quality.title).tag(quality.rawValue)
          }
        }
        .pickerStyle(.menu)

        Toggle("Default English subtitles", isOn: $preferEnglishSubtitles)
        Toggle("Prefer non-CC / non-SDH", isOn: $preferNonCCSubtitles)
          .disabled(!preferEnglishSubtitles)
        Toggle("Dual subtitles", isOn: $dualSubtitlesEnabled)
        Picker("Second subtitle language", selection: $secondSubtitleLanguage) {
          ForEach(SubtitlePreferences.secondLanguageOptions, id: \.self) { code in
            Text(LanguageNames.name(for: code)).tag(code)
          }
        }
        .pickerStyle(.menu)
        .disabled(!dualSubtitlesEnabled)
      } footer: {
        Text("A track picked in the player wins over these, and is remembered for the next episode.")
      }
    }
    .formStyle(.grouped)
  }
}
#endif
