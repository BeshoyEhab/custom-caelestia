// Clock position math unit tests — run with `node tests/clock_position_test.js`
const fs = require("fs");
const vm = require("vm");

function assert(cond, msg) {
  if (!cond)
    throw new Error("FAIL: " + msg);
  console.log("  ok " + msg);
}

function assertDeep(actual, expected, msg) {
  const a = JSON.stringify(actual);
  const e = JSON.stringify(expected);
  if (a !== e)
    throw new Error(`FAIL: ${msg}: expected ${e}, got ${a}`);
  console.log("  ok " + msg);
}

const ctx = { console };
vm.createContext(ctx);
const source = fs
  .readFileSync(__dirname + "/../shell/modules/background/ClockPosition.js", "utf8")
  .replace(/^\.pragma library\s*$/m, "");
vm.runInContext(source, ctx);

const ins = { left: 20, right: 30, top: 40, bottom: 50 };

assert(ctx.isAuto("auto-empty") === true, "auto-empty is auto");
assert(ctx.isAuto("auto-full") === true, "auto-full is auto");
assert(ctx.isAuto("bottom-right") === false, "a preset is not auto");

assertDeep(ctx.preset("bottom-right", 1920, 1080, 300, 200, ins), { x: 1590, y: 830 }, "bottom-right respects right/bottom insets");
assertDeep(ctx.preset("top-left", 1920, 1080, 300, 200, ins), { x: 20, y: 40 }, "top-left respects left/top insets");
assertDeep(ctx.preset("top-center", 1920, 1080, 300, 200, ins), { x: 810, y: 40 }, "top-center centres horizontally");
assertDeep(ctx.preset("middle-left", 1920, 1080, 300, 200, ins), { x: 20, y: 440 }, "middle-left centres vertically");
assertDeep(ctx.preset("middle-center", 1920, 1080, 300, 200, ins), { x: 810, y: 440 }, "middle-center ignores insets");

assertDeep(ctx.fromCenter(0, 0, 1920, 1080, 300, 200, ins), { x: 20, y: 40 }, "fromCenter clamps to the top-left inset");
assertDeep(ctx.fromCenter(1920, 1080, 1920, 1080, 300, 200, ins), { x: 1590, y: 830 }, "fromCenter clamps to the bottom-right inset");
assertDeep(ctx.fromCenter(960, 540, 1920, 1080, 300, 200, ins), { x: 810, y: 440 }, "fromCenter centres an unclamped box");

assertDeep(ctx.clampOffset(9999, -999, 100, 100, 300, 200, 1920, 1080, ins), { dx: 1490, dy: -60 }, "clampOffset clamps both axes");
assertDeep(ctx.clampOffset(10, 20, 100, 100, 300, 200, 1920, 1080, ins), { dx: 10, dy: 20 }, "clampOffset leaves an inside offset alone");

console.log("clock_position: all assertions passed");
