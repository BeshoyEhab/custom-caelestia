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

assert(ctx.parseBinds("not json") .length === 0, "invalid json yields an empty list");

console.log("keybinds_parse: all assertions passed");
