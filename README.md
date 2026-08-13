# kino.pub Apple client

A native client for [kino.pub](https://kino.pub), built as a **real multiplatform Apple app**
(tvOS, iOS, iPadOS, macOS) with a high bar for focus, materials, and system controls. SwiftUI on
iPhone, iPad and Mac; UIKit + TVUIKit where tvOS media surfaces need the focus engine. One target,
shared models and services, native composition per platform.

Fork of [leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client). A sibling fork,
[dungeon-master-xx/kinopub-apple-client](https://github.com/dungeon-master-xx/kinopub-apple-client),
is tracked as read-only remote `community` for **technical steals only** — we do not rebase our UI
onto theirs. See [docs/community-fork.md](docs/community-fork.md).

## What this is

- **Look:** stock Apple TV / TV / Music patterns — rows, native focus lockups, system player, Liquid
  Glass and scroll-edge chrome where they belong.
- **Features:** parity with what people use on Apple TV today (microiptv-class catalog/library), then
  wider: collections, metadata, playback memory, skips, and later language-learning subtitles.
- **Not a website port.** No site-green chrome, no hand-rolled transport bars, no fake focus.

## Current stage

**Stage 1 — Foundation and UI stabilization** (local cache/continuity, shared image pipeline,
navigation/focus/materials). Auth/Settings shell and Library/History unification follow next.
Advanced subtitles are intentionally late.

Detail checklists: [ROADMAP.md](ROADMAP.md).

## Broadly working

- Device-code authorization, catalog browse, search, bookmarks, detail, seasons/episodes
- Native `AVPlayerViewController` playback with resume; app-scoped `PlaybackSession`
- Home banner shelf, row-based Home, system `TabView` + `.sidebarAdaptable`
- List-row caching for Home/Library summaries; TMDB / Kinopoisk enrichment plumbing
- Downloads on non-TV platforms only

Verification gaps and unfinished edges live in [ROADMAP.md](ROADMAP.md) — not as a second roadmap here.

## Macro stages

1. **Foundation and UI stabilization** — continuity, image/metadata store, finish-or-gate auxiliary UI  
   → [ROADMAP](ROADMAP.md#1--foundation-and-ui-stabilization)
2. **Access and app shell** — QR/auth polish; Settings as a real sidebar destination  
   → [ROADMAP](ROADMAP.md#2--access-and-app-shell)
3. **Library and History** — one vertical Library; separate coherent History  
   → [ROADMAP](ROADMAP.md#3--library-and-history)
4. **KinoPub catalog completeness** — collections, similar, photos, people, native metadata  
   → [ROADMAP](ROADMAP.md#4--kinopub-catalog-completeness)
5. **Platform completeness and appearance** — light theme, Top Shelf, platform integrations  
   → [ROADMAP](ROADMAP.md#5--platform-completeness-and-appearance)
6. **Discovery and enrichment** — external metadata UI, editorial surfaces, real recommendations or honest absence  
   → [ROADMAP](ROADMAP.md#6--discovery-and-enrichment)
7. **Playback conveniences** — audio memory, skips, Up Next (no player rewrite)  
   → [ROADMAP](ROADMAP.md#7--playback-conveniences)
8. **Advanced subtitles** — tap-a-word, live captions, language-learning (late)  
   → [ROADMAP](ROADMAP.md#8--advanced-subtitles)

## Requirements

- Xcode with tvOS / iOS / macOS **26.0** SDKs (deployment targets 26.0)
- Swift 5 language mode in packages (`swift-tools-version: 6.2`)
- Single multiplatform target `KinoPubAppleClient` (product name `KinoPub`)
- **Dark appearance only** until stage 5

```
open KinoPubAppleClient.xcodeproj
# pick an Apple TV / iPhone / Mac destination
```

## Documentation

| Doc | Role |
| --- | --- |
| [AGENTS.md](AGENTS.md) | The whole agent context — defaults, banned patterns, traps |
| [ROADMAP.md](ROADMAP.md) | Stages, accepted behavior, checklists |
| `.claude/skills/` | Loaded on demand: tvOS surfaces, chrome, player, metadata, docs |
| [CHANGELOG.md](CHANGELOG.md) | Notable shipped changes |
| [docs/providers/](docs/providers/) | External source capability sheets |
| [docs/community-fork.md](docs/community-fork.md) | Community remote strategy |
| [docs/archive/](docs/archive/) | Frozen plans / research (evidence only) |

API reference: [kinoapi.com](https://kinoapi.com) (verify load-bearing shapes against live JSON).

## App structure

- `KinoPubAppleClient` — app target
- `KinoPubUI` / `KinoPubBackend` / `KinoPubKit` / `KinoPubLogging` / `KinoPubMetadata` — local packages

Third-party today: KeychainAccess, PopupView, Reachability. No analytics or crash-reporting SDK —
crashes come from TestFlight / Xcode Organizer; product analytics is a late-stage item.

## Contributing

Read [AGENTS.md](AGENTS.md) before changing code. Prefer small slices; put detail work in feature
docs; change this README only when positioning, the current macro stage, or a broad capability changes.

- [Feature request](https://github.com/HipsterCat/kinopub-apple-client/issues/new?template=feature_request.md)
- [Bug report](https://github.com/HipsterCat/kinopub-apple-client/issues/new?template=bug_report.md)

## Credits

Built on [leoru/kinopub-apple-client](https://github.com/leoru/kinopub-apple-client) by Kirill Kunst
and contributors.
