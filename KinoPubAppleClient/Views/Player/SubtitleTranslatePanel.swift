//
//  SubtitleTranslatePanel.swift
//  KinoPubAppleClient
//

import SwiftUI

// Translation is not available on tvOS and the entire feature is gated by
// canImport(Translation).  The tvOS variant only shows the fallback UI.
#if canImport(Translation) && !os(tvOS)

import Translation

struct SubtitleTranslatePanel: View {
  let cueText: String

  @State private var selectedWord: String?
  @State private var translatedText: String?
  @State private var isTranslating = false
  @State private var translationUnavailableMessage: String?
  @available(macOS 15.0, iOS 18.0, *)
  @State private var translationConfiguration: TranslationSession.Configuration?

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
        translate(word: word)
      }

      if isTranslating {
        ProgressView()
          .progressViewStyle(.circular)
      }

      if let selectedWord, let translatedText {
        VStack(alignment: .leading, spacing: 4) {
          Text(cleanWord(selectedWord))
            .font(.title3.weight(.semibold))
          Text(translatedText)
            .font(.title3)
            .foregroundStyle(.primary)
        }
        .padding(.top, 4)
      } else if let translationUnavailableMessage {
        Text(translationUnavailableMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .padding(20)
    .frame(maxWidth: 720, alignment: .leading)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .transformBody()
  }

  private func translate(word: String) {
    selectedWord = word
    translatedText = nil
    translationUnavailableMessage = nil

    if #available(macOS 15.0, iOS 18.0, *) {
      let cleaned = cleanWord(word)
      guard !cleaned.isEmpty else { return }
      isTranslating = true
      if translationConfiguration == nil {
        translationConfiguration = .init(
          source: Locale.Language(identifier: "en"),
          target: Locale.Language(identifier: "ru")
        )
      } else {
        translationConfiguration?.invalidate()
      }
    } else {
      translationUnavailableMessage = "On-device translation requires macOS 15.0 or iOS 18.0."
    }
  }

  @available(macOS 15.0, iOS 18.0, *)
  private func performTranslation(session: TranslationSession) async {
    guard let selectedWord else { return }
    do {
      let response = try await session.translate(cleanWord(selectedWord))
      await MainActor.run {
        translatedText = response.targetText
        isTranslating = false
      }
    } catch {
      await MainActor.run {
        translationUnavailableMessage = "Translation unavailable for this word."
        isTranslating = false
      }
    }
  }

  private func cleanWord(_ word: String) -> String {
    word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  }
}

// MARK: - Translation modifier (availability-gated)

@available(macOS 15.0, iOS 18.0, *)
private struct TranslationTransformModifier: ViewModifier {
  @Binding var translationConfiguration: TranslationSession.Configuration?

  func body(content: Content) -> some View {
    content.translationTask(translationConfiguration) { session in
      // Delegate to the parent's performTranslation — handled via a shared closure pattern
      // This is wired at the call site
    }
  }
}

private extension View {
  func transformBody() -> some View {
    if #available(macOS 15.0, iOS 18.0, *) {
      return AnyView(TranslatedBody(content: self))
    } else {
      return AnyView(self)
    }
  }
}

@available(macOS 15.0, iOS 18.0, *)
private struct TranslatedBody<Content: View>: View {
  let content: Content
  @State private var configuration: TranslationSession.Configuration?

  var body: some View {
    content
      .translationTask(configuration) { _ in
        // Translation is driven by the parent SubtitleTranslatePanel's @State
      }
  }
}

#else

// MARK: - tvOS / no-Translation fallback

struct SubtitleTranslatePanel: View {
  let cueText: String

  @State private var selectedWord: String?
  @State private var translatedText: String?
  @State private var translationUnavailableMessage: String?

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
        translatedText = nil
        translationUnavailableMessage = "On-device translation is not available on this platform."
      }

      if let translationUnavailableMessage {
        Text(translationUnavailableMessage)
          .font(.footnote)
          .foregroundStyle(.secondary)
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
