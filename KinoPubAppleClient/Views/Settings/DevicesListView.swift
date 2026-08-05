//
//  DevicesListView.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubBackend
import KinoPubUI

#if !os(tvOS)

@MainActor
final class DevicesListModel: ObservableObject {
  @Published private(set) var devices: [ManagedDevice] = []
  @Published private(set) var currentDeviceId: Int?
  @Published private(set) var isLoading = false

  func load(deviceService: DeviceService, errorHandler: ErrorHandler) async {
    isLoading = true
    defer { isLoading = false }
    do {
      async let current = deviceService.fetchCurrentDevice()
      async let list = deviceService.listDevices()
      currentDeviceId = try await current.id
      devices = try await list
    } catch {
      errorHandler.setError(error)
    }
  }

  func remove(_ device: ManagedDevice, deviceService: DeviceService, errorHandler: ErrorHandler) async {
    do {
      try await deviceService.removeDevice(id: device.id)
      devices.removeAll { $0.id == device.id }
    } catch {
      errorHandler.setError(error)
    }
  }
}

/// Account device list — current device marked, others removable. Service side of
/// `DeviceService.listDevices()` / `removeDevice(id:)` predates this screen.
struct DevicesListView: View {
  @Environment(\.appContext) private var appContext
  @Environment(ErrorHandler.self) private var errorHandler
  @StateObject private var model = DevicesListModel()
  @State private var pendingRemoval: ManagedDevice?

  var body: some View {
    List {
      ForEach(model.devices) { device in
        row(for: device)
      }
    }
#if os(iOS)
    .listStyle(.insetGrouped)
#endif
    .overlay {
      if model.isLoading && model.devices.isEmpty {
        ProgressView()
      } else if !model.isLoading && model.devices.isEmpty {
        ContentUnavailableView("No devices", systemImage: "laptopcomputer.and.iphone")
      }
    }
    .platformNavigationTitle("Devices")
    .task { await model.load(deviceService: appContext.deviceService, errorHandler: errorHandler) }
    .refreshable { await model.load(deviceService: appContext.deviceService, errorHandler: errorHandler) }
    .confirmationDialog(
      "Remove this device?",
      isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
      presenting: pendingRemoval
    ) { device in
      Button("Remove", role: .destructive) {
        Task {
          await model.remove(device, deviceService: appContext.deviceService, errorHandler: errorHandler)
          pendingRemoval = nil
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: { device in
      Text("\(device.title ?? "Unknown device") will be signed out and can't stream until it's activated again.")
    }
  }

  @ViewBuilder
  private func row(for device: ManagedDevice) -> some View {
    let isCurrent = device.id == model.currentDeviceId
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(device.title ?? "Unknown device")
        if let software = device.software, !software.isEmpty {
          Text(software)
            .font(.caption)
            .foregroundStyle(Color.KinoPub.subtitle)
        }
      }
      Spacer()
      if isCurrent {
        Text("This Device")
          .font(.caption)
          .foregroundStyle(Color.KinoPub.subtitle)
      } else {
        Button(role: .destructive) {
          pendingRemoval = device
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
      }
    }
  }
}

#Preview {
  NavigationStack {
    DevicesListView()
      .environment(ErrorHandler())
  }
}

#endif
