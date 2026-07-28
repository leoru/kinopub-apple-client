import SwiftUI

/// Required TMDB attribution (API Terms). Official logo asset can replace the
/// wordmark later; the mandatory disclaimer ships either way. The Kinopoisk
/// block only shows once the user has their own validated key configured —
/// unlike TMDB (always on via the shared proxy), Kinopoisk is per-user opt-in,
/// so there's nothing to disclose until they've turned it on. Exact required
/// wording from kinopoiskapiunofficial.tech's own terms hasn't been checked —
/// this is a conservative placeholder, not confirmed language.
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

      if KinopoiskKeyValidation.isValidated {
        Text("Kinopoisk")
          .font(.title2.weight(.bold))
          .foregroundStyle(Color.KinoPub.text)
          .padding(.top, 4)

        Text("Photos, facts and awards are fetched using your own Kinopoisk Unofficial API key — a third-party service, not an official Kinopoisk product.")
          .font(.footnote)
          .foregroundStyle(Color.KinoPub.subtitle)
          .fixedSize(horizontal: false, vertical: true)

        Link(destination: URL(string: "https://kinopoiskapiunofficial.tech")!) {
          Text("kinopoiskapiunofficial.tech")
            .font(.footnote)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
