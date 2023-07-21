//
//  CURLLoggingPlugin.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation
import OSLog
import KinoPubLogging

public class CURLLoggingPlugin: APIClientPlugin {
  
  public func prepare(_ request: URLRequest) -> URLRequest {
    return request
  }
  
  public func willSend(_ request: URLRequest) {
    Logger.backend.debug("\(request.curlString)")
  }
  
  public func didReceive(_ response: URLResponse, data: Data?) {
    // Do nothing
  }
}

extension URLRequest {
  var curlString: String {
    guard let url = url else { return "" }
    var baseCommand = "curl \(url.absoluteString)"
    
    if httpMethod == "POST" {
      baseCommand = baseCommand.appending(" -X POST")
    }
    
    allHTTPHeaderFields?.forEach { key, value in
      baseCommand = baseCommand.appending(" -H '\(key): \(value)'")
    }
    
    if let body = httpBody, let bodyAsString = String(data: body, encoding: .utf8) {
      baseCommand = baseCommand.appending(" -d '\(bodyAsString)'")
    }
    
    return baseCommand
  }
}
