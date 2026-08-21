//
//  SettingsModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 9.08.2023.
//

import Foundation
import KinoPubBackend
import KinoPubLogging
import OSLog

@MainActor
@Observable
class ProfileModel {

    private var userService: UserService
    private var errorHandler: ErrorHandler
    private var authState: AuthState

    public var userData: UserData = UserData.mock()
    var selectedLanguage: String
    var shouldShowExitAlert: Bool = false
    
    // LT is not shipping yet — no translations exist for it, so offering it here would
    // just fall back to English everywhere.
    let availableLanguages = ["en": "English", "ru": "Русский"]
    
    init(userService: UserService,
         errorHandler: ErrorHandler,
         authState: AuthState) {
        self.userService = userService
        self.errorHandler = errorHandler
        self.authState = authState
        self.selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? (Locale.current.language.languageCode?.identifier ?? "en")
    }
    func fetch() {
        Task {
            do {
                self.userData = try await userService.fetchUserData()
            } catch {
                errorHandler.setError(error)
            }
        }
    }
    
    func logout() {
        authState.logout()
    }
    
    func changeLanguage(to language: String) {
        UserDefaults.standard.setValue([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        shouldShowExitAlert = true
    }
}
