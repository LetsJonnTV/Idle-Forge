# Google OAuth Setup Guide

Google Sign-In ist jetzt vollständig in Idle Forge integriert. Hier ist wie du es einrichtest:

## 1️⃣ Google Cloud Console Setup

### Schritt 1: Google Cloud Project erstellen
1. Gehe zu [Google Cloud Console](https://console.cloud.google.com)
2. Erstelle ein neues Projekt oder wähle ein bestehendes
3. Aktiviere die "Google+ API"

### Schritt 2: OAuth 2.0 Credentials erstellen

**Für Android:**
1. Gehe zu "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
2. Wähle "Android" als Application Type
3. Du brauchst den **SHA-1 Fingerprint** deiner App:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
4. Kopiere den SHA-1 und füge ihn ein
5. Package Name: `com.example.idle_forge`
6. Activity: `com.example.idle_forge.MainActivity`
7. Speichere die `Client ID`

**Für Web/Backend:**
1. Erstelle einen "Web" OAuth Client
2. Authorized JavaScript origins: `https://api.idle-forge.jonn2008.me`
3. Authorized Redirect URIs: `https://api.idle-forge.jonn2008.me/auth/google/callback`
4. Kopiere `Client ID` und `Client Secret`

---

## 2️⃣ Environment Variables konfigurieren

### Für den Backend (.env oder vercel.json):
```env
GOOGLE_CLIENT_ID=YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=YOUR_GOOGLE_CLIENT_SECRET
```

### Für Flutter (build.gradle oder google-services.json):
Die `google_sign_in` Package braucht nur die Android App SHA-1 in Google Cloud Console registriert zu sein.

---

## 3️⃣ Datenbank Migration

Die Migration wurde bereits erstellt bei `/backend/supabase/migrations/20260622_add_google_oauth.sql`

Sie fügt zwei neue Spalten zur `players` Tabelle hinzu:
- `google_id`: Unique Google Identifier
- `email`: Email Adresse

Führe folgendes aus:
```bash
supabase migration up
```

Oder führe manuell die SQL aus in deiner Supabase Console.

---

## 4️⃣ Testing

### Flutter App
1. Starte die App: `flutter run`
2. Du wirst einen "Google anmelden" Button unter dem normalen Login sehen
3. Klick den Button → Google Sign-In Dialog öffnet sich
4. Melde dich mit deinem Google Account an
5. Die App erstellt automatisch einen neuen Spieler oder meldet dich an

### Backend Endpoint
Test den Google OAuth Endpoint manuell:
```bash
curl -X POST https://api.idle-forge.jonn2008.me/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"idToken": "YOUR_ID_TOKEN"}'
```

Die Antwort enthält:
```json
{
  "token": "JWT_TOKEN",
  "playerId": "player_uuid",
  "username": "username",
  "isNewPlayer": true/false
}
```

---

## 5️⃣ Features

✅ **Optional Login** - Spieler können spielen ohne sich anzumelden  
✅ **Google Account Linking** - Nutzer können später ihren Account mit Google verbinden  
✅ **Automatic User Creation** - Neue Google User werden automatisch als Player erstellt  
✅ **Cloud Save Integration** - Google Login speichert automatisch Game State zur Cloud  
✅ **Multiple Providers** - Spieler können sowohl mit Username/Password als auch Google spielen  

---

## 6️⃣ Troubleshooting

### "Google login cancelled"
- User hat den Google Dialog abgebrochen

### "Google login failed: Invalid token"
- Google Client ID ist falsch
- App SHA-1 ist nicht in Google Cloud Console registriert

### "No ID token received"
- Google Sign-In Package Problem
- Führe aus: `flutter clean && flutter pub get`

### Production Deployment
- Ändern Sie `applicationId` von `com.example.idle_forge` zu Ihrer echten App ID
- Registrieren Sie die echte App's SHA-1 in Google Cloud Console
- Aktualisieren Sie `GOOGLE_CLIENT_ID` im Backend

---

## 7️⃣ Sicherheit

⚠️ **WICHTIG:**
- ID Tokens werden auf dem Backend mit Google verrifiziert
- Tokens haben eine Lebensdauer von 1 Stunde
- JWTs vom Server haben 30 Tage Gültigkeit
- Alle Tokens sind in SecureStorage gespeichert (verschlüsselt)

---

**Fragen?** Schau in die Sourcecode:
- Frontend: `lib/services/api_service.dart` (loginWithGoogle)
- Backend: `backend/app/api/auth/google/route.ts`
- UI: `lib/screens/auth_screen.dart`
