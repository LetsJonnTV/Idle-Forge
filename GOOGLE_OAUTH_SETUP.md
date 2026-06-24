# Google OAuth Setup Guide

Dieses Projekt nutzt Google Sign-In mit einem Next.js Backend auf Google Cloud Run und PostgreSQL.

## 1) Google Cloud OAuth konfigurieren

1. Öffne die Google Cloud Console.
2. Erstelle oder wähle ein Projekt.
3. Aktiviere die Google Identity / OAuth APIs.
4. Erstelle OAuth 2.0 Credentials:
   - Android Client (für mobile App)
   - Web Client (für Backend-Verifikation)

### Android Client

- Package Name: `com.letsjonntv.idle_forge`
- SHA-1 des Signing-Zertifikats hinterlegen

Wichtig fuer CI/CD: Wenn Android-Builds in GitHub Actions laufen, muss die SHA-1 des in der Pipeline verwendeten Keystores mit der SHA-1 im Android OAuth Client uebereinstimmen. In diesem Repo wird der Keystore aus `ANDROID_DEBUG_KEYSTORE` restauriert.

Wenn lokal alles funktioniert, in der Pipeline aber `sign_in_failed` mit Status 10 auftritt, ist fast immer die SHA-1 des CI-Keystores nicht im Google OAuth Android Client hinterlegt.

Beispiel Debug-SHA1:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Web Client

- Authorized JavaScript origins: eure Frontend-Domain
- Redirect URI ist für den aktuellen ID-Token-Flow nicht zwingend erforderlich, kann aber für spätere OAuth-Web-Flows gepflegt werden.

## 2) Backend-Umgebungsvariablen

Setze diese Variablen in Cloud Run (oder lokal in `backend/.env`):

```env
DATABASE_URL=postgresql://user:password@/idle_forge?host=/cloudsql/PROJECT:REGION:INSTANCE
JWT_SECRET=minimum-32-char-secret
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET
DEBUG=false
```

## 3) PostgreSQL Schema anwenden

Das Schema liegt in:

- backend/database/schema.sql
- backend/database/migrations/20260622_add_google_oauth.sql

Für neue Umgebungen reicht in der Regel `schema.sql`, da die Google-Spalten dort idempotent ergänzt werden.

Beispiel mit `psql`:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f backend/database/schema.sql
```

## 4) Cloud Run Deployment

Die CI/CD Workflows deployen auf Cloud Run:

- DEV: `.github/workflows/dev-build.yml`
- PROD: `.github/workflows/deploy-backend-gcp-prod.yml`

Erforderliche Secret-Mappings am Service:

- `JWT_SECRET`
- `DATABASE_URL`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`

## 5) API Test

Google-Login Endpoint testen:

```bash
curl -X POST https://<backend-domain>/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"idToken":"YOUR_ID_TOKEN"}'
```

Erwartete Antwort:

```json
{
  "token": "JWT_TOKEN",
  "playerId": "player_uuid",
  "username": "username",
  "isNewPlayer": true
}
```

## 6) Troubleshooting

- `Invalid token`: Client-ID oder Token-Audience passt nicht.
- `Failed to create account`: Benutzername-Kollision oder DB-Constraint verletzt.
- `Database error`: `DATABASE_URL`/Cloud SQL-Verbindung prüfen.

## 7) Sicherheit

- ID-Token werden serverseitig mit Google validiert.
- Backend stellt eigenes JWT (30 Tage) aus.
- `JWT_SECRET` und DB-Zugang nur über Secret Manager/Cloud Run Secrets bereitstellen.