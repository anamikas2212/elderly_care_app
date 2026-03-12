import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/cognitive/cognitive_report.dart';
import '../../../theme/caretaker_theme.dart';

class AiReportDetailScreen extends StatelessWidget {
  final CognitiveReport report;
  final String caretakerId;

  const AiReportDetailScreen({
    Key? key,
    required this.report,
    required this.caretakerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Mark as read when opened
    if (caretakerId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(caretakerId)
          .collection('cognitive_reports')
          .doc(report.id)
          .update({'isRead': true}).catchError((_) {});
    }

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
                  _buildAnalysisCard(),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getCaretakerIdFromPath() {
    // Implementation simplified for UI. In real app, ID should be passed.
    return null; 
  }

  Widget _buildAppBar(BuildContext context) {
    final bool isWeekly = report.type == 'weekly';
    final dateStr = DateFormat('MMMM d, yyyy').format(report.date);

    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: isWeekly ? CaretakerColors.primaryGreen : Colors.blue,
      flexibleSpace: FlexibleSpaceBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isWeekly ? "Weekly Summary" : "Daily Health Report",
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
                  report.type == 'weekly' 
                    ? "Based on a 7-day trend analysis"
                    : "Based on today's game metrics",
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

  Widget _buildAnalysisCard() {
    final bullets = _analysisToBullets(report.analysis);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: bullets.map(_buildBullet).toList(),
      ),
    );
  }

  Widget _buildDomainGrid() {
    final domains = report.domainScores;
    // Filter to only non-zero domain scores
    final entries = domains.entries.where((e) => e.value > 0).toList();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CaretakerColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              _getDomainIcon(entry.key),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDomainName(entry.key),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    Text(
                      "${entry.value}%",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildSuggestionsList() {
    final List<String> items = List<String>.from(report.suggestions);
    items.add("You're doing a great job supporting their progress. No need to worry — small, steady steps matter.");
    if (_shouldSuggestDoctor()) {
      items.add("Some scores are quite low today. Consider a professional check‑in with a doctor or specialist for guidance.");
    }
    return Column(
      children: items.map((s) => _buildSuggestionItem(s)).toList(),
    );
  }

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
                Text(
                  "Tracked: ${tracked.join(', ')}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (accuracy != null)
                    _metricChip("Accuracy", accuracy),
                  if (rt != null)
                    _metricChip("Reaction Time", rt),
                  if (efficiency != null)
                    _metricChip("Efficiency", efficiency),
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
      case 'correct_taps':
        return 'Correct Taps';
      case 'false_taps':
        return 'False Taps';
      case 'missed_taps':
        return 'Missed Taps';
      case 'average_reaction_time':
        return 'Reaction Time';
      case 'reaction_time':
        return 'Reaction Time';
      case 'accuracy':
        return 'Accuracy';
      case 'efficiency':
        return 'Efficiency';
      case 'total_pairs':
        return 'Total Pairs';
      case 'pairs_matched':
        return 'Pairs Matched';
      case 'total_attempts':
        return 'Total Attempts';
      case 'wrong_attempts':
        return 'Wrong Attempts';
      case 'average_time_per_pair':
        return 'Avg Time per Pair';
      case 'time_per_pair':
        return 'Time per Pair';
      case 'total_time':
        return 'Total Time';
      case 'sequence_accuracy':
        return 'Sequence Accuracy';
      case 'order_accuracy':
        return 'Order Accuracy';
      default:
        return '';
    }
  }

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

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MMM d, yyyy • h:mm a').format(dt);
    } catch (_) {
      return iso;
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

    // Split on sentence endings and filter empties.
    final parts = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Sort by a simple importance heuristic.
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

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontSize: 16, height: 1.4)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
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
