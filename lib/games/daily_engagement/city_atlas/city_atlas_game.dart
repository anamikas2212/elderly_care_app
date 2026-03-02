import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_id_helper.dart';

class CityAtlasGame extends StatefulWidget {
  final int difficultyLevel; // 1, 2, or 3
  final String userState; // User's state (e.g., "Kerala")
  
  const CityAtlasGame({
    super.key,
    required this.difficultyLevel,
    required this.userState,
  });
  
  @override
  State<CityAtlasGame> createState() => _CityAtlasGameState();
}

class _CityAtlasGameState extends State<CityAtlasGame> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Game State
  List<Question> questions = [];
  int currentQuestionIndex = 0;
  DateTime gameStartTime = DateTime.now();
  bool gameActive = true;
  bool isLoading = true;
  bool? lastAnswerCorrect;
  String? lastExplanation;
  bool showingFeedback = false;
  
  // Metrics
  int totalQuestions = 0;
  int correctAnswers = 0;
  int wrongAnswers = 0;
  Map<int, double> timePerQuestion = {};
  Map<int, DateTime> questionStartTimes = {};
  Map<int, bool> answerCorrectness = {};
  Map<int, String> userAnswers = {};
  int consecutiveCorrect = 0;
  int maxConsecutiveCorrect = 0;
  int firstAttemptCorrect = 0;

  // Question rotation
  int _sessionNumber = 0;

  @override
  void initState() {
    super.initState();
    _loadSessionAndQuestions();
  }

  Future<void> _loadSessionAndQuestions() async {
    setState(() => isLoading = true);
    
    try {
      // Get session count for question rotation
      final userId = await UserIdHelper.getCurrentUserId();
      if (userId != null) {
        final sessions = await _db.collection('game_sessions')
            .where('userId', isEqualTo: userId)
            .where('gameType', isEqualTo: 'city_atlas')
            .where('difficultyLevel', isEqualTo: widget.difficultyLevel)
            .get();
        _sessionNumber = sessions.docs.length;
      }

      questions = _generateQuestions();
      totalQuestions = questions.length;
      questionStartTimes[0] = DateTime.now();
      
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ==========================================
  // QUESTION ROTATION SYSTEM
  // ==========================================
  // Sessions 1-2: Set A | Sessions 3-4: Set B
  // Sessions 5-6: Set A | Sessions 7-8: Set B  
  // ... After 20 sessions: Set C & D cycle
  // After 40 sessions: Back to A & B
  
  int _getQuestionSetIndex() {
    int cyclePosition = _sessionNumber % 40;
    if (cyclePosition < 20) {
      // First 20 sessions: alternate A (0) and B (1)
      int pair = (cyclePosition ~/ 2) % 2;
      return pair; // 0 or 1
    } else {
      // Sessions 20-39: alternate C (2) and D (3)
      int pair = ((cyclePosition - 20) ~/ 2) % 2;
      return pair + 2; // 2 or 3
    }
  }

  // ==========================================
  // QUESTION GENERATION
  // ==========================================
  
  List<Question> _generateQuestions() {
    int setIndex = _getQuestionSetIndex();
    
    switch (widget.difficultyLevel) {
      case 1:
        return _generateLevel1Questions(setIndex);
      case 2:
        return _generateLevel2Questions(setIndex);
      case 3:
        return _generateLevel3Questions(setIndex);
      default:
        return _generateLevel1Questions(setIndex);
    }
  }

  // ---- LEVEL 1: Local Cities (near your home) ----
  List<Question> _generateLevel1Questions(int setIndex) {
    final stateCities = _getStateCities(widget.userState);
    final neighborCities = _getNeighborStateCities(widget.userState);
    final allSets = _getLevel1QuestionSets(stateCities, neighborCities, widget.userState);
    
    List<Question> selectedSet = allSets[setIndex % allSets.length];
    selectedSet.shuffle(Random());
    return selectedSet.take(8).toList();
  }

  List<List<Question>> _getLevel1QuestionSets(
    List<String> homeCities, 
    List<String> farCities,
    String userState,
  ) {
    // 4 question sets, each with 8 questions
    // "Find the city that is near your home" style
    List<List<Question>> sets = [];
    
    // Build template questions
    List<String> questionTemplates = [
      'Which city is NOT near your home in $userState?',
      'Find the city that does NOT belong to your area',
      'Which of these cities is far from your home?',
      'One of these is NOT a $userState city. Which one?',
      'Which city would you NOT find near your home?',
      'Identify the city that is NOT from your local area',
      'Which city is from a different state?',
      'Find the odd one out — which city is NOT from $userState?',
    ];

    for (int s = 0; s < 4; s++) {
      List<Question> setQuestions = [];
      List<String> shuffledHome = List.from(homeCities)..shuffle(Random(s));
      List<String> shuffledFar = List.from(farCities)..shuffle(Random(s + 100));
      List<String> shuffledTemplates = List.from(questionTemplates)..shuffle(Random(s + 200));
      
      for (int i = 0; i < 8; i++) {
        // Pick 3 local cities and 1 non-local
        List<String> localPick = [];
        for (int j = 0; j < 3; j++) {
          localPick.add(shuffledHome[(i * 3 + j) % shuffledHome.length]);
        }
        String oddCity = shuffledFar[(i + s * 4) % shuffledFar.length];
        
        List<String> options = [...localPick, oddCity];
        options.shuffle(Random(i + s));
        
        setQuestions.add(Question(
          type: QuestionType.oddOneOut,
          questionText: shuffledTemplates[i % shuffledTemplates.length],
          options: options,
          correctAnswers: [oddCity],
          category: 'local_cities',
          explanation: '$oddCity is not from $userState. The others are cities near your home.',
        ));
      }
      sets.add(setQuestions);
    }
    return sets;
  }

  // ---- LEVEL 2: States (find non-neighbor state) ----
  List<Question> _generateLevel2Questions(int setIndex) {
    final neighbors = _getNeighborStates(widget.userState);
    final farStates = _getFarStates(widget.userState);
    final allSets = _getLevel2QuestionSets(neighbors, farStates, widget.userState);
    
    List<Question> selectedSet = allSets[setIndex % allSets.length];
    selectedSet.shuffle(Random());
    return selectedSet.take(10).toList();
  }

  List<List<Question>> _getLevel2QuestionSets(
    List<String> neighborStates,
    List<String> farStates,
    String userState,
  ) {
    List<String> templates = [
      'Which state is NOT a neighbor of $userState?',
      'Find the state that does NOT share a border with $userState',
      'Which state is far from $userState?',
      'One of these states is NOT near $userState. Which one?',
      'Identify the state that is NOT adjacent to your state',
      'Which state would you NOT reach by crossing one border from $userState?',
      'Find the odd state — NOT a neighbor of $userState',
      'Which of these is geographically distant from $userState?',
      'Which state does NOT touch $userState?',
      'Spot the state that has no border with $userState',
    ];

    List<List<Question>> sets = [];
    for (int s = 0; s < 4; s++) {
      List<Question> setQuestions = [];
      List<String> shuffledNeighbors = List.from(neighborStates)..shuffle(Random(s));
      List<String> shuffledFar = List.from(farStates)..shuffle(Random(s + 50));
      List<String> shuffledTemplates = List.from(templates)..shuffle(Random(s + 300));
      
      for (int i = 0; i < 10; i++) {
        // Pick 3 UNIQUE neighbors. If fewer than 3, we must fill with others but NOT the odd one.
        // Actually for "odd one out" we need 3 "correct-group" items (neighbors) and 1 "odd" item (non-neighbor).
        
        Set<String> optionsSet = {};
        
        // 1. Add the odd one (non-neighbor)
        String oddState = shuffledFar[(i + s * 3) % shuffledFar.length];
        
        // 2. Add neighbors
        int neighborIndex = 0;
        // If we don't have enough neighbors, we might need to use "nearby but not touching" 
        // or just repeat, but repeating is what we want to AVOID.
        // Better strategy: If < 3 neighbors, include states that are 'close' but not 'far', 
        // OR just have fewer options? UI expects 4.
        
        // Let's try to fill with neighbors first
        for (final n in shuffledNeighbors) {
          if (optionsSet.length < 3) {
             optionsSet.add(n);
          }
        }

        // If still need more to make 3 'group' items, we have a problem for states like Kerala (2 neighbors).
        // Solution: Add a 'far' state that is NOT the 'oddState' (target) -- wait, that makes it ambiguous?
        // NO. The question is "Which is NOT a neighbor?". 
        // So {Neighbor, Neighbor, Neighbor, Non-Neighbor}.
        // If we only have 2 neighbors {N1, N2, ?, Odd}.
        // If '?' is a Non-Neighbor, then there are TWO correct answers. Bad.
        // If '?' is a Neighbor, we already used all of them.
        // So we MUST duplicate one of the neighbors? User complained about duplicates.
        // "Tamil Nadu is twice in options".
        
        // If we absolutely only have 2 neighbors, we cannot form a "3 neighbors vs 1 non-neighbor" question 
        // without duplicating a neighbor.
        // UNLESS we change the question format or adding a 'fake' neighbor... which is lying.
        
        // Alternative: For states with < 3 neighbors, add OTHER 'nearby' states and change phrasing?
        // Too complex.
        
        // BETTER FIX: If neighbors count < 3, add a filler that is NOT the odd state, 
        // but maybe we can just accept 3 options? (2 neighbors + 1 odd).
        // The UI renders list of options. It doesn't force 4.
        // Let's just generate fewer options if we run out of unique neighbors.
        
        // Current logic:
        List<String> neighborsToUse = [];
        if (neighborStates.length >= 3) {
          // Normal case, pick 3 unique
          // Rotate start index to avoid same 3 every time
           for(int k=0; k<3; k++) {
             neighborsToUse.add(shuffledNeighbors[(i + k) % shuffledNeighbors.length]);
           }
           optionsSet.addAll(neighborsToUse);
        } else {
          // Few neighbors (e.g. Kerala: TN, KA).
          // Add all real neighbors
          optionsSet.addAll(neighborStates);
          // If we have fewer than 3 'good' items, we just stop here. 
          // Resulting options: {TN, KA, OddState} -> 3 options total.
          // This eliminates duplicates and ambiguous questions.
        }
        
        // Add the odd state
        optionsSet.add(oddState);
        
        List<String> options = optionsSet.toList();
        options.shuffle(Random(i + s));
        
        setQuestions.add(Question(
          type: QuestionType.oddOneOut,
          questionText: shuffledTemplates[i % shuffledTemplates.length],
          options: options,
          correctAnswers: [oddState],
          category: 'neighbor_states',
          explanation: '$oddState does not share a border with $userState. The others are neighboring states.',
        ));
      }
      sets.add(setQuestions);
    }
    return sets;
  }

  // ---- LEVEL 3: Countries (find non-neighbor country) ----
  List<Question> _generateLevel3Questions(int setIndex) {
    final neighbors = _getIndiaNeighborCountries();
    final farCountries = _getFarCountries();
    final allSets = _getLevel3QuestionSets(neighbors, farCountries);
    
    List<Question> selectedSet = allSets[setIndex % allSets.length];
    selectedSet.shuffle(Random());
    return selectedSet.take(10).toList();
  }

  List<List<Question>> _getLevel3QuestionSets(
    List<String> neighborCountries,
    List<String> farCountries,
  ) {
    List<String> templates = [
      'Which country does NOT share a border with India?',
      'Find the country that is NOT a neighbor of India',
      'Which country is far from India?',
      'One of these is NOT an Indian neighbor. Which one?',
      'Identify the country that does NOT border India',
      'Which country has no shared border with India?',
      'Find the odd one — NOT a neighbor of India',
      'Which of these countries is geographically distant from India?',
      'Spot the country that does NOT touch India\u0027s border',
      'Which country would you NOT reach by land from India?',
    ];

    List<List<Question>> sets = [];
    for (int s = 0; s < 4; s++) {
      List<Question> setQuestions = [];
      List<String> shuffledNeighbors = List.from(neighborCountries)..shuffle(Random(s));
      List<String> shuffledFar = List.from(farCountries)..shuffle(Random(s + 70));
      List<String> shuffledTemplates = List.from(templates)..shuffle(Random(s + 400));
      
      for (int i = 0; i < 10; i++) {
        List<String> neighborPick = [];
        for (int j = 0; j < 3; j++) {
          neighborPick.add(shuffledNeighbors[(i * 3 + j) % shuffledNeighbors.length]);
        }
        String oddCountry = shuffledFar[(i + s * 3) % shuffledFar.length];
        
        List<String> options = [...neighborPick, oddCountry];
        options.shuffle(Random(i + s));
        
        setQuestions.add(Question(
          type: QuestionType.oddOneOut,
          questionText: shuffledTemplates[i % shuffledTemplates.length],
          options: options,
          correctAnswers: [oddCountry],
          category: 'neighbor_countries',
          explanation: '$oddCountry does not share a border with India. The others are neighboring countries.',
        ));
      }
      sets.add(setQuestions);
    }
    return sets;
  }

  // ==========================================
  // DATA: Cities, States, Countries
  // ==========================================

  List<String> _getStateCities(String state) {
    final Map<String, List<String>> stateCities = {
      'Kerala': ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kannur', 'Alappuzha', 'Kollam', 'Palakkad', 'Malappuram', 'Kottayam', 'Munnar', 'Wayanad'],
      'Tamil Nadu': ['Chennai', 'Madurai', 'Coimbatore', 'Salem', 'Tiruchirappalli', 'Tirunelveli', 'Erode', 'Vellore', 'Thoothukudi', 'Dindigul', 'Thanjavur', 'Ooty'],
      'Karnataka': ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubli', 'Belgaum', 'Shimoga', 'Davangere', 'Gulbarga', 'Udupi', 'Hassan', 'Tumkur', 'Raichur'],
      'Maharashtra': ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad', 'Solapur', 'Kolhapur', 'Thane', 'Satara', 'Sangli', 'Ratnagiri', 'Amravati'],
      'Andhra Pradesh': ['Visakhapatnam', 'Vijayawada', 'Guntur', 'Nellore', 'Kurnool', 'Tirupati', 'Kakinada', 'Rajahmundry', 'Anantapur', 'Kadapa'],
      'Telangana': ['Hyderabad', 'Warangal', 'Nizamabad', 'Karimnagar', 'Khammam', 'Mahbubnagar', 'Nalgonda', 'Adilabad', 'Suryapet', 'Siddipet'],
      'West Bengal': ['Kolkata', 'Howrah', 'Durgapur', 'Asansol', 'Siliguri', 'Darjeeling', 'Kharagpur', 'Haldia', 'Bardhaman', 'Malda'],
      'Gujarat': ['Ahmedabad', 'Surat', 'Vadodara', 'Rajkot', 'Bhavnagar', 'Jamnagar', 'Junagadh', 'Gandhinagar', 'Anand', 'Bharuch'],
      'Rajasthan': ['Jaipur', 'Jodhpur', 'Udaipur', 'Kota', 'Bikaner', 'Ajmer', 'Bhilwara', 'Alwar', 'Sikar', 'Pali'],
      'Uttar Pradesh': ['Lucknow', 'Kanpur', 'Agra', 'Varanasi', 'Prayagraj', 'Meerut', 'Noida', 'Ghaziabad', 'Bareilly', 'Aligarh'],
      'Punjab': ['Chandigarh', 'Ludhiana', 'Amritsar', 'Jalandhar', 'Patiala', 'Bathinda', 'Mohali', 'Pathankot', 'Hoshiarpur', 'Moga'],
      'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Ponda', 'Bicholim', 'Curchorem', 'Sanquelim', 'Canacona', 'Quepem'],
      'Odisha': ['Bhubaneswar', 'Cuttack', 'Rourkela', 'Puri', 'Sambalpur', 'Balasore', 'Berhampur', 'Baripada'],
      'Bihar': ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur', 'Purnia', 'Darbhanga', 'Bihar Sharif'],
      'Jharkhand': ['Ranchi', 'Jamshedpur', 'Dhanbad', 'Bokaro', 'Deoghar', 'Hazaribagh'],
      'Madhya Pradesh': ['Bhopal', 'Indore', 'Jabalpur', 'Gwalior', 'Ujjain', 'Sagar', 'Dewas'],
      'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Durg', 'Rajnandgaon'],
      'Haryana': ['Gurugram', 'Faridabad', 'Panipat', 'Ambala', 'Yamunanagar', 'Rohtak'],
      'Uttarakhand': ['Dehradun', 'Haridwar', 'Rishikesh', 'Nainital', 'Mussoorie', 'Roorkee'],
      'Himachal Pradesh': ['Shimla', 'Manali', 'Dharamshala', 'Solan', 'Mandi', 'Kullu'],
      'Assam': ['Guwahati', 'Silchar', 'Dibrugarh', 'Jorhat', 'Nagaon', 'Tinsukia'],
    };
    return stateCities[state] ?? ['Thiruvananthapuram', 'Kochi', 'Kozhikode', 'Thrissur', 'Kannur', 'Alappuzha', 'Kollam', 'Palakkad'];
  }

  List<String> _getNeighborStateCities(String state) {
    // Returns cities from NON-neighbor states (to use as odd ones out)
    List<String> farCities = [];
    final farStates = _getFarStates(state);
    
    // Sort to randomize which far states are picked, but seeding random might be better. 
    // Here we just take from the list.
    for (final fs in farStates) {
      // Ensure we have cities for this state
      final cities = _getStateCities(fs);
      // Only add if it's not the default fallback list (checking first element as proxy)
      // The default fallback in _getStateCities returns Kerala cities. 
      // If our 'fs' is not in the map, we get Kerala cities. 
      // We must avoid adding Kerala cities if the userState IS Kerala.
      // But _getFarStates should filter that out. 
      // HOWEVER, if 'fs' is 'UnknownState' and returns default, it might overlap.
      
      // Let's rely on the updated map having coverage.
      if (cities.isNotEmpty && cities.first != 'Thiruvananthapuram') {
         // This check prevents using the default fallback if the state isn't in our map,
         // UNLESS the state IS Kerala, but fs won't be Kerala if userState is Kerala.
         // Effectively, this skips undefined states.
         farCities.addAll(cities.take(4));
      } else if (fs == 'Kerala' && state != 'Kerala') {
         // Explicitly handle Kerala as a far state
         farCities.addAll(cities.take(4));
      }
    }
    
    if (farCities.isEmpty) {
      // Fallback only if we really can't find anything
      farCities = ['Delhi', 'Mumbai', 'Kolkata', 'Chennai', 'Bengaluru', 'Hyderabad']
          .where((c) => !_getStateCities(state).contains(c)).toList();
    }
    
    // Shuffle here to mix up sources
    farCities.shuffle();
    return farCities;
  }

  List<String> _getNeighborStates(String state) {
    final Map<String, List<String>> neighbors = {
      'Kerala': ['Tamil Nadu', 'Karnataka'],
      'Tamil Nadu': ['Kerala', 'Karnataka', 'Andhra Pradesh', 'Puducherry'],
      'Karnataka': ['Kerala', 'Tamil Nadu', 'Andhra Pradesh', 'Telangana', 'Maharashtra', 'Goa'],
      'Maharashtra': ['Karnataka', 'Goa', 'Telangana', 'Madhya Pradesh', 'Gujarat', 'Chhattisgarh'],
      'Andhra Pradesh': ['Tamil Nadu', 'Karnataka', 'Telangana', 'Odisha', 'Chhattisgarh'],
      'Telangana': ['Andhra Pradesh', 'Karnataka', 'Maharashtra', 'Chhattisgarh'],
      'West Bengal': ['Odisha', 'Jharkhand', 'Bihar', 'Sikkim', 'Assam'],
      'Gujarat': ['Maharashtra', 'Madhya Pradesh', 'Rajasthan'],
      'Rajasthan': ['Gujarat', 'Madhya Pradesh', 'Uttar Pradesh', 'Haryana', 'Punjab'],
      'Uttar Pradesh': ['Rajasthan', 'Madhya Pradesh', 'Chhattisgarh', 'Jharkhand', 'Bihar', 'Uttarakhand', 'Haryana', 'Delhi'],
      'Punjab': ['Rajasthan', 'Haryana', 'Himachal Pradesh', 'Jammu & Kashmir'],
      'Goa': ['Karnataka', 'Maharashtra'],
      'Odisha': ['West Bengal', 'Jharkhand', 'Chhattisgarh', 'Andhra Pradesh'],
      'Bihar': ['Uttar Pradesh', 'Jharkhand', 'West Bengal'],
      'Jharkhand': ['Bihar', 'Uttar Pradesh', 'Chhattisgarh', 'Odisha', 'West Bengal'],
      'Madhya Pradesh': ['Uttar Pradesh', 'Rajasthan', 'Gujarat', 'Maharashtra', 'Chhattisgarh'],
      'Chhattisgarh': ['Madhya Pradesh', 'Maharashtra', 'Telangana', 'Andhra Pradesh', 'Odisha', 'Jharkhand', 'Uttar Pradesh'],
      'Haryana': ['Punjab', 'Himachal Pradesh', 'Rajasthan', 'Uttar Pradesh', 'Delhi'],
      'Uttarakhand': ['Himachal Pradesh', 'Uttar Pradesh'],
      'Himachal Pradesh': ['Jammu & Kashmir', 'Punjab', 'Haryana', 'Uttarakhand'],
      'Assam': ['West Bengal', 'Arunachal Pradesh', 'Nagaland', 'Manipur', 'Mizoram', 'Tripura', 'Meghalaya'],
    };
    return neighbors[state] ?? ['Tamil Nadu', 'Karnataka'];
  }

  List<String> _getFarStates(String state) {
    final neighbors = _getNeighborStates(state);
    final allStates = [
      'Kerala', 'Tamil Nadu', 'Karnataka', 'Maharashtra', 'Andhra Pradesh',
      'Telangana', 'West Bengal', 'Gujarat', 'Rajasthan', 'Uttar Pradesh',
      'Punjab', 'Goa', 'Odisha', 'Bihar', 'Jharkhand', 'Assam',
      'Madhya Pradesh', 'Chhattisgarh', 'Haryana', 'Uttarakhand',
      'Himachal Pradesh', 'Sikkim', 'Meghalaya', 'Tripura',
    ];
    return allStates.where((s) => s != state && !neighbors.contains(s)).toList();
  }

  List<String> _getIndiaNeighborCountries() {
    return ['Pakistan', 'China', 'Nepal', 'Bhutan', 'Bangladesh', 'Myanmar', 'Sri Lanka'];
  }

  List<String> _getFarCountries() {
    return [
      'Japan', 'Australia', 'Brazil', 'Canada', 'France', 'Germany',
      'Italy', 'Mexico', 'South Korea', 'United Kingdom', 'Russia',
      'Spain', 'Argentina', 'Egypt', 'Nigeria', 'South Africa',
      'Turkey', 'Saudi Arabia', 'Indonesia', 'Thailand', 'Vietnam',
      'Sweden', 'Norway', 'Poland', 'Greece', 'New Zealand',
    ];
  }

  // ==========================================
  // ANSWER HANDLING
  // ==========================================
  
  void _onAnswerSubmitted(String selectedAnswer) {
    if (!gameActive || currentQuestionIndex >= questions.length || showingFeedback) return;
    
    DateTime answerTime = DateTime.now();
    Question currentQuestion = questions[currentQuestionIndex];
    
    // Calculate time taken
    if (questionStartTimes.containsKey(currentQuestionIndex)) {
      double timeTaken = answerTime.difference(questionStartTimes[currentQuestionIndex]!).inMilliseconds / 1000.0;
      timePerQuestion[currentQuestionIndex] = timeTaken;
    }
    
    bool isCorrect = selectedAnswer == currentQuestion.correctAnswers.first;
    answerCorrectness[currentQuestionIndex] = isCorrect;
    userAnswers[currentQuestionIndex] = selectedAnswer;
    
    if (isCorrect) {
      correctAnswers++;
      consecutiveCorrect++;
      if (consecutiveCorrect > maxConsecutiveCorrect) {
        maxConsecutiveCorrect = consecutiveCorrect;
      }
      if (timePerQuestion[currentQuestionIndex] != null && timePerQuestion[currentQuestionIndex]! < 5.0) {
        firstAttemptCorrect++;
      }
    } else {
      wrongAnswers++;
      consecutiveCorrect = 0;
    }
    
    // Show feedback
    setState(() {
      lastAnswerCorrect = isCorrect;
      lastExplanation = currentQuestion.explanation;
      showingFeedback = true;
    });
    
    // Move to next after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      currentQuestionIndex++;
      
      if (currentQuestionIndex < questions.length) {
        questionStartTimes[currentQuestionIndex] = DateTime.now();
        setState(() {
          showingFeedback = false;
          lastAnswerCorrect = null;
        });
      } else {
        setState(() => showingFeedback = false);
        _endGame();
      }
    });
  }

  // ==========================================
  // GAME END & FIRESTORE SAVE
  // ==========================================
  
  void _endGame() async {
    setState(() => gameActive = false);
    
    double averageTime = timePerQuestion.isEmpty ? 0 : timePerQuestion.values.reduce((a, b) => a + b) / timePerQuestion.length;
    double accuracy = totalQuestions == 0 ? 0 : correctAnswers / totalQuestions;
    double fastRate = correctAnswers == 0 ? 0 : firstAttemptCorrect / correctAnswers;
    
    int finalScore = _calculateScore();
    Map<String, int> cognitiveScores = _calculateCognitiveScores(accuracy, averageTime, fastRate);
    
    String? userId = await UserIdHelper.getCurrentUserId();
    
    if (userId == null || userId.isEmpty) {
      _showResultDialog(finalScore, accuracy, cognitiveScores);
      return;
    }
    
    try {
      Map<String, dynamic> sessionData = {
        'userId': userId,
        'gameType': 'city_atlas',
        'difficultyLevel': widget.difficultyLevel,
        'userState': widget.userState,
        'startTime': gameStartTime.toIso8601String(),
        'endTime': DateTime.now().toIso8601String(),
        'duration': DateTime.now().difference(gameStartTime).inSeconds,
        'completed': true,
        'score': finalScore,
        'sessionNumber': _sessionNumber,
        'questionSetIndex': _getQuestionSetIndex(),
        'metrics': {
          'total_questions': totalQuestions,
          'correct_answers': correctAnswers,
          'wrong_answers': wrongAnswers,
          'accuracy': accuracy,
          'average_time_per_question': averageTime,
          'fast_response_rate': fastRate,
          'max_consecutive_correct': maxConsecutiveCorrect,
          'first_attempt_correct': firstAttemptCorrect,
        },
        'cognitive_contributions': cognitiveScores,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _db.collection('game_sessions').add(sessionData);
      await _updateCognitiveSummary(userId, cognitiveScores);
      
      if (mounted) _showResultDialog(finalScore, accuracy, cognitiveScores);
    } catch (e) {
      if (mounted) _showResultDialog(finalScore, accuracy, cognitiveScores);
    }
  }

  int _calculateScore() {
    int score = correctAnswers * 15;
    score += maxConsecutiveCorrect * 3;
    score += firstAttemptCorrect * 5;
    
    if (widget.difficultyLevel == 2) score = (score * 1.2).toInt();
    if (widget.difficultyLevel == 3) score = (score * 1.5).toInt();
    
    return score > 0 ? score : 0;
  }

  Map<String, int> _calculateCognitiveScores(double accuracy, double avgTime, double fastRate) {
    // Executive Function: categorization + decision speed
    int categorizationScore;
    if (accuracy > 0.9) categorizationScore = 100;
    else if (accuracy > 0.75) categorizationScore = 85;
    else if (accuracy > 0.6) categorizationScore = 70;
    else if (accuracy > 0.5) categorizationScore = 60;
    else categorizationScore = 45;

    int decisionSpeed;
    if (avgTime < 6) decisionSpeed = 100;
    else if (avgTime < 10) decisionSpeed = 85;
    else if (avgTime < 15) decisionSpeed = 70;
    else decisionSpeed = 55;

    int executiveFunction = (categorizationScore * 0.6 + decisionSpeed * 0.4).round();

    // Memory: geographic knowledge + recall speed
    int knowledgeScore = (accuracy * 100).toInt();
    int recallSpeed;
    if (fastRate > 0.7) recallSpeed = 100;
    else if (fastRate > 0.5) recallSpeed = 85;
    else if (fastRate > 0.3) recallSpeed = 70;
    else recallSpeed = 60;

    int memoryScore = (knowledgeScore * 0.6 + recallSpeed * 0.4).round();

    return {
      'executive_function': executiveFunction,
      'memory': memoryScore,
    };
  }

  Future<void> _updateCognitiveSummary(String userId, Map<String, int> cognitiveScores) async {
    try {
      final recentSessions = await _db.collection('game_sessions')
          .where('userId', isEqualTo: userId)
          .where('gameType', isEqualTo: 'city_atlas')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      if (recentSessions.docs.length < 3) return;

      int avgExec = 0, avgMem = 0;
      for (var doc in recentSessions.docs) {
        Map<String, dynamic> data = doc.data();
        Map<String, dynamic> contributions = data['cognitive_contributions'] ?? {};
        avgExec += (contributions['executive_function'] as num? ?? 0).toInt();
        avgMem += (contributions['memory'] as num? ?? 0).toInt();
      }
      avgExec = (avgExec / recentSessions.docs.length).round();
      avgMem = (avgMem / recentSessions.docs.length).round();

      await _db.collection('cognitive_summary').doc(userId).set({
        'executiveFunctionScore': avgExec,
        'memoryScore': avgMem,
        'lastUpdated': FieldValue.serverTimestamp(),
        'totalGamesPlayed': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _showResultDialog(int score, double accuracy, Map<String, int> cognitiveScores) {
    if (!mounted) return;
    
    String levelLabel;
    switch (widget.difficultyLevel) {
      case 1: levelLabel = 'Local Cities'; break;
      case 2: levelLabel = 'Indian States'; break;
      case 3: levelLabel = 'World Countries'; break;
      default: levelLabel = 'City Atlas';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(
              accuracy > 0.7 ? Icons.emoji_events : Icons.sports_score,
              color: accuracy > 0.7 ? Colors.amber : Colors.blue,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text('$levelLabel Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Score: $score', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            Text('Accuracy: ${(accuracy * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 16)),
            Text('$correctAnswers / $totalQuestions correct', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            const Divider(),
            const Text('Cognitive Assessment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildScoreRow('Executive Function', cognitiveScores['executive_function'] ?? 0, Colors.orange),
            const SizedBox(height: 4),
            _buildScoreRow('Memory', cognitiveScores['memory'] ?? 0, Colors.purple),
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
  // UI BUILD
  // ==========================================
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('City Atlas')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading questions...'),
            ],
          ),
        ),
      );
    }
    
    if (!gameActive || currentQuestionIndex >= questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('City Atlas')),
        body: const Center(child: Text('Game Over')),
      );
    }
    
    Question currentQuestion = questions[currentQuestionIndex];
    
    String levelTitle;
    switch (widget.difficultyLevel) {
      case 1: levelTitle = 'Cities Near You'; break;
      case 2: levelTitle = 'Indian States'; break;
      case 3: levelTitle = 'World Countries'; break;
      default: levelTitle = 'City Atlas';
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(levelTitle),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${currentQuestionIndex + 1}/$totalQuestions',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (currentQuestionIndex + 1) / totalQuestions,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.difficultyLevel == 1 ? Colors.green :
              widget.difficultyLevel == 2 ? Colors.orange : Colors.red,
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatChip('✅ $correctAnswers', Colors.green),
                      _buildStatChip('❌ $wrongAnswers', Colors.red),
                      _buildStatChip('🔥 $consecutiveCorrect', Colors.orange),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Question card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            widget.difficultyLevel == 1 ? Icons.home :
                            widget.difficultyLevel == 2 ? Icons.map :
                            Icons.public,
                            size: 32,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentQuestion.questionText,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
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
                        border: Border.all(
                          color: lastAnswerCorrect! ? Colors.green : Colors.red,
                        ),
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
                              lastAnswerCorrect! ? 'Correct! 🎉' : lastExplanation ?? 'Wrong answer',
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
                  Expanded(
                    child: ListView.builder(
                      itemCount: currentQuestion.options.length,
                      itemBuilder: (context, index) {
                        String option = currentQuestion.options[index];
                        
                        Color? cardColor;
                        if (showingFeedback) {
                          if (option == currentQuestion.correctAnswers.first) {
                            cardColor = Colors.green.shade50;
                          } else if (userAnswers[currentQuestionIndex] == option && !answerCorrectness[currentQuestionIndex]!) {
                            cardColor = Colors.red.shade50;
                          }
                        }
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: cardColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: cardColor != null 
                                ? (cardColor == Colors.green.shade50 ? Colors.green : Colors.red)
                                : Colors.grey.shade300,
                            ),
                          ),
                          child: ListTile(
                            title: Text(
                              option,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                            ),
                            trailing: showingFeedback && option == currentQuestion.correctAnswers.first
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                            onTap: showingFeedback ? null : () => _onAnswerSubmitted(option),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ==========================================
// DATA MODELS
// ==========================================

enum QuestionType {
  oddOneOut,
  multipleCorrect,
}

class Question {
  final QuestionType type;
  final String questionText;
  final List<String> options;
  final List<String> correctAnswers;
  final String category;
  final String explanation;
  
  Question({
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswers,
    required this.category,
    required this.explanation,
  });
}

class City {
  final String name;
  final String state;
  final String category;
  final bool isCapital;
  final bool isMetro;
  final bool isCoastal;
  
  City(this.name, this.state, this.category, this.isCapital, this.isMetro, this.isCoastal);
}
