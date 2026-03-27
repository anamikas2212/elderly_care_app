// FILE LOCATION: lib/models/cognitive/game_session.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class GameSession {
  final String id;
  final String userId;
  final String gameName;
  final int difficulty;
  final int score;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic>? cognitiveScores;

  GameSession({
    required this.id,
    required this.userId,
    required this.gameName,
    required this.difficulty,
    required this.score,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.metrics,
    this.cognitiveScores,
  });

  // Calculate duration from start and end time
  factory GameSession.create({
    required String userId,
    required String gameName,
    required int difficulty,
    required int score,
    required DateTime startTime,
    required DateTime endTime,
    required Map<String, dynamic> metrics,
    Map<String, dynamic>? cognitiveScores,
  }) {
    return GameSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      gameName: gameName,
      difficulty: difficulty,
      score: score,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: endTime.difference(startTime).inSeconds,
      metrics: metrics,
      cognitiveScores: cognitiveScores,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'gameName': gameName,
      'difficulty': difficulty,
      'score': score,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'durationSeconds': durationSeconds,
      'metrics': metrics,
      'cognitiveScores': cognitiveScores,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Create from Firestore document
  factory GameSession.fromMap(Map<String, dynamic> map) {
    return GameSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      gameName: map['gameName'] ?? '',
      difficulty: map['difficulty'] ?? 1,
      score: map['score'] ?? 0,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      durationSeconds: map['durationSeconds'] ?? 0,
      metrics: Map<String, dynamic>.from(map['metrics'] ?? {}),
      cognitiveScores:
          map['cognitiveScores'] != null
              ? Map<String, dynamic>.from(map['cognitiveScores'])
              : null,
    );
  }

  // Copy with method for updates
  GameSession copyWith({
    String? id,
    String? userId,
    String? gameName,
    int? difficulty,
    int? score,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    Map<String, dynamic>? metrics,
    Map<String, dynamic>? cognitiveScores,
  }) {
    return GameSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      gameName: gameName ?? this.gameName,
      difficulty: difficulty ?? this.difficulty,
      score: score ?? this.score,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      metrics: metrics ?? this.metrics,
      cognitiveScores: cognitiveScores ?? this.cognitiveScores,
    );
  }
}
