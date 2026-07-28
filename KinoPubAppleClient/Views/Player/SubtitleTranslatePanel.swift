//
//  SubtitleTranslatePanel.swift
//  KinoPubAppleClient
//
//  PARKED — nothing builds this view. Tap-a-word-to-translate on pause was never good
//  enough to show anyone: kino.pub has no such feature, it only ever worked off tvOS
//  (the Translation framework is unavailable there), and the panel sat as a SwiftUI
//  overlay above the system player where it fought the real transport controls. Kept as
//  source so the work isn't lost; wire it back only once the basics kino.pub already
//  does well are done.
//

import SwiftUI

// Translation is not available on tvOS and the entire feature is gated by
// canImport(Translation).  The tvOS variant only shows the fallback UI.
#if canImport(Translation) && !os(tvOS)

import Translation

struct SubtitleTranslatePanel: View {
  let cueText: String

  @State private var selectedWord: String?

  private var words: [String] {
    cueText
      .components(separatedBy: .whitespacesAndNewlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Pause to translate")
        .font(.headline)
        .foregroundStyle(.secondary)

      FlowWordChips(words: words, selectedWord: selectedWord) { word in
        selectedWord = word
      }

      if let selectedWord, !cleanWord(selectedWord).isEmpty {
        if #available(macOS 15.0, iOS 18.0, *) {
          WordTranslationView(word: cleanWord(selectedWord))
            .padding(.top, 4)
        } else {
          Text("On-device translation requires macOS 15.0 or iOS 18.0.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: 720, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func cleanWord(_ word: String) -> String {
    word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  }
}

/// Owns the translation session for one word.
///
/// This lives in its own view for two reasons: a stored property cannot be marked
/// `@available` when the enclosing type is available earlier, and `.translationTask`
/// has to observe the very same `@State` that requests the translation — the previous
/// version kept them in separate views, so the request never reached a task.
@available(macOS 15.0, iOS 18.0, *)
private struct WordTranslationView: View {
  let word: String

  @State private var configuration: TranslationSession.Configuration?
  @State private var translated: String?
  @State private var failed = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(word)
        .font(.title3.weight(.semibold))

      if let translated {
        Text(translated)
          .font(.title3)
          .foregroundStyle(.primary)
      } else if failed {
        Text("Translation unavailable for this word.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else {
        ProgressView()
          .progressViewStyle(.circular)
      }
    }
    .task(id: word) {
      translated = nil
      failed = false
      configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "en"),
        target: Locale.Language(identifier: "ru")
      )
    }
    .translationTask(configuration) { session in
      do {
        let response = try await session.translate(word)
        await MainActor.run { translated = response.targetText }
      } catch {
        await MainActor.run { failed = true }
      }
    }
  }
}

#else

// MARK: - tvOS / no-Translation fallback

struct SubtitleTranslatePanel: View {
  let cueText: String

  @State private var selectedWord: String?

  private var words: [String] {
    cueText
      .components(separatedBy: .whitespacesAndNewlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Pause to translate")
        .font(.headline)
        .foregroundStyle(.secondary)

      FlowWordChips(words: words, selectedWord: selectedWord) { word in
        selectedWord = word
      }

      if selectedWord != nil {
        Text("On-device translation is not available on this platform.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(20)
    .frame(maxWidth: 720, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

#endif

// MARK: - Flow Word Chips (shared)

private struct FlowWordChips: View {
  let words: [String]
  let selectedWord: String?
  let onSelect: (String) -> Void

  var body: some View {
    FlexibleWordLayout(words: words, selectedWord: selectedWord, onSelect: onSelect)
  }
}

/// Simple wrapping layout for subtitle word chips (tvOS-friendly buttons).
private struct FlexibleWordLayout: View {
  let words: [String]
  let selectedWord: String?
  let onSelect: (String) -> Void

  var body: some View {
    let columns = [GridItem(.adaptive(minimum: chipMinWidth), spacing: 8)]
    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
      ForEach(Array(words.enumerated()), id: \.offset) { _, word in
        Button {
          onSelect(word)
        } label: {
          Text(word)
            .font(.body.weight(.medium))
        }
        .buttonStyle(WordChipButtonStyle(isSelected: word == selectedWord))
      }
    }
  }

  private var chipMinWidth: CGFloat {
#if os(tvOS)
    return 100
#else
    return 56
#endif
  }
}

/// Chip styling that reacts to focus, so the Siri Remote has something to land on.
/// `.buttonStyle(.plain)` leaves tvOS buttons focusable but visually inert.
private struct WordChipButtonStyle: ButtonStyle {
  let isSelected: Bool

  // Spelled out rather than `Configuration`: the Translation framework puts a
  // protocol of that name in scope in this file.
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Chip(configuration: configuration, isSelected: isSelected)
  }

  private struct Chip: View {
    let configuration: ButtonStyle.Configuration
    let isSelected: Bool
    @Environment(\.isFocused) private var isFocused

    private var fill: Color {
      if isFocused { return Color.accentColor.opacity(0.65) }
      if isSelected { return Color.accentColor.opacity(0.35) }
      return Color.primary.opacity(0.12)
    }

    var body: some View {
      configuration.label
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fill)
        )
        .scaleEffect(isFocused ? 1.1 : (configuration.isPressed ? 0.95 : 1.0))
        .animation(.easeOut(duration: 0.15), value: isFocused)
        .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
  }
}
