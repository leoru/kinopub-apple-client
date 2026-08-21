//
//  PlaybackSettingsPane.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend

#if !os(tvOS)
struct PlaybackSettingsPane: View {
  @Environment(\.appContext) private var appContext

  @AppStorage(SubtitlePreferences.preferEnglishKey) private var preferEnglishSubtitles = true
  @AppStorage(SubtitlePreferences.preferNonCCKey) private var preferNonCCSubtitles = true
  @AppStorage(SubtitlePreferences.dualSubtitlesKey) private var dualSubtitlesEnabled = false
  @AppStorage(SubtitlePreferences.secondSubtitleLanguageKey) private var secondSubtitleLanguage = "ru"
  @AppStorage(StreamQuality.userDefaultsKey) private var streamQualityRaw = StreamQuality.auto.rawValue
  @AppStorage(PlaybackLanguagePreferences.minimumDubKindKey)
  private var minimumDubKind = PlaybackLanguagePreferences.noDubFloor
  @AppStorage(PlaybackLanguagePreferences.animeOriginalAudioKey)
  private var animePrefersOriginalAudio = false

  /// Rebuilt when a preference changes so the summary below never disagrees with the
  /// switches above it.
  private var settings: PlaybackLanguagePreferences { .current }

  var body: some View {
    Form {
      qualitySection
      audioSection
      subtitleSection
      TrackMemorySections(store: appContext.trackPreferences)
    }
    .formStyle(.grouped)
  }

  private var qualitySection: some View {
    Section {
      Picker("Stream quality", selection: $streamQualityRaw) {
        ForEach(StreamQuality.allCases) { quality in
          Text(quality.title).tag(quality.rawValue)
        }
      }
      .pickerStyle(.menu)
    }
  }

  private var audioSection: some View {
    Section {
      LabeledContent("Preferred audio", value: languageList(settings.resolvedAudioLanguages(system: Locale.preferredLanguages)))

      Picker("Lowest acceptable dub", selection: $minimumDubKind) {
        Text("Any").tag(PlaybackLanguagePreferences.noDubFloor)
        ForEach(0...4, id: \.self) { rank in
          Text(AudioTracks.localizedKindLabel(rank: rank) ?? "").tag(rank)
        }
      }
      .pickerStyle(.menu)

      Toggle("Anime in the original", isOn: $animePrefersOriginalAudio)
    } header: {
      Text("Audio")
    } footer: {
      Text("Below the lowest acceptable dub, the original is played with subtitles instead. Preferred languages follow the system until an app setting overrides them.")
    }
  }

  private var subtitleSection: some View {
    Section {
      LabeledContent("Subtitles by default",
                     value: PlaybackLanguagePreferences.systemWantsCaptions ? "On" : "Off")
      Toggle("Default English subtitles", isOn: $preferEnglishSubtitles)
      Toggle("Prefer non-CC / non-SDH", isOn: $preferNonCCSubtitles)
      Toggle("Dual subtitles", isOn: $dualSubtitlesEnabled)
      Picker("Second subtitle language", selection: $secondSubtitleLanguage) {
        ForEach(SubtitlePreferences.secondLanguageOptions, id: \.self) { code in
          Text(LanguageNames.name(for: code)).tag(code)
        }
      }
      .pickerStyle(.menu)
      .disabled(!dualSubtitlesEnabled)
    } header: {
      Text("Subtitles")
    } footer: {
      Text("Whether subtitles appear by default follows Settings › Accessibility › Subtitles & Captioning. They also come on whenever the audio is in a language you do not read.")
    }
  }

  private func languageList(_ codes: [String]) -> String {
    let names = codes.prefix(3).map { LanguageNames.name(for: $0) }
    return names.isEmpty ? "—" : names.joined(separator: ", ")
  }
}
#endif
