// FILE LOCATION: lib/services/game_services/session_tracker.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cognitive/game_session.dart';

class SessionTracker {
  final String userId;
  final String gameName;
  final int difficulty;

  late DateTime _startTime;
  final List<Map<String, dynamic>> _actions = [];
  final Map<String, dynamic> _metrics = {};

  SessionTracker({
    required this.userId,
    required this.gameName,
    required this.difficulty,
  });

  // Start tracking a new session
  void startSession() {
    _startTime = DateTime.now();
    _actions.clear();
    _metrics.clear();
  }

  // Record an action during gameplay
  void recordAction(String actionType, Map<String, dynamic> data) {
    _actions.add({
      'type': actionType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
  }

  // Add or update a metric
  void updateMetric(String key, dynamic value) {
    _metrics[key] = value;
  }

  // End session and save to Firestore
  Future<GameSession> endSession({
    required int finalScore,
    Map<String, dynamic>? additionalMetrics,
  }) async {
    final endTime = DateTime.now();

    // Merge additional metrics
    if (additionalMetrics != null) {
      _metrics.addAll(additionalMetrics);
    }

    // Add action history to metrics
    _metrics['actions'] = _actions;
    _metrics['totalActions'] = _actions.length;

    // Create game session
    final session = GameSession.create(
      userId: userId,
      gameName: gameName,
      difficulty: difficulty,
      score: finalScore,
      startTime: _startTime,
      endTime: endTime,
      metrics: _metrics,
    );

    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('game_sessions')
          .doc(session.id)
          .set(session.toMap());

      // Also save to a general collection for analytics
      await FirebaseFirestore.instance
          .collection('game_sessions')
          .doc(session.id)
          .set(session.toMap());
    } catch (e) {
      print('Error saving game session: $e');
      // Still return the session even if save fails
    }

    return session;
  }

  // Get session duration so far
  Duration getSessionDuration() {
    return DateTime.now().difference(_startTime);
  }

  // Get recorded actions
  List<Map<String, dynamic>> getActions() {
    return List.from(_actions);
  }

  // Get metrics
  Map<String, dynamic> getMetrics() {
    return Map.from(_metrics);
  }

  // Calculate response times from actions
  List<int> getResponseTimes() {
    List<int> times = [];
    for (int i = 1; i < _actions.length; i++) {
      int timeDiff = _actions[i]['timestamp'] - _actions[i - 1]['timestamp'];
      times.add(timeDiff);
    }
    return times;
  }

  // Calculate average response time
  double getAverageResponseTime() {
    final times = getResponseTimes();
    if (times.isEmpty) return 0;
    return times.reduce((a, b) => a + b) / times.length;
  }
}
