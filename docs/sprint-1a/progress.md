# Sprint 1A — Progress Tracker

> Falls Kontext überläuft, neuen Chat starten:
> "Lies PROJECT_BRIEF.md und docs/sprint-1a/progress.md. Mache weiter wo aufgehört wurde."

## Task Status

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Dungeon-Modelle & Enums | ✅ Done | DungeonDifficulty, DungeonStage, DungeonRun, DungeonReward in models.dart |
| 2 | DungeonController | ✅ Done | lib/game/dungeon_controller.dart: Energie-System, 5 Stages, Reward-Berechnung |
| 3 | Dungeon-UI | ✅ Done | Modal Sheet mit Stage-Bars, Boss-Info, Difficulty-Auswahl |
| 4 | Expedition-Modelle | ✅ Done | ExpeditionType, ExpeditionDefinition, ActiveExpedition in models.dart |
| 5 | ExpeditionController | ✅ Done | 3 Slots, Timer-Logik, Offline-kompatibel (DateTime-Persistenz) |
| 6 | Expedition-UI | ✅ Done | Modal Sheet: 3 Slots, Dropdown-Auswahl, Timer-Countdown, Claim-Button |
| 7 | Crafting-Rezept-Modelle | ✅ Done | RecipeIngredient, CraftingRecipe in models.dart |
| 8 | Rezept-Logik in GameController | ✅ Done | 5 Rezepte, Drop beim Kill, Crafting-Validierung |
| 9 | Rezept-UI | ✅ Done | RecipeBook Sheet: bekannte Rezepte, Zutaten-Prüfung, Craft-Button |
| 10 | Ascension-Baum-Modelle | ✅ Done | AscensionPath, AscensionBonusType, AscensionNode in models.dart |
| 11 | Ascension-Logik | ✅ Done | 15 Nodes, 3 Pfade, Punkte aus Prestige, dauerhafte Boni |
| 12 | Ascension-UI | ✅ Done | Tab-basierte Tree-Darstellung mit Lock/Unlock-Status |
| 13 | Save/Load Integration | ✅ Done | Alle neuen States in _save()/_load() integriert |
| 14 | Lokalisierung | ✅ Done | DE+EN Strings für alle Features in app_text.dart |
| 15 | Tests | ✅ Done | Unit-Tests: Expedition, Recipes, Ascension, Dungeon (28 Tests, alle grün) |

## Bugs Found

| # | Beschreibung | Schwere | Status | Fix |
|---|-------------|---------|--------|-----|
| — | — | — | — | — |

## Notes

Sprint 1A vollständig implementiert.

Neue Dateien:
- lib/game/dungeon_controller.dart
- test/sprint_1a_test.dart

Geänderte Dateien:
- lib/game/models.dart (4 neue Feature-Gruppen von Typen: Dungeon, Expedition, Crafting, Ascension)
- lib/game/game_controller.dart (~300 neue Zeilen: Dungeon-, Expedition-, Recipe-, Ascension-Logik)
- lib/l10n/app_text.dart (~100 neue Strings für alle Features)
- lib/main.dart (~400 neue UI-Zeilen: DungeonSheet, ExpeditionSheet, RecipeBook, AscensionTree)

Test-Ergebnis: 28/28 Tests bestanden (flutter test test/sprint_1a_test.dart)
