# Idle Forge — Feature-Plan

Alle geplanten Features, priorisiert nach Aufwand und Impact.
Reihenfolge: Phase 1 → 4, innerhalb einer Phase nach Priorität.

---

## Phase 1 — Quick Wins (je 1–3 Tage)

Diese Features haben keinen oder kaum Backend-Aufwand und verbessern sofort die Spielerfahrung.

### 1.1 Item-Filter & Sortierung im Inventar
**Beschreibung:** Inventar nach Slot, Stärke oder Set filtern und sortieren.  
**Aufwand:** Frontend only  
**Abhängigkeiten:** keine  
**Nutzen:** Jeder Spieler mit viel Inventar profitiert sofort

### 1.2 Item-Vergleich
**Beschreibung:** Beim Anschauen eines Items wird direkt angezeigt, wie es gegen das aktuell ausgerüstete abschneidet (Stärke-Delta, Set-Boni-Vorschau).  
**Aufwand:** Frontend only  
**Abhängigkeiten:** keine  
**Nutzen:** Reduziert Rätselraten beim Ausrüsten

### 1.3 Schnell-Schmiede (Bulk Crafting)
**Beschreibung:** Items nicht nur einzeln, sondern x5 / x10 / x50 auf einmal schmieden.  
**Aufwand:** Frontend only (GameController-Schleife)  
**Abhängigkeiten:** keine  
**Nutzen:** Spart Zeit bei Prestige-Grinds

### 1.4 Offline-Fortschritts-Zusammenfassung
**Beschreibung:** Beim Öffnen der App erscheint eine Übersicht: „Während deiner Abwesenheit: +X Gold, Y Items geschmiedet, Z Dungeons abgeschlossen."  
**Aufwand:** Frontend (Zeitstempel speichern + berechnen)  
**Abhängigkeiten:** keine  
**Nutzen:** Sofortige Belohnungs-Gefühl beim App-Öffnen

---

## Phase 2 — Mittlere Features (je 1–2 Wochen)

Brauchen Backend-Arbeit, sind aber in sich abgeschlossen und bauen auf bestehenden Systemen auf.

### 2.1 Tägliche Herausforderungen
**Beschreibung:** 3 zufällige Aufgaben pro Tag (z.B. „Schmied 10 Helme", „Gewinne 5 PVP-Kämpfe", „Schließe 2 Dungeons ab") mit Gold- oder Item-Belohnungen.  
**Aufwand:** Backend (neue Tabelle `daily_challenges`, Seed-Aufgaben, Fortschritt-Tracking) + Frontend (Challenge-Panel)  
**Abhängigkeiten:** keine  
**Nutzen:** Gibt Spielern täglich einen konkreten Grund, die App zu öffnen

**Datenbank:**
```sql
CREATE TABLE daily_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  challenges JSONB NOT NULL,  -- [{ type, target, progress, reward, completed }]
  UNIQUE(player_id, date)
);
```

### 2.2 Spielerprofil-Seite (öffentlich)
**Beschreibung:** Öffentliche Profilseite pro Spieler mit ausgerüsteten Items, Prestige-Level, Errungenschaften und Clan. Per Link teilbar (`/profile/[username]`).  
**Aufwand:** Backend (neuer GET-Endpunkt `/api/players/[username]/profile`) + Frontend (neue Seite)  
**Abhängigkeiten:** keine  
**Nutzen:** Social-Aspekt, Spieler können sich zeigen

### 2.3 Freundschafts-Duelle
**Beschreibung:** Direkter PVP-Challenge an einen Freund schicken. Der Freund erhält eine Einladung und kann annehmen/ablehnen. Ergebnis wie normales PVP.  
**Aufwand:** Backend (neue Tabelle `pvp_challenges`, Erweiterung des PVP-Systems) + Frontend  
**Abhängigkeiten:** Freundessystem (bereits vorhanden), PVP-System (bereits vorhanden)  
**Nutzen:** Macht PVP persönlicher

### 2.4 Prestige-Shop
**Beschreibung:** Mit Scherben aus dem Prestige-System können Spieler im Shop kosmetische Skins (Waffen-Farben, Namens-Farben) oder kleine permanente QoL-Boosts kaufen.  
**Aufwand:** Backend (neue Tabelle `prestige_shop_items`, Kauflogik) + Frontend  
**Abhängigkeiten:** Prestige-System (bereits vorhanden), Scherben-Währung (bereits vorhanden)  
**Nutzen:** Gibt Scherben einen langfristigen Wert über den Ascension-Tree hinaus

---

## Phase 3 — Große Features (je 2–4 Wochen)

Komplex, brauchen sorgfältige Planung. Hier sollte jeweils ein Feature fertig sein bevor das nächste beginnt.

### 3.1 Push-Notifications
**Beschreibung:** Benachrichtigungen für: Expedition fertig, Energie aufgefüllt, Clan-Einladung erhalten, Clan-War beginnt.  
**Aufwand:** Backend (Push-Service, z.B. Firebase Cloud Messaging oder Web Push) + Flutter (Permission-Handling, Notification-Handler)  
**Abhängigkeiten:** keine, aber sinnvoll nach Phase 2 Features die Trigger brauchen  
**Nutzen:** Hoher Retention-Effekt — Spieler kommen zurück wenn etwas passiert

**Hinweis:** `flutter_local_notifications` ist bereits installiert. Für Server-Push wird FCM (Firebase) empfohlen.

### 3.2 Weltbosse
**Beschreibung:** Alle 6 Stunden spawnt ein globaler Boss mit geteiltem HP-Pool. Jeder Spieler kann angreifen und Schaden beitragen. Nach Ablauf der Zeit: Schaden-Rangliste → Top-Angreifer erhalten seltene Belohnungen, alle Teilnehmer erhalten Grundbelohnung.  
**Aufwand:** Backend (Boss-State-Management, Schaden-Tracking, Timer, Belohnungsverteilung) + Frontend (neues Boss-Panel mit HP-Balken, Rangliste, Countdown)  
**Abhängigkeiten:** keine  
**Nutzen:** Stärkste Community-Feature — alle kämpfen gemeinsam gegen etwas

**Datenbank:**
```sql
CREATE TABLE world_bosses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  max_hp BIGINT NOT NULL,
  current_hp BIGINT NOT NULL,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT CHECK (status IN ('active', 'defeated', 'expired')) DEFAULT 'active'
);

CREATE TABLE world_boss_damage (
  boss_id UUID REFERENCES world_bosses(id) ON DELETE CASCADE,
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  damage BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (boss_id, player_id)
);
```

### 3.3 Saisonales Event-System
**Beschreibung:** Zeitlich begrenzte Events (z.B. „Feuer-Festival", „Winter-Schmied") mit:
- Exklusive Event-Items (nur während des Events erhältlich)
- Event-spezifische Dungeons oder Quests
- Event-Währung die gegen Sonderbelohnungen eingetauscht wird
- Countdown bis Event-Ende

**Aufwand:** Backend (Event-Config, Event-Items im Admin-Panel, Event-Währung-Tracking) + Frontend (Event-Banner, Event-Shop, Event-Dungeon) + Admin (Event erstellen/verwalten)  
**Abhängigkeiten:** Admin-Panel (bereits vorhanden), Dungeon-System (bereits vorhanden)  
**Nutzen:** Stärkstes Retention-Tool — FOMO motiviert Spieler, in bestimmten Zeiträumen aktiv zu sein

---

## Phase 4 — Ambitiöse Features (4–8 Wochen, komplex)

Nur angehen wenn Spielerbasis und Infrastruktur stabil sind.

### 4.1 Gildenkampf (Clan War)
**Beschreibung:** Einmal pro Woche treten zwei zufällig gematchte Clans gegeneinander an. Alle Clan-Mitglieder tragen durch ihre Stärke/Aktivität Punkte bei. Am Ende gewinnt der Clan mit mehr Punkten — Belohnungen für alle Mitglieder des Sieger-Clans.  
**Aufwand:** Backend (Matchmaking, War-State, Punkte-Aggregation, Zeitplan) + Frontend (Clan-War-Tab) + Admin (War-Verwaltung)  
**Abhängigkeiten:** Clan-System (bereits vorhanden)  
**Nutzen:** Gibt Clans einen gemeinsamen Wochenrhythmus und Wettbewerb

### 4.2 Item-Auktionshaus
**Beschreibung:** Spieler können Items zum Verkauf anbieten (Mindestpreis in Gold). Andere Spieler können bieten oder sofort kaufen. Nach X Stunden: Höchstbietender erhält Item, Verkäufer erhält Gold (minus kleiner Markt-Gebühr).  
**Aufwand:** Backend (Auktions-Engine, Anti-Exploit-Maßnahmen, Gold-Transfers) + Frontend (Auktionshaus-Seite, Eigene Auktionen verwalten) + Admin (Monitoring, manuelle Eingriffe)  
**Abhängigkeiten:** Spielerprofil (2.2), solides Gold-Economy-Balancing  
**Nutzen:** Schafft eine Spieler-Wirtschaft, sehr hoher Langzeit-Engagement-Faktor  
**Risiko:** Erfordert Anti-Cheat und sorgfältiges Economy-Balancing — ohne das kann es die Wirtschaft kaputt machen

---

## Empfohlene Reihenfolge

| Priorität | Feature | Phase | Aufwand |
|-----------|---------|-------|---------|
| 1 | Item-Filter & Sortierung | 1 | Klein |
| 2 | Schnell-Schmiede | 1 | Klein |
| 3 | Item-Vergleich | 1 | Klein |
| 4 | Offline-Zusammenfassung | 1 | Klein |
| 5 | Tägliche Herausforderungen | 2 | Mittel |
| 6 | Freundschafts-Duelle | 2 | Mittel |
| 7 | Spielerprofil-Seite | 2 | Mittel |
| 8 | Prestige-Shop | 2 | Mittel |
| 9 | Push-Notifications | 3 | Groß |
| 10 | Weltbosse | 3 | Groß |
| 11 | Saisonales Event-System | 3 | Groß |
| 12 | Gildenkampf | 4 | Sehr groß |
| 13 | Auktionshaus | 4 | Sehr groß |

**Empfehlung zum Start:** Phase 1 komplett abschließen (ein Wochenende), dann mit Täglichen Herausforderungen beginnen — das hat den besten Verhältnis aus Aufwand und spürbarem Mehrwert für die Spieler.
