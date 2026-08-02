//
//  CommunityPortTests.swift
//
//  Decoding / filter contracts ported from dungeon-master-xx so UI work can
//  rely on the backend pieces without re-discovering API quirks.
//

import XCTest
@testable import KinoPubBackend

final class CommunityPortTests: XCTestCase {

  // MARK: - Vote

  func testVoteRequestTargetsItemsVote() {
    let request = VoteRequest(id: 42, like: 1)
    XCTAssertEqual(request.path, "/v1/items/vote")
    XCTAssertEqual(request.method, "GET")
    XCTAssertEqual(request.parameters?["id"] as? Int, 42)
    XCTAssertEqual(request.parameters?["like"] as? Int, 1)
    XCTAssertTrue(request.forceSendAsGetParams)
  }

  func testVoteDataDecodesStringCounts() throws {
    let json = """
    {"voted":true,"total":"120","positive":"90","negative":"30","rating":60}
    """.data(using: .utf8)!
    let data = try JSONDecoder().decode(VoteData.self, from: json)
    XCTAssertTrue(data.voted)
    XCTAssertEqual(data.totalCount, 120)
    XCTAssertEqual(data.positiveCount, 90)
    XCTAssertEqual(data.negativeCount, 30)
    XCTAssertEqual(data.rating, 60)
  }

  // MARK: - Collections

  func testCollectionsRequestPath() {
    let request = CollectionsRequest(page: 2, perpage: 20, sort: "-watchers")
    XCTAssertEqual(request.path, "/v1/collections")
    XCTAssertEqual(request.parameters?["page"] as? String, "2")
    XCTAssertEqual(request.parameters?["sort"] as? String, "-watchers")
  }

  func testCollectionsDataDecodesItemsKeyLossily() throws {
    let json = """
    {"items":[{"id":1,"title":"Good"},{"id":"bad","title":"Skip me"},{"id":2,"title":"Also good"}],
     "pagination":{"total":2,"current":1,"perpage":20}}
    """.data(using: .utf8)!
    let data = try JSONDecoder().decode(CollectionsData.self, from: json)
    XCTAssertEqual(data.collections.map(\.id), [1, 2])
    XCTAssertEqual(data.collections.map(\.title), ["Good", "Also good"])
  }

  func testCollectionViewRequest() {
    let request = CollectionViewRequest(id: 7)
    XCTAssertEqual(request.path, "/v1/collections/view")
    XCTAssertEqual(request.parameters?["id"] as? String, "7")
  }

  // MARK: - Device settings

  func testDeviceSettingsDecodesNestedScalarsAndLists() throws {
    let json = """
    {
      "supportSsl": {"value": 1, "label": "SSL"},
      "supportHevc": {"value": 1, "label": "HEVC"},
      "supportHdr": {"value": 0, "label": "HDR"},
      "support4k": {"value": 1, "label": "4K"},
      "mixedPlaylist": {"value": 1, "label": "Mixed"},
      "streamingType": {"type":"list","value":[
        {"id":2,"label":"HLS","selected":0},
        {"id":4,"label":"HLS4","selected":1}
      ]},
      "serverLocation": {"type":"list","value":[
        {"id":1,"label":"NL","selected":1}
      ]}
    }
    """.data(using: .utf8)!
    let settings = try JSONDecoder().decode(DeviceSettings.self, from: json)
    XCTAssertTrue(settings.supportSsl)
    XCTAssertTrue(settings.supportHevc)
    XCTAssertFalse(settings.supportHdr)
    XCTAssertTrue(settings.support4k)
    XCTAssertTrue(settings.mixedPlaylist)
    XCTAssertEqual(settings.streamingType, 4)
    XCTAssertEqual(settings.streamingTypeOptions.map(\.id), [2, 4])
    XCTAssertEqual(settings.serverLocation, 1)
  }

  func testUpdateDeviceSettingsPostsBooleansAsIntsInBody() {
    let settings = DeviceSettings(
      supportHevc: true,
      supportHdr: true,
      support4k: true,
      mixedPlaylist: true,
      streamingType: 4,
      serverLocation: 1
    )
    let request = UpdateDeviceSettingsRequest(id: 9, settings: settings)
    XCTAssertEqual(request.path, "/v1/device/9/settings")
    XCTAssertEqual(request.method, "POST")
    XCTAssertFalse(request.forceSendAsGetParams)
    XCTAssertEqual(request.parameters?["supportHevc"] as? Int, 1)
    XCTAssertEqual(request.parameters?["supportHdr"] as? Int, 1)
    XCTAssertEqual(request.parameters?["support4k"] as? Int, 1)
    XCTAssertEqual(request.parameters?["mixedPlaylist"] as? Int, 1)
  }

  func testDeviceNotifyPutsIdentityInFormBody() {
    let request = DeviceNotifyRequest(
      title: "Alexander's MacBook",
      hardware: "MacBook Pro M1 Max, macOS 27",
      software: "KinoPub, v0.56 (123)"
    )
    XCTAssertEqual(request.path, "/v1/device/notify")
    XCTAssertEqual(request.method, "POST")
    XCTAssertFalse(request.forceSendAsGetParams)
    XCTAssertEqual(request.parameters?["title"] as? String, "Alexander's MacBook")
    XCTAssertEqual(request.parameters?["hardware"] as? String, "MacBook Pro M1 Max, macOS 27")
    XCTAssertEqual(request.parameters?["software"] as? String, "KinoPub, v0.56 (123)")
  }

  func testListAndRemoveDevicePaths() {
    XCTAssertEqual(ListDevicesRequest().path, "/v1/device")
    XCTAssertEqual(RemoveDeviceRequest(id: 42).path, "/v1/device/42/remove")
  }

  func testClearHistoryForSeasonPath() {
    let request = ClearHistoryForSeasonRequest(id: 99)
    XCTAssertEqual(request.path, "/v1/history/clear-for-season")
    XCTAssertEqual(request.method, "POST")
    XCTAssertTrue(request.forceSendAsGetParams)
    XCTAssertEqual(request.parameters?["id"] as? Int, 99)
  }

  // MARK: - Client-side filter facets

  func testClientSideFacetsMatchQualityAndRatings() {
    // mock() carries kinopoiskRating 8.3, so it would pass a rating facet — the
    // intended "low" item (quality 0, no decent ratings) is built from JSON like
    // the high one.
    let lowJSON = """
    {
      "id":2,"type":"movie","subtype":"","title":"Lo","year":2020,"cast":"","director":"",
      "genres":[],"countries":[],"duration":{"total":1,"average":1},
      "langs":1,"quality":0,"plot":"","imdb_rating":5.0,"kinopoisk_rating":5.0,"rating":0,
      "rating_votes":0,"rating_percentage":0,"views":1,"comments":0,
      "posters":{"small":"","medium":"","big":"","wide":""},
      "finished":false,"advert":false,"poor_quality":false,"created_at":0,"updated_at":0,"ac3":0
    }
    """.data(using: .utf8)!
    let low = try! JSONDecoder().decode(MediaItem.self, from: lowJSON)
    let highJSON = """
    {
      "id":1,"type":"movie","subtype":"","title":"Hi","year":2020,"cast":"","director":"",
      "genres":[],"countries":[],"duration":{"total":1,"average":1},
      "langs":1,"quality":2160,"plot":"","imdb_rating":8.5,"kinopoisk_rating":8.0,"rating":1,
      "rating_votes":1,"rating_percentage":100,"views":1,"comments":0,
      "posters":{"small":"","medium":"","big":"","wide":""},
      "finished":false,"advert":false,"poor_quality":false,"created_at":0,"updated_at":0,"ac3":1
    }
    """.data(using: .utf8)!
    let high = try! JSONDecoder().decode(MediaItem.self, from: highJSON)

    let filter4K = LibraryFilter(want4K: true)
    XCTAssertTrue(filter4K.hasClientSideFacets)
    XCTAssertTrue(filter4K.clientSideMatches(high))
    XCTAssertFalse(filter4K.clientSideMatches(low))

    let filterKP = LibraryFilter(kinopoiskMin: 7.5)
    XCTAssertTrue(filterKP.clientSideMatches(high))
    XCTAssertFalse(filterKP.clientSideMatches(low))

    let filterAC3 = LibraryFilter(wantAC3: true)
    XCTAssertTrue(filterAC3.clientSideMatches(high))
  }

  // MARK: - FileInfo dedupe

  func testFileInfoDedupesByQualityLabel() throws {
    func file(codec: String, quality: String, host: String) throws -> FileInfo {
      let json = """
      {"codec":"\(codec)","w":1920,"h":1080,"quality":"\(quality)","quality_id":1,
       "url":{"http":"http://\(host)","hls":"http://\(host).m3u8","hls4":"","hls2":""}}
      """.data(using: .utf8)!
      return try JSONDecoder().decode(FileInfo.self, from: json)
    }
    let a = try file(codec: "hevc", quality: "2160p", host: "a")
    let b = try file(codec: "h264", quality: "2160p", host: "b")
    let c = try file(codec: "hevc", quality: "1080p", host: "c")
    XCTAssertEqual([a, b, c].dedupedByQuality.map(\.codec), ["hevc", "hevc"])
  }

  // MARK: - Kinopoisk extras models

  func testKpFactAndReviewDecode() throws {
    let factsJSON = """
    {"items":[{"text":"A fact","type":"FACT","spoiler":false},
              {"text":"A blooper","type":"BLOOPER","spoiler":true}]}
    """.data(using: .utf8)!
    struct Envelope: Decodable { let items: [KpFact] }
    let facts = try JSONDecoder().decode(Envelope.self, from: factsJSON).items
    XCTAssertEqual(facts.count, 2)
    XCTAssertTrue(facts[1].isBlooper)
    XCTAssertEqual(facts[1].spoiler, true)

    let reviewsJSON = """
    {"total":1,"totalPositiveReviews":1,"totalNegativeReviews":0,"totalNeutralReviews":0,
     "items":[{"kinopoiskId":1,"type":"POSITIVE","date":"2020-01-01","author":"A","title":"T","description":"Body"}]}
    """.data(using: .utf8)!
    let page = try JSONDecoder().decode(KpReviewsPage.self, from: reviewsJSON)
    XCTAssertEqual(page.items.first?.author, "A")
    XCTAssertEqual(page.totalPositiveReviews, 1)
  }
}
