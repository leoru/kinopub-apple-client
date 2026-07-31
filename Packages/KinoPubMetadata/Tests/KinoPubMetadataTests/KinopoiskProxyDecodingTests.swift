import XCTest
@testable import KinoPubMetadata

final class KinopoiskProxyDecodingTests: XCTestCase {

  func testProxyFactsEnvelopeMatchesLiveShape() throws {
    let json = """
    {"total":2,"items":[
      {"text":"Fact one","type":"FACT","spoiler":false},
      {"text":"Blooper","type":"BLOOPER","spoiler":true}
    ]}
    """.data(using: .utf8)!
    struct Envelope: Decodable {
      struct Item: Decodable {
        let text: String
        let type: String?
        let spoiler: Bool?
      }
      let items: [Item]
    }
    let decoded = try JSONDecoder().decode(Envelope.self, from: json)
    XCTAssertEqual(decoded.items.count, 2)
    XCTAssertEqual(decoded.items[1].type, "BLOOPER")
  }

  func testProxyReviewsEnvelopeMatchesLiveShape() throws {
    let json = """
    {"total":1,"totalPages":1,"totalPositiveReviews":1,"totalNegativeReviews":0,"totalNeutralReviews":0,
     "items":[{"kinopoiskId":1,"type":"POSITIVE","date":"2020-01-01T00:00:00",
               "author":"Alice","title":"Great","description":"Body text"}]}
    """.data(using: .utf8)!
    struct Page: Decodable {
      struct Item: Decodable {
        let author: String?
        let title: String?
        let description: String?
        let type: String?
      }
      let items: [Item]
      let totalPositiveReviews: Int?
    }
    let page = try JSONDecoder().decode(Page.self, from: json)
    XCTAssertEqual(page.items.first?.author, "Alice")
    XCTAssertEqual(page.totalPositiveReviews, 1)
  }

  func testReviewModelIdentity() {
    let review = Review(author: "A", title: "T", body: "B", sentiment: "POSITIVE", date: "2020")
    XCTAssertEqual(review.id, "A-T-2020")
  }
}
