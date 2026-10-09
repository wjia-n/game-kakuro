import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/kakuro_engine.dart';
import '../engine/kakuro_generator.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/chalkboard.dart';
import '../theme/chalkboard_themes.dart';
import 'pro_screen.dart';

/// Game board screen: top chalk panel, oak-framed slate grid, chalk number
/// pad, pencil/erase/undo/hint controls, pause / victory / failure overlays.
/// Renders engine state; never owns it.
class GameScreen extends StatefulWidget {
  final StudyAudio audio;
  final StudySettings settings;
  final KakuroEngine engine;
  final bool fresh; // false when arriving via Continue (already paused)
  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.engine,
    required this.fresh,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  KakuroEngine get _engine => widget.engine;
  ChalkThemeDef get _theme => widget.settings.theme;

  List<int> _prevEntries = [];
  int _lastMistakes = 0;
  int _lastHints = 0;
  final Map<int, int> _popTick = {};
  final Map<int, int> _shakeTick = {};
  final Map<int, int> _hintTick = {};
  final Map<int, int> _dustTick = {};
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _overlaysArmed = false;

  @override
  void initState() {
    super.initState();
    _prevEntries = List<int>.from(_engine.entries);
    _lastMistakes = _engine.mistakes;
    _lastHints = _engine.hintsUsed;
    if (!widget.fresh) {
      // Continue: engine restored in paused phase; stay paused until resume.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPause());
    }
    _engine.addListener(_onEngine);
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngine);
    _persist();
    super.dispose();
  }

  void _onEngine() {
    if (!mounted) return;
    final p = _engine.puzzle;
    if (p == null) return;
    // Diff entries -> animation ticks.
    for (var i = 0; i < p.cellCount; i++) {
      if (!p.isWhite[i]) continue;
      final was = _prevEntries[i];
      final now = _engine.entries[i];
      if (was != now) {
        if (was == 0 && now != 0) {
          _popTick[i] = (_popTick[i] ?? 0) + 1;
        } else if (was != 0 && now == 0) {
          _dustTick[i] = (_dustTick[i] ?? 0) + 1;
        } else if (was != 0 && now != 0) {
          _popTick[i] = (_popTick[i] ?? 0) + 1;
        }
      }
    }
    _prevEntries = List<int>.from(_engine.entries);
    // Mistakes -> shake error cells.
    if (_engine.mistakes > _lastMistakes) {
      _lastMistakes = _engine.mistakes;
      widget.audio.invalid();
      for (final c in _engine.errorCells) {
        _shakeTick[c] = (_shakeTick[c] ?? 0) + 1;
      }
    }
    // Hints -> shimmer the hinted cell.
    if (_engine.hintsUsed > _lastHints) {
      _lastHints = _engine.hintsUsed;
      widget.audio.hint();
      final c = _engine.selected;
      if (c >= 0) _hintTick[c] = (_hintTick[c] ?? 0) + 1;
    }
    // Win / fail fanfare + overlays.
    if (_engine.phase == KakuroPhase.solved && !_overlaysArmed) {
      _overlaysArmed = true;
      widget.audio.win();
      widget.settings.recordSolved(
        difficultyIdx: _engine.mode.difficulty.index,
        secs: _engine.elapsedSecs,
        mistakes: _engine.mistakes,
        hintsUsed: _engine.hintsUsed,
        isDaily: _engine.mode.isDaily,
        todayKey: _todayKey(),
      );
      widget.settings.clearSavedGame();
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _showVictory();
      });
    } else if (_engine.phase == KakuroPhase.failed && !_overlaysArmed) {
      _overlaysArmed = true;
      widget.audio.lose();
      widget.settings.recordAbandoned();
      widget.settings.clearSavedGame();
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) _showFailure();
      });
    }
    // Periodic autosave while playing.
    if (_engine.phase == KakuroPhase.playing) {
      final now = DateTime.now();
      if (now.difference(_lastSave).inSeconds > 15) {
        _lastSave = now;
        _persist();
      }
    }
    setState(() {});
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  void _persist() {
    if (_engine.hasGame &&
        (_engine.phase == KakuroPhase.playing ||
            _engine.phase == KakuroPhase.paused)) {
      widget.settings.saveGame(_engine.save());
    }
  }

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // -------------------------------------------------------------- actions
  void _tapCell(int i) {
    final ok = _engine.selectCell(i);
    widget.audio.click();
    if (!ok) widget.audio.invalid(); // clue cell tapped
  }

  void _enterDigit(int d) {
    final r = _engine.enterDigit(d);
    if (r == 'ok') {
      widget.audio.chalkWrite();
    } else if (r == 'pencil') {
      widget.audio.click();
    } else if (r == 'mistake') {
      // invalid() played by the engine listener.
    } else {
      widget.audio.invalid();
    }
  }

  void _erase() {
    if (_engine.erase()) {
      widget.audio.erase();
    } else {
      widget.audio.click();
    }
  }

  void _undo() {
    if (_engine.undo()) {
      widget.audio.erase();
    } else {
      widget.audio.click();
    }
  }

  void _hint() {
    if (_engine.hint()) {
      // shimmer + sound handled by the engine listener.
    } else {
      widget.audio.invalid();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No hints left — the chalk is worn down.',
                style: ChalkType.hand(20, theme: _theme))),
      );
    }
  }

  void _togglePencil() {
    _engine.setPencilMode(!_engine.pencilMode);
    widget.audio.click();
  }

  void _showPause() {
    _engine.pause();
    _persist();
    widget.audio.click();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PauseDialog(
        theme: _theme,
        audio: widget.audio,
        settings: widget.settings,
        onResume: () {
          Navigator.pop(context);
          _engine.resume();
        },
        onRestart: () {
          Navigator.pop(context);
          _overlaysArmed = false;
          _engine.restart();
          _engine.setPencilMode(widget.settings.pencilDefault);
          widget.audio.gameStart();
        },
        onQuit: () {
          Navigator.pop(context);
          _engine.abandon();
          _persist();
          widget.settings.clearSavedGame();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showVictory() {
    final stars = StudySettings.starsFor(
        mistakes: _engine.mistakes, hintsUsed: _engine.hintsUsed);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VictoryDialog(
        theme: _theme,
        audio: widget.audio,
        engine: _engine,
        stars: stars,
        timeLabel: _fmt(_engine.elapsedSecs),
        onPlayAgain: () {
          Navigator.pop(context);
          Navigator.pop(context, 'replay');
        },
        onNewPuzzle: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onMenu: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showFailure() {
    final timedOut =
        _engine.mode.timeLimitSecs > 0 && _engine.timeLeftSecs <= 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FailureDialog(
        theme: _theme,
        audio: widget.audio,
        timedOut: timedOut,
        mistakes: _engine.mistakes,
        onRetry: () {
          Navigator.pop(context);
          _overlaysArmed = false;
          _engine.restart();
          _engine.setPencilMode(widget.settings.pencilDefault);
          widget.audio.gameStart();
        },
        onMenu: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    final engine = _engine;
    final p = engine.puzzle!;
    final timed = engine.mode.timeLimitSecs > 0;
    return Scaffold(
      backgroundColor: theme.desk,
      body: LampWash(
        theme: theme,
        child: SlateTexture(
          theme: theme,
          child: SafeArea(
            child: Column(
              children: [
                // Top chalk panel.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _showPause,
                        icon: Icon(Icons.pause,
                            color: theme.chalk, size: 26),
                      ),
                      Expanded(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (widget.settings.showTimer)
                              ChalkChip(
                                theme: theme,
                                text: timed
                                    ? '⏳ ${_fmt(engine.timeLeftSecs)}'
                                    : '⏱ ${_fmt(engine.elapsedSecs)}',
                              ),
                            ChalkChip(
                                theme: theme,
                                text: engine.mode.label),
                            ChalkChip(
                                theme: theme,
                                text:
                                    '✕ ${engine.mistakes}${engine.mode.mistakeLimit > 0 ? '/${engine.mode.mistakeLimit}' : ''}'),
                            if (engine.mode.hintLimit > 0)
                              ChalkChip(
                                  theme: theme,
                                  text:
                                      '💡 ${engine.hintsLeft}'),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          widget.audio.click();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProScreen(
                                audio: widget.audio,
                                settings: widget.settings,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.workspace_premium,
                            color: theme.accent, size: 24),
                      ),
                    ],
                  ),
                ),
                // Board.
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: LayoutBuilder(
                        builder: (_, cons) {
                          final cell = (cons.maxWidth - 4) / p.cols;
                          final maxH = cons.maxHeight - 4;
                          final c2 = cell > maxH / p.rows
                              ? maxH / p.rows
                              : cell;
                          return OakFrame(
                            theme: theme,
                            rim: 8,
                            child: SizedBox(
                              width: c2 * p.cols,
                              height: c2 * p.rows,
                              child: _Board(
                                theme: theme,
                                engine: engine,
                                cell: c2,
                                errorOn: widget
                                    .settings.errorHighlight,
                                popTick: _popTick,
                                shakeTick: _shakeTick,
                                hintTick: _hintTick,
                                dustTick: _dustTick,
                                onTapCell: _tapCell,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Controls.
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(14, 6, 14, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ToolButton(
                        theme: theme,
                        icon: Icons.edit,
                        label: 'Pencil',
                        active: engine.pencilMode,
                        onTap: _togglePencil,
                      ),
                      _ToolButton(
                        theme: theme,
                        icon: Icons.backspace_outlined,
                        label: 'Erase',
                        onTap: _erase,
                      ),
                      _ToolButton(
                        theme: theme,
                        icon: Icons.undo,
                        label: 'Undo',
                        onTap: _undo,
                      ),
                      _ToolButton(
                        theme: theme,
                        icon: Icons.lightbulb_outline,
                        label: engine.mode.hintLimit > 0
                            ? 'Hint ${engine.hintsLeft}'
                            : 'Hint',
                        onTap: _hint,
                      ),
                    ],
                  ),
                ),
                // Number pad.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var d = 1; d <= 9; d++)
                        Flexible(
                          child: ChalkCircleButton(
                            theme: theme,
                            label: '$d',
                            size: 44,
                            fontSize: 24,
                            onTap: () => _enterDigit(d),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Board: rows of cells. Clue cells get the etched diagonal split; entry
// cells get chalk outlines, digits, pencil marks, error/selection states.
// ---------------------------------------------------------------------------

class _Board extends StatelessWidget {
  final ChalkThemeDef theme;
  final KakuroEngine engine;
  final double cell;
  final bool errorOn;
  final Map<int, int> popTick;
  final Map<int, int> shakeTick;
  final Map<int, int> hintTick;
  final Map<int, int> dustTick;
  final void Function(int) onTapCell;
  const _Board({
    required this.theme,
    required this.engine,
    required this.cell,
    required this.errorOn,
    required this.popTick,
    required this.shakeTick,
    required this.hintTick,
    required this.dustTick,
    required this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    final p = engine.puzzle!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < p.rows; r++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < p.cols; c++)
                _Cell(
                  theme: theme,
                  engine: engine,
                  index: p.idx(r, c),
                  size: cell,
                  errorOn: errorOn,
                  popTick: popTick[indexKey(p, r, c)] ?? 0,
                  shakeTick: shakeTick[indexKey(p, r, c)] ?? 0,
                  hintTick: hintTick[indexKey(p, r, c)] ?? 0,
                  dustTick: dustTick[indexKey(p, r, c)] ?? 0,
                  onTap: onTapCell,
                ),
            ],
          ),
      ],
    );
  }

  int indexKey(KakuroPuzzle p, int r, int c) => p.idx(r, c);
}

class _Cell extends StatelessWidget {
  final ChalkThemeDef theme;
  final KakuroEngine engine;
  final int index;
  final double size;
  final bool errorOn;
  final int popTick;
  final int shakeTick;
  final int hintTick;
  final int dustTick;
  final void Function(int) onTap;
  const _Cell({
    required this.theme,
    required this.engine,
    required this.index,
    required this.size,
    required this.errorOn,
    required this.popTick,
    required this.shakeTick,
    required this.hintTick,
    required this.dustTick,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = engine.puzzle!;
    if (!p.isWhite[index]) return _clueCell(p);
    return _entryCell(p);
  }

  Widget _clueCell(KakuroPuzzle p) {
    final down = p.downClue[index];
    final across = p.acrossClue[index];
    final fs = (size * 0.30).clamp(7.0, 13.0);
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        margin: const EdgeInsets.all(0.75),
        decoration: BoxDecoration(
          color: theme.boardDeep,
          borderRadius: BorderRadius.circular(2),
        ),
        child: CustomPaint(
          painter: _CluePainter(
            down: down > 0 ? '$down' : '',
            across: across > 0 ? '$across' : '',
            theme: theme,
            fontSize: fs,
          ),
        ),
      ),
    );
  }

  Widget _entryCell(KakuroPuzzle p) {
    final selected = engine.selected == index;
    final isError = errorOn && engine.errorCells.contains(index);
    final digit = engine.entries[index];
    final pencilMask = engine.pencil[index];
    Widget inner;
    if (digit != 0) {
      inner = Center(
        child: Text('$digit',
            style: ChalkType.display(
                (size * 0.52).clamp(12.0, 30.0),
                theme: theme,
                color: isError ? theme.error : theme.chalk)),
      );
      inner = ChalkPop(tick: popTick, child: inner);
    } else if (pencilMask != 0) {
      inner = PencilMarks(mask: pencilMask, theme: theme, cellSize: size);
    } else {
      inner = const SizedBox.shrink();
    }
    if (hintTick > 0 && digit != 0) {
      inner = HintReveal(tick: hintTick, shimmer: theme.accent, child: inner);
    }
    Widget cell = Container(
      margin: const EdgeInsets.all(0.75),
      decoration: BoxDecoration(
        color: selected
            ? theme.accent.withValues(alpha: 0.16)
            : isError
                ? theme.error.withValues(alpha: 0.14)
                : theme.entry,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isError
              ? theme.error
              : selected
                  ? theme.accent
                  : theme.chalk.withValues(alpha: 0.42),
          width: (isError || selected) ? 2.2 : 1.1,
        ),
      ),
      child: Stack(
        children: [
          inner,
          if (dustTick > 0)
            Positioned.fill(
                child: DustPuff(tick: dustTick, color: theme.chalk)),
        ],
      ),
    );
    if (shakeTick > 0 && isError) {
      cell = ShakeChalk(tick: shakeTick, child: cell);
    }
    return GestureDetector(
      onTap: () => onTap(index),
      child: SizedBox(width: size, height: size, child: cell),
    );
  }
}

/// Diagonal-split clue cell: etched diagonal top-left -> bottom-right,
/// down sum top-right, across sum bottom-right (DESIGN.md).
class _CluePainter extends CustomPainter {
  final String down;
  final String across;
  final ChalkThemeDef theme;
  final double fontSize;
  _CluePainter(
      {required this.down,
      required this.across,
      required this.theme,
      required this.fontSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (down.isNotEmpty || across.isNotEmpty) {
      canvas.drawLine(
          Offset(size.width * 0.10, size.height * 0.10),
          Offset(size.width * 0.90, size.height * 0.90),
          Paint()
            ..color = theme.chalk.withValues(alpha: 0.30)
            ..strokeWidth = 1.1);
    }
    final style = TextStyle(
        fontFamily: 'Caveat',
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        color: theme.chalkDim);
    if (down.isNotEmpty) {
      final tp = TextPainter(
          text: TextSpan(text: down, style: style),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas,
          Offset(size.width - tp.width - 2.5, 0.5));
    }
    if (across.isNotEmpty) {
      final tp = TextPainter(
          text: TextSpan(text: across, style: style),
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas,
          Offset(size.width - tp.width - 2.5, size.height - tp.height - 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _CluePainter old) => false;
}

class _ToolButton extends StatelessWidget {
  final ChalkThemeDef theme;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToolButton({
    required this.theme,
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: active ? theme.accent : theme.chalkDim,
                  width: active ? 2.4 : 1.6),
              color: active
                  ? theme.accent.withValues(alpha: 0.20)
                  : theme.boardDeep.withValues(alpha: 0.6),
            ),
            child: Icon(icon,
                color: active ? theme.accent : theme.chalk, size: 24),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: ChalkType.small(14, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

class _PauseDialog extends StatelessWidget {
  final ChalkThemeDef theme;
  final StudyAudio audio;
  final StudySettings settings;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseDialog({
    required this.theme,
    required this.audio,
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: theme.boardDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.frame, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: ChalkType.display(40, theme: theme)),
            const SizedBox(height: 6),
            Text('the chalk rests…',
                style: ChalkType.hand(22,
                    theme: theme, color: theme.chalkDim)),
            const SizedBox(height: 20),
            ChalkButton(
                theme: theme, label: 'Resume', active: true, onTap: onResume),
            const SizedBox(height: 10),
            ChalkButton(theme: theme, label: 'Restart', onTap: onRestart),
            const SizedBox(height: 10),
            ChalkButton(
                theme: theme, label: 'Quit to Menu', onTap: onQuit),
          ],
        ),
      ),
    );
  }
}

class _VictoryDialog extends StatelessWidget {
  final ChalkThemeDef theme;
  final StudyAudio audio;
  final KakuroEngine engine;
  final int stars;
  final String timeLabel;
  final VoidCallback onPlayAgain;
  final VoidCallback onNewPuzzle;
  final VoidCallback onMenu;
  const _VictoryDialog({
    required this.theme,
    required this.audio,
    required this.engine,
    required this.stars,
    required this.timeLabel,
    required this.onPlayAgain,
    required this.onNewPuzzle,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: theme.boardDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.frame, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(120, 40),
              painter: _StarburstPainter(color: theme.accent),
            ),
            Text('Puzzle Solved!',
                style: ChalkType.display(40, theme: theme)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: CustomPaint(
                      size: const Size(44, 44),
                      painter: _ChalkStarPainter(
                        color: i < stars
                            ? theme.accent
                            : theme.chalkDim.withValues(alpha: 0.4),
                        filled: i < stars,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.chalk.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text('⏱ $timeLabel',
                      style: ChalkType.hand(24, theme: theme)),
                  Text(
                      '✕ ${engine.mistakes} mistakes · 💡 ${engine.hintsUsed} hints',
                      style: ChalkType.hand(21,
                          theme: theme, color: theme.chalkDim)),
                  Text(engine.mode.label,
                      style: ChalkType.small(16, theme: theme)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ChalkButton(
                theme: theme,
                label: 'Play Again',
                active: true,
                onTap: () {
                  audio.click();
                  onPlayAgain();
                }),
            const SizedBox(height: 10),
            ChalkButton(
                theme: theme, label: 'New Puzzle', onTap: onNewPuzzle),
            const SizedBox(height: 10),
            ChalkButton(
                theme: theme, label: 'Main Menu', onTap: onMenu),
          ],
        ),
      ),
    );
  }
}

class _FailureDialog extends StatelessWidget {
  final ChalkThemeDef theme;
  final StudyAudio audio;
  final bool timedOut;
  final int mistakes;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  const _FailureDialog({
    required this.theme,
    required this.audio,
    required this.timedOut,
    required this.mistakes,
    required this.onRetry,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: theme.boardDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.frame, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Puzzle Failed',
                style: ChalkType.display(38,
                    theme: theme, color: theme.error)),
            const SizedBox(height: 8),
            Text(
              timedOut
                  ? 'The lamp burned out — time ran dry.'
                  : 'Three chalk marks against you — the board wins this round.',
              textAlign: TextAlign.center,
              style: ChalkType.hand(22,
                  theme: theme, color: theme.chalkDim),
            ),
            const SizedBox(height: 18),
            ChalkButton(
                theme: theme,
                label: 'Retry Puzzle',
                active: true,
                onTap: () {
                  audio.click();
                  onRetry();
                }),
            const SizedBox(height: 10),
            ChalkButton(theme: theme, label: 'Main Menu', onTap: onMenu),
          ],
        ),
      ),
    );
  }
}

class _StarburstPainter extends CustomPainter {
  final Color color;
  _StarburstPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final rng = Random(11);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * pi + rng.nextDouble() * 0.2;
      final r1 = 8.0;
      final r2 = 16 + rng.nextDouble() * 8;
      canvas.drawLine(
          Offset(c.dx + cos(a) * r1, c.dy + sin(a) * r1),
          Offset(c.dx + cos(a) * r2, c.dy + sin(a) * r2),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarburstPainter old) => false;
}

class _ChalkStarPainter extends CustomPainter {
  final Color color;
  final bool filled;
  _ChalkStarPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    if (filled) {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _ChalkStarPainter old) =>
      old.color != color || old.filled != filled;
}
