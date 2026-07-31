//
//  TVChannelsTests.swift
//

import XCTest
@testable import KinoPubBackend

final class TVChannelsTests: XCTestCase {

  func testRequestTargetsTV() {
    let request = TVChannelsRequest()
    XCTAssertEqual(request.path, "/v1/tv")
    XCTAssertEqual(request.method, "GET")
    XCTAssertNil(request.parameters)
  }

  func testChannelDecodesLogosObject() throws {
    let json = """
    {"id":1,"title":"Match TV","name":"matchtv",
     "logos":{"s":"https://example.com/s.png","m":"https://example.com/m.png"},
     "stream":"https://cdn.example.com/live.m3u8"}
    """.data(using: .utf8)!
    let channel = try JSONDecoder().decode(TVChannel.self, from: json)
    XCTAssertEqual(channel.id, 1)
    XCTAssertEqual(channel.title, "Match TV")
    XCTAssertEqual(channel.name, "matchtv")
    XCTAssertEqual(channel.logo, "https://example.com/m.png")
    XCTAssertEqual(channel.stream, "https://cdn.example.com/live.m3u8")
    XCTAssertEqual(channel.files.first?.url.hls4, channel.stream)
  }

  func testChannelDecodesLogosStringAndArray() throws {
    let asString = """
    {"id":2,"title":"A","logos":"https://example.com/a.png","stream":"https://s/a"}
    """.data(using: .utf8)!
    XCTAssertEqual(try JSONDecoder().decode(TVChannel.self, from: asString).logo,
                   "https://example.com/a.png")

    let asArray = """
    {"id":3,"title":"B","logos":["https://example.com/b.png"],"stream":"https://s/b"}
    """.data(using: .utf8)!
    XCTAssertEqual(try JSONDecoder().decode(TVChannel.self, from: asArray).logo,
                   "https://example.com/b.png")
  }

  func testChannelsDataDefaultsEmpty() throws {
    let json = #"{"status":200}"#.data(using: .utf8)!
    let data = try JSONDecoder().decode(TVChannelsData.self, from: json)
    XCTAssertTrue(data.channels.isEmpty)
  }
}
