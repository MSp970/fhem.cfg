# Arbeitsregeln für dieses Repository (FHEM-Konfiguration)

- Antworten auf Deutsch.
- Jede Änderung an FHEM-Geräten (DOIF, notify, Attribute, Readings usw.) immer als
  **sofort ausführbaren Befehl für die FHEM-Kommandozeile** ausgeben, nicht nur als Codeblock
  oder Beschreibung. Beispiele: `modify <dev> <DEF>`, `defmod ...`, `attr ...`,
  `setreading ...`, Perl-Einzeiler in `{ ... }`.
- Bei Teiländerungen an einem langen DOIF-DEF einen Perl-Einzeiler verwenden, der das DEF aus
  `$defs{<dev>}{DEF}` per Regex ersetzt und mit `CommandModify(undef,"<dev> $d")` neu setzt.
  Er darf keine `#`-Kommentare enthalten (die Kommandozeile entfernt Zeilenumbrüche) und muss bei
  nicht gefundenem Muster eine Meldung liefern statt zu ändern.
- In Perl-Einzeilern `{ ... }` für die FHEM-Kommandozeile **jedes `;` zu `;;` verdoppeln**
  (auch innerhalb von `q{}` und Regex), sonst zerlegt FHEM den Befehl an den Semikolons
  ("Unknown command {", "Unknown command my"). In der `fhem.cfg` selbst gilt dasselbe.
- Am Ende eines Änderungsbefehls immer `save` als eigenen Befehl nennen.
- Zusätzlich einen kurzen Prüfbefehl angeben, z. B. `list <dev> <reading>`.
