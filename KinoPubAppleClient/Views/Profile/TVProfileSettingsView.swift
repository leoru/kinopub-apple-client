//
//  TVProfileSettingsView.swift
//  KinoPubAppleClient
//
//  System-settings-shaped layout for tvOS: persistent left panel (page icon +
//  per-row tip), right list of pill rows. Read-only account rows have no plate.
//  Root has no page title (the tab bar is enough); pushed pages show a centered
//  title and hide the tab bar.
//

#if os(tvOS)
import SwiftUI
import KinoPubBackend
import KinoPubUI

struct TVProfileSettingsView: View {

  let model: ProfileModel
  let kinopoiskKeyProvider: KinopoiskKeyProvider
  @Binding var selectedLanguage: String
  @Binding var preferEnglishSubtitles: Bool
  @Binding var preferNonCCSubtitles: Bool
  @Binding var dualSubtitlesEnabled: Bool
  @Binding var secondSubtitleLanguage: String
  @Binding var streamQualityRaw: String
  var onLogout: () -> Void
  var onLanguageChange: (String) -> Void

  @FocusState private var focusedItem: SettingsFocusItem?
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      rootPage
        .navigationDestination(for: SettingsRoute.self) { route in
          destination(for: route)
            .toolbar(.hidden, for: .tabBar)
        }
    }
    .toolbar(path.isEmpty ? .automatic : .hidden, for: .tabBar)
  }

  // MARK: - Root

  private var rootPage: some View {
    SettingsSplitLayout(
      title: nil,
      pageSymbol: "gear",
      tipKey: tip.messageKey
    ) {
      accountSection
      languageSection
      playbackSection
      // DESIGN: Devices section — `DeviceService.listDevices` / `removeDevice` are ready
      // (identity + HEVC/4K/HDR already sync on auth). Focusable Settings list TBD.
      kinopoiskSection
      dataSourcesSection
#if DEBUG
      diagnosticsSection
#endif
      logoutSection
    }
    .defaultFocus($focusedItem, .language)
  }

  // MARK: - Destinations

  @ViewBuilder
  private func destination(for route: SettingsRoute) -> some View {
    switch route {
    case .language:
      SettingsChoiceView(
        title: "Language",
        pageSymbol: "globe",
        tipKey: "Settings_Tip_Language",
        options: model.availableLanguages.keys.sorted().map { key in
          SettingsChoiceOption(id: key, title: model.availableLanguages[key] ?? key)
        },
        selection: $selectedLanguage,
        onSelect: onLanguageChange
      )
    case .secondSubtitleLanguage:
      SettingsChoiceView(
        title: "Second subtitle language",
        pageSymbol: "character.bubble",
        tipKey: "Settings_Tip_SecondLanguage",
        options: SubtitlePreferences.secondLanguageOptions.map { code in
          SettingsChoiceOption(id: code, title: LanguageNames.name(for: code))
        },
        selection: $secondSubtitleLanguage
      )
    case .streamQuality:
      SettingsChoiceView(
        title: "Stream quality",
        pageSymbol: "gauge.with.dots.needle.33percent",
        tipKey: "Settings_Tip_StreamQuality",
        options: StreamQuality.allCases.map { quality in
          SettingsChoiceOption(id: quality.rawValue, title: quality.title)
        },
        selection: $streamQualityRaw
      )
    case .kinopoisk:
      TVKinopoiskKeyView(keyProvider: kinopoiskKeyProvider)
#if DEBUG
    case .streamSurvey:
      StreamSurveyView()
    case .typeStyles:
      SystemTypeStylesCatalogView()
    case .tvUIKitGallery:
      TVUIKitComponentGalleryView()
    case .navFocusLab:
      NavigationFocusLabView()
    case .libraryLab:
      LibrarySidebarLabView()
#endif
    }
  }

  // MARK: - Sections

  private var tip: SettingsTip {
    SettingsTip.tip(for: focusedItem)
  }

  private var accountSection: some View {
    SettingsSection("Account") {
      infoRow(label: "User Name", value: model.userData.username)
      infoRow(
        label: "User Subscription",
        value: "\(model.userData.subscription.days) \("days".localized)"
      )
      infoRow(label: "Registration Date", value: model.userData.registrationDateFormatted)
      infoRow(label: "App version", value: Bundle.main.appVersionLong)
    }
  }

  private var languageSection: some View {
    SettingsSection("Language") {
      Button {
        path.append(SettingsRoute.language)
      } label: {
        SettingsPillLabel(
          title: "Language",
          value: model.availableLanguages[selectedLanguage] ?? selectedLanguage,
          showsChevron: true
        )
      }
      .buttonStyle(SettingsPillButtonStyle())
      .focused($focusedItem, equals: .language)
    }
  }

  private var playbackSection: some View {
    SettingsSection("Playback") {
      Button {
        path.append(SettingsRoute.streamQuality)
      } label: {
        SettingsPillLabel(
          title: "Stream quality",
          value: (StreamQuality(rawValue: streamQualityRaw) ?? .auto).title,
          showsChevron: true
        )
      }
      .buttonStyle(SettingsPillButtonStyle())
      .focused($focusedItem, equals: .streamQuality)

      toggleRow(
        title: "Default English subtitles",
        isOn: $preferEnglishSubtitles,
        focus: .englishSubs
      )

      toggleRow(
        title: "Prefer non-CC / non-SDH",
        isOn: $preferNonCCSubtitles,
        focus: .nonCC
      )
      .disabled(!preferEnglishSubtitles)

      toggleRow(
        title: "Dual subtitles",
        isOn: $dualSubtitlesEnabled,
        focus: .dual
      )

      Button {
        path.append(SettingsRoute.secondSubtitleLanguage)
      } label: {
        SettingsPillLabel(
          title: "Second subtitle language",
          value: LanguageNames.name(for: secondSubtitleLanguage),
          showsChevron: true
        )
      }
      .buttonStyle(SettingsPillButtonStyle())
      .focused($focusedItem, equals: .secondLang)
      .disabled(!dualSubtitlesEnabled)
    }
  }

  private var kinopoiskSection: some View {
    SettingsSection("Kinopoisk") {
      Button {
        path.append(SettingsRoute.kinopoisk)
      } label: {
        SettingsPillLabel(title: "API key", showsChevron: true)
      }
      .buttonStyle(SettingsPillButtonStyle())
      .focused($focusedItem, equals: .kinopoisk)
    }
  }

  private var dataSourcesSection: some View {
    SettingsSection("Data sources") {
      DataSourcesAttributionView()
        .padding(.horizontal, Metrics.pillHorizontalPadding)
        .padding(.vertical, Metrics.infoVerticalPadding)
        .focusable()
        .focused($focusedItem, equals: .dataSources)
    }
  }

#if DEBUG
  private var diagnosticsSection: some View {
    // Every row carries its own focus value. They all shared `.diagnostics` before,
    // which is the exact pattern `.claude/skills/tvos-surface/SKILL.md` bans —
    // several sibling views bound to one `@FocusState` equals-value leave the engine
    // unable to resolve which one is focused, and that cost a whole misdiagnosed
    // detour on the detail page. The payload only disambiguates; the tip stays shared.
    SettingsSection("Diagnostics") {
      diagnosticsRow("Stream survey", route: .streamSurvey, id: "streamSurvey")
      diagnosticsRow("Type Styles", route: .typeStyles, id: "typeStyles")
      diagnosticsRow("TVUIKit Gallery", route: .tvUIKitGallery, id: "tvUIKitGallery")
      diagnosticsRow("Navigation / Focus Lab", route: .navFocusLab, id: "navFocusLab")
      diagnosticsRow("Library Sidebar Lab", route: .libraryLab, id: "libraryLab")
    }
  }

  private func diagnosticsRow(_ title: LocalizedStringKey,
                              route: SettingsRoute,
                              id: String) -> some View {
    Button {
      path.append(route)
    } label: {
      SettingsPillLabel(title: title, showsChevron: true)
    }
    .buttonStyle(SettingsPillButtonStyle())
    .focused($focusedItem, equals: .diagnostics(id))
  }
#endif

  private var logoutSection: some View {
    Button(action: onLogout) {
      SettingsPillLabel(title: "Logout", isDestructive: true)
    }
    .buttonStyle(SettingsPillButtonStyle())
    .focused($focusedItem, equals: .logout)
  }

  private func infoRow(label: LocalizedStringKey, value: String) -> some View {
    HStack(spacing: 16) {
      Text(label)
        .foregroundStyle(.primary)
      Spacer(minLength: 12)
      Text(value)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.trailing)
    }
    .padding(.horizontal, Metrics.pillHorizontalPadding)
    .padding(.vertical, Metrics.infoVerticalPadding)
  }

  private func toggleRow(
    title: LocalizedStringKey,
    isOn: Binding<Bool>,
    focus: SettingsFocusItem
  ) -> some View {
    Button {
      isOn.wrappedValue.toggle()
    } label: {
      SettingsPillLabel(
        title: title,
        value: isOn.wrappedValue ? "On".localized : "Off".localized
      )
    }
    .buttonStyle(SettingsPillButtonStyle())
    .focused($focusedItem, equals: focus)
  }
}

// MARK: - Split chrome

/// Full-width optional title + 50/50 left tip panel and right list.
private struct SettingsSplitLayout<Content: View>: View {
  let title: LocalizedStringKey?
  let pageSymbol: String
  let tipKey: LocalizedStringKey
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(spacing: 0) {
      if let title {
        Text(title)
          .font(.system(size: Metrics.titlePointSize, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
          .padding(.top, Metrics.titleTopPadding)
          .padding(.bottom, Metrics.titleBottomPadding)
      }

      HStack(alignment: .top, spacing: 0) {
        SettingsLeftPanel(symbol: pageSymbol, tipKey: tipKey)
          .frame(maxWidth: .infinity)

        ScrollView {
          VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            content()
          }
          .padding(.horizontal, Metrics.listHorizontalPadding)
          .padding(.top, title == nil ? Metrics.listTopPaddingRoot : Metrics.listTopPaddingPushed)
          .padding(.bottom, Metrics.listBottomPadding)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Page icon is fixed; only the tip text crossfades when focus moves.
private struct SettingsLeftPanel: View {
  let symbol: String
  let tipKey: LocalizedStringKey

  var body: some View {
    VStack(spacing: Metrics.previewSpacing) {
      Image(systemName: symbol)
        .font(.system(size: Metrics.iconPointSize, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: Metrics.iconFrame, height: Metrics.iconFrame)
        .background(
          RoundedRectangle(cornerRadius: Metrics.iconCornerRadius, style: .continuous)
            .fill(Color.KinoPub.selectionBackground)
        )

      Text(tipKey)
        .font(.system(size: Metrics.tipPointSize))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .frame(minHeight: Metrics.tipMinHeight, alignment: .top)
        .padding(.horizontal, Metrics.tipHorizontalPadding)
        .animation(.easeOut(duration: 0.25), value: String(describing: tipKey))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(.top, Metrics.previewTopPadding)
    .padding(.horizontal, Metrics.previewSidePadding)
  }
}

private struct SettingsSection<Content: View>: View {
  let title: LocalizedStringKey
  @ViewBuilder var content: () -> Content

  init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
    self.title = title
    self.content = content
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Metrics.rowSpacing) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
        .padding(.horizontal, Metrics.pillHorizontalPadding)
        .padding(.bottom, 4)
      content()
    }
  }
}

// MARK: - Routes / focus / tips

private enum SettingsRoute: Hashable {
  case language
  case secondSubtitleLanguage
  case streamQuality
  case kinopoisk
#if DEBUG
  case streamSurvey
  case typeStyles
  case tvUIKitGallery
  case navFocusLab
  case libraryLab
#endif
}

private enum SettingsFocusItem: Hashable {
  case language
  case streamQuality
  case englishSubs
  case nonCC
  case dual
  case secondLang
  case kinopoisk
  case dataSources
  case logout
  /// The payload only keeps sibling rows from sharing one focus value — see the note
  /// on `diagnosticsRow`. Every diagnostics row still shows the same tip.
  case diagnostics(String)
}

private struct SettingsTip {
  let messageKey: LocalizedStringKey

  static func tip(for item: SettingsFocusItem?) -> SettingsTip {
    switch item {
    case .language:
      return SettingsTip(messageKey: "Settings_Tip_Language")
    case .streamQuality:
      return SettingsTip(messageKey: "Settings_Tip_StreamQuality")
    case .englishSubs:
      return SettingsTip(messageKey: "Settings_Tip_EnglishSubtitles")
    case .nonCC:
      return SettingsTip(messageKey: "Settings_Tip_PreferNonCC")
    case .dual:
      return SettingsTip(messageKey: "Settings_Tip_DualSubtitles")
    case .secondLang:
      return SettingsTip(messageKey: "Settings_Tip_SecondLanguage")
    case .kinopoisk:
      return SettingsTip(messageKey: "Settings_Tip_Kinopoisk")
    case .dataSources:
      return SettingsTip(messageKey: "Settings_Tip_DataSources")
    case .logout:
      return SettingsTip(messageKey: "Settings_Tip_Logout")
    case .diagnostics:
      return SettingsTip(messageKey: "Settings_Tip_Diagnostics")
    case nil:
      return SettingsTip(messageKey: "Settings_Tip_Default")
    }
  }
}

// MARK: - Pill pieces

private struct SettingsPillLabel: View {
  let title: LocalizedStringKey
  var verbatimTitle: String? = nil
  var value: String? = nil
  var showsChevron: Bool = false
  var showsCheckmark: Bool = false
  var isDestructive: Bool = false

  @Environment(\.isFocused) private var isFocused

  var body: some View {
    HStack(spacing: 16) {
      titleText
        .foregroundStyle(titleColor)
        .frame(maxWidth: .infinity, alignment: .leading)
      if let value {
        Text(verbatim: value)
          .foregroundStyle(valueColor)
      }
      if showsCheckmark {
        Image(systemName: "checkmark")
          .font(.body.weight(.semibold))
          .foregroundStyle(valueColor)
      }
      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(valueColor)
      }
    }
  }

  @ViewBuilder
  private var titleText: some View {
    if let verbatimTitle {
      Text(verbatim: verbatimTitle)
    } else {
      Text(title)
    }
  }

  private var titleColor: Color {
    if isFocused { return .black }
    if isDestructive { return .red }
    return .primary
  }

  private var valueColor: Color {
    if isFocused { return .black.opacity(0.55) }
    return .secondary
  }
}

private struct SettingsPillButtonStyle: ButtonStyle {
  func makeBody(configuration: ButtonStyleConfiguration) -> some View {
    Pill(configuration: configuration)
  }

  private struct Pill: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
      configuration.label
        .padding(.horizontal, Metrics.pillHorizontalPadding)
        .padding(.vertical, Metrics.pillVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          Capsule(style: .continuous)
            .fill(isFocused ? Color.white : Color.KinoPub.selectionBackground)
        )
        .scaleEffect(isFocused ? 1.02 : (configuration.isPressed ? 0.98 : 1.0))
        .opacity(isEnabled ? 1.0 : 0.4)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
  }
}

// MARK: - Choice destination

private struct SettingsChoiceOption: Identifiable, Hashable {
  let id: String
  let title: String
}

private struct SettingsChoiceView: View {
  let title: LocalizedStringKey
  let pageSymbol: String
  let tipKey: LocalizedStringKey
  let options: [SettingsChoiceOption]
  @Binding var selection: String
  var onSelect: ((String) -> Void)? = nil

  @Environment(\.dismiss) private var dismiss
  @FocusState private var focusedID: String?

  var body: some View {
    SettingsSplitLayout(title: title, pageSymbol: pageSymbol, tipKey: tipKey) {
      ForEach(options) { option in
        Button {
          selection = option.id
          onSelect?(option.id)
          dismiss()
        } label: {
          SettingsPillLabel(
            title: LocalizedStringKey(option.title),
            verbatimTitle: option.title,
            showsCheckmark: selection == option.id
          )
        }
        .buttonStyle(SettingsPillButtonStyle())
        .focused($focusedID, equals: option.id)
      }
    }
    .background(Color.KinoPub.background.ignoresSafeArea())
    .defaultFocus($focusedID, selection)
    .onAppear {
      if focusedID == nil {
        focusedID = selection
      }
    }
  }
}

// MARK: - Kinopoisk key destination

/// First text-entry UI anywhere in this app — auth is device-code OAuth, so
/// there was no existing pattern to follow. `TextField` does work on tvOS (the
/// system on-screen keyboard comes up on focus+click), but typing a 30+ char
/// key via Siri Remote is inherently clunky — an accepted compromise for now,
/// same spirit as this app's other "unverified on real remote" callouts.
private struct TVKinopoiskKeyView: View {
  @StateObject private var model: KinopoiskKeySettingsModel
  @FocusState private var isFieldFocused: Bool

  init(keyProvider: KinopoiskKeyProvider) {
    _model = StateObject(wrappedValue: KinopoiskKeySettingsModel(keyProvider: keyProvider))
  }

  var body: some View {
    SettingsSplitLayout(title: "Kinopoisk", pageSymbol: "photo.stack", tipKey: "Settings_Tip_Kinopoisk") {
      TextField("API key", text: $model.keyText)
        .textFieldStyle(.plain)
        .padding(.horizontal, Metrics.pillHorizontalPadding)
        .padding(.vertical, Metrics.pillVerticalPadding)
        .background(
          Capsule(style: .continuous)
            .fill(isFieldFocused ? Color.white : Color.KinoPub.selectionBackground)
        )
        .focused($isFieldFocused)

      Button {
        Task { await model.validate() }
      } label: {
        SettingsPillLabel(title: "Validate")
      }
      .buttonStyle(SettingsPillButtonStyle())
      .disabled(!model.isValidateEnabled)

      Text(model.statusText)
        .font(.system(size: Metrics.tipPointSize))
        .foregroundStyle(.secondary)
        .padding(.horizontal, Metrics.pillHorizontalPadding)
        .fixedSize(horizontal: false, vertical: true)
    }
    .background(Color.KinoPub.background.ignoresSafeArea())
    .defaultFocus($isFieldFocused, true)
  }
}

// MARK: - Metrics

private enum Metrics {
  // Title spans the full page (not the list column).
  static let titlePointSize: CGFloat = 48
  static let titleTopPadding: CGFloat = 20
  static let titleBottomPadding: CGFloat = 12

  // Left panel — icon stays put; tip text has a reserved height so focus
  // changes don't reflow the stack.
  static let previewTopPadding: CGFloat = 72
  static let previewSidePadding: CGFloat = 40
  static let previewSpacing: CGFloat = 28
  static let iconFrame: CGFloat = 260
  static let iconPointSize: CGFloat = 100
  static let iconCornerRadius: CGFloat = 52
  static let tipPointSize: CGFloat = 28
  static let tipMinHeight: CGFloat = 120
  static let tipHorizontalPadding: CGFloat = 24

  // Right list fills its half; only inset, no fixed width clamp.
  static let listHorizontalPadding: CGFloat = 32
  static let listTopPaddingRoot: CGFloat = 72
  static let listTopPaddingPushed: CGFloat = 8
  static let listBottomPadding: CGFloat = 48
  static let sectionSpacing: CGFloat = 36
  static let rowSpacing: CGFloat = 12
  static let pillHorizontalPadding: CGFloat = 28
  static let pillVerticalPadding: CGFloat = 18
  static let infoVerticalPadding: CGFloat = 14
}

#endif
