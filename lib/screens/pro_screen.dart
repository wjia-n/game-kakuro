import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/chalkboard.dart';
import '../theme/chalkboard_themes.dart';

/// Free-vs-Pro comparison + tip jar. Products must be created by Wajiha in
/// Play Console; until then the screen honestly says "available after
/// store setup" — never a fake buy button.
class ProScreen extends StatefulWidget {
  final StudyAudio audio;
  final StudySettings settings;
  const ProScreen({super.key, required this.audio, required this.settings});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  final StoreService _store = StoreService();
  bool _loading = true;

  static const _freeVsPro = [
    ('Puzzles', 'Easy & Medium boards', 'All boards incl. Hard 10×12'),
    ('Chalkboards', '5 classic colorways', '15 colorways + custom creator'),
    ('Mistake rules', 'Relaxed play', 'Sudden-death challenges'),
    ('Timed mode', 'Standard only', 'Timed challenges'),
    ('Support', '—', 'Keeps the chalk coming'),
  ];

  @override
  void initState() {
    super.initState();
    _store.lastThanks.addListener(_onThanks);
    _init();
  }

  Future<void> _init() async {
    await _store.init();
    if (mounted) setState(() => _loading = false);
  }

  
  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg,
                style: ChalkType.hand(20,
                    theme: widget.settings.theme))),
      );
      _store.lastThanks.value = null;
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
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
                        child: Text('Free vs Pro',
                            textAlign: TextAlign.center,
                            style: ChalkType.display(
                                32, theme: theme)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        // Comparison chalkboard.
                        Container(
                          decoration: BoxDecoration(
                            color: theme.boardDeep
                                .withValues(alpha: 0.8),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.chalk
                                    .withValues(alpha: 0.4),
                                width: 1.4),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 10),
                                child: Row(
                                  children: [
                                    const Spacer(),
                                    Expanded(
                                      flex: 2,
                                      child: Text('Free',
                                          textAlign:
                                              TextAlign.center,
                                          style: ChalkType.hand(
                                              22,
                                              theme: theme,
                                              color: theme
                                                  .chalkDim)),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text('PRO',
                                          textAlign:
                                              TextAlign.center,
                                          style: ChalkType.hand(
                                              24,
                                              theme: theme,
                                              color: theme
                                                  .accent)),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                  color: theme.chalk.withValues(
                                      alpha: 0.25),
                                  height: 1),
                              for (final row in _freeVsPro)
                                _compareRow(row),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (widget.settings.isPro)
                          _ownedPanel(theme)
                        else if (_loading)
                          Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: theme.accent),
                            ),
                          )
                        else if (_store.storeReady &&
                            _store.proProduct != null)
                          _buyPanel(theme, _store.proProduct!)
                        else
                          _notReadyPanel(theme),
                        const SizedBox(height: 18),
                        Text('Tip jar',
                            textAlign: TextAlign.center,
                            style: ChalkType.display(
                                26, theme: theme)),
                        const SizedBox(height: 4),
                        Text(
                          'Kakuro is free forever. Tips keep the lamp lit.',
                          textAlign: TextAlign.center,
                          style: ChalkType.small(17, theme: theme),
                        ),
                        const SizedBox(height: 10),
                        if (_loading)
                          const SizedBox.shrink()
                        else if (_store.storeReady)
                          Row(
                            children: [
                              Expanded(
                                  child: _tipButton(
                                      theme,
                                      _store.coffeeProduct,
                                      '☕ Coffee')),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: _tipButton(
                                      theme,
                                      _store.chocolateProduct,
                                      '🍫 Chocolate')),
                            ],
                          )
                        else
                          _notReadyPanel(theme, compact: true),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              widget.audio.click();
                              _store.restore();
                            },
                            child: Text('Restore purchases',
                                style: ChalkType.hand(19,
                                    theme: theme,
                                    color: theme.chalkDim)),
                          ),
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable:
                              _store.purchaseError,
                          builder: (_, err, _) => err == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding:
                                      const EdgeInsets.only(
                                          top: 6),
                                  child: Text(err,
                                      textAlign:
                                          TextAlign.center,
                                      style: ChalkType.hand(
                                          19,
                                          theme: theme,
                                          color: theme.error)),
                                ),
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

  Widget _compareRow((String, String, String) row) {
    final theme = widget.settings.theme;
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(row.$1,
                style: ChalkType.hand(20, theme: theme)),
          ),
          Expanded(
            flex: 2,
            child: Text(row.$2,
                textAlign: TextAlign.center,
                style: ChalkType.small(16, theme: theme)),
          ),
          Expanded(
            flex: 2,
            child: Text(row.$3,
                textAlign: TextAlign.center,
                style: ChalkType.small(16,
                    theme: theme, color: theme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _ownedPanel(ChalkThemeDef theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: theme.accent, width: 2),
        color: theme.accent.withValues(alpha: 0.12),
      ),
      child: Column(
        children: [
          Text('You hold the golden chalk.',
              style: ChalkType.hand(24,
                  theme: theme, color: theme.accent)),
          Text('Every board, every colorway — yours.',
              style: ChalkType.small(16, theme: theme)),
        ],
      ),
    );
  }

  Widget _buyPanel(ChalkThemeDef theme, ProductDetails p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChalkButton(
          theme: theme,
          label: 'Unlock PRO · ${p.price}',
          active: true,
          fontSize: 24,
          onTap: () {
            widget.audio.click();
            _store.buyPro();
          },
        ),
        const SizedBox(height: 6),
        Text('One-time purchase. Yours forever, on every device.',
            textAlign: TextAlign.center,
            style: ChalkType.small(15, theme: theme)),
      ],
    );
  }

  Widget _notReadyPanel(ChalkThemeDef theme, {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.chalkDim.withValues(alpha: 0.5),
            width: 1.4),
      ),
      child: Text(
        compact
            ? 'Tips available after store setup.'
            : 'Pro purchases will appear here once the store products are set up. Everything still plays free.',
        textAlign: TextAlign.center,
        style: ChalkType.hand(19,
            theme: theme, color: theme.chalkDim),
      ),
    );
  }

  Widget _tipButton(ChalkThemeDef theme, ProductDetails? p, String label) {
    if (p == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.chalkDim.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: ChalkType.hand(20,
                theme: theme, color: theme.chalkDim)),
      );
    }
    return ChalkButton(
      theme: theme,
      label: '$label\n${p.price}',
      fontSize: 20,
      onTap: () {
        widget.audio.click();
        _store.buyTip(p);
      },
    );
  }
}