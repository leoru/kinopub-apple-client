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

    /// Combines **every source the caller supplied**, weighted by how many people
    /// voted. 6.0 from 4,867 voters next to 1.0 from 7 is a 6.0 title, not the 3.5 a
    /// plain mean would print. A source that reports no count still counts, but as a
    /// single vote, so it can never outweigh a real audience. Zero means "not rated"
    /// in the API, so it counts as missing.
    ///
    /// `weights` is the user's say over that: a multiplier per source, `0` to leave
    /// one out. Everything is on and equal by default — see `RatingWeights`.
    public init?(scores: MediaScores, weights: RatingWeights = .default) {
        let sources = scores.inputs
            .compactMap { input -> (score: Double, weight: Double)? in
                guard let score = input.score, score > 0 else { return nil }
                let weight = Double(max(input.votes ?? 0, 1)) * weights.weight(for: input.id)
                guard weight > 0 else { return nil }
                return (score, weight)
            }
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
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
//            return AnyShapeStyle(Color.green.gradient)
        case .average:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .poor:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
//            return AnyShapeStyle(Color.red.gradient)
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
        .init(color: .white.opacity(0.4), location: 0.0),
        .init(color: .white.opacity(0), location: 0.4),
        .init(color: .white.opacity(0.4), location: 1.0)
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
            return rating.tier.showsWings ? .black : .white
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
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(badgeGlassStroke, lineWidth: 0.5)
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

/// Five stars filled to a fraction — the App Store's shape for "how good, at a
/// glance", next to the number that says it precisely.
///
/// Takes a **0…5** value, so a 10-point `Rating` is halved by the caller rather than
/// this view guessing which scale it was handed. The empty stars are `.quaternary`
/// (a hierarchical style, not a colour), and the filled ones take the tier colour the
/// rest of the app already gives that score.
public struct StarRatingRow: View {
    private let value: Double
    private let tint: Color
    private let font: Font

    public init(value: Double, tint: Color = .yellow, font: Font = .title) {
        self.value = value
        self.tint = tint
        self.font = font
    }

    /// Convenience for the 10-point aggregate every score in this app is on.
    public init(rating: Rating, font: Font = .title) {
        self.init(value: rating.rounded / 2, tint: rating.tier.color, font: font)
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: symbol(at: index))
            }
        }
        .foregroundStyle(tint)
        .font(font)
        .accessibilityElement()
        .accessibilityLabel(Text(String(format: "%.1f", clamped)))
    }

    private var clamped: Double { min(max(value, 0), 5) }

    /// Rounded to the nearest half so a star is full, half or empty — the three
    /// symbols the system draws. A continuous mask over five filled stars can paint
    /// 0.13 of a star, which is a fill percentage, not a rating.
    private func symbol(at index: Int) -> String {
        let halves = (clamped * 2).rounded()
        let filled = Double(index) * 2
        if halves >= filled + 2 { return "star.fill" }
        if halves >= filled + 1 { return "star.leadinghalf.filled" }
        return "star"
    }
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
            return rating.tier.showsWings ? .black : .white
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
        .padding(.horizontal, (showBackground && showWings) ? 8 : showBackground ? 12 : 0)
        .padding(.vertical, showBackground ? 4 : 0)
        .background(
            showBackground ? rating.tier.background : AnyShapeStyle(Color.clear),
            in: Capsule()
        )
        .overlay {
            if showBackground {
                Capsule()
                    .strokeBorder(badgeGlassStroke, lineWidth: 0.5)
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
    static let wingHeight: CGFloat = 30
    static let wingSpacing: CGFloat = 4
    #endif
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        ForEach([9.1, 7.4, 6.2, 4.8], id: \.self) { score in
            if let rating = Rating(imdb: score, kinopoisk: score) {
                HStack(spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Badge").font(.callout).foregroundColor(.gray)
                        RatingBadgeView(rating: rating)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aggregate").font(.callout).foregroundColor(.gray)
                        AggregateRatingLabel(rating: rating)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No BG").font(.callout).foregroundColor(.gray)
                        RatingBadgeView(rating: rating, showBackground: false, showWings: true)
                    } 
                }
            }
        }
    }
    .padding()
//  .background(Color.black)
}
