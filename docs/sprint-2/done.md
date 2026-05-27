# Sprint 2 — Done

## Was gebaut wurde

### Backend (Next.js 14 auf Vercel)
- `backend/` — vollständiges Next.js 14 App Router Projekt mit TypeScript
- `backend/supabase/schema.sql` — PostgreSQL-Schema: players, friends, clans, clan_members, pvp_battles, coop_sessions, leaderboard View
- `backend/lib/supabaseClient.ts` — Supabase-Client (env-basiert, kein Hardcode)
- `backend/lib/auth.ts` — JWT-Verify Middleware
- `backend/lib/rateLimit.ts` — In-Memory Rate-Limiter (30 req/min per IP)
- `backend/app/api/auth/register/route.ts` — POST Register (bcrypt + JWT)
- `backend/app/api/auth/login/route.ts` — POST Login
- `backend/app/api/players/[id]/route.ts` — GET/PUT Spieler-Profil (JWT required)
- `backend/app/api/leaderboard/route.ts` — GET Top 100 (global + weekly)
- `backend/app/api/friends/route.ts` — GET Freunde / POST Anfrage
- `backend/app/api/friends/[id]/route.ts` — PUT accept/reject/block
- `backend/app/api/clans/route.ts` — GET alle Clans / POST erstellen
- `backend/app/api/clans/[id]/route.ts` — GET Clan-Details / PUT Perks
- `backend/app/api/clans/[id]/join/route.ts` — POST beitreten
- `backend/app/api/clans/[id]/members/route.ts` — GET Mitglieder
- `backend/app/api/pvp/route.ts` — GET Kämpfe / POST Herausforderung (server-seitige Berechnung)
- `backend/app/api/pvp/[id]/route.ts` — GET Kampf-Ergebnis
- `backend/app/api/coop/route.ts` — GET Sessions / POST erstellen
- `backend/app/api/coop/[id]/route.ts` — GET/PUT Session-Status

### Flutter App
- `lib/services/api_service.dart` — HTTP-Client, JWT via flutter_secure_storage, graceful offline
- `lib/screens/auth_screen.dart` — Login/Register mit Tab-Switch + "Ohne Account spielen"
- `lib/screens/leaderboard_screen.dart` — Global/Weekly Tabs, eigener Rang hervorgehoben
- `lib/screens/friends_screen.dart` — Freunde-Liste + Anfragen senden/annehmen
- `lib/screens/pvp_screen.dart` — Herausfordern, Battle-History, Ergebnis-Overlay
- `lib/screens/coop_screen.dart` — Lobby, Supabase Realtime Channel, geteilte Boss-HP
- `lib/screens/coming_soon_screen.dart` — Wiederverwendbarer Platzhalter
- `lib/main.dart` — Auth-Flow beim Start, neue Nav-Einträge, Supabase-Init, Stats-Sync
- `pubspec.yaml` — flutter_secure_storage ^9.x, supabase_flutter ^2.x hinzugefügt

## Was NICHT fertig ist
- Supabase-Projekt und Vercel-Projekt müssen manuell erstellt werden (Cloud-Setup)
- Env-Vars in Vercel müssen manuell eingetragen werden
- `backend/` wurde noch nicht deployed (`vercel deploy --prod`)
- Schema noch nicht in Supabase SQL-Editor eingespielt

## Manuelle Setup-Schritte (Entwickler)
1. Supabase-Konto → neues Projekt erstellen → SQL-Editor → `backend/supabase/schema.sql` einspielen
2. Vercel-Konto → neues Projekt → mit GitHub-Repo verbinden → `backend/` als Root Directory
3. In Vercel Dashboard Env-Vars setzen:
   - `SUPABASE_URL` = deine Supabase-URL
   - `SUPABASE_ANON_KEY` = dein Supabase Anon Key  
   - `JWT_SECRET` = beliebig langer zufälliger String
4. `vercel deploy --prod` oder automatischer Deploy via GitHub Push
5. In Flutter: `API_BASE_URL` beim Build setzen: `flutter build apk --dart-define=API_BASE_URL=https://deine-app.vercel.app`

## Geänderte/Erstellte Dateien
- `backend/` (komplett neu — 20+ Dateien)
- `lib/services/api_service.dart` (neu)
- `lib/screens/auth_screen.dart` (neu)
- `lib/screens/leaderboard_screen.dart` (neu)
- `lib/screens/friends_screen.dart` (neu)
- `lib/screens/pvp_screen.dart` (neu)
- `lib/screens/coop_screen.dart` (neu)
- `lib/screens/coming_soon_screen.dart` (neu)
- `lib/main.dart` (erweitert: Auth-Flow, Supabase-Init, neue Screens)
- `lib/l10n/app_text.dart` (erweitert: Login/Social-Strings)
- `pubspec.yaml` (flutter_secure_storage, supabase_flutter)

## Bekannte Issues
- `flutter analyze` konnte nicht ausgeführt werden (Shell-Timeout im Build-Environment)
- Koop-Supabase Realtime benötigt Supabase Realtime aktiviert im Dashboard
