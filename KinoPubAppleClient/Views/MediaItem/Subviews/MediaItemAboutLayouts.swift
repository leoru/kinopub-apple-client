//
//  MediaItemAboutLayouts.swift
//  KinoPubAppleClient
//
//  Four deliberately different compositions of the detail page's bottom "About"
//  block, switchable at runtime so they can be compared on a real title with real
//  data rather than argued about in the abstract. Pick one, then delete the rest and
//  this switcher with them — this file is a fork in the road, not an architecture.
//
//  The brief they are answering:
//   * A table is a table. It lives at the bottom, it is quiet, it can grow without
//     limit, and its flat background says "skip me unless you need this".
//   * What you decide *before pressing play* — quality, audio, subtitles, age rating —
//     is not table material. It wants the weight of the ratings row: card-backed, so
//     the background itself hints there is something to press.
//   * Badges (4K / CC / AD / Dolby) are a legend, and a legend nobody explains is
//     decoration. Apple spells CC and AD out in full underneath; so should we.
//   * Languages should answer "can I watch this" — the best dub in each of *my*
//     preferred languages, in the order the system ranks them, falling back to
//     English or the original when none of mine are there.
//   * Big headings take attention the content should be getting.
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubMetadata

// MARK: - Shared value types

/// Lifted out of `MediaItemInfoColumns` so every layout below can be handed the same
/// already-built rows instead of each one re-deriving them.
enum ValueStyle {
  case primary
  case note
}

struct InfoValue: Identifiable {
  let id: String
  let title: String
  /// When set, the value opens Search with this filter.
  var filter: LibraryFilter? = nil
  var style: ValueStyle = .primary
}

struct InfoSection: Identifiable {
  let id: String
  let caption: String
  let values: [InfoValue]
}

// MARK: - Layout switch

enum MediaItemAboutLayout: String, CaseIterable, Identifiable {
  /// The Apple TV app's own shape: two wide cards, then quiet unbacked columns.
  case appleShape
  /// Badges first, each spelled out — the legend *is* the section.
  case legend
  /// Pressable spec tiles on top, one flat table underneath.
  case tiers
  /// No cards at all: a dense label/value sheet with hairlines.
  case specSheet

  var id: String { rawValue }

  var title: String {
    switch self {
    case .appleShape: return "1 · Apple shape"
    case .legend: return "2 · Decoded legend"
    case .tiers: return "3 · Tiles + table"
    case .specSheet: return "4 · Spec sheet"
    }
  }

  static let storageKey = "mediaItemAboutLayout"
}

// MARK: - Content

/// Everything the layouts draw, computed once by `MediaItemInfoColumns` and passed
/// down. Keeping this a plain value (not a view) is what lets four very different
/// compositions stay honest about showing the *same* information.
struct MediaItemAboutContent {
  var synopsis: String?
  var title: String
  var primaryGenre: String?
  var ageRating: String?
  var advisories: [String]
  var tags: [InfoValue]
  var releaseSections: [InfoSection]
  var detailSections: [InfoSection]
  var technicalSections: [InfoSection]
  var badges: [AboutBadge]
  var languageSummary: [LanguageLine]
  var subtitleNames: [String]

  /// A decoded badge: the chip you see, and the sentence that says what it means.
  struct AboutBadge: Identifiable {
    let id: String
    /// Short form drawn in the chip — "4K", "CC", "AD", "5.1".
    let short: String
    /// What it stands for, spelled out.
    let name: String
    /// One plain sentence. Apple writes these out under Accessibility; so do we.
    let explanation: String
    var isProminent: Bool = false
  }

  /// One preferred language and the best thing available in it.
  struct LanguageLine: Identifiable {
    let id: String
    let language: String
    /// Best dub kind for this language, already ranked by `AudioTracks`.
    let best: String?
    let hasSubtitles: Bool
    /// Extra dubs folded away behind this one.
    let extraCount: Int
  }
}

// MARK: - 1 · Apple shape

/// What the Apple TV app actually does: a couple of wide cards carrying the two
/// things people read (what it is about, and whether it is OK for whoever is in the
/// room), then plain unbacked columns underneath. No card behind the columns at all —
/// their job is to be skippable, and a background would argue otherwise.
struct AboutLayoutAppleShape: View {
  let content: MediaItemAboutContent

  var body: some View {
    VStack(alignment: .leading, spacing: AboutMetrics.blockSpacing) {
      AboutHeading("About")

      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: AboutMetrics.cardSpacing) {
          synopsisCard
          advisoryCard
        }
        VStack(alignment: .leading, spacing: AboutMetrics.cardSpacing) {
          synopsisCard
          advisoryCard
        }
      }

      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: AboutMetrics.columnSpacing) {
          columns
        }
        VStack(alignment: .leading, spacing: AboutMetrics.columnSpacing) {
          columns
        }
      }
    }
  }

  private var synopsisCard: some View {
    AboutCard {
      VStack(alignment: .leading, spacing: 8) {
        Text(content.title)
          .font(AboutMetrics.cardTitleFont)
          .foregroundStyle(Color.KinoPub.text)
        if let genre = content.primaryGenre {
          Text(genre.uppercased())
            .font(AboutMetrics.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
        }
        if let synopsis = content.synopsis {
          Text(synopsis)
            .font(AboutMetrics.bodyFont)
            .foregroundStyle(Color.KinoPub.subtitle)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  @ViewBuilder
  private var advisoryCard: some View {
    if content.ageRating != nil || !content.advisories.isEmpty {
      AboutCard {
        VStack(alignment: .leading, spacing: 8) {
          if let rating = content.ageRating {
            Text(rating)
              .font(AboutMetrics.cardTitleFont)
              .foregroundStyle(Color.KinoPub.text)
          }
          Text("MediaItem_Flags")
            .font(AboutMetrics.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
          if !content.advisories.isEmpty {
            Text(content.advisories.joined(separator: ", "))
              .font(AboutMetrics.bodyFont)
              .foregroundStyle(Color.KinoPub.subtitle)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var columns: some View {
    AboutColumn(title: "Information", sections: content.releaseSections + content.detailSections)
    AboutColumn(title: "Languages", sections: [], languageLines: content.languageSummary,
                subtitleNames: content.subtitleNames)
    AboutLegendColumn(badges: content.badges)
  }
}

// MARK: - 2 · Decoded legend

/// The badges are the section. Chips across the top for the glance, then every one of
/// them written out underneath — the thing Apple does for CC and AD and nobody else
/// bothers with. Everything else is demoted to a single quiet column.
struct AboutLayoutLegend: View {
  let content: MediaItemAboutContent

  var body: some View {
    VStack(alignment: .leading, spacing: AboutMetrics.blockSpacing) {
      AboutHeading("About")

      AboutFlowLayout(spacing: AboutMetrics.chipSpacing) {
        ForEach(content.badges) { badge in
          AboutBadgeChip(badge: badge)
        }
      }

      VStack(alignment: .leading, spacing: 14) {
        ForEach(content.badges) { badge in
          HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(badge.short)
              .font(AboutMetrics.captionFont.monospaced())
              .foregroundStyle(Color.KinoPub.text)
              .frame(width: AboutMetrics.legendGutter, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              Text(badge.name)
                .font(AboutMetrics.valueFont)
                .foregroundStyle(Color.KinoPub.text)
              Text(badge.explanation)
                .font(AboutMetrics.captionFont)
                .foregroundStyle(Color.KinoPub.subtitle)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }

      AboutColumn(title: "Information",
                  sections: content.releaseSections + content.detailSections + content.technicalSections)
    }
  }
}

// MARK: - 3 · Tiles + table

/// The split the brief asks for most directly. On top, the pre-play decisions as
/// pressable tiles — same card weight as the ratings row, so the background itself
/// says "there is more behind this". Underneath, one flat table for everything else,
/// free to grow to any number of rows without ever competing for attention.
struct AboutLayoutTiers: View {
  let content: MediaItemAboutContent

  var body: some View {
    VStack(alignment: .leading, spacing: AboutMetrics.blockSpacing) {
      AboutHeading("About")

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: AboutMetrics.cardSpacing) {
          ForEach(specTiles) { tile in
            AboutSpecTile(tile: tile)
          }
        }
        .padding(.vertical, DetailTileStyle.focusPadding)
      }
      .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
#if os(tvOS)
      .scrollClipDisabled()
      .focusSection()
#endif

      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: AboutMetrics.columnSpacing) {
          tableColumns
        }
        VStack(alignment: .leading, spacing: AboutMetrics.columnSpacing) {
          tableColumns
        }
      }
    }
  }

  @ViewBuilder
  private var tableColumns: some View {
    AboutColumn(title: "Information", sections: content.releaseSections)
    AboutColumn(title: "MediaItem_Technical",
                sections: content.detailSections + content.technicalSections)
  }

  private var specTiles: [AboutSpecTile.Model] {
    var tiles: [AboutSpecTile.Model] = []
    if let quality = content.technicalSections
      .first(where: { $0.id == "quality" })?.values.first?.title {
      tiles.append(.init(id: "quality", caption: "MediaItem_VideoQuality", value: quality))
    }
    if let voice = content.languageSummary.first {
      tiles.append(.init(id: "voice",
                         caption: "MediaItem_Voice",
                         value: voice.language,
                         detail: voice.best))
    }
    if !content.subtitleNames.isEmpty {
      tiles.append(.init(id: "subs",
                         caption: "Subtitles",
                         value: content.subtitleNames.prefix(2).joined(separator: ", ")))
    }
    if let rating = content.ageRating {
      tiles.append(.init(id: "age", caption: "MediaItem_AgeRating", value: rating))
    }
    return tiles
  }
}

// MARK: - 4 · Spec sheet

/// No cards anywhere. A dense two-column label/value sheet with hairline rules — the
/// shape a spec page or an infobox takes. Everything is on screen, nothing is folded
/// away, and the eye scans the left rail rather than hopping between panels. The bet:
/// for a page that is *reference material*, density beats decoration.
struct AboutLayoutSpecSheet: View {
  let content: MediaItemAboutContent

  private var allSections: [InfoSection] {
    content.releaseSections + content.detailSections + content.technicalSections
  }

  var body: some View {
    VStack(alignment: .leading, spacing: AboutMetrics.blockSpacing) {
      AboutHeading("About")

      VStack(spacing: 0) {
        ForEach(Array(allSections.enumerated()), id: \.element.id) { index, section in
          if index > 0 { Divider().overlay(Color.KinoPub.subtitle.opacity(0.18)) }
          HStack(alignment: .firstTextBaseline, spacing: AboutMetrics.columnSpacing) {
            Text(LocalizedStringKey(section.caption))
              .font(AboutMetrics.captionFont)
              .foregroundStyle(Color.KinoPub.subtitle)
              .frame(width: AboutMetrics.specLabelWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              ForEach(section.values) { value in
                Text(value.title)
                  .font(value.style == .note ? AboutMetrics.captionFont : AboutMetrics.valueFont)
                  .foregroundStyle(value.style == .note
                                   ? Color.KinoPub.subtitle
                                   : Color.KinoPub.text)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            Spacer(minLength: 0)
          }
          .padding(.vertical, AboutMetrics.specRowPadding)
        }

        if !content.languageSummary.isEmpty {
          Divider().overlay(Color.KinoPub.subtitle.opacity(0.18))
          HStack(alignment: .firstTextBaseline, spacing: AboutMetrics.columnSpacing) {
            Text("Languages")
              .font(AboutMetrics.captionFont)
              .foregroundStyle(Color.KinoPub.subtitle)
              .frame(width: AboutMetrics.specLabelWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              ForEach(content.languageSummary) { line in
                Text(AboutFormat.languageLine(line))
                  .font(AboutMetrics.valueFont)
                  .foregroundStyle(Color.KinoPub.text)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            Spacer(minLength: 0)
          }
          .padding(.vertical, AboutMetrics.specRowPadding)
        }

        if !content.badges.isEmpty {
          Divider().overlay(Color.KinoPub.subtitle.opacity(0.18))
          HStack(alignment: .firstTextBaseline, spacing: AboutMetrics.columnSpacing) {
            Text("MediaItem_Technical")
              .font(AboutMetrics.captionFont)
              .foregroundStyle(Color.KinoPub.subtitle)
              .frame(width: AboutMetrics.specLabelWidth, alignment: .leading)
            AboutFlowLayout(spacing: AboutMetrics.chipSpacing) {
              ForEach(content.badges) { badge in
                AboutBadgeChip(badge: badge)
              }
            }
            Spacer(minLength: 0)
          }
          .padding(.vertical, AboutMetrics.specRowPadding)
        }
      }
    }
  }
}

// MARK: - Shared pieces

/// Section heading for the block. Deliberately small: the old 32pt titles were taking
/// the attention their contents wanted.
struct AboutHeading: View {
  private let key: LocalizedStringKey
  init(_ key: LocalizedStringKey) { self.key = key }

  var body: some View {
    Text(key)
      .font(AboutMetrics.headingFont)
      .foregroundStyle(.secondary)
  }
}

struct AboutCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(AboutMetrics.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: AboutMetrics.cardCornerRadius, style: .continuous)
          .fill(.thinMaterial)
      }
  }
}

/// Which sizes a column's lines are drawn at. The same lines appear twice — small and
/// skippable in the page, at reading size in the popup — and nothing else differs.
struct AboutColumnTypography {
  let caption: Font
  let value: Font

  static let inline = AboutColumnTypography(caption: AboutMetrics.captionFont,
                                            value: AboutMetrics.valueFont)
  /// The popup is a reading surface, and on a TV that is the whole reason to open it.
  static let popup = AboutColumnTypography(caption: .caption, value: InfoPopupMetrics.bodyFont)
}

/// Plain, unbacked column of label/value blocks — the "table" half of every layout.
///
/// The column opens itself. Nothing here is clipped by a line limit, but the content
/// *is* summarised upstream (the Languages column keeps three preferred languages and
/// counts the rest), and at ten feet the table is deliberately small — so selecting the
/// column shows the same lines at reading size. No `i` button beside it: the thing you
/// want to read is the thing you press.
struct AboutColumn: View {
  let title: LocalizedStringKey
  let sections: [InfoSection]
  var languageLines: [MediaItemAboutContent.LanguageLine] = []
  var subtitleNames: [String] = []

  var body: some View {
    VStack(alignment: .leading, spacing: AboutMetrics.sectionSpacing) {
      Text(title)
        .font(AboutMetrics.columnTitleFont)
        .foregroundStyle(Color.KinoPub.text)

      lines(typography: .inline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .expandsIntoInfoPopup(title: Text(title)) {
      lines(typography: .popup)
    }
  }

  @ViewBuilder
  private func lines(typography: AboutColumnTypography) -> some View {
    VStack(alignment: .leading, spacing: AboutMetrics.sectionSpacing) {
      ForEach(sections) { section in
        VStack(alignment: .leading, spacing: 3) {
          Text(LocalizedStringKey(section.caption))
            .font(typography.caption)
            .foregroundStyle(Color.KinoPub.subtitle)
          ForEach(section.values) { value in
            Text(value.title)
              .font(value.style == .note ? typography.caption : typography.value)
              .foregroundStyle(value.style == .note
                               ? Color.KinoPub.subtitle
                               : Color.KinoPub.text)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      if !languageLines.isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          Text("MediaItem_Voice")
            .font(typography.caption)
            .foregroundStyle(Color.KinoPub.subtitle)
          ForEach(languageLines) { line in
            Text(AboutFormat.languageLine(line))
              .font(typography.value)
              .foregroundStyle(Color.KinoPub.text)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      if !subtitleNames.isEmpty {
        VStack(alignment: .leading, spacing: 3) {
          Text("Subtitles")
            .font(typography.caption)
            .foregroundStyle(Color.KinoPub.subtitle)
          Text(subtitleNames.joined(separator: ", "))
            .font(typography.value)
            .foregroundStyle(Color.KinoPub.text)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Apple's Accessibility column: the badge, then what it means, in prose. Opens itself
/// the same way the other columns do — this is the one column that is pure explanation,
/// so reading size is exactly what it is for.
struct AboutLegendColumn: View {
  let badges: [MediaItemAboutContent.AboutBadge]

  var body: some View {
    VStack(alignment: .leading, spacing: AboutMetrics.sectionSpacing) {
      Text("MediaItem_Technical")
        .font(AboutMetrics.columnTitleFont)
        .foregroundStyle(Color.KinoPub.text)

      legend(typography: .inline)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .expandsIntoInfoPopup(title: Text("MediaItem_Technical")) {
      legend(typography: .popup)
    }
  }

  private func legend(typography: AboutColumnTypography) -> some View {
    VStack(alignment: .leading, spacing: AboutMetrics.sectionSpacing) {
      ForEach(badges) { badge in
        VStack(alignment: .leading, spacing: 4) {
          AboutBadgeChip(badge: badge)
          Text(badge.explanation)
            .font(typography.caption)
            .foregroundStyle(Color.KinoPub.subtitle)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct AboutBadgeChip: View {
  let badge: MediaItemAboutContent.AboutBadge

  var body: some View {
    Text(badge.short)
      .font(AboutMetrics.badgeFont)
      .foregroundStyle(badge.isProminent ? Color.black : Color.KinoPub.text)
      .padding(.horizontal, AboutMetrics.badgeHorizontalPadding)
      .padding(.vertical, AboutMetrics.badgeVerticalPadding)
      .background {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill(badge.isProminent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.thinMaterial))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(Color.KinoPub.subtitle.opacity(badge.isProminent ? 0 : 0.5), lineWidth: 1)
      }
  }
}

/// Card-backed, pressable spec — same weight as a rating tile, which is the whole
/// point: the background is the affordance.
struct AboutSpecTile: View {
  struct Model: Identifiable {
    let id: String
    let caption: LocalizedStringKey
    let value: String
    var detail: String? = nil
  }

  let tile: Model

  var body: some View {
    Button {
      // Nothing behind these yet — the expansion (all resolutions, every dub,
      // the full parental guide) is the next step once a layout is chosen.
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        Text(tile.caption)
          .font(AboutMetrics.captionFont)
          .foregroundStyle(Color.KinoPub.subtitle)
        Text(tile.value)
          .font(AboutMetrics.tileValueFont)
          .foregroundStyle(Color.KinoPub.text)
        if let detail = tile.detail {
          Text(detail)
            .font(AboutMetrics.captionFont)
            .foregroundStyle(Color.KinoPub.subtitle)
        }
      }
      .frame(width: AboutMetrics.tileWidth, alignment: .leading)
      .padding(AboutMetrics.cardPadding)
    }
    .buttonStyle(DetailTileStyle.buttonStyle)
  }
}

enum AboutFormat {
  static func languageLine(_ line: MediaItemAboutContent.LanguageLine) -> String {
    var text = line.language
    if let best = line.best { text += " · \(best)" }
    if line.extraCount > 0 { text += " +\(line.extraCount)" }
    return text
  }
}

/// Left-aligned wrapping row. SwiftUI has no flow container: `HStack` runs off the
/// edge and `LazyVGrid` forces one column width that "CC" and "Dolby Digital" cannot
/// share.
struct AboutFlowLayout: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var rowWidth: CGFloat = 0
    var rowHeight: CGFloat = 0
    var totalHeight: CGFloat = 0
    var widest: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
        widest = max(widest, rowWidth)
        totalHeight += rowHeight + spacing
        rowWidth = size.width
        rowHeight = size.height
      } else {
        rowWidth += rowWidth > 0 ? spacing + size.width : size.width
        rowHeight = max(rowHeight, size.height)
      }
    }
    widest = max(widest, rowWidth)
    totalHeight += rowHeight
    return CGSize(width: min(widest, maxWidth), height: totalHeight)
  }

  func placeSubviews(in bounds: CGRect,
                     proposal: ProposedViewSize,
                     subviews: Subviews,
                     cache: inout ()) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x > bounds.minX, x + size.width > bounds.maxX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}

#if DEBUG
/// DEBUG-only cycle button, so the four candidates can be flipped through on-device
/// without a trip to Settings. Deleted along with the losing layouts.
struct AboutLayoutSwitcher: View {
  let layout: MediaItemAboutLayout
  let onChange: (MediaItemAboutLayout) -> Void

  var body: some View {
    Button {
      let all = MediaItemAboutLayout.allCases
      let index = all.firstIndex(of: layout) ?? 0
      onChange(all[(index + 1) % all.count])
    } label: {
      Text("Layout: \(layout.title)")
        .font(AboutMetrics.captionFont)
    }
    .buttonStyle(DetailTileStyle.buttonStyle)
  }
}
#endif

enum AboutMetrics {
#if os(tvOS)
  static let blockSpacing: CGFloat = 28
  static let cardSpacing: CGFloat = 24
  static let columnSpacing: CGFloat = 60
  static let sectionSpacing: CGFloat = 18
  static let cardPadding: CGFloat = 28
  static let cardCornerRadius: CGFloat = 20
  static let chipSpacing: CGFloat = 10
  static let badgeHorizontalPadding: CGFloat = 12
  static let badgeVerticalPadding: CGFloat = 6
  static let legendGutter: CGFloat = 90
  static let specLabelWidth: CGFloat = 320
  static let specRowPadding: CGFloat = 12
  static let tileWidth: CGFloat = 260
#else
  static let blockSpacing: CGFloat = 18
  static let cardSpacing: CGFloat = 12
  static let columnSpacing: CGFloat = 28
  static let sectionSpacing: CGFloat = 12
  static let cardPadding: CGFloat = 16
  static let cardCornerRadius: CGFloat = 14
  static let chipSpacing: CGFloat = 6
  static let badgeHorizontalPadding: CGFloat = 7
  static let badgeVerticalPadding: CGFloat = 3
  static let legendGutter: CGFloat = 44
  static let specLabelWidth: CGFloat = 160
  static let specRowPadding: CGFloat = 8
  static let tileWidth: CGFloat = 150
#endif

  /// Smaller than the old section titles on purpose — see the file header.
  static let headingFont: Font = TypeScale.detailSection
  static let columnTitleFont: Font = TypeScale.actionLabel
  static let cardTitleFont: Font = TypeScale.actionLabel
  static let bodyFont: Font = TypeScale.detailBody
  static let valueFont: Font = TypeScale.detailBody
  static let captionFont: Font = TypeScale.cardSubtitle
  static let tileValueFont: Font = TypeScale.rowHeader
  static let badgeFont: Font = TypeScale.cardMeta.weight(.semibold)
}
