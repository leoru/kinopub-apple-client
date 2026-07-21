//
//  SubtitleTranslatePanel.swift
//  KinoPubAppleClient
//

import SwiftUI
#if canImport(Translation) && !os(tvOS)
import Translation
#endif

struct SubtitleTranslatePanel: View {
  let cueText: String

  @State private var selectedWord: String?
  @State private var translatedText: String?
  @State private var isTranslating = false
  @State private var translationUnavailableMessage: String?
#if canImport(Translation) && !os(tvOS)
  @State private var translationConfiguration: TranslationSession.Configuration?
#endif

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
#if canImport(Translation) && !os(tvOS)
    .translationTask(translationConfiguration) { session in
      await performTranslation(session: session)
    }
#endif
  }

  private func translate(word: String) {
    selectedWord = word
    translatedText = nil
    translationUnavailableMessage = nil

#if os(tvOS)
    translationUnavailableMessage = "On-device translation is not available on Apple TV yet."
#elseif canImport(Translation)
    if #available(iOS 17.4, macOS 14.4, *) {
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
      translationUnavailableMessage = "On-device translation requires iOS 17.4+ or macOS 14.4+."
    }
#else
    translationUnavailableMessage = "On-device translation is not available on this platform."
#endif
  }

#if canImport(Translation) && !os(tvOS)
  @available(iOS 17.4, macOS 14.4, *)
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
#endif

  private func cleanWord(_ word: String) -> String {
    word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
  }
}

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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(word == selectedWord ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
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
