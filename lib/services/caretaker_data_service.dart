import 'package:cloud_firestore/cloud_firestore.dart';

class CaretakerDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ✅ HELPER METHOD: Convert Timestamp to readable string
  String _formatTimestamp(dynamic value, {String defaultValue = "Unknown"}) {
    if (value == null) return defaultValue;
    
    if (value is String) {
      return value;
    } else if (value is Timestamp) {
      final DateTime dateTime = value.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    }
    
    return defaultValue;
  }
  
  // ✅ FIXED: Get user profile with proper Timestamp handling
  Stream<Map<String, dynamic>> getUserProfile(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return {};
      final data = doc.data() ?? {};
      return {
        'name': data['name'] ?? userId,
        'age': data['age'],
        'gender': data['gender'],
        'location': data['location'],
        'lastActive': _formatTimestamp(data['lastActive'], defaultValue: 'Never'), // ✅ FIXED
        'status': data['status'] ?? 'Active',
      };
    });
  }

  // Calculate cognitive health score from game sessions
  Stream<Map<String, dynamic>> calculateCognitiveHealthScore(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return {
              'healthScore': 0,
              'totalSessions': 0,
              'avgAccuracy': 0.0,
              'avgReactionTime': 0.0,
            };
          }

          int totalSessions = snapshot.docs.length;
          double totalAccuracy = 0;
          double totalReactionTime = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final correctTaps = data['correct_taps'] as int? ?? 0;
            final falseTaps = data['false_taps'] as int? ?? 0;
            final totalTaps = correctTaps + falseTaps;

            if (totalTaps > 0) {
              totalAccuracy += (correctTaps / totalTaps * 100);
            }

            totalReactionTime +=
                (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;
          }

          double avgAccuracy =
              totalSessions > 0 ? totalAccuracy / totalSessions : 0;
          double avgReactionTime =
              totalSessions > 0 ? totalReactionTime / totalSessions : 0;

          double reactionTimeScore = 0;
          if (avgReactionTime > 0) {
            reactionTimeScore = ((1.5 - avgReactionTime) / 1.0 * 100).clamp(0, 100);
          }

          int healthScore =
              ((avgAccuracy * 0.5) + (reactionTimeScore * 0.5)).round();
          healthScore = healthScore.clamp(0, 100);

          return {
            'healthScore': healthScore,
            'totalSessions': totalSessions,
            'avgAccuracy': avgAccuracy,
            'avgReactionTime': avgReactionTime,
          };
        });
  }

  // Calculate domain scores based on game metrics
  Stream<Map<String, dynamic>> calculateDomainScores(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return {
              'attentionScore': 0.0,
              'processingSpeedScore': 0.0,
              'sessionsCount': 0,
            };
          }

          int totalSessions = snapshot.docs.length;
          double totalAccuracy = 0;
          double totalReactionTime = 0;
          double totalFalseRate = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final correctTaps = data['correct_taps'] as int? ?? 0;
            final falseTaps = data['false_taps'] as int? ?? 0;
            final totalTaps = correctTaps + falseTaps;

            if (totalTaps > 0) {
              totalAccuracy += (correctTaps / totalTaps * 100);
              totalFalseRate += (falseTaps / totalTaps * 100);
            }

            totalReactionTime +=
                (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;
          }

          double avgAccuracy =
              totalSessions > 0 ? totalAccuracy / totalSessions : 0;
          double avgReactionTime =
              totalSessions > 0 ? totalReactionTime / totalSessions : 0;
          double avgFalseRate =
              totalSessions > 0 ? totalFalseRate / totalSessions : 0;

          double attentionScore =
              (avgAccuracy * 0.7) + ((100 - avgFalseRate) * 0.3);
          attentionScore = attentionScore.clamp(0, 100);

          double processingSpeedScore = 0;
          if (avgReactionTime > 0) {
            if (avgReactionTime <= 0.5) {
              processingSpeedScore = 100;
            } else if (avgReactionTime <= 0.8) {
              processingSpeedScore = 100 - ((avgReactionTime - 0.5) / 0.3 * 20);
            } else if (avgReactionTime <= 1.0) {
              processingSpeedScore = 80 - ((avgReactionTime - 0.8) / 0.2 * 20);
            } else if (avgReactionTime <= 1.5) {
              processingSpeedScore = 60 - ((avgReactionTime - 1.0) / 0.5 * 30);
            } else {
              processingSpeedScore = 30;
            }
          }
          processingSpeedScore = processingSpeedScore.clamp(0, 100);

          return {
            'attentionScore': attentionScore,
            'processingSpeedScore': processingSpeedScore,
            'sessionsCount': totalSessions,
          };
        });
  }

  // Get detailed game metrics
  Stream<Map<String, dynamic>> getDetailedGameMetrics(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            return {
              'accuracy': 0.0,
              'avgReactionTime': 0.0,
              'totalCorrectTaps': 0,
              'totalFalseTaps': 0,
              'totalMissedTaps': 0,
            };
          }

          int totalCorrectTaps = 0;
          int totalFalseTaps = 0;
          int totalMissedTaps = 0;
          double totalReactionTime = 0;
          int sessionCount = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            totalCorrectTaps += data['correct_taps'] as int? ?? 0;
            totalFalseTaps += data['false_taps'] as int? ?? 0;
            totalMissedTaps += data['missed_taps'] as int? ?? 0;
            totalReactionTime +=
                (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;
            sessionCount++;
          }

          int totalAttempts = totalCorrectTaps + totalFalseTaps;
          double accuracy =
              totalAttempts > 0 ? (totalCorrectTaps / totalAttempts * 100) : 0;
          double avgReactionTime =
              sessionCount > 0 ? totalReactionTime / sessionCount : 0;

          return {
            'accuracy': accuracy,
            'avgReactionTime': avgReactionTime,
            'totalCorrectTaps': totalCorrectTaps,
            'totalFalseTaps': totalFalseTaps,
            'totalMissedTaps': totalMissedTaps,
          };
        });
  }

  // ✅ FIXED: Get recent game sessions with proper timestamp conversion
  Stream<List<Map<String, dynamic>>> getRecentGameSessions(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            
            // ✅ Convert Timestamp to milliseconds for dashboard
            if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
              data['createdAt'] = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
            }
            
            return data;
          }).toList();
        });
  }

  // Get overall statistics
  Stream<Map<String, dynamic>> getOverallStatistics(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return {
            'totalGames': snapshot.docs.length,
            'medicationAdherence': 87,
          };
        });
  }

  // Get active alert
  Stream<Map<String, dynamic>?> getActiveAlert(String userId) {
    return _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return snapshot.docs.first.data();
        });
  }

  // ✅ FIXED: Get score history with timestamp conversion
  Stream<List<Map<String, dynamic>>> getColorTapScoreHistory(String userId) {
    return _firestore
        .collection('colorTapGameSessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: false)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final correctTaps = data['correct_taps'] as int? ?? 0;
            final falseTaps = data['false_taps'] as int? ?? 0;
            final totalTaps = correctTaps + falseTaps;
            final avgReactionTime =
                (data['average_reaction_time'] as num?)?.toDouble() ?? 0.0;

            double attentionScore = 0;
            if (totalTaps > 0) {
              attentionScore = (correctTaps / totalTaps * 100);
            }

            double processingSpeedScore = 0;
            if (avgReactionTime > 0) {
              if (avgReactionTime <= 0.5) {
                processingSpeedScore = 100;
              } else if (avgReactionTime <= 0.8) {
                processingSpeedScore =
                    100 - ((avgReactionTime - 0.5) / 0.3 * 20);
              } else if (avgReactionTime <= 1.0) {
                processingSpeedScore =
                    80 - ((avgReactionTime - 0.8) / 0.2 * 20);
              } else if (avgReactionTime <= 1.5) {
                processingSpeedScore =
                    60 - ((avgReactionTime - 1.0) / 0.5 * 30);
              } else {
                processingSpeedScore = 30;
              }
            }
            processingSpeedScore = processingSpeedScore.clamp(0, 100);

            // ✅ Convert Timestamp to milliseconds
            int createdAtMs = 0;
            if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
              createdAtMs = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
            }

            return {
              'attention': attentionScore,
              'processing': processingSpeedScore,
              'createdAt': createdAtMs,
            };
          }).toList();
        });
  }
}