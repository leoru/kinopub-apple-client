//
//  BundleConfiguration.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

final class BundleConfiguration: Configuration {

  var clientID: String {
    requiredValue(for: "ClientID")
  }

  var clientSecret: String {
    requiredValue(for: "ClientSecret")
  }

  var baseURL: String {
    requiredValue(for: "BaseURL")
  }

  var tmdbProxyBaseURL: String? {
    optionalValue(for: "TMDBProxyBaseURL")
  }

  private func requiredValue(for key: String) -> String {
    Bundle.main.object(forInfoDictionaryKey: key) as! String
  }

  private func optionalValue(for key: String) -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
