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

  /// One line per response: status, URL, size. Bodies are not dumped — a single
  /// history page would flood the console with megabytes of JSON.
  public func didReceive(_ response: URLResponse, data: Data?) {
    guard let http = response as? HTTPURLResponse else { return }
    let size = data?.count ?? 0
    Logger.backend.debug("Response \(http.statusCode) \(http.url?.absoluteString ?? "?") \(size)b")
  }
}
