//
//  DevicesSettingsPane.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend
#if canImport(UIKit)
import UIKit
#endif

#if !os(tvOS)

@MainActor
final class DeviceSettingsPaneModel: ObservableObject {
  @Published var settings = DeviceSettings()
  @Published private(set) var isLoading = false
  @Published private(set) var isSaving = false
  @Published private(set) var deviceTitle = ""
  /// Flips true briefly after a successful save to swap the footer to a confirmation.
  @Published private(set) var didSave = false

  private var deviceId: Int?

  func load(deviceService: DeviceService, errorHandler: ErrorHandler) async {
    isLoading = true
    defer { isLoading = false }
    do {
      let device = try await deviceService.fetchCurrentDevice()
      deviceId = device.id
      deviceTitle = device.title ?? ""
      settings = try await deviceService.fetchSettings(deviceId: device.id)
    } catch {
      errorHandler.setError(error)
    }
  }

  func save(deviceService: DeviceService, errorHandler: ErrorHandler) async {
    guard let deviceId else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      try await deviceService.updateSettings(deviceId: deviceId, settings: settings)
      // Optimistic — do not re-fetch. The server can be briefly eventually-consistent,
      // and re-reading right after a save made toggles appear to snap back.
      confirmSaved()
    } catch {
      errorHandler.setError(error)
    }
  }

  private func confirmSaved() {
#if os(iOS)
    UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    didSave = true
    Task {
      try? await Task.sleep(nanoseconds: 1_800_000_000)
      didSave = false
    }
  }
}

struct DevicesSettingsPane: View {
  @Environment(\.appContext) private var appContext
  @Environment(ErrorHandler.self) private var errorHandler
  @StateObject private var model = DeviceSettingsPaneModel()

  var body: some View {
    Form {
      if model.isLoading && model.settings.streamingTypeOptions.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else {
        if !model.deviceTitle.isEmpty {
          Section {
            LabeledContent("This device", value: model.deviceTitle)
          }
        }

        Section {
          Picker("Stream type", selection: $model.settings.streamingType) {
            ForEach(model.settings.streamingTypeOptions) { option in
              Text(option.label).tag(option.id)
            }
          }
          Picker("Server location", selection: $model.settings.serverLocation) {
            ForEach(model.settings.serverLocationOptions) { option in
              Text(option.label).tag(option.id)
            }
          }
        }

        Section {
          Toggle("4K", isOn: $model.settings.support4k)
          Toggle("HEVC", isOn: $model.settings.supportHevc)
          Toggle("HDR", isOn: $model.settings.supportHdr)
          Toggle("Mixed playlists", isOn: $model.settings.mixedPlaylist)
        } footer: {
          Text("Mixed playlists keep an H.264 fallback alongside HEVC, so an HDR title can't arrive as an HEVC-only stream the player can't open.")
        }

        Section {
          Button {
            Task { await model.save(deviceService: appContext.deviceService, errorHandler: errorHandler) }
          } label: {
            if model.isSaving {
              ProgressView()
            } else {
              Text("Save")
            }
          }
          .disabled(model.isSaving)
        } footer: {
          Text(model.didSave ? "Saved. Changes take effect within a minute." : "Changes take effect within a minute.")
        }

        Section {
          NavigationLink("Manage devices", value: SettingsDetailRoute.devicesList)
        }
      }
    }
    .formStyle(.grouped)
    .task { await model.load(deviceService: appContext.deviceService, errorHandler: errorHandler) }
  }
}

#Preview {
  DevicesSettingsPane()
    .environment(ErrorHandler())
}

#endif
