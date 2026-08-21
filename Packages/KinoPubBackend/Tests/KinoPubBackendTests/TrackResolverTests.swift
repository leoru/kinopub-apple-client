//
//  TrackResolverTests.swift
//
//  The business rules for "which dub and which subtitles does this open with",
//  as scenarios. Rules and reasons: docs/product/playback-tracks.md
//

import XCTest
@testable import KinoPubBackend

final class TrackResolverTests: XCTestCase {

  // MARK: - Fixtures

  private let ruThenEn = ["ru", "en"]
  private let seriesID = 4242

  /// kino.pub type ids: 1 DUB, 2 MVO, 3 DVO, 4 VO, 5 AVO, 6 Orig.
  private func audio(_ lang: String,
                     _ typeId: Int,
                     _ studio: String? = nil,
                     channels: Int = 2,
                     index: Int = 0,
                     ad: Bool = false) -> AudioTrackInfo {
    let titles = [1: "Дубляж", 2: "Многоголосый", 3: "Двухголосый",
                  4: "Одноголосый", 5: "Авторский", 6: "Оригинал"]
    return AudioTrackInfo(lang: lang,
                          typeId: typeId,
                          typeTitle: titles[typeId],
                          typeShortTitle: nil,
                          authorTitle: studio,
                          channels: channels,
                          codec: "aac",
                          index: index,
                          isAudioDescription: ad)
  }

  private func subtitle(_ lang: String, url: String? = nil) -> Subtitle {
    Subtitle(lang: lang, shift: 0, embed: false, url: url ?? "https://cdn/\(lang).srt")
  }

  private func subtitleTracks(_ langs: [String]) -> [SubtitleTrack] {
    SubtitleTracks.catalog(langs.map { subtitle($0) })
  }

  // The dubs this series has been offered over its life.
  private var mosfilmDub: AudioTrackInfo { audio("ru", 1, "Мосфильм") }
  private var lostfilmMVO: AudioTrackInfo { audio("ru", 2, "LostFilm") }
  private var kurajMVO: AudioTrackInfo { audio("ru", 2, "Кураж-Бамбей") }
  private var syenduk: AudioTrackInfo { audio("ru", 3, "Сыендук") }
  private var jaskierDVO: AudioTrackInfo { audio("ru", 3, "Jaskier") }
  private var englishOriginal: AudioTrackInfo { audio("en", 6) }
  private var japaneseOriginal: AudioTrackInfo { audio("ja", 6) }

  private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_700_000_000 + Double(n) * 86_400) }

  /// A viewer who has watched this series a lot: Сыендук for most of it, LostFilm when
  /// Сыендук was not there, Кураж once. Every dub below has been on a menu here.
  private func establishedLedger() -> TrackPreferenceLedger {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(syenduk.signature, at: day(30), weight: 20)
    ledger.recordAudio(lostfilmMVO.signature, at: day(20), weight: 6)
    ledger.recordAudio(kurajMVO.signature, at: day(10), weight: 1)
    ledger.noteMenu([mosfilmDub, lostfilmMVO, kurajMVO, syenduk, englishOriginal])
    return ledger
  }

  private func titleScope(_ ledger: TrackPreferenceLedger) -> [ScopedLedger] {
    [ScopedLedger(scope: .title(id: seriesID), ledger: ledger)]
  }

  private func decide(_ available: [AudioTrackInfo],
                      subtitles: [SubtitleTrack] = [],
                      ledgers: [ScopedLedger] = [],
                      settings: PlaybackLanguagePreferences = .default,
                      profile: TitleTrackProfile = TitleTrackProfile()) -> TrackDecision {
    TrackResolver.resolve(audio: available,
                          subtitles: subtitles,
                          ledgers: ledgers,
                          settings: settings,
                          systemLanguages: ruThenEn,
                          profile: profile)
  }

  // MARK: - The ladder, with no history at all

  func testLadderPrefersDubOverEverythingElseInTheSameLanguage() {
    let decision = decide([englishOriginal, syenduk, lostfilmMVO, mosfilmDub])
    XCTAssertEqual(decision.audio, mosfilmDub)
    XCTAssertEqual(decision.audioReason, .ladder)
  }

  func testLadderWalksTheKindOrderWhenNoDubExists() {
    let decision = decide([englishOriginal, syenduk, lostfilmMVO])
    XCTAssertEqual(decision.audio, lostfilmMVO, "MVO outranks DVO")
  }

  func testLadderFallsToTheSecondPreferredLanguage() {
    let decision = decide([englishOriginal, audio("de", 1, "Studio")])
    XCTAssertEqual(decision.audio, englishOriginal)
  }

  func testLadderPutsAudioDescriptionLastWithinALanguage() {
    let describes = audio("ru", 1, "Мосфильм", index: 1, ad: true)
    let decision = decide([describes, mosfilmDub])
    XCTAssertEqual(decision.audio, mosfilmDub)
  }

  func testSingleTrackNeedsNoLadder() {
    let decision = decide([jaskierDVO])
    XCTAssertEqual(decision.audio, jaskierDVO)
  }

  func testNoTracksDecidesNothing() {
    let decision = decide([])
    XCTAssertNil(decision.audio)
    XCTAssertEqual(decision.audioReason, .none)
  }

  // MARK: - Two seasons: rewatch and new episodes against an established preference

  func testRewatchOfAnEpisodeThatHasTheTopDub() {
    let decision = decide([mosfilmDub, lostfilmMVO, syenduk],
                          ledgers: titleScope(establishedLedger()))
    XCTAssertEqual(decision.audio, syenduk)
    XCTAssertEqual(decision.audioReason, .remembered)
    XCTAssertEqual(decision.audioScope, TrackMemoryScope.title(id: seriesID))
  }

  func testRewatchOfAnEpisodeWithoutTheTopDubTakesTheNextRememberedOne() {
    let decision = decide([mosfilmDub, lostfilmMVO, englishOriginal],
                          ledgers: titleScope(establishedLedger()))
    XCTAssertEqual(decision.audio, lostfilmMVO, "top-1 absent, top-2 is remembered too")
    XCTAssertEqual(decision.audioReason, .rememberedAlternate)
  }

  func testNewEpisodeWithTheTopDubOpensWithIt() {
    let decision = decide([syenduk, englishOriginal],
                          ledgers: titleScope(establishedLedger()))
    XCTAssertEqual(decision.audio, syenduk)
    XCTAssertEqual(decision.audioReason, .remembered)
  }

  func testNewEpisodeWithOnlyTheThirdRememberedDub() {
    let decision = decide([kurajMVO, englishOriginal],
                          ledgers: titleScope(establishedLedger()))
    XCTAssertEqual(decision.audio, kurajMVO)
    XCTAssertEqual(decision.audioReason, .rememberedAlternate)
  }

  func testNewEpisodeWithNoRememberedDubFallsBackToTheLadder() {
    let novafilm = audio("ru", 2, "NovaFilm")
    let decision = decide([novafilm, englishOriginal],
                          ledgers: titleScope(establishedLedger()))
    XCTAssertEqual(decision.audio, novafilm)
    XCTAssertEqual(decision.audioReason, .ladder)
    XCTAssertNil(decision.audioScope)
  }

  /// The point of weighting by episodes watched: twenty episodes of Сыендук are not
  /// displaced by a studio dub that turns up later.
  func testAStrongHabitSurvivesANewerBetterDub() {
    var ledger = establishedLedger()
    ledger.seenAudio.remove(mosfilmDub.signature)
    let decision = decide([mosfilmDub, syenduk], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, syenduk)
    XCTAssertEqual(decision.audioReason, .remembered)
  }

  // MARK: - The fresh series: choices made before anyone dubbed it properly

  /// Three episodes watched with the only thing available, then the show gets dubbed.
  /// The stopgap was never a preference.
  func testProvisionalStopgapYieldsToTheFirstProperDub() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(jaskierDVO.signature, at: day(1), weight: 2)
    ledger.noteMenu([jaskierDVO, englishOriginal])

    let decision = decide([mosfilmDub, jaskierDVO, englishOriginal], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, mosfilmDub)
    XCTAssertEqual(decision.audioReason, .newBetterDub)
  }

  func testProvisionalStopgapAlsoYieldsToAMultiVoice() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(jaskierDVO.signature, at: day(1), weight: 2)
    ledger.noteMenu([jaskierDVO])

    let decision = decide([lostfilmMVO, jaskierDVO], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, lostfilmMVO)
    XCTAssertEqual(decision.audioReason, .newBetterDub)
  }

  func testProvisionalStopgapIsKeptWhenTheNewTrackIsWorse() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(jaskierDVO.signature, at: day(1), weight: 2)
    ledger.noteMenu([jaskierDVO])

    let singleVoice = audio("ru", 4, "Кто-то")
    let decision = decide([singleVoice, jaskierDVO], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, jaskierDVO)
    XCTAssertEqual(decision.audioReason, .remembered)
  }

  func testAHabitAtTheConfidenceFloorHoldsAgainstANewDub() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(jaskierDVO.signature,
                       at: day(1),
                       weight: TrackPreferenceLedger.confidentWeight)
    ledger.noteMenu([jaskierDVO])

    let decision = decide([mosfilmDub, jaskierDVO], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, jaskierDVO)
    XCTAssertEqual(decision.audioReason, .remembered)
  }

  /// A better dub the viewer has been declining all along is not "new".
  func testABetterDubAlreadySeenDoesNotPromoteItself() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(jaskierDVO.signature, at: day(1), weight: 2)
    ledger.noteMenu([jaskierDVO, mosfilmDub])

    let decision = decide([mosfilmDub, jaskierDVO], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, jaskierDVO)
    XCTAssertEqual(decision.audioReason, .remembered)
  }

  // MARK: - Scopes

  func testSeasonPreferenceBeatsTheTitlePreference() {
    var season = TrackPreferenceLedger()
    season.recordAudio(lostfilmMVO.signature, at: day(40), weight: 4)
    season.noteMenu([lostfilmMVO, syenduk])

    let ledgers = [
      ScopedLedger(scope: .season(titleID: seriesID, season: 4), ledger: season),
      ScopedLedger(scope: .title(id: seriesID), ledger: establishedLedger())
    ]
    let decision = decide([syenduk, lostfilmMVO], ledgers: ledgers)
    XCTAssertEqual(decision.audio, lostfilmMVO)
    XCTAssertEqual(decision.audioScope, TrackMemoryScope.season(titleID: seriesID, season: 4))
  }

  func testTitlePreferenceAnswersWhenTheSeasonKnowsNothing() {
    let ledgers = [
      ScopedLedger(scope: .season(titleID: seriesID, season: 9), ledger: TrackPreferenceLedger()),
      ScopedLedger(scope: .title(id: seriesID), ledger: establishedLedger())
    ]
    let decision = decide([syenduk, mosfilmDub], ledgers: ledgers)
    XCTAssertEqual(decision.audio, syenduk)
    XCTAssertEqual(decision.audioScope, TrackMemoryScope.title(id: seriesID))
  }

  /// A brand-new anime opens the way the last anime did — the class is the scope, not
  /// the title.
  func testAnimeClassSeedsATitleWithNoHistoryOfItsOwn() {
    var anime = TrackPreferenceLedger()
    anime.recordAudio(japaneseOriginal.signature, at: day(5), weight: 12)
    anime.recordSubtitle(SubtitleChoiceSignature(languageKey: "ru", isCC: false),
                         at: day(5),
                         weight: 12)

    let ledgers = [
      ScopedLedger(scope: .title(id: 999), ledger: TrackPreferenceLedger()),
      ScopedLedger(scope: .anime, ledger: anime)
    ]
    let decision = decide([japaneseOriginal, lostfilmMVO],
                          subtitles: subtitleTracks(["ru", "en"]),
                          ledgers: ledgers,
                          profile: TitleTrackProfile(isAnime: true, originalLanguageKey: "ja"))
    XCTAssertEqual(decision.audio, japaneseOriginal)
    XCTAssertEqual(decision.audioScope, TrackMemoryScope.anime)
    XCTAssertEqual(decision.subtitle?.lang, "ru")
  }

  func testTheEpisodeItselfIsAskedBeforeTheSeason() {
    var episode = TrackPreferenceLedger()
    episode.recordAudio(mosfilmDub.signature, at: day(50), weight: 1)

    var season = TrackPreferenceLedger()
    season.recordAudio(lostfilmMVO.signature, at: day(40), weight: 9)

    let ledgers = [
      ScopedLedger(scope: .episode(titleID: seriesID, season: 2, episode: 5), ledger: episode),
      ScopedLedger(scope: .season(titleID: seriesID, season: 2), ledger: season),
      ScopedLedger(scope: .title(id: seriesID), ledger: establishedLedger())
    ]
    let decision = decide([mosfilmDub, lostfilmMVO, syenduk], ledgers: ledgers)
    XCTAssertEqual(decision.audio, mosfilmDub, "a rewatch replays what this episode played")
    XCTAssertEqual(decision.audioScope,
                   TrackMemoryScope.episode(titleID: seriesID, season: 2, episode: 5))
  }

  // MARK: - The priority chain

  func testChainForAnEpisodeOfAnAnimeSeries() {
    XCTAssertEqual(
      TrackMemoryScope.chain(titleID: seriesID, season: 2, episode: 5, isAnime: true),
      [.episode(titleID: seriesID, season: 2, episode: 5),
       .season(titleID: seriesID, season: 2),
       .title(id: seriesID),
       .anime]
    )
  }

  func testChainForAFilmIsJustTheTitle() {
    XCTAssertEqual(TrackMemoryScope.chain(titleID: seriesID), [.title(id: seriesID)])
  }

  func testChainSkipsTheAnimeBucketForOtherGenres() {
    XCTAssertEqual(
      TrackMemoryScope.chain(titleID: seriesID, season: 1, episode: 1, isAnime: false),
      [.episode(titleID: seriesID, season: 1, episode: 1),
       .season(titleID: seriesID, season: 1),
       .title(id: seriesID)]
    )
  }

  // MARK: - The dub floor

  func testDubFloorPrefersTheOriginalOverATwoVoiceDub() {
    var settings = PlaybackLanguagePreferences.default
    settings.minimumDubKind = 1 // multi-voice or better

    let decision = decide([jaskierDVO, englishOriginal],
                          settings: settings,
                          profile: TitleTrackProfile(originalLanguageKey: "en"))
    XCTAssertEqual(decision.audio, englishOriginal)
    XCTAssertEqual(decision.audioReason, .originalPreferred)
  }

  func testDubFloorFindsTheOriginalEvenWithoutACountryHint() {
    var settings = PlaybackLanguagePreferences.default
    settings.minimumDubKind = 1

    let decision = decide([jaskierDVO, englishOriginal], settings: settings)
    XCTAssertEqual(decision.audio, englishOriginal)
    XCTAssertEqual(decision.audioReason, .originalPreferred)
  }

  func testDubFloorAcceptsAMultiVoiceThatMeetsIt() {
    var settings = PlaybackLanguagePreferences.default
    settings.minimumDubKind = 1

    let decision = decide([lostfilmMVO, jaskierDVO, englishOriginal], settings: settings)
    XCTAssertEqual(decision.audio, lostfilmMVO)
    XCTAssertEqual(decision.audioReason, .ladder)
  }

  /// A Russian film's own soundtrack is not a dub, and the floor must not exile it.
  func testDubFloorNeverFiltersAnOriginalTrack() {
    var settings = PlaybackLanguagePreferences.default
    settings.minimumDubKind = 1

    let russianOriginal = audio("ru", 6)
    let decision = decide([russianOriginal], settings: settings)
    XCTAssertEqual(decision.audio, russianOriginal)
  }

  func testDubFloorStillPlaysSomethingWhenNothingMeetsIt() {
    var settings = PlaybackLanguagePreferences.default
    settings.minimumDubKind = 0 // dubbed only

    let singleVoice = audio("ru", 4, "Кто-то")
    let decision = decide([jaskierDVO, singleVoice], settings: settings)
    XCTAssertEqual(decision.audio, jaskierDVO, "the floor prefers, it does not refuse to play")
    XCTAssertEqual(decision.audioReason, .ladder)
  }

  // MARK: - Anime and subtitles

  func testAnimeTogglePrefersTheOriginalAndTurnsSubtitlesOn() {
    var settings = PlaybackLanguagePreferences.default
    settings.animePrefersOriginalAudio = true

    let decision = decide([lostfilmMVO, japaneseOriginal],
                          subtitles: subtitleTracks(["ru", "en"]),
                          settings: settings,
                          profile: TitleTrackProfile(isAnime: true, originalLanguageKey: "ja"))
    XCTAssertEqual(decision.audio, japaneseOriginal)
    XCTAssertEqual(decision.audioReason, .originalPreferred)
    XCTAssertEqual(decision.subtitle?.lang, "ru")
    XCTAssertEqual(decision.subtitleReason, .audioNotUnderstood)
  }

  func testAnimeWithoutTheToggleTakesTheDubLikeAnythingElse() {
    let decision = decide([lostfilmMVO, japaneseOriginal],
                          subtitles: subtitleTracks(["ru"]),
                          profile: TitleTrackProfile(isAnime: true, originalLanguageKey: "ja"))
    XCTAssertEqual(decision.audio, lostfilmMVO)
    XCTAssertNil(decision.subtitle)
    XCTAssertEqual(decision.subtitleReason, .off)
  }

  /// The same rule, with no anime anywhere: a film that only ever had an English track.
  func testAFilmWithNoUnderstoodAudioTurnsSubtitlesOn() {
    var settings = PlaybackLanguagePreferences.default
    settings.audioLanguages = ["ru"]
    settings.subtitleLanguages = ["ru"]

    let decision = decide([englishOriginal],
                          subtitles: subtitleTracks(["ru", "en"]),
                          settings: settings)
    XCTAssertEqual(decision.audio, englishOriginal)
    XCTAssertEqual(decision.subtitle?.lang, "ru")
    XCTAssertEqual(decision.subtitleReason, .audioNotUnderstood)
  }

  func testSubtitlesStayOffWhenTheAudioIsUnderstood() {
    let decision = decide([mosfilmDub], subtitles: subtitleTracks(["ru", "en"]))
    XCTAssertNil(decision.subtitle)
    XCTAssertEqual(decision.subtitleReason, .off)
  }

  func testSubtitlesTurnedOffOnceStayOff() {
    var ledger = TrackPreferenceLedger()
    ledger.recordSubtitle(.off, at: day(3), weight: 5)

    let decision = decide([japaneseOriginal],
                          subtitles: subtitleTracks(["ru"]),
                          ledgers: titleScope(ledger),
                          profile: TitleTrackProfile(isAnime: true, originalLanguageKey: "ja"))
    XCTAssertNil(decision.subtitle)
    XCTAssertEqual(decision.subtitleReason, .remembered)
  }

  func testARememberedSubtitleLanguageSurvivesTheEpisodeChange() {
    var ledger = TrackPreferenceLedger()
    ledger.recordSubtitle(SubtitleChoiceSignature(languageKey: "en", isCC: false),
                          at: day(3),
                          weight: 4)

    // Next episode: different sidecar URLs, same languages.
    let decision = decide([mosfilmDub],
                          subtitles: subtitleTracks(["ru", "en"]),
                          ledgers: titleScope(ledger))
    XCTAssertEqual(decision.subtitle?.lang, "en")
    XCTAssertEqual(decision.subtitleReason, .remembered)
  }

  func testARememberedSubtitleLanguageThatIsGoneFallsThrough() {
    var ledger = TrackPreferenceLedger()
    ledger.recordSubtitle(SubtitleChoiceSignature(languageKey: "de", isCC: false),
                          at: day(3),
                          weight: 4)

    let decision = decide([mosfilmDub],
                          subtitles: subtitleTracks(["ru", "en"]),
                          ledgers: titleScope(ledger))
    XCTAssertNil(decision.subtitle)
    XCTAssertEqual(decision.subtitleReason, .off)
  }

  func testForcedSubtitlesAreNeverADefault() {
    var settings = PlaybackLanguagePreferences.default
    settings.audioLanguages = ["ru"]
    settings.subtitleLanguages = ["ru"]

    let tracks = SubtitleTracks.catalog([subtitle("ru", url: "https://cdn/ru.forced.srt")])
    let decision = decide([englishOriginal], subtitles: tracks, settings: settings)
    XCTAssertNil(decision.subtitle, "forced tracks carry signage only")
  }

  // MARK: - Subtitles follow the system, then the same ladder audio does

  private var subtitlesOn: PlaybackLanguagePreferences {
    var settings = PlaybackLanguagePreferences.default
    settings.subtitlesDefaultOn = true
    return settings
  }

  /// The viewer watches everything with subtitles — the system already knows that, so a
  /// dubbed title gets them too.
  func testSubtitlesOnInTheSystemMeansOnHere() {
    let decision = decide([mosfilmDub],
                          subtitles: subtitleTracks(["ru", "en"]),
                          settings: subtitlesOn)
    XCTAssertEqual(decision.subtitle?.lang, "ru")
    XCTAssertEqual(decision.subtitleReason, .systemDefault)
  }

  func testSubtitlesOffInTheSystemLeavesADubbedTitleBare() {
    let decision = decide([mosfilmDub], subtitles: subtitleTracks(["ru", "en"]))
    XCTAssertNil(decision.subtitle)
    XCTAssertEqual(decision.subtitleReason, .off)
  }

  /// Watching in Russian, reading English, because the point is the language practice.
  func testEnglishSubtitlesOverRussianAudioAreRemembered() {
    var ledger = TrackPreferenceLedger()
    ledger.recordSubtitle(SubtitleChoiceSignature(languageKey: "en", isCC: false),
                          at: day(4),
                          weight: 3)

    let decision = decide([mosfilmDub],
                          subtitles: subtitleTracks(["ru", "en"]),
                          ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, mosfilmDub)
    XCTAssertEqual(decision.subtitle?.lang, "en")
    XCTAssertEqual(decision.subtitleReason, .remembered)
  }

  /// Anime in the original with English subtitles, remembered on the anime bucket so the
  /// next series opens the same way.
  func testAnimeInTheOriginalWithEnglishSubtitlesCarriesToTheNextTitle() {
    var anime = TrackPreferenceLedger()
    anime.recordAudio(japaneseOriginal.signature, at: day(5), weight: 9)
    anime.recordSubtitle(SubtitleChoiceSignature(languageKey: "en", isCC: false),
                         at: day(5),
                         weight: 9)

    let ledgers = [
      ScopedLedger(scope: .title(id: 777), ledger: TrackPreferenceLedger()),
      ScopedLedger(scope: .anime, ledger: anime)
    ]
    let decision = decide([japaneseOriginal, lostfilmMVO],
                          subtitles: subtitleTracks(["ru", "en"]),
                          ledgers: ledgers,
                          profile: TitleTrackProfile(isAnime: true, originalLanguageKey: "ja"))
    XCTAssertEqual(decision.audio, japaneseOriginal)
    XCTAssertEqual(decision.subtitle?.lang, "en")
  }

  /// The other anime viewer: original audio, Russian subtitles, and Russian is the only
  /// subtitle language on offer.
  func testAnimeInTheOriginalWithTheOnlySubtitlesThereAre() {
    var settings = PlaybackLanguagePreferences.default
    settings.animePrefersOriginalAudio = true

    let decision = decide([japaneseOriginal, lostfilmMVO],
                          subtitles: subtitleTracks(["ru"]),
                          settings: settings,
                          profile: TitleTrackProfile(isAnime: true, originalLanguageKey: "ja"))
    XCTAssertEqual(decision.audio, japaneseOriginal)
    XCTAssertEqual(decision.subtitle?.lang, "ru")
    XCTAssertEqual(decision.subtitleReason, .audioNotUnderstood)
  }

  /// Unknown subtitles: none of them are in a language the viewer reads, but they asked
  /// for subtitles, so a track they can at least see beats nothing.
  func testSubtitlesInAnUnreadLanguageStillAppearWhenAskedFor() {
    var settings = subtitlesOn
    settings.audioLanguages = ["ru"]
    settings.subtitleLanguages = ["ru"]

    let decision = decide([mosfilmDub],
                          subtitles: subtitleTracks(["pt"]),
                          settings: settings)
    XCTAssertEqual(decision.subtitle?.lang, "pt")
    XCTAssertEqual(decision.subtitleReason, .systemDefault)
  }

  func testNoSubtitleTracksDecidesNothingRatherThanOff() {
    let decision = decide([mosfilmDub], subtitles: [], settings: subtitlesOn)
    XCTAssertNil(decision.subtitle)
    XCTAssertEqual(decision.subtitleReason, .none, "nothing was on offer, so nothing was decided")
  }

  /// Original audio, no dub, no subtitles at all — the case Apple's generated captions
  /// would later fill. Today it must simply not crash or invent a track.
  func testOriginalAudioWithNothingToReadIsSilentAboutSubtitles() {
    var settings = subtitlesOn
    settings.audioLanguages = ["ru"]
    settings.subtitleLanguages = ["ru"]

    let decision = decide([englishOriginal], subtitles: [], settings: settings)
    XCTAssertEqual(decision.audio, englishOriginal)
    XCTAssertNil(decision.subtitle)
  }

  /// Turning them off against a system that has them on is the strong signal, and it wins
  /// on the next episode.
  func testTurningSubtitlesOffBeatsTheSystemDefault() {
    var ledger = TrackPreferenceLedger()
    ledger.recordSubtitle(.off, at: day(6), weight: 1)

    let decision = decide([mosfilmDub],
                          subtitles: subtitleTracks(["ru"]),
                          ledgers: titleScope(ledger),
                          settings: subtitlesOn)
    XCTAssertNil(decision.subtitle)
    XCTAssertEqual(decision.subtitleReason, .remembered)
  }

  func testSubtitleMemoryFollowsTheSameScopeChainAsAudio() {
    var season = TrackPreferenceLedger()
    season.recordSubtitle(SubtitleChoiceSignature(languageKey: "en", isCC: false),
                          at: day(7),
                          weight: 2)
    var title = TrackPreferenceLedger()
    title.recordSubtitle(SubtitleChoiceSignature(languageKey: "ru", isCC: false),
                         at: day(1),
                         weight: 8)

    let ledgers = [
      ScopedLedger(scope: .season(titleID: seriesID, season: 3), ledger: season),
      ScopedLedger(scope: .title(id: seriesID), ledger: title)
    ]
    let decision = decide([mosfilmDub], subtitles: subtitleTracks(["ru", "en"]), ledgers: ledgers)
    XCTAssertEqual(decision.subtitle?.lang, "en", "the season is asked before the series")
    XCTAssertEqual(decision.subtitleScope, TrackMemoryScope.season(titleID: seriesID, season: 3))
  }

  // MARK: - Signature identity

  /// The same team upgrading its two-voice track to a full dub is the same choice.
  func testAStudioIsRecognisedAcrossAKindUpgrade() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(audio("ru", 3, "LostFilm").signature, at: day(3), weight: 8)
    ledger.noteMenu([audio("ru", 3, "LostFilm")])

    let decision = decide([mosfilmDub, lostfilmMVO], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, lostfilmMVO)
    XCTAssertEqual(decision.audioReason, .remembered)
  }

  /// "Some other Russian track" is exactly what remembering a dub has to prevent.
  func testLanguageAloneIsNotAMatch() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(syenduk.signature, at: day(3), weight: 8)
    ledger.noteMenu([syenduk, mosfilmDub])

    let decision = decide([mosfilmDub, kurajMVO], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audioReason, .ladder)
    XCTAssertEqual(decision.audio, mosfilmDub)
  }

  func testStudioMatchingIgnoresCaseAndPadding() {
    XCTAssertEqual(AudioTrackSignature(audio("ru", 2, "  LostFilm ")),
                   AudioTrackSignature(audio("ru", 2, "lostfilm")))
  }

  // MARK: - Ledger weighting

  /// Two episodes of a stopgap must never outrank a season of the real preference,
  /// however recent they are.
  func testWeightOrdersTheLadderAheadOfRecency() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(lostfilmMVO.signature, at: day(1), weight: 99)
    ledger.recordAudio(jaskierDVO.signature, at: day(60), weight: 2)

    XCTAssertEqual(ledger.audioLadder.first?.signature, lostfilmMVO.signature)
  }

  func testRecencyOnlyBreaksATie() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(lostfilmMVO.signature, at: day(1), weight: 4)
    ledger.recordAudio(syenduk.signature, at: day(60), weight: 4)

    XCTAssertEqual(ledger.audioLadder.first?.signature, syenduk.signature)
  }

  func testRepeatedPlaysAccumulateWeight() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(syenduk.signature, at: day(1))
    ledger.recordAudio(syenduk.signature, at: day(2))
    ledger.recordAudio(syenduk.signature, at: day(3))

    XCTAssertEqual(ledger.audioLadder.first?.weight, 3)
    XCTAssertEqual(ledger.audio.count, 1)
  }

  /// An explicit pick has to steer the very next episode, not wait for a count to build.
  func testAnExplicitPickCountsImmediately() {
    var ledger = TrackPreferenceLedger()
    ledger.noteMenu([mosfilmDub, syenduk])
    ledger.recordAudio(syenduk.signature, at: day(1))

    let decision = decide([mosfilmDub, syenduk], ledgers: titleScope(ledger))
    XCTAssertEqual(decision.audio, syenduk)
  }

  func testRecordingATrackAlsoMarksItSeen() {
    var ledger = TrackPreferenceLedger()
    ledger.recordAudio(syenduk.signature, at: day(1))
    XCTAssertTrue(ledger.seenAudio.contains(syenduk.signature))
  }

  func testALedgerSurvivesACodableRoundTrip() throws {
    let ledger = establishedLedger()
    let data = try JSONEncoder().encode(ledger)
    let restored = try JSONDecoder().decode(TrackPreferenceLedger.self, from: data)
    XCTAssertEqual(restored, ledger)
  }

  // MARK: - Title profile inference

  /// Anime-ness is `MediaPresentationProfile`'s answer, not a second genre classifier.
  private func trackProfile(type: String = "serial",
                       genres: [String],
                       countries: [String],
                       trackLanguages: [String]) -> TitleTrackProfile {
    let presentation = MediaPresentationProfile(
      type: type,
      genres: genres.enumerated().map { TypeClass(id: $0.offset, title: $0.element, shortTitle: nil) }
    )
    return TitleTrackProfile.infer(presentation: presentation,
                                   countries: countries,
                                   trackLanguages: trackLanguages)
  }

  func testJapaneseOriginalIsInferredFromCountryAndTracks() {
    let profile = trackProfile(genres: ["Аниме", "Комедия"],
                               countries: ["Япония"],
                               trackLanguages: ["ru", "ja"])
    XCTAssertTrue(profile.isAnime)
    XCTAssertEqual(profile.originalLanguageKey, "ja")
  }

  func testACountryWhoseLanguageIsNotOnTheMenuIsIgnored() {
    let profile = trackProfile(genres: ["Аниме"],
                               countries: ["Япония"],
                               trackLanguages: ["ru"])
    XCTAssertNil(profile.originalLanguageKey, "never name a track that does not exist")
  }

  func testACartoonIsNotAnime() {
    let profile = trackProfile(genres: ["Мультфильм"],
                               countries: ["Россия"],
                               trackLanguages: ["ru"])
    XCTAssertFalse(profile.isAnime)
    XCTAssertEqual(profile.originalLanguageKey, "ru")
  }

  func testChineseOriginalIsInferred() {
    let profile = trackProfile(type: "movie",
                               genres: ["Боевик"],
                               countries: ["Китай"],
                               trackLanguages: ["ru", "zh"])
    XCTAssertEqual(profile.originalLanguageKey, "zh")
  }

  // MARK: - Settings resolution

  func testEmptyAudioLanguagesFallBackToTheSystem() {
    let settings = PlaybackLanguagePreferences.default
    XCTAssertEqual(settings.resolvedAudioLanguages(system: ["en-US", "ru-RU"]), ["en", "ru"])
  }

  func testExplicitAudioLanguagesOverrideTheSystem() {
    var settings = PlaybackLanguagePreferences.default
    settings.audioLanguages = ["ru"]
    XCTAssertEqual(settings.resolvedAudioLanguages(system: ["en-US"]), ["ru"])
  }

  func testSubtitleLanguagesMirrorAudioWhenUnset() {
    var settings = PlaybackLanguagePreferences.default
    settings.audioLanguages = ["ru", "en"]
    XCTAssertEqual(settings.resolvedSubtitleLanguages(system: []), ["ru", "en"])
  }

  func testReadingLanguagesMergeBothLists() {
    var settings = PlaybackLanguagePreferences.default
    settings.audioLanguages = ["ru"]
    settings.subtitleLanguages = ["en"]
    XCTAssertEqual(settings.readingLanguages(system: []), ["en", "ru"])
  }
}
