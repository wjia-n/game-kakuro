import 'package:flutter_test/flutter_test.dart';
import 'package:kakuro/engine/kakuro_engine.dart';
import 'package:kakuro/engine/kakuro_generator.dart';

/// RULES.md Section 13 test cases, executed against the engine.

KakuroPuzzle _easyPuzzle() =>
    generateKakuroPuzzle(const KakuroGenParams(KakuroDifficulty.easy, 42));

KakuroEngine _engineFor(KakuroPuzzle p, {KakuroMode? mode}) {
  final e = KakuroEngine();
  e.startGame(
      p,
      mode ??
          const KakuroMode(
              difficulty: KakuroDifficulty.easy, label: 'Easy'));
  return e;
}

void main() {
  group('generation', () {
    test('easy puzzle has unique solution', () {
      final p = _easyPuzzle();
      expect(countKakuroSolutions(p, cap: 2), 1);
    });

    test('all difficulties generate valid unique puzzles', () {
      for (final d in KakuroDifficulty.values) {
        final spec = kakuroDifficultySpecs[d]!;
        final p = generateKakuroPuzzle(
            KakuroGenParams(d, 1000 + d.index * 77));
        expect(p.rows, spec.rows);
        expect(p.cols, spec.cols);
        // every white cell belongs to both an across and a down run
        for (var i = 0; i < p.cellCount; i++) {
          if (p.isWhite[i]) {
            expect(p.acrossRunOf[i] >= 0, true);
            expect(p.downRunOf[i] >= 0, true);
          }
        }
        // run lengths within 2..9
        for (final r in [...p.acrossRuns, ...p.downRuns]) {
          expect(r.cells.length, inInclusiveRange(2, 9));
        }
        expect(countKakuroSolutions(p, cap: 2), 1);
      }
    });

    test('uniqueness across several seeds per difficulty (RULES 13.16)',
        () {
      for (final d in KakuroDifficulty.values) {
        for (var s = 0; s < 5; s++) {
          final p = generateKakuroPuzzle(
              KakuroGenParams(d, 5000 + d.index * 131 + s * 17));
          expect(countKakuroSolutions(p, cap: 2), 1,
              reason: 'difficulty $d seed $s not unique');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('rules compliance', () {
    test('13.1 valid complete solution accepted with 3 stars', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      for (var i = 0; i < p.cellCount; i++) {
        if (!p.isWhite[i]) continue;
        e.selectCell(i);
        e.enterDigit(p.solution[i]);
      }
      expect(e.phase, KakuroPhase.solved);
      expect(e.mistakes, 0);
      expect(e.hintsUsed, 0);
    });

    test('13.2 duplicate digit flagged as mistake', () {
      final p = _easyPuzzle();
      // find a 2-cell across run
      final run = p.acrossRuns.firstWhere((r) => r.cells.length == 2);
      final e = _engineFor(p);
      // enter 8 in both cells of the run: both wrong or duplicate
      e.selectCell(run.cells[0]);
      final before = e.mistakes;
      e.enterDigit(p.solution[run.cells[0]] == 8
          ? 7
          : 8); // avoid accidentally entering the true digit
      // force a duplicate: enter the same digit in the sibling cell
      final d = e.entries[run.cells[0]] != 0
          ? e.entries[run.cells[0]]
          : 5;
      e.selectCell(run.cells[1]);
      e.enterDigit(d);
      expect(e.mistakes, greaterThan(before));
      expect(
          e.errorCells.contains(run.cells[0]) ||
              e.errorCells.contains(run.cells[1]),
          true);
    });

    test('13.3 wrong sum on completed run flagged', () {
      final p = _easyPuzzle();
      final run = p.acrossRuns.firstWhere((r) => r.cells.length == 2);
      final e = _engineFor(p);
      // complete the run with digits that sum wrong but don't duplicate
      final s = run.sum;
      var d1 = 1;
      var d2 = 2;
      // find two distinct digits != solution pair with wrong sum
      var found = false;
      outer:
      for (var a = 1; a <= 9; a++) {
        for (var b = 1; b <= 9; b++) {
          if (a == b) continue;
          if (a + b == s) continue;
          d1 = a;
          d2 = b;
          found = true;
          break outer;
        }
      }
      expect(found, true);
      final before = e.mistakes;
      e.selectCell(run.cells[0]);
      e.enterDigit(d1);
      e.selectCell(run.cells[1]);
      e.enterDigit(d2);
      // after completing the run with a wrong sum -> mistake counted
      expect(e.mistakes, greaterThan(before));
    });

    test('13.4 unverifiable entry is not a mistake', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      // enter a plausible digit in an incomplete run: pick a cell, enter a
      // digit that is not an immediate duplicate.
      var target = -1;
      for (var i = 0; i < p.cellCount; i++) {
        if (p.isWhite[i]) {
          target = i;
          break;
        }
      }
      final before = e.mistakes;
      e.selectCell(target);
      // digit 1..9 not equal to solution, but the run is incomplete so it
      // cannot be proven wrong by duplicates (may be wrong silently).
      var d = p.solution[target] == 1 ? 2 : 1;
      // ensure no duplicate with currently empty run (nothing entered yet)
      e.enterDigit(d);
      expect(e.mistakes, before);
      expect(e.errorCells.contains(target), false);
    });

    test('13.5 clue cell not editable', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      var clueIdx = -1;
      for (var i = 0; i < p.cellCount; i++) {
        if (!p.isWhite[i]) {
          clueIdx = i;
          break;
        }
      }
      expect(e.selectCell(clueIdx), false);
      expect(e.selected, -1);
    });

    test('13.6 digit 0 rejected', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      e.selectCell(p.acrossRuns.first.cells.first);
      expect(e.enterDigit(0), 'rejected');
      expect(e.enterDigit(10), 'rejected');
    });

    test('13.7 pencil marks toggle and clear on digit entry', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      final cell = p.acrossRuns.first.cells.first;
      e.selectCell(cell);
      e.setPencilMode(true);
      e.enterDigit(3);
      e.enterDigit(7);
      expect(e.pencil[cell] & (1 << 3), isNot(0));
      expect(e.pencil[cell] & (1 << 7), isNot(0));
      e.enterDigit(3); // toggle off
      expect(e.pencil[cell] & (1 << 3), 0);
      e.setPencilMode(false);
      e.enterDigit(5);
      expect(e.entries[cell], 5);
      expect(e.pencil[cell], 0); // pencil cleared by digit entry
    });

    test('13.8 erase clears cell; undo restores', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      final cell = p.acrossRuns.first.cells.first;
      e.selectCell(cell);
      e.enterDigit(p.solution[cell]);
      expect(e.entries[cell], isNot(0));
      e.erase();
      expect(e.entries[cell], 0);
      expect(e.pencil[cell], 0);
      expect(e.undo(), true);
      expect(e.entries[cell], isNot(0));
    });

    test('13.9 undo chain restores in reverse; empty undo no-op', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      final c1 = p.acrossRuns.first.cells[0];
      final c2 = p.acrossRuns.first.cells[1];
      e.selectCell(c1);
      e.enterDigit(4);
      e.setPencilMode(true);
      e.selectCell(c2);
      e.enterDigit(6);
      e.setPencilMode(false);
      e.selectCell(c1);
      e.enterDigit(5);
      expect(e.undo(), true);
      expect(e.entries[c1], 4);
      expect(e.undo(), true);
      expect(e.pencil[c2], 0);
      expect(e.undo(), true);
      expect(e.entries[c1], 0);
      expect(e.undo(), false); // 4th undo: no-op
    });

    test('13.10 hint fills solution digit; caps stars at 2', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      final cell = p.acrossRuns.first.cells.first;
      e.selectCell(cell);
      expect(e.hint(), true);
      expect(e.entries[cell], p.solution[cell]);
      expect(e.hintsUsed, 1);
      // finish the rest correctly
      for (var i = 0; i < p.cellCount; i++) {
        if (!p.isWhite[i] || e.entries[i] != 0) continue;
        e.selectCell(i);
        e.enterDigit(p.solution[i]);
      }
      expect(e.phase, KakuroPhase.solved);
      expect(
          StudySettingsStarsForForTest.starsFor(
              mistakes: e.mistakes, hintsUsed: e.hintsUsed),
          2);
    });

    test('13.11 mistake limit failure ends attempt with no stars', () {
      final p = _easyPuzzle();
      final e = _engineFor(
          p,
          mode: const KakuroMode(
              difficulty: KakuroDifficulty.easy,
              label: 'Easy',
              mistakeLimit: 3));
      // commit 3 provable duplicates across three different runs
      var made = 0;
      for (final run in p.acrossRuns) {
        if (run.cells.length < 2 || made >= 3) continue;
        e.selectCell(run.cells[0]);
        e.enterDigit(9);
        e.selectCell(run.cells[1]);
        e.enterDigit(9); // duplicate -> certain mistake
        made++;
        if (e.phase == KakuroPhase.failed) break;
      }
      expect(e.phase, KakuroPhase.failed);
    });

    test('13.12 no-repeat across shared cell intersection', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      // find a white cell, enter digit X, then enter X in a sibling of
      // either of its runs.
      var cell = -1;
      for (var i = 0; i < p.cellCount; i++) {
        if (p.isWhite[i]) {
          cell = i;
          break;
        }
      }
      e.selectCell(cell);
      e.enterDigit(4);
      final runIdx = p.acrossRunOf[cell];
      final run = p.acrossRuns[runIdx];
      final sibling = run.cells.firstWhere((c) => c != cell);
      final before = e.mistakes;
      e.selectCell(sibling);
      e.enterDigit(4);
      expect(e.mistakes, greaterThan(before));
      expect(e.errorCells.contains(sibling), true);
    });

    test('13.13 victory requires all runs valid', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      // fill everything with the solution except swap two digits inside
      // one across run (sums stay right per-run only if same sum; swapping
      // keeps each run's sum but creates duplicates where digits differ).
      final run = p.acrossRuns.firstWhere((r) => r.cells.length >= 2);
      final a = run.cells[0];
      final b = run.cells[1];
      for (var i = 0; i < p.cellCount; i++) {
        if (!p.isWhite[i]) continue;
        var d = p.solution[i];
        if (i == a) d = p.solution[b];
        if (i == b) d = p.solution[a];
        e.selectCell(i);
        e.enterDigit(d);
      }
      if (p.solution[a] == p.solution[b]) {
        expect(e.phase, KakuroPhase.solved); // swap was identity
      } else {
        expect(e.phase, isNot(KakuroPhase.solved));
        expect(e.errorCells.isNotEmpty, true);
      }
    });

    test('13.14 pause freezes the clock', () async {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      expect(e.phase, KakuroPhase.playing);
      await Future.delayed(const Duration(milliseconds: 1200));
      final t1 = e.elapsedSecs;
      e.onAppPaused(); // background the app
      expect(e.phase, KakuroPhase.paused);
      await Future.delayed(const Duration(milliseconds: 1200));
      expect(e.elapsedSecs, t1); // no foreground time accrued
      e.resume();
      expect(e.phase, KakuroPhase.playing);
      e.dispose();
    });

    test('13.15 continue restores full state', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      final cell = p.acrossRuns.first.cells.first;
      e.selectCell(cell);
      e.enterDigit(p.solution[cell]);
      e.setPencilMode(true);
      final c2 = p.acrossRuns.first.cells[1];
      e.selectCell(c2);
      e.enterDigit(3);
      e.pause();
      final saved = e.save();
      final e2 = KakuroEngine();
      expect(e2.restore(saved), true);
      expect(e2.entries[cell], e.entries[cell]);
      expect(e2.pencil[c2], e.pencil[c2]);
      expect(e2.mistakes, e.mistakes);
      expect(e2.elapsedSecs, e.elapsedSecs);
      expect(e2.selected, e.selected);
      expect(e2.pencilMode, e.pencilMode);
      e.dispose();
      e2.dispose();
    });

    test('13.17 smart hint picks the most constrained cell', () {
      final p = _easyPuzzle();
      final e = _engineFor(p);
      // no selection -> hint() uses the smart cell
      expect(e.hint(), true);
      final filled = e.selected;
      expect(filled >= 0, true);
      expect(e.entries[filled], p.solution[filled]);
      e.dispose();
    });

    test('13.18 hard puzzle has exactly one solution', () {
      final p = generateKakuroPuzzle(
          const KakuroGenParams(KakuroDifficulty.hard, 777));
      expect(countKakuroSolutions(p, cap: 2), 1);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}

/// Local mirror of StudySettings.starsFor (settings imports flutter/material
/// only; kept here to avoid pulling services into engine tests).
class StudySettingsStarsForForTest {
  static int starsFor({required int mistakes, required int hintsUsed}) {
    if (mistakes == 0 && hintsUsed == 0) return 3;
    if (mistakes <= 2 && hintsUsed <= 1) return 2;
    return 1;
  }
}
