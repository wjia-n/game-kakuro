import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/chalkboard.dart';
import '../theme/chalkboard_themes.dart';
import 'menu_screen.dart';

/// Single launch splash: WAJIHA company mark + "Credits: WAJIHA", then the
/// game logo + name + animated loading line. Prewarms audio and starts menu
/// music while showing.
class SplashScreen extends StatefulWidget {
  final StudyAudio audio;
  final StudySettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyPhase = true;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _run();
  }

  Future<void> _run() async {
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Company moment.
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => _companyPhase = false);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    return Scaffold(
      backgroundColor: theme.desk,
      body: LampWash(
        theme: theme,
        child: SlateTexture(
          theme: theme,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: _companyPhase
                ? _CompanySplash(theme: theme)
                : _GameSplash(theme: theme, loader: _loader),
          ),
        ),
      ),
    );
  }
}

/// Company splash moment: the official WAJIHA mark, untouched.
class _CompanySplash extends StatelessWidget {
  final ChalkThemeDef theme;
  const _CompanySplash({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/wajiha_logo.png', width: 120, height: 120),
          const SizedBox(height: 18),
          Text('W A J I H A',
              style: ChalkType.display(34, theme: theme)),
        ],
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final ChalkThemeDef theme;
  final AnimationController loader;
  const _GameSplash({required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: theme.frame, width: 6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 10),
                  blurRadius: 22,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/kakuro_logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(height: 20),
          Text('KAKURO', style: ChalkType.display(54, theme: theme)),
          const SizedBox(height: 4),
          Text('cross-sums, chalked by hand',
              style: ChalkType.hand(22, theme: theme, color: theme.chalkDim)),
          const SizedBox(height: 28),
          SizedBox(
            width: 220,
            child: AnimatedBuilder(
              animation: loader,
              builder: (_, _) => Column(
                children: [
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(
                          color: theme.chalk.withValues(alpha: 0.4)),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: loader.value.clamp(0.02, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: theme.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loader.value < 1
                        ? 'Sharpening the chalk…'
                        : 'Ready!',
                    style: ChalkType.small(17, theme: theme),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/wajiha_logo.png',
                  width: 28, height: 28, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Text('Credits: WAJIHA',
                  style: ChalkType.hand(20, theme: theme)),
            ],
          ),
        ],
      ),
    );
  }
}
