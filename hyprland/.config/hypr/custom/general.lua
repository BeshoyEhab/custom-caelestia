-- ── custom/general.lua ───────────────────────────────────────────────
-- Converted from custom/general.conf for Hyprland 0.55 (Lua)

-- ── Plugin: dynamic-cursors ───────────────────────────────────────────
-- hl.config({ plugin = { ... } }) passes nested Lua tables to Hyprland's
-- config system, but dynamic-cursors registers its keys as a flat hyprlang
-- namespace (plugin:dynamic-cursors:shake:enabled, etc.), NOT as nested
-- sections. Hyprland therefore rejects every sub-key as "unknown config key".
hl.config { plugin = { dynamic_cursors = {
  enabled    = true,
  mode       = "stretch", -- your original mode
  threshold  = 2,

  rotate     = {
    length = 20,
    offset = 0.0,
  },

  tilt       = {
    limit      = 5000,
    activation = "negative_quadratic", -- was `function` in old syntax
    window     = 100,                  -- new field
    full       = 60,                   -- new field
  },

  stretch    = {
    limit      = 3000,
    activation = "negative_quadratic", -- was `function`; also note default is "quadratic"
    window     = 100,                  -- new field
  },

  shake      = {
    enabled   = true,
    threshold = 3.0,  -- ⚠ you had 3.0; new default is 6.0, pick yours
    base      = 3.0,  -- ⚠ you had 3.0; new default is 4.0
    speed     = 6.0,  -- ⚠ you had 6.0; new default is 4.0
    influence = 0.0,
    limit     = 5.0,  -- ⚠ you had 5.0; new default disables the cap
    timeout   = 250,  -- ⚠ you had 250ms; new default is 2000ms
    effects   = true, -- ⚠ you had true
    ipc       = false,
  },

  hyprcursor = {
    nearest    = 0,   -- ⚠ was 0; now 0/1/2 enum instead of bool
    enabled    = true,
    resolution = 100, -- ⚠ you had 100; -1 = auto-scale to cursor size
    fallback   = "clientside",
  },
} } }
-- The plugin has good defaults (stretch mode, shake enabled) so no config
-- block is needed here. If you need to tweak it later, use hyprctl:
--   hyprctl keyword plugin:dynamic-cursors:mode tilt
--   hyprctl keyword plugin:dynamic-cursors:shake:threshold 4.0
-- and add the persistent form once an hl.plugin_config() API lands upstream.

-- ── Misc ──────────────────────────────────────────────────────────────
-- NOTE: focus_on_activate overrides hyprland/general.lua (which sets it true).
--       This custom file is sourced after, so false wins.
hl.config({
  misc = {
    focus_on_activate            = false,
    animate_manual_resizes       = true,
    animate_mouse_windowdragging = true,
  }
})

hl.config({
  debug = {
    vfr = false
  }
})

-- ── Input ─────────────────────────────────────────────────────────────
hl.config({
  input = {
    kb_layout  = "us,ara",
    kb_options = "grp:win_space_toggle,grp:alt_shift_toggle",
    kb_variant = ",",
    touchpad   = {
      disable_while_typing = false, -- overrides hyprland/general.lua (true → false)
    }
  }
})

-- ── Decoration ────────────────────────────────────────────────────────
hl.config({
  decoration = {
    -- Transparency
    active_opacity     = 1.0,
    inactive_opacity   = 0.95,
    fullscreen_opacity = 1.0,

    -- Blur — overrides hyprland/general.lua values
    blur               = {
      enabled           = true,
      size              = 6,
      passes            = 2,
      new_optimizations = true,
      xray              = false,
      noise             = 0.02,
      contrast          = 0.9,
      brightness        = 0.8,
    },

    -- Dim
    dim_special        = 0.4,
    dim_strength       = 0.10,
  }
})

-- ── Animations ────────────────────────────────────────────────────────
-- Override workspaces animation to vertical slide
-- Uses the "menu_decel" curve already defined in hyprland/general.lua
hl.animation({
  leaf    = "workspaces",
  enabled = true,
  speed   = 7,
  bezier  = "menu_decel",
  style   = "slidevert",
})
