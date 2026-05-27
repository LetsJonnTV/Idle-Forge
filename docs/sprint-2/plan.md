# Sprint 2 — Backend & Social Features

> Sprint Goal: Vercel-Backend + Freunde-System + Rangliste + Clan-Server + PVP (async) + Koop (realtime)
> Branch: `feature/sprint-2`
> Startet NACH dem Merge von Sprint 1A + 1B in main
> Teams: Sage (Backend) + Nova (Flutter-Integration) + Milo (Social-UI)

## Kontext

Sprint 2 ist ein Architektur-Sprint. Er führt erstmals einen Server ein.
Der Stack: **Next.js 14 (Vercel)** + **Supabase** (PostgreSQL + Realtime).
Supabase ist gewählt wegen: kostenloses Tier, eingebautem Realtime (für Koop), RLS, einfacher SDK.

---

## Pre-Sprint Checklist (Remy)

- [ ] Supabase-Projekt erstellen: https://supabase.com
- [ ] Vercel-Projekt erstellen: https://vercel.com
- [ ] `SUPABASE_URL` und `SUPABASE_ANON_KEY` in Vercel-Env-Vars eintragen
- [ ] `JWT_SECRET` generieren und in Vercel-Env-Vars eintragen
- [ ] `backend/` Ordner im Repo erstellen (Next.js App)
- [ ] GitHub Actions für Vercel-Deploy konfigurieren

---

## Prioritized Task List

| # | Task | Owner | Beschreibung |
|---|------|-------|-------------|
| **BACKEND** | | | |
| 1 | Next.js Projekt Setup | Sage | `backend/` mit `next.config.js`, `package.json`, TypeScript-Setup |
| 2 | Supabase Schema | Sage | Tabellen: `players`, `friends`, `clans`, `clan_members`, `pvp_battles`, `leaderboard` |
| 3 | Auth: Register/Login | Sage | `POST /api/auth/register`, `POST /api/auth/login` — JWT zurückgeben |
| 4 | Spieler-Profil-API | Sage | `GET/PUT /api/players/[id]` — Stats, Name, Level hochladen |
| 5 | Leaderboard-API | Sage | `GET /api/leaderboard` — Top 100 nach Stärke, wöchentlich/global |
| 6 | Freunde-API | Sage | `POST /api/friends/request`, `PUT /api/friends/accept`, `GET /api/friends` |
| 7 | Clan-API | Sage | CRUD Clan, Beitritt-Requests, Clan-Mitglieder, Clan-Perks synchronisieren |
| 8 | PVP-API | Sage | `POST /api/pvp/challenge` — async Kampf: Stats senden, Server berechnet Ergebnis |
| 9 | Koop-Realtime-Setup | Sage | Supabase Realtime Channel: `coop_session_{id}`, Presence + Broadcast |
| 10 | Rate Limiting & Auth Middleware | Sage | JWT-Middleware für alle geschützten Routes, Rate-Limit per IP |
| **FLUTTER** | | | |
| 11 | ApiService | Nova | `lib/services/api_service.dart` — HTTP-Client, JWT-Storage (flutter_secure_storage) |
| 12 | Auth-Flow in App | Nova | Register/Login-Screen, JWT in SecureStorage, Auto-Login |
| 13 | Leaderboard-Screen | Nova + Milo | `LeaderboardScreen`: Tab Global/Wöchentlich, eigene Platzierung hervorheben |
| 14 | Freunde-System UI | Nova + Milo | Freunde-Liste, Anfragen senden/annehmen, Freund-Profil ansehen |
| 15 | Clan-Server-Integration | Nova | Echten Clan-Server nutzen statt lokal: Beitreten, erstellen, Mitglieder-Liste |
| 16 | Clan-UI Überarbeitung | Milo | Clan-Screen: echte Mitglieder, Chat-Placeholder, Perk-Sync mit Server |
| 17 | PVP-Screen | Nova + Milo | Herausfordern-Button, offene Kämpfe, Kampf-Ergebnis-Overlay |
| 18 | PVP-Logik Flutter | Nova | Stats an API senden, Ergebnis pollen/webhook, Belohnungen claimen |
| 19 | Koop-Session Flutter | Nova | Supabase Realtime Client, Session erstellen/beitreten, Sync-Logik |
| 20 | Koop-UI | Milo | Koop-Lobby-Screen, Partner-Status, geteilte Boss-HP-Bar |
| 21 | Offline-First Handling | Nova | Alle API-Calls haben Fallback auf lokalen State, kein Hard-Crash bei No-Internet |
| 22 | "Coming Soon" Screens | Milo | Platzhalter-Screens für nicht-impl. soziale Features mit "Bald verfügbar"-Banner |

---

## Work Schedule

### Phase 1: Backend Fundament (Tasks 1-4)
- Next.js Setup, Supabase Schema, Auth-API
- Flutter ApiService + Auth-Flow
- Checkpoint: `sprint-2: phase-1 backend-foundation`

### Phase 2: Leaderboard + Freunde (Tasks 5-6, 11-14)
- APIs + Flutter-Integration
- UI-Screens
- Checkpoint: `sprint-2: phase-2 social-core`

### Phase 3: Clan-Server (Tasks 7, 15-16)
- Clan-API + Flutter-Integration
- UI überarbeiten
- Checkpoint: `sprint-2: phase-3 clan-server`

### Phase 4: PVP (Tasks 8, 17-18)
- PVP-API (async Kampf-Berechnung)
- Flutter-Integration + UI
- Checkpoint: `sprint-2: phase-4 pvp`

### Phase 5: Koop Realtime (Tasks 9, 19-20)
- Supabase Realtime + Flutter-Client
- Koop-Lobby + Kampf-Sync
- Checkpoint: `sprint-2: phase-5 coop`

### Phase 6: Polish & Coming-Soon (Tasks 10, 21-22)
- Rate Limiting, Offline-Fallback
- Coming-Soon-Platzhalter
- Final-Commit: `sprint-2: complete`

---

## Success Criteria

- [ ] Spieler kann sich registrieren und einloggen (JWT)
- [ ] Leaderboard zeigt Top 100, eigener Rang sichtbar
- [ ] Freund-Anfrage senden, annehmen, Freunde-Liste sehen
- [ ] Clan erstellen, beitreten, Mitglieder sehen (server-seitig)
- [ ] PVP-Herausforderung senden, Ergebnis nach < 10 Sek erhalten
- [ ] Koop-Session: 2 Spieler kämpfen synchron gegen denselben Boss
- [ ] App stürzt NICHT ab wenn kein Internet vorhanden
- [ ] Alle API-Routen sind JWT-gesichert
- [ ] `flutter analyze` ohne Errors

---

## What's NOT in This Sprint

| Feature | Grund |
|---------|-------|
| Guild Wars | Sprint 3+ |
| Auction House | Sprint 3+ |
| Realtime PVP | Zu aufwändig, async reicht für v1 |
| iOS App Store | Anderes Thema, separater Sprint |
| Battle Pass | Sprint 3+ |

---

## Datenbankschema (Supabase PostgreSQL)

```sql
-- Spieler
CREATE TABLE players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  total_strength INT DEFAULT 0,
  prestige_level INT DEFAULT 0,
  chapter INT DEFAULT 1,
  clan_id UUID REFERENCES clans(id)
);

-- Freunde
CREATE TABLE friends (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES players(id),
  addressee_id UUID REFERENCES players(id),
  status TEXT CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requester_id, addressee_id)
);

-- Clans
CREATE TABLE clans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  leader_id UUID REFERENCES players(id),
  level INT DEFAULT 1,
  xp INT DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- PVP Kämpfe (async)
CREATE TABLE pvp_battles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id UUID REFERENCES players(id),
  defender_id UUID REFERENCES players(id),
  winner_id UUID REFERENCES players(id),
  challenger_stats JSONB,
  defender_stats JSONB,
  status TEXT CHECK (status IN ('pending', 'completed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Leaderboard View
CREATE VIEW leaderboard AS
  SELECT id, username, total_strength, prestige_level, chapter
  FROM players ORDER BY total_strength DESC LIMIT 100;
```

---

## Agent Prompt

```
Lies PROJECT_BRIEF.md, dann lies docs/sprint-2/plan.md. Führe Sprint 2 aus.

Du bist Sage (Backend) und Nova (Flutter) und Milo (UI).

Voraussetzungen prüfen:
- Supabase-Projekt und Vercel-Projekt müssen existieren (Pre-Sprint Checklist in plan.md)
- Env-Vars müssen gesetzt sein

Zuerst:
  git pull origin main
  git checkout -b feature/sprint-2

Backend (Sage): Erstelle `backend/` als Next.js 14 App mit TypeScript.
Flutter (Nova): Erstelle `lib/services/api_service.dart`.
UI (Milo): Neue Screens für Social-Features.

Nach jeder Phase: Checkpoint-Commit.
Aktualisiere docs/sprint-2/progress.md nach jeder Phase.

SICHERHEITS-REGELN (aus PROJECT_BRIEF.md Abschnitt 9 — PFLICHT):
- Keine Secrets in Code
- JWT in flutter_secure_storage (NICHT SharedPreferences)
- Supabase RLS aktivieren für alle player-spezifischen Tabellen
- Server validiert ALLE Kampfberechnungen (kein Trust auf Client)

Am Ende: git push origin feature/sprint-2 und PR erstellen.
```
