//
//  Bundle+Data.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 10.08.2023.
//

import Foundation

extension Bundle {
  public var appBuild: String          { getInfo("CFBundleVersion") }
  public var appVersionLong: String    { getInfo("CFBundleShortVersionString") }
  fileprivate func getInfo(_ str: String) -> String { infoDictionary?[str] as? String ?? "⚠️" }
}
