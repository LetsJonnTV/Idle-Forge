# Sprint 1B — Progress Tracker

> Falls Kontext überläuft, neuen Chat starten:
> "Lies PROJECT_BRIEF.md und docs/sprint-1b/progress.md. Mache weiter wo aufgehört wurde."

## Task Status

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Pet-Modelle | ✅ Done | `PetType`, `PetState` enums/classes in models.dart |
| 2 | Pet-Logik | ✅ Done | `adoptPet()`, `feedPet()`, `petGoldBonus`, `petForgeBonus`, `petDefenseBonus` in game_controller.dart |
| 3 | Pet-UI | ✅ Done | `_PetPanel` widget in profile sheet; shows pet stats, feed button |
| 4 | Set-Bonus-System | ✅ Done | 6-piece set bonuses for Ember/Storm/Tide; `setForgeBonus`, `setAttackSpeedBonus`, `setFlaskEffectBonus`, `setHpBonusMultiplier`, `setAttackBonus` |
| 5 | Set-Bonus-UI | ✅ Done | `activeSetBonuses` list shown in existing Set Bonus display; equip diff badges in inventory cards |
| 6 | Enchantment-Modelle | ✅ Done | `RuneType`, `Rune`, `EquipDiff` in models.dart; `GameItem.enchantments` field + `copyWith()` |
| 7 | Enchantment-Logik | ✅ Done | `enchantItem()`, `removeEnchantment()`, `_generateRune()`, fire/ice/life/speed/gold rune bonuses integrated in getters |
| 8 | Enchantment-UI | ✅ Done | `_RunesPanel` widget in forge panel; shows rune inventory, enchant dialog, remove button |
| 9 | Daily-Login-Streak-Logik | ✅ Done | `checkAndClaimLoginStreak()`, `getStreakReward()`, `loginStreakDays`, `streakClaimedToday` fields |
| 10 | Daily-Login-UI | ✅ Done | `_showStreakDialog()` shown on boot; 7-day calendar display with reward info |
| 11 | Smart-Equip-Preview-Logik | ✅ Done | `calculateEquipDiff()` in game_controller.dart returns `EquipDiff` with `delta` |
| 12 | Smart-Equip-UI | ✅ Done | Equip diff `+N`/`-N`/`±0` shown in inventory item cards (color-coded) |
| 13 | Push-Notifications Setup | ✅ Done | `NotificationService` in `lib/services/notification_service.dart`; Android only (Windows skipped, v17 limitation) |
| 14 | Offline-Reward-Notification | ✅ Done | `scheduleOfflineRewardFull()` in NotificationService; called from `_boot()` |
| 15 | Expedition-Done-Notification | ⬜ Skipped | No expedition system in scope this sprint |
| 16 | Save/Load Integration | ✅ Done | `_save()`/`_load()` extended with pet, rune, streak persistence |
| 17 | Lokalisierung | ✅ Done | ~35 new keys in `app_text.dart` (DE + EN) for all new features |
| 18 | Tests | ✅ Done | `test/sprint_1b_test.dart` — pet, set bonus, streak, equip diff unit tests |

## Bugs Found

| # | Beschreibung | Schwere | Status | Fix |
|---|-------------|---------|--------|-----|
| 1 | `_RunesPanel` enchant dialog lists all inventory items, not just equipped — user can enchant un-equipped items | Low | Open | Acceptable for MVP; item enchants travel with item |
| 2 | `feedPet()` deducts hammer cost inside controller; old UI code in `_PetPanel` also had a direct mutation — fixed: only controller deducts | Medium | Fixed | Removed duplicate deduction from UI |

## Notes

- **models.dart** was completely rewritten after accidental corruption during edit (EnemyState class header mangled).
- **Windows notifications**: `flutter_local_notifications` v17 does not support Windows. Service silently skips on non-Android/iOS platforms.
- **Gold per kill**: `_onEnemyDefeated()` now grants gold per kill (new behavior vs original hammer-only drops). Balancing may need review.
- **flutter analyze**: 0 issues after all changes.
- **`_showSkillTree` formatting**: Fixed concatenation artifact from earlier edit.
- `flutter pub get` completed successfully — added `flutter_local_notifications 17.2.4`, `timezone 0.9.4`, `dbus 0.7.12`.

