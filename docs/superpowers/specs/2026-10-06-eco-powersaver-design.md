# Eco / PowerSaver design

Date: 2026-10-06. Scope: laptop battery + low-spec PCs. Approach: hybrid C
(Phase 1 silent guards, Phase 2 PowerSaver service). No C++ schema change
except one default-list line for the quick-toggle id.

## 1. Goals / non-goals

- Goals: measurable idle CPU + battery-life win; manual Eco for desktops;
  auto Eco on battery / low battery for laptops; user-visible in quick
  settings AND battery popout.
- Non-goals: no `plugin/` logic changes; no new GlobalConfig schema; no
  touch of `upstream/`; no always-on daemon work.

## 2. Architecture

New QML singleton `shell/services/PowerSaver.qml` owns `ecoActive`.
Phase 1 plugs always-on holes unconditionally. Phase 2 consumers read
`PowerSaver.ecoActive` and degrade. All event-driven bindings, no polling.
Battery source: `Quickshell.Services.UPower` (`onBattery`,
`displayDevice.{percentage,isLaptopBattery}`); thresholds reuse
`GlobalConfig.general.battery.warningLevel` (`generalconfig.hpp:55-61`).

```
UPower.onBattery/percentage → PowerSaver.eval() (2% hysteresis + 400ms
coalesce, cf. VideoWallpaper.qml:158-167) → ecoActive → bindings fan out
(visualiser, video, intervals, Hypr options). GameMode × Eco: low-gfx stays
while EITHER is on; `reload` only when both off (cf. GameMode.qml:48-54).
```

## 3. Components

| # | File | Change |
|---|---|---|
| 1 | `shell/services/PowerSaver.qml` (new) | Singleton: `enabled` (manual), `autoOnBattery`, `ecoActive`, `eval()`, `PersistentProperties reloadableId:"powerSaver"`, `IpcHandler target:"powerSaver"` (`toggle/enable/disable/isEnabled/debug`). Registered like `GameMode` in `shell/modules/ServiceLoader.qml:11`. |
| 2 | `shell/services/Time.qml:38` | Gate seconds `SystemClock` behind ref-count (bar seconds, lock, desktop clock register only when visible). |
| 3 | `shell/modules/background/Visualiser.qml:43` | `layer.enabled: opacity > 0` (currently always true). |
| 4 | `shell/modules/background/Visualiser.qml:18` | `shouldBeActive && !PowerSaver.ecoActive`. Inner `ServiceRef`/`Loader active: opacity>0` already gates cava. |
| 5 | `shell/services/VideoWallpaper.qml` | `externalActive && !PowerSaver.videoBlocked`; coalescing timer pattern kept. |
| 6 | `shell/services/Audio.qml:178` | `bars: PowerSaver.ecoActive ? 24 : GlobalConfig.services.visualiserBars`. |
| 7 | Polling sites | `dash/Media.qml:36`, `media/Details.qml:19`, `NetworkUsage.qml:159`: `interval ×4 when eco` via pure binding (`Math.max(base, base*(eco?4:1))`). |
| 8 | Hypr low-gfx | On `ecoActiveChanged`: `applyOptions({animations,blur,shadow off, gaps 0, rounding 0})` (cf. `GameMode.qml:16-25`); re-apply on `Hypr.onConfigReloaded` while eco on. |
| 9 | Quick toggle | `utilities/cards/Toggles.qml` `DelegateChoice roleValue:"eco"` (`icon:"energy_savings_leaf"`, `checked: PowerSaver.ecoActive`, click toggles manual) + one-line C++ default in `utilitiesconfig.hpp:55-64` + `UtilitiesPanel.qml` enable/disable support. |
| 10 | Battery popout | `bar/popouts/Battery.qml`: Eco switch row above `profiles` rect ("Shell Eco", leaf icon, subtext shows auto reason). Independent from system `PowerProfiles.profile` (power-profiles-daemon), co-located per request. |
| 11 | Nexus | `nexus/pages/ServicesPage.qml` new `Power` section (`ToggleRow` manual + `ToggleRow` auto-on-battery, `ToggleRow.qml:9-26` API) + toast opt-in mirroring `NotificationsPage` game-mode toast. |

## 4. Data flow / error handling

- Desktop, no battery (`isLaptopBattery=false`): auto never fires; manual works (low-spec target). Unknown UPower: fail-visible, eco off.
- Rapid plug/unplug: hysteresis + coalesce prevents Hypr flapping.
- mpvpaper missing / backend `qs`: `videoBlocked` no-op.
- Eco+GameMode: union of low-gfx; no `reload` while either on.

## 5. Tests-first (RED before features)

New `tests/qml_eco_powersaver_test.sh` in repo's structural-test style
(cf. `tests/qml_idle_timers_test.sh`):

- RED asserts: `PowerSaver.qml` exists with `ecoActive`, `IpcHandler target:"powerSaver"`, UPower watch; `Visualiser.qml` has `layer.enabled: opacity` gate + `!PowerSaver.ecoActive`; `VideoWallpaper` has `videoBlocked`/eco gate; `Toggles.qml` has `roleValue:"eco"`; `Battery.qml` popout references `PowerSaver`; polling sites reference eco multiplier; `Time.qml` seconds gated.
- GREEN: implement features until pass. Then run `tests/run.sh` (+ `qml_test.sh`, `widget_test.sh`) and manual matrix: AC on/off, no-battery desktop, GameMode×Eco, dashboard open/closed, `qs ipc call powerSaver debug`.

## 6. Verification

- `qs ipc call powerSaver debug` snapshot; idle `top -p $(pgrep -f 'qs -c caelestia')`;
  discharge via `upower -d` / `/sys/class/power_supply/BAT*/power_now`.
- Dual deploy (repo `shell/` + `~/.config/quickshell/caelestia/`) per AGENTS.md.
