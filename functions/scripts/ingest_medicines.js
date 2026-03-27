const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

// Usage:
// 1) Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON.
// 2) Place a JSON array file with medicine docs (name, short_composition1, short_composition2).
// 3) Run: node scripts/ingest_medicines.js ./medicines.json
//
// This script will add:
// - name_lc, short_comp1_lc, short_comp2_lc
// - search_tokens (array)

admin.initializeApp();
const db = admin.firestore();

const STOP_WORDS = new Set([
  "tablet",
  "tablets",
  "tab",
  "tabs",
  "capsule",
  "capsules",
  "cap",
  "caps",
  "syrup",
  "suspension",
  "drops",
  "drop",
  "injection",
  "inj",
  "cream",
  "ointment",
  "gel",
  "solution",
  "oral",
]);

function normalizeText(input) {
  return String(input || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function tokenize(input) {
  const normalized = normalizeText(input);
  if (!normalized) return [];
  return normalized
    .split(" ")
    .filter((p) => p && !STOP_WORDS.has(p));
}

function buildSearchTokens(name, comp1, comp2) {
  const tokens = new Set();
  const parts = [
    ...tokenize(name),
    ...tokenize(comp1),
    ...tokenize(comp2),
  ];

  if (parts.length > 0) {
    tokens.add(parts.join("")); // e.g. "dolo650"
    tokens.add(parts[0]);
    tokens.add(parts[parts.length - 1]);
  }

  for (const p of parts) {
    tokens.add(p);
    // Add prefixes for partial typing (min length 3).
    for (let i = 3; i <= p.length; i++) {
      tokens.add(p.slice(0, i));
    }
  }
  return Array.from(tokens);
}

async function run() {
  const inputPath = process.argv[2];
  if (!inputPath) {
    console.error("Please provide a JSON file path.");
    process.exit(1);
  }

  const abs = path.resolve(process.cwd(), inputPath);
  const raw = fs.readFileSync(abs, "utf8");
  const rows = JSON.parse(raw);
  if (!Array.isArray(rows)) {
    console.error("Input must be a JSON array.");
    process.exit(1);
  }

  const batchSize = 400;
  let batch = db.batch();
  let count = 0;
  let total = 0;

  for (const row of rows) {
    const name = String(row.name || "");
    const comp1 = String(row.short_composition1 || "");
    const comp2 = String(row.short_composition2 || "");

    if (!name && !comp1) continue;

    const data = {
      name,
      short_composition1: comp1,
      short_composition2: comp2,
      name_lc: name.toLowerCase(),
      short_comp1_lc: comp1.toLowerCase(),
      short_comp2_lc: comp2.toLowerCase(),
      search_tokens: buildSearchTokens(name, comp1, comp2),
    };

    const docRef = db.collection("medicines").doc();
    batch.set(docRef, data);
    count++;
    total++;

    if (count >= batchSize) {
      await batch.commit();
      batch = db.batch();
      count = 0;
      console.log(`Committed ${total}`);
    }
  }

  if (count > 0) {
    await batch.commit();
    console.log(`Committed ${total}`);
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
