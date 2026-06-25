# Idle Forge — Feature Audit

_Stand: Juni 2026_

---

## 1. Feature-Status

| Feature | Status | Anmerkung |
|---|---|---|
| **Forge (Schmieden)** | ✅ Vollständig | Kern-Loop, stabil |
| **Inventory** | ✅ Vollständig | Slot-System, Bulk-Sell, Enchanting |
| **Dungeon** | ✅ Vollständig | Eigener Controller, Belohnungen, Schwierigkeiten |
| **World / Kapitel** | ✅ Vollständig | Progressions-System, Bosse, Meilensteine |
| **Shop** | ✅ Vollständig | Upgrades, Prestige-Shop |
| **Tränke** | ✅ Vollständig | Healing + Berserk Flasks |
| **Quests** | ✅ Vollständig | Daily-Cycle, Claim-System, Targets |
| **Pets** | ✅ Vollständig | Panel existiert, System integriert |
| **Expedition** | ✅ Vollständig | System vorhanden |
| **Recipes** | ✅ Vollständig | Known-Recipe-System |
| **Ascension / Prestige** | ✅ Vollständig | Nodes, Boni, Titles |
| **Achievements** | ✅ Vollständig | Tracking + Claim |
| **Auth (Login/Register)** | ✅ Vollständig | Username/PW + Google OAuth |
| **Leaderboard** | ✅ Vollständig | Global + Weekly, Backend vorhanden |
| **Friends** | ✅ Vollständig | Requests, Respond, Challenge |
| **PVP** | ✅ Vollständig | Battles, History, Result-Overlay |
| **Coop** | ✅ Vollständig | Session-Code, Boss-HP, Shared Damage |
| **World Boss** | ✅ Vollständig | Raid, Damage-Leaderboard |
| **Events** | ✅ Vollständig | 5 Typen, Shop, Leaderboard, Countdown |
| **Auctions** | ✅ Vollständig | Bid, Buy-Now, Claim, Cancel, Mine |
| **Clan** | ⚠️ Teilweise | Create/Join/Chat/Invites vorhanden — Clan-Profil, Level-Up, Mitglieder-Rollen fehlen |
| **Clan War** | ⚠️ Teilweise | Contribute-Button + Leaderboard da — aber kein automatischer Match-Making, kein Scheduler im Backend |
| **Daily Challenges** | ⚠️ Teilweise | Backend-Sync vorhanden, aber keine eigenständige UI — läuft über das Quest-Board |
| **Cloud Save** | ⚠️ Teilweise | Upload/Download vorhanden — Konflikt-Handling bei gleichzeitiger Nutzung mehrerer Geräte unklar |
| **Notifications** | ❌ Fehlt | Firebase eingebunden aber kein Push für Events, War-Ende, Auktionen |
| **Admin Panel** | ⚠️ Teilweise | Players, Clans da — Events-CRUD, globale Item-Verwaltung ausbaufähig |

---

## 2. Doppelte / ungewollte Features

### Problem 1 — Clan und Clan War als getrennte Tiles
`Clan` und `Clan War` sind zwei separate Einträge im More-Menü. Das ist für den User verwirrend, denn Clan War ist logisch ein **Sub-Feature von Clan**. Richtig wäre: Clan War als Tab innerhalb von `ClanScreen` (neben Mitglieder, Chat, Einladungen). Derzeit ist Clan War ein vollständig separater Einstiegspunkt.

### Problem 2 — PVP doppelt (Friends + PVP-Screen)
Im `FriendsScreen` gibt es einen „Challenge"-Button, der einen Freund zum PVP herausfordert. Der eigenständige `PvpScreen` macht dasselbe, zeigt aber auch die Battle-History. Das „Challenge"-Verhalten ist damit an zwei Stellen implementiert.

### Problem 3 — World Boss doppelt in Events
Events können vom Typ `world_boss` sein — aber es gibt auch einen eigenständigen `WorldBossScreen`. Der Unterschied zwischen „World Boss als Dauerfeature" und „World Boss als temporäres Event" ist dem Spieler nicht klar.

### Problem 4 — Daily Challenges vs. Quests
Die Quest-Anzeige in der App und `syncDailyChallenges()` im Backend sind zwei parallele Systeme, die teilweise dasselbe tun. Dem User ist nicht klar, welcher „Quest"-Begriff welches System meint.

### Problem 5 — Hardcoded Strings
Mehrere Labels sind noch auf Deutsch hardgecoded statt über `AppText`-Übersetzungs-Keys zu laufen:
`'Tränke'`, `'Dark Mode'`, `'Kampf-Log anzeigen'`, `'Reduzierte Effekte'`, `'Weltkarte'`, `'Meilensteine'` u.a.

---

## 3. Persönliche Einschätzung — Was dieses Spiel wirklich braucht

**Kurz gesagt:** Das Fundament ist solide und überraschend komplett. Das Problem ist keine fehlende Feature-Breite, sondern **fehlende Feature-Tiefe** und **fehlender sozialer Klebstoff**.

---

### ① Clan-System zusammenführen und vertiefen _(höchste Priorität)_
Clan War rein in `ClanScreen` als Tab. Dann: Clan-Level, Clan-Boni (z.B. +5 % Gold für alle Mitglieder), Clan-Beitragspunkte. Das ist der soziale Anker — wenn Clans sich wertvoll anfühlen, kommen Spieler täglich zurück.

### ② Idle-Loop belohnender machen
Das Spiel heißt „Idle Forge" — aber die Offline-Belohnungen fühlen sich nach dem Öffnen wie ein einfacher Gold-Dump an. Besser: offline gecraftete Items die man dann auspackt („Du hast 3 Items geschmiedet während du weg warst"), zufällige seltene Funde, Spannung beim Zurückkommen.

### ③ Progression sichtbarer machen
Kein Spieler sieht auf einen Blick wie weit er ist. Ein einfaches Profil-Summary (Kapitel X, Prestige Y, Stärke Z, Clan-Name) oben in der Hauptansicht würde den Fortschritt greifbarer machen.

### ④ Push-Notifications anschließen
Firebase ist schon eingebunden. Notifications für „Deine Auktion wurde überboten", „Clan War beginnt in 1 Stunde", „Event startet heute" — das holt Spieler aktiv zurück.

### ⑤ Events als Herzstück, nicht als Nebensache
Events sind das kompetitivste Feature (Leaderboard, Timer, Belohnungen) aber sie sind tief im More-Menü versteckt und haben keine Prominenz auf dem Hauptbildschirm. Ein kleines Event-Banner auf der Hauptansicht (`🔥 Turnier läuft — 2:34h`) würde die Teilnahme massiv erhöhen.

### ⑥ PVP sinnvoller gestalten
Momentan ist PVP ein Challenge-and-Wait-System. Eine asynchrone „Arena"-Ansicht wo Spieler automatisch gematcht werden (ohne aktives Herausfordern) würde PVP lebendig machen ohne Echtzeit-Anforderungen.
