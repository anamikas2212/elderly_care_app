const fs = require("fs");
const path = require("path");

// Usage:
// node scripts/convert_medicine_json.js <input.json> <output.json>
// Keeps only: name, short_composition1, short_composition2

const inputPath = process.argv[2];
const outputPath = process.argv[3];

if (!inputPath || !outputPath) {
  console.error("Usage: node scripts/convert_medicine_json.js <input.json> <output.json>");
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

const cleaned = rows.map((r) => ({
  name: String(r.name || "").trim(),
  short_composition1: String(r.short_composition1 || "").trim(),
  short_composition2: String(r.short_composition2 || "").trim(),
}));

fs.writeFileSync(outAbs, JSON.stringify(cleaned));
console.log(`Wrote ${cleaned.length} records to ${outAbs}`);
