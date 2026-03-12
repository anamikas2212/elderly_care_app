//used...
import 'package:flutter/material.dart';
import '../../games/chill_zone/color_tap/color_tap_game.dart';
import '../../games/chill_zone/flip_card_match/flip_card_game.dart';

class ChillZoneScreen extends StatelessWidget {
  final String userId;

  const ChillZoneScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chill Zone'),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.shade50, Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader('Relax & Play'),
            const SizedBox(height: 20),
            _buildGameCard(
              context,
              title: 'Color Tap',
              description: 'Match colors and test your reflexes!',
              icon: Icons.palette,
              color: Colors.purple,
              onTap: () => _showColorTapDifficultyDialog(context),
            ),
            const SizedBox(height: 15),
            _buildGameCard(
              context,
              title: 'Flip Card Match',
              description: 'Test your memory by matching card pairs!',
              icon: Icons.psychology,
              color: Colors.deepPurple,
              onTap: () => _showFlipCardDifficultyDialog(context),
            ),
            const SizedBox(height: 15),
            _buildGameCard(
              context,
              title: 'Nature Sounds',
              description: 'Listen to soothing sounds of nature.',
              icon: Icons.landscape,
              color: Colors.green,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming Soon!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorTapDifficultyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Choose Difficulty',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDifficultyButton(
                context,
                'Easy',
                'Slower pace - 2.0s intervals',
                1,
                Colors.green,
                Icons.sentiment_satisfied,
              ),
              const SizedBox(height: 12),
              _buildDifficultyButton(
                context,
                'Medium',
                'Moderate pace - 1.8s intervals',
                2,
                Colors.orange,
                Icons.sentiment_neutral,
              ),
              const SizedBox(height: 12),
              _buildDifficultyButton(
                context,
                'Hard',
                'Fast pace - 1.4s intervals',
                3,
                Colors.red,
                Icons.sentiment_very_dissatisfied,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFlipCardDifficultyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Choose Difficulty',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFlipCardDifficultyButton(
                context,
                'Easy',
                '6 pairs - 5 seconds preview',
                1,
                Colors.green,
                Icons.sentiment_satisfied,
              ),
              const SizedBox(height: 12),
              _buildFlipCardDifficultyButton(
                context,
                'Medium',
                '8 pairs - 4 seconds preview',
                2,
                Colors.orange,
                Icons.sentiment_neutral,
              ),
              const SizedBox(height: 12),
              _buildFlipCardDifficultyButton(
                context,
                'Hard',
                '10 pairs - 3 seconds preview',
                3,
                Colors.red,
                Icons.sentiment_very_dissatisfied,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDifficultyButton(
    BuildContext context,
    String level,
    String description,
    int difficultyLevel,
    Color color,
    IconData icon,
  ) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ColorTapGame(
              difficultyLevel: difficultyLevel,
              userId: userId,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipCardDifficultyButton(
    BuildContext context,
    String level,
    String description,
    int difficultyLevel,
    Color color,
    IconData icon,
  ) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context); // Close dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlipCardGame(
              difficultyLevel: difficultyLevel,
              userId: userId,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.teal.shade800,
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill, size: 40, color: color.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }
}
