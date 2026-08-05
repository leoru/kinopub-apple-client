import XCTest
@testable import KinoPubBackend

/// The refresh-token rejection matrix. The session ends only when the backend says
/// so — a 400/401 from the token endpoint (any body shape, any error code), never
/// on transport failures, pending device polls, or 5xx.
class AuthRejectionTests: XCTestCase {

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

  // MARK: - Helpers

  private func stub(status: Int, body: String?) {
    sessionMock.data = body?.data(using: .utf8)
    sessionMock.response = HTTPURLResponse(
      url: URL(string: "https://api.example.com/oauth2/token")!,
      statusCode: status,
      httpVersion: nil,
      headerFields: nil
    )
  }

  private func performRefresh() async -> APIClientError? {
    do {
      let _: AccessToken = try await apiClient.performRequest(
        with: RequestData(path: "/oauth2/token", method: "POST"),
        decodingType: AccessToken.self
      )
      return nil
    } catch let error as APIClientError {
      return error
    } catch {
      XCTFail("Non-APIClientError: \(error)")
      return nil
    }
  }

  // MARK: - Rejections

  func testRefresh400InvalidGrantEnvelope_IsAuthRejection() async {
    stub(status: 400, body: #"{"error":"invalid_grant","error_description":"Invalid refresh token"}"#)
    let error = await performRefresh()
    guard case .networkError(let underlying) = error,
          let backendError = underlying as? BackendError else {
      return XCTFail("Expected BackendError, got \(String(describing: error))")
    }
    XCTAssertEqual(backendError.errorCode, .invalidGrant)
    XCTAssertEqual(backendError.errorDescription, "Invalid refresh token")
    XCTAssertTrue(error?.isAuthRejection == true)
  }

  /// The production failure: a 400 whose `error` code is not one we know. It must
  /// still decode (as `.unknown`) and still count as a rejection — never transient.
  func testRefresh400UnknownErrorCode_IsAuthRejection() async {
    stub(status: 400, body: #"{"status":400,"error":"some_unseen_code"}"#)
    let error = await performRefresh()
    guard case .networkError(let underlying) = error,
          let backendError = underlying as? BackendError else {
      return XCTFail("Expected BackendError, got \(String(describing: error))")
    }
    XCTAssertEqual(backendError.errorCode, .unknown("some_unseen_code"))
    XCTAssertTrue(error?.isAuthRejection == true)
  }

  func testRefresh400NonJSONBody_IsAuthRejection() async {
    stub(status: 400, body: "<html>Bad Request</html>")
    let error = await performRefresh()
    guard case .httpStatus(let code, _) = error else {
      return XCTFail("Expected httpStatus(400), got \(String(describing: error))")
    }
    XCTAssertEqual(code, 400)
    XCTAssertTrue(error?.isAuthRejection == true)
  }

  func testContent401EmptyBody_IsAuthRejection() async {
    stub(status: 401, body: nil)
    let error = await performRefresh()
    guard case .httpStatus(let code, _) = error else {
      return XCTFail("Expected httpStatus(401), got \(String(describing: error))")
    }
    XCTAssertEqual(code, 401)
    XCTAssertTrue(error?.isAuthRejection == true)
  }

  // MARK: - Not rejections

  /// Device-code polling gets 400 authorization_pending until the user activates —
  /// that must never log anyone out.
  func testDevicePoll400AuthorizationPending_IsNotRejection() async {
    stub(status: 400, body: #"{"status":400,"error":"authorization_pending"}"#)
    let error = await performRefresh()
    guard case .networkError(let underlying) = error,
          let backendError = underlying as? BackendError else {
      return XCTFail("Expected BackendError, got \(String(describing: error))")
    }
    XCTAssertEqual(backendError.errorCode, .authorizationPending)
    XCTAssertTrue(error?.isAuthRejection == false)
  }

  func testServer500_IsNotRejection() async {
    stub(status: 500, body: "Internal Server Error")
    let error = await performRefresh()
    guard case .httpStatus(let code, _) = error else {
      return XCTFail("Expected httpStatus(500), got \(String(describing: error))")
    }
    XCTAssertEqual(code, 500)
    XCTAssertTrue(error?.isAuthRejection == false)
  }

  func testTransportTimeout_IsNotRejection() async {
    // The real URLSessionImpl wraps transport failures into networkError; the mock
    // throws what it's given, so feed it the wrapped form.
    sessionMock.error = APIClientError.networkError(URLError(.timedOut))
    let error = await performRefresh()
    guard case .networkError = error else {
      return XCTFail("Expected networkError, got \(String(describing: error))")
    }
    XCTAssertTrue(error?.isAuthRejection == false)
  }

  func testDecodingFailure_IsNotRejection() async {
    stub(status: 200, body: "not json at all")
    let error = await performRefresh()
    guard case .decodingError = error else {
      return XCTFail("Expected decodingError, got \(String(describing: error))")
    }
    XCTAssertTrue(error?.isAuthRejection == false)
  }
}
