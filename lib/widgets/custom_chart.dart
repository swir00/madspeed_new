import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:madspeed_app/models/log_data_point.dart';
import 'dart:math'; // Potrzebne do funkcji log() i pow()

class CustomChart extends StatelessWidget {
  final List<LogDataPoint> logData; // Zmieniono nazwę na logData dla spójności
  final Color lineColor; // Nowy parametr koloru linii

  const CustomChart({
    super.key,
    required this.logData,
    this.lineColor = Colors.blueAccent, // Domyślny kolor linii
  });

  // Funkcja przygotowująca dane dla wykresu (prędkość vs dystans)
  List<FlSpot> _getSpeedVsDistanceSpots(List<LogDataPoint> rawData) {
    if (rawData.isEmpty) {
      return [];
    }

    List<FlSpot> spots = [];
    double lastValidDistance = 0.0; // Śledzi ostatni prawidłowy (rosnący) dystans

    // Dodaj pierwszy punkt. Zaczynamy od 0 dystansu na osi X dla spójności wykresu.
    if (rawData.isNotEmpty) {
      // Upewniamy się, że początkowa prędkość też nie jest ujemna
      spots.add(FlSpot(0.0, rawData.first.speed < 0 ? 0.0 : rawData.first.speed));
    }

    for (int i = 0; i < rawData.length; i++) {
      final dataPoint = rawData[i];
      double currentDistanceMeters = dataPoint.distance;
      double currentSpeed = dataPoint.speed;

      // KLUCZOWA POPRAWKA 1: Zapewnienie monotonicznego wzrostu dystansu
      // Jeśli bieżący dystans jest mniejszy niż poprzedni, użyj poprzedniego
      if (currentDistanceMeters < lastValidDistance) {
        currentDistanceMeters = lastValidDistance;
      } else {
        lastValidDistance = currentDistanceMeters;
      }

      // KLUCZOWA POPRAWKA 2: Zapewnienie, że prędkość nigdy nie jest ujemna
      if (currentSpeed < 0) {
        // Jeśli prędkość jest ujemna (z błędu GPS), ustaw na 0
        currentSpeed = 0.0;
      }
      // Opcjonalna filtracja: Wygładzanie bardzo niskich prędkości do zera
      else if (currentSpeed < 0.5) {
        // Jeśli prędkość jest bardzo niska (szum), ustaw na 0
        currentSpeed = 0.0;
      }

      spots.add(FlSpot(currentDistanceMeters, currentSpeed));
    }

    // Usunięcie duplikatów punktów na tej samej pozycji X, biorąc ostatnią wartość Y
    // Dodatkowo sortujemy punkty, aby upewnić się, że są w prawidłowej kolejności dla wykresu liniowego
    spots.sort((a, b) => a.x.compareTo(b.x));
    List<FlSpot> uniqueSpots = [];
    if (spots.isNotEmpty) {
      uniqueSpots.add(spots.first);
      for (int i = 1; i < spots.length; i++) {
        if (spots[i].x != uniqueSpots.last.x) {
          uniqueSpots.add(spots[i]);
        } else {
          uniqueSpots.last = spots[i]; // Zastąp, jeśli X jest takie samo (weź ostatnią wartość Y)
        }
      }
    }

    return uniqueSpots;
  }

  // Helper do formatowania etykiet osi X (dystans)
  String _formatDistanceLabel(double distance) {
    if (distance >= 1000) {
      final km = distance / 1000;
      // Użyj toStringAsFixed(1) i usuń .0 jeśli nie ma części ułamkowej
      return '${km.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}km';
    }
    return '${distance.toInt()}m';
  }

  // Helper do obliczania interwału na osi X
  double _calculateInterval(double maxDistance) {
    if (maxDistance <= 0) return 100; // Domyślny interwał dla bardzo małego dystansu
    // Chcemy mieć około 5-6 etykiet na osi
    final double roughInterval = maxDistance / 5;
    // Zaokrąglij do najbliższej "ładnej" liczby (np. 10, 25, 50, 100, 250, 500)
    final double magnitude = pow(10, (log(roughInterval) / ln10).floor()).toDouble();
    final double residual = roughInterval / magnitude;
    if (residual > 5) return 10 * magnitude;
    if (residual > 2) return 5 * magnitude;
    if (residual > 1) return 2 * magnitude;
    return magnitude;
  }

  @override
  Widget build(BuildContext context) {
    final List<FlSpot> spots = _getSpeedVsDistanceSpots(logData);

    if (spots.isEmpty) {
      return const Center(
        child: Text(
          'Brak danych do wyświetlenia wykresu.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    double minX = 0;
    // Znajdź maksymalny X spośród punktów, aby uniknąć problemów z nieposortowaną listą
    double maxX = spots.isNotEmpty
        ? spots.map((spot) => spot.x).reduce((a, b) => a > b ? a : b)
        : 1.0;
    double minY = 0;
    // Znajdź maksymalny Y spośród punktów
    double maxY = spots.isNotEmpty
        ? spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b)
        : 1.0;

    // Dodanie marginesów do osi i zapewnienie minimalnego zakresu Y
    maxX = maxX * 1.05; // 5% margines po prawej
    maxY = maxY * 1.15; // 15% margines u góry
    
    if (maxY < 10.0) maxY = 10.0; // Zapewnij minimalną wartość dla maxY, np. 10 km/h
    if (maxX < 10.0) maxX = 10.0; // Zapewnij minimalną wartość dla maxX, np. 10 m

    final double xInterval = _calculateInterval(maxX);
    // Interwał dla osi Y, dostosowany dynamicznie do maxY
    final double yInterval = (maxY / 5 < 1) ? 1 : (maxY / 5).roundToDouble();

    return InteractiveViewer(
      boundaryMargin: const EdgeInsets.all(20.0), // Margines wokół wykresu
      minScale: 0.1, // Minimalne powiększenie
      maxScale: 10.0, // Maksymalne powiększenie
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true), // Pokaż siatkę
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: const Text(
                'Dystans', // Zmieniono na 'Dystans' i formatowanie w getTitlesWidget
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: xInterval, // Użycie dynamicznego interwału
                getTitlesWidget: (value, meta) {
                  // Ukryj etykiety min/max, jeśli są wyświetlane przez interval
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(
                      _formatDistanceLabel(value), // Użycie funkcji formatującej
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Prędkość [km/h]',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              axisNameSize: 25,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: yInterval, // Dynamiczny interwał dla osi Y
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor, // Użycie przekazanego koloru linii
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false), // Ukryj kropki danych
              belowBarData: BarAreaData(show: false), // Obszar pod linią
            ),
          ],
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          // Wyłączamy wbudowaną obsługę dotyku w wykresie, aby umożliwić
          // InteractiveViewer przejęcie gestów powiększania i przesuwania.
          // Spowoduje to wyłączenie domyślnych interakcji, takich jak podpowiedzi po dotknięciu.
          lineTouchData: const LineTouchData(enabled: false),
        ),
      ),
    );
  }
}