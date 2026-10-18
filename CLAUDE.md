# Regeln für diese Repo (FHEM-Konfiguration)

## Code zur Direkteingabe in die FHEM-Kommandozeile
- Der Nutzer will Code **immer als direkt einfügbaren Einzeiler** für die FHEM-Kommandozeile (FHEMWEB-Eingabefeld), nicht als Editier-Anleitung.
- Perl-Code steht in `{ ... }` auf **einer Zeile**.
- **Jedes Semikolon im Perl-Block muss verdoppelt werden (`;;`)**, auch innerhalb von Strings. Sonst zerlegt FHEM die Zeile an `;` und meldet `Unknown command my / return / ...`. FHEM macht aus `;;` vor der Ausführung wieder `;`.
- DEF eines Devices per Perl ändern: `CommandModify(undef,"$name $def")` verwenden, nicht `fhem("modify ...")` (dort würde an `;` gesplittet).
- Vor Änderungen an laufenden Definitionen: Hinweis auf `save`; Einzeiler sollen erst prüfen (Treffer genau 1) und sonst abbrechen.
- Befehle, die keine Perl-Blöcke sind (`setreading`, `attr`, `save`), einzeln in je einem Codeblock ausgeben.
- Dateien: aktuelle Stände sind die datierten Snapshots (`A9/A9 fhem 180106.cfg`, `S9/S9 fhem 181026.cfg`).
