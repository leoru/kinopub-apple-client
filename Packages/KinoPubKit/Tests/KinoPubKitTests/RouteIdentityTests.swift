//
//  RouteIdentityTests.swift
//  KinoPubKitTests
//
//  Mirrors the app's navigation-route Equatable contract: case-by-case identity,
//  never `hashValue == hashValue`. Player vs trailerPlayer with the same id must
//  stay distinct even when their hashes previously collided under the old compare.
//

import XCTest

/// Stand-in for the app's `MainRoutes` / `DownloadsRoutes` equality rules. Kept
/// here because the app target has no unit-test bundle; the real enums in
/// `KinoPubAppleClient/States/Navigation/Routes.swift` follow the same pattern.
private enum SampleRoute: Hashable {
  case details(Int)
  case detailsById(Int)
  case history
  case player(Int)
  case trailerPlayer(Int)

  func hash(into hasher: inout Hasher) {
    switch self {
    case .details(let id):
      hasher.combine(0)
      hasher.combine(id)
    case .detailsById(let id):
      hasher.combine(1)
      hasher.combine(id)
    case .history:
      hasher.combine(2)
    case .player(let id):
      hasher.combine(3)
      hasher.combine(id)
    case .trailerPlayer(let id):
      hasher.combine(4)
      hasher.combine(id)
    }
  }

  static func == (lhs: SampleRoute, rhs: SampleRoute) -> Bool {
    switch (lhs, rhs) {
    case (.details(let a), .details(let b)):
      return a == b
    case (.detailsById(let a), .detailsById(let b)):
      return a == b
    case (.history, .history):
      return true
    case (.player(let a), .player(let b)):
      return a == b
    case (.trailerPlayer(let a), .trailerPlayer(let b)):
      return a == b
    default:
      return false
    }
  }
}

final class RouteIdentityTests: XCTestCase {

  func testSameCaseSamePayloadIsEqual() {
    XCTAssertEqual(SampleRoute.details(42), SampleRoute.details(42))
    XCTAssertEqual(SampleRoute.detailsById(7), SampleRoute.detailsById(7))
    XCTAssertEqual(SampleRoute.history, SampleRoute.history)
    XCTAssertEqual(SampleRoute.player(9), SampleRoute.player(9))
    XCTAssertEqual(SampleRoute.trailerPlayer(9), SampleRoute.trailerPlayer(9))
  }

  func testDifferentPayloadsAreNotEqual() {
    XCTAssertNotEqual(SampleRoute.details(1), SampleRoute.details(2))
    XCTAssertNotEqual(SampleRoute.player(1), SampleRoute.player(2))
  }

  func testPlayerAndTrailerPlayerWithSameIdAreDistinct() {
    // The old `hashValue == hashValue` compare collapsed these when discriminators
    // were missing from `hash(into:)`. Case-by-case equality must keep them apart.
    XCTAssertNotEqual(SampleRoute.player(42), SampleRoute.trailerPlayer(42))
  }

  func testDetailsAndDetailsByIdWithSameIdAreDistinct() {
    XCTAssertNotEqual(SampleRoute.details(42), SampleRoute.detailsById(42))
  }

  func testSetMembershipRespectsCaseIdentity() {
    var routes: Set<SampleRoute> = [.player(1), .trailerPlayer(1), .history]
    XCTAssertEqual(routes.count, 3)
    XCTAssertTrue(routes.contains(.player(1)))
    XCTAssertTrue(routes.contains(.trailerPlayer(1)))
    XCTAssertFalse(routes.contains(.player(2)))
    routes.insert(.player(1))
    XCTAssertEqual(routes.count, 3)
  }
}
