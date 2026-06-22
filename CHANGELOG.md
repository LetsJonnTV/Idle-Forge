# Changelog

All notable changes to Idle Forge are documented here.

## [2.1.10] - 2026-06-22

### Fixed
- **Android-Tastatur/Inputs stabilisiert**: Test-Hook `enableFlutterDriverExtension()` aus dem normalen App-Start entfernt, damit Textfelder auf echten Geraeten die Systemtastatur wieder zuverlaessig oeffnen.
- **In-App-Update auf Android robuster gemacht**: APK-Installation auf `ACTION_INSTALL_PACKAGE` umgestellt, fehlende Berechtigung fuer "Unbekannte Apps installieren" wird erkannt und direkt in die passende Systemeinstellung geleitet, plus konkretere Fehlermeldungen statt generischem "Installation fehlgeschlagen".

## [2.1.9] - 2026-06-22

### Fixed
- Release-Vorbereitung: App-Version auf `2.1.9+0` erhöht
- Changelog-Konflikt bereinigt (verbliebene Git-Merge-Marker entfernt)

## [2.1.8] - 2026-06-22

### Added
- **Schnell-Schmiede (Bulk Crafting)**: Neue ×5, ×10 und ×50 Buttons direkt unter dem Forge-Button — schmiedet mehrere Items auf einmal; Auto-Sell wird korrekt angewendet; SnackBar zeigt Zusammenfassung (Anzahl, Inventar, Auto-Sell-Gold)
- **WhatsApp Release-Benachrichtigung**: Release-Pipeline sendet nach jedem GitHub Release eine WhatsApp-Nachricht via CallMeBot-Webhook (`WHATSAPP_WEBHOOK_URL` Secret)

### Fixed
- **Admin-Panel Item-Liste**: Nach dem Erstellen oder Bearbeiten eines Items wurde die Liste nicht neu geladen — Items schienen zu verschwinden weil sie nach `slot`+`id` sortiert an anderer Position erschienen als erwartet; Liste wird jetzt nach jeder Änderung neu von Supabase geladen
- **Pipeline `tag-on-main-release-bump.yml`**: `actions/checkout@v4` schlug fehl wenn `BOT_GH_PAT` nicht gesetzt war (`token: ""` wird als fehlender Pflichtparameter behandelt); Fallback auf `github.token` für den Checkout-Schritt hinzugefügt

## [2.1.7] - 2026-06-22

### Fixed
- **Android-Tastatur auf älteren Geräten (Samsung Galaxy A12, Android 11)**
  - `android:windowSoftInputMode` von `adjustResize` auf `adjustNothing` umgestellt
  - Auf Geräten mit Android 11 / kleineren Displays öffnete sich die Soft-Tastatur in Textfeldern (Login/Register) nicht zuverlässig
  - Root cause: `adjustResize` ließ das Fenster schrumpfen, sodass `MediaQuery.viewInsets.bottom` auf 0 fiel; `AnimatedPadding` im Profil-Sheet hatte damit keinen Effekt
  - Mit `adjustNothing` übernimmt Flutter die komplette Inset-Verwaltung — `viewInsets.bottom` liefert die korrekte Tastaturhöhe und `SingleChildScrollView` im Auth-Screen scrollt automatisch zum aktiven Textfeld

### Added
- **Regressions-Tests Tastatur-Fix**
  - `test/android_manifest_test.dart`: statischer Unit-Test prüft, dass `adjustNothing` gesetzt und `adjustResize` nicht vorhanden ist
  - `test/auth_screen_keyboard_test.dart`: 5 Widget-Tests für `AuthScreen` (TextFormField-Präsenz, `SingleChildScrollView`, `resizeToAvoidBottomInset`, Tastatur öffnet sich bei Username- und Passwort-Feld)
- **CI-Matrix für Android-Emulator-Tests**
  - `android-ui-test`-Job in `ci.yml` und `all-tests.yml` läuft jetzt auf zwei API-Levels parallel:
    - API 30 (Android 11, Pixel 4 Profil) — deckt das A12-Szenario ab
    - API 34 (Android 14, Pixel 6 Profil) — bisheriger Basis-Smoke-Test


## [2.1.6] - 2026-06-15

### Changed
- **`manual-tag-release.yml`** leicht robuster gemacht (kein inhaltlicher Funktions-Unterschied)


## [2.1.5] - 2026-06-10

### Added
- **Auto-Tag-Workflow** (`tag-on-main-release-bump.yml`): Erstellt automatisch einen Git-Tag, wenn `pubspec.yaml` auf `main` mit einer neuen Version und Build-Nummer `+0` gepusht wird
- **Dev-Branch-Protection** (`protect-dev-branch.yml`): Verhindert direkte Pushes auf `dev` ohne CI-Grün
- ESLint-Konfiguration für das Backend aktualisiert und vereinheitlicht

### Changed
- Alle CI-Workflows (`ci.yml`, `all-tests.yml`, `pr-main.yml`, `release.yml`) überarbeitet und stabilisiert
- Integrations-Test-Setup verbessert: Treiber-Skript und `app_test.dart` robuster gemacht


## [2.1.4] - 2026-06-02

### Added
- **Integrations-Test-Infrastruktur**: `integration_test/app_test.dart` und `test_driver/integration_test.dart` eingeführt
- **`android-ui-test`-Job** in der CI-Pipeline: Führt Flutter-Integrations-Tests auf einem Android-Emulator (API 34) aus, wenn KVM verfügbar ist; fällt auf Widget-Smoke-Test zurück wenn nicht

### Fixed
- Diverse Korrekturen in `lib/main.dart` (Layout-Stabilität)


## [2.1.3] - 2026-05-29

### Fixed
- **APK Login / API Response**
  - Flutter-Default `API_BASE_URL` auf `https://api.idle-forge.jonn2008.me` gesetzt, damit Clients standardmäßig gegen den korrekten API-Host laufen
  - Fehlerbild `Server returned an invalid response` beim Login durch falsche Host-Default-Adresse beseitigt
- **CI Stabilität**
  - `dart format --output=none --set-exit-if-changed .` wieder grün (Format in `game_controller.dart` korrigiert)
  - Backend-Buildfehler im Rate-Limiter-Loop beseitigt (TS-Iteration kompatibel gemacht)
  - Backend-Build entkoppelt von hartem Supabase-Env-Throw während Build-Time-Imports

### Changed
- Release-Vorbereitung auf **Version 2.1.3** in allen Modulen:
  - Flutter App-Version auf `2.1.3+5`
  - Backend `package.json`/`package-lock.json` auf `2.1.3`
  - Frontend `package.json`/`package-lock.json` auf `2.1.3`


## [2.1.2] - 2026-05-29

### Fixed
- **Login/Auth-Härtung (Backend)**
  - JWT-Signing schlägt bei fehlendem `JWT_SECRET` jetzt kontrolliert fehl (kein unkontrollierter Runtime-Crash mehr)
  - Login/Register geben bei JWT-Signing-Problemen eine saubere 500-Antwort zurück
  - Login prüft `is_admin` / `is_blocked` jetzt strikt; bei Fehlern in der Flag-Abfrage wird der Login sicher abgebrochen
  - Register prüft Username-Verfügbarkeit jetzt mit Fehlerbehandlung und behandelt DB-Unique-Races (`duplicate key`) als sauberen `409 Username already taken`
- **Coop-Session Join Race Condition behoben (Backend)**
  - `PUT /api/coop/[id]` verwendet jetzt atomare Join-Bedingungen (`status=waiting` und `guest_id IS NULL`) im Update
  - Gleichzeitige Join-Requests führen jetzt deterministisch zu `409` statt inkonsistenter Session-Zustände
- **Rate-Limiter robuster gemacht (Backend)**
  - In-Memory-Store wird periodisch bereinigt, um unbegrenztes Wachstum zu vermeiden
  - Client-IP-Erkennung erweitert (mehr Header + robustes Parsing)
- **CORS-Verhalten verbessert (Backend)**
  - Preflight-Requests aus nicht erlaubten Origins liefern jetzt `403` statt leerem `Access-Control-Allow-Origin`
  - `Vary: Origin` gesetzt, um Caching-/Proxy-Nebenwirkungen zu vermeiden
- **Savegame-/API-Parsing stabilisiert (Flutter)**
  - Harte Casts in `GameItem.fromJson` durch sichere Fallback-Konvertierung ersetzt (Slot/Tier/Power/SellValue)
  - Laden von `equippedBySlot` / Loadout-Slots toleriert ungültige oder alte Daten robust
  - Numerische API-Felder in Friends/Clan/PVP/Coop-Screens sind jetzt `num`-sicher geparst
- **Login-Zieladresse stabilisiert (Flutter)**
  - Fallback `API_BASE_URL` zeigt nicht mehr auf Platzhalter-Domain, sondern auf produktive Domain

### Changed
- Release-Vorbereitung auf **Version 2.1.2** in allen Modulen:
  - Flutter App-Version auf `2.1.2+4`
  - Backend `package.json`/`package-lock.json` auf `2.1.2`
  - Frontend `package.json`/`package-lock.json` auf `2.1.2`


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
