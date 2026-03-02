import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/caretaker_theme.dart';
import '../../../services/caretaker_data_service.dart';

class CognitiveHealthScreen extends StatefulWidget {
  const CognitiveHealthScreen({Key? key}) : super(key: key);

  @override
  State<CognitiveHealthScreen> createState() => _CognitiveHealthScreenState();
}

class _CognitiveHealthScreenState extends State<CognitiveHealthScreen> {
  final CaretakerDataService _dataService = CaretakerDataService();
  String _elderlyUserId = "";
  bool _isLoading = true;
  int? _selectedDifficulty; // null = all levels, 1 = easy, 2 = medium, 3 = hard


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

      if (!mounted) return;
      setState(() {
        _elderlyUserId = userId ?? "";
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: CaretakerColors.background,
        appBar: AppBar(
          title: const Text(
            'Cognitive Health',
            style: CaretakerTextStyles.header,
          ),
          backgroundColor: CaretakerColors.cardWhite,
          iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_elderlyUserId.isEmpty) {
      return Scaffold(
        backgroundColor: CaretakerColors.background,
        appBar: AppBar(
          title: const Text(
            'Cognitive Health',
            style: CaretakerTextStyles.header,
          ),
          backgroundColor: CaretakerColors.cardWhite,
          iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
          elevation: 0,
        ),
        body: const Center(child: Text('No user data available')),
      );
    }

    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text(
          'Cognitive Health',
          style: CaretakerTextStyles.header,
        ),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _dataService.calculateDomainScoresByDifficulty(
          _elderlyUserId,
          _selectedDifficulty,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final domainData =
              snapshot.data ??
              {
                'attentionScore': 0.0,
                'processingSpeedScore': 0.0,
                'sessionsCount': 0,
              };

          final attentionScore = domainData['attentionScore'] as double;
          final processingSpeedScore =
              domainData['processingSpeedScore'] as double;
          final sessionsCount = domainData['sessionsCount'] as int;

          return SingleChildScrollView(
            padding: CaretakerLayout.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Difficulty Filter Dropdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CaretakerColors.cardWhite,
                    borderRadius: CaretakerLayout.cardRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_list,
                        color: CaretakerColors.primaryGreen,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Difficulty Level:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButton<int?>(
                          value: _selectedDifficulty,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Text('All Levels'),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: Text('Easy (2.0s intervals)'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('Medium (1.8s intervals)'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('Hard (1.4s intervals)'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedDifficulty = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildOverviewCard(
                  attentionScore,
                  processingSpeedScore,
                  sessionsCount,
                ),
                const SizedBox(height: 20),
                _buildDomainScoresCard(
                  attentionScore,
                  processingSpeedScore,
                  sessionsCount,
                ),
                const SizedBox(height: 20),
                _buildDetailedMetricsCard(),
                const SizedBox(height: 20),
                _buildTrendsChartCard(),
                const SizedBox(height: 20),
                _buildReminiscenceCard(),
                const SizedBox(height: 20),
                _buildAiRecommendations(attentionScore, processingSpeedScore),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    double attentionScore,
    double processingSpeedScore,
    int sessionsCount,
  ) {
    final overallScore = ((attentionScore + processingSpeedScore) / 2).round();
    final Color scoreColor =
        overallScore >= 75
            ? Colors.green
            : overallScore >= 50
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CaretakerColors.primaryGreen.withValues(alpha: 0.1),
            CaretakerColors.highlightBlue.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: CaretakerLayout.cardRadius,
        border: Border.all(
          color: CaretakerColors.primaryGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '$overallScore',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
                Text(
                  'Score',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Cognitive Health',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: CaretakerColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on $sessionsCount game sessions',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.videogame_asset,
                      size: 14,
                      color: CaretakerColors.primaryGreen,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Color Tap Game',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CaretakerColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainScoresCard(
    double attentionScore,
    double processingSpeedScore,
    int sessionsCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cognitive Domains',
            style: CaretakerTextStyles.sectionTitle,
          ),
          const SizedBox(height: 8),
          Text(
            sessionsCount > 0
                ? 'Based on $sessionsCount game sessions'
                : 'No data available yet',
            style: const TextStyle(
              fontSize: 11,
              color: CaretakerColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),

          if (sessionsCount > 0) ...[
            // Attention Domain
            _buildDomainRow(
              'Attention',
              'Focus and accuracy in identifying correct targets',
              attentionScore,
              CaretakerColors.primaryGreen,
              Icons.center_focus_strong,
            ),
            const SizedBox(height: 20),

            // Processing Speed Domain
            _buildDomainRow(
              'Processing Speed',
              'Speed of response and reaction time',
              processingSpeedScore,
              CaretakerColors.highlightBlue,
              Icons.speed,
            ),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.videogame_asset_off,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No game data yet. Play Color Tap to see domain scores!',
                      style: TextStyle(
                        color: CaretakerColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
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
                    label,
                    style: const TextStyle(
                      fontSize: 15,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
              ),
              child: Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade200,
            color: color,
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetricsCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _dataService.getDetailedGameMetrics(_elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading metrics...");
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final metrics = snapshot.data!;
        final accuracy = metrics['accuracy'] as double;
        final avgReactionTime = metrics['avgReactionTime'] as double;
        final correctTaps = metrics['totalCorrectTaps'] as int;
        final falseTaps = metrics['totalFalseTaps'] as int;
        final missedTaps = metrics['totalMissedTaps'] as int;

        if (correctTaps == 0 && falseTaps == 0 && missedTaps == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CaretakerColors.cardWhite,
            borderRadius: CaretakerLayout.cardRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance Metrics',
                style: CaretakerTextStyles.sectionTitle,
              ),
              const SizedBox(height: 20),

              // Accuracy and Reaction Time
              Row(
                children: [
                  Expanded(
                    child: _buildMetricBox(
                      'Overall Accuracy',
                      '${accuracy.toStringAsFixed(1)}%',
                      Icons.star_rate, // Changed from Icons.target
                      Colors.purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricBox(
                      'Avg Reaction Time',
                      '${avgReactionTime.toStringAsFixed(3)}s',
                      Icons.timer,
                      Colors.blue,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Tap Breakdown
              _buildTapBreakdown(
                'Correct',
                correctTaps,
                Colors.green,
                Icons.check_circle,
              ),
              const SizedBox(height: 12),
              _buildTapBreakdown('False', falseTaps, Colors.red, Icons.cancel),
              const SizedBox(height: 12),
              _buildTapBreakdown(
                'Missed',
                missedTaps,
                Colors.orange,
                Icons.remove_circle_outline,
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
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
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
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTapBreakdown(
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label Taps:',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendsChartCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _dataService.getColorTapScoreHistory(_elderlyUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard("Loading trends...");
        }

        final history = snapshot.data ?? [];

        if (history.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CaretakerColors.cardWhite,
              borderRadius: CaretakerLayout.cardRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Score Trends',
                  style: CaretakerTextStyles.sectionTitle,
                ),
                const SizedBox(height: 40),
                Icon(Icons.show_chart, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                const Text(
                  'Play more games to see trend chart',
                  style: TextStyle(
                    color: CaretakerColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CaretakerColors.cardWhite,
            borderRadius: CaretakerLayout.cardRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
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
                  const Text(
                    'Score Trends',
                    style: CaretakerTextStyles.sectionTitle,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CaretakerColors.lightGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Last ${history.length} Games',
                      style: const TextStyle(
                        color: CaretakerColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          interval: 25,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: CaretakerColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < history.length) {
                              return Text(
                                'G${value.toInt() + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: CaretakerColors.textSecondary,
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey.shade300),
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    minX: 0,
                    maxX: (history.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      // Attention line
                      LineChartBarData(
                        spots:
                            history.asMap().entries.map((entry) {
                              return FlSpot(
                                entry.key.toDouble(),
                                (entry.value['attention'] as double).toDouble(),
                              );
                            }).toList(),
                        isCurved: true,
                        color: CaretakerColors.primaryGreen,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                      // Processing Speed line
                      LineChartBarData(
                        spots:
                            history.asMap().entries.map((entry) {
                              return FlSpot(
                                entry.key.toDouble(),
                                (entry.value['processing'] as double)
                                    .toDouble(),
                              );
                            }).toList(),
                        isCurved: true,
                        color: CaretakerColors.highlightBlue,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Attention', CaretakerColors.primaryGreen),
                  const SizedBox(width: 20),
                  _buildLegendItem(
                    'Processing Speed',
                    CaretakerColors.highlightBlue,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: CaretakerColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildReminiscenceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.lightGreen,
        borderRadius: CaretakerLayout.cardRadius,
        border: Border.all(
          color: CaretakerColors.primaryGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.psychology, color: CaretakerColors.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Reminiscence Therapy Insights',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CaretakerColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Cognitive activities help maintain mental sharpness. Continue with regular game sessions and varied activities.',
            style: TextStyle(color: CaretakerColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip('Daily Activities'),
              _buildChip('Memory Games'),
              _buildChip('Social Interaction'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: CaretakerColors.primaryGreen,
        ),
      ),
      backgroundColor: Colors.white,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildAiRecommendations(
    double attentionScore,
    double processingSpeedScore,
  ) {
    // Generate dynamic recommendations based on scores
    List<Map<String, dynamic>> recommendations = [];

    if (attentionScore < 60) {
      recommendations.add({
        'text':
            'Attention score is low. Increase focus-based activities and minimize distractions during games.',
        'color': CaretakerColors.errorRed,
      });
    } else if (attentionScore < 75) {
      recommendations.add({
        'text':
            'Good attention levels! Try increasing game difficulty to further improve focus.',
        'color': CaretakerColors.warningAmber,
      });
    } else {
      recommendations.add({
        'text': 'Excellent attention performance! Continue current activities.',
        'color': CaretakerColors.successGreen,
      });
    }

    if (processingSpeedScore < 60) {
      recommendations.add({
        'text':
            'Processing speed needs improvement. Practice regularly to enhance reaction times.',
        'color': CaretakerColors.errorRed,
      });
    } else if (processingSpeedScore < 75) {
      recommendations.add({
        'text':
            'Processing speed is improving. Maintain consistent practice sessions.',
        'color': CaretakerColors.warningAmber,
      });
    } else {
      recommendations.add({
        'text': 'Outstanding processing speed! Reaction times are excellent.',
        'color': CaretakerColors.successGreen,
      });
    }

    recommendations.add({
      'text':
          'Play Color Tap daily for 10-15 minutes to maintain cognitive health.',
      'color': CaretakerColors.highlightBlue,
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.smart_toy, color: CaretakerColors.highlightBlue),
              SizedBox(width: 8),
              Text(
                'AI Recommendations',
                style: CaretakerTextStyles.sectionTitle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recommendations
              .map(
                (rec) => _buildRecommendationItem(
                  rec['text'] as String,
                  rec['color'] as Color,
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(String text, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle, size: 8, color: dotColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

