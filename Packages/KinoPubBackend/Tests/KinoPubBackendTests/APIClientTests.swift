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
            "token_type": "bearer"
        }
        """
        sessionMock.data = json.data(using: .utf8)
        
        // When
        do {
            let response: TokenResponse = try await apiClient.performRequest(RequestData(path: "/token", method: "GET"), decodingType: TokenResponse.self)
            
            // Then
            XCTAssertEqual(response.accessToken, "testToken")
            XCTAssertEqual(response.tokenType, "bearer")
        } catch {
            XCTFail("Expected successful decoding but got error: \(error)")
        }
    }
    
    func testPerformRequest_WhenError_ThrowsError() async {
        // Given
        sessionMock.error = NSError(domain: "Test", code: 1234, userInfo: nil)
        
        // When
        do {
            let _: TokenResponse = try await apiClient.performRequest(RequestData(path: "/token", method: "GET"), decodingType: TokenResponse.self)
            XCTFail("Expected error but got a successful response")
        } catch {
            // Expected behavior
        }
    }

    // ... More tests based on different scenarios
}
