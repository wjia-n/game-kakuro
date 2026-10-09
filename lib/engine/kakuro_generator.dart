import 'dart:math';

/// Pure-Dart Kakuro puzzle generation, solving and validation.
///
/// No Flutter imports: this file runs in tests and in a background isolate
/// (via compute) so generation never blocks the UI thread.
///
/// Generation strategy (validated empirically):
/// 1. Construct a valid black/white pattern (row 0 + col 0 always clue
///    cells; no run of length 1 or > 9 — enforced by construction).
/// 2. Fill the white cells with a valid solution, then *anneal* the fill to
///    minimize the total number of sum-combinations across all runs. Tight
///    clue sums are what make a Kakuro uniquely solvable; random fills
///    essentially never are.
/// 3. Derive clues from the fill and verify uniqueness with a backtracking
///    solver (cap 2). Retry with new fills/patterns until unique.

// ---------------------------------------------------------------------------
// Difficulty specs (RULES.md Section 2: Easy 6x8, Medium 8x10, Hard 10x12)
// ---------------------------------------------------------------------------

enum KakuroDifficulty { easy, medium, hard }

class KakuroDifficultySpec {
  final int rows;
  final int cols;
  final double blackProbability;
  final int annealIters;
  final int fillsPerPattern;
  final String label;
  const KakuroDifficultySpec({
    required this.rows,
    required this.cols,
    required this.blackProbability,
    required this.annealIters,
    required this.fillsPerPattern,
    required this.label,
  });
}

const kakuroDifficultySpecs = <KakuroDifficulty, KakuroDifficultySpec>{
  KakuroDifficulty.easy: KakuroDifficultySpec(
      rows: 6,
      cols: 8,
      blackProbability: 0.30,
      annealIters: 1200,
      fillsPerPattern: 6,
      label: 'Easy'),
  KakuroDifficulty.medium: KakuroDifficultySpec(
      rows: 8,
      cols: 10,
      blackProbability: 0.36,
      annealIters: 1500,
      fillsPerPattern: 8,
      label: 'Medium'),
  KakuroDifficulty.hard: KakuroDifficultySpec(
      rows: 10,
      cols: 12,
      blackProbability: 0.42,
      annealIters: 2000,
      fillsPerPattern: 10,
      label: 'Hard'),
};

// ---------------------------------------------------------------------------
// Puzzle model
// ---------------------------------------------------------------------------

class KakuroRun {
  final List<int> cells; // flat indices, in run order
  final int sum;
  const KakuroRun(this.cells, this.sum);
}

class KakuroPuzzle {
  final int rows;
  final int cols;
  final KakuroDifficulty difficulty;
  final int seed;
  final List<bool> isWhite; // rows*cols
  final List<int> acrossClue; // per cell, 0 = none
  final List<int> downClue; // per cell, 0 = none
  final List<int> solution; // digit per white cell, 0 for clue cells
  final List<KakuroRun> acrossRuns;
  final List<KakuroRun> downRuns;
  final List<int> acrossRunOf; // per cell: run index or -1
  final List<int> downRunOf; // per cell: run index or -1

  const KakuroPuzzle({
    required this.rows,
    required this.cols,
    required this.difficulty,
    required this.seed,
    required this.isWhite,
    required this.acrossClue,
    required this.downClue,
    required this.solution,
    required this.acrossRuns,
    required this.downRuns,
    required this.acrossRunOf,
    required this.downRunOf,
  });

  int get cellCount => rows * cols;
  int idx(int r, int c) => r * cols + c;

  int get whiteCount {
    var n = 0;
    for (final w in isWhite) {
      if (w) n++;
    }
    return n;
  }

  /// Serialize for Continue/resume persistence.
  Map<String, dynamic> toJson() => {
        'rows': rows,
        'cols': cols,
        'difficulty': difficulty.index,
        'seed': seed,
        'isWhite': isWhite.map((b) => b ? 1 : 0).toList(),
        'acrossClue': acrossClue,
        'downClue': downClue,
        'solution': solution,
      };

  static KakuroPuzzle fromJson(Map<String, dynamic> j) {
    final rows = j['rows'] as int;
    final cols = j['cols'] as int;
    final difficulty = KakuroDifficulty.values[j['difficulty'] as int];
    final isWhite =
        (j['isWhite'] as List).map((e) => (e as int) == 1).toList();
    final acrossClue = (j['acrossClue'] as List).map((e) => e as int).toList();
    final downClue = (j['downClue'] as List).map((e) => e as int).toList();
    final solution = (j['solution'] as List).map((e) => e as int).toList();
    return _assemble(
      rows: rows,
      cols: cols,
      difficulty: difficulty,
      seed: j['seed'] as int,
      isWhite: isWhite,
      acrossClue: acrossClue,
      downClue: downClue,
      solution: solution,
    );
  }

  /// Rebuild runs from a pattern + clues (used by fromJson and generation).
  static KakuroPuzzle _assemble({
    required int rows,
    required int cols,
    required KakuroDifficulty difficulty,
    required int seed,
    required List<bool> isWhite,
    required List<int> acrossClue,
    required List<int> downClue,
    required List<int> solution,
  }) {
    int at(int r, int c) => r * cols + c;
    final acrossRuns = <KakuroRun>[];
    final downRuns = <KakuroRun>[];
    final acrossRunOf = List<int>.filled(rows * cols, -1);
    final downRunOf = List<int>.filled(rows * cols, -1);
    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < cols) {
        if (isWhite[at(r, c)]) {
          final cells = <int>[];
          while (c < cols && isWhite[at(r, c)]) {
            cells.add(at(r, c));
            c++;
          }
          var sum = 0;
          for (final i in cells) {
            sum += solution[i];
          }
          final ri = acrossRuns.length;
          acrossRuns.add(KakuroRun(cells, sum));
          for (final i in cells) {
            acrossRunOf[i] = ri;
          }
        } else {
          c++;
        }
      }
    }
    for (var c = 0; c < cols; c++) {
      var r = 0;
      while (r < rows) {
        if (isWhite[at(r, c)]) {
          final cells = <int>[];
          while (r < rows && isWhite[at(r, c)]) {
            cells.add(at(r, c));
            r++;
          }
          var sum = 0;
          for (final i in cells) {
            sum += solution[i];
          }
          final ri = downRuns.length;
          downRuns.add(KakuroRun(cells, sum));
          for (final i in cells) {
            downRunOf[i] = ri;
          }
        } else {
          r++;
        }
      }
    }
    return KakuroPuzzle(
      rows: rows,
      cols: cols,
      difficulty: difficulty,
      seed: seed,
      isWhite: isWhite,
      acrossClue: acrossClue,
      downClue: downClue,
      solution: solution,
      acrossRuns: acrossRuns,
      downRuns: downRuns,
      acrossRunOf: acrossRunOf,
      downRunOf: downRunOf,
    );
  }
}

// ---------------------------------------------------------------------------
// Distinct-digit sum combination tables (bitmasks of digits 1-9)
// ---------------------------------------------------------------------------

final Map<int, List<int>> _comboTable = _buildComboTable();

int _comboKey(int sum, int len) => sum * 16 + len;

Map<int, List<int>> _buildComboTable() {
  final table = <int, List<int>>{};
  void rec(int start, int left, int sumLeft, int mask) {
    if (left == 0) {
      if (sumLeft == 0) {
        final len = _popCount(mask);
        final key = _comboKey(_maskSum(mask), len);
        table.putIfAbsent(key, () => <int>[]).add(mask);
      }
      return;
    }
    for (var d = start; d <= 9; d++) {
      if (d > sumLeft) break;
      rec(d + 1, left - 1, sumLeft - d, mask | (1 << d));
    }
  }

  for (var len = 2; len <= 9; len++) {
    var minSum = 0;
    var maxSum = 0;
    for (var k = 0; k < len; k++) {
      minSum += k + 1;
      maxSum += 9 - k;
    }
    for (var s = minSum; s <= maxSum; s++) {
      rec(1, len, s, 0);
    }
  }
  return table;
}

int _popCount(int mask) {
  var n = 0;
  while (mask != 0) {
    mask &= mask - 1;
    n++;
  }
  return n;
}

int _maskSum(int mask) {
  var s = 0;
  for (var d = 1; d <= 9; d++) {
    if ((mask & (1 << d)) != 0) s += d;
  }
  return s;
}

List<int> combosFor(int sum, int len) =>
    _comboTable[_comboKey(sum, len)] ?? const <int>[];

// ---------------------------------------------------------------------------
// Solver: count solutions up to [cap] (MRV backtracking + combo propagation)
// ---------------------------------------------------------------------------

class _SolverState {
  final KakuroPuzzle puzzle;
  final List<int> assigned; // 0 = unassigned
  final List<KakuroRun> runs; // across + down
  int solutions = 0;
  final int cap;
  int nodeBudget;

  _SolverState(this.puzzle, {required this.cap, required this.nodeBudget})
      : assigned = List<int>.filled(puzzle.cellCount, 0),
        runs = [...puzzle.acrossRuns, ...puzzle.downRuns];

  /// Bitmask of digits the cell can take given current assignments.
  /// Digits already placed elsewhere in the same run are excluded
  /// (no-repeat rule, RULES.md Section 7).
  int domainOf(int cell) {
    var mask = 0x3FE; // bits 1..9
    for (final ri in _runsOfCell(cell)) {
      final run = runs[ri];
      var used = 0;
      for (final c in run.cells) {
        final a = assigned[c];
        if (a != 0) used |= (1 << a);
      }
      var union = 0;
      for (final combo in combosFor(run.sum, run.cells.length)) {
        var ok = true;
        for (final c in run.cells) {
          final a = assigned[c];
          if (a != 0 && (combo & (1 << a)) == 0) {
            ok = false;
            break;
          }
        }
        if (ok) union |= combo;
      }
      union &= ~used;
      mask &= union;
      if (mask == 0) return 0;
    }
    return mask;
  }

  List<int> _runsOfCell(int cell) {
    final out = <int>[];
    final a = puzzle.acrossRunOf[cell];
    final d = puzzle.downRunOf[cell];
    if (a >= 0) out.add(a);
    if (d >= 0) out.add(puzzle.acrossRuns.length + d);
    return out;
  }

  bool search() {
    if (solutions >= cap) return true;
    if (--nodeBudget < 0) return true; // budget blown: stop (caller retries)
    // MRV: unassigned white cell with smallest domain.
    var best = -1;
    var bestMask = 0;
    var bestCount = 99;
    for (var i = 0; i < assigned.length; i++) {
      if (!puzzle.isWhite[i] || assigned[i] != 0) continue;
      final m = domainOf(i);
      final cnt = _popCount(m);
      if (cnt == 0) return false;
      if (cnt < bestCount) {
        bestCount = cnt;
        best = i;
        bestMask = m;
        if (cnt == 1) break;
      }
    }
    if (best < 0) {
      solutions++;
      return solutions >= cap;
    }
    var m = bestMask;
    while (m != 0) {
      final bit = m & -m;
      m -= bit;
      var digit = 0;
      for (var d = 1; d <= 9; d++) {
        if ((bit & (1 << d)) != 0) {
          digit = d;
          break;
        }
      }
      assigned[best] = digit;
      if (search()) {
        assigned[best] = 0;
        return true;
      }
      assigned[best] = 0;
    }
    return false;
  }
}

/// Count solutions of [puzzle], stopping at [cap].
int countKakuroSolutions(KakuroPuzzle puzzle,
    {int cap = 2, int nodeBudget = 400000}) {
  final s = _SolverState(puzzle, cap: cap, nodeBudget: nodeBudget);
  s.search();
  return s.solutions;
}

// ---------------------------------------------------------------------------
// Pattern generation (validity by construction)
// ---------------------------------------------------------------------------

/// White-segment lengths touching (r,c) in the 4 directions, assuming (r,c)
/// itself is black. Length 0 = no white neighbor.
List<int> _touchingSegments(
    List<bool> isWhite, int rows, int cols, int r, int c) {
  int at(int rr, int cc) => rr * cols + cc;
  final segs = <int>[];
  var n = 0;
  var cc = c - 1;
  while (cc >= 0 && isWhite[at(r, cc)]) {
    n++;
    cc--;
  }
  segs.add(n);
  n = 0;
  cc = c + 1;
  while (cc < cols && isWhite[at(r, cc)]) {
    n++;
    cc++;
  }
  segs.add(n);
  n = 0;
  var rr = r - 1;
  while (rr >= 0 && isWhite[at(rr, c)]) {
    n++;
    rr--;
  }
  segs.add(n);
  n = 0;
  rr = r + 1;
  while (rr < rows && isWhite[at(rr, c)]) {
    n++;
    rr++;
  }
  segs.add(n);
  return segs;
}

/// Tentatively place a black cell at (r,c); keep it only if no length-1
/// white run is created and the clue cell touches at least one white cell.
bool _tryPlaceBlack(
    List<bool> isWhite, int rows, int cols, int r, int c) {
  int at(int rr, int cc) => rr * cols + cc;
  if (r < 1 || r >= rows || c < 1 || c >= cols) return false;
  if (!isWhite[at(r, c)]) return false;
  isWhite[at(r, c)] = false;
  final segs = _touchingSegments(isWhite, rows, cols, r, c);
  if (segs.any((s) => s == 1) || segs.every((s) => s == 0)) {
    isWhite[at(r, c)] = true; // revert
    return false;
  }
  return true;
}

/// Build a valid pattern. Returns the isWhite list, or null if the attempt
/// fails (caller tries a new seed — attempts are cheap).
List<bool>? _generatePattern(KakuroDifficultySpec spec, Random rng) {
  final rows = spec.rows;
  final cols = spec.cols;
  int at(int r, int c) => r * cols + c;

  // Row 0 and col 0 are always clue cells; interior starts white.
  final isWhite = List<bool>.filled(rows * cols, false);
  for (var r = 1; r < rows; r++) {
    for (var c = 1; c < cols; c++) {
      isWhite[at(r, c)] = true;
    }
  }

  // Wide boards (interior width > 9) need full black columns so no across
  // run exceeds 9 cells. A column split keeps every down run intact.
  final interiorW = cols - 1;
  if (interiorW > 9) {
    // Place full black columns; each resulting across segment must have
    // length >= 2 (length 1 runs are illegal).
    var left = 1;
    final splits = <int>[];
    while (interiorW - left + 1 > 9) {
      // choose a split column: segment [left, split) and (split, ...]
      final minC = left + 2;
      final maxC = (left + 9).clamp(minC, cols - 3);
      if (minC > maxC) return null;
      final c = minC + rng.nextInt(maxC - minC + 1);
      splits.add(c);
      left = c + 1;
    }
    // last segment must also be >= 2
    if (cols - left < 2) return null;
    for (final c in splits) {
      for (var r = 1; r < rows; r++) {
        isWhite[at(r, c)] = false;
      }
    }
  }

  // Random black cells with a local veto (never create length-1 runs).
  // Bias toward splitting long runs: shorter runs constrain more, which is
  // what makes puzzles uniquely solvable.
  final interior = (rows - 1) * (cols - 1);
  var targetBlacks = (interior * spec.blackProbability).round();
  var alreadyBlack = 0;
  for (var r = 1; r < rows; r++) {
    for (var c = 1; c < cols; c++) {
      if (!isWhite[at(r, c)]) alreadyBlack++;
    }
  }
  targetBlacks = (targetBlacks - alreadyBlack).clamp(0, interior);
  var placed = 0;
  for (var tries = 0;
      tries < targetBlacks * 40 && placed < targetBlacks;
      tries++) {
    final r = 1 + rng.nextInt(rows - 1);
    final c = 1 + rng.nextInt(cols - 1);
    if (!isWhite[at(r, c)]) continue;
    var acrossLen = 1;
    var cc = c - 1;
    while (cc >= 1 && isWhite[at(r, cc)]) {
      acrossLen++;
      cc--;
    }
    cc = c + 1;
    while (cc < cols && isWhite[at(r, cc)]) {
      acrossLen++;
      cc++;
    }
    var downLen = 1;
    var rr = r - 1;
    while (rr >= 1 && isWhite[at(rr, c)]) {
      downLen++;
      rr--;
    }
    rr = r + 1;
    while (rr < rows && isWhite[at(rr, c)]) {
      downLen++;
      rr++;
    }
    if ((acrossLen < 4 && downLen < 4) && rng.nextDouble() < 0.7) {
      continue; // prefer breaking up long runs
    }
    if (_tryPlaceBlack(isWhite, rows, cols, r, c)) placed++;
  }

  // Final validation (guaranteed by construction; belt and braces).
  for (var r = 0; r < rows; r++) {
    var c = 0;
    while (c < cols) {
      if (isWhite[at(r, c)]) {
        var c2 = c;
        while (c2 < cols && isWhite[at(r, c2)]) {
          c2++;
        }
        final len = c2 - c;
        if (len < 2 || len > 9) return null;
        c = c2;
      } else {
        c++;
      }
    }
  }
  for (var c = 0; c < cols; c++) {
    var r = 0;
    while (r < rows) {
      if (isWhite[at(r, c)]) {
        var r2 = r;
        while (r2 < rows && isWhite[at(r2, c)]) {
          r2++;
        }
        final len = r2 - r;
        if (len < 2 || len > 9) return null;
        r = r2;
      } else {
        r++;
      }
    }
  }

  // Need a reasonable number of white cells.
  var whiteCount = 0;
  for (final w in isWhite) {
    if (w) whiteCount++;
  }
  if (whiteCount < (rows * cols * 0.25).round()) return null;
  return isWhite;
}

// ---------------------------------------------------------------------------
// Annealed fill: minimize total sum-combinations (tight clues)
// ---------------------------------------------------------------------------

class _PatternRuns {
  final List<List<int>> across;
  final List<List<int>> down;
  final List<int> acrossOf;
  final List<int> downOf;
  _PatternRuns(this.across, this.down, this.acrossOf, this.downOf);
}

_PatternRuns _collectRuns(
    List<bool> isWhite, int rows, int cols) {
  int at(int r, int c) => r * cols + c;
  final across = <List<int>>[];
  final down = <List<int>>[];
  final acrossOf = List<int>.filled(rows * cols, -1);
  final downOf = List<int>.filled(rows * cols, -1);
  for (var r = 0; r < rows; r++) {
    var c = 0;
    while (c < cols) {
      if (isWhite[at(r, c)]) {
        final cells = <int>[];
        while (c < cols && isWhite[at(r, c)]) {
          cells.add(at(r, c));
          c++;
        }
        final i = across.length;
        across.add(cells);
        for (final cell in cells) {
          acrossOf[cell] = i;
        }
      } else {
        c++;
      }
    }
  }
  for (var c = 0; c < cols; c++) {
    var r = 0;
    while (r < rows) {
      if (isWhite[at(r, c)]) {
        final cells = <int>[];
        while (r < rows && isWhite[at(r, c)]) {
          cells.add(at(r, c));
          r++;
        }
        final i = down.length;
        down.add(cells);
        for (final cell in cells) {
          downOf[cell] = i;
        }
      } else {
        r++;
      }
    }
  }
  return _PatternRuns(across, down, acrossOf, downOf);
}

/// Produce a valid solution fill whose run sums are as "tight" (few
/// combinations) as possible. Returns null if no valid fill found.
List<int>? _annealedFill(List<bool> isWhite, int rows, int cols,
    _PatternRuns runs, Random rng, int iters) {
  final sol = List<int>.filled(rows * cols, 0);

  // Greedy initial valid fill (distinct digits per run).
  final order = <int>[];
  for (var i = 0; i < isWhite.length; i++) {
    if (isWhite[i]) order.add(i);
  }
  order.shuffle(rng);
  for (var restart = 0; restart < 60; restart++) {
    sol.fillRange(0, sol.length, 0);
    var ok = true;
    for (final i in order) {
      final used = <int>{};
      for (final run in [
        runs.across[runs.acrossOf[i]],
        runs.down[runs.downOf[i]]
      ]) {
        for (final c in run) {
          if (sol[c] != 0) used.add(sol[c]);
        }
      }
      final choices = <int>[];
      for (var d = 1; d <= 9; d++) {
        if (!used.contains(d)) choices.add(d);
      }
      if (choices.isEmpty) {
        ok = false;
        break;
      }
      sol[i] = choices[rng.nextInt(choices.length)];
    }
    if (ok) break;
    if (restart == 59) return null;
    order.shuffle(rng);
  }

  int runSum(List<int> run) {
    var s = 0;
    for (final c in run) {
      s += sol[c];
    }
    return s;
  }

  int totalCombos() {
    var t = 0;
    for (final run in runs.across) {
      t += combosFor(runSum(run), run.length).length;
    }
    for (final run in runs.down) {
      t += combosFor(runSum(run), run.length).length;
    }
    return t;
  }

  // Greedy annealing: repeatedly apply the single-cell change that most
  // reduces the total combination count.
  for (var it = 0; it < iters; it++) {
    final cell = order[rng.nextInt(order.length)];
    final old = sol[cell];
    final used = <int>{};
    for (final run in [
      runs.across[runs.acrossOf[cell]],
      runs.down[runs.downOf[cell]]
    ]) {
      for (final c in run) {
        if (c != cell && sol[c] != 0) used.add(sol[c]);
      }
    }
    final before = totalCombos();
    var bestD = old;
    var bestScore = before;
    for (var d = 1; d <= 9; d++) {
      if (d == old || used.contains(d)) continue;
      sol[cell] = d;
      final sc = totalCombos();
      if (sc < bestScore) {
        bestScore = sc;
        bestD = d;
      }
    }
    sol[cell] = bestD;
  }
  return sol;
}

// ---------------------------------------------------------------------------
// Generation entry point
// ---------------------------------------------------------------------------

class KakuroGenParams {
  final KakuroDifficulty difficulty;
  final int seed;
  const KakuroGenParams(this.difficulty, this.seed);
}

/// Generate a puzzle with a guaranteed unique solution.
/// Top-level so it can run in an isolate via compute().
KakuroPuzzle generateKakuroPuzzle(KakuroGenParams params) {
  final spec = kakuroDifficultySpecs[params.difficulty]!;
  final rng = Random(params.seed);
  const maxPatternAttempts = 40;
  for (var attempt = 0; attempt < maxPatternAttempts; attempt++) {
    final isWhite =
        _generatePattern(spec, Random(rng.nextInt(1 << 32)));
    if (isWhite == null) continue;
    final runs =
        _collectRuns(isWhite, spec.rows, spec.cols);
    for (var f = 0; f < spec.fillsPerPattern; f++) {
      final fill = _annealedFill(isWhite, spec.rows, spec.cols, runs,
          Random(rng.nextInt(1 << 32)), spec.annealIters);
      if (fill == null) continue;
      final puzzle = _buildPuzzle(
          spec, params.difficulty, params.seed, isWhite, fill);
      // Uniqueness check (RULES.md Sections 7 and 11).
      if (countKakuroSolutions(puzzle, cap: 2) == 1) return puzzle;
    }
  }
  throw StateError('Could not generate a unique Kakuro puzzle');
}

KakuroPuzzle _buildPuzzle(
    KakuroDifficultySpec spec,
    KakuroDifficulty difficulty,
    int seed,
    List<bool> isWhite,
    List<int> solution) {
  final rows = spec.rows;
  final cols = spec.cols;
  int at(int r, int c) => r * cols + c;
  final acrossClue = List<int>.filled(rows * cols, 0);
  final downClue = List<int>.filled(rows * cols, 0);
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      final i = at(r, c);
      if (isWhite[i]) continue;
      if (c + 1 < cols && isWhite[at(r, c + 1)]) {
        var sum = 0;
        var cc = c + 1;
        while (cc < cols && isWhite[at(r, cc)]) {
          sum += solution[at(r, cc)];
          cc++;
        }
        acrossClue[i] = sum;
      }
      if (r + 1 < rows && isWhite[at(r + 1, c)]) {
        var sum = 0;
        var rr = r + 1;
        while (rr < rows && isWhite[at(rr, c)]) {
          sum += solution[at(rr, c)];
          rr++;
        }
        downClue[i] = sum;
      }
    }
  }
  return KakuroPuzzle._assemble(
    rows: rows,
    cols: cols,
    difficulty: difficulty,
    seed: seed,
    isWhite: isWhite,
    acrossClue: acrossClue,
    downClue: downClue,
    solution: solution,
  );
}

// ---------------------------------------------------------------------------
// Live validation (RULES.md Section 12: mistake counting)
// ---------------------------------------------------------------------------

class KakuroValidation {
  final bool duplicate; // certain duplicate digit within a run
  final bool sumMismatch; // completed run whose sum is wrong
  const KakuroValidation({required this.duplicate, required this.sumMismatch});
  bool get isMistake => duplicate || sumMismatch;
}

/// Validate entering [digit] into [cell] given current [entries].
/// A mistake is counted only when the validator PROVES the entry wrong:
/// a duplicate digit inside any of the cell's runs, or a completed run
/// whose sum mismatches the clue. Unverifiable entries are never mistakes.
KakuroValidation validateEntry(
    KakuroPuzzle puzzle, List<int> entries, int cell, int digit) {
  var duplicate = false;
  var sumMismatch = false;
  final runIdxs = <int>[];
  final a = puzzle.acrossRunOf[cell];
  final d = puzzle.downRunOf[cell];
  if (a >= 0) runIdxs.add(a);
  if (d >= 0) runIdxs.add(puzzle.acrossRuns.length + d);
  final runs = [...puzzle.acrossRuns, ...puzzle.downRuns];
  for (final ri in runIdxs) {
    final run = runs[ri];
    final seen = <int>{};
    var complete = true;
    var sum = 0;
    for (final i in run.cells) {
      final v = i == cell ? digit : entries[i];
      if (v == 0) {
        complete = false;
      } else {
        if (!seen.add(v)) duplicate = true;
        sum += v;
      }
    }
    if (complete && sum != run.sum) sumMismatch = true;
  }
  return KakuroValidation(duplicate: duplicate, sumMismatch: sumMismatch);
}

/// All error cells for highlighting: duplicates in partial runs are flagged
/// immediately; sum mismatches only on completed runs.
Set<int> computeErrorCells(KakuroPuzzle puzzle, List<int> entries) {
  final errors = <int>{};
  final runs = [...puzzle.acrossRuns, ...puzzle.downRuns];
  for (final run in runs) {
    final seen = <int, int>{};
    var complete = true;
    var sum = 0;
    for (final i in run.cells) {
      final v = entries[i];
      if (v == 0) {
        complete = false;
      } else {
        sum += v;
        if (seen.containsKey(v)) {
          errors.add(i);
          errors.add(seen[v]!);
        } else {
          seen[v] = i;
        }
      }
    }
    if (complete && sum != run.sum) {
      errors.addAll(run.cells);
    }
  }
  return errors;
}

/// True when every white cell is filled and every run is valid.
bool isPuzzleSolved(KakuroPuzzle puzzle, List<int> entries) {
  for (final run in [...puzzle.acrossRuns, ...puzzle.downRuns]) {
    final seen = <int>{};
    var sum = 0;
    for (final i in run.cells) {
      final v = entries[i];
      if (v == 0) return false;
      if (!seen.add(v)) return false;
      sum += v;
    }
    if (sum != run.sum) return false;
  }
  return true;
}

/// Candidate digits for [cell] treating current [entries] as fixed.
int candidatesFor(KakuroPuzzle puzzle, List<int> entries, int cell) {
  var mask = 0x3FE;
  final runs = [...puzzle.acrossRuns, ...puzzle.downRuns];
  final idxs = <int>[];
  final a = puzzle.acrossRunOf[cell];
  final d = puzzle.downRunOf[cell];
  if (a >= 0) idxs.add(a);
  if (d >= 0) idxs.add(puzzle.acrossRuns.length + d);
  for (final ri in idxs) {
    final run = runs[ri];
    var used = 0;
    for (final c in run.cells) {
      final e = entries[c];
      if (e != 0) used |= (1 << e);
    }
    var union = 0;
    for (final combo in combosFor(run.sum, run.cells.length)) {
      var ok = true;
      for (final c in run.cells) {
        final e = entries[c];
        if (e != 0 && (combo & (1 << e)) == 0) {
          ok = false;
          break;
        }
      }
      if (ok) union |= combo;
    }
    union &= ~used;
    mask &= union;
    if (mask == 0) return 0;
  }
  return mask;
}
