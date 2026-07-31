import SwiftUI

/// Required TMDB attribution (API Terms). Kinopoisk extras always have a keyless
/// third-party path (kpapp.link); the keyed unofficial API is optional enrichment.
/// Exact required wording from those services' terms hasn't been checked —
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

      Text("Kinopoisk")
        .font(.title2.weight(.bold))
        .foregroundStyle(Color.KinoPub.text)
        .padding(.top, 4)

      Text("Facts, stills, reviews and some cast details come from a third-party Kinopoisk data proxy (kpapp.link), not an official Kinopoisk product.")
        .font(.footnote)
        .foregroundStyle(Color.KinoPub.subtitle)
        .fixedSize(horizontal: false, vertical: true)

      if KinopoiskKeyValidation.isValidated {
        Text("Awards and richer metadata also use your own Kinopoisk Unofficial API key (kinopoiskapiunofficial.tech).")
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
