// Launcher order-cache unit tests — run with `node tests/launcher_order_test.js`
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
  .readFileSync(__dirname + "/../shell/modules/launcher/services/OrderCache.js", "utf8")
  .replace(/^\.pragma library\s*$/m, "");
vm.runInContext(source, ctx);

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const NOW = 1_700_000_000_000;

const app = id => ({ id, entry: { marker: id } });
const ids = list => list.map(item => item.id);

// ── parse ────────────────────────────────────────────────────────────────────
{
  const empty = ctx.parse("");
  assert(empty.ids.length === 0 && empty.savedAt === 0, "parse empty text yields an empty state");

  const broken = ctx.parse("{not json");
  assert(broken.ids.length === 0, "parse garbage yields an empty state");

  const wrongShape = ctx.parse(JSON.stringify({ version: 1, ids: "nope", savedAt: "x" }));
  assert(wrongShape.ids.length === 0 && wrongShape.savedAt === 0, "parse rejects wrongly typed fields");

  const wrongVersion = ctx.parse(JSON.stringify({ version: 99, ids: ["a"], savedAt: NOW }));
  assert(wrongVersion.ids.length === 0, "parse ignores another cache version");

  const ok = ctx.parse(JSON.stringify({
    version: 1,
    savedAt: NOW,
    favourites: ["a", 3],
    ids: ["b", "", 7, "a"]
  }));
  assert(ok.savedAt === NOW, "parse keeps a numeric savedAt");
  assert(JSON.stringify(ok.ids) === '["b","a"]', "parse drops non-string and empty ids");
  assert(JSON.stringify(ok.favourites) === '["a"]', "parse drops non-string favourites");
}

// ── serialize/parse round trip ───────────────────────────────────────────────
{
  const text = ctx.serialize(["a", "b"], ["b"], NOW);
  const state = ctx.parse(text);
  assert(JSON.stringify(state.ids) === '["a","b"]' && state.savedAt === NOW, "serialize round-trips ids and timestamp");
  assert(JSON.stringify(state.favourites) === '["b"]', "serialize round-trips favourites");
}

// ── merge ────────────────────────────────────────────────────────────────────
{
  const apps = ["a", "b", "c"].map(app);

  assert(JSON.stringify(ids(ctx.merge(apps, ["c", "a", "b"]))) === '["c","a","b"]', "merge follows the cached order");

  assert(
    JSON.stringify(ids(ctx.merge(apps, ["c"]))) === '["c","a","b"]',
    "merge appends apps the cache has never seen, in AppDb order"
  );

  assert(
    JSON.stringify(ids(ctx.merge(apps, ["gone", "b"]))) === '["b","a","c"]',
    "merge skips cached ids that no longer exist"
  );

  assert(
    JSON.stringify(ids(ctx.merge(apps, ["b", "b", "c"]))) === '["b","c","a"]',
    "merge ignores duplicate ids in the cache"
  );

  assert(JSON.stringify(ids(ctx.merge(apps, []))) === '["a","b","c"]', "merge without a cache keeps AppDb order");
  assert(ctx.merge([], ["a"]).length === 0, "merge with no apps yields nothing");
}

// ── needsRefresh ─────────────────────────────────────────────────────────────
{
  const apps = ["a", "b", "c"].map(app);
  const cached = { ids: ["c", "b", "a"], favourites: [], savedAt: NOW - HOUR };

  assert(ctx.needsRefresh(cached, apps, [], NOW, DAY) === false, "keeps a fresh cache with the same app set");

  assert(
    ctx.needsRefresh({ ...cached, savedAt: 0 }, apps, [], NOW, DAY) === true,
    "rewrites when there is no cache yet"
  );

  assert(
    ctx.needsRefresh(cached, apps, [], NOW + DAY + 1, DAY) === true,
    "rewrites once the cache is older than the refresh window"
  );

  assert(
    ctx.needsRefresh(cached, ["a", "b", "c", "d"].map(app), [], NOW, DAY) === true,
    "rewrites when an app is added"
  );

  assert(
    ctx.needsRefresh(cached, ["a", "b"].map(app), [], NOW, DAY) === true,
    "rewrites when an app is removed"
  );

  // The whole point: AppDb re-sorts on every launch, and that alone must not
  // rewrite the cache or the order would change under a stable file.
  assert(
    ctx.needsRefresh(cached, ["a", "b", "c"].map(app), [], NOW, DAY) === false,
    "ignores a pure frequency reorder"
  );

  assert(
    ctx.needsRefresh(cached, apps, ["a"], NOW, DAY) === true,
    "rewrites when favourites change"
  );

  assert(
    ctx.needsRefresh({ ...cached, favourites: ["a"] }, apps, ["a"], NOW, DAY) === false,
    "keeps the cache when favourites still match"
  );

  assert(
    ctx.needsRefresh(cached, [], [], NOW, DAY) === false,
    "never rewrites from an empty app DB"
  );
}

console.log("\nlauncher_order: all assertions passed");
