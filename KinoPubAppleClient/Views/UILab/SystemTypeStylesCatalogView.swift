//
//  SystemTypeStylesCatalogView.swift
//  KinoPubAppleClient
//
//  DEBUG reference: system text styles × semantic / vibrant color roles.
//  Tap any sample card for a full material preview over a blurred backdrop.
//

#if DEBUG
import SwiftUI
import KinoPubUI
#if os(macOS)
import AppKit
#endif

// MARK: - Catalog

struct SystemTypeStylesCatalogView: View {
  @State private var section: CatalogSection = .systemStyles
  @State private var previewSelection: TypeStylePreviewSelection?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: sectionSpacing) {
        header
        sectionPicker
        sectionContent
        platformFooter
      }
      .padding(contentPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color.KinoPub.background)
    .platformNavigationTitle("Type Styles")
    .sheet(item: $previewSelection) { selection in
      TypeStyleMaterialPreviewSheet(selection: selection)
#if os(macOS)
        .frame(minWidth: 720, minHeight: 560)
#endif
    }
  }

  // MARK: - Sections

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("System Type Styles")
        .font(TypeScale.settingsTitle)
      Text("Flat cards show label hierarchy on the page background. Tap any card for a blurred-backdrop + material preview — including Vibrant Primary / Secondary / Tertiary.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var sectionPicker: some View {
    Picker("Section", selection: $section) {
      ForEach(CatalogSection.allCases) { item in
        Text(item.title).tag(item)
      }
    }
    .pickerStyle(.segmented)
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch section {
    case .systemStyles:
      systemStylesSection
    case .semanticColors:
      semanticColorsSection
    case .typeScale:
      typeScaleSection
    case .weights:
      weightsSection
    }
  }

  private var systemStylesSection: some View {
    VStack(alignment: .leading, spacing: rowSpacing) {
      catalogSectionHeader(
        "Text Styles × Colors",
        note: "Default and Emphasized weights. Vibrant roles use a material chip in-grid; tap for the full backdrop preview."
      )

      ForEach(SystemFontSpec.all) { spec in
        VStack(alignment: .leading, spacing: 12) {
          Text(spec.name)
            .font(.headline)
            .foregroundStyle(.secondary)

          styleGrid(
            spec: spec,
            weight: .default,
            font: spec.font
          )

          styleGrid(
            spec: spec,
            weight: .emphasized,
            font: spec.emphasizedFont
          )
        }
      }
    }
  }

  private func styleGrid(spec: SystemFontSpec, weight: SampleWeight, font: Font) -> some View {
    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
      ForEach(SemanticColorRole.allCases) { role in
        TypeStyleSampleCard(
          role: role,
          weight: weight,
          font: font,
          sample: spec.samplePhrase,
          styleName: spec.name
        ) {
          previewSelection = TypeStylePreviewSelection(
            role: role,
            weight: weight,
            font: font,
            sample: spec.samplePhrase,
            styleName: spec.name
          )
        }
      }
    }
  }

  private var semanticColorsSection: some View {
    VStack(alignment: .leading, spacing: rowSpacing) {
      catalogSectionHeader(
        "Semantic Colors",
        note: "Primary body copy at `.body` on each hierarchical foreground role."
      )

      roleGrid(font: .body) { $0.samplePhrase }

      catalogSectionHeader(
        "On Headline",
        note: "Same roles at `.headline`."
      )

      roleGrid(font: .headline) { $0.title }
    }
  }

  private func roleGrid(
    font: Font,
    sample: @escaping (SemanticColorRole) -> String
  ) -> some View {
    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 12) {
      ForEach(SemanticColorRole.allCases) { role in
        TypeStyleSampleCard(
          role: role,
          weight: .default,
          font: font,
          sample: sample(role),
          styleName: "Semantic"
        ) {
          previewSelection = TypeStylePreviewSelection(
            role: role,
            weight: .default,
            font: font,
            sample: sample(role),
            styleName: role.title
          )
        }
      }
    }
  }

  private var typeScaleSection: some View {
    VStack(alignment: .leading, spacing: rowSpacing) {
      catalogSectionHeader(
        "TypeScale tokens",
        note: "App-level aliases in `KinoPubUI/Layout/TypeScale.swift`. Tap a row for material preview."
      )

      ForEach(TypeScaleToken.all) { token in
        TypeScaleTokenRow(token: token) {
          previewSelection = TypeStylePreviewSelection(
            role: .primary,
            weight: .default,
            font: token.font,
            sample: token.sample,
            styleName: "TypeScale.\(token.name)"
          )
        }
      }
    }
  }

  private var weightsSection: some View {
    VStack(alignment: .leading, spacing: rowSpacing) {
      catalogSectionHeader(
        "Weight axis",
        note: "Same `.body` style with regular, medium, semibold, and bold."
      )

      ForEach(FontWeightSpec.all) { spec in
        HStack(alignment: .firstTextBaseline, spacing: 16) {
          Text(spec.name)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(width: labelColumnWidth, alignment: .leading)

          Text("Shows, Movies, and More")
            .font(.body.weight(spec.weight))
            .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
      }

      catalogSectionHeader(
        "Title weights",
        note: "`.title2` with the same weight sweep."
      )

      ForEach(FontWeightSpec.all) { spec in
        HStack(alignment: .firstTextBaseline, spacing: 16) {
          Text(spec.name)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(width: labelColumnWidth, alignment: .leading)

          Text("Browse Categories")
            .font(.title2.weight(spec.weight))
            .foregroundStyle(.primary)
        }
        .padding(.vertical, 6)
      }
    }
  }

  private var platformFooter: some View {
    VStack(alignment: .leading, spacing: 4) {
      Divider().padding(.vertical, 8)
      LabeledContent("Platform") {
        Text(platformLabel).foregroundStyle(.secondary)
      }
      LabeledContent("Color scheme") {
        Text("Dark (app enforced)").foregroundStyle(.secondary)
      }
    }
    .font(.footnote)
  }

  // MARK: - Layout

  private var gridColumns: [GridItem] {
#if os(tvOS)
    [GridItem(.adaptive(minimum: 420), spacing: 16)]
#elseif os(macOS)
    [GridItem(.adaptive(minimum: 260), spacing: 12)]
#else
    [GridItem(.adaptive(minimum: 300), spacing: 12)]
#endif
  }

  private var contentPadding: CGFloat {
#if os(tvOS)
    48
#else
    20
#endif
  }

  private var sectionSpacing: CGFloat {
#if os(tvOS)
    40
#else
    28
#endif
  }

  private var rowSpacing: CGFloat {
#if os(tvOS)
    32
#else
    24
#endif
  }

  private var labelColumnWidth: CGFloat {
#if os(tvOS)
    120
#else
    88
#endif
  }

  private var platformLabel: String {
#if os(macOS)
    "macOS"
#elseif os(tvOS)
    "tvOS"
#elseif os(iOS)
    "iOS"
#else
    "Unknown"
#endif
  }

  @ViewBuilder
  private func catalogSectionHeader(_ title: String, note: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title3.weight(.semibold))
      Text(note)
        .font(.footnote)
        .foregroundStyle(.tertiary)
    }
  }
}

// MARK: - Section enum

private enum CatalogSection: String, CaseIterable, Identifiable {
  case systemStyles
  case semanticColors
  case typeScale
  case weights

  var id: String { rawValue }

  var title: String {
    switch self {
    case .systemStyles: return "Styles"
    case .semanticColors: return "Colors"
    case .typeScale: return "TypeScale"
    case .weights: return "Weights"
    }
  }
}

// MARK: - Preview selection

private struct TypeStylePreviewSelection: Identifiable {
  let id = UUID()
  let role: SemanticColorRole
  let weight: SampleWeight
  let font: Font
  let sample: String
  let styleName: String
}

// MARK: - System fonts

private struct SystemFontSpec: Identifiable {
  let name: String
  let font: Font
  let emphasizedFont: Font
  let samplePhrase: String

  var id: String { name }

  static let all: [SystemFontSpec] = [
    .init(name: "Large Title", font: .largeTitle, emphasizedFont: .largeTitle.bold(), samplePhrase: "Large Title"),
    .init(name: "Title", font: .title, emphasizedFont: .title.bold(), samplePhrase: "Title"),
    .init(name: "Title 2", font: .title2, emphasizedFont: .title2.bold(), samplePhrase: "Title 2"),
    .init(name: "Title 3", font: .title3, emphasizedFont: .title3.bold(), samplePhrase: "Title 3"),
    .init(name: "Headline", font: .headline, emphasizedFont: .headline.bold(), samplePhrase: "Headline"),
    .init(name: "Body", font: .body, emphasizedFont: .body.weight(.semibold), samplePhrase: "Body text for running copy"),
    .init(name: "Callout", font: .callout, emphasizedFont: .callout.weight(.semibold), samplePhrase: "Callout"),
    .init(name: "Subheadline", font: .subheadline, emphasizedFont: .subheadline.weight(.semibold), samplePhrase: "Subheadline"),
    .init(name: "Footnote", font: .footnote, emphasizedFont: .footnote.weight(.semibold), samplePhrase: "Footnote"),
    .init(name: "Caption", font: .caption, emphasizedFont: .caption.weight(.semibold), samplePhrase: "Caption"),
    .init(name: "Caption 2", font: .caption2, emphasizedFont: .caption2.weight(.semibold), samplePhrase: "Caption 2"),
  ]
}

// MARK: - Semantic colors

private enum SemanticColorRole: String, CaseIterable, Identifiable {
  case primary
  case secondary
  case tertiary
  case quaternary
  case accent
  case kinoText
  case kinoSubtitle
  case vibrantPrimary
  case vibrantSecondary
  case vibrantTertiary

  var id: String { rawValue }

  var title: String {
    switch self {
    case .primary: return "Primary"
    case .secondary: return "Secondary"
    case .tertiary: return "Tertiary"
    case .quaternary: return "Quaternary"
    case .accent: return "Accent"
    case .kinoText: return "KinoPub.text"
    case .kinoSubtitle: return "KinoPub.subtitle"
    case .vibrantPrimary: return "Vibrant Primary"
    case .vibrantSecondary: return "Vibrant Secondary"
    case .vibrantTertiary: return "Vibrant Tertiary"
    }
  }

  var samplePhrase: String { title }

  var needsMaterialBackdrop: Bool {
    switch self {
    case .vibrantPrimary, .vibrantSecondary, .vibrantTertiary:
      return true
    default:
      return false
    }
  }

  var isVibrant: Bool {
    switch self {
    case .vibrantPrimary, .vibrantSecondary, .vibrantTertiary:
      return true
    default:
      return false
    }
  }
}

private enum SampleWeight: String {
  case `default` = "Default"
  case emphasized = "Emphasized"
}

// MARK: - Sample card

private struct TypeStyleSampleCard: View {
  let role: SemanticColorRole
  let weight: SampleWeight
  let font: Font
  let sample: String
  let styleName: String
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 10) {
        sampleArea

        HStack {
          Text(role.title)
          Spacer(minLength: 8)
          Text(weight.rawValue)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)

        Text("Tap for material preview")
          .font(.caption2)
          .foregroundStyle(.quaternary)
      }
      .padding(cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.KinoPub.selectionBackground)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
      }
    }
    .buttonStyle(.plain)
#if os(tvOS)
    .buttonStyle(.borderless)
#endif
  }

  @ViewBuilder
  private var sampleArea: some View {
    if role.needsMaterialBackdrop {
      ZStack(alignment: .leading) {
        TypeStyleBackdropImage()
          .frame(height: sampleAreaHeight)
          .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(.regularMaterial)
          .frame(height: sampleAreaHeight)

        styledSample
          .font(font)
          .lineLimit(2)
          .minimumScaleFactor(0.85)
          .padding(.horizontal, 10)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      styledSample
        .font(font)
        .lineLimit(2)
        .minimumScaleFactor(0.85)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private var styledSample: some View {
    TypeStyleColoredText(role: role, text: sample)
  }

  private var sampleAreaHeight: CGFloat {
#if os(tvOS)
    72
#else
    52
#endif
  }

  private var cardPadding: CGFloat {
#if os(tvOS)
    20
#else
    14
#endif
  }
}

// MARK: - Colored text helper

private struct TypeStyleColoredText: View {
  let role: SemanticColorRole
  let text: String

  var body: some View {
    Group {
      switch role {
      case .primary, .vibrantPrimary:
        Text(text).foregroundStyle(.primary)
      case .secondary, .vibrantSecondary:
        Text(text).foregroundStyle(.secondary)
      case .tertiary, .vibrantTertiary:
        Text(text).foregroundStyle(.tertiary)
      case .quaternary:
        Text(text).foregroundStyle(.quaternary)
      case .accent:
        Text(text).foregroundStyle(Color.KinoPub.accent)
      case .kinoText:
        Text(text).foregroundStyle(Color.KinoPub.text)
      case .kinoSubtitle:
        Text(text).foregroundStyle(Color.KinoPub.subtitle)
      }
    }
  }
}

// MARK: - Material preview sheet

private struct TypeStyleMaterialPreviewSheet: View {
  let selection: TypeStylePreviewSelection

  @Environment(\.dismiss) private var dismiss
  @State private var material: TypeStylePreviewMaterial = .regular
  @State private var backdropIndex = 0

  private let backdrops = TypeStyleBackdrop.allCases

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          heroPreview
          controls
          comparisonGrid
        }
        .padding(contentPadding)
      }
      .background(Color.KinoPub.background)
      .platformNavigationTitle("Material Preview")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private var heroPreview: some View {
    ZStack(alignment: .bottomLeading) {
      TypeStyleBackdropImage(backdrop: backdrops[backdropIndex])
        .frame(height: heroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(material.swiftUIMaterial)
        .frame(height: heroHeight)

      VStack(alignment: .leading, spacing: 12) {
        TypeStyleColoredText(role: selection.role, text: selection.sample)
          .font(selection.font)

        Text("\(selection.styleName) · \(selection.role.title) · \(selection.weight.rawValue)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(20)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
    }
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Material")
          .font(.headline)
        Picker("Material", selection: $material) {
          ForEach(TypeStylePreviewMaterial.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Backdrop")
          .font(.headline)
        Picker("Backdrop", selection: $backdropIndex) {
          ForEach(backdrops.indices, id: \.self) { index in
            Text(backdrops[index].title).tag(index)
          }
        }
        .pickerStyle(.segmented)
      }
    }
  }

  private var comparisonGrid: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("All roles on this material")
        .font(.title3.weight(.semibold))

      Text("Standard hierarchy vs Vibrant — same semantic steps, Vibrant is meant for labels drawn on top of blurred content.")
        .font(.footnote)
        .foregroundStyle(.tertiary)

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], alignment: .leading, spacing: 12) {
        ForEach(SemanticColorRole.allCases) { role in
          materialRoleCard(role: role)
        }
      }
    }
  }

  private func materialRoleCard(role: SemanticColorRole) -> some View {
    ZStack(alignment: .leading) {
      TypeStyleBackdropImage(backdrop: backdrops[backdropIndex])
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(material.swiftUIMaterial)
        .frame(height: cardHeight)

      VStack(alignment: .leading, spacing: 4) {
        TypeStyleColoredText(role: role, text: role.title)
          .font(selection.font)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        if role.isVibrant {
          Text("Vibrant")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.horizontal, 12)
    }
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(
          role == selection.role ? Color.KinoPub.accent : Color.primary.opacity(0.08),
          lineWidth: role == selection.role ? 2 : 1
        )
    }
  }

  private var heroHeight: CGFloat {
#if os(tvOS)
    280
#else
    200
#endif
  }

  private var cardHeight: CGFloat {
#if os(tvOS)
    88
#else
    64
#endif
  }

  private var contentPadding: CGFloat {
#if os(tvOS)
    48
#else
    24
#endif
  }
}

// MARK: - Backdrop

private enum TypeStyleBackdrop: CaseIterable {
  case widePoster
  case poster
  case mesh

  var title: String {
    switch self {
    case .widePoster: return "Wide"
    case .poster: return "Poster"
    case .mesh: return "Mesh"
    }
  }

  var imageURL: URL? {
    switch self {
    case .widePoster:
      return URL(string: "https://m.staticpop.net/poster/item/wide/581.jpg")
    case .poster:
      return URL(string: "https://m.staticpop.net/poster/item/big/581.jpg")
    case .mesh:
      return nil
    }
  }
}

private struct TypeStyleBackdropImage: View {
  var backdrop: TypeStyleBackdrop = .widePoster

  var body: some View {
    Group {
      if let url = backdrop.imageURL {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
              .blur(radius: backdropBlurRadius)
          case .failure:
            meshFallback
          case .empty:
            meshFallback.overlay { ProgressView() }
          @unknown default:
            meshFallback
          }
        }
      } else {
        meshFallback
      }
    }
    .clipped()
  }

  private var backdropBlurRadius: CGFloat {
#if os(tvOS)
    28
#else
    18
#endif
  }

  private var meshFallback: some View {
    LinearGradient(
      colors: [
        Color(red: 0.15, green: 0.22, blue: 0.45),
        Color(red: 0.45, green: 0.18, blue: 0.32),
        Color(red: 0.12, green: 0.35, blue: 0.28)
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }
}

private enum TypeStylePreviewMaterial: String, CaseIterable, Identifiable {
  case ultraThin
  case thin
  case regular
  case thick
  case ultraThick

  var id: String { rawValue }

  var title: String {
    switch self {
    case .ultraThin: return "Ultra Thin"
    case .thin: return "Thin"
    case .regular: return "Regular"
    case .thick: return "Thick"
    case .ultraThick: return "Ultra Thick"
    }
  }

  var swiftUIMaterial: Material {
    switch self {
    case .ultraThin: return .ultraThinMaterial
    case .thin: return .thinMaterial
    case .regular: return .regularMaterial
    case .thick: return .thickMaterial
    case .ultraThick: return .ultraThickMaterial
    }
  }
}

// MARK: - TypeScale rows

private struct TypeScaleToken: Identifiable {
  let name: String
  let font: Font
  let sample: String

  var id: String { name }

  static let all: [TypeScaleToken] = [
    .init(name: "cardTitle", font: TypeScale.cardTitle, sample: "Card title"),
    .init(name: "cardSubtitle", font: TypeScale.cardSubtitle, sample: "Card subtitle"),
    .init(name: "cardMeta", font: TypeScale.cardMeta, sample: "4K · HDR"),
    .init(name: "rowHeader", font: TypeScale.rowHeader, sample: "Continue Watching"),
    .init(name: "rowCount", font: TypeScale.rowCount, sample: "12"),
    .init(name: "rowChevron", font: TypeScale.rowChevron, sample: "›"),
    .init(name: "heroTitle", font: TypeScale.heroTitle, sample: "Hero title"),
    .init(name: "heroSecondary", font: TypeScale.heroSecondary, sample: "Hero secondary"),
    .init(name: "detailBody", font: TypeScale.detailBody, sample: "Synopsis and metadata body copy."),
    .init(name: "filterControl", font: TypeScale.filterControl, sample: "Genre"),
    .init(name: "actionLabel", font: TypeScale.actionLabel, sample: "Play"),
    .init(name: "detailSection", font: TypeScale.detailSection, sample: "Episodes"),
    .init(name: "settingsTitle", font: TypeScale.settingsTitle, sample: "Settings"),
    .init(name: "settingsTip", font: TypeScale.settingsTip, sample: "Tip text"),
    .init(name: "ratingBadge", font: TypeScale.ratingBadge, sample: "8.4"),
    .init(name: "ratingAggregate", font: TypeScale.ratingAggregate, sample: "8.4"),
  ]
}

private struct TypeScaleTokenRow: View {
  let token: TypeScaleToken
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 8) {
        Text(token.name)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
          .textCase(.uppercase)

        HStack(alignment: .firstTextBaseline, spacing: 16) {
          Text(token.sample)
            .font(token.font)
            .foregroundStyle(Color.KinoPub.text)

          Spacer(minLength: 0)

          Text(token.sample)
            .font(token.font)
            .foregroundStyle(Color.KinoPub.subtitle)
        }

        Text("Tap for material preview")
          .font(.caption2)
          .foregroundStyle(.quaternary)
      }
      .padding(cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color.KinoPub.selectionBackground)
      }
    }
    .buttonStyle(.plain)
#if os(tvOS)
    .buttonStyle(.borderless)
#endif
  }

  private var cardPadding: CGFloat {
#if os(tvOS)
    20
#else
    14
#endif
  }
}

// MARK: - Weights

private struct FontWeightSpec: Identifiable {
  let name: String
  let weight: Font.Weight

  var id: String { name }

  static let all: [FontWeightSpec] = [
    .init(name: "Regular", weight: .regular),
    .init(name: "Medium", weight: .medium),
    .init(name: "Semibold", weight: .semibold),
    .init(name: "Bold", weight: .bold),
  ]
}

#endif
