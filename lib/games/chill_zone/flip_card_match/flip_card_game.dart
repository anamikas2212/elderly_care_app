import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../../services/game_services/session_tracker.dart';
import 'flip_card_widget.dart';

class FlipCardGame extends StatefulWidget {
  final int difficultyLevel; // 1, 2, or 3
  final String userId;

  const FlipCardGame({
    super.key,
    required this.difficultyLevel,
    required this.userId,
  });

  @override
  State<FlipCardGame> createState() => _FlipCardGameState();
}

class _FlipCardGameState extends State<FlipCardGame> {
  // GAME STATE
  List<FlipCardData> cards = [];
  FlipCardData? firstFlippedCard;
  FlipCardData? secondFlippedCard;
  bool canFlip = false;
  bool isInitialReveal = true;

  // METRICS TO TRACK
  int totalPairs = 0;
  int pairsMatched = 0;
  int totalAttempts = 0;
  int wrongAttempts = 0;
  int wrongAttemptsFirstHalf = 0;
  int wrongAttemptsSecondHalf = 0;
  List<double> timePerPair = [];
  DateTime? pairAttemptStartTime;
  DateTime? gameStartTime;

  // GAME TIMER
  int elapsedSeconds = 0;
  Timer? gameTimer;
  Timer? initialRevealTimer;

  late SessionTracker _sessionTracker;

  @override
  void initState() {
    super.initState();
    _sessionTracker = SessionTracker(
      userId: widget.userId,
      gameName: 'Flip Card Match',
      difficulty: widget.difficultyLevel,
    );
    _sessionTracker.startSession();
    _initializeGame();
  }

  void _initializeGame() {
    // Difficulty determines number of pairs
    // Level 1 (Easy): 6 pairs = 12 cards
    // Level 2 (Medium): 8 pairs = 16 cards
    // Level 3 (Hard): 10 pairs = 20 cards
    totalPairs =
        widget.difficultyLevel == 1
            ? 6
            : widget.difficultyLevel == 2
            ? 8
            : 10;

    // Create card pairs
    cards = _generateCards(totalPairs);

    // Initial reveal time based on difficulty
    // Level 1: 5 seconds
    // Level 2: 4 seconds
    // Level 3: 3 seconds
    int initialRevealDuration =
        widget.difficultyLevel == 1
            ? 5
            : widget.difficultyLevel == 2
            ? 4
            : 3;

    // Show all cards initially
    setState(() {
      for (var card in cards) {
        card.isFlipped = true;
      }
    });

    // Start initial reveal countdown
    initialRevealTimer = Timer(Duration(seconds: initialRevealDuration), () {
      setState(() {
        for (var card in cards) {
          card.isFlipped = false;
        }
        isInitialReveal = false;
        canFlip = true;
      });
      _startGameTimer();
    });
  }

  List<FlipCardData> _generateCards(int pairs) {
    final List<Map<String, dynamic>> cardTemplates = [
      {'icon': Icons.pets, 'color': Colors.brown, 'value': 'dog'},
      {'icon': Icons.brightness_2, 'color': Colors.blue, 'value': 'cat'},
      {'icon': Icons.nature, 'color': Colors.green, 'value': 'tree'},
      {'icon': Icons.local_florist, 'color': Colors.pink, 'value': 'flower'},
      {'icon': Icons.wb_sunny, 'color': Colors.orange, 'value': 'sun'},
      {'icon': Icons.cloud, 'color': Colors.grey, 'value': 'cloud'},
      {'icon': Icons.star, 'color': Colors.yellow, 'value': 'star'},
      {'icon': Icons.favorite, 'color': Colors.red, 'value': 'heart'},
      {'icon': Icons.music_note, 'color': Colors.purple, 'value': 'music'},
      {'icon': Icons.cake, 'color': Colors.pinkAccent, 'value': 'cake'},
      {'icon': Icons.coffee, 'color': Colors.brown.shade700, 'value': 'coffee'},
      {'icon': Icons.book, 'color': Colors.indigo, 'value': 'book'},
      {'icon': Icons.home, 'color': Colors.teal, 'value': 'home'},
      {'icon': Icons.car_rental, 'color': Colors.blueGrey, 'value': 'car'},
      {'icon': Icons.flight, 'color': Colors.cyan, 'value': 'plane'},
    ];

    List<FlipCardData> generatedCards = [];

    // Select random templates
    final selectedTemplates = (cardTemplates..shuffle()).take(pairs).toList();

    // Create pairs
    for (int i = 0; i < pairs; i++) {
      final template = selectedTemplates[i];
      // First card of pair
      generatedCards.add(
        FlipCardData(
          id: 'card_${i}_a',
          value: template['value'],
          icon: template['icon'],
          color: template['color'],
        ),
      );
      // Second card of pair
      generatedCards.add(
        FlipCardData(
          id: 'card_${i}_b',
          value: template['value'],
          icon: template['icon'],
          color: template['color'],
        ),
      );
    }

    // Shuffle cards
    generatedCards.shuffle();

    return generatedCards;
  }

  void _startGameTimer() {
    gameStartTime = DateTime.now();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          elapsedSeconds++;
        });
      }
    });
  }

  void onCardFlipped(FlipCardData card) {
    if (!canFlip || card.isFlipped || card.isMatched) return;

    setState(() {
      card.isFlipped = true;

      if (firstFlippedCard == null) {
        // First card flipped
        firstFlippedCard = card;
        pairAttemptStartTime = DateTime.now();
      } else if (secondFlippedCard == null) {
        // Second card flipped
        secondFlippedCard = card;
        canFlip = false;
        totalAttempts++;

        // Check for match
        if (firstFlippedCard!.value == card.value) {
          // ✅ MATCH!
          _handleMatch();
        } else {
          // ❌ NO MATCH
          _handleMismatch();
        }
      }
    });
  }

  void _handleMatch() {
    // Calculate time for this pair
    if (pairAttemptStartTime != null) {
      double timeTaken =
          DateTime.now().difference(pairAttemptStartTime!).inMilliseconds /
          1000.0;
      timePerPair.add(timeTaken);
    }

    pairsMatched++;
    
    print('✅ Match found! Pairs: $pairsMatched/$totalPairs');

    _sessionTracker.recordAction('correct_match', {
      'pair_value': firstFlippedCard!.value,
      'time_taken': timePerPair.last,
    });

    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          firstFlippedCard!.isMatched = true;
          secondFlippedCard!.isMatched = true;
          firstFlippedCard = null;
          secondFlippedCard = null;
          canFlip = true;

          // Check if game is complete
          print('🎯 Checking game completion: $pairsMatched == $totalPairs');
          if (pairsMatched >= totalPairs) {
            print('🏁 All pairs matched! Ending game...');
            _endGame();
          }
        });
      }
    });
  }

  void _handleMismatch() {
    wrongAttempts++;

    // Track consistency: wrong attempts in first half vs second half
    if (pairsMatched < (totalPairs / 2)) {
      wrongAttemptsFirstHalf++;
    } else {
      wrongAttemptsSecondHalf++;
    }

    _sessionTracker.recordAction('wrong_match', {
      'attempted_pair':
          '${firstFlippedCard!.value} vs ${secondFlippedCard!.value}',
    });

    // Reset pair attempt timer
    pairAttemptStartTime = DateTime.now();

    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          firstFlippedCard!.isFlipped = false;
          secondFlippedCard!.isFlipped = false;
          firstFlippedCard = null;
          secondFlippedCard = null;
          canFlip = true;
        });
      }
    });
  }

  Future<void> _endGame() async {
    print('🏁 Game Over!');
    gameTimer?.cancel();

    double totalTime =
        gameStartTime != null
            ? DateTime.now().difference(gameStartTime!).inMilliseconds / 1000.0
            : 0;

    double avgTimePerPair =
        timePerPair.isEmpty
            ? 0
            : timePerPair.reduce((a, b) => a + b) / timePerPair.length;

    double efficiency = totalAttempts == 0 ? 0 : pairsMatched / totalAttempts;

    int score = _calculateScore(efficiency, avgTimePerPair);

    // Calculate cognitive domain scores
    Map<String, int> cognitiveScores = _calculateCognitiveScores(
      efficiency,
      avgTimePerPair,
    );

    print('📊 Game Stats:');
    print(' Score: $score');
    print(' Pairs Matched: $pairsMatched/$totalPairs');
    print(' Total Attempts: $totalAttempts');
    print(' Wrong Attempts: $wrongAttempts');
    print(' Efficiency: ${(efficiency * 100).toStringAsFixed(1)}%');
    print(' Avg Time/Pair: ${avgTimePerPair.toStringAsFixed(2)}s');
    print(' Memory Score: ${cognitiveScores['memory']}');

    // Show results dialog first
    if (mounted) {
      _showResultsDialog(score, efficiency, avgTimePerPair, cognitiveScores);
    }

    // Save to Firebase in background
    _saveSessionInBackground(
      score,
      efficiency,
      avgTimePerPair,
      totalTime,
      cognitiveScores,
    );
  }

  int _calculateScore(double efficiency, double avgTime) {
    int score = pairsMatched * 20; // Base points

    // Memory bonus
    if (totalAttempts == totalPairs) {
      score += 100; // Perfect memory
    } else if (totalAttempts < totalPairs * 1.5) {
      score += 50; // Very good memory
    }

    // Speed bonus/penalty
    if (avgTime < 3) {
      score += 30; // Fast
    } else if (avgTime > 10) {
      score -= 20; // Slow
    }

    return max(0, score);
  }

  Map<String, int> _calculateCognitiveScores(
    double efficiency,
    double avgTime,
  ) {
    // Memory Score (Primary Domain - 80% weight)
    double efficiencyScore = 0;
    if (efficiency >= 1.0) {
      efficiencyScore = 100;
    } else if (efficiency >= 0.8) {
      efficiencyScore = 90;
    } else if (efficiency >= 0.6) {
      efficiencyScore = 75;
    } else if (efficiency >= 0.4) {
      efficiencyScore = 60;
    } else {
      efficiencyScore = 40;
    }

    double completionScore = (pairsMatched / totalPairs) * 100;

    double speedScore = 0;
    if (avgTime < 3) {
      speedScore = 100;
    } else if (avgTime < 5) {
      speedScore = 85;
    } else if (avgTime < 8) {
      speedScore = 70;
    } else {
      speedScore = 50;
    }

    int memoryScore =
        ((efficiencyScore * 0.5) + (completionScore * 0.3) + (speedScore * 0.2))
            .round();

    // Attention Score (Secondary Domain - 20% weight)
    // Based on consistency - did wrong attempts increase toward the end?
    // Formula: 100 - ((secondHalf - firstHalf) * 10). Clamped at 0.
    int consistencyPenalty =
        (wrongAttemptsSecondHalf - wrongAttemptsFirstHalf) * 10;
    int attentionScore = 100 - (consistencyPenalty > 0 ? consistencyPenalty : 0);

    return {
      'memory': memoryScore.clamp(0, 100),
      'attention': attentionScore.clamp(0, 100),
    };
  }

  void _saveSessionInBackground(
    int score,
    double efficiency,
    double avgTime,
    double totalTime,
    Map<String, int> cognitiveScores,
  ) async {
    try {
      print('💾 Saving flip card session in background...');
      await _sessionTracker
          .endSession(
            finalScore: score,
            additionalMetrics: {
              'total_pairs': totalPairs,
              'pairs_matched': pairsMatched,
              'total_attempts': totalAttempts,
              'wrong_attempts': wrongAttempts,
              'wrong_attempts_first_half': wrongAttemptsFirstHalf,
              'wrong_attempts_second_half': wrongAttemptsSecondHalf,
              'total_time': totalTime,
              'average_time_per_pair': avgTime,
              'time_per_pair': timePerPair,
              'efficiency': efficiency,
            },
            cognitiveScores: cognitiveScores,
          )
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('⏱️ Firebase save timed out');
              return Future.value();
            },
          );
      print('✅ Flip card session saved!');
    } catch (e) {
      print('❌ Background save error: $e');
    }
  }

  void _showResultsDialog(
    int score,
    double efficiency,
    double avgTime,
    Map<String, int> cognitiveScores,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Game Complete!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 48,
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('Points', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                _buildResultRow('Pairs Found:', '$pairsMatched/$totalPairs'),
                _buildResultRow('Total Attempts:', '$totalAttempts'),
                _buildResultRow('Wrong Attempts:', '$wrongAttempts'),
                _buildResultRow(
                  'Efficiency:',
                  '${(efficiency * 100).toStringAsFixed(0)}%',
                ),
                _buildResultRow(
                  'Avg Time/Pair:',
                  '${avgTime.toStringAsFixed(1)}s',
                ),
                const Divider(height: 20),
                _buildResultRow(
                  'Memory Score:',
                  '${cognitiveScores['memory']}/100',
                  valueColor: Colors.purple,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Exit game
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    initialRevealTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate grid size based on number of cards
    int crossAxisCount =
        totalPairs <= 6
            ? 3
            : totalPairs <= 8
            ? 4
            : 4;

    double screenWidth = MediaQuery.of(context).size.width;
    double cardSize = (screenWidth - 60) / crossAxisCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Flip Card Match (Level ${widget.difficultyLevel})'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (!isInitialReveal)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Text(
                  '⏱️ ${elapsedSeconds}s',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Stats Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.purple.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Pairs',
                  '$pairsMatched/$totalPairs',
                  Icons.check_circle,
                ),
                _buildStatItem('Attempts', '$totalAttempts', Icons.touch_app),
                _buildStatItem('Wrong', '$wrongAttempts', Icons.cancel),
              ],
            ),
          ),
          // Initial Reveal Message
          if (isInitialReveal)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.shade100,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Memorize the cards!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          // Card Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: cards.length,
                itemBuilder: (context, index) {
                  return FlipCardWidget(
                    data: cards[index],
                    onTap: onCardFlipped,
                    size: cardSize,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.purple,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
