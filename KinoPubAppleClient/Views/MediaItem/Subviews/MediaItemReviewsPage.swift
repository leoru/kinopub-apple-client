//
//  MediaItemReviewsPage.swift
//  KinoPubAppleClient
//

import SwiftUI
import KinoPubUI
import KinoPubBackend
import KinoPubMetadata

/// What the Ratings and Reviews block opens — every card in it leads here.
///
/// The rail's cards are previews: one headline, five lines, a footer, cut to a fixed
/// height. This is where a review is actually read, so the same `BlockCard` runs full
/// width with no line limit, under the same ratings card and the review tally.
///
/// Nothing here fetches. It all travelled in the route, because it was already merged
/// into the item's metadata before the header could be tapped — which is also why the
/// destination exists even on a title nobody has reviewed: the block always leads
/// somewhere, and here that somewhere is the scores plus an honest empty note.
///
/// Not built for tvOS — a navigating section header is an iOS/macOS affordance.
struct MediaItemRatingsAndReviewsPage: View {
  let payload: RatingsAndReviews

  private var reviews: [Review] { payload.reviews }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: BlockMetrics.spacing) {
        // The aggregate without its chip row: on a page there is width for the
        // sources to be rows of their own, named and linked, instead of four marks
        // and four numbers with nothing saying which is which.
        MediaItemRatingsCard(mediaItem: payload.item,
                             externalMetadata: payload.metadata,
                             likeCount: payload.likeCount,
                             dislikeCount: payload.dislikeCount,
                             reviewCount: reviewCount,
                             showsSources: false)
        if !scores.isEmpty {
          MediaItemRatingSourceRows(scores: scores)
        }
        if let summary = payload.summary, !summary.isEmpty, !reviews.isEmpty {
          ReviewsSummaryCard(summary: summary, width: nil)
        }
        if reviews.isEmpty {
          emptyNote
        } else {
          ForEach(reviews) { review in
            ReviewCard(review: review, mode: .expanded, sourceURL: kinopoiskReviewsURL)
          }
        }
      }
      .padding(.horizontal, MediaItemLayout.horizontalInset)
      .padding(.vertical, MediaItemLayout.sectionSpacing)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .platformNavigationTitle(payload.item.localizedTitle)
    .background(Color.KinoPub.background.ignoresSafeArea())
  }

  private var reviewCount: Int {
    let total = payload.summary.map(\.total) ?? 0
    return total > 0 ? total : reviews.count
  }

  private var scores: [RatingSources.Score] {
    RatingSources.scores(for: payload.item,
                         metadata: payload.metadata,
                         likeCount: payload.likeCount,
                         dislikeCount: payload.dislikeCount)
  }

  /// The title's review list at the source. **Not a permalink to one review** — the
  /// proxy gives the review's id but Kinopoisk's own review URL is built from a user
  /// id we never receive, so "where this came from" is as precise as we can be
  /// (`docs/providers/kinopoisk-proxy.md`).
  private var kinopoiskReviewsURL: URL? {
    guard let id = payload.item.kinopoisk, id > 0 else { return nil }
    let kind = payload.item.isSeries ? "series" : "film"
    return URL(string: "https://www.kinopoisk.ru/\(kind)/\(id)/reviews/")
  }

  private var emptyNote: some View {
    BlockCard {
      Text("MediaItem_NoReviews")
        .font(TypeScale.detailBody)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

}

#Preview("Ratings and reviews page") {
  var metadata = TitleMetadata()
  metadata.reviews = [
    Review(author: "Арсений П.",
           title: "",
           body: "Фильмы философской тематики занимают отдельное место в кинематографическом пьедестале.\n\nНе каждому зрителю дано понять смысл, который художник вкладывает в нутро киноленты.",
           sentiment: "POSITIVE",
           date: "2022-02-18T21:51:09",
           postedAt: Date(timeIntervalSince1970: 1_645_217_469),
           helpfulVotes: 3,
           unhelpfulVotes: 2),
    Review(author: "Lintandil",
           title: "Аромат беды",
           body: "Высочайший пик технических достижений в кинематографе на тот момент.",
           sentiment: "NEUTRAL",
           date: "2015-02-28T12:57:52",
           postedAt: Date(timeIntervalSince1970: 1_425_124_672),
           helpfulVotes: 7,
           unhelpfulVotes: 2)
  ]
  metadata.reviewsSummary = ReviewsSummary(total: 11, positive: 7, negative: 1, neutral: 3)
  metadata.tmdbRating = 6.3
  metadata.tmdbVotes = 1536

  return NavigationStack {
    MediaItemRatingsAndReviewsPage(
      payload: RatingsAndReviews(item: MediaItem.mock(),
                                 metadata: metadata,
                                 likeCount: 548,
                                 dislikeCount: 12)
    )
  }
  .preferredColorScheme(.dark)
}
