# Idle Forge — Feature-Plan

Alle geplanten Features, priorisiert nach Aufwand und Impact.
Reihenfolge: Phase 1 → 8, innerhalb einer Phase nach Priorität.

**Überblick:**
- **Phase 1–4**: Kernfeatures (teilweise implementiert)
- **Phase 5**: Event-System-Erweiterung (in Arbeit)
- **Phase 6–8**: 20 neue Game Features (Strategy, Progression, Community, RPG-Elemente)
- **Web Features**: 10 neue Angular-Frontend Features
- **Tech-Evaluation**: Game Engine für Flutter/Dart

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

> **Status:** Teilweise implementiert (Backend vorhanden, Frontend-Erweiterungen ⏳)

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

---

---

# TEIL 2: 20 NEUE GAME FEATURES (PHASE 6–8)

## Phase 6 — Progression & RPG-Vertiefung (2–4 Wochen)

Neue Features die das Progression-System erweitern und mehr RPG-Tiefe bringen.

### 6.1 Skill-System & Fähigkeiten
**Beschreibung:** Spieler lernen aktive Skills (z.B. „Flammenschlag", „Schutzschild") die sie im Kampf aktivieren können. Skills haben Cooldowns und kosten Mana. Durch Ausrüstung und Passiv-Skills können Skills gepowertet werden (mehr Schaden, kürzerer Cooldown).  
**Aufwand:** Backend (Skill-Datenbank, Mana-System) + Frontend (Combat-UI mit Skill-Buttons, Cooldown-Anzeige)  
**Abhängigkeiten:** Combat-System (bereits vorhanden)  
**Nutzen:** Macht Kämpfe taktischer statt nur automatisch  
**Tech:** Neue DB-Tabelle `player_skills`, Skill-Configs in JSON

### 6.2 Runen & Sockelsystem
**Beschreibung:** Items können Sockels haben (je nach Tier 1–3). Spieler können Runen (kleinere Artefakte) in Sockels einsetzen. Jede Rune gibt kleine Boni (z.B. +5 % Schaden, +10 Gold-Ertrag). Runen können aus speziellen Dungeons gedroppt werden.  
**Aufwand:** Backend (neue Tabellen `runes`, `item_sockets`, Runen-Drop-Logik) + Frontend (Socket-UI, Rune-Crafting-Screen)  
**Abhängigkeiten:** Item-System (bereits vorhanden), Dungeon-System (bereits vorhanden)  
**Nutzen:** Gibt Power-Gaming-Spielern tiefere Optimierungs-Möglichkeiten  
**Economy:** Anti-Inflation-Mechanismus (Runen sind schwer zu farmen)

### 6.3 Transmog & Kosmetik-Skins
**Beschreibung:** Spieler können das Aussehen eines Items auf ein anderes „übertragen" (Transmog). Ein Helm kann wie ein Kronendiadem aussehen, ohne die Stats zu verlieren. Skins können aus Events oder dem Prestige-Shop kommen.  
**Aufwand:** Frontend (Transmog-UI, Rendering-System für Item-Skins) + Backend (Skin-Mapping-Tabelle)  
**Abhängigkeiten:** Item-System, Prestige-Shop (Phase 2.4)  
**Nutzen:** Spieler-Individualität, beliebt in Action-RPGs  
**Hinweis:** Senkt Druck auf Content-Updates (alte Items sehen neu aus)

### 6.4 Herausforderungs-Dungeons (Challenge Mode)
**Beschreibung:** Spezielle, schwerere Dungeon-Varianten mit Modifiern (z.B. „Gegner haben 2x HP", „Spieler regeneriert weniger"). Erfolgreicher Clear gibt exklusive Belohnungen. Pro Dungeon gibt es bis zu 5 Schwierigkeitsstufen.  
**Aufwand:** Backend (Modifier-System, Schwierigkeits-Skalierung, Belohnungs-Tabelle) + Frontend (Modifier-Anzeige, Challenge-Mode-Toggle)  
**Abhängigkeiten:** Dungeon-System, Belohnungs-System (bereits vorhanden)  
**Nutzen:** Endgame-Content, Hardcore-Spieler brauchen etwas zum Arbeiten  
**Balance:** Challenge-Items sollten *nicht* besser sein als normale Items — nur exklusiv

### 6.5 Passive Skill-Tree (Ascension 2.0)
**Beschreibung:** Neuer großer Passive-Skill-Tree für erworbene Punkte. Spieler können permanent kleine Boni wählen (z.B. +2 % Schaden, +1 % Kritrate, +5 % Exp-Ertrag). Tree hat viele Pfade und Verzweigungen.  
**Aufwand:** Backend (Tree-Graph speichern, Punkte-Allocation) + Frontend (Tree-Visualisierung, interaktive Auswahl)  
**Abhängigkeiten:** Progression-System, Prestige-System (bereits vorhanden)  
**Nutzen:** Großer Progression-Milestone nach Prestige — beliebt wie Path of Exile Passive Tree  
**UI:** Tree sollte schöne Verzweigungen haben und visuell ansprechend sein

### 6.6 Gegenstands-Inschriften & Legendäre Effekte
**Beschreibung:** Legendäre Items haben einzigartige Fähigkeiten (z.B. „Stiefel der Windläufer: +50 % Bewegungsgeschwindigkeit"). Diese Effekte sind nicht stackbar — die stärkste Inschrift wird aktiv. Spieler sammeln legendäre Items wie Reliquien.  
**Aufwand:** Backend (Unique-Item-Database, Effekt-System) + Frontend (Effekt-Tooltip, Uniqueness-Anzeige)  
**Abhängigkeiten:** Item-System, Drop-System (bereits vorhanden)  
**Nutzen:** Collector's Dream, hoher Grind-Anreiz für spezifische Items  
**Balance:** Legendäre Items sollten *nicht* übermächtig sein — nur thematisch einzigartig

### 6.7 Meisterschafts-Abzeichen & Erfolgs-System
**Beschreibung:** Spieler können Meisterschafts-Abzeichen verdienen (z.B. „Drachentöter", „Goldgierig", „Sozialschmetterling") durch spezifische Leistungen. Abzeichen sind auf dem Profil sichtbar und geben kleine permanente Boni (+0,5 % pro Abzeichen).  
**Aufwand:** Backend (Badge-Tabelle, Fortschritts-Tracking) + Frontend (Badge-Showcase auf Profil, Badge-Quest-Monitor)  
**Abhängigkeiten:** Spielerprofil (2.2), Achievement-Tracking  
**Nutzen:** Langjährige Ziele, Alt-Account-Prevention, Social-Prestige  
**Beispiele:** 
- „Drachentöter": World Boss 100x besiegt → +0,5 % Schaden
- „Schmiedemeister": 10.000 Items geschmiedet → +0,5 % Craftgeschwindigkeit
- „Freundlich": 100 PVP-Duelle gegen Freunde → +0,5 % Gold-Ertrag

---

## Phase 7 — Strategie & Clan-Gameplay (2–4 Wochen)

Neue Features die Clan-Interaktion vertiefen und strategisches Spielen fördern.

### 7.1 Clan-Basis & Struktur-Upgrade
**Beschreibung:** Jeder Clan hat eine Basis mit Gebäuden (Schmiede, Barracks, Bibliothek). Clan-Ressourcen (von allen Mitgliedern verdient) können zum Upgraden der Gebäude genutzt werden. Höhere Level = bessere Boni für alle Clan-Mitglieder (z.B. Schmiede Level 5 = +10 % Crafting-Geschwindigkeit).  
**Aufwand:** Backend (Clan-Gebäude-Table, Upgrade-Logik, Clan-Ressourcen-Tracking) + Frontend (Basis-UI, Upgrade-Queue)  
**Abhängigkeiten:** Clan-System (bereits vorhanden)  
**Nutzen:** Gibt Clans gemeinsame langfristige Ziele, Loyalität  
**Features:** 
- Gebäude-Upgrades können in eine Queue (z.B. max. 2 gleichzeitig)
- Vollendung kann durch Clan-Währung beschleunigt werden
- Abgelöste Leader können Gebäude sperren (Anti-Sabotage)

### 7.2 Clan-Quests & Missionen
**Beschreibung:** Admin kann pro Clan zeitlich begrenzte Quests erstellen (z.B. „10 Weltbosse besiegten", „100.000 Gold verdienen"). Alle Mitglieder tragen gemeinsam bei. Am Ende: Clan erhält Belohnung (Gold, Items, Prestige).  
**Aufwand:** Backend (Clan-Quest-Table, Fortschritts-Tracking, Aggregation) + Frontend (Quest-Panel, Beitrags-Anzeige)  
**Abhängigkeiten:** Clan-System, Admin-Panel  
**Nutzen:** Gibt Clans wöchentliche Aktivitäten neben Clan Wars, fördert Kooperation  
**Unterschied zu Daily Challenges:** Persönlich (1 Person) vs. Clan-weite Quests (ganzes Team)

### 7.3 Clan-Dungeon (Instanz für 3–5 Spieler)
**Beschreibung:** Spezielle Dungeons nur für Clan-Mitglieder. 3–5 Spieler starten gemeinsam (synchron, nicht async). Schwieriger als normale Dungeons. Belohnungen: Items, Clan-Gold.  
**Aufwand:** Backend (Instanzen-Management, Sync-Mechaniken, Drop-Logik) + Frontend (Lobby, Multiplayer-UI, Loot-Distribution)  
**Abhängigkeiten:** Dungeon-System, Multiplayer-Grundlagen  
**Nutzen:** Neue Multiplayer-Dimension, bonding-Erlebnis, hoher Engagement-Wert  
**Tech:** Real-time Synchronisation über WebSocket oder Polling

### 7.4 Handels-Karawanen zwischen Clans
**Beschreibung:** Clans können Handel treiben — Clan A schickt eine Karawane mit Items/Gold zu Clan B. Beide Seiten müssen zustimmen. Handelshistorie wird getracked (Transparenz-Tool).  
**Aufwand:** Backend (Handels-Table, Verhandlungs-State-Machine, Transaktions-Logik) + Frontend (Trade-Negotiation-UI)  
**Abhängigkeiten:** Item-System, Clan-System  
**Nutzen:** Clan-Diplomatie, Anti-Pay-to-Win Mechanismus (Clans können Ressourcen teilen, müssen nicht auf Gacha hoffen)  
**Anti-Exploit:** Alle Trades müssen verifiziert sein (keine Dupe-Exploit-Möglichkeit)

### 7.5 Clan-Territorium & Ressourcen-Generator
**Beschreibung:** Die Spielwelt hat Territorien (z.B. „Goldminen", „Krystall-Berge"). Clans können um Territorien kämpfen (analog zu Clan War). Owner-Clan generiert regelmäßig Ressourcen aus dem Territorium (z.B. Gold pro Stunde). Nach 2 Wochen können neue Clans Challenge lancieren.  
**Aufwand:** Backend (Territory-Table, Resource-Generation, Contested-State) + Frontend (World-Map mit Territiories, Claim-UI)  
**Abhängigkeiten:** Clan-War-System, Economy-System  
**Nutzen:** Stärkste langfristige Clan-Motivation — passive Einnahmequelle motiviert große Clans zu bestehen  
**Balance:** Ressourcen-Generierung sollte gering sein (nicht game-breaking)

### 7.6 Clan-Events & Turniere
**Beschreibung:** Admin kann Clan-Turniere ausschreiben (z.B. PVP-1v1-Bracket, Dungeon-Speed-Run-Relays). Clans treten als Teams an. Gewinner-Clan erhält Ehren-Banner und Ressourcen.  
**Aufwand:** Backend (Tournament-Framework, Bracket-Generator, Matching-Logic) + Frontend (Bracket-Viewer, Live-Updates)  
**Abhängigkeiten:** PVP-System, Clans (bereits vorhanden)  
**Nutzen:** Regelmäßige große Events, spektakulär für Zuschauer  
**Beispiele:** 
- PVP-Meisterschaft: 16 Top-Clans treten an
- Relay-Race: 3er Teams, Pass-the-Baton zu stärksten Item-Drops
- Dungeon-Speed-Run: Schnellster Durchspielen

### 7.7 Clan-Nachrichten & Pinboard
**Beschreibung:** Erweiterte Clan-Kommunikation — News-Pinboard für wichtige Ankündigungen. Leader kann Nachrichten pinnen. System trackt Leserstatus (Leader sieht wer Nachricht gelesen hat). Optional: Integration mit Discord-Webhook für externe Benachrichtigungen.  
**Aufwand:** Frontend (News-UI, Read-Status) + Backend (Nachrichten-Table, Read-Tracking)  
**Abhängigkeiten:** Clan-System  
**Nutzen:** Bessere interne Kommunikation, Leader-Tools  
**Beispiel:** „Morgen 20:00 Clan War, alle müssen aktiv sein!" — alle sehen ob verstanden

---

## Phase 8 — Community & Endgame (2–4 Wochen)

Endgame-Features und Gemeinschafts-Content.

### 8.1 Globale Rankings & Saisons
**Beschreibung:** Wöchentliche globale Rankings nach verschiedenen Kriterien (Total-Stärke, Prestige-Level, PVP-Wins, Schmiedemeister-Score). Top-100 erscheinen auf einer globalen Leaderboard. Am Ende der Saison (Monat) erhalten Top-Spieler kosmetische Skins und Belohnungen.  
**Aufwand:** Backend (Ranking-Aggregation via scheduled jobs, Saison-Tracking) + Frontend (Leaderboard-Seite mit Filterung)  
**Abhängigkeiten:** Spielerdaten  
**Nutzen:** Prestige-System, Retention über Saison-End-Goals  
**Tech:** Optimiert mit Materialized Views / Caching (nicht bei jedem Request neu aggregieren)

### 8.2 Mythische Raids (8–10 Spieler)
**Beschreibung:** Schwierigste Dungeons im Spiel. 8–10 Spieler in Instanz, sehr hohes Zeitlimit, komplexe Phasen mit Mechanics. Loot: beste Items im Spiel, seltene Runen, exklusive Transmog-Skins.  
**Aufwand:** Backend (Raid-Logik, Komplexe Mob-AIs, Loot-Table) + Frontend (Raid-Matchmaking, Lobby, Complex-UI)  
**Abhängigkeiten:** Multiplayer-Infrastruktur, Dungeon-System, Item-System  
**Nutzen:** Hardcore-Endgame-Content, Clan-Unite-Mechanik, Speedrun-Community  
**Balance:** SEHR schwierig — sollte nur Top-10%-Clans bearbeiten können

### 8.3 Transmuter-Shop (Item-Conversion & Upgrade-Crafting)
**Beschreibung:** Spieler können alte Items „konvertieren" (z.B. 3x Epic → 1x Legendary-Chunk). Chunks können gedroppt oder gekauft werden. Mit genug Chunks kann man ein Transmuter-Rezept craften (z.B. „Flammenschwert +2").  
**Aufwand:** Backend (Transmuter-Rezept-DB, Conversion-Logik) + Frontend (Transmuter-UI, Recipe-Discovery)  
**Abhängigkeiten:** Item-System  
**Nutzen:** Sink für alte Items (Anti-Inflation), Path for Target-Item-Farming  
**Beispiel:** 
- Brauche „Stiefel der Schneegöttin"
- Könnte auf Drops warten (1/1000 Chance)
- Oder: Sammle 100 „Legendary Boots Chunks" durch Transmuting andere Boots
- Dann: Rezept farmen → craften → Spezial-Stiefel erhalten

### 8.4 Infinite Dungeon (Roguelike-Elemente)
**Beschreibung:** Dungeon ohne Ende — Spieler geht Stufe für Stufe tiefer. Mit jeder Stufe werden Gegner stärker. Aber auch Rewards steigen. Wenn Spieler stirbt, endet Run. Globale Rangliste nach erreichte Tiefe trackt Top-Runs.  
**Aufwand:** Backend (Endless-Dungeon-Logik, Skalierung, Death-Check) + Frontend (Depth-Counter, Run-History)  
**Abhängigkeiten:** Combat-System, Dungeon-System  
**Nutzen:** Zero-Entry-Hardcore-Challenge, bragging rights  
**Twist:** Optional: Kurz vor die zu tiefe zu gehen einen „Exit-Point" (Spieler kann QuittenSave machen und später weitermachen, wenn er vorsichtig ist)

### 8.5 Guild Bank & Shared Resources
**Beschreibung:** Clans haben eine gemeinsame Bank. Leader/Officer können Items und Gold darin lagern. Normale Members können Items rausnehmen (aber nicht einlagern). Transparenz: Bank-Logis wird trackt (wer hat was wann rausgenommen).  
**Aufwand:** Backend (Guild-Bank-Table, Permissions, Transaktions-Log) + Frontend (Bank-UI, Permissions-Manager)  
**Abhängigkeiten:** Clan-System, Permissions-Framework  
**Nutzen:** Neue Spieler können equipped werden (Handouts von erfahrenen Playern), Clan-Cooperation Tool  
**Anti-Grief:** Nur Leader/Officer können einlagern — verhindert dass neue Members alles rausnehmen

### 8.6 Seasonal Pass & Battle Pass (Optional Monetization)
**Beschreibung:** Optional kostenpflichtiger/freier Battle Pass. Spieler sammeln Pass-XP durch normale Spielaktivitäten. Mit jedem Level unlock der Pass neue Belohnungen (Skins, Emotes, kleine Boosts). Premium-Pass-Käufer erhalten bonus Items.  
**Aufwand:** Backend (Pass-Level-Tracking, Pass-Inventory) + Frontend (Pass-UI, Tier-Display, Purchase-Flow)  
**Abhängigkeiten:** Payment-System (bereits vorhanden?), Item-System  
**Nutzen:** Monetization-Quelle, Spieler-Engagement über Saison  
**Design:** Pass sollte optional sein — Free-Players können auch durchspielen (keine Pay-to-Win)

---

---

# TEIL 3: 10 NEUE WEB FEATURES

Die Angular-Web-Anwendung erhält folgende Frontend-Features:

### W.1 Web-Dashboard mit Statistiken
**Beschreibung:** Landing-Page nach Login mit Spiel-Übersicht: aktueller Stärke-Level, nächstes Prestige-Milestone, aktive Events, Top-Achievements, Clan-War-Status.  
**Aufwand:** 1 Woche (Backend: Data-Aggregations-API, Frontend: Dashboard-Komponenten + Charts)  
**Abhängigkeiten:** keine  
**Priorität:** Hoch

### W.2 Vollständige Inventar-Verwaltung im Web
**Beschreibung:** Web-Portal zur Inventar-Verwaltung — Filter, Sortierung, Vergleich, Transmog-Preview, direkt Items zum Auktionshaus stellbar.  
**Aufwand:** 1 Woche (komplexe Filter-Komponente, Transmog-Preview, Auktionshaus-Integration)  
**Abhängigkeiten:** Auktionshaus-API (bereits implementiert)  
**Priorität:** Mittel

### W.3 Raid-Planner & Team-Builder
**Beschreibung:** Tool zum Planen von Raid-Teams. Mitglieder-Roster anzeigen, Komposition analysieren (z.B. „3 Tanks, 2 Healer, 3 DPS"). Raid-Aufzeichnungen speichern.  
**Aufwand:** 5 Tage (Backend: Raid-Planner-API, Frontend: Roster-Komponente, Komposition-Analyzer)  
**Abhängigkeiten:** Clan-System  
**Priorität:** Mittel

### W.4 Analytik-Dashboard (für Leader)
**Beschreibung:** Leader-Tool zur Clan-Analytik — Aktivitätstrends, Mitglieder-Aktivität im Zeitverlauf, Ressourcen-Flow, Einzahlungen/Ausgaben in Clan-Bank tracken.  
**Aufwand:** 1 Woche (Backend: Analytics-APIs, Frontend: Charts mit Trend-Daten)  
**Abhängigkeiten:** Clan-System, Guild-Bank (Phase 8.5)  
**Priorität:** Mittel

### W.5 Build-Calculator & Optimizer
**Beschreibung:** Tool zum Theorycraft — Spieler kann Items, Skills, Runen zusammenstellen und sieht berechnete finale Stats (DPS, Crit-Rate, etc.). Kann Builds als Links teilen.  
**Aufwand:** 5 Tage (Frontend: Complex-Calculator-UI, Backend: Build-Validation-API, Sharing)  
**Abhängigkeiten:** Item-System, Skill-System (Phase 6.1)  
**Priorität:** Hoch (Hardcore-Spieler lieben das)

### W.6 Event-Manager für Admins (erweitert)
**Beschreibung:** Erweiterte Admin-Tools — Event-Vorschau (wie sieht Event aus in-game?), Live-Monitoring (aktuelle Spieler-Partizipation, Scores), Quick-Adjustments (z.B. Währungsausbeute erhöhen mid-event).  
**Aufwand:** 1 Woche (Frontend: Event-Preview, Live-Monitor, Backend: APIs für Live-Statistiken)  
**Abhängigkeiten:** Event-System (Phase 5)  
**Priorität:** Mittel

### W.7 Community-Forum / Nachrichten-Board
**Beschreibung:** In-Game-Forum direkt im Web-Portal. Spieler können Beiträge erstellen, Communitys folgen. Threads sind nach Kategorie sortiert (Bugs, Suggestions, Lore, Trading-Post).  
**Aufwand:** 2 Wochen (Backend: Forum-DB, Moderation-APIs, Frontend: Full Forum-App mit Pagination/Search)  
**Abhängigkeiten:** keine  
**Priorität:** Mittel (schön zu haben, aber nicht kritisch)

### W.8 Trade-Post (weltweites Handels-Board)
**Beschreibung:** In-Game-Handels-Portal wo Spieler Items kaufen/verkaufen können (ähnlich Auktionshaus, aber mit kürzeren Listings). Spieler können Angebote machen („Suche Legendären Helm, biete 50.000 Gold").  
**Aufwand:** 1 Woche (Backend: Trade-Listing-API, Frontend: Trade-Board-UI mit Suchfilter)  
**Abhängigkeiten:** Item-System  
**Priorität:** Mittel (Alternative zu Auktionshaus für bilaterale Deals)

### W.9 Achievement-Gallery & Stats-Export
**Beschreibung:** Spieler-Profil-Seite im Web mit vollständiger Achievement-Gallery, Charakterstatistiken (GTA-V-Style: „Dungeons geklärt: 5.432", „Items geschmiedet: 123.456", etc.), Export zu CSV/PDF.  
**Aufwand:** 5 Tage (Backend: Stats-Aggregations-API, Frontend: Gallery + Export)  
**Abhängigkeiten:** Spielerprofil (2.2)  
**Priorität:** Niedrig (Nice-to-Have für Achievement-Sammler)

### W.10 Patch-Notes & Update-Ticker
**Beschreibung:** Zentrale Seite für Patch-Notes, Update-Ankündigungen, Wartungsarbeiten. Spieler können sich für Benachrichtigungen anmelden (E-Mail). Newsletter-Integration.  
**Aufwand:** 3 Tage (Backend: News-API, Frontend: News-Feed + Subscription)  
**Abhängigkeiten:** keine  
**Priorität:** Mittel (wichtig für Community-Transparenz)

---

---

# TEIL 4: GAME ENGINE-EVALUIERUNG FÜR FLUTTER/DART

Aktuell verwendet Idle Forge Flutter's natives rendering (Skia) mit einem eigenentwickeltem `GameController`. Für zukünftige 2D/3D-Features könnte eine spezialisierte Game Engine sinnvoll sein.

## Evaluierte Optionen

### Option A: **Flame Engine** ✅ EMPFOHLEN

**Was ist Flame?**
- Pure Dart Game Engine built for Flutter
- 2D-fokussiert (Sprites, Physics, Collision-Detection)
- Tight Flutter-Integration
- Active Community

**Vorteile:**
- ✅ Einfachste Integration mit bestehendem Flutter-Code
- ✅ Hot-Reload funktioniert (iterativer Entwicklung!)
- ✅ Kostenlos, Open-Source
- ✅ Gute Dokumentation
- ✅ Particle Systems, Animations eingebaut
- ✅ Perfect für 2D-RPG-Combat

**Nachteile:**
- ❌ Keine 3D-Grafiken
- ❌ Kleinere Community vs. Unity/Godot
- ❌ Performance bei hunderten Entities kann problematisch sein

**Eignet sich für:**
- Enhanced Dungeon-Visuals
- Schöne Combat-Animationen
- Particle-Effects bei Skills
- Mini-Games (Match-3, Clicker-Minigames)

**Ressourcen:**
- [flame.dev](https://flame.dev)
- Pubspec-Package: `flame: ^1.0.0`
- Tutorials: [FlutterFire Series](https://www.youtube.com/watch?v=GxJRh8VhG0s)

**Geschätzter Aufwand für erste Integration:**
- Basis-Setup: 2–3 Tage
- Combat-Visuals: 1 Woche
- Particle-Effects: 1 Woche
- **Total: 2–3 Wochen**

---

### Option B: **Bevy (Rust, via FFI)** ⚠️ MACHBAR ABER KOMPLEX

**Was ist Bevy?**
- Rust-basierte Game Engine (2D + 3D)
- Über FFI (Foreign Function Interface) in Dart aufrufbar
- Extrem performant

**Vorteile:**
- ✅ Sehr hohe Performance
- ✅ 3D-fähig (für zukünftige Features)
- ✅ Industry-Standard (AAA-Studios nutzen ähnliche Patterns)

**Nachteile:**
- ❌ Complex FFI-Setup notwendig
- ❌ Deutlich höherer Komplexität vs. Flame
- ❌ Hot-Reload funktioniert nicht einfach
- ❌ Steile Lernkurve (Rust lernen notwendig)

**Eignet sich für:**
- AAA-Level Graphics
- Zukünftige 3D-Features (z.B. Realm-Mode)
- Extreme Performance-Anforderungen

**Geschätzter Aufwand für erste Integration:**
- FFI-Bridge: 1 Woche
- Bevy-Lernen: 2 Wochen
- Combat-Engine: 2 Wochen
- **Total: 5+ Wochen + Rust-Expertise notwendig**

---

### Option C: **Unity (via Mobile)**  ❌ NICHT EMPFOHLEN

**Warum NICHT?**
- ❌ Nicht Dart/Flutter-nativ
- ❌ Würde kompletten App-Neuaufbau erfordern
- ❌ Größere App-Size
- ❌ Flutter-Backend-Integration schwer
- ❌ Bereits 2+ Jahre Flutter-Investment

**Nur wenn:** Kompletter 3D-AAA-Remake geplant (Industrie-Standard wäre dann eher Unreal Engine)

---

### Option D: **Godot (via GDScript Bindings)** ⚠️ EXPERIMENTAL

**Was ist Godot?**
- Open-Source Engine mit 2D + 3D Support
- Kann theoretisch in Flutter eingebettet werden

**Vorteile:**
- ✅ Open-Source
- ✅ 3D-möglich
- ✅ Große Community

**Nachteile:**
- ❌ Dart-Integration nicht offiziell supported
- ❌ Experimental-Status
- ❌ Steile Lernkurve
- ❌ Migration kompliziert

**Nicht empfohlen für Idle Forge.**

---

## EMPFEHLUNG

**Für Idle Forge (nächsten 12 Monate):**
1. **Flame Engine verwenden** für Enhanced Combat-Visuals
2. **Schrittweise Integration** — nicht kompletten Rewrite
3. **Fokus:** 
   - bessere Skill-Animationen
   - Particle-Effects für World-Bosses
   - Mini-Games (z.B. Rätselhaftes Schmied-Minigame)
4. **Zeitrahmen:** Phase 6–7 (nach anderen Features)

**Langfristig (Jahr 2+):**
- Bei Bedarf auf Bevy evaluieren (für 3D-Realm oder VR)
- Aber: Flame Engine reicht wahrscheinlich für 5+ Jahre regulären RPG-Content

---

### Flame Integration — Roadmap

| Phase | Feature | Aufwand | Engine |
|-------|---------|---------|--------|
| 6.1 | Skill-Visualisierung | 3 Tage | Flame |
| 6.1 | Combat-Particles | 5 Tage | Flame |
| 7.3 | Clan-Dungeon-Visuals | 1 Woche | Flame |
| 8.2 | Raid-Boss-Animationen | 1 Woche | Flame |
| 8.4 | Infinite-Dungeon Visuals | 1 Woche | Flame |

**Estimated Total:** 3–4 Wochen verteilt über 6 Monate

---

---

# FINALER PRIORITÄTS-ROADMAP (ALLE FEATURES)

| Phase | Feature | Kategorisierung | Aufwand | Start |
|-------|---------|-----------------|---------|-------|
| 1 | Quickwins (Filter, Bulk-Craft, Offline-Summary) | ✅ Geplant | Klein | Sofort |
| 2 | Daily Challenges, Profil, Freundschafts-Duelle | ✅ Implementiert (meisten) | Mittel | Sofort |
| 3 | Push-Notifications, World-Boss, Saisonales Event-System | ✅ Implementiert | Groß | Sofort |
| 4 | Clan Wars, Auktionshaus | ✅ Implementiert | Sehr groß | Sofort |
| 5 | Event-System-Erweiterung (Typ-Konfiguration, Ranglisten) | ⏳ In Arbeit | Groß | 1 Woche |
| 6.1–6.7 | Progression & RPG (20 Game Features Start) | ⏳ Q3 2026 | 4 Wochen | +3 Wochen |
| 7.1–7.7 | Strategie & Clan-Gameplay | ⏳ Q3 2026 | 4 Wochen | +7 Wochen |
| 8.1–8.6 | Community & Endgame | ⏳ Q4 2026 | 4 Wochen | +11 Wochen |
| W.1–W.10 | Web Features | ⏳ Q3/Q4 2026 | 2 Wochen | +5 Wochen (parallel) |
| Flame | Engine-Integration (schrittweise) | ⏳ Q4 2026+ | 4 Wochen | +15 Wochen |

**Gesamtplanung:** 
- Nächste 6 Monate: Phasen 5 + 6 + 7 + Website-Features
- Monate 7–12: Phase 8 + Flame-Integration + Community-Feedback-Zyklen
- **Zielmarke:** Sofort-spielbar für 50.000+ Spieler bis Q4 2026

---

## ABSCHLIESSENDE BEMERKUNGEN

Dieser Plan ist ein **lebendiges Dokument**. Basierend auf Spieler-Feedback werden Prioritäten angepasst. Beispielsweise wenn Spieler PVP lieben könnte Phase 7 (Clan-Features) Vorrang vor Phase 8 (Endgame) bekommen.

**Nächste Schritte:**
1. Phase 5 fertigstellen (Event-System erweitern)
2. Phase 6 planen (Design-Spezifikationen, UI-Mockups)
3. Designer + Backend-Dev für Skill-System & Runen-System rekrutieren
4. Erste Flame-Engine Prototyp für Combat-Visuals bauen

---

**Dokumentation erstellt:** 24. Juni 2026  
**Version:** 2.1  
**Maintainer:** @Game-Design-Team
