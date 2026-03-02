import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_id_helper.dart';

class DailyRoutineRecallGame extends StatefulWidget {
  final String userId;
  const DailyRoutineRecallGame({super.key, required this.userId});

  @override
  State<DailyRoutineRecallGame> createState() => _DailyRoutineRecallGameState();
}

class _DailyRoutineRecallGameState extends State<DailyRoutineRecallGame> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Phase management
  // Phase 1: Schedule builder (step by step)
  // Phase 2: Memorize (30 second display)
  // Phase 3: Recall test (reorder scrambled steps)
  String _currentPhase = 'loading'; // loading, setup, memorize, recall, result
  
  // Schedule data
  List<ScheduleStep> _savedSchedule = [];
  List<ScheduleStep> _scrambledSchedule = [];
  int _scheduleSessionCount = 0; // How many sessions played with current schedule
  
  // Setup phase
  int _currentSetupStep = 0;
  List<ScheduleStep> _buildingSchedule = [];
  
  // Memorize phase
  int _memorizeCountdown = 30;
  Timer? _memorizeTimer;
  
  // Recall phase
  DateTime? _recallStartTime;
  int _reorderCount = 0;
  
  // Available activities for schedule building
  final List<List<ActivityOption>> _activityOptions = [
    // Step 1: Morning start
    [
      ActivityOption('🌅 Wake up early (6-7 AM)', 'wake_early', '06:30'),
      ActivityOption('😴 Wake up moderate (7-8 AM)', 'wake_moderate', '07:30'),
      ActivityOption('🌄 Wake up late (8-9 AM)', 'wake_late', '08:30'),
      ActivityOption('🧘 Wake up with stretching', 'wake_stretch', '07:00'),
    ],
    // Step 2: Morning hygiene
    [
      ActivityOption('🪥 Brush & freshen up', 'freshen_up', '07:00'),
      ActivityOption('🚿 Bath & get ready', 'bath', '07:15'),
      ActivityOption('🧼 Full morning routine', 'full_routine', '07:00'),
      ActivityOption('💆 Light freshening up', 'light_freshen', '07:00'),
    ],
    // Step 3: Breakfast
    [
      ActivityOption('🥣 Heavy breakfast', 'breakfast_heavy', '08:00'),
      ActivityOption('🍞 Light breakfast', 'breakfast_light', '08:00'),
      ActivityOption('🥤 Just tea/coffee', 'tea_coffee', '07:30'),
      ActivityOption('🍎 Fruits & juice', 'fruits', '08:00'),
    ],
    // Step 4: Morning activity
    [
      ActivityOption('🚶 Morning walk', 'morning_walk', '09:00'),
      ActivityOption('🧘 Yoga/Exercise', 'yoga', '09:00'),
      ActivityOption('🪴 Gardening', 'gardening', '09:00'),
      ActivityOption('📖 Reading newspaper', 'reading', '09:00'),
      ActivityOption('🙏 Prayer/Meditation', 'prayer', '09:00'),
    ],
    // Step 5: Mid-day
    [
      ActivityOption('💊 Take medications', 'medications', '10:30'),
      ActivityOption('📺 Watch TV/News', 'tv', '10:30'),
      ActivityOption('👥 Visit neighbors', 'neighbors', '10:30'),
      ActivityOption('📞 Phone calls to family', 'phone_calls', '10:30'),
    ],
    // Step 6: Lunch
    [
      ActivityOption('🍛 Full lunch', 'lunch_full', '12:30'),
      ActivityOption('🥗 Light lunch', 'lunch_light', '13:00'),
      ActivityOption('🍲 Traditional meal', 'lunch_traditional', '12:00'),
    ],
    // Step 7: Afternoon
    [
      ActivityOption('😴 Afternoon nap', 'afternoon_nap', '14:00'),
      ActivityOption('🎵 Listen to music', 'music', '14:00'),
      ActivityOption('🧩 Puzzles/Games', 'games', '14:00'),
      ActivityOption('👐 Crafts/Hobbies', 'hobbies', '14:00'),
      ActivityOption('📚 Afternoon reading', 'afternoon_reading', '14:00'),
    ],
    // Step 8: Evening
    [
      ActivityOption('☕ Evening tea & snacks', 'evening_tea', '16:00'),
      ActivityOption('🚶 Evening walk', 'evening_walk', '17:00'),
      ActivityOption('🛕 Temple/Church visit', 'temple', '17:00'),
      ActivityOption('👨‍👩‍👧 Family time', 'family_time', '17:00'),
    ],
    // Step 9: Dinner
    [
      ActivityOption('🍽️ Early dinner (7 PM)', 'dinner_early', '19:00'),
      ActivityOption('🍽️ Regular dinner (8 PM)', 'dinner_regular', '20:00'),
      ActivityOption('🥣 Light dinner (soup/porridge)', 'dinner_light', '19:30'),
    ],
    // Step 10: Bedtime
    [
      ActivityOption('💊 Night medication', 'night_meds', '21:00'),
      ActivityOption('📖 Bedtime reading', 'bedtime_reading', '21:00'),
      ActivityOption('🙏 Night prayer', 'night_prayer', '21:00'),
      ActivityOption('😴 Early sleep (9-10 PM)', 'sleep_early', '21:30'),
      ActivityOption('😴 Regular sleep (10-11 PM)', 'sleep_regular', '22:30'),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _memorizeTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // Check if user has an active schedule
      final scheduleDoc = await _db.collection('user_schedules')
          .doc(widget.userId)
          .get();
      
      if (scheduleDoc.exists) {
        final data = scheduleDoc.data()!;
        final int sessionCount = (data['sessionCount'] as num?)?.toInt() ?? 0;
        final List<dynamic> steps = data['steps'] ?? [];
        
        if (steps.isNotEmpty && sessionCount < 7) {
          // Load existing schedule
          _savedSchedule = steps.map((s) => ScheduleStep(
            label: s['label'] as String,
            id: s['id'] as String,
            time: s['time'] as String,
            stepNumber: (s['stepNumber'] as num).toInt(),
          )).toList();
          _scheduleSessionCount = sessionCount;
          
          // Start memorize phase
          setState(() => _currentPhase = 'memorize');
          _startMemorizeTimer();
          return;
        }
      }
      
      // No schedule or expired → setup new schedule
      setState(() => _currentPhase = 'setup');
    } catch (e) {
      setState(() => _currentPhase = 'setup');
    }
  }

  // ==========================================
  // PHASE 1: Schedule Setup (Step by Step)
  // ==========================================
  
  void _selectActivity(ActivityOption option) {
    setState(() {
      _buildingSchedule.add(ScheduleStep(
        label: option.label,
        id: option.id,
        time: option.time,
        stepNumber: _currentSetupStep + 1,
      ));
      
      if (_currentSetupStep < _activityOptions.length - 1) {
        _currentSetupStep++;
      } else {
        // Schedule complete — save it
        _saveSchedule();
      }
    });
  }

  Future<void> _saveSchedule() async {
    _savedSchedule = List.from(_buildingSchedule);
    _scheduleSessionCount = 0;
    
    try {
      await _db.collection('user_schedules').doc(widget.userId).set({
        'steps': _savedSchedule.map((s) => {
          'label': s.label,
          'id': s.id,
          'time': s.time,
          'stepNumber': s.stepNumber,
        }).toList(),
        'sessionCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    
    // Show the schedule for memorization
    setState(() => _currentPhase = 'memorize');
    _startMemorizeTimer();
  }

  // ==========================================
  // PHASE 2: Memorize (30 seconds)
  // ==========================================
  
  void _startMemorizeTimer() {
    _memorizeCountdown = 30;
    _memorizeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _memorizeCountdown--;
        if (_memorizeCountdown <= 0) {
          timer.cancel();
          _startRecallPhase();
        }
      });
    });
  }

  // ==========================================
  // PHASE 3: Recall Test (Reorder)
  // ==========================================
  
  void _startRecallPhase() {
    _scrambledSchedule = List.from(_savedSchedule);
    // Ensure it's actually scrambled
    do {
      _scrambledSchedule.shuffle(Random());
    } while (_isOrderCorrect(_scrambledSchedule));
    
    _reorderCount = 0;
    _recallStartTime = DateTime.now();
    setState(() => _currentPhase = 'recall');
  }

  bool _isOrderCorrect(List<ScheduleStep> order) {
    for (int i = 0; i < _savedSchedule.length; i++) {
      if (order[i].id != _savedSchedule[i].id) return false;
    }
    return true;
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _scrambledSchedule.removeAt(oldIndex);
      _scrambledSchedule.insert(newIndex, item);
      _reorderCount++;
    });
  }

  Future<void> _submitRecallOrder() async {
    DateTime endTime = DateTime.now();
    double totalTime = endTime.difference(_recallStartTime!).inMilliseconds / 1000.0;
    
    // Calculate accuracy
    int correctPositions = 0;
    for (int i = 0; i < _savedSchedule.length; i++) {
      if (_scrambledSchedule[i].id == _savedSchedule[i].id) {
        correctPositions++;
      }
    }
    
    int totalSteps = _savedSchedule.length;
    double orderAccuracy = correctPositions / totalSteps;
    bool perfectOrder = correctPositions == totalSteps;
    double efficiency = _reorderCount > 0 ? totalSteps / _reorderCount : 0;
    
    // Score calculation
    int score = 0;
    score += correctPositions * 15;
    if (perfectOrder) score += 50;
    if (efficiency > 0.8) score += 30;
    else if (efficiency > 0.5) score += 15;
    if (totalTime < 30) score += 20;
    else if (totalTime < 60) score += 10;
    
    // Cognitive scores
    // Memory (primary): recall accuracy + speed
    int recallSpeedScore;
    if (totalTime < 20) recallSpeedScore = 100;
    else if (totalTime < 40) recallSpeedScore = 85;
    else if (totalTime < 60) recallSpeedScore = 70;
    else recallSpeedScore = 55;
    
    int memoryScore = (orderAccuracy * 100 * 0.6 + recallSpeedScore * 0.4).round();
    
    // Executive Function (secondary): planning efficiency
    int planningScore;
    if (efficiency > 0.9) planningScore = 100;
    else if (efficiency > 0.7) planningScore = 80;
    else if (efficiency > 0.5) planningScore = 60;
    else planningScore = 40;
    
    int execFunctionScore = (planningScore * 0.5 + (correctPositions / totalSteps * 100) * 0.5).round();
    
    Map<String, int> cognitiveScores = {
      'memory': memoryScore,
      'executive_function': execFunctionScore,
    };
    
    // Save session
    try {
      final userId = await UserIdHelper.getCurrentUserId();
      if (userId != null && userId.isNotEmpty) {
        await _db.collection('game_sessions').add({
          'userId': userId,
          'gameType': 'daily_routine_recall',
          'timestamp': FieldValue.serverTimestamp(),
          'completed': true,
          'score': score,
          'metrics': {
            'total_steps': totalSteps,
            'correct_positions': correctPositions,
            'order_accuracy': orderAccuracy,
            'reorder_count': _reorderCount,
            'total_time': totalTime,
            'efficiency': efficiency,
            'perfect_order': perfectOrder,
          },
          'cognitive_contributions': cognitiveScores,
          'recall_details': _scrambledSchedule.asMap().entries.map((e) {
            int idx = e.key;
            return {
              'step': e.value.label,
              'user_position': idx + 1,
              'correct_position': e.value.stepNumber,
              'is_correct': _scrambledSchedule[idx].id == _savedSchedule[idx].id,
            };
          }).toList(),
        });
        
        // Increment session count for schedule
        _scheduleSessionCount++;
        await _db.collection('user_schedules').doc(userId).update({
          'sessionCount': _scheduleSessionCount,
        });
      }
    } catch (_) {}
    
    // Show result
    setState(() => _currentPhase = 'result');
    _showResultDialog(score, orderAccuracy, cognitiveScores, correctPositions, totalSteps);
  }

  void _showResultDialog(int score, double accuracy, Map<String, int> scores, int correct, int total) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(
              accuracy > 0.7 ? Icons.psychology : Icons.psychology_alt,
              color: accuracy > 0.7 ? Colors.green : Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text('Recall Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $score', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            Text('$correct / $total steps correct', style: const TextStyle(fontSize: 16)),
            Text('Accuracy: ${(accuracy * 100).toStringAsFixed(0)}%', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            const Divider(),
            const Text('Cognitive Assessment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildScoreRow('Memory', scores['memory'] ?? 0, Colors.purple),
            const SizedBox(height: 4),
            _buildScoreRow('Executive Function', scores['executive_function'] ?? 0, Colors.orange),
            const SizedBox(height: 12),
            Text(
              'Schedule: Session ${_scheduleSessionCount}/7',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, int score, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: color)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$score/100', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  // ==========================================
  // BUILD UI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    switch (_currentPhase) {
      case 'loading':
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case 'setup':
        return _buildSetupScreen();
      case 'memorize':
        return _buildMemorizeScreen();
      case 'recall':
        return _buildRecallScreen();
      case 'result':
        return Scaffold(
          appBar: AppBar(title: const Text('Daily Routine')),
          body: const Center(child: Text('Session Complete!')),
        );
      default:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
  }

  // ---- Setup Screen ----
  Widget _buildSetupScreen() {
    final stepOptions = _activityOptions[_currentSetupStep];
    final stepLabels = [
      'Morning Start', 'Morning Hygiene', 'Breakfast', 'Morning Activity',
      'Mid-Morning', 'Lunch', 'Afternoon', 'Evening', 'Dinner', 'Bedtime',
    ];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Your Schedule'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                'Step ${_currentSetupStep + 1}/${_activityOptions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentSetupStep + 1) / _activityOptions.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  stepLabels[_currentSetupStep],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your activity for this part of the day',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          
          // Already selected steps
          if (_buildingSchedule.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.teal, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_buildingSchedule.length} step${_buildingSchedule.length > 1 ? "s" : ""} set: ${_buildingSchedule.last.label}',
                      style: TextStyle(color: Colors.teal.shade800, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Options
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: stepOptions.length,
              itemBuilder: (context, index) {
                final option = stepOptions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectActivity(option),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option.label,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Memorize Screen ----
  Widget _buildMemorizeScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memorize Your Schedule'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Countdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: _memorizeCountdown <= 10 ? Colors.red.shade50 : Colors.blue.shade50,
            child: Column(
              children: [
                Text(
                  '$_memorizeCountdown',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _memorizeCountdown <= 10 ? Colors.red : Colors.blue,
                  ),
                ),
                Text(
                  'seconds to memorize',
                  style: TextStyle(
                    color: _memorizeCountdown <= 10 ? Colors.red.shade700 : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          // Schedule display
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedSchedule.length,
              itemBuilder: (context, index) {
                final step = _savedSchedule[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(step.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: Text(step.time, style: TextStyle(color: Colors.grey.shade600)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Recall Screen ----
  Widget _buildRecallScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recall Your Schedule'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(Icons.touch_app, color: Colors.amber.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Drag and reorder the steps to match your schedule!',
                    style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Theme(
              data: ThemeData(
                canvasColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: ReorderableListView.builder(
                itemCount: _scrambledSchedule.length,
                onReorder: _onReorder,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final step = _scrambledSchedule[index];
                  return Card(
                    key: ValueKey(step.id),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                        ),
                      ),
                      title: Text(step.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitRecallOrder,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('SUBMIT ORDER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// DATA MODELS
// ==========================================

class ScheduleStep {
  final String label;
  final String id;
  final String time;
  final int stepNumber;
  
  ScheduleStep({
    required this.label,
    required this.id,
    required this.time,
    required this.stepNumber,
  });
}

class ActivityOption {
  final String label;
  final String id;
  final String time;
  
  ActivityOption(this.label, this.id, this.time);
}
