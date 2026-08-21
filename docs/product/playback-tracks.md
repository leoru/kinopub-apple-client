# Playback tracks — which dub and which subtitles a title opens with

Audio and subtitles are the first thing a viewer notices and the last thing they want to fix by
hand. This file is what the player is supposed to *decide*; the mechanics live on
`TrackResolver` / `TrackPreferenceLedger`, and the shape of kino.pub's own audio payload is in
[docs/providers/kinopub/video.md](../providers/kinopub/video.md).

kino.pub ships several dubs per episode, and they arrive **over time**: a fresh episode may have a
single two-voice track on Monday and a studio dub on Thursday. Every rule here exists because that
is true.

## Scopes

**prd** — A decision is looked up in this order, first hit wins. The order lives in exactly one
place, `TrackMemoryScope.chain(titleID:season:episode:isAnime:)`:

| Step | Key | Why it exists |
| --- | --- | --- |
| Episode | title id + season + episode | What this very episode last played. A rewatch replays it |
| Season | title id + season number | Studios change between seasons — the team that dubbed S1 may not have done S4 |
| Title | title id | The series or film as a whole |
| Genre | `anime` | *"надо запоминать для аниме его предпочтения, не на тайтл"* — a new anime opens the way the last one did |
| App settings | — | Preferred languages and the dub floor. **Mirrors the system list until it is set** |
| System | — | `Locale.preferredLanguages`, in order |

The last two are not scopes and hold no history: they are the ladder the resolver falls back to when
nothing above answered.

**prd** — A play writes to **every** scope that applies, not only the most specific one. Watching
S2E5 in a studio's multi-voice teaches that episode, the season, the title and — on an anime — the
anime bucket.

**prd** — Only `anime` is a class. It is a kino.pub genre and it is about to be a section of ours;
cartoons (genre 23, `мультфильм`) are **not** anime and do not share the bucket.

## What is remembered

**prd** — A dub is remembered as **language + kind + studio**, never as a rendition name, index or
URL. Those differ between two episodes of one season, so remembering one pre-selects nothing on the
next episode.

**prd** — The weight of a remembered dub is **how many episodes were actually watched with it**, not
how many times a picker was opened. *"Ему похуй, что я одну-две серии так глянул, а 99 других в
нормальной озвучке"* — two episodes of a stopgap must never outrank a season.

**prd** — An explicit pick in the player counts immediately, as one play. The next episode follows
it without waiting for the count to build.

**prd** — Each scope also records **every dub it has ever seen on a menu**. That is what makes a
newly-arrived dub distinguishable from one the viewer has been ignoring all along.

## Choosing

**prd** — With no usable history, the ladder decides: preferred audio languages in order (app
setting, else the system's list), then kind DUB → MVO → DVO → VO → AVO → Orig, audio description
last, studio A–Z, more channels first. This is the same ladder the detail page's Audio column
already sorts by (`AudioTracks.sortKey`).

**prd** — With history, the scope's strongest entry wins, if this episode offers it. If it does not,
the next entry down does — that is the top-1 / top-2 / top-3 fallback. Only when no remembered dub
is on the menu does the ladder decide.

**prd** — **A dub that was never on offer before beats a weak habit.** When a menu contains a dub
this scope has never seen, and it outranks the remembered leader on the ladder, and that leader's
weight is under `TrackPreferenceLedger.confidentWeight` (3), the new dub wins. This is the
"watched the first three episodes before anyone dubbed it properly, came back to five more seasons"
case: the stopgap was never a preference, it was the only thing there.

**prd** — Above that weight the habit wins and the new dub just sits in the menu. A viewer who chose
one studio for ninety-nine episodes does not want a fresh dub from someone else taking over.

**prd** — **A dub floor sends us to the original instead of down the ladder.**
`minimumDubKind` is the worst dub kind still preferred over original audio with subtitles —
*"уж лучше на английском, чем в двухголосой"*. Original and unknown-kind tracks are never filtered
by it: the floor is about dub quality, and an original track is not a dub.

**idea** — `minimumDubKind` ships as `nil` (no floor) so nothing changes silently. Whether the
shipped default should be multi-voice is the owner's call.

## Subtitles

**prd** — **Subtitles are the same mechanism as audio, not a lesser one.** Same scope chain, same
ledger, same weights. Whether a title opens with them is a localization question exactly like which
dub it opens with.

**prd** — With no history, **the app mirrors the system**: Settings → Accessibility → Subtitles &
Captioning, read through `MediaAccessibility`. `.alwaysOn` means on; `.automatic` — the stock value —
means "let the content decide", which is the rule below. The viewer already answered this question
once, in the place built for it; answering it again with our own default is how an app ends up
disagreeing with the rest of the system about the same preference. System caption languages seed the
subtitle language order the same way.

**prd** — On top of that, subtitles come on when **the audio that won is in a language the viewer
does not read**, whatever the default says. Reading languages are the preferred subtitle languages
plus the preferred audio languages. One rule, and it covers the anime watched in Japanese and the
film that only ever had an English track.

**prd** — When subtitles were asked for and none of them are in a language the viewer reads, a track
they cannot read still beats nothing. Unknown subtitles are a real category.

**prd** — **"Off" is a remembered choice** like any other. A viewer whose system has captions on and
who turns them off here means it, and the next episode has to honour it.

**prd** — Nothing is written when there was nothing to choose. An item that offered no subtitle
track teaches the scope nothing, and recording "off" from a menu that only ever said "Off" would
turn subtitles off for the whole series.

**prd** — A subtitle track is remembered as language + CC-ness, with the same scopes and the same
weights as audio. Forced tracks are never a default: they carry signage and alien dialogue only.

**prd** — Dual subtitles stay where they are (`SubtitlePreferences`, tvOS). They are a deliberate
extra line, not part of what a title opens with.

## Anime

**prd** — `animePrefersOriginalAudio` is a global toggle: on an anime, original audio plus subtitles
wins even when a dub exists.

**prd** — The original language is a **heuristic from data we already have** — the countries on the
title against the languages actually on the menu. Japan with a Japanese track means the original is
Japanese. Nothing is fetched for this, and no provider field is added.

## Later

**idea** — Deviating from the system default is a strong signal: a viewer whose system has captions
off and who turns them on here, on title after title, is telling us their app default. Offer to set
it rather than silently accumulating it. The same for audio, once a language keeps being overridden.

**idea** — With English audio and no subtitle track at all, Apple's own generated captions (26/27+)
are the honest filler. **English only** — the quality on other languages does not carry the feature.

## Open

- **Decay.** A ledger entry never ages. If a viewer's taste moves, the new choice has to out-count
  the old one rather than out-date it.
- **Where the answer comes from before the player opens.** The resolver is pure and takes a menu, so
  a card can ask it as soon as it has one — but nothing calls it from outside the player yet. See
  [ROADMAP.md](../../ROADMAP.md).
