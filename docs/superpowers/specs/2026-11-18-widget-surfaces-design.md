# Widget Surfaces Design

**Status:** draft, awaiting approval
**Date:** 2026-11-18
**Goal:** every panel and shell element becomes a list of widgets, and any widget can be hosted by a window, a panel, or the shell frame without being rewritten.

## Intent

Today the shell is hard-wired by type. The bar owns a fixed set of entries chosen by
`Bar.qml`'s `topEntries`/`bottomEntries` arrays and created by inline `switch` statements.
The dashboard grid, the sidebar, the utilities stack and every popout have their own
bespoke layout code. A widget built for one of them cannot move to another, and a
"floating version" of any of them would be a copy.

The refactor introduces one widget contract and a small set of surface roles, so placement
becomes data instead of code.

## The model

Two axes, not five parallel bucket types. Every named concept is a value on one axis:

| Axis | Values |
|---|---|
| **Surface** — where content renders | `window`, `panel`, `popover`, `frame` (the shell) |
| **Content** — what a surface holds | widget, helper (`structure` or `decoration`) |
| **Placement** — which region, in what order | slot, item list |

| Concept | In this design |
|---|---|
| **Widget** | A self-contained QML item with a registry entry. Knows nothing about where it is hosted. |
| **Helper** | A widget whose job is spacing or styling. `role: "structure"` (spacer, group, stack) cooperates with the host's layout; `role: "decoration"` (separator, frame, padding) only paints. |
| **Panel** | A surface that hosts a widget list and auto-fits it. `mount: "layer"` (own layer-shell window) or `mount: "attached"` (a region of the shell frame). |
| **Window** | A surface that is a real toplevel (`FloatingWindow`), auto-fits its content, and is subject to normal Hyprland window rules. |
| **Shell** | The per-screen frame: border, the dock slot, edge slots. Surfaces placed in slots; small widget lists can sit in a slot directly. |
| **Popover** | A transient surface anchored to a widget or a slot: popouts, OSD, toasts, notifications, launcher, cheat sheet. One at a time per screen, dismissed on click-outside, never tiled. |
| **Slot** | A named region a surface or a widget list occupies: shell edges (`left-start`, `left-center`, …), panel sections (`header`, `body`, `footer`). |

Window and Panel are *roles*, not mechanisms: a floating panel and a widget window are
both toplevels. Keeping `kind` (role) apart from `mount` (mechanism) stops the two from
being implemented twice.

## Widget contract

A widget is a QML file whose root item declares:

- `implicitWidth` / `implicitHeight` — what the surface fits to. No widget sets its own
  outer size.
- `property var item` — its placement item; options are `item.options`, children
  `item.children`.
- `property var host` — the surface object. Widgets that need screen/visibilities/fullscreen
  read them from here and narrow with duck typing.
- `property string orientation` — `"horizontal"` / `"vertical"`, so size policies respond.
- optionally `property string widgetError` — a human-readable problem for the editor.

All three of `item`, `host`, `orientation` are declared (`property`, not `required`) so
`WidgetFrame` can pass them at creation time. A widget that omits one is instantiated by
nobody: the frame shows an error placeholder instead.

Metadata lives in `WidgetRegistry.js` (pure JS, node-tested):

```
{ id, name, description, icon,
  category: "widget" | "helper",
  role: "structure" | "decoration" | null,   // helpers only
  singleton: bool,          // only one enabled instance per surface
  defaultOptions: {},       // merged into every instance
  allowHelpers: bool,       // may contain child widgets (Group, Stack)
  compositeOf: [],          // leaf ids this widget can be split into later
  wantsFocus: bool,         // surface must request keyboard focus when this is present
  ownsPopover: bool,        // may raise a popover from its own anchor
  minSize: { width, height } }
```

`wantsFocus` and `ownsPopover` exist so hosts never branch on widget ids: a window with
a text field asks for focus because the registry says so, and a popover is routed to the
surface that owns the anchor. `minSize` is what `fit` respects when content is smaller
than the surface must be.

Widget ids are stable strings and are never derived from file paths, so widgets can be
physically moved later without touching saved layouts.

## Surfaces and placement

One surface shape, one padding item shape:

```
{ id, kind: "window" | "panel" | "popover" | "frame",
  mount: "toplevel" | "layer" | "attached",     // frame is always attached
  screen: "*" | "<monitor name>",
  title: string,                                // toplevel window title
  slot: "left-start" | "left-center" | ... | "body",   // where it mounts
  anchor: { edge, align, offset },              // popovers only
  size: { mode: "fit" | "fixed", width, height },
  regions: { start: [...], center: [...], end: [...] },  // frame dock only
  items: [ item, ... ] }
```

```
{ type: "<registry id>", instance: "<unique string>", enabled: bool, options: {}, children: [ ... ] }
```

- `kind: "window"` → `mount: "toplevel"`, `title: "caelestia-window:<id>"`, auto-fit through
  `implicitWidth`/`implicitHeight`, matched by a generic Hyprland rule
  (`^(caelestia-window:.+)$` → float + center), so SUPER+Q, workspace moves and user rules
  behave like any other window. Focus is requested only when a `wantsFocus` widget is
  present.
- `kind: "panel"` → `mount: "layer"` (own layer-shell window, auto-fit) or
  `mount: "attached"` (a region of the shell frame).
- `kind: "popover"` → drawn by the surface that owns the anchor, never its own toplevel
  unless it leaves the frame (a launcher can be its own layer surface). Exactly one open
  per screen; click-outside and Escape dismiss.
- `kind: "frame"` → the shell: border, the dock region, and edge slots. Exclusive zone
  derived from content thickness. A slot holds one surface or a widget list.

The dock is therefore "the frame's `dock` region", the dashboard is "a panel attached to
the `top-center` slot", the OSD is "a popover anchored to the `right-center` slot", and a
detached clock is "a window titled `caelestia-window:clock-1`". Nothing needs a new code
path per combination.

## Architecture

```
WidgetRegistry.js   pure: metadata, validation, migration, id generation
WidgetCatalog.qml   singleton: id -> Component, plus the metadata list for the editor
WidgetHost.qml      surface-side: items in, laid-out frames out, hit-testing out
WidgetFrame.qml     per-widget wrapper: creates the widget, injects item/host/orientation
helpers/            Spacer, Separator, Group (Group contains a WidgetHost)
builtin/            adapters binding today's bar widgets to `item` / `host`
```

Later plans add `surfaces/` (`FrameSurface`, `PanelSurface`, `WindowSurface`,
`PopoverBroker`) and the `Stack` structural helper. The foundation plan implements the
vertical flow only (`WidgetHost` is a `ColumnLayout`); the horizontal flow arrives with
panels, the first surface that needs it.

Two rules from this repo are load-bearing:

- `Repeater` with a JS array model does not render. All hosts use `ScriptModel` over a
  computed array (the pattern `Bar.qml` already uses).
- `pragma ComponentBehavior: Bound` breaks inline component loaders. `WidgetHost`,
  `WidgetFrame` and `Bar.qml` stay unbound.

Widgets are created with `Component.createObject(frame, { item, host, orientation })`, so
the injected properties exist before the widget's own bindings evaluate. Every widget —
adapters and helpers included — declares all three, or `WidgetFrame` shows an error
placeholder instead of instantiating it.

## Decisions (mine, not the user's)

1. **Layout lives in `Config`, not a separate JSON file.** A new `LayoutConfig`
   subobject of `GlobalConfig` with `QVariantList surfaces`. Free file watching,
   per-screen override, Nexus bindings, one save path; `BarConfig.entries` is the
   precedent for `QVariantList`. A loose JSON file would need its own service, watcher
   and save path for no gain.
2. **`Config.bar.entries` stays authoritative until the dock flips to `Config.layout`.**
   The first plan adds the machinery without changing what the user sees; the flip is a
   tested, idempotent migration (`fromBarEntries`).
3. **Widgets are registered in place first.** The existing bar components stay in
   `modules/bar/components/` during the foundation plan; `builtin/` holds thin adapters.
   Physical relocation is a later, mechanical step once nothing imports them directly.
4. **One popout at a time, owned by a broker.** Today popouts are tied to bar geometry.
   For arbitrary placement they invert: a widget raises `requestPopout(name, anchorItem)`,
   a per-screen broker decides, and the hosting surface draws it. Foundation plan keeps
   the bar's current logic behind the host; the broker lands with the surfaces plan.
5. **`fit` is the default size mode.** Auto-fit is the whole point; fixed sizes are an
   explicit per-surface override.
6. **The dock keeps three regions in the foundation plan.** `start`, `center`, `end`
   mirror today's top / middle-active-window / bottom groups. `fromBarEntries` drops the
   inert `spacer` entries and puts `activeWindow` in `center`, so the visible bar is
   unchanged. Regions fold into one flat list (with fill spacers) in the surfaces plan,
   once the dock becomes an ordinary `shell` surface.
7. **Granularity: leaf widgets now, splits later.** `statusIcons` and `tray` stay single
   widgets in the foundation plan (their hit-testing lives inside those components) and
   declare `compositeOf`: `statusIcons` → `battery, network, audio, bluetooth, kbLayout,
   lockStatus, microphone`; `tray` → none. Splitting adds new ids later; it never removes
   `statusIcons`, so saved layouts stay valid.
8. **`options` is pass-through in the foundation plan.** Adapters keep reading
   `Config.bar.*`; `options` is injected but unused, so parity is guaranteed. Precedence
   once it becomes live: `item.options` key > `defaultOptions` key > `Config.*` read.
9. **The dock host is always a vertical column.** Today all four edges render as a
   column, and top/bottom/right edges already have a pre-existing hover-position bug
   (`Interactions` passes `x` while `Bar.qml` reads `y`). The foundation plan does not
   change that. Acceptance is verified on the configured left edge; edge-aware layout is
   part of the shell-surface work.
10. **Popover is a surface kind, not a helper.** Popouts, OSD, toasts, notifications,
    launcher and cheat sheet all share one lifecycle (one per screen, anchored,
    click-outside). Leaving them out of the model is what keeps them special-cased.
11. **Slot is placement, not a container type.** The frame owns slots; panels own
    sections; a slot holds either a surface or a widget list. This is how "the shell can
    have a panel or small widgets" becomes data.
12. **Helper role decides cooperation.** `structure` helpers interact with the host's
    layout (fill, split, stack pages); `decoration` helpers only paint and wrap. Without
    the split, every helper needs the host's special attention.
13. **Capabilities are metadata, never id checks.** No host may write
    `if (type === "clock")`. Focus, popover ownership and minimum size come from the
    registry entry, which is why they land in the foundation plan even though only the
    later plans consume them.
14. **No layout profiles in this design.** Named arrangements, per-workspace layouts and
    `preferredOrientation` per widget are real but change the schema; they are deferred
    rather than half-supported.

## Scope

**Goals**

- Any registered widget renders in any surface without modification.
- A widget can be detached from the dock into a window, into a panel, or back.
- Popovers are available to any widget, wherever it is hosted.
- Layouts survive restart and are editable without editing QML.

**Non-goals**

- Drag-resizing individual widgets. Size policy is `fit`/`fill`/fixed per item.
- Persisting free window positions after the user moves them by mouse. Windows float and
  center; per-window `size` is supported, `x`/`y` is not.
- Third-party/out-of-tree widget plugins. The registry is in-tree.
- Named layout profiles, per-workspace layouts, and per-widget preferred orientation.

**Anti-goals** — anything that makes a widget aware of which surface hosts it, or that
adds a second layout code path per surface. If a new surface needs different layout rules,
the rules go in the host, not the widget.

## Delivery roadmap

Each plan ships working software on its own.

| Plan | Delivers | Leaves the shell… |
|---|---|---|
| **A — foundation** | registry with capabilities, catalog, host, frame, helpers, dock driven by the host | visually identical, now data-driven |
| **B — surfaces** | `LayoutConfig`, migration, frame slots, window/panel/popover surfaces, popout broker, IPC | with arbitrary placement |
| **C — editor & migration** | Nexus drag-and-drop editor, `Stack` pages, then dashboard/sidebar/utilities/OSD/notifications become widget lists | fully uniform |

Plans B and C are written after A lands, because their interfaces depend on A's real
code rather than its intent.

## Risks

- **Visual parity of the dock.** `Bar.qml` carries hover popouts, tray expansion, wheel
  actions and `childAt` hit-testing. The foundation plan keeps `entryId` on each frame so
  those paths survive, and verifies parity by hand on a running shell.
- **Layout churn.** `ColumnLayout` → host-wrapped frames can shift spacing by a few
  pixels. Frame spacing must come from `Tokens.spacing.medium`, matching today.
- **Config schema drift.** `surfaces` is `QVariantList`; validation must happen in
  `WidgetRegistry.js`, not in QML, so a corrupt layout degrades to defaults instead of
  breaking the shell.
