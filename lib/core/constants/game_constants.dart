// FILE LOCATION: lib/core/constants/game_constants.dart

class GameConstants {
  // Difficulty Levels
  static const int DIFFICULTY_EASY = 1;
  static const int DIFFICULTY_MEDIUM = 2;
  static const int DIFFICULTY_HARD = 3;

  // Color Tap Game Settings
  static const Map<int, ColorTapSettings> colorTapSettings = {
    DIFFICULTY_EASY: ColorTapSettings(
      duration: 60,
      numberOfCircles: 4,
      circleSize: 100.0,
      colorChangeInterval: 4000,
      pointsPerCorrect: 10,
      pointsPerWrong: -5,
    ),
    DIFFICULTY_MEDIUM: ColorTapSettings(
      duration: 60,
      numberOfCircles: 6,
      circleSize: 80.0,
      colorChangeInterval: 3000,
      pointsPerCorrect: 15,
      pointsPerWrong: -5,
    ),
    DIFFICULTY_HARD: ColorTapSettings(
      duration: 60,
      numberOfCircles: 8,
      circleSize: 70.0,
      colorChangeInterval: 2000,
      pointsPerCorrect: 20,
      pointsPerWrong: -5,
    ),
  };

  // Cognitive Score Thresholds
  static const Map<String, dynamic> cognitiveThresholds = {
    'excellent': 80,
    'good': 60,
    'average': 40,
    'needsImprovement': 20,
  };

  // Game Session Batch Size for Analytics
  static const int ANALYTICS_BATCH_SIZE = 10;

  // Minimum sessions required for cognitive scoring
  static const int MIN_SESSIONS_FOR_SCORING = 3;
}

class ColorTapSettings {
  final int duration;
  final int numberOfCircles;
  final double circleSize;
  final int colorChangeInterval;
  final int pointsPerCorrect;
  final int pointsPerWrong;

  const ColorTapSettings({
    required this.duration,
    required this.numberOfCircles,
    required this.circleSize,
    required this.colorChangeInterval,
    required this.pointsPerCorrect,
    required this.pointsPerWrong,
  });
}

// Game Types
enum GameType {
  colorTap,
  candyCrush,
  wordSearch,
  reminiscence,
  cityAtlas,
  flipCard,
  eventOrdering,
  routineRecall,
  monumentRecall,
}

// Game Zones
enum GameZone { chillZone, dailyEngagement }

// Game Categories for Cognitive Mapping
class GameCategory {
  static const String ATTENTION = 'attention'; //color tap
  static const String MEMORY = 'memory';
  static const String EXECUTIVE = 'executive';
  static const String PROCESSING_SPEED = 'processing_speed'; //color tap
  static const String LANGUAGE = 'language';
}

// Cognitive Score Weights (out of 100)
class CognitiveWeights {
  static const Map<String, int> colorTap = {
    GameCategory.ATTENTION: 40,
    GameCategory.PROCESSING_SPEED: 35,
    GameCategory.EXECUTIVE: 25,
  };

  static const Map<String, int> wordSearch = {
    GameCategory.ATTENTION: 30,
    GameCategory.LANGUAGE: 40,
    GameCategory.PROCESSING_SPEED: 30,
  };

  static const Map<String, int> flipCard = {
    GameCategory.MEMORY: 50,
    GameCategory.ATTENTION: 30,
    GameCategory.PROCESSING_SPEED: 20,
  };
}
