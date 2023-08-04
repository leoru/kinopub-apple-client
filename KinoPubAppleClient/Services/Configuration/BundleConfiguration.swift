//
//  BundleConfiguration.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

final class BundleConfiguration: Configuration {

  var clientID: String {
    value(for: "ClientID")
  }

  var clientSecret: String {
    value(for: "ClientSecret")
  }

  var baseURL: String {
    value(for: "BaseURL")
  }

  private func value(for key: String) -> String {
    Bundle.main.object(forInfoDictionaryKey: key) as! String
  }
}
