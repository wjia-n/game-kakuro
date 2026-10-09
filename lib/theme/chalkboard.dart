import 'dart:math';
import 'package:flutter/material.dart';
import 'chalkboard_themes.dart';

// ---------------------------------------------------------------------------
// Typography: Cabin Sketch for chalk headlines, Caveat for handwriting.
// ---------------------------------------------------------------------------

class ChalkType {
  static TextStyle display(double size,
      {required ChalkThemeDef theme, Color? color, double? height}) {
    return TextStyle(
      fontFamily: 'CabinSketch',
      fontWeight: FontWeight.w700,
      fontSize: size,
      height: height,
      color: color ?? theme.chalk,
      letterSpacing: 0.5,
    );
  }

  static TextStyle hand(double size,
      {required ChalkThemeDef theme, Color? color, double? height}) {
    return TextStyle(
      fontFamily: 'Caveat',
      fontWeight: FontWeight.w600,
      fontSize: size,
      height: height,
      color: color ?? theme.chalk,
    );
  }

  static TextStyle small(double size,
      {required ChalkThemeDef theme, Color? color}) {
    return TextStyle(
      fontFamily: 'Caveat',
      fontWeight: FontWeight.w500,
      fontSize: size,
      color: color ?? theme.chalkDim,
    );
  }
}

// ---------------------------------------------------------------------------
// Slate texture: chalk-dust speckle over the board color.
// ---------------------------------------------------------------------------

class SlateTexture extends StatelessWidget {
  final ChalkThemeDef theme;
  final Widget child;
  final double speckleAlpha;
  const SlateTexture(
      {super.key,
      required this.theme,
      required this.child,
      this.speckleAlpha = 0.05});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SlatePainter(
          base: theme.board,
          speck: theme.chalk,
          alpha: speckleAlpha,
          seed: 7),
      child: child,
    );
  }
}

class _SlatePainter extends CustomPainter {
  final Color base;
  final Color speck;
  final double alpha;
  final int seed;
  _SlatePainter(
      {required this.base,
      required this.speck,
      required this.alpha,
      required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = base);
    final rng = Random(seed);
    // chalk-dust speckles
    final count = (size.width * size.height / 900).round().clamp(60, 900);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.4 + rng.nextDouble() * 1.3;
      canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = speck.withValues(alpha: alpha * rng.nextDouble()));
    }
    // a few faint dry-wipe streaks
    for (var i = 0; i < 6; i++) {
      final y = rng.nextDouble() * size.height;
      final x = rng.nextDouble() * size.width;
      final w = 40 + rng.nextDouble() * 120;
      canvas.drawRRect(
          RRect.fromLTRBR(x, y, x + w, y + 2.5, const Radius.circular(2)),
          Paint()..color = speck.withValues(alpha: alpha * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _SlatePainter old) => false;
}

// ---------------------------------------------------------------------------
// Lamp wash: warm radial pool of desk-lamp light, very subtle.
// ---------------------------------------------------------------------------

class LampWash extends StatelessWidget {
  final ChalkThemeDef theme;
  final Widget child;
  const LampWash({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.25, -0.55),
                radius: 1.25,
                colors: [
                  theme.lamp.withValues(alpha: 0.10),
                  theme.lamp.withValues(alpha: 0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Oak frame: raised timber enclosure with rim + shadow edge.
// ---------------------------------------------------------------------------

class OakFrame extends StatelessWidget {
  final ChalkThemeDef theme;
  final Widget child;
  final double rim;
  const OakFrame(
      {super.key, required this.theme, required this.child, this.rim = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(rim),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.frame,
        border: Border.all(color: theme.frameDeep, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
          BoxShadow(
            color: theme.lamp.withValues(alpha: 0.12),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chalk buttons: hand-drawn wobbly outline, amber fill when active.
// ---------------------------------------------------------------------------

class ChalkButton extends StatelessWidget {
  final ChalkThemeDef theme;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final double fontSize;
  final EdgeInsets padding;
  const ChalkButton({
    super.key,
    required this.theme,
    required this.label,
    this.onTap,
    this.active = false,
    this.fontSize = 26,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _WobblyOutlinePainter(
          color: active ? theme.accent : theme.chalk,
          fill: active ? theme.accent.withValues(alpha: 0.22) : null,
          seed: label.hashCode,
          width: active ? 3.2 : 2.4,
        ),
        child: Container(
          padding: padding,
          alignment: Alignment.center,
          child: Text(label,
              style: ChalkType.hand(fontSize,
                  theme: theme,
                  color: active ? theme.accent : theme.chalk)),
        ),
      ),
    );
  }
}

class _WobblyOutlinePainter extends CustomPainter {
  final Color color;
  final Color? fill;
  final int seed;
  final double width;
  _WobblyOutlinePainter(
      {required this.color, this.fill, required this.seed, this.width = 2.4});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    const r = 14.0;
    // wobbly rounded rect path
    final path = Path();
    final pts = <Offset>[];
    void edge(Offset a, Offset b) {
      const steps = 7;
      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        final wob = (rng.nextDouble() - 0.5) * 3.0;
        final p = Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
        // perpendicular wobble
        final dx = b.dx - a.dx;
        final dy = b.dy - a.dy;
        final len = (dx * dx + dy * dy).clamp(1.0, 1e9);
        final nx = -dy / sqrt(len);
        final ny = dx / sqrt(len);
        pts.add(Offset(p.dx + nx * wob, p.dy + ny * wob));
      }
    }

    edge(Offset(r, 2), Offset(size.width - r, 2));
    edge(Offset(size.width - 2, r), Offset(size.width - 2, size.height - r));
    edge(Offset(size.width - r, size.height - 2), Offset(r, size.height - 2));
    edge(Offset(2, size.height - r), Offset(2, r));
    // connect corners with arcs (approximate: just close through corner points)
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _WobblyOutlinePainter old) =>
      old.color != color || old.fill != fill;
}

// ---------------------------------------------------------------------------
// Chalk circle buttons (number pad): >= 48px targets, amber fill when active.
// ---------------------------------------------------------------------------

class ChalkCircleButton extends StatelessWidget {
  final ChalkThemeDef theme;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final double size;
  final double fontSize;
  const ChalkCircleButton({
    super.key,
    required this.theme,
    required this.label,
    this.onTap,
    this.active = false,
    this.size = 56,
    this.fontSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ChalkCirclePainter(
            color: active ? theme.accent : theme.chalk,
            fill: active ? theme.accent.withValues(alpha: 0.25) : null,
            seed: label.hashCode,
          ),
          child: Center(
            child: Text(label,
                style: ChalkType.display(fontSize,
                    theme: theme,
                    color: active ? theme.accent : theme.chalk)),
          ),
        ),
      ),
    );
  }
}

class _ChalkCirclePainter extends CustomPainter {
  final Color color;
  final Color? fill;
  final int seed;
  _ChalkCirclePainter({required this.color, this.fill, required this.seed});

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
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _ChalkCirclePainter old) =>
      old.color != color || old.fill != fill;
}

// ---------------------------------------------------------------------------
// Wooden peg toggle: a small oak peg sliding in a carved slot.
// ---------------------------------------------------------------------------

class PegToggle extends StatelessWidget {
  final ChalkThemeDef theme;
  final bool value;
  final ValueChanged<bool> onChanged;
  const PegToggle(
      {super.key, required this.theme, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 64,
        height: 34,
        child: CustomPaint(
          painter: _PegPainter(theme: theme, value: value),
        ),
      ),
    );
  }
}

class _PegPainter extends CustomPainter {
  final ChalkThemeDef theme;
  final bool value;
  _PegPainter({required this.theme, required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    // carved slot
    final slot = RRect.fromLTRBR(
        2, 10, size.width - 2, size.height - 10, const Radius.circular(8));
    canvas.drawRRect(slot, Paint()..color = theme.frameDeep);
    canvas.drawRRect(
        slot,
        Paint()
          ..color = theme.chalk.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    // wooden peg
    final px = value ? size.width - 20 : 20.0;
    final peg = RRect.fromLTRBR(
        px - 11, 3, px + 11, size.height - 3, const Radius.circular(9));
    canvas.drawRRect(
        peg,
        Paint()
          ..color = theme.frame
          ..style = PaintingStyle.fill);
    // wood grain lines on the peg
    final grain = Paint()
      ..color = theme.frameDeep.withValues(alpha: 0.7)
      ..strokeWidth = 1.1;
    canvas.drawLine(Offset(px - 5, 7), Offset(px - 5, size.height - 7), grain);
    canvas.drawLine(Offset(px + 1, 6), Offset(px + 1, size.height - 6), grain);
    canvas.drawLine(Offset(px + 6, 8), Offset(px + 6, size.height - 8), grain);
    // peg highlight / shadow for physicality
    canvas.drawRRect(
        peg,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);
    if (value) {
      canvas.drawCircle(
          Offset(px, size.height / 2),
          3,
          Paint()..color = theme.accent.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant _PegPainter old) =>
      old.value != value || old.theme != theme;
}

// ---------------------------------------------------------------------------
// Entry animations: chalk-in pop, eraser dust puff, mistake shake.
// ---------------------------------------------------------------------------

/// Digit "chalks in": quick scale + opacity stroke-draw feel.
class ChalkPop extends StatefulWidget {
  final Widget child;
  final int tick; // change to retrigger
  const ChalkPop({super.key, required this.child, required this.tick});

  @override
  State<ChalkPop> createState() => _ChalkPopState();
}

class _ChalkPopState extends State<ChalkPop>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  int _last = -1;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _last = widget.tick;
    if (widget.tick > 0) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ChalkPop old) {
    super.didUpdateWidget(old);
    if (widget.tick != _last) {
      _last = widget.tick;
      _c.forward(from: 0);
    }
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
        final t = _c.value;
        // weighted, physical: fast in, tiny overshoot, settle
        final s = t < 0.6
            ? 0.6 + 0.5 * (t / 0.6)
            : 1.1 - 0.1 * ((t - 0.6) / 0.4);
        return Transform.scale(
          scale: s.clamp(0.6, 1.1),
          child: Opacity(opacity: (0.35 + 0.65 * t).clamp(0.0, 1.0), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Eraser dust puff: soft expanding chalk-dust cloud that fades.
class DustPuff extends StatefulWidget {
  final int tick;
  final Color color;
  const DustPuff({super.key, required this.tick, required this.color});

  @override
  State<DustPuff> createState() => _DustPuffState();
}

class _DustPuffState extends State<DustPuff>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    if (widget.tick > 0) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant DustPuff old) {
    super.didUpdateWidget(old);
    if (widget.tick != old.tick && widget.tick > 0) {
      _c.forward(from: 0);
    }
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
      builder: (_, _) => CustomPaint(
        painter: _DustPainter(progress: _c.value, color: widget.color),
      ),
    );
  }
}

class _DustPainter extends CustomPainter {
  final double progress;
  final Color color;
  _DustPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rng = Random(42);
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 14; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final dist = progress * (10 + rng.nextDouble() * 22);
      final r = (1 - progress) * (2.5 + rng.nextDouble() * 3.5);
      canvas.drawCircle(
          Offset(c.dx + cos(a) * dist, c.dy + sin(a) * dist),
          r,
          Paint()..color = color.withValues(alpha: 0.35 * (1 - progress)));
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) =>
      old.progress != progress || old.color != color;
}

/// Mistake shake: weighted horizontal shake, no springy bounce.
class ShakeChalk extends StatefulWidget {
  final Widget child;
  final int tick;
  const ShakeChalk({super.key, required this.child, required this.tick});

  @override
  State<ShakeChalk> createState() => _ShakeChalkState();
}

class _ShakeChalkState extends State<ShakeChalk>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    if (widget.tick > 0) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant ShakeChalk old) {
    super.didUpdateWidget(old);
    if (widget.tick != old.tick && widget.tick > 0) {
      _c.forward(from: 0);
    }
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
        final dx = sin(_c.value * pi * 4) * 7 * (1 - _c.value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Hint reveal: golden chalk shimmer sweep across the cell.
// ---------------------------------------------------------------------------

class HintReveal extends StatefulWidget {
  final Widget child;
  final int tick;
  final Color shimmer;
  const HintReveal(
      {super.key, required this.child, required this.tick, required this.shimmer});

  @override
  State<HintReveal> createState() => _HintRevealState();
}

class _HintRevealState extends State<HintReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    if (widget.tick > 0) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant HintReveal old) {
    super.didUpdateWidget(old);
    if (widget.tick != old.tick && widget.tick > 0) {
      _c.forward(from: 0);
    }
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
        return CustomPaint(
          foregroundPainter: _ShimmerPainter(
              progress: _c.value, color: widget.shimmer),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;
  _ShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final x = -size.width * 0.3 + progress * size.width * 1.6;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.45 * (1 - progress * 0.5));
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
        Rect.fromLTWH(x - 6, 0, 12, size.height), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) =>
      old.progress != progress;
}

// ---------------------------------------------------------------------------
// Pencil marks: 3x3 mini grid of candidate digits.
// ---------------------------------------------------------------------------

class PencilMarks extends StatelessWidget {
  final int mask;
  final ChalkThemeDef theme;
  final double cellSize;
  const PencilMarks(
      {super.key, required this.mask, required this.theme, required this.cellSize});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(cellSize * 0.08),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemCount: 9,
      itemBuilder: (_, i) {
        final d = i + 1;
        final on = (mask & (1 << d)) != 0;
        return Center(
          child: Text(on ? '$d' : '',
              style: ChalkType.small(cellSize * 0.22,
                  theme: theme, color: theme.pencil)),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Small chalk label chip (timer / difficulty / mistakes panel).
// ---------------------------------------------------------------------------

class ChalkChip extends StatelessWidget {
  final ChalkThemeDef theme;
  final String text;
  const ChalkChip({super.key, required this.theme, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: theme.chalk.withValues(alpha: 0.5), width: 1.4),
        color: theme.boardDeep.withValues(alpha: 0.7),
      ),
      child: Text(text,
          style: ChalkType.hand(19, theme: theme, color: theme.chalk)),
    );
  }
}
