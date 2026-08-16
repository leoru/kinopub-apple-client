//
//  RatingBadgeView.swift
//
//

import Foundation
import SwiftUI

/// Our own averaged score: the poster plaque, the hero pill, the detail "Rating"
/// tile, and the card Rating placement / source settings that drive them.
///
/// Source numbers live in `MediaScores`. This type is only the weighted aggregate
/// derived from them — views never re-weigh loose API fields.
///
/// Off while the aggregate is being reworked — until then IMDb and Kinopoisk show
/// only under their own logos, never folded into one number. An off flag hides the
/// settings too, so nothing points at chrome that cannot appear.
public enum RatingFeature {
    public static let combinedEnabled = true
}

/// A single score combining the IMDb and Kinopoisk ratings.
///
/// Built from `MediaScores` — the views never re-weigh loose optionals themselves.
public struct Rating {
    public let value: Double

    /// Combines the two sources, **weighted by how many people voted**. 6.0 from 4,867
    /// voters next to 1.0 from 7 is a 6.0 title, not the 3.5 a plain mean of the two
    /// numbers would print. A source that reports no count still counts, but as a single
    /// vote, so it can never outweigh a real audience. Zero means "not rated" in the API,
    /// so it counts as missing.
    public init?(scores: MediaScores) {
        let sources = [
            (scores.imdb ?? 0, scores.imdbVotes ?? 0),
            (scores.kinopoisk ?? 0, scores.kinopoiskVotes ?? 0)
        ]
            .filter { $0.0 > 0 }
            .map { (score: $0.0, weight: Double(max($0.1, 1))) }
        guard !sources.isEmpty else { return nil }
        let total = sources.reduce(0) { $0 + $1.weight }
        value = sources.reduce(0) { $0 + $1.score * $1.weight } / total
    }

    public init?(imdb: Double?,
                 imdbVotes: Int? = nil,
                 kinopoisk: Double?,
                 kinopoiskVotes: Int? = nil) {
        self.init(scores: MediaScores(
            imdb: imdb,
            imdbVotes: imdbVotes,
            kinopoisk: kinopoisk,
            kinopoiskVotes: kinopoiskVotes
        ))
    }

    public enum Tier {
        case awarded   // 8.0+
        case good      // 7.0…8.0
        case average   // 6.0…7.0
        case poor      // below 6.0
    }

    /// The value as shown, to one decimal. Tiering off this rather than the raw average
    /// keeps the colour honest: a 7.95 that reads "8.0" gets the 8.0 treatment.
    public var rounded: Double {
        (value * 10).rounded() / 10
    }

    public var tier: Tier {
        switch rounded {
        case 8...: return .awarded
        case 7..<8: return .good
        case 6..<7: return .average
        default: return .poor
        }
    }

    public var formatted: String {
        String(format: "%.1f", rounded)
    }
}

public extension Rating.Tier {
    var color: Color {
        switch self {
        case .awarded: return Color.yellow
        case .good: return Color.green
        case .average: return Color.gray
        case .poor: return Color.red
        }
    }
    
    var background: AnyShapeStyle {
        switch self {
        case .awarded:
            return AnyShapeStyle(Color.yellow.gradient)
        case .good:
            return AnyShapeStyle(Color.green.gradient)
        case .average:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .poor:
            return AnyShapeStyle(Color.red.gradient)
        }
    }

    /// Only the top tier earns the laurel wings.
    var showsWings: Bool {
        self == .awarded
    }
    
    var common: Bool {
        self == .average
    }
}

/// Вспомогательный градиент для обводки бейджей ("эффект дешевого стеклышка")
private let badgeGlassStroke = LinearGradient(
    stops: [
        .init(color: .white.opacity(0.8), location: 0.0),
        .init(color: .white.opacity(0), location: 0.4),
        .init(color: .white, location: 1.0)
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

/// Score plaque for the top-left corner of a poster.
public struct RatingBadgeView: View {
    private let rating: Rating
    private let showBackground: Bool
    private let showWings: Bool
    
    public init(rating: Rating, showBackground: Bool = true, showWings: Bool = true) {
        self.rating = rating
        self.showBackground = showBackground
        self.showWings = showWings
    }
    
    private var contentColor: Color {
        if showBackground {
            return rating.tier.common ? .white : .black
        } else {
            return rating.tier.color
        }
    }
    
    public var body: some View {
        HStack(spacing: 3) {
            if showWings && rating.tier.showsWings {
                wing(mirrored: false)
            }
            
            Text(rating.formatted)
                .font(TypeScale.ratingBadge)
                .fontDesign(.rounded)
                .foregroundStyle(contentColor)
            
            if showWings && rating.tier.showsWings {
                wing(mirrored: true)
            }
        }
        // Паддинги обнуляются, если выключен фон, чтобы голый текст не разъезжался
        .padding(.horizontal, showBackground ? ((showWings && rating.tier.showsWings) ? Self.horizontalPadding / 2 : Self.horizontalPadding) : 0)
        .padding(.vertical, showBackground ? Self.verticalPadding : 0)
        .background(
            showBackground ? rating.tier.background : AnyShapeStyle(Color.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay {
            if showBackground {
                RoundedRectangle(cornerRadius: 6.5)
                    .strokeBorder(badgeGlassStroke, lineWidth: 1)
            }
        }
    }
    
    private func wing(mirrored: Bool) -> some View {
        Image("wing", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: Self.wingHeight)
            .foregroundStyle(contentColor)
            .scaleEffect(x: mirrored ? -1 : 1)
    }
    
    #if os(tvOS)
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 2
    static let wingHeight: CGFloat = 24
    #else
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 2
    static let wingHeight: CGFloat = 14
    #endif
}

/// Large aggregate score for the detail ratings row: coloured digits and laurel
/// wings when the tier earns them — not the poster capsule.
public struct AggregateRatingLabel: View {
    private let rating: Rating
    private let showBackground: Bool
    private let showWings: Bool
    
    public init(rating: Rating, showBackground: Bool = true, showWings: Bool = true) {
        self.rating = rating
        self.showBackground = showBackground
        self.showWings = showWings
    }
    
    private var contentColor: Color {
        if showBackground {
            return rating.tier.common ? .white : .black
        } else {
            return rating.tier.color
        }
    }
    
    public var body: some View {
        HStack(spacing: Self.wingSpacing) {
            if showWings && rating.tier.showsWings {
                wing(mirrored: false)
            }
            
            Text(rating.formatted)
                .font(TypeScale.ratingAggregate)
                .foregroundStyle(contentColor)
            
            if showWings && rating.tier.showsWings {
                wing(mirrored: true)
            }
        }
        .padding(.horizontal, showBackground ? 18 : (showBackground && showWings) ? 8 : 0)
        .padding(.vertical, showBackground ? 6 : 0)
        .background(
            showBackground ? rating.tier.background : AnyShapeStyle(Color.clear),
            in: Capsule()
        )
        .overlay {
            if showBackground {
                Capsule()
                    .strokeBorder(badgeGlassStroke, lineWidth: 1)
            }
        }
    }
    
    private func wing(mirrored: Bool) -> some View {
        Image("wing", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: Self.wingHeight)
            .foregroundStyle(contentColor)
            .scaleEffect(x: mirrored ? -1 : 1)
    }
    
    #if os(tvOS)
    static let wingHeight: CGFloat = 40
    static let wingSpacing: CGFloat = 8
    #else
    static let wingHeight: CGFloat = 22
    static let wingSpacing: CGFloat = 4
    #endif
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        ForEach([9.1, 7.4, 6.2, 4.8], id: \.self) { score in
            if let rating = Rating(imdb: score, kinopoisk: score) {
                HStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badge").font(.caption).foregroundColor(.gray)
                        RatingBadgeView(rating: rating)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aggregate").font(.caption).foregroundColor(.gray)
                        AggregateRatingLabel(rating: rating)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No BG").font(.caption).foregroundColor(.gray)
                        RatingBadgeView(rating: rating, showBackground: false, showWings: true)
                    }
                }
            }
        }
    }
    .padding()
//  .background(Color.black)
}
