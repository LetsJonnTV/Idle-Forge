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

## Phase 5 — Erweitertes Event-System (vollständige Spec)

> **Legende:** ✅ bereits implementiert · ⏳ fehlt noch

### Systemübersicht

Zeitlich begrenzte Events, die der Admin vollständig über das Frontend konfigurieren kann. Event-Typen sind **Vorlagen** — jede konkrete Instanz ist eine eigene, individuell eingestellte Veranstaltung mit eigenem Namen, Zeitraum, Belohnungen und Regeln. Das System soll so generisch sein, dass neue Typen später leicht ergänzt werden können.

---

### 5.1 Admin-Panel — Event erstellen & verwalten

✅ Events erstellen (Name, Beschreibung, Start, Ende, Währungsname, Banner-Farbe)  
✅ Event vorzeitig beenden  
✅ Event löschen (kaskadierend)  
✅ Shop-Items hinzufügen/entfernen  
✅ Event-Währung an Spieler vergeben  

⏳ **Event-Typ auswählen** beim Erstellen (Vorlage: Sammel, Boss, Schmiede, Dungeon-Rush, Handels-Expedition) — bestimmt welche Konfigurationsfelder erscheinen  
⏳ **Typ-spezifische Einstellungen** speichern (z.B. Missionsdauer für Sammel-Event, Boss-HP für Boss-Event)  
⏳ **Ranglisten-Belohnungen** konfigurieren: Admin legt fest welcher Rang welches Item / welche Währungsmenge erhält (z.B. Platz 1–3: Item X, Platz 4–10: 500 Gold)  
⏳ **Push-Notification beim Event-Start** optionally aktivierbar — Admin kann bei der Event-Erstellung "Spieler benachrichtigen" anhaken  
⏳ **Typ-Vorschau** im Admin-Panel: kurze Beschreibung was der gewählte Typ tut, damit der Admin versteht was er einstellt  

---

### 5.2 In-App Event-Anzeige

✅ `EventBannerWidget` — kompaktes Banner auf dem Hauptscreen  
✅ `EventsListScreen` — Liste aktiver Events  
✅ `EventShopScreen` — vollständiger Event-Shop  

⏳ **Schwebendes Event-Tipp-Widget** auf der rechten Seite des Hauptscreens: kleines, animiert schwebendes Panel zeigt Event-Icon (aus Banner-Farbe generiert) und Countdown im Format `4T 2H`. Ersetzt das bestehende `EventBannerWidget` als primären Einstiegspunkt.  
⏳ **Vollbild-Event-Seite**: Tippen auf das Widget öffnet eine eigene Seite die das ganze Display einnimmt (kein Popup/Sheet, sondern `Navigator.push`). Enthält: Event-Header (Name, Beschreibung, Countdown, Banner-Farbe), typ-spezifischen Spielbereich (siehe 5.3), Event-Shop-Tab, Rangliste-Tab.  
⏳ **Countdown-Format** `XD XH XM` — unter 1 Tag: `XH XM`, unter 1 Stunde: `XM XS` (Dringlichkeits-Gefühl erzeugen)  
⏳ **Event-Ende-Benachrichtigung** via `flutter_local_notifications`: wenn ein Event in < 1h endet und der Spieler noch teilgenommen hat, lokale Notification schicken  

---

### 5.3 Event-Typen (Vorlagen)

Jede Vorlage definiert nur Standardwerte — alle Felder sind im Admin-Panel überschreibbar.

---

#### Typ A — Sammel-Event (`collection`)
✅ Grundstruktur (Event-Währung sammeln, Event-Shop)  

**Spielmechanik:** Spieler schicken Helden auf Sammel-Missionen und bringen Event-Ressourcen zurück. Einzeln oder als Clan-Gruppe. Clan-Mitglieder können ihre Ressourcen zusammenlegen für einen gemeinsamen Clan-Score.

**Admin-Konfiguration (⏳ fehlt):**
- Missionsdauer-Optionen (z.B. 30 Min / 2h / 8h) und Ressourcenausbeute pro Mission
- Solo-Rangliste und/oder Clan-Rangliste aktivieren
- Rang-Belohnungen: Admin legt Belohnungen pro Platzierung fest (Item-ID oder Gold-Betrag)
- Max. Missionen gleichzeitig (Slot-Limit)

**Rangliste (⏳ fehlt):** Live-Rangliste nach gesammelten Ressourcen. Eigene Position immer sichtbar. Am Event-Ende: automatische Belohnungsverteilung per Rang.

---

#### Typ B — Community-Boss (`world_boss`)
✅ Boss spawnt alle 6h, globaler HP-Pool  
✅ Spieler können angreifen, Schaden wird pro Spieler getrackt  
✅ Top-10-Rangliste mit Spielernamen  

**Neu / ⏳ fehlt:**
- Boss **pro Event konfigurierbar**: Admin legt Boss-HP, Boss-Name, Boss-Dauer, maximaler Schaden pro Angriff fest (statt hartcodierter Werte)
- **Rang-Belohnungen** konfigurierbar (Platz 1–3, Top-10, alle Teilnehmer)
- **Boss-Bild / Icon** wählbar aus Vorlagen-Set (für die Event-Seite)
- Mehrere Boss-Phasen optional: Boss wechselt bei 50 % HP Aussehen und Schadens-Cap

---

#### Typ C — Schmiede-Wettbewerb (`forge_tournament`)
**Spielmechanik:** Während der Event-Laufzeit zählt jedes geschmiedete Item Punkte. Items über einem Mindest-Tier (einstellbar) geben Bonus-Punkte. Wer am Ende die meisten Punkte hat, gewinnt. Motiviert zum aktiven Spielen statt nur Ressourcen-Sammeln.

**Admin-Konfiguration (⏳ alles):**
- Mindest-Tier für Punkte (z.B. ab `rare`)
- Punkte-Multiplier pro Tier (`common=1, uncommon=2, rare=5, epic=10, legendary=25`)
- Rang-Belohnungen konfigurierbar
- Ob Bulk-Crafting zählt (ja/nein)

**Rangliste:** Punkte kumulieren sich über die gesamte Event-Laufzeit. Live-Updates.

---

#### Typ D — Dungeon-Rush (`dungeon_rush`)
**Spielmechanik:** Für die Event-Dauer wird ein exklusiver Event-Dungeon freigeschaltet. Jedes erfolgreiche Durchspielen (Clear) zählt als Punkt. Schwierigkeit und Dungeon-Name sind admin-konfigurierbar. Der Dungeon kann nur während des Events betreten werden.

**Admin-Konfiguration (⏳ alles):**
- Dungeon-Name und Beschreibung (erscheint auf der Event-Seite)
- Schwierigkeits-Einstellung (normal / hard / nightmare)
- Max. Clears pro Tag (verhindert Farming durch Hardcore-Spieler die alle anderen abgehängt hätten)
- Rang-Belohnungen konfigurierbar (Top-3, Top-10, alle die mindestens 1 Clear haben)
- Ob eine Mindest-Stärke vorausgesetzt wird

**Rangliste:** Anzahl Clears. Bei Gleichstand entscheidet Zeitpunkt des letzten Clears.

---

#### Typ E — Handels-Expedition (`trade_expedition`)
**Spielmechanik:** Spieler schicken Expeditionen auf Event-spezifische Handelsrouten. Je länger die Route, desto mehr Event-Währung kehrt zurück. Clan-Mitglieder können Routen gemeinsam nutzen (Clan-Expedition gibt Bonus). Event-Währung wird im Event-Shop eingetauscht.

**Admin-Konfiguration (⏳ alles):**
- 2–4 Routen mit unterschiedlicher Dauer und Ausbeute
- Clan-Bonus-Multiplikator (z.B. +20 % wenn 3+ Mitglieder gleichzeitig auf Route)
- Max. aktive Expeditionen pro Spieler
- Event-Währungs-Ausbeute skalierbar
- Rang-Belohnungen optional (nach gesamt gesammelter Währung)

---

### 5.4 Ranglisten-System (Event-übergreifend)

⏳ **Allgemeines Ranking-Framework**: jeder Event-Typ kann eine oder mehrere Ranglisten haben (Solo, Clan)  
⏳ **Live-Leaderboard** auf der Event-Seite: Top 100, eigene Position immer eingeblendet (auch wenn außerhalb Top 100)  
⏳ **Rang-Belohnungen automatisch verteilen** beim Event-Ende: serverseitiger Job der alle Gewinner ermittelt und `pending_rewards` befüllt (Gold oder Item)  
⏳ **Belohnungs-Konfiguration im Admin**: Admin definiert Rang-Brackets (z.B. `[{"from":1,"to":1,"itemId":"legendary_sword"},{"from":2,"to":10,"gold":5000}]`)  

---

### 5.5 Push-Benachrichtigungen für Events

⏳ **Event-Start-Notification** (optional, admin-aktivierbar): wenn Admin ein Event erstellt und "Benachrichtigen" anhakt, erhalten alle Spieler eine Push-Notification beim Start  
⏳ **Event-Ende-Warnung**: lokale Notification 1h vor Event-Ende für aktive Teilnehmer  
⏳ **Rang-Belohnungs-Notification**: wenn Belohnungen nach Event-Ende vergeben wurden, erhält der Spieler eine Notification mit seinem Rang und der Belohnung  

---

### 5.6 Datenbankänderungen (⏳ offen)

```sql
-- Event-Typ und Typ-Konfiguration
ALTER TABLE seasonal_events ADD COLUMN IF NOT EXISTS event_type TEXT
  CHECK (event_type IN ('collection','world_boss','forge_tournament','dungeon_rush','trade_expedition'))
  DEFAULT 'collection';
ALTER TABLE seasonal_events ADD COLUMN IF NOT EXISTS type_config JSONB DEFAULT '{}';

-- Rang-Belohnungen (Admin-konfigurierbar pro Event)
CREATE TABLE IF NOT EXISTS event_rank_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  rank_from INT NOT NULL,
  rank_to   INT NOT NULL,
  reward_type TEXT CHECK (reward_type IN ('gold','item')) NOT NULL,
  amount INT,
  item_id TEXT,
  leaderboard_type TEXT DEFAULT 'solo'  -- 'solo' | 'clan'
);

-- Event-Teilnahme / Punkte-Tracking
CREATE TABLE IF NOT EXISTS event_player_scores (
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  event_id  UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  score     BIGINT NOT NULL DEFAULT 0,
  meta      JSONB  DEFAULT '{}',  -- typ-spezifische Zusatzdaten
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (player_id, event_id)
);

-- Clan-Score für Clan-Rangliste
CREATE TABLE IF NOT EXISTS event_clan_scores (
  clan_id  UUID REFERENCES clans(id) ON DELETE CASCADE,
  event_id UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  score    BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (clan_id, event_id)
);

-- Belohnungs-Vergabe-Log (verhindert Doppelvergabe)
CREATE TABLE IF NOT EXISTS event_rewards_distributed (
  event_id  UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  rank      INT NOT NULL,
  rewarded_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (event_id, player_id)
);
```

---

### Implementierungs-Reihenfolge (empfohlen)

| Schritt | Was | Aufwand |
|---------|-----|---------|
| 1 | DB-Schema erweitern (`event_type`, `type_config`, `event_player_scores`, `event_rank_rewards`) | 1 Tag |
| 2 | Admin-Panel: Event-Typ-Auswahl + Typ-Konfigurationsfelder + Rang-Belohnungen | 2–3 Tage |
| 3 | Flutter: schwebendes Widget + Vollbild-Event-Seite mit Tab-Struktur | 2 Tage |
| 4 | Sammel-Event (Typ A): Score-Tracking API + Flutter Mission-UI | 3 Tage |
| 5 | Community-Boss (Typ B): Config-Parameter aus DB statt Hardcode | 1 Tag |
| 6 | Ranglisten-Framework + automatische Belohnungsverteilung bei Event-Ende | 2 Tage |
| 7 | Schmiede-Wettbewerb (Typ C): Score-Hook in craftItem + Rangliste | 2 Tage |
| 8 | Dungeon-Rush (Typ D): Event-Dungeon-Freischaltung + Clear-Tracking | 3 Tage |
| 9 | Handels-Expedition (Typ E): Event-Routen + Clan-Bonus | 3 Tage |
| 10 | Push-Notifications für Event-Start, Ende-Warnung, Belohnungen | 2 Tage |

**Gesamtaufwand geschätzt:** ~3–4 Wochen für das komplette System.

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
| 14 | Event-Typ-System + Admin-Konfig | 5 | Groß |
| 15 | Schwebendes Widget + Vollbild-Event-Seite | 5 | Mittel |
| 16 | Sammel-Event (Typ A) | 5 | Groß |
| 17 | Community-Boss konfigurierbar (Typ B) | 5 | Klein |
| 18 | Schmiede-Wettbewerb (Typ C) | 5 | Mittel |
| 19 | Dungeon-Rush (Typ D) | 5 | Groß |
| 20 | Handels-Expedition (Typ E) | 5 | Groß |
| 21 | Ranglisten-Framework + auto. Belohnungen | 5 | Groß |
| 22 | Push-Notifications für Events | 5 | Mittel |

**Empfehlung zum Start:** Phase 1 komplett abschließen (ein Wochenende), dann mit Täglichen Herausforderungen beginnen — das hat den besten Verhältnis aus Aufwand und spürbarem Mehrwert für die Spieler.
