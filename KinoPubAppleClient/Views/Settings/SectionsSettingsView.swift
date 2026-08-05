//
//  SectionsSettingsView.swift
//  KinoPubAppleClient
//

import SwiftUI

#if !os(tvOS)

/// Toggle screen for `SectionVisibilityStore`. Persists immediately; does not yet change
/// what `TabsNavigationView` shows — see the store's doc comment.
struct SectionsSettingsView: View {
  @ObservedObject private var store = SectionVisibilityStore.shared

  var body: some View {
    Form {
      Section {
        ForEach(SectionVisibilityStore.librarySections) { section in
          Toggle(section.titleKey, isOn: binding(for: section))
            .disabled(!store.canHide(section))
        }
      } header: {
        Text("Library")
      } footer: {
        Text("Movies and Series always stay visible.")
      }

      if !SectionVisibilityStore.otherSections.isEmpty {
        Section("Other") {
          ForEach(SectionVisibilityStore.otherSections) { section in
            Toggle(section.titleKey, isOn: binding(for: section))
          }
        }
      }
    }
    .formStyle(.grouped)
    .platformNavigationTitle("Sections")
    .safeAreaInset(edge: .bottom) {
      Text("Hiding a section here doesn't change the tab bar or sidebar yet — that lands with the upcoming catalog sections update.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding()
    }
  }

  private func binding(for section: AppSection) -> Binding<Bool> {
    Binding(
      get: { store.isVisible(section) },
      set: { store.setVisible($0, for: section) }
    )
  }
}

#Preview {
  NavigationStack {
    SectionsSettingsView()
  }
}

#endif
