import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:elderly_care_app/config/app_config.dart';
import 'package:elderly_care_app/services/cognitive_report_service.dart';
import '../../../models/cognitive/cognitive_report.dart';
import '../../../theme/caretaker_theme.dart';
import 'ai_report_detail_screen.dart';

class AiCognitiveReportsScreen extends StatefulWidget {
  final String caretakerId;
  final String elderlyId;
  final String? elderlyName;

  const AiCognitiveReportsScreen({
    Key? key,
    required this.caretakerId,
    required this.elderlyId,
    this.elderlyName,
  }) : super(key: key);

  @override
  _AiCognitiveReportsScreenState createState() => _AiCognitiveReportsScreenState();
}

class _AiCognitiveReportsScreenState extends State<AiCognitiveReportsScreen> {
  bool _isGenerating = false;
  bool _showAllReports = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        backgroundColor: CaretakerColors.cardWhite,
        elevation: 0,
        title: const Text(
          "AI Cognitive Reports",
          style: CaretakerTextStyles.header,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CaretakerColors.primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color: _isGenerating
                  ? CaretakerColors.primaryGreen.withOpacity(0.5)
                  : CaretakerColors.primaryGreen,
            ),
            onPressed: _isGenerating ? null : _generateReportNow,
            tooltip: "Generate report now",
          ),
          IconButton(
            icon: Icon(
              Icons.bolt,
              color: _isGenerating
                  ? CaretakerColors.primaryGreen.withOpacity(0.5)
                  : CaretakerColors.primaryGreen,
            ),
            onPressed: _isGenerating ? null : _forceGenerateReport,
            tooltip: "Force generate",
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: CaretakerColors.primaryGreen),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.caretakerId)
            .collection('cognitive_reports')
            .orderBy('date', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final reports = snapshot.data!.docs;
          final filtered = reports.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final id = data['elderlyId']?.toString();
            final name = data['elderlyName']?.toString();
            final matchId = id == widget.elderlyId;
            final matchName = widget.elderlyName != null && name == widget.elderlyName;
            final matchIdToName = widget.elderlyName != null && id == widget.elderlyName;
            return matchId || matchName || matchIdToName;
          }).toList();

          if (filtered.isEmpty && !_showAllReports) {
            final sample = reports.take(3).map((d) {
              final data = d.data() as Map<String, dynamic>;
              return "${data['elderlyId'] ?? '-'} / ${data['elderlyName'] ?? '-'}";
            }).join(', ');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    "No AI reports for this elderly yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                    child: Text(
                      "If you just played a game, tap Generate Report Now.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Debug: caretaker=${widget.caretakerId}, elderlyId=${widget.elderlyId}, name=${widget.elderlyName ?? '-'}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Debug: total reports=${reports.length}. Sample: $sample",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: reports.isEmpty
                        ? null
                        : () => setState(() => _showAllReports = true),
                    child: const Text("Show all reports (debug)"),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _GlobalReportsDebugScreen(
                            elderlyId: widget.elderlyId,
                            elderlyName: widget.elderlyName,
                          ),
                        ),
                      );
                    },
                    child: const Text("Open global reports (debug)"),
                  ),
                ],
              ),
            );
          }

          final list = _showAllReports ? reports : filtered;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final reportData = list[index].data() as Map<String, dynamic>;
              final report = CognitiveReport.fromMap(reportData, list[index].id);
              return _buildReportCard(report);
            },
          );
        },
      ),
    );
  }

  Widget _buildReportCard(CognitiveReport report) {
    final bool isWeekly = report.type == 'weekly';
    final bool isHourly = report.type == 'hourly';
    final bool isTenMinute = report.type == 'ten_minute';
    final color = isWeekly
        ? CaretakerColors.primaryGreen
        : (isHourly ? Colors.deepPurple : Colors.blue);
    final dateStr = DateFormat('EEEE, MMM d').format(report.date);
    final label = isWeekly
        ? 'WEEKLY TREND'
        : (isHourly ? 'HOURLY SUMMARY' : (isTenMinute ? '10-MIN REPORT' : 'DAILY ANALYSIS'));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AiReportDetailScreen(
                  report: report,
                  caretakerId: widget.caretakerId,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isWeekly ? Icons.assessment : Icons.today,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: color,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (!report.isRead)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                "NEW",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.analysis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getScoreColor(report.overallScore).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${report.overallScore}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(report.overallScore),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () => _confirmDelete(report),
                  tooltip: "Delete report",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("About AI Reports"),
        content: const Text(
          "These reports are generated using advanced AI (Groq/Llama-3) that analyzes "
          "daily game performance. It looks at reaction times, accuracy, and efficiency "
          "across multiple cognitive domains to provide actionable insights for caregivers.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Understood"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(CognitiveReport report) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete report?"),
        content: const Text("This will permanently delete the report."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (result != true) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.caretakerId)
        .collection('cognitive_reports')
        .doc(report.id)
        .delete();
  }

  Future<void> _generateReportNow() async {
    setState(() {
      _isGenerating = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating report...')),
    );

    try {
      final service = CognitiveReportService(groqApiKey: AppConfig.groqApiKey);
      final status = await service.generateDailyCognitiveReportWithStatus(
        widget.elderlyId,
        caretakerIdOverride: widget.caretakerId,
      );
      if (!mounted) return;
      String message;
      switch (status) {
        case 'generated':
          message = 'Report generated.';
          break;
        case 'updated':
          message = 'Report updated.';
          break;
        case 'already_exists':
          message = 'Report already exists for today.';
          break;
        case 'no_sessions':
          message = 'No sessions in the last 24 hours.';
          break;
        case 'no_caretaker':
          message = 'No caretaker linked for this user.';
          break;
        case 'user_not_found':
          message = 'User not found.';
          break;
        default:
          message = 'Failed to generate report.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _forceGenerateReport() async {
    setState(() {
      _isGenerating = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Force generating report...')),
    );

    try {
      final service = CognitiveReportService(groqApiKey: AppConfig.groqApiKey);
      final status = await service.generateDailyCognitiveReportWithStatus(
        widget.elderlyId,
        caretakerIdOverride: widget.caretakerId,
        force: true,
      );
      if (!mounted) return;
      String message;
      switch (status) {
        case 'generated':
          message = 'Report generated.';
          break;
        case 'updated':
          message = 'Report updated.';
          break;
        case 'no_sessions':
          message = 'No sessions in the last 24 hours.';
          break;
        case 'no_caretaker':
          message = 'No caretaker linked for this user.';
          break;
        case 'user_not_found':
          message = 'User not found.';
          break;
        default:
          message = 'Failed to generate report.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate report: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "No AI reports generated yet.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: Text(
              "No report is generated when no sessions are played. Play a game to generate the next report.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _GlobalReportsDebugScreen(
                    elderlyId: widget.elderlyId,
                    elderlyName: widget.elderlyName,
                  ),
                ),
              );
            },
            child: const Text("Open global reports (debug)"),
          ),
        ],
      ),
    );
  }
}

class _GlobalReportsDebugScreen extends StatelessWidget {
  final String elderlyId;
  final String? elderlyName;

  const _GlobalReportsDebugScreen({
    required this.elderlyId,
    required this.elderlyName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Global Reports (Debug)")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('cognitive_reports')
            .orderBy('date', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No global reports found."));
          }
          final reports = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final id = data['elderlyId']?.toString();
            final name = data['elderlyName']?.toString();
            final matchId = id == elderlyId;
            final matchName = elderlyName != null && name == elderlyName;
            final matchIdToName = elderlyName != null && id == elderlyName;
            return matchId || matchName || matchIdToName;
          }).toList();

          if (reports.isEmpty) {
            return const Center(child: Text("No matching reports in global collection."));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final data = reports[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text("${data['type'] ?? 'daily'} • ${data['elderlyName'] ?? data['elderlyId']}"),
                subtitle: Text("caretaker=${data['caretakerId'] ?? '-'}"),
              );
            },
          );
        },
      ),
    );
  }
}
