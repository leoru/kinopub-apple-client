//
//  NavigationFocusLabView.swift
//  KinoPubAppleClient
//
//  DEBUG-only, tvOS-only. Four shells of the same two-tab app, each isolating exactly
//  one variable behind the two open tvOS bugs: the tab bar that flickers and does not
//  come back after Menu, and focus stranding when several collections sit on one page.
//
//  Run each variant, do the same four things — scroll down, Select into the detail page,
//  Menu back, then Up to the bar — and read the HUD. It reports what the system thinks
//  (`isTabBarHidden`, which scroll view `contentScrollViewForEdge(.top)` resolved to,
//  stack depth), not what the screen looks like, because those two disagreeing *is* the
//  bug. See docs/archive/plans/detail-page-choreography.md § "Bugs found, deliberately NOT
//  fixed" and .claude/skills/apple-chrome/SKILL.md.
//
//  Each variant runs in a `fullScreenCover` on purpose: nested inside the real Settings
//  tab it would find the *app's* tab bar controller in its ancestor chain and measure
//  that instead of its own.
//
//  Reached from Settings → Diagnostics → "Navigation / Focus Lab".
//

#if os(tvOS) && DEBUG
import SwiftUI
import KinoPubUI

enum NavLabVariant: String, CaseIterable, Identifiable {
  /// What ships today: a stack per tab, and a page made of one vertical SwiftUI
  /// `ScrollView` with a horizontal `ScrollView` per rail — so the tab bar's heuristic
  /// has one vertical and five horizontal candidates to choose between.
  case swiftUIRails
  /// Same page, but one `NavigationStack` **outside** the `TabView` with a single
  /// destination registry (the silo-apple shape our own 2026-07 research pointed at).
  /// Isolates: does the bar survive a pop better when the stack is not per-tab?
  case singleStackOutside
  /// Same per-tab stacks, but the page is **one** `UICollectionView` with the rails as
  /// compositional sections. Isolates: does one scroll view instead of six change the
  /// bar — and does cross-rail focus stop stranding when rails stop being siblings?
  case oneCollection
  /// The previous one plus `setContentScrollView(_:for: .top)`. Isolates the single
  /// variable the header calls out: heuristic versus told.
  case oneCollectionHandover

  var id: String { rawValue }

  var title: String {
    switch self {
    case .swiftUIRails: "A · Как сейчас: стек на таб, рельсы на SwiftUI"
    case .singleStackOutside: "B · Один NavigationStack снаружи TabView"
    case .oneCollection: "C · Одна коллекция, рельсы — секции"
    case .oneCollectionHandover: "D · C + явный setContentScrollView"
    }
  }

  var note: String {
    switch self {
    case .swiftUIRails:
      "Базовая линия. Шесть скролл-вью на странице, ни одного не отдано системе — эвристика UIKit выбирает сама."
    case .singleStackOutside:
      "Контент тот же. Меняется только владелец стека: один снаружи, один реестр destination'ов."
    case .oneCollection:
      "Одно скролл-вью на всю страницу вместо шести, рельсы — секции orthogonalLayoutSectionForMediaItems."
    case .oneCollectionHandover:
      "То же самое, но контроллер прямо говорит бару, за чем следить."
    }
  }

  var usesCollection: Bool {
    self == .oneCollection || self == .oneCollectionHandover
  }

  var handsOverScrollView: Bool {
    self == .oneCollectionHandover
  }
}

/// Launcher pushed from Settings. Each row opens its variant full-screen.
struct NavigationFocusLabView: View {
  @State private var running: NavLabVariant?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        header
        ForEach(NavLabVariant.allCases) { variant in
          Button {
            running = variant
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              Text(variant.title)
                .font(.headline)
              Text(variant.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
          }
          .buttonStyle(.card)
        }
      }
      .padding(60)
    }
    .background(Color.KinoPub.background)
    .fullScreenCover(item: $running) { variant in
      NavLabRunner(variant: variant)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Navigation / Focus Lab")
        .font(.largeTitle)
      Text("В каждом варианте: проскроллить вниз, Select в деталь, Menu назад, Up в бар. "
           + "Смотреть на HUD справа — расходится ли то, что видно, с тем, что система думает.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Runner

private struct NavLabRunner: View {
  let variant: NavLabVariant

  @StateObject private var probe = NavLabProbe()
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .topTrailing) {
      shell
      NavLabAnchor(probe: probe)
        .frame(width: 1, height: 1)
        .allowsHitTesting(false)
      hud
    }
    .background(Color.KinoPub.background)
    .onExitCommand { dismiss() }
    .task {
      // Polling, deliberately: the values we are after are UIKit state with no
      // publisher, and this is a DEBUG page where a twice-a-second read costs nothing.
      while !Task.isCancelled {
        probe.sample()
        try? await Task.sleep(for: .milliseconds(500))
      }
    }
  }

  @ViewBuilder
  private var shell: some View {
    switch variant {
    case .singleStackOutside:
      NavLabSingleStackShell(variant: variant, probe: probe)
    default:
      NavLabPerTabShell(variant: variant, probe: probe)
    }
  }

  private var hud: some View {
    let reading = probe.reading
    return VStack(alignment: .leading, spacing: 6) {
      Text(variant.title)
        .font(.caption)
        .foregroundStyle(.secondary)
      row("isTabBarHidden", reading.tabBarHidden.map(String.init) ?? "—")
      row("observed scroll", reading.observedScrollView ?? "— (nil: эвристика ничего не нашла)")
      row("handed over", reading.explicitScrollView ?? "—")
      row("stack depth", reading.stackDepth.map(String.init) ?? "—")
      row("tab bar", reading.tabBarClass ?? "—")
    }
    .padding(20)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .padding(40)
    .allowsHitTesting(false)
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(width: 200, alignment: .leading)
      Text(value)
        .font(.caption2.monospaced())
    }
  }
}

// MARK: - Shells

/// A stack per tab — the shape the app ships.
private struct NavLabPerTabShell: View {
  let variant: NavLabVariant
  let probe: NavLabProbe

  @State private var tab = 0
  @State private var firstPath: [NavLabItem] = []
  @State private var secondPath: [NavLabItem] = []

  var body: some View {
    TabView(selection: $tab) {
      Tab(value: 0) {
        NavigationStack(path: $firstPath) {
          NavLabPage(variant: variant, probe: probe) { firstPath.append($0) }
            .navigationDestination(for: NavLabItem.self) { NavLabDetail(item: $0) }
        }
      } label: {
        Text("First")
      }

      Tab(value: 1) {
        NavigationStack(path: $secondPath) {
          NavLabPage(variant: variant, probe: probe) { secondPath.append($0) }
            .navigationDestination(for: NavLabItem.self) { NavLabDetail(item: $0) }
        }
      } label: {
        Text("Second")
      }
    }
    .tabViewStyle(.tabBarOnly)
  }
}

/// One stack outside the `TabView`, one destination registry for the whole shell.
private struct NavLabSingleStackShell: View {
  let variant: NavLabVariant
  let probe: NavLabProbe

  @State private var tab = 0
  @State private var path: [NavLabItem] = []

  var body: some View {
    NavigationStack(path: $path) {
      TabView(selection: $tab) {
        Tab(value: 0) {
          NavLabPage(variant: variant, probe: probe) { path.append($0) }
        } label: {
          Text("First")
        }

        Tab(value: 1) {
          NavLabPage(variant: variant, probe: probe) { path.append($0) }
        } label: {
          Text("Second")
        }
      }
      .tabViewStyle(.tabBarOnly)
      .navigationDestination(for: NavLabItem.self) { NavLabDetail(item: $0) }
    }
  }
}

// MARK: - Page

private struct NavLabPage: View {
  let variant: NavLabVariant
  let probe: NavLabProbe
  let onSelect: (NavLabItem) -> Void

  var body: some View {
    if variant.usesCollection {
      NavLabSectionedCollection(probe: probe,
                                handsOverScrollView: variant.handsOverScrollView,
                                onSelect: onSelect)
    } else {
      swiftUIRails
    }
  }

  /// Deliberately the same shape as `MediaRowsView`: one vertical `ScrollView` whose
  /// `LazyVStack` holds a horizontal `ScrollView` per rail.
  private var swiftUIRails: some View {
    ScrollView(.vertical) {
      LazyVStack(alignment: .leading, spacing: 48) {
        ForEach(Array(NavLabContent.sections.enumerated()), id: \.offset) { index, items in
          VStack(alignment: .leading, spacing: 12) {
            Text("Rail \(index + 1)")
              .font(.headline)
              .padding(.leading, 60)
            ScrollView(.horizontal, showsIndicators: false) {
              LazyHStack(spacing: 40) {
                ForEach(items) { item in
                  Button {
                    onSelect(item)
                  } label: {
                    NavLabTile(item: item)
                  }
                  .buttonStyle(.card)
                }
              }
              .padding(.horizontal, 60)
              .padding(.vertical, 24)
            }
            .scrollClipDisabled()
            .focusSection()
          }
        }
      }
      .padding(.vertical, 40)
    }
    .scrollClipDisabled()
  }
}

private struct NavLabTile: View {
  let item: NavLabItem

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      Color(hue: item.hue, saturation: 0.45, brightness: 0.55)
      Text(item.title)
        .font(.caption)
        .padding(10)
    }
    .frame(width: 320, height: 180)
  }
}

private struct NavLabDetail: View {
  let item: NavLabItem

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 40) {
        Text(item.title)
          .font(.largeTitle)
        Text("Menu отсюда должен вернуть на страницу — и бар должен оказаться там же, где был.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HStack(spacing: 24) {
          ForEach(0..<3, id: \.self) { index in
            Button("Action \(index + 1)") {}
              .buttonStyle(.card)
          }
        }
        ForEach(0..<3, id: \.self) { index in
          Text("Filler \(index + 1)")
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
        }
      }
      .padding(60)
    }
  }
}
#endif
