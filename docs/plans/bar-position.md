# Bar Position Generalization (TODO #1) — implementation plan

Status: container slice drafted on `feat/bar-container-slice`, NOT working yet.
Left-bar behavior verified unaffected. Do not merge until horizontal renders.

## What works (verified via screenshot)
- Left/right vertical bar: pixel-identical, no errors.
- `positioningEdge` 0–3 config key exists (`CONFIG_GLOBAL_PROPERTY`, default 0).

## Done (unverified for horizontal)
- `BarWrapper.qml`: orientation-aware exclusiveZone (fixed dead ternary),
  x/y slide-off, edge anchors, implicitWidth/implicitHeight per orientation.
- `Bar.qml`: left/right `RowLayout` groups + `LeftLoader`/`RightLoader` with
  orientation-gated `active`, loader-aware `closeTray`/`findEntry`,
  axis-aware wheel zones.
- `ContentWindow.qml`: wrapper docks to top/bottom edges via
  `barIsTop`/`barIsBottom`.

## Known failure (reproduced 2026-09-03)
With `positioningEdge=2`: compositor reserves the 48px zone (docking works)
but the strip renders empty, zero QML errors. Left bar unaffected.
Prime suspects, in order:
1. Entry instantiation in the horizontal layouts (models evaluate but
   delegates don't paint?) — verify with a bare Rectangle placeholder in
   leftLayout to isolate Bar-vs-entry.
2. `Bar.width/height` bindings against the Loader (`parent.width`) —
   confirm Loader gives the item size (add a debug rect sized to Bar).
3. `positioningEdge` per-monitor-overlay reads — confirm value propagation
   (temporarily hardcode `isVertical: false` and observe).

## Remaining work
1. Debug horizontal content (above) until top bar renders entries.
2. Horizontal entry variants (all under `shell/modules/bar/components/`):
   - `workspaces/`: row-mode pills, horizontal occupied connectors,
     indicator sliding on x (~100 lines across Workspaces.qml,
     OccupiedBg.qml, Workspace.qml).
   - `Clock.qml`: side-by-side hour:minute (currently stacked w/ overlap).
   - `Tray.qml`: horizontal row + expand direction.
   - `StatusIcons.qml`: confirm row behavior, popout anchor math in
     `Bar.checkPopout` (currentCenter is y-based; popouts Wrapper needs
     horizontal positioning).
   - `ActiveWindow.qml`: horizontal text (currently pre-rotated title).
   - `Power.qml`, logo: orientation-free, no change.
3. `Interactions.qml` + `Regions.qml`: edge-aware hover/drag areas for
   top/bottom (currently left/right assumptions).
4. `Panels.qml` + `ContentWindow.qml`: bar-offset margins per edge.
5. Nexus UI: edge selector (TaskbarPanel), `shell.json` docs.
6. Screenshot-verify all 4 edges + popouts, update TODO checkboxes.

## Test procedure (established)
- Backup `~/.config/caelestia/shell.json`, set `bar.positioningEdge`,
  restart shell, `grim -g` the edge strip, restore backup, restart.
- Left-edge regression strip after every change.
