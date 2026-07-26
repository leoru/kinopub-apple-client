import SwiftUI

/// Required TMDB attribution (API Terms). Official logo asset can replace the
/// wordmark later; the mandatory disclaimer ships either way.
struct DataSourcesAttributionView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("TMDB")
        .font(.title2.weight(.bold))
        .foregroundStyle(Color.KinoPub.text)

      Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
        .font(.footnote)
        .foregroundStyle(Color.KinoPub.subtitle)
        .fixedSize(horizontal: false, vertical: true)

      Link(destination: URL(string: "https://www.themoviedb.org")!) {
        Text("themoviedb.org")
          .font(.footnote)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
