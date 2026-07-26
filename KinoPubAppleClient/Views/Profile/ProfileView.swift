//
//  SettingsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubBackend
import KinoPubKit

struct ProfileView: View {

  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: ProfileModel
  @AppStorage("selectedLanguage") private var selectedLanguage: String = (Locale.current.language.languageCode?.identifier ?? "en")
  @AppStorage(SubtitlePreferences.preferEnglishKey) private var preferEnglishSubtitles: Bool = true
  @AppStorage(SubtitlePreferences.preferNonCCKey) private var preferNonCCSubtitles: Bool = true
  @AppStorage(SubtitlePreferences.dualSubtitlesKey) private var dualSubtitlesEnabled: Bool = false
  @AppStorage(SubtitlePreferences.secondSubtitleLanguageKey) private var secondSubtitleLanguage: String = "ru"

  @State private var showLogoutAlert: Bool = false

  init(model: @autoclosure @escaping () -> ProfileModel) {
    _model = StateObject(wrappedValue: model())
  }

  var body: some View {
#if os(tvOS)
    TVProfileSettingsView(
      model: model,
      selectedLanguage: $selectedLanguage,
      preferEnglishSubtitles: $preferEnglishSubtitles,
      preferNonCCSubtitles: $preferNonCCSubtitles,
      dualSubtitlesEnabled: $dualSubtitlesEnabled,
      secondSubtitleLanguage: $secondSubtitleLanguage,
      onLogout: { showLogoutAlert = true },
      onLanguageChange: { model.changeLanguage(to: $0) }
    )
    .background(Color.KinoPub.background.ignoresSafeArea())
    .onAppear { model.fetch() }
    .alert("Are you sure?", isPresented: $showLogoutAlert) {
      Button("Logout", role: .destructive) { model.logout() }
      Button("Cancel", role: .cancel) { }
    }
    .alert(isPresented: $model.shouldShowExitAlert) {
      Alert(
        title: Text("Restarting the app"),
        message: Text("The app will restart to apply the language change."),
        primaryButton: .default(Text("OK")) {
          exit(0)
        },
        secondaryButton: .cancel()
      )
    }
#else
    NavigationStack {
      ZStack {
        Color.KinoPub.background.edgesIgnoringSafeArea(.all)
        VStack(alignment: .leading) {
          Form {
            Section {
              LabeledContent("User Name", value: model.userData.username)
              LabeledContent("User Subscription", value: "\(model.userData.subscription.days) \("days".localized)")
              LabeledContent("Registration Date", value: "\(model.userData.registrationDateFormatted)")
              LabeledContent("App version", value: Bundle.main.appVersionLong)
            }

            languageSection
            playbackSection

            Section(header: Text("Data sources")) {
              DataSourcesAttributionView()
            }

#if DEBUG
            Section(header: Text("Diagnostics")) {
              NavigationLink("Stream survey") {
                StreamSurveyView()
              }
            }
#endif

            Section {
              Button(action: {
                showLogoutAlert = true
              }, label: {
                Text("Logout").foregroundStyle(Color.red)
              })
#if os(macOS)
              .buttonStyle(PlainButtonStyle())
#endif
            }
          }
          .scrollContentBackground(.hidden)
          .background(Color.KinoPub.background)
        }
      }
      .platformNavigationTitle("Settings")
      .onAppear(perform: {
        model.fetch()
      })
      .alert("Are you sure?", isPresented: $showLogoutAlert) {
        Button("Logout", role: .destructive) { model.logout() }
        Button("Cancel", role: .cancel) { }
      }
      .alert(isPresented: $model.shouldShowExitAlert) {
        Alert(
          title: Text("Restarting the app"),
          message: Text("The app will restart to apply the language change."),
          primaryButton: .default(Text("OK")) {
            exit(0)
          },
          secondaryButton: .cancel()
        )
      }
    }
    .navigationStackActive(for: .settings, selected: navigationState.selectedTab)
#endif
  }

#if !os(tvOS)
  private var languageSection: some View {
    Section(header: Text("Language")) {
      Picker("Select Language", selection: $selectedLanguage) {
        ForEach(model.availableLanguages.keys.sorted(), id: \.self) { key in
          Text(model.availableLanguages[key] ?? key).tag(key)
        }
      }
      .pickerStyle(MenuPickerStyle())
      .onChange(of: selectedLanguage) { newLanguage in
        model.changeLanguage(to: newLanguage)
      }
    }
  }

  private var playbackSection: some View {
    Section(header: Text("Playback"),
            footer: Text("A track picked in the player wins over these, and is remembered for the next episode.")) {
      Toggle("Default English subtitles", isOn: $preferEnglishSubtitles)
      Toggle("Prefer non-CC / non-SDH", isOn: $preferNonCCSubtitles)
        .disabled(!preferEnglishSubtitles)
      Toggle("Dual subtitles", isOn: $dualSubtitlesEnabled)
      Picker("Second subtitle language", selection: $secondSubtitleLanguage) {
        ForEach(SubtitlePreferences.secondLanguageOptions, id: \.self) { code in
          Text(LanguageNames.name(for: code)).tag(code)
        }
      }
      .pickerStyle(MenuPickerStyle())
      .disabled(!dualSubtitlesEnabled)
    }
  }
#endif
}

struct ProfileView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileView(model: ProfileModel(userService: UserServiceMock(),
                                    errorHandler: ErrorHandler(),
                                    authState: AuthState(authService: AuthorizationServiceMock(),
                                                         accessTokenService: AccessTokenServiceMock())))
  }
}
