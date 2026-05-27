import 'dart:math';
import 'models.dart';

class DungeonController {
  DungeonController({required this.random});

  final Random random;

  int dungeonEnergy = 10;
  int dungeonMaxEnergy = 10;
  DateTime? dungeonEnergyLastRefreshAt;

  DungeonRun? activeDungeonRun;
  DungeonReward? pendingDungeonReward;

  static const List<DungeonStage> stages = [
    DungeonStage(
      stageNumber: 1,
      bossName: 'Steinspalter',
      bossHp: 200,
      guaranteedRewardTier: ItemTier.uncommon,
    ),
    DungeonStage(
      stageNumber: 2,
      bossName: 'Feuerwächter',
      bossHp: 400,
      guaranteedRewardTier: ItemTier.rare,
    ),
    DungeonStage(
      stageNumber: 3,
      bossName: 'Schattenkönig',
      bossHp: 700,
      guaranteedRewardTier: ItemTier.rare,
    ),
    DungeonStage(
      stageNumber: 4,
      bossName: 'Todeswächter',
      bossHp: 1100,
      guaranteedRewardTier: ItemTier.epic,
    ),
    DungeonStage(
      stageNumber: 5,
      bossName: 'Uraltdämon',
      bossHp: 1800,
      guaranteedRewardTier: ItemTier.legendary,
    ),
  ];

  void tickEnergyRegeneration() {
    final now = DateTime.now();
    final last = dungeonEnergyLastRefreshAt;
    if (dungeonEnergy >= dungeonMaxEnergy) {
      dungeonEnergyLastRefreshAt = now;
      return;
    }
    if (last == null) {
      dungeonEnergyLastRefreshAt = now;
      return;
    }
    final minutesPassed = now.difference(last).inMinutes;
    if (minutesPassed <= 0) return;
    final gained = minutesPassed ~/ 30;
    if (gained <= 0) return;
    dungeonEnergy = min(dungeonMaxEnergy, dungeonEnergy + gained);
    dungeonEnergyLastRefreshAt = last.add(Duration(minutes: gained * 30));
  }

  bool canStartDungeon(DungeonDifficulty difficulty) {
    final cost = energyCostForDifficulty(difficulty);
    return activeDungeonRun == null && dungeonEnergy >= cost && pendingDungeonReward == null;
  }

  int energyCostForDifficulty(DungeonDifficulty difficulty) {
    return switch (difficulty) {
      DungeonDifficulty.normal => 3,
      DungeonDifficulty.hard => 5,
      DungeonDifficulty.nightmare => 8,
    };
  }

  double difficultyMultiplier(DungeonDifficulty difficulty) {
    return switch (difficulty) {
      DungeonDifficulty.normal => 1.0,
      DungeonDifficulty.hard => 1.6,
      DungeonDifficulty.nightmare => 2.5,
    };
  }

  bool startDungeon(DungeonDifficulty difficulty) {
    if (!canStartDungeon(difficulty)) return false;
    dungeonEnergy -= energyCostForDifficulty(difficulty);
    activeDungeonRun = DungeonRun(
      difficulty: difficulty,
      currentStage: 1,
      isActive: true,
      startedAt: DateTime.now(),
    );
    return true;
  }

  DungeonStage? get currentStage {
    final run = activeDungeonRun;
    if (run == null || !run.isActive) return null;
    return stages[run.currentStage - 1];
  }

  double getBossHp(DungeonDifficulty difficulty, int stageIndex) {
    return stages[stageIndex - 1].bossHp * difficultyMultiplier(difficulty);
  }

  DungeonReward buildReward({
    required DungeonDifficulty difficulty,
    required int chapter,
    required int completedStages,
    required GameItem Function(ItemTier tier) itemFactory,
  }) {
    final mult = difficultyMultiplier(difficulty);
    final goldBase = (100 + chapter * 20 + completedStages * 50) * mult;
    final hammersBase = (5 + completedStages * 3) * mult;
    final shardsBase = completedStages >= 5 ? (3 * mult).round() : 0;

    final items = <GameItem>[];
    final lastStage = stages[completedStages - 1];
    items.add(itemFactory(lastStage.guaranteedRewardTier));

    if (completedStages == 5) {
      if (random.nextDouble() < 0.35 + (difficulty.index * 0.15)) {
        items.add(itemFactory(ItemTier.legendary));
      }
    }

    return DungeonReward(
      gold: goldBase.round(),
      hammers: hammersBase.round(),
      shards: shardsBase,
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
    'dungeonEnergy': dungeonEnergy,
    'dungeonEnergyLastRefreshAt': dungeonEnergyLastRefreshAt?.millisecondsSinceEpoch,
    'activeDungeonRun': activeDungeonRun?.toJson(),
  };

  void loadFromJson(Map<String, dynamic> json) {
    dungeonEnergy = json['dungeonEnergy'] as int? ?? 10;
    final energyMs = json['dungeonEnergyLastRefreshAt'] as int?;
    dungeonEnergyLastRefreshAt = energyMs != null
        ? DateTime.fromMillisecondsSinceEpoch(energyMs)
        : null;
    final runJson = json['activeDungeonRun'] as Map<String, dynamic>?;
    activeDungeonRun = runJson != null ? DungeonRun.fromJson(runJson) : null;
  }
}
