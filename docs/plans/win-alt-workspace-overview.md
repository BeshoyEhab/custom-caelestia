# Plan: Win+Alt Workspace Overview

## Goal

Pressing `Super+O` shows a workspace overview/switcher UI instead of switching to the next workspace. The user can see all workspaces and click one to switch.

## Current Behavior

- `Super+O` is not bound to anything currently
- Workspace switching uses `Win+1-0`, `Win+Tab`, `Ctrl+Win+Arrow`, etc.
- There is no workspace overview/switcher UI in the shell

## Proposed Behavior

- `Super+O` triggers a global event `caelestia:workspaceOverview`
- A full-screen overlay panel appears showing all workspaces as cards/thumbnails
- Each card shows: workspace number, app icon (from `lastFocusedPerWorkspace`), window count
- Clicking a card switches to that workspace and closes the overview
- `Esc` or clicking outside closes the overview without switching
- `Super+O` again toggles it off

## Architecture

### 1. Keybind (Hyprland)

**File:** `hyprland/.config/hypr/hyprland/keybinds.lua`

Add a new keybind:
```lua
hl.bind("<SUPER>O", hl.dsp.global("caelestia:workspaceOverview"), { description = "Toggle workspace overview" })
```

### 2. Global Event Handler (Shell)

**File:** `shell/modules/Shortcuts.qml`

Add a new `CustomShortcut` handler:
```qml
CustomShortcut {
    name: "workspaceOverview"
    description: "Toggle workspace overview"
    onPressed: Drawers.toggle("workspaceOverview")
}
```

### 3. Drawer Registration

**File:** `shell/modules/drawers/Panels.qml`

Register the workspace overview as a new panel position (full-screen overlay):
```qml
Panel {
    id: workspaceOverview
    anchors.fill: parent
    visible: Drawers.workspaceOverview
}
```

**File:** `shell/components/DrawerVisibilities.qml`

Add `workspaceOverview` visibility property.

### 4. Workspace Overview Panel

**New file:** `shell/modules/workspaceoverview/Wrapper.qml`

Full-screen semi-transparent overlay with:
- Grid of workspace cards (responsive layout based on monitor size)
- Each card is a clickable `StyledRect` showing:
  - Workspace number/name
  - App icon from `Hypr.lastFocusedPerWorkspace[wsId]`
  - Window count badge
  - Active indicator (highlighted border for current workspace)
- Background: blurred or dimmed overlay
- Fade-in/fade-out animation

**New file:** `shell/modules/workspaceoverview/WorkspaceCard.qml`

Individual workspace card component:
```qml
StyledRect {
    required property int wsId
    property bool isActive: wsId === Hypr.activeWsId

    // Card content: icon, name, window count
    // Click handler: Hypr.dispatch(`workspace ${wsId}`) + close overview
}
```

### 5. Integration with Drawer System

The workspace overview should be a toggle-able panel in the drawer system:
- `Drawers.toggle("workspaceOverview")` shows/hides it
- It should be exclusive (closing other panels when opened)
- It should capture input focus (click outside to close)

### 6. Workspace Data

Use existing services:
- `Hypr.workspaces.values` - list of all workspaces
- `Hypr.lastFocusedPerWorkspace` - app icon per workspace (from Feature 1)
- `Hypr.toplevels.values` - window count per workspace
- `Hypr.activeWsId` - current workspace

### 7. Card Layout

```
┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│  WS 1   │ │  WS 2   │ │  WS 3   │ │  WS 4   │ │  WS 5   │
│  [icon] │ │  [icon] │ │  [icon] │ │  [icon] │ │  [icon] │
│  3 wins │ │  1 win  │ │  0 wins │ │  5 wins │ │  2 wins │
└─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘
```

- Active workspace: highlighted border (m3primary color)
- Empty workspaces: dimmed/transparent
- Occupied workspaces: normal opacity with app icon
- Hover effect: slight scale up + elevation

### 8. Animation

- Opening: fade in + scale from 0.95 to 1.0
- Closing: fade out + scale from 1.0 to 0.95
- Card hover: scale 1.02 + elevation increase
- Card click: quick flash + close

## Files to Create/Modify

| File | Action |
|------|--------|
| `hyprland/.config/hypr/hyprland/keybinds.lua` | Add `SUPER+ALT` keybind |
| `shell/modules/Shortcuts.qml` | Add `workspaceOverview` handler |
| `shell/modules/drawers/Panels.qml` | Register overview panel |
| `shell/components/DrawerVisibilities.qml` | Add visibility property |
| `shell/modules/workspaceoverview/Wrapper.qml` | **New** - overview container |
| `shell/modules/workspaceoverview/WorkspaceCard.qml` | **New** - workspace card |

## Config Options (Future)

Add to a new `WorkspaceOverviewConfig` class:
- `columns: int` - number of columns in grid (default: auto based on workspace count)
- `cardWidth: int` - card width in px (default: 200)
- `showEmpty: bool` - show empty workspaces (default: true)
- `blurBackground: bool` - blur screen behind overview (default: true)

## Testing

1. Press `Super+O` - overview should appear
2. Click a workspace card - should switch and close
3. Press `Esc` - should close without switching
4. Press `Super+O` again - should toggle off
5. Verify app icons show correctly (depends on Feature 1)
6. Verify animation is smooth
7. Test with multiple monitors (per-monitor workspaces)

## Dependencies

- Feature 1 (Workspace App Icon Display) - for `lastFocusedPerWorkspace`
- Quickshell.Hyprland plugin - for workspace data
- Existing drawer system - for panel management
