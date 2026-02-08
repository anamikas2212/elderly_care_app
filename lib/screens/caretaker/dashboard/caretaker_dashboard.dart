import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ ADDED - Important for Timestamp type
import '../../../theme/caretaker_theme.dart';
import '../../../services/caretaker_data_service.dart';
import 'cognitive_health_screen.dart';
import 'safety_monitor_screen.dart';
import 'medication_screen.dart';
import 'medication_management_screen.dart';
import 'buddy_activity_log_screen.dart';
import 'connect_screens.dart';
import '../../auth/login_screen.dart';

class CaretakerDashboard extends StatefulWidget {
  const CaretakerDashboard({Key? key}) : super(key: key);

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  final CaretakerDataService _dataService = CaretakerDataService();
  String elderlyUserId = "";
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadElderlyUserId();
  }

  Future<void> _loadElderlyUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId =
          prefs.getString('elderly_user_id') ??
          prefs.getString('elderly_user_name');

      if (userId == null || userId.isEmpty) {
        setState(() {
          _errorMessage = "No elderly user linked. Please set up a connection.";
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        elderlyUserId = userId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load user data: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: CaretakerColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: CaretakerColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: CaretakerColors.errorRed,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _loadElderlyUserId(),
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CaretakerColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: CaretakerLayout.screenPadding,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildPatientHeaderCard(context),
                const SizedBox(height: 16),
                _buildAlertBanner(context),
                const SizedBox(height: 16),

                // Cognitive Health Score Card
                _buildCognitiveHealthCard(),
                const SizedBox(height: 16),

                // Domain Scores Card (Attention & Processing Speed)
                _buildDomainScoresCard(),
                const SizedBox(height: 16),

                // Game Metrics Card
                _buildGameMetricsCard(),
                const SizedBox(height: 16),

                _buildStatsCardsRow(context),
                const SizedBox(height: 16),

                // Recent Activity
                _buildRecentActivityCard(),
                const SizedBox(height: 24),

                _buildSectionTitle("Quick Access"),
                const SizedBox(height: 12),
                _buildQuickAccessGrid(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Cognitive Health Score Card
  Widget _buildCognitiveHealthCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.calculateCognitiveHealthScore(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Calculating cognitive health...");
        }

        if (snapshot.hasError) {
          return _buildErrorCard(
            "Error calculating cognitive health: ${snapshot.error}",
          );
        }

        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!['totalSessions'] == 0) {
          return _buildEmptyCard(
            "No game data available yet. Play games to see cognitive health score.",
          );
        }

        final data = snapshot.data!;
        final score = data['healthScore'] as int;
        final totalSessions = data['totalSessions'] as int;
        final avgAccuracy = data['avgAccuracy'] as double;
        final avgReactionTime = data['avgReactionTime'] as double;

        final Color scoreColor =
            score >= 75
                ? Colors.green
                : score >= 50
                ? Colors.orange
                : Colors.red;

        final String statusEmoji =
            score >= 75
                ? '🟢'
                : score >= 50
                ? '🟡'
                : '🔴';

        final String status =
            score >= 75
                ? 'Excellent'
                : score >= 50
                ? 'Good'
                : 'Needs Attention';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cognitive Health Score',
                    style: CaretakerTextStyles.cardTitle,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor),
                    ),
                    child: Text(
                      '$statusEmoji $status',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Circular Progress Indicator
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey.shade200,
                        color: scoreColor,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          'out of 100',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Metrics Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildMetricRow(
                      'Accuracy',
                      '${avgAccuracy.toStringAsFixed(1)}%',
                      Icons.check_circle_outline,
                    ),
                    const Divider(height: 16),
                    _buildMetricRow(
                      'Avg Reaction Time',
                      '${avgReactionTime.toStringAsFixed(3)}s',
                      Icons.timer_outlined,
                    ),
                    const Divider(height: 16),
                    _buildMetricRow(
                      'Sessions Analyzed',
                      '$totalSessions',
                      Icons.analytics_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: CaretakerColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Domain Scores Card - Attention & Processing Speed
  Widget _buildDomainScoresCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.calculateDomainScores(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Calculating domain scores...");
        }

        if (snapshot.hasError) {
          return _buildErrorCard("Error loading domains: ${snapshot.error}");
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildEmptyCard("No domain data available");
        }

        final data = snapshot.data!;
        final attentionScore = data['attentionScore'] as double;
        final processingSpeedScore = data['processingSpeedScore'] as double;
        final sessionsCount = data['sessionsCount'] as int;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cognitive Domains',
                    style: CaretakerTextStyles.cardTitle,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: CaretakerColors.lightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Color Tap Game',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: CaretakerColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Based on $sessionsCount game sessions',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              // Attention Domain
              _buildDomainRow(
                'Attention',
                'Measures focus and correct tap accuracy',
                attentionScore,
                CaretakerColors.highlightBlue,
                Icons.center_focus_strong,
              ),
              const SizedBox(height: 16),

              // Processing Speed Domain
              _buildDomainRow(
                'Processing Speed',
                'Measures reaction time and response speed',
                processingSpeedScore,
                CaretakerColors.successGreen,
                Icons.speed,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDomainRow(
    String label,
    String description,
    double score,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              '${score.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade200,
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Game Metrics Card - Shows detailed game metrics
  Widget _buildGameMetricsCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.getDetailedGameMetrics(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading game metrics...");
        }

        if (snapshot.hasError) {
          return _buildErrorCard("Error loading metrics: ${snapshot.error}");
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return _buildEmptyCard("No game metrics available");
        }

        final data = snapshot.data!;
        final accuracy = data['accuracy'] as double;
        final avgReactionTime = data['avgReactionTime'] as double;
        final correctTaps = data['totalCorrectTaps'] as int;
        final falseTaps = data['totalFalseTaps'] as int;
        final missedTaps = data['totalMissedTaps'] as int;
        final totalTaps = correctTaps + falseTaps + missedTaps;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Game Performance Metrics',
                style: CaretakerTextStyles.cardTitle,
              ),
              const SizedBox(height: 20),

              // Main Metrics
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBox(
                      'Accuracy',
                      '${accuracy.toStringAsFixed(1)}%',
                      Icons.stars,
                      Colors.purple,
                      'Correct taps / Total taps',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricBox(
                      'Reaction Time',
                      '${avgReactionTime.toStringAsFixed(3)}s',
                      Icons.timer,
                      Colors.blue,
                      'Average response speed',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Tap Breakdown
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap Breakdown (Total: $totalTaps)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Correct Taps
                    _buildTapBreakdownRow(
                      'Correct Taps',
                      correctTaps,
                      totalTaps > 0 ? (correctTaps / totalTaps * 100) : 0,
                      Colors.green,
                      Icons.check_circle,
                    ),
                    const SizedBox(height: 8),

                    // False Taps
                    _buildTapBreakdownRow(
                      'False Taps',
                      falseTaps,
                      totalTaps > 0 ? (falseTaps / totalTaps * 100) : 0,
                      Colors.red,
                      Icons.cancel,
                    ),
                    const SizedBox(height: 8),

                    // Missed Taps
                    _buildTapBreakdownRow(
                      'Missed Taps',
                      missedTaps,
                      totalTaps > 0 ? (missedTaps / totalTaps * 100) : 0,
                      Colors.orange,
                      Icons.remove_circle_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildTapBreakdownRow(
    String label,
    int count,
    double percentage,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '(${percentage.toStringAsFixed(1)}%)',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ✅ Recent Activity Card - WITH IMPROVED TIMESTAMP HANDLING
  Widget _buildRecentActivityCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dataService.getRecentGameSessions(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading recent activity...");
        }

        if (snapshot.hasError) {
          return _buildErrorCard("Error loading activity: ${snapshot.error}");
        }

        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent activity',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Activity will appear here once games are played',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final sessions = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: CaretakerTextStyles.cardTitle,
                  ),
                  Text(
                    '${sessions.length} sessions',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...sessions.take(5).map((session) {
                final score = session['score'] as int? ?? 0;
                final correctTaps = session['correct_taps'] as int? ?? 0;
                final falseTaps = session['false_taps'] as int? ?? 0;
                final missedTaps = session['missed_taps'] as int? ?? 0;
                final avgReactionTime =
                    session['average_reaction_time'] as double? ?? 0.0;

                // ✅ IMPROVED TIMESTAMP HANDLING
                int timestamp = 0;
                final timestampValue = session['createdAt'];

                if (timestampValue != null) {
                  if (timestampValue is int) {
                    // Already an integer timestamp
                    timestamp = timestampValue;
                  } else if (timestampValue is Timestamp) {
                    // Firestore Timestamp object - type-safe conversion
                    timestamp = timestampValue.millisecondsSinceEpoch;
                  } else {
                    // Fallback: try dynamic conversion with error handling
                    try {
                      timestamp =
                          (timestampValue as dynamic).millisecondsSinceEpoch;
                    } catch (e) {
                      // If conversion fails, use 0 (will show "Unknown")
                      timestamp = 0;
                    }
                  }
                }

                final timeAgo = _getTimeAgo(timestamp);

                // Calculate accuracy
                final totalAttempts = correctTaps + falseTaps;
                final accuracy =
                    totalAttempts > 0
                        ? (correctTaps / totalAttempts * 100).toInt()
                        : 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CaretakerColors.lightGreen,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.touch_app,
                                size: 20,
                                color: CaretakerColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Color Tap Game',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CaretakerColors.primaryGreen
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$score pts',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: CaretakerColors.primaryGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$accuracy% acc',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        accuracy >= 80
                                            ? Colors.green
                                            : accuracy >= 60
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Metrics Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSessionMetric(
                              '✓',
                              '$correctTaps',
                              Colors.green,
                            ),
                            _buildSessionMetric('✗', '$falseTaps', Colors.red),
                            _buildSessionMetric(
                              '○',
                              '$missedTaps',
                              Colors.orange,
                            ),
                            _buildSessionMetric(
                              '⚡',
                              '${avgReactionTime.toStringAsFixed(2)}s',
                              Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionMetric(String icon, String value, Color color) {
    return Row(
      children: [
        Text(icon, style: TextStyle(fontSize: 12, color: color)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(int timestamp) {
    if (timestamp == 0) return 'Unknown';
    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - timestamp;
    final seconds = difference ~/ 1000;

    if (seconds < 60) {
      return '${seconds}s ago';
    } else if (seconds < 3600) {
      return '${seconds ~/ 60}m ago';
    } else if (seconds < 86400) {
      return '${seconds ~/ 3600}h ago';
    } else {
      return '${seconds ~/ 86400}d ago';
    }
  }

  // ✅ Patient Header Card
  Widget _buildPatientHeaderCard(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.getUserProfile(elderlyUserId),
      builder: (context, snapshot) {
        String name = elderlyUserId;
        String age = "--";
        String gender = "--";
        String location = "Unknown";
        String lastActive = "Unknown";
        String status = "Active";

        if (snapshot.hasData && snapshot.data != null) {
          final profile = snapshot.data!;
          name = profile['name'] as String? ?? elderlyUserId;
          age = profile['age']?.toString() ?? "--";
          gender = profile['gender'] as String? ?? "--";
          location = profile['location'] as String? ?? "Unknown";
          lastActive = profile['lastActive'] as String? ?? "Unknown";
          status = profile['status'] as String? ?? "Active";
        }

        final statusColor = _getStatusColor(status);

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [CaretakerColors.primaryGreen, Color(0xFF2DBE91)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: CaretakerLayout.cardRadius,
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Age $age • $gender",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "$location • $lastActive",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'stable':
      case 'active':
        return CaretakerColors.successGreen;
      case 'critical':
        return CaretakerColors.errorRed;
      case 'warning':
        return CaretakerColors.warningAmber;
      default:
        return Colors.grey;
    }
  }

  // ✅ Alert Banner
  Widget _buildAlertBanner(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _dataService.getActiveAlert(elderlyUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final alert = snapshot.data!;
        final title = alert['title'] as String? ?? 'Alert';
        final message = alert['message'] as String? ?? '';
        final type = alert['type'] as String? ?? 'warning';
        final actionText = alert['actionText'] as String? ?? 'View';

        final alertColor = _getAlertColor(type);
        final alertBgColor = _getAlertBackgroundColor(type);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: alertBgColor,
            borderRadius: CaretakerLayout.cardRadius,
          ),
          child: Row(
            children: [
              Icon(_getAlertIcon(type), color: alertColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: alertColor.withOpacity(0.9),
                        fontSize: 14,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: alertColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicationManagementScreen(),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: alertColor,
                  side: BorderSide(color: alertColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(actionText),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications;
    }
  }

  Color _getAlertColor(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return CaretakerColors.errorRed;
      case 'warning':
        return const Color(0xFF5D4037);
      case 'info':
        return CaretakerColors.highlightBlue;
      default:
        return Colors.grey;
    }
  }

  Color _getAlertBackgroundColor(String type) {
    switch (type.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFFEBEE);
      case 'warning':
        return const Color(0xFFFFF4E5);
      case 'info':
        return const Color(0xFFE3F2FD);
      default:
        return Colors.grey.shade100;
    }
  }

  // ✅ Stats Cards Row
  Widget _buildStatsCardsRow(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.getOverallStatistics(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              Expanded(child: _buildLoadingCard("Loading...")),
              const SizedBox(width: 12),
              Expanded(child: _buildLoadingCard("Loading...")),
            ],
          );
        }

        int totalGames = 0;
        int medicationAdherence = 87;

        if (snapshot.hasData && snapshot.data != null) {
          final stats = snapshot.data!;
          totalGames = stats['totalGames'] as int? ?? 0;
          medicationAdherence = stats['medicationAdherence'] as int? ?? 87;
        }

        return Row(
          children: [
            Expanded(
              child: _buildSmallStatCard(
                title: "Games Played",
                value: "$totalGames",
                subtext: "Total sessions",
                icon: Icons.videogame_asset,
                color: CaretakerColors.highlightBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallStatCard(
                title: "Medication",
                value: "$medicationAdherence%",
                subtext: "Adherence",
                icon: Icons.medication,
                color: CaretakerColors.successGreen,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallStatCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: CaretakerTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: CaretakerColors.textPrimary,
            ),
          ),
          Text(
            subtext,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Utility widgets
  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: CaretakerColors.errorRed, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: CaretakerColors.cardWhite,
      borderRadius: CaretakerLayout.cardRadius,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: CaretakerColors.cardWhite,
      floating: true,
      pinned: true,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: CaretakerColors.lightGreen,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            "EC",
            style: TextStyle(
              color: CaretakerColors.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Overview", style: CaretakerTextStyles.header),
          Text(
            "Caretaker Dashboard",
            style: CaretakerTextStyles.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none,
            color: CaretakerColors.textPrimary,
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: CaretakerColors.errorRed),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: CaretakerTextStyles.sectionTitle);
  }

  Widget _buildQuickAccessGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildNavCard(
          context,
          "Safety Monitor",
          Icons.security,
          Colors.red.shade100,
          Colors.red,
          const SafetyMonitorScreen(),
        ),
        _buildNavCard(
          context,
          "Medication",
          Icons.medical_services,
          Colors.blue.shade100,
          Colors.blue,
          const MedicationScreen(),
        ),
        _buildNavCard(
          context,
          "Care Connect",
          Icons.people,
          Colors.purple.shade100,
          Colors.purple,
          const VisionGuardianScreen(),
        ),
        _buildNavCard(
          context,
          "Activity Log",
          Icons.history,
          Colors.orange.shade100,
          Colors.orange,
          const BuddyActivityLogScreen(),
        ),
      ],
    );
  }

  Widget _buildNavCard(
    BuildContext context,
    String title,
    IconData icon,
    Color bg,
    Color iconColor,
    Widget screen,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        decoration: BoxDecoration(
          color: CaretakerColors.cardWhite,
          borderRadius: CaretakerLayout.cardRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(height: 8),
            Text(title, style: CaretakerTextStyles.cardTitle),
          ],
        ),
      ),
    );
  }
}
