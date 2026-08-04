//
//  AboutView.swift
//  KinoPubAppleClient
//

import SwiftUI

struct AboutView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "play.rectangle.fill")
        .font(.system(size: 56))
        .foregroundStyle(.secondary)

      Text(Bundle.main.displayName)
        .font(.title.weight(.semibold))

      Text(Bundle.main.appVersionLong)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)

      Divider()
        .frame(maxWidth: 280)

      DataSourcesAttributionView()
        .frame(maxWidth: 320, alignment: .leading)
    }
    .padding(28)
#if os(macOS)
    .frame(width: 380)
#endif
    .platformNavigationTitle("About")
  }
}

private extension Bundle {
  var displayName: String {
    object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "KinoPub"
  }
}
