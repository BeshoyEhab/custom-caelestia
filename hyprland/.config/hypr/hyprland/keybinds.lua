-- Caelestia-Impulse (Celestimpulse) Keybinds Configuration
require("hyprland.lib")
require("hyprland.variables")
if is_file_exists(HOME .. "/.config/hypr/custom/variables.lua") then
    require("custom.variables")
end

local qsScripts = "$HOME/.config/quickshell/ii/scripts"
local hyprScripts = "$HOME/.config/hypr/hyprland/scripts"
local qsIpcCall = "qs -c $qsConfig ipc call"

-- ##! Shell (caelestia quickshell)
-- Nexus (settings panel)
hl.bind("SUPER + I", hl.dsp.global("caelestia:nexus"), { description = "Shell: Toggle nexus/settings" })
-- Launcher (Super alone opens, interrupt for other binds)
hl.bind("SUPER + SUPER_L", hl.dsp.global("caelestia:launcher"), { release = true, description = "Shell: Toggle launcher" })
hl.bind("SUPER + Space", hl.dsp.global("caelestia:launcher"), { description = "Shell: Toggle launcher" })
-- Dashboard
hl.bind("SUPER + G", hl.dsp.global("caelestia:dashboard"), { description = "Shell: Toggle dashboard" })
-- Utilities
hl.bind("SUPER + U", hl.dsp.global("caelestia:utilities"), { description = "Shell: Toggle utilities" })
-- Sidebar
hl.bind("SUPER + A", hl.dsp.global("caelestia:sidebar"), { description = "Shell: Toggle sidebar" })
hl.bind("SUPER + B", hl.dsp.global("caelestia:sidebar"))
hl.bind("SUPER + O", hl.dsp.global("caelestia:sidebar"))
-- Session
hl.bind("CTRL + ALT + Delete", hl.dsp.global("caelestia:session"), { description = "Shell: Toggle session menu" })
-- Bar (toggle via IPC)
hl.bind("SUPER + J", hl.dsp.exec_cmd("qs -c $qsConfig ipc call drawers toggle bar"), { description = "Shell: Toggle bar" })
-- OSD (toggle via IPC)
hl.bind("SUPER + Slash", hl.dsp.exec_cmd("qs -c $qsConfig ipc call drawers toggle osd"), { description = "Shell: Toggle OSD" })
-- Restart widgets
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("killall qs quickshell; qs -c $qsConfig &"),
    { description = "Shell: Restart widgets" })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(qsIpcCall .. " brightness set +5% || brightnessctl s 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qsIpcCall .. " brightness set 5%- || brightnessctl s 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ -l 1.5"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
    { locked = true, repeating = true })

-- Clipboard (CopyQ fallback to Caelestia cliphist)
hl.bind("SUPER + V", hl.dsp.exec_cmd("if command -v copyq &>/dev/null; then if [ \"$(hyprctl activewindow -j | jq -r '.class')\" = \"copyq\" ] || [ \"$(hyprctl activewindow -j | jq -r '.class')\" = \"com.github.hluk.copyq\" ]; then copyq hide; else copyq show; fi; else caelestia clipboard; fi"), { description = "Utilities: Clipboard history" })

-- Emoji (Emote fallback to Caelestia emoji picker)
hl.bind("SUPER + Period", hl.dsp.exec_cmd("if command -v emote &>/dev/null; then emote --class=emote; else caelestia emoji -p; fi"), { description = "Utilities: Emoji picker" })

-- Screenshot
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("qs -c $qsConfig ipc call picker openFreezeClip || hyprshot --freeze --clipboard-only --mode region --silent"),
    { description = "Utilities: Screen snip" })

-- Google Lens (grabs region, runs Google Lens search)
hl.bind("SUPER + SHIFT + A", hl.dsp.exec_cmd(hyprScripts .. "/snip_to_search.sh"),
    { description = "Utilities: Google Lens" })

-- OCR (tesseract)
hl.bind("SUPER + SHIFT + X", hl.dsp.exec_cmd("grim -g \"$(slurp)\" /tmp/ocr_image.png && tesseract /tmp/ocr_image.png stdout -l eng+ara | wl-copy && rm /tmp/ocr_image.png"),
    { description = "OCR: Screenshot to clipboard" })

-- Color picker
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"),
    { description = "Utilities: Pick color #RRGGBB >> clipboard" })

-- Recording
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh"), { locked = true, description = "Utilities: Record region (no sound)" })
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh"), { locked = true })
hl.bind("CTRL + ALT + R", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh --fullscreen"), { locked = true })
hl.bind("SUPER + SHIFT + ALT + R", hl.dsp.exec_cmd(qsScripts .. "/videos/record.sh --fullscreen --sound"),
    { locked = true, description = "Utilities: Record screen (with sound)" })

-- Fullscreen screenshot
local grimhyprctl = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
hl.bind("Print", hl.dsp.exec_cmd(grimhyprctl .. " - | wl-copy"),
    { locked = true, description = "Utilities: Screenshot >> clipboard" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(
    "mkdir -p $(xdg-user-dir PICTURES)/Screenshots && " ..
    grimhyprctl .. " $(xdg-user-dir PICTURES)/Screenshots/Screenshot_\"$(date '+%Y-%m-%d_%H.%M.%S')\".png"
), { locked = true, non_consuming = true, description = "Utilities: Screenshot >> clipboard & file" })
hl.bind("CTRL + Print", hl.dsp.exec_cmd(grimhyprctl .. " - | wl-copy"), { locked = true, non_consuming = true })

-- AI
hl.bind("SUPER + SHIFT + ALT + mouse:273", hl.dsp.exec_cmd(hyprScripts .. "/ai/primary-buffer-query.sh"),
    { description = "Utilities: Generate AI summary for selected text" })

-- ##! Screen
-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind("SUPER + Minus", function() zoomfunction(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function() zoomfunction(0.3) end, { repeating = true, description = "Screen: Zoom in" })
hl.bind("SUPER + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind("SUPER + code:86", function() zoomfunction(0.3) end, { repeating = true })

-- ##! Media
local mediaNextCommand =
"playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(mediaNextCommand), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(mediaNextCommand), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + SHIFT + ALT + mouse:275", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("SUPER + SHIFT + ALT + mouse:276", hl.dsp.exec_cmd(mediaNextCommand))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"),
    { locked = true, description = "Media: Previous track" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"),
    { locked = true, description = "Media: Toggle mute" })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("SUPER + ALT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"),
    { locked = true, description = "Media: Toggle mic" })

-- ##! Window
-- Focusing
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })

for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + " .. arrowkey[i], hl.dsp.focus({ direction = focusdir[i] }),
        { description = "Window: Focus " .. arrowkey[i] })
end
for i = 1, 2 do
    local arrowkey = { "BracketLeft", "BracketRight" }
    local focusdir = { "l", "r" }
    hl.bind("SUPER + " .. arrowkey[i], hl.dsp.focus({ direction = focusdir[i] }))
end

for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + SHIFT + " .. arrowkey[i], hl.dsp.window.move({ direction = focusdir[i] }),
        { description = "Window: Move " .. arrowkey[i] })
end

hl.bind("ALT + F4",
    function()
        hl.exec_cmd(
            "notify-send \"Wrong close keybind\" \"Super+Q to close. Use Alt+F4 for Windows VMs\" -a Hyprland")
    end,
    { non_consuming = true })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Forcefully zap a window" })

-- Window split ratio
hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })
-- Positioning mode
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Window: Maximize" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Window: Fullscreen" })
hl.bind("SUPER + ALT + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3, action = "toggle" }),
    { description = "Window: Fullscreen spoof" })

-- Send to workspace
for i = 1, 10 do
    local numberkey = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
    hl.bind("SUPER + ALT + code:" .. numberkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end, { description = "Window: Send to workspace " .. i })
end
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + ALT + code:" .. numpadkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end)
end

-- Send to workspace left/right
for i = 1, 4 do
    local key = { "SUPER + SHIFT + mouse_", "SUPER + ALT + mouse_" }
    local keycombos = { key[1] .. "down", key[1] .. "up", key[2] .. "down", key[2] .. "up" }
    local prefix = { "r-", "r+", "r-", "r+" }
    hl.bind(keycombos[i], hl.dsp.window.move({ workspace = prefix[i] .. "1" }))
end

for i = 1, 2 do
    local keydirs = { "Up", "Down" }
    local prefix = { "r-", "r+" }
    local descdir = { "left", "right" }
    hl.bind("SUPER + SHIFT + Page_" .. keydirs[i], hl.dsp.window.move({ workspace = prefix[i] .. "1" }),
        { description = "Window: Send to workspace " .. descdir[i] })
end
for i = 1, 4 do
    local key = { "SUPER + ALT + Page_", "CTRL + SUPER + SHIFT + " }
    local keycombos = { key[1] .. "down", key[1] .. "up", key[2] .. "Right", key[2] .. "Left" }
    local prefix = { "r+", "r-", "r+", "r-" }
    hl.bind(keycombos[i], hl.dsp.window.move({ workspace = prefix[i] .. "1" }))
end

hl.bind("SUPER + ALT + S",
    hl.dsp.window.move({ workspace = "special:special", follow = false }),
    { description = "Window: Send to scratchpad" })
hl.bind("CTRL + SUPER + S", hl.dsp.workspace.toggle_special("special"))

-- ##! Workspace
-- Switching
for i = 1, 10 do
    local numberkey = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
    hl.bind("SUPER + code:" .. numberkey[i], function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
    end, { description = "Workspace: Focus " .. i })
end
for i = 1, 10 do
    local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
    hl.bind("SUPER + code:" .. numpadkey[i], function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
    end)
end

-- Focus left/right
for i = 1, 2 do
    local keys = { "Left", "Right" }
    local prefix = { "r-", "r+" }
    local descdir = { "left", "right" }
    hl.bind("CTRL + SUPER + " .. keys[i], hl.dsp.focus({ workspace = prefix[i] .. "1" }),
        { description = "Workspace: Focus " .. descdir[i] })
end
for i = 1, 2 do
    local keys = { "Left", "Right" }
    local prefix = { "m-", "m+" }
    hl.bind("CTRL + SUPER + ALT + " .. keys[i], hl.dsp.focus({ workspace = prefix[i] .. "1" }))
end
for i = 1, 4 do
    local key = { "SUPER + Page_Down", "SUPER + Page_Up" }
    local keycombos = { key[1], key[2], "CTRL + " .. key[1], "CTRL + " .. key[2] }
    local prefix = { "r+", "r-", "r+", "r-" }
    hl.bind(keycombos[i], hl.dsp.focus({ workspace = prefix[i] .. "1" }))
end
for i = 1, 4 do
    local key = { "SUPER + mouse_up", "SUPER + mouse_down" }
    local keycombos = { key[1], key[2], "CTRL + " .. key[1], "CTRL + " .. key[2] }
    local prefix = { "+", "-", "r+", "r-" }
    hl.bind(keycombos[i], hl.dsp.focus({ workspace = prefix[i] .. "1" }))
end

-- Special workspace
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Toggle scratchpad" })
hl.bind("SUPER + mouse:275", hl.dsp.workspace.toggle_special("special"))
for i = 1, 4 do
    local key = { "BracketLeft", "BracketRight", "Up", "Down" }
    local prefix = { "-1", "+1", "r-5", "r+5" }
    hl.bind("CTRL + SUPER + " .. key[i], hl.dsp.focus({ workspace = prefix[i] }))
end

-- ##! Virtual machines
hl.define_submap("virtual-machine", function()
    hl.bind("SUPER + ALT + F1", function()
        local currentsubmap = hl.get_current_submap()
        if currentsubmap == "virtual-machine" then
            hl.dispatch(hl.dsp.exec_cmd(
                "notify-send 'Exited Virtual Machine submap' 'Keybinds re-enabled' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("reset"))
        elseif currentsubmap == "" then
            hl.dispatch(hl.dsp.exec_cmd(
                "notify-send 'Entered Virtual Machine submap' 'Keybinds disabled. hit SUPER+ALT+F1 to escape' -a 'Hyprland'"))
            hl.dispatch(hl.dsp.submap("virtual-machine"))
        end
    end, { submap_universal = true })
end)

-- ##! Session
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind("CTRL + SHIFT + ALT + SUPER + Delete", hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"),
    { description = "Session: Shut down" })

-- ##! Apps
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind("SUPER + T", hl.dsp.exec_cmd(terminal))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })
hl.bind("CTRL + SUPER + SHIFT + ALT + W", hl.dsp.exec_cmd(officeSoftware), { description = "App: Office software" })
hl.bind("SUPER + X", hl.dsp.exec_cmd(textEditor), { description = "App: Text editor" })
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd(volumeMixer), { description = "App: Volume mixer" })
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class btop -e btop"), { description = "App: Task manager" })

-- ##! User custom keybinds are in ~/.config/hypr/custom/keybinds.lua
