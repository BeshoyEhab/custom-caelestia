// DisplayMath unit tests — run with `node tests/display_math_test.js`
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
  .readFileSync(__dirname + "/../shell/services/DisplayMath.js", "utf8")
  .replace(/^\.pragma library\s*$/m, "");
vm.runInContext(source, ctx);

const m = over => ({
  name: "eDP-1",
  width: 1920,
  height: 1200,
  x: 0,
  y: 0,
  scale: 1,
  refresh: 60,
  disabled: false,
  mirrorOf: "none",
  modes: [],
  ...over
});

assert(ctx.detectMode([m()], "eDP-1") === "single", "single");
assert(ctx.detectMode([m(), m({ name: "HDMI-A-1", x: 1920 })], "eDP-1") === "extend", "extend");
assert(ctx.detectMode([m(), m({ name: "HDMI-A-1", mirrorOf: "eDP-1" })], "eDP-1") === "duplicate", "duplicate");
assert(ctx.detectMode([m({ id: 0 }), m({ name: "HDMI-A-1", mirrorOf: "0" })], "eDP-1") === "duplicate", "duplicate by monitor id");
assert(ctx.detectMode([m({ disabled: true }), m({ name: "HDMI-A-1", x: 0 })], "eDP-1") === "second", "second only");
assert(ctx.detectMode([m(), m({ name: "HDMI-A-1", disabled: true })], "eDP-1") === "main", "main only");

const right = ctx.layout({
  main: m(),
  all: [m(), m({ name: "HDMI-A-1", width: 2560, height: 1440 })],
  mode: "extend",
  placement: "right"
});
assert(right.find(r => r.output === "HDMI-A-1").position === "1920x0", "right placement");

const left = ctx.layout({
  main: m(),
  all: [m(), m({ name: "HDMI-A-1", width: 2560, height: 1440 })],
  mode: "extend",
  placement: "left"
});
assert(left.find(r => r.output === "HDMI-A-1").position === "-2560x0", "left placement uses logical width");

const top = ctx.layout({
  main: m(),
  all: [m(), m({ name: "HDMI-A-1", width: 2560, height: 1440 })],
  mode: "extend",
  placement: "top"
});
assert(top.find(r => r.output === "HDMI-A-1").position === "0x-1440", "top placement");

const bottom = ctx.layout({
  main: m(),
  all: [m(), m({ name: "HDMI-A-1" })],
  mode: "extend",
  placement: "bottom"
});
assert(bottom.find(r => r.output === "HDMI-A-1").position === "0x1200", "bottom placement");

const dup = ctx.layout({ main: m(), all: [m(), m({ name: "HDMI-A-1" })], mode: "duplicate" });
assert(dup.find(r => r.output === "HDMI-A-1").mirror === "eDP-1", "duplicate mirrors main");

const only = ctx.layout({ main: m(), all: [m(), m({ name: "HDMI-A-1" })], mode: "main" });
assert(only.find(r => r.output === "HDMI-A-1").disabled === true, "main-only disables the other");
assert(only.find(r => r.output === "eDP-1").disabled !== true, "main-only keeps main enabled");

const second = ctx.layout({ main: m(), all: [m(), m({ name: "HDMI-A-1" })], mode: "second" });
assert(second.find(r => r.output === "eDP-1").disabled === true, "second-only disables main");
assert(second.find(r => r.output === "HDMI-A-1").position === "0x0", "second-only moves secondary to origin");

const sole = ctx.layout({ main: m(), all: [m()], mode: "main" });
assert(sole.length === 1 && sole[0].disabled !== true, "one monitor: never disables the last output");

assert(
  ctx.luaMonitor({ output: "HDMI-A-1", mode: "1920x1080@60.00", position: "1920x0", scale: 1, mirror: "eDP-1" }) ===
    'hl.monitor({\n    output = "HDMI-A-1",\n    mode = "1920x1080@60.00",\n    position = "1920x0",\n    scale = 1,\n    mirror = "eDP-1"\n})',
  "lua monitor block"
);
assert(
  ctx.luaMonitor({ output: "HDMI-A-1", disabled: true }) ===
    'hl.monitor({\n    output = "HDMI-A-1",\n    disabled = true\n})',
  "lua disable block"
);
assert(
  ctx.luaWorkspace({ workspace: 2, monitor: "HDMI-A-1", isDefault: true }) ===
    'hl.workspace_rule({\n    workspace = "2",\n    monitor = "HDMI-A-1",\n    default = true\n})',
  "lua workspace block"
);
assert(
  ctx.luaWorkspace({ workspace: 3, monitor: "HDMI-A-1" }) ===
    'hl.workspace_rule({\n    workspace = "3",\n    monitor = "HDMI-A-1"\n})',
  "lua workspace block without default"
);

const parsed = ctx.parseWorkspaceRules(
  'hl.workspace_rule({\n    workspace = "2",\n    monitor = "HDMI-A-1",\n    default = true\n})'
);
assert(
  parsed.length === 1 && parsed[0].workspace === 2 && parsed[0].monitor === "HDMI-A-1" && parsed[0].isDefault,
  "parse workspace rules"
);
const merged = ctx.mergeWorkspaceRule(parsed, { workspace: 2, monitor: "DP-1", isDefault: true });
assert(merged.length === 1 && merged[0].monitor === "DP-1", "replaces the rule for the same workspace");
assert(ctx.mergeWorkspaceRule([], { workspace: 3, monitor: "DP-1" }).length === 1, "appends a new rule");
const repinned = ctx.mergeWorkspaceRule(
  [{ workspace: 2, monitor: "HDMI-A-1", isDefault: true }, { workspace: 7, monitor: "eDP-1", isDefault: true }],
  { workspace: 3, monitor: "HDMI-A-1", isDefault: true }
);
assert(repinned.length === 2, "repinning drops the old default for that monitor");
assert(repinned.every(r => !(r.monitor === "HDMI-A-1" && r.workspace === 2)), "old workspace no longer pinned");

assert(ctx.pickMain([m({ x: 1920 }), m({ name: "HDMI-A-1", x: 0 })], null) === "HDMI-A-1", "picks the monitor at origin");
assert(
  ctx.pickMain([m({ x: 1920 }), m({ name: "HDMI-A-1", x: 0 })], "eDP-1") === "eDP-1",
  "preferred main wins over the origin monitor"
);
assert(ctx.pickMain([m()], "GONE-1") === "eDP-1", "preferred main falls back when absent");
assert(
  ctx.pickMain([m({ disabled: true }), m({ name: "HDMI-A-1", x: 0 })], "eDP-1") === "eDP-1",
  "preferred main survives being switched off"
);

const healed = ctx.healRules([m(), m({ name: "HDMI-A-1", width: 2560, height: 1440 })]);
assert(healed.length === 2, "heal keeps every monitor");
assert(healed.every(r => !r.disabled), "heal never disables");
assert(healed[1].position === "1920x0", "heal lays out left to right");
assert(ctx.healRules([m({ width: 0, height: 0 })])[0].mode === "preferred", "heal falls back to preferred when the mode is unknown");
assert(
  ctx.healRules([m(), { name: "HEADLESS-1", width: 1920, height: 1080, x: 0, y: 0, scale: 1 }]).length === 1,
  "heal prefers the real panel over virtual outputs"
);

const fake = { name: "HEADLESS-1", width: 1920, height: 1080 };
assert(
  ctx.keepsAPhysicalOutput(
    [{ output: "eDP-1", disabled: true }, { output: "HEADLESS-1", mode: "1920x1080@60.00" }],
    [m(), fake]
  ) === false,
  "refuses a layout that leaves only a virtual output on"
);
assert(
  ctx.keepsAPhysicalOutput([{ output: "eDP-1", mode: "1920x1200@60.00" }], [m(), fake]) === true,
  "physical output on is allowed"
);
assert(
  ctx.keepsAPhysicalOutput([{ output: "HEADLESS-1", mode: "1920x1080@60.00" }], [fake]) === true,
  "virtual-only machines are not blocked"
);
assert(
  ctx.keepsAPhysicalOutput(
    [{ output: "FALLBACK", mode: "1920x1080@60.00" }],
    [m(), { name: "FALLBACK", width: 1920, height: 1080 }]
  ) === false,
  "Hyprland's FALLBACK output counts as virtual"
);

console.log("display_math: all assertions passed");
