import 'package:cloud_firestore/cloud_firestore.dart';

class CognitiveReport {
  final String id;
  final String elderlyId;
  final String elderlyName;
  final DateTime date;
  final String type; // 'daily' or 'weekly'
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
