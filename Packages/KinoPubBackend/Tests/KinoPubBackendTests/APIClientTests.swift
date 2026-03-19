import XCTest
@testable import KinoPubBackend

class APIClientTests: XCTestCase {

  var apiClient: APIClient!
  var sessionMock: URLSessionMock!

  override func setUp() {
    super.setUp()
    sessionMock = URLSessionMock()
    apiClient = APIClient(baseUrl: "https://api.example.com", session: sessionMock)
  }

  override func tearDown() {
    apiClient = nil
    sessionMock = nil
    super.tearDown()
  }

  func testPerformRequest_ReturnsDecodedData() async {
    // Given
    let json = """
        {
            "code": "testCode",
            "user_code": "ABCD-1234",
            "verification_uri": "https://example.com/activate",
            "expires_in": 12345,
            "interval": 5
        }
        """
    sessionMock.data = json.data(using: .utf8, allowLossyConversion: true)

    // When
    do {
      let response: VerificationResponse = try await apiClient.performRequest(with: RequestData(path: "/token", method: "GET"), decodingType: VerificationResponse.self)

      // Then
      XCTAssertEqual(response.code, "testCode")
      XCTAssertEqual(response.userCode, "ABCD-1234")
      XCTAssertEqual(response.verificationUri, "https://example.com/activate")
      XCTAssertEqual(response.expiresIn, 12345)
      XCTAssertEqual(response.interval, 5)
    } catch {
      XCTFail("Expected successful decoding but got error: \(error)")
    }
  }

  func testPerformRequest_WhenError_ThrowsError() async {
    // Given
    sessionMock.error = NSError(domain: "Test", code: 1234, userInfo: nil)

    // When
    do {
      let _: VerificationResponse = try await apiClient.performRequest(with: RequestData(path: "/token", method: "GET"), decodingType: VerificationResponse.self)
      XCTFail("Expected error but got a successful response")
    } catch {
      // Expected behavior
    }
  }

  func testPerformRequest_WhenBookmarksCountIsNumeric_DecodesResponse() async throws {
    let json = """
        {
            "status": 200,
            "items": [
                {
                    "id": 1920676,
                    "title": "basket",
                    "views": 0,
                    "count": 15,
                    "created": 1700883333,
                    "updated": 1713963602
                }
            ]
        }
        """
    sessionMock.data = json.data(using: .utf8, allowLossyConversion: true)

    let response: ArrayData<Bookmark> = try await apiClient.performRequest(
      with: RequestData(path: "/bookmarks", method: "GET"),
      decodingType: ArrayData<Bookmark>.self
    )

    XCTAssertEqual(response.items.count, 1)
    XCTAssertEqual(response.items.first?.count, "15")
  }

  func testPerformRequest_WhenNonErrorPayloadDecodingFails_ThrowsOriginalDecodingError() async {
    let json = """
        {
            "status": 200,
            "items": []
        }
        """
    sessionMock.data = json.data(using: .utf8, allowLossyConversion: true)

    do {
      let _: VerificationResponse = try await apiClient.performRequest(
        with: RequestData(path: "/token", method: "GET"),
        decodingType: VerificationResponse.self
      )
      XCTFail("Expected decoding error but got a successful response")
    } catch APIClientError.decodingError(let error) {
      guard case let DecodingError.keyNotFound(key, _) = error else {
        XCTFail("Expected missing code decoding error but got \(error)")
        return
      }

      XCTAssertEqual(key.stringValue, "code")
    } catch {
      XCTFail("Expected decoding error but got \(error)")
    }
  }
}
