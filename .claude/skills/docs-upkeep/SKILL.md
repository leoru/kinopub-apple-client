---
name: docs-upkeep
description: Recording something you learned, decided, or were told — where a fact belongs, how to write a rule that survives, and how to retire a stale one. Use before adding to AGENTS.md, ROADMAP.md, a skill or the changelog, and whenever you are about to write down a limitation you hit.
---

# Writing things down without growing a bureaucracy

This repo previously carried ~30 documents across four genre folders and ~21k words of dated plans.
Agents read the plans as law, defended workarounds they found there, and the volume made every
session start expensive. The current shape exists to stop that, and it only holds if new facts land
in the right place at the right size.

## Where a fact goes

| What you have | Where it goes |
| --- | --- |
| A rule that applies to any surface, or a trap that costs real time | **AGENTS.md** — one line, with the cost |
| A rule that only matters while doing one kind of work | The matching **skill** |
| Something we are going to build, or just built | **ROADMAP.md** — tick the box, or add one |
| A shipped fact a future agent needs (a deleted type, a changed contract, a landed decision) | **CHANGELOG.md** under Unreleased |
| Public positioning or a macro stage change | **README.md** — and only then |
| Endpoints, fields and models of an external source | **docs/providers/** — in full, before integrating |
| The story of an attempt: what was tried, what broke, what the on-device evidence was | **docs/archive/** |

Nothing else exists. Do not create a new top-level document, a new folder, or a fifth "policy" —
if a fact does not fit one of the rows above, it probably belongs in a code comment next to the
thing it describes.

## The bar for a line in AGENTS.md

**A line must carry either the default, or the cost of getting it wrong.** Preferably both. A line
that carries neither is a line the next agent will argue with, and that is how the file grows.

Good — the default is unambiguous and the failure is named:

> Never bind two sibling views to the same `@FocusState` equals-value. Six hero buttons shared one
> case: focus froze dead on Play, and Menu quit the app instead of popping.

Bad — true, unfalsifiable, and worth nothing:

> Focus management should be handled carefully on tvOS.

Also: name what is **dead**. A deleted type that still appears in a comment somewhere will be
resurrected by someone who assumes it is load-bearing. The "what is dead" section is as valuable as
the rules.

## Before writing down a limitation

**Constraints are not requirements.** Classify first (the four labels are in AGENTS.md):

1. **Apple API limitation** — name the symbol, from the SDK headers, and say what you tried. Probe
   it: `swiftc -typecheck` against the SDK settles most of these in a minute. It expires with the
   next SDK.
2. **Performance limitation** — bring a number from a device or Instruments. It expires with the
   next measurement.
3. **Focus / navigation invariant** — describe the state the user gets stuck in.
4. **Product decision** — quote where the user said so.

Only 3 and 4 may become durable requirements. 1 and 2 become **one adapter** with the limitation in
its doc comment — never a statement about what the product is, never an argument for a second
component, never a reason another screen looks different.

If it is none of the four, it is a workaround. Ship it if you must, label it as one in the code, and
do not let it change any other file.

## Retiring a rule

The failure mode is not only adding — it is leaving. When a rule stops being true:

- **Delete it, or mark it void with the date and the reason.** Do not leave both versions and hope
  the reader picks the newer one.
- If it lived in a plan that is now history, add a line at the top of that document saying what
  survived and what did not, then move the file to `docs/archive/`.
- If code comments cite it, fix them in the same change. A stale citation is how a voided rule comes
  back.
- Superseded is not the same as forbidden. Say which one you mean: "we do not do this any more"
  reads very differently from "this was tried, and here is what it cost".

## Updating work in flight

- Tick the ROADMAP box **when it lands**, not when it is planned. A checklist nobody ticks is worse
  than no checklist.
- Be honest about verification. "Builds green, not confirmed on device" is a complete and acceptable
  status; "done" for something nobody watched run is not.
- When you revert something, say so where the claim was made — the revert is the more useful record.

## Size discipline

AGENTS.md is read every session by every agent. Adding 20 lines to it is a real cost paid on every
future task, so it is the file with the highest bar, not the lowest. When it grows past what a
person will actually read:

- move the detail into a skill and leave the *default* behind;
- delete anything already true of the code and unlikely to be undone;
- merge two rules that are the same rule.
