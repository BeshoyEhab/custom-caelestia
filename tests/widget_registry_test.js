const fs = require("fs");
const vm = require("vm");

function assert(cond, msg) {
  if (!cond) throw new Error("FAIL: " + msg);
  console.log("  ok " + msg);
}

const ctx = { console };
vm.createContext(ctx);
vm.runInContext(
  fs.readFileSync(__dirname + "/../shell/modules/widgets/WidgetRegistry.js", "utf8").replace(/^\.pragma library\s*$/m, ""),
  ctx,
);

const ids = ctx.registry().map(w => w.id);
for (const id of ["logo", "workspaces", "activeWindow", "tray", "clock", "statusIcons", "power", "spacer", "separator", "group"])
  assert(ids.includes(id), `registry has ${id}`);
assert(ctx.registry().filter(w => w.category === "helper").length === 3, "exactly three helpers");
assert(ctx.get("clock").category === "widget", "clock is a widget");
assert(ctx.get("spacer").category === "helper", "spacer is a helper");
assert(ctx.get("group").allowHelpers === true, "group accepts children");
assert(ctx.get("statusIcons").compositeOf.includes("battery"), "statusIcons declares its leaves");
assert(ctx.get("nope") === null, "unknown id returns null");

// Helper roles and capabilities: the contract later plans rely on.
assert(ctx.get("spacer").role === "structure", "spacer is a structural helper");
assert(ctx.get("separator").role === "decoration", "separator is a decoration helper");
assert(ctx.get("group").role === "structure", "group is a structural helper");
assert(ctx.get("clock").role === null, "widgets have no helper role");
for (const w of ctx.registry()) {
  assert(typeof w.wantsFocus === "boolean", `${w.id} declares wantsFocus`);
  assert(typeof w.ownsPopover === "boolean", `${w.id} declares ownsPopover`);
  assert(Number.isFinite(w.minSize.width) && Number.isFinite(w.minSize.height), `${w.id} declares minSize`);
}
assert(ctx.registry().every(w => w.wantsFocus === false), "no dock widget requests focus");
assert(
  ctx.registry().filter(w => w.ownsPopover).map(w => w.id).sort().join(",") === "activeWindow,power,statusIcons,tray,workspaces",
  "popover owners are exactly the widgets that raise a popout today",
);

// Migration from Config.bar.entries. This is the shipped default list.
const entries = [
  { id: "logo", enabled: true }, { id: "workspaces", enabled: true },
  { id: "spacer", enabled: true }, { id: "activeWindow", enabled: true },
  { id: "spacer", enabled: true }, { id: "tray", enabled: true },
  { id: "clock", enabled: true }, { id: "statusIcons", enabled: true },
  { id: "power", enabled: true },
];
assert(ctx.fromBarEntries(entries, "start").map(i => i.type).join(",") === "logo,workspaces", "start keeps logo+workspaces");
assert(ctx.fromBarEntries(entries, "center").map(i => i.type).join(",") === "activeWindow", "center keeps activeWindow");
assert(ctx.fromBarEntries(entries, "end").map(i => i.type).join(",") === "tray,clock,statusIcons,power", "end keeps four widgets in order");
assert(ctx.fromBarEntries(entries, "end").every(i => i.type !== "spacer"), "spacers are not migrated");
assert(ctx.fromBarEntries([{ id: "nope" }, { id: "clock" }], "end").map(i => i.type).join(",") === "clock", "unknown entry skipped");
assert(ctx.fromBarEntries([{ id: "clock", enabled: false }], "end")[0].enabled === false, "enabled flag preserved");
assert(ctx.fromBarEntries([{ id: "clock" }, { id: "clock" }], "end").map(i => i.instance).join(",") === "clock,clock-2", "duplicate entries get unique instances");
assert(ctx.fromBarEntries(undefined, "end").length === 0, "missing entries -> empty list");

// Validation
const v = ctx.validateItems([{ type: "clock" }, { type: "nope" }, { type: "clock" }], {});
assert(v.ok === false, "invalid layout is not ok");
assert(v.items.length === 1 && v.items[0].type === "clock", "unknown and duplicate dropped");
assert(v.errors.some(e => e.includes("nope")), "error names the unknown type");
assert(v.errors.some(e => /duplicate/i.test(e)), "error mentions the duplicate");
assert(ctx.validateItems(null).items.length === 0, "null input -> no items");
assert(ctx.validateItems([]).ok === true, "empty layout is valid");
assert(ctx.visibleItems([{ type: "clock" }, { type: "nope" }, { type: "tray" }]).map(i => i.type).join(",") === "clock,tray", "visibleItems drops unknown");

const group = n => n === 0 ? { type: "group", children: [] } : { type: "group", children: [group(n - 1)] };
assert(ctx.validateItems([group(ctx.MAX_DEPTH)]).ok === true, "nesting at MAX_DEPTH is accepted");
assert(ctx.validateItems([group(ctx.MAX_DEPTH + 1)]).ok === false, "nesting past MAX_DEPTH is rejected");
assert(ctx.validateItems([group(ctx.MAX_DEPTH + 1)]).errors.some(e => /depth/i.test(e)), "depth error is reported");

// Defaults and ids
assert(ctx.nextInstanceId("clock", []) === "clock", "first instance is the type");
assert(ctx.nextInstanceId("clock", [{ instance: "clock" }]) === "clock-2", "second instance gets -2");
assert(ctx.nextInstanceId("clock", [{ instance: "clock" }, { instance: "clock-2" }]) === "clock-3", "third instance gets -3");
assert(ctx.normalizeItem({ type: "clock" }).instance === "clock", "normalize fills the instance");
assert(ctx.normalizeItem({ type: "clock", enabled: false }).enabled === false, "normalize keeps enabled");

// Catalog coverage: every registry id must be reachable in QML.
const catalog = fs.readFileSync(__dirname + "/../shell/modules/widgets/WidgetCatalog.qml", "utf8");
for (const w of ctx.registry())
  assert(new RegExp(`case "${w.id}":`).test(catalog), `catalog maps ${w.id}`);
assert(/default:\s*return null/.test(catalog), "catalog returns null for unknown types");
for (const f of ["Spacer", "Separator", "Group"])
  assert(fs.existsSync(__dirname + `/../shell/modules/widgets/helpers/${f}.qml`), `${f} helper exists`);
for (const f of ["DockLogo", "DockWorkspaces", "DockActiveWindow", "DockTray", "DockClock", "DockStatusIcons", "DockPower"])
  assert(fs.existsSync(__dirname + `/../shell/modules/widgets/builtin/${f}.qml`), `${f} adapter exists`);

// The switch must return a distinct, declared component per id, not just name it.
const cases = [...catalog.matchAll(/case "(\w+)":\s*return (\w+);/g)].map(m => [m[1], m[2]]);
assert(cases.length === ctx.registry().length, "catalog has one case per registry id");
assert(new Set(cases.map(c => c[1])).size === cases.length, "every widget maps to its own component");
for (const [id, comp] of cases)
  assert(new RegExp(`id: ${comp}\\b`).test(catalog), `${id} maps to a declared component`);
