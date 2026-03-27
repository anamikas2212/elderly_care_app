import 'dart:async';
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
  final String? elderlyUid;

  const AiCognitiveReportsScreen({
    Key? key,
    required this.caretakerId,
    required this.elderlyId,
    this.elderlyName,
    this.elderlyUid,
  }) : super(key: key);

  @override
  _AiCognitiveReportsScreenState createState() =>
      _AiCognitiveReportsScreenState();
}

class _AiCognitiveReportsScreenState extends State<AiCognitiveReportsScreen>
    with SingleTickerProviderStateMixin {
  bool _isGenerating = false;
  late TabController _tabController;

  // Calendar state
  late int _selectedYear;
  late int _selectedMonth;

  static const _tabLabels = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  static const _tabTypes = ['daily', 'weekly', 'monthly', 'yearly'];

  String get _effectiveElderlyId {
    final uid = widget.elderlyUid;
    if (uid != null && uid.isNotEmpty) return uid;
    return widget.elderlyId;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        backgroundColor: CaretakerColors.cardWhite,
        elevation: 0,
        title: const Text(
          "Cognitive Health Reports",
          style: CaretakerTextStyles.header,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: CaretakerColors.primaryGreen,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.auto_awesome,
              color:
                  _isGenerating
                      ? CaretakerColors.primaryGreen.withOpacity(0.5)
                      : CaretakerColors.primaryGreen,
            ),
            onPressed: _isGenerating ? null : _generateReportNow,
            tooltip: "Generate report",
          ),
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: CaretakerColors.primaryGreen,
            ),
            onPressed: () => _showInfoDialog(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _buildCalendarHeader(),
              TabBar(
                controller: _tabController,
                labelColor: CaretakerColors.primaryGreen,
                unselectedLabelColor: Colors.grey,
                indicatorColor: CaretakerColors.primaryGreen,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabTypes.map((type) => _buildReportsTab(type)).toList(),
      ),
    );
  }

  // ─── Calendar Header ───────────────────────────────────────────

  Widget _buildCalendarHeader() {
    final monthName = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(_selectedYear, _selectedMonth));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left,
              color: CaretakerColors.primaryGreen,
            ),
            onPressed: _previousMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showMonthYearPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: CaretakerColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month,
                    size: 18,
                    color: CaretakerColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    monthName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CaretakerColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.chevron_right,
              color: CaretakerColors.primaryGreen,
            ),
            onPressed: _nextMonth,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth--;
      if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth++;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      }
    });
  }

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        int tempYear = _selectedYear;
        int tempMonth = _selectedMonth;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Month & Year"),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setDialogState(() => tempYear--),
                        ),
                        Text(
                          "$tempYear",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setDialogState(() => tempYear++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Month grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.0,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isSelected = month == tempMonth;
                        return GestureDetector(
                          onTap: () => setDialogState(() => tempMonth = month),
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? CaretakerColors.primaryGreen
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              DateFormat('MMM').format(DateTime(2000, month)),
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CaretakerColors.primaryGreen,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedYear = tempYear;
                      _selectedMonth = tempMonth;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Select",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Reports Tab ────────────────────────────────────────────────

  Widget _buildReportsTab(String type) {
    // For yearly tab, query the whole year; otherwise filter by selected month
    DateTime rangeStart;
    DateTime rangeEnd;

    if (type == 'yearly') {
      rangeStart = DateTime(_selectedYear, 1, 1);
      rangeEnd = DateTime(_selectedYear + 1, 1, 1);
    } else {
      rangeStart = DateTime(_selectedYear, _selectedMonth, 1);
      rangeEnd = DateTime(_selectedYear, _selectedMonth + 1, 1);
    }

    return Stack(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _reportsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyTabState(type);
            }

            // Filter by elderlyId, type, and date range, then sort
            final filtered = snapshot.data!.where((entry) {
              final data = entry['data'] as Map<String, dynamic>;
              final id = data['elderlyId']?.toString();
              final name = data['elderlyName']?.toString();
              final reportType = data['type']?.toString() ?? 'daily';
              final matchId = id == widget.elderlyId;
              final matchName =
                  widget.elderlyName != null && name == widget.elderlyName;
              final matchIdToName =
                  widget.elderlyName != null && id == widget.elderlyName;
              final matchType = reportType == type;

              // Date range filter
              final ts = data['date'] as Timestamp?;
              if (ts == null) return false;
              final reportDate = ts.toDate();
              final inRange = !reportDate.isBefore(rangeStart) && reportDate.isBefore(rangeEnd);

              return (matchId || matchName || matchIdToName) && matchType && inRange;
            }).toList();

            // Sort by date descending
            filtered.sort((a, b) {
              final aTs = (a['data'] as Map<String, dynamic>)['date'] as Timestamp?;
              final bTs = (b['data'] as Map<String, dynamic>)['date'] as Timestamp?;
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return bTs.compareTo(aTs);
            });

            if (filtered.isEmpty) {
              return _buildEmptyTabState(type);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                final reportData = entry['data'] as Map<String, dynamic>;
                final report = CognitiveReport.fromMap(
                  reportData,
                  entry['id'] as String,
                );
                final sourceId = entry['sourceId'] as String? ?? widget.elderlyId;
                return _buildReportCard(report, sourceId);
              },
            );
          },
        ),
        // Generate button for non-daily tabs
        if (type != 'daily')
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'generate_$type',
              backgroundColor:
                  _isGenerating
                      ? Colors.grey
                      : type == 'weekly'
                      ? CaretakerColors.primaryGreen
                      : type == 'monthly'
                      ? Colors.deepPurple
                      : Colors.indigo,
              onPressed:
                  _isGenerating ? null : () => _generateReportForType(type),
              icon:
                  _isGenerating
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Icon(Icons.auto_awesome, color: Colors.white),
              label: Text(
                'Generate ${type[0].toUpperCase()}${type.substring(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Stream<List<Map<String, dynamic>>> _reportsStream() {
    final ids = <String>{widget.elderlyId};
    if (widget.elderlyUid != null && widget.elderlyUid!.isNotEmpty) {
      ids.add(widget.elderlyUid!);
    }

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final Map<String, List<Map<String, dynamic>>> bySource = {};
    final List<StreamSubscription> subs = [];

    void emit() {
      final all = <Map<String, dynamic>>[];
      for (final list in bySource.values) {
        all.addAll(list);
      }
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final item in all) {
        final data = item['data'] as Map<String, dynamic>;
        final ts = data['date'] as Timestamp?;
        final key =
            '${data['type']}_${ts?.millisecondsSinceEpoch ?? ''}_${data['overallScore'] ?? ''}';
        if (seen.add(key)) deduped.add(item);
      }
      controller.add(deduped);
    }

    void register(String id) {
      final sub = FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .collection('cognitive_reports')
          .snapshots()
          .listen(
            (snapshot) {
              bySource[id] = snapshot.docs
                  .map(
                    (doc) => {
                      'id': doc.id,
                      'data': doc.data(),
                      'sourceId': id,
                    },
                  )
                  .toList();
              emit();
            },
            onError: (_) {
              bySource[id] = [];
              emit();
            },
          );
      subs.add(sub);
    }

    for (final id in ids) {
      register(id);
    }

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  Widget _buildEmptyTabState(String type) {
    final typeLabel = type[0].toUpperCase() + type.substring(1);
    String hint;
    if (type == 'daily') {
      hint =
          'Play games to generate daily reports, or tap the ✨ button to generate now.';
    } else if (type == 'weekly') {
      hint =
          'Tap the Generate Weekly button below to create a combined report from this week\'s daily reports.';
    } else if (type == 'monthly') {
      hint =
          'Tap the Generate Monthly button below to create a summary from this month\'s daily reports.';
    } else {
      hint =
          'Tap the Generate Yearly button below to create a summary from this year\'s daily reports.';
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No $typeLabel reports for this period.",
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Report Card ────────────────────────────────────────────────

  Widget _buildReportCard(CognitiveReport report, String sourceId) {
    final bool isWeekly = report.type == 'weekly';
    final bool isMonthly = report.type == 'monthly';
    final bool isYearly = report.type == 'yearly';

    Color color;
    String label;
    IconData icon;

    if (isWeekly) {
      color = CaretakerColors.primaryGreen;
      label = 'WEEKLY TREND';
      icon = Icons.assessment;
    } else if (isMonthly) {
      color = Colors.deepPurple;
      label = 'MONTHLY SUMMARY';
      icon = Icons.calendar_month;
    } else if (isYearly) {
      color = Colors.indigo;
      label = 'YEARLY SUMMARY';
      icon = Icons.date_range;
    } else {
      color = Colors.blue;
      label = 'DAILY ANALYSIS';
      icon = Icons.today;
    }

    final dateStr = DateFormat('EEEE, MMM d').format(report.date);

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
                builder:
                    (_) => AiReportDetailScreen(
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
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
                  onPressed: () => _confirmDelete(report, sourceId),
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

  // ─── Generate Report ────────────────────────────────────────────

  Future<void> _generateReportNow() async {
    setState(() {
      _isGenerating = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating report... this may take a moment.'),
      ),
    );

    try {
      final service = CognitiveReportService(groqApiKey: AppConfig.groqApiKey);
      final status = await service.generateDailyCognitiveReportWithStatus(
        _effectiveElderlyId,
        caretakerIdOverride: widget.caretakerId,
      );
      if (!mounted) return;
      String message;
      switch (status) {
        case 'generated':
          message = 'Report generated successfully.';
          break;
        case 'updated':
          message = 'Existing report updated with latest data.';
          break;
        case 'no_sessions':
          message = 'No game sessions in the last 24 hours.';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
    }
  }

  // ─── Generate Report for Type (Weekly/Monthly/Yearly) ───────────

  Future<void> _generateReportForType(String type) async {
    setState(() {
      _isGenerating = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generating ${type} report... this may take a moment.'),
      ),
    );

    try {
      final service = CognitiveReportService(groqApiKey: AppConfig.groqApiKey);

      if (type == 'weekly') {
        final now = DateTime.now();
        DateTime? targetDate;
        if (_selectedYear != now.year || _selectedMonth != now.month) {
          // If viewing a different month, generate for a week within that month
          targetDate = DateTime(_selectedYear, _selectedMonth, 7);
        }
        await service.generateWeeklyCognitiveReport(
          _effectiveElderlyId,
          periodEnd: targetDate, // If null, service uses DateTime.now()
        );
      } else if (type == 'monthly') {
        await service.generateMonthlyCognitiveReport(
          _effectiveElderlyId,
          month: _selectedMonth,
          year: _selectedYear,
        );
      } else if (type == 'yearly') {
        await service.generateYearlyCognitiveReport(
          _effectiveElderlyId,
          year: _selectedYear,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${type[0].toUpperCase()}${type.substring(1)} report generated!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate ${type} report: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
    }
  }

  // ─── Delete ─────────────────────────────────────────────────────

  Future<void> _confirmDelete(CognitiveReport report, String sourceId) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete report?"),
            content: const Text("This will permanently delete the report."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (result != true) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(sourceId)
        .collection('cognitive_reports')
        .doc(report.id)
        .delete();
  }

  // ─── Info Dialog ────────────────────────────────────────────────

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("About Cognitive Health Reports"),
            content: const Text(
              "These reports are generated using advanced AI (Groq/Llama-3) that analyzes "
              "daily game performance. It looks at reaction times, accuracy, and efficiency "
              "across multiple cognitive domains to provide actionable insights for caregivers.\n\n"
              "• Daily reports are generated from game sessions\n"
              "• Weekly reports combine all daily reports (auto-generated on Sundays)\n"
              "• Monthly reports summarize the entire month\n"
              "• Yearly reports provide long-term cognitive health trends",
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
}
