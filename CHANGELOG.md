# Changelog

All notable changes to Idle Forge are documented here.


## [2.1.0] - 2026-05-28

### Added
- **Echtes Clan-System**: Vollständig server-gestütztes Clan-System ersetzt die lokale Clan-Logik
  - Neue `ClanScreen`-Seite mit Tab-Navigation: Clan suchen + Einladungen (außerhalb Clan) / Mitglieder + Chat (innerhalb Clan)
  - **Clan gründen**: Kostet 1000 Gold, öffnet Dialog für Name und Beschreibung
  - **Clan beitreten**: Spieler ohne Clan können offenen Clans beitreten
  - **Clan verlassen**: Mit Bestätigungsdialog; Leader übergibt Führung automatisch oder löscht den Clan wenn solo
  - **Clan-Chat**: Echtzeit-ähnlicher Chat mit 5-Sekunden-Polling, Scroll-to-Bottom beim Senden
  - **Einladungssystem**: Clan-Leader kann Spieler per Benutzername einladen; Spieler können annehmen/ablehnen
  - Clan-Menü-Button nur für eingeloggte Spieler sichtbar
- **Neue Backend-Endpunkte**:
  - `GET/POST /api/clans/[id]/chat` — Clan-Chat lesen und schreiben
  - `POST /api/clans/[id]/leave` — Clan verlassen (mit Leadership-Transfer-Logik)
  - `POST /api/clans/[id]/invite` — Spieler einladen (nur Leader)
  - `GET /api/clans/invites` — Ausstehende Einladungen abrufen
  - `PUT /api/clans/invites` — Auf Einladung antworten (annehmen/ablehnen)
  - `GET /api/players/me` — Eigenes Spielerprofil inkl. Clan-ID abrufen
- **Neue DB-Tabellen** (`schema.sql`):
  - `clan_chat` — Clan-Nachrichten mit RLS
  - `clan_invites` — Clan-Einladungen mit Status-Constraints und RLS
- **Neue `ApiService`-Methoden**: `getMyProfile`, `getClanChat`, `sendClanMessage`, `invitePlayerToClan`, `getMyInvites`, `respondToInvite`, `leaveClan`
- **`spendGold(int amount)`** in `GameController` — atomares Gold-Abziehen mit Rückgabewert
- Neue Übersetzungsschlüssel für das Clan-System in DE und EN

### Changed
- **Clan-Menü-Button** navigiert jetzt zur echten `ClanScreen` statt zum alten lokalen Talent-/Clan-Panel
- **`_showTalentTree`** enthält nur noch den Talentzweig (Scherben-Upgrades), keine Clan-Perks mehr
- Tutorial-Text für Clan angepasst: beschreibt jetzt das echte Clan-Beitreten/-Gründen

### Removed
- **Lokale Clan-Logik** vollständig entfernt:
  - `ClanPerkType`-Enum aus `models.dart` entfernt
  - Felder `clanLevel`, `clanXp`, `clanPoints`, `clanWarpathLevel`, `clanBulwarkLevel`, `clanProsperityLevel`, `clanRitualsLevel` aus `GameController` entfernt
  - Methoden `clanPerkLevel`, `clanPerkCost`, `clanPerkTitle`, `clanPerkDescription`, `upgradeClanPerk`, `_gainClanXp` entfernt
  - Alle ~15 `_gainClanXp()`-Aufrufe entfernt
  - Clan-Felder aus Save/Load-Maps entfernt (alte Spielstände werden ignoriert, rückwärtskompatibel)
  - Clan-Perk-Sektion aus `_showTalentTree` entfernt


## [2.0.1] - 2026-05-28

### Added
- **Cloud-Spielstand**: Eingeloggte Spieler können ihren Spielstand in der Cloud speichern und laden
  - Neuer Backend-Endpunkt `GET /api/saves` (Laden) und `PUT /api/saves` (Speichern) mit JWT-Auth
  - Neue Supabase-Tabelle `game_saves` (`player_id`, `save_data JSONB`, `updated_at`)
  - **Auto-Sync beim Start**: Cloud-Stand wird automatisch geladen, wenn er neuer ist als der lokale Stand
  - **Auto-Cloud-Save**: Spielstand wird automatisch alle 5 Minuten in die Cloud hochgeladen (wenn eingeloggt)
  - **Manueller Cloud-Speicher**: „In Cloud speichern" und „Aus Cloud laden" Buttons im Profil-Panel
  - Statusanzeige im Profil-Panel (Wird gespeichert… / Erfolgreich / Fehler) mit Spinner
  - Übersetzungen für alle Cloud-Save-Texte in DE und EN

### Changed
- Menü-Buttons im Kompaktmodus (Smartphone) werden jetzt als wischbares **PageView** angezeigt — immer 2 Buttons nebeneinander, nach links wischen für die nächsten 2
- Punkte-Indikatoren unter dem Menü zeigen die aktuelle Seite an und sind antippbar
- Spielername wird beim Login automatisch auf den Account-Namen gesetzt und kann danach nicht mehr manuell geändert werden (Namensfeld gesperrt, Speichern-Button ausgeblendet)
- Begleiter aus den Profil-/User-Einstellungen entfernt — er ist jetzt ausschließlich über die eigene **Haustier**-Menükachel erreichbar

### Fixed
- Social-Panel (Online-Button) ist jetzt durch Login-Gating gesichert — Zugriff ohne Account wird sofort zur Auth-Seite geleitet
- Neue Panels (Dungeon, Expedition, Ascension, Rezepte, Haustier) haben jetzt einen sichtbaren Drag-Handle und können nach unten gewischt werden
- SVG-Icons für alle neuen Menü-Buttons (Dungeon, Haustier, Expedition, Rezepte, Aufstieg, Online)
- Supabase-Backend nutzt nun `SUPABASE_SERVICE_ROLE_KEY` — alle Schreiboperationen (PVP, Koop, Freunde) funktionieren zuverlässig
- Fehlende deutsche Übersetzungen in Koop- und PVP-Bildschirm ergänzt

## [2.0.0] - 2026-05-27

### Added
- **Dungeon-System**: Mehrstufige Instanzen mit 3 Schwierigkeiten (Normal/Hard/Nightmare), 5 Stages pro Run, Boss-HP-Balken, garantierter Legendary-Reward auf Stage 5, Energie-Regeneration (1 Energie alle 30 Min.)
- **Enchantment-System**: Items mit Runen aufwerten (`enchantItem`) und Verzauberungen entfernen (`removeEnchantment`), bis zu 2 Slots pro Item
- **Crafting-Rezepte**: Gezieltes Craften nach gefundenen Rezepten statt nur Zufallsschmiede
- **Ascension-Baum**: Permanenter Skill-Tree nach Prestige mit Warrior/Smith/Rogue-Builds
- **Pet/Companion**: Begleiter mit passiven Boni (Wolf: Gold, Phoenix: Schmiede), Level-System durch Füttern
- **Set-Boni**: Gleiche Item-Sets tragen gibt Boni (z.B. Ember-Set: +20% Schmiede, Dragon-Set: +25% Angriffsgeschwindigkeit)
- **Expeditionen**: Helden auf Timer-Missionen schicken (1h/4h/12h) für seltene Materialien
- **Tägliche Login-Belohnung**: Streak-System mit eskalierenden Rewards (Gold → Hämmer → Scherben)
- **Schnellausrüstung-Vorschau (Smart Equip)**: Zeigt Stärke-Differenz vor dem Ausrüsten
- **Backend (Sprint 2)**: Next.js API auf Vercel mit Supabase — Auth, Rangliste, Freunde, PVP (async), Koop (Realtime)
- **Social-Panel**: Zugang zu Auth, Rangliste, Freunde, PVP und Koop direkt aus dem Hauptmenü
- **CI/CD-Pipeline**: GitHub Actions baut Android APK und Windows ZIP bei jedem `v*`-Tag; `API_BASE_URL` wird als GitHub Secret injiziert

### Changed
- Branch-Protection für `main`: CI-Check muss bestehen, kein Force-Push/Löschen
- Tag-Ruleset `v*`: Löschen und Force-Push von Release-Tags verhindert
- Next.js von 14.2.5 auf 14.2.30 aktualisiert (Sicherheits-Patch)

### Fixed
- Supabase Relationen-Join gibt Array zurück — Type-Cast in `/api/coop/[id]` und `/api/pvp/[id]` korrigiert
- `dart format` auf alle Dart-Dateien angewendet (17 Dateien)
- `curly_braces_in_flow_control_structures`-Warning in `game_controller.dart` behoben

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
