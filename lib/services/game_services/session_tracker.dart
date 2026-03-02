// FILE LOCATION: lib/services/game_services/session_tracker.dart
// UPDATED VERSION - Supports both Color Tap and Flip Card Match games

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
    print('🎮 Session started for $gameName (Difficulty: $difficulty)');
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
    Map<String, int>? cognitiveScores,
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
      cognitiveScores: cognitiveScores,
    );

    // Save to Firestore
    try {
      print('🎮 Saving game session...');
      print('   User: $userId');
      print('   Game: $gameName');
      print('   Score: $finalScore');
      print('   Duration: ${session.durationSeconds}s');

      final sessionData = session.toMap();

      // Add fields expected by caretaker dashboard
      sessionData['gameType'] = gameName;
      sessionData['timestamp'] = FieldValue.serverTimestamp();

      if (!sessionData.containsKey('createdAt')) {
        sessionData['createdAt'] = FieldValue.serverTimestamp();
      }

      // Flatten metrics to document root level
      if (sessionData.containsKey('metrics') && sessionData['metrics'] is Map) {
        final metrics = sessionData['metrics'] as Map;

        // For Color Tap game
        if (gameName == 'Color Tap (Reaction)') {
          if (metrics.containsKey('correct_taps')) {
            sessionData['correct_taps'] = metrics['correct_taps'];
          }
          if (metrics.containsKey('false_taps')) {
            sessionData['false_taps'] = metrics['false_taps'];
          }
          if (metrics.containsKey('missed_taps')) {
            sessionData['missed_taps'] = metrics['missed_taps'];
          }
          if (metrics.containsKey('average_reaction_time')) {
            sessionData['average_reaction_time'] =
                metrics['average_reaction_time'];
          }
          if (metrics.containsKey('accuracy')) {
            sessionData['accuracy'] = metrics['accuracy'];
          }
        }

        // For Flip Card Match game
        if (gameName == 'Flip Card Match') {
          if (metrics.containsKey('total_pairs')) {
            sessionData['total_pairs'] = metrics['total_pairs'];
          }
          if (metrics.containsKey('pairs_matched')) {
            sessionData['pairs_matched'] = metrics['pairs_matched'];
          }
          if (metrics.containsKey('total_attempts')) {
            sessionData['total_attempts'] = metrics['total_attempts'];
          }
          if (metrics.containsKey('wrong_attempts')) {
            sessionData['wrong_attempts'] = metrics['wrong_attempts'];
          }
          if (metrics.containsKey('average_time_per_pair')) {
            sessionData['average_time_per_pair'] =
                metrics['average_time_per_pair'];
          }
          if (metrics.containsKey('total_time')) {
            sessionData['total_time'] = metrics['total_time'];
          }
          if (metrics.containsKey('efficiency')) {
            sessionData['efficiency'] = metrics['efficiency'];
          }
          if (metrics.containsKey('time_per_pair')) {
            sessionData['time_per_pair'] = metrics['time_per_pair'];
          }
        }
      }

      // Determine collection name based on game
      String collectionName;
      if (gameName == 'Color Tap (Reaction)') {
        collectionName = 'colorTapGameSessions';
      } else if (gameName == 'Flip Card Match') {
        collectionName = 'flipCardGameSessions';
      } else {
        collectionName = 'game_sessions';
      }

      // Save to main collection
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(session.id)
          .set(sessionData);

      // Save to user's personal collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(collectionName)
          .doc(session.id)
          .set(sessionData);

      // Update user stats
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'lastGamePlayed': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
        'lastGameName': gameName,
        'totalGamesPlayed': FieldValue.increment(1),
      }, SetOptions(merge: true));

      print('✅ Session saved successfully!');
      print('   Main collection: $collectionName/${session.id}');
      print('   User collection: users/$userId/$collectionName/${session.id}');
      print('   🎯 Caretaker dashboard will update in real-time!');
    } catch (e, stackTrace) {
      print('❌ ERROR SAVING SESSION: $e');
      print('Stack trace: $stackTrace');
      rethrow;
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

  // Calculate response times from actions (in milliseconds)
  List<int> getResponseTimes() {
    List<int> times = [];
    for (int i = 1; i < _actions.length; i++) {
      int timeDiff = _actions[i]['timestamp'] - _actions[i - 1]['timestamp'];
      times.add(timeDiff);
    }
    return times;
  }

  // Calculate average response time (in milliseconds)
  double getAverageResponseTime() {
    final times = getResponseTimes();
    if (times.isEmpty) return 0;
    return times.reduce((a, b) => a + b) / times.length;
  }

  // Quick test method
  static Future<void> testFirebaseConnection(String userId) async {
    try {
      print('🧪 Testing Firebase connection...');
      await FirebaseFirestore.instance.collection('test').add({
        'message': 'Test from SessionTracker',
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('✅ Firebase connection works!');
    } catch (e) {
      print('❌ Firebase test failed: $e');
    }
  }
}
