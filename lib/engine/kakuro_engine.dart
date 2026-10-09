import 'dart:async';
import 'package:flutter/foundation.dart';
import 'kakuro_generator.dart';

/// Game phases owned by the engine (never by UI timers).
enum KakuroPhase { idle, playing, paused, solved, failed }

/// Game mode configuration.
class KakuroMode {
  final KakuroDifficulty difficulty;
  final String label;
  final int timeLimitSecs; // 0 = untimed
  final int hintLimit; // 0 = unlimited
  final int mistakeLimit; // 0 = disabled
  final bool isDaily;

  const KakuroMode({
    required this.difficulty,
    required this.label,
    this.timeLimitSecs = 0,
    this.hintLimit = 0,
    this.mistakeLimit = 0,
    this.isDaily = false,
  });

  Map<String, dynamic> toJson() => {
        'difficulty': difficulty.index,
        'label': label,
        'timeLimitSecs': timeLimitSecs,
        'hintLimit': hintLimit,
        'mistakeLimit': mistakeLimit,
        'isDaily': isDaily,
      };

  static KakuroMode fromJson(Map<String, dynamic> j) => KakuroMode(
        difficulty: KakuroDifficulty.values[j['difficulty'] as int],
        label: j['label'] as String,
        timeLimitSecs: j['timeLimitSecs'] as int,
        hintLimit: j['hintLimit'] as int,
        mistakeLimit: j['mistakeLimit'] as int,
        isDaily: j['isDaily'] as bool,
      );
}

class _Edit {
  final int cell;
  final int prevDigit;
  final int prevPencil;
  final int prevMistakes;
  _Edit(this.cell, this.prevDigit, this.prevPencil, this.prevMistakes);
}

/// Kakuro game engine: owns ALL puzzle state, the phase state machine,
/// the clock, mistakes, hints, undo history and error detection.
///
/// A watchdog timer runs every second and repairs any inconsistency it
/// finds (stalled clock, missed win, over-limit mistakes, expired timer),
/// so stuck states are impossible by construction. The UI only renders
/// and forwards input; it never owns game state.
class KakuroEngine extends ChangeNotifier {
  KakuroPuzzle? _puzzle;
  KakuroMode _mode = const KakuroMode(
      difficulty: KakuroDifficulty.easy, label: 'Easy');

  List<int> _entries = [];
  List<int> _pencil = []; // bitmask per cell
  final List<_Edit> _undo = [];
  Set<int> _errorCells = {};

  int _selected = -1;
  bool _pencilMode = false;
  int _mistakes = 0;
  int _hintsUsed = 0;
  KakuroPhase _phase = KakuroPhase.idle;

  int _elapsedSecs = 0;
  int _timeLeftSecs = 0;

  Timer? _clock;
  Timer? _watchdog;
  String _lastRecovery = '';
  bool _disposed = false;

  // ------------------------------------------------------------ getters
  KakuroPuzzle? get puzzle => _puzzle;
  KakuroMode get mode => _mode;
  KakuroPhase get phase => _phase;
  List<int> get entries => _entries;
  List<int> get pencil => _pencil;
  Set<int> get errorCells => _errorCells;
  int get selected => _selected;
  bool get pencilMode => _pencilMode;
  int get mistakes => _mistakes;
  int get hintsUsed => _hintsUsed;

  /// Hints left, or -1 when unlimited.
  int get hintsLeft =>
      _mode.hintLimit == 0 ? -1 : (_mode.hintLimit - _hintsUsed).clamp(0, 1 << 30);
  int get elapsedSecs => _elapsedSecs;
  int get timeLeftSecs => _timeLeftSecs;
  bool get canUndo => _undo.isNotEmpty;
  bool get canHint => _mode.hintLimit == 0 || _hintsUsed < _mode.hintLimit;
  String get lastRecovery => _lastRecovery;

  bool get hasGame => _puzzle != null;
  bool get isPlaying => _phase == KakuroPhase.playing;

  int get filledCount {
    var n = 0;
    for (var i = 0; i < _entries.length; i++) {
      if (_puzzle!.isWhite[i] && _entries[i] != 0) n++;
    }
    return n;
  }

  int get whiteCount => _puzzle?.whiteCount ?? 0;

  // ------------------------------------------------------------ lifecycle
  /// Start a new attempt on [puzzle] under [mode].
  void startGame(KakuroPuzzle puzzle, KakuroMode mode) {
    _puzzle = puzzle;
    _mode = mode;
    _entries = List<int>.filled(puzzle.cellCount, 0);
    _pencil = List<int>.filled(puzzle.cellCount, 0);
    _undo.clear();
    _errorCells = {};
    _selected = -1;
    _mistakes = 0;
    _hintsUsed = 0;
    _elapsedSecs = 0;
    _timeLeftSecs = mode.timeLimitSecs;
    _phase = KakuroPhase.playing;
    _startClock();
    _startWatchdog();
    notifyListeners();
  }

  /// Restore a saved attempt (Continue).
  bool restore(Map<String, dynamic> j) {
    try {
      final puzzle = KakuroPuzzle.fromJson(
          Map<String, dynamic>.from(j['puzzle'] as Map));
      _puzzle = puzzle;
      _mode = KakuroMode.fromJson(Map<String, dynamic>.from(j['mode'] as Map));
      _entries = (j['entries'] as List).map((e) => e as int).toList();
      _pencil = (j['pencil'] as List).map((e) => e as int).toList();
      _selected = j['selected'] as int;
      _pencilMode = j['pencilMode'] as bool;
      _mistakes = j['mistakes'] as int;
      _hintsUsed = j['hintsUsed'] as int;
      _elapsedSecs = j['elapsedSecs'] as int;
      _timeLeftSecs = j['timeLeftSecs'] as int;
      _phase = KakuroPhase.paused; // resume explicitly via resume()
      _undo.clear();
      _recomputeErrors();
      _startWatchdog();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> save() => {
        'puzzle': _puzzle!.toJson(),
        'mode': _mode.toJson(),
        'entries': _entries,
        'pencil': _pencil,
        'selected': _selected,
        'pencilMode': _pencilMode,
        'mistakes': _mistakes,
        'hintsUsed': _hintsUsed,
        'elapsedSecs': _elapsedSecs,
        'timeLeftSecs': _timeLeftSecs,
      };

  // ------------------------------------------------------------ input
  /// Select a cell. Returns false for clue cells / out of bounds (RULES 5).
  bool selectCell(int i) {
    final p = _puzzle;
    if (p == null || _phase != KakuroPhase.playing) return false;
    if (i < 0 || i >= p.cellCount) return false;
    if (!p.isWhite[i]) return false; // clue cells are not selectable
    _selected = (_selected == i) ? -1 : i;
    notifyListeners();
    return true;
  }

  void setPencilMode(bool v) {
    if (_pencilMode == v) return;
    _pencilMode = v;
    notifyListeners();
  }

  /// Enter digit 1-9 into the selected cell. Values outside 1-9 rejected.
  /// Returns 'ok' | 'mistake' | 'pencil' | 'rejected'.
  String enterDigit(int digit) {
    final p = _puzzle;
    if (p == null || _phase != KakuroPhase.playing) return 'rejected';
    if (digit < 1 || digit > 9) return 'rejected'; // RULES 5: 0 rejected
    final cell = _selected;
    if (cell < 0 || !p.isWhite[cell]) return 'rejected';

    if (_pencilMode) {
      _undo.add(_Edit(cell, _entries[cell], _pencil[cell], _mistakes));
      _pencil[cell] ^= (1 << digit); // toggle candidate (idempotent)
      notifyListeners();
      return 'pencil';
    }

    _undo.add(_Edit(cell, _entries[cell], _pencil[cell], _mistakes));
    _entries[cell] = digit;
    _pencil[cell] = 0; // entering a digit clears pencil marks (RULES 12)
    final v = validateEntry(p, _entries, cell, digit);
    _recomputeErrors();
    var result = 'ok';
    if (v.isMistake) {
      _mistakes++;
      result = 'mistake';
      _checkMistakeLimit();
    }
    if (_phase == KakuroPhase.playing && isPuzzleSolved(p, _entries)) {
      _win();
    }
    notifyListeners();
    return result;
  }

  /// Erase the selected cell (digit + pencil marks).
  bool erase() {
    final p = _puzzle;
    if (p == null || _phase != KakuroPhase.playing) return false;
    final cell = _selected;
    if (cell < 0 || !p.isWhite[cell]) return false;
    if (_entries[cell] == 0 && _pencil[cell] == 0) return false;
    _undo.add(_Edit(cell, _entries[cell], _pencil[cell], _mistakes));
    _entries[cell] = 0;
    _pencil[cell] = 0;
    _recomputeErrors();
    notifyListeners();
    return true;
  }

  /// Undo the most recent edit. No-op when history is empty (RULES 5).
  bool undo() {
    if (_phase != KakuroPhase.playing) return false;
    if (_undo.isEmpty) return false;
    final e = _undo.removeLast();
    _entries[e.cell] = e.prevDigit;
    _pencil[e.cell] = e.prevPencil;
    // Mistakes are NOT refunded by undo — a counted mistake stays counted.
    _recomputeErrors();
    notifyListeners();
    return true;
  }

  /// Fill the selected cell (or the smart-hint cell) with the solution digit.
  /// Returns false when no hints remain or nothing selectable.
  bool hint() {
    final p = _puzzle;
    if (p == null || _phase != KakuroPhase.playing) return false;
    if (_mode.hintLimit > 0 && _hintsUsed >= _mode.hintLimit) return false;
    var cell = _selected;
    if (cell < 0 || !p.isWhite[cell] || _entries[cell] != 0) {
      cell = _smartHintCell(p);
    }
    if (cell < 0) return false;
    _undo.add(_Edit(cell, _entries[cell], _pencil[cell], _mistakes));
    _entries[cell] = p.solution[cell];
    _pencil[cell] = 0;
    _hintsUsed++;
    _selected = cell;
    _recomputeErrors();
    if (isPuzzleSolved(p, _entries)) {
      _win();
    }
    notifyListeners();
    return true;
  }

  /// Smart hint (RULES 11.5): the empty cell with the fewest candidates.
  int _smartHintCell(KakuroPuzzle p) {
    var best = -1;
    var bestCount = 99;
    for (var i = 0; i < p.cellCount; i++) {
      if (!p.isWhite[i] || _entries[i] != 0) continue;
      final c = _popCount(candidatesFor(p, _entries, i));
      if (c == 0) continue; // inconsistent with a past error; skip
      if (c < bestCount) {
        bestCount = c;
        best = i;
        if (c == 1) break;
      }
    }
    if (best < 0) {
      for (var i = 0; i < p.cellCount; i++) {
        if (p.isWhite[i] && _entries[i] == 0) return i;
      }
    }
    return best;
  }

  // ------------------------------------------------------------ phase control
  void pause() {
    if (_phase != KakuroPhase.playing) return;
    _phase = KakuroPhase.paused;
    _clock?.cancel();
    _clock = null;
    notifyListeners();
  }

  void resume() {
    if (_phase != KakuroPhase.paused) return;
    _phase = KakuroPhase.playing;
    _startClock();
    notifyListeners();
  }

  /// Restart the same puzzle fresh.
  void restart() {
    final p = _puzzle;
    if (p == null) return;
    startGame(p, _mode);
  }

  /// Abandon the attempt (quit to menu).
  void abandon() {
    _phase = KakuroPhase.idle;
    _clock?.cancel();
    _clock = null;
    notifyListeners();
  }

  void _win() {
    _phase = KakuroPhase.solved;
    _clock?.cancel();
    _clock = null;
    notifyListeners();
  }

  void _fail() {
    _phase = KakuroPhase.failed;
    _clock?.cancel();
    _clock = null;
    notifyListeners();
  }

  void _checkMistakeLimit() {
    if (_mode.mistakeLimit > 0 &&
        _mistakes >= _mode.mistakeLimit &&
        _phase == KakuroPhase.playing) {
      _fail();
    }
  }

  // ------------------------------------------------------------ clock
  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _phase != KakuroPhase.playing) return;
      _elapsedSecs++;
      if (_mode.timeLimitSecs > 0) {
        _timeLeftSecs--;
        if (_timeLeftSecs <= 0) {
          _timeLeftSecs = 0;
          _fail(); // timed out (RULES 10: failure state)
          return;
        }
      }
      notifyListeners();
    });
  }

  // ------------------------------------------------------------ watchdog
  /// Every second the watchdog re-asserts engine invariants and repairs
  /// anything the UI or lifecycle could have left inconsistent. Stuck states
  /// are impossible by construction.
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || _puzzle == null) return;
      final fixes = <String>[];
      // 1. Clock must tick while playing.
      if (_phase == KakuroPhase.playing &&
          (_clock == null || !_clock!.isActive)) {
        _startClock();
        fixes.add('restarted stalled clock');
      }
      // 2. Clock must NOT tick while paused/solved/failed/idle.
      if (_phase != KakuroPhase.playing &&
          _clock != null &&
          _clock!.isActive) {
        _clock?.cancel();
        _clock = null;
        fixes.add('stopped runaway clock');
      }
      // 3. A fully valid board must never sit in "playing".
      if (_phase == KakuroPhase.playing &&
          isPuzzleSolved(_puzzle!, _entries)) {
        _win();
        fixes.add('settled missed win');
      }
      // 4. Mistake limit / timer expiry must fail the attempt.
      if (_phase == KakuroPhase.playing) {
        if (_mode.mistakeLimit > 0 && _mistakes >= _mode.mistakeLimit) {
          _fail();
          fixes.add('enforced mistake limit');
        } else if (_mode.timeLimitSecs > 0 && _timeLeftSecs <= 0) {
          _fail();
          fixes.add('enforced time limit');
        }
      }
      // 5. Selection must always point at a white cell.
      if (_selected >= 0 &&
          (_selected >= _puzzle!.cellCount ||
              !_puzzle!.isWhite[_selected])) {
        _selected = -1;
        fixes.add('cleared invalid selection');
      }
      if (fixes.isNotEmpty) {
        _lastRecovery = fixes.join('; ');
        notifyListeners();
      }
    });
  }

  void _recomputeErrors() {
    final p = _puzzle;
    if (p == null) {
      _errorCells = {};
      return;
    }
    _errorCells = computeErrorCells(p, _entries);
  }

  /// App lifecycle: freeze the clock when backgrounded.
  void onAppPaused() {
    if (_phase == KakuroPhase.playing) {
      pause();
    }
  }

  void onAppResumed() {
    // Stay paused — the user resumes explicitly from the pause overlay.
  }

  @override
  void dispose() {
    _disposed = true;
    _clock?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }
}

int _popCount(int mask) {
  var n = 0;
  while (mask != 0) {
    mask &= mask - 1;
    n++;
  }
  return n;
}
