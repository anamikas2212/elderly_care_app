// FILE LOCATION: lib/services/game_services/session_tracker.dart
// CORRECTED VERSION - Fixed collection names to match caretaker dashboard

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

  // End session and save to Firestore (AUTOMATIC - NO MANUAL DATA ENTRY!)
  Future<GameSession> endSession({
    required int finalScore,
    Map<String, dynamic>? additionalMetrics,
    Map<String, dynamic>? cognitiveScores,
  }) async {
    final endTime = DateTime.now();

    // Merge additional metrics
    if (additionalMetrics != null) {
      _metrics.addAll(additionalMetrics);
    }

    // Add action history to metrics
    _metrics['actions'] = _actions;
    _metrics['totalActions'] = _actions.length;

    // Calculate and add average_reaction_time for caretaker dashboard
    final avgResponseTime = getAverageResponseTime();
    if (avgResponseTime > 0) {
      _metrics['average_reaction_time'] =
          avgResponseTime / 1000; // Convert ms to seconds
    }

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

    // Save to Firestore AUTOMATICALLY
    try {
      print('🎮 Saving game session...');
      print('   User: $userId');
      print('   Game: $gameName');
      print('   Score: $finalScore');
      print('   Duration: ${session.durationSeconds}s');

      final sessionData = session.toMap();

      // CRITICAL: Add gameType field for caretaker queries
      sessionData['gameType'] = gameName;

      // Add timestamp field that caretaker dashboard expects
      sessionData['timestamp'] = FieldValue.serverTimestamp();

      // Ensure createdAt is set (caretaker dashboard needs this)
      if (!sessionData.containsKey('createdAt')) {
        sessionData['createdAt'] = FieldValue.serverTimestamp();
      }

      // ✅ CRITICAL FIX: Flatten metrics to document root level
      // CaretakerDataService expects these fields at the top level, not nested in metrics
      if (sessionData.containsKey('metrics') && sessionData['metrics'] is Map) {
        final metrics = sessionData['metrics'] as Map<String, dynamic>;

        // Extract key metrics to document root for easy querying
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
        if (metrics.containsKey('total_color_changes')) {
          sessionData['total_color_changes'] = metrics['total_color_changes'];
        }
      }

      // ✅ FIXED: Changed to colorTapGameSessions to match caretaker queries
      // MAIN COLLECTION - Caretaker dashboard reads from here
      await FirebaseFirestore.instance
          .collection('colorTapGameSessions') // ✅ Changed from 'game_sessions'
          .doc(session.id)
          .set(sessionData);

      // USER'S PERSONAL COLLECTION - For user-specific queries
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('colorTapGameSessions') // ✅ Changed from 'game_sessions'
          .doc(session.id)
          .set(sessionData);

      // UPDATE USER STATS - Using set with merge to create if doesn't exist
      // ✅ FIXED: Changed from .update() to .set() with merge: true
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'lastGamePlayed': FieldValue.serverTimestamp(),
        'lastGameName': gameName,
        'totalGamesPlayed': FieldValue.increment(1),
      }, SetOptions(merge: true)); // Creates document if it doesn't exist!

      print('✅ Session saved successfully!');
      print('   Main collection: colorTapGameSessions/${session.id}');
      print(
        '   User collection: users/$userId/colorTapGameSessions/${session.id}',
      );
      print('   🎯 Caretaker dashboard will update in real-time!');
    } catch (e, stackTrace) {
      print('❌ ERROR SAVING SESSION: $e');
      print('Stack trace: $stackTrace');

      // Check common issues
      if (e.toString().contains('permission-denied')) {
        print('⚠️  PERMISSION DENIED - Check Firestore Rules!');
        print(
          '   Go to: https://console.firebase.google.com/project/buddy-system-74299/firestore/rules',
        );
        print('   Make sure rules allow write access.');
      } else if (e.toString().contains('not initialized')) {
        print('⚠️  Firebase not initialized properly!');
        print('   Check if Firebase.initializeApp() was called in main.dart');
      } else if (e.toString().contains('FAILED_PRECONDITION')) {
        print('⚠️  Missing index! Firebase needs to create an index.');
        print('   Click the link in the error above to auto-create it.');
      }

      // Re-throw to let caller handle
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

  // Quick test method - call this from a button to verify Firebase works
  static Future<void> testFirebaseConnection(String userId) async {
    try {
      print('🧪 Testing Firebase connection...');

      await FirebaseFirestore.instance.collection('test').add({
        'message': 'Test from SessionTracker',
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Firebase connection works!');
      print('   Check Firebase Console → Firestore → test collection');
    } catch (e) {
      print('❌ Firebase test failed: $e');
    }
  }
}
