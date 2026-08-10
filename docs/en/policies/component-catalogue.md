# Policy: one component catalogue, templated pages

> Durable policy, not a dated plan. Applies to every platform, most sharply to tvOS.
> Related: [focus-and-tvui](../apple-platform/focus-and-tvui.md),
> [layout-and-containers](../apple-platform/layout-and-containers.md),
> [materials-blur-and-chrome](../apple-platform/materials-blur-and-chrome.md).

## The rule

**Pages are assembled from a fixed catalogue of components. A page is a list of typed
sections, not a hand-written stack of views.**

Two pages that show a shelf must show the *same* shelf — same component, same metrics,
same focus behaviour — not two views that happen to look similar. When a shelf is
wrong, it is wrong in one place and fixed in one place.

This is the single most violated rule in this codebase's history. Every regression
worth remembering came from a screen growing its own copy of something that already
existed: a second "big rating number" style beside `TypeScale.ratingAggregate`, three
independent poster shelves on the detail page each with its own focus state and menu
coordinator, a hand-rolled `ExpandableButtonStyle` where `.card` was meant, section
headers written inline in the information table instead of `SectionHeader`.

## Where the catalogue comes from

TVML's `productTemplate` is the reference specification, and it is not nostalgia:
Apple deprecated the *transport* (XML + a JS engine), not the design. What Apple's
current SwiftUI tvOS guidance describes — a showcase header at ~80% of the viewport,
shelves below the fold, snapping at the fold, a material gradient over the artwork —
is the same page, restated. Read `productTemplate` as the spec of what a media detail
page **is**, then build it from native parts.

Most of those parts already exist natively; TVUIKit is the surviving edition of the
same lockups. Reach for these before writing anything:

| Concept (TVML name) | Use |
| --- | --- |
| `banner` | above-the-fold region: `containerRelativeFrame(.vertical) { l, _ in l * 0.8 }` + full-width `.focusSection()` |
| `heroImg` / `background` | one wide still + `.regularMaterial` masked by a `LinearGradient` whose stop opacities animate |
| `shelf` / `section` / `lockup` | `MediaPosterShelf`, `TVUIKitMediaCollection`, `TVPosterView`, `TVLockupView` |
| `monogramLockup` | `TVMonogramContentConfiguration` — it draws the circle, the background and the initials from `personNameComponents`; never hand-pick those |
| `buttonLockup` | `TVCaptionButtonView`, or a `Button` whose label is a `Label` |
| `badge` / `textBadge` | an `Image` from the asset catalogue; badges are artwork, not text |
| `productInfo` / `infoTable` | the About block's columns — a table, quiet, free to grow |
| `description handlesOverflow` | truncated text in a `.plain` `Button` + `fullScreenCover` |
| section header | `SectionHeader` — and on tvOS it never navigates (no chevron, no `NavigationLink`) |

No native equivalent exists for `ratingCard`, `reviewCard` and the `ratingBadge` bar.
Those we own — which means they too live in exactly one place.

## Native first, and at the right level

- Prefer the system control over a custom one. `.card` / `.borderless` / `.plain`
  carry the platform's focus motion for free; a custom `ButtonStyle` re-implements it
  worse and then has to be maintained.
- Assign the button style **on the outside of the container**, not per item. A shelf
  holds one kind of lockup.
- A `ButtonStyle` cannot apply another button style to its own `configuration.label` —
  that line does nothing. If a call site needs native focus, change the call site.
- State that drives a page-wide appearance must have exactly **one writer**. Two
  writers racing one flag has broken this page twice (`washProgress`, then the fold).

## Trying designs is allowed — divergence is not

While a component's look is unsettled, it is fine to keep **2–4 variants of that one
component** side by side behind a switch, so they can be compared on real data. That is
exploration and it is encouraged.

What is not allowed is the same idea implemented twice in two places because two
screens needed it. The variants must be variants *of one component*, in one file, and
the losers get deleted once a winner is picked — along with the switch.

## For agents working in this repo

Before writing a view, answer these:

1. Does this already exist in the catalogue above, or in `KinoPubUI`? Use it.
2. Is there a system component (SwiftUI, UIKit, TVUIKit) that does it? Use that.
3. Am I about to write focus, scale, shadow or blur by hand? Almost certainly the
   platform already has it — check before hand-rolling.
4. If it is genuinely new: put it in `KinoPubUI` as one component, used by name, and
   add it to this table.

A screen-specific copy is a defect, even when it looks right.
