//
//  MediaItemModel.swift
//  KinoPubAppleClient
//
//  Created by Kirill Kunst on 2.08.2023.
//

import Combine
import Foundation
import KinoPubBackend
import OSLog
import KinoPubLogging
import KinoPubKit
import KinoPubMetadata
import KinoPubUI

/// The viewer's own kino.pub thumbs vote for a title. Votes are one-shot server-side.
enum MediaItemUserVote: Equatable {
  case none
  case up
  case down
}

@MainActor
class MediaItemModel: ObservableObject {

  private var itemsService: VideoContentService
  private var downloadManager: DownloadManager<DownloadMeta>
  private var errorHandler: ErrorHandler
  private var metadataService: MetadataService
  public var linkProvider: NavigationLinkProvider
  public var mediaItemId: Int
  
  @Published public var mediaItem: MediaItem = MediaItem.mock()
  @Published public var itemLoaded: Bool = false
  /// True after `fetchDetails` fails — the page shows `UnavailableView` instead of a stuck spinner.
  @Published public var loadFailed: Bool = false
  /// The failure behind `loadFailed`, so the retry state can say what actually went wrong.
  @Published public var loadError: Error?

  /// "More like this", loaded alongside the page. Empty until it arrives, and left
  /// empty when it fails — the section hides itself rather than erroring over the art.
  @Published public var similarItems: [MediaItem] = []

  /// The author shelf — every credited director/creator at once, `/v1/items?director=`.
  /// Empty + loaded hides the section; not-yet-loaded shows a skeleton rail.
  @Published public var moreFromDirector: [MediaItem] = []
  @Published public var moreFromDirectorLoaded: Bool = false
  /// The cast shelf — `/v1/items?cast=`, scoped by `CastShelfPolicy`: one actor for a
  /// film, every performer for a concert or a stand-up set.
  @Published public var moreWithActor: [MediaItem] = []
  @Published public var moreWithActorLoaded: Bool = false

  /// The collections this title sits in, each with its own items — one shelf per
  /// collection, and the page's only editorial recommendation.
  @Published public var collectionShelves: [CollectionShelf] = []

  /// The floor under the related area: more of the same type and genre, asked for only
  /// when everything above came back empty, so a concert or a TV show is never a page
  /// that recommends nothing.
  @Published public var moreInGenre: [MediaItem] = []
  @Published public var moreInGenreTitle: String?
  /// The genres actually asked for — part of the row's id, so a shelf can never be
  /// mistaken for the previous page's.
  private(set) var moreInGenreGenreIDs: [Int] = []

  /// Answered-or-failed flags. The genre floor waits on **all** of them: "still empty"
  /// and "came back empty" are different states, and firing on the first one asked for
  /// comedies while a concert's payload was still in flight.
  private var similarLoaded = false
  private var collectionsLoaded = false

  /// One collection the current title belongs to, with what is in it.
  public struct CollectionShelf: Identifiable {
    public let collection: Collection
    public let items: [MediaItem]
    public var id: Int { collection.id }
  }

  /// All bookmark folders, and the ids of those already holding this item.
  @Published public var folders: [Bookmark] = []
  @Published public var folderIDsContainingItem: Set<Int> = []
  @Published public var isWatched: Bool = false
  @Published public var myVote: MediaItemUserVote = .none
  @Published public var likeCount: Int = 0
  @Published public var dislikeCount: Int = 0
  /// Glyph + Title confirmation for hero library actions. Cleared by the view
  /// modifier as soon as presentation starts.
  @Published public var hudToast: HudToast?

  /// TMDB (and later other sources) overlay. Empty when the proxy is unset or the
  /// title has no IMDb id — the page then draws exactly as before.
  @Published public var externalMetadata: TitleMetadata = TitleMetadata()

  /// True once `loadExternalMetadata` finishes or is skipped. Cast photos wait on
  /// this before falling back to the pushbr CDN so URLs don't swap mid-paint.
  @Published public var externalMetadataLoaded: Bool = false

  /// Season number → episode schedules from TMDB. Loaded on demand per season.
  @Published public var seasonSchedules: [Int: [EpisodeSchedule]] = [:]

  private var actionsService: UserActionsService
  private var contentStore: ContentStore
  private var collectionsService: CollectionsService
  private var libraryState: MediaLibraryStore
  private var identity: MediaIdentity?

  public var isBookmarked: Bool { !folderIDsContainingItem.isEmpty }

  /// The people behind the author shelf — **one request each**, because `/v1/items`
  /// matches `director` against the credits as written and a comma-joined pair matches
  /// nothing (verified live). Two names, so a co-directed film asks about both without
  /// turning a shelf into a crawl.
  ///
  /// Empty where the shelf has no meaning — a concert's director is a TV credit nobody
  /// follows (`MediaPresentationProfile.showsAuthorShelf`).
  public var shelfAuthors: [MediaPerson] {
    guard mediaItem.presentation.showsAuthorShelf else { return [] }
    return MediaPerson.each(of: mediaItem.directorNames,
                            role: .director,
                            limit: Self.creditQueryLimit)
  }

  /// How the author shelf is labelled: director or creator, one or several. With two
  /// names there is no single one to print, so the header names the role instead.
  public var authorShelfTitle: String {
    mediaItem.presentation.authorShelfTitleKey(count: shelfAuthors.count).localized
  }

  /// Who the cast shelf asks for — again one request per name. A film asks about its
  /// billed lead; a concert or a stand-up set asks about the two people on stage, who
  /// *are* the title. Empty for animation, where `cast` is the voice actors
  /// (`MediaPresentationProfile.showsCastShelf`).
  public var shelfCast: [MediaPerson] {
    let profile = mediaItem.presentation
    guard profile.showsCastShelf else { return [] }
    return MediaPerson.each(of: mediaItem.castMembers,
                            role: .actor,
                            limit: profile.castShelf.nameLimit)
  }

  /// Role-worded for the stage kinds ("More from These Comedians"), and the actor's own
  /// name everywhere else, which reads better when there is exactly one of them.
  public var castShelfTitle: String {
    let cast = shelfCast
    guard let first = cast.first else { return "" }
    if let key = mediaItem.presentation.castShelfTitleKey(count: cast.count) {
      return key.localized
    }
    return String(format: "More with %@".localized, first.name)
  }

  /// Two names per shelf: each one is its own request.
  private static let creditQueryLimit = 2

  /// Similar + person-credit shelves as one data-driven list — the same `MediaRow`
  /// shape `MediaRowsView` renders on Home, so the detail page's related rows go
  /// through the identical rendering + cross-row focus-memory mechanism instead of
  /// being three independently-wired shelves (see `MediaItemRelatedRowsSection`).
  /// A row is only included once its query has actually returned something; the
  /// still-loading state is `pendingRelatedShelfTitles` below, kept separate because
  /// `MediaRow` has no notion of "loading."
  public var relatedRows: [MediaRow] {
    var rows: [MediaRow] = []
    if !similarItems.isEmpty {
      rows.append(MediaRow(id: "similar", title: "Similar".localized, cards: similarItems.map(MediaCard.init)))
    }
    // `destination` on the person rows is what makes their header navigate to that
    // person's page — the shelves' one route to it besides a cast circle. A shelf
    // standing for several directors has no one page to open, so it gets no header
    // link rather than an arbitrary one.
    let authors = shelfAuthors
    if let first = authors.first, !moreFromDirector.isEmpty {
      rows.append(MediaRow(id: "director-\(first.id)",
                           title: authorShelfTitle,
                           cards: moreFromDirector.map(MediaCard.init),
                           destination: authors.count == 1 ? linkProvider.person(for: first) : nil))
    }
    let cast = shelfCast
    if let first = cast.first, !moreWithActor.isEmpty {
      rows.append(MediaRow(id: "actor-\(first.id)",
                           title: castShelfTitle,
                           cards: moreWithActor.map(MediaCard.init),
                           destination: cast.count == 1 ? linkProvider.person(for: first) : nil))
    }
    // Editorial, and the only shelf on the page somebody actually assembled by hand —
    // so it follows the queries rather than opening over them.
    for shelf in collectionShelves where !shelf.items.isEmpty {
      rows.append(MediaRow(id: "collection-\(shelf.collection.id)",
                           title: shelf.collection.title,
                           cards: shelf.items.map(MediaCard.init),
                           destination: linkProvider.collection(shelf.collection)))
    }
    if !moreInGenre.isEmpty, let title = moreInGenreTitle {
      let id = moreInGenreGenreIDs.map(String.init).joined(separator: "-")
      rows.append(MediaRow(id: "genre-\(id)", title: title, cards: moreInGenre.map(MediaCard.init)))
    }
    return rows
  }

  /// Titles for person shelves still in flight — rendered as skeleton rails
  /// alongside `relatedRows` until their query resolves one way or the other.
  public var pendingRelatedShelfTitles: [String] {
    var titles: [String] = []
    if !shelfAuthors.isEmpty, moreFromDirector.isEmpty, !moreFromDirectorLoaded {
      titles.append(authorShelfTitle)
    }
    if !shelfCast.isEmpty, moreWithActor.isEmpty, !moreWithActorLoaded {
      titles.append(castShelfTitle)
    }
    return titles
  }

  /// A related row's card back to its source item — `MediaCard` alone doesn't carry
  /// the full `MediaItem` payload `NavigationLinkProvider.link(for:)` needs.
  public func relatedItem(forCardID id: Int) -> MediaItem? {
    similarItems.first(where: { $0.id == id })
      ?? moreFromDirector.first(where: { $0.id == id })
      ?? moreWithActor.first(where: { $0.id == id })
      ?? moreInGenre.first(where: { $0.id == id })
      ?? collectionShelves.lazy.compactMap { $0.items.first(where: { $0.id == id }) }.first
  }

  /// - Parameter knownItem: the listing's copy of the item, where the caller has one.
  ///   Only the artwork is used from it — the page waits for the full details before
  ///   drawing anything else, so a stale title or missing seasons can't leak through.
  init(mediaItemId: Int,
       knownItem: MediaItem? = nil,
       itemsService: VideoContentService,
       downloadManager: DownloadManager<DownloadMeta>,
       linkProvider: NavigationLinkProvider,
       errorHandler: ErrorHandler,
       actionsService: UserActionsService = AppContext.shared.actionsService,
       metadataService: MetadataService = AppContext.shared.metadataService,
       contentStore: ContentStore = AppContext.shared.contentStore,
       collectionsService: CollectionsService = AppContext.shared.collectionsService,
       libraryState: MediaLibraryStore = AppContext.shared.libraryState) {
    self.itemsService = itemsService
    self.mediaItemId = mediaItemId
    self.linkProvider = linkProvider
    self.errorHandler = errorHandler
    self.downloadManager = downloadManager
    self.actionsService = actionsService
    self.metadataService = metadataService
    self.contentStore = contentStore
    self.collectionsService = collectionsService
    self.libraryState = libraryState
    // Only the card can tell us this is episodic before the details call answers, and
    // only for episodic items is `nolinks=1` worth it (a film's link block is small, and
    // its `Video` is a struct we would have to write back through the item).
    self.excludeLinksOnFetch = FeatureFlags.seriesDetailsWithoutLinks && (knownItem?.isEpisodicType ?? false)
    switch libraryState.userVote(itemId: mediaItemId) {
    case true: myVote = .up
    case false: myVote = .down
    case nil: break
    }
    if let knownItem {
      self.mediaItem = knownItem
      AppContext.shared.localProgressStore.cacheItem(knownItem)
      let serverWatchlist = knownItem.inWatchlist ?? knownItem.subscribed ?? false
      libraryState.seedWatchlistIfAbsent(itemId: knownItem.id, value: serverWatchlist)
      isInWatchlist = libraryState.inWatchlist(itemId: knownItem.id) ?? serverWatchlist
      isWatched = libraryState.movieWatched(
        itemId: knownItem.id,
        serverWatched: knownItem.playbackAction == .playAgain
      )
    }
  }

  /// True when this page fetched its item with `nolinks=1` — episode links then arrive
  /// per episode, through `MediaLinksResolver`.
  private let excludeLinksOnFetch: Bool

  func fetchData() {
    loadFailed = false
    loadError = nil
    externalMetadataLoaded = false
    moreFromDirector = []
    moreWithActor = []
    moreFromDirectorLoaded = false
    moreWithActorLoaded = false
    collectionShelves = []
    moreInGenre = []
    moreInGenreTitle = nil
    moreInGenreGenreIDs = []
    similarLoaded = false
    collectionsLoaded = false
    // Draw the library controls from what is already on disk, then correct them from
    // the payload below. The old version raced the details call from its own Task and
    // read `mediaItem.bookmarks` before it had arrived.
    applyBookmarkState()
    followBookmarkFolders()
    Task {
      do {
        mediaItem = try await itemsService.fetchDetails(for: "\(mediaItemId)",
                                                       excludeLinks: excludeLinksOnFetch).item
        let mediaId = mediaItem.id
        mediaItem.seasons = mediaItem.seasons?.map({ $0.mediaId = mediaId; return $0 })
        AppContext.shared.localProgressStore.cacheItem(mediaItem)
        isWatched = libraryState.movieWatched(
          itemId: mediaItem.id,
          serverWatched: mediaItem.playbackAction == .playAgain
        )
        applyBookmarkState()
        // Without this the hero's follow control opened as "not following" on every
        // visit, whatever the account actually had, and the first tap unfollowed.
        let serverWatchlist = mediaItem.inWatchlist ?? mediaItem.subscribed ?? false
        libraryState.seedWatchlistIfAbsent(itemId: mediaItem.id, value: serverWatchlist)
        isInWatchlist = libraryState.inWatchlist(itemId: mediaItem.id) ?? serverWatchlist
        seedVoteCounts()
        let episodeFlags = (mediaItem.seasons ?? []).flatMap(\.episodes).map {
          (id: $0.id, watched: $0.watched > 0)
        }
        libraryState.reconcileWatched(
          movieItemId: mediaItem.id,
          serverMovieWatched: mediaItem.playbackAction == .playAgain,
          episodes: episodeFlags
        )
        // What the payload actually carried, so a "nothing plays" report can be told
        // apart from a link-resolution one without guessing.
        Logger.app.info(
          "details id=\(self.mediaItemId) nolinks=\(self.excludeLinksOnFetch) type=\(self.mediaItem.type) seasons=\(self.mediaItem.seasons?.count ?? 0) firstEpisodeFiles=\(self.mediaItem.seasons?.first?.episodes.first?.files.count ?? -1) videoFiles=\(self.mediaItem.videos?.first?.files.count ?? -1) trailer=\(self.mediaItem.trailerURL?.host ?? "none")"
        )
        itemLoaded = true
        identity = MediaIdentity(mediaItem: mediaItem)
        // People shelves need credit names from the details payload — kick them
        // off as soon as we have them, in parallel with TMDB enrichment. The
        // collections only need the id, but they run here too so the genre floor
        // below them sees whether they found anything.
        Task {
          await loadCollectionShelves()
          await ensureSomethingRelated()
        }
        Task { await loadPeopleShelves() }
        await loadExternalMetadata()
        // The "what's next" data lives on the latest season, not the first one —
        // and a long-running show should not fan out schedule fetches for every
        // published season (the rest load lazily when their tab is selected).
        if let lastSeason = mediaItem.seasons?.last?.number {
          await ensureSeasonSchedule(lastSeason)
        }
      } catch {
        Logger.app.error("Failed to load item \(self.mediaItemId): \(error)")
        loadFailed = true
        loadError = error
        externalMetadataLoaded = true
        moreFromDirectorLoaded = true
        moreWithActorLoaded = true
        collectionsLoaded = true
      }
    }
    Task {
      await loadSimilar()
      // Whichever query answers last is the one that fires the floor — every one of
      // them has to have answered before "nothing to recommend" is true.
      await ensureSomethingRelated()
    }
  }

  func ensureSeasonSchedule(_ kinoSeasonNumber: Int) async {
    guard seasonSchedules[kinoSeasonNumber] == nil,
          let identity,
          identity.imdb != nil else {
      Logger.metadata.debug(
        "TMDB schedule skip s\(kinoSeasonNumber): alreadyLoaded=\(self.seasonSchedules[kinoSeasonNumber] != nil) imdb=\(self.identity?.imdb ?? "nil")"
      )
      return
    }

    guard let tmdbSeason = tmdbSeasonNumber(forKinoSeason: kinoSeasonNumber) else {
      // No sensible TMDB counterpart (renumbered/special block) — mark loaded so we
      // don't refetch on every tab visit, and simply show kino.pub episodes alone.
      Logger.metadata.info(
        "TMDB schedule skip s\(kinoSeasonNumber): no TMDB match (title=\(self.kinoSeason(for: kinoSeasonNumber)?.title ?? "nil"))"
      )
      seasonSchedules[kinoSeasonNumber] = []
      return
    }

    let kinoCount = kinoSeason(for: kinoSeasonNumber)?.episodes.count ?? 0
    Logger.metadata.info(
      "TMDB schedule fetch kinopub=\(self.mediaItemId) imdb=\(identity.imdb ?? "?") season=\(kinoSeasonNumber)→tmdb=\(tmdbSeason) kinoEpisodes=\(kinoCount)"
    )
    let episodes = await metadataService.schedule(for: identity, season: tmdbSeason)
    seasonSchedules[kinoSeasonNumber] = episodes
    let tmdbNums = episodes.map(\.episodeNumber).sorted()
    let kinoNums = Set(kinoSeason(for: kinoSeasonNumber)?.episodes.map(\.number) ?? [])
    let missingOnKino = tmdbNums.filter { !kinoNums.contains($0) }
    let upcoming = episodes.filter(\.isUpcoming).map(\.episodeNumber)
    Logger.metadata.info(
      "TMDB schedule result season=\(kinoSeasonNumber) tmdb=\(episodes.count) [\(tmdbNums.map(String.init).joined(separator: ","))] missingOnKino=\(missingOnKino) upcoming=\(upcoming) sampleStill=\(episodes.first?.still?.absoluteString ?? "nil")"
    )
  }

  private func kinoSeason(for number: Int) -> Season? {
    mediaItem.seasons?.first(where: { $0.number == number })
  }

  /// kino.pub sometimes re-numbers its season blocks from 1 while titling them
  /// "Сезон N" — TMDB numbers by the real season. Map by the title's digits first
  /// (validated against TMDB's season list), then by kino number, else give up:
  /// asking TMDB for "season 1" of a block that is really season 14 produced
  /// decade-old "missing episodes" on a current show.
  private func tmdbSeasonNumber(forKinoSeason kinoNumber: Int) -> Int? {
    guard let kinoSeason = kinoSeason(for: kinoNumber) else { return nil }
    let tmdbNumbers = Set(externalMetadata.seasonSummaries.map(\.seasonNumber))
    if let titleNumber = kinoSeason.titleSeasonNumber,
       tmdbNumbers.contains(titleNumber) {
      return titleNumber
    }
    if tmdbNumbers.isEmpty || tmdbNumbers.contains(kinoNumber) {
      return kinoNumber
    }
    return nil
  }

  func schedule(for episode: Episode, in season: Season) -> EpisodeSchedule? {
    seasonSchedules[season.number]?.first(where: { $0.episodeNumber == episode.number })
  }

  private func loadExternalMetadata() async {
    defer { externalMetadataLoaded = true }
    guard let identity else {
      Logger.metadata.info("TMDB skip kinopub=\(self.mediaItemId): no identity")
      return
    }
    guard let imdb = identity.imdb else {
      Logger.metadata.info("TMDB skip kinopub=\(self.mediaItemId): no imdb id")
      return
    }
    Logger.metadata.info(
      "TMDB metadata fetch kinopub=\(self.mediaItemId) imdb=\(imdb) series=\(identity.isSeries) title=\(identity.title)"
    )
    let meta = await metadataService.metadata(for: identity)
    externalMetadata = meta
    Logger.metadata.info(
      "TMDB metadata result kinopub=\(self.mediaItemId) tmdbId=\(meta.tmdbId.map(String.init) ?? "nil") cast=\(meta.cast.count) photos=\(meta.cast.filter { $0.photo != nil }.count) logo=\(meta.titleLogoURL?.absoluteString ?? "nil") next=\(meta.nextEpisode.map { "S\($0.seasonNumber)E\($0.episodeNumber)" } ?? "nil") status=\(meta.status ?? "nil")"
    )
  }

  // MARK: - Actions

  /// Bookmark state, entirely from what the page already has: membership from the item
  /// payload (`bookmarks`) with the local store as the fallback, folder names from
  /// `BookmarkFoldersStore`. Opening a title costs no bookmarks request — neither
  /// `get-item-folders` nor the folder list, which only changes when the viewer
  /// creates or deletes one.
  /// Folder names for the hero's bookmark menu come from the shared store, restored from
  /// disk at launch — the page never asks the server for them. Following the store rather
  /// than copying it once means a folder created from a card menu on this same page shows
  /// up here too.
  ///
  /// Set up here, not in `init`: this model is built inside a view body
  /// (`RouteDestination.detailsView`), and a subscription that delivers its current value
  /// straight away publishes during that update — "Publishing changes from within view
  /// updates is not allowed". `fetchData()` runs from `.task`, off the update.
  private func followBookmarkFolders() {
    guard folderSubscription == nil else { return }
    folders = BookmarkFoldersStore.shared.folders
    folderSubscription = BookmarkFoldersStore.shared.$folders
      .dropFirst()
      .sink { [weak self] in self?.folders = $0 }
  }

  private var folderSubscription: AnyCancellable?

  private func applyBookmarkState() {
    if let bookmarks = mediaItem.bookmarks {
      let ids = Set(bookmarks.map(\.id))
      folderIDsContainingItem = ids
      BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: ids)
    } else {
      folderIDsContainingItem = BookmarkMembershipStore.shared.folderIDs(for: mediaItemId)
    }
  }

  /// Related items are a tail-end extra, so — like the bookmark state — a failure is
  /// logged and swallowed rather than thrown at the user over the artwork.
  private func loadSimilar() async {
    defer { similarLoaded = true }
    do {
      similarItems = try await itemsService.fetchSimilar(for: "\(mediaItemId)").items
    } catch {
      Logger.app.error("Failed to load similar items for \(self.mediaItemId): \(error)")
    }
  }

  /// The author shelf ("More by This Director" / "…These Creators") and "More with
  /// actor" — best-effort, same swallow-on-failure rule as `loadSimilar`. The author
  /// query covers every credited director at once; the actor one is the first billed
  /// name (community heuristic). Picked by
  /// Kinopoisk rating so the rail is a "best of" strip rather than upload order, then
  /// shown newest first — a filmography reads as a timeline, and "known for" ordering
  /// waits until we have a signal worth ranking on.
  /// Current title is always dropped; titles that land in both rails stay on the
  /// director shelf only so the pair doesn't repeat the same poster twice — by film,
  /// not by id, so the flat copy of a 3D entry counts as the same title.
  private func loadPeopleShelves() async {
    let policy = mediaItem.presentation.castShelf
    async let directorItems = fetchPeopleShelf(people: shelfAuthors)
    async let actorItems = fetchPeopleShelf(people: shelfCast, onlyType: policy.onlyType)
    let director = await directorItems
    let actor = await actorItems.preferringTypes(policy.preferredTypes)
    let directorFilms = Set(director.map(\.filmIdentity))
    moreFromDirector = director
    moreWithActor = actor.filter { !directorFilms.contains($0.filmIdentity) }
    moreFromDirectorLoaded = true
    moreWithActorLoaded = true
    await ensureSomethingRelated()
  }

  /// **One request per name, merged.** `/v1/items` matches `cast` / `director` on the
  /// credits field as written, so `director=A,B` matches nobody — a co-directed film
  /// has to ask twice. The union is collapsed by film, so the titles both of them
  /// worked on appear once.
  ///
  /// One card per film for the other reason too: kino.pub files the 3D encoding as its
  /// own entry under the same credits. Which copy survives follows the page — a 3D
  /// title keeps 3D company — and collapsing happens before the shelf is cut to length,
  /// so a duplicate never costs a slot.
  private func fetchPeopleShelf(people: [MediaPerson], onlyType: MediaType? = nil) async -> [MediaItem] {
    guard !people.isEmpty else { return [] }
    var merged: [MediaItem] = []
    for person in people {
      merged.append(contentsOf: await fetchPersonShelf(person: person, onlyType: onlyType))
    }
    let items = merged
      .collapsingFilmVariants(preferring3D: mediaItem.is3D)
    return Array(items.prefix(Self.peopleShelfLimit)).sortedNewestFirst()
  }

  private func fetchPersonShelf(person: MediaPerson, onlyType: MediaType?) async -> [MediaItem] {
      let filter = LibraryFilter(
        contentType: onlyType,
        sort: .year,
        person: person
      )
    do {
      let items = try await itemsService.fetchItems(filter: filter, page: nil).items
        .filter { $0.filmIdentity != mediaItem.filmIdentity }
      Logger.app.info(
        "credit shelf id=\(self.mediaItemId) \(person.role.rawValue)=\(person.name) items=\(items.count)"
      )
      return items
    } catch {
      Logger.app.error(
        "Failed to load \(person.role.rawValue) shelf for \(person.name): \(error)"
      )
      return []
    }
  }

  // MARK: - Collections and the genre floor

  /// The collections this title sits in, each as its own shelf. Editorial, so it is
  /// worth a request of its own — but capped, because every collection costs a second
  /// one to read what is in it.
  ///
  /// 🔎 The endpoint was captured from the PWA on its `api2/v1.1` branch and this asks
  /// our own host for the same path; the log line is what will tell us whether it
  /// answers at all. A failure is silence, like every other related shelf.
  private func loadCollectionShelves() async {
    defer { collectionsLoaded = true }
    do {
      let collections = Array(
        try await collectionsService.fetchCollections(forItem: mediaItemId)
          .prefix(Self.collectionShelfLimit)
      )
      Logger.app.info("item collections id=\(self.mediaItemId) count=\(collections.count)")
      guard !collections.isEmpty else { return }
      var shelves: [CollectionShelf] = []
      for collection in collections {
        guard let items = try? await collectionsService.fetchCollection(id: collection.id).1 else {
          continue
        }
        let cards = items
          .filter { $0.filmIdentity != mediaItem.filmIdentity }
          .collapsingFilmVariants(preferring3D: mediaItem.is3D)
        guard !cards.isEmpty else { continue }
        shelves.append(CollectionShelf(collection: collection,
                                       items: Array(cards.prefix(Self.peopleShelfLimit))))
      }
      collectionShelves = shelves
    } catch {
      Logger.app.error("Failed to load collections for \(self.mediaItemId): \(error)")
    }
  }

  /// The floor, and **the last resort**: only when similar, both credit shelves and the
  /// collections have all come back with nothing does the page ask for more of the same
  /// type and genre. That is the normal state of a TV show, a concert or a stand-up set
  /// and the rare state of a film.
  ///
  /// It waits for every other shelf to have *answered* — not merely to be empty — or it
  /// would fire against `MediaItem.mock()` while the details are still in flight and
  /// recommend comedies on a page that turns out to be a concert.
  ///
  /// **The query is the web client's own genre page**: type, several genres
  /// (`genre=23,26` — mult + short), the country, and a `period` window, ordered by
  /// what was updated last. The point is what there is to watch *now*, not the all-time
  /// top of a genre.
  ///
  /// It asks up to three times, narrowest first, because a narrow query on a thin genre
  /// answers nothing and an empty shelf is the thing this whole mechanism exists to
  /// prevent: country + genres + this month → genres alone → the one genre that
  /// describes the title best.
  private func ensureSomethingRelated() async {
    guard itemLoaded, similarLoaded, collectionsLoaded,
          moreFromDirectorLoaded, moreWithActorLoaded else { return }
    guard moreInGenre.isEmpty,
          similarItems.isEmpty,
          moreFromDirector.isEmpty,
          moreWithActor.isEmpty,
          collectionShelves.isEmpty else { return }

    let profile = mediaItem.presentation
    let named = mediaItem.genres.filter { !($0.title ?? "").isEmpty }
    guard !named.isEmpty else { return }
    let signature = named.first { profile.signatureGenreIDs.contains($0.id) }
    // A film asks about one genre — "more comedy" under a comedy is a truism. Anything
    // else is described by the combination it is filed under, not by the first entry.
    let wide = profile.genreShelfUsesEveryGenre
      ? Array(named.prefix(Self.genreQueryLimit))
      : [signature ?? named[0]]
    let narrow = [signature ?? named[0]]

    for attempt in genreShelfAttempts(wide: wide, narrow: narrow) {
      let items = await fetchGenreShelf(attempt.filter)
      if !items.isEmpty {
        apply(genreShelf: items, genres: attempt.genres)
        return
      }
    }
  }

  private func genreShelfAttempts(wide: [TypeClass],
                                  narrow: [TypeClass]) -> [(filter: LibraryFilter, genres: [TypeClass])] {
    let type = mediaItem.contentTypeFilter
    let country = mediaItem.countries.first?.id
    var attempts: [(LibraryFilter, [TypeClass])] = []
    if let country {
      attempts.append((LibraryFilter(contentType: type,
                                     sort: .recentlyUpdated,
                                     genreIDs: wide.map(\.id),
                                     countryID: country,
                                     period: .month), wide))
    }
    attempts.append((LibraryFilter(contentType: type,
                                   sort: .recentlyUpdated,
                                   genreIDs: wide.map(\.id)), wide))
    // Several genres at once is unverified — the vendor docs say nothing about a comma
    // on `genre`. Ending on one genre means an unlucky guess still leaves a shelf.
    if wide.count > 1 {
      attempts.append((LibraryFilter(contentType: type,
                                     sort: .recentlyUpdated,
                                     genreIDs: narrow.map(\.id)), narrow))
    }
    return attempts
  }

  private func apply(genreShelf items: [MediaItem], genres: [TypeClass]) {
    guard !items.isEmpty else { return }
    moreInGenre = items
    moreInGenreGenreIDs = genres.map(\.id)
    moreInGenreTitle = String(format: "MediaItem_MoreInGenre".localized,
                              genres.compactMap(\.title).joined(separator: " · "))
  }

  private func fetchGenreShelf(_ filter: LibraryFilter) async -> [MediaItem] {
    do {
      let items = try await itemsService.fetchItems(filter: filter, page: nil).items
        .filter { $0.filmIdentity != mediaItem.filmIdentity }
        .collapsingFilmVariants(preferring3D: mediaItem.is3D)
      Logger.app.info(
        "genre floor id=\(self.mediaItemId) type=\(filter.contentType?.rawValue ?? "any") genres=\(filter.genreIDs.map(String.init).joined(separator: ",")) country=\(filter.countryID.map(String.init) ?? "any") period=\(filter.period?.rawValue ?? "all") items=\(items.count)"
      )
      return Array(items.prefix(Self.peopleShelfLimit))
    } catch {
      Logger.app.error("Failed to load genre shelf for \(self.mediaItemId): \(error)")
      return []
    }
  }

  private static let genreQueryLimit = 4
  private static let peopleShelfLimit = 15
  private static let collectionShelfLimit = 3

  func toggleWatched() {
    if let (season, episode) = mediaItem.primaryEpisode {
      toggleWatched(episode: episode, season: season)
      return
    }
    let previous = isWatched
    isWatched.toggle()
    libraryState.setMovieWatched(itemId: mediaItemId, value: isWatched)
    presentWatchedHud(nowWatched: isWatched)
    Task {
      do {
        try await actionsService.toggleWatching(id: mediaItemId, video: 1, season: nil)
        contentStore.invalidate(family: .watch)
      } catch {
        isWatched = previous
        libraryState.setMovieWatched(itemId: mediaItemId, value: previous)
        errorHandler.setError(error)
      }
    }
  }

  /// Marks one episode watched/unwatched from the season rail's context menu.
  func toggleWatched(episode: Episode, season: Season) {
    let previous = episode.watched
    episode.watched = previous > 0 ? 0 : 1
    // Force the published item to refresh so the rail redraws checkmarks/progress.
    mediaItem = mediaItem
    isWatched = mediaItem.playbackAction == .playAgain
    libraryState.setEpisodeWatched(episodeId: episode.id, value: episode.watched > 0)
    presentWatchedHud(nowWatched: episode.watched > 0)
    Task {
      do {
        let watched = try await actionsService.toggleWatching(id: mediaItemId,
                                                              video: episode.number,
                                                              season: season.number)
        if let watched {
          episode.watched = watched
          mediaItem = mediaItem
          isWatched = mediaItem.playbackAction == .playAgain
          libraryState.setEpisodeWatched(episodeId: episode.id, value: watched > 0)
        }
        contentStore.invalidate(family: .watch)
      } catch {
        episode.watched = previous
        mediaItem = mediaItem
        isWatched = mediaItem.playbackAction == .playAgain
        libraryState.setEpisodeWatched(episodeId: episode.id, value: previous > 0)
        errorHandler.setError(error)
      }
    }
  }

  /// Marks a whole season watched/unwatched at once. `/v1/watching/toggle` with a
  /// season and no video number is the API's own bulk form, and it flips the season
  /// to the opposite of what it mostly is — so a part-watched season completes rather
  /// than resetting. The response carries no per-episode flags, hence the refetch.
  func toggleWatched(season: Season) {
    let target = season.episodes.contains { !$0.isWatched } ? 1 : 0
    let previous = season.episodes.map(\.watched)
    for episode in season.episodes {
      episode.watched = target
    }
    mediaItem = mediaItem
    isWatched = mediaItem.playbackAction == .playAgain
    presentWatchedHud(nowWatched: target > 0)
    Task {
      do {
        _ = try await actionsService.toggleWatching(id: mediaItemId, video: nil, season: season.number)
        contentStore.invalidate(family: .watch)
        // The optimistic flip above is a guess at what a bulk toggle did; the item's
        // own episode flags are the answer.
        var refreshed = try await itemsService.fetchDetails(for: "\(mediaItemId)").item
        let mediaId = refreshed.id
        refreshed.seasons = refreshed.seasons?.map({ $0.mediaId = mediaId; return $0 })
        mediaItem = refreshed
        AppContext.shared.localProgressStore.cacheItem(refreshed)
        isWatched = mediaItem.playbackAction == .playAgain
      } catch {
        for (episode, watched) in zip(season.episodes, previous) {
          episode.watched = watched
        }
        mediaItem = mediaItem
        isWatched = mediaItem.playbackAction == .playAgain
        errorHandler.setError(error)
      }
    }
  }

  /// Drops the title from history so it stops cluttering Continue Watching.
  func clearFromContinueWatching() {
    presentHud(systemImage: "trash", title: "Removed")
    Task {
      do {
        try await actionsService.clearHistoryForItem(id: mediaItemId)
        contentStore.invalidate(family: .watch)
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  /// Drops one episode from history so it stops cluttering Continue Watching.
  func hide(episode: Episode, season: Season) {
    Task {
      do {
        try await actionsService.clearHistoryForMedia(id: episode.id)
        contentStore.invalidate(family: .watch)
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  /// Bookmark folders live in `ContentStore` too (`.folder(id)`), so a toggle here
  /// needs both folders it affects to refetch next time Library is shown, not sit
  /// stale for up to 10 minutes.
  func toggleFolder(_ folder: Bookmark) {
    let previous = folderIDsContainingItem
    if folderIDsContainingItem.contains(folder.id) {
      folderIDsContainingItem.remove(folder.id)
      presentHud(systemImage: "bookmark", title: "Removed")
    } else {
      folderIDsContainingItem.insert(folder.id)
      presentHud(systemImage: "bookmark.fill", title: "Bookmarked")
    }
    BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: folderIDsContainingItem)
    Task {
      do {
        try await itemsService.toggleBookmark(itemId: mediaItemId, folderId: folder.id)
        contentStore.invalidate(family: .bookmarks)
      } catch {
        folderIDsContainingItem = previous
        BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: previous)
        errorHandler.setError(error)
      }
    }
  }

  /// Series follow state — `/v1/watching/togglewatchlist`, seeded from the item's own
  /// `in_watchlist` / `subscribed` flags. Distinct from bookmark folders (a shelf you
  /// file things on) and from watched (how far you got).
  @Published public var isInWatchlist: Bool = false

  func toggleWatchlist() {
    let previous = isInWatchlist
    isInWatchlist.toggle()
    libraryState.setWatchlist(itemId: mediaItemId, value: isInWatchlist)
    if isInWatchlist {
      presentHud(systemImage: "plus", title: "Added to Watchlist")
    } else {
      presentHud(systemImage: "minus", title: "Removed from Watchlist")
    }
    Task {
      do {
        try await actionsService.toggleWatchlist(id: mediaItemId)
        contentStore.invalidate(family: .watch)
      } catch {
        isInWatchlist = previous
        libraryState.setWatchlist(itemId: mediaItemId, value: previous)
        errorHandler.setError(error)
      }
    }
  }

  /// Create a bookmark folder and put this item in it.
  func createFolderAndAdd(named name: String) {
    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }
    Task {
      do {
        let folderId = try await actionsService.createBookmarkFolder(title: title)
        try await itemsService.toggleBookmark(itemId: mediaItemId, folderId: folderId)
        folderIDsContainingItem.insert(folderId)
        BookmarkMembershipStore.shared.replace(itemID: mediaItemId, folderIDs: folderIDsContainingItem)
        // The folder list itself changed — the one case where this page fetches it.
        // `folders` follows the store, so the new folder lands in the menu here.
        await BookmarkFoldersStore.shared.reload(using: itemsService)
        contentStore.invalidate(family: .bookmarks)
        presentHud(systemImage: "bookmark.fill", title: "Bookmarked")
      } catch {
        errorHandler.setError(error)
      }
    }
  }

  private func presentWatchedHud(nowWatched: Bool) {
    if nowWatched {
      presentHud(systemImage: "checkmark", title: "Watched")
    } else {
      presentHud(systemImage: "eye", title: "Marked as New")
    }
  }

  private func presentHud(systemImage: String, title: String) {
    hudToast = HudToast(systemImage: systemImage, title: title.localized)
  }

  /// kino.pub exposes aggregate as `rating` + `rating_votes` (+ percentage); derive like/dislike
  /// for the initial display. A real vote refreshes them from `VoteData`.
  private func seedVoteCounts() {
    switch libraryState.userVote(itemId: mediaItemId) {
    case true: myVote = .up
    case false: myVote = .down
    case nil: myVote = .none
    }
    if let votes = mediaItem.communityVotes {
      likeCount = votes.likes
      dislikeCount = votes.dislikes
    } else {
      likeCount = 0
      dislikeCount = 0
    }
  }

  /// Cast a like (`up: true` → `like=1`) or dislike. One-shot — can't switch or re-cast.
  func vote(up: Bool) {
    let target: MediaItemUserVote = up ? .up : .down
    if myVote == target { return }
    if myVote != .none { return }

    myVote = target
    libraryState.setUserVote(itemId: mediaItemId, up: up)
    if up { likeCount += 1 } else { dislikeCount += 1 }
    Task {
      do {
        let result = try await actionsService.vote(id: mediaItemId, like: up ? 1 : 0)
        if result.voted {
          if let p = result.positiveCount { likeCount = p }
          if let n = result.negativeCount { dislikeCount = n }
        } else {
          // Already voted on another device — keep highlight, undo optimistic bump.
          if up { likeCount = max(0, likeCount - 1) } else { dislikeCount = max(0, dislikeCount - 1) }
        }
      } catch {
        myVote = .none
        libraryState.clearUserVote(itemId: mediaItemId)
        if up { likeCount = max(0, likeCount - 1) } else { dislikeCount = max(0, dislikeCount - 1) }
        errorHandler.setError(error)
      }
    }
  }
  
  func startDownload(item: DownloadableMediaItem, file: FileInfo) {
    guard FeatureFlags.downloadsEnabled else { return }
    let meta = DownloadMeta.make(from: item, quality: file.quality)
#if os(iOS)
    // Prefer offline HLS (.movpkg) — full quality + all dubs/subs. Fall back to mp4.
    if let hls = URL(string: file.url.hls4), !file.url.hls4.isEmpty {
      Task { @MainActor in
        let result = await AppContext.shared.hlsDownloadManager.startDownload(meta: meta, hlsURL: hls)
        switch result {
        case .started, .alreadyDownloading, .alreadyDownloaded:
          return
        case .failed:
          guard let url = URL(string: file.url.http), !file.url.http.isEmpty else { return }
          _ = self.downloadManager.startDownload(url: url, withMetadata: meta)
        }
      }
      return
    }
#endif
    guard let url = URL(string: file.url.http), !file.url.http.isEmpty else { return }
    _ = downloadManager.startDownload(url: url, withMetadata: meta)
  }

  /// Enqueues every episode of a season at `quality` (mp4 path). Non-TV only.
  @discardableResult
  func startSeasonDownload(mediaId: Int, seriesTitle: String, season: Season, quality: String?) -> Int {
#if os(tvOS)
    return 0
#else
    guard FeatureFlags.downloadsEnabled else { return 0 }
    return AppContext.shared.seasonDownloadManager.downloadSeason(
      mediaId: mediaId,
      seriesTitle: seriesTitle,
      season: season,
      quality: quality
    )
#endif
  }

}

extension MediaIdentity {
  init(mediaItem: MediaItem) {
    self.init(
      kinopubId: mediaItem.id,
      imdb: mediaItem.imdb.map(TMDBIDFormatter.imdbString(from:)),
      kinopoisk: mediaItem.kinopoisk,
      title: mediaItem.localizedTitle,
      originalTitle: mediaItem.originalTitle,
      year: mediaItem.year,
      isSeries: mediaItem.isSeries
    )
  }
}
