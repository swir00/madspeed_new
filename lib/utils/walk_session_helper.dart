import 'package:madspeed_app/models/walk_session_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalkSessionHelper {
  static const _key = 'walk_sessions';

  /// Zapisuje pojedynczą sesję spaceru, dodając ją do istniejącej listy.
  static Future<void> saveWalkSession(WalkSession session) async {
    final List<WalkSession> sessions = await loadWalkSessions();
    sessions.add(session);
    sessions.sort((a, b) => b.date.compareTo(a.date)); // Sortuj od najnowszych
    await _saveList(sessions);
  }

  /// Wczytuje wszystkie zapisane sesje spacerów.
  static Future<List<WalkSession>> loadWalkSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString(_key);
    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      return WalkSession.decode(sessionsJson);
    }
    return [];
  }

  /// Zapisuje całą listę sesji, nadpisując istniejące dane.
  static Future<void> _saveList(List<WalkSession> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = WalkSession.encode(sessions);
    await prefs.setString(_key, encodedData);
  }

  /// Usuwa sesję spaceru z listy na podstawie jej ID.
  static Future<void> deleteWalkSession(String sessionId) async {
    final List<WalkSession> sessions = await loadWalkSessions();
    sessions.removeWhere((session) => session.id == sessionId);
    await _saveList(sessions);
  }
}