-- Caelestia-Impulse (Celestimpulse) Hyprland Config
-- Integrated: Caelestia Shell + Fast Keybinds & Utilities + Personal Customizations
-- Lua config format (Hyprland 0.55+)

-- Internal stuff
require("hyprland.lib")
require("hyprland.services")

-- Environment variables
require("hyprland.env")

-- Default configurations
require("hyprland.execs")
require("hyprland.general")
require("hyprland.rules")
require("hyprland.keybinds")

-- Custom configurations (user overrides)
if is_file_exists(HOME .. "/.config/hypr/custom/execs.lua") then
    require("custom.execs")
end
if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then
    require("custom.general")
end
if is_file_exists(HOME .. "/.config/hypr/custom/rules.lua") then
    require("custom.rules")
end
if is_file_exists(HOME .. "/.config/hypr/custom/keybinds.lua") then
    require("custom.keybinds")
end
if is_file_exists(HOME .. "/.config/hypr/custom/colors.lua") then
    require("custom.colors")
end
