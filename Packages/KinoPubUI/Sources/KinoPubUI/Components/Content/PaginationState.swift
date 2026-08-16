//
//  PaginationState.swift
//  KinoPubUI
//
//  What a paginated surface is doing right now, and the one component that says so.
//
//  Paging used to be silent: a grid or a rail simply stopped, and nothing on screen
//  told you whether more was on its way, whether a request had failed, or whether you
//  had reached the end. All three look identical when the answer is "nothing happens".
//
//  One state, three renderings — a full-width footer under a grid, a card-shaped tile
//  at the end of a rail, and a compact badge beside a section header. They are one
//  semantic component configured for three containers, not three components.
//

import SwiftUI

public struct PaginationState: Equatable, Sendable {
  public enum Phase: Equatable, Sendable {
    /// Nothing to say: not paginated, or sitting mid-list with more available.
    case idle
    case loading
    /// A page failed. The surface offers a retry where it can host one.
    case failed
    /// Everything there is has been loaded — the only phase that shows a count.
    case complete
  }

  public var phase: Phase
  /// Items actually loaded. Not derived from `Pagination`, which counts *pages* and
  /// has no item total, so anything else here would be a guess presented as a fact.
  public var loadedCount: Int

  public init(phase: Phase = .idle, loadedCount: Int = 0) {
    self.phase = phase
    self.loadedCount = loadedCount
  }

  public static let idle = PaginationState()

  /// Nothing is drawn for `.idle`, and `.complete` is worth drawing only once a list
  /// is long enough that "is that everything?" is a real question.
  public var isWorthShowing: Bool {
    switch phase {
    case .idle: return false
    case .loading, .failed: return true
    case .complete: return loadedCount >= Self.countWorthStating
    }
  }

  /// Below this, the end of the list is self-evident from the list itself.
  static let countWorthStating = 20

  /// `String.localized` is an app-target extension, so the package resolves against
  /// `Bundle.main` directly — the same catalogue, reached the long way.
  var completionText: String {
    String(format: NSLocalizedString("Pagination_AllLoaded", comment: "End of a paginated list"),
           loadedCount)
  }
}

// MARK: - Footer, under a vertical grid

public struct PaginationFooter: View {
  private let state: PaginationState
  private let onRetry: (() -> Void)?

  public init(state: PaginationState, onRetry: (() -> Void)? = nil) {
    self.state = state
    self.onRetry = onRetry
  }

  @ViewBuilder
  public var body: some View {
    if state.isWorthShowing {
      content
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .transition(.opacity)
    }
  }

  @ViewBuilder
  private var content: some View {
    Group {
      switch state.phase {
      case .idle:
        EmptyView()
      case .loading:
        ProgressView()
          .controlSize(.regular)
      case .failed:
        VStack(spacing: 12) {
          Text("Pagination_Failed")
            .font(TypeScale.cardSubtitle)
            .foregroundStyle(Color.KinoPub.subtitle)
          if let onRetry {
            Button("Try Again", action: onRetry)
#if !os(tvOS)
              .buttonStyle(.glass)
              .controlSize(.large)
#endif
          }
        }
      case .complete:
        Text(state.completionText)
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
      }
    }
    .animation(.easeOut(duration: 0.2), value: state)
  }
}

// MARK: - Tile, at the end of a horizontal rail

/// Sized to the rail's card so the row's rhythm holds — a half-height spinner at the
/// end of a shelf reads as a broken card, not as a status.
public struct PaginationTailTile: View {
  private let state: PaginationState
  private let onRetry: (() -> Void)?

  public init(state: PaginationState, onRetry: (() -> Void)? = nil) {
    self.state = state
    self.onRetry = onRetry
  }

  public var body: some View {
    VStack(spacing: 10) {
      switch state.phase {
      case .idle:
        EmptyView()
      case .loading:
        ProgressView()
      case .failed:
        Image(systemName: "arrow.clockwise")
          .font(.title3)
          .foregroundStyle(Color.KinoPub.subtitle)
        Text("Pagination_Failed_Short")
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
          .multilineTextAlignment(.center)
      case .complete:
        Text("\(state.loadedCount)")
          .font(TypeScale.cardTitle)
          .foregroundStyle(Color.KinoPub.text)
        Text("Pagination_AllLoaded_Short")
          .font(TypeScale.cardMeta)
          .foregroundStyle(Color.KinoPub.subtitle)
          .multilineTextAlignment(.center)
      }
    }
    .padding(8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.KinoPub.selectionBackground.opacity(0.35),
                in: RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous))
  }

  /// Only the failed tile does anything when pressed, so only it becomes a button.
  @ViewBuilder
  public func wrapped() -> some View {
    if state.phase == .failed, let onRetry {
      Button(action: onRetry) { body }
#if os(tvOS)
        .buttonStyle(.card)
#else
        .buttonStyle(MediaCardButtonStyle())
#endif
    } else {
      body
    }
  }
}

// MARK: - Badge, beside a section header

/// For containers that cannot host a tile — the TVUIKit rails own their own cells, so
/// a shelf on tvOS reports its paging state next to the row title instead.
public struct PaginationHeaderBadge: View {
  private let state: PaginationState

  public init(state: PaginationState) {
    self.state = state
  }

  public var body: some View {
    switch state.phase {
    case .idle, .complete:
      EmptyView()
    case .loading:
      ProgressView()
        .controlSize(.small)
    case .failed:
      Image(systemName: "exclamationmark.triangle")
        .font(.caption)
        .foregroundStyle(Color.KinoPub.subtitle)
    }
  }
}
