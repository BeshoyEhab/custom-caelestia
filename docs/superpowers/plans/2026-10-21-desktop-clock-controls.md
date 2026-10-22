# Desktop Clock Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the desktop clock reposition on wallpaper change, draggable in every mode, animated, and deeply styleable (digital, Android cookie, analog).

**Architecture:** Replace the anchor-state clock placement with one x/y model driven by a pure JS module, apply the drag offset through the existing `Translate`, and animate x/y with a `Behavior`. Extract the digital clock, port end-4's cookie clock onto M3Shapes, and add one Nexus sub-page for all clock options backed by new C++ config sub-objects.

**Tech Stack:** Quickshell/Qt 6 QML, C++ config plugin (`CONFIG_PROPERTY`/`CONFIG_SUBOBJECT`), M3Shapes (`MaterialShape.star`, cookie shapes), Python least-busy analyser, Node for pure-logic tests, bash test runner.

**Spec:** `docs/superpowers/specs/2026-10-21-desktop-clock-controls-design.md`

## Global Constraints

- Source of truth is `shell/`; the running shell loads `~/.config/quickshell/caelestia/`. Deploy changed files to both at the end.
- Never edit `shell/upstream/`.
- Default digital typography, colours, letter spacing and time layout must not change (font size 1.0 / weight 700). Adaptive date alignment is on by default and follows the clock's screen third, as specified; set `adaptiveAlignment: false` for the old left-aligned date column.
- Dragging uses the `Translate` transform and must be 1:1 with the cursor; x/y are never written during a drag.
- The least-busy analyser runs at most once per settled size, never per animation frame.
- `pragma ComponentBehavior: Bound` is required in QML files with inline Repeater delegates.
- Every QML file using `Colours.palette` needs `import qs.services`.
- Clock settings are global (`GlobalConfig`); drag offsets and placement are per screen.
- Cookie constant rotation is off by default and labelled expensive.
- No config key ships without a visible or documented effect.
- M3Shapes is already a build dependency; do not vendor shape geometry.
- Use existing Nexus controls only (`ToggleRow`, `SelectRow`, `SliderRow`, `StepperRow`, `TextFieldRow`, `NavRow`, `SectionHeader`).
- The worktree currently has unrelated uncommitted changes (bar/workspace overview and `tests/run.sh`). Stage only clock-related hunks; never `git add -A`, and do not blanket-add a file that also carries unrelated edits.

## Review Focus

1. Wallpaper change while a preset is selected must not move the clock or clear its drag offset.
2. An analyser result that lands mid-drag must not move the clock under the cursor; defer it until release.
3. A double-click that resets the offset must win over the press/release drag save, and must not persist a stale offset.
4. Cookie `sides` at 4 and 40, sine outline on, and constant rotation on must render without crashes or degenerate geometry.
5. A nonexistent font family, or width/roundness on Rubik, must fall back to normal text instead of breaking the clock.

Each of these gets an explicit check in the task that owns it, plus manual verification at the end.

---

### Task 1: Config schema and defaults

**Files:**
- Modify: `shell/plugin/src/Caelestia/Config/backgroundconfig.hpp`
- Modify: `shell/README.md` (sample `background.desktopClock` block)

**Interfaces:**
- Produces: new config objects and defaults used by all later QML:
  - `Config.background.desktopClock.animatePosition: bool`
  - `.quote.enabled: bool`, `.quote.text: string`
  - `.digital.orientation: string`, `.digital.showDate: bool`,
    `.digital.showSeconds: bool`, `.digital.animateChange: bool`,
    `.digital.adaptiveAlignment: bool`
  - `.digital.font.family: string`, `.font.size: real`, `.font.weight: int`,
    `.font.width: int`, `.font.roundness: int`
  - `.cookie.sides: int`, `.cookie.dialNumberStyle: string`,
    `.cookie.hourHandStyle: string`, `.cookie.minuteHandStyle: string`,
    `.cookie.secondHandStyle: string`, `.cookie.dateStyle: string`,
    `.cookie.timeIndicators: bool`, `.cookie.hourMarks: bool`,
    `.cookie.dateInClock: bool`, `.cookie.useSineCookie: bool`,
    `.cookie.constantlyRotate: bool`

- [ ] **Step 1: Add the sub-object classes before `DesktopClock`**

In `backgroundconfig.hpp`, add `DesktopClockQuote`, `DesktopClockFont`,
`DesktopClockDigital`, and `DesktopClockCookie`, each `QML_ANONYMOUS` and
derived from `ConfigObject`. Use these exact defaults:

```cpp
class DesktopClockQuote : public ConfigObject {
    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(QString, text, QString())
};

class DesktopClockFont : public ConfigObject {
    CONFIG_PROPERTY(QString, family, QString())
    CONFIG_PROPERTY(qreal, size, 1.0)
    CONFIG_PROPERTY(int, weight, 700)
    CONFIG_PROPERTY(int, width, 100)
    CONFIG_PROPERTY(int, roundness, 0)
};

class DesktopClockDigital : public ConfigObject {
    CONFIG_PROPERTY(QString, orientation, QStringLiteral("auto"))
    CONFIG_PROPERTY(bool, showDate, true)
    CONFIG_PROPERTY(bool, showSeconds, false)
    CONFIG_PROPERTY(bool, animateChange, true)
    CONFIG_PROPERTY(bool, adaptiveAlignment, true)
    CONFIG_SUBOBJECT(DesktopClockFont, font)
};

class DesktopClockCookie : public ConfigObject {
    CONFIG_PROPERTY(int, sides, 14)
    CONFIG_PROPERTY(QString, dialNumberStyle, QStringLiteral("full"))
    CONFIG_PROPERTY(QString, hourHandStyle, QStringLiteral("fill"))
    CONFIG_PROPERTY(QString, minuteHandStyle, QStringLiteral("medium"))
    CONFIG_PROPERTY(QString, secondHandStyle, QStringLiteral("dot"))
    CONFIG_PROPERTY(QString, dateStyle, QStringLiteral("bubble"))
    CONFIG_PROPERTY(bool, timeIndicators, true)
    CONFIG_PROPERTY(bool, hourMarks, false)
    CONFIG_PROPERTY(bool, dateInClock, true)
    CONFIG_PROPERTY(bool, useSineCookie, false)
    CONFIG_PROPERTY(bool, constantlyRotate, false)
};
```

Each constructor with sub-objects initializes them in declaration order:
`DesktopClockDigital` creates `m_font`, `DesktopClockCookie` has no
sub-objects. `DesktopClock` gets `CONFIG_PROPERTY(bool, animatePosition, true)`,
`CONFIG_SUBOBJECT(DesktopClockQuote, quote)`,
`CONFIG_SUBOBJECT(DesktopClockDigital, digital)`,
`CONFIG_SUBOBJECT(DesktopClockCookie, cookie)`, and creates them in its
constructor in the order the members are declared.

- [ ] **Step 2: Build the plugin to prove the schema compiles**

Run: `cmake --build build -j$(nproc)`
Expected: build succeeds, no `Q_PROPERTY`/moc errors.

- [ ] **Step 3: Update the README sample config**

Replace the `"desktopClock"` object in `shell/README.md` with the full tree from
the spec's Config schema section, preserving existing keys and ordering. Use the
same defaults as the header.

- [ ] **Step 4: Commit**

```bash
git add shell/plugin/src/Caelestia/Config/backgroundconfig.hpp shell/README.md
git commit -m "feat(clock): add digital, cookie and placement config"
```

---

### Task 2: Pure position math

**Files:**
- Create: `shell/modules/background/ClockPosition.js`
- Create: `tests/clock_position_test.js`
- Create: `tests/clock_position_test.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Produces, in `ClockPosition.js`:
  - `isAuto(position: string) -> bool`
  - `preset(position: string, screenW: real, screenH: real, w: real, h: real, insets: {left,right,top,bottom}) -> {x: real, y: real}`
  - `fromCenter(cx: real, cy: real, screenW: real, screenH: real, w: real, h: real, insets: {left,right,top,bottom}) -> {x: real, y: real}`
  - `clampOffset(dx: real, dy: real, baseX: real, baseY: real, w: real, h: real, screenW: real, screenH: real, insets: {left,right,top,bottom}) -> {dx: real, dy: real}`

- [ ] **Step 1: Write the failing Node test**

`shell/modules/background/ClockPosition.js` starts with `.pragma library` and
exposes top-level functions, following `shell/services/DisplayMath.js`.
`tests/clock_position_test.js` loads it with `fs` + `vm` (strip the pragma, run
in a context) and asserts:

```js
const ins = { left: 20, right: 30, top: 40, bottom: 50 };
assert(C.isAuto("auto-empty") === true);
assert(C.isAuto("auto-full") === true);
assert(C.isAuto("bottom-right") === false);
assertDeep(C.preset("bottom-right", 1920, 1080, 300, 200, ins), { x: 1590, y: 830 });
assertDeep(C.preset("top-left", 1920, 1080, 300, 200, ins), { x: 20, y: 40 });
assertDeep(C.preset("top-center", 1920, 1080, 300, 200, ins), { x: 810, y: 40 });
assertDeep(C.preset("middle-center", 1920, 1080, 300, 200, ins), { x: 810, y: 440 });
assertDeep(C.fromCenter(0, 0, 1920, 1080, 300, 200, ins), { x: 20, y: 40 });
assertDeep(C.fromCenter(1920, 1080, 1920, 1080, 300, 200, ins), { x: 1590, y: 830 });
assertDeep(C.clampOffset(9999, -999, 100, 100, 300, 200, 1920, 1080, ins), { dx: 1490, dy: -60 });
assertDeep(C.clampOffset(10, 20, 100, 100, 300, 200, 1920, 1080, ins), { dx: 10, dy: 20 });
```

The wrapper `tests/clock_position_test.sh` follows the existing node-suite
pattern (`tests/display_math_test.sh`): run `node`, count PASS/FAIL, exit
non-zero on failure. Add `test_suite "clock_position_test" "tests/clock_position_test.sh"` to `tests/run.sh`.

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/clock_position_test.sh`
Expected: FAIL, source file not found.

- [ ] **Step 3: Implement `ClockPosition.js`**

Use the formulas from the spec. Start the file with `.pragma library` and
declare the four functions at top level (no `module.exports`). `preset` maps
`top`/`middle`/`bottom` and `left`/`center`/`right` from the position key, with
centre positions ignoring insets and edge positions using the matching inset.
`fromCenter` clamps to `inset.left` / `screenW - inset.right - w` and the
vertical equivalent. `clampOffset` computes
`clampedX = min(max(baseX + dx, inset.left), screenW - inset.right - w)`
then returns `dx = clampedX - baseX`; do the same for y.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/clock_position_test.sh`
Expected: all assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/background/ClockPosition.js tests/clock_position_test.js tests/clock_position_test.sh
git add -p tests/run.sh   # only the clock_position_test line
git commit -m "feat(clock): add pure position math and tests"
```

---

### Task 3: Placement, animation, drag and wallpaper reset

**Files:**
- Modify: `shell/modules/background/Background.qml`

**Interfaces:**
- Consumes: `ClockPosition.isAuto`, `.preset`, `.fromCenter`, `.clampOffset`.
- Produces: `clockLoader` with:
  - `readonly property bool autoClockPlacement` (existing name)
  - `readonly property real baseX`, `baseY`
  - `readonly property bool placementSettled`

- [ ] **Step 1: Replace the anchor states with computed x/y**

Add `import "ClockPosition.js" as ClockPosition` to `Background.qml`, then
delete the `states` array and `transitions` block. Give `clockLoader`:

```qml
readonly property bool autoClockPlacement: ClockPosition.isAuto(Config.background.desktopClock.position)
readonly property var insets: ({ left: win.clockInsetL, right: win.clockInsetR, top: win.clockInsetT, bottom: win.clockInsetB })
readonly property var presetPos: autoClockPlacement ? ({ x: 0, y: 0 }) : ClockPosition.preset(Config.background.desktopClock.position, win.width, win.height, width, height, insets)
readonly property var autoPosResult: ClockPosition.fromCenter(autoPos.cx, autoPos.cy, win.width, win.height, width, height, insets)
readonly property real baseX: autoClockPlacement ? autoPosResult.x : presetPos.x
readonly property real baseY: autoClockPlacement ? autoPosResult.y : presetPos.y
x: baseX
y: baseY
```

Keep the existing `anchors` margins removed (no anchors). Keep the `Translate`
for `clockPos.dx/dy` applied in **all** modes.

- [ ] **Step 2: Add the animation, gated off during drag and first placement**

```qml
Behavior on x { enabled: Config.background.desktopClock.animatePosition && clockLoader.placementSettled && !dragArea.dragging; Anim { type: Anim.DefaultSpatial } }
Behavior on y { enabled: Config.background.desktopClock.animatePosition && clockLoader.placementSettled && !dragArea.dragging; Anim { type: Anim.DefaultSpatial } }
```

`placementSettled` starts false. For preset modes set it in
`Component.onCompleted` via `Qt.callLater`. For auto modes set it on the first
accepted analysis result. Also give `clockTrans` (`Translate`) `Behavior on x`
and `Behavior on y` with the same gate, so resetting a drag offset (wallpaper
change or double-click) animates instead of snapping.

- [ ] **Step 3: Make drag work in every mode and add double-click reset**

Rename the MouseArea to `dragArea`. Remove the `!win.autoClockPlacement`
visibility condition. Keep `onPressed` recording `grabDX/grabDY`. Set
`clockPos.custom = true` on the first `onPositionChanged` with `pressed` (not on
press), so a plain click does not persist a zero offset. In
`onPositionChanged`, clamp using
`ClockPosition.clampOffset(...)` with `baseX/baseY` and the insets, then write
`clockPos.dx/dy`. Add:

```qml
onDoubleClicked: {
    clockPos.custom = false;
    clockPos.dx = 0;
    clockPos.dy = 0;
    saveClockPos();
}
```

`onReleased` still saves. Ensure `acceptedButtons: Qt.LeftButton` and
`dragArea.dragging` is a bool property set true on press, false on release.

- [ ] **Step 4: Reset the offset on wallpaper change (auto modes only)**

Add a `Connections` on `Wallpapers` for `onActualCurrentChanged`. If
`win.autoClockPlacement`, clear `clockPos` and `saveClockPos()`. Keep the
existing `onPositionChanged` reset and also clear any deferred analysis.

- [ ] **Step 5: Debounce the analyser and defer results during drag**

Replace the direct `analysisProc.exec()` in `onClockAnalysisCmdChanged` with a
single-shot `Timer { id: analysisTimer; interval: 300 }`. On trigger:
- if `analysisProc.running`, set `analysisPending = true` and return;
- otherwise `analysisProc.exec(clockAnalysisCmd)`.

In `StdioCollector.onStreamFinished`, parse the result. If `dragArea.dragging`,
store it in `deferredAnalysis` and return; otherwise assign `autoPos.cx/cy`.
In `onReleased`, if `deferredAnalysis` exists, apply it and clear it.
In `Process.onExited`, if `analysisPending`, clear it and restart
`analysisTimer`. Set `placementSettled = true` on the first accepted result.
(Quickshell's `Process` exposes `onExited`, not `onFinished`.)

- [ ] **Step 6: Verify the scene loads and the position math is exercised**

Run: `bash tests/clock_position_test.sh` (still passes).
Then deploy this file only:

```bash
cp shell/modules/background/Background.qml ~/.config/quickshell/caelestia/modules/background/Background.qml
cp shell/modules/background/ClockPosition.js ~/.config/quickshell/caelestia/modules/background/ClockPosition.js
```

Restart the shell (`./restart.sh` or `qs -c caelestia` restart) and check the
log for `ClockPosition is not defined` or state/anchor errors. Expected: no QML
errors; clock appears at its preset.

- [ ] **Step 7: Commit**

```bash
git add shell/modules/background/Background.qml
git commit -m "feat(clock): animated placement, drag in all modes, wallpaper reset"
```

---

### Task 4: Digital clock extraction and style options

**Files:**
- Create: `shell/modules/background/DigitalClock.qml`
- Modify: `shell/modules/background/DesktopClock.qml`

**Interfaces:**
- Produces: `DigitalClock` with:
  - required `clockScale: real`
  - required `primaryColor`, `secondaryColor`, `tertiaryColor`, `textColor: color`
  - required `vertical: bool`
  - required `dateAlignment: int` (`Text.AlignLeft/Center/Right`)
  - readonly `contentWidth`, `contentHeight: real`

- [ ] **Step 1: Move the existing digital layout into `DigitalClock.qml`**

Move `layout` (RowLayout), `verticalLayout` (ColumnLayout), and their
`ClockText` children out of `DesktopClock.qml`. Root is an `Item` with
`contentWidth`/`contentHeight` taken from the visible layout and
`implicitWidth: contentWidth`, `implicitHeight: contentHeight`; both layouts
are centred in the root. Keep the exact fonts, margins, divider and date
column from today as the defaults.

- [ ] **Step 2: Add the font builder**

Add a JS function on the root:

```qml
function clockFont(pointSize, weight, spacing) {
    const f = Config.background.desktopClock.digital.font;
    let b = Tokens.font.clock.size(pointSize * clockScale * f.size);
    if (weight > 0)
        b = b.weight(weight);
    if (f.family.length > 0)
        b = b.family(f.family);
    return b.vaxes({ "wdth": f.width, "ROND": f.roundness }).letterSpacing(spacing).build();
}
```

Use `clockFont` for the time group only: hour, colon, minute, AM/PM, seconds.
Leave the date column's existing fonts and letter spacing untouched.
Apply `f.weight` to the hour and minute only; the colon and AM/PM keep their
current weights (the colon has no explicit weight, AM/PM uses default), so the
default 700 does not bold them and the default look is unchanged.

- [ ] **Step 3: Add the toggles**

- `showDate`: `visible` on the date column (horizontal) and date texts (vertical).
- `showSeconds`: a small `ClockText { text: Time.secondsStr }` after the minute,
  size = 0.35 × the minute size, hidden when false.
- `animateChange`: set `animate: Config...animateChange` on every `ClockText`.
- `orientation`: compute `vertical` in `DesktopClock` as
  `digital.orientation === "vertical" || (digital.orientation === "auto" && (position.endsWith("left") || position.endsWith("right")))`.
  The preset keys are `middle-left`, `bottom-right`, etc., so compare suffixes;
  a `=== "left"` check never matches.
- `adaptiveAlignment` and `dateAlignment`: when horizontal and adaptive, set the
  date `ColumnLayout.Layout.preferredWidth` to the time group's
  `implicitWidth` and apply `horizontalAlignment: dateAlignment` to its texts.
  When not adaptive, keep today's left-aligned date column (`Layout.preferredWidth: -1`).

- [ ] **Step 4: Wire `DesktopClock` to the extracted component**

Replace the inline horizontal/vertical blocks with a `DigitalClock` created by
a `Loader` (or direct child) whose `vertical`, colours and `dateAlignment` are
computed from config. `dateAlignment` uses `absX + width / 2` against
`wallpaper.width / 3` and `2 * wallpaper.width / 3`.

- [ ] **Step 5: Verify default appearance is unchanged**

Deploy `DesktopClock.qml` and `DigitalClock.qml`, restart, compare the digital
clock against the pre-change screenshot/log. Expected: identical typography,
time layout, colours, letter spacing and weights with defaults. The date column
width/alignment follows the clock's screen third while `adaptiveAlignment` is
on (the default); turn it off to compare the old left-aligned column.

- [ ] **Step 6: Exercise each new knob**

Temporarily set in `~/.config/caelestia/shell.json` or via the config:
`orientation: "vertical"`, then `"horizontal"`; `showDate: false`; `showSeconds:
true`; `animateChange: false`; `adaptiveAlignment: false`; `font.family:
"Google Sans Flex"`; `font.size: 1.5`; `font.weight: 350`; `font.width: 25`;
`font.roundness: 100`. Expected: each visibly changes the clock; no warnings
for a missing family.

- [ ] **Step 7: Commit**

```bash
git add shell/modules/background/DigitalClock.qml shell/modules/background/DesktopClock.qml
git commit -m "feat(clock): styleable digital clock"
```

---

### Task 5: Cookie face

**Files:**
- Create: `shell/modules/background/cookie/CookieFace.qml`
- Create: `shell/modules/background/cookie/SineCookie.qml`

**Interfaces:**
- `CookieFace`:
  - required `size: real`, `sides: int`, `sine: bool`, `constantlyRotate: bool`, `color: color`
  - readonly `faceSize: real` (= `size`)
- `SineCookie`: required `size: real`, `sides: real`, `color: color`, `constantlyRotate: bool`.

- [ ] **Step 1: Implement the M3Shapes cookie**

`CookieFace.qml` is an `Item` with `implicitWidth/Height: size`. Inside, an
`Item { id: face; anchors.fill: parent }` holds:

```qml
MaterialShape {
    anchors.fill: parent
    shape: MaterialShape.Custom
    customShape: MaterialShape.star(sides, 0.8, Math.min(0.08, 1.5 / Math.max(sides, 4)), 0)
    color: root.color
}
```

with `import M3Shapes`. Apply the shadow with `layer.enabled:
Config.background.desktopClock.shadow.enabled` and a `MultiEffect` using the
configured shadow colour/opacity/blur. Add
`RotationAnimation on rotation` with `running: constantlyRotate`, linear, 30 s,
`from: 360; to: 0; loops: Animation.Infinite`.

- [ ] **Step 2: Implement the sine outline**

`SineCookie.qml` ports end-4's `SineCookie`: a `Shape` with
`PathPolyline { path: pointsList }`, 360 points, `radius = size/2 - amplitude`,
`amplitude = size/50`, `rotatedAngle = angle * sides + Math.PI/2`. Give it the
same constant-rotation behavior. Use `preferredRendererType: Shape.CurveRenderer`.

- [ ] **Step 3: Select the outline**

`CookieFace` shows the M3 shape when `!sine` and the sine shape when `sine`.
Both share `size`, `color` and rotation. Expected: 14 sides looks like a
scalloped Android clock; 4 and 40 sides remain closed shapes.

- [ ] **Step 4: Verify extremes**

Deploy both files and a temporary test harness page (or set the live config)
with `cookie.sides = 4`, then `40`; toggle `useSineCookie`; toggle
`constantlyRotate`. Expected: no crash, no NaN geometry warnings, rotation
smooth. Turn rotation off afterwards.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/background/cookie/CookieFace.qml shell/modules/background/cookie/SineCookie.qml
git commit -m "feat(clock): cookie face with M3 and sine outlines"
```

---

### Task 6: Cookie dial, hands and centre digits

**Files:**
- Create: `shell/modules/background/cookie/CookieDial.qml`
- Create: `shell/modules/background/cookie/CookieHands.qml`
- Modify: `shell/modules/background/CookieClock.qml` (composition start)

**Interfaces:**
- `CookieDial`: required `size: real`, `dialStyle: string`, `hourMarks: bool`, `color: color`.
- `CookieHands`: required `size: real`, `hour: int`, `minute: int`, `second: int`,
  `hourStyle: string`, `minuteStyle: string`, `secondStyle: string`,
  `hourColor`, `minuteColor`, `secondColor: color`.
- `CookieClock` (partial): required `clockScale: real`, `primaryColor`,
  `secondaryColor`, `tertiaryColor`, `textColor: color`; readonly `contentWidth`,
  `contentHeight`.

- [ ] **Step 1: Implement `CookieDial`**

Scale every end-4 pixel value by `size / 230`. Use
`pragma ComponentBehavior: Bound` for the repeaters.

- `none`: nothing.
- `dots`: 12 dots, radius `size/2 - 46 * k`, dot size `12 * k`.
- `full`: 60 minute ticks (`2 × 7 * k`) plus 12 longer hour ticks
  (`4 × 18 * k`), both at `size/2 - 46 * k`.
- `numbers`: 3/6/9/12 numerals, `font { family: Tokens.font.clock.medium.family; pixelSize: 80 * k; weight: Font.Black }`.
- `hourMarks`: an inner ring of 12 marks, only when `dialStyle` is `dots` or
  `full`, at `size * 0.29` radius. Hidden otherwise regardless of the flag.

- [ ] **Step 2: Implement `CookieHands`**

Port the three hand geometries from end-4, scaled by `k = size / 230`:

- hour: rotation `-90 + 30 * (hour + minute / 60)`, length `72 * k`,
  width `20 * k`; `classic` → height 8, x offset -15; `fill` → rounded;
  `hollow` → transparent fill with 4 px border; `hide` → invisible.
- minute: rotation `-90 + 6 * minute`, length `95 * k`; widths `5/12/20 * k`
  for thin/medium/bold; `classic` → width 5 and x offset -15.
- second: rotation `-90 + 6 * second`; `line` → `95 * k × 2 * k`;
  `dot` → a `20 * k` dot at `10 * k` from the left; `classic` → line plus a
  `14 * k` mid dot; `hide` → invisible.
- Hour/minute `Behavior on rotation` uses a clockwise `RotationAnimation`,
  duration `Tokens.anim.durations.expressiveFastSpatial` (or ~300 ms),
  `Easing.BezierSpline` with the emphasized curve. Second hand animates only
  when `cookie.constantlyRotate` is true.
- Draw the centre dot per end-4: hidden for `bold` minute hand, face-coloured
  for `medium`, minute colour otherwise.

- [ ] **Step 3: Compose `CookieClock` face, dial, digits and hands**

Root `Item` with `faceSize = 230 * clockScale`. Colours:
`face = m3primaryContainer`, `onFace = m3onPrimaryContainer`, `hour = m3primary`,
`minute = m3tertiary`, `second = m3primary`, with the existing
`useLightSet` inversion logic. Layers: `CookieFace` → `CookieDial` →
centre digits → `CookieHands`.

Centre digits: `Column` with `Time.hourStr` and `Time.minuteStr` (and
`Time.amPmStr` when `useTwelveHourClock`), size `68 * k` / `26 * k`, hidden when
`!timeIndicators` or `dialNumberStyle === "numbers"`. Shrink to `40/20 * k`
when `hourMarks` is on.

- [ ] **Step 4: Verify dial and hands**

Deploy and temporarily set each dial style and each hand style. Expected:
- dots show 12 dots; full shows 60 ticks with 12 longer; numbers show 3/6/9/12.
- hidden hands disappear; hollow hour hand shows its outline.
- second hand ticks once per second with rotation off and sweeps smoothly with
  rotation on.
- centre digits hide for the numbers dial.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/background/cookie/CookieDial.qml shell/modules/background/cookie/CookieHands.qml shell/modules/background/CookieClock.qml
git commit -m "feat(clock): cookie dial, hands and centre digits"
```
---

### Task 7: Cookie date and clock integration

**Files:**
- Create: `shell/modules/background/cookie/CookieDate.qml`
- Modify: `shell/modules/background/CookieClock.qml` (finish composition)
- Modify: `shell/modules/background/DesktopClock.qml`

**Interfaces:**
- `CookieDate`: required `size: real`, `style: string`, `inClock: bool`,
  `primaryColor`, `secondaryColor`, `textColor: color`; readonly
  `dateHeight: real`.
- `CookieClock`: required `clockScale: real`, `primaryColor`,
  `secondaryColor`, `tertiaryColor`, `textColor: color`; readonly
  `contentWidth`, `contentHeight`.
- `DesktopClock` keeps its public `wallpaper`, `absX`, `absY` properties.

- [ ] **Step 1: Implement `CookieDate`**

- `bubble`: day `d` in a `MaterialShape.Cookie4Sided` at top-left, month `MM`
  in a `MaterialShape.Pill` at bottom-right; sizes `64 * k` and
  `40 * k`; colours `m3tertiaryContainer` / `m3secondaryContainer` with their
  on-colours.
- `rect`: day `dd` on a small rounded rect at the right side, `45 × 30 * k`,
  `m3secondaryContainer` background.
- `border`: the string `ddd dd` laid out character by character around the rim
  at radius `size * 0.39`, each rotated by `angle + 90`, rotating with
  `Time.seconds` (or static when the second hand is hidden).
- `hide`: nothing.
- `inClock: false`: none of the above inside the face; expose `dateHeight` for
  a below-face stack (`MMMM`, `dd`, `dddd`) using the current CookieClock date
  typography.

- [ ] **Step 2: Finish `CookieClock`**

Add the date layer and size the root:

```qml
implicitWidth: Math.max(faceSize, dateHeight > 0 ? dateColumn.implicitWidth : 0)
implicitHeight: faceSize + (inClock ? 0 : dateHeight + Tokens.spacing.large * clockScale)
```

Place the below-face date Column at `y: faceSize + spacing`, centred. Keep the
existing `Behavior on clockScale`. The rewritten `CookieClock` no longer needs
the old `wallpaper`/`absX`/`absY` required properties (the cookie draws no
wallpaper blur); drop them, or keep them optional if `DesktopClock` still
passes them.

- [ ] **Step 3: Dispatch styles in `DesktopClock.qml`**

Use three loaders or a `Loader` with `sourceComponent` chosen by
`clockStyle`:

- `digital` → `DigitalClock` (existing plate/blur/shadow behaviour).
- `cookie` → cookie clock. Hide the plate/blur; the cookie face is opaque.
  Cookie shadow is handled by `CookieFace`.
- `analog` → `AnalogClock` (unchanged geometry).

There is exactly one cookie implementation: `shell/modules/background/CookieClock.qml`
composes the pieces in `shell/modules/background/cookie/`. Do not create a
second wrapper file.

Compute `implicitWidth/Height` from the loaded item plus the existing padding.
Add a `Behavior on implicitHeight` alongside the existing width behavior.
Render `quote` below the clock body for every style: `ClockText`/`StyledText`,
body size, secondary colour (`safeSecondary`), wrap at the clock width, hidden
when `!quote.enabled || quote.text.length === 0`. Size the digital plate and blur
mask to the clock body only, not to the quote; the quote sits outside the plate.

- [ ] **Step 4: Verify the cookie clock end to end**

Toggle `clockStyle` between digital, cookie and analog. Expected:
- each style gets correct sizing, shadow, and no plate on cookie/analog;
- cookie date inside/outside works for bubble/rect/border/hide;
- quote appears below and wraps;
- switching styles does not break the placement box.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/background/cookie/CookieDate.qml shell/modules/background/CookieClock.qml shell/modules/background/DesktopClock.qml
git commit -m "feat(clock): cookie date and style dispatch"
```

---

### Task 8: Nexus clock settings

**Files:**
- Create: `shell/modules/nexus/pages/wallandstyle/ClockSettings.qml`
- Modify: `shell/modules/nexus/pages/WallpaperAndStyle.qml`
- Modify: `shell/modules/nexus/PageCompRegistry.qml`
- Create: `tests/clock_settings_test.sh`
- Modify: `tests/run.sh`

**Interfaces:**
- Consumes: all config from Task 1.
- Produces: sub-page index 4 in the Wallpaper & style stack.

- [ ] **Step 1: Add the Clock sub-page**

Create `ClockSettings.qml`:

```qml
PageBase {
    id: root
    title: qsTr("Clock")
    isSubPage: true
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2
        // rows...
    }
}
```

Rows in this order, all bound to
`GlobalConfig.background.desktopClock.*`:

`SliderRow` is normalised 0–1 (`value` is 0–1, `moved(value)` is 0–1). Convert
with these exact mappings:

| Row | value | onMoved |
|---|---|---|
| Scale | `(scale - 0.5) / 1.5` | `scale = 0.5 + v * 1.5` |
| Plate opacity | `opacity` | `opacity = v` |
| Shadow opacity | `opacity` | `opacity = v` |
| Text size | `(size - 0.5) / 1.5` | `size = 0.5 + v * 1.5` |
| Weight | `(weight - 1) / 999` | `weight = Math.round(1 + v * 999)` |
| Width | `(width - 25) / 100` | `width = Math.round(25 + v * 100)` |
| Roundness | `roundness / 100` | `roundness = Math.round(v * 100)` |

1. General: enabled toggle; style select (Digital / Cookie (Android) /
   Analog); scale slider (mapping above, label `×N.N`); animate position
   toggle; invert colours toggle; quote toggle + text field; hint text "Drag
   the clock to move it. Double-click it to reset."
2. Backdrop (visible for digital and cookie): plate toggle, opacity slider and
   blur toggle visible only for digital; shadow toggle, opacity slider and blur
   slider visible for digital and cookie.
3. Digital (visible for digital): orientation select (Auto/Horizontal/Vertical);
   show date, show seconds, animate time change, adaptive alignment toggles;
   font family `TextFieldRow`; weight slider; text size slider; width slider
   with variable-font subtext; roundness slider with variable-font subtext.
4. Cookie (visible for cookie): sine-cookie toggle; sides `StepperRow` 4–40;
   constant-rotation toggle with expense subtext; date-in-clock toggle; hour
   marks toggle `enabled: dial === "dots" || dial === "full"`; centre digits
   toggle `enabled: dial !== "numbers"`; dial style select (None/Dots/Full/
   Numbers); hour hand select (Classic/Fill/Hollow/Hide); minute hand select
   (Classic/Thin/Medium/Bold/Hide); second hand select (Classic/Line/Dot/Hide);
   date style select (Bubble/Border/Rect/Hide).
5. Analog: one explanatory `StyledText`; no knobs.

On dial selection, enforce the same dependencies end-4 does: selecting numbers
sets `timeIndicators = false`; selecting anything other than dots/full sets
`hourMarks = false`.

- [ ] **Step 2: Register sub-page 4**

In `PageCompRegistry.qml`'s Wallpaper & style `StackPage`, add
`Component { ClockSettings {} }` after `ColourSelect` (index 4). The existing
`import qs.modules.nexus.pages.wallandstyle` resolves the file.

- [ ] **Step 3: Compact the main Wallpaper & style clock section**

Replace the current "Clock style" and "Clock position" rows with:

1. `ToggleRow` — Desktop clock (`enabled`), first.
2. `SelectRow` — Position, same 11 menu items and `positionKeys` mapping.
3. `NavRow` — "Clock appearance", status = style label, `onClicked:
   root.nState.openSubPage(4)`, last.

Keep the existing `root.positionKeys` property.

- [ ] **Step 4: Add the config-completeness test**

`tests/clock_settings_test.sh` hardcodes the spec's key list and greps
`ClockSettings.qml` for each `desktopClock.<key>` (including nested
`digital.font.`, `cookie.` etc.). It fails with the missing key name. Add it to
`tests/run.sh`.

- [ ] **Step 5: Run the automated suites**

Run: `bash tests/clock_position_test.sh && bash tests/clock_settings_test.sh && bash tests/qml_test.sh && bash tests/run.sh`
Expected: PASS. `qml_test` must resolve the new imports (including `M3Shapes`
and `qs.modules.nexus.pages.wallandstyle`).

- [ ] **Step 6: Verify navigation and persistence**

Deploy the Nexus files, open Nexus → Wallpaper & style → Clock appearance.
Expected: sub-page opens, back button returns, every row changes the live clock
immediately, values survive a shell restart.

- [ ] **Step 7: Commit**

```bash
git add shell/modules/nexus/pages/wallandstyle/ClockSettings.qml shell/modules/nexus/pages/WallpaperAndStyle.qml shell/modules/nexus/PageCompRegistry.qml tests/clock_settings_test.sh
git add -p tests/run.sh   # only the clock_settings_test line
git commit -m "feat(clock): Nexus clock settings page"
```

---

### Task 9: Full verification and deployment

**Files:**
- Modify (if needed): `shell/README.md`, `docs/superpowers/specs/2026-10-21-desktop-clock-controls-design.md`
- Deploy: changed QML + plugin to `~/.config/quickshell/caelestia/`

- [ ] **Step 1: Run the complete automated suite**

Run: `bash tests/run.sh`
Expected: every suite passes, including `clock_position_test` and
`clock_settings_test`.

- [ ] **Step 2: Build and install the plugin**

Run: `./build-plugin.sh`
Expected: plugin builds and installs. If install needs sudo, run it
interactively; do not skip the build.

- [ ] **Step 3: Deploy the changed QML**

Copy every changed/new file under `shell/modules/background/`,
`shell/modules/nexus/`, and the new `ClockPosition.js` into the matching paths
under `~/.config/quickshell/caelestia/`. Preserve user files elsewhere.

- [ ] **Step 4: Run the manual checklist**

1. `auto-empty` + wallpaper change → clock animates to the empty area.
2. Drag in `auto-empty` → follows cursor exactly; release persists; restart
   restores the offset.
3. Drag, then change wallpaper → offset clears and the clock repositions.
4. Change wallpaper while a preset is selected → clock and offset unchanged
   (**Review Focus 1**).
5. Start a drag while analysis is running → result must not move the clock until
   release (**Review Focus 2**).
6. Double-click after a drag → returns to base position; restart shows no offset
   (**Review Focus 3**).
7. Preset → preset, preset → auto, auto → preset animate; `animatePosition` off
   jumps.
8. Cookie: every dial, hand, date style; sides 4 and 40; sine on; rotation on,
   then off (**Review Focus 4**).
9. Digital: each toggle, font family, size, weight, width, roundness; a
   nonexistent family and Rubik width/roundness still render (**Review Focus 5**).
10. Multi-monitor: drag offsets per screen; settings global.
11. No QML warnings on startup; clean restart.

- [ ] **Step 5: Update docs**

If implementation diverged from the spec, update the spec's decisions section
and the plan's notes. Add a line to `shell/README.md` for the new options if any
were renamed. No need to document internal cookie files.

- [ ] **Step 6: Commit**

```bash
git add shell/README.md docs/superpowers/specs/2026-10-21-desktop-clock-controls-design.md
git commit -m "docs(clock): finalize desktop clock controls"
```
