# Widget Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dock a list of registry-driven widgets hosted by a generic widget host, with no visible change.

**Architecture:** A pure-JS registry owns widget metadata, validation and migration. A QML singleton maps registry ids to components. `WidgetFrame` creates one widget and injects `item`/`host`/`orientation`; `WidgetHost` lays frames out in a `ColumnLayout` and answers hit-tests. `Bar.qml` keeps its popout, tray and wheel behaviour but reads frames instead of hardcoded loaders.

**Tech Stack:** QML / Qt 6 / Quickshell (`ScriptModel`, `Singleton`), pure JS with `.pragma library`, node tests wrapped by bash, `qmllint`, `install.sh --update`.

**Spec:** `docs/superpowers/specs/2026-11-18-widget-surfaces-design.md`

## Global Constraints

- No C++ changes. `shell/plugin/` is untouched; no plugin rebuild needed.
- Never add `pragma ComponentBehavior: Bound` to `Bar.qml`, `WidgetHost.qml`, `WidgetFrame.qml`, `WidgetCatalog.qml`.
- `Repeater` must never take a JS array directly; use `ScriptModel { values: ... }`.
- Registry JS is `.pragma library`, top-level `function` declarations and `var` bindings (never `const`/`let` — the node harness reads them off the vm context), no `import`/`export`, no QML types.
- Spacing between dock widgets is `Tokens.spacing.medium`; no literal pixel values outside `Tokens`.
- `shell/` is the source of truth. Deploy with `./install.sh --update`; never hand-edit `~/.config/quickshell/caelestia/` in this plan.
- Every new suite is registered in `tests/run.sh` and passes under `bash tests/run.sh`.
- Bar visual parity is verified on `positioningEdge: 0` (left), the configured edge.

## Review Focus

These are the inputs and failures that no single widget test covers. Each has a test in the task named.

1. A saved entry naming a widget id that no longer exists: the item is skipped, the rest render, an error is recorded. (Task 1)
2. The same singleton widget listed twice: the first wins, the duplicate is dropped. (Task 1)
3. A region whose items are all filtered out: the host's height is 0 and the bar thickness is unchanged. (Task 3, Task 4)
4. The default `Config.bar.entries` still containing `spacer` and `activeWindow`: migration yields exactly 2 / 1 / 4 items and no spacers. (Task 1)
5. A widget that throws on creation or a catalog id with no component: the frame shows a placeholder, siblings survive. (Task 2, Task 3)

---

### Task 1: Widget registry

**Files:**
- Create: `shell/modules/widgets/WidgetRegistry.js`
- Create: `tests/widget_registry_test.js`
- Create: `tests/widget_registry_test.sh`
- Modify: `tests/run.sh` (add `test_suite "widget_registry_test" "tests/widget_registry_test.sh"` before the summary)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `registry() -> Array<meta>` where `meta = {id, name, description, icon, category: "widget"|"helper", role: "structure"|"decoration"|null, singleton: bool, defaultOptions: object, allowHelpers: bool, compositeOf: string[], wantsFocus: bool, ownsPopover: bool, minSize: {width, height}}`
  - `get(type: string) -> meta|null`
  - `fromBarEntries(entries: Array|undefined, region: "start"|"center"|"end") -> Array<item>`
  - `normalizeItem(raw: object) -> item` where `item = {type, instance, enabled, options, children}`
  - `validateItems(items: Array|null, opts?: object) -> {ok: bool, errors: string[], items: Array<item>}`
  - `visibleItems(items: Array|null) -> Array<item>`
  - `nextInstanceId(type: string, items: Array) -> string`
  - `var MAX_DEPTH = 4;` (a `var`, so the node harness can read `ctx.MAX_DEPTH`)

Registry contents (ids are the contract; keep them exactly these strings):

| id | category | singleton | notes |
|---|---|---|---|
| `logo` | widget | yes | |
| `workspaces` | widget | yes | |
| `activeWindow` | widget | yes | center region only |
| `tray` | widget | yes | `compositeOf: []` |
| `clock` | widget | yes | |
| `statusIcons` | widget | yes | `compositeOf: ["battery","network","audio","bluetooth","kbLayout","lockStatus","microphone"]` |
| `power` | widget | yes | |
| `spacer` | helper | no | options: `{size: number}` (flex fill lands with the flat-dock plan) |
| `separator` | helper | no | |
| `group` | helper | no | `allowHelpers: true` |

Region map used by `fromBarEntries`: `start = ["logo","workspaces"]`, `center = ["activeWindow"]`, `end = ["tray","clock","statusIcons","power"]`. `spacer` belongs to no region and is dropped. Unknown ids are dropped. `enabled` is preserved as-is. Instances are `type` for the first occurrence and `type-N` (N starting at 2) after. The `activeWindow` item carries `options.fillWidth: true` (it is the one dock widget that fills the column width).

Capabilities — these land now because they are the contract and later plans consume them:

| id | `role` | `ownsPopover` | `wantsFocus` | `minSize` |
|---|---|---|---|---|
| `logo` | null | false | false | `{0, 0}` |
| `workspaces` | null | true (`workspacepreview`) | false | `{0, 0}` |
| `activeWindow` | null | true (`activewindow`) | false | `{0, 0}` |
| `tray` | null | true (`traymenu`) | false | `{0, 0}` |
| `clock` | null | false | false | `{0, 0}` |
| `statusIcons` | null | true (per icon) | false | `{0, 0}` |
| `power` | null | true (session) | false | `{0, 0}` |
| `spacer` | `"structure"` | false | false | `{0, 0}` |
| `separator` | `"decoration"` | false | false | `{0, 0}` |
| `group` | `"structure"` | false | false | `{0, 0}` |

`validateItems` must not reject unknown *metadata* fields; the capability values are inert in this plan and consumed by the popover broker and focus rules later.

- [ ] **Step 1: Write the failing test**

```js
// tests/widget_registry_test.js
const fs = require("fs");
const vm = require("vm");

function assert(cond, msg) {
  if (!cond) throw new Error("FAIL: " + msg);
  console.log("  ok " + msg);
}

const ctx = { console };
vm.createContext(ctx);
vm.runInContext(
  fs.readFileSync(__dirname + "/../shell/modules/widgets/WidgetRegistry.js", "utf8").replace(/^\.pragma library\s*$/m, ""),
  ctx,
);

const ids = ctx.registry().map(w => w.id);
for (const id of ["logo", "workspaces", "activeWindow", "tray", "clock", "statusIcons", "power", "spacer", "separator", "group"])
  assert(ids.includes(id), `registry has ${id}`);
assert(ctx.registry().filter(w => w.category === "helper").length === 3, "exactly three helpers");
assert(ctx.get("clock").category === "widget", "clock is a widget");
assert(ctx.get("spacer").category === "helper", "spacer is a helper");
assert(ctx.get("group").allowHelpers === true, "group accepts children");
assert(ctx.get("statusIcons").compositeOf.includes("battery"), "statusIcons declares its leaves");
assert(ctx.get("nope") === null, "unknown id returns null");

// Helper roles and capabilities: the contract later plans rely on.
assert(ctx.get("spacer").role === "structure", "spacer is a structural helper");
assert(ctx.get("separator").role === "decoration", "separator is a decoration helper");
assert(ctx.get("group").role === "structure", "group is a structural helper");
assert(ctx.get("clock").role === null, "widgets have no helper role");
for (const w of ctx.registry()) {
  assert(typeof w.wantsFocus === "boolean", `${w.id} declares wantsFocus`);
  assert(typeof w.ownsPopover === "boolean", `${w.id} declares ownsPopover`);
  assert(Number.isFinite(w.minSize.width) && Number.isFinite(w.minSize.height), `${w.id} declares minSize`);
}
assert(ctx.registry().every(w => w.wantsFocus === false), "no dock widget requests focus");
assert(
  ctx.registry().filter(w => w.ownsPopover).map(w => w.id).sort().join(",") === "activeWindow,power,statusIcons,tray,workspaces",
  "popover owners are exactly the widgets that raise a popout today",
);

// Migration from Config.bar.entries. This is the shipped default list.
const entries = [
  { id: "logo", enabled: true }, { id: "workspaces", enabled: true },
  { id: "spacer", enabled: true }, { id: "activeWindow", enabled: true },
  { id: "spacer", enabled: true }, { id: "tray", enabled: true },
  { id: "clock", enabled: true }, { id: "statusIcons", enabled: true },
  { id: "power", enabled: true },
];
assert(ctx.fromBarEntries(entries, "start").map(i => i.type).join(",") === "logo,workspaces", "start keeps logo+workspaces");
assert(ctx.fromBarEntries(entries, "center").map(i => i.type).join(",") === "activeWindow", "center keeps activeWindow");
assert(ctx.fromBarEntries(entries, "end").map(i => i.type).join(",") === "tray,clock,statusIcons,power", "end keeps four widgets in order");
assert(ctx.fromBarEntries(entries, "end").every(i => i.type !== "spacer"), "spacers are not migrated");
assert(ctx.fromBarEntries([{ id: "nope" }, { id: "clock" }], "end").map(i => i.type).join(",") === "clock", "unknown entry skipped");
assert(ctx.fromBarEntries([{ id: "clock", enabled: false }], "end")[0].enabled === false, "enabled flag preserved");
assert(ctx.fromBarEntries([{ id: "clock" }, { id: "clock" }], "end").map(i => i.instance).join(",") === "clock,clock-2", "duplicate entries get unique instances");
assert(ctx.fromBarEntries(undefined, "end").length === 0, "missing entries -> empty list");

// Validation
const v = ctx.validateItems([{ type: "clock" }, { type: "nope" }, { type: "clock" }], {});
assert(v.ok === false, "invalid layout is not ok");
assert(v.items.length === 1 && v.items[0].type === "clock", "unknown and duplicate dropped");
assert(v.errors.some(e => e.includes("nope")), "error names the unknown type");
assert(v.errors.some(e => /duplicate/i.test(e)), "error mentions the duplicate");
assert(ctx.validateItems(null).items.length === 0, "null input -> no items");
assert(ctx.validateItems([]).ok === true, "empty layout is valid");
assert(ctx.visibleItems([{ type: "clock" }, { type: "nope" }, { type: "tray" }]).map(i => i.type).join(",") === "clock,tray", "visibleItems drops unknown");

const group = n => n === 0 ? { type: "group", children: [] } : { type: "group", children: [group(n - 1)] };
assert(ctx.validateItems([group(ctx.MAX_DEPTH)]).ok === true, "nesting at MAX_DEPTH is accepted");
assert(ctx.validateItems([group(ctx.MAX_DEPTH + 1)]).ok === false, "nesting past MAX_DEPTH is rejected");
assert(ctx.validateItems([group(ctx.MAX_DEPTH + 1)]).errors.some(e => /depth/i.test(e)), "depth error is reported");

// Defaults and ids
assert(ctx.nextInstanceId("clock", []) === "clock", "first instance is the type");
assert(ctx.nextInstanceId("clock", [{ instance: "clock" }]) === "clock-2", "second instance gets -2");
assert(ctx.nextInstanceId("clock", [{ instance: "clock" }, { instance: "clock-2" }]) === "clock-3", "third instance gets -3");
assert(ctx.normalizeItem({ type: "clock" }).instance === "clock", "normalize fills the instance");
assert(ctx.normalizeItem({ type: "clock", enabled: false }).enabled === false, "normalize keeps enabled");
```

```bash
# tests/widget_registry_test.sh
#!/usr/bin/env bash
set -euo pipefail
exec node "$(dirname "${BASH_SOURCE[0]}")/widget_registry_test.js"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/widget_registry_test.sh`
Expected: FAIL — `ENOENT ... shell/modules/widgets/WidgetRegistry.js`.

- [ ] **Step 3: Implement `shell/modules/widgets/WidgetRegistry.js`**

`.pragma library` header, the metadata table from the table above, and the eight functions. Rules the tests pin:

- `normalizeItem` returns `options` merged under `meta.defaultOptions` (`Object.assign({}, defaults, raw.options)`), `children` normalized recursively, and falls back to `nextInstanceId`.
- `validateItems` walks `items` in order. On each: unknown type → error `unknown widget "<type>"`, drop; duplicate `instance` → error `duplicate instance "<instance>"`; enabled duplicate of a `singleton` type → error `duplicate singleton "<type>"`, drop; `children` on a meta without `allowHelpers` → error, children dropped; recursion depth `> MAX_DEPTH` (top-level items are depth 0) → error naming the path, subtree dropped. Returns `ok: errors.length === 0`.
- `validateItems` accepts `opts.region` but does not filter by it (regions are a dock concern, handled by `fromBarEntries`).
- `visibleItems` = `validateItems(items).items.filter(i => i.enabled)`.
- `nextInstanceId(type, items)` returns `type` if unused, else the first unused `type-N` with N from 2.
- Every meta carries all fields from the interface block, even when inert: `role: null` for widgets, `wantsFocus: false`, `ownsPopover: false`, `minSize: { width: 0, height: 0 }` unless the capability table says otherwise.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/widget_registry_test.sh`
Expected: every `ok` line, exit 0.

- [ ] **Step 5: Register the suite and run the full runner**

Add the `test_suite "widget_registry_test" "tests/widget_registry_test.sh"` line, then run `bash tests/run.sh`.
Expected: `widget_registry_test` PASS and no other suite regressed.

- [ ] **Step 6: Commit**

```bash
git add shell/modules/widgets/WidgetRegistry.js tests/widget_registry_test.js tests/widget_registry_test.sh tests/run.sh
git commit -m "feat(widgets): add pure widget registry with validation and bar migration"
```

---

### Task 2: Widget catalog, dock adapters and helpers

**Files:**
- Create: `shell/modules/widgets/WidgetCatalog.qml`
- Create: `shell/modules/widgets/builtin/DockLogo.qml`, `DockWorkspaces.qml`, `DockActiveWindow.qml`, `DockTray.qml`, `DockClock.qml`, `DockStatusIcons.qml`, `DockPower.qml`
- Create: `shell/modules/widgets/helpers/Spacer.qml`, `Separator.qml`, `Group.qml`
- Modify: `tests/widget_registry_test.js` (append the catalog section)

**Interfaces:**
- Consumes: `WidgetRegistry.registry()`, `WidgetRegistry.get()`.
- Produces:
  - `WidgetCatalog` singleton: `readonly property list<var> catalog`, `meta(type) -> meta|null`, `componentFor(type: string) -> Component|null`
  - Widget contract, declared on every widget root: `property var item`, `property var host`, `property string orientation`

`WidgetCatalog.componentFor` is a `switch` over the ten ids returning `Component` blocks that instantiate the builtin adapters and helpers; `default: return null`.

Adapter wiring (each file's root is the real widget type, so `frame.widgetItem` exposes the properties `Bar.qml` already reads):

```qml
// builtin/DockWorkspaces.qml
import QtQuick
import qs.modules.bar.components.workspaces
Workspaces {
    property var item
    property var host
    property string orientation: "vertical"

    screen: host.screen
    fullscreen: host.fullscreen
    bar: host
}
```

| adapter | root type | extra bindings |
|---|---|---|
| `DockLogo` | `OsIcon` | none |
| `DockWorkspaces` | `Workspaces` | `screen: host.screen`, `fullscreen: host.fullscreen`, `bar: host` |
| `DockActiveWindow` | `ActiveWindow` | `bar: host`, `monitor: Brightness.getMonitorForScreen(host.screen)`, `maxHeight: host.activeWindowMaxHeight` |
| `DockTray` | `Tray` | none |
| `DockClock` | `Clock` | none |
| `DockStatusIcons` | `StatusIcons` | none |
| `DockPower` | `Power` | `visibilities: host.visibilities` |

`host` is the `Bar` instance, so `host.screen`, `host.fullscreen`, `host.visibilities`, `host.activeWindowMaxHeight` are the same values `Bar.qml` passes today. Import paths: `qs.modules.bar.components`, `qs.modules.bar.components.workspaces`, `qs.services` (for `Brightness`).

Helpers:

```qml
// helpers/Spacer.qml
import QtQuick
import Caelestia.Config
Item {
    id: root
    property var item
    property var host
    property string orientation: "vertical"

    readonly property int size: item?.options?.size ?? Tokens.spacing.medium

    implicitWidth: size
    implicitHeight: size
}
```

`Separator` is a `StyledRect`: 1px thin, half the dock inner width long, `color: Colours.palette.m3outlineVariant`, axis chosen by `orientation`. `Group` is a `StyledRect` with `readonly property int padding: Tokens.padding.small`, containing a `WidgetHost` imported relatively (`import ".." as Widgets`, then `Widgets.WidgetHost`), `items: root.item?.children ?? []`, `hostContext: root.host`, centered; `options.background === false` makes it transparent. `DockActiveWindow` needs `import QtQuick.Layouts` for its `Layout.fillWidth`.

- [ ] **Step 1: Write the failing catalog test**

Append to `tests/widget_registry_test.js`:

```js
// Catalog coverage: every registry id must be reachable in QML.
const catalog = fs.readFileSync(__dirname + "/../shell/modules/widgets/WidgetCatalog.qml", "utf8");
for (const w of ctx.registry())
  assert(new RegExp(`case "${w.id}":`).test(catalog), `catalog maps ${w.id}`);
assert(/default:\s*return null/.test(catalog), "catalog returns null for unknown types");
for (const f of ["Spacer", "Separator", "Group"])
  assert(fs.existsSync(__dirname + `/../shell/modules/widgets/helpers/${f}.qml`), `${f} helper exists`);
for (const f of ["DockLogo", "DockWorkspaces", "DockActiveWindow", "DockTray", "DockClock", "DockStatusIcons", "DockPower"])
  assert(fs.existsSync(__dirname + `/../shell/modules/widgets/builtin/${f}.qml`), `${f} adapter exists`);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/widget_registry_test.sh`
Expected: FAIL — `ENOENT ... WidgetCatalog.qml`.

- [ ] **Step 3: Implement the catalog, adapters and helpers**

`WidgetCatalog.qml` starts with `pragma Singleton`, imports `QtQuick`, `Quickshell`, `"WidgetRegistry.js" as Registry`, `"builtin"` and `"helpers"`, and has root `Singleton { readonly property list<var> catalog: Registry.registry(); function meta(type) {...}; function componentFor(type: string): Component {...} }` with one `Component { id: ...Comp; <Type> {} }` per id.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/widget_registry_test.sh`
Expected: PASS, exit 0.

- [ ] **Step 5: Syntax check the new QML**

Run: `qmllint shell/modules/widgets/WidgetCatalog.qml shell/modules/widgets/builtin/*.qml shell/modules/widgets/helpers/*.qml 2>&1 | grep -i "syntax error"`
Expected: no output. Unresolved-import warnings are expected here (the `qs.*` and `Caelestia.*` modules are resolved by Quickshell, not qmllint) and are not a failure.

- [ ] **Step 6: Commit**

```bash
git add shell/modules/widgets tests/widget_registry_test.js
git commit -m "feat(widgets): add catalog, dock adapters and layout helpers"
```

---

### Task 3: Widget frame and host

**Files:**
- Create: `shell/modules/widgets/WidgetFrame.qml`
- Create: `shell/modules/widgets/WidgetHost.qml`
- Modify: `tests/widget_test.sh` (add a widget-host section; leave existing sections alone in this task)

**Interfaces:**
- Consumes: `WidgetCatalog.componentFor`, `WidgetRegistry.validateItems`.
- Produces:
  - `WidgetFrame`: `required property var item`, `required property var hostContext`, `property string orientation`, `readonly property string entryId`, `readonly property alias widgetItem`, `property string errorText`
  - `WidgetHost` (root `ColumnLayout`): `required property var items`, `property var hostContext`, `property string orientation`, `readonly property var frames`, `function hitTest(x: real, y: real): var`, `function frameFor(type: string): var`

`WidgetFrame` creates its widget in `Component.onCompleted` via `comp.createObject(root, { item: item, host: hostContext, orientation: orientation })` inside `try`/`catch`. Unknown `type` or a thrown error sets `errorText` and shows a `Text` with `Colours.palette.m3error`; `implicitWidth`/`implicitHeight` fall back to the error label. It sets `Layout.alignment: orientation === "vertical" ? Qt.AlignHCenter : Qt.AlignVCenter` and `Layout.fillWidth: item.options?.fillWidth ?? false` — fill is a frame property because the widget itself is not a direct child of the layout. When `fillWidth` is set, a `Binding { target: widgetItem; property: "width"; value: root.width; when: widgetItem !== null && (root.item.options?.fillWidth ?? false) }` stretches the widget into the frame.

`WidgetHost` builds `Repeater { model: ScriptModel { values: Registry.validateItems(root.items).items } }` with `WidgetFrame` delegates carrying `required property var modelData`. It does not assign `implicitWidth`/`implicitHeight` (the layout computes them), and `hitTest` returns `childAt(x, y)`.

- [ ] **Step 1: Write the failing structural test**

Append to `tests/widget_test.sh`:

```bash
# ── 8. Widget host/frame contract ────────────────────────────────────────────
WIDGETS_DIR="$SHELL_DIR/modules/widgets"

[[ -f "$WIDGETS_DIR/WidgetHost.qml" ]] && pass "WidgetHost.qml exists" || fail "WidgetHost.qml missing"
[[ -f "$WIDGETS_DIR/WidgetFrame.qml" ]] && pass "WidgetFrame.qml exists" || fail "WidgetFrame.qml missing"

grep -q '^ColumnLayout' "$WIDGETS_DIR/WidgetHost.qml" && pass "WidgetHost root is ColumnLayout" || fail "WidgetHost root is not ColumnLayout"
grep -q 'ScriptModel' "$WIDGETS_DIR/WidgetHost.qml" && pass "WidgetHost uses ScriptModel" || fail "WidgetHost does not use ScriptModel"
grep -q 'ComponentBehavior: Bound' "$WIDGETS_DIR/WidgetHost.qml" && fail "WidgetHost must not use ComponentBehavior: Bound" || pass "WidgetHost is unbound"
grep -qE '^\s*implicit(Width|Height)\s*:' "$WIDGETS_DIR/WidgetHost.qml" && fail "WidgetHost must size itself from the layout" || pass "WidgetHost takes implicit size from the layout"
grep -q 'function hitTest' "$WIDGETS_DIR/WidgetHost.qml" && pass "WidgetHost exposes hitTest" || fail "WidgetHost missing hitTest"

grep -q 'createObject' "$WIDGETS_DIR/WidgetFrame.qml" && pass "WidgetFrame creates the widget with initial properties" || fail "WidgetFrame missing createObject"
grep -q 'errorText' "$WIDGETS_DIR/WidgetFrame.qml" && pass "WidgetFrame reports widget failures" || fail "WidgetFrame missing errorText"
grep -q 'entryId' "$WIDGETS_DIR/WidgetFrame.qml" && pass "WidgetFrame exposes entryId" || fail "WidgetFrame missing entryId"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/widget_test.sh`
Expected: FAIL lines for the missing files, existing sections still PASS.

- [ ] **Step 3: Implement `WidgetFrame.qml` and `WidgetHost.qml`**

Per the Interfaces block. `WidgetHost` imports `QtQuick`, `QtQuick.Layouts`, `Quickshell`, `Caelestia.Config` and `"WidgetRegistry.js" as Registry`.

- [ ] **Step 4: Run it to verify it passes**

Run: `bash tests/widget_test.sh`
Expected: all PASS, exit 0.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/widgets/WidgetFrame.qml shell/modules/widgets/WidgetHost.qml tests/widget_test.sh
git commit -m "feat(widgets): add widget frame and column host"
```

---

### Task 4: Move the dock onto the host

**Files:**
- Modify: `shell/modules/bar/Bar.qml` (replace regions, loaders and entry arrays)
- Modify: `tests/widget_test.sh` (rewrite sections 1 and 4 for the new structure)
- Modify: `AGENTS.md` ("Bar Rendering" section)

**Interfaces:**
- Consumes: `WidgetHost`, `WidgetFrame.entryId`, `WidgetRegistry.fromBarEntries`.
- Produces: `Bar.qml` properties `readonly property var startItems`, `centerItems`, `endItems`, `readonly property int activeWindowMaxHeight`.

`Bar.qml` changes, in order:

1. Imports: drop `"components"` and `"components/workspaces"`, add `import qs.modules.widgets` and `import "../widgets/WidgetRegistry.js" as Registry`.
2. Delete `topEntries`, `bottomEntries`, the six `Component` blocks, `TopLoader` and `BottomLoader`.
3. Add `readonly property var startItems: Registry.fromBarEntries(Config.bar.entries, "start")` and the `centerItems`/`endItems` equivalents.
4. The three `ColumnLayout`s become `WidgetHost` instances: `startHost` (top anchored, like today's `topLayout`), `endHost` (bottom anchored, like today's `bottomLayout`), and `centerHost` inside a wrapper `Item { id: centerWrapper }` anchored `top: startHost.bottom; bottom: endHost.top`, with the host vertically centered and `width: root.width`.
5. `readonly property int activeWindowMaxHeight: Math.max(0, centerWrapper.height - root.vPadding * 2)`.
6. `findEntry(pos)` maps `pos` into each host and returns `host.hitTest(host.width / 2, p.y)`, checking `centerHost`, then `startHost`, then `endHost`; return `null` when nothing matches.
7. `closeTray()` iterates `startHost.frames` and `endHost.frames`, filters `entryId === "tray"`, and sets `frame.widgetItem.expanded = false`.
8. `checkPopout(pos)` uses the frame: `entryId` for branching, `frame.widgetItem` where it used `trayItem`, `statusIconsItem`, `activeWindowItem` (the tray's `layout`, `items`, `expandIcon`, `padding`, `spacing`, and the status icons' `items` all live on those roots).
9. `handleWheel` is unchanged apart from reading `entryId` from the frame.

Do not add new `entryId` branches in this task. The existing `tray`, `statusIcons`, `workspaces` and `activeWindow` branches stay exactly as they are because the popover broker does not exist yet; the registry's `ownsPopover` marks them as the broker's future work. Any *new* behaviour must key off registry metadata instead.

- [ ] **Step 1: Rewrite the structural assertions to the new shape**

In `tests/widget_test.sh`, replace section 1 and the section-4 entry map with:

```bash
grep -q 'WidgetHost' "$BAR_QML" && pass "Bar.qml hosts widgets" || fail "Bar.qml does not use WidgetHost"
grep -q 'startHost' "$BAR_QML" && pass "Bar.qml has startHost" || fail "Bar.qml missing startHost"
grep -q 'centerHost' "$BAR_QML" && pass "Bar.qml has centerHost" || fail "Bar.qml missing centerHost"
grep -q 'endHost' "$BAR_QML" && pass "Bar.qml has endHost" || fail "Bar.qml missing endHost"
grep -q 'TopLoader\|BottomLoader' "$BAR_QML" && fail "Bar.qml still has its old loaders" || pass "Bar.qml has no old loaders"
grep -q 'topEntries\|bottomEntries' "$BAR_QML" && fail "Bar.qml still hardcodes entry lists" || pass "Bar.qml has no hardcoded entry lists"
grep -q 'fromBarEntries' "$BAR_QML" && pass "Bar.qml migrates Config.bar.entries" || fail "Bar.qml does not migrate entries"
grep -q 'closeTray' "$BAR_QML" && pass "Bar.qml keeps tray handling" || fail "Bar.qml lost tray handling"
grep -q 'handleWheel' "$BAR_QML" && pass "Bar.qml keeps wheel actions" || fail "Bar.qml lost wheel actions"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/widget_test.sh`
Expected: FAIL on the new `startHost`/`fromBarEntries` assertions.

- [ ] **Step 3: Rewrite `Bar.qml`**

Per the nine changes above. Keep `pragma ComponentBehavior: Bound` out of the file.

- [ ] **Step 4: Run the automated suite**

Run: `bash tests/run.sh`
Expected: `widget_test` and `widget_registry_test` PASS, overall `0 failed`.

- [ ] **Step 5: Syntax check**

Run: `qmllint shell/modules/bar/Bar.qml shell/modules/widgets/*.qml 2>&1 | grep -i "syntax error"`
Expected: no output.

- [ ] **Step 6: Deploy and verify parity by hand**

Run: `./install.sh --update`
Expected: shell/ copied into `~/.config/quickshell/caelestia/`, Quickshell reloads.

Then verify on the running shell (`qs -c caelestia`), on the left edge:

- Top of the dock: OS logo, then workspaces; spacing unchanged.
- Middle: active window title, still vertically centred and clipped.
- Bottom: tray, clock, status icons, power, in that order.
- Hover the tray icon: popout appears after the usual delay; compact tray expands.
- Hover a status icon: its popout opens at the icon, not the dock edge.
- Wheel over workspaces: switches workspace. Wheel over the lower half: volume.
- Fullscreen a window: dock hides; leave fullscreen: dock returns.
- `qs log | tail -80`: no `TypeError`, `is not defined`, or `Unable to assign` lines from `Bar.qml`, `WidgetHost.qml`, `WidgetFrame.qml`.

- [ ] **Step 7: Update `AGENTS.md`**

Replace the "Bar Rendering" entry list with: the dock is three `WidgetHost` regions (`start`, `center`, `end`); widgets come from `Config.bar.entries` through `WidgetRegistry.fromBarEntries`; adding a widget means a registry entry, a `WidgetCatalog.componentFor` case, a component declaring `item`/`host`/`orientation`, and the registry's capability fields (`role`, `ownsPopover`, `wantsFocus`, `minSize`). Add one rule: hosts never branch on widget ids to decide focus, popover routing or minimum size — those read the registry, and the existing dock branches are scheduled for the popover broker. Keep rules 1–6 (no `ComponentBehavior: Bound`, no `ColumnLayout` root, token widths, `BarWrapper` anchoring, `contentWidth`) verbatim.

- [ ] **Step 8: Commit**

```bash
git add shell/modules/bar/Bar.qml tests/widget_test.sh AGENTS.md
git commit -m "refactor(bar): host dock widgets through the widget registry"
```
