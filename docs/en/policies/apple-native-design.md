# Apple-native design

Durable UI policy for this multiplatform client. How-tos and API tables live in
[`docs/en/apple-platform/`](../apple-platform/).

## Goal

Look and feel like a stock Apple media app, with a wider feature set. Extend capability, not the
visual vocabulary. Match Apple TV / TV / Music / Journal patterns; steal features from microiptv and
the community fork's backend, not their chrome.

## Platform stance

- Ship a real app on **tvOS, iOS, iPadOS, and macOS**.
- tvOS defines media consumption, focus, and the 10-foot quality bar.
- Each platform uses **its own** native controls: remote focus / lockups on TV, touch gestures on
  iPhone, pointer / sidebar / menus on Mac. Do not force one platform's chrome onto another.
- One app target. Differences live in `#if os(...)` or thin platform bridges.

## Control selection order

1. Stock SwiftUI container or control (`List`, `Form`, `TabView`, `NavigationStack`, system buttons,
   menus, sheets, scroll-edge effects, materials).
2. System UIKit / AppKit / AVKit API through a thin representable / bridge when SwiftUI cannot express
   the real system behavior (player, some tab badges historically, layered images, private filters).
3. Proven pattern from Apple sample code, our reference apps (Rivulet, Silo, IceCubes), or a mature
   library — see [agent-workflow](agent-workflow.md) borrow-before-build.
4. Minimal custom component.

UIKit / AppKit is not a failure of SwiftUI. It is required when the system behavior lives there, or
when Instruments proves SwiftUI cannot hit acceptable focus / layout / performance.

## Custom and private API

- Custom UI needs: the missing system API named, alternatives rejected, and ongoing cost stated.
- Private API (for example `CAFilter` `variableBlur`) is allowed on this personal project when
  isolated behind a thin helper, with availability / fallback and a short decision note.
- Do not sprinkle private symbols through feature views.
- **Distribution is personal builds / TestFlight; App Store review is not a target.** That is what
  keeps private API acceptable. If distribution ever changes, revisit this section first — do not
  quietly ban private API on App Store grounds that do not apply.

## Settled visual decisions

| Topic | Decision |
| --- | --- |
| Appearance | Dark only until the deliberate light-theme stage |
| Accent | White / system; no kino.pub site green |
| Home featured band | Contained 16:9 banner shelf **today**. Not a ban: the user's stated direction is toward a focus-preview / autoplaying hero. Reopen it with prototypes, do not "defend" the current shelf |
| Hero CTAs | White Play pill + translucent circular secondaries — **not** Liquid Glass on hero |
| Blur | Private `variableBlur` over **static** art; **no blur over video on tvOS/macOS**; blur OK over video on iOS/iPadOS |
| Nav / list chrome | Prefer system scroll-edge / materials / `backgroundExtensionEffect` |
| Poster focus | Native `.borderless` + explicit `.hoverEffect`; system lift / specular / tilt |
| Continue Watching | Long-press context menu; **no** decorative ⋯ button on the card |
| Player | Native `AVPlayerViewController`; single app-scoped `PlaybackSession`; custom overlays only where system cannot (e.g. dual sidecar subs on tvOS) |
| Downloads | Non-TV only; feature-gate until ready |

## Atoms and inheritance

- One media-card component family (poster + landscape), one badge path, one image loader, one type
  scale, one section header.
- New screens compose atoms. Do not re-skin the same card three ways.
- Semantic tokens (`Color.KinoPub.*`, `TypeScale`) over hard-coded greys and one-off fonts.

## Adding a component

1. **Check the atoms first.** A card, badge, section header, image view, or button style probably
   already exists. Extend it instead of adding a sibling.
2. **Reusable UI lives in `KinoPubUI`.** Screen-specific composition stays in the app target.
3. **Semantic tokens only.** `Color.KinoPub.background` is opaque on every platform — if a surface
   needs to be see-through, layer a scrim explicitly; do not expect the token to be transparent.
4. **Ship a working `#Preview`,** on tvOS too when the component is focusable.
5. **tvOS focus is part of "done":** reachable, visibly focusable, verified on the remote — not from
   a preview. See [focus-and-tvui](../apple-platform/focus-and-tvui.md).
6. **One component, `#if os(...)` inside it** — never a second parallel component per platform.

## Motion and interaction

- Prefer system transitions (`navigationTransition(.zoom)`, matched sources) over custom morphs.
- Gesture-driven motion must be interruptible and track 1:1; springs over scripted ease when the user
  can grab the motion.
- Enter / exit along the same path; anchor sheets / menus to their trigger.
- Respect reduced motion, reduced transparency, and increased contrast.
- State UI motion under ~300ms unless illustrative. No decorative delay that blocks input.

## Ambiguous UI

When the system control is predetermined, implement it. When a noticeable custom piece is
ambiguous, build **2–3 genuinely different** isolated Preview / prototype variants on named axes,
then integrate only the chosen one. See [agent-workflow](agent-workflow.md).
