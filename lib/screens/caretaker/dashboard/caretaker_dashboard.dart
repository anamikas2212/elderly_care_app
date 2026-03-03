import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/caretaker_theme.dart';
import '../../../services/caretaker_data_service.dart';
import 'cognitive_health_screen.dart';
import 'safety_monitor_screen.dart';
import 'medication_screen.dart';
import 'medication_management_screen.dart';
import 'buddy_activity_log_screen.dart';
import 'connect_screens.dart';
import '../../auth/login_screen.dart';
import 'enhanced_buddy_activity_screen.dart';
// Added: analytics screen imports
import '../analytics/flip_card_analytics_screen.dart';
import '../analytics/color_tap_analytics_screen.dart';
import '../analytics/city_atlas_analytics_screen.dart';
import '../analytics/event_ordering_analytics_screen.dart';
import '../analytics/daily_routine_analytics_screen.dart';
import '../analytics/monument_recall_analytics_screen.dart';

class CaretakerDashboard extends StatefulWidget {
  const CaretakerDashboard({Key? key}) : super(key: key);

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  final CaretakerDataService _dataService = CaretakerDataService();

  // Added: separate uid vs display fields
  String elderlyUserId = "";
  String elderlyUserName = "";
  String elderlyUserAge = "--";
  String elderlyUserGender = "--";

  // kept for backwards compat with existing widgets that used these names
  String get elderlyName => elderlyUserName;
  String get age => elderlyUserAge;
  String get gender => elderlyUserGender;

  bool _isLoading = true;
  String? _errorMessage;

  // Added: cached cognitive health future
  Future<Map<String, dynamic>>? _cognitiveHealthFuture;

  @override
  void initState() {
    super.initState();
    _loadElderlyUserId();
  }

  // Added: robust loader using UID
  Future<void> _loadElderlyUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid =
          prefs.getString('elderly_user_uid') ??
          prefs.getString('elderly_user_id') ??
          prefs.getString('elderly_user_name');
      final name = prefs.getString('elderly_user_name') ?? uid ?? '';
      final loadedAge = prefs.getString('elderly_user_age') ?? '--';
      final loadedGender = prefs.getString('elderly_user_gender') ?? '--';

      if (uid == null || uid.isEmpty) {
        setState(() {
          _errorMessage = "No elderly user linked. Please set up a connection.";
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        elderlyUserId = uid;
        elderlyUserName = name;
        elderlyUserAge = loadedAge;
        elderlyUserGender = loadedGender;
        _cognitiveHealthFuture = _dataService.getCognitiveHealthFuture(uid);
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

  // Added: create test medication alert
  Future<void> _createTestMedicationAlert() async {
    if (elderlyUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user ID loaded yet')));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('alerts').add({
        'userId': elderlyUserId,
        'isActive': true,
        'type': 'warning',
        'title': 'Missed Evening Medication',
        'message': 'Blood pressure pill overdue by 2 hours',
        'actionText': 'View',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Test medication alert created'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error creating alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Added: dismiss alert
  Future<void> _dismissAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update(
        {'isActive': false},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert dismissed'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error dismissing alert: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Added: loading and error states
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
                const Icon(
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
                  onPressed: _loadElderlyUserId,
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
                _buildAlertBanner(context), // Added: Firestore-driven alerts
                const SizedBox(height: 16),
                _buildCognitiveHealthCard(), // Added
                const SizedBox(height: 16),
                _buildGameMetricsCard(), // Added
                const SizedBox(height: 16),
                _buildStatsCardsRow(context),
                const SizedBox(height: 16),
                _buildRecentActivityCard(), // Added
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

  // ── App Bar ───────────────────────────────────────────────────────────────

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
          onPressed: () {
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

  // ── Patient Header Card ───────────────────────────────────────────────────

  Widget _buildPatientHeaderCard(BuildContext context) {
    final name = elderlyUserName.isNotEmpty ? elderlyUserName : elderlyUserId;
    const status = 'Active';
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
                    const Icon(Icons.home, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      "Home",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Text(
              status,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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

  // ── Alert Banner (Firestore-driven) ───────────────────────────────────────

  Widget _buildAlertBanner(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('alerts')
              .where('userId', isEqualTo: elderlyUserId)
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(3)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children:
              snapshot.data!.docs.map((doc) {
                final alert = doc.data() as Map<String, dynamic>;
                final alertId = doc.id;
                final title = alert['title'] as String? ?? 'Alert';
                final message = alert['message'] as String? ?? '';
                final type = alert['type'] as String? ?? 'warning';
                final actionText = alert['actionText'] as String? ?? 'View';

                final alertColor = _getAlertColor(type);
                final alertBgColor = alertColor.withOpacity(0.1);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: alertColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _dismissAlert(alertId),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: alertColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(actionText),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.error_outline;
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'critical':
        return CaretakerColors.errorRed;
      case 'info':
        return CaretakerColors.primaryGreen;
      default:
        return CaretakerColors.warningAmber;
    }
  }

  // ── Cognitive Health Card (Added) ─────────────────────────────────────────

  Widget _buildCognitiveHealthCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _cognitiveHealthFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Calculating cognitive health...");
        }
        if (snapshot.hasError) {
          return _buildErrorCard("Error: ${snapshot.error}");
        }

        final data = snapshot.data ?? {};
        final score = data['overallScore'] as int? ?? 0;
        final Color scoreColor =
            score >= 75
                ? Colors.green
                : score >= 50
                ? Colors.orange
                : Colors.red;
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
                      status,
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
              Center(
                child: Column(
                  children: [
                    Stack(
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
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Overall Score',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Domain Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDomainBar("Memory", data['memory'] ?? 0, Colors.purple),
              _buildDomainBar("Attention", data['attention'] ?? 0, Colors.blue),
              _buildDomainBar(
                "Processing Speed",
                data['processingSpeed'] ?? 0,
                Colors.orange,
              ),
              _buildDomainBar(
                "Executive Function",
                data['executiveFunction'] ?? 0,
                Colors.teal,
              ),
              _buildDomainBar("Language", data['language'] ?? 0, Colors.pink),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDomainBar(String label, int score, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.grey.shade100,
                color: color,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Game Metrics Card (Added) ─────────────────────────────────────────────

  Widget _buildGameMetricsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Game Analytics', style: CaretakerTextStyles.sectionTitle),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildGameCard(
                'Color Tap',
                'Focus & Speed',
                Icons.touch_app,
                Colors.blue,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ColorTapAnalyticsScreen(userId: elderlyUserId),
                    ),
                  );
                },
              ),
              _buildGameCard(
                'Flip Card',
                'Memory & Focus',
                Icons.flip,
                Colors.purple,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => FlipCardAnalyticsScreen(userId: elderlyUserId),
                    ),
                  );
                },
              ),
              _buildGameCard(
                'City Atlas',
                'Geography & Logic',
                Icons.map,
                Colors.teal,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              CityAtlasAnalyticsScreen(userId: elderlyUserId),
                    ),
                  );
                },
              ),
              _buildGameCard(
                'Event Order',
                'History & Sequencing',
                Icons.history_edu,
                Colors.orange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => EventOrderingAnalyticsScreen(
                            userId: elderlyUserId,
                          ),
                    ),
                  );
                },
              ),
              _buildGameCard(
                'Routine Recall',
                'Daily Memory',
                Icons.schedule,
                Colors.green,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => DailyRoutineAnalyticsScreen(
                            userId: elderlyUserId,
                          ),
                    ),
                  );
                },
              ),
              _buildGameCard(
                'Monuments',
                'Visual Memory',
                Icons.account_balance,
                Colors.indigo,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => MonumentRecallAnalyticsScreen(
                            userId: elderlyUserId,
                          ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent Activity Card (Added) ──────────────────────────────────────────

  Widget _buildRecentActivityCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dataService.getGameSessionHistory(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading activity...");
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyCard("No recent activity");
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
              ...sessions.take(5).map((s) => _buildActivityItem(s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> session) {
    final gameType = session['gameType'] as String? ?? 'Game';
    final score = session['score'] as int? ?? 0;
    final timestamp = session['createdAt'] as int? ?? 0;
    final timeAgo = _getTimeAgo(timestamp);

    IconData icon;
    Color color;
    String subtitle;

    switch (gameType) {
      case 'Color Tap':
        icon = Icons.touch_app;
        color = Colors.blue;
        final correct = session['correct_taps'] as int? ?? 0;
        final wrong = session['false_taps'] as int? ?? 0;
        final denom = correct + wrong;
        final acc = denom > 0 ? (correct / denom * 100).toInt() : 0;
        subtitle =
            'Accuracy: $acc%  •  Reaction: ${((session['average_reaction_time'] as double? ?? 0.0)).toStringAsFixed(2)}s';
        break;
      case 'Flip Card':
        icon = Icons.flip;
        color = Colors.purple;
        final eff = ((session['efficiency'] as double? ?? 0.0) * 100).toInt();
        subtitle = 'Efficiency: $eff%';
        break;
      case 'City Atlas':
        icon = Icons.map;
        color = Colors.teal;
        final cognitive =
            session['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        subtitle =
            'Exec: ${cognitive['executive_function'] ?? '-'}  •  Mem: ${cognitive['memory'] ?? '-'}';
        break;
      case 'Event Ordering':
        icon = Icons.history_edu;
        color = Colors.orange;
        final metrics = session['metrics'] as Map<String, dynamic>? ?? {};
        final seqAcc =
            ((metrics['sequence_accuracy'] as num? ?? 0) * 100).toInt();
        subtitle = 'Sequence Accuracy: $seqAcc%';
        break;
      case 'Routine Recall':
        icon = Icons.schedule;
        color = Colors.green;
        final metrics = session['metrics'] as Map<String, dynamic>? ?? {};
        final comp = ((metrics['completeness'] as num? ?? 0) * 100).toInt();
        subtitle = 'Completeness: $comp%';
        break;
      case 'Monument Recall':
        icon = Icons.account_balance;
        color = Colors.indigo;
        final cognitive =
            session['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        subtitle =
            'Memory: ${cognitive['memory'] ?? '-'}  •  Language: ${cognitive['language'] ?? '-'}';
        break;
      default:
        icon = Icons.sports_esports;
        color = Colors.grey;
        subtitle = 'Score: $score';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gameType,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$score pts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(int timestamp) {
    if (timestamp == 0) return 'Unknown';
    final now = DateTime.now().millisecondsSinceEpoch;
    final seconds = (now - timestamp) ~/ 1000;
    if (seconds < 60) return '${seconds}s ago';
    if (seconds < 3600) return '${seconds ~/ 60}m ago';
    if (seconds < 86400) return '${seconds ~/ 3600}h ago';
    return '${seconds ~/ 86400}d ago';
  }

  // ── Stats Cards Row ───────────────────────────────────────────────────────

  Widget _buildStatsCardsRow(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.getOverallStatistics(elderlyUserId),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final totalGames = stats['totalGames'] as int? ?? 0;
        final adherence = stats['medicationAdherence'] as int? ?? 0;

        return Row(
          children: [
            Expanded(
              child: _buildSmallStatCard(
                title: "Total Games",
                value: "$totalGames",
                subtext: "Total played",
                icon: Icons.videogame_asset,
                color: CaretakerColors.highlightBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallStatCard(
                title: "Meds",
                value: "$adherence%",
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
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: CaretakerTextStyles.caption),
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
            style: const TextStyle(
              fontSize: 11,
              color: CaretakerColors.successGreen,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Access Grid ─────────────────────────────────────────────────────

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
          _buildEnhancedBuddyScreen(context),
        ),
        // Added: Test Alert button
        _buildNavCard(
          context,
          "Test Alert",
          Icons.notification_important,
          Colors.amber.shade100,
          Colors.orange,
          const SizedBox(), // placeholder — onTap overridden via GestureDetector below
        ),
      ],
    );
  }

  // Kept from your original
  Widget _buildEnhancedBuddyScreen(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getElderlyInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final info = snapshot.data!;
        return EnhancedBuddyActivityScreen(
          caretakerId: info['caretakerId'] ?? '',
          elderlyId: info['elderlyId'] ?? '',
          elderlyName: info['elderlyName'] ?? 'Patient',
        );
      },
    );
  }

  Future<Map<String, String>> _getElderlyInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'caretakerId': prefs.getString('caretaker_id') ?? 'caretaker_demo_id',
      'elderlyId': prefs.getString('elderly_user_id') ?? 'elderly_demo_id',
      'elderlyName': prefs.getString('elderly_user_name') ?? 'Patient',
    };
  }

  Widget _buildNavCard(
    BuildContext context,
    String title,
    IconData icon,
    Color bg,
    Color iconColor,
    Widget screen,
  ) {
    // Special case: Test Alert triggers a function instead of navigation
    if (title == "Test Alert") {
      return GestureDetector(
        onTap: _createTestMedicationAlert,
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

  // ── Section Title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(title, style: CaretakerTextStyles.sectionTitle);
  }

  // ── Card Helpers ──────────────────────────────────────────────────────────

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: CaretakerLayout.cardRadius,
      boxShadow: CaretakerLayout.cardShadow,
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Center(
        child: Text(error, style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

/*import'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/caretaker_theme.dart';
import '../../../services/caretaker_data_service.dart';
import 'cognitive_health_screen.dart';
import 'safety_monitor_screen.dart';
import 'medication_screen.dart';
import 'medication_management_screen.dart';
import 'buddy_activity_log_screen.dart';
import 'connect_screens.dart';
import '../../auth/login_screen.dart';
import '../analytics/flip_card_analytics_screen.dart';
import '../analytics/color_tap_analytics_screen.dart';
import '../analytics/city_atlas_analytics_screen.dart';
import '../analytics/event_ordering_analytics_screen.dart';
import '../analytics/daily_routine_analytics_screen.dart';
import '../analytics/monument_recall_analytics_screen.dart';

class CaretakerDashboard extends StatefulWidget {
  const CaretakerDashboard({Key? key}) : super(key: key);

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  final CaretakerDataService _dataService = CaretakerDataService();
  String elderlyUserId = "";      // Firebase UID used for Firestore queries
  String elderlyUserName = "";    // Display name from SharedPreferences
  String elderlyUserAge = "--";   // Age from SharedPreferences
  String elderlyUserGender = "--"; // Gender from SharedPreferences
  bool _isLoading = true;
  String? _errorMessage;
  // Cached future so cognitive score doesn't reset on every rebuild/navigation
  Future<Map<String, dynamic>>? _cognitiveHealthFuture;

  @override
  void initState() {
    super.initState();
    _loadElderlyUserId();
  }

  Future<void> _loadElderlyUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try to get Firebase UID first (set after our fix), fall back to name
      final uid = prefs.getString('elderly_user_uid') ??
                  prefs.getString('elderly_user_id') ??
                  prefs.getString('elderly_user_name');
      final name = prefs.getString('elderly_user_name') ?? uid ?? '';
      final age = prefs.getString('elderly_user_age') ?? '--';
      final gender = prefs.getString('elderly_user_gender') ?? '--';

      if (uid == null || uid.isEmpty) {
        setState(() {
          _errorMessage = "No elderly user linked. Please set up a connection.";
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        elderlyUserId = uid;
        elderlyUserName = name;
        elderlyUserAge = age;
        elderlyUserGender = gender;
        // Cache the future once so it persists across rebuilds
        _cognitiveHealthFuture = _dataService.getCognitiveHealthFuture(uid);
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

  // âœ… NEW: Create a test medication alert
  Future<void> _createTestMedicationAlert() async {
    if (elderlyUserId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user ID loaded yet')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('alerts').add({
        'userId': elderlyUserId,
        'isActive': true,
        'type': 'warning', // Options: 'critical', 'warning', 'info'
        'title': 'Missed Evening Medication',
        'message': 'Blood pressure pill overdue by 2 hours',
        'actionText': 'View',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('âœ… Test medication alert created'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('âŒ Error creating alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // âœ… NEW: Dismiss an alert
  Future<void> _dismissAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance.collection('alerts').doc(alertId).update(
        {'isActive': false},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alert dismissed'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error dismissing alert: $e');
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

                // âœ… Alert Banner - Shows medication reminders and other alerts
                _buildAlertBanner(context),
                const SizedBox(height: 16),

                // Cognitive Health Score Card
                _buildCognitiveHealthCard(),
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _cognitiveHealthFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Calculating cognitive health...");
        }

        if (snapshot.hasError) {
          return _buildErrorCard("Error: ${snapshot.error}");
        }

        final data = snapshot.data ?? {};
        final score = data['overallScore'] as int? ?? 0;
        
        final Color scoreColor = score >= 75 ? Colors.green : score >= 50 ? Colors.orange : Colors.red;
        final String status = score >= 75 ? 'Excellent' : score >= 50 ? 'Good' : 'Needs Attention';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cognitive Health Score', style: CaretakerTextStyles.cardTitle),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scoreColor),
                    ),
                    child: Text(status, style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Score Circle
              Center(
                child: Column(
                  children: [
                     Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 120, width: 120,
                          child: CircularProgressIndicator(
                            value: score / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade200,
                            color: scoreColor,
                          ),
                        ),
                        Text('$score', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: scoreColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Overall Score', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Text('Domain Breakdown', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // 5 Domains
              _buildDomainBar("Memory", data['memory'] ?? 0, Colors.purple),
              _buildDomainBar("Attention", data['attention'] ?? 0, Colors.blue),
              _buildDomainBar("Processing Speed", data['processingSpeed'] ?? 0, Colors.orange),
              _buildDomainBar("Executive Function", data['executiveFunction'] ?? 0, Colors.teal),
              _buildDomainBar("Language", data['language'] ?? 0, Colors.pink),
            ],
          ),
        );
      },
    );
  }

  
  Widget _buildDomainBar(String label, int score, Color color) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
              children: [
                  SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13))),
                  Expanded(
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                              value: score / 100,
                              backgroundColor: Colors.grey.shade100,
                              color: color,
                              minHeight: 8,
                          ),
                      ),
                  ),
                  const SizedBox(width: 10),
                  Text('$score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              ],
          ),
      );
  }

  // âœ… Game Analytics Cards
  Widget _buildGameMetricsCard() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text('Game Analytics', style: CaretakerTextStyles.sectionTitle),
            const SizedBox(height: 12),
            SizedBox(
                height: 160,
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                        _buildGameCard(
                            'Color Tap', 
                            'Focus & Speed', 
                            Icons.touch_app, 
                            Colors.blue,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ColorTapAnalyticsScreen(userId: elderlyUserId))),
                        ),
                        _buildGameCard(
                            'Flip Card', 
                            'Memory & Focus', 
                            Icons.flip, 
                            Colors.purple,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => FlipCardAnalyticsScreen(userId: elderlyUserId))),
                        ),
                        _buildGameCard(
                            'City Atlas', 
                            'Geography & Logic', 
                            Icons.map, 
                            Colors.teal,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityAtlasAnalyticsScreen(userId: elderlyUserId))),
                        ),
                        _buildGameCard(
                            'Event Order', 
                            'History & Sequencing', 
                            Icons.history_edu, 
                            Colors.orange,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventOrderingAnalyticsScreen(userId: elderlyUserId))),
                        ),
                        _buildGameCard(
                            'Routine Recall', 
                            'Daily Memory', 
                            Icons.schedule, 
                            Colors.green,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyRoutineAnalyticsScreen(userId: elderlyUserId))),
                        ),
                        _buildGameCard(
                            'Monuments', 
                            'Visual Memory', 
                            Icons.account_balance, 
                            Colors.indigo,
                            () => Navigator.push(context, MaterialPageRoute(builder: (_) => MonumentRecallAnalyticsScreen(userId: elderlyUserId))),
                        ),
                    ],
                ),
            ),
        ],
    );
  }
  
  Widget _buildGameCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
      return Container(
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          child: GestureDetector(
              onTap: onTap,
              child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  ),
                              child: Icon(icon, color: color, size: 24),
                          ),
                          const Spacer(),
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                  ),
              ),
          ),
      );
  }
  
  // ✅ Recent Activity Card — shows ALL game types
  Widget _buildRecentActivityCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dataService.getGameSessionHistory(elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading activity...");
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyCard("No recent activity");
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
                  const Text('Recent Activity', style: CaretakerTextStyles.cardTitle),
                  Text('${sessions.length} sessions',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 16),
              ...sessions.take(5).map((session) => _buildActivityItem(session)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> session) {
    final gameType = session['gameType'] as String? ?? 'Game';
    final score = session['score'] as int? ?? 0;
    final timestamp = session['createdAt'] as int? ?? 0;
    final timeAgo = _getTimeAgo(timestamp);

    // Pick icon + color based on game type
    IconData icon;
    Color color;
    String subtitle;

    switch (gameType) {
      case 'Color Tap':
        icon = Icons.touch_app;
        color = Colors.blue;
        final correct = session['correct_taps'] as int? ?? 0;
        final wrong = session['false_taps'] as int? ?? 0;
        final denom = correct + wrong;
        final acc = denom > 0 ? (correct / denom * 100).toInt() : 0;
        subtitle = 'Accuracy: $acc%  •  Reaction: ${((session['average_reaction_time'] as double? ?? 0.0)).toStringAsFixed(2)}s';
        break;
      case 'Flip Card':
        icon = Icons.flip;
        color = Colors.purple;
        final eff = ((session['efficiency'] as double? ?? 0.0) * 100).toInt();
        subtitle = 'Efficiency: $eff%';
        break;
      case 'City Atlas':
        icon = Icons.map;
        color = Colors.teal;
        final cognitive = session['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        subtitle = 'Exec: ${cognitive['executive_function'] ?? '-'}  •  Mem: ${cognitive['memory'] ?? '-'}';
        break;
      case 'Event Ordering':
        icon = Icons.history_edu;
        color = Colors.orange;
        final metrics = session['metrics'] as Map<String, dynamic>? ?? {};
        final seqAcc = ((metrics['sequence_accuracy'] as num? ?? 0) * 100).toInt();
        subtitle = 'Sequence Accuracy: $seqAcc%';
        break;
      case 'Routine Recall':
        icon = Icons.schedule;
        color = Colors.green;
        final metrics = session['metrics'] as Map<String, dynamic>? ?? {};
        final comp = ((metrics['completeness'] as num? ?? 0) * 100).toInt();
        subtitle = 'Completeness: $comp%';
        break;
      case 'Monument Recall':
        icon = Icons.account_balance;
        color = Colors.indigo;
        final cognitive = session['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        subtitle = 'Memory: ${cognitive['memory'] ?? '-'}  •  Language: ${cognitive['language'] ?? '-'}';
        break;
      default:
        icon = Icons.sports_esports;
        color = Colors.grey;
        subtitle = 'Score: $score';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gameType,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(timeAgo,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$score pts',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
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

  // ✅ Patient Header Card — reads from SharedPreferences state (no Firestore query needed)
  Widget _buildPatientHeaderCard(BuildContext context) {
    final name = elderlyUserName.isNotEmpty ? elderlyUserName : elderlyUserId;
    final age = elderlyUserAge;
    final gender = elderlyUserGender;
    const status = 'Active';
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
                  'Age $age • $gender',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.home, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: const Text(
              status,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
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

  // âœ… ENHANCED: Alert Banner - Now supports medication reminders and dismissal
  Widget _buildAlertBanner(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('alerts')
              .where('userId', isEqualTo: elderlyUserId)
              .where('isActive', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(3) // Show up to 3 alerts
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show all active alerts
        return Column(
          children:
              snapshot.data!.docs.map((doc) {
                final alert = doc.data() as Map<String, dynamic>;
                final alertId = doc.id;
                final title = alert['title'] as String? ?? 'Alert';
                final message = alert['message'] as String? ?? '';
                final type = alert['type'] as String? ?? 'warning';
                final actionText = alert['actionText'] as String? ?? 'View';

                final alertColor = _getAlertColor(type);
                final alertBgColor = _getAlertBackgroundColor(type);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: alertColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _dismissAlert(alertId),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: alertColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(actionText),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  IconData _getAlertIcon(String type) {
    switch (type) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.error_outline;
    }
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'critical':
        return CaretakerColors.errorRed;
      case 'info':
        return CaretakerColors.primaryGreen;
      default:
        return CaretakerColors.warningAmber;
    }
  }

  Color _getAlertBackgroundColor(String type) {
    return _getAlertColor(type).withValues(alpha: 0.1);
  }

  // âœ… Quick Access Grid
  Widget _buildQuickAccessGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildQuickAccessCard(
          context,
          'Safety Monitor',
          Icons.security,
          Colors.red,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SafetyMonitorScreen(),
            ),
          ),
        ),
        _buildQuickAccessCard(
          context,
          'Medication',
          Icons.medication,
          Colors.blue,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MedicationManagementScreen(),
            ),
          ),
        ),
        _buildQuickAccessCard(
          context,
          'Buddy Logs',
          Icons.chat_bubble,
          Colors.green,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BuddyActivityLogScreen(),
            ),
          ),
        ),
        // Test Alert Button (For Demo)
        _buildQuickAccessCard(
          context,
          'Test Alert',
          Icons.notification_important,
          Colors.orange,
          _createTestMedicationAlert,
        ),
      ],
    );
  }

  Widget _buildQuickAccessCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: CaretakerLayout.cardRadius,
          boxShadow: CaretakerLayout.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CaretakerColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // âœ… Stats Cards Row (Total Games & Adherence)
  Widget _buildStatsCardsRow(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.getOverallStatistics(elderlyUserId),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {};
        final totalGames = stats['totalGames'] as int? ?? 0;
        final adherence = stats['medicationAdherence'] as int? ?? 0;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Total Games',
                '$totalGames',
                Icons.games,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                'Medication',
                '$adherence%',
                Icons.medical_services,
                Colors.blue,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: CaretakerLayout.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: CaretakerColors.background,
      elevation: 0,
      floating: true,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Caretaker Dashboard',
            style: TextStyle(
              color: CaretakerColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Monitoring & Care',
            style: TextStyle(color: CaretakerColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.black),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.red),
          // Sign out
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: CaretakerColors.textPrimary,
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: CaretakerLayout.cardRadius,
      boxShadow: CaretakerLayout.cardShadow,
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Center(
        child: Text(error, style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          width: double.infinity,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(Icons.inbox, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(message, style: TextStyle(color: Colors.grey.shade500)),
              ],
          ),
      );
  }
}

*/
