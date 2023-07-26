//
//  ResponseLoggingPlugin.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation
import OSLog
import KinoPubLogging

public class ResponseLoggingPlugin: APIClientPlugin {
  
  public init() {}
  
  public func prepare(_ request: URLRequest) -> URLRequest {
    return request
  }
  
  public func willSend(_ request: URLRequest) {}
  
  public func didReceive(_ response: URLResponse, data: Data?) {
    Logger.backend.debug("Response: \(response)")
    if let data = data {
      let str = String(data: data, encoding: .utf8)
      Logger.backend.debug("Data: \(str ?? "")")
    }
  }
}
