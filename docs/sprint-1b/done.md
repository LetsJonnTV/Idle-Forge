# Sprint 1B — Done

> PR: https://github.com/LetsJonnTV/Idle-Forge/pull/1
> Branch: `agents/sprint-1b-execution-docs-update-9d54a7bc`
> Commit: `d6a6aba`
> `flutter analyze`: 0 issues

## What Was Built

### Phase 1 — Pet/Companion System ✅
- **Models**: `PetType` (wolf/cat/dragon), `PetState` (type, level, xp, happiness) in `lib/game/models.dart`
- **Controller**: `adoptPet()`, `feedPet()`, `petGoldBonus`, `petForgeBonus`, `petDefenseBonus` in `game_controller.dart`
- **UI**: `_PetPanel` in profile sheet — shows pet icon, level, XP progress, happiness, feed cost

### Phase 2 — Set Bonus Extensions (6-piece) ✅
- All three sets now have 2/4/6-piece tiers
- **Ember**: +10% HP / +8% attack / +20% forge chance
- **Storm**: +10% attack / +12% attack / 25% faster attack interval (×0.75)
- **Tide**: +8% flask effect / +5% HP / +15% flask effectiveness

### Phase 3 — Enchantment/Rune System ✅
- **Models**: `RuneType`, `Rune`, `EquipDiff`; `GameItem.enchantments` (max 2, `const []` default, backward-compatible)
- **Controller**: `_generateRune()`, `enchantItem()`, `removeEnchantment()`, rune effects in all relevant getters
- **UI**: `_RunesPanel` widget in forge sheet — lists rune inventory, enchant-to-item dialog, remove buttons

### Phase 4 — Daily Login Streak ✅
- **Controller**: `checkAndClaimLoginStreak()` on boot, `getStreakReward()` (gold + hammers scale with streak)
- **UI**: `_showStreakDialog()` — 7-day calendar grid, today highlighted, reward claimed message

### Phase 5 — Smart Equip Preview ✅
- **Controller**: `calculateEquipDiff(GameItem)` → `EquipDiff { delta, currentItem }`
- **UI**: Color-coded badge in every inventory card (green `+N`, red `-N`, grey `±0`)

### Phase 6 — Push Notifications ✅
- `lib/services/notification_service.dart` — wraps `flutter_local_notifications 17.2.4`
- Android only (Windows not supported by v17, skipped silently via `Platform.isWindows` guard)
- `AndroidManifest.xml` updated with 3 permissions + 2 BroadcastReceivers

### Phase 7 — Localization ✅
- `lib/l10n/app_text.dart` extended with ~35 new DE + EN strings

### Tests ✅
- `test/sprint_1b_test.dart` — 7 test cases: 6-piece set bonuses ×3, streak ×2, equip diff ×2, pet ×2

## Files Changed

| File | Change |
|------|--------|
| `lib/game/models.dart` | Rewritten — added PetType, RuneType, PetState, Rune, EquipDiff, StreakReward; extended GameItem |
| `lib/game/game_controller.dart` | +250 lines — new fields, getters, methods for all phases; updated save/load |
| `lib/main.dart` | +350 lines — _PetPanel, _RunesPanel, _showStreakDialog, equip diff badges |
| `lib/l10n/app_text.dart` | +35 new localization keys |
| `lib/services/notification_service.dart` | New file |
| `pubspec.yaml` | Added flutter_local_notifications ^17.2.4 |
| `android/app/src/main/AndroidManifest.xml` | Added permissions + receivers |
| `test/sprint_1b_test.dart` | New test file |
| `docs/sprint-1b/progress.md` | All 18 tasks updated |

## Known Issues / Decisions

1. **Gold per kill is new behaviour** — `_onEnemyDefeated()` now grants gold. Previously only hammers dropped. This changes game economy; balancing pass recommended.
2. **Expedition notification skipped** — No expedition system exists yet. Notification hook left as `scheduleOfflineRewardFull()` only.
3. **Rune enchanting non-equipped items** — The `_RunesPanel` lets players enchant any inventory item (not just equipped). Runes travel with the item on equip. Acceptable for MVP.
4. **Windows notifications** — `flutter_local_notifications` v17 dropped Windows support. The service exits early on Windows/macOS/Linux. Upgrade to v21+ when ready, but that will require dependency updates across the project.

## What's Next (Sprint 2 Suggestions)

- Balance review for gold-per-kill economy change
- Expedition system (then wire `scheduleExpeditionDone()` notification)
- Rune crafting UI (combine T1 runes → T2)
- Set badge indicators on equipment grid slots
- Upgrade `flutter_local_notifications` to v21+ for Windows support
