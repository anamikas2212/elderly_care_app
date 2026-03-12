import 'package:cloud_firestore/cloud_firestore.dart';

class CognitiveReport {
  final String id;
  final String elderlyId;
  final String elderlyName;
  final DateTime date;
  final String type; // 'daily', 'weekly', 'monthly', 'yearly'
  final Map<String, dynamic> domainScores;
  final int overallScore;
  final String analysis;
  final List<String> suggestions;
  final Map<String, dynamic> metadata;
  final bool isRead;
  final DateTime createdAt;

  CognitiveReport({
    required this.id,
    required this.elderlyId,
    required this.elderlyName,
    required this.date,
    required this.type,
    required this.domainScores,
    required this.overallScore,
    required this.analysis,
    required this.suggestions,
    required this.metadata,
    this.isRead = false,
    required this.createdAt,
  });

  /// Baseline domain scores from historical average
  Map<String, int> get baselineScores {
    final raw = metadata['baselineScores'];
    if (raw is Map) {
      return Map<String, int>.from(
        raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
      );
    }
    return {};
  }

  /// Per-domain percentage change vs baseline (negative = decline)
  Map<String, double> get domainChanges {
    final raw = metadata['domainChanges'];
    if (raw is Map) {
      return Map<String, double>.from(
        raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0)),
      );
    }
    return {};
  }

  /// Overall percentage change vs historical average
  double get overallChangePercent {
    return (metadata['overallChangePercent'] as num?)?.toDouble() ?? 0.0;
  }

  /// Structured key insights from AI
  List<Map<String, dynamic>> get keyInsights {
    final raw = metadata['keyInsights'];
    if (raw is List) {
      return List<Map<String, dynamic>>.from(
        raw.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}),
      );
    }
    return [];
  }

  /// Daily report dates included in a weekly/monthly/yearly report
  List<String> get includedDailyDates {
    final raw = metadata['includedDailyDates'];
    if (raw is List) return List<String>.from(raw);
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'elderlyId': elderlyId,
      'elderlyName': elderlyName,
      'date': Timestamp.fromDate(date),
      'type': type,
      'domainScores': domainScores,
      'overallScore': overallScore,
      'analysis': analysis,
      'suggestions': suggestions,
      'metadata': metadata,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory CognitiveReport.fromMap(Map<String, dynamic> map, String docId) {
    return CognitiveReport(
      id: docId,
      elderlyId: map['elderlyId'] ?? '',
      elderlyName: map['elderlyName'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] ?? 'daily',
      domainScores: Map<String, dynamic>.from(map['domainScores'] ?? {}),
      overallScore: (map['overallScore'] as num?)?.toInt() ?? 0,
      analysis: map['analysis'] ?? '',
      suggestions: List<String>.from(map['suggestions'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
