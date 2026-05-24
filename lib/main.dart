import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'game/game_controller.dart';
import 'game/models.dart';

const bool devMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);

enum InventorySortMode { powerDesc, tierDesc, sellValueDesc, nameAsc }

enum SmartEquipMode { purePower, setSynergy }

enum AchievementFilterMode { all, claimable, unclaimed, claimed }

enum ShopPanelTab { all, daily, upgrades, resources, combat }

double _adaptiveSheetHeight(
  BuildContext context, {
  required double factor,
  double min = 320,
  double max = 820,
}) {
  final h = MediaQuery.sizeOf(context).height * factor;
  return h.clamp(min, max).toDouble();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  runApp(const IdleForgeApp());
}

class IdleForgeApp extends StatefulWidget {
  const IdleForgeApp({super.key});

  @override
  State<IdleForgeApp> createState() => _IdleForgeAppState();
}

class _IdleForgeAppState extends State<IdleForgeApp> {
  final GameController controller = GameController(localeCode: 'de');

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await controller.initialize();
    if (!mounted) {
      return;
    }

    final reward = controller.lastOfflineReward;
    if (reward != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(controller.text.tr('offlineReward')),
              content: Text(
                '${controller.text.tr('offlineSummary')}\n\n'
                '+${reward.gold} ${controller.text.tr('gold')}\n'
                '+${reward.hammers} ${controller.text.tr('hammers')}\n'
                '${reward.minutes} Minuten',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(controller.text.tr('close')),
                ),
              ],
            );
          },
        );
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: controller.text.tr('appTitle'),
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'monospace',
        scaffoldBackgroundColor: const Color(0xFF171717),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4D4D4),
          secondary: Color(0xFFB8B8B8),
          surface: Color(0xFF232323),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2B2B2B),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!controller.isLoaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return IdleForgeHome(controller: controller);
        },
      ),
    );
  }
}

class IdleForgeHome extends StatelessWidget {
  const IdleForgeHome({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF191919),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(controller: controller),
              Expanded(child: _CombatArea(controller: controller)),
              _ForgePanel(controller: controller),
              _BottomMenu(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;

    Widget actionIcon({required IconData icon, required VoidCallback onTap}) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF434343)),
          ),
          child: Icon(icon, color: const Color(0xFFD8D8D8), size: 20),
        ),
      );
    }

    final profileCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3C3C3C)),
      ),
      child: Row(
        children: [
          _SvgIcon(path: 'assets/icons/profile.svg', size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.playerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${text.tr('totalStrength')}: ${controller.totalStrength}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB5B5B5),
                  ),
                ),
                Text(
                  'Prestige ${controller.prestigeLevel} | Scherben ${controller.forgeShards}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFA9A9A9),
                  ),
                ),
                Text(
                  'HP ${controller.playerHp.round()}/${controller.maxPlayerHp.round()} | Tode ${controller.deaths}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFA9A9A9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final goldCard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3C3C3C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SvgIcon(path: 'assets/icons/gold.svg', size: 20),
          const SizedBox(width: 6),
          Text(
            '${controller.gold}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFFE0E0E0),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          if (!compact) {
            return Row(
              children: [
                Expanded(child: profileCard),
                const SizedBox(width: 8),
                goldCard,
                const SizedBox(width: 8),
                actionIcon(icon: Icons.auto_awesome, onTap: () => _showSkillTree(context, controller)),
                if (devMode) ...[
                  const SizedBox(width: 8),
                  actionIcon(icon: Icons.tune, onTap: () => _showDeveloperPanel(context)),
                ],
              ],
            );
          }

          return Column(
            children: [
              profileCard,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: goldCard),
                  const SizedBox(width: 8),
                  actionIcon(icon: Icons.auto_awesome, onTap: () => _showSkillTree(context, controller)),
                  if (devMode) ...[
                    const SizedBox(width: 8),
                    actionIcon(icon: Icons.tune, onTap: () => _showDeveloperPanel(context)),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeveloperPanel(BuildContext context) async {
    if (!devMode) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(context, factor: 0.8, min: 360, max: 900),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final tuning = controller.tuning;

                void update(BalanceTuning next, {bool refreshEnemy = false}) {
                  controller.setTuning(next, refreshEnemy: refreshEnemy);
                  setModalState(() {});
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Developer Panel',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Live Balancing fuer Kampf und Oekonomie',
                      style: TextStyle(color: Color(0xFFBABABA), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              controller.debugAddResources(goldDelta: 200, hammerDelta: 20);
                              setModalState(() {});
                            },
                            child: const Text('+200 Gold / +20 Haemmer'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              controller.debugAdvanceStage(1);
                              setModalState(() {});
                            },
                            child: const Text('Naechste Stage'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              controller.debugAdvanceStage(-1);
                              setModalState(() {});
                            },
                            child: const Text('Vorige Stage'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              update(const BalanceTuning(), refreshEnemy: true);
                            },
                            child: const Text('Reset Tuning'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Presets', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              update(
                                const BalanceTuning(
                                  autoAttackIntervalSec: 0.8,
                                  playerDamageMultiplier: 1.2,
                                  enemyHpMultiplier: 0.8,
                                  enemyApproachSpeedMultiplier: 0.9,
                                  goldGainMultiplier: 1.2,
                                  offlineRewardMultiplier: 1.1,
                                  forgeExtraBonus: 0.05,
                                  killsPerStage: 7,
                                ),
                                refreshEnemy: true,
                              );
                            },
                            child: const Text('Easy'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              update(const BalanceTuning(), refreshEnemy: true);
                            },
                            child: const Text('Normal'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              update(
                                const BalanceTuning(
                                  autoAttackIntervalSec: 1.1,
                                  playerDamageMultiplier: 0.85,
                                  enemyHpMultiplier: 1.4,
                                  enemyApproachSpeedMultiplier: 1.15,
                                  goldGainMultiplier: 0.95,
                                  offlineRewardMultiplier: 0.95,
                                  forgeExtraBonus: 0,
                                  killsPerStage: 11,
                                ),
                                refreshEnemy: true,
                              );
                            },
                            child: const Text('Hard'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _TuningSlider(
                      label: 'Auto Attack Intervall',
                      value: tuning.autoAttackIntervalSec,
                      min: 0.2,
                      max: 2.5,
                      onChanged: (value) {
                        update(tuning.copyWith(autoAttackIntervalSec: value));
                      },
                    ),
                    _TuningSlider(
                      label: 'Schaden Multiplikator',
                      value: tuning.playerDamageMultiplier,
                      min: 0.3,
                      max: 4,
                      onChanged: (value) {
                        update(tuning.copyWith(playerDamageMultiplier: value));
                      },
                    ),
                    _TuningSlider(
                      label: 'Gegner HP Multiplikator',
                      value: tuning.enemyHpMultiplier,
                      min: 0.3,
                      max: 4.5,
                      onChanged: (value) {
                        update(tuning.copyWith(enemyHpMultiplier: value), refreshEnemy: true);
                      },
                    ),
                    _TuningSlider(
                      label: 'Gegner Geschwindigkeit',
                      value: tuning.enemyApproachSpeedMultiplier,
                      min: 0.3,
                      max: 3,
                      onChanged: (value) {
                        update(tuning.copyWith(enemyApproachSpeedMultiplier: value));
                      },
                    ),
                    _TuningSlider(
                      label: 'Gold Multiplikator',
                      value: tuning.goldGainMultiplier,
                      min: 0.2,
                      max: 5,
                      onChanged: (value) {
                        update(tuning.copyWith(goldGainMultiplier: value));
                      },
                    ),
                    _TuningSlider(
                      label: 'Offline Multiplikator',
                      value: tuning.offlineRewardMultiplier,
                      min: 0.2,
                      max: 5,
                      onChanged: (value) {
                        update(tuning.copyWith(offlineRewardMultiplier: value));
                      },
                    ),
                    _TuningSlider(
                      label: 'Forge Extra Bonus',
                      value: tuning.forgeExtraBonus,
                      min: 0,
                      max: 0.25,
                      onChanged: (value) {
                        update(tuning.copyWith(forgeExtraBonus: value));
                      },
                    ),
                    _TuningSlider(
                      label: 'Kills je Stage',
                      value: tuning.killsPerStage.toDouble(),
                      min: 1,
                      max: 12,
                      divisions: 11,
                      onChanged: (value) {
                        update(tuning.copyWith(killsPerStage: value.round()));
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TuningSlider extends StatelessWidget {
  const _TuningSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.toStringAsFixed(2)}'),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CombatArea extends StatelessWidget {
  const _CombatArea({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final hpPercent = (controller.enemy.hp / controller.enemy.maxHp).clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B3B3B)),
          color: const Color(0xFF222222),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Text(
                    '${text.tr('chapter')} ${controller.chapter}-${controller.stage}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFE1E1E1),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${controller.killsInStage}/${controller.stageTargetKills}',
                    style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (controller.lastCombatEvent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    controller.lastCombatEvent,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFC9A8A8)),
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final enemyX = (width * controller.enemy.approach).clamp(width * 0.54, width - 94);
                  final playerYBob = controller.animationBob;

                  return Stack(
                    children: [
                      Positioned(
                        left: width * 0.5 - 36,
                        bottom: 28 + playerYBob,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 78,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: controller.playerHpPercent,
                                  minHeight: 5,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8FBCE3)),
                                  backgroundColor: const Color(0xFF4B4B4B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const _Runner(),
                          ],
                        ),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        left: enemyX,
                        bottom: 24,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 88,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: hpPercent,
                                  minHeight: 6,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    controller.enemy.isBoss
                                        ? const Color(0xFFE06767)
                                        : const Color(0xFFD5D5D5),
                                  ),
                                  backgroundColor: const Color(0xFF4B4B4B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              controller.enemy.name,
                              style: const TextStyle(fontSize: 10, color: Color(0xFFD3D3D3)),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2F2F2F),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFF5A5A5A)),
                              ),
                              child: Text(
                                controller.enemy.isBoss
                                    ? 'Boss ${controller.bossPatternLabel(controller.currentBossPattern)} P${controller.currentBossPhase}'
                                    : controller.archetypeLabel(controller.enemy.archetype),
                                style: const TextStyle(fontSize: 9, color: Color(0xFFD7D7D7)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            _Enemy(isBoss: controller.enemy.isBoss),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;

                  Widget skillCard(int index, {double? width}) {
                    final state = controller.skills[index];
                    final available = state.cooldownRemaining <= 0;
                    final autoEnabled = controller.isAutoSkillEnabled(index);
                    final iconPath = switch (index) {
                      0 => 'assets/icons/skill_strike.svg',
                      1 => 'assets/icons/skill_whirl.svg',
                      _ => 'assets/icons/skill_focus.svg',
                    };

                    return SizedBox(
                      width: width,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => controller.activateSkill(index),
                          onLongPress: () {
                            final enabled = controller.toggleAutoSkill(index);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  enabled
                                      ? 'Auto-Skill aktiv fuer ${controller.text.tr(state.definition.labelKey)}'
                                      : 'Auto-Skill deaktiviert fuer ${controller.text.tr(state.definition.labelKey)}',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: available ? const Color(0xFF2D2D2D) : const Color(0xFF252525),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: autoEnabled
                                    ? const Color(0xFF8BAF85)
                                    : available
                                    ? const Color(0xFF5A5A5A)
                                    : const Color(0xFF464646),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: _SvgIcon(path: iconPath, size: 18),
                                ),
                                Positioned(
                                  left: 30,
                                  top: 8,
                                  right: 4,
                                  child: Text(
                                    controller.text.tr(state.definition.labelKey),
                                    style: const TextStyle(fontSize: 10, color: Colors.white),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (autoEnabled)
                                  Positioned(
                                    right: 6,
                                    bottom: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3E5A3B),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'AUTO',
                                        style: TextStyle(fontSize: 8, color: Color(0xFFDDE9DA)),
                                      ),
                                    ),
                                  ),
                                if (!available)
                                  Positioned.fill(
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: const Color(0xB0202020),
                                      ),
                                      child: Text(
                                        '${state.cooldownRemaining.toStringAsFixed(1)}s',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE7E7E7),
                                        ),
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

                  final skillStrip = !compact
                      ? Row(
                          children: List.generate(
                            controller.skills.length,
                            (index) => Expanded(child: skillCard(index)),
                          ),
                        )
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: List.generate(
                            controller.skills.length,
                            (index) => skillCard(index, width: (constraints.maxWidth - 12) / 2),
                          ),
                        );

                  Widget flaskControls() {
                    final cooldownText = controller.flaskCooldownRemaining > 0
                        ? 'Trank-CD ${controller.flaskCooldownRemaining.toStringAsFixed(1)}s'
                        : 'Trank bereit';

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF424242)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: CombatStance.values
                                .map(
                                  (stance) => ChoiceChip(
                                    label: Text(controller.combatStanceLabel(stance)),
                                    selected: controller.combatStance == stance,
                                    onSelected: (_) => controller.setCombatStance(stance),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cooldownText,
                            style: const TextStyle(fontSize: 11, color: Color(0xFFCACACA)),
                          ),
                          const SizedBox(height: 6),
                          if (compact)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonal(
                                    onPressed: controller.useHealingFlask,
                                    child: Text('Heiltrank nutzen (${controller.healingFlasks})'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      final ok = controller.buyFlask(FlaskType.healing);
                                      if (!ok) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Nicht genug Gold.')),
                                        );
                                      }
                                    },
                                    child: Text('Heiltrank kaufen (${controller.healingFlaskCost}G)'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.tonal(
                                    onPressed: controller.useBerserkFlask,
                                    child: Text('Berserk nutzen (${controller.berserkFlasks})'),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      final ok = controller.buyFlask(FlaskType.berserk);
                                      if (!ok) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Nicht genug Gold.')),
                                        );
                                      }
                                    },
                                    child: Text('Berserk kaufen (${controller.berserkFlaskCost}G)'),
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: controller.useHealingFlask,
                                        child: Text('Heiltrank (${controller.healingFlasks})'),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          final ok = controller.buyFlask(FlaskType.healing);
                                          if (!ok) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Nicht genug Gold.')),
                                            );
                                          }
                                        },
                                        child: Text('Kaufen ${controller.healingFlaskCost}G'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: controller.useBerserkFlask,
                                        child: Text('Berserk (${controller.berserkFlasks})'),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          final ok = controller.buyFlask(FlaskType.berserk);
                                          if (!ok) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Nicht genug Gold.')),
                                            );
                                          }
                                        },
                                        child: Text('Kaufen ${controller.berserkFlaskCost}G'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      skillStrip,
                      flaskControls(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgePanel extends StatelessWidget {
  const _ForgePanel({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3D3D3D)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;

            final craftCard = InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final item = controller.craftItem();
                if (item == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(text.tr('notEnoughHammers'))),
                  );
                  return;
                }

                if (controller.consumeLastCraftAutoSoldFlag()) {
                  final message = controller.consumeLastCraftAutoSoldText();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message.isEmpty ? 'Auto-Sell aktiv' : message)),
                  );
                  return;
                }

                await _showCraftResultDialog(context, controller, item);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF494949)),
                ),
                child: Row(
                  children: [
                    _SvgIcon(path: 'assets/icons/forge.svg', size: 30),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.tr('forge'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${text.tr('hammers')}: ${controller.hammers}',
                          style: const TextStyle(
                            color: Color(0xFFC8C8C8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            final upgradeCard = InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                final success = controller.upgradeForgeChance();
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(text.tr('notEnoughGold'))),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF494949)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.tr('upgradeChance'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${text.tr('forgeLevel')}: ${controller.forgeLevel}',
                      style: const TextStyle(color: Color(0xFFC7C7C7), fontSize: 11),
                    ),
                    Text(
                      'Bonus ${(controller.forgeBonusChance * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: Color(0xFFC7C7C7), fontSize: 11),
                    ),
                    Text(
                      'Kosten ${controller.forgeUpgradeCost}',
                      style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.tonal(
                      onPressed: () => _showPrestigeDialog(context, controller),
                      child: const Text('Prestige'),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      onPressed: controller.cycleAutoSellMode,
                      child: Text('Auto-Sell: ${controller.autoSellLabel}'),
                    ),
                  ],
                ),
              ),
            );

            if (compact) {
              return Column(
                children: [
                  craftCard,
                  const SizedBox(height: 8),
                  upgradeCard,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: craftCard),
                const SizedBox(width: 8),
                Expanded(child: upgradeCard),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCraftResultDialog(
    BuildContext context,
    GameController controller,
    GameItem item,
  ) async {
    final text = controller.text;
    final equipped = controller.equippedInSlot(item.slot);
    final hasEquipped = equipped != null && equipped.id.isNotEmpty;
    final equippedPower = hasEquipped ? equipped.power : 0;
    final powerDelta = item.power - equippedPower;
    final comparisonLabel = hasEquipped
        ? powerDelta > 0
            ? 'Besser (+$powerDelta)'
            : powerDelta < 0
                ? 'Schlechter (${powerDelta.toString()})'
                : 'Gleich stark (0)'
        : 'Neuer Slot (+${item.power})';
    final comparisonColor = hasEquipped
        ? powerDelta > 0
            ? const Color(0xFF8FD39E)
            : powerDelta < 0
                ? const Color(0xFFE39A9A)
                : const Color(0xFFC8C8C8)
        : const Color(0xFFD6D6D6);
    final comparisonIcon = hasEquipped
      ? powerDelta > 0
        ? Icons.arrow_upward_rounded
        : powerDelta < 0
          ? Icons.arrow_downward_rounded
          : Icons.remove_rounded
      : Icons.fiber_new_rounded;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(text.tr('crafted')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SvgIcon(path: item.iconPath, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text(controller.tierLabel(item.tier)),
              Text('Set: ${controller.setLabel(item.setId)}'),
              Text('${controller.slotLabel(item.slot)} | +${item.power}'),
              const SizedBox(height: 8),
              Text(
                hasEquipped
                    ? 'Aktuell angelegt: ${equipped.name} (+${equipped.power})'
                    : 'Aktuell angelegt: Kein Item',
                style: const TextStyle(fontSize: 12, color: Color(0xFFCBCBCB)),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(comparisonIcon, size: 16, color: comparisonColor),
                  const SizedBox(width: 4),
                  Text(
                    comparisonLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: comparisonColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Wert ${item.sellValue} Gold'),
              const SizedBox(height: 2),
              Text(
                item.isLocked ? 'Status: Gesperrt' : 'Status: Offen',
                style: const TextStyle(fontSize: 12, color: Color(0xFFC8C8C8)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.toggleItemLock(item.id);
                Navigator.of(context).pop();
              },
              child: Text(item.isLocked ? 'Entsperren' : 'Sperren'),
            ),
            TextButton(
              onPressed: () {
                controller.equipItem(item);
                Navigator.of(context).pop();
              },
              child: Text(text.tr('equip')),
            ),
            TextButton(
              onPressed: () {
                final sold = controller.sellItem(item);
                if (!sold) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item ist gesperrt und kann nicht verkauft werden.')),
                  );
                  return;
                }
                Navigator.of(context).pop();
              },
              child: Text(text.tr('sell')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPrestigeDialog(BuildContext context, GameController controller) async {
    final canPrestige = controller.canPrestige;
    final gain = controller.prestigeShardGain;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Prestige'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aktuell: Prestige ${controller.prestigeLevel}'),
              Text('Scherben: ${controller.forgeShards}'),
              const SizedBox(height: 8),
              Text('Gewinn bei Reset: +$gain Scherben'),
              Text('Dauerbonus Schaden: x${controller.prestigeDamageBonus.toStringAsFixed(2)}'),
              Text(
                'Dauerbonus Schmiede: +${(controller.prestigeForgeBonus * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 10),
              Text(
                canPrestige
                    ? 'Fortschritt wird zurueckgesetzt (Stage, Items, Gold), Boni bleiben.'
                    : 'Noch nicht verfuegbar. Erreiche mindestens Kapitel 2.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: canPrestige
                  ? () {
                      controller.performPrestige();
                      Navigator.of(context).pop();
                    }
                  : null,
              child: const Text('Prestige ausfuehren'),
            ),
          ],
        );
      },
    );
  }
}

Future<void> _showSkillTree(BuildContext context, GameController controller) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1F1F1F),
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: _adaptiveSheetHeight(context, factor: 0.58, min: 320, max: 760),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Widget skillCard({
                required String title,
                required String desc,
                required int level,
                required int cost,
                required VoidCallback onUpgrade,
              }) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF474747)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Level $level | Kosten $cost Scherben'),
                      const SizedBox(height: 6),
                      FilledButton.tonal(onPressed: onUpgrade, child: const Text('Skill verbessern')),
                    ],
                  ),
                );
              }

              void buy(int index) {
                final ok = controller.upgradeSkill(index);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nicht genug Scherben.')),
                  );
                }
                setModalState(() {});
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  const Text(
                    'Skillbaum',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Verfuegbare Scherben: ${controller.forgeShards}'),
                  const SizedBox(height: 10),
                  skillCard(
                    title: 'Kraftschlag',
                    desc: 'Mehr Skill-Schaden und kuerzerer Cooldown.',
                    level: controller.skillStrikeLevel,
                    cost: controller.skillStrikeCost,
                    onUpgrade: () => buy(0),
                  ),
                  skillCard(
                    title: 'Wirbelhieb',
                    desc: 'Mehr Treffer und besserer Cooldown.',
                    level: controller.skillWhirlLevel,
                    cost: controller.skillWhirlCost,
                    onUpgrade: () => buy(1),
                  ),
                  skillCard(
                    title: 'Kampffokus',
                    desc: 'Deutlich staerkerer Burst und kuerzerer Cooldown.',
                    level: controller.skillFocusLevel,
                    cost: controller.skillFocusCost,
                    onUpgrade: () => buy(2),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _BottomMenu extends StatelessWidget {
  const _BottomMenu({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3C3C3C)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final buttons = [
            _MenuButton(
              iconPath: 'assets/icons/menu_world.svg',
              label: text.tr('menuWorld'),
              onTap: () => _showWorldPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_clan.svg',
              label: text.tr('menuClan'),
              onTap: () => _showTalentTree(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_shop.svg',
              label: text.tr('menuShop'),
              onTap: () => _showShopPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_quest.svg',
              label: text.tr('menuQuest'),
              onTap: () => _showQuestBoard(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/inventory.svg',
              label: text.tr('inventory'),
              onTap: () => _showInventory(context, controller),
            ),
          ];

          if (!compact) {
            return Row(
              children: buttons.map((button) => Expanded(child: button)).toList(growable: false),
            );
          }

          final columns = 3;
          final itemWidth = (constraints.maxWidth - ((columns - 1) * 6)) / columns;
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: buttons
                .map((button) => SizedBox(width: itemWidth, child: button))
                .toList(growable: false),
          );
        },
      ),
    );
  }

  Future<void> _showQuestBoard(BuildContext context, GameController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(context, factor: 0.6, min: 340, max: 780),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final quests = controller.questBoard;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;

                    Widget questCard(QuestStateView quest, {double? width}) {
                      final progressRatio = (quest.progress / quest.target).clamp(0.0, 1.0);
                      final rewardText =
                          '+${quest.rewardGold} Gold | +${quest.rewardHammers} Haemmer'
                          '${quest.rewardShards > 0 ? ' | +${quest.rewardShards} Scherben' : ''}';
                      return Container(
                        width: width,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF474747)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quest.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(quest.description, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                minHeight: 6,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFCFCFCF)),
                                backgroundColor: const Color(0xFF4A4A4A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${quest.progress}/${quest.target}'),
                            const SizedBox(height: 4),
                            Text(rewardText, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            if (quest.claimed)
                              const Text('Belohnung geholt', style: TextStyle(color: Color(0xFF9BC89E)))
                            else
                              FilledButton.tonal(
                                onPressed: quest.canClaim
                                    ? () {
                                        controller.claimQuest(quest.type);
                                        setModalState(() {});
                                      }
                                    : null,
                                child: const Text('Belohnung holen'),
                              ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const Text(
                          'Quest Board',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('Schliesse Quests ab und hole dir Belohnungen.'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('Cycle ${controller.questCycle}'),
                            const Spacer(),
                            OutlinedButton(
                              onPressed: controller.allQuestsClaimed
                                  ? () {
                                      controller.refreshQuestCycle();
                                      setModalState(() {});
                                    }
                                  : null,
                              child: const Text('Neue Quest-Runde'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (!wide) ...quests.map((quest) => questCard(quest)) else ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 0,
                            children: quests
                                .map((quest) => questCard(quest, width: (constraints.maxWidth - 10) / 2))
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTalentTree(BuildContext context, GameController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(context, factor: 0.72, min: 420, max: 920),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                Future<void> tryUpgrade(TalentType type) async {
                  final ok = controller.upgradeTalent(type);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nicht genug Scherben.')),
                    );
                  }
                  setModalState(() {});
                }

                Future<void> tryUpgradeClanPerk(ClanPerkType type) async {
                  final ok = controller.upgradeClanPerk(type);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nicht genug Clan-Punkte.')),
                    );
                  }
                  setModalState(() {});
                }

                Widget talentCard({
                  required String title,
                  required String desc,
                  required int level,
                  required int cost,
                  required VoidCallback onUpgrade,
                }) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF474747)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(desc, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Level $level | Kosten $cost Scherben'),
                        const SizedBox(height: 6),
                        FilledButton.tonal(onPressed: onUpgrade, child: const Text('Upgrade')),
                      ],
                    ),
                  );
                }

                Widget clanPerkCard({
                  required ClanPerkType type,
                  double? width,
                }) {
                  final title = controller.clanPerkTitle(type);
                  final desc = controller.clanPerkDescription(type);
                  final level = controller.clanPerkLevel(type);
                  final cost = controller.clanPerkCost(type);
                  final affordable = controller.clanPoints >= cost;

                  return Container(
                    width: width,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF474747)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(desc, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Perk-Level $level | Kosten $cost Clan-Punkte'),
                        const SizedBox(height: 6),
                        FilledButton.tonal(
                          onPressed: affordable ? () => tryUpgradeClanPerk(type) : null,
                          child: const Text('Perk verbessern'),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;
                    final clanCards = ClanPerkType.values
                        .map((type) {
                          if (!wide) {
                            return clanPerkCard(type: type);
                          }
                          return clanPerkCard(type: type, width: (constraints.maxWidth - 10) / 2);
                        })
                        .toList(growable: false);

                    final talentCards = [
                      talentCard(
                        title: 'Kampfkunst',
                        desc: 'Mehr Dauerschaden pro Prestige-Lauf.',
                        level: controller.talentAttackLevel,
                        cost: controller.talentAttackCost,
                        onUpgrade: () => tryUpgrade(TalentType.attack),
                      ),
                      talentCard(
                        title: 'Standhaftigkeit',
                        desc: 'Erhoeht maximale Spieler-HP dauerhaft.',
                        level: controller.talentVitalityLevel,
                        cost: controller.talentVitalityCost,
                        onUpgrade: () => tryUpgrade(TalentType.vitality),
                      ),
                      talentCard(
                        title: 'Meisterschmiede',
                        desc: 'Verbessert dauerhaft die Schmiede-Chance.',
                        level: controller.talentForgeLevel,
                        cost: controller.talentForgeCost,
                        onUpgrade: () => tryUpgrade(TalentType.forge),
                      ),
                    ];

                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Text(
                          'Clan Stufe ${controller.clanLevel}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Clan-XP: ${controller.clanXp}/${controller.clanXpRequired}'),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: controller.clanXpProgress,
                            minHeight: 8,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF9BC89E)),
                            backgroundColor: const Color(0xFF454545),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Clan-Punkte: ${controller.clanPoints} | Scherben: ${controller.forgeShards}'),
                        const SizedBox(height: 12),
                        const Text(
                          'Clan Perks',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (!wide)
                          ...clanCards
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 0,
                            children: clanCards,
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Talentzweig (Scherben)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        if (!wide)
                          ...talentCards
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 0,
                            children: talentCards
                                .map((card) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: card))
                                .toList(growable: false),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInventory(BuildContext context, GameController controller) async {
    final text = controller.text;
    ItemSet? setFilter;
    ItemSlot? slotFilter;
    ItemTier? tierFilter;
    InventorySortMode sortMode = InventorySortMode.powerDesc;
    SmartEquipMode smartEquipMode = SmartEquipMode.purePower;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(context, factor: 0.72, min: 420, max: 940),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                void refresh() {
                  setModalState(() {});
                }

                final filteredInventory = controller.inventory
                    .where((item) {
                      final matchesSet = setFilter == null || item.setId == setFilter;
                      final matchesSlot = slotFilter == null || item.slot == slotFilter;
                      final matchesTier = tierFilter == null || item.tier == tierFilter;
                      return matchesSet && matchesSlot && matchesTier;
                    })
                    .toList();

                filteredInventory.sort((a, b) {
                  return switch (sortMode) {
                    InventorySortMode.powerDesc => b.power.compareTo(a.power),
                    InventorySortMode.tierDesc => b.tier.index.compareTo(a.tier.index),
                    InventorySortMode.sellValueDesc => b.sellValue.compareTo(a.sellValue),
                    InventorySortMode.nameAsc => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  };
                });

                final compact = MediaQuery.sizeOf(context).width < 760;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          _SvgIcon(path: 'assets/icons/inventory.svg', size: 24),
                          const SizedBox(width: 8),
                          Text(
                            text.tr('inventory'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(3, (idx) {
                          final slot = idx + 1;
                          final hasPreset = controller.hasLoadoutPreset(slot);
                          return SizedBox(
                            width: compact ? 140 : 180,
                            child: OutlinedButton(
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: Text('Loadout $slot'),
                                      content: Text(
                                        hasPreset
                                            ? 'Loadout laden oder aktuellen Stand ueberschreiben?'
                                            : 'Diesen Slot als aktuelles Loadout speichern?',
                                      ),
                                      actions: [
                                        if (hasPreset)
                                          TextButton(
                                            onPressed: () {
                                              final changes = controller.applyLoadout(slot);
                                              Navigator.of(dialogContext).pop();
                                              final msg = changes > 0
                                                  ? 'Loadout $slot geladen ($changes Aenderungen).'
                                                  : 'Loadout $slot ist bereits aktiv oder teilweise nicht verfuegbar.';
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text(msg)),
                                              );
                                              refresh();
                                            },
                                            child: const Text('Laden'),
                                          ),
                                        FilledButton.tonal(
                                          onPressed: () {
                                            final saved = controller.saveCurrentLoadout(slot);
                                            Navigator.of(dialogContext).pop();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Loadout $slot gespeichert ($saved Slots).',
                                                ),
                                              ),
                                            );
                                            refresh();
                                          },
                                          child: const Text('Speichern'),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              child: Text(hasPreset ? 'L$slot (S)' : 'L$slot'),
                            ),
                          );
                        }),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth < 500
                              ? 1
                              : constraints.maxWidth < 860
                              ? 2
                              : 3;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              childAspectRatio: cols == 1 ? 3.6 : 2.5,
                            ),
                            itemCount: ItemSlot.values.length,
                            itemBuilder: (context, index) {
                              final slot = ItemSlot.values[index];
                          final equipped = controller.equippedInSlot(slot);
                          final best = controller.bestItemForSlot(slot);
                          final upgradeDelta = controller.bestUpgradeDelta(slot);
                          return Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF464646)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(controller.slotLabel(slot), style: const TextStyle(fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  equipped?.name ?? '-',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE3E3E3),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  best == null
                                      ? 'Keine Items'
                                      : upgradeDelta > 0
                                      ? 'Upgrade +$upgradeDelta'
                                      : 'Best in Slot',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: best == null
                                        ? const Color(0xFF989898)
                                        : upgradeDelta > 0
                                        ? const Color(0xFFBFD8BF)
                                        : const Color(0xFFA9A9A9),
                                  ),
                                ),
                              ],
                            ),
                          );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(color: Color(0xFF2D3F5E), height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Filter', style: TextStyle(fontSize: 12)),
                              const Spacer(),
                              Text(
                                '${filteredInventory.length}/${controller.inventory.length}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFC6C6C6)),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setFilter = null;
                                  slotFilter = null;
                                  tierFilter = null;
                                  setModalState(() {});
                                },
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (compact)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      final changed = controller.smartEquipBestItems(
                                        preferSetSynergy: smartEquipMode == SmartEquipMode.setSynergy,
                                      );
                                      final msg = changed > 0
                                          ? 'Smart Equip: $changed Slots aktualisiert.'
                                          : 'Smart Equip: Keine bessere Ausruestung gefunden.';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                      refresh();
                                    },
                                    child: const Text('Smart Equip'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      if (filteredInventory.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Keine Items im aktuellen Filter.')),
                                        );
                                        return;
                                      }

                                      final preview = controller.getBulkSellPreview(
                                        filteredInventory.map((item) => item.id),
                                      );
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) {
                                          return AlertDialog(
                                            title: const Text('Massenverkauf bestaetigen'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Im Filter: ${preview.candidateCount} Items'),
                                                Text('Verkaufbar: ${preview.sellableCount}'),
                                                Text('Geschuetzt: ${preview.protectedCount}'),
                                                const SizedBox(height: 8),
                                                Text('Erwartetes Gold: +${preview.estimatedGold}'),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                                child: const Text('Abbrechen'),
                                              ),
                                              FilledButton.tonal(
                                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                                child: const Text('Verkaufen'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                      if (confirmed != true) {
                                        return;
                                      }
                                      if (!context.mounted) {
                                        return;
                                      }

                                      final result = controller.sellItemsByIds(
                                        filteredInventory.map((item) => item.id),
                                      );
                                      final msg = result.soldCount > 0
                                          ? 'Massenverkauf: ${result.soldCount} Items fuer +${result.earnedGold} Gold.'
                                          : 'Massenverkauf: Keine verkaufbaren Items (gesperrt/ausgeruestet).';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                      refresh();
                                    },
                                    child: const Text('Massenverkauf'),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      final changed = controller.smartEquipBestItems(
                                        preferSetSynergy: smartEquipMode == SmartEquipMode.setSynergy,
                                      );
                                      final msg = changed > 0
                                          ? 'Smart Equip: $changed Slots aktualisiert.'
                                          : 'Smart Equip: Keine bessere Ausruestung gefunden.';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                      refresh();
                                    },
                                    child: const Text('Smart Equip'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                    if (filteredInventory.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Keine Items im aktuellen Filter.')),
                                      );
                                      return;
                                    }

                                    final preview = controller.getBulkSellPreview(
                                      filteredInventory.map((item) => item.id),
                                    );
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) {
                                        return AlertDialog(
                                          title: const Text('Massenverkauf bestaetigen'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Im Filter: ${preview.candidateCount} Items'),
                                              Text('Verkaufbar: ${preview.sellableCount}'),
                                              Text('Geschuetzt: ${preview.protectedCount}'),
                                              const SizedBox(height: 8),
                                              Text('Erwartetes Gold: +${preview.estimatedGold}'),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(false),
                                              child: const Text('Abbrechen'),
                                            ),
                                            FilledButton.tonal(
                                              onPressed: () => Navigator.of(dialogContext).pop(true),
                                              child: const Text('Verkaufen'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                    if (confirmed != true) {
                                      return;
                                    }
                                    if (!context.mounted) {
                                      return;
                                    }

                                    final result = controller.sellItemsByIds(
                                      filteredInventory.map((item) => item.id),
                                    );
                                    final msg = result.soldCount > 0
                                        ? 'Massenverkauf: ${result.soldCount} Items fuer +${result.earnedGold} Gold.'
                                        : 'Massenverkauf: Keine verkaufbaren Items (gesperrt/ausgeruestet).';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)),
                                    );
                                    refresh();
                                    },
                                    child: const Text('Massenverkauf'),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 6),
                          if (compact)
                            Column(
                              children: [
                                DropdownButton<ItemSet?>(
                                  value: setFilter,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  items: [
                                    const DropdownMenuItem<ItemSet?>(
                                      value: null,
                                      child: Text('Alle Sets'),
                                    ),
                                    ...ItemSet.values.map(
                                      (setId) => DropdownMenuItem<ItemSet?>(
                                        value: setId,
                                        child: Text(controller.setLabel(setId)),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setFilter = value;
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(height: 8),
                                DropdownButton<ItemSlot?>(
                                  value: slotFilter,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  items: [
                                    const DropdownMenuItem<ItemSlot?>(
                                      value: null,
                                      child: Text('Alle Slots'),
                                    ),
                                    ...ItemSlot.values.map(
                                      (slot) => DropdownMenuItem<ItemSlot?>(
                                        value: slot,
                                        child: Text(controller.slotLabel(slot)),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    slotFilter = value;
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(height: 8),
                                DropdownButton<ItemTier?>(
                                  value: tierFilter,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  items: [
                                    const DropdownMenuItem<ItemTier?>(
                                      value: null,
                                      child: Text('Alle Tiers'),
                                    ),
                                    ...ItemTier.values.map(
                                      (tier) => DropdownMenuItem<ItemTier?>(
                                        value: tier,
                                        child: Text(controller.tierLabel(tier)),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    tierFilter = value;
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButton<ItemSet?>(
                                    value: setFilter,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF2A2A2A),
                                    items: [
                                      const DropdownMenuItem<ItemSet?>(
                                        value: null,
                                        child: Text('Alle Sets'),
                                      ),
                                      ...ItemSet.values.map(
                                        (setId) => DropdownMenuItem<ItemSet?>(
                                          value: setId,
                                          child: Text(controller.setLabel(setId)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setFilter = value;
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<ItemSlot?>(
                                    value: slotFilter,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF2A2A2A),
                                    items: [
                                      const DropdownMenuItem<ItemSlot?>(
                                        value: null,
                                        child: Text('Alle Slots'),
                                      ),
                                      ...ItemSlot.values.map(
                                        (slot) => DropdownMenuItem<ItemSlot?>(
                                          value: slot,
                                          child: Text(controller.slotLabel(slot)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      slotFilter = value;
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<ItemTier?>(
                                    value: tierFilter,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF2A2A2A),
                                    items: [
                                      const DropdownMenuItem<ItemTier?>(
                                        value: null,
                                        child: Text('Alle Tiers'),
                                      ),
                                      ...ItemTier.values.map(
                                        (tier) => DropdownMenuItem<ItemTier?>(
                                          value: tier,
                                          child: Text(controller.tierLabel(tier)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      tierFilter = value;
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          if (compact)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Smart:', style: TextStyle(fontSize: 12)),
                                DropdownButton<SmartEquipMode>(
                                  value: smartEquipMode,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  items: const [
                                    DropdownMenuItem(
                                      value: SmartEquipMode.purePower,
                                      child: Text('Power-Fokus'),
                                    ),
                                    DropdownMenuItem(
                                      value: SmartEquipMode.setSynergy,
                                      child: Text('Set-Synergie'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    smartEquipMode = value;
                                    setModalState(() {});
                                  },
                                ),
                                const SizedBox(height: 8),
                                const Text('Sortierung:', style: TextStyle(fontSize: 12)),
                                DropdownButton<InventorySortMode>(
                                  value: sortMode,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  items: const [
                                    DropdownMenuItem(
                                      value: InventorySortMode.powerDesc,
                                      child: Text('Power absteigend'),
                                    ),
                                    DropdownMenuItem(
                                      value: InventorySortMode.tierDesc,
                                      child: Text('Tier absteigend'),
                                    ),
                                    DropdownMenuItem(
                                      value: InventorySortMode.sellValueDesc,
                                      child: Text('Wert absteigend'),
                                    ),
                                    DropdownMenuItem(
                                      value: InventorySortMode.nameAsc,
                                      child: Text('Name A-Z'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    sortMode = value;
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    const Text('Smart:', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButton<SmartEquipMode>(
                                        value: smartEquipMode,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF2A2A2A),
                                        items: const [
                                          DropdownMenuItem(
                                            value: SmartEquipMode.purePower,
                                            child: Text('Power-Fokus'),
                                          ),
                                          DropdownMenuItem(
                                            value: SmartEquipMode.setSynergy,
                                            child: Text('Set-Synergie'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value == null) {
                                            return;
                                          }
                                          smartEquipMode = value;
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Sortierung:', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButton<InventorySortMode>(
                                        value: sortMode,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF2A2A2A),
                                        items: const [
                                          DropdownMenuItem(
                                            value: InventorySortMode.powerDesc,
                                            child: Text('Power absteigend'),
                                          ),
                                          DropdownMenuItem(
                                            value: InventorySortMode.tierDesc,
                                            child: Text('Tier absteigend'),
                                          ),
                                          DropdownMenuItem(
                                            value: InventorySortMode.sellValueDesc,
                                            child: Text('Wert absteigend'),
                                          ),
                                          DropdownMenuItem(
                                            value: InventorySortMode.nameAsc,
                                            child: Text('Name A-Z'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value == null) {
                                            return;
                                          }
                                          sortMode = value;
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          if (compact)
                            Column(
                              children: [
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Auto-Lock', style: TextStyle(fontSize: 12)),
                                  value: controller.autoLockEnabled,
                                  onChanged: (value) {
                                    controller.setAutoLock(
                                      enabled: value,
                                      fromTier: controller.autoLockFromTier,
                                    );
                                    setModalState(() {});
                                  },
                                ),
                                DropdownButton<ItemTier>(
                                  value: controller.autoLockFromTier,
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF2A2A2A),
                                  items: ItemTier.values
                                      .map(
                                        (tier) => DropdownMenuItem<ItemTier>(
                                          value: tier,
                                          child: Text('Lock ab ${controller.tierLabel(tier)}'),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    controller.setAutoLock(
                                      enabled: controller.autoLockEnabled,
                                      fromTier: value,
                                    );
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: SwitchListTile.adaptive(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Auto-Lock', style: TextStyle(fontSize: 12)),
                                    value: controller.autoLockEnabled,
                                    onChanged: (value) {
                                      controller.setAutoLock(
                                        enabled: value,
                                        fromTier: controller.autoLockFromTier,
                                      );
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<ItemTier>(
                                    value: controller.autoLockFromTier,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF2A2A2A),
                                    items: ItemTier.values
                                        .map(
                                          (tier) => DropdownMenuItem<ItemTier>(
                                            value: tier,
                                            child: Text('Lock ab ${controller.tierLabel(tier)}'),
                                          ),
                                        )
                                        .toList(growable: false),
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      controller.setAutoLock(
                                        enabled: controller.autoLockEnabled,
                                        fromTier: value,
                                      );
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                final changed = controller.applyAutoLockToInventory();
                                final msg = changed > 0
                                    ? 'Auto-Lock auf Bestand angewendet: $changed Items geaendert.'
                                    : 'Keine vorhandenen Items mussten angepasst werden.';
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                                refresh();
                              },
                              child: const Text('Auto-Lock auf Bestand anwenden'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.completedSetCount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Komplette Sets: ${controller.completedSetCount}/${ItemSet.values.length}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFBFD8BF)),
                          ),
                        ),
                      ),
                    if (controller.activeSetBonuses.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF4A4A4A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aktive Set-Boni',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            ...controller.activeSetBonuses.map(
                              (bonus) => Text(
                                bonus,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFD6D6D6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final grid = constraints.maxWidth >= 920;

                          Widget card(GameItem item) {
                            final equipped = controller.isEquipped(item);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF454545)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _SvgIcon(path: item.iconPath, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (equipped)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3A3A3A),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            text.tr('equipped'),
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${controller.tierLabel(item.tier)} | ${controller.setLabel(item.setId)} | +${item.power} | ${controller.slotLabel(item.slot)}',
                                    style: const TextStyle(color: Color(0xFFC9C9C9), fontSize: 12),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          controller.toggleItemLock(item.id);
                                          refresh();
                                        },
                                        icon: Icon(
                                          item.isLocked ? Icons.lock : Icons.lock_open,
                                          size: 18,
                                          color: item.isLocked
                                              ? const Color(0xFFE2D18D)
                                              : const Color(0xFFA8A8A8),
                                        ),
                                        tooltip: item.isLocked ? 'Entsperren' : 'Sperren',
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (equipped) {
                                            controller.unequipSlot(item.slot);
                                          } else {
                                            controller.equipItem(item);
                                          }
                                          refresh();
                                        },
                                        child: Text(equipped ? text.tr('unequip') : text.tr('equip')),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        onPressed: () {
                                          final sold = controller.sellItem(item);
                                          if (!sold) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Item ist gesperrt und kann nicht verkauft werden.'),
                                              ),
                                            );
                                            return;
                                          }
                                          refresh();
                                        },
                                        child: Text(
                                          item.isLocked
                                              ? 'Gesperrt'
                                              : '${text.tr('sell')} (${item.sellValue})',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          if (!grid) {
                            return ListView.builder(
                              itemCount: filteredInventory.length,
                              itemBuilder: (context, index) => card(filteredInventory[index]),
                            );
                          }

                          return GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.5,
                            ),
                            itemCount: filteredInventory.length,
                            itemBuilder: (context, index) => card(filteredInventory[index]),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showWorldPanel(BuildContext context, GameController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(context, factor: 0.72, min: 420, max: 940),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weltkarte',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Aktuell: Kapitel ${controller.chapter} - Stage ${controller.stage}'),
                      Text('Bosse besiegt: ${controller.bossDefeats}'),
                      Text('Tode: ${controller.deaths}'),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: () => _showAchievementsPanel(context, controller),
                          child: Text(
                            'Errungenschaften '
                            '(${controller.claimableAchievementCount} bereit)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF464646)),
                        ),
                        child: Text(
                          controller.chapterSetHuntHint,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFD4D4D4)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Meilensteine'),
                      const SizedBox(height: 6),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 900;

                            Widget milestoneCard(int milestoneChapter) {
                              final reached = controller.chapter >= milestoneChapter;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: reached ? const Color(0xFF2D352D) : const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: reached ? const Color(0xFF5E7A5E) : const Color(0xFF454545),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      reached ? Icons.check_circle : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: reached ? const Color(0xFF9AC39A) : const Color(0xFF8D8D8D),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Kapitel $milestoneChapter Boss besiegen'),
                                  ],
                                ),
                              );
                            }

                            Widget setCard(SetCollectionView entry, {double? width}) {
                              final missing = entry.missingSlots
                                  .map((slot) => controller.slotLabel(slot))
                                  .join(', ');
                              return Container(
                                width: width,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: entry.ownedCount == entry.totalCount
                                      ? const Color(0xFF2D352D)
                                      : const Color(0xFF2A2A2A),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF454545)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${controller.setLabel(entry.setId)} ${entry.ownedCount}/${entry.totalCount}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      entry.missingSlots.isEmpty
                                          ? 'Komplett gesammelt'
                                          : 'Fehlt: $missing',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Belohnung: +${entry.rewardGold} Gold, +${entry.rewardShards} Scherben',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFCFCFCF)),
                                    ),
                                    const SizedBox(height: 6),
                                    if (entry.rewardClaimed)
                                      const Text(
                                        'Belohnung eingesammelt',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF9AC39A)),
                                      )
                                    else if (entry.rewardClaimable)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: FilledButton.tonal(
                                          onPressed: () {
                                            final ok = controller.claimSetCompletionReward(entry.setId);
                                            if (ok) {
                                              setModalState(() {});
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Set-Belohnung eingesammelt.')),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Set-Belohnung kann noch nicht eingesammelt werden.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text('Belohnung einsammeln'),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }

                            return ListView(
                              children: [
                                if (!wide)
                                  ...List.generate(8, (index) => milestoneCard(index + 1))
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 0,
                                    children: List.generate(
                                      8,
                                      (index) => SizedBox(
                                        width: (constraints.maxWidth - 8) / 2,
                                        child: milestoneCard(index + 1),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                const Text('Set-Sammlung', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                if (!wide)
                                  ...controller.setCollection.map((entry) => setCard(entry))
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 0,
                                    children: controller.setCollection
                                        .map((entry) => setCard(entry, width: (constraints.maxWidth - 8) / 2))
                                        .toList(growable: false),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAchievementsPanel(BuildContext context, GameController controller) async {
    AchievementFilterMode filterMode = AchievementFilterMode.all;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(context, factor: 0.78, min: 460, max: 960),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final entries = controller.achievements;
                final claimable = entries.where((entry) => entry.canClaim).length;
                final unclaimed = entries.where((entry) => !entry.claimed).length;
                final total = entries.length;
                final claimed = entries.where((entry) => entry.claimed).length;
                final shownEntries = switch (filterMode) {
                  AchievementFilterMode.all => entries,
                  AchievementFilterMode.claimable => entries
                      .where((entry) => entry.canClaim)
                      .toList(growable: false),
                  AchievementFilterMode.unclaimed => entries
                      .where((entry) => !entry.claimed)
                      .toList(growable: false),
                  AchievementFilterMode.claimed => entries
                      .where((entry) => entry.claimed)
                      .toList(growable: false),
                };

                Widget achievementCard(AchievementView entry) {
                  final def = entry.definition;
                  final progressRatio = (entry.progress / def.target).clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: entry.claimed ? const Color(0xFF2D352D) : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF454545)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(def.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(def.description, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: progressRatio,
                            backgroundColor: const Color(0xFF202020),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              entry.canClaim ? const Color(0xFF9AC39A) : const Color(0xFF7E8D9B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fortschritt ${entry.progress}/${def.target} | '
                          '+${def.rewardGold} Gold, +${def.rewardShards} Scherben',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFCFCFCF)),
                        ),
                        const SizedBox(height: 6),
                        if (entry.claimed)
                          const Text(
                            'Bereits eingesammelt',
                            style: TextStyle(fontSize: 12, color: Color(0xFF9AC39A)),
                          )
                        else
                          FilledButton.tonal(
                            onPressed: entry.canClaim
                                ? () {
                                    final ok = controller.claimAchievement(def.id);
                                    if (ok) {
                                      setModalState(() {});
                                    }
                                  }
                                : null,
                            child: const Text('Belohnung einsammeln'),
                          ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Errungenschaften',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('Freigeschaltet: $claimed/$total | Offen: $unclaimed | Einloesbar: $claimable'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: controller.claimableAchievementCount > 0
                                ? () {
                                    final count = controller.claimAllAchievements();
                                    if (count > 0) {
                                      setModalState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$count Belohnungen eingesammelt.')),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('Alle verfuegbaren einsammeln'),
                          ),
                          ChoiceChip(
                            label: const Text('Alle'),
                            selected: filterMode == AchievementFilterMode.all,
                            onSelected: (_) {
                              setModalState(() {
                                filterMode = AchievementFilterMode.all;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text('Einloesbar ($claimable)'),
                            selected: filterMode == AchievementFilterMode.claimable,
                            onSelected: (_) {
                              setModalState(() {
                                filterMode = AchievementFilterMode.claimable;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text('Offen ($unclaimed)'),
                            selected: filterMode == AchievementFilterMode.unclaimed,
                            onSelected: (_) {
                              setModalState(() {
                                filterMode = AchievementFilterMode.unclaimed;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text('Erledigt ($claimed)'),
                            selected: filterMode == AchievementFilterMode.claimed,
                            onSelected: (_) {
                              setModalState(() {
                                filterMode = AchievementFilterMode.claimed;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 920;
                            if (!wide) {
                              return ListView(
                                children: shownEntries
                                    .map(achievementCard)
                                    .toList(growable: false),
                              );
                            }

                            return GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.9,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: shownEntries.length,
                              itemBuilder: (context, index) => achievementCard(shownEntries[index]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showShopPanel(BuildContext context, GameController controller) async {
    ShopPanelTab selectedTab = ShopPanelTab.all;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1F1F1F),
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(context, factor: 0.58, min: 320, max: 760),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                String formatDuration(Duration value) {
                  final minutes = value.inMinutes;
                  final seconds = value.inSeconds % 60;
                  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                }

                Widget shopCard({required ShopOffer offer, double? width}) {
                  final soldOut = offer.stock <= 0;
                  final canBuy = !soldOut && controller.gold >= offer.cost;
                  return Container(
                    width: width,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF474747)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                controller.shopOfferTitle(offer),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (offer.isDaily)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B3D2C),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'DAILY -${offer.discountPercent}%',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFFFFD6A6)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.shopOfferDescription(offer),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text('Bestand ${offer.stock} | Kosten ${offer.cost} Gold'),
                        const SizedBox(height: 6),
                        FilledButton.tonal(
                          onPressed: canBuy
                              ? () {
                                  final ok = controller.buyShopOffer(offer.id);
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Kauf fehlgeschlagen.')),
                                    );
                                  }
                                  setModalState(() {});
                                }
                              : null,
                          child: Text(soldOut ? 'Ausverkauft' : 'Kaufen'),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        final wide = constraints.maxWidth >= 900;
                        final timer = formatDuration(controller.shopRefreshRemaining);
                        final offers = controller.allShopOffers.where((offer) {
                          return switch (selectedTab) {
                            ShopPanelTab.all => true,
                            ShopPanelTab.daily => offer.isDaily,
                            ShopPanelTab.upgrades =>
                              offer.kind == ShopOfferKind.speedUpgrade ||
                              offer.kind == ShopOfferKind.hammerUpgrade ||
                              offer.kind == ShopOfferKind.recoveryUpgrade,
                            ShopPanelTab.resources =>
                              offer.kind == ShopOfferKind.hammerPack ||
                              offer.kind == ShopOfferKind.shardCache,
                            ShopPanelTab.combat =>
                              offer.kind == ShopOfferKind.healingFlask ||
                              offer.kind == ShopOfferKind.berserkFlask,
                          };
                        }).toList(growable: false);

                        return ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            const Text(
                              'Marktplatz',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Gold: ${controller.gold} | Scherben: ${controller.forgeShards}'),
                            Text('Flasks: Heil ${controller.healingFlasks} | Berserk ${controller.berserkFlasks}'),
                            Text('Tagesangebote: ${controller.dailyShopOffers.where((entry) => entry.stock > 0).length} aktiv'),
                            Text('Shop-Refresh in $timer'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () {
                                    final ok = controller.refreshShopManually();
                                    if (!ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Zu wenig Gold fuer Reroll.')),
                                      );
                                    }
                                    setModalState(() {});
                                  },
                                  child: Text('Shop neu rollen (${controller.shopRefreshCost} Gold)'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Alle'),
                                  selected: selectedTab == ShopPanelTab.all,
                                  onSelected: (_) => setModalState(() => selectedTab = ShopPanelTab.all),
                                ),
                                ChoiceChip(
                                  label: const Text('Daily'),
                                  selected: selectedTab == ShopPanelTab.daily,
                                  onSelected: (_) => setModalState(() => selectedTab = ShopPanelTab.daily),
                                ),
                                ChoiceChip(
                                  label: const Text('Upgrades'),
                                  selected: selectedTab == ShopPanelTab.upgrades,
                                  onSelected: (_) => setModalState(() => selectedTab = ShopPanelTab.upgrades),
                                ),
                                ChoiceChip(
                                  label: const Text('Ressourcen'),
                                  selected: selectedTab == ShopPanelTab.resources,
                                  onSelected: (_) => setModalState(() => selectedTab = ShopPanelTab.resources),
                                ),
                                ChoiceChip(
                                  label: const Text('Kampf'),
                                  selected: selectedTab == ShopPanelTab.combat,
                                  onSelected: (_) => setModalState(() => selectedTab = ShopPanelTab.combat),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Angebote', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (offers.isEmpty)
                              const Text(
                                'Keine Angebote in dieser Kategorie.',
                                style: TextStyle(color: Color(0xFFC0C0C0)),
                              ),
                            if (!wide)
                              ...offers.map((offer) => shopCard(offer: offer))
                            else
                              Wrap(
                                spacing: 10,
                                runSpacing: 0,
                                children: offers
                                    .map(
                                      (offer) => shopCard(
                                        offer: offer,
                                        width: (constraints.maxWidth - 10) / 2,
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.iconPath, required this.label, required this.onTap});

  final String iconPath;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF454545)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SvgIcon(path: iconPath, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Color(0xFFD2D2D2)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SvgIcon extends StatelessWidget {
  const _SvgIcon({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(path, width: size, height: size, fit: BoxFit.contain);
  }
}

class _Runner extends StatelessWidget {
  const _Runner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x554D4D4D), Color(0x00282828)],
        ),
      ),
      child: const _SvgIcon(path: 'assets/icons/player.svg', size: 48),
    );
  }
}

class _Enemy extends StatelessWidget {
  const _Enemy({required this.isBoss});

  final bool isBoss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isBoss ? 82 : 70,
      height: isBoss ? 82 : 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isBoss
              ? const [Color(0x886D4A4A), Color(0x00322222)]
              : const [Color(0x88555555), Color(0x00272727)],
        ),
      ),
      child: _SvgIcon(path: 'assets/icons/enemy.svg', size: isBoss ? 56 : 48),
    );
  }
}
