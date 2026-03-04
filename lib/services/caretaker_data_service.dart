import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class CaretakerDataService {
  FirebaseFirestore? get _firestore {
    try {
      // Check if Firebase is initialized
      Firebase.app();
      print('📊 CaretakerDataService: Firebase is available');
      return FirebaseFirestore.instance;
    } catch (e) {
      // Firebase not initialized (e.g., on web without config)
      print('⚠️ CaretakerDataService: Firebase NOT available - returning mock data');
      print('   Reason: $e');
      return null;
    }
  }

  // Get Cognitive Health Score (0-100)
  // Logic: Base 50 + (Accuracy * 50) - (AvgReactionTime * 10)
  Stream<int> getCognitiveHealthScore(String userId) {
    if (_firestore == null) return Stream.value(70);
    
    return _firestore!
        .collection('game_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 70; // Baseline

      double totalAccuracy = 0;
      double totalReactionTime = 0;
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['metrics'] != null) {
          totalAccuracy += (data['metrics']['accuracy'] ?? 0.0);
          totalReactionTime += (data['metrics']['average_reaction_time'] ?? 1.0);
          count++;
        }
      }

      if (count == 0) return 70;

      double avgAcc = totalAccuracy / count;
      double avgTime = totalReactionTime / count;

      // Formula: Accuracy contributes up to 50, Speed penalty
      // Fast reaction (0.5s) -> Penalty 5. Slow (2.0s) -> Penalty 20.
      double score = 50 + (avgAcc * 50) - (avgTime * 10);
      return score.clamp(0, 100).toInt();
    });
  }

  // Get Domain Scores (Map of String -> Double 0-100)
  // Only Color Tap domains: Attention and Processing Speed
  Stream<Map<String, double>> getDomainScores(String userId) {
     // Return mock data if Firebase not available
     if (_firestore == null) {
       return Stream.value({
         'Attention': 75.0,
         'Processing Speed': 80.0,
       });
     }
     
     return _firestore!
        .collection('game_sessions')
        .where('userId', isEqualTo: userId)
        .where('gameType', isEqualTo: 'Color Tap (Reaction)') // Only Color Tap
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
           if (snapshot.docs.isEmpty) {
             return {
               'Attention': 0.0,
               'Processing Speed': 0.0,
             };
           }

           // Use latest session for instant feedback
           var latest = snapshot.docs.first.data();
           var metrics = latest['metrics'] ?? {};

           // Attention: Based on accuracy (correct taps vs total changes)
           double accuracy = (metrics['accuracy'] ?? 0.0) * 100;
           
           // Processing Speed: Based on reaction time (lower is better)
           // 0.5s = 100, 2.0s = 0
           double reactionTime = metrics['average_reaction_time'] ?? 1.0;
           double processingScore = ((2.0 - reactionTime) / 1.5 * 100).clamp(0.0, 100.0);

           return {
             'Attention': accuracy.clamp(0.0, 100.0),
             'Processing Speed': processingScore, 
           };
        });
  }

  // Get Recent Game Activity
  Stream<List<Map<String, dynamic>>> getRecentActivity(String userId) {
    if (_firestore == null) return Stream.value([]);
    
    return _firestore!
        .collection('game_sessions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'game': data['gameType'] ?? 'Unknown Game',
          'score': data['score'] ?? 0,
          'time': (data['createdAt'] as Timestamp).toDate(),
        };
      }).toList();
    });
  }
  
  // Get Color Tap Game Count
  Stream<int> getColorTapGameCount(String userId) {
    if (_firestore == null) return Stream.value(0);
    
    return _firestore!
        .collection('game_sessions')
        .where('userId', isEqualTo: userId)
        .where('gameType', isEqualTo: 'Color Tap (Reaction)')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // Get Color Tap Score History for Trend Chart
  Stream<List<Map<String, dynamic>>> getColorTapScoreHistory(String userId) {
    if (_firestore == null) return Stream.value([]);
    
    return _firestore!
        .collection('game_sessions')
        .where('userId', isEqualTo: userId)
        .where('gameType', isEqualTo: 'Color Tap (Reaction)')
        .orderBy('createdAt', descending: false) // Oldest first for chart
        .limit(10) // Last 10 games
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final metrics = data['metrics'] ?? {};
        final timestamp = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        // Calculate domain scores
        double accuracy = (metrics['accuracy'] ?? 0.0) * 100;
        double reactionTime = metrics['average_reaction_time'] ?? 1.0;
        double processingScore = ((2.0 - reactionTime) / 1.5 * 100).clamp(0.0, 100.0);
        
        return {
          'timestamp': timestamp,
          'attention': accuracy.clamp(0.0, 100.0),
          'processing': processingScore,
        };
      }).toList();
    });
  }
}
