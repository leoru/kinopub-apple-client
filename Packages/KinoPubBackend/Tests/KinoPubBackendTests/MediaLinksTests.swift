//
//  MediaLinksTests.swift
//
//  `nolinks=1` on item details, and the separate media-links call that replaces what it
//  leaves out.
//

import XCTest
@testable import KinoPubBackend

final class MediaLinksTests: XCTestCase {

  func testDetailsRequestSendsNoLinksOnlyWhenAsked() {
    XCTAssertNil(ItemDetailsRequest(id: "18044").parameters)
    let stripped = ItemDetailsRequest(id: "18044", excludeLinks: true)
    XCTAssertEqual(stripped.path, "/v1/items/18044")
    XCTAssertEqual(stripped.parameters?["nolinks"] as? Int, 1)
  }

  func testMediaLinksRequestAsksForOneMedia() {
    let request = MediaLinksRequest(mediaId: 992)
    XCTAssertEqual(request.path, "/v1/items/media-links")
    XCTAssertEqual(request.parameters?["mid"] as? Int, 992)
    XCTAssertTrue(request.forceSendAsGetParams)
  }

  /// media-links names the link bag `urls`; item details names the same thing `url`.
  func testDecodesFilesFromTheUrlsKeyAndSubtitles() throws {
    let json = Data("""
    {
      "files": [
        {
          "codec": "hevc",
          "w": 1920,
          "h": 1080,
          "quality": "1080p",
          "quality_id": 3,
          "file": "/b/8c/x.mp4",
          "urls": {
            "http": "https://host/t/file.mp4",
            "hls": "https://host/t/hls.m3u8",
            "hls4": "https://host/t/hls4.m3u8",
            "hls2": "https://host/t/hls2.m3u8"
          }
        }
      ],
      "subtitles": [
        {"lang": "eng", "shift": 0, "embed": true, "file": "/a/71/1.srt", "url": "https://host/t/1.srt"}
      ]
    }
    """.utf8)

    let links = try JSONDecoder().decode(MediaLinks.self, from: json)
    XCTAssertEqual(links.files.count, 1)
    XCTAssertEqual(links.files.first?.quality, "1080p")
    XCTAssertEqual(links.files.first?.qualityID, 3)
    XCTAssertEqual(links.files.first?.codec, "hevc")
    XCTAssertEqual(links.files.first?.url.hls4, "https://host/t/hls4.m3u8")
    XCTAssertEqual(links.subtitles.first?.lang, "eng")
  }

  /// The shape a `nolinks=1` details response actually returns: the ladder is described,
  /// with no link bag under any key. This must decode — requiring one failed the whole
  /// item at `item.seasons[0].episodes[0].files[0]` and left every series page on
  /// "Couldn't Load".
  func testDecodesALinklessFileAndReportsItUnplayable() throws {
    let json = Data("""
    {
      "codec": "h264",
      "file": "/e/0a/bf519a7514cb698066960a61a35f8b20.mp4",
      "h": 1080,
      "quality": "1080p",
      "quality_id": 3,
      "w": 1920
    }
    """.utf8)

    let file = try JSONDecoder().decode(FileInfo.self, from: json)
    XCTAssertEqual(file.quality, "1080p")
    XCTAssertEqual(file.codec, "h264")
    XCTAssertEqual(file.h, 1080)
    XCTAssertFalse(file.hasPlayableURL)
    XCTAssertFalse([file].hasPlayableURLs)
  }

  func testAFileWithLinksIsPlayable() throws {
    let file = FileInfo(codec: "h264",
                        w: 1920,
                        h: 1080,
                        quality: "1080p",
                        qualityID: 3,
                        url: URLInfo(http: "", hls: "", hls4: "https://host/x.m3u8", hls2: ""))
    XCTAssertTrue(file.hasPlayableURL)
    XCTAssertTrue([file].hasPlayableURLs)
  }

  func testDecodesFilesFromTheItemsShapedUrlKey() throws {
    let json = Data("""
    {
      "codec": "h264",
      "w": 1280,
      "h": 720,
      "quality": "720p",
      "quality_id": 2,
      "url": {
        "http": "https://host/t/file.mp4",
        "hls": "https://host/t/hls.m3u8",
        "hls4": "https://host/t/hls4.m3u8",
        "hls2": "https://host/t/hls2.m3u8"
      }
    }
    """.utf8)

    let file = try JSONDecoder().decode(FileInfo.self, from: json)
    XCTAssertEqual(file.url.http, "https://host/t/file.mp4")
    XCTAssertEqual(file.quality, "720p")
  }

  /// `DownloadMeta` on disk holds encoded `FileInfo`s — a round trip must survive the
  /// dual-key decoding.
  func testFileInfoRoundTripsThroughItsOwnEncoding() throws {
    let original = FileInfo(codec: "hevc",
                            w: 3840,
                            h: 2160,
                            quality: "2160p",
                            qualityID: 4,
                            url: URLInfo(http: "a", hls: "b", hls4: "c", hls2: "d"))
    let data = try JSONEncoder().encode(original)
    XCTAssertEqual(try JSONDecoder().decode(FileInfo.self, from: data), original)
  }

  func testMissingSubtitlesDecodeAsEmpty() throws {
    let json = Data(#"{"files": []}"#.utf8)
    let links = try JSONDecoder().decode(MediaLinks.self, from: json)
    XCTAssertTrue(links.files.isEmpty)
    XCTAssertTrue(links.subtitles.isEmpty)
  }

  func testEpisodicTypesAreKnownFromTheCardAlone() {
    XCTAssertTrue(MediaItem.mock(type: "serial").isEpisodicType)
    XCTAssertTrue(MediaItem.mock(type: "docuserial").isEpisodicType)
    XCTAssertTrue(MediaItem.mock(type: "tvshow").isEpisodicType)
    XCTAssertFalse(MediaItem.mock(type: "movie").isEpisodicType)
    XCTAssertFalse(MediaItem.mock(type: "documovie").isEpisodicType)
  }
}
