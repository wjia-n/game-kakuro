import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../engine/kakuro_engine.dart';
import '../engine/kakuro_generator.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/chalkboard.dart';
import '../theme/chalkboard_themes.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: hand-chalked title, profile, New Game / Continue / Daily /
/// mode pickers, Settings, Pro. Portrait phone-first.
class MenuScreen extends StatefulWidget {
  final StudyAudio audio;
  final StudySettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _difficulty = 1;
  bool _timed = false;
  bool _hintChallenge = false;
  bool _hasSave = false;
  bool _generating = false;
  String _genLabel = '';

  @override
  void initState() {
    super.initState();
    _difficulty = widget.settings.difficulty;
    _timed = widget.settings.timedDefault;
    widget.audio.startMenuMusic();
    _checkSave();
  }

  Future<void> _checkSave() async {
    final s = await widget.settings.loadSavedGame();
    if (mounted) setState(() => _hasSave = s != null);
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  KakuroMode _modeFor(KakuroDifficulty d, {bool daily = false}) {
    final spec = kakuroDifficultySpecs[d]!;
    final label = daily
        ? 'Daily ${spec.label}'
        : _hintChallenge
            ? '${spec.label} · Hint Challenge'
            : _timed
                ? '${spec.label} · Timed'
                : spec.label;
    return KakuroMode(
      difficulty: d,
      label: label,
      timeLimitSecs: _timed && !daily
          ? [600, 900, 1500][d.index] // 10 / 15 / 25 min
          : 0,
      hintLimit: _hintChallenge && !daily ? 3 : 0,
      mistakeLimit:
          (_hintChallenge && !daily) || widget.settings.mistakeLimit ? 3 : 0,
      isDaily: daily,
    );
  }

  Future<void> _startNew({required KakuroDifficulty difficulty, bool daily = false}) async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _genLabel = daily ? 'Fetching today\u2019s puzzle…' : 'Chalking your puzzle…';
    });
    widget.audio.gameStart();
    final seed = daily
        ? int.parse(_todayKey())
        : DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    try {
      final puzzle = await compute(
          generateKakuroPuzzle, KakuroGenParams(difficulty, seed));
      if (!mounted) return;
      final engine = KakuroEngine();
      engine.setPencilMode(widget.settings.pencilDefault);
      engine.startGame(puzzle, _modeFor(difficulty, daily: daily));
      widget.audio.startGameMusic();
      setState(() => _generating = false);
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            audio: widget.audio,
            settings: widget.settings,
            engine: engine,
            fresh: true,
          ),
        ),
      );
      widget.audio.startMenuMusic();
      _checkSave();
      if (result == 'replay' && mounted) {
        // Victory -> Play Again: chalk a fresh puzzle in the same mode.
        _startNew(difficulty: difficulty, daily: daily);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not chalk a puzzle — try again.')),
      );
    }
  }

  Future<void> _continue() async {
    if (_generating) return;
    final saved = await widget.settings.loadSavedGame();
    if (saved == null || !mounted) return;
    final engine = KakuroEngine();
    if (!engine.restore(saved)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved puzzle was unreadable.')),
        );
      }
      return;
    }
    widget.audio.click();
    widget.audio.startGameMusic();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          engine: engine,
          fresh: false,
        ),
      ),
    );
    widget.audio.startMenuMusic();
    _checkSave();
  }

  void _editProfile() {
    final theme = widget.settings.theme;
    final ctrl = TextEditingController(text: widget.settings.profileName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.boardDeep,
        title: Text('Scholar\u2019s name',
            style: ChalkType.hand(28, theme: theme)),
        content: TextField(
          controller: ctrl,
          maxLength: 16,
          style: ChalkType.hand(24, theme: theme),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.chalk)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: theme.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: ChalkType.hand(22, theme: theme)),
          ),
          TextButton(
            onPressed: () {
              widget.settings.setProfileName(ctrl.text);
              widget.audio.click();
              Navigator.pop(context);
            },
            child: Text('Chalk it in',
                style: ChalkType.hand(22, theme: theme, color: theme.accent)),
          ),
        ],
      ),
    );
  }

  void _howToPlay() {
    final theme = widget.settings.theme;
    widget.audio.click();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.boardDeep,
        title: Text('How to play',
            style: ChalkType.display(30, theme: theme)),
        content: SingleChildScrollView(
          child: Text(
            'Fill every empty cell with a digit 1–9.\n\n'
            '• Each clue is the SUM of its run — the unbroken line of cells beside it.\n'
            '• Digits never repeat inside one run.\n'
            '• Tap a cell, then tap 1–9 on the chalk pad.\n'
            '• Pencil mode chalks in little candidate marks.\n'
            '• Duplicates are flagged in red chalk at once; wrong sums are flagged when a run is complete.\n'
            '• Hints fill the true digit. Three mistakes can end a challenge run.',
            style: ChalkType.hand(21, theme: theme, color: theme.chalk),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it',
                style: ChalkType.hand(22, theme: theme, color: theme.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    final isDailyDone = widget.settings.dailyDate == _todayKey();
    return Scaffold(
      backgroundColor: theme.desk,
      body: LampWash(
        theme: theme,
        child: SlateTexture(
          theme: theme,
          child: SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 26),
                      // Title with chalk swoosh + tally marks.
                      Center(
                        child: Column(
                          children: [
                            Text('KAKURO',
                                style: ChalkType.display(62, theme: theme)),
                            CustomPaint(
                              size: const Size(220, 22),
                              painter: _SwooshPainter(color: theme.accent),
                            ),
                            const SizedBox(height: 4),
                            Text('the cross-sums chalkboard',
                                style: ChalkType.hand(22,
                                    theme: theme, color: theme.chalkDim)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Profile row.
                      Center(
                        child: GestureDetector(
                          onTap: _editProfile,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit,
                                  size: 16,
                                  color: theme.chalkDim),
                              const SizedBox(width: 6),
                              Text(
                                  'Scholar: ${widget.settings.profileName}',
                                  style: ChalkType.hand(22,
                                      theme: theme,
                                      color: theme.chalkDim)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Difficulty chalk circles.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: _DifficultyCircle(
                                theme: theme,
                                label: ['Easy', 'Med', 'Hard'][i],
                                sub: ['6×8', '8×10', '10×12'][i],
                                active: _difficulty == i,
                                locked: i == 2 && !widget.settings.isPro,
                                onTap: () {
                                  widget.audio.click();
                                  if (i == 2 && !widget.settings.isPro) {
                                    _openPro();
                                    return;
                                  }
                                  setState(() => _difficulty = i);
                                  widget.settings.setDifficulty(i);
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Mode chips.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ModeChip(
                            theme: theme,
                            label: 'Timed',
                            active: _timed,
                            onTap: () {
                              widget.audio.click();
                              setState(() => _timed = !_timed);
                            },
                          ),
                          const SizedBox(width: 10),
                          _ModeChip(
                            theme: theme,
                            label: 'Hint Challenge',
                            active: _hintChallenge,
                            onTap: () {
                              widget.audio.click();
                              setState(
                                  () => _hintChallenge = !_hintChallenge);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      ChalkButton(
                        theme: theme,
                        label: 'New Game',
                        active: true,
                        onTap: () => _startNew(
                            difficulty:
                                KakuroDifficulty.values[_difficulty]),
                      ),
                      const SizedBox(height: 12),
                      if (_hasSave)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ChalkButton(
                            theme: theme,
                            label: 'Continue',
                            onTap: _continue,
                          ),
                        ),
                      ChalkButton(
                        theme: theme,
                        label: isDailyDone
                            ? 'Daily Puzzle ✓'
                            : 'Daily Puzzle',
                        onTap: () => _startNew(
                            difficulty: KakuroDifficulty.medium,
                            daily: true),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ChalkButton(
                              theme: theme,
                              label: 'How to Play',
                              fontSize: 21,
                              onTap: _howToPlay,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChalkButton(
                              theme: theme,
                              label: 'Settings',
                              fontSize: 21,
                              onTap: () {
                                widget.audio.click();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SettingsScreen(
                                      audio: widget.audio,
                                      settings: widget.settings,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Stats line.
                      Center(
                        child: Text(
                          '${widget.settings.solved} solved · ${widget.settings.starsTotal}★ · streak ${widget.settings.dailyStreak}',
                          style: ChalkType.small(17, theme: theme),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Pro / tip jar.
                      Center(
                        child: GestureDetector(
                          onTap: _openPro,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium,
                                  size: 18, color: theme.accent),
                              const SizedBox(width: 6),
                              Text(
                                widget.settings.isPro
                                    ? 'Kakuro PRO ✓'
                                    : 'Go Pro · Tip Jar',
                                style: ChalkType.hand(21,
                                    theme: theme, color: theme.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
                if (_generating)
                  _GeneratingOverlay(theme: theme, label: _genLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }
}

class _DifficultyCircle extends StatelessWidget {
  final ChalkThemeDef theme;
  final String label;
  final String sub;
  final bool active;
  final bool locked;
  final VoidCallback onTap;
  const _DifficultyCircle({
    required this.theme,
    required this.label,
    required this.sub,
    required this.active,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: CustomPaint(
              painter: _ChalkRingPainter(
                color: active ? theme.accent : theme.chalk,
                fill: active
                    ? theme.accent.withValues(alpha: 0.25)
                    : null,
                seed: label.hashCode,
              ),
              child: Center(
                child: locked
                    ? Icon(Icons.lock,
                        color: theme.chalkDim, size: 26)
                    : Text(label,
                        style: ChalkType.hand(21,
                            theme: theme,
                            color:
                                active ? theme.accent : theme.chalk)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(sub, style: ChalkType.small(15, theme: theme)),
        ],
      ),
    );
  }
}

class _ChalkRingPainter extends CustomPainter {
  final Color color;
  final Color? fill;
  final int seed;
  _ChalkRingPainter(
      {required this.color, this.fill, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final c = Offset(size.width / 2, size.height / 2);
    final base = size.width / 2 - 3;
    final path = Path();
    const steps = 26;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * pi;
      final rr = base + (rng.nextDouble() - 0.5) * 3.0;
      final p = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (fill != null) canvas.drawPath(path, Paint()..color = fill!);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _ChalkRingPainter old) =>
      old.color != color || old.fill != fill;
}

class _ModeChip extends StatelessWidget {
  final ChalkThemeDef theme;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeChip(
      {required this.theme,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? theme.accent : theme.chalkDim, width: 1.6),
          color: active
              ? theme.accent.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
        child: Text(label,
            style: ChalkType.hand(19,
                theme: theme,
                color: active ? theme.accent : theme.chalkDim)),
      ),
    );
  }
}

class _SwooshPainter extends CustomPainter {
  final Color color;
  _SwooshPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(6, 12)
      ..quadraticBezierTo(
          size.width * 0.5, 22, size.width - 8, 6);
    canvas.drawPath(path, paint);
    // tally marks
    for (var i = 0; i < 4; i++) {
      final x = 30.0 + i * 14;
      canvas.drawLine(Offset(x, 2), Offset(x + 3, 14), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwooshPainter old) => false;
}

class _GeneratingOverlay extends StatelessWidget {
  final ChalkThemeDef theme;
  final String label;
  const _GeneratingOverlay({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: theme.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(label, style: ChalkType.hand(24, theme: theme)),
          ],
        ),
      ),
    );
  }
}
