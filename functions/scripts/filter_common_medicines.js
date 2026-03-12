const fs = require("fs");
const path = require("path");

// Usage:
// node scripts/filter_common_medicines.js <input.json> <output.json> [limit]
//
// Heuristic "common" filter:
// - Is_discontinued == "FALSE"
// - type == "allopathy" (if present)
// - name and short_composition1 present
// Then take first N sorted by name.

const inputPath = process.argv[2];
const outputPath = process.argv[3];
const limit = parseInt(process.argv[4] || "5000", 10);

if (!inputPath || !outputPath) {
  console.error(
    "Usage: node scripts/filter_common_medicines.js <input.json> <output.json> [limit]"
  );
  process.exit(1);
}

const inAbs = path.resolve(process.cwd(), inputPath);
const outAbs = path.resolve(process.cwd(), outputPath);

const raw = fs.readFileSync(inAbs, "utf8");
const rows = JSON.parse(raw);
if (!Array.isArray(rows)) {
  console.error("Input must be a JSON array.");
  process.exit(1);
}

const forcedKeywords = ["aspirin", "paracetamol", "dolo"];
const forcedKeywordRegexes = forcedKeywords.map(
  (k) => new RegExp(`\\b${k}\\b`, "i")
);

const filtered = rows.filter((r) => {
  const name = String(r.name || "").trim();
  const comp1 = String(r.short_composition1 || "").trim();
  const isDisc = String(r.Is_discontinued || "").toUpperCase();
  const type = String(r.type || "").toLowerCase();
  if (!name || !comp1) return false;
  if (isDisc && isDisc !== "FALSE") return false;
  if (type && type !== "allopathy") return false;
  return true;
});

// Force-include any medicine that contains key keywords in name or composition.
const forced = rows.filter((r) => {
  const name = String(r.name || "");
  const comp1 = String(r.short_composition1 || "");
  const comp2 = String(r.short_composition2 || "");
  return forcedKeywordRegexes.some(
    (rx) => rx.test(name) || rx.test(comp1) || rx.test(comp2)
  );
});

filtered.sort((a, b) =>
  String(a.name || "").localeCompare(String(b.name || ""))
);

const combined = [...forced, ...filtered];

// Deduplicate by name + composition
const seen = new Set();
const deduped = [];
for (const r of combined) {
  const key = `${r.name}|${r.short_composition1}|${r.short_composition2}`;
  if (seen.has(key)) continue;
  seen.add(key);
  deduped.push(r);
}

let sliced = deduped.slice(0, limit);

// Ensure at least one entry for each forced keyword (e.g. "dolo")
for (const rx of forcedKeywordRegexes) {
  const match = rows.find((r) => {
    const name = String(r.name || "");
    const comp1 = String(r.short_composition1 || "");
    const comp2 = String(r.short_composition2 || "");
    return rx.test(name) || rx.test(comp1) || rx.test(comp2);
  });
  if (!match) continue;
  sliced.unshift(match);
}

// Final dedupe + trim after forced inserts.
const finalSeen = new Set();
const finalList = [];
for (const r of sliced) {
  const key = `${r.name}|${r.short_composition1}|${r.short_composition2}`;
  if (finalSeen.has(key)) continue;
  finalSeen.add(key);
  finalList.push(r);
  if (finalList.length >= limit) break;
}

const output = finalList.map((r) => ({
  name: String(r.name || "").trim(),
  short_composition1: String(r.short_composition1 || "").trim(),
  short_composition2: String(r.short_composition2 || "").trim(),
}));

fs.writeFileSync(outAbs, JSON.stringify(output));
console.log(`Wrote ${output.length} records to ${outAbs}`);
