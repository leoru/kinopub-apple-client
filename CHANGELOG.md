# Changelog

Notable shipped changes and implementation facts future agents need. Trivial copy/token churn does
not belong here. Detail checklists live in [ROADMAP.md](ROADMAP.md).

## Unreleased

### CI skips macos-26 jobs when the diff cannot compile (2026-08-21)

- Fastlane, TestFlight yaml, markdown, `workers/`, `tools/` wake nothing.
  `xcassets` / `Localizable.xcstrings` still compile (a broken catalog must
  fail xcodebuild) but skip the simulator UI-test jobs. Swift / pbxproj still
  run the full matrix.

### TestFlight archive signing (2026-08-21)

- First CI run authenticated and minted App Store profiles for `com.soda.kinopub`.
  The archive then failed for two Fastfile bugs, not a missing bundle-id secret:
  global `xcargs` applied `PROVISIONING_PROFILE_SPECIFIER` to SPM packages
  ("does not support provisioning profiles"), and
  `CODE_SIGN_IDENTITY[sdk=macosx*]` was parsed as the identity
  `macosx*]=Apple Distribution`. Signing now writes onto the app target only.
  macOS sigh filenames are `.mobileprovision` (Fastlane rejects `.provisionprofile`).
- `APP_STORE_CONNECT_API_KEY_CONTENT` accepts base64 of the `.p8` **or** the PEM.

- `Xcodeproj::Project.open` was resolving `KinoPubAppleClient.xcodeproj` under
  `fastlane/` (Fastlane's cwd). The path is now absolute from the repo root.

### TestFlight upload (2026-08-21)

Signing and archive succeeded on [run 32497341767](https://github.com/HipsterCat/kinopub-apple-client/actions/runs/32497341767).
App Store Connect then rejected iOS/tvOS, and macOS Release did not compile:

- **iOS 90717:** the 1024 App Store icon had an alpha channel (and was a
  placeholder, not our mark). The set is now the KinoPub mark, opaque RGB.
- **tvOS 90513:** no Brand Assets, so `CFBundleIcons.CFBundlePrimaryIcon` and
  `TVTopShelfImage.TVTopShelfPrimaryImageWide` were missing.
  `AppIcon.brandassets` sits next to `AppIcon.appiconset` under the same
  `ASSETCATALOG_COMPILER_APPICON_NAME`.
- **macOS:** `LibraryFiltersBar` applied `UILabGlassChipStyle`, which exists
  only in the DEBUG UI Lab. `LibraryFilterGlassStyle` already owns the glass;
  the extra modifier is gone.

### Internal TestFlight from GitHub Actions (2026-08-21)

- **Actions → TestFlight** archives Release of the one multiplatform target for
  iOS, tvOS and macOS and uploads to TestFlight as a technical internal build
  (`distribute_external: false`). Manual `workflow_dispatch` only — no git tag,
  no GitHub Release, no App Store submission.
- **One shared `CURRENT_PROJECT_VERSION`** is reserved first (max of the three
  platforms' latest TestFlight numbers + 1), then the archives fan out. Marketing
  version stays whatever is in the project (`1.0` today).
- Signing is Swiftfin-shaped: App Store Connect API key + a persistent Apple
  Distribution p12 in GitHub secrets, provisioning profiles minted by sigh so
  entitlements can change without re-exporting a profile. Not Match (no extra
  certs repo), not Codemagic (Rivulet's split), not Xcode Cloud (config would
  live outside the repo).
- `ITSAppUsesNonExemptEncryption=false` is in `Info.plist` so a build does not
  sit on "Missing Compliance" until someone clicks the questionnaire — this app
  only uses HTTPS. Testers still have to be App Store Connect Users (or named
  in `TESTFLIGHT_INTERNAL_GROUPS`).
- Secrets are not in the repo; the first upload waits on them. Checklist is the
  comment at the top of `.github/workflows/testflight.yml`.

### Which dub a title opens with is now a decided rule, not player-local guesswork (2026-08-20)

- **`TrackResolver` decides audio and subtitles as one pure function** over a menu, what
  the scopes remember, the settings and the system languages. No player, no network, no
  storage — a card can ask it before the player exists, which is what the pre-open resolve
  needs. Rules and their reasons: [docs/product/playback-tracks.md](docs/product/playback-tracks.md).
- **Scopes, most specific first: season → title → `anime` class → ladder.** Season, because
  studios change between seasons. The anime class, because a preference for watching anime
  in the original belongs to anime, not to one title. Cartoons (genre 23) are not anime.
- **A dub is remembered as language + kind + studio**, never a rendition name, index or URL
  — those differ between two episodes of one season. A studio that upgrades its two-voice
  track to a full dub still matches; "some other Russian track" deliberately does not.
- **Weight is episodes watched, not picker opens.** Two episodes of a stopgap must not
  outrank a season of the real preference. Count orders the ladder, recency only breaks ties.
- **A dub never offered before beats a habit under `confidentWeight` (3).** This is the
  "watched three episodes before anyone dubbed it properly, came back to five more seasons"
  case. At or above that weight the habit holds, so a fresh dub cannot displace a studio the
  viewer chose for a season.
- **`minimumDubKind` prefers the original with subtitles over a dub below the floor**, and
  never filters original or unknown-kind tracks — the floor is about dub quality. Ships as
  `nil` so nothing changes silently.
- **Subtitles are the same mechanism as audio**, not a lesser one: same scope chain, same
  ledger, same weights. With no history the app mirrors the system's own captions setting
  (Accessibility → Subtitles & Captioning, via `MediaAccessibility`), whose caption
  languages also seed the language order. On top of that they come on whenever the audio
  that won is in a language the viewer does not read — the anime in Japanese, the film that
  only ever had an English track. Subtitles in a language the viewer cannot read still beat
  nothing once subtitles were asked for; "off" is a remembered choice; and an item that
  offered no track writes nothing at all.
- **`isAnime` lives on `MediaPresentationProfile`**, which is the one place a rule that
  depends on type or genre is derived. Separate from `kind`, because an anime and a cartoon
  are drawn the same way and only one of them is normally watched in the original. kino.pub
  files anime as a genre — `MediaType` has no case for it.
- Original language is inferred from the countries on the title against the languages
  actually on the menu. Nothing is fetched for it and no provider field was added.
- **The priority chain is `TrackMemoryScope.chain`** — episode → season → title → genre →
  app settings → system languages, in one place so no caller can assemble it differently.
  The last two are the ladder, not scopes, and app settings mirror the system list until set.
- 54 scenario tests in `TrackResolverTests`, green on CI.

### What a title will play is answerable before the player opens (2026-08-20)

- **`PlaybackPreflight`** owns the question. `decision(for:profile:)` answers from what is
  already loaded — no network — so a card, a Play button or a diagnostics screen can ask
  while drawing. `PlayerManager` asks through it too and contributes only what it alone can
  see: the real renditions, for a master the API gave no track metadata for. Two ways of
  assembling those inputs would have been two answers.
- **`warm(_:)` moves the media-links request out of the tap.** A series episode arrives
  without links and the player used to fetch them on open, which is dead time on a spinner.
  The detail hero warms its play target while the page is on screen. A no-op for anything
  already playable, and `MediaLinksResolver` runs one request per media id however many
  callers ask, so re-running it costs nothing. Failure is silent on purpose — the player
  still resolves for itself and still owns reporting a stream it cannot play.
- `audioSummary(for:profile:)` names the dub that will play. Nil for a single track.

### App test targets exist, and CI runs them (2026-08-20)

- `KinoPubAppleClientTests` (unit, hosted) and `KinoPubAppleClientUITests` (XCUITest),
  written into `project.pbxproj` by hand — there is no project generator in this repo.
  Both are `buildForTesting` only in the scheme, so the compile jobs stay as fast as they
  were, and a `test-app` job runs them on a tvOS and an iOS simulator.
- **The simulator is picked by udid, never by name.** Runner images rename and renumber
  their devices; a hard-coded `Apple TV 4K (3rd generation)` is a job that dies on the next
  image refresh.
- **A CI runner has no kino.pub session** — `DevSessionMirror` seeds one only from a
  developer's own machine — so the UI tests assert what is reachable without auth: the app
  launches and paints something. Focus is not asserted; it needs content, and a screenshot
  cannot show whether a landing felt right.
- **The app target's Swift module is `KinoPub`, not `KinoPubAppleClient`.** `PRODUCT_NAME`
  is KinoPub and nothing overrides `PRODUCT_MODULE_NAME`.
- **A witness to a public protocol from another module must be `public`**, whatever the
  visibility of the conformance — `extension AVMediaSelectionOption: AudioRendition` needs
  `public var renditionName`.

### CI was red on tvOS and iOS, for three unrelated reasons (2026-08-20)

Found while building the track work, all pre-existing, all now fixed:

- `TVUIKitMediaItemStatusTests` was not fenced, and `TVUIKitMediaItem` is `#if os(tvOS)` —
  it broke `swift test` for the whole of KinoPubUI.
- `MediaCardView`'s watched-artwork opacity read `isHovered`, which is declared under
  `#if os(macOS)`. Both simulator builds failed.
- A `UILabGlassChipStyle` modifier — macOS- **and** DEBUG-only, from UILab — had been
  pasted into `LibraryFiltersBar`'s sort menu. Both simulator builds failed.

**Why nobody saw them:** `swift test` runs a package on **macOS only**. A symbol fenced to
macOS and used unfenced compiles there and fails every simulator build, so green package
tests prove nothing about tvOS or iOS. The `xcodebuild` jobs are the only guard.

### The player asks the resolver, and the two old track memories are gone (2026-08-20)

- **`AudioTrackMemory` and `AudioTrackRanker` are deleted.** The first keyed a dub by its
  rendition display name; HLS uniques duplicate `NAME=` with a " ∙ n" suffix and renditions
  are not ordered the same across episodes, so the handle did not survive the one jump it
  existed for. The second re-implemented the detail page's ladder and knew nothing about
  history. `AVMediaSelectionOption.kinopubTrackName` survives, and gains
  `kinopubLanguageCode`.
- **`TrackPreferenceStore`** (`Services/Playback/`) owns the ledgers, keyed by
  `TrackMemoryScope.storageKey`, and writes to every scope a play teaches. It migrates
  `subtitleTrackChoices` — a `SubtitleTrackReference` carries a real language code — and
  **drops `audioTrackChoices`**, which stored a display name that cannot be reversed into
  one. Those pick themselves up again on the next choice.
- **`PlaybackSession` derives `TitleTrackProfile`** and hands it to the player. Genres and
  countries are on the *item*, and an `Episode` is not one — the series snapshot in
  `LocalWatchProgressStore` is where they are read from, so playing straight from Continue
  Watching still knows an anime is an anime.
- Audio and subtitles ask **one** decision, so they cannot disagree about what is playing.
  With no API track metadata the menu is synthesised from the renditions themselves, so an
  unlabelled master still gets a considered pick rather than AVFoundation's first rendition.
- A play is recorded once it passes `WatchProgress.enterContinueWatchingSeconds`, not on
  open: weight is episodes watched, and a title sampled for a minute teaches nothing.
- The old "Default English subtitles" switch now decides *which* language wins when
  subtitles appear, not whether they appear — that is the system's answer.
  `SubtitleSelector` no longer selects; it catalogues.
- **`AudioRenditions` owns the bridge** between a decided `AudioTrackInfo` and the
  rendition the player can select, behind an `AudioRendition` protocol that
  `AVMediaSelectionOption` conforms to. It was in `PlayerManager` behind a type that needs
  a real asset to construct, so the sharpest rules in the feature — duplicate ` ∙ n`
  suffixes, one label being a prefix of another, the no-API-metadata path — were untestable.
- **Verification:** green on CI — tvOS, iOS and macOS builds plus every package suite —
  with 77 tests over the rules and the bridge. **Nothing here has been watched on a
  device**; that the right rendition is actually selected in a real player is unconfirmed.


### Continue Watching stops offering junk in an arbitrary order (2026-08-20)

- **The row is capped** (`ContinueWatchingOrder.maxItems`). `/v1/watching/serials`
  returns every unfinished serial on the account, so the shelf scrolled sideways
  through hundreds of titles nobody remembers starting.
- **Undated titles sort by backlog.** Neither watching endpoint carries a timestamp —
  the only dates in this row come from the one page of `/v1/history` we fetch — so most
  of the row tied on bucket *and* date and fell through to the server's list order. It
  now falls through to `new` ascending: one or two unwatched episodes is a title being
  followed, a hundred and seventy is one abandoned. Films count as zero.
- **`WatchProgress.enterContinueWatchingSeconds` (90 s)** gates a card the server never
  listed. `startedSeconds` stays 10 s and keeps meaning "has begun" — it paints a bar on
  a card already in the row. A local-only card has nothing to take it back out, which is
  how a minute of a trailer became something to "continue".
- The rules are in [docs/product/continue-watching.md](docs/product/continue-watching.md).
- Unrelated, found on the way: `ContinueWatchingLocalOverlayTests` had two calls with
  arguments in the wrong order, which stopped the whole `KinoPubBackend` test target
  from compiling. Fixed; 305 tests pass.

### Card geometry, shelf rhythm, and chrome that stays put (2026-08-20)

- **A poster's height follows its column again.** `MediaCardView` measured the
  artwork's own width and fed the height back into it; `aspectRatio(_:contentMode:
  .fit)` accepts *every* width no wider than the one offered, so `w × w/ratio` was a
  stable answer for any `w` — the card kept whatever width it first landed on. A
  window resize then grew the column and the caption while the artwork stood still
  (measured: 3 columns, 500pt → 1100pt, grid height 194 → 98 before, 193 → 425 after).
  The width now comes from a zero-height `maxWidth: .infinity` probe above the
  artwork, which nothing can clamp, and the box is pinned in both directions.
- **`ShelfMetrics`: the ladder no longer falls back at the top, and the gutter is
  derived.** Past the last named breakpoint it adds a column every 200pt instead of
  dropping from 8 columns to 6 (which inflated every card the moment a Mac window
  passed 1600pt). Gutter is always `inset / 2` — hand-picked per-step gutters (20 /
  28 / 32 / 24 for banners) made the gap between two posters as wide as the page
  margin on a phone, and a different width at every breakpoint. The phone step now
  runs to 520pt, so a 440pt Pro Max keeps 3 columns instead of four 72pt ones.
- **`Metrics.sectionHeaderSpacing`** joins `rowSpacing` as the two numbers that own a
  page of sections; `landscapeFocusPadding` equals `focusPadding` off tvOS (it is
  focus-lift room, and there is no focus engine there), so Continue Watching sits the
  same distance under its header, and above the next section, as every poster rail.
- **`SectionHeader` hugs its own words.** It was `maxWidth: .infinity` with the tap
  shape over all of it, so the "see all" link — and any hover on it — covered the full
  width of the grid; a click level with the title but four columns to the right
  navigated. The leading inset is outside the shape now too, and the tvOS pagination
  badge keeps its trailing position via a spacer instead of the header's old fill.
  An HDR-boosted hover tried here the same day was **reverted**: over a grey page with
  white labels the boost is invisible, and highlighting a full-width region with a
  dead gap under it is not a thing anyone does. `Color.KinoPub.hdrHighlight` is gone
  with it — do not re-add either without being asked.
- **macOS search now reaches `/v1/items/search` at all**, and runs while you type.
  `LibraryCatalog.init` takes a seed query, `TabsNavigationView` fills it from the
  toolbar field, and the first non-blank character opens the surface. **The how and
  why live on `LibraryCatalog` itself** — deliberately not repeated here.
- **`MediaRow.onOpen`** — a "see all" that is not a push. Continue Watching's chevron
  selects the Library tab, where the same titles live split into series, films and
  history. `HomeCatalog` still knows nothing about tabs: `MainView` attaches it.
- **The macOS tab bar stays drawn while searching.** Search used to be laid over the
  whole `TabView`, which took the tabs with it; it now fills the content of the tab it
  was entered from (that one tab only — every root stays mounted, so answering
  "search" for all four would stand up four `SearchView`s and four fetches).
- **An empty search field offers starters**, not just recents — recents cannot answer
  on a first run. `/v1/items/search` matches `title` / `director` / `cast`, so the
  examples are names as well as titles.

### Community architecture, without their UI (2026-08-18)

- **`MediaLibraryStore`** — the per-item optimistic library from
  dungeon-master-xx (watchlist, watched overrides, votes, download façade,
  local-progress query). Wired through `AppContext` and the detail page.
  Does **not** replace `ContentStore` (Home/Library rows) or the bookmark
  stores. Votes migrate out of the old `UserDefaults` key once.
- **`WatchProgress.resumeFraction` is what a card paints.** The landscape time
  chip, TVUIKit rail status, poster progress bar, episode/variant mapping, and
  history/Play progress all stopped re-thresholding `time / duration` at 0.95 /
  0.02. Those fudges were a second credits window (six minutes left on a
  two-hour title vs the classifier's three). Outro markers will feed
  `WatchProgress`, not the views.
- **Continue Watching trusts local progress.** The player still does not
  invalidate Home TTL (a full `.watch` refetch was the wrong lever). Instead
  `assembleRows` overlays `LocalWatchProgressStore` onto the cached row: the
  bar moves on the next tick, a finished film disappears, a finished episode
  steps to the next S/E. Offered S/E stays on the card so a TTL refresh does
  not refetch up to 12 series details. `rows-v2.json` is not rewritten from
  the playhead.
- A literal merge of `community/main` is still rejected: ~73 overlapping
  files, almost all Views. Continue Watching, lazy SwiftUI stacks, and
  `WatchProgress` were already on our side; glass stays `kinoGlass`.

### Flags, a Video rename, full quality list, CC moved to Languages (2026-08-17)

- **`FlagGlyph`** (`KinoPubUI`): a round flag keyed by ISO 639-1 language code or
  ISO 3166-1 country code — both resolve to `flag_<code>` in `Media.xcassets`, so the
  same view will serve a language row and a country tag later. The asset set is added
  separately (by hand); a code with no matching file draws nothing rather than a
  broken-image glyph — checked via `UIImage(named:in:)` / `NSBundle.image(forResource:)`
  before deciding whether to draw. `LanguagesCard`'s rows lead with one now.
- **"Technical" is `MediaItem_VideoCard` → "Video"** (`TechnicalCard`/`TechnicalBadge`
  renamed to `VideoCard`/`VideoBadge` to match). Left `MediaItem_Technical` alone —
  that key still titles a column in the separate, still-switchable `MediaItemAboutLayouts`
  experiment, and renaming its text would have relabelled a different section.
- **The Subtitles badge left the Video card** — the Languages card already puts a CC
  glyph on every language that actually has one, which says more than a title-wide
  flag did.
- **The Video card's popup lists every quality the title offers**, not just the top
  one: `mediaItem.videoTechLines` (`"1080p · h264 · 1920×1080"` per distinct file),
  shown only when there is more than one — "what am I about to download" is a
  quality-picking decision, not a glance.
- No SDH badge yet, but not never: kino.pub's payload cannot tell a hard-of-hearing
  track from a translated one today; once OpenSubtitles (or another SDH-tagging
  source) is wired, only the badge list changes.

### The badge cards got a third card, a real order, and less to hide behind (2026-08-17)

- 🔴 **Reordered by what a viewer decides with, not by what was easiest to compute.**
  The rail was Technical → Age Rating; it is now **Age Rating → Languages → Technical**
  — can whoever's in the room watch this at all, can *you* understand it, and only
  then what it technically is. The old order buried the one card that gates the other
  two behind the one nobody actually opens first.
- **Languages joins the rail** (`LanguagesCard`) — the card the mockup showed and the
  page never had. Best dub per preferred language (reused, not reinvented: same
  `AudioTracks` DUB→MVO→DVO→VO→AVO→Orig ranking, same `LanguageListVisibility`
  collapsing), a CC glyph on any language that also has subtitles, "+N languages" for
  the rest, full breakdown in the popup. **Superseded a dead, never-instantiated
  `LanguagesCard`** that duplicated this exact job inside `MediaItemInfoColumns` — one
  live implementation now, and five now-orphaned metrics (`languageGroupSpacing`,
  `languageNameToKindSpacing`, `subtitleExtraTop`, `detailFont`) deleted with it.
- **The Age Rating card decodes itself without a tap now.** `MediaItem_LegendAgeRating`
  ("Возрастная категория тайтла.") used to live only behind the popup; a title with no
  advisory flags — most of them — showed a bare checkmark and a number, which is what
  read as empty. It's inline under the number always, same as the popup, so the
  collapsed card says something even when kino.pub gave us nothing else to add.
- **A DEBUG-only illustration, not a shipped guess.** `CapabilityGlyph` gained
  `.dolbyVision` / `.dolbyAtmos` — real assets — and a
  `#Preview("Technical card, with a Dolby signal (illustration)")` renders them against
  fabricated badge data, explicitly marked non-reachable from `technicalBadges`. This
  is "look at it without wiring it to a real source" done the way the repo's own rule
  requires: a real user can never see a badge the app cannot back, only whoever opens
  the preview can.
- `mediaItemPreferredLanguages()` joins `mediaItemAdvisories(_:)` as a second shared
  free function — the language-ranking logic was about to exist in the info table and
  the new card as two copies.

### Technical and Parental Advisory cards, on the same block shape (2026-08-17)

- **`MediaItemBadgeCardsSection`** (iOS/macOS): a `BlockRail` of two `BlockCard`s, right
  after Facts/Reviews and before the untouched info table — a Technical card (quality,
  3D, AC-3, subtitles, audio description, each as an icon + spelled-out label) and a
  Parental Advisory card (the age rating under a checkmark, plus whatever real
  advisory kino.pub sent). Same component the ratings/reviews/facts rails already use;
  nothing about the table or `InfoFooter` beneath it changed.
- 🔴 **Only a real signal gets a badge.** kino.pub sends no HDR / Dolby Vision / Dolby
  Atmos / MPAA flag, so those stay off — the same rule `aboutBadges` already followed,
  restated here because the mockup this was sketched from draws exactly those. Their
  icon assets (`dolby-vision`, `dolby-atmos`, `tv-ma`, `R`, `subtitle`) are in
  `Media.xcassets`, unreferenced, on purpose — see `MediaItemBadgeCardsSection`'s doc
  comment for where they plug in once a real source exists.
  `MediaCapabilityBadges.isHDR` is real but only ever filled from a probed HLS
  `VIDEO-RANGE`, which the detail page does not fetch.
- **`CapabilityGlyph`** (`KinoPubUI`): the app target cannot reach `Bundle.module` —
  every catalogue image before this went through a public wrapper defined inside
  `KinoPubUI` (`MediaScoreLogo`, the "wing" icon), and this is the same idiom for the
  quality/3D/CC/AD/checkmark pills. Fixed height, free width, `.template` tint.
- **Tapping a card opens the shared `InfoPopup`** — the same "the clipped thing is the
  trigger" mechanism `AboutColumn` / `AboutLegendColumn` already use — not a page, and
  not a new expansion mechanism. Each badge gets its full sentence there
  (`MediaItem_Legend*`, already localized, plus a new `MediaItem_Legend3D`).
- Parental Advisory never writes a sentence we were not given: an age rating with no
  advisory flags draws the number alone rather than manufacturing a reason for it.
- `mediaItemAdvisories(_:)` replaces the `advisories` logic that was about to exist in
  two places (`MediaItemInfoColumns` and the new card) — one function, both callers.

### One card shape for the page's blocks, tried on Ratings and Reviews first (2026-08-17)

- **`BlockCard` / `BlockRail` / `BlockMetrics`** (`KinoPubUI`) — the card every block-shaped section
  on iOS/macOS is meant to be built from. Two kinds, **one look**: `.interactive` (the card is the
  control) and `.flat` (the card is a surface holding its own rows — the table shape). One
  component configured, not a card per section; the next blocks (facts, photos, information
  columns) go on the same one. tvOS compiles but is not a customer — its media surfaces are TVUIKit,
  and the section is not shown there.
- **Fill is a `Material`, never a colour.** The detail page sits on an ambient wash of the title's
  own artwork, so a fixed grey stops belonging to it. Hover deepens the material
  (`.regular` → `.thick`) instead of tinting — that is the only "raised" move available without
  introducing a colour the page did not have. Not `kinoGlass`: glass is chrome floating *over*
  content, and a block card **is** content. Materials do their own Reduce Transparency degradation.
- 🔴 **Scores and opinions as one section** (`MediaItemRatingsAndReviewsSection`), the App Store's
  shape: a fixed-height rail of ratings card → review cards. **An experiment running beside the
  shipped row, not replacing it** — `MediaItemRatingsSection` is still on the page, on every
  platform, and so is `MediaItemReviewsSection`. Deleting the validated thing before the replacement
  is settled is how a comparison stops being possible; both go through one switch in `MediaItemView`
  when one wins.
- **The block is identical on every title**: one title (always "Ratings and Reviews"), one
  destination, always present. A header derived from what has loaded flickers, because enrichment is
  async — the chevron used to appear halfway through. **Every card in the rail opens the same page**
  through `BlockCard`'s new `.link` kind, so the block has exactly one destination and the cards
  visibly hover and press.
- **Nothing inside a card is separately clickable.** The per-source links move to the popup or to
  buttons of their own; a small target inside a big one competing for the same press is the thing
  the card shape exists to avoid.
- **The ratings card**: the aggregate as a number (`largeTitle`, rounded, **semibold**) and as
  `StarRatingRow` (new in `KinoPubUI`; takes a 0…5 value so nothing guesses the scale), stars
  **always orange** — a green or grey star row reads as a second signal contradicting the number.
  Under it, one `.body` line of "N Ratings · N рецензий"; the source chips are `.body` too.
- **kino.pub's own score is the community thumbs as one percentage** under the app's own mark —
  a thumbs system measures the share that liked it, and a lone SF Symbol in a row of brand logos
  reads as a different kind of thing. Display only until the Rate control is designed.
- **Sources are ordered by vote count**, biggest audience first. The order used to be the order the
  cases were written in, which put 300 voters ahead of 300 000 on every title.
- **Views are not a rating** and are not in the card; the review count is not a card of its own,
  because a tally with nothing to expand had no reason to be tappable.
- 🔴 **The aggregate weighs four sources now**, not two: IMDb, Kinopoisk, TMDB and kino.pub.
  `Rating.init?(scores:weights:)` iterates `MediaScores.inputs` instead of naming two fields, so a
  fifth source is data. Vote-weighting keeps it honest — on a title with 280k IMDb voters, adding
  TMDB's 1 536 and kino.pub's 560 moved 8.34 to 8.33.
- **TMDB is a rating source.** `vote_average` / `vote_count` were arriving on every details call and
  being dropped; `TitleMetadata.tmdbRating` / `.tmdbVotes` now, with a `.tmdb` case on
  `MediaScoreLogo.Source` (the asset was already there).
- **kino.pub is a rating source**: `likes / (likes + dislikes)`, printed as a percentage and
  averaged on the 0…10 scale, under the app's own mark (`kinopub` asset added to `KinoPubUI`).
  A thumbs system runs high — that is real, and turnout weighting is what stops it mattering.
- **`RatingWeights` exists and is all-on, equal.** A multiplier per source, `0` to exclude, so the
  settings pane this is heading for — tick what you trust, weigh one above another — changes a
  stored value rather than the shape of the calculation. "All sources, equally" is now a written
  default rather than the absence of a decision.
- **A card and the page it opens can differ by a tenth.** kino.pub's payload carries IMDb and
  Kinopoisk only; TMDB arrives with enrichment and the thumbs with the vote endpoint, so a poster
  badge aggregates two sources and the detail page four. Documented on `MediaScores` — the
  alternative is plumbing enrichment through every shelf to buy one decimal place.
- Both rating renderings read one `RatingSources`: which sources earn a tile, their order, what each
  prints, and where each links are one rule, not two copies of it.
- **Review cards have two modes, one component.** `.compact` in the rail — headline, body, sentiment,
  date, and nothing else; a preview earns its space by being readable, not by carrying every field
  at four points smaller. `.expanded` on the page — full body with the author's paragraphing intact,
  nickname, turnout tallies, and a link to the source. `Review` carries `sourceId` now too.
- **`FillingText`** (`KinoPubUI`): text that takes every line the box allows and ellipsises on the
  last one that fits. `lineLimit(5)` is a fixed count against a box measured in points — it either
  stopped short of the bottom or asked for a line the frame had no room for, differently at every
  Dynamic Type size. Compact review bodies also flatten paragraph breaks: in a four-line preview a
  blank line is a quarter of it spent on nothing.
- **Sentiment is the one coloured thing on these cards** — green / red / secondary. It is the only
  field a reader scans rather than reads, and it already has that convention; everything else stays
  materials and hierarchical styles.
- **`StarRatingRow` draws `star.fill` / `star.leadinghalf.filled` / `star`**, rounded to the nearest
  half. The mask over five filled stars it replaced could paint 0.13 of a star, which is a fill
  percentage, not a rating.
- **Score marks are fixed in height and free in width** (`MediaScoreLogo.Style.compact`, the
  `*_small` vector set). Boxing every one into `height × height` letterboxed the wide wordmarks down
  to nothing.
- 🔴 **A number never wraps.** `6.4` came out as "6." over "4" and `(35K)` as "(35" over "K)",
  because nothing said the cells keep their own width and the row squeezed them. Every score cell
  is `lineLimit(1)` and sized to itself now; the one line allowed to truncate is the votes/reviews
  count, which is the only one long enough to outgrow the card — and a card that grows to fit a
  vote count breaks the rail.
- **Sources are a table by default**, one per line, fixed columns (`value | mark | name | turnout`)
  shared between the card and the page so the two do not line up differently. The one-line chip row
  is kept as `MediaItemRatingsCard.SourceLayout.chips` — it was already tight at four sources and
  the sources are not going to stop arriving.
- **One size, regular weight, throughout.** Chip values, counters, review footers and the reviews
  tally were `.caption` / `.caption2` / semibold, which made a card read as three documents stacked.
  Everything is `TypeScale.detailBody` at regular now; only a review's **title and sentiment** are
  semibold, and only the aggregate digits are larger. Review bodies are primary text, not secondary.
- **A review's title hugs.** Clamping it to one line cut half the headlines mid-word for a line the
  body never got back.
- `localizedPluralForm` is now one function (was inline in the season/episode unit helper), and
  `MediaItem_UnitReview{One,Few,Many}` decline the review count — "53 рецензии", not "53 Рецензии".
- Review cards are flat: a card that highlights under the pointer and then does nothing is worse
  than one that does not offer, and what "expand" means has not been designed.
- 🔴 **The proxy was already sending things we threw away.** `positiveRating` / `negativeRating`
  (usefulness votes — *not* the review's sentiment: one capture is a NEGATIVE review at 23 useful /
  79 not), and the page totals. `Review` now carries `helpfulVotes` / `unhelpfulVotes` / `postedAt`,
  and `TitleMetadata.reviewsSummary` carries the totals. **`ReviewsSummary.total` is not
  `reviews.count`** — the endpoint pages and we hold page 1, so the header count and the card count
  legitimately disagree.
- **`stripHTML` recovers paragraphs.** Review bodies arrive as `<br />\r\n<br />` between
  paragraphs; dropping those with the rest of the tags glued a 4 000-character review into one
  unbroken wall. Line breaks are restored first, runs collapsed to one blank line.
- **`date` has no zone offset** (`2022-02-18T21:51:09`), so there is no instant to recover. Parsed
  in the current calendar's zone, which keeps the wall-clock day Kinopoisk itself prints — UTC would
  shift it by the offset.
- **Sheet first, as the rule says:** [docs/providers/kinopoisk-proxy.md](docs/providers/kinopoisk-proxy.md)
  documents all four `kpapi` endpoints from live captures, including the fields we deliberately
  leave (`BLOOPER` facts, non-actor crew, review paging).
- Verified: builds on macOS, iOS and tvOS. **Not seen running** — the iOS 26.0 simulator runtime
  cannot load this build at all (`dyld: Symbol not found: …glassEffect…`, an SDK/runtime mismatch
  that predates this change).

### Watching reported the wrong id, and reported it too early (2026-08-17)

- 🔴 **Continue Watching asks the series itself which episode is next.** Nothing else can answer it:
  history and the watching counters do not know where a season ends, so an eight-episode S1 read as
  "S1, E9" — an episode with no file to play — and an episode whose last five minutes are credits
  came back as "resume" while the server already counted it watched. `HomeCatalog` now fetches the
  payload for each series in the row (max 12, `nolinks`, only when the row's TTL expires) and takes
  `primaryEpisode` — the same property the detail page's Play button uses, so the two can no longer
  disagree. A series whose `playbackAction` is `playAgain` leaves the row. The history/counter
  heuristic below stays as the fallback when a payload does not arrive.
- **Anything that fetches details and hands an episode onward stamps its seasons first**
  (`MediaCardMenuCoordinator.play`) — otherwise the episode reaches the player with no item id and,
  since the fix below, reports nothing at all.
- 🔴 **Continue Watching offered episodes that were already watched.** The card took its S/E from the
  newest history row — which is where the viewer *was*, not what to play next — so a series whose
  last row was "S1, E2, finished" offered E2 again, with E2's full runtime under it as if it had
  never been played. `ContinueWatchingEpisode.forSeries` picks it now: an episode someone is
  mid-way through, else the server's watched count + 1, else one past the last thing seen. A card
  whose series is fully watched (and has no new episodes) is **dropped from the row**. Progress bar,
  duration and `mediaID` are only attached when the episode is actually being resumed — they belong
  to the previous episode otherwise, and the overlay label now says whatever Play will open.

- 🔴 **`/v1/watching*` keys on the *item* id, never the episode's.** `Episode.metadata` fell back to
  its own id when the season had not been stamped, so `GET /v1/watching?id=928900&season=1&video=2`
  answered 404 (928900 is episode 2's *media* id; the series is 87940). Setting `Season.mediaId` now
  stamps every episode in it, `Episode.metadata` reports `0` rather than guessing, and
  `WatchingMetadata.isResolved` is what `PlayerManager` checks before saying anything to the server.
  A media id that collides with a real item id would have written progress onto another title.
  `MediaItem.downloadableItems` carried the same bug.
- **Nothing is reported before playback starts.** `fetchWatchMark()` ran from `onAppear` on all three
  platforms — before the player had an item, about a title the viewer had not begun. It now fires
  once, on `readyToPlay`, from the player itself.

### One profile decides what a type or genre changes on screen (2026-08-17)

**The rules themselves are product, and live in
[docs/product/media-presentation.md](docs/product/media-presentation.md)** — not here, and not in
AGENTS.md. What shipped:

- **`MediaPresentationProfile` (KinoPubBackend) is the only place a type/genre rule may live.** Views
  ask `mediaItem.presentation`; a view that tests `type == "concert"` itself is the defect the type
  exists to prevent — such a rule lands on one surface and is missed on the poster, the card and the
  label next to it. Kinds: `fiction`, `documentary`, `concert`, `standup`, `animation`, `show`, plus
  `MediaAuthorRole` (director vs creator).
- `Cast & Crew` is **dead** as a string key — the rail is actors-only and reads `MediaItem_CastSection`
  ("В ролях"). New keys: `MediaItem_Credits`, `MediaItem_CreditsParticipants`, `MediaItem_Creators`,
  `MediaItem_MoreBy{Director,Directors,Creator,Creators}`.
- **Genres are matched by id where we know one** (101 stand-up, 23 animation) and by RU/EN title
  otherwise, because we hold no genre-id table. The real one is `filter.genres` in
  `kpapp.link/config.json` (see [docs/providers/kinopub/references.md](docs/providers/kinopub/references.md));
  folding it in would retire the string matching.
- 🔴 **A comma on `cast` / `director` matches nothing** — verified live 2026-08-17, against what the
  vendor docs claim: `director=Фил Лорд,Кристофер Миллер` answers an empty list where either name
  alone answers a filmography. A shelf covering two people is **two requests merged**
  (`MediaPerson.each(of:role:limit:)`); the earlier `MediaPerson.group(names:role:)` is **dead**.
  On `genre` we do use a comma as OR (`LibraryFilter.genreIDs`) — still unverified, so the genre
  shelf falls back to a single genre when the multi-genre request answers nothing.
- **The genre floor waits for every other shelf to have *answered*, not to be empty.** Firing on
  "still empty" ran it against `MediaItem.mock()` while the details were in flight, and put a
  "More in Comedy" shelf of cartoons on a concert page. `similarLoaded` / `collectionsLoaded` join
  the two credit flags as the gate, and the row's id now carries the genre ids it asked for.
- **The related area is a plan, not three hard-wired shelves** — similar → author → cast →
  collections → a genre floor that only fires when everything else came back empty, so no type opens
  a page that recommends nothing. `CastShelfPolicy` says who the cast shelf asks for and what floats
  to the front of the answer; `preferringTypes(_:)` is an ordering and never a filter.
- 🔴 **`items/collections/{id}` is not on our host** — `/v1/items/collections/248` answers 404 on
  `api.service-kp.com` (seen live). It lives on the PWA's branch,
  `api.ios-kp.store/api2/v1.1/`, so `Endpoint` gained **`baseURLOverride`** and
  `ItemCollectionsRequest` is the only endpoint that sets it. Everything else stays on the mirror
  the user signed in to. `NavigationLinkProvider.collection(_:)` is new, for those shelf headers.
- **The genre floor asks the web client's own genre query** — `type` + `genre=23,26` +
  `country` + `period=month` + `sort=-updated`, narrowing dropped one step at a time until
  something answers (`LibraryFilter.genreIDs` is the comma-joined OR).
- **One card per film** in person shelves and on the person page: `MediaItem.filmIdentity` +
  `collapsingFilmVariants` collapse the 3D and flat entries of one title (they share a Kinopoisk /
  IMDb id). The library grid and search do **not** collapse: a "3D" type filter asks for exactly
  those entries.

### Device identity actually reaches kino.pub (2026-08-16)

- **Every JSON body POST was a silent no-op.** `RequestBuilder` wrote a JSON body and set no
  `Content-Type`, so URLSession stamped it `application/x-www-form-urlencoded`; kino.pub parsed no
  parameters out of it and still answered `{"status":200}`. That is why `/v1/device/notify` kept
  writing "unknown / unknown / unknown" and the streaming profile never moved. The builder now
  labels the body `application/json` unless the endpoint sets its own header. Verified live against
  `api.service-kp.com`: same body, header off → nothing changes; header on → applies.
  Every body POST rode on this — notify, device settings, bookmark toggle, folder create/remove,
  token refresh.
- **`DeviceIdentity` has no model table.** Titles/models/OS names come from the system at runtime
  (`UIDevice` / `WKInterfaceDevice` / `Host` + `sysctl`), so an unreleased device still reads
  correctly. `hardware` is `"<family> (<identifier>[, chip])"` — `Mac (MacBookPro18,2, Apple M1 Max)`,
  `iPhone (iPhone17,1)` — and the raw identifier keeps it exact. macOS `uname` is the *architecture*,
  so the Mac model comes from `sysctl hw.model`; in a Simulator both are the host's, so
  `SIMULATOR_MODEL_IDENTIFIER` wins. The OS moved to `software` (`"macOS 27.0, KinoPub v1.0 (1)"`),
  where kino.pub's own docs put it. `DeviceIdentity.deviceName` is the single source for the
  device's name — nothing else may invent one. macOS bidi isolates (U+2068/U+2069) around the
  localized host name are stripped.
- **Registration happens at activation, not on every launch.** `DeviceService.syncDeviceProfile(activated:)`
  replaces `registerDeviceIdentity()` + `syncCapabilities()`. `AuthState.markSignedIn(activated:)`
  separates a device-code exchange from a token refresh. Later launches no-op unless the payload
  changed (rename, OS update, new build, new hardware) or the last attempt failed — see
  `DeviceProfileRegistry`, cleared on logout. Re-pushing the profile every launch is what let the
  capability sync clobber a streaming profile the user had just edited in Settings › Device.

### Concerts decode, and the PWA's API surface is written down (2026-08-16)

- **The PWA's API surface is written into the vendor sheets, each note next to the method it
  describes** — not a separate file. Everything ours is marked 🔎, and anything captured but not
  probed by us says so, so it reads as a shape and not a contract:
  - `intro` — the alternate hosts (`api.boramoraboom.ru`, and `api.ios-kp.store` with its
    `/api2/v1.1/` branch) and the artwork domains. **Nothing may key on a domain**: the same poster
    comes from `m.staticpop.net`, `m.boramoraboom.ru` or `m.pushbr.com`.
  - `video` — **`conditions[]`**, undocumented and the mechanism behind every filter checkbox in
    their UI: repeatable free-form comparisons (`year<=2020`, `kinopoisk_rating>=6.0`). Noted on
    **`/v1/items`**, which is where the captured requests went. `/v1/items/search` is a different
    method — text over `title` / `cast` / `director`, `type=` sent empty for "all" — and the web
    client never sends it a filter, so neither should we. Also **`api2/v1.1/items/search` answers
    with no token at all** (verified: HTTP 200, 40 summary items with a ready-made `value` display
    string and a `pagination` block, but no `videos` / `genres` / `duration`) — it looks like the
    typeahead endpoint, and it is a search that works **before login**. Plus
    `api2/v1.1/items/{id}`, a slim response carrying **`age_rating` and `fps`, neither of which v1
    returns** — we currently take the age rating from TMDB only.
  - `collections` — `items/collections/{item_id}`, which collections an item sits in, with
    `views`/`watchers` counters that exist nowhere else.
  - `device` — the real `settings` payload, where the vendor doc has only `// Список настроек`:
    five checkboxes and two lists, including **`streamingType`** (HTTP / HLS / HLS2 / HLS4 — the
    choice between the `url.*` variants we currently hard-code to `hls4`) and `serverLocation`
    (1 = NL, 3 = RU, which is the `?loc=nl` on every CDN URL).
  - `references` — **`https://www.kpapp.link/config.json`, public and unauthenticated**: types,
    genres, countries, sorts, subtitle languages, the 11 menu sections, home blocks and quality
    tables in one 26 KB file. `home_blocks_shortcut` is the spec the hard-coded
    `HomeCatalog.Shortcut` is supposed to become, and `filter.types[].genres` says which genre set
    applies to which type — they are not all-to-all.
- **A concert payload now has a fixture and tests** (item 126187). It decodes — but it is the first
  payload seen with **`imdb: null` alongside `imdb_rating: 8.1`**, so "has a rating" can never imply
  "has an external id". Also `subtype: ""` (empty, not absent), `trailer: null`, and
  `audios[].author: null` on an original-language track.
- 🔴 **`tracklist` is not decoded at all** — six tracks in that payload, dropped on the floor.
  `ConcertItemTests.testTracklistIsNotDecodedYet` pins the gap and fails the day it is closed.
  On the live data `artists` and `url` are empty on every track and an unknown one is literally
  `"N/A"`, so only `title` is usable.
- **Artwork hosts in the network-log filter were incomplete** — kino.pub serves the same posters
  from `m.boramoraboom.ru` and `m.pushbr.com` too. Added, and the list is now labelled as knowingly
  incomplete with the extension patterns as the real net.
- Kept **out of AGENTS.md on purpose**: this was decided once and belongs with the method, not in
  the file every session loads. The multi-version findings live in `video.md` too — including one
  place the vendor docs disagree with reality (`tracks` documented as `'1,2,3,4'`, arrives as `4`).
- 221 backend tests green.

### Films with several versions are playable, and stop being a tag (2026-08-16)

- **`PlaybackVariant` + `VersionsRailView`.** A `subtype: "multi"` movie ships its encodings in
  `videos` — several entries with `snumber: 0`, their own `id`, and a human `title` ("24 fps",
  "48 fps"); director's cut and colour/black-and-white are the same shape. They now render as a
  landscape rail directly under the hero, above the seasons rail, using the same card an episode
  draws (`MediaCard(variant:)`) and the same TVUIKit media-item cell on tvOS. They are **not**
  episodes and never enter that rail.
- **`videos.first` was the bug.** Every film-level `PlayableItem` member — `files`, `metadata`,
  `subtitles`, `audioTracks`, `watchableURL` — read `videos.first`, so on a two-version title the
  second version was unreachable *and* Play resumed the first one at a position belonging to the
  other encoding. They now read `MediaItem.primaryVideo`: the started-but-unfinished version, else
  the first. `playbackAction` considers every version, not just one.
- **`subtype: multi` is gone from the tag strip** (type · country · genre). It is not a fact about
  the film in the way a country is — it says the film ships in several versions, which the rail now
  says by listing them. Unknown subtypes still render: better an unexplained word than a dropped one.
- **A 2 h 24 min film was claiming 4 h 48 min.** `duration.total` is the sum of every *version*
  (8634 + 8634 on item 124447), the same trap the code already documented one level up for series.
  The runtime line now uses `duration.average` when a film has versions.
- **Subtitles and audio are per version.** On item 124447 the 24 fps encoding carries 55 subtitle
  tracks and the 48 fps one carries none — so reading them off `videos.first` handed the 48 fps
  player a subtitle list that was not its own.
- **Verified against the real response.** `Fixtures/item_124447_multi.json` is the actual
  `GET /v1/items/124447` payload (signed CDN URLs replaced, subtitle/audio/file lists trimmed —
  nothing asserted on was changed), with `MultiVersionItemTests` covering decode, variant order and
  ids, `metadata` shape, per-version subtitles, the runtime, and `playbackAction`.
- **The ROADMAP's "fake episodes `s0e1`/`s0e2`" note was right all along** — that is the API's own
  notation: every `videos` entry carries `snumber: 0` and `number: 1…n`. (An earlier draft of this
  entry called the note wrong; it was not.) **Multi-part films are the same mechanism**, not a
  second one — one `videos` array either way, and only the `title` string says which. So do not
  infer semantics from the structure.
- Not verified on a device: how the rail reads at ten feet, and how `.card` focus looks on it.

### A network log you can read on the device, and a launch that says what it is waiting for (2026-08-16)

- **Settings › Diagnostics › Network log** — every request with headers, full request and response
  bodies, timing, errors and cURL, kept 14 days on the device, searchable and filterable, exportable
  as a `.pulse` file. Backed by [Pulse 5.2.3](https://github.com/kean/Pulse), pinned `from:
  "5.2.3"`, declared in `KinoPubUI`; nothing outside `NetworkDiagnostics` / `NetworkConsoleView`
  imports it.
- **What it replaced:** `ResponseLoggingPlugin` logs one line — status, URL, byte count — and says
  in its own doc comment that bodies are not dumped. There was no in-app viewer and no history, so
  on an Apple TV with no Xcode attached a slow launch and a failing one looked identical.
- **Capture is `NetworkLogger.enableProxy()`, once in `App.init`.** It swizzles `URLSession`, which
  is what makes one call cover kino.pub, artwork through Nuke, TMDB and the Cloudflare workers, and
  what makes tasks visible while they are still in flight. **Not DEBUG-only** — the launches worth
  reading a log for are TestFlight ones on real hardware.
- **The log records API traffic only, and is capped.** Artwork and media are excluded at capture by
  host (`*.staticpop.net`, `image.tmdb.org`, `*.mds.yandex.net`) *and* by extension (jpg/png/webp/
  gif/avif, m3u8/ts/mp4/mkv/m4s) — both, because hosts catch artwork served without an extension and
  extensions catch a CDN we have not met. A picture in a log answers no question its status line
  did not already answer, and an HLS segment answers none at all.
- **`NetworkDiagnostics.store` is ours, not `LoggerStore.shared`.** Pulse's shared store is built
  with its defaults and cannot be reconfigured after creation, and those defaults are what produced
  50 MB log files: **256 MB** of store, **8 MB** per response body. Ours caps the store at 32 MB and
  a body at 512 KB — kino.pub's largest reply, a history page, is about 96 KB. It lives in
  `Caches/`, the only place on tvOS an app may put a file this size; the system purges it between
  runs there, which is the documented tvOS trade.
- Settings › Storage gained a **Network log** row (size + clear) alongside the artwork one.
- **Tokens are redacted at capture, not at export.** `Authorization`, `Cookie`, `access_token`,
  `refresh_token`, `api_key`, `password`. A redaction you have to remember to apply at share time is
  one you will forget, and this store is meant to be shared.
- **`CURLLoggingPlugin` is out of the default plugin stack.** It printed every request's headers,
  bearer token included, into the system log; the Network log renders cURL redacted. The type is
  kept for one-off local debugging.
- **`NetworkActivity` (`KinoPubLogging`) answers the other half:** what is outstanding *now*,
  hooked once in `URLSessionImpl` so no view model has to remember to report and none can forget.
  Pulse cannot answer this — it writes its record when a task *completes*.
- **The launch splash says what it is waiting for, in release.** `LaunchStatusLabel` replaces the
  bare `ProgressView` with the names of everything currently outstanding, joined — "Проверяем
  сессию · Загружаем историю" — because the wait is several things at once and a single-line
  "Loading…" is the empty spinner with extra steps. Names are distinct and ordered by start, so
  three catalogue pages in flight read as one thing and not a stutter.
- **Activity entries carry a localization key, not a path.** `Activity_Session`, `Activity_History`,
  `Activity_Watching`, `Activity_Bookmarks`, `Activity_Collections`, `Activity_Catalog`,
  `Activity_Sections`, `Activity_Search`, `Activity_Device`, `Activity_Network` — RU + EN in
  `Localizable.xcstrings`. An unmapped endpoint falls back to "Загружаем" rather than to `/v1/items/…`;
  the path travels alongside for the debug overlay, which shows paths precisely because it is for
  whoever is debugging. Product decision (2026-08-16): the label ships.
- Item 2 of [the 2026-08-10 plan](docs/archive/plans/2026-08-10-launch-status-and-continuity.md) —
  activity *toasts* — was **not** built; the debug overlay covers that ground and `HudToast` was
  left alone. Items 3–5 of that plan are still open; its header now says so.
- **Streaming to the Pulse app on a Mac**, off by default, toggled in Settings › Advanced ›
  Diagnostics (and in the tvOS diagnostics list, where it matters most — reading a log on a
  television with a remote is nobody's idea of a good time). `RemoteLogger` over Bonjour
  `_pulse._tcp`; `NSBonjourServices` + `NSLocalNetworkUsageDescription` added to `Info.plist`.
  Enabling it is what asks for local-network permission, so nothing turns it on for the user, and
  it is restored at launch only if they left it on. The macOS entitlements already carried
  `network.client` / `network.server`.
- **Adapter:** `PulseUI.ConsoleView` does not exist on macOS in 5.2.3 — the module ships
  `ConsoleView-ios/-tvos/-watchos` and fences its public init `#if !os(macOS)`. Capture runs on the
  Mac anyway, so `NetworkConsoleView` offers export there and the `.pulse` file opens in the
  standalone Pulse app.
- The "Verbose logging" / "Keep playback diagnostics" toggles are gone. They were bound to `@State`
  that nothing read, under the footer "Demo controls — not saved yet".
- Verified: `xcodebuild build` green on tvOS 27 simulator, iOS Simulator and macOS. **Not yet run
  on a physical Apple TV** — which is the run that motivated this, so the launch trace it is
  supposed to produce has not been read yet.

### One artwork cache on Nuke, for all four platforms (2026-08-16)

- **`Artwork` (`ArtworkPipeline.swift`) is the single image cache.** Decoded-image memory cache
  keyed by *target size*, one disk entry per URL (`.storeOriginalData`), request coalescing and
  prefetching — for tvOS, iOS, iPadOS and macOS at once. Backed by
  [Nuke 13](https://github.com/kean/Nuke), pinned `from: "13.2.0"`, declared in `KinoPubUI`.
- **What it replaced:** tvOS had all of that hand-written in `TVUIKitRemoteImage` (private
  `NSCache`, an `ArtworkFetcher` actor for coalescing, `preparingThumbnail` downsampling);
  iOS/macOS had `AsyncImage`, which caches **bytes** and pays a full decode on every recycled
  tile — and which stays in `.empty` forever on a 404 instead of reporting failure. A fix on one
  side never reached the other. `TVUIKitRemoteImage` keeps its three-function API
  (`cached` / `load` / `prefetch`), so no cell changed.
- **Nothing outside `KinoPubUI` imports Nuke.** `Artwork`, `ArtworkImage`, `CachedRemoteImage`,
  `FallbackRemoteImage` and `TVUIKitRemoteImage` are the whole surface — swapping the library is
  one file. The fallback chain (wide → big → poster) stays ours; no image library models it.
- **`AsyncImage` is gone from the codebase** — all 14 remaining call sites moved over (media cards,
  hero still, blurred poster and ambient backdrop, title logos, season stills, the stills rail and
  its sheet, downloads, the UILab backdrop, two preview galleries). `ArtworkImage` is the primitive
  with `AsyncImage`'s phase shape for the sites whose states need different geometry — a title logo
  that fails becomes a text block — and `CachedRemoteImage` is that primitive configured, which is
  what every other site uses.
- **Prefetching stops at the data cache and is now cancellable.** The old fire-and-forget
  `Task.detached` prefetch decoded at *full resolution* under a cache key no poster or wide cell
  ever read, and could not be cancelled when the row scrolled away. All three prefetching
  collections gained `cancelPrefetchingForItemsAt`.
- **Artwork no longer shares `URLCache` with the API client** — the loader's session cache is off,
  so Settings › Storage gained an **Artwork cache** row (disk + memory, clearable) and the Network
  cache row is now API responses only. That file's "there is no unified image cache yet" note is
  void.
- `ArtworkLog.loaded(_:bytes:)` → `loaded(_:from:)`, reporting which tier answered
  (memory / disk / network). A rail refetching over the network every scroll pass is a cache-key
  bug, and that is where it shows.
- **AGENTS.md gained a [Dependencies](AGENTS.md#dependencies) section.** There was never a ban on
  third-party SPM — the repo already shipped `KeychainAccess`, `PopupView` and `Reachability` — but
  the one-component-per-idea rules were readable as one, and that reading is what kept the artwork
  stack split in two. The bar: it replaces code we would otherwise own, it stays behind our own
  type, it is pinned to a major, and it builds on all four platforms. Telemetry stays the exception.
- Verified: `xcodebuild build` green on tvOS 27 simulator, iOS Simulator and macOS. **Scroll
  behaviour not yet watched on device.**

### Docs: one context file, five skills, and constraints that stop becoming requirements (2026-08-13)

- **The documentation tree collapsed into [AGENTS.md](AGENTS.md) + [ROADMAP.md](ROADMAP.md) +
  `.claude/skills/`.** `docs/en/policies/`, `docs/en/apple-platform/` and `docs/en/features/` are
  gone as folders: durable rules are one always-on file, how-to knowledge loads on demand
  (`tvos-surface`, `apple-chrome`, `player-avkit`, `metadata-service`, `docs-upkeep`), stage
  checklists are one roadmap, and every dated plan moved to `docs/archive/plans/` with a note at the
  top saying what survived it. Before: ~23.6k words of always-relevant docs plus 21.6k words of
  plans that agents kept reading as law. The rule that keeps it that way: **a line in AGENTS.md must
  carry either the default or the cost of getting it wrong.**
- **Constraints are not requirements.** Every limitation gets one of four labels — Apple API /
  performance / focus invariant / product decision — and only the last two may become durable
  requirements; the first two become one named adapter. Three registers came with it: banned
  patterns (focus bridges, shared `@FocusState` cases, manual focus delays, hand-rolled focus
  chrome, continuous scroll-progress choreography, hand-driven `contentOffset`, custom hero focus
  graphs, SwiftUI preview state machines, screen-specific component variants), invalid
  agent-invented "requirements", and the two adapters that are allowed to exist.
- **Voided as requirements:** the detail page's scroll-progress scrub (`washProgress`), "hero lives
  outside the scrolling container" (only the *artwork layer* does — hero content stays in one focus
  graph with the sections), the overlay title logo / compact title, and tab-bar pinning. The
  detail-page plan is now explicitly history, with a table of what survived.
- **Renderers differ by platform on purpose:** tvOS media surfaces are UIKit + TVUIKit; iOS/iPadOS/
  macOS are SwiftUI including `.navigationTransition(.zoom)`. Shared: models, services, view
  models, component semantics, tokens, assets — never view hierarchy or geometry. Cross-platform
  geometry parity (the two-line tvOS poster caption) is named as the anti-pattern it was.
- **`badgeText` can carry a glyph** — an SF Symbol is a character. "The system badge cannot show an
  icon" was never a reason for a parallel overlay system.
- **The playable graph** ([ROADMAP](ROADMAP.md#4--kinopub-catalog-completeness)):
  episodes, trailers, parts and versions are one `PlayableItem` rail, with `PlaybackVariant` under
  it (kino.pub ships 24/48 fps as `s0e1`/`s0e2` — item 124447 is the probe). Detail pages lead with
  what can be played. The kino.pub endpoints to map before more detail UI are listed there.

### The info popup, and hero buttons that are actually the system's

- **`InfoPopup` (KinoPubUI) is the one "show me the rest of this" surface, on every platform** —
  phase 8 of the detail-page plan, with the trigger deliberately changed from the reference app's.
  No round `i` button: `expandsIntoInfoPopup(title:)` makes the *clipped content itself* the
  control. Presentation is the system's per platform — a sheet drawn as a centred panel over a
  scrim on tvOS (where Menu dismisses it for free, and `.presentationBackground(.clear)` is what
  keeps it reading as a popup instead of a pushed page), detents on iPhone/iPad, a panel on macOS.
- **The synopsis now always opens** — every platform, truncated or not. It used to be a dead press
  on tvOS whenever the text happened to fit, and plain unfocusable copy off tvOS: the same
  paragraph behaved two ways for a reason the reader cannot see. The "More" hint still depends on
  truncation, because that is a statement about the text, not about whether the control exists.
- **The About columns open themselves too** (`AboutColumn`, `AboutLegendColumn`) — the same lines at
  reading size, which is the whole point at ten feet. `MediaItemDetailSheet` /
  `MediaItemSheetLayout` are gone; their own doc comment promised "the synopsis, **or a column with
  its lists unclamped**" and only ever delivered the synopsis. **Judge on device:** the columns are
  `Button`s now, so on tvOS they wear `.card`, which argues with `AboutLayoutAppleShape`'s "no card
  behind the columns at all".
- **Hero actions are `.borderedProminent` / `.bordered` with a border shape, and nothing else.**
  Three hand-written `ButtonStyle`s went away: hand-painted capsule and circle plates, hairline
  strokes, `Color.white.opacity(0.22)` fills, black-on-white inversion, `.onHover` state, drop
  shadows, and a `scaleEffect` focus lift with its own spring — a reimplementation of two system
  styles, which on tvOS also meant owning the focus lift, the specular and the press feedback the
  system already ships. `.circle` and `.capsule` are real `ButtonBorderShape`s on tvOS 26 (checked
  in the SDK). What survives is the vocabulary, the icon metrics, and the resume bar — the one part
  with no system equivalent, now drawn with **hierarchical** styles (`.tertiary` / `.primary`) so it
  inverts with the button instead of needing a `forceFocusedColors` flag to guess when the button
  turned white.
- **Trailer is a labelled capsule, first in the row under Play** — not a fifth anonymous circle. The
  circles are all *state* (following / filed / how far in); the trailer is the other thing on the
  page you can watch, and a film glyph among four state glyphs read as one more toggle. The hidden
  "Up from Play opens the fullscreen trailer" gesture is untouched and now arguably redundant —
  left as a product call.
- **Built on tvOS, macOS and iOS. Not run** — the hero and the popup are visual work and the
  simulator is yours.

### One navigation assembly, one tab table, and a lab for the tvOS bar

- **`RouteStack` replaces ten hand-copied stacks.** Every tab used to write the same four lines —
  a `NavigationStack` bound to one of `NavigationState`'s arrays, a `.navigationDestination(for:
  Route.self)` building a `RouteDestination`, and a `.navigationStackActive` gate — and they had
  already drifted: two passed a zoom namespace, eight did not. `RouteStack(tab:zoom:)` now owns all
  four; `appRouteDestinations()` covers the two stacks whose path is local `@State`
  (bookmark-folder tabs, tvOS Settings). Zoom stays **opt-in per stack** because the zoom *source*
  modifier is `#if os(iOS)`-only — publishing a namespace on a stack whose cards never mark a
  source would give the destination a transition with nothing to match.
- **`NavigationState` lost both of its ten-case switches.** `push` and `popToRoot` each carried one
  over the same tabs — two places to forget a tab in. One `routes(for:)` key-path table feeds both,
  plus the new `path(for:)` binding. `.settings` has no shared stack and now says so once.
- **`TabsNavigationView`: four hand-written platform trees → one browse-tab table.** The tabs come
  from `browseTabs` and a `ForEach` (`ForEach` conforms to `TabContent`); each platform only decides
  how a tab labels itself and which utility ends surround it. That drift was already visible — the
  iPad bar's own comment described "glyph · words · glyph" while its code built icon+word chips.
  Badges stay off tvOS: `TabContent.badge` is `@available(tvOS, unavailable)` in the 27.0 SDK
  interface (checked, not assumed).
- **The unrendered profile-avatar fetch is gone.** `TabsNavigationView` downloaded the avatar and
  the user record on every sign-in into `@State` that no branch of its body drew — left over from
  the parked sidebar shell. `SettingsRootView` already loads and caches the avatar for the one
  screen that shows it. Two fewer launch requests, which is the direction
  `docs/archive/plans/2026-08-10-launch-status-and-continuity.md` asks for.
- **Fixed on sight: five Settings diagnostics rows shared one `@FocusState` value.** All bound
  `.focused($focusedItem, equals: .diagnostics)` — the exact ambiguity
  `.claude/skills/tvos-surface/SKILL.md` bans and that cost a misdiagnosed detour on the detail
  page. `SettingsFocusItem.diagnostics` now carries a disambiguating id; the tip stays shared.
- **New DEBUG/tvOS page: Settings → Diagnostics → "Navigation / Focus Lab."** Four shells of the
  same two-tab app, each isolating one variable behind the tab-bar and focus-stranding bugs:
  (A) what ships — stack per tab, SwiftUI rails; (B) one `NavigationStack` outside the `TabView`;
  (C) one `UICollectionView` with the rails as `orthogonalLayoutSectionForMediaItems` sections;
  (D) C plus `setContentScrollView(_:for: .top)`. A HUD reads `isTabBarHidden`, the class+address of
  whatever `contentScrollView(for: .top)` resolved to, and stack depth — because the screen and the
  system disagreeing is the bug, and that is not visible from SwiftUI. Each variant runs in a
  `fullScreenCover`: nested in the real Settings tab it would measure the *app's* tab bar controller
  instead of its own. **Built on all three platforms, not yet run.**

### tvOS wide rails are system media items

- **Every 16:9 horizontal rail now draws with `TVMediaItemContentConfiguration.wideCell()`, laid out
  by `NSCollectionLayoutSection.orthogonalLayoutSectionForMediaItems()`** — new
  `TVUIKitMediaItemRail` in KinoPubUI. The hand-built landscape tile (artwork + gradient legibility
  band + title + meta + progress track, all stacked by hand in `TVUIKitContinueWatchingCell`) is
  gone from the shelf path: text, secondary line, badge, and progress bar are configuration
  properties, so the focus motion, band, badge shape, and bar are all system-owned.
  `MediaPosterShelf` routes landscape cards there; Continue Watching is the first surface on it.
- **Posters stay on `TVPosterView`.** The media-item configuration ships a 16:9
  `wideCellConfiguration` only — there is no 2:3 variant, so `TVUIKitPosterCell` /
  `TVUIKitMediaCollection` remain the poster and vertical-grid path (including landscape *grids*,
  which the orthogonal section cannot express).
- **`text` and `secondaryText` are not two stacked lines under the tile** — measured on device, not
  read off the header: `text` renders centred *below* the artwork, `secondaryText` renders *over* the
  artwork's bottom-leading corner. They are different surfaces; setting both put `secondaryText`
  straight through our own chip in that corner (caught it live — a card's own title, rendered by the
  system in caps, drawn on top of our "▶ 1h 52m"). We use `text` only, and leave `secondaryText` nil.
- **One look, not a set of options.** First pass shipped a knobs struct (scale / progress-on-focus /
  center-glyph / title-on-focus) with an A/B gallery bench to compare them — reasonable for exploring,
  wrong for shipping: no product requirement asked for options, and the result read as "a UI ideas
  page," not a component. `TVUIKitMediaItemRailStyle` is gone; the rail has exactly one behaviour now.
- **Under the tile: the name, always visible, not focus-gated.** A movie's own title, or "S2, E11 ·
  Show" for an episode — built from `overlayLabel` (already formatted "S2, E11" by both History and
  Continue Watching) plus `title`. Earlier this said "state, never the name" and showed a generic
  "Continue" placeholder instead — wrong: the artwork's own baked-in title text is not the same
  surface as the caption below the tile, so putting the real name there is not a duplicate.
- **Inside the artwork: the bar and the runtime are mutually exclusive, both shown immediately —
  never gated by focus.** Went through two readings before landing here. First pass showed "56m left"
  unconditionally beside the glyph; second pass hid all text until focus (bar-only at rest). Landed
  on: `TVUIKitMediaItemStatus.showsRuntime` is true for `.ready`/`.watched`, false for `.inProgress`
  (the bar already says "how far along" — showing both is redundant) and `.upcoming` (nothing is
  known yet). Whichever one applies shows immediately. The glyph (bottom-leading) and the runtime
  (bottom-trailing) are on opposite corners of the same row, not a shared pill — no black background
  behind either; a drop shadow (`applyLegibilityShadow`) carries contrast instead, the same technique
  system text over artwork uses elsewhere. Declined: having the bar itself visually displace the
  glyph/runtime as it fills — the system draws its bar in a separate layer we cannot hook into, so
  that would need custom position math tied to `progress`, exactly the bespoke logic this rail is
  trying to avoid. **No SF Symbol floats over the middle of the tile on focus** — that shipped in the
  first pass and reads as homemade; removed.
- **A top-leading badge carries "Watched" and an upcoming release date** — `TVUIKitMediaItemStatus
  .stateBadgeText` / `.badgeShowsClock`. Unlike the bottom-corner glyph/runtime, this one *does* sit
  on a pill (`badge` in the overlay): it is a badge, the same kind of chrome as the 4K/HDR capability
  badge it replaces for exactly these two states — the corner has room for one, and the state wins
  (`updateConfiguration` suppresses `config.badgeText` whenever `status.stateBadgeText != nil`). The
  system's own badge is text-only (`TVMediaItemContentBadgeProperties` has no icon slot), so the clock
  glyph on an upcoming tile is ours, not the system's — this is the one place in the rail that is
  deliberately custom rather than system-drawn, because the system genuinely cannot do it.
- **Progress is never a series completion ratio.** `TVUIKitMediaItem.status(for:)` returns `.ready`
  for any `isSeries` card with no `video` pinned to it, regardless of what `progress` holds — e.g.
  `WatchingItem.progress` (`LibrarySectionCatalog.card(for:isSeries:)`) is `watched episodes / total`,
  not a resume point, and must never paint a bar even if such a card is ever routed through this rail.
- **`TVMediaItemContentConfiguration.overlayView`** carries what the configuration has no property
  for: a light bottom-up gradient (so the glyph/runtime read over any artwork — this replaces the
  commented-out `TVUIKitBottomInfoBlurView` for this rail specifically), the glyph, the runtime, the
  state badge, and the watched scrim. One view per cell, mutated in place; the configuration is
  rebuilt every state change and would otherwise rebuild the overlay with it.
- **Status drives the glyph** (`TVUIKitMediaItemStatus`): ready/in-progress/watched → play or
  checkmark, unavailable/upcoming → **no glyph at all** — nothing to select. A missing episode is
  signalled by the absent glyph and the caption, not by fading or disabling the tile.
- `TVUIKitMediaItem.badgeText` is one capability token — 4K, else HDR. `MediaCard.badge` deliberately
  does **not** feed it: on Home it carries kino.pub's "+10 new episodes" counter, which is noise in a
  corner chip.
- Sizing is **measured, then scaled**: `orthogonalLayoutSectionForMediaItems()` cannot be resized — it
  exposes neither its group nor its item — so `TVUIKitMediaItemMetrics` probes what it lays out at a
  given width (tile size, gap, vertical padding) with a throwaway collection view and rebuilds an
  equivalent section at a fixed `TVUIKitMediaItemMetrics.scale` (1.18). The system row reads small in
  our shelves; the tile keeps Apple's proportions. The rail reports its height through `sizeThatFits`
  — callers must not pin a `.frame(height:)` on top of it.
- `TVUIKitTileArtwork` draws flat-tint + SF Symbol artwork for tiles with no photograph (genres /
  categories, and the panel shown while a still is in flight). Colour is FNV-hashed from the name so
  a genre keeps its colour across launches — `String.hashValue` is seeded per process.

### TVUIKit gallery

- Rows were cropped because each lockup sat inside a hand-picked SwiftUI `.frame`. A `TVLockupView`
  keeps laying its content out at its own `contentSize` when the outer control is stretched, so the
  content ended up in a corner of an oversized box. Every representable now sets `contentSize` and
  answers `sizeThatFits` from `systemLayoutSizeFitting`; the rows dropped their frames and turned
  off scroll clipping so the focus lift is not sheared at the row edges.
- The media-items section is the shipping `TVUIKitMediaItemRail`, one row per episode state (ready /
  in progress / watched / not on kino.pub / upcoming), plus a genre-tile row on the same component.
  The earlier A/B variants (tile scale, progress-on-focus, centred play glyph) are gone along with
  the style knobs they compared — see above. Monogram cells were sized to the 160pt circle alone,
  which clipped the two labels the system stacks under it.

### Detail page

- **Library sidebar (macOS + tvOS) no longer traps a title's detail page beside itself.**
  `LibraryShellView`'s `NavigationStack` wrapped only the detail pane, a sibling of the permanent
  sidebar in an `HStack` — every route pushed through it, including the full-bleed `MediaItemView`,
  stayed confined to that pane's width forever. Every other tab wraps its whole content in one
  `NavigationStack`, which is why detail pages cover the full tab there. The stack now wraps sidebar
  + detail together; section switching is separate state (`LibraryModel.selection`), not a stack
  push, so it is unaffected.
- **tvOS hero title gets its own contrast, on top of the existing full-width scrim.** Rivulet's
  diagonal bottom-leading → top-trailing scrim reads well for them because their hero text is one
  narrow left-hand column; ours runs the full bottom edge (title + actions on the leading side,
  synopsis / credits / metadata filling the trailing side), so a pure diagonal would starve the
  right column of contrast. `titleScrim` adds diagonal weight only over the title block —
  `bottomScrim` still holds the floor full-width for everything else.
- tvOS scroll-progress scrub (`washProgress`) actually scrubs now — `MediaItemHeroView.effectiveWash`
  returned `max(washProgress, 1)` (always 1), so the material veil was a binary flip on
  `isHeroOnScreen` rather than continuous. Returns `washProgress` directly.
- **Reverted same-day:** pulling the hero out of the scrolling `VStack` into a fixed `ZStack` layer
  (meant to stop scroll jitter between Play / Watched / Watchlist). Broke tvOS focus outright on
  device — stuck on Play, Down/Up dead ends, Menu closed the app instead of popping. Full account in
  [detail-page-choreography](docs/archive/plans/detail-page-choreography.md).
- **Root cause of the above, found and fixed same day:** six hero buttons (watchlist, bookmark,
  watched, trailer, more, plus the non-tvOS plot branch) shared one `@FocusState` equals-value,
  `MediaItemFocusTarget.heroOther`. Ambiguous — the engine could not resolve which view was actually
  focused, so focus froze dead on Play (Right and Down both no-ops, on sparse *and*
  fully-populated titles alike) and Menu popped past the tab's own grid straight to the system
  Springboard instead of the detail page. One case per button now. Confirmed on-device: Down walks
  hero → Ratings → Cast & Crew → Information cleanly, Up restores the sharp hero exactly, Menu pops
  correctly.
- tvOS shadows removed from cards, badges, and action chrome that render per-item in a scrolling
  shelf or animate their radius with focus — real, measured cost, not just visual noise:
  `MediaCardView` (watched/bookmark/editorial glyphs), `HomeBannerCardView`, `PosterStyle`,
  `MediaActionButtonStyle` (hero Play pill + circle buttons), and `PortraitButtonStyle` (cast/crew
  circles — this one's radius *animated* on every focus change, the worst of the set). Hero title
  text shadow removed too, in favor of the `bottomScrim`/`titleScrim` contrast already in place —
  confirmed synopsis text still reads over a bright backdrop without it.
- Rating tiles (`RatingTile` / `AggregateRatingTile` / `ViewsRatingTile`) had **zero** tvOS focus
  feedback — the custom button style only read `isPressed`. First attempt used
  `.hoverEffect(.highlight)`, which was **wrong and had to be redone the same day**: the tvOS system
  highlight attaches to the first `Image` in the label, so on an `icon + number + caption` tile it
  scaled and shadowed the *logo alone* while the tile sat still (and it was the highlight, not the
  asset, drawing those icon shadows). Now `DetailTileFocusChrome` — `scaleEffect` + `brightness` on
  the whole label, via a `ButtonStyle` for the real buttons and `@FocusState` for the two focus-stop
  tiles. That hand-rolled chrome was then **itself replaced the same day by `.buttonStyle(.card)`** —
  the system card style — after the user pointed at Apple's `DestinationVideo` sample, which applies
  `#if os(tvOS) .card #else .plain #endif` to every card and writes no focus code, fencing
  `.hoverEffect()` to iOS/visionOS. All four controls now share `DetailTileStyle.buttonStyle`; the
  two that were focus stops rather than actions became `Button {}`, which is how that sample makes
  everything focusable too. **Rule in `focus-and-tvui.md`:** for a focusable container on tvOS reach
  for `.card` first and write no focus code; `.hoverEffect(.highlight)` is only for controls whose
  label *is* the image.
- **`FeatureFlags.fakeSeasonsOnMovies` — temporary DEBUG diagnostic, delete on sight.** Synthesises
  one season of six unplayable episodes onto titles that have none, to test whether the hero
  blur/scroll choreography only behaves when a season rail sits under the hero. **It did:** movies
  with a fabricated rail started blurring like series, which pinned the cause below.
- **Detail hero wash is section state, not scroll offset.** `washProgress` was `scrollOffset / 600`,
  and the page only scrolls as far as it must to reveal the next focusable thing — so a tall season
  rail produced a full wash while a movie's short first section (ratings) produced almost none. The
  blur was a function of content geometry, and arrived in uneven steps because every focus move
  scrolled a different distance. It also wrote state on **every scroll frame**, re-running the
  detail page's body and re-rendering every shelf below it (each `TVUIKitMediaCollection`'s
  `updateUIViewController` included) — the likely source of the reported scroll lag, and a suspect
  for the stranded multi-poster focus bug. `washProgress` and `onScrollGeometryChange` are gone:
  `effectiveWash` is `isHeroOnScreen ? 0 : 1`, `chromeAlpha` is `isHeroOnScreen ? 1 : 0.35`, one
  animation clock, written only by "focus entered a hero control" / "a section reported focus".
- Every detail content section that lacked one now declares `.focusSection()` (vote, cast, awards,
  photos, similar, both person shelves, info columns), so focus travels section-to-section rather
  than creeping element-by-element. Ratings and `SeasonsRailView` already built their own.
- Hero `titleScrim` was not missing, it was half-strength: ours shipped `0.5 → 0.18 → clear` where
  Rivulet's `ScrimGradientView` is `0.92 → 0.55 → clear` (stops `0 / 0.45 / 1`, bottom-leading →
  top-trailing). Over a bright backdrop that reads as no scrim at all. Matched to the reference
  values.
- Tab bar shown at rest on the detail page again (was unconditionally hidden there on tvOS/iOS);
  iOS/iPad additionally opt out of the system's scroll-driven minimize
  (`.tabBarMinimizeBehavior(.never)` — unavailable on tvOS/macOS in this SDK, so that half is
  iOS-only). **Known follow-up bug, not fixed:** returning from the detail page can leave the tab
  bar area blank instead of it reappearing; full account and a proposed direction (stop treating the
  bar as chrome that independently hides/shows — Apple's own tvOS apps don't duplicate a bar layer
  over content the way ours does) are in
  [detail-page-choreography](docs/archive/plans/detail-page-choreography.md).
- Fixed one of two writers racing `washProgress` on Up-back-to-hero: `MediaItemHeroView.chromeAlpha`
  read the raw (possibly stale, scroll-overwritten) value directly, unlike
  `MediaItemHeroBackdrop.effectiveWash`'s pre-existing `isHeroOnScreen` guard — so the backdrop
  snapped sharp correctly while the title/button chrome kept re-dimming in step with the still-settling
  scroll. Same guard added to `chromeAlpha`. Confirmed no navigation regression; the visual smoothness
  itself needs eyes-on, not a screenshot, to confirm — see
  [detail-page-choreography](docs/archive/plans/detail-page-choreography.md) phase 4.5.

### Ratings

- **Our combined score is behind `FeatureFlags.combinedRatingEnabled`, currently off** (the value
  lives in `KinoPubUI.RatingFeature.combinedEnabled` because card chrome reads it inside the
  package). Off hides the poster plaque, the hero pill, the detail "Rating" tile and the whole
  card Rating placement / source settings section. IMDb and Kinopoisk show only under their own
  logos — `MediaScoresView` in card captions and in the hero meta line.
- `Rating` now averages **weighted by vote count**: 6.0 from 4,867 voters next to 1.0 from 7 is a
  6.0 title, where the plain mean printed 3.5. A source that reports no count weighs as one vote,
  so two countless sources still average evenly. Votes on an unrated source never enter the mean.
- Tier boundaries match their own documentation again: `average` is 6.0–7.0, so 5.9 is `poor`
  (the switch said `5..<7`, and `testTierBoundaries` had been failing against it).
- Ratings tiles keep their natural width inside a horizontal scroll, like every other section.
  Squeezing them into the page width had been wrapping "Кинопоиск" mid-word.
- A source with voters but no published score (Kinopoisk counts votes long before it prints a
  number) gets its own tile: an em-dash and "Not enough ratings yet", instead of vanishing.

### One landscape card

- Episodes now draw `MediaCardView` — the same landscape card as Continue Watching and History.
  `SeasonsRailView`'s private `EpisodeRailCard` / `EpisodeCardButtonStyle` and the season grid's
  `SeasonItemView` are gone.
- `MediaCard(episode:in:title:episodeLabel:dateLabel:stillURL:primaryAction:)` in `KinoPubUI` is the
  single mapping (ids, resume fraction, watched flag, runtime); callers pass only the strings the
  payload cannot compose. `MediaCard(unavailableEpisodeID:…)` covers schedule-only episodes.
- Caption never says the same thing twice: a name that is only the episode's own number — "Эпизод 1"
  against `Episode 1`, in any UI language — counts as no name, and the card falls back to
  "Episode 1" as the title with the date alone underneath. Named episodes keep
  name / "Episode 3 · Jul 22, 2026".
- Air dates carry the **year** (a rail spans seasons, so a bare "8 Jul" says nothing), and inside a
  week either way they are relative instead — "in 3 days", "7 days ago", "tomorrow".
- Rail metrics come from `ShelfMetrics.landscape` + `CardAspect.landscape` against the measured
  rail width, so episode cards sit on the same grid as every other landscape shelf instead of a
  fixed 480/300pt. Focus is the shelves' `.borderless` lift, not a bespoke plate.
- The rail keeps `contentMargins` (not `padding`) for its inset: `scrollTo(anchor: .leading)` on a
  season tab would otherwise park the first episode under the page inset.
- Play affordance is one per platform, never two: iOS/iPadOS keep the play glyph inside the time
  chip and draw **no** centre play chrome; tvOS/macOS keep the centre glyph on focus / hover and
  the chip is bare time. The watched checkmark stays in the chip everywhere.

### tvOS card size beside a sidebar

- Sizing already read the **container** width, not the screen — every shelf and grid measures
  itself with `onGeometryChange`. What was screen-shaped was the *rule*: `ShelfMetrics.posters`
  gave TV six columns only from 1600pt up, and anything narrower fell into the handheld table. The
  Library shell's 420pt tvOS sidebar leaves ~1500pt, which read as "wide tablet" — 8 columns, a
  **150pt** poster where the full screen draws 290pt.
- On tvOS the column count now comes from a target card width (`ShelfMetrics.tvCardWidth` 290,
  `tvLandscapeCardWidth` 352) instead of the width table, so a narrower container gets fewer cards,
  never smaller ones: 1920 → 6×290 / 5×352 (byte-identical to before), 1500 → 5×268 / 4×340.
  Landscape stops being "posters minus one column", which overshot once the count got small.
- Other platforms keep the width table unchanged — there a 1500pt canvas really is a wide window
  at arm's length.

### tvOS context menus on TVUIKit cards

- Long-press-Select opens the card menu on the `TVUIKitPosterCell` / `TVUIKitContinueWatchingCell`
  path again (Home rails, catalog grids, search results — everything behind
  `FeatureFlags.tvUIKitPosters`). It had been silently dead: the `UIContextMenuInteraction` sat on
  each cell's `contentView`, and tvOS delivers remote presses to the **focused** view and up its
  responder chain, so an interaction on a descendant of the focus item never sees the gesture.
- The menu now comes from `TVUIKitMediaCollectionController`'s
  `collectionView(_:contextMenuConfigurationForItemsAt:point:)`, which is the hook UIKit wires to
  the focus engine — and the only one that exists on tvOS: the single-indexPath variant is
  `API_UNAVAILABLE(tvos)`, the `…ForItemsAtIndexPaths:` one is tvOS 17+. Entries still come from the
  same `contextMenuProvider` and `TVUIKitContextMenuBuilder`, so SwiftUI and TVUIKit cards show the
  same items.
- Dismissing the menu resets the visible poster cells' focus appearance, the same
  `resetStaleFocusAppearance()` workaround focus changes already need — `TVPosterView` can otherwise
  stay stranded at its enlarged size after the preview hands the cell back.

### iPad tab bar

- Shaped like tvOS: Search glyph first, Settings **gear** last (icon-only, title kept as the
  accessibility label), words in between. Search no longer uses `Tab(role: .search)` — that role
  pinned it trailing next to Settings. iPhone keeps the role (bottom-bar HIG) and gets `gear` too.
- Subscription-days badge is off the Settings tab (both iOS layouts); `subscriptionDaysBadge` is
  gone with it. Days left still show inside Profile.

### Detail — people shelves

- "More from \<director\>" / "More with \<actor\>" rails under Similar on the item page. First
  credited name only, `LibraryFilter.person` + Kinopoisk sort, skeleton while loading, hidden when
  empty. Title taps push `PersonItemsView`. Actor queries send `cast=` (live API), not the docs'
  `actor`.

### Detail hero

- Two columns on tvOS/macOS instead of three: **title + actions** (fixed width) | **synopsis,
  credits, facts** (fills the rest). The "starring" column is gone; its lines moved under the plot.
- Column order inside the written column is synopsis → genres · country / cast / director →
  year · runtime + score + chips. Facts sit at the foot, not the head.
- Actions are a vertical stack: Play pill, then one row of identical circles. `plus` follows the
  series (`togglewatchlist`), `bookmark` opens folders, `checkmark` marks watched, `film` plays the
  trailer. The first two used to be the same folder menu; `isInWatchlist` was never seeded from the
  API, so the follow control always opened as "not following" and the first tap unfollowed.
- Watched checkmark shows for films and series whenever anything is unwatched (was: only mid-title),
  and hides once everything is watched. A series asks episode or season;
  `MediaItemModel.toggleWatched(season:)` uses `/v1/watching/toggle` with a season and no video
  number, then refetches — the bulk response carries no per-episode flags.
- Aggregate `RatingBadgeView` (the poster badge) replaces the split IMDb/Kinopoisk scores.
- Age-rating chip is **opt-in** (`MediaItemDisplayPreferences.showAgeRatingBadge`, Settings →
  Details → Metadata). Still always listed in the information table.
- Overflow moved from a hero circle to the navigation toolbar on iOS/macOS; tvOS keeps the circle.
- No navigation bar on the item page (iOS/macOS): hidden toolbar background, empty title.
- Ambient trailer is off on iOS pending a phone hero that gives the picture room.
- macOS `TrailerLayerHostView` now uses `makeBackingLayer()` so the `AVPlayerLayer` *is* the backing
  layer. It was a sublayer under a `layer` assigned after `wantsLayer`, which left the view
  host-backed: `layout()` did not reliably fire and aspect-fill rendered at a stale frame size.

### Typography

- `TypeScale.detailBody` (`.body`) is the single running-text size on the item page — hero metadata,
  synopsis, credit lines, rating vote counts, and every information-table row. They were four
  hand-picked sizes between 12 and 15pt. Rule recorded in
  [apple-native-design](AGENTS.md): always a Dynamic Type text style,
  and when unifying sizes, unify **up**.

### Documentation

- Rebuilt agent constitution ([AGENTS.md](AGENTS.md)), Cursor rules, policies, feature-stage docs, and
  English Apple-platform knowledge base.
- README reduced to public overview + eight macro stages; minutiae moved to feature docs.
- July 2026 research and notes export archived under [`docs/archive/`](docs/archive/); duplicate
  `research/en` + `research/ru` trees removed.
- Continuity policy replaces the old absolute “no skeletons” rule: stale-first rendering first;
  exact-layout skeletons only on true cold loads.

## 2026-08 — Native UI remediation (historical)

Agent-relevant facts from the remediation pass (verify in code before assuming still true):

- Home: contained 16:9 banner shelf; Netflix `showsFeaturedPreview` path deleted.
- Blur: private `CAFilter` `variableBlur` over static art; Metal progressive blur removed; no blur
  over video on tvOS/macOS.
- Hero CTAs: white Play pill + translucent secondaries (not Liquid Glass on hero).
- Navigation: unified `Route` + `RouteDestination`; zoom transitions on iOS/tvOS.
- Detail: single vertical `ScrollView` (offset slideshow removed).
- Playback: app-scoped `PlaybackSession` (one `PlayerManager` at a time).
- Shell: shared `.sidebarAdaptable` `TabView`; macOS profile via `tabViewSidebarBottomBar`.
- Caching: `ContentStore` list-row cache for Home/Library summaries shipped; item-facts TTL and
  paginated grid cache still open ([ROADMAP](ROADMAP.md#1--foundation-and-ui-stabilization)).

## Earlier

See git history and dated plans under [`docs/archive/plans/`](docs/archive/plans/) /
[`docs/archive/plans/`](docs/archive/plans/) for pre-remediation modernization work.
