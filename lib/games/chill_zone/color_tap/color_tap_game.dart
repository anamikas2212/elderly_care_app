// FILE LOCATION: lib/games/chill_zone/color_tap/color_tap_game.dart

import 'package:flutter/material.dart';
import 'dart:async';

import 'dart:math';
import 'color_tap_timer.dart';
import 'color_circle_widget.dart';
import '../../../models/cognitive/game_session.dart';
import '../../../services/game_services/session_tracker.dart';
import '../../../core/constants/game_constants.dart';

class ColorTapGame extends StatefulWidget {
  final int difficulty; // 1, 2, or 3
  final String userId;

  const ColorTapGame({Key? key, required this.difficulty, required this.userId})
    : super(key: key);

  @override
  State<ColorTapGame> createState() => _ColorTapGameState();
}

class _ColorTapGameState extends State<ColorTapGame> {
  late ColorTapTimer _timer;
  late SessionTracker _sessionTracker;

  int _score = 0;
  int _totalTaps = 0;
  int _correctTaps = 0;
  int _wrongTaps = 0;

  Color? _targetColor;
  List<ColorCircleData> _circles = [];

  bool _gameStarted = false;
  bool _gameEnded = false;

  final Random _random = Random();

  // Difficulty-based configurations
  late int _gameDuration;
  late int _numberOfCircles;
  late double _circleSize;
  late int _colorChangeInterval;

  final List<Color> _availableColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _initializeDifficulty();
    _sessionTracker = SessionTracker(
      userId: widget.userId,
      gameName: 'Color Tap',
      difficulty: widget.difficulty,
    );
    _timer = ColorTapTimer(
      duration: _gameDuration,
      onTick: _onTimerTick,
      onComplete: _endGame,
    );
  }

  void _initializeDifficulty() {
    switch (widget.difficulty) {
      case 1: // Easy
        _gameDuration = 60;
        _numberOfCircles = 4;
        _circleSize = 100.0;
        _colorChangeInterval = 4000;
        break;
      case 2: // Medium
        _gameDuration = 60;
        _numberOfCircles = 6;
        _circleSize = 80.0;
        _colorChangeInterval = 3000;
        break;
      case 3: // Hard
        _gameDuration = 60;
        _numberOfCircles = 8;
        _circleSize = 70.0;
        _colorChangeInterval = 2000;
        break;
      default:
        _gameDuration = 60;
        _numberOfCircles = 4;
        _circleSize = 100.0;
        _colorChangeInterval = 4000;
    }
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _generateTargetColor();
      _generateCircles();
    });
    _timer.start();
    _sessionTracker.startSession();
    _startColorChangeTimer();
  }

  void _onTimerTick(int remainingSeconds) {
    // Optional: Add visual feedback for time running out
    if (remainingSeconds <= 10) {
      // Could show warning animation
    }
  }

  void _generateTargetColor() {
    setState(() {
      _targetColor = _availableColors[_random.nextInt(_availableColors.length)];
    });
  }

  void _generateCircles() {
    List<ColorCircleData> circles = [];

    // At least one circle should be the target color
    int targetColorIndex = _random.nextInt(_numberOfCircles);

    for (int i = 0; i < _numberOfCircles; i++) {
      Color color;
      if (i == targetColorIndex) {
        color = _targetColor!;
      } else {
        // Generate a different color
        do {
          color = _availableColors[_random.nextInt(_availableColors.length)];
        } while (color == _targetColor);
      }

      circles.add(ColorCircleData(id: i, color: color, size: _circleSize));
    }

    setState(() {
      _circles = circles;
    });
  }

  void _startColorChangeTimer() {
    Timer.periodic(Duration(milliseconds: _colorChangeInterval), (timer) {
      if (!_gameStarted || _gameEnded) {
        timer.cancel();
        return;
      }
      _generateTargetColor();
      _generateCircles();
    });
  }

  void _onCircleTap(Color tappedColor) {
    if (!_gameStarted || _gameEnded) return;

    setState(() {
      _totalTaps++;

      if (tappedColor == _targetColor) {
        _correctTaps++;
        _score += 10;

        // Track correct tap
        _sessionTracker.recordAction('correct_tap', {
          'color': _targetColor.toString(),
          'score_gained': 10,
        });

        // Immediate feedback - generate new colors
        _generateTargetColor();
        _generateCircles();
      } else {
        _wrongTaps++;
        _score = max(0, _score - 5);

        // Track wrong tap
        _sessionTracker.recordAction('wrong_tap', {
          'expected_color': _targetColor.toString(),
          'tapped_color': tappedColor.toString(),
          'score_lost': 5,
        });
      }
    });
  }

  void _endGame() async {
    if (_gameEnded) return;

    setState(() {
      _gameEnded = true;
    });

    // Calculate metrics
    double accuracy = _totalTaps > 0 ? (_correctTaps / _totalTaps) * 100 : 0;
    double avgResponseTime = _gameDuration > 0 ? _totalTaps / _gameDuration : 0;

    // Complete session tracking
    GameSession session = await _sessionTracker.endSession(
      finalScore: _score,
      additionalMetrics: {
        'total_taps': _totalTaps,
        'correct_taps': _correctTaps,
        'wrong_taps': _wrongTaps,
        'accuracy': accuracy,
        'avg_taps_per_second': avgResponseTime,
      },
    );

    // Navigate to results screen
    // Show dialog instead
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: Text('Game Complete!', style: TextStyle(fontSize: 24)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Score: $_score', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 10),
                  Text(
                    'Accuracy: ${accuracy.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Correct: $_correctTaps / $_totalTaps',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to login/previous screen
                  },
                  child: Text('OK', style: TextStyle(fontSize: 20)),
                ),
              ],
            ),
      );
    }
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color Tap'),
        backgroundColor: Colors.purple,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.purple.shade300, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: _gameStarted ? _buildGameArea() : _buildStartScreen(),
        ),
      ),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app, size: 120, color: Colors.purple.shade700),
          const SizedBox(height: 30),
          Text(
            'Color Tap',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade900,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tap circles matching the target color!',
            style: TextStyle(fontSize: 24, color: Colors.purple.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Difficulty: Level ${widget.difficulty}',
            style: TextStyle(
              fontSize: 20,
              color: Colors.purple.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 50),
          ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'START GAME',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea() {
    return Column(
      children: [
        _buildGameHeader(),
        const SizedBox(height: 20),
        _buildTargetColorDisplay(),
        const SizedBox(height: 30),
        Expanded(child: _buildCirclesGrid()),
      ],
    );
  }

  Widget _buildGameHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('Score', _score.toString(), Icons.stars),
          _buildStatCard('Time', '${_timer.remainingSeconds}s', Icons.timer),
          _buildStatCard('Taps', _totalTaps.toString(), Icons.touch_app),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.purple.shade700, size: 28),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade900,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.purple.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetColorDisplay() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Tap This Color:',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _targetColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _targetColor?.withOpacity(0.5) ?? Colors.transparent,
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCirclesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            widget.difficulty == 1 ? 2 : (widget.difficulty == 2 ? 3 : 4),
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
      ),
      itemCount: _circles.length,
      itemBuilder: (context, index) {
        return ColorCircleWidget(data: _circles[index], onTap: _onCircleTap);
      },
    );
  }
}

class ColorCircleData {
  final int id;
  final Color color;
  final double size;

  ColorCircleData({required this.id, required this.color, required this.size});
}
