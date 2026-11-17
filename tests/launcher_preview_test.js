// Launcher preview-cache unit tests — run with `node tests/launcher_preview_test.js`
const fs = require("fs");
const vm = require("vm");

function assert(cond, msg) {
  if (!cond)
    throw new Error("FAIL: " + msg);
  console.log("  ok " + msg);
}

const ctx = { console, JSON, Map, Set, Array, Object, String, Number };
vm.createContext(ctx);
const source = fs
  .readFileSync(__dirname + "/../shell/modules/launcher/services/PreviewCache.js", "utf8")
  .replace(/^\.pragma library\s*$/m, "");
vm.runInContext(source, ctx);

const NOW = 1_700_000_000_000;
const row = (id, extra) => ({ id, name: id.toUpperCase(), comment: "", icon: "", ...extra });

// ── parse ────────────────────────────────────────────────────────────────────
{
  assert(ctx.parse("").rows.length === 0, "parse empty text yields no rows");
  assert(ctx.parse("{not json").rows.length === 0, "parse garbage yields no rows");
  assert(ctx.parse(JSON.stringify({ version: 9, rows: [row("a")] })).rows.length === 0, "parse ignores another cache version");
  assert(ctx.parse(JSON.stringify({ version: 1, rows: "nope" })).rows.length === 0, "parse rejects a non-array rows field");

  const parsed = ctx.parse(JSON.stringify({
    version: 1,
    savedAt: NOW,
    rows: [row("a"), { id: "" }, { name: "no id" }, row("a"), "junk", row("b", { name: 7, comment: 5, icon: null })]
  }));

  assert(parsed.rows.length === 2, "parse keeps only rows with an id, without duplicates");
  assert(parsed.savedAt === NOW, "parse keeps a numeric savedAt");
  assert(parsed.rows[0].id === "a" && parsed.rows[1].id === "b", "parse keeps row order");
  assert(parsed.rows[1].name === "b", "parse falls back to the id when the name is broken");
  assert(parsed.rows[1].comment === "" && parsed.rows[1].icon === "", "parse normalizes broken optional fields");
}

// ── serialize ───────────────────────────────────────────────────────────────
{
  const rows = [row("a"), row("b", { comment: "does things", icon: "foo" })];
  const state = ctx.parse(ctx.serialize(rows, NOW));
  assert(state.rows.length === 2 && state.savedAt === NOW, "serialize round-trips the rows and timestamp");
  assert(state.rows[1].comment === "does things" && state.rows[1].icon === "foo", "serialize keeps the display fields");
  assert(JSON.parse(ctx.serialize([{ id: "" }, row("c")], NOW)).rows.length === 1, "serialize drops unusable rows");
}

// ── merge ────────────────────────────────────────────────────────────────────
{
  const apps = ["a", "b", "c", "d"].map(id => ({ id }));

  assert(
    JSON.stringify(ctx.merge(apps, ["c", "a"]).map(a => a.id)) === '["c","a","b","d"]',
    "merge keeps the preview order first, then AppDb order"
  );

  assert(
    JSON.stringify(ctx.merge(apps, ["gone", "b"]).map(a => a.id)) === '["b","a","c","d"]',
    "merge skips preview ids that no longer exist"
  );

  assert(
    JSON.stringify(ctx.merge(apps, ["a", "a", "b"]).map(a => a.id)) === '["a","b","c","d"]',
    "merge ignores duplicate preview ids"
  );

  assert(
    JSON.stringify(ctx.merge(apps, []).map(a => a.id)) === '["a","b","c","d"]',
    "merge without a preview keeps AppDb order"
  );

  assert(ctx.merge([], ["a"]).length === 0, "merge with no apps yields nothing");
}

console.log("\nlauncher_preview: all assertions passed");
