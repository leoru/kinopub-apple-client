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
  
  public init() {}
  
  public func prepare(_ request: URLRequest) -> URLRequest {
    return request
  }
  
  public func willSend(_ request: URLRequest) {
    Logger.backend.debug("\(request.cURL(pretty: true))")
  }
  
  public func didReceive(_ response: URLResponse, data: Data?) {
    // Do nothing
  }
}

extension URLRequest {
  public func cURL(pretty: Bool = false) -> String {
    let newLine = pretty ? "\\\n" : ""
    let method = (pretty ? "--request " : "-X ") + "\(self.httpMethod ?? "GET") \(newLine)"
    let url: String = (pretty ? "--url " : "") + "\'\(self.url?.absoluteString ?? "")\' \(newLine)"
    
    var cURL = "curl "
    var header = ""
    var data: String = ""
    
    if let httpHeaders = self.allHTTPHeaderFields, httpHeaders.keys.count > 0 {
      for (key,value) in httpHeaders {
        header += (pretty ? "--header " : "-H ") + "\'\(key): \(value)\' \(newLine)"
      }
    }
    
    if let bodyData = self.httpBody, let bodyString = String(data: bodyData, encoding: .utf8),  !bodyString.isEmpty {
      data = "--data '\(bodyString)'"
    }
    
    cURL += method + url + header + data
    
    return cURL
  }
}
