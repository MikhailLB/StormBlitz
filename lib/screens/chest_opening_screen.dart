import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/card_data.dart';
import '../data/relic_data.dart';
import '../models/chest.dart';
import '../models/game_card.dart';
import '../models/player_profile.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import '../widgets/card_view.dart';
import '../widgets/chest_widget.dart';
import '../widgets/particle_burst.dart';
import '../widgets/primary_button.dart';
import '../widgets/storm_background.dart';

enum _OpenPhase { idle, shaking, revealing, done }

/// The chest-opening ceremony: wobble -> shake -> particle burst -> the
/// currency counts up and cards drop in face-down, flipping over one by one
/// (tap a card to flip it early). Newly discovered gods get a NEW ribbon.
class ChestOpeningScreen extends StatefulWidget {
  const ChestOpeningScreen({super.key, required this.slot});

  final int slot;

  @override
  State<ChestOpeningScreen> createState() => _ChestOpeningScreenState();
}

class _CardDrop {
  _CardDrop({
    required this.card,
    required this.count,
    required this.isNew,
  });

  final GameCard card;
  final int count;
  final bool isNew;
  bool revealed = false;
}

class _ChestOpeningScreenState extends State<ChestOpeningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;
  final RewardService _rewards = RewardService();

  _OpenPhase _phase = _OpenPhase.idle;
  ChestTier? _tier;
  ChestContents? _contents;
  final List<_CardDrop> _drops = [];
  int _burstTrigger = 0;
  Timer? _flipTimer;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    final profile = context.read<PlayerProfile>();
    _tier = profile.chestSlots[widget.slot]?.tier;
  }

  @override
  void dispose() {
    _shake.dispose();
    _flipTimer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    if (_phase != _OpenPhase.idle || _tier == null) return;
    final profile = context.read<PlayerProfile>();

    setState(() => _phase = _OpenPhase.shaking);
    HapticFeedback.mediumImpact();
    await _shake.forward(from: 0);
    if (!mounted) return;

    // Roll contents; remember which gods are brand new BEFORE applying.
    _contents = _rewards.rollChestContents(
      _tier!,
      ownedRelicIds: profile.ownedRelics,
    );
    final roster = CardData.roster();
    for (final entry in _contents!.cardCopies.entries) {
      final card = roster.firstWhere((c) => c.id == entry.key);
      _drops.add(_CardDrop(
        card: card,
        count: entry.value,
        isNew: profile.copiesOf(entry.key) == 0 &&
            profile.cardLevel(entry.key) == 1,
      ));
    }
    // New discoveries flip last for maximum drama.
    _drops.sort((a, b) {
      if (a.isNew != b.isNew) return a.isNew ? 1 : -1;
      return a.card.rarity.index.compareTo(b.card.rarity.index);
    });
    profile.applyChestContents(widget.slot, _contents!);

    HapticFeedback.heavyImpact();
    setState(() {
      _phase = _OpenPhase.revealing;
      _burstTrigger++;
    });

    // Auto-flip the cards one by one.
    _flipTimer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (!mounted) return;
      final next = _drops.where((d) => !d.revealed).toList();
      if (next.isEmpty) {
        t.cancel();
        setState(() => _phase = _OpenPhase.done);
        return;
      }
      _reveal(next.first);
    });
  }

  void _reveal(_CardDrop drop) {
    if (drop.revealed) return;
    if (drop.isNew) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    setState(() {
      drop.revealed = true;
      if (_drops.every((d) => d.revealed)) _phase = _OpenPhase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tier;
    if (tier == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final opened = _phase != _OpenPhase.idle && _phase != _OpenPhase.shaking;

    return Scaffold(
      body: StormBackground(
        darken: 0.78,
        showFlash: false,
        child: SafeArea(
          child: Stack(
            children: [
              if (opened)
                Positioned.fill(
                  child: ParticleBurst(
                    trigger: _burstTrigger,
                    colors: [
                      tier.color,
                      AppColors.goldLight,
                      AppColors.lightning,
                      if (tier == ChestTier.epic ||
                          tier == ChestTier.olympian)
                        AppColors.epic,
                    ],
                    particleCount: tier == ChestTier.olympian ? 48 : 30,
                    spread: 190,
                  ),
                ),
              Column(
                children: [
                  const SizedBox(height: 10),
                  Text(tier.label.toUpperCase(),
                      style: AppTheme.title(22, color: tier.color)),
                  const SizedBox(height: 12),
                  // The chest shrinks to the corner once opened.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    height: opened ? 64 : 170,
                    child: GestureDetector(
                      onTap: _open,
                      child: AnimatedBuilder(
                        animation: _shake,
                        builder: (context, child) {
                          final t = _shake.value;
                          final angle = _phase == _OpenPhase.shaking
                              ? sin(t * pi * 10) * 0.12 * (1 - t * 0.5)
                              : 0.0;
                          return Transform.rotate(angle: angle, child: child);
                        },
                        child: ChestWidget(
                          tier: tier,
                          size: opened ? 64 : 150,
                          glowing: !opened,
                          open: opened,
                        ),
                      ),
                    ),
                  ),
                  if (_phase == _OpenPhase.idle) ...[
                    const SizedBox(height: 8),
                    Text('TAP TO OPEN',
                        style:
                            AppTheme.title(16, color: AppColors.goldLight)),
                  ],
                  if (opened) _currencyRow(),
                  const SizedBox(height: 4),
                  Expanded(child: opened ? _cardGrid() : const SizedBox()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: AnimatedOpacity(
                      opacity: _phase == _OpenPhase.done ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: PrimaryButton(
                        label: 'COLLECT',
                        icon: Icons.check,
                        onTap: _phase == _OpenPhase.done
                            ? () => Navigator.of(context).pop()
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _currencyRow() {
    final c = _contents!;
    final relic = RelicData.byId(c.relicId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _lootPill(Icons.monetization_on, AppColors.gold, '+${c.gold}'),
          if (c.ambrosia > 0)
            _lootPill(
                Icons.local_drink, AppColors.ambrosia, '+${c.ambrosia}'),
          if (relic != null)
            _lootPill(relic.icon, relic.color, 'RELIC: ${relic.name}'),
        ],
      ),
    );
  }

  Widget _lootPill(IconData icon, Color color, String text) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Transform.scale(
          scale: (0.6 + 0.4 * t).clamp(0.0, 1.2),
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(text, style: AppTheme.title(15, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _cardGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: [
          for (final drop in _drops)
            GestureDetector(
              onTap: () => _reveal(drop),
              child: _FlipCard(drop: drop),
            ),
        ],
      ),
    );
  }
}

/// Face-down card that flips over in 3D when [drop.revealed] becomes true.
class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.drop});

  final _CardDrop drop;

  static const double _width = 92;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: drop.revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        final angle = t * pi;
        final showFront = t >= 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _front(),
                )
              : _back(),
        );
      },
    );
  }

  Widget _front() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            CardView(card: drop.card, width: _width, showDescription: false),
            const SizedBox(height: 4),
            Text(
              'x${drop.count}',
              style: AppTheme.title(15, color: AppColors.textPrimary),
            ),
          ],
        ),
        if (drop.isNew)
          Positioned(
            top: -8,
            right: -8,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.epic, AppColors.lightning],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.epic.withValues(alpha: 0.7),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text('NEW!',
                    style: AppTheme.title(11, color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _back() {
    const height = _width * 1.4;
    return SizedBox(
      // Match the front's total height (card + count label).
      height: height + 25,
      child: Column(
        children: [
          Container(
            width: _width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_width * 0.10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.backgroundLight, AppColors.panel],
              ),
              border: Border.all(color: AppColors.panelBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: _width * 0.45,
                height: _width * 0.45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      width: 1.5),
                ),
                child: const Icon(Icons.bolt,
                    color: AppColors.gold, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
