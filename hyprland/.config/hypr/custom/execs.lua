-- ── custom/execs.lua ─────────────────────────────────────────────────
-- Converted from custom/execs.conf for Hyprland 0.55 (Lua)
--
-- NOTE: exec-once = ... becomes hl.exec_cmd(...) inside hl.on("hyprland.start", ...)
-- NOTE: pypr (pyprland) is kept — see NOTES below about its usage

hl.on("hyprland.start", function()
  -- Wallpaper / lighting
  hl.exec_cmd("$HOME/.local/share/bin/startwb")
  hl.exec_cmd("sleep 5 && $HOME/.local/share/bin/lights")

  -- XWayland root access (needed by some apps that run as root under X)
  hl.exec_cmd("xhost +SI:localuser:root")

  -- Clipboard manager
  hl.exec_cmd("sleep 5 && copyq exit ; copyq --start-server")

  -- Pyprland (scratchpads plugin)
  hl.exec_cmd("pypr")

  -- Kill leftover notification daemons from previous sessions
  hl.exec_cmd("sleep 5 && pkill deadd-notific")

  -- Emote (emoji picker daemon)
  hl.exec_cmd("emote")

  -- Per-window keyboard layout
  hl.exec_cmd("/usr/bin/hyprland-per-window-layout &")

  -- Disable fcitx input method (conflicts with kb_options layout)
  hl.exec_cmd("sleep 5 && killall fcitx")
  hl.exec_cmd("$HOME/.local/share/bin/sudor rm etc/xdg/autostart/org.fcitx.Fcitx5.desktop")

  -- Start wayscriber (Wayland screen laser)
  hl.exec_cmd("wayscriber --daemon")

  -- Reload hyprpm plugins
  hl.exec_cmd("hyprpm reload")
end)
