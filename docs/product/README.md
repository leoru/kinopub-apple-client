# Product decisions

**What the product does, per feature. Not how it is built.**

This exists so behavior rules stop landing in AGENTS.md. That file is read on every task by every
agent, so a business rule in it is a cost paid forever by everyone who will never touch that
feature. A rule here is read by whoever opens the feature.

## What belongs here

One file per **feature area**, holding only the decisions someone would otherwise have to guess:
which kinds of title get which treatment, what a label says, what is deliberately not shown. A
logical rule, and the reason it is that way.

**What does not belong here:** how it is implemented (that is a doc comment on the type), what is
still being built ([ROADMAP.md](../../ROADMAP.md)), a shipped implementation fact
([CHANGELOG.md](../../CHANGELOG.md)), the story of an attempt ([docs/archive/](../archive/)), or an
external source's fields ([docs/providers/](../providers/)).

If a rule fits in one line inside an existing file here, it is a line — not a new file.

## Status, on every rule

Each rule carries one, because "we decided this" and "we assumed this" have to be told apart:

| Tag | Means |
| --- | --- |
| **idea** | Proposed, not decided. Nothing may be built to defend it |
| **prd** | Decided by the user. This is a requirement — code follows it |
| **verified** | prd, *and* seen working — on device, or against a live payload. Say which |

An **idea** that got built is a bug in the process, not a requirement. A **prd** nobody has looked
at on screen stays **prd** — do not promote it because it compiles.

## Files

- [continue-watching.md](continue-watching.md) — what the Home row offers, in what order, and what it
  leaves out
- [media-presentation.md](media-presentation.md) — what a title's type and genre change on screen
- [playback-tracks.md](playback-tracks.md) — which dub and which subtitles a title opens with
- [related-sections.md](related-sections.md) — what a detail page recommends, per type
