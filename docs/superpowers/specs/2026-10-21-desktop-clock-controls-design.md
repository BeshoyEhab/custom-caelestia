# Desktop clock: reposition, drag, and style controls

## Intent

The desktop clock should feel like a real widget, not a fixed decoration:

- It repositions itself to the emptiest (or busiest) part of a new wallpaper.
- After it lands, the user can drag it anywhere, including while auto-placement
  is active.
- Position changes animate; dragging never lags behind the cursor.
- The clock has a deep style editor matching the spirit of end-4's
  dots-hyprland clock settings, including the Android 12-style cookie clock.

The current implementation already has preset anchors, an auto-placement
analysis, a simple drag offset, and a basic analog style. What is missing is
drag-after-auto, reset-on-wallpaper-change, animated placement, and the style
surface that makes the cookie clock worth having.

## Goals

1. **Auto-place on wallpaper change.** Whenever the active wallpaper changes and
   the clock is in `auto-empty` or `auto-full`, run the least-busy analysis again,
   animate the clock to the result, and clear any user drag offset for that screen.
2. **Drag everywhere.** Allow dragging in every position mode, including both
   auto modes. Persist the offset per screen. Keep drag 1:1 with the cursor.
3. **Animate placement.** Position changes animate (preset to preset, preset to
   auto, auto to auto, wallpaper change). A setting can turn this off.
4. **Full cookie style.** Add a third clock style, Cookie (Android), with the
   end-4 knobs: sides, dial style, hour/minute/second hand styles, date style,
   centre digits, hour marks, date-in-clock, sine-cookie shape, constant rotation.
5. **Digital style controls.** Add end-4's digital knobs in a form that fits the
   existing Caelestia digital layout: orientation, date, seconds, change
   animation, adaptive alignment, font family/weight/size/width/roundness, quote.
6. **Expose the hidden settings.** Scale, invert colours, plate, and shadow get
   UI instead of being config-file-only.
7. **Clean settings surface.** Move clock-specific settings to a "Clock" sub-page
   under Wallpaper & style, leaving a compact summary on the main page.

## Non-goals

- Lock-screen clock and bar clock settings are unchanged.
- No Gemini or network-based "AI styling". The end-4 option is omitted rather
  than shipped as an inert switch.
- No live full-size clock preview inside Nexus. Rows use end-4-style icon/menu
  affordances instead.
- No new C++ rendering work. M3Shapes is already a build dependency and provides
  the cookie/star/bubble geometry.
- No wallpaper-change animation of the wallpaper itself.

## Anti-goals

- The default digital clock must look the same as today.
- Dragging must never feel rubber-banded by the position animation.
- No config key may exist without a documented effect. The two variable-font axes
  are documented in the UI as requiring a variable font.
- Constant rotation must stay off by default and must be labelled expensive.
- No per-second timer runs when no visible clock needs seconds.

## Constraints

- QML runs from `~/.config/quickshell/caelestia/`; source lives in `shell/`.
  Both locations must be updated when the work is deployed (see AGENTS.md).
- Config is a C++ backend (`shell/plugin/src/Caelestia/Config/`) built into the
  local plugin. New options require a rebuild and a config schema entry.
- Nexus uses the existing `PageBase`/`StackPage`/`ToggleRow`/`SelectRow`/
  `SliderRow`/`StepperRow`/`TextFieldRow`/`NavRow` components. No new generic
  controls are needed.
- M3Shapes exposes `star(points, innerRadius, radius, smoothing)` as an
  **instance method** on `MaterialShape` (not a static type method), plus the
  `Cookie*Sided`, `Pentagon`, and `Pill` enums. `MaterialShape` supports
  `customShape`.
- Quickshell/Qt 6.9. Repeater delegates use `pragma ComponentBehavior: Bound`.
- The analysis script is `shell/scripts/least_busy_region.py`; do not change its
  CLI contract.

## Position model

Replace the anchor-state machine with a single x/y model. This is the core of
the animation and drag work.

### Geometry

For a clock of size `w × h` in a screen of `W × H`, with bar/border-aware insets
`insetL`, `insetR`, `insetT`, `insetB`:

```
preset x = left   ? insetL
         : right  ? W - insetR - w
         :          (W - w) / 2
preset y = top    ? insetT
         : bottom ? H - insetB - h
         :          (H - h) / 2
```

Auto placement clamps the analysed centre to the same inset box:

```
x = clamp(cx - w/2, insetL, W - insetR - w)
y = clamp(cy - h/2, insetT, H - insetB - h)
```

The drag offset `(dx, dy)` is applied through the existing `Translate`
transform, not by writing x/y. That keeps dragging independent of the
animation and of the analysis.

### Why no anchors/states

Anchors plus `AnchorAnimation` animate preset changes but cannot animate the
auto x/y path, and mixing them makes drag-in-auto awkward. A single x/y binding
lets one `Behavior` animate every position change. It also fixes an existing
inconsistency where right/bottom presets ignored the bar/border insets while
left/top honoured them. The new model uses the same inset box on all sides.

### Animation

- `Behavior on x` and `Behavior on y`, `Anim { type: Anim.DefaultSpatial }`.
- Enabled only when `animatePosition` is true, the first placement has settled,
  and the user is not dragging.
- First placement is marked settled after the first auto analysis result (or
  immediately for non-auto modes) using `Qt.callLater`, so the clock does not
  fly in from `(0,0)` at startup.
- Drag uses the `Translate` transform and is never animated.
- On drag release, x/y do not change, so nothing snaps.

### Wallpaper change

- Watch `Wallpapers.actualCurrent` (not `current`, so previewing a wallpaper in
  Nexus does not move the clock).
- On change, if the mode is `auto-empty` or `auto-full`:
  1. reset `dx`/`dy`, clear `custom`, and persist the empty offset;
  2. let the existing `clockAnalysisCmd` rebuild (it already includes the image
     path) and run the analyser;
  3. the new `autoPos` values animate x/y.
- In preset modes, a wallpaper change does not move the clock and does not
  clear the drag offset.
- Changing `position` in settings keeps the existing reset (offset cleared,
  clock snaps/animates to the preset).
- If the analysis fails, fall back to screen centre as today.

### Analysis pacing

Clock width/height can animate (scale, font changes), and the analyser command
currently depends on the live width/height. Running it on every intermediate
frame would spawn one Python process per frame and can place the clock using a
stale size.

- Feed the analyser from a 300 ms debounce timer that restarts on every
  `clockAnalysisCmd` change, instead of calling `analysisProc.exec()` directly
  from `onClockAnalysisCmdChanged`.
- The command is built at fire time, after the size animation has settled.
- A result that arrives after a newer command was scheduled is discarded
  (compare a monotonically increasing run id).
- The "first placement settled" flag is set by the first accepted result (or by
  the first frame for non-auto modes).

### Drag bounds

- The dragged rectangle must stay inside the inset box on all four sides.
- The MouseArea covers the clock rectangle and is active in every mode.
- A drag sets `custom = true`; release persists `{dx, dy}`.
- Double-clicking the clock clears the offset for that screen and returns it to
  its preset/analysed position. This is the escape hatch after an accidental
  drag in a preset mode, where no other reset path exists.
- Persistence stays per screen in
  `${Paths.state}/desktopClockPos-<screen>.json` and keeps the immediate-write
  `FileView` approach (PersistentProperties are not reliable across crashes).

## Config schema

All options live under `background.desktopClock`.

```
enabled            bool    false
scale              real    1.0          0.5 – 2.0
position           string  "bottom-right" 9 presets + auto-empty/auto-full
clockStyle         string  "digital"     digital | cookie | analog
invertColors       bool    false
animatePosition    bool    true
quote.enabled      bool    false
quote.text         string  ""

digital.orientation       string "auto"    auto | horizontal | vertical
digital.showDate          bool   true
digital.showSeconds       bool   false
digital.animateChange     bool   true
digital.adaptiveAlignment bool   true
digital.font.family       string ""        empty = theme clock font
digital.font.size         real   1.0       0.5 – 2.0 multiplier
digital.font.weight       int    700       1 – 1000
digital.font.width        int    100       25 – 125 (wdth axis)
digital.font.roundness    int    0         0 – 100 (ROND axis)

cookie.sides              int    14        4 – 40
cookie.dialNumberStyle    string "full"    none | dots | full | numbers
cookie.hourHandStyle      string "fill"    classic | fill | hollow | hide
cookie.minuteHandStyle    string "medium"  classic | thin | medium | bold | hide
cookie.secondHandStyle    string "dot"     classic | line | dot | hide
cookie.dateStyle          string "bubble"  border | rect | bubble | hide
cookie.timeIndicators     bool   true
cookie.hourMarks          bool   false
cookie.dateInClock        bool   true
cookie.useSineCookie      bool   false
cookie.constantlyRotate   bool   false

background.enabled   bool  false
background.opacity   real  0.7
background.blur      bool  true
shadow.enabled       bool  true
shadow.opacity       real  0.7
shadow.blur          real  0.4
```

`auto` orientation means vertical when the clock sits on the left or right edge,
preserving today's edge behaviour. Explicit `vertical`/`horizontal` override it.

Unknown-key warnings and auto-save behave as they do for every other config
object; no migration script is needed. `shell/README.md`'s sample config gets
the same tree.

## Clock rendering

### Digital

Keep the existing Caelestia "accent" layout: bold hour, coloured colon, minute,
a divider, then a date column. Do not replace it with end-4's stacked layout.
The new knobs map onto it:

- `orientation`: `auto` keeps the current edge-driven vertical mode, decided by
  the `position` key only (`left`/`right` presets are vertical; auto and other
  presets are horizontal). It is deliberately not derived from the clock's
  actual x, so dragging can never flip the layout, change the analysed box, or
  oscillate. Explicit `vertical`/`horizontal` override it.
- `showDate`: hides the date column in horizontal and the date lines in vertical.
- `showSeconds`: adds a small seconds field after the minute. Off by default.
- `animateChange`: sets `ClockText.animate` on the time and date fields; text
  cross-fades via the existing `Behavior on text`.
- `adaptiveAlignment`: in horizontal mode the date column gets the same width
  as the time group, and its text aligns left/centre/right based on the clock's
  screen third. Vertical mode aligns all fields. Centre is the default look.
- `font.*`: applies to the **time group only** (hour, colon, minute, AM/PM,
  seconds), matching end-4, whose date text keeps its own typography. Build the
  time text with
  `Tokens.font.clock.size(base * font.size).weight(font.weight)
   .vaxes({wdth: font.width, ROND: font.roundness})` and `.family(family)` when
  family is non-empty. `font.weight` replaces the hour/minute Bold weight; the
  colon and AM/PM keep their current lighter weights, so size 1.0 weight 700
  looks exactly like today. The date column keeps today's title/headline/body
  sizes, per-field weights (Bold/Medium/default), and letter spacing. `width`
  and `roundness` only affect fonts with `wdth`/`ROND` axes; the UI says so in
  the subtext.
- `quote`: one line of body text under the clock, wrapped, at `body.large`.
  With the backdrop plate on it sits on a `m3surfaceContainerHigh` plate with
  `m3onSurface` text; with the plate off it is `m3onSurface` over the wallpaper.
  `m3onSecondaryContainer` was dropped: at the default 0.7 plate opacity over a
  light wallpaper the muted on-container ink fell to ~3:1, while the surface
  pair holds ~5.5:1 on the same backdrop. The plate follows the opacity/blur
  settings like the digital plate. Hidden when empty.

### Cookie (Android)

A face of `230 * scale` logical pixels, using M3Shapes for the outline.

- **Face**: `MaterialShape` with
  `customShape: shapeBuilder.star(cookie.sides, 0.8, radius, smoothing)`, where
  `shapeBuilder` is a hidden `MaterialShape` instance (the installed Qt 6.11
  plugin does not expose `star` statically). `useSineCookie` swaps in a
  `Shape`/`PathPolyline` sine-star outline ported from end-4 (amplitude
  proportional to size, 360 points).
- **Rotation**: `constantlyRotate` rotates only the face outline continuously
  (30 s linear). It does not rotate hands or dial. Off by default.
- **Dial**: `none`; `dots` = 12 dots; `full` = 60 minute ticks plus 12 longer
  hour ticks; `numbers` = 3/6/9/12 large numerals.
- **Hands**: ported geometry and styles from end-4:
  - hour: `classic` thin bar, `fill` rounded bar, `hollow` outlined bar, `hide`;
  - minute: `classic`, `thin`, `medium`, `bold`, `hide`;
  - second: `classic` line with mid dot, `line`, `dot`, `hide`.
  Hour/minute rotation animates clockwise over ~300 ms. Second-hand rotation
  animates only when `constantlyRotate` is on; otherwise it ticks.
- **Centre digits**: `timeIndicators` shows HH and MM (plus AM/PM in 12-hour
  mode and an optional small seconds field). It shrinks when `hourMarks` is on
  so the two do not collide.
- **Hour marks**: a small inner ring of 12 marks, allowed only for `dots`/`full`
  dial styles (the setting disables itself otherwise).
- **Date**: `bubble` = day bubble top-left + month bubble bottom-right;
  `rect` = a compact date plate on the right; `border` = date text around the
  rim; `hide` = none. With `dateInClock` false, the date moves below the face
  instead of inside it, using the current `MMMM / dd / dddd` stack.
- **Colours**: the face is a large surface, so it takes the container role —
  `m3primaryContainer` with `m3onPrimaryContainer` for the centre digits' base.
  The vivid accents go to the hands: hour/second `m3primary`, minute
  `m3tertiary`. The dial is `m3primaryContainer` tinted 15% with `m3secondary`
  (subtle marks), and the centre digits are a 55/45 `m3primary`/container mix
  (mid-tone), mirroring end-4's `CookieClock`. Date badges are contrast-picked by
  `ClockColours.pickBadge` (tertiary container for the day, secondary for the
  month in the current dark scheme) so a pale container never lands on the face.
  `invertColors` swaps the face to `m3primary`/`m3onPrimary` and uses on-accent
  marks. This is what keeps the clock distinct from the shell's main accent.
- **Shadow**: apply the configured `MultiEffect` shadow to the face outline,
  not to the whole item, so hands stay crisp. The body plate/blur background is
  not drawn for Cookie or Analog (the face is already opaque); the quote gets
  its own plate when the backdrop is on.

### Analog

Unchanged geometry and colours. It inherits scale, invert colours, and the new
placement/drag/animation model. No new analog-specific knobs.

### Shared

- `scale` changes animate via the existing `Behavior on clockScale`.
- Width/height also get a `Behavior` so style and font-size changes resize
  smoothly.
- Style switches are allowed to swap content immediately; only position and
  size animate.
- Quote renders for every style below the clock body.

## Settings UI

### Wallpaper & style page

Replace the current "Clock style" select with:

1. `ToggleRow` — Desktop clock.
2. `SelectRow` — Position (the existing 11 entries).
3. `NavRow` — "Clock appearance", status = current style name, opens sub-page
   index 4 of the Wallpaper & style stack.

The main page stays short; everything else moves to the sub-page.

### Clock sub-page

New file `shell/modules/nexus/pages/wallandstyle/ClockSettings.qml`, registered
as component index 4 of the Wallpaper & style `StackPage` (after the existing
page, wallpaper select, category and colour select components) and reached with
`nState.openSubPage(4)`.

Sections, in order:

**General**
- Enabled toggle.
- Style select: Digital / Cookie (Android) / Analog.
- Scale slider (0.5–2.0, label `×1.0`).
- Animate position toggle.
- Invert colours toggle.
- Quote toggle + text field (applies to every style).
- A short hint line: "Drag the clock to move it. Double-click it to reset."

**Backdrop**
- Plate toggle; opacity slider; blur toggle (digital, or any style when the quote
  is enabled — the plate then wraps the quote).
- Shadow toggle; opacity slider; blur slider (digital and cookie).

**Digital** (visible when style is digital)
- Orientation select (Auto / Horizontal / Vertical).
- Show date, show seconds, animate time change, adaptive alignment toggles.
- Font family text field (placeholder = theme font).
- Weight slider (1–1000), text size slider (0.5–2.0), width slider (25–125),
  roundness slider (0–100).

**Cookie** (visible when style is cookie)
- Sine-cookie toggle, sides stepper (4–40), constant-rotation toggle with the
  expense warning in the subtext.
- Date-in-clock toggle, hour marks toggle (disabled unless dial is dots/full),
  centre digits toggle (disabled for numbers dial).
- Dial style select (None / Dots / Full / Numbers).
- Hour hand select, minute hand select, second hand select.
- Date style select (Bubble / Border / Rect / Hide).

**Analog**
- Short explanatory subtext only; no knobs.

Rows use `first`/`last` grouping and only appear when relevant. Every row binds
to `GlobalConfig.background.desktopClock.*`; the settings page is global even
though the background window uses per-screen config.

### Search

The sub-page rows register with `SearchIndex` through the existing row
components. The existing "clock" keywords on the Wallpaper & style page remain.

## File map

New:
- `shell/modules/nexus/pages/wallandstyle/ClockSettings.qml`
- `shell/modules/background/DigitalClock.qml` (extracted from DesktopClock)
- `shell/modules/background/cookie/CookieFace.qml`
- `shell/modules/background/cookie/CookieDial.qml`
- `shell/modules/background/cookie/CookieHands.qml`
- `shell/modules/background/cookie/CookieDate.qml`
- `shell/modules/background/cookie/SineCookie.qml` (only if kept separate)

Changed:
- `shell/plugin/src/Caelestia/Config/backgroundconfig.hpp` (subobjects + defaults)
- `shell/modules/background/DesktopClock.qml` (shell + style dispatch)
- `shell/modules/background/CookieClock.qml` (rewrite; currently unused)
- `shell/modules/background/Background.qml` (x/y model, drag, reset, animation)
- `shell/modules/nexus/pages/WallpaperAndStyle.qml` (compact clock section)
- `shell/modules/nexus/PageCompRegistry.qml` (register sub-page 4)
- `shell/README.md` (sample config)

No changes to `shell/upstream/`.

## Verification

Automated:
- Build the plugin (`cmake --build build` or `./build-plugin.sh`) to prove the
  config schema compiles.
- `tests/run.sh` (QML structure/import checks, widget checks, existing suites).
- Grep checks: every new config key appears in both the C++ header and the
  settings page; no `Colours.palette` file misses `import qs.services`.

Manual, on a live session:
1. `auto-empty` + wallpaper change → clock animates to the empty area.
2. Drag in `auto-empty` → follows cursor exactly; release persists; restart
   restores the offset.
3. Wallpaper change after a drag → offset clears and the clock repositions.
4. Preset → preset, preset → auto, auto → preset all animate; `animatePosition`
   off makes them jump.
5. Each style renders: digital (all knobs), cookie (each hand/dial/date option,
   sine shape, rotation), analog.
6. Cookie date-in-clock on/off, quote on/off, seconds on/off.
7. Multi-monitor: drag offsets are per screen; settings remain global.
8. Double-click resets the clock to its preset/analysed position and persists.
9. Changing scale/style/font while in an auto mode starts one analyser run after
   the size settles, not one per frame.
10. No QML warnings on startup; shell restart clean.

Deploy:
- Copy changed QML to `~/.config/quickshell/caelestia/` (or `./install.sh
  --update`) and rebuild the plugin before live testing.
- The repo `shell/` tree remains the source of truth.

## Decisions made here (builder may revisit with reason)

- Single x/y position model over anchors/states.
- Inset box used on all four sides for presets, not just left/top.
- `orientation: auto` is decided by the `position` key, never by the dragged
  geometry. No feedback loop, no mid-drag layout flips.
- Digital `font.*` applies to the time group only; the date column keeps its
  current typography. This matches end-4 and preserves the default look.
- Digital `font.size` is a multiplier over the existing `scale`, not absolute
  pixels, so the two settings compose.
- `font.width`/`font.roundness` stay in the schema and are labelled as
  variable-font-only; with the default Rubik clock font they have no effect.
- Cookie face colours follow the M3 container palette rather than end-4's
  fixed appearance colours.
- `dateInClock` is made meaningful (inside face vs below face); end-4's key is
  effectively unused.
- AI/Gemini styling is omitted; no switch that does nothing.
- Digital layout stays Caelestia's accent layout, not end-4's stacked layout.
- Drag reset is a double-click on the clock, not a settings row. It is
  per-screen and needs no cross-component state.
- The analyser is debounced (300 ms, last result wins) instead of running per
  size-animation frame.

## Implementation notes

- The cookie face builds its star polygon through a hidden
  `MaterialShape { id: shapeBuilder }`; a static
  `MaterialShape.star(...)` call silently produces no face.
- Cookie dates use the same inverted palette set as the face:
  `safeTertiary` for the day bubble, `safeSecondary` for the month bubble and
  rect, and the face's on-colour for all date text. The below-face
  `MMMM / dd / dddd` stack uses that single text colour (monochrome), not the
  old split accent colours.
- `SliderRow` gained an optional `subtext` so the width/roundness rows can
  document that they only affect variable fonts. Existing sliders leave it
  empty and are unchanged.
- Nexus exposes the settings through the Wallpaper & style sub-page index 4;
  the main page keeps only the enabled toggle, position select, and a
  "Clock appearance" `NavRow`.

## Left to the builder

- Exact decomposition of the cookie components (one file vs several).
- Whether to port end-4's sine-cookie path wholesale or generate equivalent
  points.
- Exact easing/duration tokens for x/y and hand rotation.
- Whether the plate opacity/blur rows are worth showing for Cookie (design says
  no) or should be hidden entirely.
- Test additions, if any, beyond the existing suite.
