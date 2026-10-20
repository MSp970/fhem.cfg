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
- Eine Seite mit je einem Schieberegler pro `EMS_Control`-Parameter, untereinander in Tabs: `weblink wl_EMS_Parameter` (Raum `EMS-Parameter`),
  reine Konfiguration ohne Modul, in einem Shadow-DOM gekapselt (FHEMWEB-Themes überschreiben sonst generische CSS-Klassen).
  Der Generator steht in `EMSPanel/ems_weblink_defmod.txt`, der Katalog (Name|System|Tab|min|Schritt|max|Einheit|
  Standard S9|Standard A9|Bezeichnung|Flags) als Attribut `comment` des Weblinks, Vorlage in `EMSPanel/ems_weblink_katalog_attr.txt`.
  Neuer oder gestrichener `$P->("name",default)` im Code bedeutet: Katalogzeile ergänzen bzw. entfernen (`EMSPanel/ems_katalog.txt` ist die Langfassung).
- Alternative ohne eigene Seite: `EMSPanel/ems_slider_einzeiler.txt` setzt `setList`/`readingList` (Regler nur im Set-Feld).

## Ladestrom schreiben
- `Batterie_Ladestrom_Max` landet im Flash des Wechselrichters (`di_GoodWe_Flash` zählt es) und darf nur selten geschrieben werden.
  Mode 1: in ganzen Ampere abgerundet (`iSchrittA`, Standard 1), frühestens alle `iMinAbstandS` s (Standard 300).
  Alle anderen Modi (außer 255): Strom = `iMaxA` (10 A), einmalig beim Moduswechsel gesetzt (`i_mode`), nie 0 A; die Leistung geht über `EMSPowerWatt`.
  Eintritt in Mode 1 setzt den gestuften Wert sofort. Abschalten/Moduswechsel (`iStopSofort`) und Schnell-Reduzierung bei Netzbezug
  (`iSchnellSofort`) bleiben sofort. Alter Zustand: `iNurMode1=0`, `iSchrittA=0`, `iMinAbstandS=0`. Nicht wieder auf 0,05-A-Schritte zurückbauen.
