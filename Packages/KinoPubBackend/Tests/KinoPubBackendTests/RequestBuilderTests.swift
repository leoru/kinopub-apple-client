//
//  File.swift
//  
//
//  Created by Kirill Kunst on 21.07.2023.
//

import Foundation
import XCTest
@testable import KinoPubBackend

struct RequestData: Endpoint {
  var path: String
  var method: String
  var headers: [String: String]?
  var parameters: [String: Any]?
}

class RequestBuilderTests: XCTestCase {

    var requestBuilder: RequestBuilder!
    let baseURL = URL(string: "https://api.example.com")!

    override func setUp() {
        super.setUp()
        requestBuilder = RequestBuilder(baseURL: baseURL)
    }

    override func tearDown() {
        requestBuilder = nil
        super.tearDown()
    }

    func testBuildRequest_WithPath_ReturnsCorrectURL() {
        let requestData = RequestData(path: "/testPath", method: "GET")
        let request = requestBuilder.build(with: requestData)

        XCTAssertEqual(request?.url, URL(string: "https://api.example.com/testPath"))
    }

    func testBuildRequest_WithHeaders_SetsHeadersCorrectly() {
        let headers = ["Authorization": "Bearer token123"]
        let requestData = RequestData(path: "/testPath", method: "GET", headers: headers)
        let request = requestBuilder.build(with: requestData)

        XCTAssertEqual(request?.value(forHTTPHeaderField: "Authorization"), "Bearer token123")
    }

    func testBuildRequest_WithGETParameters_EncodesParametersInURL() {
        let parameters = ["key1": "value1", "key2": "value2"]
        let requestData = RequestData(path: "/testPath", method: "GET", parameters: parameters)
        let request = requestBuilder.build(with: requestData)

        let expectedURL = URL(string: "https://api.example.com/testPath?key1=value1&key2=value2")!
        XCTAssertEqual(request?.url, expectedURL)
    }

    /// Without this header URLSession labels the body `x-www-form-urlencoded`, kino.pub
    /// parses no parameters out of the JSON and answers 200 anyway — a silent no-op.
    func testBuildRequest_WithBodyParameters_LabelsBodyAsJSON() {
        let requestData = RequestData(path: "/v1/device/notify",
                                      method: "POST",
                                      parameters: ["title": "Mac"])
        let request = requestBuilder.build(with: requestData)

        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request?.httpBody, #"{"title":"Mac"}"#.data(using: .utf8))
    }

    func testBuildRequest_WithExplicitContentType_KeepsEndpointHeader() {
        let requestData = RequestData(path: "/v1/device/notify",
                                      method: "POST",
                                      headers: ["Content-Type": "application/x-www-form-urlencoded"],
                                      parameters: ["title": "Mac"])
        let request = requestBuilder.build(with: requestData)

        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded")
    }

    /// Query-param POSTs carry no body, so they must not claim to.
    func testBuildRequest_WithForcedGetParams_SetsNoContentType() {
        let request = requestBuilder.build(with: RemoveDeviceRequest(id: 42))

        XCTAssertNil(request?.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertNil(request?.httpBody)
    }

    func testSimilarItemsRequest_EncodesIdAsQueryParam() {
        let request = requestBuilder.build(with: SimilarItemsRequest(id: "42"))
        XCTAssertEqual(request?.url,
                       URL(string: "https://api.example.com/v1/items/similar?id=42"))
        XCTAssertEqual(request?.httpMethod, "GET")
    }

}
