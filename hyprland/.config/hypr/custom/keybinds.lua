-- ── custom/keybinds.lua ──────────────────────────────────────────────
-- Converted from custom/keybinds.conf for Hyprland 0.55 (Lua)

local SCRIPTS = "$HOME/.local/share/bin"

-- ── Cheat-sheet descriptions ─────────────────────────────────────────
-- SUPER+/ groups every bind by the text before the first ": " in its
-- description, and shows the action after it:
--
--   hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("my-script.sh"),
--     { description = "App: My script" })
--                      ^^^^^  category  ^^^^^^^^^ action
--
-- Binds that share the exact same description are listed together in one
-- row, which is how you mark two keys as equivalent:
--
--   hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("my-script.sh"),
--     { description = "App: My script" })
--   hl.bind("SUPER + ALT + W", hl.dsp.exec_cmd("my-script.sh"),
--     { description = "App: My script" })   -- same text -> one row
--
-- A bind without a description is hidden from the sheet unless you turn on
-- the "Unlabeled" toggle in its header.


-- ── Gestures ─────────────────────────────────────────────────────────
-- Unset default 4-finger horizontal/up/down gestures from hyprland/general.lua,
-- then override vertical to workspace-switch.
-- NOTE: In Lua there is no `gesture = 4, horizontal, unset` syntax.
-- You override by re-declaring with action = nil or just redeclare:
hl.gesture({ fingers = 4, direction = "horizontal", action = "unset" })
hl.gesture({ fingers = 4, direction = "up", action = "unset" })
hl.gesture({ fingers = 4, direction = "down", action = "unset" })
hl.gesture({ fingers = 4, direction = "vertical", action = "workspace" })

-- ── Move windows to workspaces 1–10 ──────────────────────────────────
for i = 1, 10 do
  hl.bind("SUPER + SHIFT + code:" .. (9 + i), hl.dsp.window.move({ workspace = i }),
    { description = "Window: Send to workspace " .. i })
end

-- ── Override keybinds from hyprland/keybinds.lua ─────────────────────
-- Terminal
hl.unbind("SUPER + Return")
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"), { description = "App: Terminal" })
hl.unbind("SUPER + T")
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"), { description = "App: Terminal" })

-- Browser
hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.exec_cmd("brave"), { description = "App: Browser" })

-- File manager
hl.unbind("SUPER + E")
hl.bind("SUPER + E", hl.dsp.exec_cmd("dolphin"), { description = "App: File manager" })

-- Code editor: Zed
hl.unbind("SUPER + Z")
hl.bind("SUPER + Z", hl.dsp.exec_cmd("zeditor"), { description = "App: Code editor (Zed)" })
hl.unbind("SUPER + C")
hl.bind("SUPER + C", hl.dsp.exec_cmd("code"), { description = "App: Code editor (VS Code)" })

-- Task manager → btop in kitty
hl.unbind("CTRL + SHIFT + Escape")
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class btop -e btop"),
  { description = "App: Task manager" })

-- Volume mixer → pavucontrol (replaces SUPER+Shift+P default)
hl.unbind("SUPER + SHIFT + P")
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("pavucontrol"), { description = "App: Volume mixer" })

-- Float toggle (was SUPER+ALT+Space in defaults, add SUPER+SHIFT+F alias)
hl.bind("SUPER + SHIFT + F", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })

-- Clipboard: CopyQ toggle (overrides quickshell clipboard)
hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.exec_cmd("copyq toggle"), { description = "Utilities: Clipboard history" })

-- Emoji: emote app (overrides quickshell emoji)
hl.unbind("SUPER + Period")
hl.bind("SUPER + Period", hl.dsp.exec_cmd("emote --class=emote"), { description = "Utilities: Emoji picker" })

-- Workspace cycling with Tab
hl.unbind("SUPER + Tab")
-- SUPER+Tab now used for workspace overview
hl.unbind("SUPER + SHIFT + Tab")
hl.bind("SUPER + SHIFT + Tab", hl.dsp.focus({ workspace = "r-1" }),
  { description = "Workspace: Previous workspace" })

-- Wallpaper navigation
hl.unbind("SUPER + ALT + Left")
hl.unbind("SUPER + ALT + Right")
hl.bind("SUPER + ALT + Left", hl.dsp.exec_cmd(SCRIPTS .. "/startwb p"),
  { description = "App: Previous wallpaper" })
hl.bind("SUPER + ALT + Right", hl.dsp.exec_cmd(SCRIPTS .. "/startwb n"),
  { description = "App: Next wallpaper" })

-- Mic mute (replace default with custom mic script)
hl.unbind("XF86AudioMicMute")
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(SCRIPTS .. "/mic"),
  { locked = true, description = "Media: Toggle mic" })

-- Webcam toggle
hl.bind("XF86WebCam", hl.dsp.exec_cmd(SCRIPTS .. "/camera"), { description = "Media: Toggle webcam" })

-- Display switcher (SUPER+P): mirror / extend / main screen + workspace pin
hl.unbind("SUPER + P")
hl.bind("SUPER + P", hl.dsp.global("caelestia:displays"), { description = "Display: Open display switcher" })

-- Reboot shortcut
hl.unbind("SUPER + SHIFT + CTRL + R")
hl.bind("SUPER + SHIFT + CTRL + R", hl.dsp.exec_cmd("reboot"), { description = "Session: Reboot" })

-- EasyEffects
hl.unbind("CTRL + SUPER + SHIFT + V")
hl.bind("CTRL + SUPER + SHIFT + V", hl.dsp.exec_cmd("flatpak run com.github.wwmm.easyeffects"),
  { description = "App: EasyEffects" })

-- Prevent overview from opening when Super+Space is used for ibus language switching
hl.bind("SUPER + Space", hl.dsp.global("caelestia:launcherInterrupt"),
  { non_consuming = true, description = "Input: Interrupt overview on Super+Space (language switch)" })

-- Wayscriber: toggle drawing overlay on/off (strokes persist while hidden)
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("wayscriber --daemon-toggle"),
  { description = "Utilities: Toggle drawing overlay" })

-- Wayscriber: exit light-passthrough globally (click-through escape)
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd("wayscriber --light-toggle"),
  { description = "Utilities: Toggle drawing passthrough" })
