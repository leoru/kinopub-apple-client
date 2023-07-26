//
//  ConfigurationProvider.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 26.07.2023.
//

import Foundation

protocol ConfigurationProvider {
  var configuration: Configuration { get set }
}
