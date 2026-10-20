// Keybinds parsing unit tests — run with `node tests/keybinds_parse_test.js`
const fs = require("fs");
const vm = require("vm");

function assert(cond, msg) {
  if (!cond)
    throw new Error("FAIL: " + msg);
  console.log("  ok " + msg);
}

const ctx = { console };
vm.createContext(ctx);
const source = fs
  .readFileSync(__dirname + "/../shell/services/Keybinds.js", "utf8")
  .replace(/^\.pragma library\s*$/m, "");
vm.runInContext(source, ctx);

const raw = JSON.stringify([
  { modmask: 64, key: "P", description: "Display: Open display switcher", mouse: false, submap: "", has_description: true },
  { modmask: 65, key: "S", description: "Window: Close", mouse: false, submap: "", has_description: true },
  { modmask: 64, key: "Slash", description: "Shell: Toggle cheat sheet", mouse: false, submap: "", has_description: true },
  { modmask: 0, key: "Print", description: "Utilities: Screenshot", mouse: false, submap: "", has_description: true },
  { modmask: 64, key: "mouse:272", description: "", mouse: true, submap: "", has_description: false },
  { modmask: 64, key: "Q", description: "Sub: thing", mouse: false, submap: "resize", has_description: true },
  { modmask: 4, key: "Period", description: "", mouse: false, submap: "", has_description: false },
  { modmask: 8, key: "mouse:273", description: "Window: Resize window", mouse: true, submap: "", has_description: true },
  { modmask: 1, key: "code:10", description: "Media: Play next", mouse: false, submap: "", has_description: true }
]);

const binds = ctx.parseBinds(raw);
assert(binds.length === 6, "drops undescribed, submap and empty binds");
assert(binds[0].combo === "SUPER + P", "super combo");
assert(binds[1].keys.join(" ") === "⊞ Shift S", "keycaps use modifier symbols");
assert(binds[0].keys.join(" ") === "⊞ P", "plain keys stay readable");
assert(binds[2].keys.join(" ") === "⊞ /", "slash keycap is /");
assert(binds[1].combo === "SUPER + SHIFT + S", "mod order puts SUPER before SHIFT");
assert(binds[2].combo === "SUPER + /", "slash is displayed as /");
assert(binds[3].combo === "Print", "no modifier");
assert(binds[0].category === "Display" && binds[0].action === "Open display switcher", "splits description at the first colon");
assert(binds.some(b => b.combo === "ALT + Right Click"), "mouse buttons are named");
assert(binds.some(b => b.combo === "SHIFT + Keycode 10"), "keycodes stay readable");

const groups = ctx.group(binds);
assert(groups.map(g => g.category).join(",") === "Display,Media,Shell,Utilities,Window", "categories sorted");
assert(groups.every(g => g.binds.length > 0), "no empty groups");

assert(ctx.filterBinds(groups, "close").length === 1, "filter by action");
assert(ctx.filterBinds(groups, "super + s")[0].category === "Window", "filter by combo, case-insensitive");
assert(ctx.filterBinds(groups, "resize")[0].category === "Window", "mouse bind is searchable by action");
assert(ctx.filterBinds(groups, "").length === groups.length, "empty query keeps everything");
assert(ctx.filterBinds(groups, "zzz").length === 0, "no matches yields no groups");

assert(ctx.parseBinds("not json").length === 0, "invalid json yields an empty list");

const withUnlabeled = ctx.parseBinds(raw, true);
assert(withUnlabeled.length === 8, "opt-in keeps undescribed binds");
assert(withUnlabeled.filter(b => b.category === "Unlabeled").length === 2, "undescribed binds get their own group");
assert(withUnlabeled.every(b => b.combo.length > 0), "binds without a key are always skipped");

// Workspace 1-10 are bound with `code:<n>` and Hyprland reports an empty key.
const numeric = JSON.stringify([
  { modmask: 64, key: "", description: "Workspace: Focus 1" },
  { modmask: 64, key: "", description: "Workspace: Focus 2" },
  { modmask: 64, key: "", description: "Workspace: Focus 10" },
  { modmask: 68, key: "Left", description: "Window: Focus Left" },
  { modmask: 68, key: "Right", description: "Window: Focus Right" },
  { modmask: 68, key: "Up", description: "Window: Focus Up" },
  { modmask: 64, key: "", description: "Unnumbered and keyless" }
]);
const collapsed = ctx.group(ctx.parseBinds(numeric));
const workspace = collapsed.find(g => g.category === "Workspace");
assert(workspace.binds.length === 1, "workspace 1-10 collapse to one row");
assert(workspace.binds[0].combo === "SUPER + <Number>", "collapsed workspace keeps the modifier");
assert(workspace.binds[0].keys.join(" ") === "⊞ <Number>", "collapsed workspace keycaps stay symbolic");
assert(workspace.binds[0].action === "Focus <Number>", "collapsed workspace action is generic");
const windowGroup = collapsed.find(g => g.category === "Window");
assert(windowGroup.binds.length === 3, "directions stay separate rows");
assert(windowGroup.binds.map(b => b.combo).sort().join(" | ") === "SUPER + CTRL + Left | SUPER + CTRL + Right | SUPER + CTRL + Up",
  "direction keys keep their names");

// Equivalent keys share one description, so they share one row.
const duplicates = JSON.stringify([
  { modmask: 64, key: "M", description: "Media: Toggle mute" },
  { modmask: 0, key: "XF86AudioMute", description: "Media: Toggle mute" },
  { modmask: 64, key: "N", description: "Media: Next track" }
]);
const merged = ctx.group(ctx.parseBinds(duplicates));
assert(merged[0].binds.length === 2, "equivalent keys merge into one row");
const mute = merged[0].binds.find(b => b.action === "Toggle mute");
assert(mute.combos.length === 2, "both key combos are kept on the row");
assert(mute.combo === "SUPER + M", "the first combo is the row default");
assert(ctx.filterBinds(merged, "xf86audiomute")[0].category === "Media", "search finds secondary combos");
assert(ctx.filterBinds(merged, "next track")[0].binds[0].combos.length === 1, "single-key rows still work");

console.log("keybinds_parse: all assertions passed");
