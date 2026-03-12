import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_id_helper.dart';

class MonumentRecallGame extends StatefulWidget {
  final int difficultyLevel; // 1: State, 2: National, 3: International
  final String userState;

  const MonumentRecallGame({super.key, required this.difficultyLevel, required this.userState});

  @override
  State<MonumentRecallGame> createState() => _MonumentRecallGameState();
}

class _MonumentRecallGameState extends State<MonumentRecallGame> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Game State
  List<MonumentQuestion> questions = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool gameActive = true;
  bool showingFeedback = false;
  bool? lastAnswerCorrect;
  String? lastCorrectAnswer;
  
  // Metrics
  int correctAnswers = 0;
  Map<int, double> timePerAnswer = {};
  DateTime? questionStartTime;
  Map<int, bool> answerResults = {};
  
  // Category Tracking
  Map<String, Map<String, int>> categoryStats = {};
  
  // Session tracking for question rotation
  int _sessionNumber = 0;
  
  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }
  
  Future<void> _loadQuestions() async {
    setState(() => isLoading = true);
    
    try {
      // Get session count for rotation
      final userId = await UserIdHelper.getCurrentUserId();
      if (userId != null) {
        final sessions = await _db.collection('game_sessions')
            .where('userId', isEqualTo: userId)
            .where('gameType', isEqualTo: 'monument_recall')
            .where('difficultyLevel', isEqualTo: widget.difficultyLevel)
            .get();
        _sessionNumber = sessions.docs.length;
      }
    } catch (_) {}
    
    int setIndex = _getQuestionSetIndex();
    questions = _generateQuestions(widget.difficultyLevel, widget.userState, setIndex);
    questions.shuffle();
    
    for (var q in questions) {
      if (!categoryStats.containsKey(q.category)) {
        categoryStats[q.category] = {'correct': 0, 'total': 0};
      }
    }
    
    setState(() {
      isLoading = false;
      questionStartTime = DateTime.now();
    });
  }

  // Question rotation: same system as City Atlas
  int _getQuestionSetIndex() {
    int cyclePosition = _sessionNumber % 40;
    if (cyclePosition < 20) {
      return (cyclePosition ~/ 2) % 2; // 0 or 1
    } else {
      return ((cyclePosition - 20) ~/ 2) % 2 + 2; // 2 or 3
    }
  }
  
  void _submitAnswer(String selectedOption) {
    if (!gameActive || showingFeedback) return;
    
    double timeTaken = DateTime.now().difference(questionStartTime!).inMilliseconds / 1000.0;
    timePerAnswer[currentIndex] = timeTaken;
    
    MonumentQuestion currentQ = questions[currentIndex];
    bool isCorrect = (selectedOption == currentQ.correctAnswer);
    answerResults[currentIndex] = isCorrect;
    
    if (isCorrect) correctAnswers++;
    
    categoryStats[currentQ.category]!['total'] = (categoryStats[currentQ.category]!['total'] ?? 0) + 1;
    if (isCorrect) {
      categoryStats[currentQ.category]!['correct'] = (categoryStats[currentQ.category]!['correct'] ?? 0) + 1;
    }
    
    // Show feedback
    setState(() {
      showingFeedback = true;
      lastAnswerCorrect = isCorrect;
      lastCorrectAnswer = currentQ.correctAnswer;
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (currentIndex < questions.length - 1) {
        setState(() {
          currentIndex++;
          questionStartTime = DateTime.now();
          showingFeedback = false;
          lastAnswerCorrect = null;
        });
      } else {
        setState(() => showingFeedback = false);
        _endGame();
      }
    });
  }
  
  void _endGame() async {
    setState(() => gameActive = false);
    
    int totalQuestions = questions.length;
    double accuracy = totalQuestions > 0 ? correctAnswers / totalQuestions : 0;
    double avgTime = timePerAnswer.values.isEmpty ? 0 : timePerAnswer.values.reduce((a, b) => a + b) / totalQuestions;
    
    int score = _calculateScore(accuracy, avgTime, totalQuestions);
    Map<String, int> cognitiveScores = _calculateCognitiveScores(accuracy, avgTime);
    
    final String? userId = await UserIdHelper.getCurrentUserId();
    if (userId != null && userId.isNotEmpty) {
      try {
        await _db.collection('game_sessions').add({
          'userId': userId,
          'gameType': 'monument_recall',
          'difficultyLevel': widget.difficultyLevel,
          'region': widget.userState,
          'timestamp': FieldValue.serverTimestamp(),
          'score': score,
          'sessionNumber': _sessionNumber,
          'questionSetIndex': _getQuestionSetIndex(),
          'metrics': {
            'total_questions': totalQuestions,
            'correct_answers': correctAnswers,
            'accuracy': accuracy,
            'average_time_per_answer': avgTime,
          },
          'category_performance': categoryStats,
          'cognitive_contributions': cognitiveScores,
        });
        
        await _updateCognitiveSummary(userId, cognitiveScores);
      } catch (_) {}
    }
    
    if (mounted) _showResultDialog(score, accuracy, cognitiveScores);
  }
  
  int _calculateScore(double accuracy, double avgTime, int total) {
    int score = (accuracy * total * 15).toInt();
    if (widget.difficultyLevel == 2) score = (score * 1.2).toInt();
    if (widget.difficultyLevel == 3) score = (score * 1.5).toInt();
    if (avgTime < 6) score += 20;
    else if (avgTime < 10) score += 10;
    if (accuracy == 1.0) score += 30;
    return score;
  }
  
  Map<String, int> _calculateCognitiveScores(double accuracy, double avgTime) {
    int semanticScore = (accuracy * 100).toInt();
    int visualScore = (accuracy * 100).toInt();
    int speedScore;
    if (avgTime < 5) speedScore = 100;
    else if (avgTime < 8) speedScore = 85;
    else if (avgTime < 12) speedScore = 70;
    else speedScore = 50;
    
    int memoryScore = (semanticScore * 0.6 + visualScore * 0.25 + speedScore * 0.15).round();
    int languageScore = (accuracy * 100).toInt();
    
    return {'memory': memoryScore, 'language': languageScore};
  }

  Future<void> _updateCognitiveSummary(String userId, Map<String, int> scores) async {
    try {
      await _db.collection('cognitive_summary').doc(userId).set({
        'memoryScore': scores['memory'],
        'languageScore': scores['language'],
        'lastUpdated': FieldValue.serverTimestamp(),
        'totalGamesPlayed': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
  
  void _showResultDialog(int score, double accuracy, Map<String, int> scores) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(
              accuracy > 0.7 ? Icons.emoji_events : Icons.museum,
              color: accuracy > 0.7 ? Colors.amber : Colors.blue,
              size: 48,
            ),
            const SizedBox(height: 8),
            const Text("Game Over"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Score: $score", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            Text("Accuracy: ${(accuracy * 100).toStringAsFixed(0)}%"),
            const Divider(),
            const Text('Cognitive Assessment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildScoreRow("Memory", scores['memory'] ?? 0, Colors.purple),
            const SizedBox(height: 4),
            _buildScoreRow("Language", scores['language'] ?? 0, Colors.pink),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Close"),
          )
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    MonumentQuestion q = questions[currentIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Monuments - Lvl ${widget.difficultyLevel}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${currentIndex + 1}/${questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress
            LinearProgressIndicator(
              value: (currentIndex + 1) / questions.length,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
            const SizedBox(height: 16),
            
            // Image (with proper BoxFit.contain to avoid distortion)
            if (q.hasImage && q.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.network(
                    q.imageUrl!,
                    headers: const {'User-Agent': 'ElderlyCareApp/1.0 (flutter)'},
                    fit: BoxFit.contain, // FIXED: was BoxFit.cover causing distortion
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Image unavailable', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (q.hasImage)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
              ),
              
            const SizedBox(height: 20),
            Text(
              q.questionText,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (q.hint != null)
              Text(
                q.hint!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            
            // Feedback banner
            if (showingFeedback && lastAnswerCorrect != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: lastAnswerCorrect! ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: lastAnswerCorrect! ? Colors.green : Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(
                      lastAnswerCorrect! ? Icons.check_circle : Icons.cancel,
                      color: lastAnswerCorrect! ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lastAnswerCorrect! ? 'Correct! 🎉' : 'Wrong! The answer is: $lastCorrectAnswer',
                        style: TextStyle(
                          color: lastAnswerCorrect! ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Options
            ...q.options.map((opt) {
              Color? btnColor;
              if (showingFeedback) {
                if (opt == q.correctAnswer) {
                  btnColor = Colors.green;
                }
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                  onPressed: showingFeedback ? null : () => _submitAnswer(opt),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 17),
                    backgroundColor: btnColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(opt),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  // ==========================================
  // QUESTION SETS (4 sets per level for rotation)
  // ==========================================
  
  List<MonumentQuestion> _generateQuestions(int level, String state, int setIndex) {
    if (level == 1) return _getLevel1Questions(state, setIndex);
    if (level == 2) return _getLevel2Questions(setIndex);
    return _getLevel3Questions(setIndex);
  }

  // LEVEL 1: State monuments - 4 sets
  List<MonumentQuestion> _getLevel1Questions(String state, int setIndex) {
    final Map<String, List<List<MonumentQuestion>>> stateQuestions = {
      'Kerala': [
        // Set A
        [
          MonumentQuestion("What is this monument?", ["Padmanabhaswamy Temple", "Guruvayur Temple", "Sabarimala"], "Padmanabhaswamy Temple", "Temples", true,
            imageUrl: "https://images.unsplash.com/photo-1600010991979-3baaa196f3cf?w=400&q=80"), // Golden temple architecture proxy
          MonumentQuestion("Where is Bekal Fort located?", ["Kasaragod", "Kannur", "Kochi"], "Kasaragod", "Forts", false),
          MonumentQuestion("Which palace is famous for murals?", ["Mattancherry Palace", "Hill Palace", "Kowdiar Palace"], "Mattancherry Palace", "Palaces", false),
          MonumentQuestion("Edakkal Caves are in which district?", ["Wayanad", "Idukki", "Palakkad"], "Wayanad", "Caves", false),
          MonumentQuestion("Jewish Synagogue is located in?", ["Kochi", "Kozhikode", "Thrissur"], "Kochi", "Religious", false),
        ],
        // Set B
        [
          MonumentQuestion("This is a famous backwater destination. Where?", ["Alappuzha", "Kottayam", "Ernakulam"], "Alappuzha", "Landmarks", true,
            imageUrl: "https://images.unsplash.com/photo-1602216056096-3b40cc0c9944?w=400&q=80"), // Kerala backwaters proxy
          MonumentQuestion("Thalassery Fort was built by?", ["British", "Dutch", "Portuguese"], "British", "Forts", false),
          MonumentQuestion("Where is Guruvayur Temple?", ["Thrissur", "Palakkad", "Ernakulam"], "Thrissur", "Temples", false),
          MonumentQuestion("Munnar is famous for?", ["Tea plantations", "Beaches", "Forts"], "Tea plantations", "Landmarks", false),
          MonumentQuestion("Identify this waterfall in Idukki", ["Athirappilly", "Cheeyappara", "Soochipara"], "Cheeyappara", "Nature", true,
            imageUrl: "https://images.unsplash.com/photo-1546944061-07eb7ccff4d6?w=400&q=80"), // Waterfall proxy
        ],
        // Set C
        [
          MonumentQuestion("Where is the Chinese Fishing Net?", ["Kochi", "Alappuzha", "Kozhikode"], "Kochi", "Landmarks", false),
          MonumentQuestion("Krishnapuram Palace is in?", ["Alappuzha", "Kottayam", "Thrissur"], "Alappuzha", "Palaces", false),
          MonumentQuestion("Thirunelli Temple is in which district?", ["Wayanad", "Kannur", "Kasaragod"], "Wayanad", "Temples", false),
          MonumentQuestion("St. Francis Church (oldest European church in India) is in?", ["Kochi", "Thrissur", "Kozhikode"], "Kochi", "Religious", false),
          MonumentQuestion("Where is Jatayu Earth's Center?", ["Kollam", "Thiruvananthapuram", "Pathanamthitta"], "Kollam", "Landmarks", false),
        ],
        // Set D
        [
          MonumentQuestion("Sabarimala Temple is in which district?", ["Pathanamthitta", "Idukki", "Kottayam"], "Pathanamthitta", "Temples", false),
          MonumentQuestion("Where is Willingdon Island?", ["Kochi", "Kozhikode", "Alappuzha"], "Kochi", "Landmarks", false),
          MonumentQuestion("Kappad Beach is historically significant because?", ["Vasco da Gama landed", "Tipu Sultan battle", "Dutch trading post"], "Vasco da Gama landed", "History", false),
          MonumentQuestion("Anjengo Fort was built by?", ["British", "Dutch", "Portuguese"], "British", "Forts", false),
          MonumentQuestion("Identify this waterfall", ["Athirappilly", "Soochipara", "Palaruvi"], "Athirappilly", "Nature", true,
            imageUrl: "https://images.unsplash.com/photo-1616843413587-9e3a37f7bbd8?w=400&q=80"), // Athirappilly proxy
        ],
      ],
    };

    // Default questions if state not found
    final defaultSets = stateQuestions['Kerala']!;
    final sets = stateQuestions[state] ?? defaultSets;
    return sets[setIndex % sets.length];
  }

  // LEVEL 2: National monuments - 4 sets
  List<MonumentQuestion> _getLevel2Questions(int setIndex) {
    final List<List<MonumentQuestion>> sets = [
      // Set A
      [
        MonumentQuestion("Identify this monument", ["Taj Mahal", "Red Fort", "Qutub Minar"], "Taj Mahal", "Monuments", true,
            imageUrl: "https://images.unsplash.com/photo-1564507592227-0b0efa862ced?w=400&q=80"),
        MonumentQuestion("Where is the Gateway of India?", ["Mumbai", "Delhi", "Kolkata"], "Mumbai", "Monuments", false),
        MonumentQuestion("Who built the Red Fort?", ["Shah Jahan", "Akbar", "Aurangzeb"], "Shah Jahan", "Forts", false),
        MonumentQuestion("Hawa Mahal is in which city?", ["Jaipur", "Jodhpur", "Udaipur"], "Jaipur", "Palaces", false),
        MonumentQuestion("Where is Charminar located?", ["Hyderabad", "Chennai", "Bengaluru"], "Hyderabad", "Monuments", false),
      ],
      // Set B
      [
        MonumentQuestion("Identify this monument", ["Qutub Minar", "India Gate", "Victoria Memorial"], "Qutub Minar", "Monuments", true,
            imageUrl: "https://images.unsplash.com/photo-1587474260584-136574528ed5?w=400&q=80"),
        MonumentQuestion("Victoria Memorial is in?", ["Kolkata", "Mumbai", "Chennai"], "Kolkata", "Monuments", false),
        MonumentQuestion("Mysore Palace is in which state?", ["Karnataka", "Tamil Nadu", "Kerala"], "Karnataka", "Palaces", false),
        MonumentQuestion("Where is Konark Sun Temple?", ["Odisha", "Rajasthan", "Madhya Pradesh"], "Odisha", "Temples", false),
        MonumentQuestion("Golden Temple is in which city?", ["Amritsar", "Delhi", "Jaipur"], "Amritsar", "Temples", false),
      ],
      // Set C
      [
        MonumentQuestion("Where is Meenakshi Temple?", ["Madurai", "Chennai", "Kanchipuram"], "Madurai", "Temples", false),
        MonumentQuestion("Ajanta Caves are in?", ["Maharashtra", "Madhya Pradesh", "Rajasthan"], "Maharashtra", "Caves", false),
        MonumentQuestion("Sanchi Stupa is in which state?", ["Madhya Pradesh", "Uttar Pradesh", "Rajasthan"], "Madhya Pradesh", "Monuments", false),
        MonumentQuestion("Where is the Jagannath Temple?", ["Puri", "Varanasi", "Haridwar"], "Puri", "Temples", false),
        MonumentQuestion("Hampi ruins are in which state?", ["Karnataka", "Andhra Pradesh", "Tamil Nadu"], "Karnataka", "Historical", false),
      ],
      // Set D
      [
        MonumentQuestion("India Gate is in which city?", ["Delhi", "Mumbai", "Kolkata"], "Delhi", "Monuments", false),
        MonumentQuestion("Amer Fort is near which city?", ["Jaipur", "Jodhpur", "Udaipur"], "Jaipur", "Forts", false),
        MonumentQuestion("Where is Ellora Caves?", ["Maharashtra", "Karnataka", "Gujarat"], "Maharashtra", "Caves", false),
        MonumentQuestion("Lotus Temple is in?", ["Delhi", "Agra", "Lucknow"], "Delhi", "Temples", false),
        MonumentQuestion("Fatehpur Sikri was built by?", ["Akbar", "Shah Jahan", "Babur"], "Akbar", "Historical", false),
      ],
    ];
    return sets[setIndex % sets.length];
  }

  // LEVEL 3: International monuments - 4 sets with FIXED image URLs
  List<MonumentQuestion> _getLevel3Questions(int setIndex) {
    final List<List<MonumentQuestion>> sets = [
      // Set A
      [
        MonumentQuestion("Where is the Eiffel Tower?", ["Paris", "London", "New York"], "Paris", "Monuments", true,
          // FIXED: using a proper thumbnail URL with contain fit
          imageUrl: "https://images.unsplash.com/photo-1511739001486-6bfe10ce785f?w=400&q=80",
          hint: "This iconic iron lattice tower is a symbol of France"),
        MonumentQuestion("The Great Wall is in which country?", ["China", "Japan", "Korea"], "China", "Monuments", false),
        MonumentQuestion("Machu Picchu is in?", ["Peru", "Brazil", "Mexico"], "Peru", "Historical", false),
        MonumentQuestion("Colosseum is in which citysensing", ["Rome", "Athens", "Istanbul"], "Rome", "Monuments", false),
      ],
      // Set B
      [
        MonumentQuestion("Where is the Statue of Liberty?", ["New York", "Washington D.C.", "Los Angeles"], "New York", "Monuments", true,
            imageUrl: "https://images.unsplash.com/photo-1605130284535-11dd9eedc58a?w=400&q=80"),
        MonumentQuestion("Pyramids of Giza are in?", ["Egypt", "Iraq", "Sudan"], "Egypt", "Historical", false),
        MonumentQuestion("Big Ben is in which city?", ["London", "Paris", "Dublin"], "London", "Monuments", false),
        MonumentQuestion("Where is the Leaning Tower of Pisa?", ["Italy", "Spain", "Greece"], "Italy", "Monuments", false),
      ],
      // Set C
      [
        MonumentQuestion("Where is Christ the Redeemer statue?", ["Rio de Janeiro", "Buenos Aires", "São Paulo"], "Rio de Janeiro", "Monuments", false),
        MonumentQuestion("Angkor Wat is in?", ["Cambodia", "Thailand", "Vietnam"], "Cambodia", "Temples", false),
        MonumentQuestion("The Parthenon is in?", ["Athens", "Rome", "Istanbul"], "Athens", "Historical", false),
        MonumentQuestion("Where is the Sydney Opera House?", ["Australia", "New Zealand", "Canada"], "Australia", "Monuments", false),
      ],
      // Set D
      [
        MonumentQuestion("Petra is in which country?", ["Jordan", "Egypt", "Turkey"], "Jordan", "Historical", false),
        MonumentQuestion("Where is Mount Rushmore?", ["USA", "Canada", "Australia"], "USA", "Monuments", false),
        MonumentQuestion("Stonehenge is in?", ["England", "Scotland", "Ireland"], "England", "Historical", false),
        MonumentQuestion("Where is the Forbidden City?", ["Beijing", "Tokyo", "Seoul"], "Beijing", "Historical", false),
      ],
    ];
    return sets[setIndex % sets.length];
  }
}

class MonumentQuestion {
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String category;
  final bool hasImage;
  final String? imageUrl;
  final String? hint;
  
  MonumentQuestion(this.questionText, this.options, this.correctAnswer, this.category, this.hasImage, {this.imageUrl, this.hint});
}
