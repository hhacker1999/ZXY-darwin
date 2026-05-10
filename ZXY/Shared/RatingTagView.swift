import Foundation
import SwiftUI

enum RatingSource {
    case imdb, tmdb

    var accentColor: Color {
        switch self {
        case .imdb: return Color(hex: "#F5C518")  // IMDB gold
        case .tmdb: return Color(hex: "#01B4E4")  // TMDB blue
        }
    }

    var label: String {
        switch self {
        case .imdb: return "IMDb"
        case .tmdb: return "TMDb"
        }
    }
}

struct RatingTagView: View {
    let rating: String?
    let source: RatingSource
    let isMobile: Bool

    var body: some View {
        if let rating = rating {
            HStack(spacing: 6) {
                Text(source.label)
                    .font(
                        .system(
                            size: isMobile ? 9 : 10,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(AppTheme.Colors.elementSubtle)
                Text(rating)
                    .font(
                        .system(
                            size: isMobile ? 11 : 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(source.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
    }
}
