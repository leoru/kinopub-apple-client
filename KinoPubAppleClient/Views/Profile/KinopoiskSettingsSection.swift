//
//  KinopoiskSettingsSection.swift
//  KinoPubAppleClient
//

import SwiftUI

/// iOS/macOS Settings row for entering a Kinopoisk Unofficial API key. tvOS has
/// its own destination (`TVKinopoiskKeyView`) — no `TextField`/`SecureField`
/// precedent existed anywhere in this app before this, so tvOS text entry is
/// new territory there, not something to squeeze into this shared view.
struct KinopoiskSettingsSection: View {
  @StateObject private var model: KinopoiskKeySettingsModel

  init(keyProvider: KinopoiskKeyProvider) {
    _model = StateObject(wrappedValue: KinopoiskKeySettingsModel(keyProvider: keyProvider))
  }

  var body: some View {
    Section(header: Text("Kinopoisk"), footer: Text(model.statusText).fixedSize(horizontal: false, vertical: true)) {
      SecureField("API key", text: $model.keyText)
#if !os(tvOS)
        .textContentType(.password)
        .autocorrectionDisabled()
#endif
      Button {
        Task { await model.validate() }
      } label: {
        HStack {
          Text("Validate")
          if model.validationState == .checking {
            Spacer()
            ProgressView()
          }
        }
      }
      .disabled(!model.isValidateEnabled)
#if os(macOS)
      .buttonStyle(PlainButtonStyle())
#endif
    }
  }
}
