-- ── custom/rules.lua ─────────────────────────────────────────────────
-- converted from custom/rules.conf for hyprland 0.55 (lua)

-- ── blur ──────────────────────────────────────────────────────────────
-- hyprland/rules.lua disables blur for all windows globally.
-- re-enable it here (custom is sourced after, so it wins).
hl.window_rule({ match = { class = ".*" }, no_blur = false })
-- re-disable for xwayland context menus (empty class and title)
hl.window_rule({ match = { class = "^()$", title = "^()$" }, no_blur = true })

-- ── keep windows within screen bounds ────────────────────────────────
-- note: the hyprlang `move min(cursor_x,(monitor_w-window_w)) ...` expression
-- is a computed-position feature. in lua it is passed as a string exactly as before.
hl.window_rule({
  match = { float = true },
  move  = "min(cursor_x,(monitor_w-window_w)) min(cursor_y,monitor_h-window_h)",
})

-- steam: force tiling (prevents it floating by default)
hl.window_rule({ match = { class = "^(steam)$" }, tile = true })

-- ── copyq clipboard manager ───────────────────────────────────────────
-- float + place near cursor, and keep it pinned so it doesn't hide on focus loss
hl.window_rule({
  name  = "clipboard copyq",
  match = { class = "^(com\\.github\\.hluk\\.copyq|copyq)$" },
  float = true,
  move  = "min(cursor_x,(monitor_w-window_w)) min(cursor_y,monitor_h-window_h)",
  pin   = true,          -- stays on top across workspaces (prevents hide-on-deactivate)
  no_initial_focus = false,
})

-- ── wl-mirror on hdmi-a-1 ────────────────────────────────────────────
hl.window_rule({
  name       = "mirror on hdmi-a-1",
  match      = { class = "^(wl-mirror)$" },
  monitor    = "hdmi-a-1",
  fullscreen = true,
  no_anim    = true,
})

-- --- gromit-mpx (screenshot annotation tool) ─────────────────────────
hl.window_rule({
  match = { class = "^(Gromit-mpx)$" },
  no_blur = true,
  opaque = true,
  no_shadow = true,
  pin = true,
  no_initial_focus = true,
})
