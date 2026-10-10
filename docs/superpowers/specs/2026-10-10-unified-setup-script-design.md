# Unified setup script design

Date: 2026-10-10. Scope: merge `install.sh` + `update.sh` into one entry
point with a single deploy path, manifest-based stale pruning, and one
plugin-build flow. No change to what gets deployed or to `shell.json`
handling.

## 1. Goals / non-govements

- Goals:
  - One script (`install.sh`) owns install, update, check, and build.
  - Single deploy function — the plugin/build/upstream excludes cannot drift.
  - Manifest-tracked pruning of files removed from the repo (the deployed
    `plugin/` rot class of bug).
  - One plugin-build flow (incremental by default, no `sudo rm -rf build`).
  - `update.sh` stays as a thin compat stub so the deployed
    `scripts/update.sh` symlink and Nexus's hardcoded calls keep working.
- Non-goals:
  - No change to which packages or configs are installed.
  - No new package-manager logic; `pacman`/AUR handling stays as-is.
  - No migration of Nexus `UpdatesPage.qml` off its current flag strings.
  - No `--yes`/unattended package installs beyond what exists.

## 2. CLI surface

Single entry `install.sh`. Bare invocation shows an interactive menu
(Install / Update / Check / Build). Explicit commands:

| Command | Behavior |
|---|---|
| `--install` | Full install: packages + configs + plugin. Interactive section picker unless `--non-interactive`. |
| `--update` | Update deployed configs; rebuild plugin when sources changed, or always with `--build`. Auto-detects which sections are installed. |
| `--check` | Print `BEHIND=<n>` and `PLUGINS_STALE=<true|false>`; exit non-zero if either indicates updates. Nexus reads these exact strings. |
| `--build` | Rebuild + install the C++ plugin only. |

Shared flags (override defaults for any command):

| Flag | Meaning |
|---|---|
| `--dry-run` | Print would-be actions; touch nothing. |
| `--backup` | Copy files about to be replaced into a timestamped backup dir first. |
| `--on-conflict MODE` | `ask` (default) \| `replace` \| `keep` \| `backup` \| `new` — what to do when a deployed file differs from the repo. |
| `--no-install` | Skip package install + plugin build (configs only). |
| `--non-interactive` | No prompts; assume defaults, deploy everything selected. |
| `--no-prune` | Never delete stale files this run. |
| `--force-rebuild` | Clean-build the plugin (wipe build dir) instead of incremental. |

`update.sh` becomes: `exec "$(dirname "$0")/install.sh" "$@"`. The old
flag names (`--build`, `--check`, `--on-conflict`, `--backup`, `--dry-run`,
`--non-interactive`) already map onto the table above, so callers are
unchanged.

## 3. Architecture

```
install.sh
├─ arg parse → mode (menu|install|update|check|build) + option struct
├─ deploy_tree(src, dst, excludes...)   # THE one deploy path
│    ├─ skip via .updateignore
│    ├─ mtime/user-mod heuristic → conflict mode (ask/replace/keep/backup/new)
│    ├─ --dry-run prints, writes nothing (not even manifest)
│    └─ records every written rel-path into a manifest array
├─ prune_stale(dst, manifest)
│    ├─ for each manifest entry: source gone AND deployed copy unmodified
│    ├─ default: delete; --no-prune skips; --dry-run lists only
│    └─ never touches .updateignore'd paths, custom/, shell.json
├─ write_manifest(dst)   # after a real (non-dry-run) deploy
├─ build_plugin(force?)  # incremental cmake --build + sudo cmake --install
└─ check_status()        # BEHIND / PLUGINS_STALE (unchanged contract)
```

Sections (`core`, `hyprland`, `shell_extras`, `quickshell`) each call
`deploy_tree` with their own src/dst and the shared exclude list
(`build/`, `upstream/`, `plugin/`, `.git*`). The exclude list is one
variable, defined once.

### Manifest

- Location: `<quickshell_dst>/.deploy-manifest` (plain text, one relative
  path per line), plus the same for hyprland and shell-extras roots so
  pruning works per-section. Simplest: one manifest per deploy root.
- Written only after a successful non-dry-run deploy of that root.
- On update, before deploying, read the prior manifest; after deploying,
  compute `removed = prior_manifest − current_repo_files`; for each
  `removed` path, delete the deployed file if it is unmodified (deploy's
  mtime heuristic: deployed copy not newer than the repo version it came
  from) else warn and keep.
- `.updateignore`d files are never added to the manifest (so pruning can
  never remove a user-owned file that happens to match a deleted repo
  path).

### Build

- `build_plugin`: configure once into `build/` (reuse existing cache),
  `cmake --build build -j$(nproc)`, then `sudo cmake --install build
  --prefix /`. On install failure, fall back to manual copy of
  `build/qml/Caelestia` + M3Shapes deps dir (ported from current
  `update.sh`). `--force-rebuild` wipes `build/` first. No unconditional
  `sudo rm -rf build`.
- `PLUGINS_STALE` compares `shell/plugin/src` mtimes against
  `build/.plugin_build_stamp`, unchanged.

## 4. Compatibility

- `UpdatesPage.qml` calls (unchanged, verified against new parser):
  - `scripts/update.sh --check` → stub → `install.sh --check`
  - `scripts/update.sh --non-interactive` → bare `--non-interactive`
    without a command defaults to `--update` (matches old update.sh
    behavior of "run an update").
  - `scripts/install.sh --non-interactive --no-install` → `--install`
    with configs-only.
- To keep "bare flags = update" working, arg parsing treats
  `--non-interactive`/`--backup`/`--dry-run`/`--on-conflict` with no
  explicit `--install`/`--update`/`--check`/`--build` as `--update`.
- README flag section rewritten to the new table.

## 5. Error handling

- `set -euo pipefail` retained. Conflict/copy failures warn and continue
  (current behavior), never abort the whole section for one file.
- `sudo` failures during plugin install: warn, print the exact command,
  continue (config deploy already succeeded).
- Prune deletion failure: warn, continue.
- `--check` exit code: `0` up-to-date, `1` updates/stale, `2` git/repo
  error — same semantics Nexus already relies on (0 vs non-0).

## 6. Testing

Manual + scripted checks (no new test framework):

1. `bash -n install.sh update.sh` — syntax.
2. `./install.sh --check` prints the two `KEY=value` lines; exit code
   correct.
3. `./install.sh --update --dry-run` on a scratch HOME (`HOME=/tmp/...`)
   deploys nothing, prints would-be actions, writes no manifest.
4. Manifest prune: seed a scratch HOME with a manifest entry whose
   source was deleted; run update; file removed. Same with a
   user-modified target; file kept + warned.
5. Conflict modes: `--on-conflict keep|replace|backup` each behave as
   tabled against a pre-modified target.
6. `./update.sh --check` (stub) output identical to `install.sh --check`.
7. Deploy excludes: confirm `plugin/`, `upstream/`, `build/` never appear
   under a scratch deploy root.
8. `--no-prune` leaves a stale manifest entry's file intact.
