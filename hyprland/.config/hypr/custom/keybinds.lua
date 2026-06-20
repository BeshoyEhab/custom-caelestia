-- ── custom/keybinds.lua ──────────────────────────────────────────────
-- Converted from custom/keybinds.conf for Hyprland 0.55 (Lua)

local SCRIPTS = "$HOME/.local/share/bin"

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
  hl.bind("SUPER + SHIFT + code:" .. (9 + i), hl.dsp.window.move({ workspace = i }))
end

-- ── Override keybinds from hyprland/keybinds.lua ─────────────────────
-- Terminal
hl.unbind("SUPER + Return")
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.unbind("SUPER + T")
hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))

-- Browser
hl.unbind("SUPER + W")
hl.bind("SUPER + W", hl.dsp.exec_cmd("brave"))

-- File manager
hl.unbind("SUPER + E")
hl.bind("SUPER + E", hl.dsp.exec_cmd("dolphin"))

-- Code editor: Zed
hl.unbind("SUPER + Z")
hl.bind("SUPER + Z", hl.dsp.exec_cmd("zeditor"))
hl.unbind("SUPER + C")
hl.bind("SUPER + C", hl.dsp.exec_cmd("code"))

-- Task manager → btop in kitty
hl.unbind("CTRL + SHIFT + Escape")
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class btop -e btop"))

-- Volume mixer → pavucontrol (replaces SUPER+Shift+P default)
hl.unbind("SUPER + SHIFT + P")
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("pavucontrol"))

-- Float toggle (was SUPER+ALT+Space in defaults, add SUPER+SHIFT+F alias)
hl.bind("SUPER + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- Clipboard: CopyQ toggle (overrides quickshell clipboard)
hl.unbind("SUPER + V")
hl.bind("SUPER + V", hl.dsp.exec_cmd("copyq toggle"))

-- Emoji: emote app (overrides quickshell emoji)
hl.unbind("SUPER + Period")
hl.bind("SUPER + Period", hl.dsp.exec_cmd("emote --class=emote"))

-- Workspace cycling with Tab
hl.unbind("SUPER + Tab")
hl.bind("SUPER + Tab", hl.dsp.focus({ workspace = "r+1" }))
hl.unbind("SUPER + SHIFT + Tab")
hl.bind("SUPER + SHIFT + Tab", hl.dsp.focus({ workspace = "r-1" }))

-- Wallpaper navigation
hl.unbind("SUPER + ALT + Left")
hl.unbind("SUPER + ALT + Right")
hl.bind("SUPER + ALT + Left", hl.dsp.exec_cmd(SCRIPTS .. "/startwb p"))
hl.bind("SUPER + ALT + Right", hl.dsp.exec_cmd(SCRIPTS .. "/startwb n"))

-- Mic mute (replace default with custom mic script)
hl.unbind("XF86AudioMicMute")
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(SCRIPTS .. "/mic"), { locked = true })

-- Webcam toggle
hl.bind("XF86WebCam", hl.dsp.exec_cmd(SCRIPTS .. "/camera"))

-- Screen mirror toggle (SUPER+P, was pin in defaults)
hl.unbind("SUPER + P")
hl.bind("SUPER + P", hl.dsp.exec_cmd(SCRIPTS .. "/toggle-mirror.sh"))

-- Shutdown shortcut (SUPER+U → shutcut menu)
hl.unbind("SUPER + U")
hl.bind("SUPER + U", hl.dsp.exec_cmd(SCRIPTS .. "/shutcut"))

-- Reboot shortcut
hl.unbind("SUPER + SHIFT + CTRL + R")
hl.bind("SUPER + SHIFT + CTRL + R", hl.dsp.exec_cmd("reboot"))

-- EasyEffects
hl.unbind("CTRL + SUPER + SHIFT + V")
hl.bind("CTRL + SUPER + SHIFT + V", hl.dsp.exec_cmd("flatpak run com.github.wwmm.easyeffects"))

-- Prevent overview from opening when Super+Space is used for ibus language switching
hl.bind("SUPER + Space", hl.dsp.global("caelestia:launcherInterrupt"),
  { non_consuming = true, description = "Input: Interrupt overview on Super+Space (language switch)" })

-- Wayscriber: toggle drawing overlay on/off (strokes persist while hidden)
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("wayscriber --daemon-toggle"))

-- Wayscriber: exit light-passthrough globally (click-through escape)
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd("wayscriber --light-toggle"))
