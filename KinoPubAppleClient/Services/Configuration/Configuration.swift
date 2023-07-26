//
//  Configuration.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

protocol Configuration {
  var clientID: String { get }
  var clientSecret: String { get }
  var baseURL: String { get }
}

protocol ConfigurationProvider {
  var configuration: Configuration { get set }
}
