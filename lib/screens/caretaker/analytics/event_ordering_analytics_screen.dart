import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/caretaker_data_service.dart';

class EventOrderingAnalyticsScreen extends StatelessWidget {
  final String userId;
  const EventOrderingAnalyticsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final dataService = CaretakerDataService();

    return Scaffold(
      appBar: AppBar(title: const Text("Event Ordering Analytics")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: dataService.getEventOrderingAnalytics(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final data = snapshot.data ?? {};
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final sessions = data['sessions'] as List<dynamic>? ?? [];

          final execScore = stats['executiveFunctionScore'] as int? ?? 0;
          final memScore = stats['memoryScore'] as int? ?? 0;
          final totalSessions = stats['totalSessions'] as int? ?? 0;

          final improvement = _calculateImprovement(sessions);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard("Exec Function", "$execScore", Colors.orange, improvement['exec'])),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard("Memory", "$memScore", Colors.purple, improvement['memory'])),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard("Sessions", "$totalSessions", Colors.teal, null)),
                  ],
                ),
                const SizedBox(height: 24),

                const Text("Cognitive Domain Trends", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("Track improvements or dips over sessions", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 12),

                if (sessions.length >= 2)
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: _buildCognitiveSpots(sessions, 'executive_function'),
                            isCurved: true, color: Colors.orange, barWidth: 2.5,
                            dotData: FlDotData(show: sessions.length <= 10),
                            belowBarData: BarAreaData(show: true, color: Colors.orange.withValues(alpha: 0.08)),
                          ),
                          LineChartBarData(
                            spots: _buildCognitiveSpots(sessions, 'memory'),
                            isCurved: true, color: Colors.purple, barWidth: 2.5,
                            dotData: FlDotData(show: sessions.length <= 10),
                            belowBarData: BarAreaData(show: true, color: Colors.purple.withValues(alpha: 0.08)),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => Text('S${val.toInt() + 1}', style: const TextStyle(fontSize: 10)), interval: sessions.length > 10 ? (sessions.length / 5).ceilToDouble() : 1)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text('${val.toInt()}', style: const TextStyle(fontSize: 10)))),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                        minY: 0, maxY: 100,
                        gridData: FlGridData(show: true, horizontalInterval: 25, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                      ),
                    ),
                  )
                else
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("Play at least 2 sessions to see trends"))),

                if (sessions.length >= 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem("Executive Function", Colors.orange),
                        const SizedBox(width: 20),
                        _buildLegendItem("Memory", Colors.purple),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),
                const Text("Score Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (sessions.length >= 2)
                  SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(sessions.length, (i) => FlSpot(i.toDouble(), ((sessions[i]['score'] as num?) ?? 0).toDouble())),
                            isCurved: true, color: Colors.teal, barWidth: 2.5,
                            dotData: FlDotData(show: sessions.length <= 10),
                            belowBarData: BarAreaData(show: true, color: Colors.teal.withValues(alpha: 0.1)),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (val, meta) => Text('S${val.toInt() + 1}', style: const TextStyle(fontSize: 10)), interval: sessions.length > 10 ? (sessions.length / 5).ceilToDouble() : 1)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35, getTitlesWidget: (val, meta) => Text('${val.toInt()}', style: const TextStyle(fontSize: 10)))),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                        gridData: FlGridData(show: true, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                      ),
                    ),
                  )
                else
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Not enough data for score trend"))),

                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDetailRow("Executive Function", "$execScore / 100", improvement['exec']),
                        const Divider(),
                        _buildDetailRow("Memory Score", "$memScore / 100", improvement['memory']),
                        const Divider(),
                        _buildDetailRow("Total Sessions", "$totalSessions", null),
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

  List<FlSpot> _buildCognitiveSpots(List<dynamic> sessions, String domain) {
    return List.generate(sessions.length, (i) {
      final c = sessions[i]['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      return FlSpot(i.toDouble(), ((c[domain] as num?) ?? 0).toDouble());
    });
  }

  Map<String, double?> _calculateImprovement(List<dynamic> sessions) {
    if (sessions.length < 4) return {'exec': null, 'memory': null};
    int rc = (sessions.length * 0.3).ceil().clamp(1, 5);
    double rE = 0, pE = 0, rM = 0, pM = 0;
    for (int i = sessions.length - rc; i < sessions.length; i++) {
      final c = sessions[i]['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      rE += (c['executive_function'] as num?)?.toDouble() ?? 0;
      rM += (c['memory'] as num?)?.toDouble() ?? 0;
    }
    int ps = (sessions.length - rc - rc).clamp(0, sessions.length);
    int apc = (sessions.length - rc) - ps;
    if (apc <= 0) return {'exec': null, 'memory': null};
    for (int i = ps; i < sessions.length - rc; i++) {
      final c = sessions[i]['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      pE += (c['executive_function'] as num?)?.toDouble() ?? 0;
      pM += (c['memory'] as num?)?.toDouble() ?? 0;
    }
    return {'exec': (rE / rc) - (pE / apc), 'memory': (rM / rc) - (pM / apc)};
  }

  Widget _buildSummaryCard(String title, String value, Color color, double? change) {
    String arrow = '';
    if (change != null) { if (change > 2) arrow = ' ↑'; else if (change < -2) arrow = ' ↓'; else arrow = ' →'; }
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(padding: const EdgeInsets.all(12.0), child: Column(children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('$value$arrow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ])),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    ]);
  }

  Widget _buildDetailRow(String label, String value, double? change) {
    String indicator = ''; Color ic = Colors.grey;
    if (change != null) { if (change > 2) { indicator = '↑ Improving'; ic = Colors.green; } else if (change < -2) { indicator = '↓ Declining'; ic = Colors.red; } else { indicator = '→ Stable'; ic = Colors.blue; } }
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        if (indicator.isNotEmpty) Text(indicator, style: TextStyle(fontSize: 11, color: ic)),
      ]),
    ]);
  }
}
