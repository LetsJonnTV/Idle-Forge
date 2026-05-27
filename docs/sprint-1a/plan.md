# Sprint 1A — Game Systems

> Sprint Goal: Dungeons, Expeditionen, Crafting-Rezepte und Ascension-Baum implementieren
> Branch: `feature/sprint-1a`
> Teams: Nova (Logik) + Milo (UI)

## Kontext

Alle Features sind rein lokal (kein Backend nötig). Persistenz über SharedPreferences (JSON).
Bestehende Strukturen: `GameController` in `lib/game/game_controller.dart`, Models in `lib/game/models.dart`.

---

## Prioritized Task List

| # | Task | Owner | Beschreibung |
|---|------|-------|-------------|
| 1 | Dungeon-Modelle & Enums | Nova | `DungeonStage`, `DungeonBoss`, `DungeonReward`, `DungeonState` enum in models.dart |
| 2 | DungeonController | Nova | Separater Controller: Stages (1-5), Mini-Bosse, Legendary-Drop am Ende, Energie-System |
| 3 | Dungeon-UI | Milo | `DungeonScreen` Widget: Stage-Progress, Boss-HP-Bar, Loot-Overlay mit Legendary-Animation |
| 4 | Expedition-Modelle | Nova | `Expedition`, `ExpeditionSlot`, Timer-Dauern (1h/4h/12h), Belohnungs-Tabellen |
| 5 | ExpeditionController | Nova | Timer-Logik in GameController integrieren, Offline-Kompatibilität (DateTime-Differenz) |
| 6 | Expedition-UI | Milo | `ExpeditionScreen`: 3 Slots, Timer-Countdown, Held-Icons, Belohnungs-Claim-Animation |
| 7 | Crafting-Rezept-Modelle | Nova | `CraftingRecipe`, `RecipeIngredient`, `RecipeDiscovery`-System in models.dart |
| 8 | Rezept-Logik in GameController | Nova | Rezepte finden (Drop-Chance), Rezepte in SharedPrefs speichern, Crafting-Validierung |
| 9 | Rezept-UI | Milo | Rezept-Buch-Sheet: gefundene/unbekannte Rezepte, Zutaten-Prüfung, Craft-Button |
| 10 | Ascension-Baum-Modelle | Nova | `AscensionNode`, `AscensionTree`, Build-Typen (Krieger/Schmied/Schurke) |
| 11 | Ascension-Logik | Nova | Freischalten nach Prestige, Punkte-System, dauerhafte Boni berechnen |
| 12 | Ascension-UI | Milo | Tree-Visualisierung (Nodes + Connections), Hover-Tooltip, Reset-Button |
| 13 | Save/Load Integration | Nova | Alle neuen States in `_saveToPrefs()` / `_loadFromPrefs()` integrieren |
| 14 | Lokalisierung | Nova | DE/EN Strings für alle neuen Features in `app_text.dart` |
| 15 | Tests | Nova | Unit-Tests: Timer-Logik, Rezept-Drop, Ascension-Punkte |

---

## Work Schedule

### Phase 1: Dungeons (Tasks 1-3)
- Dungeon-Modelle in `models.dart` ergänzen
- `lib/game/dungeon_controller.dart` erstellen
- `DungeonScreen` Widget + Integration in Haupt-Navigation
- Checkpoint-Commit: `sprint-1a: phase-1 dungeons`

### Phase 2: Expeditionen (Tasks 4-6)
- Expedition-Modelle + Timer-Integration in GameController
- `lib/game/expedition_controller.dart` (oder in GameController integrieren)
- `ExpeditionScreen` Widget
- Checkpoint-Commit: `sprint-1a: phase-2 expeditions`

### Phase 3: Crafting-Rezepte (Tasks 7-9)
- Rezept-System in GameController
- Rezept-Buch UI (`RecipeBookSheet`)
- Schmiede-Screen erweitern um Rezept-Crafting-Tab
- Checkpoint-Commit: `sprint-1a: phase-3 recipes`

### Phase 4: Ascension-Baum (Tasks 10-12)
- Ascension-Modelle + Logik
- Tree-UI (Canvas oder Stack-basiert)
- In Prestige-Flow integrieren
- Checkpoint-Commit: `sprint-1a: phase-4 ascension`

### Phase 5: Integration & Polish (Tasks 13-15)
- Save/Load für alle neuen Systems
- Lokalisierung vervollständigen
- Tests schreiben
- Final-Commit: `sprint-1a: complete`

---

## Success Criteria

- [ ] Dungeon mit 5 Stages spielbar, Legendary-Drop am Ende bestätigt
- [ ] Expedition-Timer läuft korrekt, auch nach App-Neustart (Offline-kompatibel)
- [ ] Crafting-Rezept kann gedroppt, angezeigt und genutzt werden
- [ ] Ascension-Baum nach Prestige zugänglich, Boni werden korrekt angewendet
- [ ] Alle neuen States überleben App-Neustart (SharedPrefs)
- [ ] DE und EN Texte vollständig
- [ ] `flutter analyze` ohne Errors
- [ ] Unit-Tests bestehen

---

## What's NOT in This Sprint

| Feature | Grund |
|---------|-------|
| Online-Sync der Expedition | Backend kommt Sprint 2 |
| Dungeon-Leaderboard | Backend kommt Sprint 2 |
| Mehr als 3 Item-Sets | Scope-Kontrolle |
| Dungeon-Editor | Zu komplex, Sprint 3+ |

---

## Agent Prompt

```
Lies PROJECT_BRIEF.md, dann lies docs/sprint-1a/plan.md. Führe Sprint 1A aus.

Du bist Nova (Flutter Dev) und Milo (UI/Art). Arbeitet zusammen als ein Team.

Zuerst:
  git pull origin main
  git checkout -b feature/sprint-1a

Implementiere alle Tasks in der Reihenfolge der Work Schedule Phasen.
Nach jeder Phase: Checkpoint-Commit mit der angegebenen Message.
Aktualisiere docs/sprint-1a/progress.md nach jeder Phase.

Schließe GitHub Issues in Commits: "fix: beschreibung (Fixes #NN)"
Am Ende: git push origin feature/sprint-1a und PR erstellen.
Halte dich an Abschnitte 12-14 von PROJECT_BRIEF.md.

WICHTIG: Kein Rebase. Merge-Commits bevorzugen.
WICHTIG: Alle neuen Features müssen Deutsch UND Englisch unterstützen (app_text.dart).
WICHTIG: SharedPreferences-Kompatibilität — bestehende Save-Daten dürfen nicht zerstört werden.
```

---

## Technische Hinweise

**Dungeon-System Design:**
```dart
// Empfohlene Struktur
enum DungeonDifficulty { normal, hard, nightmare }
class DungeonStage { int stageNumber; String bossName; int bossHp; ItemTier guaranteedReward; }
class DungeonRun { DungeonDifficulty difficulty; int currentStage; bool isActive; DateTime? startedAt; }
```

**Expedition-System Design:**
```dart
// Timer-Logik: DateTime speichern, bei Load prüfen ob abgelaufen
class ActiveExpedition { String expeditionId; DateTime completesAt; bool claimed; }
// 3 Slots: expeditionSlot0, expeditionSlot1, expeditionSlot2 in SharedPrefs als JSON
```

**Ascension-Baum Design:**
- 3 Build-Pfade: Krieger (Kampf-Boni), Schmied (Forge-Boni), Schurke (Gold/Drop-Boni)
- Punkte aus Prestige-Level (1 Punkt pro Prestige)
- Nodes: Kosten 1-3 Punkte, Voraussetzungen beachten
- Permanente Boni: multiplizieren in `BalanceTuning`
