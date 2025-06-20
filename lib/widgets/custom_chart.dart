import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:madspeed_app/models/log_data_point.dart';

class CustomChart extends StatelessWidget {
  final List<LogDataPoint> logData;

  const CustomChart({super.key, required this.logData});

  @override
  Widget build(BuildContext context) {
    if (logData.isEmpty) {
      return const Center(
        child: Text('Brak danych do wyświetlenia wykresu.'),
      );
    }

    // Prepare data for the LineChart
    // X-axis: Distance (converted to meters for plotting if needed, but current data is already in meters)
    // Y-axis: Speed (km/h)

    // Find min/max values for scaling the chart
    double minX = logData.map((point) => point.distance).reduce((a, b) => a < b ? a : b);
    double maxX = logData.map((point) => point.distance).reduce((a, b) => a > b ? a : b);
    double minY = logData.map((point) => point.speed).reduce((a, b) => a < b ? a : b);
    double maxY = logData.map((point) => point.speed).reduce((a, b) => a > b ? a : b);

    // Add some padding to min/max Y for better visual
    if (minY > 0) minY = 0;
    maxY = maxY * 1.1; // 10% higher than max speed

    // Create FlSpot list
    List<FlSpot> spots = logData.asMap().entries.map((entry) {
      // Use distance for X, speed for Y
      return FlSpot(entry.value.distance, entry.value.speed);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                // Display distance in meters, or convert to KM for larger distances
                String text;
                if (value >= 1000) {
                  text = '${(value / 1000).toStringAsFixed(1)}km';
                } else {
                  text = '${value.toStringAsFixed(0)}m';
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(text, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text('${value.toStringAsFixed(0)}km/h', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                Colors.blueAccent.withOpacity(0.4),
                Colors.blueAccent,
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false), // Hide individual dots
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blueAccent.withOpacity(0.3),
                  Colors.blueAccent.withOpacity(0.0),
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ],
        // Tooltip (optional, for showing data on touch)
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            // For fl_chart 0.68.0, use getTooltipColor to set the tooltip background.
            getTooltipColor: (LineBarSpot touchedSpot) => Colors.blueAccent.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final textStyle = const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                return LineTooltipItem(
                  'Dystans: ${touchedSpot.x.toStringAsFixed(1)}m\nPrędkość: ${touchedSpot.y.toStringAsFixed(1)}km/h',
                  textStyle,
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}
