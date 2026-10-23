// Clock colour pairing unit tests — run with `node tests/clock_colours_test.js`
const fs = require("fs");
const vm = require("vm");

function assert(cond, msg) {
  if (!cond)
    throw new Error("FAIL: " + msg);
  console.log("  ok " + msg);
}

function near(actual, expected, tolerance, msg) {
  if (Math.abs(actual - expected) > tolerance)
    throw new Error(`FAIL: ${msg}: expected ~${expected}, got ${actual}`);
  console.log("  ok " + msg);
}

const ctx = { console };
vm.createContext(ctx);
const source = fs
  .readFileSync(__dirname + "/../shell/modules/background/ClockColours.js", "utf8")
  .replace(/^\.pragma library\s*$/m, "");
vm.runInContext(source, ctx);

// Real values from the dynamic dark scheme this bug was reported on.
const face = "#f7b6b9";
const onFace = "#603337";
const tertiaryContainer = { background: "#f3c3ea", foreground: "#5f3b5b" };
const secondaryContainer = { background: "#503436", foreground: "#deb5b7" };
const primaryContainer = { background: "#764548", foreground: "#ffdbdc" };
const tertiary = { background: "#ffd2f6", foreground: "#694464" };
const secondary = { background: "#e6bdbe", foreground: "#55393a" };
const surfaceHigh = { background: "#281d1d", foreground: "#f8e0e0" };

near(ctx.contrast("#000000", "#ffffff"), 21, 0.1, "black on white is 21:1");
near(ctx.contrast(face, face), 1, 0.001, "a colour against itself is 1:1");
near(ctx.contrast(face, onFace), 6.09, 0.05, "onPrimary passes on the cookie face");

// The day bubble skips tertiaryContainer (invisible on the face) and uses the
// first pair that clears both thresholds.
const day = ctx.pickBadge(face, onFace, [tertiaryContainer, secondaryContainer, primaryContainer, surfaceHigh], [], 3, 4.5);
assert(day.background === secondaryContainer.background, "day badge skips a low-contrast container");
assert(day.foreground === secondaryContainer.foreground, "day badge keeps its matching on-colour");

// The month badge must not repeat the day badge when another pair passes.
const month = ctx.pickBadge(face, onFace, [secondaryContainer, tertiaryContainer, tertiary, secondary, primaryContainer, surfaceHigh], [day.background], 3, 4.5);
assert(month.background === primaryContainer.background, "month badge avoids the used background");
assert(month.foreground === primaryContainer.foreground, "month badge uses its own on-colour");

// No candidate clears the bar: invert the face pair instead of shipping an
// unreadable badge.
const pale = [{ background: "#f3c3ea", foreground: "#5f3b5b" }, { background: "#e6bdbe", foreground: "#55393a" }];
const fallback = ctx.pickBadge(face, onFace, pale, [], 3, 4.5);
assert(fallback.background === onFace, "fallback badge uses the face on-colour as background");
assert(fallback.foreground === face, "fallback badge uses the face colour as text");

// Even with every distinct pair used, a passing pair is better than nothing.
const reused = ctx.pickBadge(face, onFace, [secondaryContainer], [secondaryContainer.background], 3, 4.5);
assert(reused.background === secondaryContainer.background, "a single passing pair is reused when nothing else passes");

// QML colors are objects with 0..1 channels: accepting both shapes keeps the
// helper usable from QML and from node.
const qmlFace = { r: 0.969, g: 0.714, b: 0.725 };
near(ctx.contrast(qmlFace, "#603337"), ctx.contrast(face, "#603337"), 0.1, "QML colour objects are accepted");

console.log("clock_colours: all assertions passed");
