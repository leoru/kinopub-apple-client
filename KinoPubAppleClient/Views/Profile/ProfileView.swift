//
//  SettingsView.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 22.07.2023.
//
import SwiftUI
import KinoPubBackend
import KinoPubKit
import SkeletonUI

struct ProfileView: View {
  
  @EnvironmentObject var navigationState: NavigationState
  @EnvironmentObject var errorHandler: ErrorHandler
  @Environment(\.appContext) var appContext
  @StateObject private var model: ProfileModel
  @AppStorage("selectedLanguage") private var selectedLanguage: String = (Locale.current.language.languageCode?.identifier ?? "en")

  @State private var showLogoutAlert: Bool = false
    
  init(model: @autoclosure @escaping () -> ProfileModel) {
    _model = StateObject(wrappedValue: model())
  }
  
  var body: some View {
    NavigationStack {
      ZStack {
        Color.KinoPub.background.edgesIgnoringSafeArea(.all)
        VStack(alignment: .leading) {
          Form {
            Section {
              LabeledContent("User Name", value: model.userData.username)
                .skeleton(enabled: model.userData.skeleton ?? false)
              LabeledContent("User Subscription", value: "\(model.userData.subscription.days) \("days".localized)")
                .skeleton(enabled: model.userData.skeleton ?? false)
              LabeledContent("Registration Date", value: "\(model.userData.registrationDateFormatted)")
                .skeleton(enabled: model.userData.skeleton ?? false)
              LabeledContent("App version", value: Bundle.main.appVersionLong)
            }
              
            languageSection
              
            Section {
              Button(action: {
                showLogoutAlert = true
              }, label: {
                Text("Logout").foregroundStyle(Color.red)
              })
              .skeleton(enabled: model.userData.skeleton ?? false)
#if os(macOS)
              .buttonStyle(PlainButtonStyle())
#endif
            }
          }
          .scrollContentBackground(.hidden)
          .background(Color.KinoPub.background)
        }
      }
      .navigationTitle("Profile")
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
  }
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
}

struct ProfileView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileView(model: ProfileModel(userService: UserServiceMock(),
                                    errorHandler: ErrorHandler(),
                                    authState: AuthState(authService: AuthorizationServiceMock(),
                                                         accessTokenService: AccessTokenServiceMock())))
  }
}
