import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/caretaker_id_helper.dart';
import '../../../services/caretaker_notification_service.dart';
import '../../../theme/caretaker_theme.dart';
import '../../../services/caretaker_data_service.dart';
import 'cognitive_health_screen.dart';
import 'safety_monitor_screen.dart';
import 'medication_management_screen.dart';
import 'buddy_activity_log_screen.dart';
import 'connect_screens.dart';
import 'patient_overview_screen.dart';
import '../../auth/login_screen.dart';
import 'enhanced_buddy_activity_screen.dart';
import '../reports/ai_cognitive_reports_screen.dart';
// Analytics screen imports
import '../analytics/flip_card_analytics_screen.dart';
import '../analytics/color_tap_analytics_screen.dart';
import '../analytics/city_atlas_analytics_screen.dart';
import '../analytics/event_ordering_analytics_screen.dart';
import '../analytics/daily_routine_analytics_screen.dart';
import '../analytics/monument_recall_analytics_screen.dart';

class CaretakerDashboard extends StatefulWidget {
  final String? elderlyUserId;
  const CaretakerDashboard({Key? key, this.elderlyUserId}) : super(key: key);

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  final CaretakerDataService _dataService = CaretakerDataService();
  final CaretakerNotificationService _notificationService =
      CaretakerNotificationService();

  String elderlyUserId = "";
  String elderlyUserUid = "";
  String elderlyUserName = "";
  String elderlyUserAge = "--";
  String elderlyUserGender = "--";
  String caretakerId = "";

  bool _isLoading = true;
  String? _errorMessage;

  // Cached futures so they don't reset on every rebuild
  Future<Map<String, dynamic>>? _cognitiveHealthFuture;
  Future<List<Map<String, dynamic>>>? _recentActivityFuture;
  Future<Map<String, dynamic>>? _overallStatsFuture;

  @override
  void initState() {
    super.initState();
    _loadElderlyUserId();
  }

  Future<void> _loadElderlyUserId() async {
    try {
      String? uid = widget.elderlyUserId;
      String name = '';
      String loadedAge = '--';
      String loadedGender = '--';
      String dataId = ''; // The ID used by SessionTracker for game data
      String? storedUid;

      if (uid != null && uid.isNotEmpty) {
        // UID passed from PatientSelectionScreen → fetch profile from Firestore
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          if (doc.exists) {
            final data = doc.data()!;
            name = data['name'] ?? uid;
            loadedAge = data['age'] ?? '--';
            loadedGender = data['gender'] ?? '--';
          } else {
            name = uid;
          }
        } catch (_) {
          name = uid;
        }

        // The SessionTracker stores game data using the NAME as userId,
        // not the Firebase UID. So we use the name for data queries.
        // Also check if a name-based user doc exists (old format) with richer data.
        dataId = name;
        if (name.isNotEmpty && name != uid) {
          try {
            final nameDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(name)
                .get();
            if (nameDoc.exists) {
              final nameData = nameDoc.data()!;
              // Use name-based doc for age/gender if UID doc didn't have them
              if (loadedAge == '--') loadedAge = nameData['age'] ?? '--';
              if (loadedGender == '--') loadedGender = nameData['gender'] ?? '--';
            }
          } catch (_) {}
        }
      } else {
        // Fallback: read from SharedPreferences (backwards compatibility)
        final prefs = await SharedPreferences.getInstance();
        storedUid =
            prefs.getString('elderly_user_uid') ??
            prefs.getString('elderly_user_id');
        uid = storedUid ?? prefs.getString('elderly_user_name');
        name = prefs.getString('elderly_user_name') ?? uid ?? '';
        loadedAge = prefs.getString('elderly_user_age') ?? '--';
        loadedGender = prefs.getString('elderly_user_gender') ?? '--';
        dataId = name.isNotEmpty ? name : (uid ?? '');
      }

      if (dataId.isEmpty) dataId = uid ?? name;

      final cId = await CaretakerIdHelper.getCurrentCaretakerId() ?? '';

      if (uid == null || uid.isEmpty || cId.isEmpty) {
        setState(() {
          _errorMessage = "Identity error. Please log in again.";
          _isLoading = false;
        });
        return;
      }

      // Ensure elderly profile is linked to the current caretaker UID.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'caretakerId': cId}, SetOptions(merge: true));
        if (name.isNotEmpty && name != uid) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(name)
              .set({'caretakerId': cId}, SetOptions(merge: true));
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        elderlyUserId = dataId; // Use name-based ID for data queries
        elderlyUserUid = storedUid ?? uid ?? '';
        elderlyUserName = name;
        elderlyUserAge = loadedAge;
        elderlyUserGender = loadedGender;
        caretakerId = cId;
        _cognitiveHealthFuture = _dataService.getCognitiveHealthFuture(dataId);
        _recentActivityFuture = _dataService.getRecentActivityFuture(dataId);
        _overallStatsFuture = _dataService.getOverallStatisticsFuture(dataId);
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



  // ── Build ─────────────────────────────────────────────────────────────────

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
                const SizedBox(height: 12),
                _buildPatientOverviewBanner(context),
                const SizedBox(height: 16),
                _buildCognitiveHealthCard(),
                const SizedBox(height: 16),
                _buildGameAnalyticsSection(),
                const SizedBox(height: 16),
                _buildStatsCardsRow(context),
                const SizedBox(height: 16),
                _buildRecentActivityCard(),
                const SizedBox(height: 16),
                _buildBuddyAlertsCard(),
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
            "Caregiver Dashboard",
            style: CaretakerTextStyles.caption.copyWith(fontSize: 12),
          ),
        ],
      ),
      actions: [
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

  // ── Patient Header Card (uses getUserProfile stream from File 2) ──────────

  Widget _buildPatientHeaderCard(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.getUserProfile(elderlyUserId),
      builder: (context, snapshot) {
        String name = elderlyUserName.isNotEmpty ? elderlyUserName : elderlyUserId;
        String age = elderlyUserAge;
        String gender = elderlyUserGender;
        String location = "Home";
        String lastActive = "";
        String status = "Active";

        if (snapshot.hasData && snapshot.data != null) {
          final profile = snapshot.data!;
          name = profile['name'] as String? ?? name;
          age = profile['age']?.toString() ?? age;
          gender = profile['gender'] as String? ?? gender;
          location = profile['location'] as String? ?? location;
          lastActive = profile['lastActive'] as String? ?? "";
          status = profile['status'] as String? ?? status;
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
                        const Icon(Icons.location_on, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            lastActive.isNotEmpty
                                ? "$location • $lastActive"
                                : location,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  // ── Patient Overview Banner ───────────────────────────────────────────────

  Widget _buildPatientOverviewBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientOverviewScreen(
            elderlyUid: elderlyUserUid,
            elderlyId: elderlyUserId,
            elderlyName: elderlyUserName,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: CaretakerColors.cardWhite,
          borderRadius: CaretakerLayout.cardRadius,
          border: Border.all(
            color: CaretakerColors.primaryGreen.withOpacity(0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CaretakerColors.lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_search,
                color: CaretakerColors.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patient Overview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: CaretakerColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Medical history, conditions, emergency contact & notes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  // ── Cognitive Health Score Card ───────────────────────────────────────────

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
        if (!snapshot.hasData || snapshot.data == null) {
          return _buildEmptyCard(
            "No game data yet. Play games to see your cognitive health score.",
          );
        }

        final data = snapshot.data!;
        final score = (data['overallScore'] as num?)?.toInt() ?? 0;

        final Color scoreColor =
            score >= 75 ? Colors.green : score >= 50 ? Colors.orange : Colors.red;
        final String statusEmoji =
            score >= 75 ? '🟢' : score >= 50 ? '🟡' : '🔴';
        final String status =
            score >= 75 ? 'Excellent' : score >= 50 ? 'Good' : 'Needs Attention';

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
              const SizedBox(height: 24),
              const Text(
                'Domain Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDomainBar("Memory", data['memory'], Colors.purple),
              _buildDomainBar("Attention", data['attention'], Colors.blue),
              _buildDomainBar(
                "Processing Speed",
                data['processingSpeed'],
                Colors.orange,
              ),
              _buildDomainBar(
                "Executive Function",
                data['executiveFunction'],
                Colors.teal,
              ),
              _buildDomainBar("Language", data['language'], Colors.pink),
            ],
          ),
        );
      },
    );
  }



  Widget _buildDomainBar(String label, dynamic rawScore, Color color) {
    final int score = (rawScore as num?)?.toInt() ?? 0;
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



  // ── Game Analytics Horizontal Scroll (File 1) ─────────────────────────────

  Widget _buildGameAnalyticsSection() {
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
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ColorTapAnalyticsScreen(userId: elderlyUserId),
                  ),
                ),
              ),
              _buildGameCard(
                'Flip Card',
                'Memory & Focus',
                Icons.flip,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FlipCardAnalyticsScreen(userId: elderlyUserId),
                  ),
                ),
              ),
              _buildGameCard(
                'City Atlas',
                'Geography & Logic',
                Icons.map,
                Colors.teal,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CityAtlasAnalyticsScreen(userId: elderlyUserId),
                  ),
                ),
              ),
              _buildGameCard(
                'Event Order',
                'History & Sequencing',
                Icons.history_edu,
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EventOrderingAnalyticsScreen(userId: elderlyUserId),
                  ),
                ),
              ),
              _buildGameCard(
                'Routine Recall',
                'Daily Memory',
                Icons.schedule,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DailyRoutineAnalyticsScreen(userId: elderlyUserId),
                  ),
                ),
              ),
              _buildGameCard(
                'Monuments',
                'Visual Memory',
                Icons.account_balance,
                Colors.indigo,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MonumentRecallAnalyticsScreen(userId: elderlyUserId),
                  ),
                ),
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

  // ── Recent Activity Card (File 2 detailed + File 1 multi-game support) ────

  Widget _buildRecentActivityCard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recentActivityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading activity...");
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
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
              ...sessions.take(5).map((s) => _buildActivityItem(s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> session) {
    final gameType = session['gameType'] as String? ?? 'Game';
    final score = (session['score'] as num?)?.toInt() ?? 0;
    final timestamp = (session['createdAt'] as num?)?.toInt() ?? 0;
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
        final missed = session['missed_taps'] as int? ?? 0;
        final denom = correct + wrong;
        final acc = denom > 0 ? (correct / denom * 100).toInt() : 0;
        final rt = session['average_reaction_time'] as double? ?? 0.0;
        subtitle =
            'Accuracy: $acc%  •  Reaction: ${rt.toStringAsFixed(2)}s  •  Missed: $missed';
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
        final cog = session['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        subtitle =
            'Exec: ${cog['executive_function'] ?? '-'}  •  Mem: ${cog['memory'] ?? '-'}';
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
        final cog = session['cognitive_contributions'] as Map<String, dynamic>? ?? {};
        subtitle =
            'Memory: ${cog['memory'] ?? '-'}  •  Language: ${cog['language'] ?? '-'}';
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _overallStatsFuture,
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
        final stats = snapshot.data ?? {};
        final totalGames = (stats['totalGames'] as num?)?.toInt() ?? 0;

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
                value: "--",
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
          MedicationManagementScreen(userId: elderlyUserId),
        ),/*
        _buildNavCard(
          context,
          "Care Connect",
          Icons.people,
          Colors.purple.shade100,
          Colors.purple,
          const VisionGuardianScreen(),
        ),*/

        // Enhanced buddy activity screen
        GestureDetector(
          onTap: () async {
            final screen = await _buildEnhancedBuddyScreen();
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => screen),
            );
          },
          child: _buildNavCardContent(
            "Buddy Activity",
            Icons.people_alt,
            Colors.teal.shade100,
            Colors.teal,
          ),
        ),

        _buildNavCard(
          context,
          "AI Reports",
          Icons.auto_awesome,
          Colors.amber.shade100,
          Colors.amber.shade700,
          AiCognitiveReportsScreen(
            caretakerId: caretakerId,
            elderlyId: elderlyUserId,
            elderlyName: elderlyUserName,
          ),
        ),

        _buildNavCard(
          context,
          "Patient Overview",
          Icons.person_search,
          Colors.green.shade100,
          Colors.green.shade700,
          PatientOverviewScreen(
            elderlyUid: elderlyUserUid,
            elderlyId: elderlyUserId,
            elderlyName: elderlyUserName,
          ),
        ),

      ],
    );
  }

  Future<Widget> _buildEnhancedBuddyScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final fallbackElderlyId =
        prefs.getString('elderly_user_uid') ??
        prefs.getString('elderly_user_id') ??
        elderlyUserId;
    return EnhancedBuddyActivityScreen(
      caretakerId: await CaretakerIdHelper.getCurrentCaretakerId() ?? caretakerId,
      elderlyId: elderlyUserUid.isNotEmpty ? elderlyUserUid : fallbackElderlyId,
      elderlyName: prefs.getString('elderly_user_name') ?? elderlyUserName,
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
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: _buildNavCardContent(title, icon, bg, iconColor),
    );
  }

  Widget _buildNavCardContent(
    String title,
    IconData icon,
    Color bg,
    Color iconColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
    );
  }

  // ── Section Title ─────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(title, style: CaretakerTextStyles.sectionTitle);
  }

  // ── Buddy Alerts Summary ──────────────────────────────────────────────────

  Widget _buildBuddyAlertsCard() {
    if (caretakerId.isEmpty) {
      return _buildEmptyCard("No caretaker linked for alerts.");
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _notificationService.getNotificationsStream(caretakerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading buddy alerts...");
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyCard(
            "No buddy alerts yet. Alerts will appear here when attention is needed.",
          );
        }

        final notifications = snapshot.data!.docs;
        final unreadCount = notifications.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['isRead'] != true;
        }).length;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: _buildCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Buddy Alerts', style: CaretakerTextStyles.cardTitle),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        '$unreadCount unread',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ...notifications.take(3).map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildBuddyAlertItem(data);
              }),
              if (notifications.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Open Buddy Activity to view all alerts.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBuddyAlertItem(Map<String, dynamic> notification) {
    final severity = notification['severity'] ?? 'info';
    final title = notification['title'] ?? 'Alert';
    final message = notification['message'] ?? '';
    final timestamp = notification['createdAt'] as Timestamp?;

    IconData icon;
    Color color;
    switch (severity) {
      case 'urgent':
        icon = Icons.warning;
        color = Colors.red;
        break;
      case 'moderate':
        icon = Icons.info;
        color = Colors.orange;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatAlertTimestamp(timestamp),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _formatAlertTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }
    return '${dateTime.month}/${dateTime.day}';
  }

  // ── Card Helpers ──────────────────────────────────────────────────────────

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
          const Icon(Icons.error_outline, color: CaretakerColors.errorRed, size: 20),
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
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
