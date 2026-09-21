# Measurement logs

These files are the raw output of a separate test mod (`tools/measure-mod/`).
The test mod runs inside Project Zomboid, reads values from a live character
with and without a trait, and writes one text file per run. The evidence wiki
links to these files as proof.

File names are German and dated: `messung-2026-09-13-schlaf.txt` is the
measurement ("Messung") of 13 September 2026, test "Schlaf" (sleep). A letter
after the date (`b`, `c`) marks a later run on the same day.

Lines that start with `#` are the header. The header names the test, the
test mod version ("Mess-Mod 6.26.5") and the game version ("Build 42.20").
Older logs did not record the patch level. It was 42.20.4; newer logs say
"Spiel 42.20.4". A line in square brackets, like `[werte] id|trait|ohne|mit|...`,
names the columns of the lines below it. Columns are separated by `|`.

Traits appear under their id in the game code, in lower case. Some ids differ
from the name the game shows: `weak` is Puny, `feeble` is Weak, `obese` is
Very High Weight, `veryunderweight` is Very Low Weight, `insomniac` is
Restless Sleeper. The full list is in `docs/engine/trait_id_cost_name.txt`.

## Glossary

| German | Meaning |
| --- | --- |
| wert, werte | value, values (one measured effect per line) |
| ohne / mit | result without / with the trait |
| faktor | mit divided by ohne; in groups marked "differenz" it is mit minus ohne |
| differenz | difference (with minus without) |
| soll_mod | the number the Trait Facts mod shows; `-` if it shows none |
| soll_code | the number read from the game code of 42.20 |
| urteil | verdict |
| stimmt / weicht ab | matches / deviates |
| nicht messbar | not measurable in this run |
| ergebnis | summary: stimmen = matching, weichen_ab = deviating |
| toleranz | allowed gap between faktor and the expected number |
| stichprobe, proben | random sample, number of samples |
| nachweisgrenze | detection limit: a factor closer to 1 than this is noise ("Rauschen") |
| lauf, laeufe | run, runs |
| phase, nr | one stretch of a run with a fixed trait setup, and its number |
| fall, faelle | case, cases (one trait setup) |
| figur | character |
| stufe | level (skill level, or the carry capacity that follows from Strength) |
| tragen | carry capacity the game reports |
| gewaehlt / jetzt / dazu / weg | traits chosen / traits now / added / removed by the game |
| notiz, grund | note, reason |

Other common words: mittel (mean), kleinster / groesster (smallest / largest),
je tick / je_h / je_s (per tick / game hour / second), tempo (speed), strecke
(distance), schaden (damage), hieb (axe hit), fertig (finished), fehlt (missing).

The logs write ae, oe, ue for the German letters ä, ö, ü.

## How to read one line

From `messung-2026-09-14b-werte.txt`, under
`[werte] id|trait|ohne|mit|faktor|soll_mod|soll_code|urteil|notiz`:

```
wert|erholung|obese|1.2000|0.4800|0.4000|0.4000|0.4000|stimmt
```

The value group is "erholung" (endurance recovery) and the trait is `obese`
(Very High Weight). Without the trait the game returned 1.2000, with it 0.4800.
The factor is 0.4800 / 1.2000 = 0.4000. The Trait Facts mod shows 0.4000 and
the game code says 0.4000, so the verdict is "stimmt" (matches).
