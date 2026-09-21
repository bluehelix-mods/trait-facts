# Trait Facts übersetzen

Stand 21.09.2026. Gilt für jede Sprache außer Englisch (die Quelle) und
Deutsch (fertig, zugleich Beispiel für den Ton).

## Was der Mod ist

Trait Facts zeigt in der Charaktererstellung von Project Zomboid, **was ein
Trait wirklich tut**: gemessene und aus dem Spielcode gelesene Zahlen, nicht
die Marketingtexte der Trait-Beschreibungen. Die Texte sind kurze
Tabellenzeilen, keine Sätze: Bezeichnung, Einheit, Fußnote.

## Die Dateien

| Was | Wo |
| --- | --- |
| Quelle | `mod/42/media/lua/shared/Translate/EN/UI.json` |
| Beispiel für den Ton | `mod/42/media/lua/shared/Translate/DE/UI.json` |
| Glossar der Sprache | `docs/uebersetzung/glossar-<LANG>.md` |
| Ziel | `mod/42/media/lua/shared/Translate/<LANG>/UI.json` |

Ordnernamen sind die des Spiels: `RU`, `CN` (vereinfachtes Chinesisch), `PTBR`,
`ES`, `FR`, `PL`, `KO`, `JP`, `TR`, `IT`.

## Regeln, die eine Maschine prüft

`python tools/uebersetzung-pruefen.py <LANG>` muss ohne Fehler durchlaufen.

1. **Gültiges JSON**, ein Objekt, UTF-8, **LF** als Zeilenende, Zeilenumbruch
   am Dateiende, zwei Leerzeichen Einrückung, Schlüssel alphabetisch sortiert.
2. **Derselbe Schlüsselsatz wie EN.** Kein Schlüssel fehlt, keiner kommt dazu.
3. **Platzhalter bleiben.** `%1` bis `%9` stehen genauso oft in der Übersetzung
   wie im Englischen. Ihre Stellung im Satz darf sich ändern.
4. **Ein einzelnes Prozentzeichen wird `%%` geschrieben.** Das Spiel verlangt
   das seit Build 42.20.1. `+40%%` ist richtig, `+40%` ist falsch.
5. **Keine Geviert- oder Halbgeviertstriche** (— und –). Bindestrich nehmen
   oder umformulieren.
6. **Keine spitzen Klammern.** Das Spiel liest `<...>` als Befehl und
   verschluckt den Rest der Zeile.
7. **Nichts bleibt englisch stehen**, außer Zeichen und Einheiten, die in jeder
   Sprache gleich sind.

## Regeln, die ein Mensch prüft

- **Das Glossar gilt.** Skills, Trait-Namen, Berufe und Körperteile heißen
  genau so, wie das Spiel sie in dieser Sprache nennt. Ein eigenes Wort für
  "Foraging" findet der Spieler in seiner Oberfläche nirgends wieder.
- **Kurz.** Die Texte stehen in schmalen Spalten neben Zahlen. Ist die
  Übersetzung viel länger als das Englische, kürzer fassen. Das Werkzeug meldet
  alles über dem 2,2-fachen als Hinweis.
- **Gleiche Dinge gleich benennen.** Kommt "Chance of ..." in 40 Zeilen vor,
  steht in allen 40 dieselbe Wendung.
- **Nüchtern.** Keine Werbesprache, keine Ausrufezeichen, kein "du schaffst
  das". Der Mod nennt Tatsachen.
- **Etablierte englische Begriffe stehen lassen**, wenn die Spieler dieser
  Sprache sie benutzen und das Spiel sie nicht übersetzt (Mod, Workshop,
  Build). Das Glossar sagt, was das Spiel übersetzt.
- **Fußnoten beginnen klein** und sind Halbsätze, keine Sätze:
  "nur bei Nahkampfwaffen", nicht "Dies gilt nur für Nahkampfwaffen."

## Die Namensräume der Schlüssel

| Präfix | Was es ist | Ton |
| --- | --- | --- |
| `UI_TF_eff_` | Bezeichnung einer Wirkung, die Zeile in der Übersicht | Substantiv, kurz: "Chance of catching a cold" |
| `UI_TF_note_` | Fußnote dahinter, grau, klein | Halbsatz: "melee only" |
| `UI_TF_unit_` | Einheit hinter einer Zahl | ein bis drei Zeichen: "lvl", "tiles" |
| `UI_TF_grp_` | Überschrift einer Gruppe | Substantiv: "Movement and endurance" |
| `UI_TF_build_` | Build-Code kopieren und einfügen, Meldungen dazu | ganze Sätze |
| `UI_TF_opt_` | Optionen und ihre Erklärung | Checkbox-Text, dann ein Satz |
| `UI_TF_legend_` | Legende "What the colours mean" | Halbsätze |
| `UI_TF_xp_` | Startskills und ihre Herkunft | kurz |
| `UI_TF_live_` | wie `UI_TF_eff_`, aber live aus dem Spiel gelesen | wie `eff` |
| `UI_TF_ext_` | Hinweise zu Traits aus fremden Mods | Halbsätze |
| `UI_TF_sym_` | Zeichen ohne Wort | bleibt, wie es ist |

## Besonderheiten

- `_one`-Schlüssel sind die Einzahl zum Schlüssel ohne `_one`. Sprachen mit
  mehr als zwei Zahlformen (Russisch, Polnisch) können nur diese zwei
  bedienen: die Einzahl für 1, die andere Form für alles übrige. Wähle die
  Form, die mit den meisten Zahlen richtig klingt.
- `UI_TF_decimalsep` ist das Dezimaltrennzeichen der Sprache: `.` oder `,`.
- `UI_TF_sum_title` ist der Name des Mods, "Trait Facts". Er bleibt, außer in
  Sprachen ohne lateinische Schrift, wo eine Umschrift üblich ist.
- `UI_TF_legend_tagsample` ist das Beispielkürzel "MOD", drei Großbuchstaben.
- Einige Fußnoten nennen Spielfehler ("game quirk", "an engine bug"). Das ist
  wörtlich gemeint: der Mod meldet, wo das Spiel sich anders verhält, als es
  aussieht.
