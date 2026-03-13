import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/caretaker_notification_service.dart';
import '../../../services/enhanced_memory_service.dart';
import '../../../services/report_scheduler_service.dart';
import '../../../config/app_config.dart';

class EnhancedBuddyActivityScreen extends StatefulWidget {
  final String caretakerId;
  final String elderlyId;
  final String elderlyName;

  const EnhancedBuddyActivityScreen({
    super.key,
    required this.caretakerId,
    required this.elderlyId,
    required this.elderlyName,
  });

  @override
  State<EnhancedBuddyActivityScreen> createState() =>
      _EnhancedBuddyActivityScreenState();
}

class _EnhancedBuddyActivityScreenState
    extends State<EnhancedBuddyActivityScreen>
    with SingleTickerProviderStateMixin {
  late CaretakerNotificationService _notificationService;
  late EnhancedMemoryService _memoryService;
  late TabController _tabController;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _notificationService = CaretakerNotificationService();
    _memoryService = EnhancedMemoryService(groqApiKey: AppConfig.groqApiKey);
    _tabController = TabController(length: 3, vsync: this);

    // Initialize notifications
    _notificationService.initializeForCaretaker(widget.caretakerId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.elderlyName}\'s Buddy Activity',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.blue[700],
          tabs: const [
            Tab(icon: Icon(Icons.notifications), text: 'Alerts'),
            Tab(icon: Icon(Icons.analytics), text: 'Reports'),
            Tab(icon: Icon(Icons.emoji_emotions), text: 'Wellness'),
          ],
        ),
        actions: [
          // Unread notification badge
          StreamBuilder<int>(
            stream: _notificationService.getUnreadNotificationCount(
              widget.caretakerId,
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAlertsTab(), _buildReportsTab(), _buildWellnessTab()],
      ),
    );
  }

  // Alerts Tab
  Widget _buildAlertsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationService.getNotificationsForElderlyStream(widget.elderlyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.notifications_none,
            title: 'No alerts yet',
            subtitle:
                'You\'ll be notified when ${widget.elderlyName} needs attention',
          );
        }

        final notifications = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notificationDoc = notifications[index];
            final notification = notificationDoc.data() as Map<String, dynamic>;
            final notificationId = notificationDoc.id;

            return _buildNotificationCard(notification, notificationId);
          },
        );
      },
    );
  }

  // Notification Card Widget
  Widget _buildNotificationCard(
    Map<String, dynamic> notification,
    String notificationId,
  ) {
    final isRead = notification['isRead'] ?? false;
    final severity = notification['severity'] ?? 'moderate';
    final type = notification['type'] ?? 'alert';
    final title = notification['title'] ?? 'Alert';
    final message = notification['message'] ?? '';
    final timestamp = notification['createdAt'] as Timestamp?;

    Color severityColor;
    IconData severityIcon;

    switch (severity) {
      case 'urgent':
        severityColor = Colors.red;
        severityIcon = Icons.warning;
        break;
      case 'moderate':
        severityColor = Colors.orange;
        severityIcon = Icons.info;
        break;
      default:
        severityColor = Colors.blue;
        severityIcon = Icons.notifications;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 1 : 3,
      color: isRead ? Colors.white : severityColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey[300]! : severityColor.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          _showNotificationDetails(notification, notificationId);
          if (!isRead) {
            _notificationService.markBuddyNotificationAsRead(widget.elderlyId, notificationId);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(severityIcon, color: severityColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      isRead
                                          ? FontWeight.w600
                                          : FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: severityColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        if (timestamp != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildActionChip(
                    label: 'View Details',
                    icon: Icons.visibility,
                    onTap:
                        () => _showNotificationDetails(
                          notification,
                          notificationId,
                        ),
                  ),
                  const SizedBox(width: 8),
                  if (severity == 'urgent')
                    _buildActionChip(
                      label: 'Mark Resolved',
                      icon: Icons.check_circle,
                      color: Colors.green,
                      onTap: () {
                        _notificationService.markBuddyNotificationAsResolved(
                          widget.elderlyId,
                          notificationId,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as resolved')),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Action Chip Widget
  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? Colors.blue;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: chipColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chipColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reports Tab
  Widget _buildReportsTab() {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _notificationService.getWeeklyReportsStream(
            widget.caretakerId,
            widget.elderlyId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(
                icon: Icons.analytics,
                title: 'No reports yet',
                subtitle:
                    'Tap the button below to generate reports from past conversations',
              );
            }

            final reports = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final reportDoc = reports[index];
                final report = reportDoc.data() as Map<String, dynamic>;
                final reportId = reportDoc.id;
                return _buildReportCard(report, reportId);
              },
            );
          },
        ),
        // FAB to manually generate reports
        Positioned(
          bottom: 24,
          right: 24,
          child:
              _isGenerating
                  ? const CircularProgressIndicator()
                  : FloatingActionButton.extended(
                    onPressed: _generateReportsNow,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Generate Reports'),
                    backgroundColor: Colors.blue[700],
                  ),
        ),
      ],
    );
  }

  Future<void> _generateReportsNow() async {
    setState(() => _isGenerating = true);
    try {
      final memoryService = EnhancedMemoryService(
        groqApiKey: AppConfig.groqApiKey,
      );

      // Get current week boundaries
      final now = DateTime.now();
      final daysSinceSunday = now.weekday % 7;
      final thisWeekStart = DateTime(
        now.year,
        now.month,
        now.day - daysSinceSunday,
      );

      // Try generating for the last 8 weeks
      int generated = 0;
      for (int w = 8; w >= 0; w--) {
        final weekStart = thisWeekStart.subtract(Duration(days: 7 * w));
        final weekEnd = weekStart.add(const Duration(days: 7));
        if (weekEnd.isAfter(DateTime.now().add(const Duration(days: 1))))
          continue;

        try {
          await memoryService.generateWeeklySentimentReportForPeriod(
            elderlyId: widget.elderlyId,
            periodStart: weekStart,
            periodEnd: weekEnd,
          );
          generated++;
        } catch (e) {
          debugPrint('Backfill week $weekStart error: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              generated > 0
                  ? '✅ Generated $generated reports from past conversations!'
                  : 'No new conversations found to generate reports from.',
            ),
            backgroundColor: generated > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generating reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // Report Card Widget
  Widget _buildReportCard(Map<String, dynamic> report, String reportId) {
    final isRead = report['isRead'] ?? false;
    final summary = report['summary'] ?? 'Report generated';
    final sentimentData =
        report['sentimentData'] as Map<String, dynamic>? ?? {};
    final reportPeriod = report['reportPeriod'] as Map<String, dynamic>?;
    final wellnessScore =
        (sentimentData['emotionalWellnessScore'] as num?)?.toDouble() ?? 50.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _showReportDetails(report, reportId);
          if (!isRead) {
            _notificationService.markBuddyReportAsRead(widget.elderlyId, reportId);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.analytics,
                      color: Colors.blue[700],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Wellness Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.bold,
                          ),
                        ),
                        if (reportPeriod != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatReportPeriod(reportPeriod),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Wellness Score
              _buildWellnessScoreBar(wellnessScore),
              const SizedBox(height: 16),
              // Summary Preview
              Text(
                summary.length > 150
                    ? '${summary.substring(0, 150)}...'
                    : summary,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showReportDetails(report, reportId),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View Full Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Wellness Tab
  Widget _buildWellnessTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationService.getBuddyActivityStream(widget.elderlyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.emoji_emotions,
            title: 'No activity yet',
            subtitle: 'Buddy activity will be tracked here',
          );
        }

        final activities = snapshot.data!.docs;

        return Column(
          children: [
            // Current Wellness Score
            _buildCurrentWellnessCard(),
            // Activity List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activityDoc = activities[index];
                  final activity = activityDoc.data() as Map<String, dynamic>;
                  return _buildActivityItem(activity);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Current Wellness Card — reads live emotionalHistory from Firestore
  Widget _buildCurrentWellnessCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.elderlyId)
              .snapshots(),
      builder: (context, snapshot) {
        double wellnessScore = 50.0; // default
        String dominantSentiment = 'neutral';
        String trendLabel = 'Calculating...';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final history = data?['emotionalHistory'] as List<dynamic>? ?? [];

          if (history.isNotEmpty) {
            // Take the last 20 entries for recency
            final recent =
                history.length > 20
                    ? history.sublist(history.length - 20)
                    : history;

            final counts = <String, int>{};
            for (final entry in recent) {
              final s = (entry['sentiment'] ?? 'neutral') as String;
              counts[s] = (counts[s] ?? 0) + 1;
            }

            final total = recent.length;
            final pct = <String, double>{};
            counts.forEach((s, c) => pct[s] = (c / total) * 100);

            // Same formula as EnhancedMemoryService._calculateWellnessScore
            wellnessScore = 50.0;
            wellnessScore += (pct['positive'] ?? 0) * 0.5;
            wellnessScore += (pct['happy'] ?? 0) * 0.5;
            wellnessScore -= (pct['negative'] ?? 0) * 0.5;
            wellnessScore -= (pct['sad'] ?? 0) * 0.6;
            wellnessScore -= (pct['anxious'] ?? 0) * 0.6;
            wellnessScore -= (pct['lonely'] ?? 0) * 0.7;
            wellnessScore = wellnessScore.clamp(0.0, 100.0);

            // Dominant sentiment
            int maxCount = 0;
            counts.forEach((s, c) {
              if (c > maxCount) {
                maxCount = c;
                dominantSentiment = s;
              }
            });

            trendLabel =
                'Mood: $dominantSentiment • ${recent.length} data points';
          } else {
            trendLabel = 'No chat data yet';
          }
        } else if (snapshot.hasError) {
          trendLabel = 'Could not load data';
        }

        // Pick gradient colour based on score
        final List<Color> gradientColors =
            wellnessScore >= 70
                ? [Colors.green[400]!, Colors.green[600]!]
                : wellnessScore >= 45
                ? [Colors.orange[400]!, Colors.orange[600]!]
                : [Colors.red[400]!, Colors.red[600]!];

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradientColors),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Emotional Wellness',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Text(
                    '${wellnessScore.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                trendLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Activity Item Widget
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type'] ?? 'alert';
    final title = activity['title'] ?? 'Activity';
    final severity = activity['severity'] ?? 'moderate';
    final timestamp = activity['timestamp'] as Timestamp?;

    IconData activityIcon;
    Color activityColor;

    switch (type) {
      case 'loneliness':
        activityIcon = Icons.psychology;
        activityColor = Colors.orange;
        break;
      case 'health':
        activityIcon = Icons.favorite;
        activityColor = Colors.red;
        break;
      case 'video_call':
        activityIcon = Icons.videocam;
        activityColor = Colors.green;
        break;
      default:
        activityIcon = Icons.notifications;
        activityColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activityColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(activityIcon, color: activityColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          if (severity == 'urgent')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Urgent',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Wellness Score Bar
  Widget _buildWellnessScoreBar(double score) {
    Color scoreColor;
    String scoreLabel;

    if (score >= 70) {
      scoreColor = Colors.green;
      scoreLabel = 'Good';
    } else if (score >= 50) {
      scoreColor = Colors.orange;
      scoreLabel = 'Fair';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Needs Attention';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Emotional Wellness',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              scoreLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${score.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Empty State Widget
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // Show Notification Details Dialog
  void _showNotificationDetails(
    Map<String, dynamic> notification,
    String notificationId,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  _getNotificationIcon(notification['type']),
                  color: _getSeverityColor(notification['severity']),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(notification['title'] ?? 'Alert')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification['message'] ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (notification['originalMessage'] != null) ...[
                    const Divider(),
                    const Text(
                      'Original Message:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notification['originalMessage'],
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  if (notification['emotionalContext'] != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Emotional Context:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(notification['emotionalContext']),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (notification['severity'] == 'urgent')
                ElevatedButton(
                  onPressed: () {
                    _notificationService.markBuddyNotificationAsResolved(
                      widget.elderlyId,
                      notificationId,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked as resolved')),
                    );
                  },
                  child: const Text('Mark Resolved'),
                ),
            ],
          ),
    );
  }

  // Show Report Details Dialog
  void _showReportDetails(Map<String, dynamic> report, String reportId) {
    final sentimentData =
        report['sentimentData'] as Map<String, dynamic>? ?? {};
    final summary = report['summary'] ?? 'Report generated';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Weekly Wellness Report'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWellnessScoreBar(
                    (sentimentData['emotionalWellnessScore'] as num?)
                            ?.toDouble() ??
                        50.0,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Summary:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  if (sentimentData['concerningPatterns'] != null &&
                      (sentimentData['concerningPatterns'] as List)
                          .isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Concerning Patterns:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(sentimentData['concerningPatterns'] as List).map(
                      (pattern) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontSize: 14)),
                            Expanded(
                              child: Text(
                                pattern.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (!(report['isRead'] ?? false)) {
                    _notificationService.markBuddyReportAsRead(
                      widget.elderlyId,
                      reportId,
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  // Helper methods
  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    }
  }

  String _formatReportPeriod(Map<String, dynamic> period) {
    final start = (period['start'] as Timestamp).toDate();
    final end = (period['end'] as Timestamp).toDate();
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'loneliness':
        return Icons.psychology;
      case 'health':
        return Icons.favorite;
      case 'weekly_report':
        return Icons.analytics;
      default:
        return Icons.notifications;
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case 'urgent':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
