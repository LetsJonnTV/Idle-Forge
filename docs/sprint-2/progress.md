# Sprint 2 — Progress Tracker

> Falls Kontext überläuft, neuen Chat starten:
> "Lies PROJECT_BRIEF.md und docs/sprint-2/progress.md. Mache weiter wo aufgehört wurde."

## Pre-Sprint Checklist

| # | Setup-Schritt | Status |
|---|--------------|--------|
| 1 | Supabase-Projekt erstellt | ⬜ manuell durch Entwickler |
| 2 | Vercel-Projekt erstellt | ⬜ manuell durch Entwickler |
| 3 | SUPABASE_URL in Vercel-Env-Vars | ⬜ manuell durch Entwickler |
| 4 | SUPABASE_ANON_KEY in Vercel-Env-Vars | ⬜ manuell durch Entwickler |
| 5 | JWT_SECRET in Vercel-Env-Vars | ⬜ manuell durch Entwickler |
| 6 | `backend/` Ordner erstellt | ✅ |

## Task Status

| # | Task | Status | Notes |
|---|------|--------|-------|
| 1 | Next.js Projekt Setup | ✅ Done | `backend/` mit next.config.js, tsconfig, package.json |
| 2 | Supabase Schema | ✅ Done | `backend/supabase/schema.sql` — alle Tabellen + Views |
| 3 | Auth: Register/Login | ✅ Done | `backend/app/api/auth/register/route.ts` + `login/route.ts` |
| 4 | Spieler-Profil-API | ✅ Done | `backend/app/api/players/[id]/route.ts` |
| 5 | Leaderboard-API | ✅ Done | `backend/app/api/leaderboard/route.ts` |
| 6 | Freunde-API | ✅ Done | `backend/app/api/friends/route.ts` + `[id]/route.ts` |
| 7 | Clan-API | ✅ Done | `backend/app/api/clans/` (CRUD, join, members) |
| 8 | PVP-API | ✅ Done | `backend/app/api/pvp/route.ts` + `[id]/route.ts` |
| 9 | Koop-Realtime-Setup | ✅ Done | `backend/app/api/coop/` + Supabase Realtime in CoopScreen |
| 10 | Rate Limiting & Auth Middleware | ✅ Done | `backend/lib/auth.ts` + `rateLimit.ts` |
| 11 | ApiService Flutter | ✅ Done | `lib/services/api_service.dart` — JWT via flutter_secure_storage |
| 12 | Auth-Flow in App | ✅ Done | `lib/screens/auth_screen.dart` + main.dart integration |
| 13 | Leaderboard-Screen | ✅ Done | `lib/screens/leaderboard_screen.dart` |
| 14 | Freunde-System UI | ✅ Done | `lib/screens/friends_screen.dart` |
| 15 | Clan-Server-Integration | ✅ Done | GameController + ApiService Clan-Methoden |
| 16 | Clan-UI Überarbeitung | ✅ Done | main.dart Clan-Screen mit Online-Members |
| 17 | PVP-Screen | ✅ Done | `lib/screens/pvp_screen.dart` |
| 18 | PVP-Logik Flutter | ✅ Done | Challenge + Result in pvp_screen.dart |
| 19 | Koop-Session Flutter | ✅ Done | `lib/screens/coop_screen.dart` mit Supabase Realtime |
| 20 | Koop-UI | ✅ Done | Lobby + geteilte Boss-HP-Bar in coop_screen.dart |
| 21 | Offline-First Handling | ✅ Done | ApiService gibt bei Offline nie crash, immer Fallback |
| 22 | Coming-Soon-Screens | ✅ Done | `lib/screens/coming_soon_screen.dart` |

## Bugs Found

| # | Beschreibung | Schwere | Status | Fix |
|---|-------------|---------|--------|-----|
| — | — | — | — | — |

## Notes

[Notizen zu Entscheidungen, Problemen oder Kontext für Recovery]
