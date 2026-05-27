# Sprint 1B — Game Polish

> Sprint Goal: Pet/Companion, Set-Boni, Enchantment, Daily-Login-Streak, Smart-Equip-Preview und Push-Notifications
> Branch: `feature/sprint-1b`
> Teams: Nova (Logik) + Milo (UI) — PARALLEL zu Sprint 1A

## Kontext

Sprint 1B läuft gleichzeitig mit Sprint 1A auf einem separaten Branch (`feature/sprint-1b`).
Beide Branches werden separat nach `main` gemergt. 1B berührt überwiegend andere Dateibereiche als 1A,
daher sind Konflikte minimal (hauptsächlich `game_controller.dart` und `models.dart` — sorgfältig mergen!).

---

## Prioritized Task List

| # | Task | Owner | Beschreibung |
|---|------|-------|-------------|
| 1 | Pet-Modelle | Nova | `PetType`, `PetState`, `PetBonus` in models.dart; Bonus-Typen: gold%, damage%, forge% |
| 2 | Pet-Logik | Nova | Pet leveln (Futter = Materialien), Boni in GameController anwenden |
| 3 | Pet-UI | Milo | `PetPanel` Widget: Pet-Animation (einfach), Level-Bar, Boni-Anzeige, Feed-Button |
| 4 | Set-Bonus-System | Nova | Getragene Items prüfen auf vollständiges Set → Bonus-Multiplikatoren aktivieren |
| 5 | Set-Bonus-UI | Milo | In Inventar/Equipment-Screen: Set-Indikator-Icons, Bonus-Text wenn Set aktiv |
| 6 | Enchantment-Modelle | Nova | `Rune`, `RuneType` (Fire/Ice/Life/Speed), `EnchantmentSlot` pro Item |
| 7 | Enchantment-Logik | Nova | Runen droppen, Items enchantenin Schmiede, Stacking-Regeln |
| 8 | Enchantment-UI | Milo | Enchantment-Tab in Schmiede: Runen-Slots, Drag-or-Tap, Vorschau-Boni |
| 9 | Daily-Login-Streak-Logik | Nova | Streak-Zähler, DateTime-Vergleich, Reward-Tabelle (Gold→Hämmer→Scherben→Special) |
| 10 | Daily-Login-UI | Milo | Login-Streak-Dialog beim App-Start: 7-Tage-Kalender, heutige Belohnung hervorheben |
| 11 | Smart-Equip-Preview-Logik | Nova | `calculateEquipDiff(item)` → gibt `StrengthDiff` zurück (±Stärke, ±Stats) |
| 12 | Smart-Equip-UI | Milo | In Item-Detail-Sheet: Vorher/Nachher-Stärke, farbige Diff-Anzeige (+grün/-rot) |
| 13 | Push-Notifications Setup | Nova | `flutter_local_notifications` einbinden, Permissions (Android/iOS/Windows) |
| 14 | Offline-Reward-Notification | Nova | Notification planen wenn Offline-Reward-Cap erreicht wird (max 8h) |
| 15 | Expedition-Done-Notification | Nova | Notification planen wenn Expedition-Timer abläuft (aus Sprint 1A merged) |
| 16 | Save/Load Integration | Nova | Pet, Enchantments, Streak in SharedPrefs persistieren |
| 17 | Lokalisierung | Nova | DE/EN Strings für alle neuen Features in `app_text.dart` |
| 18 | Tests | Nova | Unit-Tests: Set-Bonus-Berechnung, Streak-Logik, Equip-Diff |

---

## Work Schedule

### Phase 1: Pet/Companion (Tasks 1-3)
- Pet-Modelle + Logik
- Pet-Panel UI
- Checkpoint-Commit: `sprint-1b: phase-1 pet-companion`

### Phase 2: Set-Boni (Tasks 4-5)
- Set-Bonus-Berechnung in GameController
- UI-Indikatoren in Equipment-Screen
- Checkpoint-Commit: `sprint-1b: phase-2 set-bonuses`

### Phase 3: Enchantment-System (Tasks 6-8)
- Rune-Modelle + Drop-System
- Enchantment in Schmiede integrieren
- Enchantment-UI
- Checkpoint-Commit: `sprint-1b: phase-3 enchantments`

### Phase 4: Daily-Login-Streak (Tasks 9-10)
- Streak-Logik + Reward-Tabelle
- Login-Streak-Dialog
- Checkpoint-Commit: `sprint-1b: phase-4 login-streak`

### Phase 5: Smart-Equip-Preview (Tasks 11-12)
- `calculateEquipDiff()` im GameController
- Vorher/Nachher-Anzeige im Item-Sheet
- Checkpoint-Commit: `sprint-1b: phase-5 smart-equip`

### Phase 6: Push-Notifications (Tasks 13-15)
- Package einbinden + Permissions
- Offline-Reward-Notification
- Expedition-Notification (Platzhalter falls Sprint 1A noch nicht merged)
- Checkpoint-Commit: `sprint-1b: phase-6 notifications`

### Phase 7: Integration & Polish (Tasks 16-18)
- Save/Load für alle neuen Systems
- Lokalisierung vervollständigen
- Tests
- Final-Commit: `sprint-1b: complete`

---

## Success Criteria

- [ ] Pet wird gespeichert, Boni werden aktiv angewendet (messbar in Combat-Stats)
- [ ] Set-Bonus aktiviert sich korrekt wenn vollständiges Set getragen wird
- [ ] Enchantment bleibt nach App-Neustart erhalten
- [ ] Login-Streak zählt nur 1x pro Tag, Reset nach verpasstem Tag
- [ ] Smart-Equip zeigt korrekte ±Stärke-Differenz vor dem Equip
- [ ] Push-Notification erscheint wenn Offline-Reward voll ist (testen mit kurzer Test-Dauer)
- [ ] DE und EN Texte vollständig
- [ ] `flutter analyze` ohne Errors
- [ ] Unit-Tests bestehen

---

## What's NOT in This Sprint

| Feature | Grund |
|---------|-------|
| Pet-PVP | Zu komplex, Sprint 3+ |
| Enchantment-Trading | Backend nötig, Sprint 2+ |
| Login-Streak Server-Sync | Backend kommt Sprint 2 |
| iOS Push-Notifications (APNs) | App ist primär Android/Windows |

---

## Agent Prompt

```
Lies PROJECT_BRIEF.md, dann lies docs/sprint-1b/plan.md. Führe Sprint 1B aus.

Du bist Nova (Flutter Dev) und Milo (UI/Art). Sprint 1B läuft PARALLEL zu Sprint 1A.

Zuerst:
  git pull origin main
  git checkout -b feature/sprint-1b

WICHTIG: Sprint 1A läuft parallel auf feature/sprint-1a. Berühre NICHT dieselben
Funktionen die Sprint 1A implementiert (Dungeons, Expeditionen, Rezepte, Ascension).
Bei Konflikten in models.dart oder game_controller.dart: beide Änderungen zusammenführen.

Implementiere alle Tasks in der Reihenfolge der Work Schedule Phasen.
Nach jeder Phase: Checkpoint-Commit mit der angegebenen Message.
Aktualisiere docs/sprint-1b/progress.md nach jeder Phase.

Für Push-Notifications: `flutter_local_notifications: ^17.x` zu pubspec.yaml hinzufügen.
AndroidManifest.xml Permissions eintragen. Notification-Channels für Android 8+ erstellen.

Am Ende: git push origin feature/sprint-1b und PR erstellen.
```

---

## Technische Hinweise

**Pet-System Design:**
```dart
enum PetType { wolf, phoenix, golem }  // wolf=gold%, phoenix=forge%, golem=defense%
class PetState { PetType type; int level; int xp; bool isActive; }
// Level 1-20, XP via Materialien füttern, Boni: level * 0.5% pro Kategorie
```

**Set-Bonus Design:**
```dart
// In GameController: Set prüfen beim Item equip/unequip
// Ember-Set (6-teilig): +20% Schmiedechance
// Tide-Set (6-teilig): +15% Trank-Effektivität  
// Storm-Set (6-teilig): +25% Angriffs-Speed
// Teilboni: 2/4/6 Items = gestaffelte Boni
```

**Enchantment Design:**
```dart
enum RuneType { fire, ice, life, speed, gold }
class Rune { RuneType type; int tier; double bonusValue; }
// Items haben maximal 2 Enchantment-Slots
// Runen droppen aus Gegnern (seltener als Items)
// Tier 1-3 Runen, höhere Tiere = stärkerer Bonus
```

**Smart-Equip-Preview:**
```dart
class EquipDiff { int currentPower; int newPower; int delta; /* delta > 0 = Verbesserung */ }
EquipDiff calculateEquipDiff(GameItem item) { ... }
// In Item-Detail-Sheet: "+42 Stärke" (grün) oder "-10 Stärke" (rot)
```

**Push-Notifications (flutter_local_notifications):**
```dart
// Notification-IDs: 1 = offline_reward_full, 2-4 = expedition_slot_0/1/2
// Beim Starten der Expedition: scheduleNotification(id, completesAt)
// Beim Claim: cancelNotification(id)
// Offline-Reward: scheduleNotification(1, now + maxOfflineDuration)
```
