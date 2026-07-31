import XCTest
@testable import KinoPubBackend

final class ResponseCacheTests: XCTestCase {

  func testStoreAndRetrieve_Memory() {
    let cache = ResponseCache(directoryName: "test-cache-\(UUID().uuidString)")
    let payload = Data("hello".utf8)
    cache.store(payload, for: "k", ttl: 60, persist: false)
    XCTAssertEqual(cache.data(for: "k"), payload)
  }

  func testExpiredEntry_ReturnsNil() {
    let cache = ResponseCache(directoryName: "test-cache-\(UUID().uuidString)")
    cache.store(Data("x".utf8), for: "k", ttl: -1, persist: false)
    XCTAssertNil(cache.data(for: "k"))
  }

  func testRemoveAndClear() {
    let cache = ResponseCache(directoryName: "test-cache-\(UUID().uuidString)")
    cache.store(Data("a".utf8), for: "a", ttl: 60, persist: false)
    cache.store(Data("b".utf8), for: "b", ttl: 60, persist: false)
    cache.remove(for: "a")
    XCTAssertNil(cache.data(for: "a"))
    XCTAssertNotNil(cache.data(for: "b"))
    cache.clear()
    XCTAssertNil(cache.data(for: "b"))
  }

  func testMissingKey_ReturnsNil() {
    let cache = ResponseCache(directoryName: "test-cache-\(UUID().uuidString)")
    XCTAssertNil(cache.data(for: "absent"))
  }
}

// MARK: - APIClient cache integration

private struct Probe: Codable { let value: Int }

private struct CacheProbeRequest: Endpoint, CacheableRequest {
  var cachePolicy: CachePolicy { .memory(ttl: 60) }
  var path: String { "/probe" }
  var method: String { "GET" }
  var headers: [String: String]? { nil }
  var parameters: [String: Any]? { nil }
}

private struct UncachedProbeRequest: Endpoint {
  var path: String { "/probe" }
  var method: String { "GET" }
  var headers: [String: String]? { nil }
  var parameters: [String: Any]? { nil }
}

final class APIClientCacheTests: XCTestCase {

  private func json(_ value: Int) -> Data { Data("{\"value\":\(value)}".utf8) }

  func testCacheableRequest_SecondCallReturnsCachedValue() async throws {
    let session = URLSessionMock()
    let client = APIClient(baseUrl: "https://api.example.com",
                           session: session,
                           cache: ResponseCache(directoryName: "t-\(UUID().uuidString)"))

    session.data = json(1)
    let first: Probe = try await client.performRequest(with: CacheProbeRequest(), decodingType: Probe.self)
    XCTAssertEqual(first.value, 1)

    session.data = json(2)
    let second: Probe = try await client.performRequest(with: CacheProbeRequest(), decodingType: Probe.self)
    XCTAssertEqual(second.value, 1, "Expected cached value, not the fresh network value")
  }

  func testForceRefresh_BypassesCache() async throws {
    let session = URLSessionMock()
    let client = APIClient(baseUrl: "https://api.example.com",
                           session: session,
                           cache: ResponseCache(directoryName: "t-\(UUID().uuidString)"))

    session.data = json(1)
    _ = try await client.performRequest(with: CacheProbeRequest(), decodingType: Probe.self)

    session.data = json(2)
    let refreshed: Probe = try await client.performRequest(with: CacheProbeRequest(),
                                                           decodingType: Probe.self,
                                                           forceRefresh: true)
    XCTAssertEqual(refreshed.value, 2, "forceRefresh must hit the network")

    session.data = json(3)
    let cached: Probe = try await client.performRequest(with: CacheProbeRequest(), decodingType: Probe.self)
    XCTAssertEqual(cached.value, 2)
  }

  func testNonCacheableRequest_AlwaysHitsNetwork() async throws {
    let session = URLSessionMock()
    let client = APIClient(baseUrl: "https://api.example.com",
                           session: session,
                           cache: ResponseCache(directoryName: "t-\(UUID().uuidString)"))

    session.data = json(1)
    let first: Probe = try await client.performRequest(with: UncachedProbeRequest(), decodingType: Probe.self)
    XCTAssertEqual(first.value, 1)

    session.data = json(2)
    let second: Probe = try await client.performRequest(with: UncachedProbeRequest(), decodingType: Probe.self)
    XCTAssertEqual(second.value, 2, "Non-cacheable request must always reflect fresh network data")
  }
}
