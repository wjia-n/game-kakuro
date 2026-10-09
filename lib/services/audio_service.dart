import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Kakuro — all sounds synthesized in code as WAV bytes.
/// No asset files. Quiet, analog study sounds: chalk on slate, wood, paper.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Music is app-scoped and
///   never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption resumes exactly
///   where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class StudyAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  StudyAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Chalk dragged on slate: short band-passed noise scratch.
  List<double> _chalkScratch(double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final noise = _rand.nextDouble() * 2 - 1;
      // crude band-pass: high-passed noise with resonant wobble
      lp += 0.35 * (noise - lp);
      final hp = noise - lp;
      final wobble = 0.6 + 0.4 * sin(2 * pi * 2400 * t);
      out[i] = _env(i, n, attack: 0.08) * hp * wobble * 0.8;
    }
    return out;
  }

  /// Felt eraser wipe: longer soft noise sweep.
  List<double> _eraserWipe() {
    final secs = 0.32;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    var lp = 0.0;
    for (int i = 0; i < n; i++) {
      final noise = _rand.nextDouble() * 2 - 1;
      lp += 0.12 * (noise - lp); // heavier low-pass = soft felt
      out[i] = _env(i, n, attack: 0.15) * lp * 1.4;
    }
    return out;
  }

  /// Soft wooden thud for errors — low, never harsh.
  List<double> _softThud() {
    final n = (_rate * 0.22).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.8 * sin(2 * pi * 110 * t) * exp(-t * 22) +
              0.4 * sin(2 * pi * 220 * t) * exp(-t * 40));
    }
    return out;
  }

  /// Chalk tap on slate: bright short click.
  List<double> _chalkTap() {
    final n = (_rate * 0.07).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.7 * sin(2 * pi * 1900 * t) * exp(-t * 90) +
              0.3 * (_rand.nextDouble() * 2 - 1) * exp(-t * 160));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {double harmonics = 0.22}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: harmonics));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Quiet study ambience: slow warm pads, 18s loop.
        final seq = [
          [146.83, 220.0, 293.66], // Dm
          [130.81, 196.0, 261.63], // Cm
          [174.61, 261.63, 349.23], // F
          [146.83, 220.0, 293.66], // Dm
        ];
        final out = <double>[];
        for (final chord in seq) {
          out.addAll(_padChord(chord, 4.5));
        }
        return out;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Soft music-box plucks over a low drone, 14s loop.
        final drone = _padChord([110.0, 164.81], 14.0);
        final plucks = [523.25, 587.33, 659.25, 587.33, 523.25, 440.0, 392.0, 440.0];
        final n = (_rate * 14).round();
        final out = List<double>.from(drone);
        for (int k = 0; k < plucks.length; k++) {
          final start = (n * k / plucks.length).round();
          final tone = _tone(plucks[k], 0.6, harmonics: 0.15);
          for (int i = 0; i < tone.length && start + i < n; i++) {
            out[start + i] += tone[i] * 0.3;
          }
        }
        return out;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', _chalkTap));
  Future<void> chalkWrite() =>
      _play(_clip('chalk', () => _chalkScratch(0.16)));
  Future<void> erase() => _play(_clip('erase', _eraserWipe));
  Future<void> invalid() => _play(_clip('invalid', _softThud));
  Future<void> gameStart() => _play(_clip('start', () {
        final a = _chalkScratch(0.25);
        final b = _tone(330, 0.4, freqEnd: 494, harmonics: 0.2);
        final out = List<double>.filled(a.length + b.length, 0);
        for (var i = 0; i < a.length; i++) {
          out[i] += a[i] * 0.7;
        }
        for (var i = 0; i < b.length; i++) {
          out[a.length + i] += b[i] * 0.8;
        }
        return out;
      }));
  Future<void> hint() => _play(_clip(
      'hint', () => _arp([880.0, 1174.66], 0.14, 0.04, harmonics: 0.15)));
  Future<void> win() => _play(_clip('win',
      () => _arp([392.0, 523.25, 659.25, 783.99, 1046.5], 0.18, 0.03)));
  Future<void> lose() =>
      _play(_clip('lose', () => _arp([329.63, 293.66, 261.63, 220.0], 0.24, 0.05)));

  // ----------------------------------------------------------------- music
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen;
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
