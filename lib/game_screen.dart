import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Kakuro: cross-sums. Tap a white cell, enter 1-9. No repeats in a run.
/// 3 puzzles: Easy Peasy 6x6, Medium Spicy 8x8, Hard Core 10x10.


class _KakuroData {
  final String label;
  final int size;
  final List<int> cells; // 0 = black, else solution digit
  final List<int> across; // across clue on black cells
  final List<int> down; // down clue on black cells
  const _KakuroData(this.label, this.size, this.cells, this.across, this.down);
}

const _puzzles = [_kakuroEasy, _kakuroMedium, _kakuroHard];

class KakuroScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const KakuroScreen({super.key, required this.players, required this.callbacks});

  @override
  State<KakuroScreen> createState() => _KakuroScreenState();
}

class _KakuroScreenState extends State<KakuroScreen> {
  int _puz = 0;
  late List<int> _entry;
  late List<bool> _locked;
  late List<List<int>> _runOf; // white cell -> across run cells + down run cells
  int _sel = -1;
  int _mistakes = 0;
  int _shake = -1;
  bool _over = false;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  _KakuroData get _d => _puzzles[_puz];
  int get _n => _d.size;

  void _load(int p) {
    _puz = p;
    final n = _d.size;
    _entry = List.filled(n * n, 0);
    _locked = List.filled(n * n, false);
    _runOf = List.generate(n * n, (_) => <int>[]);
    // across runs
    for (int r = 0; r < n; r++) {
      int c = 0;
      while (c < n) {
        if (_d.cells[r * n + c] != 0) {
          final run = <int>[];
          while (c < n && _d.cells[r * n + c] != 0) {
            run.add(r * n + c);
            c++;
          }
          for (final i in run) {
            _runOf[i] = [..._runOf[i], ...run.where((x) => x != i)];
          }
        } else {
          c++;
        }
      }
    }
    // down runs
    for (int c = 0; c < n; c++) {
      int r = 0;
      while (r < n) {
        if (_d.cells[r * n + c] != 0) {
          final run = <int>[];
          while (r < n && _d.cells[r * n + c] != 0) {
            run.add(r * n + c);
            r++;
          }
          for (final i in run) {
            _runOf[i] = [..._runOf[i], ...run.where((x) => x != i)];
          }
        } else {
          r++;
        }
      }
    }
    _sel = -1;
    _mistakes = 0;
    _shake = -1;
    _over = false;
    setState(() {});
  }

  int get _whiteCount => _d.cells.where((v) => v != 0).length;
  int get _doneCount => _locked.where((v) => v).length;

  void _tapCell(int i) {
    if (_over || _d.cells[i] == 0 || _locked[i]) return;
    Sfx.tap();
    setState(() => _sel = (_sel == i) ? -1 : i);
  }

  void _enterDigit(int dg) {
    if (_over || _sel == -1 || _locked[_sel]) return;
    final sol = _d.cells[_sel];
    final dup = _runOf[_sel].any((o) => _entry[o] == dg);
    if (dg == sol && !dup) {
      _entry[_sel] = dg;
      _locked[_sel] = true;
      _sel = -1;
      Sfx.click();
      setState(() {});
      _checkWin();
    } else {
      _mistakes++;
      _shake = _sel;
      Sfx.lose();
      setState(() {});
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) setState(() => _shake = -1);
      });
    }
  }

  void _clearSel() {
    if (_over || _sel == -1 || _locked[_sel]) return;
    _entry[_sel] = 0;
    Sfx.tap();
    setState(() {});
  }

  void _checkWin() {
    if (_over) return;
    for (int i = 0; i < _d.cells.length; i++) {
      if (_d.cells[i] != 0 && !_locked[i]) return;
    }
    _over = true;
    Sfx.win();
      widget.callbacks.finish(
        headline: '${_d.label} conquered! ➕',
        subline: _mistakes == 0
            ? 'Flawless victory — every sum nailed first try. Genius!'
            : 'Puzzle complete with $_mistakes mistake${_mistakes == 1 ? '' : 's'}. The sums bow to you!',
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final pct = _whiteCount == 0 ? 0 : _doneCount * 100 ~/ _whiteCount;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_d.label, style: TextStyle(color: t.text, fontWeight: FontWeight.w900, fontSize: 18)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _whiteCount == 0 ? 0 : _doneCount / _whiteCount,
                        minHeight: 8,
                        backgroundColor: t.surface,
                        valueColor: AlwaysStoppedAnimation(t.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _chip(t, '🎯 $pct%'),
              const SizedBox(width: 8),
              _chip(t, '💥 $_mistakes'),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _puzzles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final sel = i == _puz;
              const emojis = ['🟢', '🟡', '🔴'];
              return GestureDetector(
                onTap: () {
                  Sfx.click();
                  _load(i);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? t.primary : t.surface,
                    borderRadius: t.radius,
                    border: Border.all(color: sel ? t.primary : t.muted.withValues(alpha: 0.25)),
                  ),
                  child: Text('${emojis[i]} ${_puzzles[i].label}',
                      style: TextStyle(
                          color: sel ? Colors.white : t.text, fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (_, cons) {
                final size = (cons.maxWidth < cons.maxHeight ? cons.maxWidth : cons.maxHeight) - 24;
                final cell = size / _n;
                return Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _n),
                    itemCount: _n * _n,
                    itemBuilder: (_, i) => _buildCell(t, i, cell),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.35),
            itemCount: 10,
            itemBuilder: (_, i) {
              if (i == 9) {
                return GestureDetector(
                  onTap: _clearSel,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
                    child: Text('⌫', style: TextStyle(fontSize: 22, color: t.muted)),
                  ),
                );
              }
              final dg = i + 1;
              return GestureDetector(
                onTap: () => _enterDigit(dg),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [t.primary, t.secondary]),
                    borderRadius: t.radius,
                  ),
                  child: Text('$dg',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _chip(GameTheme t, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: t.text, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildCell(GameTheme t, int i, double cell) {
    final v = _d.cells[i];
    final fontSize = (cell * 0.30).clamp(8.0, 15.0);
    if (v == 0) {
      final a = _d.across[i], d = _d.down[i];
      return Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: CustomPaint(
          painter: _CluePainter(
            down: d > 0 ? '$d' : '',
            across: a > 0 ? '$a' : '',
            color: t.muted,
            fontSize: fontSize,
          ),
        ),
      );
    }
    final sel = i == _sel;
    final locked = _locked[i];
    final shaking = i == _shake;
    Widget inner = Container(
      margin: const EdgeInsets.all(1.5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: locked
            ? t.primary.withValues(alpha: 0.22)
            : sel
                ? t.secondary.withValues(alpha: 0.30)
                : t.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: sel ? t.secondary : t.muted.withValues(alpha: 0.25), width: sel ? 2.2 : 1),
      ),
      child: _entry[i] == 0
          ? null
          : Text('${_entry[i]}',
              style: TextStyle(
                  fontSize: cell * 0.42,
                  fontWeight: FontWeight.w900,
                  color: locked ? t.primary : t.text)),
    );
    if (shaking) {
      return _Shaker(
          child: Container(
        margin: const EdgeInsets.all(1.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D).withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5484D), width: 2),
        ),
        child: Text('${_entry[i] == 0 ? '✕' : _entry[i]}',
            style: TextStyle(
                fontSize: cell * 0.42, fontWeight: FontWeight.w900, color: const Color(0xFFE5484D))),
      ));
    }
    return GestureDetector(onTap: () => _tapCell(i), child: inner);
  }
}

/// Diagonal-split clue cell: down clue top-left, across clue bottom-right.
class _CluePainter extends CustomPainter {
  final String down;
  final String across;
  final Color color;
  final double fontSize;
  _CluePainter({required this.down, required this.across, required this.color, required this.fontSize});

  @override
  void paint(Canvas canvas, Size size) {
    if (down.isNotEmpty || across.isNotEmpty) {
      canvas.drawLine(
          Offset(size.width * 0.12, size.height * 0.12),
          Offset(size.width * 0.88, size.height * 0.88),
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..strokeWidth = 1);
    }
    final style = TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: fontSize);
    if (down.isNotEmpty) {
      final tp = TextPainter(text: TextSpan(text: down, style: style), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(3, 1));
    }
    if (across.isNotEmpty) {
      final tp = TextPainter(text: TextSpan(text: across, style: style), textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(size.width - tp.width - 3, size.height - tp.height - 1));
    }
  }

  @override
  bool shouldRepaint(covariant _CluePainter old) => false;
}

/// Runs a shake animation once when created.
class _Shaker extends StatefulWidget {
  final Widget child;
  const _Shaker({required this.child});

  @override
  State<_Shaker> createState() => _ShakerState();
}

class _ShakerState extends State<_Shaker> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final dx = sin(_c.value * pi * 5) * 6 * (1 - _c.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

const _kakuroEasy = _KakuroData(
  'Easy Peasy', 6,
  [0, 0, 0, 0, 0, 0, 0, 8, 9, 0, 1, 8, 0, 9, 4, 3, 5, 1, 0, 0, 3, 2, 8, 0, 0, 0, 5, 1, 2, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 17, 0, 0, 9, 0, 0, 22, 0, 0, 0, 0, 0, 0, 13, 0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 17, 21, 0, 16, 9, 0, 0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
);
const _kakuroMedium = _KakuroData(
  'Medium Spicy', 8,
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 1, 0, 8, 3, 0, 0, 2, 6, 3, 4, 9, 7, 0, 0, 6, 2, 9, 3, 1, 4, 0, 0, 0, 1, 5, 7, 4, 6, 0, 0, 2, 9, 0, 1, 6, 2, 0, 0, 5, 3, 0, 2, 5, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 0, 11, 0, 0, 0, 31, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 0, 0, 0, 0, 0, 23, 0, 0, 0, 0, 0, 0, 11, 0, 0, 9, 0, 0, 0, 0, 8, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 11, 25, 18, 0, 33, 31, 0, 0, 0, 0, 0, 17, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
);
const _kakuroHard = _KakuroData(
  'Hard Core', 10,
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 4, 2, 8, 1, 9, 0, 0, 0, 3, 1, 6, 9, 7, 8, 5, 2, 0, 0, 1, 8, 0, 5, 9, 0, 8, 1, 0, 0, 7, 5, 6, 8, 4, 2, 1, 3, 0, 0, 5, 4, 2, 6, 1, 7, 3, 8, 0, 0, 2, 6, 0, 1, 6, 0, 2, 5, 0, 0, 8, 2, 7, 4, 3, 1, 6, 9, 0, 0, 0, 9, 1, 3, 2, 4, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 27, 0, 0, 0, 0, 0, 0, 0, 0, 41, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9, 0, 0, 14, 0, 0, 9, 0, 0, 0, 36, 0, 0, 0, 0, 0, 0, 0, 0, 0, 36, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 7, 0, 0, 7, 0, 0, 0, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 38, 10, 38, 40, 9, 41, 0, 0, 0, 26, 0, 0, 0, 0, 0, 0, 28, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
);
