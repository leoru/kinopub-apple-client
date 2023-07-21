//
//  File.swift
//
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation

public class URLSessionMock: URLSession {
  var data: Data?
  var response: URLResponse?
  var error: Error?
}
