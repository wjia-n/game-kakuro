import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kakuro/services/settings_service.dart';

/// Regression tests for player-name persistence (2026-10-09 batch-1 audit).
///
/// A sibling game (ludo) stored player names via
/// SharedPreferences.setStringList, which Android backs with an UNORDERED
/// StringSet — scrambling name order on every app restart. MASTER_RULES now
/// bans setStringList for names. Kakuro only has ONE profile name, stored as
/// a single String under `kakuro_profile_name`, so the bug was never present
/// here. These tests pin that down so it stays true.
void main() {
  setUp(() async {
    // In-memory prefs backing; survives across StudySettings instances,
    // simulating an app restart.
    SharedPreferences.setMockInitialValues({});
  });

  test('profile name survives a reload exactly as typed', () async {
    final s = StudySettings();
    await s.load();
    await s.setProfileName('Wajiha');

    // Simulate app restart.
    final restarted = StudySettings();
    await restarted.load();
    expect(restarted.profileName, 'Wajiha');
  });

  test('name is stored as ONE plain string, not a StringList', () async {
    final s = StudySettings();
    await s.load();
    await s.setProfileName('Zara');

    final prefs = await SharedPreferences.getInstance();
    // The only name key is a single string: order-preserving by construction.
    expect(prefs.getString('kakuro_profile_name'), 'Zara');
    final keys = prefs.getKeys();
    for (final k in keys) {
      if (k.toLowerCase().contains('name')) {
        expect(prefs.getStringList(k), isNull,
            reason: 'name keys must never be StringLists (Android StringSet '
                'scrambling risk): $k');
      }
    }
  });

  test('blank name falls back to the default', () async {
    final s = StudySettings();
    await s.load();
    await s.setProfileName('   ');
    expect(s.profileName, 'Scholar');

    final restarted = StudySettings();
    await restarted.load();
    expect(restarted.profileName, 'Scholar');
  });

  test('surrounding whitespace is trimmed once', () async {
    final s = StudySettings();
    await s.load();
    await s.setProfileName('  Ali  ');
    expect(s.profileName, 'Ali');
  });
}
