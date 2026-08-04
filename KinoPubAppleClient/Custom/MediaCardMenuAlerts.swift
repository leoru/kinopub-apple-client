//
//  MediaCardMenuAlerts.swift
//  KinoPubAppleClient
//

import SwiftUI

extension View {
  /// Presents the New Folder alert driven by `MediaCardMenuCoordinator`.
  func mediaCardNewFolderAlert(_ menu: MediaCardMenuCoordinator) -> some View {
    alert("New Folder", isPresented: Binding(
      get: { menu.newFolderItemID != nil },
      set: { if !$0 { menu.cancelNewFolder() } }
    )) {
      TextField("Folder name", text: Binding(
        get: { menu.newFolderName },
        set: { menu.newFolderName = $0 }
      ))
      Button("Create") { menu.confirmNewFolder() }
      Button("Cancel", role: .cancel) { menu.cancelNewFolder() }
    }
  }
}
