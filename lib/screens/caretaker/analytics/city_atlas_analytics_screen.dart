import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../services/caretaker_data_service.dart';

class CityAtlasAnalyticsScreen extends StatelessWidget {
  final String userId;
  const CityAtlasAnalyticsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final dataService = CaretakerDataService();

    return Scaffold(
      appBar: AppBar(title: const Text("City Atlas Analytics")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: dataService.getCityAtlasAnalytics(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final data = snapshot.data ?? {};
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          final sessions = data['sessions'] as List<dynamic>? ?? [];

          final execScore = stats['executiveFunctionScore'] as int? ?? 0;
          final memScore = stats['memoryScore'] as int? ?? 0;
          final totalSessions = stats['totalSessions'] as int? ?? 0;

          // Calculate improvement indicators
          final improvement = _calculateImprovement(sessions);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSummaryCard("Exec Function", "$execScore", Colors.indigo, improvement['exec'])),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard("Memory", "$memScore", Colors.purple, improvement['memory'])),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSummaryCard("Sessions", "$totalSessions", Colors.teal, null)),
                  ],
                ),
                const SizedBox(height: 24),

                // Cognitive Domain Trends
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
                          // Executive Function line
                          LineChartBarData(
                            spots: _buildCognitiveSpots(sessions, 'executive_function'),
                            isCurved: true,
                            color: Colors.indigo,
                            barWidth: 2.5,
                            dotData: FlDotData(show: sessions.length <= 10),
                            belowBarData: BarAreaData(show: true, color: Colors.indigo.withValues(alpha: 0.08)),
                          ),
                          // Memory line
                          LineChartBarData(
                            spots: _buildCognitiveSpots(sessions, 'memory'),
                            isCurved: true,
                            color: Colors.purple,
                            barWidth: 2.5,
                            dotData: FlDotData(show: sessions.length <= 10),
                            belowBarData: BarAreaData(show: true, color: Colors.purple.withValues(alpha: 0.08)),
                          ),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) => Text('S${val.toInt() + 1}', style: const TextStyle(fontSize: 10)),
                            interval: sessions.length > 10 ? (sessions.length / 5).ceilToDouble() : 1,
                          )),
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

                // Legend
                if (sessions.length >= 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem("Executive Function", Colors.indigo),
                        const SizedBox(width: 20),
                        _buildLegendItem("Memory", Colors.purple),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Score Trend
                const Text("Score Trend", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (sessions.length >= 2)
                  SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(sessions.length, (i) {
                              return FlSpot(i.toDouble(), ((sessions[i]['score'] as num?) ?? 0).toDouble());
                            }),
                            isCurved: true,
                            color: Colors.teal,
                            barWidth: 2.5,
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
                // Details card
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
      final cognitive = sessions[i]['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      return FlSpot(i.toDouble(), ((cognitive[domain] as num?) ?? 0).toDouble());
    });
  }

  Map<String, double?> _calculateImprovement(List<dynamic> sessions) {
    if (sessions.length < 4) return {'exec': null, 'memory': null};
    int recentCount = (sessions.length * 0.3).ceil().clamp(1, 5);
    int prevCount = recentCount;

    double recentExec = 0, prevExec = 0, recentMem = 0, prevMem = 0;
    for (int i = sessions.length - recentCount; i < sessions.length; i++) {
      final c = sessions[i]['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      recentExec += (c['executive_function'] as num?)?.toDouble() ?? 0;
      recentMem += (c['memory'] as num?)?.toDouble() ?? 0;
    }
    int prevStart = (sessions.length - recentCount - prevCount).clamp(0, sessions.length);
    for (int i = prevStart; i < sessions.length - recentCount; i++) {
      final c = sessions[i]['cognitive_contributions'] as Map<String, dynamic>? ?? {};
      prevExec += (c['executive_function'] as num?)?.toDouble() ?? 0;
      prevMem += (c['memory'] as num?)?.toDouble() ?? 0;
    }
    int actualPrevCount = (sessions.length - recentCount) - prevStart;
    if (actualPrevCount <= 0) return {'exec': null, 'memory': null};

    return {
      'exec': (recentExec / recentCount) - (prevExec / actualPrevCount),
      'memory': (recentMem / recentCount) - (prevMem / actualPrevCount),
    };
  }

  Widget _buildSummaryCard(String title, String value, Color color, double? change) {
    String arrow = '';
    if (change != null) {
      if (change > 2) arrow = ' ↑';
      else if (change < -2) arrow = ' ↓';
      else arrow = ' →';
    }
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('$value$arrow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, double? change) {
    String indicator = '';
    Color indicatorColor = Colors.grey;
    if (change != null) {
      if (change > 2) { indicator = '↑ Improving'; indicatorColor = Colors.green; }
      else if (change < -2) { indicator = '↓ Declining'; indicatorColor = Colors.red; }
      else { indicator = '→ Stable'; indicatorColor = Colors.blue; }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (indicator.isNotEmpty) Text(indicator, style: TextStyle(fontSize: 11, color: indicatorColor)),
          ],
        ),
      ],
    );
  }
}
