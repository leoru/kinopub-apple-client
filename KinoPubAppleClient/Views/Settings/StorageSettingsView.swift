//
//  StorageSettingsView.swift
//  KinoPubAppleClient
//
//  Reports what's actually introspectable on disk today. There is no unified image
//  cache yet (a feature-01 item), so this deliberately does not invent a number for
//  one — only sources that are real get a row.
//

import SwiftUI
import Foundation
import KinoPubKit

#if !os(tvOS)

@MainActor
final class StorageSettingsModel: ObservableObject {
  @Published private(set) var rowSnapshotBytes: Int64 = 0
  @Published private(set) var hlsTempBytes: Int64 = 0
  @Published private(set) var urlCacheDiskBytes: Int = 0
  @Published private(set) var urlCacheMemoryBytes: Int = 0
  @Published private(set) var downloadsCount = 0
  @Published private(set) var downloadsBytes: Int64 = 0

  private let rowSnapshotStore = RowSnapshotStore()

  func refresh(appContext: AppContextProtocol) {
    rowSnapshotBytes = rowSnapshotStore.diskUsage
    hlsTempBytes = HLSAudioLabeler.legacyTemporaryDirectorySize
    urlCacheDiskBytes = URLCache.shared.currentDiskUsage
    urlCacheMemoryBytes = URLCache.shared.currentMemoryUsage

    if FeatureFlags.downloadsEnabled {
      let files = appContext.downloadedFilesDatabase.readData() ?? []
      downloadsCount = files.count
      downloadsBytes = files.reduce(into: 0) { total, file in
        let size = try? file.localFileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        total += Int64(size ?? 0)
      }
    }
  }

  func clearRowSnapshots() {
    rowSnapshotStore.clear()
    rowSnapshotBytes = 0
  }

  func clearHLSTemp() {
    HLSAudioLabeler.removeLegacyTemporaryFiles()
    hlsTempBytes = 0
  }

  func clearURLCache() {
    URLCache.shared.removeAllCachedResponses()
    urlCacheDiskBytes = 0
    urlCacheMemoryBytes = 0
  }
}

struct StorageSettingsView: View {
  @Environment(\.appContext) private var appContext
  @StateObject private var model = StorageSettingsModel()
  @State private var pendingClear: ClearTarget?

  private enum ClearTarget: Identifiable, Hashable {
    case rowSnapshots
    case hlsTemp
    case urlCache

    var id: Self { self }

    var title: LocalizedStringKey {
      switch self {
      case .rowSnapshots: return "Clear row cache?"
      case .hlsTemp: return "Clear HLS temp files?"
      case .urlCache: return "Clear network cache?"
      }
    }
  }

  var body: some View {
    Form {
      Section {
        LabeledContent("Home & Library snapshots", value: formatted(model.rowSnapshotBytes))
        Button("Clear") { pendingClear = .rowSnapshots }
          .disabled(model.rowSnapshotBytes == 0)
      } header: {
        Text("Row cache")
      } footer: {
        Text("Cached rows paint Home and Library instantly on a cold start. Clearing forces the next launch to refetch from the network.")
      }

      Section {
        LabeledContent("HLS temp files", value: formatted(model.hlsTempBytes))
        Button("Clear") { pendingClear = .hlsTemp }
          .disabled(model.hlsTempBytes == 0)
      } header: {
        Text("Playback")
      } footer: {
        Text("Scratch files from relabeling audio tracks in older builds. These are already swept on every launch.")
      }

      Section {
        LabeledContent("Disk", value: formatted(Int64(model.urlCacheDiskBytes)))
        LabeledContent("Memory", value: formatted(Int64(model.urlCacheMemoryBytes)))
        Button("Clear") { pendingClear = .urlCache }
          .disabled(model.urlCacheDiskBytes == 0 && model.urlCacheMemoryBytes == 0)
      } header: {
        Text("Network cache")
      } footer: {
        Text("Artwork and API responses cached by the system. Clearing just means the next loads re-download.")
      }

      if FeatureFlags.downloadsEnabled {
        Section {
          LabeledContent("Downloaded files", value: "\(model.downloadsCount)")
          LabeledContent("Downloads size", value: formatted(model.downloadsBytes))
        } header: {
          Text("Downloads")
        } footer: {
          Text("Manage individual downloads from the Downloads tab — remove titles you're done with from there.")
        }
      }
    }
    .formStyle(.grouped)
    .platformNavigationTitle("Storage")
    .task { model.refresh(appContext: appContext) }
    .confirmationDialog(
      pendingClear?.title ?? "",
      isPresented: Binding(get: { pendingClear != nil }, set: { if !$0 { pendingClear = nil } }),
      presenting: pendingClear
    ) { target in
      Button("Clear", role: .destructive) {
        switch target {
        case .rowSnapshots: model.clearRowSnapshots()
        case .hlsTemp: model.clearHLSTemp()
        case .urlCache: model.clearURLCache()
        }
        pendingClear = nil
      }
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("This only affects local caches — nothing on your account changes.")
    }
  }

  private func formatted(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}

#Preview {
  NavigationStack {
    StorageSettingsView()
  }
}

#endif
