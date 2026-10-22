// Overview math unit tests — run with `node tests/overview_math_test.js`
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
  .readFileSync(__dirname + "/../shell/modules/workspaceoverview/OverviewMath.js", "utf8")
  .replace(/^\.pragma library\s*$/m, "");
vm.runInContext(source, ctx);

const win = over => ({
  address: "0x1",
  wsId: 1,
  title: "",
  winClass: "",
  posX: 0,
  posY: 0,
  ...over
});

const windows = [
  win({ address: "0xa", wsId: 2, title: "cat pictures", winClass: "kitty", posY: 100, posX: 900 }),
  win({ address: "0xb", wsId: 1, title: "custom-caelestia — nvim", winClass: "kitty", posY: 300, posX: 10 }),
  win({ address: "0xc", wsId: 1, title: "YouTube", winClass: "brave-browser", posY: 100, posX: 600 }),
  win({ address: "0xd", wsId: 2, title: "cat videos", winClass: "firefox", posY: 20, posX: 100 })
];

assert(ctx.normalize("  Kitty ").length === 5 && ctx.normalize("  Kitty ") === "kitty", "query is trimmed and lowercased");
assert(ctx.matches(windows[0], "CAT"), "title match is case-insensitive");
assert(ctx.matches(windows[0], "kitty"), "app class matches");
assert(ctx.matches(windows[0], "cat kitty"), "every term must match");
assert(!ctx.matches(windows[0], "cat firefox"), "a term with no hit rejects the window");
assert(ctx.matches(windows[0], ""), "empty query matches everything");
assert(ctx.matches(windows[0], "   "), "whitespace query matches everything");

assert(ctx.orderedMatches(windows, "").join(",") === "0xc,0xb,0xd,0xa", "reading order: workspace, row, column");
const cats = ctx.orderedMatches(windows, "cat");
assert(cats.join(",") === "0xd,0xa", "filtered matches keep reading order");
assert(ctx.orderedMatches(windows, "zzz").length === 0, "no match yields an empty list");

assert(ctx.pageOffsetFor(1, 10) === 0, "workspace 1 is on page 1");
assert(ctx.pageOffsetFor(10, 10) === 0, "workspace 10 is still page 1");
assert(ctx.pageOffsetFor(11, 10) === 10, "workspace 11 starts page 2");
assert(ctx.pageOffsetFor(23, 10) === 20, "workspace 23 is on page 3");
assert(ctx.pageOffsetFor(0, 10) === 0, "workspace 0 clamps to page 1");
assert(ctx.pageCount(1, 10) === 1, "one page for a single workspace");
assert(ctx.pageCount(10, 10) === 1, "exactly one page of ten");
assert(ctx.pageCount(11, 10) === 2, "eleven workspaces need two pages");
assert(ctx.pageCount(24, 10) === 3, "twenty-four workspaces need three pages");
assert(ctx.clampPageOffset(20, 10, 12) === 10, "clamps past the last page");
assert(ctx.clampPageOffset(-10, 10, 12) === 0, "clamps before the first page");
assert(ctx.clampPageOffset(15, 10, 30) === 10, "snaps an offset to its page");

const ordered = ["0xa", "0xb", "0xc"];
assert(ctx.stepAddress(ordered, "0xa", 1) === "0xb", "next match");
assert(ctx.stepAddress(ordered, "0xc", 1) === "0xa", "next wraps around");
assert(ctx.stepAddress(ordered, "0xa", -1) === "0xc", "previous wraps around");
assert(ctx.stepAddress(ordered, "gone", 1) === "0xa", "forward from no selection picks the first");
assert(ctx.stepAddress(ordered, "gone", -1) === "0xc", "backward from no selection picks the last");
assert(ctx.stepAddress([], "0xa", 1) === "", "empty match list selects nothing");

console.log("overview_math: all assertions passed");
