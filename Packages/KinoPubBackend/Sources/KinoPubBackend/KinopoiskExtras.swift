//
//  KinopoiskExtras.swift
//
//  Rich detail-screen extras (facts, reviews, full crew with characters, stills) that
//  kino.pub's own API doesn't expose. They come from the kpapp.link "kpapi" proxy over
//  the Kinopoisk unofficial API — public, no key required — keyed by the title's
//  Kinopoisk id:
//    https://kpapp.link/kpapi/films/<kinopoiskId>/{facts,reviews,staff,images}
//
//  Ported from dungeon-master-xx/kinopub-apple-client. Verified live (2026-07): facts /
//  reviews / images return 200 with no auth headers. Best-effort — empty on failure.
//

import Foundation

// MARK: - Models

/// A trivia fact or goof ("киноляп"). `type` is "FACT" or "BLOOPER".
public struct KpFact: Decodable, Identifiable, Hashable {
  public let text: String
  public let type: String?
  public let spoiler: Bool?

  public var id: String { text }
  public var isBlooper: Bool { (type ?? "").uppercased() == "BLOOPER" }
}

private struct KpFactsResponse: Decodable {
  let items: [KpFact]
}

/// A user review. `type` is "POSITIVE" / "NEGATIVE" / "NEUTRAL".
public struct KpReview: Decodable, Identifiable, Hashable {
  public let kinopoiskId: Int?
  public let type: String?
  public let date: String?
  public let author: String?
  public let title: String?
  public let description: String?

  public var id: String { "\(kinopoiskId ?? 0)-\(title ?? "")-\(date ?? "")" }
}

public struct KpReviewsPage: Decodable, Hashable {
  public let total: Int?
  public let totalPositiveReviews: Int?
  public let totalNegativeReviews: Int?
  public let totalNeutralReviews: Int?
  public let items: [KpReview]

  public static let empty = KpReviewsPage(
    total: 0,
    totalPositiveReviews: 0,
    totalNegativeReviews: 0,
    totalNeutralReviews: 0,
    items: []
  )
}

/// A crew/cast member with their role and (for actors) the character they play.
public struct KpStaffMember: Decodable, Identifiable, Hashable {
  public let staffId: Int
  public let nameRu: String?
  public let nameEn: String?
  /// The character played (actors) — Kinopoisk calls this `description`.
  public let description: String?
  public let posterUrl: String?
  public let professionText: String?
  public let professionKey: String?

  public var id: Int { staffId }
  public var displayName: String {
    let ru = (nameRu ?? "").trimmingCharacters(in: .whitespaces)
    if !ru.isEmpty { return ru }
    return (nameEn ?? "").trimmingCharacters(in: .whitespaces)
  }
}

/// A still / promotional image.
public struct KpImage: Decodable, Identifiable, Hashable {
  public let imageUrl: String?
  public let previewUrl: String?

  public var id: String { previewUrl ?? imageUrl ?? UUID().uuidString }
}

private struct KpImagesResponse: Decodable {
  let items: [KpImage]
}

// MARK: - Service

public final class KinopoiskExtrasService: @unchecked Sendable {
  private let session: URLSession
  private let baseURL: String

  public init(
    session: URLSession = .shared,
    baseURL: String = "https://kpapp.link/kpapi/films"
  ) {
    self.session = session
    self.baseURL = baseURL
  }

  private func fetch<T: Decodable>(_ filmId: Int, _ resource: String) async throws -> T {
    guard let url = URL(string: "\(baseURL)/\(filmId)/\(resource)") else {
      throw URLError(.badURL)
    }
    let (data, response) = try await session.data(from: url)
    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw URLError(.badServerResponse)
    }
    return try JSONDecoder().decode(T.self, from: data)
  }

  public func facts(filmId: Int) async throws -> [KpFact] {
    let response: KpFactsResponse = try await fetch(filmId, "facts")
    return response.items
  }

  public func reviews(filmId: Int) async throws -> KpReviewsPage {
    try await fetch(filmId, "reviews")
  }

  public func staff(filmId: Int) async throws -> [KpStaffMember] {
    try await fetch(filmId, "staff")
  }

  public func images(filmId: Int) async throws -> [KpImage] {
    let response: KpImagesResponse = try await fetch(filmId, "images")
    return response.items
  }
}
