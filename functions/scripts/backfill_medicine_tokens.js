const admin = require("firebase-admin");

// Usage:
// 1) Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON.
// 2) Run: node scripts/backfill_medicine_tokens.js
//
// This updates existing docs with:
// - name_lc, short_comp1_lc, short_comp2_lc
// - search_tokens (array, including prefixes)

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
    tokens.add(parts.join(""));
    tokens.add(parts[0]);
    tokens.add(parts[parts.length - 1]);
  }

  for (const p of parts) {
    tokens.add(p);
    for (let i = 3; i <= p.length; i++) {
      tokens.add(p.slice(0, i));
    }
  }
  return Array.from(tokens);
}

async function run() {
  const batchSize = 400;
  let lastDoc = null;
  let updated = 0;

  while (true) {
    let query = db.collection("medicines").orderBy("__name__").limit(batchSize);
    if (lastDoc) query = query.startAfter(lastDoc);
    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const name = String(data.name || "");
      const comp1 = String(data.short_composition1 || "");
      const comp2 = String(data.short_composition2 || "");
      if (!name && !comp1) continue;

      batch.update(doc.ref, {
        name_lc: name.toLowerCase(),
        short_comp1_lc: comp1.toLowerCase(),
        short_comp2_lc: comp2.toLowerCase(),
        search_tokens: buildSearchTokens(name, comp1, comp2),
      });
      updated++;
    }

    await batch.commit();
    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(`Updated ${updated}`);
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
