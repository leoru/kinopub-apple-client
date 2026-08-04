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

  func testPerformRequest_WhenOAuthInvalidGrantWithoutStatus_ThrowsBackendError() async {
    // Real oauth2/token 400 body — no `status` field.
    let json = """
        {
            "error": "invalid_grant",
            "error_description": "Invalid refresh token"
        }
        """
    sessionMock.data = json.data(using: .utf8, allowLossyConversion: true)

    do {
      let _: AccessToken = try await apiClient.performRequest(
        with: RequestData(path: "/oauth2/token", method: "POST"),
        decodingType: AccessToken.self
      )
      XCTFail("Expected invalid_grant network error")
    } catch APIClientError.networkError(let error as BackendError) {
      XCTAssertEqual(error.errorCode, .invalidGrant)
      XCTAssertEqual(error.errorDescription, "Invalid refresh token")
    } catch {
      XCTFail("Expected BackendError.invalidGrant but got \(error)")
    }
  }

  func testPerformRequest_ChainsPluginPrepareResults() async throws {
    // Given — two plugins each add a distinct header; both must survive the chain.
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
    apiClient = APIClient(
      baseUrl: "https://api.example.com",
      plugins: [
        HeaderPlugin(field: "X-Plugin-A", value: "alpha"),
        HeaderPlugin(field: "X-Plugin-B", value: "beta")
      ],
      session: sessionMock
    )

    // When
    let _: VerificationResponse = try await apiClient.performRequest(
      with: RequestData(path: "/token", method: "GET"),
      decodingType: VerificationResponse.self
    )

    // Then
    let prepared = try XCTUnwrap(sessionMock.lastRequest)
    XCTAssertEqual(prepared.value(forHTTPHeaderField: "X-Plugin-A"), "alpha")
    XCTAssertEqual(prepared.value(forHTTPHeaderField: "X-Plugin-B"), "beta")
  }

  func testPerformRequest_WhenHTTP404_ThrowsHttpStatusNotDecodingError() async {
    let body = Data(#"{"message":"gone"}"#.utf8)
    sessionMock.data = body
    sessionMock.response = HTTPURLResponse(
      url: URL(string: "https://api.example.com/missing")!,
      statusCode: 404,
      httpVersion: nil,
      headerFields: nil
    )

    do {
      let _: VerificationResponse = try await apiClient.performRequest(
        with: RequestData(path: "/missing", method: "GET"),
        decodingType: VerificationResponse.self
      )
      XCTFail("Expected httpStatus error")
    } catch APIClientError.httpStatus(let code, let data) {
      XCTAssertEqual(code, 404)
      XCTAssertEqual(data, body)
    } catch {
      XCTFail("Expected httpStatus(404) but got \(error)")
    }
  }

  func testPerformRequest_WhenHTTP401_ThrowsHttpStatusNotDecodingError() async {
    sessionMock.data = Data()
    sessionMock.response = HTTPURLResponse(
      url: URL(string: "https://api.example.com/secure")!,
      statusCode: 401,
      httpVersion: nil,
      headerFields: ["WWW-Authenticate": "Bearer"]
    )

    do {
      let _: VerificationResponse = try await apiClient.performRequest(
        with: RequestData(path: "/secure", method: "GET"),
        decodingType: VerificationResponse.self
      )
      XCTFail("Expected httpStatus error")
    } catch APIClientError.httpStatus(let code, let data) {
      XCTAssertEqual(code, 401)
      XCTAssertEqual(data, Data())
    } catch {
      XCTFail("Expected httpStatus(401) but got \(error)")
    }
  }

  func testPerformRequest_WhenHTTP400WithBackendErrorBody_StillThrowsBackendError() async {
    // Non-2xx must not erase structured kino.pub / OAuth envelopes — auth
    // logout depends on invalid_grant remaining a BackendError.
    let json = """
        {
            "error": "invalid_grant",
            "error_description": "Invalid refresh token"
        }
        """
    sessionMock.data = json.data(using: .utf8)
    sessionMock.response = HTTPURLResponse(
      url: URL(string: "https://api.example.com/oauth2/token")!,
      statusCode: 400,
      httpVersion: nil,
      headerFields: nil
    )

    do {
      let _: AccessToken = try await apiClient.performRequest(
        with: RequestData(path: "/oauth2/token", method: "POST"),
        decodingType: AccessToken.self
      )
      XCTFail("Expected invalid_grant network error")
    } catch APIClientError.networkError(let error as BackendError) {
      XCTAssertEqual(error.errorCode, .invalidGrant)
      XCTAssertEqual(error.errorDescription, "Invalid refresh token")
    } catch {
      XCTFail("Expected BackendError.invalidGrant but got \(error)")
    }
  }
}

private struct HeaderPlugin: APIClientPlugin {
  let field: String
  let value: String

  func prepare(_ request: URLRequest) -> URLRequest {
    var request = request
    request.addValue(value, forHTTPHeaderField: field)
    return request
  }

  func willSend(_ request: URLRequest) {}

  func didReceive(_ response: URLResponse, data: Data?) {}
}
