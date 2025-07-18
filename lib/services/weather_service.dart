// lib/services/weather_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Dla LatLng

class WeatherService {
  // UWAGA: W prawdziwej aplikacji klucz API powinien być przechowywany bezpieczniej,
  // np. w zmiennych środowiskowych, a nie bezpośrednio w kodzie źródłowym.
  final String _apiKey = '98eda26ab099f43df027f2cffe1e0ac1'; // Twój klucz API
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<Map<String, dynamic>?> fetchWeather(LatLng location) async {
    final url = Uri.parse(
        '$_baseUrl?lat=${location.latitude}&lon=${location.longitude}&appid=$_apiKey&units=metric&lang=pl'); // units=metric dla stopni Celsjusza, lang=pl dla polskiego opisu

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'temperature': data['main']['temp'] as double,
          'feels_like': data['main']['feels_like'] as double,
          'humidity': data['main']['humidity'] as int,
          'wind_speed': data['wind']['speed'] as double, // m/s
          'description': data['weather'][0]['description'] as String,
          'icon': data['weather'][0]['icon'] as String,
        };
      } else {
        // Obsługa błędów API
        print('Błąd pobierania pogody: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Wyjątek podczas pobierania pogody: $e');
      return null;
    }
  }

  // Metoda do pobierania ikony pogody
  String getWeatherIconUrl(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
}
