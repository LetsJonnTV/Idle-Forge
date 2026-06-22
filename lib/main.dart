import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'game/game_controller.dart';
import 'game/models.dart';
import 'l10n/app_text.dart';
import 'screens/auth_screen.dart';
import 'screens/clan_screen.dart';
import 'screens/coop_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/pvp_screen.dart';
import 'services/api_service.dart';
import 'services/update_checker.dart';
import 'services/update_installer.dart';

const bool devMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);
const bool disableUpdateCheck = bool.fromEnvironment(
  'DISABLE_UPDATE_CHECK',
  defaultValue: false,
);

enum InventorySortMode { powerDesc, tierDesc, sellValueDesc, nameAsc }

enum SmartEquipMode { purePower, setSynergy }

enum AchievementFilterMode { all, claimable, unclaimed, claimed }

enum ShopPanelTab { all, daily, upgrades, resources, combat }

double _uiScale(BuildContext context, {double min = 0.78, double max = 1.28}) {
  final size = MediaQuery.sizeOf(context);
  final byWidth = size.width / 390;
  final byHeight = size.height / 844;
  return math.min(byWidth, byHeight).clamp(min, max).toDouble();
}

double _rs(BuildContext context, double base, {double min = 0, double? max}) {
  final scaled = base * _uiScale(context);
  if (max != null) {
    return scaled.clamp(min, max).toDouble();
  }
  return math.max(min, scaled);
}

double _textScaleForSize(Size size) {
  final byWidth = size.width / 390;
  final byHeight = size.height / 844;
  return math.min(byWidth, byHeight).clamp(0.9, 1.1).toDouble();
}

double _adaptiveSheetHeight(
  BuildContext context, {
  required double factor,
  double min = 320,
  double max = 820,
}) {
  final size = MediaQuery.sizeOf(context);
  final insets = MediaQuery.paddingOf(context).vertical;
  final usableHeight = size.height - insets;
  final boostedFactor = size.width < 430 ? factor + 0.08 : factor;
  final h = usableHeight * boostedFactor;
  return h.clamp(min, max).toDouble();
}

extension _AppColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  // Deep forge atmosphere — near-black with a blue-coal tint in dark mode,
  // warm aged-parchment in light mode.
  Color get bodyBg =>
      _isDark ? const Color(0xFF0C0F16) : const Color(0xFFF0E8D8);

  Color get sheetBg =>
      _isDark ? const Color(0xFF12161F) : const Color(0xFFEDE0C8);

  Color get cardBg =>
      _isDark ? const Color(0xFF191E2C) : const Color(0xFFFFF8EC);

  Color get cardBgAlt =>
      _isDark ? const Color(0xFF121828) : const Color(0xFFF5EDDB);

  Color get inputBg =>
      _isDark ? const Color(0xFF0E1220) : const Color(0xFFE8DCC8);

  // Subtle dark border — used where gold would be too loud.
  Color get cardBorder =>
      _isDark ? const Color(0xFF2A3048) : const Color(0xFFBEA870);

  // Standard heavier border.
  Color get borderHeavy =>
      _isDark ? const Color(0xFF3C4560) : const Color(0xFF9A7840);

  // Gold border — the signature game accent.
  Color get borderGold =>
      _isDark ? const Color(0xFF7A5818) : const Color(0xFF9A7420);

  // Bright gold border for highlighted / interactive containers.
  Color get borderGoldBright => const Color(0xFFC09028);

  Color get divider =>
      _isDark ? const Color(0xFF262C40) : const Color(0xFFD0B878);

  Color get textPrimary =>
      _isDark ? const Color(0xFFDED0B0) : const Color(0xFF2A1E08);

  Color get textSecondary =>
      _isDark ? const Color(0xFF9A8860) : const Color(0xFF6A5028);

  Color get textTertiary =>
      _isDark ? const Color(0xFF706048) : const Color(0xFF9A8058);

  Color get textBright =>
      _isDark ? const Color(0xFFF0E4C0) : const Color(0xFF1A0E00);

  // Gold icon tint — icons glow with forge-fire hue.
  Color get iconColor =>
      _isDark ? const Color(0xFFD4A84B) : const Color(0xFF7A5A18);

  Color get overlayBg =>
      _isDark ? const Color(0xCC0C0F18) : const Color(0xCCF0E4C8);

  // Named semantic accents available throughout the file.
  Color get goldAccent => const Color(0xFFD4A84B);
  Color get goldAccentBright => const Color(0xFFF0C050);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.loadStoredCredentials();
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

    if (controller.streakClaimedToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showStreakDialog(context, controller);
      });
    }

    if (!disableUpdateCheck) {
      // Version check
      final updateChecker = UpdateChecker();
      final updateInfo = await updateChecker.checkForUpdate();
      if (updateInfo != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                _UpdateDialog(updateInfo: updateInfo, controller: controller),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: controller.text.tr('appTitle'),
          themeMode: controller.darkModeEnabled
              ? ThemeMode.dark
              : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            fontFamily: 'monospace',
            visualDensity: VisualDensity.adaptivePlatformDensity,
            scaffoldBackgroundColor: const Color(0xFFF0E8D8),
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF7A5818),
              secondary: const Color(0xFF9A7820),
              surface: const Color(0xFFFFF8EC),
              onSurface: const Color(0xFF2A1E08),
              surfaceContainerHighest: const Color(0xFFF5EDDB),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFFF5EDDB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                side: BorderSide(color: Color(0xFF9A7820), width: 1.5),
              ),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xFFE8D8A8),
              contentTextStyle: TextStyle(color: Color(0xFF2A1E08)),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'monospace',
            visualDensity: VisualDensity.adaptivePlatformDensity,
            scaffoldBackgroundColor: const Color(0xFF0C0F16),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4A84B),
              secondary: Color(0xFFC09028),
              surface: Color(0xFF191E2C),
              onSurface: Color(0xFFDED0B0),
              surfaceContainerHighest: Color(0xFF121828),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF191E2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                side: BorderSide(color: Color(0xFF7A5818), width: 1.5),
              ),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Color(0xFF252C40),
              contentTextStyle: TextStyle(color: Color(0xFFDED0B0)),
            ),
          ),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final textScale = _textScaleForSize(media.size);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(textScale)),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: controller.isLoaded
              ? IdleForgeHome(controller: controller)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        );
      },
    );
  }
}

class IdleForgeHome extends StatefulWidget {
  const IdleForgeHome({super.key, required this.controller});

  final GameController controller;

  @override
  State<IdleForgeHome> createState() => _IdleForgeHomeState();
}

class _IdleForgeHomeState extends State<IdleForgeHome> {
  GameController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (!controller.tutorialCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !controller.tutorialCompleted) {
          _showTutorial();
        }
      });
    }
  }

  void _showTutorial() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) => _TutorialOverlay(
        controller: controller,
        onComplete: () {
          controller.completeTutorial();
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dense = size.width < 390 || size.height < 760;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        color: context.bodyBg,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(controller: controller, dense: dense),
              Expanded(
                child: _CombatArea(controller: controller, dense: dense),
              ),
              _BottomMenu(controller: controller, dense: dense),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, this.dense = false});

  final GameController controller;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final compactScale = _uiScale(context, min: 0.8, max: 1.2);
    final iconSize = (dense ? 18 : 20) * compactScale;

    Widget actionIcon({required IconData icon, required VoidCallback onTap}) {
      return InkWell(
        borderRadius: BorderRadius.circular(_rs(context, 12, min: 8)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _rs(context, dense ? 8 : 10, min: 6),
            vertical: _rs(context, dense ? 8 : 10, min: 6),
          ),
          decoration: BoxDecoration(
            color: context.cardBgAlt,
            borderRadius: BorderRadius.circular(_rs(context, 12, min: 8)),
            border: Border.all(color: context.borderGold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: context.goldAccent.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: context.goldAccent, size: iconSize),
        ),
      );
    }

    final profileCard = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_rs(context, 12, min: 8)),
        onTap: () => _showProfilePanel(context),
        child: Container(
          padding: EdgeInsets.all(_rs(context, dense ? 8 : 10, min: 6)),
          decoration: BoxDecoration(
            color: context.cardBgAlt,
            borderRadius: BorderRadius.circular(_rs(context, 12, min: 8)),
            border: Border.all(color: context.borderGold, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: context.goldAccent.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _SvgIcon(
                path: 'assets/icons/profile.svg',
                size: _rs(context, dense ? 30 : 34, min: 22),
              ),
              SizedBox(width: _rs(context, 8, min: 5)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.playerName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: _rs(context, dense ? 13 : 14, min: 11),
                        color: context.textBright,
                      ),
                    ),
                    SizedBox(height: _rs(context, 2, min: 1)),
                    Text(
                      '${text.tr('totalStrength')}: ${controller.totalStrength}',
                      style: TextStyle(
                        fontSize: _rs(context, dense ? 11 : 12, min: 9),
                        color: context.textSecondary,
                      ),
                    ),
                    Text(
                      'Prestige ${controller.prestigeLevel} | Scherben ${controller.forgeShards}',
                      style: TextStyle(
                        fontSize: _rs(context, dense ? 10 : 11, min: 8.5),
                        color: context.textTertiary,
                      ),
                    ),
                    Text(
                      'HP ${controller.playerHp.round()}/${controller.maxPlayerHp.round()} | Tode ${controller.deaths}',
                      style: TextStyle(
                        fontSize: _rs(context, dense ? 10 : 11, min: 8.5),
                        color: context.textTertiary,
                      ),
                    ),
                    Text(
                      'Profil bearbeiten',
                      style: TextStyle(
                        fontSize: _rs(context, dense ? 9.5 : 10.5, min: 8.5),
                        color: const Color(0xFF9FB6CF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final goldCard = Container(
      padding: EdgeInsets.symmetric(
        horizontal: _rs(context, dense ? 10 : 12, min: 8),
        vertical: _rs(context, dense ? 8 : 10, min: 6),
      ),
      decoration: BoxDecoration(
        color: context.cardBgAlt,
        borderRadius: BorderRadius.circular(_rs(context, 12, min: 8)),
        border: Border.all(color: context.borderGoldBright, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.goldAccentBright.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SvgIcon(
            path: 'assets/icons/gold.svg',
            size: _rs(context, dense ? 18 : 20, min: 14),
          ),
          SizedBox(width: _rs(context, 6, min: 4)),
          Text(
            '${controller.gold}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: _rs(context, dense ? 14 : 15, min: 11),
              color: context.goldAccentBright,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _rs(context, 12, min: 8),
        _rs(context, dense ? 8 : 12, min: 6),
        _rs(context, 12, min: 8),
        _rs(context, dense ? 6 : 8, min: 4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = dense || constraints.maxWidth < 720;
          if (!compact) {
            return Row(
              children: [
                Expanded(child: profileCard),
                SizedBox(width: _rs(context, 8, min: 5)),
                goldCard,
                SizedBox(width: _rs(context, 8, min: 5)),
                actionIcon(
                  icon: Icons.auto_awesome,
                  onTap: () => _showSkillTree(context, controller),
                ),
                const SizedBox(width: 8),
                actionIcon(
                  icon: Icons.settings,
                  onTap: () => _showSettingsPanel(context),
                ),
                if (devMode) ...[
                  SizedBox(width: _rs(context, 8, min: 5)),
                  actionIcon(
                    icon: Icons.tune,
                    onTap: () => _showDeveloperPanel(context),
                  ),
                ],
              ],
            );
          }

          return Column(
            children: [
              profileCard,
              SizedBox(height: _rs(context, 8, min: 5)),
              Row(
                children: [
                  Expanded(child: goldCard),
                  SizedBox(width: _rs(context, 8, min: 5)),
                  actionIcon(
                    icon: Icons.auto_awesome,
                    onTap: () => _showSkillTree(context, controller),
                  ),
                  const SizedBox(width: 8),
                  actionIcon(
                    icon: Icons.settings,
                    onTap: () => _showSettingsPanel(context),
                  ),
                  if (devMode) ...[
                    SizedBox(width: _rs(context, 8, min: 5)),
                    actionIcon(
                      icon: Icons.tune,
                      onTap: () => _showDeveloperPanel(context),
                    ),
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
      backgroundColor: context.sheetBg,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.8,
              min: 360,
              max: 900,
            ),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Live Balancing für Kampf und Ökonomie',
                      style: TextStyle(color: Color(0xFFBABABA), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              controller.debugAddResources(
                                goldDelta: 200,
                                hammerDelta: 20,
                              );
                              setModalState(() {});
                            },
                            child: const Text('+200 Gold / +20 Hämmer'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              controller.debugAdvanceStage(1);
                              setModalState(() {});
                            },
                            child: const Text('Nächste Stage'),
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
                    const Text(
                      'Presets',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                        update(
                          tuning.copyWith(enemyHpMultiplier: value),
                          refreshEnemy: true,
                        );
                      },
                    ),
                    _TuningSlider(
                      label: 'Gegner Geschwindigkeit',
                      value: tuning.enemyApproachSpeedMultiplier,
                      min: 0.3,
                      max: 3,
                      onChanged: (value) {
                        update(
                          tuning.copyWith(enemyApproachSpeedMultiplier: value),
                        );
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

  Future<void> _showSettingsPanel(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    const fpsOptions = [30, 45, 60, 90, 120];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.sheetBg,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(ctx, factor: 0.65, min: 420, max: 680),
            child: StatefulBuilder(
              builder: (ctx, setModalState) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      controller.text.tr('settings'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ctx.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ctx.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: ctx.iconColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${controller.text.tr('appVersion')}: ${packageInfo.version}',
                            style: TextStyle(
                              color: ctx.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final uri = Uri.parse(
                          'https://github.com/LetsJonnTV/Idle-Forge/issues/new',
                        );
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ctx.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ctx.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bug_report_outlined,
                              color: ctx.iconColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              controller.text.tr('reportBug'),
                              style: TextStyle(
                                color: ctx.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.open_in_new,
                              color: ctx.textTertiary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'App Einstellungen',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Max FPS')),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 130,
                          child: DropdownButton<int>(
                            value: controller.targetFps,
                            isExpanded: true,
                            items: fpsOptions
                                .map(
                                  (fps) => DropdownMenuItem<int>(
                                    value: fps,
                                    child: Text('$fps'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              controller.setTargetFps(value);
                              setModalState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark Mode'),
                      value: controller.darkModeEnabled,
                      onChanged: (value) {
                        controller.setDarkModeEnabled(value);
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kampf-Log anzeigen'),
                      value: controller.showCombatLog,
                      onChanged: (value) {
                        controller.setShowCombatLog(value);
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reduzierte Effekte'),
                      value: controller.reducedEffects,
                      onChanged: (value) {
                        controller.setReducedEffects(value);
                        setModalState(() {});
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

  Future<void> _showProfilePanel(BuildContext context) async {
    final isLoggedIn = ApiService.instance.isLoggedIn;
    final loginName = ApiService.instance.currentUsername;
    if (isLoggedIn && loginName != null && loginName.isNotEmpty) {
      controller.setPlayerName(loginName);
    }
    final nameController = TextEditingController(text: controller.playerName);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
              height: _adaptiveSheetHeight(
                context,
                factor: 0.5,
                min: 320,
                max: 560,
              ),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              const Text(
                                'Profil',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: nameController,
                                maxLength: 20,
                                readOnly: isLoggedIn,
                                enabled: !isLoggedIn,
                                decoration: InputDecoration(
                                  labelText: 'Spielername',
                                  counterText: '',
                                  suffixIcon: isLoggedIn
                                      ? const Icon(Icons.lock_outline, size: 18)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Kapitel ${controller.chapter} - Stage ${controller.stage}',
                              ),
                              Text('Gesamtstärke: ${controller.totalStrength}'),
                              Text(
                                'Prestige: ${controller.prestigeLevel} | Scherben: ${controller.forgeShards}',
                              ),
                              Text(
                                'Bosse besiegt: ${controller.bossDefeats} | Tode: ${controller.deaths}',
                              ),
                              if (isLoggedIn) ...[
                                const SizedBox(height: 14),
                                Text(
                                  controller.text.tr('cloudSection'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (controller.cloudSyncStatus != null) ...[
                                  Text(
                                    () {
                                      return switch (controller
                                          .cloudSyncStatus) {
                                        'saving' => controller.text.tr(
                                          'cloudSaving',
                                        ),
                                        'loading' => controller.text.tr(
                                          'cloudLoading',
                                        ),
                                        'saved' => controller.text.tr(
                                          'cloudSaved',
                                        ),
                                        'loaded' => controller.text.tr(
                                          'cloudLoaded',
                                        ),
                                        _ => controller.text.tr('cloudError'),
                                      };
                                    }(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          controller.cloudSyncStatus == 'error'
                                          ? Colors.red
                                          : const Color(0xFF8FD39E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon:
                                            controller.cloudSyncStatus ==
                                                'saving'
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.cloud_upload_outlined,
                                                size: 16,
                                              ),
                                        label: Text(
                                          controller.text.tr('cloudSave'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed:
                                            (controller.cloudSyncStatus ==
                                                    'saving' ||
                                                controller.cloudSyncStatus ==
                                                    'loading')
                                            ? null
                                            : () async {
                                                setModalState(() {});
                                                await controller.cloudSave();
                                                if (context.mounted) {
                                                  setModalState(() {});
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon:
                                            controller.cloudSyncStatus ==
                                                'loading'
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.cloud_download_outlined,
                                                size: 16,
                                              ),
                                        label: Text(
                                          controller.text.tr('cloudLoad'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed:
                                            (controller.cloudSyncStatus ==
                                                    'saving' ||
                                                controller.cloudSyncStatus ==
                                                    'loading')
                                            ? null
                                            : () async {
                                                setModalState(() {});
                                                await controller.cloudLoad();
                                                if (context.mounted) {
                                                  setModalState(() {});
                                                }
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Schliessen'),
                              ),
                            ),
                            if (!isLoggedIn) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    final ok = controller.setPlayerName(
                                      nameController.text,
                                    );
                                    if (!ok &&
                                        nameController.text.trim() !=
                                            controller.playerName) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Name ungültig oder unverändert (2-20 Zeichen).',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setModalState(() {});
                                    FocusScope.of(context).unfocus();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Profil gespeichert.'),
                                      ),
                                    );
                                  },
                                  child: const Text('Speichern'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    // Auto-save name when sheet is dismissed (e.g. swipe-down).
    // Capture text before any rebuild can interfere.
    final pendingName = nameController.text;
    // Do NOT call nameController.dispose() here — the closing sheet
    // animation still references it and disposing triggers cascading
    // "used after disposed" / GlobalKey errors.  GC will reclaim it.
    if (!isLoggedIn) {
      controller.setPlayerName(pendingName);
    }
  }
}

class _PetPanel extends StatelessWidget {
  const _PetPanel({required this.controller, required this.onRefresh});

  final GameController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final pet = controller.activePet;
    if (pet == null || !pet.isActive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kein Begleiter aktiv.', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PetType.values.map((type) {
              final label = switch (type) {
                PetType.wolf => 'Wolf (Gold +%)',
                PetType.phoenix => 'Phoenix (Forge +%)',
                PetType.golem => 'Golem (Rüstung +%)',
              };
              return OutlinedButton(
                onPressed: () {
                  final ok = controller.adoptPet(type);
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nicht genug Gold (200 benötigt).'),
                      ),
                    );
                  }
                  onRefresh();
                },
                child: Text(
                  '$label\n(200 Gold)',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    final typeName = switch (pet.type) {
      PetType.wolf => 'Wolf',
      PetType.phoenix => 'Phoenix',
      PetType.golem => 'Golem',
    };
    final bonusText = switch (pet.type) {
      PetType.wolf =>
        '+${(controller.petGoldBonus * 100).toStringAsFixed(1)}% Gold',
      PetType.phoenix =>
        '+${(controller.petForgeBonus * 100).toStringAsFixed(1)}% Schmiedechance',
      PetType.golem =>
        '+${(controller.petDefenseBonus * 100).toStringAsFixed(1)}% Rüstung',
    };
    final maxXp = pet.level < 20 ? pet.level * 100 : 1;
    final xpRatio = pet.level < 20 ? (pet.xp / maxXp).clamp(0.0, 1.0) : 1.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pets, size: 20),
              const SizedBox(width: 8),
              Text(
                '$typeName  Lv.${pet.level}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                bonusText,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8FD39E)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (pet.level < 20) ...[
            Text(
              'XP: ${pet.xp} / ${pet.level * 100}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: xpRatio,
                minHeight: 6,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFD4A44C),
                ),
                backgroundColor: const Color(0xFF3A3A3A),
              ),
            ),
          ] else
            const Text(
              'Max Level erreicht!',
              style: TextStyle(fontSize: 12, color: Color(0xFFD4A44C)),
            ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () {
              const feedCost = 5;
              if (controller.hammers < feedCost) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nicht genug Hammer (5 benötigt).'),
                  ),
                );
                return;
              }
              controller.hammers -= feedCost;
              controller.feedPet(feedCost);
              onRefresh();
            },
            child: const Text('Füttern (5 Hammer)'),
          ),
        ],
      ),
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
        color: context.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
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
  const _CombatArea({required this.controller, this.dense = false});

  final GameController controller;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final hpPercent = (controller.enemy.hp / controller.enemy.maxHp)
        .clamp(0.0, 1.0)
        .toDouble();
    final playerPod = _rs(context, dense ? 64 : 72, min: 54, max: 90);
    final enemyPod = controller.enemy.isBoss
        ? _rs(context, dense ? 74 : 82, min: 62, max: 96)
        : _rs(context, dense ? 64 : 70, min: 54, max: 88);

    return LayoutBuilder(
      builder: (context, rootConstraints) {
        final ultraCompact = rootConstraints.maxHeight < 180;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            _rs(context, 12, min: 8),
            _rs(context, 4, min: 2),
            _rs(context, 12, min: 8),
            _rs(context, 6, min: 3),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_rs(context, 16, min: 12)),
              border: Border.all(color: context.borderGold, width: 1.5),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [context.cardBg, context.cardBgAlt],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.goldAccent.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _rs(context, 12, min: 8),
                    _rs(context, dense ? 8 : 10, min: 6),
                    _rs(context, 12, min: 8),
                    _rs(context, 6, min: 4),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${text.tr('chapter')} ${controller.chapter}-${controller.stage}',
                        style: TextStyle(
                          fontSize: _rs(context, dense ? 12 : 13, min: 10),
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${controller.killsInStage}/${controller.stageTargetKills}',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: _rs(context, dense ? 11 : 12, min: 9.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.showCombatLog &&
                    controller.lastCombatEvent.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _rs(context, 12, min: 8),
                      0,
                      _rs(context, 12, min: 8),
                      _rs(context, 6, min: 4),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        controller.lastCombatEvent,
                        style: TextStyle(
                          fontSize: _rs(context, dense ? 10 : 11, min: 9),
                          color: const Color(0xFFC9A8A8),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final enemyX = (width * controller.enemy.approach).clamp(
                        width * 0.5,
                        width - (enemyPod + 12),
                      );
                      final playerYBob = controller.animationBob;

                      return Stack(
                        children: [
                          Positioned(
                            left: width * 0.5 - (playerPod / 2),
                            bottom:
                                _rs(context, dense ? 18 : 28, min: 14) +
                                playerYBob,
                            child: Column(
                              children: [
                                SizedBox(
                                  width: playerPod + _rs(context, 6, min: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: controller.playerHpPercent,
                                      minHeight: _rs(context, 5, min: 4),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF4EC878),
                                          ),
                                      backgroundColor: const Color(0xFF0D2010),
                                    ),
                                  ),
                                ),
                                SizedBox(height: _rs(context, 4, min: 3)),
                                _Runner(size: playerPod),
                              ],
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            left: enemyX,
                            bottom: _rs(context, dense ? 14 : 24, min: 10),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: enemyPod + _rs(context, 6, min: 4),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: hpPercent,
                                      minHeight: _rs(context, 6, min: 4.5),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        controller.enemy.isBoss
                                            ? const Color(0xFFE06767)
                                            : context.textPrimary,
                                      ),
                                      backgroundColor: context.borderHeavy,
                                    ),
                                  ),
                                ),
                                SizedBox(height: _rs(context, 3, min: 2)),
                                Text(
                                  controller.enemy.name,
                                  style: TextStyle(
                                    fontSize: _rs(
                                      context,
                                      dense ? 9 : 10,
                                      min: 8,
                                    ),
                                    color: context.textPrimary,
                                  ),
                                ),
                                SizedBox(height: _rs(context, 2, min: 1)),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: _rs(context, 6, min: 4),
                                    vertical: _rs(context, 2, min: 1),
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.cardBg,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: context.borderHeavy,
                                    ),
                                  ),
                                  child: Text(
                                    controller.enemy.isBoss
                                        ? 'Boss ${controller.bossPatternLabel(controller.currentBossPattern)} P${controller.currentBossPhase}'
                                        : controller.archetypeLabel(
                                            controller.enemy.archetype,
                                          ),
                                    style: TextStyle(
                                      fontSize: _rs(
                                        context,
                                        dense ? 8 : 9,
                                        min: 7,
                                      ),
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(height: _rs(context, 4, min: 3)),
                                _Enemy(
                                  isBoss: controller.enemy.isBoss,
                                  size: enemyPod,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (!ultraCompact)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      _rs(context, 8, min: 6),
                      _rs(context, 4, min: 2),
                      _rs(context, 8, min: 6),
                      _rs(context, 10, min: 6),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = dense || constraints.maxWidth < 560;

                        Widget skillCard(int index, {double? width}) {
                          final state = controller.skills[index];
                          final available = state.cooldownRemaining <= 0;
                          final autoEnabled = controller.isAutoSkillEnabled(
                            index,
                          );
                          final iconPath = switch (index) {
                            0 => 'assets/icons/skill_strike.svg',
                            1 => 'assets/icons/skill_whirl.svg',
                            _ => 'assets/icons/skill_focus.svg',
                          };

                          return SizedBox(
                            width: width,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: _rs(context, 4, min: 2),
                                vertical: _rs(context, 4, min: 2),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  _rs(context, 10, min: 7),
                                ),
                                onTap: () => controller.activateSkill(index),
                                onLongPress: () {
                                  final enabled = controller.toggleAutoSkill(
                                    index,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        enabled
                                            ? 'Auto-Skill aktiv für ${controller.text.tr(state.definition.labelKey)}'
                                            : 'Auto-Skill deaktiviert für ${controller.text.tr(state.definition.labelKey)}',
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  height: _rs(
                                    context,
                                    dense ? 48 : 54,
                                    min: 42,
                                    max: 72,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: available
                                          ? [context.cardBg, context.cardBgAlt]
                                          : [context.inputBg, context.inputBg],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      _rs(context, 10, min: 7),
                                    ),
                                    border: Border.all(
                                      color: autoEnabled
                                          ? const Color(0xFF5AAF58)
                                          : available
                                          ? context.borderGoldBright
                                          : context.borderHeavy,
                                      width: available ? 1.5 : 1.0,
                                    ),
                                    boxShadow: available
                                        ? [
                                            BoxShadow(
                                              color: context.goldAccent
                                                  .withValues(alpha: 0.10),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: _rs(context, 8, min: 5),
                                        top: _rs(context, 8, min: 5),
                                        child: _SvgIcon(
                                          path: iconPath,
                                          size: _rs(context, 18, min: 14),
                                        ),
                                      ),
                                      Positioned(
                                        left: _rs(context, 30, min: 24),
                                        top: _rs(context, 8, min: 5),
                                        right: _rs(context, 4, min: 3),
                                        child: Text(
                                          controller.text.tr(
                                            state.definition.labelKey,
                                          ),
                                          style: TextStyle(
                                            fontSize: _rs(
                                              context,
                                              dense ? 9 : 10,
                                              min: 8,
                                            ),
                                            color: context.textBright,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (autoEnabled)
                                        Positioned(
                                          right: _rs(context, 6, min: 4),
                                          bottom: _rs(context, 5, min: 3),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: _rs(
                                                context,
                                                5,
                                                min: 3,
                                              ),
                                              vertical: _rs(context, 2, min: 1),
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3E5A3B),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'AUTO',
                                              style: TextStyle(
                                                fontSize: _rs(
                                                  context,
                                                  8,
                                                  min: 7,
                                                ),
                                                color: const Color(0xFFDDE9DA),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (!available)
                                        Positioned.fill(
                                          child: Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    _rs(context, 10, min: 7),
                                                  ),
                                              color: context.overlayBg,
                                            ),
                                            child: Text(
                                              '${state.cooldownRemaining.toStringAsFixed(1)}s',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
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
                                spacing: _rs(context, 4, min: 2),
                                runSpacing: _rs(context, 4, min: 2),
                                children: List.generate(
                                  controller.skills.length,
                                  (index) => skillCard(
                                    index,
                                    width: (constraints.maxWidth - 12) / 2,
                                  ),
                                ),
                              );

                        return Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: const PageStorageKey<String>(
                              'combat-skills-tile',
                            ),
                            initiallyExpanded: false,
                            tilePadding: EdgeInsets.symmetric(
                              horizontal: _rs(context, 10, min: 6),
                              vertical: 0,
                            ),
                            childrenPadding: EdgeInsets.only(
                              bottom: _rs(context, 4, min: 2),
                            ),
                            collapsedIconColor: context.iconColor,
                            iconColor: context.iconColor,
                            title: Text(
                              'Fähigkeiten',
                              style: TextStyle(
                                fontSize: _rs(
                                  context,
                                  dense ? 11.5 : 12.5,
                                  min: 10,
                                ),
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              controller.autoSkillSlots.isEmpty
                                  ? 'Tippen zum Aufklappen'
                                  : '${controller.autoSkillSlots.length} Auto-Skill${controller.autoSkillSlots.length > 1 ? 's' : ''} aktiv',
                              style: TextStyle(
                                fontSize: _rs(
                                  context,
                                  dense ? 9.5 : 10.5,
                                  min: 8.5,
                                ),
                                color: controller.autoSkillSlots.isEmpty
                                    ? context.textSecondary
                                    : const Color(0xFF8BAF85),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _rs(context, 4, min: 2),
                                ),
                                child: skillStrip,
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _rs(context, 10, min: 6),
                                  vertical: _rs(context, 4, min: 2),
                                ),
                                child: Text(
                                  'Lang drücken für Auto-Aktivierung',
                                  style: TextStyle(
                                    fontSize: _rs(context, 9, min: 7.5),
                                    color: context.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RunesPanel extends StatefulWidget {
  const _RunesPanel({required this.controller});

  final GameController controller;

  @override
  State<_RunesPanel> createState() => _RunesPanelState();
}

class _RunesPanelState extends State<_RunesPanel> {
  GameController get controller => widget.controller;

  String _runeLabel(RuneType type) {
    return switch (type) {
      RuneType.fire => 'Feuerrune',
      RuneType.ice => 'Eisrune',
      RuneType.life => 'Lebensrune',
      RuneType.speed => 'Temporune',
      RuneType.gold => 'Goldrune',
    };
  }

  @override
  Widget build(BuildContext context) {
    final runes = controller.runeInventory;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (runes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Keine Runen gefunden',
                style: TextStyle(fontSize: 13, color: context.textSecondary),
              ),
            )
          else
            ...runes.asMap().entries.map((entry) {
              final i = entry.key;
              final rune = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.diamond_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_runeLabel(rune.type)}  T${rune.tier}  +${(rune.bonusValue * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _showEnchantDialog(context, i),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Anlegen',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Text(
            'Verzauberte Items:',
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 4),
          ...controller.equippedItems
              .where((item) => item.enchantments.isNotEmpty)
              .map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.cardBgAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      ...item.enchantments.asMap().entries.map((e) {
                        final rune = e.value;
                        return Row(
                          children: [
                            Text(
                              '  ${_runeLabel(rune.type)} T${rune.tier} +${(rune.bonusValue * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 11),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                controller.removeEnchantment(item.id, e.key);
                                setState(() {});
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                'Entfernen',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }

  void _showEnchantDialog(BuildContext context, int runeIndex) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Item verzaubern'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Wähle ein Item aus dem Inventar:'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView(
                    children: controller.inventory
                        .where((item) => item.enchantments.length < 2)
                        .map(
                          (item) => ListTile(
                            dense: true,
                            title: Text(
                              item.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            subtitle: Text(
                              '+${item.power} | ${item.enchantments.length}/2 Runen',
                            ),
                            onTap: () {
                              controller.enchantItem(item.id, runeIndex);
                              setState(() {});
                              Navigator.of(context).pop();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }
}

class _ForgePanel extends StatelessWidget {
  const _ForgePanel({required this.controller, this.dense = false});

  final GameController controller;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _rs(context, 12, min: 8),
        0,
        _rs(context, 12, min: 8),
        _rs(context, dense ? 6 : 8, min: 4),
      ),
      child: Container(
        padding: EdgeInsets.all(_rs(context, dense ? 8 : 10, min: 6)),
        decoration: BoxDecoration(
          color: context.cardBgAlt,
          borderRadius: BorderRadius.circular(_rs(context, 12, min: 8)),
          border: Border.all(color: context.cardBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = dense || constraints.maxWidth < 800;

            final craftCard = InkWell(
              borderRadius: BorderRadius.circular(_rs(context, 10, min: 7)),
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
                    SnackBar(
                      content: Text(
                        message.isEmpty ? 'Auto-Sell aktiv' : message,
                      ),
                    ),
                  );
                  return;
                }

                await _showCraftResultDialog(context, controller, item);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _rs(context, dense ? 8 : 10, min: 6),
                  vertical: _rs(context, dense ? 9 : 12, min: 6),
                ),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(_rs(context, 10, min: 7)),
                  border: Border.all(color: context.borderHeavy),
                ),
                child: Row(
                  children: [
                    _SvgIcon(
                      path: 'assets/icons/forge.svg',
                      size: _rs(context, dense ? 24 : 30, min: 18),
                    ),
                    SizedBox(width: _rs(context, 8, min: 5)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.tr('forge'),
                          style: TextStyle(
                            color: context.textBright,
                            fontWeight: FontWeight.bold,
                            fontSize: _rs(
                              context,
                              dense ? 12.5 : 14,
                              min: 10.5,
                            ),
                          ),
                        ),
                        Text(
                          '${text.tr('hammers')}: ${controller.hammers}',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: _rs(context, dense ? 11 : 12, min: 9.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );

            final upgradeCard = InkWell(
              borderRadius: BorderRadius.circular(_rs(context, 10, min: 7)),
              onTap: () {
                final success = controller.upgradeForgeChance();
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(text.tr('notEnoughGold'))),
                  );
                }
              },
              child: Container(
                padding: EdgeInsets.all(_rs(context, dense ? 8 : 10, min: 6)),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(_rs(context, 10, min: 7)),
                  border: Border.all(color: context.borderHeavy),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.tr('upgradeChance'),
                      style: TextStyle(
                        color: context.textBright,
                        fontWeight: FontWeight.bold,
                        fontSize: _rs(context, dense ? 11 : 12, min: 9.5),
                      ),
                    ),
                    SizedBox(height: _rs(context, 6, min: 4)),
                    Text(
                      '${text.tr('forgeLevel')}: ${controller.forgeLevel}',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: _rs(context, dense ? 10 : 11, min: 8.5),
                      ),
                    ),
                    Text(
                      'Bonus ${(controller.forgeBonusChance * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: _rs(context, dense ? 10 : 11, min: 8.5),
                      ),
                    ),
                    Text(
                      'Kosten ${controller.forgeUpgradeCost}',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: _rs(context, dense ? 10 : 11, min: 8.5),
                      ),
                    ),
                    SizedBox(height: _rs(context, 6, min: 4)),
                    FilledButton.tonal(
                      onPressed: () => _showPrestigeDialog(context, controller),
                      child: const Text('Prestige'),
                    ),
                    SizedBox(height: _rs(context, 4, min: 2)),
                    OutlinedButton(
                      onPressed: controller.cycleAutoSellMode,
                      child: Text('Auto-Sell: ${controller.autoSellLabel}'),
                    ),
                  ],
                ),
              ),
            );

            final bulkRow = Row(
              children: [
                for (final count in [5, 10, 50]) ...[
                  if (count > 5) SizedBox(width: _rs(context, 6, min: 4)),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: _rs(context, dense ? 4 : 6, min: 3),
                        ),
                        textStyle: TextStyle(
                          fontSize: _rs(context, dense ? 11 : 12, min: 10),
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(color: context.borderHeavy),
                        foregroundColor: context.textBright,
                      ),
                      onPressed: () {
                        final result = controller.craftMultiple(count);
                        if (result.crafted == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                controller.text.tr('notEnoughHammers'),
                              ),
                            ),
                          );
                          return;
                        }
                        final parts = <String>[
                          '${result.crafted}× geschmiedet',
                          if (result.addedToInventory > 0)
                            '${result.addedToInventory} im Inventar',
                          if (result.autoSold > 0)
                            '${result.autoSold} verkauft (+${result.goldFromAutoSell} Gold)',
                        ];
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(parts.join(' · '))),
                        );
                      },
                      child: Text('×$count'),
                    ),
                  ),
                ],
              ],
            );

            if (compact) {
              return Column(
                children: [
                  craftCard,
                  SizedBox(height: _rs(context, 6, min: 4)),
                  bulkRow,
                  SizedBox(height: _rs(context, 8, min: 5)),
                  upgradeCard,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      craftCard,
                      SizedBox(height: _rs(context, 6, min: 4)),
                      bulkRow,
                    ],
                  ),
                ),
                SizedBox(width: _rs(context, 8, min: 5)),
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
              : context.textPrimary
        : context.textPrimary;
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
                    child: Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                style: TextStyle(fontSize: 12, color: context.textPrimary),
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
                style: TextStyle(fontSize: 12, color: context.textPrimary),
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
                    const SnackBar(
                      content: Text(
                        'Item ist gesperrt und kann nicht verkauft werden.',
                      ),
                    ),
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

  Future<void> _showPrestigeDialog(
    BuildContext context,
    GameController controller,
  ) async {
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
              Text(
                'Dauerbonus Schaden: x${controller.prestigeDamageBonus.toStringAsFixed(2)}',
              ),
              Text(
                'Dauerbonus Schmiede: +${(controller.prestigeForgeBonus * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 10),
              Text(
                canPrestige
                    ? 'Fortschritt wird zurückgesetzt (Stage, Items, Gold), Boni bleiben.'
                    : 'Noch nicht verfügbar. Erreiche mindestens Kapitel 2.',
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

void _showStreakDialog(BuildContext context, GameController controller) {
  final text = controller.text;
  final streak = controller.loginStreakDays;
  final reward = controller.getStreakReward(streak);
  showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(text.tr('streakTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text.tr('streakCurrent').replaceAll('{days}', '$streak'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: List.generate(7, (i) {
                final dayNum = i + 1;
                final isCurrent = dayNum == ((streak - 1) % 7 + 1);
                final isPast = dayNum < ((streak - 1) % 7 + 1);
                return Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? const Color(0xFFD4A44C)
                        : isPast
                        ? const Color(0xFF3E5A3B)
                        : context.cardBgAlt,
                    border: Border.all(color: context.borderHeavy),
                  ),
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? const Color(0xFF1A1A1A)
                          : context.textPrimary,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (reward.isSpecial)
              Text(
                text.tr('streakSpecial'),
                style: const TextStyle(
                  color: Color(0xFFD4A44C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (reward.gold > 0) Text('+${reward.gold} Gold'),
            if (reward.hammers > 0) Text('+${reward.hammers} Hammer'),
            if (reward.shards > 0) Text('+${reward.shards} Scherben'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(text.tr('streakClaim')),
          ),
        ],
      );
    },
  );
}

Future<void> _showSkillTree(
  BuildContext context,
  GameController controller,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.sheetBg,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: _adaptiveSheetHeight(
            context,
            factor: 0.58,
            min: 320,
            max: 760,
          ),
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
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderHeavy),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(desc, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('Level $level | Kosten $cost Scherben'),
                      const SizedBox(height: 6),
                      FilledButton.tonal(
                        onPressed: onUpgrade,
                        child: const Text('Skill verbessern'),
                      ),
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
                  Text('Verfügbare Scherben: ${controller.forgeShards}'),
                  const SizedBox(height: 10),
                  skillCard(
                    title: 'Kraftschlag',
                    desc: 'Mehr Skill-Schaden und kürzerer Cooldown.',
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
                    desc: 'Deutlich stärkerer Burst und kürzerer Cooldown.',
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

class _BottomMenu extends StatefulWidget {
  const _BottomMenu({required this.controller, this.dense = false});

  final GameController controller;
  final bool dense;

  @override
  State<_BottomMenu> createState() => _BottomMenuState();
}

class _BottomMenuState extends State<_BottomMenu> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final dense = widget.dense;
    final text = controller.text;

    return Container(
      margin: EdgeInsets.fromLTRB(
        _rs(context, 8, min: 4),
        0,
        _rs(context, 8, min: 4),
        _rs(context, dense ? 6 : 8, min: 4),
      ),
      padding: EdgeInsets.all(_rs(context, dense ? 6 : 8, min: 4)),
      decoration: BoxDecoration(
        color: context.cardBgAlt,
        borderRadius: BorderRadius.circular(_rs(context, 14, min: 9)),
        border: Border.all(color: context.borderGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.goldAccent.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = dense || constraints.maxWidth < 620;
          final buttons = [
            _MenuButton(
              iconPath: 'assets/icons/forge.svg',
              label: text.tr('forge'),
              dense: dense,
              onTap: () => _showForgePanel(context, controller),
            ),
            _MenuButton(
              icon: Icons.local_drink_rounded,
              label: 'Tränke',
              dense: dense,
              onTap: () => _showFlaskPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_world.svg',
              label: text.tr('menuWorld'),
              dense: dense,
              onTap: () => _showWorldPanel(context, controller),
            ),
            if (ApiService.instance.isLoggedIn)
              _MenuButton(
                iconPath: 'assets/icons/menu_clan.svg',
                label: text.tr('menuClan'),
                dense: dense,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ClanScreen(text: text, controller: controller),
                  ),
                ),
              ),
            _MenuButton(
              iconPath: 'assets/icons/menu_shop.svg',
              label: text.tr('menuShop'),
              dense: dense,
              onTap: () => _showShopPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_quest.svg',
              label: text.tr('menuQuest'),
              dense: dense,
              onTap: () => _showQuestBoard(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/inventory.svg',
              label: text.tr('inventory'),
              dense: dense,
              onTap: () => _showInventory(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_dungeon.svg',
              label: text.tr('menuDungeon'),
              dense: dense,
              onTap: () => _showDungeonPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_pet.svg',
              label: text.tr('menuPet'),
              dense: dense,
              onTap: () => _showPetPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_expedition.svg',
              label: text.tr('menuExpedition'),
              dense: dense,
              onTap: () => _showExpeditionPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_recipes.svg',
              label: text.tr('menuRecipes'),
              dense: dense,
              onTap: () => _showRecipePanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_ascension.svg',
              label: text.tr('menuAscension'),
              dense: dense,
              onTap: () => _showAscensionPanel(context, controller),
            ),
            _MenuButton(
              iconPath: 'assets/icons/menu_online.svg',
              label: text.tr('socialTitle'),
              dense: dense,
              onTap: () => _showSocialPanel(context, controller),
            ),
          ];

          if (!compact) {
            return Row(
              children: buttons
                  .map((button) => Expanded(child: button))
                  .toList(growable: false),
            );
          }

          final pageCount = (buttons.length / 2).ceil();
          final btnHeight = _rs(context, dense ? 54 : 64, min: 48, max: 82);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: btnHeight,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  itemBuilder: (context, pageIndex) {
                    final start = pageIndex * 2;
                    final end = (start + 2).clamp(0, buttons.length);
                    final pageBtns = buttons.sublist(start, end);
                    return Row(
                      children: pageBtns
                          .map((b) => Expanded(child: b))
                          .toList(growable: false),
                    );
                  },
                ),
              ),
              SizedBox(height: _rs(context, 6, min: 4)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pageCount, (i) {
                  final active = i == _currentPage;
                  return GestureDetector(
                    onTap: () => _pageController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 14 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? context.textPrimary
                            : context.textPrimary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showForgePanel(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.52,
              min: 320,
              max: 760,
            ),
            child: ListView(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    controller.text.tr('forge'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) =>
                      _ForgePanel(controller: controller, dense: true),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    controller.text.tr('runesTitle'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => _RunesPanel(controller: controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFlaskPanel(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.56,
              min: 340,
              max: 760,
            ),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final compact = MediaQuery.sizeOf(context).width < 560;
                final cooldownText = controller.flaskCooldownRemaining > 0
                    ? 'Trank-CD ${controller.flaskCooldownRemaining.toStringAsFixed(1)}s'
                    : 'Trank bereit';

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text(
                      'Tränke',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cooldownText,
                      style: TextStyle(color: context.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CombatStance.values
                          .map(
                            (stance) => ChoiceChip(
                              label: Text(controller.combatStanceLabel(stance)),
                              selected: controller.combatStance == stance,
                              onSelected: (_) =>
                                  controller.setCombatStance(stance),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    if (compact)
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: controller.useHealingFlask,
                              child: Text(
                                'Heiltrank nutzen (${controller.healingFlasks})',
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                final ok = controller.buyFlask(
                                  FlaskType.healing,
                                );
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nicht genug Gold.'),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Heiltrank kaufen (${controller.healingFlaskCost}G)',
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: controller.useBerserkFlask,
                              child: Text(
                                'Berserk nutzen (${controller.berserkFlasks})',
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                final ok = controller.buyFlask(
                                  FlaskType.berserk,
                                );
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nicht genug Gold.'),
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Berserk kaufen (${controller.berserkFlaskCost}G)',
                              ),
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
                                  child: Text(
                                    'Heiltrank (${controller.healingFlasks})',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    final ok = controller.buyFlask(
                                      FlaskType.healing,
                                    );
                                    if (!ok) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Nicht genug Gold.'),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Kaufen ${controller.healingFlaskCost}G',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: controller.useBerserkFlask,
                                  child: Text(
                                    'Berserk (${controller.berserkFlasks})',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    final ok = controller.buyFlask(
                                      FlaskType.berserk,
                                    );
                                    if (!ok) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Nicht genug Gold.'),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Kaufen ${controller.berserkFlaskCost}G',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Future<void> _showQuestBoard(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.82,
              min: 480,
              max: 900,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final quests = controller.questBoard;
                final dailies = controller.dailyChallenges;

                final now = DateTime.now();
                final midnight = DateTime(now.year, now.month, now.day + 1);
                final hoursLeft = midnight.difference(now).inHours;
                final minutesLeft =
                    midnight.difference(now).inMinutes % 60;
                final resetLabel =
                    'Reset in ${hoursLeft}h ${minutesLeft.toString().padLeft(2, '0')}m';

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;

                    Widget questCard(
                      QuestStateView quest, {
                      double? width,
                      required VoidCallback? onClaim,
                    }) {
                      final progressRatio = (quest.progress / quest.target)
                          .clamp(0.0, 1.0);
                      final rewardText =
                          '+${quest.rewardGold} Gold | +${quest.rewardHammers} Hämmer'
                          '${quest.rewardShards > 0 ? ' | +${quest.rewardShards} Scherben' : ''}';
                      return Container(
                        width: width,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.borderHeavy),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quest.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              quest.description,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                minHeight: 6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.textPrimary,
                                ),
                                backgroundColor: context.borderHeavy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('${quest.progress}/${quest.target}'),
                            const SizedBox(height: 4),
                            Text(
                              rewardText,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            if (quest.claimed)
                              const Text(
                                'Belohnung geholt',
                                style: TextStyle(color: Color(0xFF9BC89E)),
                              )
                            else
                              FilledButton.tonal(
                                onPressed: quest.canClaim ? onClaim : null,
                                child: const Text('Belohnung holen'),
                              ),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        // ── Tägliche Herausforderungen ──────────────────
                        Row(
                          children: [
                            const Text(
                              'Tägliche Herausforderungen',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              resetLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Täglich zurücksetzende Aufgaben für Bonusbelohnungen.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        if (!wide)
                          ...dailies.map(
                            (c) => questCard(
                              c,
                              onClaim: () {
                                controller.claimDailyChallenge(c.type);
                                setModalState(() {});
                              },
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 0,
                            children: dailies
                                .map(
                                  (c) => questCard(
                                    c,
                                    width:
                                        (constraints.maxWidth - 10) / 2,
                                    onClaim: () {
                                      controller.claimDailyChallenge(
                                        c.type,
                                      );
                                      setModalState(() {});
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          ),

                        // ── Quest Board ─────────────────────────────────
                        const Divider(height: 24),
                        const Text(
                          'Quest Board',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Schliesse Quests ab und hole dir Belohnungen.',
                        ),
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
                        if (!wide)
                          ...quests.map(
                            (quest) => questCard(
                              quest,
                              onClaim: () {
                                controller.claimQuest(quest.type);
                                setModalState(() {});
                              },
                            ),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 0,
                            children: quests
                                .map(
                                  (quest) => questCard(
                                    quest,
                                    width:
                                        (constraints.maxWidth - 10) / 2,
                                    onClaim: () {
                                      controller.claimQuest(quest.type);
                                      setModalState(() {});
                                    },
                                  ),
                                )
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

  // ignore: unused_element
  Future<void> _showTalentTree(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.72,
              min: 420,
              max: 920,
            ),
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
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.borderHeavy),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(desc, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('Level $level | Kosten $cost Scherben'),
                        const SizedBox(height: 6),
                        FilledButton.tonal(
                          onPressed: onUpgrade,
                          child: const Text('Upgrade'),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 900;

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
                          'Talentzweig',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Verfügbare Scherben: ${controller.forgeShards}'),
                        const SizedBox(height: 12),
                        const Text(
                          'Talentzweig (Scherben)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (!wide)
                          ...talentCards
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 0,
                            children: talentCards
                                .map(
                                  (card) => SizedBox(
                                    width: (constraints.maxWidth - 10) / 2,
                                    child: card,
                                  ),
                                )
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

  Future<void> _showInventory(
    BuildContext context,
    GameController controller,
  ) async {
    final text = controller.text;
    ItemSet? setFilter;
    ItemSlot? slotFilter;
    ItemTier? tierFilter;
    InventorySortMode sortMode = InventorySortMode.powerDesc;
    SmartEquipMode smartEquipMode = SmartEquipMode.purePower;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.72,
              min: 420,
              max: 940,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                void refresh() {
                  setModalState(() {});
                }

                final filteredInventory = controller.inventory.where((item) {
                  final matchesSet =
                      setFilter == null || item.setId == setFilter;
                  final matchesSlot =
                      slotFilter == null || item.slot == slotFilter;
                  final matchesTier =
                      tierFilter == null || item.tier == tierFilter;
                  return matchesSet && matchesSlot && matchesTier;
                }).toList();

                filteredInventory.sort((a, b) {
                  return switch (sortMode) {
                    InventorySortMode.powerDesc => b.power.compareTo(a.power),
                    InventorySortMode.tierDesc => b.tier.index.compareTo(
                      a.tier.index,
                    ),
                    InventorySortMode.sellValueDesc => b.sellValue.compareTo(
                      a.sellValue,
                    ),
                    InventorySortMode.nameAsc => a.name.toLowerCase().compareTo(
                      b.name.toLowerCase(),
                    ),
                  };
                });

                final compact = MediaQuery.sizeOf(context).width < 760;

                return LayoutBuilder(
                  builder: (context, sheetConstraints) {
                    final itemListHeight = (sheetConstraints.maxHeight * 0.42)
                        .clamp(220.0, 520.0)
                        .toDouble();

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: sheetConstraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  _SvgIcon(
                                    path: 'assets/icons/inventory.svg',
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    text.tr('inventory'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                  final hasPreset = controller.hasLoadoutPreset(
                                    slot,
                                  );
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
                                                    ? 'Loadout laden oder aktuellen Stand überschreiben?'
                                                    : 'Diesen Slot als aktuelles Loadout speichern?',
                                              ),
                                              actions: [
                                                if (hasPreset)
                                                  TextButton(
                                                    onPressed: () {
                                                      final changes = controller
                                                          .applyLoadout(slot);
                                                      Navigator.of(
                                                        dialogContext,
                                                      ).pop();
                                                      final msg = changes > 0
                                                          ? 'Loadout $slot geladen ($changes Aenderungen).'
                                                          : 'Loadout $slot ist bereits aktiv oder teilweise nicht verfügbar.';
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(msg),
                                                        ),
                                                      );
                                                      refresh();
                                                    },
                                                    child: const Text('Laden'),
                                                  ),
                                                FilledButton.tonal(
                                                  onPressed: () {
                                                    final saved = controller
                                                        .saveCurrentLoadout(
                                                          slot,
                                                        );
                                                    Navigator.of(
                                                      dialogContext,
                                                    ).pop();
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Loadout $slot gespeichert ($saved Slots).',
                                                        ),
                                                      ),
                                                    );
                                                    refresh();
                                                  },
                                                  child: const Text(
                                                    'Speichern',
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      child: Text(
                                        hasPreset ? 'L$slot (S)' : 'L$slot',
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final cols = constraints.maxWidth < 500
                                      ? 1
                                      : constraints.maxWidth < 860
                                      ? 2
                                      : 3;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cols,
                                          childAspectRatio: cols == 1
                                              ? 3.6
                                              : 2.5,
                                        ),
                                    itemCount: ItemSlot.values.length,
                                    itemBuilder: (context, index) {
                                      final slot = ItemSlot.values[index];
                                      final equipped = controller
                                          .equippedInSlot(slot);
                                      final best = controller.bestItemForSlot(
                                        slot,
                                      );
                                      final upgradeDelta = controller
                                          .bestUpgradeDelta(slot);
                                      return Container(
                                        margin: const EdgeInsets.all(6),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: context.cardBg,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: context.borderHeavy,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              controller.slotLabel(slot),
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              equipped?.name ?? '-',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: context.textPrimary,
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
                                                    : context.textTertiary,
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
                                      const Text(
                                        'Filter',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${filteredInventory.length}/${controller.inventory.length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.textPrimary,
                                        ),
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
                                              final changed = controller
                                                  .smartEquipBestItems(
                                                    preferSetSynergy:
                                                        smartEquipMode ==
                                                        SmartEquipMode
                                                            .setSynergy,
                                                  );
                                              final msg = changed > 0
                                                  ? 'Smart Equip: $changed Slots aktualisiert.'
                                                  : 'Smart Equip: Keine bessere Ausrüstung gefunden.';
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Keine Items im aktuellen Filter.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              final preview = controller
                                                  .getBulkSellPreview(
                                                    filteredInventory.map(
                                                      (item) => item.id,
                                                    ),
                                                  );
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (dialogContext) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                      'Massenverkauf bestaetigen',
                                                    ),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Im Filter: ${preview.candidateCount} Items',
                                                        ),
                                                        Text(
                                                          'Verkaufbar: ${preview.sellableCount}',
                                                        ),
                                                        Text(
                                                          'Geschützt: ${preview.protectedCount}',
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          'Erwartetes Gold: +${preview.estimatedGold}',
                                                        ),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'Abbrechen',
                                                        ),
                                                      ),
                                                      FilledButton.tonal(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(true),
                                                        child: const Text(
                                                          'Verkaufen',
                                                        ),
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

                                              final result = controller
                                                  .sellItemsByIds(
                                                    filteredInventory.map(
                                                      (item) => item.id,
                                                    ),
                                                  );
                                              final msg = result.soldCount > 0
                                                  ? 'Massenverkauf: ${result.soldCount} Items für +${result.earnedGold} Gold.'
                                                  : 'Massenverkauf: Keine verkaufbaren Items (gesperrt/ausgerüstet).';
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                              final changed = controller
                                                  .smartEquipBestItems(
                                                    preferSetSynergy:
                                                        smartEquipMode ==
                                                        SmartEquipMode
                                                            .setSynergy,
                                                  );
                                              final msg = changed > 0
                                                  ? 'Smart Equip: $changed Slots aktualisiert.'
                                                  : 'Smart Equip: Keine bessere Ausrüstung gefunden.';
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Keine Items im aktuellen Filter.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              final preview = controller
                                                  .getBulkSellPreview(
                                                    filteredInventory.map(
                                                      (item) => item.id,
                                                    ),
                                                  );
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (dialogContext) {
                                                  return AlertDialog(
                                                    title: const Text(
                                                      'Massenverkauf bestaetigen',
                                                    ),
                                                    content: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          'Im Filter: ${preview.candidateCount} Items',
                                                        ),
                                                        Text(
                                                          'Verkaufbar: ${preview.sellableCount}',
                                                        ),
                                                        Text(
                                                          'Geschützt: ${preview.protectedCount}',
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          'Erwartetes Gold: +${preview.estimatedGold}',
                                                        ),
                                                      ],
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(false),
                                                        child: const Text(
                                                          'Abbrechen',
                                                        ),
                                                      ),
                                                      FilledButton.tonal(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              dialogContext,
                                                            ).pop(true),
                                                        child: const Text(
                                                          'Verkaufen',
                                                        ),
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

                                              final result = controller
                                                  .sellItemsByIds(
                                                    filteredInventory.map(
                                                      (item) => item.id,
                                                    ),
                                                  );
                                              final msg = result.soldCount > 0
                                                  ? 'Massenverkauf: ${result.soldCount} Items für +${result.earnedGold} Gold.'
                                                  : 'Massenverkauf: Keine verkaufbaren Items (gesperrt/ausgerüstet).';
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                          dropdownColor: context.cardBg,
                                          items: [
                                            const DropdownMenuItem<ItemSet?>(
                                              value: null,
                                              child: Text('Alle Sets'),
                                            ),
                                            ...ItemSet.values.map(
                                              (setId) =>
                                                  DropdownMenuItem<ItemSet?>(
                                                    value: setId,
                                                    child: Text(
                                                      controller.setLabel(
                                                        setId,
                                                      ),
                                                    ),
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
                                          dropdownColor: context.cardBg,
                                          items: [
                                            const DropdownMenuItem<ItemSlot?>(
                                              value: null,
                                              child: Text('Alle Slots'),
                                            ),
                                            ...ItemSlot.values.map(
                                              (slot) =>
                                                  DropdownMenuItem<ItemSlot?>(
                                                    value: slot,
                                                    child: Text(
                                                      controller.slotLabel(
                                                        slot,
                                                      ),
                                                    ),
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
                                          dropdownColor: context.cardBg,
                                          items: [
                                            const DropdownMenuItem<ItemTier?>(
                                              value: null,
                                              child: Text('Alle Tiers'),
                                            ),
                                            ...ItemTier.values.map(
                                              (tier) =>
                                                  DropdownMenuItem<ItemTier?>(
                                                    value: tier,
                                                    child: Text(
                                                      controller.tierLabel(
                                                        tier,
                                                      ),
                                                    ),
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
                                            dropdownColor: context.cardBg,
                                            items: [
                                              const DropdownMenuItem<ItemSet?>(
                                                value: null,
                                                child: Text('Alle Sets'),
                                              ),
                                              ...ItemSet.values.map(
                                                (setId) =>
                                                    DropdownMenuItem<ItemSet?>(
                                                      value: setId,
                                                      child: Text(
                                                        controller.setLabel(
                                                          setId,
                                                        ),
                                                      ),
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
                                            dropdownColor: context.cardBg,
                                            items: [
                                              const DropdownMenuItem<ItemSlot?>(
                                                value: null,
                                                child: Text('Alle Slots'),
                                              ),
                                              ...ItemSlot.values.map(
                                                (slot) =>
                                                    DropdownMenuItem<ItemSlot?>(
                                                      value: slot,
                                                      child: Text(
                                                        controller.slotLabel(
                                                          slot,
                                                        ),
                                                      ),
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
                                            dropdownColor: context.cardBg,
                                            items: [
                                              const DropdownMenuItem<ItemTier?>(
                                                value: null,
                                                child: Text('Alle Tiers'),
                                              ),
                                              ...ItemTier.values.map(
                                                (tier) =>
                                                    DropdownMenuItem<ItemTier?>(
                                                      value: tier,
                                                      child: Text(
                                                        controller.tierLabel(
                                                          tier,
                                                        ),
                                                      ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Smart:',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        DropdownButton<SmartEquipMode>(
                                          value: smartEquipMode,
                                          isExpanded: true,
                                          dropdownColor: context.cardBg,
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
                                        const Text(
                                          'Sortierung:',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        DropdownButton<InventorySortMode>(
                                          value: sortMode,
                                          isExpanded: true,
                                          dropdownColor: context.cardBg,
                                          items: const [
                                            DropdownMenuItem(
                                              value:
                                                  InventorySortMode.powerDesc,
                                              child: Text('Power absteigend'),
                                            ),
                                            DropdownMenuItem(
                                              value: InventorySortMode.tierDesc,
                                              child: Text('Tier absteigend'),
                                            ),
                                            DropdownMenuItem(
                                              value: InventorySortMode
                                                  .sellValueDesc,
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
                                            const Text(
                                              'Smart:',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child:
                                                  DropdownButton<
                                                    SmartEquipMode
                                                  >(
                                                    value: smartEquipMode,
                                                    isExpanded: true,
                                                    dropdownColor:
                                                        context.cardBg,
                                                    items: const [
                                                      DropdownMenuItem(
                                                        value: SmartEquipMode
                                                            .purePower,
                                                        child: Text(
                                                          'Power-Fokus',
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: SmartEquipMode
                                                            .setSynergy,
                                                        child: Text(
                                                          'Set-Synergie',
                                                        ),
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
                                            const Text(
                                              'Sortierung:',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child:
                                                  DropdownButton<
                                                    InventorySortMode
                                                  >(
                                                    value: sortMode,
                                                    isExpanded: true,
                                                    dropdownColor:
                                                        context.cardBg,
                                                    items: const [
                                                      DropdownMenuItem(
                                                        value: InventorySortMode
                                                            .powerDesc,
                                                        child: Text(
                                                          'Power absteigend',
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: InventorySortMode
                                                            .tierDesc,
                                                        child: Text(
                                                          'Tier absteigend',
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: InventorySortMode
                                                            .sellValueDesc,
                                                        child: Text(
                                                          'Wert absteigend',
                                                        ),
                                                      ),
                                                      DropdownMenuItem(
                                                        value: InventorySortMode
                                                            .nameAsc,
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
                                          title: const Text(
                                            'Auto-Lock',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          value: controller.autoLockEnabled,
                                          onChanged: (value) {
                                            controller.setAutoLock(
                                              enabled: value,
                                              fromTier:
                                                  controller.autoLockFromTier,
                                            );
                                            setModalState(() {});
                                          },
                                        ),
                                        DropdownButton<ItemTier>(
                                          value: controller.autoLockFromTier,
                                          isExpanded: true,
                                          dropdownColor: context.cardBg,
                                          items: ItemTier.values
                                              .map(
                                                (
                                                  tier,
                                                ) => DropdownMenuItem<ItemTier>(
                                                  value: tier,
                                                  child: Text(
                                                    'Lock ab ${controller.tierLabel(tier)}',
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }
                                            controller.setAutoLock(
                                              enabled:
                                                  controller.autoLockEnabled,
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
                                            title: const Text(
                                              'Auto-Lock',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            value: controller.autoLockEnabled,
                                            onChanged: (value) {
                                              controller.setAutoLock(
                                                enabled: value,
                                                fromTier:
                                                    controller.autoLockFromTier,
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
                                            dropdownColor: context.cardBg,
                                            items: ItemTier.values
                                                .map(
                                                  (
                                                    tier,
                                                  ) => DropdownMenuItem<ItemTier>(
                                                    value: tier,
                                                    child: Text(
                                                      'Lock ab ${controller.tierLabel(tier)}',
                                                    ),
                                                  ),
                                                )
                                                .toList(growable: false),
                                            onChanged: (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              controller.setAutoLock(
                                                enabled:
                                                    controller.autoLockEnabled,
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
                                        final changed = controller
                                            .applyAutoLockToInventory();
                                        final msg = changed > 0
                                            ? 'Auto-Lock auf Bestand angewendet: $changed Items geaendert.'
                                            : 'Keine vorhandenen Items mussten angepasst werden.';
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text(msg)),
                                        );
                                        refresh();
                                      },
                                      child: const Text(
                                        'Auto-Lock auf Bestand anwenden',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (controller.completedSetCount > 0)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  4,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Komplette Sets: ${controller.completedSetCount}/${ItemSet.values.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFBFD8BF),
                                    ),
                                  ),
                                ),
                              ),
                            if (controller.activeSetBonuses.isNotEmpty)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  4,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: context.cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: context.borderHeavy,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Aktive Set-Boni',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...controller.activeSetBonuses.map(
                                      (bonus) => Text(
                                        bonus,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(
                              height: itemListHeight,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final grid = constraints.maxWidth >= 920;

                                  Widget card(GameItem item) {
                                    final equipped = controller.isEquipped(
                                      item,
                                    );
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: context.cardBg,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: context.borderHeavy,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              _SvgIcon(
                                                path: item.iconPath,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: context.textBright,
                                                  ),
                                                ),
                                              ),
                                              if (equipped)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: context.divider,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    text.tr('equipped'),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${controller.tierLabel(item.tier)} | ${controller.setLabel(item.setId)} | +${item.power} | ${controller.slotLabel(item.slot)}',
                                                  style: TextStyle(
                                                    color: context.textPrimary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              if (!equipped) ...[
                                                const SizedBox(width: 6),
                                                Builder(
                                                  builder: (ctx) {
                                                    final diff = controller
                                                        .calculateEquipDiff(
                                                          item,
                                                        );
                                                    final color = diff.delta > 0
                                                        ? const Color(
                                                            0xFF8FD39E,
                                                          )
                                                        : diff.delta < 0
                                                        ? const Color(
                                                            0xFFE39A9A,
                                                          )
                                                        : context.textTertiary;
                                                    final label = diff.delta > 0
                                                        ? '+${diff.delta}'
                                                        : diff.delta < 0
                                                        ? '${diff.delta}'
                                                        : '±0';
                                                    return Text(
                                                      label,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: color,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              IconButton(
                                                onPressed: () {
                                                  controller.toggleItemLock(
                                                    item.id,
                                                  );
                                                  refresh();
                                                },
                                                icon: Icon(
                                                  item.isLocked
                                                      ? Icons.lock
                                                      : Icons.lock_open,
                                                  size: 18,
                                                  color: item.isLocked
                                                      ? const Color(0xFFE2D18D)
                                                      : const Color(0xFFA8A8A8),
                                                ),
                                                tooltip: item.isLocked
                                                    ? 'Entsperren'
                                                    : 'Sperren',
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  if (equipped) {
                                                    controller.unequipSlot(
                                                      item.slot,
                                                    );
                                                  } else {
                                                    controller.equipItem(item);
                                                  }
                                                  refresh();
                                                },
                                                child: Text(
                                                  equipped
                                                      ? text.tr('unequip')
                                                      : text.tr('equip'),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              TextButton(
                                                onPressed: () {
                                                  final sold = controller
                                                      .sellItem(item);
                                                  if (!sold) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Item ist gesperrt und kann nicht verkauft werden.',
                                                        ),
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
                                      itemBuilder: (context, index) =>
                                          card(filteredInventory[index]),
                                    );
                                  }

                                  return GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 2.5,
                                        ),
                                    itemCount: filteredInventory.length,
                                    itemBuilder: (context, index) =>
                                        card(filteredInventory[index]),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _showWorldPanel(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.72,
              min: 420,
              max: 940,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weltkarte',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aktuell: Kapitel ${controller.chapter} - Stage ${controller.stage}',
                      ),
                      Text('Bosse besiegt: ${controller.bossDefeats}'),
                      Text('Tode: ${controller.deaths}'),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonal(
                          onPressed: () =>
                              _showAchievementsPanel(context, controller),
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
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.borderHeavy),
                        ),
                        child: Text(
                          controller.chapterSetHuntHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textPrimary,
                          ),
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
                              final reached =
                                  controller.chapter >= milestoneChapter;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: reached
                                      ? const Color(0xFF2D352D)
                                      : context.cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: reached
                                        ? const Color(0xFF5E7A5E)
                                        : context.borderHeavy,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      reached
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: reached
                                          ? const Color(0xFF9AC39A)
                                          : const Color(0xFF8D8D8D),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Kapitel $milestoneChapter Boss besiegen',
                                    ),
                                  ],
                                ),
                              );
                            }

                            Widget setCard(
                              SetCollectionView entry, {
                              double? width,
                            }) {
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
                                      : context.cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: context.borderHeavy,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${controller.setLabel(entry.setId)} ${entry.ownedCount}/${entry.totalCount}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (entry.rewardClaimed)
                                      const Text(
                                        'Belohnung eingesammelt',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9AC39A),
                                        ),
                                      )
                                    else if (entry.rewardClaimable)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: FilledButton.tonal(
                                          onPressed: () {
                                            final ok = controller
                                                .claimSetCompletionReward(
                                                  entry.setId,
                                                );
                                            if (ok) {
                                              setModalState(() {});
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Set-Belohnung eingesammelt.',
                                                  ),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Set-Belohnung kann noch nicht eingesammelt werden.',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                          child: const Text(
                                            'Belohnung einsammeln',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }

                            return ListView(
                              children: [
                                if (!wide)
                                  ...List.generate(
                                    8,
                                    (index) => milestoneCard(index + 1),
                                  )
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
                                const Text(
                                  'Set-Sammlung',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                if (!wide)
                                  ...controller.setCollection.map(
                                    (entry) => setCard(entry),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 0,
                                    children: controller.setCollection
                                        .map(
                                          (entry) => setCard(
                                            entry,
                                            width:
                                                (constraints.maxWidth - 8) / 2,
                                          ),
                                        )
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

  Future<void> _showAchievementsPanel(
    BuildContext context,
    GameController controller,
  ) async {
    AchievementFilterMode filterMode = AchievementFilterMode.all;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.78,
              min: 460,
              max: 960,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final entries = controller.achievements;
                final claimable = entries
                    .where((entry) => entry.canClaim)
                    .length;
                final unclaimed = entries
                    .where((entry) => !entry.claimed)
                    .length;
                final total = entries.length;
                final claimed = entries.where((entry) => entry.claimed).length;
                final shownEntries = switch (filterMode) {
                  AchievementFilterMode.all => entries,
                  AchievementFilterMode.claimable =>
                    entries
                        .where((entry) => entry.canClaim)
                        .toList(growable: false),
                  AchievementFilterMode.unclaimed =>
                    entries
                        .where((entry) => !entry.claimed)
                        .toList(growable: false),
                  AchievementFilterMode.claimed =>
                    entries
                        .where((entry) => entry.claimed)
                        .toList(growable: false),
                };

                Widget achievementCard(AchievementView entry) {
                  final def = entry.definition;
                  final progressRatio = (entry.progress / def.target).clamp(
                    0.0,
                    1.0,
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: entry.claimed
                          ? const Color(0xFF2D352D)
                          : context.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.borderHeavy),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          def.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: progressRatio,
                            backgroundColor: const Color(0xFF202020),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              entry.canClaim
                                  ? const Color(0xFF9AC39A)
                                  : const Color(0xFF7E8D9B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fortschritt ${entry.progress}/${def.target} | '
                          '+${def.rewardGold} Gold, +${def.rewardShards} Scherben',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (entry.claimed)
                          const Text(
                            'Bereits eingesammelt',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9AC39A),
                            ),
                          )
                        else
                          FilledButton.tonal(
                            onPressed: entry.canClaim
                                ? () {
                                    final ok = controller.claimAchievement(
                                      def.id,
                                    );
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Freigeschaltet: $claimed/$total | Offen: $unclaimed | Einloesbar: $claimable',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: controller.claimableAchievementCount > 0
                                ? () {
                                    final count = controller
                                        .claimAllAchievements();
                                    if (count > 0) {
                                      setModalState(() {});
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '$count Belohnungen eingesammelt.',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('Alle verfügbaren einsammeln'),
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
                            selected:
                                filterMode == AchievementFilterMode.claimable,
                            onSelected: (_) {
                              setModalState(() {
                                filterMode = AchievementFilterMode.claimable;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text('Offen ($unclaimed)'),
                            selected:
                                filterMode == AchievementFilterMode.unclaimed,
                            onSelected: (_) {
                              setModalState(() {
                                filterMode = AchievementFilterMode.unclaimed;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: Text('Erledigt ($claimed)'),
                            selected:
                                filterMode == AchievementFilterMode.claimed,
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
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 1.9,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemCount: shownEntries.length,
                              itemBuilder: (context, index) =>
                                  achievementCard(shownEntries[index]),
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

  Future<void> _showShopPanel(
    BuildContext context,
    GameController controller,
  ) async {
    ShopPanelTab selectedTab = ShopPanelTab.all;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.58,
              min: 320,
              max: 760,
            ),
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
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.borderHeavy),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                controller.shopOfferTitle(offer),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (offer.isDaily)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B3D2C),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'DAILY -${offer.discountPercent}%',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFFFD6A6),
                                  ),
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
                        Text(
                          'Bestand ${offer.stock} | Kosten ${offer.cost} Gold',
                        ),
                        const SizedBox(height: 6),
                        FilledButton.tonal(
                          onPressed: canBuy
                              ? () {
                                  final ok = controller.buyShopOffer(offer.id);
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Kauf fehlgeschlagen.'),
                                      ),
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
                        final timer = formatDuration(
                          controller.shopRefreshRemaining,
                        );
                        final offers = controller.allShopOffers
                            .where((offer) {
                              return switch (selectedTab) {
                                ShopPanelTab.all => true,
                                ShopPanelTab.daily => offer.isDaily,
                                ShopPanelTab.upgrades =>
                                  offer.kind == ShopOfferKind.speedUpgrade ||
                                      offer.kind ==
                                          ShopOfferKind.hammerUpgrade ||
                                      offer.kind ==
                                          ShopOfferKind.recoveryUpgrade,
                                ShopPanelTab.resources =>
                                  offer.kind == ShopOfferKind.hammerPack ||
                                      offer.kind == ShopOfferKind.shardCache,
                                ShopPanelTab.combat =>
                                  offer.kind == ShopOfferKind.healingFlask ||
                                      offer.kind == ShopOfferKind.berserkFlask,
                              };
                            })
                            .toList(growable: false);

                        return ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            const Text(
                              'Marktplatz',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gold: ${controller.gold} | Scherben: ${controller.forgeShards}',
                            ),
                            Text(
                              'Flasks: Heil ${controller.healingFlasks} | Berserk ${controller.berserkFlasks}',
                            ),
                            Text(
                              'Tagesangebote: ${controller.dailyShopOffers.where((entry) => entry.stock > 0).length} aktiv',
                            ),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Zu wenig Gold für Reroll.',
                                          ),
                                        ),
                                      );
                                    }
                                    setModalState(() {});
                                  },
                                  child: Text(
                                    'Shop neu rollen (${controller.shopRefreshCost} Gold)',
                                  ),
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
                                  onSelected: (_) => setModalState(
                                    () => selectedTab = ShopPanelTab.all,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Daily'),
                                  selected: selectedTab == ShopPanelTab.daily,
                                  onSelected: (_) => setModalState(
                                    () => selectedTab = ShopPanelTab.daily,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Upgrades'),
                                  selected:
                                      selectedTab == ShopPanelTab.upgrades,
                                  onSelected: (_) => setModalState(
                                    () => selectedTab = ShopPanelTab.upgrades,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Ressourcen'),
                                  selected:
                                      selectedTab == ShopPanelTab.resources,
                                  onSelected: (_) => setModalState(
                                    () => selectedTab = ShopPanelTab.resources,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Kampf'),
                                  selected: selectedTab == ShopPanelTab.combat,
                                  onSelected: (_) => setModalState(
                                    () => selectedTab = ShopPanelTab.combat,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Angebote',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (offers.isEmpty)
                              Text(
                                'Keine Angebote in dieser Kategorie.',
                                style: TextStyle(color: context.textPrimary),
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

  Future<void> _showDungeonPanel(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(
              context,
              factor: 0.82,
              min: 400,
              max: 900,
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final dc = controller.dungeonController;
                final text = controller.text;

                void refresh() => setModalState(() {});

                if (dc.pendingDungeonReward != null) {
                  final reward = dc.pendingDungeonReward!;
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.stars,
                          color: Color(0xFFFFD700),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          text.tr('dungeonComplete'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '+${reward.gold} Gold  |  +${reward.hammers} Haemmer  |  +${reward.shards} Scherben',
                        ),
                        const SizedBox(height: 8),
                        Text('${reward.items.length} Item(s) gefunden'),
                        const SizedBox(height: 20),
                        FilledButton.tonal(
                          onPressed: () {
                            controller.claimDungeonReward();
                            Navigator.of(context).pop();
                          },
                          child: Text(text.tr('dungeonClaimReward')),
                        ),
                      ],
                    ),
                  );
                }

                final run = dc.activeDungeonRun;
                if (run != null && run.isActive) {
                  final currentStage = dc.currentStage!;
                  final bossHp = dc.getBossHp(run.difficulty, run.currentStage);

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${text.tr('dungeonTitle')} — ${_difficultyLabel(text, run.difficulty)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final stageNum = i + 1;
                          final isDone = stageNum < run.currentStage;
                          final isCurrent = stageNum == run.currentStage;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 8,
                              decoration: BoxDecoration(
                                color: isDone
                                    ? const Color(0xFF4CAF50)
                                    : isCurrent
                                    ? const Color(0xFFFF9800)
                                    : context.cardBorder,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${text.tr('dungeonStage')} ${run.currentStage}/5 — ${currentStage.bossName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${text.tr("dungeonBoss")}: ${currentStage.bossName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('HP: ${bossHp.round()}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () {
                                controller.advanceDungeonStage();
                                refresh();
                              },
                              child: Text(
                                'Boss besiegen (${text.tr("dungeonStage")} ${run.currentStage})',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          controller.defeatDungeonStage();
                          refresh();
                        },
                        child: Text(text.tr('dungeonAbandon')),
                      ),
                    ],
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      text.tr('dungeonTitle'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${text.tr("dungeonEnergy")}: ${dc.dungeonEnergy}/${dc.dungeonMaxEnergy}',
                      style: TextStyle(color: context.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    for (final difficulty in DungeonDifficulty.values) ...[
                      _DifficultyCard(
                        difficulty: difficulty,
                        controller: controller,
                        onStart: () {
                          final ok = controller.startDungeon(difficulty);
                          if (!ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  text.tr('dungeonNotEnoughEnergy'),
                                ),
                              ),
                            );
                          }
                          refresh();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    const Text(
                      'Stage 1-5 jeweils mit eigenem Boss. Stage 5: Guaranteed Legendary-Drop!',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB0B0B0)),
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

  String _difficultyLabel(AppText text, DungeonDifficulty d) {
    return switch (d) {
      DungeonDifficulty.normal => text.tr('dungeonDiffNormal'),
      DungeonDifficulty.hard => text.tr('dungeonDiffHard'),
      DungeonDifficulty.nightmare => text.tr('dungeonDiffNightmare'),
    };
  }

  Future<void> _showExpeditionPanel(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(ctx, factor: 0.85, min: 450, max: 900),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final text = controller.text;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      text.tr('expeditionTitle'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sende Helden auf Expeditionen für Belohnungen.',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (
                      int i = 0;
                      i < GameController.expeditionSlotCount;
                      i++
                    ) ...[
                      _ExpeditionSlotCard(
                        slotIndex: i,
                        controller: controller,
                        onRefresh: () => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAscensionPanel(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(ctx, factor: 0.9, min: 500, max: 900),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final text = controller.text;

                return DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text.tr('ascensionTitle'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${text.tr("ascensionPoints")}: ${controller.ascensionPoints}',
                                    style: TextStyle(
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        tabs: [
                          Tab(text: text.tr('ascensionPathWarrior')),
                          Tab(text: text.tr('ascensionPathSmith')),
                          Tab(text: text.tr('ascensionPathRogue')),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _AscensionPathView(
                              path: AscensionPath.warrior,
                              controller: controller,
                              onRefresh: () => setModalState(() {}),
                            ),
                            _AscensionPathView(
                              path: AscensionPath.smith,
                              controller: controller,
                              onRefresh: () => setModalState(() {}),
                            ),
                            _AscensionPathView(
                              path: AscensionPath.rogue,
                              controller: controller,
                              onRefresh: () => setModalState(() {}),
                            ),
                          ],
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

  Future<void> _showRecipePanel(
    BuildContext context,
    GameController controller,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.sheetBg,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: _adaptiveSheetHeight(ctx, factor: 0.88, min: 480, max: 900),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final text = controller.text;
                final knownRecipes = controller.knownRecipes;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      text.tr('recipesTitle'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${knownRecipes.length}/${GameController.craftingRecipes.length} Rezepte gefunden',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (knownRecipes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.menu_book,
                                color: context.textTertiary,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                text.tr('recipesNoRecipes'),
                                style: TextStyle(color: context.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    for (final recipe in knownRecipes) ...[
                      _RecipeCard(
                        recipe: recipe,
                        controller: controller,
                        onRefresh: () => setModalState(() {}),
                      ),
                      const SizedBox(height: 10),
                    ],
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

class _AscensionPathView extends StatelessWidget {
  const _AscensionPathView({
    required this.path,
    required this.controller,
    required this.onRefresh,
  });

  final AscensionPath path;
  final GameController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final nodes = GameController.ascensionNodes
        .where((n) => n.path == path)
        .toList();
    nodes.sort((a, b) => a.tier.compareTo(b.tier));

    if (controller.ascensionPoints == 0 &&
        controller.unlockedAscensionNodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text.tr('ascensionNoPoints'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: nodes.map((node) {
        final isUnlocked = controller.unlockedAscensionNodes.contains(node.id);
        final canUnlock = controller.canUnlockAscensionNode(node.id);
        final name = controller.localeCode == 'de' ? node.nameDe : node.nameEn;
        final desc = controller.localeCode == 'de' ? node.descDe : node.descEn;

        return Container(
          margin: EdgeInsets.only(left: (node.tier - 1) * 16.0, bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isUnlocked
                ? const Color(0xFF1B5E20).withValues(alpha: 0.3)
                : context.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isUnlocked
                  ? const Color(0xFF4CAF50)
                  : canUnlock
                  ? const Color(0xFFFF9800).withValues(alpha: 0.7)
                  : context.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isUnlocked
                        ? Icons.check_circle
                        : canUnlock
                        ? Icons.lock_open
                        : Icons.lock,
                    color: isUnlocked
                        ? const Color(0xFF4CAF50)
                        : canUnlock
                        ? const Color(0xFFFF9800)
                        : context.textTertiary,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked
                            ? const Color(0xFF4CAF50)
                            : context.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${node.cost} ${text.tr("ascensionPoints")}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              if (node.requiredNodeId != null && !isUnlocked)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${text.tr("ascensionRequires")}: ${_getNodeName(node.requiredNodeId!, controller)}',
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                ),
              if (canUnlock) ...[
                const SizedBox(height: 6),
                FilledButton.tonal(
                  onPressed: () {
                    controller.unlockAscensionNode(node.id);
                    onRefresh();
                  },
                  child: Text(text.tr('ascensionUnlock')),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getNodeName(String nodeId, GameController controller) {
    for (final node in GameController.ascensionNodes) {
      if (node.id == nodeId) {
        return controller.localeCode == 'de' ? node.nameDe : node.nameEn;
      }
    }
    return nodeId;
  }
}

Future<void> _showSocialPanel(
  BuildContext context,
  GameController controller,
) async {
  final text = controller.text;

  // Require login before showing any social features
  if (!ApiService.instance.isLoggedIn) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AuthScreen(
          onLoggedIn: () => Navigator.pop(context),
          onSkip: () => Navigator.pop(context),
          text: text,
        ),
      ),
    );
    if (!context.mounted || !ApiService.instance.isLoggedIn) return;
  }

  // Helper: require login before pushing a screen
  void requireAuth(BuildContext ctx, Widget screen) {
    Navigator.pop(ctx);
    if (!ApiService.instance.isLoggedIn) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => AuthScreen(
            onLoggedIn: () {
              Navigator.pop(context);
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => screen),
              );
            },
            onSkip: () => Navigator.pop(context),
            text: text,
          ),
        ),
      );
    } else {
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.sheetBg,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text.tr('socialTitle'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _SocialTile(
                icon: Icons.person_outline,
                label: ApiService.instance.isLoggedIn
                    ? (ApiService.instance.currentUsername ??
                          text.tr('loginButton'))
                    : text.tr('loginButton'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (ApiService.instance.isLoggedIn) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: Text(text.tr('logoutConfirmTitle')),
                        content: Text(text.tr('logoutConfirmMessage')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: Text(text.tr('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: Text(text.tr('logoutButton')),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ApiService.instance.logout();
                    }
                  } else {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AuthScreen(
                          onLoggedIn: () => Navigator.pop(context),
                          onSkip: () => Navigator.pop(context),
                          text: text,
                        ),
                      ),
                    );
                  }
                },
              ),
              _SocialTile(
                icon: Icons.leaderboard_outlined,
                label: text.tr('leaderboardTitle'),
                onTap: () => requireAuth(ctx, LeaderboardScreen(text: text)),
              ),
              _SocialTile(
                icon: Icons.people_outline,
                label: text.tr('friendsTitle'),
                onTap: () => requireAuth(ctx, FriendsScreen(text: text)),
              ),
              _SocialTile(
                icon: Icons.sports_kabaddi_outlined,
                label: text.tr('pvpTitle'),
                onTap: () => requireAuth(ctx, PvpScreen(text: text)),
              ),
              _SocialTile(
                icon: Icons.group_work_outlined,
                label: text.tr('coopTitle'),
                onTap: () => requireAuth(ctx, CoopScreen(text: text)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showPetPanel(
  BuildContext context,
  GameController controller,
) async {
  final text = controller.text;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.sheetBg,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.tr('petTitle'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PetPanel(
                      controller: controller,
                      onRefresh: () => setModalState(() {}),
                    ),
                    const SizedBox(height: 16),
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

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    this.iconPath,
    this.icon,
    required this.label,
    required this.onTap,
    this.dense = false,
  }) : assert(iconPath != null || icon != null);

  final String? iconPath;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _rs(context, 3, min: 1.5)),
      child: InkWell(
        borderRadius: BorderRadius.circular(_rs(context, 10, min: 7)),
        onTap: onTap,
        child: Container(
          height: _rs(context, dense ? 54 : 64, min: 48, max: 82),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [context.cardBg, context.cardBgAlt],
            ),
            borderRadius: BorderRadius.circular(_rs(context, 10, min: 7)),
            border: Border.all(color: context.borderGoldBright, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: context.goldAccent.withValues(alpha: 0.14),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconPath != null)
                _SvgIcon(
                  path: iconPath!,
                  size: _rs(context, dense ? 17 : 20, min: 14, max: 26),
                )
              else
                Icon(
                  icon,
                  size: _rs(context, dense ? 17 : 20, min: 14, max: 26),
                  color: context.goldAccent,
                ),
              SizedBox(height: _rs(context, 4, min: 2)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _rs(context, 4, min: 2),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: _rs(context, dense ? 9 : 10, min: 8, max: 12),
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialTile extends StatelessWidget {
  const _SocialTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: context.textPrimary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Update Dialog with download progress
// ---------------------------------------------------------------------------

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.updateInfo, required this.controller});

  final UpdateInfo updateInfo;
  final GameController controller;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final message = widget.controller.text
        .tr('newVersionMessage')
        .replaceAll('{version}', widget.updateInfo.latestVersion);

    return AlertDialog(
      title: Text(widget.controller.text.tr('newVersionAvailable')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress > 0 ? _progress : null),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: _downloading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(widget.controller.text.tr('later')),
              ),
              if (widget.updateInfo.downloadUrl != null)
                FilledButton(
                  onPressed: _startUpdate,
                  child: const Text('Aktualisieren'),
                )
              else
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final uri = Uri.parse(widget.updateInfo.releaseUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Text(widget.controller.text.tr('download')),
                ),
            ],
    );
  }

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    final filePath = await UpdateInstaller.download(
      widget.updateInfo.downloadUrl!,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (filePath == null) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = 'Download fehlgeschlagen. Bitte erneut versuchen.';
        });
      }
      return;
    }

    final success = await UpdateInstaller.install(filePath);
    if (!success && mounted) {
      final installError = UpdateInstaller.lastError;
      var message = 'Installation fehlgeschlagen.';
      if (installError != null &&
          installError.contains('UNKNOWN_SOURCES_PERMISSION_REQUIRED')) {
        message =
            'Bitte erlaube "Unbekannte Apps installieren" fuer Idle Forge und versuche es erneut.';
      } else if (installError != null &&
          installError.contains('NO_PACKAGE_INSTALLER_AVAILABLE')) {
        message =
            'Kein Paket-Installer verfuegbar. Bitte lade das APK manuell aus dem Release herunter.';
      }
      setState(() {
        _downloading = false;
        _error = message;
      });
    }
  }
}

class _TutorialOverlay extends StatefulWidget {
  const _TutorialOverlay({required this.controller, required this.onComplete});

  final GameController controller;
  final VoidCallback onComplete;

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay> {
  int _step = 0;

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      icon: Icons.waving_hand_rounded,
      title: 'Willkommen bei Idle Forge!',
      body:
          'Du bist ein Schmied auf dem Weg zur Legende.\n\n'
          'Besiege Monster, sammle Gold und schmiede mächtige Ausrüstung!',
    ),
    _TutorialStep(
      icon: Icons.sports_martial_arts_rounded,
      title: 'Kampf',
      body:
          'Dein Held kämpft automatisch gegen Monster.\n\n'
          'Oben siehst du das aktuelle Kapitel und die Stage. '
          'Besiege genug Gegner, um die nächste Stage zu erreichen.',
    ),
    _TutorialStep(
      icon: Icons.flash_on_rounded,
      title: 'Fähigkeiten',
      body:
          'Klappe den Fähigkeiten-Bereich im Kampfbildschirm auf.\n\n'
          'Tippe auf eine Fähigkeit, um sie auszulösen. '
          'Halte LANG gedrueckt, um den Auto-Modus zu aktivieren — '
          'dann wird sie automatisch eingesetzt!',
    ),
    _TutorialStep(
      icon: Icons.hardware_rounded,
      title: 'Schmiede',
      body:
          'Im unteren Menue findest du die Schmiede.\n\n'
          'Gib Hämmer aus, um zufällige Ausrüstung zu schmieden. '
          'Bessere Items erhöhen deine Stärke!',
    ),
    _TutorialStep(
      icon: Icons.local_drink_rounded,
      title: 'Tränke',
      body:
          'Unter "Tränke" kannst du Heil- und Berserker-Tränke kaufen.\n\n'
          'Heiltrank stellt HP wieder her, '
          'Berserker-Trank erhoeht kurzzeitig deinen Schaden.',
    ),
    _TutorialStep(
      icon: Icons.backpack_rounded,
      title: 'Inventar & Ausrüstung',
      body:
          'Im Inventar siehst du all deine Items.\n\n'
          'Rüste die stärksten aus, verkaufe den Rest für Gold '
          'oder sperre wertvolle Stuecke vor dem Verkauf.',
    ),
    _TutorialStep(
      icon: Icons.public_rounded,
      title: 'Welt, Quests & Clan',
      body:
          'Welt: Meilensteine und Item-Set-Sammlung.\n'
          'Quests: Erledige Aufgaben für Belohnungen.\n'
          'Clan: Tritt einem Clan bei oder gründe einen eigenen (1000 Gold).\n\n'
          'Im Shop findest du taeglich wechselnde Angebote!',
    ),
    _TutorialStep(
      icon: Icons.person_rounded,
      title: 'Profil & Einstellungen',
      body:
          'Tippe oben links auf dein Profil, um deinen Namen zu aendern '
          'und Einstellungen wie Dark Mode oder FPS anzupassen.\n\n'
          'Viel Spass beim Schmieden!',
    ),
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.cardBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_steps.length, (i) {
                    return Container(
                      width: i == _step ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == _step
                            ? const Color(0xFFD4A44C)
                            : i < _step
                            ? const Color(0xFF8BAF85)
                            : context.borderHeavy,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4A44C).withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    step.icon,
                    size: 44,
                    color: const Color(0xFFD4A44C),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.textBright,
                  ),
                ),
                const SizedBox(height: 12),

                // Body
                Text(
                  step.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    if (!isLast)
                      TextButton(
                        onPressed: _skip,
                        child: Text(
                          'Überspringen',
                          style: TextStyle(color: context.textTertiary),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD4A44C),
                        foregroundColor: const Color(0xFF1A1A1A),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isLast ? 'Los geht\'s!' : 'Weiter',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_step + 1} / ${_steps.length}',
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _SvgIcon extends StatelessWidget {
  const _SvgIcon({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scaledSize = _rs(context, size, min: size * 0.78, max: size * 1.24);
    return SvgPicture.asset(
      path,
      width: scaledSize,
      height: scaledSize,
      fit: BoxFit.contain,
    );
  }
}

class _Runner extends StatelessWidget {
  const _Runner({this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x554D4D4D), Color(0x00282828)],
        ),
      ),
      child: _SvgIcon(path: 'assets/icons/player.svg', size: size * 0.67),
    );
  }
}

class _Enemy extends StatelessWidget {
  const _Enemy({required this.isBoss, this.size});

  final bool isBoss;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final resolvedSize = size ?? (isBoss ? 82 : 70).toDouble();

    return Container(
      width: resolvedSize,
      height: resolvedSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isBoss
              ? const [Color(0x886D4A4A), Color(0x00322222)]
              : const [Color(0x88555555), Color(0x00272727)],
        ),
      ),
      child: _SvgIcon(
        path: 'assets/icons/enemy.svg',
        size: resolvedSize * (isBoss ? 0.68 : 0.69),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.controller,
    required this.onStart,
  });

  final DungeonDifficulty difficulty;
  final GameController controller;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final dc = controller.dungeonController;
    final cost = dc.energyCostForDifficulty(difficulty);
    final canStart = dc.canStartDungeon(difficulty);
    final text = controller.text;

    final (label, color, desc) = switch (difficulty) {
      DungeonDifficulty.normal => (
        text.tr('dungeonDiffNormal'),
        const Color(0xFF4CAF50),
        '5 Stages | Reward: Uncommon+',
      ),
      DungeonDifficulty.hard => (
        text.tr('dungeonDiffHard'),
        const Color(0xFFFF9800),
        '5 Stages | Reward: Rare+ | 1.6x Belohnung',
      ),
      DungeonDifficulty.nightmare => (
        text.tr('dungeonDiffNightmare'),
        const Color(0xFFE91E63),
        '5 Stages | Reward: Epic+ | 2.5x Belohnung',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canStart ? color.withValues(alpha: 0.5) : context.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(desc, style: const TextStyle(fontSize: 11)),
                Text(
                  '${text.tr("dungeonEnergy")}: $cost',
                  style: TextStyle(
                    fontSize: 11,
                    color: canStart ? context.textSecondary : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: canStart ? onStart : null,
            child: Text(text.tr('dungeonStart')),
          ),
        ],
      ),
    );
  }
}

class _ExpeditionSlotCard extends StatefulWidget {
  const _ExpeditionSlotCard({
    required this.slotIndex,
    required this.controller,
    required this.onRefresh,
  });

  final int slotIndex;
  final GameController controller;
  final VoidCallback onRefresh;

  @override
  State<_ExpeditionSlotCard> createState() => _ExpeditionSlotCardState();
}

class _ExpeditionSlotCardState extends State<_ExpeditionSlotCard> {
  String? _selectedExpeditionId;

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final expedition = widget.controller.expeditionSlots[widget.slotIndex];

    if (expedition != null && !expedition.claimed) {
      final def = GameController.expeditionDefinitions.firstWhere(
        (d) => d.id == expedition.expeditionId,
        orElse: () => GameController.expeditionDefinitions.first,
      );
      final isComplete = expedition.isComplete;
      final remaining = expedition.remaining;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isComplete ? const Color(0xFF4CAF50) : context.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.explore,
                  color: isComplete
                      ? const Color(0xFF4CAF50)
                      : context.iconColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    def.nameDe,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${def.durationHours}${text.tr("expeditionHours")}',
                  style: TextStyle(color: context.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (!isComplete)
              Text(
                '${text.tr("expeditionInProgress")} — '
                '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),
            if (isComplete)
              Text(
                text.tr('expeditionComplete'),
                style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
              ),
            const SizedBox(height: 8),
            if (isComplete)
              FilledButton.tonal(
                onPressed: () {
                  widget.controller.claimExpeditionReward(widget.slotIndex);
                  widget.onRefresh();
                },
                child: Text(text.tr('expeditionClaim')),
              ),
          ],
        ),
      );
    }

    if (expedition != null && expedition.claimed) {
      widget.controller.clearExpeditionSlot(widget.slotIndex);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${text.tr("expeditionSlot")} ${widget.slotIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _selectedExpeditionId,
            hint: Text(
              text.tr('expeditionEmpty'),
              style: const TextStyle(fontSize: 12),
            ),
            isExpanded: true,
            items: GameController.expeditionDefinitions.map((def) {
              return DropdownMenuItem<String>(
                value: def.id,
                child: Text(
                  '${def.nameDe} (${def.durationHours}h)',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedExpeditionId = value),
          ),
          const SizedBox(height: 6),
          FilledButton.tonal(
            onPressed: _selectedExpeditionId != null
                ? () {
                    widget.controller.startExpedition(
                      widget.slotIndex,
                      _selectedExpeditionId!,
                    );
                    setState(() => _selectedExpeditionId = null);
                    widget.onRefresh();
                  }
                : null,
            child: Text(text.tr('expeditionStart')),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.controller,
    required this.onRefresh,
  });

  final CraftingRecipe recipe;
  final GameController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final text = controller.text;
    final canCraft = controller.canCraftRecipe(recipe.id);
    final missing = controller.getMissingIngredients(recipe.id);
    final name = controller.localeCode == 'de' ? recipe.nameDe : recipe.nameEn;
    final desc = controller.localeCode == 'de' ? recipe.descDe : recipe.descEn;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canCraft
              ? const Color(0xFF4CAF50).withValues(alpha: 0.6)
              : context.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _tierColor(recipe.resultTier).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _tierColor(recipe.resultTier).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  controller.tierLabel(recipe.resultTier),
                  style: TextStyle(
                    fontSize: 11,
                    color: _tierColor(recipe.resultTier),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '${text.tr("recipesIngredients")}:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final ingredient in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '  • ${ingredient.count}x ${controller.slotLabel(ingredient.slot)} '
                '(${controller.tierLabel(ingredient.minTier)}+)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            '${text.tr("recipesGoldCost")}: ${recipe.goldCost}  |  '
            '${text.tr("recipesHammerCost")}: ${recipe.hammerCost}',
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text.tr('recipesMissing'),
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: canCraft
                ? () {
                    final result = controller.craftByRecipe(recipe.id);
                    if (result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${result.name} hergestellt!')),
                      );
                    }
                    onRefresh();
                  }
                : null,
            child: Text(text.tr('recipesCraft')),
          ),
        ],
      ),
    );
  }

  Color _tierColor(ItemTier tier) {
    return switch (tier) {
      ItemTier.common => const Color(0xFFAAAAAA),
      ItemTier.uncommon => const Color(0xFF4CAF50),
      ItemTier.rare => const Color(0xFF2196F3),
      ItemTier.epic => const Color(0xFF9C27B0),
      ItemTier.legendary => const Color(0xFFFF9800),
    };
  }
}
