# PROJECT_BRIEF.md — Idle Forge

> Last updated: 2026-05-27 | Sprint 1A+1B (Parallel) | Status: 🔨 In Progress

## 1. Project Overview

Idle Forge ist ein Idle-RPG für Android/Windows in Flutter/Dart. Der Spieler besiegt Gegner, schmiedet Ausrüstung und steigt durch Kapitel auf. Das Spiel unterstützt Deutsch und Englisch und wird als GitHub-Release publiziert (APK + ZIP). Ab Sprint 2 wird ein Vercel-Backend für soziale Features eingebunden.

## 2. Concept / Product Description

- **Kern-Loop:** Idle-Kampf → Gold verdienen → Schmiede → stärkere Items → nächstes Kapitel
- **Prestige-System:** Nach Kapitel-Cap: Reset mit dauerhaften Boni (Scherben, Prestige-Level)
- **Clan-System (lokal):** Clan-Level, Perks (Warpath, Bulwark, Prosperity, Rituals)
- **Shop:** Tägliche Angebote, Upgrades (Speed, Hammer, Recovery)
- **Quests & Achievements:** Kill/Craft/Boss-Quests, Achievement-System
- **Item-Sets:** Ember, Tide, Storm — Set-Sammlung mit Rewards

**Geplante Features (Sprint 1):**
- Dungeons, Crafting-Rezepte, Ascension-Baum, Pet/Companion, Set-Boni, Expeditionen, Enchantment, Login-Streak, Smart-Equip-Preview, Push-Notifications

**Geplante Features (Sprint 2):**
- Vercel-Backend, Freunde-System, Rangliste, echter Clan-Server, PVP (async), Koop (realtime)

## 3. Tech Stack

- **App:** Flutter 3.x / Dart 3.x, SharedPreferences (lokaler Save), flutter_svg, http
- **Backend (ab Sprint 2):** Next.js 14 (App Router) auf Vercel, Supabase (PostgreSQL + Realtime), JWT Auth
- **Push Notifications:** `flutter_local_notifications` + `firebase_messaging` (FCM)
- **Testing:** flutter_test, integration_test
- **CI/CD:** GitHub Actions → GitHub Releases (APK/ZIP)
- **Hosting:** Vercel (API), GitHub Releases (App-Distribution)

## 4. Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Flutter App (Client)                │
│                                                      │
│  GameController (ChangeNotifier)                     │
│    ├── Combat Engine (Timer-based, 60fps)            │
│    ├── Forge/Crafting System                         │
│    ├── Shop / Daily Offers                           │
│    ├── Quest / Achievement Tracker                   │
│    ├── Offline Reward Calculator                     │
│    └── [NEU] Dungeon / Expedition / Pet Engine       │
│                                                      │
│  lib/game/                                           │
│    ├── game_controller.dart   (Haupt-State)          │
│    ├── models.dart            (Enums, ViewModels)    │
│    └── [NEU] dungeon_controller.dart etc.            │
│  lib/l10n/  (DE/EN Texte)                            │
│  lib/services/ (UpdateChecker, UpdateInstaller)      │
└───────────────────┬─────────────────────────────────┘
                    │ HTTPS (ab Sprint 2)
┌───────────────────▼─────────────────────────────────┐
│              Vercel Backend (Sprint 2)               │
│  Next.js API Routes (Edge Functions)                 │
│    ├── /api/auth    (JWT Login/Register)             │
│    ├── /api/leaderboard                              │
│    ├── /api/friends                                  │
│    ├── /api/clan                                     │
│    ├── /api/pvp     (async Herausforderungen)        │
│    └── /api/coop    (Supabase Realtime Channels)     │
└───────────────────┬─────────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────────┐
│              Supabase (Sprint 2)                     │
│  PostgreSQL: players, friends, clans, pvp_battles    │
│  Realtime:   coop_sessions channel                   │
└─────────────────────────────────────────────────────┘
```

## 5. Key Files Map

| Area | Pfad | Inhalt |
|------|------|--------|
| App-Entry | `lib/main.dart` | App bootstrap, Locale, Theme |
| Game-State | `lib/game/game_controller.dart` | Gesamter Spielzustand (ChangeNotifier) |
| Modelle | `lib/game/models.dart` | Enums, ViewModels, GameItem, etc. |
| Texte DE/EN | `lib/l10n/app_text.dart` | Alle UI-Strings |
| Services | `lib/services/` | UpdateChecker, UpdateInstaller |
| Assets | `assets/icons/` | SVG-Icons |
| Sprint 1A | `docs/sprint-1a/` | Pläne: Dungeons, Expeditionen, Rezepte, Ascension |
| Sprint 1B | `docs/sprint-1b/` | Pläne: Pet, Set-Boni, Enchantment, Login, SmartEquip, Notifs |
| Sprint 2 | `docs/sprint-2/` | Plan: Backend, Social Features |
| Ideen-Backlog | `docs/ideas-backlog.md` | Coming-soon Features |

## 6. Team Rollen

| Agent | Name | Rolle |
|-------|------|-------|
| Producer | **Remy** | Sprint-Planung, Koordination, PR-Merges — schreibt KEINEN Code |
| Flutter Dev A | **Nova** | Spielmechaniken, Controller, Dart-Logik |
| Flutter Dev B | **Sage** | Backend-Integration, API, Netzwerk, Auth |
| UI/Art | **Milo** | Widgets, Animationen, Visual Design, Theme |
| QA | **Ivy** | Tests, Spieltest, Bug-Reports als GitHub Issues |

## 7. Sprint Status

| Sprint | Name | Status | Scope |
|--------|------|--------|-------|
| 0 | Foundation | ✅ Done | v1.0.3: Tutorial, Dark/Light Mode, Auto-Update, Quests, Shop |
| 1A | Game Systems | ✅ Done | Dungeons, Expeditionen, Crafting-Rezepte, Ascension-Baum |
| 1B | Game Polish | 🔨 In Progress | Pet, Set-Boni, Enchantment, Login-Streak, SmartEquip, Notifications |
| 2 | Backend & Social | 📋 Geplant | Vercel-Backend, Freunde, Rangliste, Clan-Server, PVP, Koop |

*Sprint 1A und 1B laufen PARALLEL auf separaten Branches.*

## 8. Current State (Stand v1.0.3)

**Was funktioniert (Stand Sprint 1A):**
- Idle-Kampf mit Auto-Attacks, Skills (Strike, Whirl, Focus), Auto-Skill
- Schmiede mit Zufalls-Crafting (Common → Legendary)
- Shop: Tägliche Angebote, Speed/Hammer/Recovery-Upgrades
- Tränke: Healing Flask, Berserk Flask
- Quests (Kill/Craft/Boss) + Achievement-System
- Talent-System (Attack/Vitality/Forge)
- Clan-System (lokal: Level, XP, 4 Perks)
- Item-Sets (Ember, Tide, Storm) mit Collection-Rewards
- Offline-Rewards (bis 8h)
- Tutorial (8 Schritte)
- Dark/Light-Mode
- In-App Auto-Update (Android + Windows)
- DE/EN Lokalisierung
- **[NEU Sprint 1A]** Dungeons (3 Schwierigkeiten, 5 Stages, Energie-System, Legendary-Drop)
- **[NEU Sprint 1A]** Expeditionen (3 Slots, 6 Typen, offline-kompatibel)
- **[NEU Sprint 1A]** Crafting-Rezepte (5 Rezepte, Drop beim Kämpfen, Rezeptbuch)
- **[NEU Sprint 1A]** Ascension-Baum (3 Pfade: Krieger/Schmied/Schurke, 15 Nodes, permanente Boni)

**Was noch nicht existiert:**
- Pet/Companion (Sprint 1B)
- Enchantment-System (Sprint 1B)
- Pet/Companion
- Enchantment-System
- Set-Boni (Tragen-Bonus)
- Daily Login Streak
- Smart Equip Preview
- Push-Notifications
- Backend / Online-Features

**Was als nächstes kommt:**
- Sprint 1A: Kern-Spielsysteme (Dungeons, Expeditionen, Rezepte, Ascension)
- Sprint 1B: Spielpolitur (Pet, Enchantment, Login, SmartEquip, Notifications)
- Sprint 2: Vercel-Backend, soziale Features

## 9. Security Rules

1. Secrets (API Keys, Supabase URL, JWT Secret) ausschließlich in Umgebungsvariablen — niemals in Code oder Git
2. Supabase Row-Level-Security (RLS) aktiviert für alle user-spezifischen Tabellen
3. JWT-Token clientseitig in SecureStorage (flutter_secure_storage), nicht SharedPreferences
4. Backend-Routen validieren JWT bei jedem Request (kein Trust auf Client-Daten)
5. PVP/Koop: Server ist autoritär — Client-Moves werden serverseitig validiert

## 10. How to Run Locally

```bash
# Flutter App
flutter pub get
flutter run -d windows        # Windows Desktop
flutter run -d android        # Android (USB-Debugging)

# Ab Sprint 2: Backend
cd backend
npm install
cp .env.example .env.local    # Supabase-Keys eintragen
npm run dev                   # Startet auf localhost:3000
```

## 11. How to Deploy

**App:**
```bash
flutter build apk --release                          # Android
flutter build windows --release                      # Windows
# GitHub Actions pusht automatisch auf Release bei git tag
```

**Backend (ab Sprint 2):**
```bash
cd backend
vercel deploy --prod          # Vercel CLI
# Env Vars in Vercel Dashboard: SUPABASE_URL, SUPABASE_ANON_KEY, JWT_SECRET
```

## 12. Cross-Chat Handoff Protocol

Vor dem Schließen jedes Chat-Fensters:
1. `docs/sprint-N/done.md` schreiben — was gebaut wurde, was offen ist, welche Files geändert
2. `PROJECT_BRIEF.md` aktualisieren: Abschnitt 7 (Sprint-Status) + Abschnitt 8 (Current State)
3. Alle Änderungen commiten: `sprint-1a: <zusammenfassung>`
4. Branch pushen und PR erstellen

**Cold-Start-Prompt für neuen Chat:**
```
Lies PROJECT_BRIEF.md und docs/sprint-1a/progress.md.
Mache weiter wo aufgehört wurde.
```

## 13. Bug & Fix Tracking

Bugs → GitHub Issues mit Labels (`bug`, `severity:blocker/major/minor`).
Format: Komponente + Reproduktionsschritte + Erwartet vs. Tatsächlich.

- **Dev:** Issues vor Arbeitsbeginn prüfen. Blocker/Major zuerst fixen.
  Commits: `fix: beschreibung (Fixes #NN)`
- **QA:** Nach Sprint-Merge vollständigen Playtest. Sign-off: `docs/qa/sprint-N-signoff.md`
- **Feature-Ideen:** In `docs/ideas-backlog.md` dokumentieren

## 14. Multi-Repo Setup / Branch-Strategie

```bash
# Sprint 1A Team (Game Systems)
git checkout -b feature/sprint-1a

# Sprint 1B Team (Game Polish)
git checkout -b feature/sprint-1b

# Nach Fertigstellung:
# Sprint 1A → PR → merge to main
# Sprint 1B → PR → merge to main (nach 1A merge, Konflikte lösen)
# Sprint 2 → feature/sprint-2 (startet nach 1A+1B merged)
```

**Regeln:**
- Kein direktes Pushen auf `main`
- Kein Squash, kein Rebase von Feature-Branches (→ Commit-Verlust!)
- Merge-Commits bevorzugen
- Jeder Fix hat eigenen Commit mit Issue-Referenz
