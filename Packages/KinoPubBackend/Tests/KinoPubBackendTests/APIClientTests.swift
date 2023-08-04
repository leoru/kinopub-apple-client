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
            "access_token": "testToken",
            "token_type": "bearer",
            "expires_in": 12345,
            "refresh_token": "testRefreshToken"
        }
        """
    sessionMock.data = json.data(using: .utf8, allowLossyConversion: true)

    // When
    do {
      let response: TokenResponse = try await apiClient.performRequest(with: RequestData(path: "/token", method: "GET"), decodingType: TokenResponse.self)

      // Then
      XCTAssertEqual(response.accessToken, "testToken")
      XCTAssertEqual(response.tokenType, "bearer")
      XCTAssertEqual(response.expiresIn, 12345)
      XCTAssertEqual(response.refreshToken, "testRefreshToken")
    } catch {
      XCTFail("Expected successful decoding but got error: \(error)")
    }
  }

  func testPerformRequest_WhenError_ThrowsError() async {
    // Given
    sessionMock.error = NSError(domain: "Test", code: 1234, userInfo: nil)

    // When
    do {
      let _: TokenResponse = try await apiClient.performRequest(with: RequestData(path: "/token", method: "GET"), decodingType: TokenResponse.self)
      XCTFail("Expected error but got a successful response")
    } catch {
      // Expected behavior
    }
  }

  // ... More tests based on different scenarios
}
