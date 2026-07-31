//
//  NetworkMonitor.swift
//  KinoPubKit
//
//  Observes connectivity via NWPathMonitor and publishes a debounced `isOnline`.
//  DESIGN: offline banner / tab locking chrome TBD — wire as EnvironmentObject only.
//

import Foundation
import Network
import Combine

@MainActor
public final class NetworkMonitor: ObservableObject {

  /// Whether the device currently has a usable network path. Debounced (see below).
  @Published public private(set) var isOnline: Bool = true

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.kinopub.networkmonitor")
  /// A flip is only committed after the new state stays stable for this long, so a brief drop /
  /// reconnect doesn't yank the whole UI in and out of offline mode.
  private let debounce: UInt64 = 800_000_000
  private var pendingFlip: Task<Void, Never>?

  public init() {
    monitor.pathUpdateHandler = { [weak self] path in
      let online = path.status == .satisfied
      Task { @MainActor [weak self] in self?.schedule(online) }
    }
    monitor.start(queue: queue)
  }

  private func schedule(_ online: Bool) {
    guard online != isOnline else {
      pendingFlip?.cancel()
      pendingFlip = nil
      return
    }
    pendingFlip?.cancel()
    pendingFlip = Task { @MainActor [weak self] in
      try? await Task.sleep(nanoseconds: self?.debounce ?? 0)
      guard let self, !Task.isCancelled else { return }
      self.isOnline = online
    }
  }

  deinit {
    monitor.cancel()
  }
}
