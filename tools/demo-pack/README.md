# Trait Facts Demo Pack

Ein kleines, separates Mod, das mit erfundenen Werten Pakete über
`TraitFactsAPI` anmeldet (siehe `docs/api.md`), damit man das Feature
"Traits aus anderen Mods" im Spiel sehen kann, ohne auf ein echtes Fremd-Mod
mit passenden Traits angewiesen zu sein. Die Werte sind erfunden und dienen
nur der Vorschau.

Geht nie in den Workshop: `tools/build-workshop.py` packt ausschließlich
`mod/` in das Workshop-Item (siehe `MOD = os.path.join(ROOT, "mod")` und
`shutil.copytree(MOD, target, ...)` dort); `tools/demo-pack/` liegt außerhalb
von `mod/` und wird nie mitgenommen.

## Einrichtung (einmalig)

Das Demo-Paket muss als eigenes Mod im Zomboid-Mod-Ordner liegen. Dafür eine
Junction anlegen, keine Kopie, damit Änderungen hier sofort im Spiel
ankommen:

```powershell
New-Item -ItemType Junction -Path "$env:USERPROFILE\Zomboid\mods\TraitFactsDemoPack" -Target "<repo>\tools\demo-pack\TraitFactsDemoPack"
attrib.exe -U +P "<repo>\tools\demo-pack\TraitFactsDemoPack\*" /S /D
```

Danach müssen im Mod-Manager drei Mods aktiv sein:

- Trait Facts
- Trait Facts Demo Pack
- The Only Cure (Workshop 3580276809)

Für einen größeren Test lohnt zusätzlich More Traits Definitive (Workshop
3799050151): 96 Traits im Namensraum `ToadTraits`, ohne Datenpaket. Damit
lassen sich die Kürzel-Spalte bei vielen Einträgen, das Thema "No numbers yet"
und die Herkunft in den Startskills prüfen.

This Is Your Life (Workshop 3773911887) nicht dazunehmen: es ersetzt die
Trait-Auswahl durch einen eigenen Bildschirm, auf dem Trait Facts nichts
zeigt, und seit 0.4.2 sperrt Trait Facts die Kombination in `mod.info`
(Befund im Spiel 16.09.2026).

## Test im Spiel (nach Task 8, durch den Nutzer)

1. Mods aktivieren: Trait Facts, Trait Facts Demo Pack, The Only Cure.
2. Neues Spiel, Charaktererstellung, Seite "Select occupation and traits".
3. Log (`console.txt`) muss `[TraitFacts] Version 0.5.0 geladen` zeigen und
   darf keine `WARN` zu Paketen enthalten.
4. Prüfen:
   - Kürzel `TOC` im Kästchen in einer eigenen Spalte links neben den Kosten,
     in allen drei Trait-Listen (gute, schlechte, gewählte); die Kästchen von
     "Amputated Left Hand" (+8), "Forearm" (+10) und "Upper arm" (+20) stehen
     genau untereinander.
   - Tooltip von "Amputated Left Upper arm": oben `TOC` im Kästchen vor "The
     Only Cure", "Excludes" als Liste mit einem Trait je Zeile.
   - Tooltip von "Amputated Left Hand" mit "values from Demo: The Only Cure
     2.4.0".
   - Tooltip von "Amputated Left Forearm" orange.
   - Tooltip von Strong mit "Knockback DEMO +30%".
   - Übersicht mit Kästchen um die Kürzel, Hover zeigt das Mod, Thema
     "No numbers yet".
   - Startskills mit "TOC" bei Fitness und Strength, wenn ein Amputee-Trait
     gewählt ist.
   - Kürzel in der Übersicht wirkt scharf, nicht fett oder doppelt
     gezeichnet.
   - Ein langer fremder Trait-Name endet mit "..." vor der Kürzel-Spalte,
     statt unter das Kästchen zu laufen.
   - Übersicht mit vielen gewählten Traits scrollen: keine Kürzel-Kästchen
     schweben außerhalb der Übersicht, etwa über der Startskill-Liste.
