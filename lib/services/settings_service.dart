import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/chalkboard_themes.dart';

/// Persisted settings + profile + stats for Kakuro. Survives app restarts.
///
/// Stores: player profile name, audio toggles, theme id + custom colorway,
/// default difficulty, mode prefs (timed, mistake limit, error highlight,
/// pencil default), Pro unlock, lifetime stats, daily streak, saved game.
class StudySettings extends ChangeNotifier {
  static const _kName = 'kakuro_profile_name';
  static const _kMusic = 'kakuro_music_on';
  static const _kSfx = 'kakuro_sfx_on';
  static const _kVolume = 'kakuro_volume';
  static const _kTheme = 'kakuro_theme_id';
  static const _kDifficulty = 'kakuro_difficulty'; // 0/1/2
  static const _kPencilDefault = 'kakuro_pencil_default';
  static const _kErrorHighlight = 'kakuro_error_highlight';
  static const _kMistakeLimit = 'kakuro_mistake_limit'; // bool: 3-mistake fail
  static const _kTimedDefault = 'kakuro_timed_default'; // bool
  static const _kShowTimer = 'kakuro_show_timer';
  static const _kIsPro = 'kakuro_is_pro';
  static const _kGames = 'kakuro_games_played';
  static const _kSolved = 'kakuro_solved';
  static const _kBestTime = 'kakuro_best_time_'; // + difficulty index
  static const _kStars = 'kakuro_stars_total';
  static const _kDailyDate = 'kakuro_daily_date';
  static const _kDailyStreak = 'kakuro_daily_streak';
  static const _kSavedGame = 'kakuro_saved_game';
  static const _kCustomPrefix = 'kakuro_custom_';

  String profileName = 'Scholar';
  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String themeId = 'classic-slate';
  int difficulty = 1;
  bool pencilDefault = false;
  bool errorHighlight = true;
  bool mistakeLimit = false;
  bool timedDefault = false;
  bool showTimer = true;
  bool isPro = false;

  int gamesPlayed = 0;
  int solved = 0;
  int starsTotal = 0;
  final List<int> bestTime = [0, 0, 0]; // secs per difficulty, 0 = none
  String dailyDate = '';
  int dailyStreak = 0;

  /// Custom colorway (ARGB ints). Defaults mirror Classic Slate.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'board': 0xFF1E2522,
    'boardDeep': 0xFF171C1A,
    'entry': 0xFF232B27,
    'chalk': 0xFFF4E8B0,
    'chalkDim': 0xFFB9AC7E,
    'accent': 0xFFC98544,
    'frame': 0xFF7A4B20,
    'frameDeep': 0xFF4A2C11,
    'desk': 0xFF12140F,
    'lamp': 0xFFC98544,
    'error': 0xFFD06048,
    'pencil': 0xFF8CA891,
  };

  ChalkThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return ChalkThemeDef(
      id: 'custom',
      name: 'My Chalkboard',
      isPro: false,
      board: c('board'),
      boardDeep: c('boardDeep'),
      entry: c('entry'),
      chalk: c('chalk'),
      chalkDim: c('chalkDim'),
      accent: c('accent'),
      frame: c('frame'),
      frameDeep: c('frameDeep'),
      desk: c('desk'),
      lamp: c('lamp'),
      error: c('error'),
      pencil: c('pencil'),
    );
  }

  ChalkThemeDef get theme =>
      ChalkThemes.byId(themeId, custom: customTheme);

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    final name = p.getString(_kName) ?? '';
    profileName = name.trim().isEmpty ? 'Scholar' : name.trim();
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    themeId = p.getString(_kTheme) ?? 'classic-slate';
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    pencilDefault = p.getBool(_kPencilDefault) ?? false;
    errorHighlight = p.getBool(_kErrorHighlight) ?? true;
    mistakeLimit = p.getBool(_kMistakeLimit) ?? false;
    timedDefault = p.getBool(_kTimedDefault) ?? false;
    showTimer = p.getBool(_kShowTimer) ?? true;
    isPro = p.getBool(_kIsPro) ?? false;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    solved = p.getInt(_kSolved) ?? 0;
    starsTotal = p.getInt(_kStars) ?? 0;
    for (var i = 0; i < 3; i++) {
      bestTime[i] = p.getInt('$_kBestTime$i') ?? 0;
    }
    dailyDate = p.getString(_kDailyDate) ?? '';
    dailyStreak = p.getInt(_kDailyStreak) ?? 0;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kName, profileName);
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kDifficulty, difficulty);
    await p.setBool(_kPencilDefault, pencilDefault);
    await p.setBool(_kErrorHighlight, errorHighlight);
    await p.setBool(_kMistakeLimit, mistakeLimit);
    await p.setBool(_kTimedDefault, timedDefault);
    await p.setBool(_kShowTimer, showTimer);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kSolved, solved);
    await p.setInt(_kStars, starsTotal);
    for (var i = 0; i < 3; i++) {
      await p.setInt('$_kBestTime$i', bestTime[i]);
    }
    await p.setString(_kDailyDate, dailyDate);
    await p.setInt(_kDailyStreak, dailyStreak);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (ChalkThemes.isProTheme(themeId)) {
      themeId = 'classic-slate';
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  // ------------------------------------------------------------- setters
  Future<void> setProfileName(String v) async {
    final clean = v.trim();
    profileName = clean.isEmpty ? 'Scholar' : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && ChalkThemes.isProTheme(id)) return; // locked in free
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    difficulty = v.clamp(0, 2);
    if (!isPro && difficulty > 1) difficulty = 1; // hard is Pro
    notifyListeners();
    await _save();
  }

  Future<void> setPencilDefault(bool v) async {
    pencilDefault = v;
    notifyListeners();
    await _save();
  }

  Future<void> setErrorHighlight(bool v) async {
    errorHighlight = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMistakeLimit(bool v) async {
    mistakeLimit = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTimedDefault(bool v) async {
    timedDefault = v;
    notifyListeners();
    await _save();
  }

  Future<void> setShowTimer(bool v) async {
    showTimer = v;
    notifyListeners();
    await _save();
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  // ---------------------------------------------------------------- stats
  /// Star rating per RULES.md Section 8.
  static int starsFor({required int mistakes, required int hintsUsed}) {
    if (mistakes == 0 && hintsUsed == 0) return 3;
    if (mistakes <= 2 && hintsUsed <= 1) return 2;
    return 1;
  }

  Future<void> recordSolved({
    required int difficultyIdx,
    required int secs,
    required int mistakes,
    required int hintsUsed,
    required bool isDaily,
    required String todayKey,
  }) async {
    gamesPlayed++;
    solved++;
    final stars = starsFor(mistakes: mistakes, hintsUsed: hintsUsed);
    starsTotal += stars;
    if (bestTime[difficultyIdx] == 0 || secs < bestTime[difficultyIdx]) {
      bestTime[difficultyIdx] = secs;
    }
    if (isDaily && dailyDate != todayKey) {
      dailyDate = todayKey;
      dailyStreak++;
    }
    notifyListeners();
    await _save();
  }

  Future<void> recordAbandoned() async {
    gamesPlayed++;
    notifyListeners();
    await _save();
  }

  Future<void> resetProgress() async {
    gamesPlayed = 0;
    solved = 0;
    starsTotal = 0;
    bestTime[0] = bestTime[1] = bestTime[2] = 0;
    dailyDate = '';
    dailyStreak = 0;
    await clearSavedGame();
    notifyListeners();
    await _save();
  }

  // ------------------------------------------------------------ saved game
  Future<void> saveGame(Map<String, dynamic> state) async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kSavedGame, jsonEncode(state));
  }

  Future<Map<String, dynamic>?> loadSavedGame() async {
    final p = _prefs;
    if (p == null) return null;
    final raw = p.getString(_kSavedGame);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSavedGame() async {
    final p = _prefs;
    if (p == null) return;
    await p.remove(_kSavedGame);
  }
}
