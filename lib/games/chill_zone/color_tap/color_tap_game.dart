import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../../services/game_services/session_tracker.dart';
import 'color_tap_timer.dart';
import 'color_circle_widget.dart';

// Data class moved to color_circle_widget.dart

class ColorTapGame extends StatefulWidget {
  final int difficultyLevel; // 1, 2, or 3
  final String userId;

  const ColorTapGame({
    super.key,
    required this.difficultyLevel,
    required this.userId,
  });

  @override
  State<ColorTapGame> createState() => _ColorTapGameState();
}

class _ColorTapGameState extends State<ColorTapGame> {
  // TRACKING VARIABLES
  Color currentColor = Colors.grey;
  DateTime? colorChangeTime;
  bool waitingForTap = false;

  // METRICS TO TRACK
  List<double> reactionTimes = [];
  int totalColorChanges = 0;
  int correctTaps = 0;
  int falseTaps = 0;
  int missedTaps = 0;

  late ColorTapTimer gameTimer;
  Timer? colorChangeTimer;

  // GAME STATE
  String feedbackMessage = "Wait for color...";
  Color feedbackColor = Colors.black;
  bool isGameActive = false;
  String? tapResult; // 'correct', 'false', or null

  late SessionTracker _sessionTracker;

  @override
  void initState() {
    super.initState();
    _sessionTracker = SessionTracker(
      userId: widget.userId,
      gameName: 'Color Tap (Reaction)',
      difficulty: widget.difficultyLevel,
    );
    _sessionTracker.startSession();

    // Initialize standard game timer
    gameTimer = ColorTapTimer(
      duration: 60,
      onTick: (seconds) {
        if (mounted) setState(() {}); // Update UI every second
      },
      onComplete: endGame,
    );

    startGame();
  }

  void startGame() {
    setState(() {
      isGameActive = true;
      feedbackMessage = "Get ready...";
    });

    gameTimer.start();
    scheduleColorChange();
  }

  void scheduleColorChange() {
    if (!isGameActive) return;

    // Difficulty Logic (Requested by User)
    // Level 1: 2.0s
    // Level 2: 1.8s
    // Level 3: 1.4s
    double interval =
        widget.difficultyLevel == 1
            ? 2.0
            : widget.difficultyLevel == 2
            ? 1.8
            : 1.4;

    // Add random variation (±0.3s)
    double randomVariation = Random().nextDouble() * 0.6 - 0.3;
    double actualInterval = interval + randomVariation;

    // Reset to neutral
    setState(() {
      currentColor = Colors.grey.shade300;
      waitingForTap = false;
      feedbackMessage = "Wait...";
    });

    colorChangeTimer = Timer(
      Duration(milliseconds: (actualInterval * 1000).toInt()),
      () {
        changeColor();
      },
    );
  }

  void changeColor() {
    if (!isGameActive) return;

    setState(() {
      List<Color> colors = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
      ];
      currentColor = colors[Random().nextInt(colors.length)];

      colorChangeTime = DateTime.now();
      waitingForTap = true;
      totalColorChanges++;
      feedbackMessage = "TAP NOW!";
    });

    // Auto-mark as missed after 1.5 seconds if not tapped
    Timer(const Duration(milliseconds: 1500), () {
      if (waitingForTap && isGameActive) {
        setState(() {
          missedTaps++;
          waitingForTap = false;
          feedbackMessage = "Missed!";
          feedbackColor = Colors.red;
        });
        scheduleColorChange();
      }
    });
  }

  void onScreenTapped(Color tappedColor) {
    if (!isGameActive) return;

    if (waitingForTap && colorChangeTime != null) {
      // ✅ CORRECT TAP
      DateTime tapTime = DateTime.now();
      double reactionTime =
          tapTime.difference(colorChangeTime!).inMilliseconds / 1000.0;

      reactionTimes.add(reactionTime);
      correctTaps++;
      waitingForTap = false;

      setState(() {
        tapResult = 'correct';
        feedbackMessage = "Nice! ${reactionTime.toStringAsFixed(2)}s";
        feedbackColor = Colors.green;
      });

      _sessionTracker.recordAction('correct_tap', {
        'reaction_time': reactionTime,
      });

      // Clear tap result after animation
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => tapResult = null);
      });

      scheduleColorChange();
    } else {
      // ❌ FALSE TAP
      setState(() {
        tapResult = 'false';
        falseTaps++;
        feedbackMessage = "Too early!";
        feedbackColor = Colors.orange;
      });

      _sessionTracker.recordAction('false_tap', {});

      // Clear tap result after animation
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => tapResult = null);
      });
    }
  }

  Future<void> endGame() async {
    print('🏁 endGame called!');

    // Stop game immediately
    setState(() {
      isGameActive = false;
    });

    colorChangeTimer?.cancel();
    gameTimer.stop();

    double averageReactionTime =
        reactionTimes.isEmpty
            ? 0
            : reactionTimes.reduce((a, b) => a + b) / reactionTimes.length;

    double accuracy =
        totalColorChanges == 0 ? 0 : correctTaps / totalColorChanges;

    int score = calculateScore();

    print('📊 Game Stats:');
    print('   Score: $score');
    print('   Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');
    print('   Avg Reaction: ${averageReactionTime.toStringAsFixed(2)}s');

    // Show results dialog FIRST (don't wait for Firebase)
    if (mounted) {
      print('📋 Showing results dialog...');
      _showResultsDialog(score, accuracy, averageReactionTime);
    }

    // Save to Firebase in background (non-blocking)
    // This runs AFTER the dialog is shown
    _saveSessionInBackground(score, accuracy, averageReactionTime);
  }

  // New helper method - saves to Firebase without blocking UI
  void _saveSessionInBackground(
    int score,
    double accuracy,
    double avgTime,
  ) async {
    try {
      print('💾 Saving session in background...');

      await _sessionTracker
          .endSession(
            finalScore: score,
            additionalMetrics: {
              'total_color_changes': totalColorChanges,
              'correct_taps': correctTaps,
              'false_taps': falseTaps,
              'missed_taps': missedTaps,
              'average_reaction_time': avgTime,
              'accuracy': accuracy,
            },
          )
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ Firebase save timed out (normal on web)');
              return Future.value(
                _sessionTracker.endSession(
                  finalScore: 0,
                  additionalMetrics: {},
                ),
              );
            },
          );

      print('✅ Session saved in background!');
    } catch (e) {
      print('❌ Background save error: $e');
      print('⚠️ This is expected on web - data may not sync');
      print('💡 Try running on Windows/Android for full Firebase sync');
    }
  }

  int calculateScore() {
    int score = correctTaps * 10;
    for (double rt in reactionTimes) {
      if (rt < 0.5) score += 5; // Bonus
    }
    score -= falseTaps * 5; // Penalty
    return max(0, score);
  }

  void _showResultsDialog(int score, double accuracy, double avgTime) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Game Over!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Score: $score',
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildResultRow(
                  'Avg Reaction:',
                  '${avgTime.toStringAsFixed(2)}s',
                ),
                _buildResultRow(
                  'Accuracy:',
                  '${(accuracy * 100).toStringAsFixed(0)}%',
                ),
                _buildResultRow('False Taps:', '$falseTaps'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close Dialog
                  Navigator.pop(context); // Exit Game Screen
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameTimer.dispose();
    colorChangeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Reaction Test (Lvl ${widget.difficultyLevel})'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Timer Bar
          LinearProgressIndicator(
            value: gameTimer.progress,
            backgroundColor: Colors.grey.shade200,
            color: Colors.teal,
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          Text(
            "Time: ${gameTimer.formattedTime}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 40),
          Text(
            'Tap the circle when it changes color!',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          const Spacer(),

          // Using the specialized Widget
          ColorCircleWidget(
            data: ColorCircleData(
              color: currentColor,
              size: 250,
              tapResult: tapResult,
            ),
            onTap: onScreenTapped,
          ),

          const Spacer(),

          // Feedback Area
          Text(
            feedbackMessage,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: feedbackColor,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
