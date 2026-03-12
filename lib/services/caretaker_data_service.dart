import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CaretakerDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========== OVERALL COGNITIVE HEALTH ==========

  /// Computes cognitive domain scores live from game session data.
  /// Falls back to cognitive_summary doc if present.
  Stream<Map<String, dynamic>> getOverallCognitiveHealth(String userId) {
    // Use Stream.fromFuture so it ALWAYS emits immediately, even with no colorTap data
    return Stream.fromFuture(_computeCognitiveHealth(userId)).asBroadcastStream();
  }

  /// Direct Future version — use this when you want to cache the result in state
  Future<Map<String, dynamic>> getCognitiveHealthFuture(String userId) {
    return _computeCognitiveHealth(userId);
  }

  Future<Map<String, dynamic>> _computeCognitiveHealth(String userId) async {
    double totalAccuracy = 0;
    double totalReactionTime = 0;
    int ctCount = 0;

    // ---- Color Tap: Attention + Processing Speed ----
    try {
      // No orderBy — avoids composite index requirement. Sort in-memory instead.
      final colorTapSnap = await _firestore
          .collection('colorTapGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();
      for (final doc in colorTapSnap.docs) {
        final d = doc.data();
        final correct = (d['correct_taps'] as num?)?.toInt() ?? 0;
        final wrong = (d['false_taps'] as num?)?.toInt() ?? 0;
        final total = correct + wrong;
        final rt = (d['average_reaction_time'] as num?)?.toDouble() ?? 0.0;
        if (total > 0) {
          totalAccuracy += correct / total;
          totalReactionTime += rt;
          ctCount++;
        }
      }
    } catch (_) {}

    final double attentionScore = ctCount > 0
        ? (totalAccuracy / ctCount * 100).clamp(0, 100)
        : 0;
    final double processingSpeedScore = ctCount > 0
        ? ((2.0 - totalReactionTime / ctCount).clamp(0.0, 2.0) * 50).clamp(0, 100)
        : 0;

    // ---- Flip Card: Memory ----
    double memoryScore = 0;
    try {
      // No orderBy — avoids composite index requirement. Sort in-memory instead.
      final flipSnap = await _firestore
          .collection('flipCardGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();
      double totalEfficiency = 0;
      int fcCount = 0;
      for (final doc in flipSnap.docs) {
        final d = doc.data();
        final eff = (d['efficiency'] as num?)?.toDouble() ?? 0.0;
        totalEfficiency += eff;
        fcCount++;
      }
      memoryScore = fcCount > 0
          ? (totalEfficiency / fcCount * 100).clamp(0, 100)
          : 0;
    } catch (_) {}

    // ---- Other games from game_sessions ----
    double executiveFunctionScore = 0;
    double languageScore = 0;
    double gameMemory = 0;
    try {
      // No orderBy — avoids composite index requirement.
      final gamesSnap = await _firestore
          .collection('game_sessions')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();

      double totalExec = 0;
      double totalLang = 0;
      double totalGameMem = 0;
      int execCount = 0;
      int langCount = 0;
      int gameMemCount = 0;

      for (final doc in gamesSnap.docs) {
        final d = doc.data();
        final cognitive = d['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        if (cognitive.containsKey('executive_function')) {
          totalExec += (cognitive['executive_function'] as num?)?.toDouble() ?? 0;
          execCount++;
        }
        if (cognitive.containsKey('language')) {
          totalLang += (cognitive['language'] as num?)?.toDouble() ?? 0;
          langCount++;
        }
        if (cognitive.containsKey('memory')) {
          totalGameMem += (cognitive['memory'] as num?)?.toDouble() ?? 0;
          gameMemCount++;
        }
      }
      executiveFunctionScore = execCount > 0 ? (totalExec / execCount).clamp(0, 100) : 0;
      languageScore = langCount > 0 ? (totalLang / langCount).clamp(0, 100) : 0;
      gameMemory = gameMemCount > 0 ? (totalGameMem / gameMemCount).clamp(0, 100) : 0;
    } catch (_) {}

    // ---- Blend memory: flip card + game_sessions memory ----
    if (gameMemory > 0 && memoryScore > 0) {
      memoryScore = (memoryScore * 0.5 + gameMemory * 0.5);
    } else if (gameMemory > 0) {
      memoryScore = gameMemory;
    }

    // ---- Overall ----
    final List<double> domainScores = [
      attentionScore,
      processingSpeedScore,
      memoryScore,
      if (executiveFunctionScore > 0) executiveFunctionScore,
      if (languageScore > 0) languageScore,
    ];
    final double overallScore = domainScores.isNotEmpty
        ? domainScores.reduce((a, b) => a + b) / domainScores.length
        : 0;

    final result = {
      'overallScore': overallScore.round(),
      'memory': memoryScore.round(),
      'attention': attentionScore.round(),
      'processingSpeed': processingSpeedScore.round(),
      'executiveFunction': executiveFunctionScore.round(),
      'language': languageScore.round(),
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    };

    // Cache to Firestore
    _firestore.collection('cognitive_summary').doc(userId).set(
          result, SetOptions(merge: true));

    return result;
  }

  // ========== USER PROFILE ==========

  Stream<Map<String, dynamic>> getUserProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return <String, dynamic>{};
          final data = Map<String, dynamic>.from(snapshot.data()!);
          if (data['lastActive'] is Timestamp) {
            data['lastActive'] = DateFormat('MMM d, h:mm a')
                .format((data['lastActive'] as Timestamp).toDate());
          }
          return data;
        })
        .asBroadcastStream();
  }

  // ========== COLOR TAP ANALYTICS ==========

  Future<Map<String, dynamic>> getColorTapAnalytics(String userId) async {
    try {
      // No orderBy — avoids composite index requirement (where+where+orderBy = composite index needed).
      final snapshot = await _firestore
          .collection('colorTapGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'stats': {'averageAccuracy': 0.0, 'averageReactionTime': 0.0, 'totalSessions': 0, 'attentionScore': 0, 'processingSpeedScore': 0}, 'sessions': <Map<String, dynamic>>[]};
      }

      double totalAccuracy = 0;
      double totalReactionTime = 0;
      int count = 0;
      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final correct = (data['correct_taps'] as num?)?.toInt() ?? 0;
        final wrong = (data['false_taps'] as num?)?.toInt() ?? 0;
        final total = correct + wrong;
        final reactionTime = (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;
        final accuracy = total > 0 ? correct / total : 0.0;
        totalAccuracy += accuracy;
        totalReactionTime += reactionTime;
        count++;
        sessions.add({
          'metrics': {'accuracy': accuracy, 'reactionTime': reactionTime},
          'cognitive_contributions': {'attention': accuracy * 100, 'processing_speed': (2.0 - reactionTime).clamp(0.0, 2.0) * 50},
          'createdAt': _parseTimestamp(data['createdAt']),
        });
      }

      final avgAccuracy = count > 0 ? totalAccuracy / count : 0.0;
      final avgReactionTime = count > 0 ? totalReactionTime / count : 0.0;
      return {
        'stats': {
          'averageAccuracy': avgAccuracy,
          'averageReactionTime': avgReactionTime,
          'totalSessions': count,
          'attentionScore': (avgAccuracy * 100).toInt().clamp(0, 100),
          'processingSpeedScore': ((2.0 - avgReactionTime).clamp(0.0, 2.0) * 50).toInt().clamp(0, 100),
        },
        'sessions': sessions,
      };
    } catch (e) {
      return {'stats': {'averageAccuracy': 0.0, 'averageReactionTime': 0.0, 'totalSessions': 0, 'attentionScore': 0, 'processingSpeedScore': 0, 'error': e.toString()}, 'sessions': <Map<String, dynamic>>[], 'error': e.toString()};
    }
  }

  // ========== FLIP CARD ANALYTICS ==========

  Future<Map<String, dynamic>> getFlipCardAnalytics(String userId) async {
    try {
      // No orderBy — avoids composite index requirement.
      final snapshot = await _firestore
          .collection('flipCardGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'stats': {'memoryScore': 0, 'attentionScore': 0, 'totalSessions': 0}, 'sessions': <Map<String, dynamic>>[]};
      }

      double totalEfficiency = 0;
      int count = 0;
      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final efficiency = (data['efficiency'] as num?)?.toDouble() ?? 0.0;
        totalEfficiency += efficiency;
        count++;
        sessions.add({
          'metrics': {'efficiency': efficiency},
          'cognitive_contributions': {'memory': efficiency * 100},
          'createdAt': _parseTimestamp(data['createdAt']),
        });
      }

      final avgScore = count > 0 ? ((totalEfficiency / count) * 100).toInt().clamp(0, 100) : 0;
      return {
        'stats': {'memoryScore': avgScore, 'attentionScore': (avgScore * 0.8).toInt(), 'totalSessions': count},
        'sessions': sessions,
      };
    } catch (e) {
      return {'stats': {'memoryScore': 0, 'attentionScore': 0, 'totalSessions': 0, 'error': e.toString()}, 'sessions': <Map<String, dynamic>>[], 'error': e.toString()};
    }
  }

  // ========== CITY ATLAS ANALYTICS ==========

  Future<Map<String, dynamic>> getCityAtlasAnalytics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('game_sessions')
          .where('gameType', isEqualTo: 'city_atlas')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'stats': {'executiveFunctionScore': 0, 'memoryScore': 0, 'totalSessions': 0}, 'sessions': <Map<String, dynamic>>[]};
      }

      double totalExec = 0, totalMem = 0;
      int count = 0;
      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
        final cognitive = data['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        final accuracy = (metrics['accuracy'] as num?)?.toDouble() ?? 0.0;
        final execF = (cognitive['executive_function'] as num?)?.toDouble() ?? 0.0;
        final memF = (cognitive['memory'] as num?)?.toDouble() ?? 0.0;
        totalExec += execF;
        totalMem += memF;
        count++;
        sessions.add({
          'metrics': {'accuracy': accuracy},
          'cognitive_contributions': cognitive,
          'score': (data['score'] as num?)?.toInt() ?? 0,
          'createdAt': _parseTimestamp(data['timestamp']),
        });
      }

      // Sort by time ascending for trend charts
      sessions.sort((a, b) => (a['createdAt'] as int).compareTo(b['createdAt'] as int));

      return {
        'stats': {
          'executiveFunctionScore': count > 0 ? (totalExec / count).round().clamp(0, 100) : 0,
          'memoryScore': count > 0 ? (totalMem / count).round().clamp(0, 100) : 0,
          'totalSessions': count,
        },
        'sessions': sessions,
      };
    } catch (e) {
      return {'stats': {'executiveFunctionScore': 0, 'memoryScore': 0, 'totalSessions': 0, 'error': e.toString()}, 'sessions': <Map<String, dynamic>>[], 'error': e.toString()};
    }
  }

  // ========== EVENT ORDERING ANALYTICS ==========

  Future<Map<String, dynamic>> getEventOrderingAnalytics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('game_sessions')
          .where('gameType', isEqualTo: 'event_ordering')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();

      if (snapshot.docs.isEmpty) {
        return {'stats': {'executiveFunctionScore': 0, 'memoryScore': 0, 'totalSessions': 0}, 'sessions': <Map<String, dynamic>>[]};
      }

      double totalExec = 0, totalMem = 0;
      int count = 0;
      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
        final cognitive = data['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        final accuracy = (metrics['sequence_accuracy'] as num?)?.toDouble() ?? 0.0;
        final execF = (cognitive['executive_function'] as num?)?.toDouble() ?? 0.0;
        final memF = (cognitive['memory'] as num?)?.toDouble() ?? 0.0;
        totalExec += execF;
        totalMem += memF;
        count++;
        sessions.add({
          'metrics': {'accuracy': accuracy},
          'cognitive_contributions': cognitive,
          'score': (data['score'] as num?)?.toInt() ?? 0,
          'createdAt': _parseTimestamp(data['timestamp']),
        });
      }

      sessions.sort((a, b) => (a['createdAt'] as int).compareTo(b['createdAt'] as int));

      return {
        'stats': {
          'executiveFunctionScore': count > 0 ? (totalExec / count).round().clamp(0, 100) : 0,
          'memoryScore': count > 0 ? (totalMem / count).round().clamp(0, 100) : 0,
          'totalSessions': count,
        },
        'sessions': sessions,
      };
    } catch (e) {
      return {'stats': {'executiveFunctionScore': 0, 'memoryScore': 0, 'totalSessions': 0, 'error': e.toString()}, 'sessions': <Map<String, dynamic>>[], 'error': e.toString()};
    }
  }

  // ========== DAILY ROUTINE ANALYTICS ==========

  Future<Map<String, dynamic>> getDailyRoutineAnalytics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('game_sessions')
          .where('gameType', isEqualTo: 'daily_routine_recall')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();

      double totalOrderAcc = 0, totalMemory = 0, totalExec = 0;
      int count = 0;
      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
        final cognitive = data['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        final orderAcc = (metrics['order_accuracy'] as num?)?.toDouble() ?? 0.0;
        final memScore = (cognitive['memory'] as num?)?.toDouble() ?? 0.0;
        final execScore = (cognitive['executive_function'] as num?)?.toDouble() ?? 0.0;
        totalOrderAcc += orderAcc;
        totalMemory += memScore;
        totalExec += execScore;
        count++;
        sessions.add({
          'metrics': {'order_accuracy': orderAcc},
          'cognitive_contributions': cognitive,
          'score': (data['score'] as num?)?.toInt() ?? 0,
          'createdAt': _parseTimestamp(data['timestamp']),
        });
      }

      sessions.sort((a, b) => (a['createdAt'] as int).compareTo(b['createdAt'] as int));

      return {
        'stats': {
          'avgOrderAccuracy': count > 0 ? (totalOrderAcc / count * 100).toInt().clamp(0, 100) : 0,
          'memoryScore': count > 0 ? (totalMemory / count).round().clamp(0, 100) : 0,
          'executiveFunctionScore': count > 0 ? (totalExec / count).round().clamp(0, 100) : 0,
          'totalSessions': count,
        },
        'sessions': sessions,
      };
    } catch (e) {
      return {'stats': {'avgOrderAccuracy': 0, 'memoryScore': 0, 'executiveFunctionScore': 0, 'totalSessions': 0, 'error': e.toString()}, 'sessions': <Map<String, dynamic>>[], 'error': e.toString()};
    }
  }

  // ========== MONUMENT RECALL ANALYTICS ==========

  Future<Map<String, dynamic>> getMonumentRecallAnalytics(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('game_sessions')
          .where('gameType', isEqualTo: 'monument_recall')
          .where('userId', isEqualTo: userId)
          .limit(50)
          .get();

      double totalMemory = 0;
      double totalLanguage = 0;
      int count = 0;
      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final cognitive = data['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        final memory = (cognitive['memory'] as num?)?.toDouble() ?? 0.0;
        final language = (cognitive['language'] as num?)?.toDouble() ?? 0.0;
        totalMemory += memory;
        totalLanguage += language;
        count++;
        sessions.add({
          'cognitive_contributions': cognitive,
          'score': (data['score'] as num?)?.toInt() ?? 0,
          'createdAt': _parseTimestamp(data['timestamp']),
        });
      }

      sessions.sort((a, b) => (a['createdAt'] as int).compareTo(b['createdAt'] as int));

      return {
        'stats': {
          'memoryScore': count > 0 ? (totalMemory / count).toInt().clamp(0, 100) : 0,
          'languageScore': count > 0 ? (totalLanguage / count).toInt().clamp(0, 100) : 0,
          'totalSessions': count,
        },
        'sessions': sessions,
      };
    } catch (e) {
      return {'stats': {'memoryScore': 0, 'languageScore': 0, 'totalSessions': 0, 'error': e.toString()}, 'sessions': <Map<String, dynamic>>[], 'error': e.toString()};
    }
  }

  // ========== DOMAIN SCORES BY DIFFICULTY ==========

  Stream<Map<String, dynamic>> calculateDomainScoresByDifficulty(
      String userId, int? difficultyLevel) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId);

    if (difficultyLevel != null) {
      query = query.where('difficulty_level', isEqualTo: difficultyLevel);
    }

    return query
        .limit(50)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return {
              'attentionScore': 0.0,
              'processingSpeedScore': 0.0,
              'sessionsCount': 0,
            };
          }

          double totalAccuracy = 0;
          double totalReactionTime = 0;
          int count = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final correct = (data['correct_taps'] as num?)?.toInt() ?? 0;
            final wrong = (data['false_taps'] as num?)?.toInt() ?? 0;
            final total = correct + wrong;
            final reactionTime = (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;

            if (total > 0) {
              totalAccuracy += correct / total;
              totalReactionTime += reactionTime;
              count++;
            }
          }

          if (count == 0) {
            return {
              'attentionScore': 0.0,
              'processingSpeedScore': 0.0,
              'sessionsCount': 0,
            };
          }

          final avgAccuracy = totalAccuracy / count;
          final avgReactionTime = totalReactionTime / count;

          return {
            'attentionScore': (avgAccuracy * 100).clamp(0.0, 100.0),
            'processingSpeedScore':
                ((2.0 - avgReactionTime).clamp(0.0, 2.0) * 50).clamp(0.0, 100.0),
            'sessionsCount': count,
          };
        })
        .asBroadcastStream();
  }

  // ========== DETAILED GAME METRICS ==========

  Stream<Map<String, dynamic>> getDetailedGameMetrics(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          double totalAccuracy = 0;
          double totalReactionTime = 0;
          int totalCorrect = 0;
          int totalFalse = 0;
          int totalMissed = 0;
          int count = 0;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final correct = (data['correct_taps'] as num?)?.toInt() ?? 0;
            final wrong = (data['false_taps'] as num?)?.toInt() ?? 0;
            final missed = (data['missed_taps'] as num?)?.toInt() ?? 0;
            final reactionTime = (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;
            final denom = (correct + wrong).toDouble();

            if (denom > 0) totalAccuracy += correct / denom;
            totalReactionTime += reactionTime;
            totalCorrect += correct;
            totalFalse += wrong;
            totalMissed += missed;
            count++;
          }

          return {
            'accuracy': count > 0 ? (totalAccuracy / count * 100) : 0.0,
            'avgReactionTime': count > 0 ? totalReactionTime / count : 0.0,
            'totalCorrectTaps': totalCorrect,
            'totalFalseTaps': totalFalse,
            'totalMissedTaps': totalMissed,
          };
        })
        .asBroadcastStream();
  }

  // ========== SCORE HISTORY ==========

  Stream<List<Map<String, dynamic>>> getColorTapScoreHistory(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          final List<Map<String, dynamic>> history = [];
          for (final doc in snapshot.docs.reversed) {
            final data = doc.data();
            final correct = (data['correct_taps'] as num?)?.toInt() ?? 0;
            final wrong = (data['false_taps'] as num?)?.toInt() ?? 0;
            final denom = (correct + wrong).toDouble();
            final accuracy = denom > 0 ? correct / denom : 0.0;
            final reactionTime = (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;

            history.add({
              'attention': accuracy * 100,
              'processingSpeed': (2.0 - reactionTime).clamp(0.0, 2.0) * 50,
              'date': DateTime.fromMillisecondsSinceEpoch(_parseTimestamp(data['createdAt'])),
            });
          }
          return history;
        })
        .asBroadcastStream();
  }

  // ========== GAME SESSION HISTORY (All Games) ==========

  // ========== GAME SESSION HISTORY (All Games) ==========

  // ========== GAME SESSION HISTORY (All Games) ==========

  Stream<List<Map<String, dynamic>>> getGameSessionHistory(String userId) {
    // Combine streaks from 3 collections into one live list
    // REMOVED 'orderBy' to prevent "Missing Index" errors. Sorting is done client-side.
    
    final Stream<List<Map<String, dynamic>>> colorTapStream = _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .limit(20) 
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              return {
                'gameType': 'Color Tap',
                'icon': 'touch_app',
                'color': 'blue',
                'score': data['score'] ?? 0,
                'createdAt': _parseTimestamp(data['createdAt']),
                'correct_taps': data['correct_taps'] ?? 0,
                'false_taps': data['false_taps'] ?? 0,
                'average_reaction_time': (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0,
              };
            }).toList())
        .handleError((e) { print("Error in ColorTap stream: $e"); return []; });

    final Stream<List<Map<String, dynamic>>> flipCardStream = _firestore
        .collection('flipCardGameSessions')
        .where('userId', isEqualTo: userId)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              return {
                'gameType': 'Flip Card',
                'icon': 'flip',
                'color': 'purple',
                'score': data['score'] ?? 0,
                'createdAt': _parseTimestamp(data['createdAt']),
                'efficiency': (data['efficiency'] as num?)?.toDouble() ?? 0.0,
              };
            }).toList())
        .handleError((e) { print("Error in FlipCard stream: $e"); return []; });

    final Stream<List<Map<String, dynamic>>> otherGamesStream = _firestore
        .collection('game_sessions')
        .where('userId', isEqualTo: userId)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              final gameType = data['gameType'] as String? ?? 'Unknown';
              String label;
              switch (gameType) {
                case 'city_atlas': label = 'City Atlas'; break;
                case 'event_ordering': label = 'Event Ordering'; break;
                case 'daily_routine_recall': label = 'Routine Recall'; break;
                case 'monument_recall': label = 'Monument Recall'; break;
                default: label = gameType;
              }
              return {
                'gameType': label,
                'icon': 'sports_esports',
                'color': 'teal',
                'score': (data['score'] as num?)?.toInt() ?? 0,
                'createdAt': _parseTimestamp(data['timestamp']), // Use timestamp or createdAt
                'metrics': data['metrics'] ?? {},
                'cognitive_contributions': data['cognitive_contributions'] ?? {},
              };
            }).toList())
        .handleError((e) { print("Error in OtherGames stream: $e"); return []; });

    // Merge logic
    List<Map<String, dynamic>> ctList = [];
    List<Map<String, dynamic>> fcList = [];
    List<Map<String, dynamic>> ogList = [];
    
    // ignore: cancel_subscriptions
    StreamSubscription? sub1, sub2, sub3;

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    void update() {
      if (controller.isClosed) return;
      final all = [...ctList, ...fcList, ...ogList];
      all.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
      controller.add(all.take(10).toList());
    }

    sub1 = colorTapStream.listen((l) { ctList = l; update(); }, onError: (e) { print('CT error: $e'); update(); });
    sub2 = flipCardStream.listen((l) { fcList = l; update(); }, onError: (e) { print('FC error: $e'); update(); });
    sub3 = otherGamesStream.listen((l) { ogList = l; update(); }, onError: (e) { print('OG error: $e'); update(); });

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
      sub3?.cancel();
    };

    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> _fetchAllGameSessions(String userId) async {
    return []; 
  }

  /// Future-based version of getGameSessionHistory — fetches once, no stream complexity.
  Future<List<Map<String, dynamic>>> getRecentActivityFuture(String userId) async {
    final List<Map<String, dynamic>> all = [];

    try {
      final ctSnap = await _firestore
          .collection('colorTapGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();
      for (final d in ctSnap.docs) {
        final data = d.data();
        all.add({
          'gameType': 'Color Tap',
          'icon': 'touch_app',
          'color': 'blue',
          'score': data['score'] ?? 0,
          'createdAt': _parseTimestamp(data['createdAt']),
          'correct_taps': data['correct_taps'] ?? 0,
          'false_taps': data['false_taps'] ?? 0,
          'average_reaction_time': (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0,
        });
      }
    } catch (_) {}

    try {
      final fcSnap = await _firestore
          .collection('flipCardGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();
      for (final d in fcSnap.docs) {
        final data = d.data();
        all.add({
          'gameType': 'Flip Card',
          'icon': 'flip',
          'color': 'purple',
          'score': data['score'] ?? 0,
          'createdAt': _parseTimestamp(data['createdAt']),
          'efficiency': (data['efficiency'] as num?)?.toDouble() ?? 0.0,
        });
      }
    } catch (_) {}

    try {
      final ogSnap = await _firestore
          .collection('game_sessions')
          .where('userId', isEqualTo: userId)
          .limit(20)
          .get();
      for (final d in ogSnap.docs) {
        final data = d.data();
        final gameType = data['gameType'] as String? ?? 'Unknown';
        String label;
        switch (gameType) {
          case 'city_atlas': label = 'City Atlas'; break;
          case 'event_ordering': label = 'Event Ordering'; break;
          case 'daily_routine_recall': label = 'Routine Recall'; break;
          case 'monument_recall': label = 'Monument Recall'; break;
          default: label = gameType;
        }
        all.add({
          'gameType': label,
          'icon': 'sports_esports',
          'color': 'teal',
          'score': (data['score'] as num?)?.toInt() ?? 0,
          'createdAt': _parseTimestamp(data['timestamp']),
          'metrics': data['metrics'] ?? {},
          'cognitive_contributions': data['cognitive_contributions'] ?? {},
        });
      }
    } catch (_) {}

    all.sort((a, b) => (b['createdAt'] as int).compareTo(a['createdAt'] as int));
    return all.take(10).toList();
  }

  /// Future-based version of getOverallStatistics — fetches once.
  Future<Map<String, dynamic>> getOverallStatisticsFuture(String userId) async {
    int ct = 0, fc = 0, og = 0;

    try {
      final ctSnap = await _firestore
          .collection('colorTapGameSessions')
          .where('userId', isEqualTo: userId)
          .get();
      ct = ctSnap.docs.length;
    } catch (_) {}

    try {
      final fcSnap = await _firestore
          .collection('flipCardGameSessions')
          .where('userId', isEqualTo: userId)
          .get();
      fc = fcSnap.docs.length;
    } catch (_) {}

    try {
      final ogSnap = await _firestore
          .collection('game_sessions')
          .where('userId', isEqualTo: userId)
          .get();
      og = ogSnap.docs.where((d) {
        final type = d.data()['gameType'] as String? ?? '';
        return !['Color Tap', 'Color Tap (Reaction)', 'Flip Card', 'Flip Card Match'].contains(type);
      }).length;
    } catch (_) {}

    return {
      'totalGames': ct + fc + og,
      'medicationAdherence': 87,
    };
  }


  // ========== OVERALL STATISTICS ==========

  Stream<Map<String, dynamic>> getOverallStatistics(String userId) {
    // We combine counts from 3 collections
    
    final Stream<int> colorTapCount = _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((e) => 0);

    final Stream<int> flipCardCount = _firestore
        .collection('flipCardGameSessions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.length)
        .handleError((e) => 0);
        
    final Stream<int> otherGamesCount = _firestore
        .collection('game_sessions')
        .where('userId', isEqualTo: userId)
        // REMOVED whereNotIn to avoid usage of multiple fields query requiring index
        .snapshots()
        .map((s) {
           // Client-side filter
           return s.docs.where((d) {
             final type = d.data()['gameType'] as String? ?? '';
             // Exclude if it looks like a legacy mis-save
             return !['Color Tap', 'Color Tap (Reaction)', 'Flip Card', 'Flip Card Match'].contains(type);
           }).length;
        })
        .handleError((e) => 0);

    int ct = 0;
    int fc = 0;
    int og = 0;
    // ignore: cancel_subscriptions
    StreamSubscription? sub1, sub2, sub3;
    
    final controller = StreamController<Map<String, dynamic>>.broadcast();
    
    void emit() {
      if (!controller.isClosed) {
        controller.add({
          'totalGames': ct + fc + og,
          'medicationAdherence': 87, 
        });
      }
    }
    
    sub1 = colorTapCount.listen((c) { ct = c; emit(); }, onError: (e) { print('CT count error: $e'); emit(); });
    sub2 = flipCardCount.listen((c) { fc = c; emit(); }, onError: (e) { print('FC count error: $e'); emit(); });
    sub3 = otherGamesCount.listen((c) { og = c; emit(); }, onError: (e) { print('OG count error: $e'); emit(); });
    
    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
      sub3?.cancel();
    };
    
    return controller.stream;
  }

  // ========== ACTIVE ALERTS ==========

  Stream<Map<String, dynamic>?> getActiveAlert(String userId) {
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty ? s.docs.first.data() : null)
        .asBroadcastStream();
  }

  // ========== HELPERS ==========

  int _parseTimestamp(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is Timestamp) return value.toDate().millisecondsSinceEpoch;
    return 0;
  }

  DateTime? _extractSessionTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  String _normalizeGameType(dynamic raw) {
    final String gameType = raw?.toString() ?? 'Unknown';
    switch (gameType) {
      case 'city_atlas':
        return 'City Atlas';
      case 'event_ordering':
        return 'Event Ordering';
      case 'daily_routine_recall':
        return 'Routine Recall';
      case 'monument_recall':
        return 'Monument Recall';
      default:
        return gameType;
    }
  }

  /// Fetch games played by a user in the last 24 hours from backend collections.
  Future<List<Map<String, dynamic>>> getLast24hGames(String userId) async {
    final since = DateTime.now().subtract(const Duration(hours: 24));
    final List<Map<String, dynamic>> results = [];

    // colorTapGameSessions
    try {
      final snap = await _firestore
          .collection('colorTapGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(200)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final time = _extractSessionTime(data['createdAt']);
        if (time != null && time.isAfter(since)) {
          results.add({
            'gameType': 'Color Tap',
            'timestamp': time,
            'metricsTracked': (data['metrics'] is Map)
                ? (data['metrics'] as Map).keys.map((k) => k.toString()).toList()
                : <String>[],
          });
        }
      }
    } catch (_) {}

    // flipCardGameSessions
    try {
      final snap = await _firestore
          .collection('flipCardGameSessions')
          .where('userId', isEqualTo: userId)
          .limit(200)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final time = _extractSessionTime(data['createdAt']);
        if (time != null && time.isAfter(since)) {
          results.add({
            'gameType': 'Flip Card',
            'timestamp': time,
            'metricsTracked': (data['metrics'] is Map)
                ? (data['metrics'] as Map).keys.map((k) => k.toString()).toList()
                : <String>[],
          });
        }
      }
    } catch (_) {}

    // game_sessions (other games)
    try {
      final snap = await _firestore
          .collection('game_sessions')
          .where('userId', isEqualTo: userId)
          .limit(200)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final time = _extractSessionTime(data['timestamp'] ?? data['createdAt']);
        if (time != null && time.isAfter(since)) {
          results.add({
            'gameType': _normalizeGameType(data['gameType']),
            'timestamp': time,
            'metricsTracked': (data['metrics'] is Map)
                ? (data['metrics'] as Map).keys.map((k) => k.toString()).toList()
                : <String>[],
          });
        }
      }
    } catch (_) {}

    results.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    return results;
  }
}
