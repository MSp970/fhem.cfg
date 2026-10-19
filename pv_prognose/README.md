# PV-Prognose: Auswertung, Tageskorrektur, Orientierungsmodell

Gemeinsamer Code fuer A9 und S9 (Anlage wird automatisch erkannt).

- `at_PV_Prognose_body.pl`: Inhalt des `at`-Devices `at_PV_Prognose` (laeuft jede Minute)
- `gplot_writer.pl`: schreibt die drei gplot-Dateien fuer die SVG-Diagramme
- `einzeiler.txt`: fertige Einzeiler fuer die FHEM-Kommandozeile (`;;` bereits verdoppelt)
- `test_harness.pl`: Simulation mit Mock-Readings (`perl test_harness.pl a9|s9`)
