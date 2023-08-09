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
  
  @State private var showLogoutAlert: Bool = false
  
  init(model: @autoclosure @escaping () -> ProfileModel) {
    _model = StateObject(wrappedValue: model())
  }
  
  var body: some View {
    NavigationStack {
      VStack {
        Form {
          Section {
            LabeledContent("User Name", value: model.userData.username)
            LabeledContent("User Subscription", value: "\(model.userData.subscription.days) \("days".localized)")
            LabeledContent("Registration Date", value: "\(model.userData.registrationDateFormatted)")
          }
          
          Section {
            Button(action: {
              showLogoutAlert = true
            }, label: {
              Text("Logout").foregroundStyle(Color.red)
            })
          }
        }
        .scrollContentBackground(.hidden)
        .skeleton(enabled: model.userData.skeleton ?? false)
        .background(Color.KinoPub.background)
      }
      .navigationTitle("Profile")
      .background(Color.KinoPub.background)
      .onAppear(perform: {
        model.fetch()
      })
      .alert("Are you sure?", isPresented: $showLogoutAlert) {
        Button("Logout", role: .destructive) { model.logout() }
        Button("Cancel", role: .cancel) { }
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
