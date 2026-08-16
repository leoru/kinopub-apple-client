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
        request = convertParamsToURL(for: url, request: request, endpoint: endpoint)
      default:
        if endpoint.forceSendAsGetParams {
          request = convertParamsToURL(for: url, request: request, endpoint: endpoint)
          break
        }
        let bodyData = try? JSONSerialization.data(withJSONObject: parameters)
        request.httpBody = bodyData
        // Label the body or kino.pub silently drops every parameter in it. URLSession
        // stamps an unlabelled body `application/x-www-form-urlencoded`, so the API was
        // handed JSON bytes claiming to be a form, parsed nothing, and still answered
        // `{"status":200}` — which is exactly how `/v1/device/notify` kept writing
        // "unknown / unknown / unknown" and the streaming profile never moved.
        // Verified live: same body + this header applies; without it, nothing changes.
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
      }
    }

    return request
  }

  private func convertParamsToURL(for url: URL, request: URLRequest, endpoint: Endpoint) -> URLRequest {
    var request = request
    var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
    if let parameters = endpoint.parameters {
      components.queryItems = parameters.sorted(by: { $0.key < $1.key }).map { (key, value) in
        return URLQueryItem(name: key, value: "\(value)")
      }
    }
    request.url = components.url
    return request
  }
}
