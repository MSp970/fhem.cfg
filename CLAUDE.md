# Hinweise für Claude (FHEM-Konfiguration S9)

## Code zum Einfügen in FHEM
- **Kommandozeile / mehrzeiliger Perl-Block `{ ... }`:** Jedes Semikolon muss als `;;` stehen.
  Sonst trennt FHEM bei jedem `;` und meldet "Unknown command my, try help.".
  Code für die Kommandozeile deshalb immer mit `;;` ausgeben und vorher mit `sed 's/;/;;/g'`
  erzeugen und prüfen.
- **Perl-Code in `fhem.cfg`:** Zeilenfortsetzung mit `\` am Zeilenende und `;;` für Semikolons.
- **Keine neuen `99_*.pm`-Module und keine Dateien in `/opt/fhem/FHEM/`.** Der Nutzer hat dort teils keine Schreibrechte,
  und solche Dateien können nach einem Update (z. B. neues Container-Image) weg sein. Alles, was die Anlage braucht,
  muss in `fhem.cfg`/Attributen liegen und per `save` gesichert werden: DOIF (auch mit `subs`-Block), Attribute, Einzeiler.
  Bestehende Module (`S9/PVBudget/99_PVBudget.pm`) sind optional und rein beobachtend; die Regelung darf nicht davon abhängen.

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
- A9 hat zwei Batterien (5877/5876). `di_GoodWe_NachtFahrplan` und `DOIF_socMax_adaptiv` sind dort entfernt;
  die Nachtregelung liegt in `DOIF_GoodWe_v2`.
- socMax-Anpassung: ausschließlich die Nachtlernregel in v2 (kein PV-/Temperatur-/Prognose-Overlay). Regel:
  Nacht-Minimum-SOC < socMin -> socMax += Differenz (max 100); sonst socMax -= halbe Differenz (min 80, `socMaxBasis`).
  Gilt für S9 und A9 gleich. Keine weitere Logik, die `EMS_Control:socMax1/2` schreibt.
- Das Repo (A9/fhem.cfg) kann vom Live-Stand abweichen. Änderungen für die laufende Anlage deshalb als tolerante
  Einzeiler liefern, die Rest-Verweise anzeigen, und nie blind löschen.
- v2 sendet nur bei `EMS_Control:v2Aktiv = 1`, sonst beobachtet es nur.
- Das Ladeziel (`socmax_eff`) wird ausschließlich in v2 berechnet (`socMax1`, `smax_prog`, `vollladen_rest`).
  Das PVBudget-Modul liest es nur.

## EMS-Parameter-Oberfläche
- Schieberegler für `EMS_Control` laufen nativ über die Attribute `setList` (`name:slider,min,step,max`) und `readingList`.
  Der Katalog dazu steht in `EMSPanel/ems_katalog.txt`, der Einzeiler in `EMSPanel/ems_slider_einzeiler.txt`. Neuer oder
  gestrichener `$P->("name",default)` im Code bedeutet: Katalogzeile ergänzen bzw. entfernen und Einzeiler neu erzeugen.

## Ladestrom schreiben
- `Batterie_Ladestrom_Max` landet im Flash des Wechselrichters (`di_GoodWe_Flash` zählt es) und darf nur selten geschrieben werden.
  v2 schreibt ihn nur bei Änderung >= `iSchrittA` (Standard 1 A) und frühestens nach `iMinAbstandS` (Standard 300 s);
  Abschalten (0 A) und Schnell-Reduzierung bei Netzbezug bleiben sofort. Nicht wieder auf 0,05-A-Schritte zurückbauen.
