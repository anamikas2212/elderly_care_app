import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/caretaker_data_service.dart';

class ColorTapAnalyticsScreen extends StatelessWidget {
  final String userId;
  const ColorTapAnalyticsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final dataService = CaretakerDataService();

    return Scaffold(
      appBar: AppBar(title: const Text("Color Tap Analytics")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: dataService.getColorTapAnalytics(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data ?? {};
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final sessions = data['sessions'] as List<dynamic>? ?? [];

          final attentionScore = stats['attentionScore'] as int? ?? 0;
          final processingScore = stats['processingSpeedScore'] as int? ?? 0;
          final totalSessions = stats['totalSessions'] as int? ?? 0;
          final avgAccuracy = ((stats['averageAccuracy'] as num? ?? 0) * 100).toStringAsFixed(1);
          final avgReaction = (stats['averageReactionTime'] as num? ?? 0).toStringAsFixed(2);



          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard("Attention", "$attentionScore", Colors.blue)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard("Processing Speed", "$processingScore", Colors.orange)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard("Sessions", "$totalSessions", Colors.teal)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text("Accuracy Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (sessions.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(sessions.length, (i) {
                              final s = sessions[sessions.length - 1 - i];
                              return FlSpot(i.toDouble(), ((s['metrics']['accuracy'] as num?) ?? 0) * 100);
                            }),
                            isCurved: true,
                            color: Colors.blue,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                        minY: 0, maxY: 100,
                      ),
                    ),
                  )
                else
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("No session data yet"))),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailRow("Average Accuracy", "$avgAccuracy%"),
                        const Divider(),
                        _buildDetailRow("Avg Reaction Time", "${avgReaction}s"),
                        const Divider(),
                        _buildDetailRow("Attention Score", "$attentionScore / 100"),
                        const Divider(),
                        _buildDetailRow("Processing Speed Score", "$processingScore / 100"),
                        const Divider(),
                        _buildDetailRow("Total Sessions", "$totalSessions"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
