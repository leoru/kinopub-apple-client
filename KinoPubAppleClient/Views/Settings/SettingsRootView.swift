//
//  SettingsRootView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if !os(tvOS)
/// Shared Settings shell: sidebar split on macOS, category list on iOS.
struct SettingsRootView: View {
  @Environment(\.appContext) private var appContext
  @Bindable var model: ProfileModel
  @State private var selectedCategory: SettingsCategory? = .general
  @State private var showLogoutAlert = false
  @State private var avatarImage: Image?
#if os(macOS)
  @State private var detailPath = NavigationPath()
#endif

  var body: some View {
#if os(macOS)
    macSplit
#else
    iosList
#endif
  }

#if os(macOS)
  private var macSplit: some View {
    NavigationSplitView {
      List(selection: $selectedCategory) {
        Section {
          Button {
            selectedCategory = .general
            detailPath = NavigationPath()
          } label: {
            SettingsSidebarProfileView(
              name: profileName,
              subtitle: profileSubtitle,
              avatarImage: avatarImage
            )
          }
          .buttonStyle(.plain)
        }

        Section {
          ForEach(SettingsCategory.availableCategories) { category in
            Label {
              Text(category.titleKey)
                .lineLimit(1)
            } icon: {
              SettingsIconView(systemImage: category.systemImage, color: category.iconColor)
            }
            .tag(category)
          }
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(220)
      .toolbar(removing: .sidebarToggle)
    } detail: {
      NavigationStack(path: $detailPath) {
        macDetailRoot
#if DEBUG
          .navigationDestination(for: SettingsDetailRoute.self) { route in
            switch route {
            case .streamSurvey:
              StreamSurveyView()
                .settingsMacChrome(title: "Stream survey", isRoot: false)
            case .uiLab(let chrome):
              // Prefer Window menu / openWindow on macOS; this is a fallback push.
              UILabRoot(initialChrome: chrome)
                .settingsMacChrome(title: LocalizedStringKey(chrome.windowTitle), isRoot: false)
            case .typeStyles:
              SystemTypeStylesCatalogView()
                .settingsMacChrome(title: "Type Styles", isRoot: false)
            }
          }
#endif
      }
      .navigationSplitViewColumnWidth(500)
    }
    .navigationSplitViewStyle(.balanced)
    .frame(width: 720, height: 520)
    .onChange(of: selectedCategory) { _, _ in
      detailPath = NavigationPath()
    }
    .task {
      model.fetch()
      await loadAvatar()
      if selectedCategory == nil || selectedCategory?.isAvailable == false {
        selectedCategory = SettingsCategory.availableCategories.first
      }
    }
    .alert("Are you sure?", isPresented: $showLogoutAlert) {
      Button("Logout", role: .destructive) { model.logout() }
      Button("Cancel", role: .cancel) { }
    }
    .alert(isPresented: $model.shouldShowExitAlert) {
      Alert(
        title: Text("Restarting the app"),
        message: Text("The app will restart to apply the language change."),
        primaryButton: .default(Text("OK")) { exit(0) },
        secondaryButton: .cancel()
      )
    }
  }

  @ViewBuilder
  private var macDetailRoot: some View {
    if let selectedCategory {
      pane(for: selectedCategory)
        .settingsMacChrome(title: selectedCategory.titleKey, isRoot: true)
    } else {
      ContentUnavailableView("Settings", systemImage: "gearshape")
    }
  }
#endif

#if os(iOS)
  private var iosList: some View {
    List {
      Section {
        SettingsSidebarProfileView(
          name: profileName,
          subtitle: profileSubtitle,
          avatarImage: avatarImage
        )
      }

      ForEach(SettingsCategory.availableCategories) { category in
        NavigationLink(value: category) {
          Label {
            Text(category.titleKey)
          } icon: {
            SettingsIconView(systemImage: category.systemImage, color: category.iconColor)
          }
        }
      }

      Section {
        NavigationLink {
          AboutView()
        } label: {
          Label {
            Text("About")
          } icon: {
            SettingsIconView(systemImage: "info.circle.fill", color: .gray)
          }
        }
      }
    }
    .navigationDestination(for: SettingsCategory.self) { category in
      pane(for: category)
        .navigationTitle(category.titleKey)
        .navigationBarTitleDisplayMode(.inline)
#if DEBUG
        .navigationDestination(for: SettingsDetailRoute.self) { route in
          switch route {
          case .streamSurvey:
            StreamSurveyView()
          case .uiLab(let chrome):
            UILabRoot(initialChrome: chrome)
          case .typeStyles:
            SystemTypeStylesCatalogView()
          }
        }
#endif
    }
    .platformNavigationTitle("Settings")
    .task {
      model.fetch()
      await loadAvatar()
    }
    .alert("Are you sure?", isPresented: $showLogoutAlert) {
      Button("Logout", role: .destructive) { model.logout() }
      Button("Cancel", role: .cancel) { }
    }
    .alert(isPresented: $model.shouldShowExitAlert) {
      Alert(
        title: Text("Restarting the app"),
        message: Text("The app will restart to apply the language change."),
        primaryButton: .default(Text("OK")) { exit(0) },
        secondaryButton: .cancel()
      )
    }
  }
#endif

  private var profileName: String {
    let name = model.userData.profile.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !name.isEmpty { return name }
    let username = model.userData.username.trimmingCharacters(in: .whitespacesAndNewlines)
    return username.isEmpty ? "KinoPub" : username
  }

  private var profileSubtitle: String {
    let days = model.userData.subscription.days
    return "\(days) \("days".localized)"
  }

  @ViewBuilder
  private func pane(for category: SettingsCategory) -> some View {
    switch category {
    case .general:
      GeneralSettingsPane(model: model, showLogoutAlert: $showLogoutAlert)
    case .playback:
      PlaybackSettingsPane()
    case .integrations:
      IntegrationsSettingsPane(keyProvider: appContext.kinopoiskKeyProvider)
    case .downloads:
      DownloadsSettingsPane()
    case .devices:
      DevicesSettingsPane()
    case .appearance:
      AppearanceSettingsPane()
    case .sidebar:
      SidebarSettingsPane()
    case .notifications:
      NotificationsSettingsPane()
    case .details:
      DetailsSettingsPane()
    case .backups:
      BackupsSettingsPane()
    case .network:
      NetworkSettingsPane()
    case .advanced:
      AdvancedSettingsPane()
    }
  }

  private func loadAvatar() async {
    if let cached = UserProfileCache.shared.loadAvatar(),
       let image = Self.platformImage(from: cached) {
      avatarImage = image
    }
    let urlString = model.userData.profile.avatar
    guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else { return }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      if let image = Self.platformImage(from: data) {
        avatarImage = image
        UserProfileCache.shared.saveAvatar(data)
      }
    } catch {
      // Keep cached avatar if the network fetch fails.
    }
  }

  private static func platformImage(from data: Data) -> Image? {
#if canImport(UIKit)
    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
#elseif canImport(AppKit)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
#endif
  }
}
#endif
