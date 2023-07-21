//
//  APIClientPlugin.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public protocol APIClientPlugin {
  func prepare(_ request: URLRequest) -> URLRequest
  func willSend(_ request: URLRequest)
  func didReceive(_ response: URLResponse, data: Data?)
}
