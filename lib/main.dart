import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const KakuroApp());

class KakuroApp extends StatelessWidget {
  const KakuroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Kakuro',
      tagline: 'Cross-sums number puzzle for true logic lovers. Sudoku\'s spicy cousin!',
      emoji: '➕',
      slug: 'kakuro',
      howToPlay:
          '• Each clue is the SUM of the white cells in its row or column run.\n• Tap a white cell, then tap 1–9 on the pad. Digits can\'t repeat inside a run.\n• Wrong digit? It shakes off and counts as a mistake — think before you ink!\n• Fill every white cell to conquer the puzzle. Three difficulties, zero mercy. ➕',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => KakuroScreen(players: players, callbacks: cb),
    );
  }
}
