enum ItemSlot { weapon, armor, helm, gloves, boots, ring }

enum ItemTier { common, uncommon, rare, epic, legendary }

enum ItemSet { ember, tide, storm }

enum PetType { wolf, phoenix, golem }

enum RuneType { fire, ice, life, speed, gold }

enum EnemyArchetype { brute, assassin, poisoner, guardian }

enum QuestType { kills, crafts, bosses }

enum TalentType { attack, vitality, forge }

enum ShopUpgradeType { speed, hammer, recovery }

enum BossPattern { berserker, venom, titan }

enum CombatStance { balanced, aggressive, defensive }

enum FlaskType { healing, berserk }

enum ShopOfferKind {
  speedUpgrade,
  hammerUpgrade,
  recoveryUpgrade,
  hammerPack,
  shardCache,
  healingFlask,
  berserkFlask,
}

enum AchievementMetric {
  totalKills,
  craftedItems,
  bossDefeats,
  chapter,
  forgeLevel,
  prestigeLevel,
  totalStrength,
  questCycle,
}

class PetState {
  PetState({
    required this.type,
    this.level = 1,
    this.xp = 0,
    this.isActive = false,
  });

  final PetType type;
  final int level;
  final int xp;
  final bool isActive;

  PetState copyWith({PetType? type, int? level, int? xp, bool? isActive}) {
    return PetState(
      type: type ?? this.type,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'level': level, 'xp': xp, 'isActive': isActive};
  }

  factory PetState.fromJson(Map<String, dynamic> json) {
    return PetState(
      type: PetType.values.firstWhere(
        (t) => t.name == (json['type'] as String? ?? PetType.wolf.name),
        orElse: () => PetType.wolf,
      ),
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? false,
    );
  }
}

class EquipDiff {
  const EquipDiff({required this.currentPower, required this.newPower});

  final int currentPower;
  final int newPower;

  int get delta => newPower - currentPower;
}

class Rune {
  const Rune({
    required this.type,
    required this.tier,
    required this.bonusValue,
  });

  final RuneType type;
  final int tier;
  final double bonusValue;

  Map<String, dynamic> toJson() {
    return {'type': type.name, 'tier': tier, 'bonusValue': bonusValue};
  }

  factory Rune.fromJson(Map<String, dynamic> json) {
    return Rune(
      type: RuneType.values.firstWhere(
        (t) => t.name == (json['type'] as String? ?? RuneType.fire.name),
        orElse: () => RuneType.fire,
      ),
      tier: json['tier'] as int? ?? 1,
      bonusValue: (json['bonusValue'] as num?)?.toDouble() ?? 0.05,
    );
  }
}

class StreakReward {
  const StreakReward({
    required this.gold,
    required this.hammers,
    required this.shards,
    this.isSpecial = false,
  });

  final int gold;
  final int hammers;
  final int shards;
  final bool isSpecial;
}

class QuestStateView {
  const QuestStateView({
    required this.type,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
    required this.rewardGold,
    required this.rewardHammers,
    required this.rewardShards,
    required this.claimed,
    required this.canClaim,
  });

  final QuestType type;
  final String title;
  final String description;
  final int progress;
  final int target;
  final int rewardGold;
  final int rewardHammers;
  final int rewardShards;
  final bool claimed;
  final bool canClaim;
}

class SetCollectionView {
  const SetCollectionView({
    required this.setId,
    required this.ownedCount,
    required this.totalCount,
    required this.missingSlots,
    required this.rewardGold,
    required this.rewardShards,
    required this.rewardClaimed,
    required this.rewardClaimable,
  });

  final ItemSet setId;
  final int ownedCount;
  final int totalCount;
  final List<ItemSlot> missingSlots;
  final int rewardGold;
  final int rewardShards;
  final bool rewardClaimed;
  final bool rewardClaimable;
}

class ShopOffer {
  const ShopOffer({
    required this.id,
    required this.kind,
    required this.cost,
    required this.stock,
    required this.amount,
    this.isDaily = false,
    this.discountPercent = 0,
  });

  final String id;
  final ShopOfferKind kind;
  final int cost;
  final int stock;
  final int amount;
  final bool isDaily;
  final int discountPercent;

  ShopOffer copyWith({
    int? cost,
    int? stock,
    int? amount,
    bool? isDaily,
    int? discountPercent,
  }) {
    return ShopOffer(
      id: id,
      kind: kind,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      amount: amount ?? this.amount,
      isDaily: isDaily ?? this.isDaily,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.name,
      'cost': cost,
      'stock': stock,
      'amount': amount,
      'isDaily': isDaily,
      'discountPercent': discountPercent,
    };
  }

  factory ShopOffer.fromJson(Map<String, dynamic> json) {
    return ShopOffer(
      id: json['id'] as String,
      kind: ShopOfferKind.values.firstWhere(
        (entry) =>
            entry.name ==
            (json['kind'] as String? ?? ShopOfferKind.hammerPack.name),
        orElse: () => ShopOfferKind.hammerPack,
      ),
      cost: json['cost'] as int? ?? 0,
      stock: json['stock'] as int? ?? 0,
      amount: json['amount'] as int? ?? 1,
      isDaily: json['isDaily'] as bool? ?? false,
      discountPercent: json['discountPercent'] as int? ?? 0,
    );
  }
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
    required this.rewardGold,
    required this.rewardShards,
  });

  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int target;
  final int rewardGold;
  final int rewardShards;
}

class AchievementView {
  const AchievementView({
    required this.definition,
    required this.progress,
    required this.claimed,
    required this.canClaim,
  });

  final AchievementDefinition definition;
  final int progress;
  final bool claimed;
  final bool canClaim;
}

class GameItem {
  const GameItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.tier,
    required this.setId,
    required this.power,
    required this.sellValue,
    this.iconPath = 'assets/icons/forge.svg',
    this.isLocked = false,
    this.enchantments = const [],
  });

  final String id;
  final String name;
  final ItemSlot slot;
  final ItemTier tier;
  final ItemSet setId;
  final int power;
  final int sellValue;
  final String iconPath;
  final bool isLocked;
  final List<Rune> enchantments;

  GameItem copyWith({
    String? id,
    String? name,
    ItemSlot? slot,
    ItemTier? tier,
    ItemSet? setId,
    int? power,
    int? sellValue,
    String? iconPath,
    bool? isLocked,
    List<Rune>? enchantments,
  }) {
    return GameItem(
      id: id ?? this.id,
      name: name ?? this.name,
      slot: slot ?? this.slot,
      tier: tier ?? this.tier,
      setId: setId ?? this.setId,
      power: power ?? this.power,
      sellValue: sellValue ?? this.sellValue,
      iconPath: iconPath ?? this.iconPath,
      isLocked: isLocked ?? this.isLocked,
      enchantments: enchantments ?? this.enchantments,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slot': slot.name,
      'tier': tier.name,
      'setId': setId.name,
      'power': power,
      'sellValue': sellValue,
      'iconPath': iconPath,
      'isLocked': isLocked,
      'enchantments': enchantments
          .map((r) => r.toJson())
          .toList(growable: false),
    };
  }

  factory GameItem.fromJson(Map<String, dynamic> json) {
    final enchantmentsRaw = json['enchantments'] as List<dynamic>? ?? [];
    return GameItem(
      id: json['id'] as String,
      name: json['name'] as String,
      slot: ItemSlot.values.firstWhere((slot) => slot.name == json['slot']),
      tier: ItemTier.values.firstWhere((tier) => tier.name == json['tier']),
      setId: ItemSet.values.firstWhere(
        (setId) =>
            setId.name == (json['setId'] as String? ?? ItemSet.ember.name),
      ),
      power: json['power'] as int,
      sellValue: json['sellValue'] as int,
      iconPath: json['iconPath'] as String? ?? 'assets/icons/forge.svg',
      isLocked: json['isLocked'] as bool? ?? false,
      enchantments: enchantmentsRaw
          .map((e) => Rune.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
    );
  }
}

class SkillDefinition {
  const SkillDefinition({
    required this.id,
    required this.labelKey,
    required this.cooldownSeconds,
    required this.damageMultiplier,
    this.bonusHits = 0,
  });

  final String id;
  final String labelKey;
  final double cooldownSeconds;
  final double damageMultiplier;
  final int bonusHits;
}

class SkillState {
  const SkillState({required this.definition, required this.cooldownRemaining});

  final SkillDefinition definition;
  final double cooldownRemaining;

  SkillState copyWith({double? cooldownRemaining}) {
    return SkillState(
      definition: definition,
      cooldownRemaining: cooldownRemaining ?? this.cooldownRemaining,
    );
  }
}

class EnemyState {
  const EnemyState({
    required this.name,
    required this.maxHp,
    required this.hp,
    required this.approach,
    required this.isBoss,
    this.archetype = EnemyArchetype.brute,
    this.bossPattern = BossPattern.berserker,
  });

  final String name;
  final double maxHp;
  final double hp;
  final double approach;
  final bool isBoss;
  final EnemyArchetype archetype;
  final BossPattern bossPattern;

  EnemyState copyWith({
    String? name,
    double? maxHp,
    double? hp,
    double? approach,
    bool? isBoss,
    EnemyArchetype? archetype,
    BossPattern? bossPattern,
  }) {
    return EnemyState(
      name: name ?? this.name,
      maxHp: maxHp ?? this.maxHp,
      hp: hp ?? this.hp,
      approach: approach ?? this.approach,
      isBoss: isBoss ?? this.isBoss,
      archetype: archetype ?? this.archetype,
      bossPattern: bossPattern ?? this.bossPattern,
    );
  }
}

enum DungeonDifficulty { normal, hard, nightmare }

class DungeonStage {
  const DungeonStage({
    required this.stageNumber,
    required this.bossName,
    required this.bossHp,
    required this.guaranteedRewardTier,
  });
  final int stageNumber;
  final String bossName;
  final double bossHp;
  final ItemTier guaranteedRewardTier;
}

class DungeonRun {
  DungeonRun({
    required this.difficulty,
    required this.currentStage,
    required this.isActive,
    this.startedAt,
    this.isComplete = false,
    this.legendaryDropped = false,
  });
  DungeonDifficulty difficulty;
  int currentStage;
  bool isActive;
  DateTime? startedAt;
  bool isComplete;
  bool legendaryDropped;

  Map<String, dynamic> toJson() => {
    'difficulty': difficulty.name,
    'currentStage': currentStage,
    'isActive': isActive,
    'startedAt': startedAt?.millisecondsSinceEpoch,
    'isComplete': isComplete,
    'legendaryDropped': legendaryDropped,
  };

  factory DungeonRun.fromJson(Map<String, dynamic> json) => DungeonRun(
    difficulty: DungeonDifficulty.values.firstWhere(
      (d) => d.name == (json['difficulty'] as String? ?? 'normal'),
      orElse: () => DungeonDifficulty.normal,
    ),
    currentStage: json['currentStage'] as int? ?? 1,
    isActive: json['isActive'] as bool? ?? false,
    startedAt: json['startedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int)
        : null,
    isComplete: json['isComplete'] as bool? ?? false,
    legendaryDropped: json['legendaryDropped'] as bool? ?? false,
  );
}

class DungeonReward {
  const DungeonReward({
    required this.gold,
    required this.hammers,
    required this.shards,
    required this.items,
  });
  final int gold;
  final int hammers;
  final int shards;
  final List<GameItem> items;
}

enum ExpeditionType { hunt, scavenge, raid }

class ExpeditionDefinition {
  const ExpeditionDefinition({
    required this.id,
    required this.type,
    required this.name,
    required this.nameDe,
    required this.nameEn,
    required this.durationHours,
    required this.baseGold,
    required this.baseHammers,
    required this.baseShards,
    required this.itemDropChance,
  });

  final String id;
  final ExpeditionType type;
  final String name;
  final String nameDe;
  final String nameEn;
  final int durationHours;
  final int baseGold;
  final int baseHammers;
  final int baseShards;
  final double itemDropChance;
}

class ActiveExpedition {
  ActiveExpedition({
    required this.slotIndex,
    required this.expeditionId,
    required this.completesAt,
    this.claimed = false,
  });

  final int slotIndex;
  final String expeditionId;
  final DateTime completesAt;
  bool claimed;

  bool get isComplete => DateTime.now().isAfter(completesAt);

  Duration get remaining {
    final diff = completesAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
    'slotIndex': slotIndex,
    'expeditionId': expeditionId,
    'completesAtMillis': completesAt.millisecondsSinceEpoch,
    'claimed': claimed,
  };

  factory ActiveExpedition.fromJson(Map<String, dynamic> json) =>
      ActiveExpedition(
        slotIndex: json['slotIndex'] as int? ?? 0,
        expeditionId: json['expeditionId'] as String? ?? '',
        completesAt: DateTime.fromMillisecondsSinceEpoch(
          json['completesAtMillis'] as int? ?? 0,
        ),
        claimed: json['claimed'] as bool? ?? false,
      );
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.slot,
    required this.minTier,
    required this.count,
  });

  final ItemSlot slot;
  final ItemTier minTier;
  final int count;

  Map<String, dynamic> toJson() => {
    'slot': slot.name,
    'minTier': minTier.name,
    'count': count,
  };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        slot: ItemSlot.values.firstWhere(
          (s) => s.name == (json['slot'] as String? ?? 'weapon'),
          orElse: () => ItemSlot.weapon,
        ),
        minTier: ItemTier.values.firstWhere(
          (t) => t.name == (json['minTier'] as String? ?? 'common'),
          orElse: () => ItemTier.common,
        ),
        count: json['count'] as int? ?? 1,
      );
}

class CraftingRecipe {
  const CraftingRecipe({
    required this.id,
    required this.nameDe,
    required this.nameEn,
    required this.descDe,
    required this.descEn,
    required this.ingredients,
    required this.resultSlot,
    required this.resultTier,
    required this.goldCost,
    required this.hammerCost,
    required this.dropChance,
  });

  final String id;
  final String nameDe;
  final String nameEn;
  final String descDe;
  final String descEn;
  final List<RecipeIngredient> ingredients;
  final ItemSlot resultSlot;
  final ItemTier resultTier;
  final int goldCost;
  final int hammerCost;
  final double dropChance;
}

enum AscensionPath { warrior, smith, rogue }

enum AscensionBonusType {
  attackMultiplier,
  hpMultiplier,
  skillCooldownReduction,
  forgeBonusChance,
  hammerDropChance,
  itemPowerBonus,
  goldMultiplier,
  dropRateBonus,
  offlineRewardMultiplier,
}

class AscensionNode {
  const AscensionNode({
    required this.id,
    required this.path,
    required this.nameDe,
    required this.nameEn,
    required this.descDe,
    required this.descEn,
    required this.cost,
    required this.bonusType,
    required this.bonusValue,
    this.requiredNodeId,
    required this.tier,
  });

  final String id;
  final AscensionPath path;
  final String nameDe;
  final String nameEn;
  final String descDe;
  final String descEn;
  final int cost;
  final AscensionBonusType bonusType;
  final double bonusValue;
  final String? requiredNodeId;
  final int tier;
}
