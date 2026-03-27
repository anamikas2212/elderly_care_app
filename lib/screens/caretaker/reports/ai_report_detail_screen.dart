import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/cognitive/cognitive_report.dart';
import '../../../theme/caretaker_theme.dart';

class AiReportDetailScreen extends StatefulWidget {
  final CognitiveReport report;
  final String caretakerId;

  const AiReportDetailScreen({
    Key? key,
    required this.report,
    required this.caretakerId,
  }) : super(key: key);

  @override
  State<AiReportDetailScreen> createState() => _AiReportDetailScreenState();
}

class _AiReportDetailScreenState extends State<AiReportDetailScreen> {
  final PageController _analysisPageController = PageController();
  int _currentAnalysisPage = 0;

  CognitiveReport get report => widget.report;

  @override
  void initState() {
    super.initState();
    // Mark as read
    FirebaseFirestore.instance
        .collection('users')
        .doc(report.elderlyId)
        .collection('cognitive_reports')
        .doc(report.id)
        .update({'isRead': true}).catchError((_) {});
  }

  @override
  void dispose() {
    _analysisPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScoreSummary(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("AI Professional Analysis"),
                  const SizedBox(height: 12),
                  _buildAnalysisCarousel(),
                  const SizedBox(height: 24),
                  if (report.domainScores.isNotEmpty) ...[
                    _buildSectionTitle("Domain Performance"),
                    const SizedBox(height: 12),
                    _buildDomainGrid(),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle("Actionable Suggestions"),
                  const SizedBox(height: 12),
                  _buildSuggestionsList(),
                  if (report.metadata['sessionDetails'] is List &&
                      (report.metadata['sessionDetails'] as List).isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle("Games & Tracked Metrics"),
                    const SizedBox(height: 12),
                    _buildSessionDetails(),
                  ],
                  if (report.metadata['overallContributions'] is Map) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle("Contribution to Final Score"),
                    const SizedBox(height: 12),
                    _buildContributionDetails(),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── App Bar ────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    final bool isWeekly = report.type == 'weekly';
    final bool isMonthly = report.type == 'monthly';
    final bool isYearly = report.type == 'yearly';
    final dateStr = DateFormat('MMMM d, yyyy').format(report.date);

    String title;
    if (isWeekly) {
      title = "Weekly Summary";
    } else if (isMonthly) {
      title = "Monthly Summary";
    } else if (isYearly) {
      title = "Yearly Summary";
    } else {
      title = "Daily Health Report";
    }

    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: isWeekly
          ? CaretakerColors.primaryGreen
          : isMonthly
              ? Colors.deepPurple
              : isYearly
                  ? Colors.indigo
                  : Colors.blue,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              dateStr,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
        centerTitle: true,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ─── Score Summary (matches screenshot) ─────────────────────────

  Widget _buildScoreSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildScoreGauge(),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overall Cognitive Index",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  _getScoreLevel(report.overallScore),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(report.overallScore),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getReportBasisText(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  _domainSummaryLine(),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getReportBasisText() {
    switch (report.type) {
      case 'weekly':
        return "Based on ${report.metadata['dailyReportsAnalyzed'] ?? 'multiple'} daily reports";
      case 'monthly':
        return "Based on ${report.metadata['dailyReportsAnalyzed'] ?? 'multiple'} daily reports this month";
      case 'yearly':
        return "Based on ${report.metadata['dailyReportsAnalyzed'] ?? 'multiple'} daily reports this year";
      default:
        return "Based on today's game metrics";
    }
  }

  Widget _buildScoreGauge() {
    final color = _getScoreColor(report.overallScore);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CircularProgressIndicator(
            value: report.overallScore / 100,
            strokeWidth: 8,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Text(
          "${report.overallScore}",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─── AI Professional Analysis Carousel ──────────────────────────

  Widget _buildAnalysisCarousel() {
    return Container(
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _calculateCarouselHeight(),
            child: Stack(
              children: [
                PageView(
                  controller: _analysisPageController,
                  onPageChanged: (i) => setState(() => _currentAnalysisPage = i),
                  children: [
                    _buildBaselineComparisonPage(),
                    _buildKeyInsightsPage(),
                  ],
                ),
                // Right arrow
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _currentAnalysisPage < 1
                      ? GestureDetector(
                          onTap: () => _analysisPageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                          child: Container(
                            width: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200.withOpacity(0.8),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.chevron_right, color: Colors.black54, size: 28),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Left arrow
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _currentAnalysisPage > 0
                      ? GestureDetector(
                          onTap: () => _analysisPageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          ),
                          child: Container(
                            width: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200.withOpacity(0.8),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.chevron_left, color: Colors.black54, size: 28),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          // Page indicator dots
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentAnalysisPage == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentAnalysisPage == i
                        ? CaretakerColors.primaryGreen
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateCarouselHeight() {
    final insights = report.keyInsights;
    if (insights.isEmpty) {
      // Fallback: analysis bullets
      final bullets = _analysisToBullets(report.analysis);
      return (bullets.length * 80.0 + 200).clamp(350.0, 600.0);
    }
    return (insights.length * 75.0 + 120).clamp(350.0, 600.0);
  }

  // ─── Page 1: Baseline Comparison ────────────────────────────────

  Widget _buildBaselineComparisonPage() {
    final domains = ['executiveFunction', 'memory', 'language', 'attention', 'processingSpeed'];
    final domainScores = report.domainScores;
    final domainChanges = report.domainChanges;
    final overallChange = report.overallChangePercent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 48, 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Overall change summary
          Row(
            children: [
              Icon(
                overallChange < 0 ? Icons.trending_down : Icons.trending_up,
                color: overallChange < 0 ? Colors.orange : CaretakerColors.primaryGreen,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Score ${overallChange < 0 ? 'dipped' : 'improved'} (${overallChange.abs().toStringAsFixed(1)}%) compared to historical baseline. ${overallChange < 0 ? 'That is okay. Small breaks, good meals, and light practice can help it rebound.' : 'Great progress! Keep up the good work.'}",
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // "Today vs Baseline Domains" header
          const Text(
            "Today vs Baseline Domains",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 12),

          // Domain comparison list
          ...domains.map((domain) {
            final score = (domainScores[domain] as num?)?.toInt() ?? 0;
            final change = domainChanges[domain] ?? 0.0;
            final isDecline = change < 0;
            final changeColor = isDecline ? Colors.red.shade600 : CaretakerColors.primaryGreen;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  _getDomainIcon(domain),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _formatDomainName(domain),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    "$score%",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isDecline ? Icons.trending_down : Icons.trending_up,
                    color: changeColor,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${change.abs().toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: changeColor,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Overall vs historical line
          Row(
            children: [
              Icon(
                overallChange < 0 ? Icons.trending_down : Icons.trending_up,
                color: overallChange < 0 ? Colors.orange : CaretakerColors.primaryGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Overall vs historical average: ${overallChange.abs().toStringAsFixed(1)}% ${overallChange < 0 ? 'lower' : 'higher'}.",
                  style: TextStyle(
                    fontSize: 12,
                    color: overallChange < 0 ? Colors.orange : CaretakerColors.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Good / Watch / Improve chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip("Good", Colors.green, Icons.check_circle_outline),
              _buildStatusChip("Watch", Colors.orange, Icons.radio_button_checked),
              _buildStatusChip("Improve", Colors.grey, Icons.change_circle_outlined),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  // ─── Page 2: Key Insights ───────────────────────────────────────

  Widget _buildKeyInsightsPage() {
    final insights = report.keyInsights;

    // Fallback to analysis bullets if no key insights
    if (insights.isEmpty) {
      final bullets = _analysisToBullets(report.analysis);
      return Padding(
        padding: const EdgeInsets.fromLTRB(48, 16, 16, 8),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Key Insights",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              ...bullets.map((b) => _buildInsightItem('neutral', b)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 16, 16, 8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Key Insights",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            ...insights.map((insight) {
              final iconType = insight['icon_type']?.toString() ?? 'neutral';
              final text = insight['text']?.toString() ?? '';
              return _buildInsightItem(iconType, text);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String iconType, String text) {
    IconData icon;
    Color color;

    switch (iconType) {
      case 'decline':
        icon = Icons.trending_down;
        color = Colors.orange;
        break;
      case 'improve':
        icon = Icons.trending_up;
        color = CaretakerColors.primaryGreen;
        break;
      case 'tip':
        icon = Icons.lightbulb_outline;
        color = Colors.purple;
        break;
      default:
        icon = Icons.arrow_forward;
        color = Colors.grey.shade600;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
            ),
          ),
          const SizedBox(width: 6),
          _getInsightCategoryIcon(iconType),
        ],
      ),
    );
  }

  Widget _getInsightCategoryIcon(String type) {
    switch (type) {
      case 'decline':
        return Icon(Icons.restaurant, size: 14, color: Colors.orange.shade300);
      case 'improve':
        return Icon(Icons.emoji_events, size: 14, color: Colors.green.shade300);
      case 'tip':
        return Icon(Icons.lightbulb, size: 14, color: Colors.purple.shade300);
      default:
        return Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400);
    }
  }

  // ─── Section Title ──────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: CaretakerColors.primaryGreen,
      ),
    );
  }

  // ─── Domain Performance Grid ────────────────────────────────────

  Widget _buildDomainGrid() {
    final domains = report.domainScores;
    final entries = domains.entries.where((e) => (e.value as num?) != null && (e.value as num) > 0).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CaretakerColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _getDomainIcon(entry.key),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDomainName(entry.key),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${entry.value}%",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Actionable Suggestions ─────────────────────────────────────

  Widget _buildSuggestionsList() {
    final List<String> items = List<String>.from(report.suggestions);
    items.add("You're doing a great job supporting their progress. No need to worry — small, steady steps matter.");

    // Score-based suggestions
    final overallScore = report.overallScore;
    if (overallScore > 0) {
      if (overallScore >= 66) {
        items.add("Overall Cognitive Index is in the strong band ($overallScore). Great work!");
      } else {
        items.add("Overall Cognitive Index is in the medium band ($overallScore). Aim for 66+ to reach the strong band.");
      }
    }

    // Lowest domain suggestion
    final domainScores = report.domainScores;
    if (domainScores.isNotEmpty) {
      final activeDomains = domainScores.entries
          .where((e) => (e.value as num?) != null && (e.value as num) > 0)
          .toList();
      if (activeDomains.isNotEmpty) {
        activeDomains.sort((a, b) => (a.value as num).compareTo(b.value as num));
        final lowest = activeDomains.first;
        items.add("Today's lowest domain is ${_formatDomainName(lowest.key)} (${_getScoreBand(lowest.value as int)}). Try a gentle game focused on that domain and keep sessions short.");
      }

      // Suggest specific game for weak domain
      final weakDomains = activeDomains.where((e) => (e.value as num) < 50).toList();
      for (final weak in weakDomains) {
        final game = _suggestGameForDomain(weak.key);
        if (game != null) {
          items.add("Try $game to strengthen ${_formatDomainName(weak.key).toLowerCase()}.");
        }
      }
    }

    if (_shouldSuggestDoctor()) {
      items.add("Some scores are quite low today. Consider a check-in with a doctor or specialist if this continues.");
    }

    return Column(
      children: items.map((s) => _buildSuggestionItem(s)).toList(),
    );
  }

  String _getScoreBand(int score) {
    if (score >= 80) return 'strong';
    if (score >= 50) return 'medium';
    return 'low';
  }

  String? _suggestGameForDomain(String domain) {
    switch (domain.toLowerCase()) {
      case 'attention':
        return 'Color Tap';
      case 'processingspeed':
        return 'Color Tap';
      case 'memory':
        return 'Flip Card';
      case 'executivefunction':
        return 'City Atlas or Event Ordering';
      case 'language':
        return 'Monument Recall';
      default:
        return null;
    }
  }

  Widget _buildSuggestionItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaretakerColors.primaryGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CaretakerColors.primaryGreen.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 20, color: CaretakerColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Session Details (Games & Tracked Metrics) ──────────────────

  Widget _buildSessionDetails() {
    final details = List<Map<String, dynamic>>.from(
      report.metadata['sessionDetails'] as List,
    );

    return Column(
      children: details.map((item) {
        final game = item['gameType']?.toString() ?? 'Unknown';
        final score = item['score']?.toString() ?? '-';
        final accuracy = item['accuracy'];
        final rt = item['average_reaction_time'];
        final efficiency = item['efficiency'];
        final metrics = (item['metrics'] is Map)
            ? Map<String, dynamic>.from(item['metrics'] as Map)
            : <String, dynamic>{};
        final playedAt = item['playedAt']?.toString();
        final tracked = <String>[
          if (accuracy != null) 'Accuracy',
          if (rt != null) 'Reaction Time',
          if (efficiency != null) 'Efficiency',
          ..._mapMetricKeys(metrics.keys),
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CaretakerColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              if (playedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  "Played at: ${_formatDateTime(playedAt)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 6),
              Text("Score: $score", style: const TextStyle(fontSize: 13)),
              if (tracked.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "Tracked: ${tracked.join(', ')}",
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (accuracy != null) _metricChip("Accuracy", accuracy),
                  if (rt != null) _metricChip("Reaction Time", rt),
                  if (efficiency != null) _metricChip("Efficiency", efficiency),
                  ..._mapMetricEntries(metrics).map((e) => _metricChip(e.key, e.value)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _metricChip(String label, dynamic value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "$label: $value",
        style: const TextStyle(fontSize: 11, color: Colors.black87),
      ),
    );
  }

  // ─── Contribution Details ───────────────────────────────────────

  Widget _buildContributionDetails() {
    final overall = Map<String, dynamic>.from(
      report.metadata['overallContributions'] as Map,
    );
    final domain = report.metadata['domainContributions'] is Map
        ? Map<String, dynamic>.from(report.metadata['domainContributions'] as Map)
        : <String, dynamic>{};

    return Column(
      children: overall.entries.map((e) {
        final game = e.key.toString();
        final overallPct = e.value.toString();
        final perDomain = domain[game] is Map
            ? Map<String, dynamic>.from(domain[game] as Map)
            : <String, dynamic>{};

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CaretakerColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                game,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                "Overall contribution: $overallPct%",
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (perDomain.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: perDomain.entries
                      .map((d) => _metricChip(
                            _formatDomainName(d.key.toString()),
                            "${d.value}%",
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────

  bool _shouldSuggestDoctor() {
    if (report.overallScore < 50) return true;
    if (report.domainScores.values.whereType<num>().any((v) => v < 35)) return true;
    return false;
  }

  Iterable<String> _mapMetricKeys(Iterable keys) {
    final mapped = <String>[];
    for (final k in keys) {
      final label = _friendlyMetricLabel(k.toString());
      if (label.isNotEmpty) mapped.add(label);
    }
    return mapped.toSet();
  }

  Iterable<MapEntry<String, dynamic>> _mapMetricEntries(Map<String, dynamic> metrics) {
    final Map<String, dynamic> result = {};
    metrics.forEach((key, value) {
      final label = _friendlyMetricLabel(key);
      if (label.isNotEmpty) {
        result[label] = value;
      }
    });
    return result.entries;
  }

  String _friendlyMetricLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'correct_taps': return 'Correct Taps';
      case 'false_taps': return 'False Taps';
      case 'missed_taps': return 'Missed Taps';
      case 'average_reaction_time': return 'Reaction Time';
      case 'reaction_time': return 'Reaction Time';
      case 'accuracy': return 'Accuracy';
      case 'efficiency': return 'Efficiency';
      case 'total_pairs': return 'Total Pairs';
      case 'pairs_matched': return 'Pairs Matched';
      case 'total_attempts': return 'Total Attempts';
      case 'wrong_attempts': return 'Wrong Attempts';
      case 'average_time_per_pair': return 'Avg Time per Pair';
      case 'time_per_pair': return 'Time per Pair';
      case 'total_time': return 'Total Time';
      case 'sequence_accuracy': return 'Sequence Accuracy';
      case 'order_accuracy': return 'Order Accuracy';
      default: return '';
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getScoreLevel(int score) {
    if (score >= 80) return "Excellent";
    if (score >= 65) return "Good";
    if (score >= 50) return "Stable";
    if (score >= 35) return "Warning";
    return "Attention Required";
  }

  String _formatDomainName(String name) {
    if (name == 'processingSpeed') return "Processing Speed";
    if (name == 'executiveFunction') return "Executive Function";
    return name[0].toUpperCase() + name.substring(1);
  }

  List<String> _analysisToBullets(String analysis) {
    final text = analysis.trim();
    if (text.isEmpty) return const ["No analysis available."];

    final parts = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    parts.sort((a, b) => _importanceScore(b).compareTo(_importanceScore(a)));
    return parts;
  }

  int _importanceScore(String sentence) {
    final s = sentence.toLowerCase();
    int score = 0;
    if (s.contains('overall') || s.contains('trend') || s.contains('decline') || s.contains('improve')) score += 3;
    if (s.contains('fatigue') || s.contains('sharpness') || s.contains('attention') || s.contains('memory')) score += 2;
    if (s.contains('reaction time') || s.contains('accuracy') || s.contains('efficiency')) score += 1;
    return score;
  }

  String _domainSummaryLine() {
    final entries = report.domainScores.entries
        .where((e) => (e.value as num?) != null && (e.value as num) > 0)
        .map((e) => "${_formatDomainName(e.key)} ${e.value}%")
        .toList();
    if (entries.isEmpty) {
      return "Domains used: Not enough data yet";
    }
    return "Domains used: ${entries.join(', ')}";
  }

  Widget _getDomainIcon(String domain) {
    IconData icon;
    Color color;
    switch (domain.toLowerCase()) {
      case 'memory':
        icon = Icons.psychology;
        color = Colors.purple;
        break;
      case 'attention':
        icon = Icons.visibility;
        color = Colors.blue;
        break;
      case 'processingspeed':
        icon = Icons.speed;
        color = Colors.orange;
        break;
      case 'executivefunction':
        icon = Icons.settings_suggest;
        color = Colors.teal;
        break;
      case 'language':
        icon = Icons.translate;
        color = Colors.amber;
        break;
      default:
        icon = Icons.offline_bolt;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 20);
  }
}
