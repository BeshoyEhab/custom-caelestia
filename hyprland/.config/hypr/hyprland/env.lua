-- Environment variables

local home_dir = os.getenv("HOME")

-- Wayland
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- XDG: user config first, then system
hl.env("XDG_CONFIG_DIRS", home_dir .. "/.config:/etc/xdg")

-- Applications
local xdg_data_dirs_old = os.getenv("XDG_DATA_DIRS") or ""
hl.env("XDG_DATA_DIRS",
    home_dir ..
    "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:" .. xdg_data_dirs_old)

-- Themes (KDE integration, not qt6ct)
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")
hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- Cursor theme
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

-- Virtual environment
hl.env("CELESTIMPULSE_VIRTUAL_ENV", home_dir .. "/.local/state/quickshell/.venv")

-- Firefox/Wayland override
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Java AWT override
hl.env("JAVA_TOOL_OPTIONS", "-Xmx2g")
