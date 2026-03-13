import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../games/daily_engagement/city_atlas/city_atlas_game.dart';
import '../../games/daily_engagement/daily_routine_recall/daily_routine_recall_game.dart';
import '../../games/daily_engagement/event_ordering/event_ordering_game.dart';
import '../../games/daily_engagement/monument_recall/monument_recall_game.dart';

class DailyEngagementScreen extends StatefulWidget {
  final String userId;

  const DailyEngagementScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<DailyEngagementScreen> createState() => _DailyEngagementScreenState();
}

class _DailyEngagementScreenState extends State<DailyEngagementScreen> {
  String userState = "Kerala"; // Default
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('state')) {
          setState(() {
            userState = data['state'];
          });
        }
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Daily Engagement'),
        backgroundColor: Colors.orange,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50, Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader('Sharpen Your Mind'),
            const SizedBox(height: 20),
            
            // 1. City Atlas
            _buildGameCard(
              context,
              title: 'City Atlas',
              description: 'Explore cities and test your geography knowledge!',
              icon: Icons.map,
              color: Colors.blue,
              onTap: () => _showDifficultyDialog(
                context, 
                'City Atlas', 
                (level) => CityAtlasGame(difficultyLevel: level, userState: userState),
              ),
            ),
            const SizedBox(height: 15),

            // 2. Daily Routine Recall
            _buildGameCard(
              context,
              title: 'Daily Routine Recall',
              description: 'Track and recall your daily activities.',
              icon: Icons.history,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyRoutineRecallGame(userId: widget.userId),
                  ),
                );
              },
            ),
            const SizedBox(height: 15),

            // 3. Event Ordering
            _buildGameCard(
              context,
              title: 'Event Ordering',
              description: 'Arrange historical events in the correct order.',
              icon: Icons.format_list_numbered,
              color: Colors.purple,
              onTap: () => _showDifficultyDialog(
                context,
                'Event Ordering',
                (level) => EventOrderingGame(difficultyLevel: level, userState: userState),
                difficultyDescriptions: [
                  'Dates shown (Full)',
                  'Years only',
                  'No dates shown',
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 4. Monument Recall
            _buildGameCard(
              context,
              title: 'Monument Recall',
              description: 'Identify famous monuments from around the world.',
              icon: Icons.account_balance,
              color: Colors.brown,
              onTap: () => _showDifficultyDialog(
                context,
                'Monument Recall',
                (level) => MonumentRecallGame(difficultyLevel: level, userState: userState),
                difficultyDescriptions: [
                  'State Level',
                  'National Level',
                  'International Level',
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDifficultyDialog(
    BuildContext context, 
    String title, 
    Widget Function(int) gameBuilder, 
    {List<String>? difficultyDescriptions}
  ) {
    final descriptions = difficultyDescriptions ?? [
      'Easy',
      'Medium',
      'Hard',
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '$title Difficulty',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDifficultyButton(context, 'Level 1', descriptions[0], 1, Colors.green, gameBuilder),
              const SizedBox(height: 12),
              _buildDifficultyButton(context, 'Level 2', descriptions[1], 2, Colors.orange, gameBuilder),
              const SizedBox(height: 12),
              _buildDifficultyButton(context, 'Level 3', descriptions[2], 3, Colors.red, gameBuilder),
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
    Widget Function(int) gameBuilder,
  ) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => gameBuilder(difficultyLevel),
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
          CircleAvatar(
            backgroundColor: color,
            radius: 12,
            child: Text(
              '$difficultyLevel', 
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 18,
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
          const Icon(Icons.arrow_forward_ios, size: 16),
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
        color: Colors.orange.shade800,
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill, size: 36, color: color.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }
}
