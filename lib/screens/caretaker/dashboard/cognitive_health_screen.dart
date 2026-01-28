
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/caretaker_theme.dart';
import '../../../services/caretaker_data_service.dart';

class CognitiveHealthScreen extends StatelessWidget {
  const CognitiveHealthScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine userId (in real app, passed via constructor or provider)
    const String userId = "Grandpa Joe"; // Placeholder or use passed ID
    final CaretakerDataService dataService = CaretakerDataService();

    return Scaffold(
      backgroundColor: CaretakerColors.background,
      appBar: AppBar(
        title: const Text('Cognitive Health', style: CaretakerTextStyles.header),
        backgroundColor: CaretakerColors.cardWhite,
        iconTheme: const IconThemeData(color: CaretakerColors.textPrimary),
        elevation: 0,
      ),
      body: StreamBuilder<Map<String, double>>(
        stream: dataService.getDomainScores(userId),
        builder: (context, snapshot) {
          final scores = snapshot.data ?? {
            'Attention': 0.0,
            'Processing Speed': 0.0,
          };

          return SingleChildScrollView(
            padding: CaretakerLayout.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDomainScoresList(scores),
                const SizedBox(height: 24),
                _buildTrendsChartCard(dataService, userId),
                const SizedBox(height: 20),
                _buildReminiscenceCard(),
                const SizedBox(height: 20),
                _buildAiRecommendations(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDomainScoresList(Map<String, double> scores) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Color Tap Game - Cognitive Domains', style: CaretakerTextStyles.sectionTitle),
          const SizedBox(height: 8),
          const Text(
            'Scores calculated from latest game session',
            style: TextStyle(fontSize: 11, color: CaretakerColors.textSecondary, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          
          // Only show domains if we have data
          if (scores['Attention'] != null && scores['Attention']! > 0) ...[
            _buildDomainRow(
              'Attention', 
              scores['Attention'] ?? 0, 
              CaretakerColors.primaryGreen,
              'Accuracy: ${(scores['Attention'] ?? 0).toInt()}%'
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 140, bottom: 12),
              child: Text(
                'Correct taps ÷ Total color changes',
                style: TextStyle(fontSize: 10, color: CaretakerColors.textSecondary),
              ),
            ),
          ],
          
          if (scores['Processing Speed'] != null && scores['Processing Speed']! > 0) ...[
            _buildDomainRow(
              'Processing Speed', 
              scores['Processing Speed'] ?? 0, 
              CaretakerColors.highlightBlue,
              'Reaction: ${_getReactionTimeLabel(scores['Processing Speed'] ?? 0)}'
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 140, bottom: 12),
              child: Text(
                'Based on average reaction time',
                style: TextStyle(fontSize: 10, color: CaretakerColors.textSecondary),
              ),
            ),
          ],
          
          // Show message if no data
          if ((scores['Attention'] ?? 0) == 0 && (scores['Processing Speed'] ?? 0) == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No game data yet. Play Color Tap to see scores!',
                  style: TextStyle(color: CaretakerColors.textSecondary, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  String _getReactionTimeLabel(double score) {
    // Reverse calculate approximate reaction time from score
    // score = (2.0 - reactionTime) / 1.5 * 100
    // reactionTime = 2.0 - (score * 1.5 / 100)
    double reactionTime = 2.0 - (score * 1.5 / 100);
    return '${reactionTime.toStringAsFixed(2)}s';
  }

  Widget _buildDomainRow(String label, double score, Color color, String metricLabel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: CaretakerColors.dividerGrey,
                color: color,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              metricLabel,
              style: const TextStyle(
                color: CaretakerColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsChartCard(CaretakerDataService dataService, String userId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: dataService.getColorTapScoreHistory(userId),
      builder: (context, snapshot) {
        final history = snapshot.data ?? [];
        
        if (history.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CaretakerColors.cardWhite,
              borderRadius: CaretakerLayout.cardRadius,
            ),
            child: Column(
              children: const [
                Text('Score Trends', style: CaretakerTextStyles.sectionTitle),
                SizedBox(height: 40),
                Text(
                  'Play more games to see trend chart',
                  style: TextStyle(color: CaretakerColors.textSecondary, fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 40),
              ],
            ),
          );
        }
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CaretakerColors.cardWhite,
            borderRadius: CaretakerLayout.cardRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Score Trends', style: CaretakerTextStyles.sectionTitle),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                height: 180,
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
                              style: const TextStyle(fontSize: 10, color: CaretakerColors.textSecondary),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < history.length) {
                              return Text(
                                'G${value.toInt() + 1}',
                                style: const TextStyle(fontSize: 10, color: CaretakerColors.textSecondary),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                        spots: history.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value['attention']);
                        }).toList(),
                        isCurved: true,
                        color: CaretakerColors.primaryGreen,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                      // Processing Speed line
                      LineChartBarData(
                        spots: history.asMap().entries.map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value['processing']);
                        }).toList(),
                        isCurved: true,
                        color: CaretakerColors.highlightBlue,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
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
                  _buildLegendItem('Processing Speed', CaretakerColors.highlightBlue),
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
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: CaretakerColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildReminiscenceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.lightGreen,
        borderRadius: CaretakerLayout.cardRadius,
        border: Border.all(color: CaretakerColors.primaryGreen.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.psychology, color: CaretakerColors.primaryGreen),
              SizedBox(width: 8),
              Text('Reminiscence Therapy Insights', style: TextStyle(fontWeight: FontWeight.bold, color: CaretakerColors.primaryGreen)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Responds best to photos from the 1970s and music from college years.',
            style: TextStyle(color: CaretakerColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _buildChip('Family Photos'),
              _buildChip('Jazz Music'),
              _buildChip('Cooking Memories'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12, color: CaretakerColors.primaryGreen)),
      backgroundColor: Colors.white,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildAiRecommendations() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CaretakerColors.cardWhite,
        borderRadius: CaretakerLayout.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.smart_toy, color: CaretakerColors.highlightBlue),
              SizedBox(width: 8),
              Text('AI Recommendations', style: CaretakerTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecommendationItem('Increase memory exercises by 10 mins', CaretakerColors.warningAmber),
          _buildRecommendationItem('Try new puzzles to challenge distinct domains', CaretakerColors.warningAmber),
          _buildRecommendationItem('Continue language activities, great progress!', CaretakerColors.successGreen),
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
