//
//  RequestBuilder.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

internal class RequestBuilder {
  let baseURL: URL
  
  init(baseURL: URL) {
    self.baseURL = baseURL
  }
  
  func build(with endpoint: Endpoint) -> URLRequest? {
    guard let url = URL(string: endpoint.path, relativeTo: baseURL) else { return nil }
    
    var request = URLRequest(url: url)
    request.httpMethod = endpoint.method
    
    if let headers = endpoint.headers {
      for (key, value) in headers {
        request.addValue(value, forHTTPHeaderField: key)
      }
    }
    
    if let parameters = endpoint.parameters {
      switch endpoint.method {
      case "GET":
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = parameters.map { (key, value) in
          return URLQueryItem(name: key, value: "\(value)")
        }
        request.url = components.url
      default:
        let bodyData = try? JSONSerialization.data(withJSONObject: parameters)
        request.httpBody = bodyData
      }
    }
    
    return request
  }
}
