import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineSuggestion {
  final String id;
  final String name;
  final String shortComposition1;
  final String shortComposition2;

  MedicineSuggestion({
    required this.id,
    required this.name,
    required this.shortComposition1,
    required this.shortComposition2,
  });

  factory MedicineSuggestion.fromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MedicineSuggestion(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      shortComposition1: (data['short_composition1'] ?? '').toString(),
      shortComposition2: (data['short_composition2'] ?? '').toString(),
    );
  }
}

class MedicineSearchService {
  final FirebaseFirestore _firestore;
  MedicineSearchService(this._firestore);

  final Map<String, List<MedicineSuggestion>> _cache = {};
  final List<String> _cacheKeys = [];
  static const int _cacheLimit = 50;
  static const int _tokenQueryLimit = 5;
  static const Set<String> _stopWords = {
    'tablet',
    'tablets',
    'tab',
    'tabs',
    'capsule',
    'capsules',
    'cap',
    'caps',
    'syrup',
    'suspension',
    'drops',
    'drop',
    'injection',
    'inj',
    'cream',
    'ointment',
    'gel',
    'solution',
    'oral',
  };

  // Firestore "contains" is not available without a search index. We use a
  // lower-case prefix search on derived fields and then filter locally.
  Future<List<MedicineSuggestion>> searchMedicines(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final cached = _cache[q];
    if (cached != null) {
      return cached.take(limit).toList();
    }

    final results = <MedicineSuggestion>[];
    final seen = <String>{};

    // Primary path: search by tokenized query using `search_tokens`.
    // This recognizes partial names like "dolo 650" or "aspirin".
    final tokens = _queryTokens(q);
    for (final token in tokens) {
      final snap = await _firestore
          .collection('medicines')
          .where('search_tokens', arrayContains: token)
          .limit(_tokenQueryLimit)
          .get();
      for (final doc in snap.docs) {
        if (seen.contains(doc.id)) continue;
        final suggestion = MedicineSuggestion.fromDoc(doc);
        results.add(suggestion);
        seen.add(doc.id);
        if (results.length >= limit) break;
      }
      if (results.isNotEmpty) break;
    }

    if (results.isNotEmpty) {
      _storeCache(q, results);
      return results.take(limit).toList();
    }

    // Query on derived lower-case fields for case-insensitive prefix search.
    // Make sure your dataset includes these fields: name_lc, short_comp1_lc,
    // short_comp2_lc (lowercased copies of the original fields).
    Future<void> addFromQuery(Query queryRef) async {
      final snap = await queryRef.limit(limit).get();
      for (final doc in snap.docs) {
        if (seen.contains(doc.id)) continue;
        final suggestion = MedicineSuggestion.fromDoc(doc);
        // Local contains filter for better matching (approximate substring).
        final nameLc = suggestion.name.toLowerCase();
        final comp1Lc = suggestion.shortComposition1.toLowerCase();
        if (nameLc.contains(q) || comp1Lc.contains(q)) {
          results.add(suggestion);
          seen.add(doc.id);
          if (results.length >= limit) return;
        }
      }
    }

    // Query name_lc first, only fall back to compositions if needed.
    await addFromQuery(
      _firestore
          .collection('medicines')
          .orderBy('name_lc')
          .startAt([q])
          .endAt(['$q\uf8ff']),
    );

    if (results.isEmpty) {
      await addFromQuery(
        _firestore
            .collection('medicines')
            .orderBy('short_comp1_lc')
            .startAt([q])
            .endAt(['$q\uf8ff']),
      );
    }

    if (results.isEmpty) {
      await addFromQuery(
        _firestore
            .collection('medicines')
            .orderBy('short_comp2_lc')
            .startAt([q])
            .endAt(['$q\uf8ff']),
      );
    }

    _storeCache(q, results);
    return results.take(limit).toList();
  }

  Future<MedicineSuggestion?> findExactMatch(String nameOrComp) async {
    final q = nameOrComp.trim().toLowerCase();
    if (q.isEmpty) return null;

    // Exact match on derived lower-case fields.
    final nameSnap =
        await _firestore.collection('medicines').where('name_lc', isEqualTo: q).limit(1).get();
    if (nameSnap.docs.isNotEmpty) {
      return MedicineSuggestion.fromDoc(nameSnap.docs.first);
    }

    final compSnap = await _firestore
        .collection('medicines')
        .where('short_comp1_lc', isEqualTo: q)
        .limit(1)
        .get();
    if (compSnap.docs.isNotEmpty) {
      return MedicineSuggestion.fromDoc(compSnap.docs.first);
    }

    // Fallback: token match + local scoring.
    final tokens = _queryTokens(q);
    for (final token in tokens) {
      final snap = await _firestore
          .collection('medicines')
          .where('search_tokens', arrayContains: token)
          .limit(_tokenQueryLimit)
          .get();
      if (snap.docs.isEmpty) continue;
      MedicineSuggestion? best;
      var bestScore = -1;
      for (final doc in snap.docs) {
        final s = MedicineSuggestion.fromDoc(doc);
        final score = _matchScore(q, s);
        if (score > bestScore) {
          bestScore = score;
          best = s;
        }
      }
      if (best != null) return best;
    }

    return null;
  }

  void _storeCache(String key, List<MedicineSuggestion> values) {
    if (_cache.containsKey(key)) return;
    _cache[key] = values;
    _cacheKeys.add(key);
    if (_cacheKeys.length > _cacheLimit) {
      final oldest = _cacheKeys.removeAt(0);
      _cache.remove(oldest);
    }
  }

  List<String> _queryTokens(String query) {
    final normalized = _normalizeText(query);
    if (normalized.isEmpty) return [];
    final parts = normalized
        .split(' ')
        .where((p) => p.isNotEmpty && !_stopWords.contains(p))
        .toList();
    final tokens = <String>{};

    if (parts.isNotEmpty) {
      // Prefer the compact (no-space) token first: "dolo 650" -> "dolo650"
      tokens.add(parts.join(''));
      tokens.add(parts.first);
      if (parts.length > 1) tokens.add(parts.last);
    }

    // Add individual tokens for broader matching.
    for (final p in parts) {
      tokens.add(p);
    }

    return tokens.toList();
  }

  String _normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  int _matchScore(String query, MedicineSuggestion s) {
    final name = s.name.toLowerCase();
    final comp1 = s.shortComposition1.toLowerCase();
    if (name.contains(query)) return 100;
    if (comp1.contains(query)) return 80;

    // Looser match: token overlap between query and name/composition.
    final qTokens = _queryTokens(query);
    if (qTokens.isEmpty) return 0;
    final candTokens = _queryTokens('$name $comp1 ${s.shortComposition2}');
    var overlap = 0;
    for (final t in qTokens) {
      if (candTokens.contains(t)) overlap++;
    }
    if (overlap > 0) return 50 + (overlap * 10);
    return 0;
  }
}

class MedicineDosageExtractor {
  static final RegExp _strengthPattern = RegExp(
    r'(\d+(?:\.\d+)?\s*(?:mg|mcg|g|ml|iu|%)\b(?:\s*/\s*\d+(?:\.\d+)?\s*ml)?)',
    caseSensitive: false,
  );

  static List<String> extractDosages(String? comp1, String? comp2) {
    final out = <String>{};

    void addFrom(String? text) {
      if (text == null || text.trim().isEmpty) return;
      for (final m in _strengthPattern.allMatches(text)) {
        final raw = m.group(1) ?? '';
        final normalized = _normalizeStrength(raw);
        if (normalized.isNotEmpty) out.add(normalized);
      }
    }

    addFrom(comp1);
    addFrom(comp2);

    final list = out.toList();
    list.sort();
    return list;
  }

  static String _normalizeStrength(String value) {
    final trimmed = value.trim().toLowerCase();
    // Normalize "500 mg" -> "500mg"
    final cleaned = trimmed.replaceAll(RegExp(r'\s+'), '');
    return cleaned;
  }
}
