# Changelog

All notable changes to Idle Forge are documented here.

## [Unreleased]

### Added
- **Dungeon-System Phase 1**: Vollständige Dungeon-Infrastruktur implementiert
  - `DungeonDifficulty` Enum (Normal / Hard / Nightmare) in `models.dart`
  - `DungeonStage` Model (5 Stages mit Boss-Namen, HP, garantiertem Reward-Tier)
  - `DungeonRun` Model mit JSON-Serialisierung/Deserialisierung
  - `DungeonReward` Model (Gold, Hämmer, Scherben, Items)
  - `DungeonController` mit Energie-Regeneration (1 Energie alle 30 Min.), Start/Advance/Build-Reward-Logik
  - `GameController`: Getter `dungeonController`, `dungeonEnergy`, `dungeonMaxEnergy`, `activeDungeonRun`
  - `GameController`: Methoden `startDungeon`, `advanceDungeonStage`, `defeatDungeonStage`, `claimDungeonReward`, `abandonDungeon`, `_craftItemWithTier`
  - Persistenz: Dungeon-State wird in `_save()`/`_load()` gespeichert und geladen
  - Energie-Tick in `_tick()` integriert
  - Dungeon-Button im Bottom-Menu (`Icons.castle_outlined`)
  - `_showDungeonPanel` Modal: Difficulty-Auswahl, aktiver Run mit Stage-Fortschrittsbalken, Boss-Info, Reward-Claim
  - `_DifficultyCard` Widget mit Farb-Akzent, Energie-Kosten-Anzeige und Start-Button
  - 13 neue Lokalisierungs-Keys in `app_text.dart` (DE + EN)

## [1.0.3] - 2026-05-27

### Added
- Tutorial-System: 8-schrittiges Onboarding beim ersten Spielstart
  (Willkommen, Kampf, Fähigkeiten, Schmiede, Tränke, Inventar, Welt/Quests/Clan, Profil)
- Auto-Skill Sichtbarkeit: aktive Auto-Skills als grüner Subtitle im Kampf-Panel,
  Hinweistext „Lang drücken für Auto-Aktivierung"
- Settings-Panel (Zahnrad-Icon) mit App-Version und Bug-Report-Link nun theme-aware
- In-App Auto-Update: App lädt APK/ZIP direkt herunter und installiert sich selbst
  (Fortschrittsanzeige im Dialog, Android APK-Install via FileProvider, Windows Batch-Update-Script)

### Changed
- Komplettes Dark/Light-Mode-System: `_AppColors`-Extension mit 14 semantischen Farb-Gettern,
  ~120 hardcodierte Farben ersetzt — alle Panels, Sheets und Cards reagieren auf ThemeMode
- Alle deutschen Texte verwenden nun korrekte Umlaute (ä/ö/ü) statt ae/oe/ue (36 Ersetzungen)
- Update-Dialog zeigt jetzt „Aktualisieren"-Button mit Download-Fortschritt statt nur Browser-Link

### Fixed
- Spielername wird beim Schließen des Profil-Sheets (Swipe-Down) automatisch gespeichert
- TextEditingController-Crash behoben: Controller wird nicht mehr manuell disposed,
  verhindert kaskadierende Exceptions bei Sheet-Close-Animation
- Bug-Report-Button funktioniert jetzt auf Android 11+ (fehlende `<queries>` für https-Scheme)

## [1.0.1] - 2026-05-26

### Added
- In-app update checker: on every launch the app compares its version against the latest GitHub Release and shows a download prompt if a newer version is available
- Settings panel (gear icon in the top bar) with current app version display
- Bug report button in settings that opens GitHub Issues directly in the browser
- Internet permission for Android

### Changed
- README rewritten with feature overview, download instructions, and build guide
- `android/local.properties` added to `.gitignore` to keep local paths private

### Fixed
- Release APK now verified to preserve save data (SharedPreferences) across updates

## [1.0.0] - 2026-05-01

### Added
- Initial release
- Idle combat with auto-attacks and skills
- Crafting / forge system
- Shop with daily offers and upgrades
- Achievements & quests
- Offline rewards
- German & English language support
