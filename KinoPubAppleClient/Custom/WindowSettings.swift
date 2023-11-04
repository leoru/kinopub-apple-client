//
//  WindowSettings.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 28.10.2023.
//

import Foundation
import SwiftUI

#if os(macOS)

/// A class that manages the window settings, including the "always on top" feature.
class WindowSettings: ObservableObject {
    @Published var alwaysOnTop = UserDefaults.standard.bool(forKey: "alwaysOnTop") {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            updateWindowLevel()
        }
    }
    
    /// Updates the window level based on the "always on top" setting.
    func updateWindowLevel() {
        if alwaysOnTop {
            NSApp.windows.forEach { window in
                window.level = .floating
            }
        } else {
            NSApp.windows.forEach { window in
                window.level = .normal
            }
        }
    }
}
#endif
