import XCTest
@testable import KinoPubUI

final class PosterStyleSizeTests: XCTestCase {

  /// Posters are portrait artwork; a size whose width exceeded its height would
  /// letterbox every card in the catalog.
  func testEverySizeIsPortrait() {
    let sizes: [PosterStyle.Size] = [.small, .regular, .medium, .big]
    for size in sizes {
      XCTAssertLessThan(size.width, size.height, "\(size) is not portrait")
    }
  }

  func testSizesIncreaseMonotonically() {
    let ordered: [PosterStyle.Size] = [.small, .regular, .medium, .big]
    for (smaller, larger) in zip(ordered, ordered.dropFirst()) {
      XCTAssertLessThan(smaller.width, larger.width)
      XCTAssertLessThan(smaller.height, larger.height)
    }
  }
}
