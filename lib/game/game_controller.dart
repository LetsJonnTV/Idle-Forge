import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_text.dart';
import '../services/api_service.dart';
import '../services/item_catalog_service.dart';
import '../services/notification_service.dart';
import 'dungeon_controller.dart';
import 'models.dart';

class OfflineReward {
  const OfflineReward({
    required this.gold,
    required this.hammers,
    required this.minutes,
  });

  final int gold;
  final int hammers;
  final int minutes;
}

class BulkSellResult {
  const BulkSellResult({required this.soldCount, required this.earnedGold});

  final int soldCount;
  final int earnedGold;
}

class BulkSellPreview {
  const BulkSellPreview({
    required this.candidateCount,
    required this.sellableCount,
    required this.protectedCount,
    required this.estimatedGold,
  });

  final int candidateCount;
  final int sellableCount;
  final int protectedCount;
  final int estimatedGold;
}

class BalanceTuning {
  const BalanceTuning({
    this.autoAttackIntervalSec = 1,
    this.playerDamageMultiplier = 1,
    this.enemyHpMultiplier = 1,
    this.enemyApproachSpeedMultiplier = 1,
    this.goldGainMultiplier = 1,
    this.offlineRewardMultiplier = 1,
    this.forgeExtraBonus = 0,
    this.killsPerStage = 10,
  });

  final double autoAttackIntervalSec;
  final double playerDamageMultiplier;
  final double enemyHpMultiplier;
  final double enemyApproachSpeedMultiplier;
  final double goldGainMultiplier;
  final double offlineRewardMultiplier;
  final double forgeExtraBonus;
  final int killsPerStage;

  BalanceTuning copyWith({
    double? autoAttackIntervalSec,
    double? playerDamageMultiplier,
    double? enemyHpMultiplier,
    double? enemyApproachSpeedMultiplier,
    double? goldGainMultiplier,
    double? offlineRewardMultiplier,
    double? forgeExtraBonus,
    int? killsPerStage,
  }) {
    return BalanceTuning(
      autoAttackIntervalSec:
          autoAttackIntervalSec ?? this.autoAttackIntervalSec,
      playerDamageMultiplier:
          playerDamageMultiplier ?? this.playerDamageMultiplier,
      enemyHpMultiplier: enemyHpMultiplier ?? this.enemyHpMultiplier,
      enemyApproachSpeedMultiplier:
          enemyApproachSpeedMultiplier ?? this.enemyApproachSpeedMultiplier,
      goldGainMultiplier: goldGainMultiplier ?? this.goldGainMultiplier,
      offlineRewardMultiplier:
          offlineRewardMultiplier ?? this.offlineRewardMultiplier,
      forgeExtraBonus: forgeExtraBonus ?? this.forgeExtraBonus,
      killsPerStage: killsPerStage ?? this.killsPerStage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoAttackIntervalSec': autoAttackIntervalSec,
      'playerDamageMultiplier': playerDamageMultiplier,
      'enemyHpMultiplier': enemyHpMultiplier,
      'enemyApproachSpeedMultiplier': enemyApproachSpeedMultiplier,
      'goldGainMultiplier': goldGainMultiplier,
      'offlineRewardMultiplier': offlineRewardMultiplier,
      'forgeExtraBonus': forgeExtraBonus,
      'killsPerStage': killsPerStage,
    };
  }

  factory BalanceTuning.fromJson(Map<String, dynamic> json) {
    return BalanceTuning(
      autoAttackIntervalSec:
          (json['autoAttackIntervalSec'] as num?)?.toDouble() ?? 1,
      playerDamageMultiplier:
          (json['playerDamageMultiplier'] as num?)?.toDouble() ?? 1,
      enemyHpMultiplier: (json['enemyHpMultiplier'] as num?)?.toDouble() ?? 1,
      enemyApproachSpeedMultiplier:
          (json['enemyApproachSpeedMultiplier'] as num?)?.toDouble() ?? 1,
      goldGainMultiplier: (json['goldGainMultiplier'] as num?)?.toDouble() ?? 1,
      offlineRewardMultiplier:
          (json['offlineRewardMultiplier'] as num?)?.toDouble() ?? 1,
      forgeExtraBonus: (json['forgeExtraBonus'] as num?)?.toDouble() ?? 0,
      killsPerStage: (json['killsPerStage'] as num?)?.toInt() ?? 10,
    );
  }
}

class _ItemBlueprint {
  const _ItemBlueprint({
    required this.name,
    required this.iconPath,
    required this.basePower,
  });

  final String name;
  final String iconPath;
  final int basePower;
}

class GameController extends ChangeNotifier {
  GameController({this.localeCode = 'de'}) {
    _skills = _definitions
        .map(
          (definition) =>
              SkillState(definition: definition, cooldownRemaining: 0),
        )
        .toList(growable: false);
    _dungeonController = DungeonController(random: _random);
  }

  final String localeCode;
  final Random _random = Random();
  late List<SkillState> _skills;
  late final DungeonController _dungeonController;

  Timer? _timer;
  DateTime? _lastTickAt;
  DateTime? _lastSaveAt;
  DateTime? _lastCloudSaveAt;
  bool _isLoaded = false;

  /// Tracks the last cloud save/load result for UI feedback.
  /// Values: null = idle, 'saving', 'saved', 'loading', 'loaded', 'error'
  String? cloudSyncStatus;

  int gold = 60;
  int hammers = 0;
  int forgeLevel = 0;
  int prestigeLevel = 0;
  int forgeShards = 0;
  int chapter = 1;
  int stage = 1;
  int killsInStage = 0;
  int totalKills = 0;
  int deaths = 0;
  int craftedItems = 0;
  int bossDefeats = 0;
  int questCycle = 1;

  bool questKillsClaimed = false;
  bool questCraftsClaimed = false;
  bool questBossClaimed = false;

  PetState? activePet;
  final List<Rune> runeInventory = [];

  int loginStreakDays = 0;
  bool streakClaimedToday = false;
  String _lastLoginDateKey = '';

  int talentAttackLevel = 0;
  int talentVitalityLevel = 0;
  int talentForgeLevel = 0;

  int skillStrikeLevel = 0;
  int skillWhirlLevel = 0;
  int skillFocusLevel = 0;

  int shopSpeedLevel = 0;
  int shopHammerLevel = 0;
  int shopRecoveryLevel = 0;

  int shopManualRefreshes = 0;
  List<ShopOffer> _shopOffers = const [];
  List<ShopOffer> _dailyShopOffers = const [];
  String _dailyOfferDateKey = '';
  DateTime _shopRefreshAt = DateTime.now();

  int healingFlasks = 2;
  int berserkFlasks = 1;
  double flaskCooldownRemaining = 0;
  double berserkRemaining = 0;
  CombatStance combatStance = CombatStance.balanced;

  final Set<int> autoSkillSlots = {};

  double playerHp = 140;

  bool darkModeEnabled = true;
  int targetFps = 60;
  bool showCombatLog = true;
  bool reducedEffects = false;
  bool tutorialCompleted = false;

  bool autoSellEnabled = false;
  ItemTier autoSellKeepFromTier = ItemTier.rare;
  bool autoLockEnabled = false;
  ItemTier autoLockFromTier = ItemTier.epic;

  bool _lastCraftAutoSold = false;
  String _lastCraftAutoSoldText = '';

  String playerName = 'Rookie';

  final List<GameItem> inventory = [];
  final Map<ItemSlot, String> equippedBySlot = {};
  final Map<int, Map<ItemSlot, String>> loadoutPresets = {};
  final Set<String> discoveredSetSlots = {};
  final Set<ItemSet> claimedSetRewards = {};
  final Set<String> claimedAchievements = {};
  final Set<String> discoveredRecipes = {};
  final Set<String> unlockedAscensionNodes = {};
  int ascensionPoints = 0;

  EnemyState enemy = const EnemyState(
    name: 'Schleim',
    maxHp: 20,
    hp: 20,
    approach: 1,
    isBoss: false,
  );

  OfflineReward? lastOfflineReward;
  BalanceTuning tuning = const BalanceTuning();

  final List<ActiveExpedition?> expeditionSlots = [null, null, null];

  double _autoAttackAccumulator = 0;
  double _enemyAttackAccumulator = 0;
  double _bossSpecialAccumulator = 0;
  double _poisonTickAccumulator = 0;
  int _poisonTicksRemaining = 0;
  double _combatRecoveryBlockRemaining = 0;
  bool _bossPhaseTwo = false;
  bool _bossPhaseThree = false;
  double _animationTime = 0;

  String lastCombatEvent = '';

  static const _saveKey = 'idle_forge.save.v1';

  static const int expeditionSlotCount = 3;

  static const List<CraftingRecipe> craftingRecipes = [
    CraftingRecipe(
      id: 'recipe_runic_blade',
      nameDe: 'Runische Klinge',
      nameEn: 'Runic Blade',
      descDe: 'Eine mit Runen verstärkte Klinge.',
      descEn: 'A blade empowered with runes.',
      ingredients: [
        RecipeIngredient(
          slot: ItemSlot.weapon,
          minTier: ItemTier.rare,
          count: 2,
        ),
        RecipeIngredient(
          slot: ItemSlot.ring,
          minTier: ItemTier.uncommon,
          count: 1,
        ),
      ],
      resultSlot: ItemSlot.weapon,
      resultTier: ItemTier.epic,
      goldCost: 200,
      hammerCost: 15,
      dropChance: 0.002,
    ),
    CraftingRecipe(
      id: 'recipe_titan_armor',
      nameDe: 'Titan-Rüstung',
      nameEn: 'Titan Armor',
      descDe: 'Schwerer Schutzpanzer aus Titan-Erz.',
      descEn: 'Heavy armor forged from titan ore.',
      ingredients: [
        RecipeIngredient(
          slot: ItemSlot.armor,
          minTier: ItemTier.rare,
          count: 2,
        ),
        RecipeIngredient(
          slot: ItemSlot.helm,
          minTier: ItemTier.uncommon,
          count: 1,
        ),
      ],
      resultSlot: ItemSlot.armor,
      resultTier: ItemTier.epic,
      goldCost: 180,
      hammerCost: 12,
      dropChance: 0.002,
    ),
    CraftingRecipe(
      id: 'recipe_shadow_dagger',
      nameDe: 'Schattenklinge',
      nameEn: 'Shadow Dagger',
      descDe: 'Eine Klinge aus purem Schatten.',
      descEn: 'A dagger made of pure shadow.',
      ingredients: [
        RecipeIngredient(
          slot: ItemSlot.weapon,
          minTier: ItemTier.uncommon,
          count: 3,
        ),
      ],
      resultSlot: ItemSlot.weapon,
      resultTier: ItemTier.rare,
      goldCost: 100,
      hammerCost: 8,
      dropChance: 0.005,
    ),
    CraftingRecipe(
      id: 'recipe_storm_set_piece',
      nameDe: 'Sturm-Fragment',
      nameEn: 'Storm Fragment',
      descDe: 'Ein Fragment der mächtigen Sturm-Rüstung.',
      descEn: 'A fragment of the mighty Storm armor.',
      ingredients: [
        RecipeIngredient(
          slot: ItemSlot.armor,
          minTier: ItemTier.uncommon,
          count: 2,
        ),
        RecipeIngredient(
          slot: ItemSlot.boots,
          minTier: ItemTier.uncommon,
          count: 1,
        ),
      ],
      resultSlot: ItemSlot.armor,
      resultTier: ItemTier.rare,
      goldCost: 150,
      hammerCost: 10,
      dropChance: 0.003,
    ),
    CraftingRecipe(
      id: 'recipe_legendary_ring',
      nameDe: 'Ring der Ewigkeit',
      nameEn: 'Ring of Eternity',
      descDe: 'Ein Ring mit ewiger Macht.',
      descEn: 'A ring of eternal power.',
      ingredients: [
        RecipeIngredient(slot: ItemSlot.ring, minTier: ItemTier.rare, count: 2),
        RecipeIngredient(
          slot: ItemSlot.weapon,
          minTier: ItemTier.epic,
          count: 1,
        ),
      ],
      resultSlot: ItemSlot.ring,
      resultTier: ItemTier.legendary,
      goldCost: 500,
      hammerCost: 30,
      dropChance: 0.0008,
    ),
  ];

  static const List<AscensionNode> ascensionNodes = [
    // === Krieger-Pfad ===
    AscensionNode(
      id: 'warrior_1_attack',
      path: AscensionPath.warrior,
      nameDe: 'Kampfkraft I',
      nameEn: 'Combat Power I',
      descDe: '+8% Angriffs-Schaden dauerhaft.',
      descEn: '+8% attack damage permanently.',
      cost: 1,
      bonusType: AscensionBonusType.attackMultiplier,
      bonusValue: 0.08,
      requiredNodeId: null,
      tier: 1,
    ),
    AscensionNode(
      id: 'warrior_1_hp',
      path: AscensionPath.warrior,
      nameDe: 'Eisenhaut I',
      nameEn: 'Iron Skin I',
      descDe: '+10% maximale HP dauerhaft.',
      descEn: '+10% max HP permanently.',
      cost: 1,
      bonusType: AscensionBonusType.hpMultiplier,
      bonusValue: 0.1,
      requiredNodeId: null,
      tier: 1,
    ),
    AscensionNode(
      id: 'warrior_2_attack',
      path: AscensionPath.warrior,
      nameDe: 'Kampfkraft II',
      nameEn: 'Combat Power II',
      descDe: '+12% Angriffs-Schaden dauerhaft.',
      descEn: '+12% attack damage permanently.',
      cost: 2,
      bonusType: AscensionBonusType.attackMultiplier,
      bonusValue: 0.12,
      requiredNodeId: 'warrior_1_attack',
      tier: 2,
    ),
    AscensionNode(
      id: 'warrior_2_skill',
      path: AscensionPath.warrior,
      nameDe: 'Kampffokus',
      nameEn: 'Combat Focus',
      descDe: '-10% Skill-Cooldowns dauerhaft.',
      descEn: '-10% skill cooldowns permanently.',
      cost: 2,
      bonusType: AscensionBonusType.skillCooldownReduction,
      bonusValue: 0.1,
      requiredNodeId: 'warrior_1_attack',
      tier: 2,
    ),
    AscensionNode(
      id: 'warrior_3_apex',
      path: AscensionPath.warrior,
      nameDe: 'Kriegsmeister',
      nameEn: 'Warlord',
      descDe: '+20% Angriff und +15% HP dauerhaft.',
      descEn: '+20% attack and +15% HP permanently.',
      cost: 3,
      bonusType: AscensionBonusType.attackMultiplier,
      bonusValue: 0.2,
      requiredNodeId: 'warrior_2_attack',
      tier: 3,
    ),

    // === Schmied-Pfad ===
    AscensionNode(
      id: 'smith_1_forge',
      path: AscensionPath.smith,
      nameDe: 'Schmiedemeister I',
      nameEn: 'Master Smith I',
      descDe: '+3% Schmiedechance dauerhaft.',
      descEn: '+3% forge chance permanently.',
      cost: 1,
      bonusType: AscensionBonusType.forgeBonusChance,
      bonusValue: 0.03,
      requiredNodeId: null,
      tier: 1,
    ),
    AscensionNode(
      id: 'smith_1_hammer',
      path: AscensionPath.smith,
      nameDe: 'Hammer-Kult I',
      nameEn: 'Hammer Cult I',
      descDe: '+15% Hammer-Drop-Chance.',
      descEn: '+15% hammer drop chance.',
      cost: 1,
      bonusType: AscensionBonusType.hammerDropChance,
      bonusValue: 0.15,
      requiredNodeId: null,
      tier: 1,
    ),
    AscensionNode(
      id: 'smith_2_forge',
      path: AscensionPath.smith,
      nameDe: 'Schmiedemeister II',
      nameEn: 'Master Smith II',
      descDe: '+5% Schmiedechance dauerhaft.',
      descEn: '+5% forge chance permanently.',
      cost: 2,
      bonusType: AscensionBonusType.forgeBonusChance,
      bonusValue: 0.05,
      requiredNodeId: 'smith_1_forge',
      tier: 2,
    ),
    AscensionNode(
      id: 'smith_2_power',
      path: AscensionPath.smith,
      nameDe: 'Item-Meister',
      nameEn: 'Item Master',
      descDe: '+5 Bonus-Power auf alle gecrafteten Items.',
      descEn: '+5 bonus power on all crafted items.',
      cost: 2,
      bonusType: AscensionBonusType.itemPowerBonus,
      bonusValue: 5,
      requiredNodeId: 'smith_1_forge',
      tier: 2,
    ),
    AscensionNode(
      id: 'smith_3_apex',
      path: AscensionPath.smith,
      nameDe: 'Legenden-Schmied',
      nameEn: 'Legendary Smith',
      descDe: '+8% Schmiedechance und +10 Item-Power dauerhaft.',
      descEn: '+8% forge chance and +10 item power permanently.',
      cost: 3,
      bonusType: AscensionBonusType.forgeBonusChance,
      bonusValue: 0.08,
      requiredNodeId: 'smith_2_forge',
      tier: 3,
    ),

    // === Schurken-Pfad ===
    AscensionNode(
      id: 'rogue_1_gold',
      path: AscensionPath.rogue,
      nameDe: 'Gold-Gier I',
      nameEn: 'Gold Greed I',
      descDe: '+10% Gold aus allen Quellen dauerhaft.',
      descEn: '+10% gold from all sources permanently.',
      cost: 1,
      bonusType: AscensionBonusType.goldMultiplier,
      bonusValue: 0.1,
      requiredNodeId: null,
      tier: 1,
    ),
    AscensionNode(
      id: 'rogue_1_drop',
      path: AscensionPath.rogue,
      nameDe: 'Beute-Spezialist I',
      nameEn: 'Loot Specialist I',
      descDe: '+20% Drop-Rate für Items und Rezepte.',
      descEn: '+20% drop rate for items and recipes.',
      cost: 1,
      bonusType: AscensionBonusType.dropRateBonus,
      bonusValue: 0.2,
      requiredNodeId: null,
      tier: 1,
    ),
    AscensionNode(
      id: 'rogue_2_gold',
      path: AscensionPath.rogue,
      nameDe: 'Gold-Gier II',
      nameEn: 'Gold Greed II',
      descDe: '+15% Gold aus allen Quellen dauerhaft.',
      descEn: '+15% gold from all sources permanently.',
      cost: 2,
      bonusType: AscensionBonusType.goldMultiplier,
      bonusValue: 0.15,
      requiredNodeId: 'rogue_1_gold',
      tier: 2,
    ),
    AscensionNode(
      id: 'rogue_2_offline',
      path: AscensionPath.rogue,
      nameDe: 'Schattenwirtschaft',
      nameEn: 'Shadow Economy',
      descDe: '+25% Offline-Belohnungen dauerhaft.',
      descEn: '+25% offline rewards permanently.',
      cost: 2,
      bonusType: AscensionBonusType.offlineRewardMultiplier,
      bonusValue: 0.25,
      requiredNodeId: 'rogue_1_gold',
      tier: 2,
    ),
    AscensionNode(
      id: 'rogue_3_apex',
      path: AscensionPath.rogue,
      nameDe: 'Meisterdieb',
      nameEn: 'Master Thief',
      descDe: '+20% Gold, +30% Drop-Rate und +30% Offline dauerhaft.',
      descEn: '+20% gold, +30% drop rate and +30% offline permanently.',
      cost: 3,
      bonusType: AscensionBonusType.goldMultiplier,
      bonusValue: 0.2,
      requiredNodeId: 'rogue_2_gold',
      tier: 3,
    ),
  ];

  static const List<ExpeditionDefinition> expeditionDefinitions = [
    ExpeditionDefinition(
      id: 'hunt_1h',
      type: ExpeditionType.hunt,
      name: 'Kurze Jagd',
      nameDe: 'Kurze Jagd',
      nameEn: 'Quick Hunt',
      durationHours: 1,
      baseGold: 80,
      baseHammers: 8,
      baseShards: 0,
      itemDropChance: 0.3,
    ),
    ExpeditionDefinition(
      id: 'scavenge_1h',
      type: ExpeditionType.scavenge,
      name: 'Plünderung',
      nameDe: 'Plünderung',
      nameEn: 'Scavenge Run',
      durationHours: 1,
      baseGold: 120,
      baseHammers: 4,
      baseShards: 1,
      itemDropChance: 0.2,
    ),
    ExpeditionDefinition(
      id: 'hunt_4h',
      type: ExpeditionType.hunt,
      name: 'Große Jagd',
      nameDe: 'Große Jagd',
      nameEn: 'Grand Hunt',
      durationHours: 4,
      baseGold: 380,
      baseHammers: 35,
      baseShards: 2,
      itemDropChance: 0.55,
    ),
    ExpeditionDefinition(
      id: 'raid_4h',
      type: ExpeditionType.raid,
      name: 'Überfall',
      nameDe: 'Überfall',
      nameEn: 'Raid',
      durationHours: 4,
      baseGold: 280,
      baseHammers: 25,
      baseShards: 4,
      itemDropChance: 0.45,
    ),
    ExpeditionDefinition(
      id: 'expedition_12h',
      type: ExpeditionType.scavenge,
      name: 'Große Expedition',
      nameDe: 'Große Expedition',
      nameEn: 'Grand Expedition',
      durationHours: 12,
      baseGold: 1200,
      baseHammers: 100,
      baseShards: 10,
      itemDropChance: 0.85,
    ),
    ExpeditionDefinition(
      id: 'raid_12h',
      type: ExpeditionType.raid,
      name: 'Großer Überfall',
      nameDe: 'Großer Überfall',
      nameEn: 'Grand Raid',
      durationHours: 12,
      baseGold: 900,
      baseHammers: 80,
      baseShards: 15,
      itemDropChance: 0.8,
    ),
  ];

  static const List<SkillDefinition> _definitions = [
    SkillDefinition(
      id: 'strike',
      labelKey: 'skillStrike',
      cooldownSeconds: 5,
      damageMultiplier: 2.4,
      bonusHits: 0,
    ),
    SkillDefinition(
      id: 'whirl',
      labelKey: 'skillWhirl',
      cooldownSeconds: 8,
      damageMultiplier: 1.6,
      bonusHits: 1,
    ),
    SkillDefinition(
      id: 'focus',
      labelKey: 'skillFocus',
      cooldownSeconds: 12,
      damageMultiplier: 3.0,
      bonusHits: 0,
    ),
  ];

  static const List<String> _catalogPrefixes = [
    'Glut',
    'Frost',
    'Sturm',
    'Nebel',
    'Eisen',
    'Runen',
    'Aether',
    'Schatten',
    'Licht',
    'Donner',
    'Asche',
    'Sonnen',
    'Mond',
    'Stern',
    'Titan',
    'Drachen',
    'Wolken',
    'Wuesten',
    'Gezeiten',
    'Ewigen',
  ];

  static const List<String> _weaponNouns = [
    'Klinge',
    'Schwert',
    'Saebel',
    'Rapier',
    'Katana',
    'Axt',
    'Beil',
    'Hammer',
    'Morgenstern',
    'Speer',
    'Lanze',
    'Hellebarde',
    'Dolch',
    'Messer',
    'Sichel',
    'Sense',
    'Flegel',
    'Stab',
    'Zweihander',
    'Krummschwert',
  ];

  static const List<String> _armorNouns = [
    'Panzer',
    'Harnisch',
    'Brustplatte',
    'Schuppenpanzer',
    'Ringpanzer',
    'Lederweste',
    'Kettenhemd',
    'Brigantine',
    'Kuerass',
    'Lamellenpanzer',
    'Runenmantel',
    'Wappenrock',
    'Kampfrock',
    'Schlachtrobe',
    'Bastion',
    'Aegis',
    'Wardenmail',
    'Zitadelle',
    'Festungspanzer',
    'Sentinelplatte',
  ];

  static const List<String> _helmNouns = [
    'Helm',
    'Visier',
    'Sturmhaube',
    'Topfhelm',
    'Schaller',
    'Barbuta',
    'Maskenhelm',
    'Kronhelm',
    'Hornhelm',
    'Kopfplatte',
    'Wachhelm',
    'Aegiskrone',
    'Runenkappe',
    'Wolkenhaube',
    'Titanhelm',
    'Drachenschaedel',
    'Kampfhaube',
    'Sentinelhelm',
    'Wardenkappe',
    'Festungshelm',
  ];

  static const List<String> _gloveNouns = [
    'Handschuhe',
    'Stulpen',
    'Panzerhandschuhe',
    'Faeustlinge',
    'Klauen',
    'Greifer',
    'Griffwickel',
    'Kampfhandschuhe',
    'Schlaghandschuhe',
    'Runenstulpen',
    'Dornfaeuste',
    'Wardenfingern',
    'Bastiongreifer',
    'Titanfaeuste',
    'Schmiedehandschuhe',
    'Klingenfaeuste',
    'Schattenstulpen',
    'Sturmhandschuhe',
    'Wolkenfäuste',
    'Aegisgreifer',
  ];

  static const List<String> _bootsNouns = [
    'Stiefel',
    'Tritter',
    'Schuhe',
    'Kampfstiefel',
    'Greaves',
    'Panzerstiefel',
    'Laufstiefel',
    'Schattenstiefel',
    'Sturmstiefel',
    'Pfadlaeufer',
    'Wolkenstiefel',
    'Titantritte',
    'Wardenstiefel',
    'Bastionsohlen',
    'Runenschuhe',
    'Drachenklaue',
    'Marschstiefel',
    'Aegisstiefel',
    'Wuestenstiefel',
    'Gezeitenstiefel',
  ];

  static const List<String> _ringNouns = [
    'Ring',
    'Siegel',
    'Band',
    'Reif',
    'Signet',
    'Wappenring',
    'Runenring',
    'Aegissiegel',
    'Titanband',
    'Sturmreif',
    'Schattenring',
    'Mondring',
    'Sonnenring',
    'Sternensiegel',
    'Drachenband',
    'Bastionring',
    'Wardensiegel',
    'Gezeitenreif',
    'Wolkenband',
    'Ewigkeitsring',
  ];

  static final Map<ItemSlot, List<_ItemBlueprint>> _slotCatalogs =
      _buildSlotCatalogs();

  static Map<ItemSlot, List<_ItemBlueprint>> _buildSlotCatalogs() {
    return {
      ItemSlot.weapon: _buildCatalogForSlot(
        slot: ItemSlot.weapon,
        nouns: _weaponNouns,
        iconFolder: 'weapons',
        iconPrefix: 'w',
      ),
      ItemSlot.armor: _buildCatalogForSlot(
        slot: ItemSlot.armor,
        nouns: _armorNouns,
        iconFolder: 'armors',
        iconPrefix: 'a',
      ),
      ItemSlot.helm: _buildCatalogForSlot(
        slot: ItemSlot.helm,
        nouns: _helmNouns,
        iconFolder: 'helms',
        iconPrefix: 'h',
      ),
      ItemSlot.gloves: _buildCatalogForSlot(
        slot: ItemSlot.gloves,
        nouns: _gloveNouns,
        iconFolder: 'gloves',
        iconPrefix: 'g',
      ),
      ItemSlot.boots: _buildCatalogForSlot(
        slot: ItemSlot.boots,
        nouns: _bootsNouns,
        iconFolder: 'boots',
        iconPrefix: 'b',
      ),
      ItemSlot.ring: _buildCatalogForSlot(
        slot: ItemSlot.ring,
        nouns: _ringNouns,
        iconFolder: 'rings',
        iconPrefix: 'r',
      ),
    };
  }

  static List<_ItemBlueprint> _buildCatalogForSlot({
    required ItemSlot slot,
    required List<String> nouns,
    required String iconFolder,
    required String iconPrefix,
  }) {
    final result = <_ItemBlueprint>[];
    var index = 1;
    for (int p = 0; p < _catalogPrefixes.length; p += 1) {
      for (int n = 0; n < nouns.length; n += 1) {
        final iconId = index.toString().padLeft(3, '0');
        result.add(
          _ItemBlueprint(
            name: '${_catalogPrefixes[p]} ${nouns[n]}',
            iconPath: 'assets/icons/$iconFolder/${iconPrefix}_$iconId.svg',
            basePower: _slotBasePower(slot) + p + (n ~/ 2),
          ),
        );
        index += 1;
      }
    }
    return result;
  }

  static int _slotBasePower(ItemSlot slot) {
    return switch (slot) {
      ItemSlot.weapon => 4,
      ItemSlot.armor => 3,
      ItemSlot.helm => 2,
      ItemSlot.gloves => 2,
      ItemSlot.boots => 2,
      ItemSlot.ring => 1,
    };
  }

  late final List<AchievementDefinition> _achievementDefinitions =
      _buildAchievementDefinitions();

  AppText get text => AppText(localeCode);
  bool get isLoaded => _isLoaded;
  double get animationBob => reducedEffects ? 0 : sin(_animationTime * 3) * 5;
  List<SkillState> get skills => _skills;
  DungeonController get dungeonController => _dungeonController;
  int get dungeonEnergy => _dungeonController.dungeonEnergy;
  int get dungeonMaxEnergy => _dungeonController.dungeonMaxEnergy;
  DungeonRun? get activeDungeonRun => _dungeonController.activeDungeonRun;

  int get stageTargetKills => isBossStage ? 1 : tuning.killsPerStage;
  bool get isBossStage => stage == 15;

  int get basePower {
    return 10 + chapter * 3 + (stage - 1);
  }

  int get totalStrength {
    int gearPower = 0;
    for (final item in equippedItems) {
      gearPower += item.power;
      for (final rune in item.enchantments) {
        if (rune.type == RuneType.ice) {
          gearPower += (item.power * rune.bonusValue).round();
        }
      }
    }
    return basePower + gearPower + setAttackBonus;
  }

  Map<ItemSet, int> get equippedSetCounts {
    final counts = <ItemSet, int>{};
    for (final item in equippedItems) {
      counts[item.setId] = (counts[item.setId] ?? 0) + 1;
    }
    return counts;
  }

  int get setAttackBonus {
    int bonus = 0;
    final counts = equippedSetCounts;
    for (final entry in counts.entries) {
      final count = entry.value;
      if (count >= 2) bonus += 6;
      if (count >= 4) bonus += 12;
    }
    return bonus;
  }

  double get setHpBonusMultiplier {
    final count = equippedSetCounts[ItemSet.tide] ?? 0;
    if (count >= 6) return 1.30;
    if (count >= 4) return 1.20;
    if (count >= 2) return 1.10;
    return 1.0;
  }

  double get setForgeBonus {
    final count = equippedSetCounts[ItemSet.ember] ?? 0;
    if (count >= 6) return 0.20;
    if (count >= 4) return 0.05;
    if (count >= 2) return 0.02;
    return 0.0;
  }

  double get setFlaskEffectBonus {
    final count = equippedSetCounts[ItemSet.tide] ?? 0;
    return count >= 6 ? 1.15 : 1.0;
  }

  double get setAttackSpeedBonus {
    final count = equippedSetCounts[ItemSet.storm] ?? 0;
    return count >= 6 ? 0.75 : 1.0;
  }

  double get petGoldBonus {
    final pet = activePet;
    if (pet == null || !pet.isActive || pet.type != PetType.wolf) return 0.0;
    return 0.005 * pet.level;
  }

  double get petForgeBonus {
    final pet = activePet;
    if (pet == null || !pet.isActive || pet.type != PetType.phoenix) return 0.0;
    return 0.005 * pet.level;
  }

  double get petDefenseBonus {
    final pet = activePet;
    if (pet == null || !pet.isActive || pet.type != PetType.golem) return 0.0;
    return 0.005 * pet.level;
  }

  double get _runeDropChance => 0.03 + chapter * 0.002;

  double get maxPlayerHp {
    final base = 140 + (totalStrength * 2.4);
    final prestigeBoost =
        1 + (prestigeLevel * 0.03) + (talentVitalityLevel * 0.08);
    double lifeRuneBonus = 0.0;
    for (final item in equippedItems) {
      for (final rune in item.enchantments) {
        if (rune.type == RuneType.life) lifeRuneBonus += rune.bonusValue;
      }
    }
    return base *
        prestigeBoost *
        setHpBonusMultiplier *
        ascensionHpMultiplier *
        (1 + lifeRuneBonus);
  }

  double get playerHpPercent {
    if (maxPlayerHp <= 0) {
      return 0;
    }
    return (playerHp / maxPlayerHp).clamp(0.0, 1.0).toDouble();
  }

  int get forgeUpgradeCost => 40 + (forgeLevel + 1) * 35;

  double get prestigeDamageBonus =>
      (1 + (prestigeLevel * 0.08) + (talentAttackLevel * 0.06)) *
      clanDamageBonusMultiplier *
      ascensionAttackMultiplier;

  double get prestigeForgeBonus => (prestigeLevel * 0.01).clamp(0, 0.2);

  double get forgeBonusChance =>
      (forgeLevel * 0.018 +
              prestigeForgeBonus +
              (talentForgeLevel * 0.008) +
              setForgeBonus +
              ascensionForgeBonusChance +
              petForgeBonus)
          .clamp(0, 0.65);

  double get ascensionAttackMultiplier {
    return 1.0 + _sumAscensionBonus(AscensionBonusType.attackMultiplier);
  }

  double get ascensionHpMultiplier {
    return 1.0 + _sumAscensionBonus(AscensionBonusType.hpMultiplier);
  }

  double get ascensionSkillCooldownReduction {
    return _sumAscensionBonus(
      AscensionBonusType.skillCooldownReduction,
    ).clamp(0, 0.5);
  }

  double get ascensionForgeBonusChance {
    return _sumAscensionBonus(
      AscensionBonusType.forgeBonusChance,
    ).clamp(0, 0.25);
  }

  double get ascensionHammerDropChance {
    return _sumAscensionBonus(
      AscensionBonusType.hammerDropChance,
    ).clamp(0, 0.5);
  }

  int get ascensionItemPowerBonus {
    return _sumAscensionBonus(AscensionBonusType.itemPowerBonus).round();
  }

  double get ascensionGoldMultiplier {
    return 1.0 + _sumAscensionBonus(AscensionBonusType.goldMultiplier);
  }

  double get ascensionDropRateBonus {
    return _sumAscensionBonus(AscensionBonusType.dropRateBonus).clamp(0, 0.8);
  }

  double get ascensionOfflineMultiplier {
    return 1.0 + _sumAscensionBonus(AscensionBonusType.offlineRewardMultiplier);
  }

  double _sumAscensionBonus(AscensionBonusType type) {
    double total = 0;
    for (final nodeId in unlockedAscensionNodes) {
      final node = _findAscensionNode(nodeId);
      if (node != null && node.bonusType == type) {
        total += node.bonusValue;
      }
    }
    return total;
  }

  AscensionNode? _findAscensionNode(String nodeId) {
    for (final node in ascensionNodes) {
      if (node.id == nodeId) return node;
    }
    return null;
  }

  String get autoSellLabel {
    if (!autoSellEnabled) {
      return 'Aus';
    }
    return 'Ab ${tierLabel(autoSellKeepFromTier)} behalten';
  }

  int get prestigeShardGain {
    final raw =
        ((chapter - 1) * 3) +
        ((stage - 1) ~/ 5) +
        (forgeLevel ~/ 2) +
        (totalKills ~/ 120);
    return max(0, raw);
  }

  bool get canPrestige => chapter >= 2 && prestigeShardGain > 0;

  int get questKillsTarget => 80 + ((questCycle - 1) * 18);
  int get questCraftsTarget => 16 + ((questCycle - 1) * 4);
  int get questBossTarget => 3 + ((questCycle - 1) ~/ 2);

  int get talentAttackCost => 3 + (talentAttackLevel * 2);
  int get talentVitalityCost => 3 + (talentVitalityLevel * 2);
  int get talentForgeCost => 4 + (talentForgeLevel * 3);

  double get clanDamageBonusMultiplier => 1.0;
  double get clanDefenseReduction => 0.0;
  double get clanGoldBonusMultiplier => 1.0;
  double get clanShardBonusMultiplier => 1.0;

  int get skillStrikeCost => 2 + (skillStrikeLevel * 2);
  int get skillWhirlCost => 2 + (skillWhirlLevel * 2);
  int get skillFocusCost => 3 + (skillFocusLevel * 3);

  int get shopSpeedCost => 120 + (shopSpeedLevel * 85);
  int get shopHammerCost => 150 + (shopHammerLevel * 90);
  int get shopRecoveryCost => 110 + (shopRecoveryLevel * 80);
  int get shopRefreshCost => 90 + (chapter * 12) + (shopManualRefreshes * 60);

  List<ShopOffer> get shopOffers => List<ShopOffer>.unmodifiable(_shopOffers);
  List<ShopOffer> get dailyShopOffers =>
      List<ShopOffer>.unmodifiable(_dailyShopOffers);
  List<ShopOffer> get allShopOffers =>
      List<ShopOffer>.unmodifiable([..._dailyShopOffers, ..._shopOffers]);

  Duration get shopRefreshRemaining {
    final remaining = _shopRefreshAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  double get shopAttackSpeedFactor =>
      (1 - (shopSpeedLevel * 0.05)).clamp(0.45, 1.0);
  double get shopHammerBonusChance => (shopHammerLevel * 0.08).clamp(0.0, 0.6);
  double get shopRecoveryBonus => 1 + (shopRecoveryLevel * 0.12);

  bool get berserkActive => berserkRemaining > 0;

  double get combatDamageMultiplier {
    final stance = switch (combatStance) {
      CombatStance.balanced => 1.0,
      CombatStance.aggressive => 1.2,
      CombatStance.defensive => 0.88,
    };
    final berserk = berserkActive ? 1.25 : 1.0;
    return stance * berserk;
  }

  double get combatRegenMultiplier {
    return switch (combatStance) {
      CombatStance.balanced => 1.0,
      CombatStance.aggressive => 0.72,
      CombatStance.defensive => 1.25,
    };
  }

  double get incomingDamageMultiplier {
    final stance = switch (combatStance) {
      CombatStance.balanced => 1.0,
      CombatStance.aggressive => 1.18,
      CombatStance.defensive => 0.76,
    };
    return stance * (1 - clanDefenseReduction) * (1 - petDefenseBonus);
  }

  int get healingFlaskCost => 80 + (healingFlasks * 35) + (chapter * 4);
  int get berserkFlaskCost => 140 + (berserkFlasks * 55) + (chapter * 6);

  bool get allQuestsClaimed =>
      questKillsClaimed && questCraftsClaimed && questBossClaimed;

  int get currentBossPhase {
    if (!enemy.isBoss) {
      return 0;
    }
    if (_bossPhaseThree) {
      return 3;
    }
    if (_bossPhaseTwo) {
      return 2;
    }
    return 1;
  }

  BossPattern get currentBossPattern => enemy.bossPattern;

  List<String> get activeSetBonuses {
    final bonuses = <String>[];
    final counts = equippedSetCounts;

    for (final setId in ItemSet.values) {
      final count = counts[setId] ?? 0;
      if (count < 2) {
        continue;
      }

      if (setId == ItemSet.ember) {
        bonuses.add('${setLabel(setId)} 2er: +2% Schmiedechance');
        if (count >= 4) {
          bonuses.add('${setLabel(setId)} 4er: +5% Schmiedechance');
        }
        if (count >= 6) {
          bonuses.add('${setLabel(setId)} 6er: +20% Schmiedechance');
        }
      } else if (setId == ItemSet.tide) {
        bonuses.add('${setLabel(setId)} 2er: +10% HP');
        if (count >= 4) {
          bonuses.add('${setLabel(setId)} 4er: +20% HP');
        }
        if (count >= 6) {
          bonuses.add('${setLabel(setId)} 6er: +15% Flask-Effektivität');
        }
      } else {
        bonuses.add('${setLabel(setId)} 2er: +6 Angriff');
        if (count >= 4) {
          bonuses.add('${setLabel(setId)} 4er: +12 Angriff');
        }
        if (count >= 6) {
          bonuses.add('${setLabel(setId)} 6er: +25% Angriffsgeschwindigkeit');
        }
      }
    }

    return bonuses;
  }

  List<SetCollectionView> get setCollection {
    final total = ItemSlot.values.length;
    return ItemSet.values
        .map((setId) {
          final missing = <ItemSlot>[];
          int owned = 0;
          for (final slot in ItemSlot.values) {
            if (discoveredSetSlots.contains(_collectionKey(setId, slot))) {
              owned += 1;
            } else {
              missing.add(slot);
            }
          }
          return SetCollectionView(
            setId: setId,
            ownedCount: owned,
            totalCount: total,
            missingSlots: missing,
            rewardGold: setCompletionGoldReward(setId),
            rewardShards: setCompletionShardReward(setId),
            rewardClaimed: isSetCompletionRewardClaimed(setId),
            rewardClaimable:
                missing.isEmpty && !isSetCompletionRewardClaimed(setId),
          );
        })
        .toList(growable: false);
  }

  List<AchievementView> get achievements {
    return _achievementDefinitions
        .map((definition) {
          final raw = _achievementProgress(definition.metric);
          final progress = raw.clamp(0, definition.target);
          final claimed = claimedAchievements.contains(definition.id);
          return AchievementView(
            definition: definition,
            progress: progress,
            claimed: claimed,
            canClaim: !claimed && raw >= definition.target,
          );
        })
        .toList(growable: false);
  }

  int get claimableAchievementCount {
    return achievements.where((entry) => entry.canClaim).length;
  }

  bool claimAchievement(String achievementId) {
    AchievementView? achievement;
    for (final entry in achievements) {
      if (entry.definition.id == achievementId) {
        achievement = entry;
        break;
      }
    }
    if (achievement == null || !achievement.canClaim) {
      return false;
    }

    claimedAchievements.add(achievementId);
    gold += _scaledGoldReward(achievement.definition.rewardGold);
    forgeShards += _scaledShardReward(achievement.definition.rewardShards);
    _save();
    notifyListeners();
    return true;
  }

  int claimAllAchievements() {
    final claimable = achievements
        .where((entry) => entry.canClaim)
        .toList(growable: false);
    if (claimable.isEmpty) {
      return 0;
    }

    int rewardGold = 0;
    int rewardShards = 0;
    for (final entry in claimable) {
      claimedAchievements.add(entry.definition.id);
      rewardGold += entry.definition.rewardGold;
      rewardShards += entry.definition.rewardShards;
    }

    gold += _scaledGoldReward(rewardGold);
    forgeShards += _scaledShardReward(rewardShards);
    _save();
    notifyListeners();
    return claimable.length;
  }

  int _achievementProgress(AchievementMetric metric) {
    return switch (metric) {
      AchievementMetric.totalKills => totalKills,
      AchievementMetric.craftedItems => craftedItems,
      AchievementMetric.bossDefeats => bossDefeats,
      AchievementMetric.chapter => chapter,
      AchievementMetric.forgeLevel => forgeLevel,
      AchievementMetric.prestigeLevel => prestigeLevel,
      AchievementMetric.totalStrength => totalStrength,
      AchievementMetric.questCycle => questCycle,
    };
  }

  List<AchievementDefinition> _buildAchievementDefinitions() {
    final entries = <AchievementDefinition>[];

    void addSeries({
      required String idPrefix,
      required String titlePrefix,
      required String descPrefix,
      required AchievementMetric metric,
      required List<int> thresholds,
      required int baseGold,
      required int baseShards,
    }) {
      for (int i = 0; i < thresholds.length; i += 1) {
        final target = thresholds[i];
        entries.add(
          AchievementDefinition(
            id: '${idPrefix}_${i + 1}',
            title: '$titlePrefix ${i + 1}',
            description: '$descPrefix $target',
            metric: metric,
            target: target,
            rewardGold: baseGold + (i * 60),
            rewardShards: baseShards + (i ~/ 2),
          ),
        );
      }
    }

    List<int> buildProgressiveThresholds({
      required int lastThreshold,
      required int count,
      required double growthFactor,
      required int minStep,
    }) {
      final result = <int>[];
      var current = lastThreshold;
      var step = (lastThreshold * growthFactor).round();

      for (int i = 0; i < count; i += 1) {
        step = max(minStep, step);
        current += step;
        result.add(current);
        step = (step * 1.14).round();
      }

      return result;
    }

    addSeries(
      idPrefix: 'ach_kills',
      titlePrefix: 'Jaeger-Stufe',
      descPrefix: 'Besiege insgesamt Gegner:',
      metric: AchievementMetric.totalKills,
      thresholds: const [50, 100, 200, 350, 500, 750, 1000, 1500, 2000, 3000],
      baseGold: 120,
      baseShards: 1,
    );
    addSeries(
      idPrefix: 'ach_crafts',
      titlePrefix: 'Schmiede-Stufe',
      descPrefix: 'Schmiede insgesamt Items:',
      metric: AchievementMetric.craftedItems,
      thresholds: const [10, 25, 50, 80, 120, 170, 230, 300],
      baseGold: 140,
      baseShards: 1,
    );
    addSeries(
      idPrefix: 'ach_bosses',
      titlePrefix: 'Bossjaeger',
      descPrefix: 'Besiege Bosse:',
      metric: AchievementMetric.bossDefeats,
      thresholds: const [1, 3, 5, 8, 12, 16, 22, 30],
      baseGold: 170,
      baseShards: 2,
    );
    addSeries(
      idPrefix: 'ach_chapter',
      titlePrefix: 'Weltlaeufer',
      descPrefix: 'Erreiche Kapitel:',
      metric: AchievementMetric.chapter,
      thresholds: const [2, 3, 4, 5, 6, 7, 8, 9, 10, 12],
      baseGold: 160,
      baseShards: 2,
    );
    addSeries(
      idPrefix: 'ach_forge',
      titlePrefix: 'Essenzschmied',
      descPrefix: 'Erreiche Schmiedestufe:',
      metric: AchievementMetric.forgeLevel,
      thresholds: const [2, 4, 6, 8, 10, 12, 14, 16],
      baseGold: 180,
      baseShards: 2,
    );
    addSeries(
      idPrefix: 'ach_prestige',
      titlePrefix: 'Aufgestiegener',
      descPrefix: 'Erreiche Prestige-Stufe:',
      metric: AchievementMetric.prestigeLevel,
      thresholds: const [3, 6, 10, 14, 18, 24, 30],
      baseGold: 220,
      baseShards: 3,
    );
    addSeries(
      idPrefix: 'ach_strength',
      titlePrefix: 'Machtkern',
      descPrefix: 'Erreiche Gesamtstärke:',
      metric: AchievementMetric.totalStrength,
      thresholds: const [80, 120, 170, 230, 300, 380, 470],
      baseGold: 210,
      baseShards: 2,
    );
    addSeries(
      idPrefix: 'ach_cycles',
      titlePrefix: 'Zykluswandler',
      descPrefix: 'Erreiche Quest-Zyklus:',
      metric: AchievementMetric.questCycle,
      thresholds: const [2, 3, 4, 5, 6, 7],
      baseGold: 250,
      baseShards: 3,
    );

    // 150 neue Endgame-Meilensteine als voll integrierte Achievements.
    addSeries(
      idPrefix: 'ach_kills_mythic',
      titlePrefix: 'Mythos-Jaeger',
      descPrefix: 'Besiege insgesamt Gegner:',
      metric: AchievementMetric.totalKills,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 3000,
        count: 24,
        growthFactor: 0.11,
        minStep: 280,
      ),
      baseGold: 430,
      baseShards: 5,
    );
    addSeries(
      idPrefix: 'ach_crafts_mythic',
      titlePrefix: 'Runenschmied',
      descPrefix: 'Schmiede insgesamt Items:',
      metric: AchievementMetric.craftedItems,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 300,
        count: 20,
        growthFactor: 0.1,
        minStep: 24,
      ),
      baseGold: 420,
      baseShards: 5,
    );
    addSeries(
      idPrefix: 'ach_bosses_mythic',
      titlePrefix: 'Titanenfaeller',
      descPrefix: 'Besiege Bosse:',
      metric: AchievementMetric.bossDefeats,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 30,
        count: 18,
        growthFactor: 0.22,
        minStep: 5,
      ),
      baseGold: 470,
      baseShards: 6,
    );
    addSeries(
      idPrefix: 'ach_chapter_mythic',
      titlePrefix: 'Sphärenwanderer',
      descPrefix: 'Erreiche Kapitel:',
      metric: AchievementMetric.chapter,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 12,
        count: 16,
        growthFactor: 0.17,
        minStep: 2,
      ),
      baseGold: 440,
      baseShards: 5,
    );
    addSeries(
      idPrefix: 'ach_forge_mythic',
      titlePrefix: 'Astralschmiede',
      descPrefix: 'Erreiche Schmiedestufe:',
      metric: AchievementMetric.forgeLevel,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 16,
        count: 18,
        growthFactor: 0.2,
        minStep: 2,
      ),
      baseGold: 450,
      baseShards: 6,
    );
    addSeries(
      idPrefix: 'ach_prestige_mythic',
      titlePrefix: 'Aether-Aufstieg',
      descPrefix: 'Erreiche Prestige-Stufe:',
      metric: AchievementMetric.prestigeLevel,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 30,
        count: 18,
        growthFactor: 0.16,
        minStep: 3,
      ),
      baseGold: 480,
      baseShards: 7,
    );
    addSeries(
      idPrefix: 'ach_strength_mythic',
      titlePrefix: 'Reliktmacht',
      descPrefix: 'Erreiche Gesamtstärke:',
      metric: AchievementMetric.totalStrength,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 470,
        count: 20,
        growthFactor: 0.14,
        minStep: 48,
      ),
      baseGold: 460,
      baseShards: 6,
    );
    addSeries(
      idPrefix: 'ach_cycles_mythic',
      titlePrefix: 'Ewigzyklus',
      descPrefix: 'Erreiche Quest-Zyklus:',
      metric: AchievementMetric.questCycle,
      thresholds: buildProgressiveThresholds(
        lastThreshold: 7,
        count: 16,
        growthFactor: 0.2,
        minStep: 1,
      ),
      baseGold: 500,
      baseShards: 7,
    );

    return entries;
  }

  bool isSetCompletionRewardClaimed(ItemSet setId) {
    return claimedSetRewards.contains(setId);
  }

  int get completedSetCount {
    return setCollection
        .where((entry) => entry.ownedCount == entry.totalCount)
        .length;
  }

  SetCollectionView get chapterSetProgress {
    final chapterSet = _setForChapter();
    return setCollection.firstWhere((entry) => entry.setId == chapterSet);
  }

  String get chapterSetHuntHint {
    final chapterSet = _setForChapter();
    final progress = chapterSetProgress;
    if (progress.missingSlots.isEmpty) {
      return '${setLabel(chapterSet)} ist komplett gesammelt.';
    }
    final nextSlot = progress.missingSlots.first;
    return 'Zieljagd ${setLabel(chapterSet)}: Als nächstes ${slotLabel(nextSlot)} farmen.';
  }

  int setCompletionGoldReward(ItemSet setId) {
    final progression = max(0, (chapter - 1) + (questCycle - 1));
    final base = 280 + (setId.index * 90) + (progression * 45);
    return _scaledGoldReward(base);
  }

  int setCompletionShardReward(ItemSet setId) {
    final progression = max(0, ((chapter - 1) ~/ 2) + ((questCycle - 1) ~/ 2));
    final base = 5 + (setId.index * 2) + progression;
    return _scaledShardReward(base);
  }

  bool claimSetCompletionReward(ItemSet setId) {
    if (isSetCompletionRewardClaimed(setId)) {
      return false;
    }

    final collected = ItemSlot.values.every(
      (slot) => discoveredSetSlots.contains(_collectionKey(setId, slot)),
    );
    if (!collected) {
      return false;
    }

    claimedSetRewards.add(setId);
    gold += setCompletionGoldReward(setId);
    forgeShards += setCompletionShardReward(setId);
    _save();
    notifyListeners();
    return true;
  }

  List<QuestStateView> get questBoard {
    final killsProgress = totalKills.clamp(0, questKillsTarget);
    final craftsProgress = craftedItems.clamp(0, questCraftsTarget);
    final bossProgress = bossDefeats.clamp(0, questBossTarget);

    return [
      QuestStateView(
        type: QuestType.kills,
        title: 'Jaeger',
        description: 'Besiege $questKillsTarget Gegner',
        progress: killsProgress,
        target: questKillsTarget,
        rewardGold: _scaledGoldReward(220 + ((questCycle - 1) * 35)),
        rewardHammers: 10 + ((questCycle - 1) * 2),
        rewardShards: 0,
        claimed: questKillsClaimed,
        canClaim: !questKillsClaimed && killsProgress >= questKillsTarget,
      ),
      QuestStateView(
        type: QuestType.crafts,
        title: 'Schmiedelehrling',
        description: 'Schmiede $questCraftsTarget Items',
        progress: craftsProgress,
        target: questCraftsTarget,
        rewardGold: _scaledGoldReward(160 + ((questCycle - 1) * 24)),
        rewardHammers: 14 + ((questCycle - 1) * 2),
        rewardShards: 0,
        claimed: questCraftsClaimed,
        canClaim: !questCraftsClaimed && craftsProgress >= questCraftsTarget,
      ),
      QuestStateView(
        type: QuestType.bosses,
        title: 'Boss-Brecher',
        description: 'Besiege $questBossTarget Bosse',
        progress: bossProgress,
        target: questBossTarget,
        rewardGold: _scaledGoldReward(250 + ((questCycle - 1) * 40)),
        rewardHammers: 8 + questCycle,
        rewardShards: _scaledShardReward(4 + ((questCycle - 1) ~/ 2)),
        claimed: questBossClaimed,
        canClaim: !questBossClaimed && bossProgress >= questBossTarget,
      ),
    ];
  }

  List<GameItem> get equippedItems {
    final equippedIds = equippedBySlot.values.toSet();
    return inventory
        .where((item) => equippedIds.contains(item.id))
        .toList(growable: false);
  }

  bool hasLoadoutPreset(int index) {
    final preset = loadoutPresets[index];
    return preset != null && preset.isNotEmpty;
  }

  int saveCurrentLoadout(int index) {
    loadoutPresets[index] = Map<ItemSlot, String>.from(equippedBySlot);
    _save();
    notifyListeners();
    return loadoutPresets[index]?.length ?? 0;
  }

  int applyLoadout(int index) {
    final preset = loadoutPresets[index];
    if (preset == null || preset.isEmpty) {
      return 0;
    }

    int changes = 0;
    for (final entry in preset.entries) {
      final exists = inventory.any((item) => item.id == entry.value);
      if (!exists) {
        continue;
      }
      if (equippedBySlot[entry.key] == entry.value) {
        continue;
      }
      equippedBySlot[entry.key] = entry.value;
      changes += 1;
    }

    if (changes > 0) {
      _save();
      notifyListeners();
    }
    return changes;
  }

  GameItem? bestItemForSlot(ItemSlot slot) {
    final candidates = inventory
        .where((item) => item.slot == slot)
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    candidates.sort((a, b) => b.power.compareTo(a.power));
    return candidates.first;
  }

  int bestUpgradeDelta(ItemSlot slot) {
    final best = bestItemForSlot(slot);
    final equipped = equippedInSlot(slot);
    if (best == null) {
      return 0;
    }
    final equippedPower = equipped?.power ?? 0;
    return best.power - equippedPower;
  }

  Future<void> initialize() async {
    await NotificationService.initialize();
    await _load();
    // If logged in, try to sync with the cloud save. Use cloud if it is newer.
    if (ApiService.instance.isLoggedIn) {
      await _syncCloudOnStartup();
    }
    checkAndClaimLoginStreak();
    _ensureDailyOffers();
    if (_shopOffers.isEmpty) {
      _regenerateShopOffers();
      _shopRefreshAt = DateTime.now().add(const Duration(minutes: 5));
    }
    _spawnEnemy();
    playerHp = playerHp.clamp(1.0, maxPlayerHp).toDouble();
    _isLoaded = true;
    _startTickLoop();
    // Claim any pending admin rewards (non-blocking, runs after first load)
    if (ApiService.instance.isLoggedIn) {
      _claimPendingRewards();
    }
    // Sync item blueprints from API in background (non-blocking)
    ItemCatalogService.instance.loadFromCache().then((_) {
      ItemCatalogService.instance.syncBlueprints().ignore();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTickLoop() {
    _timer?.cancel();
    _lastTickAt = DateTime.now();

    final fps = targetFps.clamp(30, 120);
    final intervalMs = (1000 / fps).round().clamp(8, 34);

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      final now = DateTime.now();
      final dt = _lastTickAt == null
          ? 1 / fps
          : (now.difference(_lastTickAt!).inMicroseconds / 1000000)
                .clamp(0.008, 0.05)
                .toDouble();
      _lastTickAt = now;
      _tick(dt);
    });
  }

  void _tick(double dt) {
    if (!_isLoaded) {
      return;
    }

    _dungeonController.tickEnergyRegeneration();
    _animationTime += dt;

    _skills = _skills
        .map(
          (skill) => skill.copyWith(
            cooldownRemaining: max(0, skill.cooldownRemaining - dt),
          ),
        )
        .toList(growable: false);

    flaskCooldownRemaining = max(0, flaskCooldownRemaining - dt);
    berserkRemaining = max(0, berserkRemaining - dt);
    _combatRecoveryBlockRemaining = max(0, _combatRecoveryBlockRemaining - dt);

    for (final index in autoSkillSlots.toList(growable: false)) {
      if (index < 0 || index >= _skills.length) {
        continue;
      }
      if (_skills[index].cooldownRemaining <= 0) {
        activateSkill(index);
      }
    }

    _autoAttackAccumulator += dt;
    double runeSpeedBonus = 0.0;
    for (final item in equippedItems) {
      for (final rune in item.enchantments) {
        if (rune.type == RuneType.speed) runeSpeedBonus += rune.bonusValue;
      }
    }
    final attackInterval =
        (tuning.autoAttackIntervalSec *
                shopAttackSpeedFactor *
                setAttackSpeedBonus *
                (1 - runeSpeedBonus))
            .clamp(0.15, 3.0);
    while (_autoAttackAccumulator >= attackInterval) {
      _autoAttackAccumulator -= attackInterval;
      double runeFireBonus = 0.0;
      for (final item in equippedItems) {
        for (final rune in item.enchantments) {
          if (rune.type == RuneType.fire) runeFireBonus += rune.bonusValue;
        }
      }
      final baseHit =
          (4 + (totalStrength * 0.38)) *
          tuning.playerDamageMultiplier *
          prestigeDamageBonus *
          combatDamageMultiplier *
          (1 + runeFireBonus);
      _damageEnemy(baseHit.roundToDouble());
    }

    _updateBossPhases();

    if (_poisonTicksRemaining > 0) {
      _poisonTickAccumulator += dt;
      if (_poisonTickAccumulator >= 1) {
        _poisonTickAccumulator = 0;
        _poisonTicksRemaining -= 1;
        final poisonDamage = max(1.0, maxPlayerHp * 0.012);
        playerHp = max(0.0, playerHp - poisonDamage);
        lastCombatEvent = 'Gift verursacht Schaden.';
        if (playerHp <= 0) {
          _onPlayerDefeated();
        }
      }
    }

    final nextApproach = max(
      0.15,
      enemy.approach -
          dt * (0.08 + chapter * 0.005) * tuning.enemyApproachSpeedMultiplier,
    ).toDouble();
    enemy = enemy.copyWith(approach: nextApproach);

    final inMeleeRange = enemy.approach <= 0.22;
    final regenFactorInCombat =
        (inMeleeRange || _combatRecoveryBlockRemaining > 0) ? 0.0 : 1.0;
    final regenPerSecond =
        maxPlayerHp *
        0.015 *
        shopRecoveryBonus *
        combatRegenMultiplier *
        regenFactorInCombat;
    playerHp = min(maxPlayerHp, playerHp + regenPerSecond * dt);

    if (inMeleeRange) {
      _enemyAttackAccumulator += dt;
      final attackEvery = enemy.isBoss
          ? (_bossPhaseThree ? 1.0 : (_bossPhaseTwo ? 1.2 : 1.4))
          : 2.2;
      if (_enemyAttackAccumulator >= attackEvery) {
        _enemyAttackAccumulator = 0;
        _enemyAttack();
      }
    }

    if (_lastSaveAt == null ||
        DateTime.now().difference(_lastSaveAt!).inSeconds >= 6) {
      _save();
      _lastSaveAt = DateTime.now();
    }

    if (DateTime.now().isAfter(_shopRefreshAt)) {
      _regenerateShopOffers();
      _shopRefreshAt = DateTime.now().add(const Duration(minutes: 5));
      shopManualRefreshes = 0;
      _save();
    }

    if (_dailyOfferDateKey != _todayKey()) {
      _regenerateDailyOffers();
      _save();
    }

    notifyListeners();
  }

  void _updateBossPhases() {
    if (!enemy.isBoss) {
      return;
    }

    final hpRatio = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
    if (!_bossPhaseTwo && hpRatio <= 0.66) {
      _bossPhaseTwo = true;
      if (enemy.bossPattern == BossPattern.venom) {
        _poisonTicksRemaining = max(_poisonTicksRemaining, 5);
        playerHp = max(0.0, playerHp - (maxPlayerHp * 0.05));
        lastCombatEvent = 'Boss Phase 2: Giftwelle!';
      } else if (enemy.bossPattern == BossPattern.berserker) {
        playerHp = max(0.0, playerHp - (maxPlayerHp * 0.1));
        lastCombatEvent = 'Boss Phase 2: Blutrausch!';
      } else {
        playerHp = max(0.0, playerHp - (maxPlayerHp * 0.06));
        lastCombatEvent = 'Boss Phase 2: Titan-Schild!';
      }
      if (playerHp <= 0) {
        _onPlayerDefeated();
      }
    }

    if (!_bossPhaseThree && hpRatio <= 0.33) {
      _bossPhaseThree = true;
      _enemyAttackAccumulator = 0;
      if (enemy.bossPattern == BossPattern.venom) {
        _poisonTicksRemaining = max(_poisonTicksRemaining, 8);
        playerHp = max(0.0, playerHp - (maxPlayerHp * 0.08));
        lastCombatEvent = 'Boss Phase 3: Toxischer Sturm!';
      } else if (enemy.bossPattern == BossPattern.berserker) {
        playerHp = max(0.0, playerHp - (maxPlayerHp * 0.14));
        lastCombatEvent = 'Boss Phase 3: Totale Raserei!';
      } else {
        playerHp = max(0.0, playerHp - (maxPlayerHp * 0.1));
        lastCombatEvent = 'Boss Phase 3: Titan-Zorn!';
      }
      if (playerHp <= 0) {
        _onPlayerDefeated();
      }
    }
  }

  void _enemyAttack() {
    double damage = enemy.isBoss
        ? (8 + chapter * 2.2 + stage * 1.2 + (maxPlayerHp * 0.022))
        : (4 + chapter * 1.1 + stage * 0.65 + (maxPlayerHp * 0.012));

    if (!enemy.isBoss) {
      damage *= switch (enemy.archetype) {
        EnemyArchetype.brute => 1.25,
        EnemyArchetype.assassin => _random.nextDouble() < 0.3 ? 1.8 : 0.95,
        EnemyArchetype.poisoner => 0.9,
        EnemyArchetype.guardian => 1.05,
      };

      lastCombatEvent = switch (enemy.archetype) {
        EnemyArchetype.brute => 'Brute trifft schwer.',
        EnemyArchetype.assassin => 'Assassine sticht schnell.',
        EnemyArchetype.poisoner => 'Du wurdest vergiftet.',
        EnemyArchetype.guardian => 'Guardian drückt dich zurück.',
      };

      if (enemy.archetype == EnemyArchetype.poisoner) {
        _poisonTicksRemaining = max(_poisonTicksRemaining, 4);
      }

      if (enemy.hp / enemy.maxHp <= 0.3 &&
          enemy.archetype == EnemyArchetype.assassin) {
        damage *= 1.35;
        lastCombatEvent = 'Assassine wird rasend!';
      }
    }

    if (enemy.isBoss) {
      if (_bossPhaseTwo) {
        damage *= enemy.bossPattern == BossPattern.titan ? 1.1 : 1.2;
      }
      if (_bossPhaseThree) {
        damage *= enemy.bossPattern == BossPattern.berserker ? 1.6 : 1.45;
      }

      _bossSpecialAccumulator += 1;
      if (_bossSpecialAccumulator >= 4) {
        _bossSpecialAccumulator = 0;
        damage *= 1.9;
        lastCombatEvent = 'Boss-Spezialangriff!';
      } else {
        lastCombatEvent = 'Boss trifft dich.';
      }
    } else {
      lastCombatEvent = 'Gegner trifft dich.';
    }

    damage *= incomingDamageMultiplier;
    damage = max(damage, maxPlayerHp * (enemy.isBoss ? 0.01 : 0.005));

    playerHp = max(0.0, playerHp - damage);
    _combatRecoveryBlockRemaining = 1.8;
    if (playerHp <= 0) {
      _onPlayerDefeated();
    }
  }

  void _onPlayerDefeated() {
    deaths += 1;
    gold = max(0, (gold * 0.9).round());
    killsInStage = 0;
    playerHp = maxPlayerHp;
    _enemyAttackAccumulator = 0;
    _bossSpecialAccumulator = 0;
    _bossPhaseTwo = false;
    _bossPhaseThree = false;
    _poisonTickAccumulator = 0;
    _poisonTicksRemaining = 0;
    _combatRecoveryBlockRemaining = 0;
    lastCombatEvent = 'Du wurdest besiegt. -10% Gold';
    _spawnEnemy();
  }

  void _damageEnemy(double damage) {
    if (enemy.isBoss) {
      if (enemy.bossPattern == BossPattern.titan && _bossPhaseTwo) {
        damage *= 0.82;
      }
      if (enemy.bossPattern == BossPattern.titan && _bossPhaseThree) {
        damage *= 0.72;
      }
    }

    final hpAfter = max(0.0, enemy.hp - damage).toDouble();
    // Do not push enemies back on every hit to avoid jittering movement near melee range.
    enemy = enemy.copyWith(hp: hpAfter);
    if (hpAfter <= 0) {
      _onEnemyDefeated();
    }
  }

  void _onEnemyDefeated() {
    int hammerDrop = 1;
    if (_random.nextDouble() < shopHammerBonusChance) {
      hammerDrop += 1;
      lastCombatEvent = 'Bonus-Hammer gefunden!';
    }

    hammers += hammerDrop;
    totalKills += 1;
    killsInStage += 1;
    _tryDropRecipe();

    double runeGoldBonus = 0.0;
    for (final item in equippedItems) {
      for (final rune in item.enchantments) {
        if (rune.type == RuneType.gold) runeGoldBonus += rune.bonusValue;
      }
    }
    final goldMultiplier =
        tuning.goldGainMultiplier *
        clanGoldBonusMultiplier *
        (1 + petGoldBonus + runeGoldBonus);
    final goldDrop = ((2 + chapter) * goldMultiplier).round();
    gold += goldDrop;

    if (_random.nextDouble() < _runeDropChance) {
      final rune = _generateRune();
      runeInventory.add(rune);
      lastCombatEvent = 'Rune gefunden!';
    }

    if (isBossStage) {
      forgeShards += _scaledShardReward(1);
      bossDefeats += 1;
    } else {}

    if (isBossStage) {
      chapter += 1;
      stage = 1;
      killsInStage = 0;
    } else if (killsInStage >= stageTargetKills) {
      stage += 1;
      killsInStage = 0;
    }

    _spawnEnemy();
  }

  void _spawnEnemy() {
    final names = [
      'Schleim',
      'Wolfsritter',
      'Steingolem',
      'Wuestenratte',
      'Nebelgeist',
      'Klingenkrabbe',
    ];

    final enemyName = isBossStage
        ? '${names[_random.nextInt(names.length)]} ${text.tr('boss')}'
        : names[_random.nextInt(names.length)];
    final archetype = isBossStage
        ? EnemyArchetype.guardian
        : EnemyArchetype.values[_random.nextInt(EnemyArchetype.values.length)];
    final bossPattern = switch (chapter % 3) {
      1 => BossPattern.berserker,
      2 => BossPattern.venom,
      _ => BossPattern.titan,
    };

    final stageScalar = chapter * 1.7 + stage * 1.1;
    final chapterGrowth = pow(chapter.toDouble(), 1.2).toDouble() * 24;
    final stageGrowth = pow(stage.toDouble(), 1.15).toDouble() * 12;
    final hpBase = isBossStage ? 120 : 45;
    final hp =
        (hpBase + chapterGrowth + stageGrowth + (stageScalar * 10)) *
        tuning.enemyHpMultiplier;
    enemy = EnemyState(
      name: enemyName,
      maxHp: hp,
      hp: hp,
      approach: 1,
      isBoss: isBossStage,
      archetype: archetype,
      bossPattern: bossPattern,
    );

    _enemyAttackAccumulator = 0;
    _bossPhaseTwo = false;
    _bossPhaseThree = false;
  }

  String archetypeLabel(EnemyArchetype archetype) {
    return switch (archetype) {
      EnemyArchetype.brute => 'Brute',
      EnemyArchetype.assassin => 'Assassin',
      EnemyArchetype.poisoner => 'Poison',
      EnemyArchetype.guardian => 'Guardian',
    };
  }

  String bossPatternLabel(BossPattern pattern) {
    return switch (pattern) {
      BossPattern.berserker => 'Berserker',
      BossPattern.venom => 'Venom',
      BossPattern.titan => 'Titan',
    };
  }

  String setLabel(ItemSet setId) {
    return switch (setId) {
      ItemSet.ember => 'Ember',
      ItemSet.tide => 'Tide',
      ItemSet.storm => 'Storm',
    };
  }

  String _setShortName(ItemSet setId) {
    return switch (setId) {
      ItemSet.ember => '[EMB]',
      ItemSet.tide => '[TID]',
      ItemSet.storm => '[STM]',
    };
  }

  ItemSet _setForChapter() {
    return switch (chapter % 3) {
      1 => ItemSet.ember,
      2 => ItemSet.tide,
      _ => ItemSet.storm,
    };
  }

  ItemSet _rollSetForChapter() {
    final favored = _setForChapter();
    final favoredWeight = (0.56 + (forgeLevel * 0.008)).clamp(0.56, 0.76);
    final otherWeight = (1 - favoredWeight) / 2;

    final weights = <ItemSet, double>{
      ItemSet.ember: otherWeight,
      ItemSet.tide: otherWeight,
      ItemSet.storm: otherWeight,
    };
    weights[favored] = favoredWeight;

    final roll = _random.nextDouble();
    double cumulative = 0;
    for (final setId in ItemSet.values) {
      cumulative += weights[setId] ?? 0;
      if (roll <= cumulative) {
        return setId;
      }
    }

    return favored;
  }

  String _collectionKey(ItemSet setId, ItemSlot slot) =>
      '${setId.name}:${slot.name}';

  bool activateSkill(int index) {
    if (index < 0 || index >= _skills.length) {
      return false;
    }
    final skill = _skills[index];
    if (skill.cooldownRemaining > 0) {
      return false;
    }

    final level = switch (index) {
      0 => skillStrikeLevel,
      1 => skillWhirlLevel,
      _ => skillFocusLevel,
    };

    final damageBoost = 1 + (level * 0.18);
    final cooldownReduction = (level * 0.03).clamp(0.0, 0.35);
    final extraHits = index == 1 ? (level ~/ 4) : 0;

    final burst =
        (totalStrength *
                combatDamageMultiplier *
                skill.definition.damageMultiplier *
                damageBoost *
                tuning.playerDamageMultiplier *
                prestigeDamageBonus)
            .roundToDouble();
    _damageEnemy(burst);

    final totalBonusHits = skill.definition.bonusHits + extraHits;
    for (int i = 0; i < totalBonusHits; i++) {
      _damageEnemy((burst * 0.52).roundToDouble());
    }

    _skills[index] = skill.copyWith(
      cooldownRemaining:
          skill.definition.cooldownSeconds * (1 - cooldownReduction),
    );
    notifyListeners();
    return true;
  }

  GameItem _craftItemWithTier(ItemTier tier) {
    final slot = ItemSlot.values[_random.nextInt(ItemSlot.values.length)];
    final stageScore = chapter * 2 + stage;
    final tierStrength = {
      ItemTier.common: 5,
      ItemTier.uncommon: 8,
      ItemTier.rare: 12,
      ItemTier.epic: 17,
      ItemTier.legendary: 24,
    }[tier]!;
    final power = (tierStrength + stageScore * 1.7 + _random.nextInt(5))
        .round();
    final sellValue = (power * 1.6).round() + (tier.index * 15);
    final setId = _rollSetForChapter();

    String craftedName;
    String craftedIconPath;
    int craftedPower = power;

    final slotCatalog = _slotCatalogs[slot];
    if (slotCatalog != null && slotCatalog.isNotEmpty) {
      final blueprint = slotCatalog[_random.nextInt(slotCatalog.length)];
      craftedName = blueprint.name;
      craftedIconPath = blueprint.iconPath;
      craftedPower += blueprint.basePower;
    } else {
      craftedName =
          '${_slotName(slot)} ${_tierShortName(tier)} ${_setShortName(setId)}';
      craftedIconPath = 'assets/icons/forge.svg';
    }

    return GameItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_d${_random.nextInt(999)}',
      name: craftedName,
      slot: slot,
      tier: tier,
      setId: setId,
      power: craftedPower,
      sellValue: sellValue,
      iconPath: craftedIconPath,
    );
  }

  bool startDungeon(DungeonDifficulty difficulty) {
    final ok = _dungeonController.startDungeon(difficulty);
    if (ok) {
      notifyListeners();
      _save();
    }
    return ok;
  }

  bool advanceDungeonStage() {
    final run = _dungeonController.activeDungeonRun;
    if (run == null || !run.isActive) return false;

    if (run.currentStage >= 5) {
      _dungeonController.activeDungeonRun!.isComplete = true;
      _dungeonController.activeDungeonRun!.isActive = false;
      _dungeonController.pendingDungeonReward = _dungeonController.buildReward(
        difficulty: run.difficulty,
        chapter: chapter,
        completedStages: 5,
        itemFactory: (tier) => _craftItemWithTier(tier),
      );
      _save();
      notifyListeners();
      return true;
    }

    run.currentStage += 1;
    _save();
    notifyListeners();
    return true;
  }

  bool defeatDungeonStage() {
    final run = _dungeonController.activeDungeonRun;
    if (run == null || !run.isActive) return false;
    final completedStages = run.currentStage;

    _dungeonController.activeDungeonRun!.isComplete = true;
    _dungeonController.activeDungeonRun!.isActive = false;

    if (completedStages >= 1) {
      _dungeonController.pendingDungeonReward = _dungeonController.buildReward(
        difficulty: run.difficulty,
        chapter: chapter,
        completedStages: completedStages,
        itemFactory: (tier) => _craftItemWithTier(tier),
      );
    } else {
      _dungeonController.activeDungeonRun = null;
    }

    _save();
    notifyListeners();
    return true;
  }

  DungeonReward? claimDungeonReward() {
    final reward = _dungeonController.pendingDungeonReward;
    if (reward == null) return null;

    gold += reward.gold;
    hammers += reward.hammers;
    forgeShards += reward.shards;
    for (final item in reward.items) {
      inventory.add(item);
    }

    _dungeonController.pendingDungeonReward = null;
    _dungeonController.activeDungeonRun = null;
    _save();
    notifyListeners();
    return reward;
  }

  void abandonDungeon() {
    _dungeonController.activeDungeonRun = null;
    _dungeonController.pendingDungeonReward = null;
    _save();
    notifyListeners();
  }

  GameItem? craftItem() {
    if (hammers <= 0) {
      return null;
    }

    hammers -= 1;
    craftedItems += 1;
    final tier = _rollTier();
    final slot = ItemSlot.values[_random.nextInt(ItemSlot.values.length)];

    final stageScore = chapter + stage / 15;
    final tierStrength = {
      ItemTier.common: 5,
      ItemTier.uncommon: 8,
      ItemTier.rare: 12,
      ItemTier.epic: 17,
      ItemTier.legendary: 24,
    }[tier]!;

    final power = (tierStrength + stageScore * 1.7 + _random.nextInt(5))
        .round();
    final sellValue = (power * 1.6).round() + (tier.index * 15);
    final setId = _rollSetForChapter();

    String craftedName;
    String craftedIconPath;
    int craftedPower = power;

    final slotCatalog = _slotCatalogs[slot];
    if (slotCatalog != null && slotCatalog.isNotEmpty) {
      final blueprint = slotCatalog[_random.nextInt(slotCatalog.length)];
      craftedName = blueprint.name;
      craftedIconPath = blueprint.iconPath;
      craftedPower += blueprint.basePower;
    } else {
      craftedName =
          '${_slotName(slot)} ${_tierShortName(tier)} ${_setShortName(setId)}';
      craftedIconPath = 'assets/icons/forge.svg';
    }

    final item = GameItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(999)}',
      name: craftedName,
      slot: slot,
      tier: tier,
      setId: setId,
      power: craftedPower,
      sellValue: sellValue,
      iconPath: craftedIconPath,
      isLocked: autoLockEnabled && tier.index >= autoLockFromTier.index,
    );

    discoveredSetSlots.add(_collectionKey(setId, slot));

    _lastCraftAutoSold = false;
    _lastCraftAutoSoldText = '';

    if (autoSellEnabled && item.tier.index < autoSellKeepFromTier.index) {
      final soldFor = max(
        1,
        (item.sellValue * tuning.goldGainMultiplier * clanGoldBonusMultiplier)
            .round(),
      );
      gold += soldFor;
      _lastCraftAutoSold = true;
      _lastCraftAutoSoldText =
          '${item.name} automatisch verkauft (+$soldFor Gold)';
      _save();
      notifyListeners();
      return item;
    }

    inventory.add(item);
    _save();
    notifyListeners();
    return item;
  }

  bool consumeLastCraftAutoSoldFlag() {
    final value = _lastCraftAutoSold;
    _lastCraftAutoSold = false;
    return value;
  }

  String consumeLastCraftAutoSoldText() {
    final value = _lastCraftAutoSoldText;
    _lastCraftAutoSoldText = '';
    return value;
  }

  void equipItem(GameItem item) {
    equippedBySlot[item.slot] = item.id;
    _save();
    notifyListeners();
  }

  void unequipSlot(ItemSlot slot) {
    equippedBySlot.remove(slot);
    _save();
    notifyListeners();
  }

  bool sellItem(GameItem item) {
    if (item.isLocked) {
      return false;
    }
    equippedBySlot.removeWhere((_, value) => value == item.id);
    inventory.removeWhere((entry) => entry.id == item.id);
    gold += max(
      1,
      (item.sellValue * tuning.goldGainMultiplier * clanGoldBonusMultiplier)
          .round(),
    );
    _save();
    notifyListeners();
    return true;
  }

  bool toggleItemLock(String itemId) {
    final index = inventory.indexWhere((entry) => entry.id == itemId);
    if (index < 0) {
      return false;
    }

    inventory[index] = inventory[index].copyWith(
      isLocked: !inventory[index].isLocked,
    );
    _save();
    notifyListeners();
    return true;
  }

  void setAutoLock({
    required bool enabled,
    ItemTier? fromTier,
    bool applyToExisting = false,
  }) {
    autoLockEnabled = enabled;
    if (fromTier != null) {
      autoLockFromTier = fromTier;
    }
    if (applyToExisting) {
      for (int i = 0; i < inventory.length; i++) {
        final item = inventory[i];
        final shouldLock = item.tier.index >= autoLockFromTier.index;
        if (item.isLocked == shouldLock) continue;
        inventory[i] = item.copyWith(isLocked: shouldLock);
      }
    }
    _save();
    notifyListeners();
  }

  int applyAutoLockToInventory() {
    int changed = 0;
    for (int i = 0; i < inventory.length; i++) {
      final item = inventory[i];
      final shouldLock = item.tier.index >= autoLockFromTier.index;
      if (item.isLocked == shouldLock) continue;
      inventory[i] = item.copyWith(isLocked: shouldLock);
      changed += 1;
    }
    if (changed > 0) {
      _save();
      notifyListeners();
    }
    return changed;
  }

  BulkSellPreview getBulkSellPreview(Iterable<String> itemIds) {
    final idSet = itemIds.toSet();
    int sellableCount = 0;
    int protectedCount = 0;
    int estimatedGold = 0;

    for (final item in inventory) {
      if (!idSet.contains(item.id)) {
        continue;
      }
      if (item.isLocked || isEquipped(item)) {
        protectedCount += 1;
        continue;
      }
      sellableCount += 1;
      estimatedGold += max(
        1,
        (item.sellValue * tuning.goldGainMultiplier * clanGoldBonusMultiplier)
            .round(),
      );
    }

    return BulkSellPreview(
      candidateCount: idSet.length,
      sellableCount: sellableCount,
      protectedCount: protectedCount,
      estimatedGold: estimatedGold,
    );
  }

  BulkSellResult sellItemsByIds(Iterable<String> itemIds) {
    final idSet = itemIds.toSet();
    int soldCount = 0;
    int earnedGold = 0;

    inventory.removeWhere((item) {
      if (!idSet.contains(item.id)) {
        return false;
      }
      if (item.isLocked || isEquipped(item)) {
        return false;
      }
      soldCount += 1;
      earnedGold += max(
        1,
        (item.sellValue * tuning.goldGainMultiplier * clanGoldBonusMultiplier)
            .round(),
      );
      return true;
    });

    if (soldCount > 0) {
      gold += earnedGold;
      _save();
      notifyListeners();
    }

    return BulkSellResult(soldCount: soldCount, earnedGold: earnedGold);
  }

  int smartEquipBestItems({bool preferSetSynergy = false}) {
    int changes = 0;

    if (!preferSetSynergy) {
      for (final slot in ItemSlot.values) {
        final candidates = inventory
            .where((item) => item.slot == slot)
            .toList(growable: false);
        if (candidates.isEmpty) {
          continue;
        }
        candidates.sort((a, b) => b.power.compareTo(a.power));
        final best = candidates.first;
        if (equippedBySlot[slot] != best.id) {
          equippedBySlot[slot] = best.id;
          changes += 1;
        }
      }

      if (changes > 0) {
        _save();
        notifyListeners();
      }
      return changes;
    }

    final selected = <ItemSlot, GameItem>{};
    final counts = <ItemSet, int>{};

    for (final slot in ItemSlot.values) {
      final candidates = inventory
          .where((item) => item.slot == slot)
          .toList(growable: false);
      if (candidates.isEmpty) {
        continue;
      }

      GameItem best = candidates.first;
      double bestScore = -1;

      for (final candidate in candidates) {
        final projectedCount = (counts[candidate.setId] ?? 0) + 1;
        double score = candidate.power.toDouble();
        score += (counts[candidate.setId] ?? 0) * 4;
        if (projectedCount >= 2) {
          score += 12;
        }
        if (projectedCount >= 4) {
          score += 18;
        }

        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }

      selected[slot] = best;
      counts[best.setId] = (counts[best.setId] ?? 0) + 1;
    }

    for (final entry in selected.entries) {
      final slot = entry.key;
      final best = entry.value;
      if (equippedBySlot[slot] != best.id) {
        equippedBySlot[slot] = best.id;
        changes += 1;
      }
    }

    if (changes > 0) {
      _save();
      notifyListeners();
    }
    return changes;
  }

  bool upgradeForgeChance() {
    if (gold < forgeUpgradeCost) {
      return false;
    }
    gold -= forgeUpgradeCost;
    forgeLevel += 1;
    _save();
    notifyListeners();
    return true;
  }

  bool performPrestige() {
    if (!canPrestige) {
      return false;
    }

    final gained = prestigeShardGain;
    forgeShards += _scaledShardReward(gained);
    prestigeLevel += gained;
    ascensionPoints += gained;

    gold = 60;
    hammers = 0;
    forgeLevel = 0;
    chapter = 1;
    stage = 1;
    killsInStage = 0;
    totalKills = 0;
    deaths = 0;
    craftedItems = 0;
    bossDefeats = 0;
    questKillsClaimed = false;
    questCraftsClaimed = false;
    questBossClaimed = false;
    playerHp = maxPlayerHp;
    inventory.clear();
    equippedBySlot.clear();

    _spawnEnemy();
    _save();
    notifyListeners();
    return true;
  }

  bool claimQuest(QuestType type) {
    final quest = questBoard.firstWhere((entry) => entry.type == type);
    if (!quest.canClaim) {
      return false;
    }

    gold += quest.rewardGold;
    hammers += quest.rewardHammers;
    forgeShards += quest.rewardShards;

    if (type == QuestType.kills) {
      questKillsClaimed = true;
    } else if (type == QuestType.crafts) {
      questCraftsClaimed = true;
    } else {
      questBossClaimed = true;
    }

    _save();
    notifyListeners();
    return true;
  }

  bool refreshQuestCycle() {
    if (!allQuestsClaimed) {
      return false;
    }

    questCycle += 1;
    questKillsClaimed = false;
    questCraftsClaimed = false;
    questBossClaimed = false;
    craftedItems = 0;
    bossDefeats = 0;
    totalKills = 0;

    _save();
    notifyListeners();
    return true;
  }

  bool upgradeTalent(TalentType type) {
    final cost = switch (type) {
      TalentType.attack => talentAttackCost,
      TalentType.vitality => talentVitalityCost,
      TalentType.forge => talentForgeCost,
    };

    if (forgeShards < cost) {
      return false;
    }

    forgeShards -= cost;

    switch (type) {
      case TalentType.attack:
        talentAttackLevel += 1;
      case TalentType.vitality:
        talentVitalityLevel += 1;
      case TalentType.forge:
        talentForgeLevel += 1;
    }

    playerHp = min(playerHp, maxPlayerHp);
    _save();
    notifyListeners();
    return true;
  }

  int _scaledGoldReward(int base) {
    return max(
      1,
      (base * clanGoldBonusMultiplier * ascensionGoldMultiplier).round(),
    );
  }

  /// Deduct gold. Returns false if insufficient funds.
  bool spendGold(int amount) {
    if (gold < amount) return false;
    gold -= amount;
    notifyListeners();
    return true;
  }

  bool canUnlockAscensionNode(String nodeId) {
    if (unlockedAscensionNodes.contains(nodeId)) return false;
    final node = _findAscensionNode(nodeId);
    if (node == null) return false;
    if (ascensionPoints < node.cost) return false;
    if (node.requiredNodeId != null &&
        !unlockedAscensionNodes.contains(node.requiredNodeId)) {
      return false;
    }
    return true;
  }

  bool unlockAscensionNode(String nodeId) {
    if (!canUnlockAscensionNode(nodeId)) return false;
    final node = _findAscensionNode(nodeId);
    if (node == null) return false;

    ascensionPoints -= node.cost;
    unlockedAscensionNodes.add(nodeId);
    _save();
    notifyListeners();
    return true;
  }

  int _scaledShardReward(int base) {
    return max(1, (base * clanShardBonusMultiplier).round());
  }

  bool upgradeShop(ShopUpgradeType type) {
    final cost = switch (type) {
      ShopUpgradeType.speed => shopSpeedCost,
      ShopUpgradeType.hammer => shopHammerCost,
      ShopUpgradeType.recovery => shopRecoveryCost,
    };

    if (gold < cost) {
      return false;
    }

    gold -= cost;
    switch (type) {
      case ShopUpgradeType.speed:
        shopSpeedLevel += 1;
      case ShopUpgradeType.hammer:
        shopHammerLevel += 1;
      case ShopUpgradeType.recovery:
        shopRecoveryLevel += 1;
    }

    _save();
    notifyListeners();
    return true;
  }

  String shopOfferTitle(ShopOffer offer) {
    return switch (offer.kind) {
      ShopOfferKind.speedUpgrade => 'Tempotraining',
      ShopOfferKind.hammerUpgrade => 'Hammerkunde',
      ShopOfferKind.recoveryUpgrade => 'Regeneration',
      ShopOfferKind.hammerPack => 'Hammerpaket',
      ShopOfferKind.shardCache => 'Scherbenkiste',
      ShopOfferKind.healingFlask => 'Heiltrank',
      ShopOfferKind.berserkFlask => 'Berserkertrank',
    };
  }

  String shopOfferDescription(ShopOffer offer) {
    return switch (offer.kind) {
      ShopOfferKind.speedUpgrade =>
        'Dauerhaft +1 Shop-Level für Angriffstempo.',
      ShopOfferKind.hammerUpgrade =>
        'Dauerhaft +1 Shop-Level für Hammerdrop-Chance.',
      ShopOfferKind.recoveryUpgrade =>
        'Dauerhaft +1 Shop-Level für HP-Regeneration.',
      ShopOfferKind.hammerPack => '+${offer.amount} Hammer sofort.',
      ShopOfferKind.shardCache => '+${offer.amount} Scherben sofort.',
      ShopOfferKind.healingFlask => '+${offer.amount} Heiltrank für den Kampf.',
      ShopOfferKind.berserkFlask =>
        '+${offer.amount} Berserkertrank für den Kampf.',
    };
  }

  bool refreshShopManually() {
    if (gold < shopRefreshCost) {
      return false;
    }

    gold -= shopRefreshCost;
    shopManualRefreshes += 1;
    _regenerateShopOffers();
    _shopRefreshAt = DateTime.now().add(const Duration(minutes: 5));
    _save();
    notifyListeners();
    return true;
  }

  bool buyShopOffer(String offerId) {
    int index = _dailyShopOffers.indexWhere((offer) => offer.id == offerId);
    var fromDaily = true;
    if (index < 0) {
      index = _shopOffers.indexWhere((offer) => offer.id == offerId);
      fromDaily = false;
    }
    if (index < 0) {
      return false;
    }

    final source = fromDaily ? _dailyShopOffers : _shopOffers;
    final offer = source[index];
    if (offer.stock <= 0 || gold < offer.cost) {
      return false;
    }

    gold -= offer.cost;
    switch (offer.kind) {
      case ShopOfferKind.speedUpgrade:
        shopSpeedLevel += offer.amount;
      case ShopOfferKind.hammerUpgrade:
        shopHammerLevel += offer.amount;
      case ShopOfferKind.recoveryUpgrade:
        shopRecoveryLevel += offer.amount;
      case ShopOfferKind.hammerPack:
        hammers += offer.amount;
      case ShopOfferKind.shardCache:
        forgeShards += offer.amount;
      case ShopOfferKind.healingFlask:
        healingFlasks += offer.amount;
      case ShopOfferKind.berserkFlask:
        berserkFlasks += offer.amount;
    }

    source[index] = offer.copyWith(stock: max(0, offer.stock - 1));
    _save();
    notifyListeners();
    return true;
  }

  void _ensureDailyOffers() {
    if (_dailyShopOffers.isEmpty || _dailyOfferDateKey != _todayKey()) {
      _regenerateDailyOffers();
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _regenerateDailyOffers() {
    _dailyOfferDateKey = _todayKey();
    final progression = chapter + (prestigeLevel ~/ 3) + (questCycle - 1);

    final dailyPool = <ShopOffer>[
      ShopOffer(
        id: 'daily_shards_${DateTime.now().microsecondsSinceEpoch}',
        kind: ShopOfferKind.shardCache,
        cost: max(110, (95 + (progression * 16))),
        stock: 1,
        amount: 6 + (progression ~/ 4),
        isDaily: true,
        discountPercent: 30,
      ),
      ShopOffer(
        id: 'daily_hammers_${DateTime.now().microsecondsSinceEpoch + 1}',
        kind: ShopOfferKind.hammerPack,
        cost: max(70, (65 + (progression * 10))),
        stock: 1,
        amount: 20 + progression,
        isDaily: true,
        discountPercent: 35,
      ),
      ShopOffer(
        id: 'daily_berserk_${DateTime.now().microsecondsSinceEpoch + 2}',
        kind: ShopOfferKind.berserkFlask,
        cost: max(65, (berserkFlaskCost * 0.52).round()),
        stock: 2,
        amount: 1,
        isDaily: true,
        discountPercent: 40,
      ),
      ShopOffer(
        id: 'daily_recovery_${DateTime.now().microsecondsSinceEpoch + 3}',
        kind: ShopOfferKind.recoveryUpgrade,
        cost: max(90, (shopRecoveryCost * 0.68).round()),
        stock: 1,
        amount: 1,
        isDaily: true,
        discountPercent: 32,
      ),
    ];

    dailyPool.shuffle(_random);
    _dailyShopOffers = dailyPool.take(2).toList(growable: false);
  }

  void _regenerateShopOffers() {
    final upgrades = <ShopOffer>[
      ShopOffer(
        id: 'speed_${DateTime.now().microsecondsSinceEpoch}',
        kind: ShopOfferKind.speedUpgrade,
        cost: max(
          90,
          (shopSpeedCost * (0.88 + _random.nextDouble() * 0.16)).round(),
        ),
        stock: 1,
        amount: 1,
      ),
      ShopOffer(
        id: 'hammer_${DateTime.now().microsecondsSinceEpoch + 1}',
        kind: ShopOfferKind.hammerUpgrade,
        cost: max(
          110,
          (shopHammerCost * (0.88 + _random.nextDouble() * 0.16)).round(),
        ),
        stock: 1,
        amount: 1,
      ),
      ShopOffer(
        id: 'recovery_${DateTime.now().microsecondsSinceEpoch + 2}',
        kind: ShopOfferKind.recoveryUpgrade,
        cost: max(
          95,
          (shopRecoveryCost * (0.88 + _random.nextDouble() * 0.16)).round(),
        ),
        stock: 1,
        amount: 1,
      ),
    ];

    final progression = chapter + ((stage - 1) ~/ 3);
    final resources = <ShopOffer>[
      ShopOffer(
        id: 'hammer_pack_${DateTime.now().microsecondsSinceEpoch + 3}',
        kind: ShopOfferKind.hammerPack,
        cost: 45 + (progression * 11),
        stock: 3,
        amount: 6 + (progression ~/ 2),
      ),
      ShopOffer(
        id: 'shard_cache_${DateTime.now().microsecondsSinceEpoch + 4}',
        kind: ShopOfferKind.shardCache,
        cost: 120 + (progression * 22),
        stock: 2,
        amount: 2 + (progression ~/ 6),
      ),
      ShopOffer(
        id: 'heal_flask_${DateTime.now().microsecondsSinceEpoch + 5}',
        kind: ShopOfferKind.healingFlask,
        cost: max(40, (healingFlaskCost * 0.6).round()),
        stock: 3,
        amount: 1,
      ),
      ShopOffer(
        id: 'berserk_flask_${DateTime.now().microsecondsSinceEpoch + 6}',
        kind: ShopOfferKind.berserkFlask,
        cost: max(70, (berserkFlaskCost * 0.62).round()),
        stock: 2,
        amount: 1,
      ),
    ];

    _shopOffers = [...upgrades, ...resources];
  }

  String combatStanceLabel(CombatStance stance) {
    return switch (stance) {
      CombatStance.balanced => 'Ausgewogen',
      CombatStance.aggressive => 'Offensiv',
      CombatStance.defensive => 'Defensiv',
    };
  }

  bool isAutoSkillEnabled(int index) {
    return autoSkillSlots.contains(index);
  }

  bool toggleAutoSkill(int index) {
    if (index < 0 || index >= _skills.length) {
      return false;
    }
    if (autoSkillSlots.contains(index)) {
      autoSkillSlots.remove(index);
    } else {
      autoSkillSlots.add(index);
    }
    _save();
    notifyListeners();
    return autoSkillSlots.contains(index);
  }

  bool setCombatStance(CombatStance stance) {
    if (combatStance == stance) {
      return false;
    }
    combatStance = stance;
    _save();
    notifyListeners();
    return true;
  }

  bool setDarkModeEnabled(bool enabled) {
    if (darkModeEnabled == enabled) {
      return false;
    }
    darkModeEnabled = enabled;
    _save();
    notifyListeners();
    return true;
  }

  bool setTargetFps(int fps) {
    final normalized = fps.clamp(30, 120);
    if (targetFps == normalized) {
      return false;
    }
    targetFps = normalized;
    _startTickLoop();
    _save();
    notifyListeners();
    return true;
  }

  bool setShowCombatLog(bool enabled) {
    if (showCombatLog == enabled) {
      return false;
    }
    showCombatLog = enabled;
    _save();
    notifyListeners();
    return true;
  }

  bool setReducedEffects(bool enabled) {
    if (reducedEffects == enabled) {
      return false;
    }
    reducedEffects = enabled;
    _save();
    notifyListeners();
    return true;
  }

  bool setPlayerName(String nextName) {
    final trimmed = nextName.trim();
    if (trimmed.isEmpty || trimmed.length < 2) {
      return false;
    }
    final normalized = trimmed.length > 20 ? trimmed.substring(0, 20) : trimmed;
    if (normalized == playerName) {
      return false;
    }
    playerName = normalized;
    _save();
    notifyListeners();
    return true;
  }

  void completeTutorial() {
    if (tutorialCompleted) return;
    tutorialCompleted = true;
    _save();
    notifyListeners();
  }

  bool buyFlask(FlaskType type) {
    final cost = switch (type) {
      FlaskType.healing => healingFlaskCost,
      FlaskType.berserk => berserkFlaskCost,
    };
    if (gold < cost) {
      return false;
    }

    gold -= cost;
    if (type == FlaskType.healing) {
      healingFlasks += 1;
    } else {
      berserkFlasks += 1;
    }

    _save();
    notifyListeners();
    return true;
  }

  bool useHealingFlask() {
    if (healingFlasks <= 0 || flaskCooldownRemaining > 0) {
      return false;
    }

    healingFlasks -= 1;
    flaskCooldownRemaining = 12;
    final healAmount =
        maxPlayerHp *
        (0.35 + (talentVitalityLevel * 0.01)) *
        setFlaskEffectBonus;
    playerHp = min(maxPlayerHp, playerHp + healAmount);
    lastCombatEvent = 'Heiltrank eingesetzt.';
    _save();
    notifyListeners();
    return true;
  }

  bool useBerserkFlask() {
    if (berserkFlasks <= 0 || flaskCooldownRemaining > 0) {
      return false;
    }

    berserkFlasks -= 1;
    flaskCooldownRemaining = 12;
    final duration = (20 + (skillFocusLevel * 0.8)) * setFlaskEffectBonus;
    berserkRemaining = max(berserkRemaining, duration);
    lastCombatEvent = 'Berserkertrank aktiv!';
    _save();
    notifyListeners();
    return true;
  }

  bool upgradeSkill(int index) {
    int cost;
    switch (index) {
      case 0:
        cost = skillStrikeCost;
      case 1:
        cost = skillWhirlCost;
      default:
        cost = skillFocusCost;
    }

    if (forgeShards < cost) {
      return false;
    }

    forgeShards -= cost;
    if (index == 0) {
      skillStrikeLevel += 1;
    } else if (index == 1) {
      skillWhirlLevel += 1;
    } else {
      skillFocusLevel += 1;
    }

    _save();
    notifyListeners();
    return true;
  }

  void setTuning(BalanceTuning value, {bool refreshEnemy = false}) {
    final clamped = value.copyWith(
      autoAttackIntervalSec: value.autoAttackIntervalSec.clamp(0.2, 3.0),
      playerDamageMultiplier: value.playerDamageMultiplier.clamp(0.3, 4.0),
      enemyHpMultiplier: value.enemyHpMultiplier.clamp(0.3, 4.5),
      enemyApproachSpeedMultiplier: value.enemyApproachSpeedMultiplier.clamp(
        0.3,
        3.0,
      ),
      goldGainMultiplier: value.goldGainMultiplier.clamp(0.2, 5.0),
      offlineRewardMultiplier: value.offlineRewardMultiplier.clamp(0.2, 5.0),
      forgeExtraBonus: value.forgeExtraBonus.clamp(0, 0.25),
      killsPerStage: value.killsPerStage.clamp(1, 12),
    );

    tuning = clamped;

    if (refreshEnemy) {
      final hpRatio = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
      _spawnEnemy();
      enemy = enemy.copyWith(hp: (enemy.maxHp * hpRatio).toDouble());
    }

    _save();
    notifyListeners();
  }

  void debugAddResources({int goldDelta = 0, int hammerDelta = 0}) {
    gold = max(0, gold + goldDelta);
    hammers = max(0, hammers + hammerDelta);
    _save();
    notifyListeners();
  }

  void debugAdvanceStage(int delta) {
    int linear = (chapter - 1) * 15 + (stage - 1) + delta;
    linear = max(0, linear);
    chapter = (linear ~/ 15) + 1;
    stage = (linear % 15) + 1;
    killsInStage = 0;
    _spawnEnemy();
    _save();
    notifyListeners();
  }

  bool adoptPet(PetType type) {
    const cost = 200;
    if (gold < cost) return false;
    gold -= cost;
    activePet = PetState(type: type, level: 1, xp: 0, isActive: true);
    _save();
    notifyListeners();
    return true;
  }

  bool feedPet(int materials) {
    final pet = activePet;
    if (pet == null) return false;
    final xpGain = materials * 10;
    int newXp = pet.xp + xpGain;
    int newLevel = pet.level;
    while (newLevel < 20 && newXp >= newLevel * 100) {
      newXp -= newLevel * 100;
      newLevel += 1;
    }
    if (newLevel >= 20) newXp = 0;
    activePet = pet.copyWith(level: newLevel, xp: newXp);
    _save();
    notifyListeners();
    return true;
  }

  Rune _generateRune() {
    final roll = _random.nextDouble();
    final int tier;
    if (roll < 0.10) {
      tier = 3;
    } else if (roll < 0.40) {
      tier = 2;
    } else {
      tier = 1;
    }
    final bonusValue = switch (tier) {
      3 => 0.18,
      2 => 0.10,
      _ => 0.05,
    };
    final type = RuneType.values[_random.nextInt(RuneType.values.length)];
    return Rune(type: type, tier: tier, bonusValue: bonusValue);
  }

  bool enchantItem(String itemId, int runeIndex) {
    if (runeIndex < 0 || runeIndex >= runeInventory.length) return false;
    final index = inventory.indexWhere((item) => item.id == itemId);
    if (index < 0) return false;
    final item = inventory[index];
    if (item.enchantments.length >= 2) return false;
    final rune = runeInventory[runeIndex];
    runeInventory.removeAt(runeIndex);
    final newEnchantments = [...item.enchantments, rune];
    inventory[index] = item.copyWith(enchantments: newEnchantments);
    _save();
    notifyListeners();
    return true;
  }

  bool removeEnchantment(String itemId, int slotIndex) {
    final index = inventory.indexWhere((item) => item.id == itemId);
    if (index < 0) return false;
    final item = inventory[index];
    if (slotIndex < 0 || slotIndex >= item.enchantments.length) return false;
    final newEnchantments = [...item.enchantments]..removeAt(slotIndex);
    final removedRune = item.enchantments[slotIndex];
    runeInventory.add(removedRune);
    inventory[index] = item.copyWith(enchantments: newEnchantments);
    _save();
    notifyListeners();
    return true;
  }

  StreakReward getStreakReward(int day) {
    final dayInCycle = ((day - 1) % 7) + 1;
    return switch (dayInCycle) {
      1 => const StreakReward(gold: 100, hammers: 0, shards: 0),
      2 => const StreakReward(gold: 0, hammers: 5, shards: 0),
      3 => const StreakReward(gold: 150, hammers: 0, shards: 0),
      4 => const StreakReward(gold: 0, hammers: 10, shards: 0),
      5 => const StreakReward(gold: 200, hammers: 0, shards: 1),
      6 => const StreakReward(gold: 0, hammers: 0, shards: 2),
      _ => const StreakReward(
        gold: 300,
        hammers: 5,
        shards: 5,
        isSpecial: true,
      ),
    };
  }

  bool checkAndClaimLoginStreak() {
    final today = _todayKey();
    if (_lastLoginDateKey == today) {
      return false;
    }

    if (_lastLoginDateKey.isNotEmpty) {
      try {
        final lastDate = DateTime.parse(_lastLoginDateKey);
        final diff = DateTime.now().difference(lastDate).inDays;
        if (diff > 1) {
          loginStreakDays = 0;
        }
      } catch (_) {
        loginStreakDays = 0;
      }
    }

    loginStreakDays += 1;
    _lastLoginDateKey = today;
    streakClaimedToday = true;

    final reward = getStreakReward(loginStreakDays);
    gold += reward.gold;
    hammers += reward.hammers;
    forgeShards += reward.shards;

    _save();
    return true;
  }

  EquipDiff calculateEquipDiff(GameItem item) {
    final currentItem = equippedInSlot(item.slot);
    final currentPower = (currentItem != null && currentItem.id.isNotEmpty)
        ? currentItem.power
        : 0;
    return EquipDiff(currentPower: currentPower, newPower: item.power);
  }

  void cycleAutoSellMode() {
    if (!autoSellEnabled) {
      autoSellEnabled = true;
      autoSellKeepFromTier = ItemTier.rare;
    } else if (autoSellKeepFromTier == ItemTier.rare) {
      autoSellKeepFromTier = ItemTier.epic;
    } else if (autoSellKeepFromTier == ItemTier.epic) {
      autoSellKeepFromTier = ItemTier.legendary;
    } else {
      autoSellEnabled = false;
      autoSellKeepFromTier = ItemTier.rare;
    }

    _save();
    notifyListeners();
  }

  bool isEquipped(GameItem item) {
    return equippedBySlot[item.slot] == item.id;
  }

  GameItem? equippedInSlot(ItemSlot slot) {
    final equippedId = equippedBySlot[slot];
    if (equippedId == null) {
      return null;
    }
    return inventory.firstWhere(
      (item) => item.id == equippedId,
      orElse: () => const GameItem(
        id: '',
        name: '',
        slot: ItemSlot.weapon,
        tier: ItemTier.common,
        setId: ItemSet.ember,
        power: 0,
        sellValue: 0,
        iconPath: 'assets/icons/forge.svg',
      ),
    );
  }

  ItemTier _rollTier() {
    final roll = _random.nextDouble();
    final bonus = (forgeBonusChance + tuning.forgeExtraBonus).clamp(0, 0.6);

    final t1 = max(0.5, 0.82 - bonus * 0.7);
    final t2 = min(0.31, 0.14 + bonus * 0.4);
    final t3 = min(0.2, 0.03 + bonus * 0.35);
    final t4 = min(0.12, 0.009 + bonus * 0.18);

    final thresholds = [t1, t1 + t2, t1 + t2 + t3, t1 + t2 + t3 + t4];

    if (roll <= thresholds[0]) {
      return ItemTier.common;
    }
    if (roll <= thresholds[1]) {
      return ItemTier.uncommon;
    }
    if (roll <= thresholds[2]) {
      return ItemTier.rare;
    }
    if (roll <= thresholds[3]) {
      return ItemTier.epic;
    }
    return ItemTier.legendary;
  }

  String _slotName(ItemSlot slot) {
    return switch (slot) {
      ItemSlot.weapon => text.tr('slotWeapon'),
      ItemSlot.armor => text.tr('slotArmor'),
      ItemSlot.helm => text.tr('slotHelm'),
      ItemSlot.gloves => text.tr('slotGloves'),
      ItemSlot.boots => text.tr('slotBoots'),
      ItemSlot.ring => text.tr('slotRing'),
    };
  }

  String _tierShortName(ItemTier tier) {
    return switch (tier) {
      ItemTier.common => 'T1',
      ItemTier.uncommon => 'T2',
      ItemTier.rare => 'T3',
      ItemTier.epic => 'T4',
      ItemTier.legendary => 'T5',
    };
  }

  String tierLabel(ItemTier tier) {
    return switch (tier) {
      ItemTier.common => text.tr('tierCommon'),
      ItemTier.uncommon => text.tr('tierUncommon'),
      ItemTier.rare => text.tr('tierRare'),
      ItemTier.epic => text.tr('tierEpic'),
      ItemTier.legendary => text.tr('tierLegendary'),
    };
  }

  String slotLabel(ItemSlot slot) {
    return switch (slot) {
      ItemSlot.weapon => text.tr('slotWeapon'),
      ItemSlot.armor => text.tr('slotArmor'),
      ItemSlot.helm => text.tr('slotHelm'),
      ItemSlot.gloves => text.tr('slotGloves'),
      ItemSlot.boots => text.tr('slotBoots'),
      ItemSlot.ring => text.tr('slotRing'),
    };
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);

    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;

    playerName = (map['playerName'] as String?)?.trim().isNotEmpty == true
        ? (map['playerName'] as String).trim()
        : playerName;
    darkModeEnabled = map['darkModeEnabled'] as bool? ?? darkModeEnabled;
    showCombatLog = map['showCombatLog'] as bool? ?? showCombatLog;
    reducedEffects = map['reducedEffects'] as bool? ?? reducedEffects;
    tutorialCompleted = map['tutorialCompleted'] as bool? ?? tutorialCompleted;
    targetFps = ((map['targetFps'] as num?)?.toInt() ?? targetFps).clamp(
      30,
      120,
    );

    gold = map['gold'] as int? ?? gold;
    hammers = map['hammers'] as int? ?? hammers;
    forgeLevel = map['forgeLevel'] as int? ?? forgeLevel;
    prestigeLevel = map['prestigeLevel'] as int? ?? prestigeLevel;
    forgeShards = map['forgeShards'] as int? ?? forgeShards;
    chapter = map['chapter'] as int? ?? chapter;
    stage = map['stage'] as int? ?? stage;
    killsInStage = map['killsInStage'] as int? ?? killsInStage;
    totalKills = map['totalKills'] as int? ?? totalKills;
    craftedItems = map['craftedItems'] as int? ?? craftedItems;
    bossDefeats = map['bossDefeats'] as int? ?? bossDefeats;
    questCycle = map['questCycle'] as int? ?? questCycle;
    questKillsClaimed = map['questKillsClaimed'] as bool? ?? questKillsClaimed;
    questCraftsClaimed =
        map['questCraftsClaimed'] as bool? ?? questCraftsClaimed;
    questBossClaimed = map['questBossClaimed'] as bool? ?? questBossClaimed;
    talentAttackLevel = map['talentAttackLevel'] as int? ?? talentAttackLevel;
    talentVitalityLevel =
        map['talentVitalityLevel'] as int? ?? talentVitalityLevel;
    talentForgeLevel = map['talentForgeLevel'] as int? ?? talentForgeLevel;
    skillStrikeLevel = map['skillStrikeLevel'] as int? ?? skillStrikeLevel;
    skillWhirlLevel = map['skillWhirlLevel'] as int? ?? skillWhirlLevel;
    skillFocusLevel = map['skillFocusLevel'] as int? ?? skillFocusLevel;
    shopSpeedLevel = map['shopSpeedLevel'] as int? ?? shopSpeedLevel;
    shopHammerLevel = map['shopHammerLevel'] as int? ?? shopHammerLevel;
    shopRecoveryLevel = map['shopRecoveryLevel'] as int? ?? shopRecoveryLevel;
    shopManualRefreshes =
        map['shopManualRefreshes'] as int? ?? shopManualRefreshes;
    healingFlasks = map['healingFlasks'] as int? ?? healingFlasks;
    berserkFlasks = map['berserkFlasks'] as int? ?? berserkFlasks;
    flaskCooldownRemaining =
        (map['flaskCooldownRemaining'] as num?)?.toDouble() ?? 0;
    berserkRemaining = (map['berserkRemaining'] as num?)?.toDouble() ?? 0;
    final stanceName = map['combatStance'] as String?;
    if (stanceName != null) {
      combatStance = CombatStance.values.firstWhere(
        (value) => value.name == stanceName,
        orElse: () => combatStance,
      );
    }

    final shopRefreshMillis = map['shopRefreshAtMillis'] as int?;
    if (shopRefreshMillis != null) {
      _shopRefreshAt = DateTime.fromMillisecondsSinceEpoch(shopRefreshMillis);
    }

    final offersJson = (map['shopOffers'] as List<dynamic>? ?? [])
        .map(
          (entry) =>
              ShopOffer.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList(growable: false);
    if (offersJson.isNotEmpty) {
      _shopOffers = offersJson;
    }

    _dailyOfferDateKey =
        map['dailyOfferDateKey'] as String? ?? _dailyOfferDateKey;
    final dailyOffersJson = (map['dailyShopOffers'] as List<dynamic>? ?? [])
        .map(
          (entry) =>
              ShopOffer.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList(growable: false);
    if (dailyOffersJson.isNotEmpty) {
      _dailyShopOffers = dailyOffersJson;
    }

    deaths = map['deaths'] as int? ?? deaths;
    playerHp = (map['playerHp'] as num?)?.toDouble() ?? playerHp;
    autoSellEnabled = map['autoSellEnabled'] as bool? ?? autoSellEnabled;
    autoLockEnabled = map['autoLockEnabled'] as bool? ?? autoLockEnabled;
    final keepTierName = map['autoSellKeepFromTier'] as String?;
    if (keepTierName != null) {
      autoSellKeepFromTier = ItemTier.values.firstWhere(
        (tier) => tier.name == keepTierName,
        orElse: () => autoSellKeepFromTier,
      );
    }
    final autoLockTierName = map['autoLockFromTier'] as String?;
    if (autoLockTierName != null) {
      autoLockFromTier = ItemTier.values.firstWhere(
        (tier) => tier.name == autoLockTierName,
        orElse: () => autoLockFromTier,
      );
    }
    tuning = BalanceTuning.fromJson(
      Map<String, dynamic>.from(map['tuning'] as Map? ?? {}),
    );
    discoveredSetSlots
      ..clear()
      ..addAll(
        (map['discoveredSetSlots'] as List<dynamic>? ?? []).cast<String>(),
      );
    claimedSetRewards
      ..clear()
      ..addAll(
        (map['claimedSetRewards'] as List<dynamic>? ?? []).map(
          (value) => ItemSet.values.firstWhere(
            (setId) => setId.name == value,
            orElse: () => ItemSet.ember,
          ),
        ),
      );
    claimedAchievements
      ..clear()
      ..addAll(
        (map['claimedAchievements'] as List<dynamic>? ?? []).cast<String>(),
      );

    autoSkillSlots
      ..clear()
      ..addAll(
        (map['autoSkillSlots'] as List<dynamic>? ?? []).map(
          (value) => (value as num).toInt(),
        ),
      );

    final inventoryJson = (map['inventory'] as List<dynamic>? ?? [])
        .map(
          (entry) => GameItem.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    inventory
      ..clear()
      ..addAll(inventoryJson);

    final equippedJson = Map<String, dynamic>.from(
      map['equippedBySlot'] as Map? ?? {},
    );
    equippedBySlot
      ..clear()
      ..addEntries(
        equippedJson.entries.map((entry) {
          final slot = ItemSlot.values.where(
            (value) => value.name == entry.key,
          );
          if (slot.isEmpty || entry.value is! String) return null;
          return MapEntry(slot.first, entry.value as String);
        }).whereType<MapEntry<ItemSlot, String>>(),
      );

    loadoutPresets.clear();
    final loadoutsJson = Map<String, dynamic>.from(
      map['loadoutPresets'] as Map? ?? {},
    );
    for (final presetEntry in loadoutsJson.entries) {
      final index = int.tryParse(presetEntry.key);
      if (index == null) {
        continue;
      }
      final slotsJson = Map<String, dynamic>.from(
        presetEntry.value as Map? ?? {},
      );
      final mapped = <ItemSlot, String>{};
      for (final slotEntry in slotsJson.entries) {
        final slot = ItemSlot.values.firstWhere(
          (value) => value.name == slotEntry.key,
          orElse: () => ItemSlot.weapon,
        );
        if (slotEntry.value is String) {
          mapped[slot] = slotEntry.value as String;
        }
      }
      if (mapped.isNotEmpty) {
        loadoutPresets[index] = mapped;
      }
    }

    playerHp = playerHp.clamp(1.0, maxPlayerHp).toDouble();

    final dungeonStateJson = map['dungeonState'] as Map<String, dynamic>?;
    if (dungeonStateJson != null) {
      _dungeonController.loadFromJson(dungeonStateJson);
    }

    final lastActiveMillis = map['lastActiveMillis'] as int?;
    if (lastActiveMillis != null) {
      _applyOfflineReward(
        DateTime.fromMillisecondsSinceEpoch(lastActiveMillis),
      );
    }

    final expeditionSlotsJson =
        (map['expeditionSlots'] as List<dynamic>? ?? []);
    for (int i = 0; i < expeditionSlotsJson.length && i < 3; i++) {
      final slotJson = expeditionSlotsJson[i];
      if (slotJson != null) {
        expeditionSlots[i] = ActiveExpedition.fromJson(
          Map<String, dynamic>.from(slotJson as Map),
        );
      }
    }

    discoveredRecipes
      ..clear()
      ..addAll(
        (map['discoveredRecipes'] as List<dynamic>? ?? []).cast<String>(),
      );

    ascensionPoints = map['ascensionPoints'] as int? ?? 0;
    unlockedAscensionNodes
      ..clear()
      ..addAll(
        (map['unlockedAscensionNodes'] as List<dynamic>? ?? []).cast<String>(),
      );

    final petJson = map['activePet'] as Map?;
    if (petJson != null) {
      activePet = PetState.fromJson(Map<String, dynamic>.from(petJson));
    }

    runeInventory
      ..clear()
      ..addAll(
        (map['runeInventory'] as List<dynamic>? ?? []).map(
          (e) => Rune.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );

    loginStreakDays = map['loginStreakDays'] as int? ?? 0;
    _lastLoginDateKey = map['lastLoginDateKey'] as String? ?? '';
  }

  void _applyOfflineReward(DateTime lastActive) {
    final minutes = DateTime.now().difference(lastActive).inMinutes;
    if (minutes <= 0) {
      return;
    }

    final clampedMinutes = min(minutes, 240);
    final estimatedKills = max(1, (clampedMinutes / 2).floor());

    final earnedGold =
        (estimatedKills *
                (6 + chapter) *
                tuning.offlineRewardMultiplier *
                clanGoldBonusMultiplier *
                ascensionOfflineMultiplier)
            .round();
    final earnedHammers = estimatedKills;

    gold += earnedGold;
    hammers += earnedHammers;

    lastOfflineReward = OfflineReward(
      gold: earnedGold,
      hammers: earnedHammers,
      minutes: clampedMinutes,
    );
  }

  bool startExpedition(int slotIndex, String expeditionId) {
    if (slotIndex < 0 || slotIndex >= expeditionSlotCount) return false;
    if (expeditionSlots[slotIndex] != null &&
        !expeditionSlots[slotIndex]!.claimed) {
      if (!expeditionSlots[slotIndex]!.isComplete) return false;
    }

    final def = expeditionDefinitions.firstWhere(
      (d) => d.id == expeditionId,
      orElse: () => expeditionDefinitions.first,
    );

    final completesAt = DateTime.now().add(Duration(hours: def.durationHours));
    expeditionSlots[slotIndex] = ActiveExpedition(
      slotIndex: slotIndex,
      expeditionId: expeditionId,
      completesAt: completesAt,
    );

    _save();
    notifyListeners();
    return true;
  }

  bool claimExpeditionReward(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= expeditionSlotCount) return false;
    final expedition = expeditionSlots[slotIndex];
    if (expedition == null || !expedition.isComplete || expedition.claimed) {
      return false;
    }

    final def = expeditionDefinitions.firstWhere(
      (d) => d.id == expedition.expeditionId,
      orElse: () => expeditionDefinitions.first,
    );

    final progression = 1 + (chapter ~/ 2) + (prestigeLevel ~/ 5);
    gold += _scaledGoldReward((def.baseGold * progression / 2).round());
    hammers += (def.baseHammers * progression / 2).round();
    if (def.baseShards > 0) {
      forgeShards += _scaledShardReward(
        (def.baseShards * progression / 3).round(),
      );
    }

    if (_random.nextDouble() < def.itemDropChance) {
      final tier = _random.nextDouble() < 0.2
          ? ItemTier.rare
          : ItemTier.uncommon;
      final item = _craftItemWithTier(tier);
      inventory.add(item);
    }

    expedition.claimed = true;
    _save();
    notifyListeners();
    return true;
  }

  void clearExpeditionSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= expeditionSlotCount) return;
    final expedition = expeditionSlots[slotIndex];
    if (expedition == null || (expedition.isComplete && expedition.claimed)) {
      expeditionSlots[slotIndex] = null;
      _save();
      notifyListeners();
    }
  }

  List<ActiveExpedition?> get currentExpeditions =>
      List.unmodifiable(expeditionSlots);

  List<CraftingRecipe> get knownRecipes {
    return craftingRecipes
        .where((r) => discoveredRecipes.contains(r.id))
        .toList(growable: false);
  }

  bool canCraftRecipe(String recipeId) {
    final recipe = _findRecipe(recipeId);
    if (recipe == null || !discoveredRecipes.contains(recipeId)) return false;
    if (gold < recipe.goldCost || hammers < recipe.hammerCost) return false;
    return _checkIngredients(recipe).isEmpty;
  }

  List<RecipeIngredient> getMissingIngredients(String recipeId) {
    final recipe = _findRecipe(recipeId);
    if (recipe == null) return [];
    return _checkIngredients(recipe);
  }

  List<RecipeIngredient> _checkIngredients(CraftingRecipe recipe) {
    final missing = <RecipeIngredient>[];
    for (final ingredient in recipe.ingredients) {
      final available = inventory
          .where(
            (item) =>
                item.slot == ingredient.slot &&
                item.tier.index >= ingredient.minTier.index &&
                !isEquipped(item) &&
                !item.isLocked,
          )
          .length;
      if (available < ingredient.count) {
        missing.add(ingredient);
      }
    }
    return missing;
  }

  GameItem? craftByRecipe(String recipeId) {
    final recipe = _findRecipe(recipeId);
    if (recipe == null || !canCraftRecipe(recipeId)) return null;

    for (final ingredient in recipe.ingredients) {
      var toConsume = ingredient.count;
      final candidates = inventory
          .where(
            (item) =>
                item.slot == ingredient.slot &&
                item.tier.index >= ingredient.minTier.index &&
                !isEquipped(item) &&
                !item.isLocked,
          )
          .toList();

      candidates.sort((a, b) => a.power.compareTo(b.power));
      for (final item in candidates) {
        if (toConsume <= 0) break;
        inventory.removeWhere((i) => i.id == item.id);
        equippedBySlot.removeWhere((_, v) => v == item.id);
        toConsume -= 1;
      }
    }

    gold -= recipe.goldCost;
    hammers -= recipe.hammerCost;

    final result = _craftItemWithTier(recipe.resultTier);
    inventory.add(result);
    craftedItems += 1;
    _save();
    notifyListeners();
    return result;
  }

  CraftingRecipe? _findRecipe(String recipeId) {
    try {
      return craftingRecipes.firstWhere((r) => r.id == recipeId);
    } catch (_) {
      return null;
    }
  }

  void _tryDropRecipe() {
    for (final recipe in craftingRecipes) {
      if (discoveredRecipes.contains(recipe.id)) continue;
      if (_random.nextDouble() < recipe.dropChance * (1 + chapter * 0.1)) {
        discoveredRecipes.add(recipe.id);
        lastCombatEvent =
            'Neues Rezept gefunden: ${localeCode == 'de' ? recipe.nameDe : recipe.nameEn}!';
      }
    }
  }

  Map<String, dynamic> _buildSaveMap() {
    return {
      'playerName': playerName,
      'darkModeEnabled': darkModeEnabled,
      'targetFps': targetFps,
      'showCombatLog': showCombatLog,
      'reducedEffects': reducedEffects,
      'tutorialCompleted': tutorialCompleted,
      'gold': gold,
      'hammers': hammers,
      'forgeLevel': forgeLevel,
      'prestigeLevel': prestigeLevel,
      'forgeShards': forgeShards,
      'chapter': chapter,
      'stage': stage,
      'killsInStage': killsInStage,
      'totalKills': totalKills,
      'craftedItems': craftedItems,
      'bossDefeats': bossDefeats,
      'questCycle': questCycle,
      'questKillsClaimed': questKillsClaimed,
      'questCraftsClaimed': questCraftsClaimed,
      'questBossClaimed': questBossClaimed,
      'talentAttackLevel': talentAttackLevel,
      'talentVitalityLevel': talentVitalityLevel,
      'talentForgeLevel': talentForgeLevel,
      'skillStrikeLevel': skillStrikeLevel,
      'skillWhirlLevel': skillWhirlLevel,
      'skillFocusLevel': skillFocusLevel,
      'shopSpeedLevel': shopSpeedLevel,
      'shopHammerLevel': shopHammerLevel,
      'shopRecoveryLevel': shopRecoveryLevel,
      'shopManualRefreshes': shopManualRefreshes,
      'healingFlasks': healingFlasks,
      'berserkFlasks': berserkFlasks,
      'flaskCooldownRemaining': flaskCooldownRemaining,
      'berserkRemaining': berserkRemaining,
      'combatStance': combatStance.name,
      'shopRefreshAtMillis': _shopRefreshAt.millisecondsSinceEpoch,
      'dailyOfferDateKey': _dailyOfferDateKey,
      'deaths': deaths,
      'playerHp': playerHp,
      'autoSellEnabled': autoSellEnabled,
      'autoSellKeepFromTier': autoSellKeepFromTier.name,
      'autoLockEnabled': autoLockEnabled,
      'autoLockFromTier': autoLockFromTier.name,
      'tuning': tuning.toJson(),
      'discoveredSetSlots': discoveredSetSlots.toList(growable: false),
      'claimedSetRewards': claimedSetRewards
          .map((setId) => setId.name)
          .toList(growable: false),
      'claimedAchievements': claimedAchievements.toList(growable: false),
      'autoSkillSlots': autoSkillSlots.toList(growable: false),
      'shopOffers': _shopOffers
          .map((offer) => offer.toJson())
          .toList(growable: false),
      'dailyShopOffers': _dailyShopOffers
          .map((offer) => offer.toJson())
          .toList(growable: false),
      'inventory': inventory
          .map((item) => item.toJson())
          .toList(growable: false),
      'equippedBySlot': equippedBySlot.map(
        (slot, id) => MapEntry(slot.name, id),
      ),
      'loadoutPresets': loadoutPresets.map(
        (index, preset) => MapEntry(
          index.toString(),
          preset.map((slot, id) => MapEntry(slot.name, id)),
        ),
      ),
      'dungeonState': _dungeonController.toJson(),
      'lastActiveMillis': DateTime.now().millisecondsSinceEpoch,
      'expeditionSlots': expeditionSlots
          .map((e) => e?.toJson())
          .toList(growable: false),
      'discoveredRecipes': discoveredRecipes.toList(growable: false),
      'unlockedAscensionNodes': unlockedAscensionNodes.toList(growable: false),
      'ascensionPoints': ascensionPoints,
      'activePet': activePet?.toJson(),
      'runeInventory': runeInventory
          .map((r) => r.toJson())
          .toList(growable: false),
      'loginStreakDays': loginStreakDays,
      'lastLoginDateKey': _lastLoginDateKey,
    };
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _buildSaveMap();
    await prefs.setString(_saveKey, jsonEncode(map));

    // Periodic cloud auto-save: upload at most once every 5 minutes.
    if (ApiService.instance.isLoggedIn) {
      final now = DateTime.now();
      if (_lastCloudSaveAt == null ||
          now.difference(_lastCloudSaveAt!) >= const Duration(minutes: 5)) {
        _lastCloudSaveAt = now;
        ApiService.instance.uploadSave(map).ignore();
        ApiService.instance
            .uploadStats(
              totalStrength: totalStrength,
              prestigeLevel: prestigeLevel,
              chapter: chapter,
            )
            .ignore();
      }
    }
  }

  // ------------------------------------------------------------------ //
  //  Public Cloud Save / Load
  // ------------------------------------------------------------------ //

  /// Manually save the current game state to the cloud.
  /// Updates [cloudSyncStatus] and notifies listeners.
  Future<void> cloudSave() async {
    if (!ApiService.instance.isLoggedIn) return;
    cloudSyncStatus = 'saving';
    notifyListeners();
    try {
      await _save();
      final map = _buildSaveMap();
      final ok = await ApiService.instance.uploadSave(map);
      if (ok) {
        _lastCloudSaveAt = DateTime.now();
        cloudSyncStatus = 'saved';
      } else {
        cloudSyncStatus = 'error';
      }
    } catch (_) {
      cloudSyncStatus = 'error';
    }
    notifyListeners();
  }

  /// Manually load the game state from the cloud.
  /// If the cloud save is newer than the local save, it is applied.
  /// Updates [cloudSyncStatus] and notifies listeners.
  Future<void> cloudLoad() async {
    if (!ApiService.instance.isLoggedIn) return;
    cloudSyncStatus = 'loading';
    notifyListeners();
    try {
      final cloudData = await ApiService.instance.downloadSave();
      if (cloudData == null) {
        cloudSyncStatus = 'error';
        notifyListeners();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saveKey, jsonEncode(cloudData));
      await _load();
      _spawnEnemy();
      playerHp = playerHp.clamp(1.0, maxPlayerHp).toDouble();
      cloudSyncStatus = 'loaded';
    } catch (_) {
      cloudSyncStatus = 'error';
    }
    notifyListeners();
  }

  /// Fetch and apply pending admin rewards from the server.
  /// Runs silently in the background — never throws.
  Future<void> _claimPendingRewards() async {
    try {
      final rewards = await ApiService.instance.claimPendingRewards();
      if (rewards.isEmpty) return;
      var changed = false;
      for (final r in rewards) {
        final type = r['reward_type'] as String? ?? '';
        if (type == 'gold') {
          final amount = (r['amount'] as num?)?.toInt() ?? 0;
          if (amount > 0) {
            gold += amount;
            changed = true;
          }
        }
        // item rewards: find blueprint in catalog and create a game item
        // (currently not implemented — blueprint-based items need crafting logic)
      }
      if (changed) {
        _save();
        notifyListeners();
      }
    } catch (_) {
      // silently fail
    }
  }

  /// Called once on startup to auto-load cloud save if it is newer.
  Future<void> _syncCloudOnStartup() async {
    try {
      final cloudData = await ApiService.instance.downloadSave();
      if (cloudData == null) return;

      final cloudMillis = cloudData['lastActiveMillis'] as int? ?? 0;
      final prefs = await SharedPreferences.getInstance();
      final localRaw = prefs.getString(_saveKey);
      int localMillis = 0;
      if (localRaw != null) {
        final localMap = jsonDecode(localRaw) as Map<String, dynamic>;
        localMillis = localMap['lastActiveMillis'] as int? ?? 0;
      }

      if (cloudMillis > localMillis) {
        await prefs.setString(_saveKey, jsonEncode(cloudData));
        await _load();
      }
    } catch (_) {
      // Silently ignore startup cloud sync errors.
    }
  }
}
