# Hinweise für Claude (FHEM-Konfiguration S9)

## Code zum Einfügen in FHEM
- **Kommandozeile / mehrzeiliger Perl-Block `{ ... }`:** Jedes Semikolon muss als `;;` stehen.
  Sonst trennt FHEM bei jedem `;` und meldet "Unknown command my, try help.".
  Code für die Kommandozeile deshalb immer mit `;;` ausgeben und vorher mit `sed 's/;/;;/g'`
  erzeugen und prüfen.
- **Perl-Code in `fhem.cfg`:** Zeilenfortsetzung mit `\` am Zeilenende und `;;` für Semikolons.
- **Größere Logik** als Modul `99_*.pm` (Perl, testbar) ablegen und in der cfg nur aufrufen.
  Der Nutzer hat teils keine Schreibrechte auf `/opt/fhem/FHEM/`. Dann Alternativen anbieten:
  `sudo cp` plus `chown`, FHEM-Web "Edit files", oder `{ require "/pfad/datei.pm" }`.

## Umgang mit der Anlage
- Es gibt keinen Live-Zugriff auf FHEM. Nur die Konfiguration im Repo ist bekannt. Aussagen zum
  Laufzeitverhalten als ungeprüft kennzeichnen.
- Neue Logik zuerst im Schattenmodus (nur rechnen, Readings, CSV-Logs), erst nach Vergleich
  mit dem realen Verhalten in die Steuerung einbinden.
- Neue Logik braucht klare Readings, ein Log und einen Klartext-Grund (Nachvollziehbarkeit).
- Antworten auf Deutsch.

## Batterie-Regelung
- `DOIF_GoodWe_v2` ist der einzige Regler für den GoodWe-Wechselrichter (S9 und A9). `DOIF_GoodWe_simple` und
  `DOIF_Batterie_Ladestrom_Max` sind in beiden Konfigurationen entfernt und dürfen nicht wieder eingeführt werden.
- A9 hat zwei Batterien (5877/5876). Dort laufen zusätzlich `di_GoodWe_NachtFahrplan` (19–8 Uhr) und
  `DOIF_socMax_adaptiv` (12:00, schreibt `socMax1/2`) neben v2. Das ist ein offener Konflikt, solange nicht entschieden ist, ob sie entfallen.
- v2 sendet nur bei `EMS_Control:v2Aktiv = 1`, sonst beobachtet es nur.
- Das Ladeziel (`socmax_eff`) wird ausschließlich in v2 berechnet (`socMax1`, `smax_prog`, `vollladen_rest`).
  Das PVBudget-Modul liest es nur.
