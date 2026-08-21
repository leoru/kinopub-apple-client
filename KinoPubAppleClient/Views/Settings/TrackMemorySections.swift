//
//  TrackMemorySections.swift
//  KinoPubAppleClient
//
//  What the app has learned about audio and subtitles, shown to everyone.
//
//  Deliberately not behind a debug flag: a preference that steers playback without ever
//  being visible is one the viewer cannot correct. The grouping is the same one the
//  resolver reads in — series, then season, then episode — so what is on screen explains
//  what actually happens.
//

import SwiftUI
import KinoPubBackend

#if !os(tvOS)
struct TrackMemorySections: View {

  let store: TrackPreferenceStore

  @Environment(\.appContext) private var appContext
  @State private var sections: [TrackPreferenceDigest.Section] = []
  @State private var showsResetAlert = false

  /// Enough to recognise what the app is doing without turning Settings into a database
  /// browser. The rest is still remembered; it is just not worth a screen.
  private static let maxSections = 12
  private static let maxEntriesPerScope = 3

  var body: some View {
    Group {
      if sections.isEmpty {
        Section {
          Text("Nothing remembered yet. Pick a dub or a subtitle track in the player and it will show up here.")
            .foregroundStyle(.secondary)
        } header: {
          Text("Remembered tracks")
        }
      } else {
        ForEach(Array(sections.prefix(Self.maxSections)), id: \.titleID) { section in
          Section {
            ForEach(Array(section.groups.enumerated()), id: \.offset) { _, group in
              rows(for: group)
            }
          } header: {
            Text(title(for: section))
          }
        }

        Section {
          Button("Forget remembered tracks", role: .destructive) {
            showsResetAlert = true
          }
        } footer: {
          if sections.count > Self.maxSections {
            Text("\(sections.count - Self.maxSections) more titles are remembered and not listed.")
          }
        }
      }
    }
    .onAppear(perform: reload)
    // Same key as the button above: Xcode's generated string symbols strip
    // punctuation, so "…tracks" and "…tracks?" collided on one symbol name.
    .alert("Forget remembered tracks", isPresented: $showsResetAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Forget", role: .destructive) {
        store.forgetEverything()
        reload()
      }
    } message: {
      Text("Playback goes back to the defaults above until new choices are made.")
    }
  }

  @ViewBuilder
  private func rows(for group: TrackPreferenceDigest.Group) -> some View {
    let scope = scopeLabel(for: group.scope)
    // The closure form, not `LabeledContent(_:value:)`: these titles are runtime strings,
    // and that initializer takes a `LocalizedStringKey`.
    ForEach(Array(group.audio.prefix(Self.maxEntriesPerScope).enumerated()), id: \.offset) { _, entry in
      LabeledContent {
        Text(detail(entry))
      } label: {
        Text(entry.isLeader ? scope : "")
      }
    }
    ForEach(Array(group.subtitles.prefix(Self.maxEntriesPerScope).enumerated()), id: \.offset) { _, entry in
      LabeledContent {
        Text(detail(entry))
      } label: {
        Text(entry.isLeader ? "\(scope) · \("Subtitles".localized)" : "")
      }
    }
  }

  /// The weight is the honest part: it is what decides ties, so showing it explains why
  /// one dub wins over another.
  private func detail(_ entry: TrackPreferenceDigest.Entry) -> String {
    "\(entry.label) · \(entry.weight)"
  }

  private func scopeLabel(for scope: TrackMemoryScope) -> String {
    switch scope {
    case .title:
      return "Whole title".localized
    case let .season(_, season):
      return "\("Season".localized) \(season)"
    case let .episode(_, season, episode):
      guard let season else { return "\("Episode".localized) \(episode)" }
      return "S\(season)E\(episode)"
    case let .contentClass(name):
      return name.capitalized
    }
  }

  /// The title's own name when the app has seen it this session, and its id when it has
  /// not — inventing a name for a row that steers playback would be worse than a number.
  private func title(for section: TrackPreferenceDigest.Section) -> String {
    guard let titleID = section.titleID else { return "Anime".localized }
    if let snapshot = appContext.localProgressStore.snapshot(for: titleID) {
      return snapshot.localizedTitle
    }
    return "#\(titleID)"
  }

  private func reload() {
    sections = TrackPreferenceDigest.sections(from: store.storedScopes)
  }
}
#endif
