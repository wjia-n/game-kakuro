import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/chalkboard.dart';
import '../theme/chalkboard_themes.dart';

/// Custom chalkboard creator: pick board, chalk, accent and frame colors
/// from curated swatches, preview live, and chalk it in.
class CustomThemeScreen extends StatefulWidget {
  final StudyAudio audio;
  final StudySettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  static const _groups = [
    ('Board', ['board', 'boardDeep', 'entry', 'desk']),
    ('Chalk', ['chalk', 'chalkDim', 'pencil']),
    ('Accents', ['accent', 'lamp', 'error']),
    ('Frame', ['frame', 'frameDeep']),
  ];

  static const _labels = {
    'board': 'Slate',
    'boardDeep': 'Clue cells',
    'entry': 'Entry cells',
    'desk': 'Desk',
    'chalk': 'Chalk',
    'chalkDim': 'Dim chalk',
    'pencil': 'Pencil',
    'accent': 'Amber',
    'lamp': 'Lamp wash',
    'error': 'Error red',
    'frame': 'Oak rim',
    'frameDeep': 'Oak shadow',
  };

  /// Curated swatches per slot — all inside the study material world.
  static const _swatches = {
    'board': [
      0xFF1E2522, 0xFF191919, 0xFF1A2233, 0xFF1C2A20, 0xFF2E1F1A,
      0xFF232A18, 0xFF1E1E3A, 0xFF2A1E2E, 0xFF16282E, 0xFFE8DCC0,
      0xFFDDE4E4, 0xFFE4D3AC, 0xFFDDE0CC, 0xFF141E33, 0xFF2B1A12,
    ],
    'boardDeep': [
      0xFF171C1A, 0xFF111111, 0xFF131A28, 0xFF142017, 0xFF231712,
      0xFF1A2011, 0xFF15152A, 0xFF1F1522, 0xFF0F1E23, 0xFFD9CBA9,
      0xFFCBD4D4, 0xFFD4C194, 0xFFCCD0B4, 0xFF0D1526, 0xFF201209,
    ],
    'entry': [
      0xFF232B27, 0xFF202020, 0xFF1F2940, 0xFF223026, 0xFF37251F,
      0xFF2A321E, 0xFF252544, 0xFF332538, 0xFF1C3038, 0xFFF2E8D2,
      0xFFE8EDED, 0xFFEEDDBB, 0xFFE6E9D8, 0xFF1A2540, 0xFF352016,
    ],
    'desk': [
      0xFF12140F, 0xFF0B0B0B, 0xFF0D1119, 0xFF10160F, 0xFF1A100C,
      0xFF141809, 0xFF101022, 0xFF160F18, 0xFF0B1518, 0xFFC9B78E,
      0xFFB9C4C2, 0xFFC2A878, 0xFFBCC09E, 0xFF090E1A, 0xFF150C06,
    ],
    'chalk': [
      0xFFF4E8B0, 0xFFF5F0E0, 0xFFEDECE4, 0xFFF1E7C4, 0xFFF6E3C2,
      0xFFF2E6BC, 0xFFEFE9F5, 0xFFF3E4EE, 0xFFEAF2EE, 0xFF4A3A26,
      0xFF1F3A4D, 0xFF3E2C18, 0xFF2E3A24, 0xFFF0EFE8, 0xFFF6E8CC,
    ],
    'chalkDim': [
      0xFFB9AC7E, 0xFFA8A094, 0xFF9AA4BC, 0xFFA8B394, 0xFFB99A78,
      0xFFA3AC82, 0xFF9A94B8, 0xFFAE94A8, 0xFF8AA4A0, 0xFF8A7554,
      0xFF5E7A8C, 0xFF7E6A48, 0xFF6E7A5E, 0xFF8E9AB5, 0xFFB08E66,
    ],
    'pencil': [
      0xFF8CA891, 0xFF9AA8B0, 0xFF8FB3C7, 0xFF9DBE8C, 0xFFA8B08A,
      0xFFB0C48A, 0xFF9AB0D0, 0xFFA8B89A, 0xFF8AC0B0, 0xFF6E8F5E,
      0xFF4E7A68, 0xFF5E7A52, 0xFF4E6E48, 0xFF8FA8C8, 0xFFB0A07A,
    ],
    'accent': [
      0xFFC98544, 0xFFD9A441, 0xFFE0A83C, 0xFFF08030, 0xFFB4712A,
      0xFF9A5F22, 0xFFD9A441, 0xFFC98544, 0xFFE08A3C, 0xFF8A5A22,
    ],
    'lamp': [
      0xFFC98544, 0xFFD9A441, 0xFFFFF3D6, 0xFFFFFFFF, 0xFFE08A3C,
      0xFFF08030, 0xFFFFF6DC, 0xFFC99A4B,
    ],
    'error': [
      0xFFD06048, 0xFFC65B43, 0xFFB0402A, 0xFFA83A24, 0xFFD0553A,
      0xFFE04A28,
    ],
    'frame': [
      0xFF7A4B20, 0xFF3A3A3A, 0xFF5A3A22, 0xFF6B4423, 0xFF8A4A24,
      0xFF6E4E22, 0xFF4A3420, 0xFF5C3A3E, 0xFF54402A, 0xFF7A3A18,
      0xFF6B4E2A, 0xFF3E3222,
    ],
    'frameDeep': [
      0xFF4A2C11, 0xFF1E1E1E, 0xFF38220F, 0xFF422712, 0xFF552A10,
      0xFF45300F, 0xFF2C1E0E, 0xFF3A2226, 0xFF332512, 0xFF4A2008,
      0xFF42300F, 0xFF241C0E,
    ],
  };

  String _picked = 'board';

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    final preview = widget.settings.customTheme;
    return Scaffold(
      backgroundColor: theme.desk,
      body: LampWash(
        theme: theme,
        child: SlateTexture(
          theme: theme,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          widget.audio.click();
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.arrow_back,
                            color: theme.chalk, size: 26),
                      ),
                      Expanded(
                        child: Text('My Chalkboard',
                            textAlign: TextAlign.center,
                            style: ChalkType.display(
                                30, theme: theme)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Live preview.
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  child: OakFrame(
                    theme: preview,
                    rim: 8,
                    child: Container(
                      height: 120,
                      color: preview.board,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                        children: [
                          _previewCell(preview, clue: true),
                          _previewCell(preview, digit: '7'),
                          _previewCell(preview, digit: '3'),
                          _previewCell(preview,
                              digit: '9', selected: true),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        for (final g in _groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                4, 12, 4, 6),
                            child: Text(g.$1,
                                style: ChalkType.display(
                                    22, theme: theme)),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final key in g.$2)
                                _slotChip(theme, key),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Chalk for: ${_labels[_picked]}',
                          textAlign: TextAlign.center,
                          style: ChalkType.hand(22,
                              theme: theme,
                              color: theme.accent),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final argb
                                in _swatches[_picked]!)
                              _swatch(theme, _picked, argb),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ChalkButton(
                                theme: theme,
                                label: 'Reset',
                                fontSize: 20,
                                onTap: () {
                                  widget.settings
                                      .resetCustomColors();
                                  widget.audio.erase();
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChalkButton(
                                theme: theme,
                                label: 'Chalk it in',
                                fontSize: 20,
                                active: true,
                                onTap: () {
                                  widget.settings
                                      .setTheme('custom');
                                  widget.audio.chalkWrite();
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewCell(ChalkThemeDef p,
      {bool clue = false, String digit = '', bool selected = false}) {
    return Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: clue ? p.boardDeep : p.entry,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
            color: selected ? p.accent : p.chalk.withValues(alpha: 0.5),
            width: selected ? 2.4 : 1.2),
      ),
      alignment: Alignment.center,
      child: clue
          ? Text('16',
              style: ChalkType.small(16,
                  theme: p, color: p.chalkDim))
          : Text(digit,
              style: ChalkType.display(30,
                  theme: p,
                  color: selected ? p.accent : p.chalk)),
    );
  }

  Widget _slotChip(ChalkThemeDef theme, String key) {
    final active = _picked == key;
    final color =
        Color(widget.settings.customColors[key] ?? 0xFF000000);
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        setState(() => _picked = key);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? theme.accent : theme.chalkDim,
              width: active ? 2 : 1.2),
          color: active
              ? theme.accent.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: theme.chalk.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(width: 6),
            Text(_labels[key]!,
                style: ChalkType.small(15, theme: theme)),
          ],
        ),
      ),
    );
  }

  Widget _swatch(ChalkThemeDef theme, String key, int argb) {
    final active = widget.settings.customColors[key] == argb;
    return GestureDetector(
      onTap: () {
        widget.settings.setCustomColor(key, argb);
        widget.audio.click();
        setState(() {});
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Color(argb),
          shape: BoxShape.circle,
          border: Border.all(
              color: active
                  ? theme.accent
                  : theme.chalk.withValues(alpha: 0.4),
              width: active ? 3 : 1.2),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: theme.accent
                          .withValues(alpha: 0.5),
                      blurRadius: 8)
                ]
              : null,
        ),
      ),
    );
  }
}
