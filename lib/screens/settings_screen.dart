import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/chalkboard.dart';
import '../theme/chalkboard_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// "Study Settings": chalk panels with wooden toggle pegs, chalk-circle
/// difficulty selector, theme picker with many colorways + custom creator.
class SettingsScreen extends StatefulWidget {
  final StudyAudio audio;
  final StudySettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StudySettings get _s => widget.settings;
  ChalkThemeDef get _theme => _s.theme;

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
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
                        child: Text('Study Settings',
                            textAlign: TextAlign.center,
                            style:
                                ChalkType.display(34, theme: theme)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionTitle('Scholar'),
                        _Panel(theme: theme, child: _nameRow()),
                        _sectionTitle('Sound'),
                        _Panel(
                          theme: theme,
                          child: Column(
                            children: [
                              _pegRow('Music', _s.musicOn, (v) {
                                _s.setMusic(v);
                                _applyAudio();
                              }),
                              _divider(),
                              _pegRow('Sound effects', _s.sfxOn,
                                  (v) {
                                _s.setSfx(v);
                                _applyAudio();
                              }),
                              _divider(),
                              _volumeRow(),
                            ],
                          ),
                        ),
                        _sectionTitle('Puzzle'),
                        _Panel(
                          theme: theme,
                          child: Column(
                            children: [
                              _pegRow('Pencil mode by default',
                                  _s.pencilDefault, (v) {
                                _s.setPencilDefault(v);
                                widget.audio.click();
                              }),
                              _divider(),
                              _pegRow('Flag errors live',
                                  _s.errorHighlight, (v) {
                                _s.setErrorHighlight(v);
                                widget.audio.click();
                              }),
                              _divider(),
                              _pegRow('3-mistake sudden death',
                                  _s.mistakeLimit, (v) {
                                _s.setMistakeLimit(v);
                                widget.audio.click();
                              }),
                              _divider(),
                              _pegRow('Timed games by default',
                                  _s.timedDefault, (v) {
                                _s.setTimedDefault(v);
                                widget.audio.click();
                              }),
                              _divider(),
                              _pegRow(
                                  'Show timer', _s.showTimer, (v) {
                                _s.setShowTimer(v);
                                widget.audio.click();
                              }),
                            ],
                          ),
                        ),
                        _sectionTitle('Default difficulty'),
                        _Panel(
                          theme: theme,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              for (var i = 0; i < 3; i++)
                                _diffCircle(i),
                            ],
                          ),
                        ),
                        _sectionTitle('Chalkboard theme'),
                        _Panel(
                          theme: theme,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.92,
                                ),
                                itemCount:
                                    ChalkThemes.all.length + 1,
                                itemBuilder: (_, i) =>
                                    _themeTile(i),
                              ),
                              const SizedBox(height: 12),
                              ChalkButton(
                                theme: theme,
                                label: 'Design my own chalkboard',
                                fontSize: 20,
                                onTap: () {
                                  widget.audio.click();
                                  Navigator.of(context)
                                      .push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CustomThemeScreen(
                                        audio: widget.audio,
                                        settings: _s,
                                      ),
                                    ),
                                  )
                                      .then((_) =>
                                          setState(() {}));
                                },
                              ),
                            ],
                          ),
                        ),
                        _sectionTitle('Study record'),
                        _Panel(
                          theme: theme,
                          child: Column(
                            children: [
                              _statRow('Puzzles solved',
                                  '${_s.solved}'),
                              _statRow('Stars earned',
                                  '${_s.starsTotal}★'),
                              _statRow('Daily streak',
                                  '${_s.dailyStreak} days'),
                              _statRow('Best Easy',
                                  _bestLabel(0)),
                              _statRow('Best Medium',
                                  _bestLabel(1)),
                              _statRow('Best Hard',
                                  _bestLabel(2)),
                              const SizedBox(height: 10),
                              ChalkButton(
                                theme: theme,
                                label: 'Reset progress',
                                fontSize: 20,
                                onTap: _confirmReset,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        ChalkButton(
                          theme: theme,
                          label: _s.isPro
                              ? 'Kakuro PRO ✓'
                              : 'Free vs Pro · Tip Jar',
                          active: true,
                          onTap: () {
                            widget.audio.click();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProScreen(
                                  audio: widget.audio,
                                  settings: _s,
                                ),
                              ),
                            );
                          },
                        ),
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

  void _applyAudio() {
    widget.audio.configure(
      musicOn: _s.musicOn,
      sfxOn: _s.sfxOn,
      volume: _s.volume,
    );
    if (_s.musicOn) {
      widget.audio.startMenuMusic();
    }
    widget.audio.click();
  }

  String _bestLabel(int i) {
    final t = _s.bestTime[i];
    if (t == 0) return '—';
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(t,
            style: ChalkType.display(24, theme: _theme)),
      );

  Widget _divider() => Divider(
      color: _theme.chalk.withValues(alpha: 0.25), height: 18);

  Widget _pegRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: ChalkType.hand(22, theme: _theme))),
        PegToggle(theme: _theme, value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _volumeRow() {
    return Row(
      children: [
        Icon(Icons.volume_up,
            color: _theme.chalkDim, size: 22),
        Expanded(
          child: Slider(
            value: _s.volume,
            activeColor: _theme.accent,
            inactiveColor: _theme.chalkDim.withValues(alpha: 0.4),
            onChanged: (v) {
              _s.setVolume(v);
              widget.audio.configure(
                  musicOn: _s.musicOn,
                  sfxOn: _s.sfxOn,
                  volume: v);
            },
          ),
        ),
      ],
    );
  }

  Widget _nameRow() {
    final ctrl = TextEditingController(text: _s.profileName);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            maxLength: 16,
            style: ChalkType.hand(24, theme: _theme),
            decoration: InputDecoration(
              labelText: 'Scholar\u2019s name',
              labelStyle:
                  ChalkType.small(16, theme: _theme),
              counterText: '',
              enabledBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: _theme.chalkDim)),
              focusedBorder: UnderlineInputBorder(
                  borderSide:
                      BorderSide(color: _theme.accent)),
            ),
            onSubmitted: (v) {
              _s.setProfileName(v);
              widget.audio.chalkWrite();
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        IconButton(
          onPressed: () {
            _s.setProfileName(ctrl.text);
            widget.audio.chalkWrite();
            FocusScope.of(context).unfocus();
          },
          icon: Icon(Icons.check, color: _theme.accent),
        ),
      ],
    );
  }

  Widget _diffCircle(int i) {
    final labels = ['Easy 6×8', 'Med 8×10', 'Hard 10×12'];
    final active = _s.difficulty == i;
    final locked = i == 2 && !_s.isPro;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProScreen(
                  audio: widget.audio, settings: _s),
            ),
          );
          return;
        }
        _s.setDifficulty(i);
      },
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: active
                      ? _theme.accent
                      : _theme.chalkDim,
                  width: active ? 2.6 : 1.6),
              color: active
                  ? _theme.accent.withValues(alpha: 0.18)
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: locked
                ? Icon(Icons.lock,
                    color: _theme.chalkDim, size: 26)
                : Text(labels[i].split(' ').first,
                    style: ChalkType.hand(21,
                        theme: _theme,
                        color: active
                            ? _theme.accent
                            : _theme.chalk)),
          ),
          const SizedBox(height: 4),
          Text(labels[i].split(' ').last,
              style: ChalkType.small(14, theme: _theme)),
        ],
      ),
    );
  }

  Widget _themeTile(int i) {
    final theme = _theme;
    final isCustom = i == ChalkThemes.all.length;
    final def =
        isCustom ? _s.customTheme : ChalkThemes.all[i];
    final active = isCustom
        ? _s.themeId == 'custom'
        : _s.themeId == def.id;
    final locked = !isCustom && def.isPro && !_s.isPro;
    return GestureDetector(
      onTap: () {
        widget.audio.click();
        if (locked) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ProScreen(audio: widget.audio, settings: _s),
            ),
          );
          return;
        }
        _s.setTheme(def.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? theme.accent : theme.chalkDim.withValues(alpha: 0.4),
              width: active ? 2.6 : 1.2),
          color: def.board,
        ),
        child: Stack(
          children: [
            // mini preview: frame rim + chalk strokes
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: def.frame, width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text('5',
                      style: ChalkType.display(26,
                          theme: def,
                          color: def.chalk)),
                ),
              ),
            ),
            if (locked)
              Positioned(
                right: 4,
                top: 4,
                child: Icon(Icons.lock,
                    size: 16, color: theme.accent),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 3,
              child: Text(def.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ChalkType.small(12, theme: theme)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style:
                      ChalkType.hand(21, theme: _theme))),
          Text(value,
              style: ChalkType.hand(21,
                  theme: _theme, color: _theme.accent)),
        ],
      ),
    );
  }

  void _confirmReset() {
    widget.audio.click();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _theme.boardDeep,
        title: Text('Wipe the slate clean?',
            style: ChalkType.display(26, theme: _theme)),
        content: Text(
            'All stats, streaks and saved puzzles will be erased.',
            style: ChalkType.hand(20, theme: _theme)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep it',
                style: ChalkType.hand(20, theme: _theme)),
          ),
          TextButton(
            onPressed: () {
              _s.resetProgress();
              widget.audio.erase();
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Wipe it',
                style: ChalkType.hand(20,
                    theme: _theme, color: _theme.error)),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final ChalkThemeDef theme;
  final Widget child;
  const _Panel({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.boardDeep.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.chalk.withValues(alpha: 0.35), width: 1.4),
      ),
      child: child,
    );
  }
}
