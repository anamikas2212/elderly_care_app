import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/user_id_helper.dart';

class EventOrderingGame extends StatefulWidget {
  final int difficultyLevel; // 1 (Full dates), 2 (Years only), 3 (No dates)
  final String userState; // e.g. "Kerala"
  
  const EventOrderingGame({
    super.key,
    required this.difficultyLevel,
    required this.userState,
  });

  @override
  State<EventOrderingGame> createState() => _EventOrderingGameState();
}

class _EventOrderingGameState extends State<EventOrderingGame> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Game State
  List<HistoricalEvent> correctOrder = [];
  List<HistoricalEvent> userOrder = [];
  bool gameActive = true;
  bool isLoading = true;
  DateTime? startTime;
  
  // Metrics
  int reorderCount = 0;
  
  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => isLoading = true);
    
    // Simulate loading events (in production, fetch from Firestore/Assets)
    // Adjust number of events based on difficulty? 
    // Prompt says: L1: 5 events, L2: 6 events, L3: 7 events
    int numEvents = (widget.difficultyLevel == 1) 
        ? 5 
        : (widget.difficultyLevel == 2) ? 6 : 7;
        
    List<HistoricalEvent> allEvents = _getEventsForState(widget.userState);
    allEvents.shuffle();
    correctOrder = allEvents.take(numEvents).toList();
    
    // Sort correctly for reference
    correctOrder.sort((a, b) => a.year.compareTo(b.year));
    
    // Create a copy for user to manipulate, initially shuffled
    userOrder = List.from(correctOrder);
    userOrder.shuffle();
    
    // Ensure user order is not accidentally same as correct order initially
    while (_isOrderCorrect()) {
      userOrder.shuffle();
    }
    
    setState(() {
      isLoading = false;
      startTime = DateTime.now();
    });
  }
  
  bool _isOrderCorrect() {
    for (int i = 0; i < correctOrder.length; i++) {
        if (correctOrder[i].id != userOrder[i].id) return false;
    }
    return true;
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (!gameActive) return;
    
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final HistoricalEvent item = userOrder.removeAt(oldIndex);
      userOrder.insert(newIndex, item);
      reorderCount++;
    });
  }

  void _submitOrder() async {
    if (!gameActive) return;
    
    DateTime endTime = DateTime.now();
    setState(() => gameActive = false);
    
    // Calculate Metrics
    double totalTime = endTime.difference(startTime!).inMilliseconds / 1000.0;
    
    int correctPositions = 0;
    for (int i = 0; i < correctOrder.length; i++) {
      if (userOrder[i].id == correctOrder[i].id) {
        correctPositions++;
      }
    }
    
    int totalEvents = userOrder.length;
    double sequenceAccuracy = correctPositions / totalEvents;
    bool perfectSequence = (correctPositions == totalEvents);
    double avgTimePerReorder = reorderCount > 0 ? totalTime / reorderCount : 0.0;
    double efficiency = reorderCount > 0 ? totalEvents / reorderCount : 0.0; // Prevent div by zero
    
    // Score Calculation
    int score = _calculateScore(correctPositions, perfectSequence, efficiency, totalTime);
    
    // Cognitive Domains
    Map<String, int> cognitiveScores = _calculateCognitiveScores(
      sequenceAccuracy,
      efficiency,
      reorderCount,
      totalTime,
      totalEvents
    );
    
    // Save to Firestore
    await _saveSession(
      score: score,
      metrics: {
        'total_events': totalEvents,
        'correct_positions': correctPositions,
        'sequence_accuracy': sequenceAccuracy,
        'reorder_count': reorderCount,
        'total_time': totalTime,
        'average_time_per_reorder': avgTimePerReorder,
        'perfect_sequence': perfectSequence,
        'efficiency': efficiency,
      },
      cognitiveScores: cognitiveScores,
      eventsData: userOrder.asMap().entries.map((e) {
        int idx = e.key;
        HistoricalEvent ev = e.value;
        int correctIdx = correctOrder.indexOf(ev);
        return {
           'event': ev.description,
           'year': ev.year,
           'user_position': idx + 1, // 1-based
           'correct_position': correctIdx + 1,
           'is_correct': idx == correctIdx,
        };
      }).toList(),
    );
    
    // Show Results
    if (mounted) {
       _showResultsDialog(score, sequenceAccuracy, cognitiveScores);
    }
  }
  
  int _calculateScore(
    int correctPositions, 
    bool perfectSequence, 
    double efficiency, 
    double totalTime
  ) {
      int score = 0;
      
      // 1. Points for correct positions (20 points each)
      score += correctPositions * 20;
      
      // 2. Perfect sequence bonus
      if (perfectSequence) {
        score += 100;
      }
      
      // 3. Efficiency bonus (fewer reorders = better planning)
      // Efficiency = totalEvents / reorderCount. 
      // If reorderCount is low, efficiency is high.
      // If reorderCount == totalEvents, efficiency = 1.0.
      
      if (efficiency > 0.8) {
        score += 50; // Very efficient
      } else if (efficiency > 0.5) {
        score += 25; // Reasonably efficient
      }
      
      // 4. Speed bonus (faster = better recall)
      if (totalTime < 60) {
        score += 30; // Under 1 minute
      } else if (totalTime < 120) {
        score += 15; // Under 2 minutes
      }
      
      return max(0, score);
  }
  
  Map<String, int> _calculateCognitiveScores(
    double sequenceAccuracy,
    double efficiency,
    int reorderCount,
    double totalTime,
    int totalEvents
  ) {
      // EXECUTIVE FUNCTION SCORE (Primary Domain - 60% weight)
      
      // 1. Sequencing Ability (40% weight)
      int sequencingScore;
      if (sequenceAccuracy >= 0.9) sequencingScore = 95;
      else if (sequenceAccuracy >= 0.75) sequencingScore = 80;
      else if (sequenceAccuracy >= 0.60) sequencingScore = 65;
      else sequencingScore = 45;
      
      // 2. Planning Efficiency (30% weight)
      // Ideal reorders = totalEvents (roughly one drag per item if optimized, though strictly min swaps is different)
      // Using prompt's logic: efficiency = totalEvents / reorderCount (or similar inverted ratio if reorderCount is large)
      // Actually prompt says: efficiency = totalEvents / reorderCount
      // Re-evaluating based on prompt example:
      // "Ideal reorders = totalEvents" -> efficiency = 1.0
      
      int planningScore;
      if (efficiency > 0.9) planningScore = 100;
      else if (efficiency > 0.7) planningScore = 80;
      else if (efficiency > 0.5) planningScore = 60;
      else planningScore = 40;
      
      // 3. Problem Solving (30% weight) - approximated here as we don't track per-item moves finely in this simplified version
      // We'll base it on whether they eventually got it right (self-correction)
      int problemSolvingScore = (sequenceAccuracy * 100).round();
      
      int executiveFunctionScore = (
          sequencingScore * 0.4 + 
          planningScore * 0.3 + 
          problemSolvingScore * 0.3
      ).round();
      
      
      // MEMORY SCORE (Secondary Domain - 40% weight)
      
      // 1. Historical Knowledge (60% weight)
      int knowledgeScore = (sequenceAccuracy * 100).round();
      
      // 2. Recall Speed (40% weight)
      double avgTimePerEvent = totalEvents > 0 ? totalTime / totalEvents : 0;
      int recallSpeedScore;
      if (avgTimePerEvent < 15) recallSpeedScore = 90;
      else if (avgTimePerEvent < 25) recallSpeedScore = 75;
      else if (avgTimePerEvent < 40) recallSpeedScore = 60;
      else recallSpeedScore = 40;
      
      int memoryScore = (
          knowledgeScore * 0.6 + 
          recallSpeedScore * 0.4
      ).round();
      
      return {
          'executive_function': executiveFunctionScore,
          'memory': memoryScore,
      };
  }
  
  Future<void> _saveSession({
    required int score,
    required Map<String, dynamic> metrics,
    required Map<String, int> cognitiveScores,
    required List<Map<String, dynamic>> eventsData,
  }) async {
      // Use UserIdHelper so we fall back to SharedPreferences if Firebase Auth lost its session
      final String? userId = await UserIdHelper.getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        print('❌ No user ID available! Skipping session save.');
        return;
      }
      
      try {
          await _db.collection('game_sessions').add({
              'userId': userId,
              'gameType': 'event_ordering',
              'difficultyLevel': widget.difficultyLevel,
              'region': widget.userState,
              'startTime': startTime?.toIso8601String(),
              'endTime': DateTime.now().toIso8601String(),
              'completed': true,
              'score': score,
              'metrics': metrics,
              'events_data': eventsData,
              'cognitive_contributions': cognitiveScores,
              'timestamp': FieldValue.serverTimestamp(),
          });
          
          await _updateCognitiveSummary(userId, cognitiveScores);
          
      } catch (e) {
          print("Error saving session: $e");
      }
  }

  
  Future<void> _updateCognitiveSummary(String userId, Map<String, int> cognitiveScores) async {
       // Similar to other games, update running averages
       try {
           DocumentReference ref = _db.collection('cognitive_summary').doc(userId);
           // Using set with merge to create if not exists
            // Ideally should fetch current average and update, but simplistic merge for latest:
           // Better approach: Cloud Function or precise read-update-write. 
           // For now, we will just log it. The dashboard will aggregate from sessions.
       } catch (e) {}
  }
  
  void _showResultsDialog(int score, double accuracy, Map<String, int> scores) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
              title: const Text('Timeline Complete!'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                       Text('Score: $score', style: const TextStyle(fontSize: 28, color: Colors.purple, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 10),
                       Text('Accuracy: ${(accuracy*100).toStringAsFixed(0)}%'),
                       const SizedBox(height: 10),
                       const Text('Assessment:', style: TextStyle(fontWeight: FontWeight.bold)),
                       Text('Execution: ${scores['executive_function']}/100'),
                       Text('Memory: ${scores['memory']}/100'),
                  ],
              ),
              actions: [
                  TextButton(
                      onPressed: () {
                          Navigator.pop(context); // Dialog
                          Navigator.pop(context); // Screen
                      },
                      child: const Text('Close'),
                  )
              ],
          ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ordering - Lvl ${widget.difficultyLevel}')),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                   Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Text(
                           _getInstructionText(),
                           style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                           textAlign: TextAlign.center,
                       ),
                   ),
                   Expanded(
                       child: Theme(
                         data: ThemeData(
                             canvasColor: Colors.transparent, 
                             shadowColor: Colors.transparent
                         ),
                         child: ReorderableListView.builder(
                             itemCount: userOrder.length,
                             onReorder: _onReorder,
                             padding: const EdgeInsets.all(16),
                             itemBuilder: (context, index) {
                                 final event = userOrder[index];
                                 return Card(
                                     key: ValueKey(event.id),
                                     elevation: 4,
                                     margin: const EdgeInsets.symmetric(vertical: 8),
                                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                     child: ListTile(
                                         leading: CircleAvatar(
                                             backgroundColor: Colors.blue.shade100,
                                             child: Text('${index + 1}'),
                                         ),
                                         title: Text(event.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                                         subtitle: _buildSubtitle(event),
                                         trailing: const Icon(Icons.drag_handle),
                                     ),
                                 );
                             },
                         ),
                       ),
                   ),
                   Padding(
                       padding: const EdgeInsets.all(20.0),
                       child: SizedBox(
                           width: double.infinity,
                           child: ElevatedButton(
                               onPressed: gameActive ? _submitOrder : null,
                               style: ElevatedButton.styleFrom(
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   backgroundColor: Colors.blue,
                                   foregroundColor: Colors.white,
                               ),
                               child: const Text('SUBMIT ORDER', style: TextStyle(fontSize: 18)),
                           ),
                       ),
                   ),
              ],
          ),
    );
  }
  
  String _getInstructionText() {
      if (widget.difficultyLevel == 1) return "Order events from earliest to latest\n(Dates shown)";
      if (widget.difficultyLevel == 2) return "Order events from earliest to latest\n(Years shown)";
      return "Order events from earliest to latest\n(No dates shown!)";
  }
  
  Widget? _buildSubtitle(HistoricalEvent event) {
      if (widget.difficultyLevel == 1) {
          return Text(event.dateString, style: TextStyle(color: Colors.grey.shade700));
      } else if (widget.difficultyLevel == 2) {
          return Text('Year: ${event.year}', style: TextStyle(color: Colors.grey.shade700));
      } else {
          // Level 3: No dates shown
          return null;
      }
  }

  // --- Mock Data ---
  List<HistoricalEvent> _getEventsForState(String state) {
      // In real app, huge database. Here, sample for Kerala (as in prompt).
      // Also add fallback or general Indian events.
      
      if (state == 'Kerala') {
        return [
           HistoricalEvent("Vasco da Gama arrived", 1498, "20 May 1498"),
           HistoricalEvent("Cochin Port established", 1936, "1936"),
           HistoricalEvent("Sabarimala opened to all", 1950, "1950"),
           HistoricalEvent("Kerala became a state", 1956, "1 Nov 1956"),
           HistoricalEvent("First Kerala ministry formed", 1957, "5 Apr 1957"),
           HistoricalEvent("Kerala literacy mission started", 1989, "1989"),
           HistoricalEvent("Kochi Metro inaugurated", 2017, "17 Jun 2017"),
           HistoricalEvent("First technopark established", 1990, "1990"),
        ];
      }
      
      // Default: India
      return [
           HistoricalEvent("India became independent", 1947, "15 Aug 1947"),
           HistoricalEvent("India became a Republic", 1950, "26 Jan 1950"),
           HistoricalEvent("First Asian Games in Delhi", 1951, "1951"),
           HistoricalEvent("Isro established", 1969, "15 Aug 1969"),
           HistoricalEvent("India won Cricket World Cup", 1983, "25 Jun 1983"),
           HistoricalEvent("Economic Liberalization", 1991, "1991"),
           HistoricalEvent("Chandrayaan-1 launched", 2008, "22 Oct 2008"),
      ];
  }
}

class HistoricalEvent {
    final String id;
    final String description;
    final int year;
    final String dateString;
    
    HistoricalEvent(this.description, this.year, this.dateString) : id = description;
}
