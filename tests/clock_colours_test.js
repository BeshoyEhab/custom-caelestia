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

// Real values from the dynamic dark scheme this bug was reported on. The face
// is the primary *container* (the large-surface role); the accent primary is
// reserved for the hands, exactly as Material 3 and the reference clock do.
const face = "#764548";
const onFace = "#ffdbdc";
const tertiaryContainer = { background: "#f3c3ea", foreground: "#5f3b5b" };
const secondaryContainer = { background: "#503436", foreground: "#deb5b7" };
const primaryContainer = { background: "#764548", foreground: "#ffdbdc" };
const tertiary = { background: "#ffd2f6", foreground: "#694464" };
const secondary = { background: "#e6bdbe", foreground: "#55393a" };
const surfaceHigh = { background: "#281d1d", foreground: "#f8e0e0" };

near(ctx.contrast("#000000", "#ffffff"), 21, 0.1, "black on white is 21:1");
near(ctx.contrast(face, face), 1, 0.001, "a colour against itself is 1:1");
near(ctx.contrast(face, onFace), 6.05, 0.05, "onPrimaryContainer passes on the container face");

// Mixing: weight is the share of the first colour, matching end-4's
// ColorUtils.mix (1 = all colour1, 0 = all colour2).
assert(ctx.mix("#ffffff", "#000000", 0.5) === "#808080", "half white + half black is mid grey");
assert(ctx.mix("#ffffff", "#000000", 1) === "#ffffff", "weight 1 keeps colour1");
assert(ctx.mix("#ffffff", "#000000", 0) === "#000000", "weight 0 keeps colour2");
assert(ctx.mix("#f7b6b9", "#764548", 0.55) === "#bd8386", "digits are a primary/container mid-tone");
assert(ctx.mix("#e6bdbe", "#764548", 0.15) === "#87575a", "dial marks are a secondary-tinted container");

// The pale tertiary container pops on the container face; the day badge takes
// it, and the month badge avoids repeating it.
const day = ctx.pickBadge(face, onFace, [tertiaryContainer, secondaryContainer, primaryContainer, surfaceHigh], [], 3, 4.5);
assert(day.background === tertiaryContainer.background, "day badge uses the first pair that reads on the face");
assert(day.foreground === tertiaryContainer.foreground, "day badge keeps its matching on-colour");

// The month badge must not repeat the day badge when another pair passes.
const month = ctx.pickBadge(face, onFace, [secondaryContainer, tertiaryContainer, secondary, tertiary, primaryContainer, surfaceHigh], [day.background], 3, 4.5);
assert(month.background === secondary.background, "month badge avoids the used background");
assert(month.foreground === secondary.foreground, "month badge uses its own on-colour");

// No candidate clears the bar: invert the face pair instead of shipping an
// unreadable badge.
const flat = [{ background: "#6b4042", foreground: "#ffdbdc" }, { background: "#815154", foreground: "#ffe4e5" }];
const fallback = ctx.pickBadge(face, onFace, flat, [], 3, 4.5);
assert(fallback.background === onFace, "fallback badge uses the face on-colour as background");
assert(fallback.foreground === face, "fallback badge uses the face colour as text");

// Even with every distinct pair used, a passing pair is better than nothing.
const reused = ctx.pickBadge(face, onFace, [secondary], [secondary.background], 3, 4.5);
assert(reused.background === secondary.background, "a single passing pair is reused when nothing else passes");

// QML colors are objects with 0..1 channels: accepting both shapes keeps the
// helper usable from QML and from node.
const qmlFace = { r: 0.463, g: 0.271, b: 0.282 };
near(ctx.contrast(qmlFace, "#ffdbdc"), ctx.contrast(face, "#ffdbdc"), 0.1, "QML colour objects are accepted");

console.log("clock_colours: all assertions passed");
