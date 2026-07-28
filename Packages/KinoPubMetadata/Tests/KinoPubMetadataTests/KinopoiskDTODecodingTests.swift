import XCTest
@testable import KinoPubMetadata

/// Fixtures are real responses captured live against kinopoisk id 326 (The
/// Shawshank Redemption) this session — not hand-written, so a field-name
/// mismatch here means the mapping code would silently come back empty in the
/// app, not just fail a test with synthetic data.
final class KinopoiskDTODecodingTests: XCTestCase {
  private let client = MetadataHTTPClient()

  func testDetailsDecodesAndMapsArtwork() throws {
    let data = try fixture("kinopoisk_details")
    let details = try client.decode(KinopoiskFilmDetails.self, from: data)
    XCTAssertEqual(details.kinopoiskId, 326)
    XCTAssertEqual(details.nameRu, "Побег из Шоушенка")
    XCTAssertEqual(details.year, 1994)
    XCTAssertEqual(details.serial, false)
    XCTAssertNotNil(details.posterUrl)
  }

  func testStaffDecodesAndSplitsCharacterFromDescription() throws {
    let data = try fixture("kinopoisk_staff")
    let members = try client.decode([KinopoiskStaffMember].self, from: data)
    XCTAssertFalse(members.isEmpty)

    let robbins = try XCTUnwrap(members.first { $0.nameRu == "Тим Роббинс" })
    XCTAssertEqual(robbins.professionKey, "ACTOR")
    let character = KinopoiskSource.splitCharacter(description: robbins.description, name: robbins.nameRu!)
    XCTAssertEqual(character, "Энди Дюфрейн")

    let director = try XCTUnwrap(members.first { $0.professionKey == "DIRECTOR" })
    XCTAssertNil(director.description)
  }

  func testAwardsDecodesRealPayload() throws {
    let data = try fixture("kinopoisk_awards")
    let response = try client.decode(KinopoiskAwardsResponse.self, from: data)
    XCTAssertEqual(response.total, 12)
    XCTAssertEqual(response.items.count, 12)
    // Shawshank famously lost every one of its 7 Oscar nominations.
    XCTAssertTrue(response.items.filter { $0.win == true }.isEmpty)
    XCTAssertTrue(response.items.contains { $0.name == "Оскар" })
  }

  func testImagesDecodesRealPayload() throws {
    let data = try fixture("kinopoisk_images")
    let response = try client.decode(KinopoiskImagesResponse.self, from: data)
    XCTAssertGreaterThan(response.total, 0)
    XCTAssertFalse(response.items.isEmpty)
    XCTAssertNotNil(response.items.first?.imageUrl)
  }

  func testFactsDecodesAndStripsHTML() throws {
    let data = try fixture("kinopoisk_facts")
    let response = try client.decode(KinopoiskFactsResponse.self, from: data)
    XCTAssertGreaterThan(response.total, 0)
    let firstRaw = try XCTUnwrap(response.items.first?.text)
    XCTAssertTrue(firstRaw.contains("<a href"), "fixture should still carry embedded markup pre-strip")
    let cleaned = KinopoiskSource.stripHTML(firstRaw)
    XCTAssertFalse(cleaned.contains("<"))
    XCTAssertFalse(cleaned.contains("&#160;"))
  }

  private func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
      ?? Bundle.module.url(forResource: name, withExtension: "json")
    )
    return try Data(contentsOf: url)
  }
}
