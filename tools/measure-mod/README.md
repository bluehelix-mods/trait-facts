# Trait Facts Measure

Hilfs-Mod, das einmal an einer lebenden Figur aufnimmt, was sich statisch
nicht lesen lässt. **Geht nie in den Workshop**: `tools/build-workshop.py`
kopiert nur `mod/`.

## Warum es eine Figur braucht

Der Container `CharacterTraits` hat genau drei rechnende Getter
(Nahkampfschaden, Ausdauerverlust, Wetterstrafe); die misst Trait Facts schon
beim Spielstart ohne Figur. Alles Weitere hängt an `IsoGameCharacter` und
existiert erst, wenn eine Figur in der Welt steht: Grapple, Tragekapazität,
Fällgeschwindigkeit, Wahrnehmungsradius, Hörweite, Bildunschärfe.

## Fassung

`TFMeasure.VERSION` im Lua und `modversion` in `mod.info` werden bei **jeder**
Aenderung am Mess-Mod hochgezaehlt und muessen uebereinstimmen; `check-data.py`
prueft das (Regel 22). Der Mod-Waehler zeigt nur `mod.info` an, und eine Nummer,
die nie wandert, beweist nichts ueber den geladenen Code.

Im Spiel steht die Fassung in der ersten Zeile des Logs
(`[TraitFactsMeasure] Fassung X, Messung laeuft.`) und im Kopf des Berichts
(`# Mess-Mod X`). Das ist der zuverlaessige Nachweis, welcher Stand lief.

## Tasten im Spiel

| Taste | Wirkung |
| --- | --- |
| **Num 9** (Nummernblock) | lädt das Mess-Mod neu und schaltet die Tests wieder scharf |
| **Num 8** (Nummernblock) | öffnet und schließt das Messfenster |
| **Num 7** (Nummernblock) | in der Charaktererstellung: Bildschirmlauf (mit Strg nur die jetzige Auflösung, mit Shift die Workshop-Bilder) |
| **Num 6** (Nummernblock) | in der Charaktererstellung: Menü-Prüflauf (seit 6.36.0) |
| **Num 5** (Nummernblock) | in der Charaktererstellung: Menü-Prüflauf und danach von selbst der Bildschirmlauf (seit 6.40.0) |
| **Num 4** (Nummernblock) | im Spiel: Fenster "Nachstellen" (seit 6.41.0). Gibt je Spielfehler die nötigen Gegenstände (Mischflasche mit verseuchtem Wasser und Bleiche, Bretter und Metallplatten samt Brenner und Maske, Äxte, Dosen) und schaltet den zugehörigen Trait an und aus. Gespielt und geschaut wird von Hand, an einer Wegwerf-Figur. Protokoll: `Zomboid/Lua/TraitFacts_nachstellen.txt` |

Seit 6.26.2 (6.26.1 hatte kurz Pos1 und Einfg). Bis dahin waren es F9 und
F8; die gelten ohne `-debug` weiter.
Mit `-debug` gehören F8 und F9 dem Spiel selbst (`IngameState.updateInternal`:
F8 Weltkarten-, Sprite- und Kachel-Editor, F9 Seam-Editor, dazu F2 und F7),
und am 13.09.2026 ging statt des Messfensters der Weltkarten-Editor auf.
F1 bis F6, F10 und F11 belegt Vanilla ohnehin (`keyBinding.lua`), F12
Steam; den Nummernblock belegt keins von beiden. Wo unten noch F8 und F9
stehen, sind heute Num 8 und Num 9 gemeint.

Mit `-debug` lud 6.26.1 zunächst gar nicht: Kahlua schreibt im Debug-Modus
zu jeder lokalen Variable die Zeile mit, in ein Feld mit 200 Plätzen, und
zählt dafür alle je in einer Funktion angelegten locals, auch die
versteckten jeder `for`-Schleife. `accelFinish` (Autotest) legte 224 an.
Seit 6.26.2 ist sie geteilt, und der Smoke-Test prüft über `string.dump`,
dass keine Funktion mehr als 180 anlegt.

## Das Messfenster (F8, seit 6.18.0)

Links stehen die offenen Tests, darunter die erledigten mit Datum. Ein Klick
wählt einen Test; die Liste scrollt mit dem Mausrad oder am Balken rechts
(seit 6.26.3, vorher wuchs das Fenster mit ihr; der Balken seit 6.26.4).
Unter Erledigt stehen die zuletzt gelaufenen oben; dafür schreibt der Stand
seit 6.26.4 `zeit=` mit (Minuten seit 1.1.2026 UTC). Ältere Einträge ohne
Zeit sortieren nach Datum und bei gleichem Datum nach der Mess-Mod-Fassung,
mit der sie liefen (seit 6.26.5; 6.26.4 stellte bei lauter Einträgen vom
13.09. die Axt oben hin). Der Balken wird seit 6.26.5 im Beschnitt der
Liste gezeichnet; danach gezeichnet war er im Spiel nicht zu sehen. Das
Log nennt je neuer Größe `Messfenster: Liste sichtbar/Inhalt ...`. Rechts stehen dann Zweck und Schritte (was das Mod tut, was
du tust), Start und Abbrechen, während des Laufs drei Live-Werte, ein Balken
und der Stand in Worten, danach das Ergebnis und der Name des Berichts. Unten
schalten vier Kästchen die Testfigur: God Mode, unsichtbar, Zombies greifen
nicht an, Ausdauer unbegrenzt (das letzte steuert auch das Auffüllen je Tick).
God Mode hält im Mess-Mod außerdem die Muskelzerrung weg (seit 6.19.0): das
Spiel fragt God Mode dabei nicht, und nach dem ersten Axt-Test stand die Figur
mit Zerrung an beiden Armen da.

**God Mode ist dem von Cheat Menu: Reloaded nachgebaut** (seit 6.21.0;
6.20.0 setzte das Mod voraus, Workshop 3683918273). Vanillas `setGodMod`
schützt nur vor Schaden. Solange das Kästchen an ist, kommt dazu:

- je Tick `RestoreToFullHealth` (setzt auch die Steifheit auf 0) und
  Müdigkeit, Hunger, Durst zurück, wie `CheatMenuToggleManager.lua`;
- das Herunterziehen durch Zombies (`ZombieLore.ZombiesDragDown`) aus, wie
  `dragDownDisable`. Geändert wird es nur, wenn es an war, und nur dann kommt
  es beim Abschalten zurück; der Merker steht in der ModData der Figur.
  Beendet man das Spiel mit God Mode an, bleibt es in diesem Spielstand aus.

Die Ausdauer bleibt beim eigenen Kästchen. Ein Test, der Verletzungen oder
Heilung misst, braucht God Mode aus. Unsichtbar und "Zombies greifen nicht
an" sind Vanillas Schalter.
Entwurf: `docs/mockups/messfenster-2026-09-12.html`, Variante A.

- **Stand der Tests:** `Zomboid/Lua/TraitFacts_tests.txt`, eine Zeile je Test
  (`id|erledigt|datum|schluessel=wert|...`). Er überlebt Neustarts und
  Spielstände. Zeilen unbekannter Tests bleiben beim Schreiben stehen, damit
  eine ältere Fassung nichts wegwirft. Das Datum rechnet Kahluas `os.date`
  in UTC (`OsLib`, feste Zeitzone); kurz nach Mitternacht steht dort noch der
  Vortag.
- **Prozentzeichen in Texten:** `%%`. Das Spiel formatiert jeden Text wie
  `String.format`; ein einzelnes `%` vor Leerzeichen und Buchstabe warf am
  13.09.2026 in jedem Bild eine Ausnahme ins Log. Der Smoke-Test prüft das.
- **Texte:** `42/media/lua/shared/Translate/EN/UI.json`, auf Deutsch und mit
  echten Umlauten; das Lua bleibt ASCII. EN, weil jede Spielsprache darauf
  zurückfällt. Seit 6.23.4 liest das Mess-Mod die Datei bei jedem Laden
  selbst (`getModFileReader`, UTF-8), **F9 reicht also auch für neue und
  geänderte Texte**. Das Spiel liest Übersetzungen nur beim Programmstart;
  vorher kostete jede Textänderung einen Neustart. Fehlt die Datei, bleibt
  es bei `getText`. Ein Eintrag je Zeile, ohne Escapes, sonst liest der
  einfache Zeilenleser ihn nicht. Im Log steht nach jedem Laden
  `Texte: N aus der UI.json`.
- **Neuer Test:** ein Eintrag in `TFMeasure.TESTS` (id, art, schritte, datei,
  start, stop, ergebnis) und seine Texte `UI_TFM_<id>_name`, `_kurz`, `_zweck`,
  `_s1` ... Das Fenster baut sich daraus.
- **Test geändert:** Misst ein Test anders als vorher, bekommt er
  `seit = "<Fassung>"`. Ergebnisse aus einer älteren Fassung zählen dann
  nicht, und er steht wieder unter Offen. Dafür schreibt der Stand seit
  6.23.4 bei jedem Test die Fassung mit (`fassung=6.23.4`); ein Ergebnis
  ohne diese Angabe zählt bei `seit` nicht. Anlass: der umgebaute
  Schlaf-Test (6.23.3) stand am 13.09.2026 weiter unter Erledigt.
- **F9 mit offenem Fenster:** das alte verschwindet, einen Tick später steht
  ein neues aus dem neuen Code da. Ein laufender Axt-Test wird dabei sauber
  abgebrochen.

**Menü-Prüflauf (seit 6.36.0, `TFMeasureMenu.lua`, Num 6 in der Charaktererstellung).**
Der Bildschirmlauf prüft, wie die Charaktererstellung aussieht; dieser prüft, ob
Trait Facts dort hält. Er wählt jeden Beruf und jeden Trait einmal (und liest
danach, was `TF.safe` abgefangen hat: ein Fehler bei genau einem Trait steht mit
Trait und Kontext im Protokoll), schickt 100 Zufalls-Builds durch den Build-Code
hin und zurück (der Code muss derselbe bleiben, nichts darf als fehlend gemeldet
werden), schätzt jeden Tooltip gegen die Fenstergröße, prüft über
`TraitFacts.hooksNeverRun`, ob ein anderer Mod einen unserer Hooks ersetzt hat,
und spielt den Controller-Pfad ohne Controller durch (vorgetäuschtes Pad, Fokus
auf einer Trait-Liste: das Panel muss den Block dieses Traits zeigen). Protokoll:
`Zomboid/Lua/TraitFacts_menu.txt`, Schlusszeile mit Klicks, ok und FEHL. Braucht
Trait Facts ab 0.12.2.

**Abnahme im Menü-Prüflauf (seit 6.40.0).** Was im Abschlusstest von Hand abzuhaken
war, prüft der Lauf selbst, gleich nach den Hooks:

* `paket-*`, `kopfzeile-*`: `modversion` gleich `TF.VERSION`, die vier eigenen Bilder
  geladen, jeder Knopf der Kopfzeile trägt ein Symbol. `wert|paket-quelle` nennt,
  woher Trait Facts läuft (`workshop-paket`, `steam` oder `entwicklung`).
* `hinweis-*`: Kopieren (grün, `ok`), Einfügen (`ok`), halber Code (`warn`), kein Code
  (`error`, Auswahl bleibt), dieselben Traits in anderer Reihenfolge ergeben denselben
  Code. `kein-phantom-mod`: eine ausgeschriebene ID aus dem Text hinterlässt nichts im
  Mod-Speicher. Die Zwischenablage des Spielers steht danach wieder da.
* `spannen-adrenaline`, `leichte-kaelte-eine-zeile`: die Spannen mit Vorzeichen und in
  Grün, die Zeile zur leichten Kälte genau einmal.
* `optionskarte-*`: der blaue Rahmen folgt dem Häkchen, die Karte bleibt im Bild.
* `startskills-spalten`: je Beruf wählen, ein Bild warten, dann die Spalten lesen, die
  Trait Facts gerechnet hat: kein Skill-Name reicht in die Herkunft, die Herkunft endet
  vor dem Rand. `wert|gekuerzte-skillnamen` nennt, was gekürzt wurde.
* Jede Übersicht und jeder Tooltip wird nach `UI_TF_` durchsucht: ein unübersetzter
  Schlüssel steht als FEHL mit seinem Namen da. Deshalb lohnt der Lauf je Sprache.
* `wert|mods` und `wert|umgebung` (Sprache, Schrift, Fenster, Quelle) sagen, wofür das
  Ergebnis gilt.

Nicht ersetzt: ob es gut aussieht. Der Lauf liest Zustände, er sieht keine Pixel.

**Stufen-Traits (seit 6.36.0, automatisch, im Patch-Tag-Lauf).** Lässt das Spiel
die Leiter selbst ablaufen (`LevelPerk`, zehnmal je Skill) und liest je Stufe,
welchen der vier Stufen-Traits Vanillas `xpUpdate.levelPerk` setzt; verglichen mit
`TraitFacts.Summary.levelTraitFor`. Ersetzt die meisten neuen Figuren des Tests
Neue Figur; der Sonderfall der Erschaffung (Stufe 0) bleibt dort.

**Live gegen gespeichert (seit 6.36.0).** Die Messung beim Weltbetreten schreibt
den Abschnitt `[trait facts live]`: jeder Wert, den Trait Facts beim Start selbst
aus dem Spiel liest, neben dem gespeicherten. `WEICHT AB` heißt: ein Patch oder
ein Mod hat den Wert geändert. Die Zahl steht auch im Log.

**Laufvergleich.** `python tools/messung-einlesen.py --vergleich` hält den neuen
Code-Werte-Lauf gegen den letzten archivierten: genaue Werte ab 2 % Abstand,
Stichproben nur bei anderem Urteil, dazu neue und fehlende Zeilen.

**Patch-Tag-Lauf (seit 6.32.0).** Der Knopf **Alle automatischen** startet
Code-Werte, Axt, Klettern und XP-Leiter nacheinander (`TFMeasure.KETTE`, nur
Tests mit `art = "auto"`) und schreibt am Ende `TraitFacts_patchtag.txt`: oben
`gesamt|abweichend=..|fehlt=..|ohne-ergebnis=..`, darunter je Test sein Stand,
seine Werte und der Name seines Berichts. Kann ein Test nicht starten (kein Baum
für die Axt), steht der Grund in seiner Zeile, und die Kette geht weiter.
Abbrechen beendet auch die Kette. Gedacht für den Tag nach einem Spiel-Update:
ein Klick, eine Datei, danach `python tools/messung-einlesen.py`.

| Test | Art | Bericht |
| --- | --- | --- |
| Axt: Ax-pert | automatisch | `TraitFacts_axt.txt` |
| Klettern | automatisch | `TraitFacts_klettern.txt` |
| Neue Figur | neue Figuren, erledigt 13.09.2026 | `TraitFacts_figur.txt` |
| Code-Werte | automatisch, erledigt 13.09.2026 | `TraitFacts_werte.txt` |
| Panik im Freien | halbautomatisch, erledigt 13.09.2026 | `TraitFacts_panik.txt` |
| Blut und Lärm: Blutpanik, Blutstress, Geräusche | halbautomatisch, offen | `TraitFacts_blut.txt` |
| Wach: Müdigkeit, Durst, Hunger | halbautomatisch, seit 6.23.0 | `TraitFacts_wach.txt` |
| Schlaf: Dauer, Einschlafen, Erholung | halbautomatisch, seit 6.23.0 | `TraitFacts_schlaf.txt` |
| Einblenden: Eagle Eyed, Short Sighted | halbautomatisch, neu 14.09.2026 | `TraitFacts_einblenden.txt` |
| Laufen: Ausdauerverlust beim Rennen | mit dir, erledigt 13.09.2026 | `TraitFacts_laufen.txt` |
| Im Auto: Klaustrophobie und Kurzschließen | mit dir, seit 14.09.2026 | `TraitFacts_imauto.txt` |
| XP-Leiter | automatisch, erledigt 12.09.2026 | `TraitFacts_xp.txt` |
| Sprint | mit dir, erledigt 10.09.2026 | `TraitFacts_measure.txt` |
| Autos | mit dir, erledigt 11.09.2026 | `TraitFacts_measure.txt` |

### Axt: Ax-pert

Drei Aussagen aus dem Code von 42.20.4:

- **Fälltempo:** die Fäll-Animation läuft mit `ChopTreeSpeed`, und
  `getChopTreeSpeed()` ist 1,0 mit Ax-pert, 0,8 ohne.
- **Baumschaden:** `IsoTree.WeaponHit` rechnet den Baumschaden der Axt mit
  Ax-pert ×1,5, danach als ganze Zahl aufs Baumleben.
- **Schwungtempo:** `calculateCombatSpeed` multipliziert bei Äxten mit
  `getChopTreeSpeed()`, und `CombatManager.pressedAttack` macht daraus
  `CombatSpeed`, das Tempo der Schwung-Animation. Die Mod führt die
  Axt-Schwungzeit bisher als wirkungslos, weil `HandWeapon.getSpeedMod` (×0,95)
  keinen Aufrufer hat. Nach dieser Lesung schwingt aber jede Axt ohne Ax-pert
  mit 0,8.

Der Test läuft ohne Zutun. Er sucht den nächsten Baum im Umkreis von 15
Feldern und legt eine Axt ins Inventar; Vanillas `doChopTree` rüstet sie aus,
läuft hin und fällt. Vor jedem Treffer steht das Baumleben auf 5000, damit der
Baum nicht fällt und jeder Treffer als Differenz lesbar ist; am Ende bekommt
er sein Leben zurück. Der Axt-Skill steht fest auf 3.

Gefällt wird in acht Phasen im Wechsel ohne und mit Ax-pert, je Phase eine
eigene Aktion mit drei Hieben; der erste ist Anlauf, gemessen wird der Abstand
der beiden folgenden. So misst der Test auch ein Spiel sauber, das das
Fälltempo nur beim Start der Aktion liest. Danach folgen 20 Schläge in die Luft über `AttemptAttack`, vom Baum
weggedreht, Ax-pert alle zwei Schläge im Wechsel; die Zeiten kommen aus
`OnWeaponSwing` und `OnPlayerAttackFinished`. Nimmt das Spiel den Schlag aus
Lua nicht an, bittet das Fenster nach 3 Sekunden, die linke Maustaste zu
halten, und zählt, was dann kommt.

Im Bericht unter `[ergebnis]`: `faellen|abstand` (erwartet 0,8; seit 6.43.0 mit Pause vor jeder Phase, siehe unten),
`faellen|schaden` (erwartet 1,5, durch das Abschneiden etwas darüber),
`schwung|takt` und `schwung|dauer` (0,8 heißt: Ax-pert wirkt aufs
Schwungtempo; 1,0 hieße wirkungslos). Je Hieb steht auch der Baumschaden der
Axt dabei; er sinkt mit ihrer Schärfe. Danach stehen Ax-pert, Axt-Skill und
Baum wie vorher; Abbrechen räumt genauso auf.

Ergebnis vom 13.09.2026, drei Läufe (6.18.0, 6.19.0 und 6.21.0,
`docs/messungen/messung-2026-09-13-axt.txt`, `-13b-axt.txt` und `-13c-axt.txt`):

| Größe | mit/ohne | Lesart |
| --- | --- | --- |
| Schaden je Hieb | 1,50, 1,52 und 1,52 (35 → 53, stumpfer 33 → 50) | bestätigt; die Axt stumpft ab |
| Schlagtakt in der Luft | 0,79, 0,80 und 0,80 (rund 830 → 660 ms) | Ax-pert wirkt aufs Schwungtempo, seit Trait Facts 0.1.24 als −20 % Axt-Schwungzeit geführt |
| Schlagdauer | 0,79, 0,80 und 0,79 | dasselbe |
| Fälltakt | 1,00, 1,00 und 0,99 (1250 ms beide; im dritten Lauf ein Ausreißer von 1399 ms ohne Ax-pert) | **ungültig** (Faktensweep 23.09.2026), siehe unten |

**Fälltakt neu messen (seit 6.43.0).** Der Faktensweep vom 23.09.2026 hat die
Lesart „Ax-pert ändert das Fälltempo nicht“ gekippt. Die Engine liest das Tempo
eines Animationsknotens (`m_SpeedScale`, hier `ChopTreeSpeed`) nur, wenn der
Knoten startet, und ein Knoten, der noch läuft, wird wiederverwendet. 6.19.0
hat die Aktion beendet und im selben Tick neu gestartet. Dabei blieb `chop_tree`
aktiv und behielt das Tempo der ersten Phase, und die lief immer ohne Ax-pert:
1,0 s / 0,8 = 1250 ms, genau der gemessene Takt. Trait Facts führt das
Fälltempo darum seit 0.14.0 wieder als +25 % aus dem Code.

6.43.0 misst so, dass es entscheiden kann:
- Phase 1 läuft **mit** Ax-pert, gesetzt, bevor die Aktion startet. Zeigt sie
  1000 ms, ist die Wirkung belegt.
- Zwischen den Phasen steht die Figur still, bis `PerformingAction` nicht mehr
  `chop_tree` ist, und danach noch 2 s. Erst dann setzt der Test den Trait.
- Der Abschnitt `[phasen]` im Bericht nennt je Phase den Trait, den Getter und
  ob die Animation vor dem Neustart wirklich aus war.

Erwartet: mit 1000 ms, ohne 1250 ms, `faellen|abstand` 0,8.

Kletterlauf und XP-Leiter kamen am selben Abend Zeile für Zeile gleich heraus
wie ihre Berichte vom 13.09. 01:05 und 12.09.; beide sind also reproduzierbar.

### Adrenalin: Gehtempo bei Panik

**Seit 6.33.0 drei Teile.** Der Lauf vom 20.09.2026 maß beim Gehen auf Panikstufe 4
eine Strecke von nur ×1,0813, wo die Variable WalkSpeed ×1,25 zeigt. Gefragt ist
seitdem der reale Wert, und der Code deckt mehr ab als der Test bis dahin: der
Zuschlag hängt an der Stufe ((Stufe + 1) / 20), und aus demselben Grundtempo
rechnet `calculateWalkSpeed` auch das Renntempo ((Grundtempo − 0,15) +
Sprinting / 20, gedeckelt bei 1,0). Der Test fährt darum nacheinander Gehen auf
Stufe 4 (neun Phasen, wie bisher), Gehen auf Stufe 3 (fünf) und Rennen mit Shift
auf Stufe 4 (fünf); das Fenster sagt, wann du rennen sollst, und zählt nur Ticks
in der Gangart des Teils. Neue Zeilen im Bericht: `walkspeed_stufe3`,
`tempo_stufe3`, `runspeed`, `tempo_rennen`; der Abschnitt `[teile]` sagt, welche
Phasen wozu gehören. Die `tempo`-Zeilen sind der reale Wert.

Paket D, Spielfehler `adrenaline-movespeed`. Zwei Stellen im Code von 42.20
heben das Tempo mit Adrenaline Junkie:

- `IsoGameCharacter.calculateBaseSpeed` (Z. 8754-8764): Grundtempo 0,8, mit
  dem Trait ab Panikstufe 3 plus (Stufe + 1) / 20, auf Stufe 4 also 1,05.
  `calculateWalkSpeed` (Z. 8957-9005) deckelt das Gehtempo bei 1,0 (Z. 8985)
  und setzt es als Animationsvariable `WalkSpeed` (Z. 9004): 1,0 gegen 0,8,
  also +25 %. Diese Stelle lesen die Code-Werte (`tempo3`, `tempo4`) schon.
- `IsoPlayer.getMoveSpeed` (Z. 1633-1668): ab Panikstufe 4
  ×(1 + (Stufe + 1) / 50), auf Stufe 4 ×1,1. Gelesen wird die Methode nur
  von `getPathSpeed` (Z. 1024-1025), und das ruft keine Klasse der Engine und
  keine Vanilla-Lua auf. Laut Code wirkt das ×1,1 also nicht.

Ob es wirkt, zeigt nur die gegangene Strecke; ein Getter, den das Gehen
liest, sagt über `getMoveSpeed` nichts. Du gehst (W, A, S, D ohne Shift) im
Freien, am besten lange geradeaus, mit Schuhen und ohne schwere Last. Das Mod
schaltet God Mode ab (er setzt die Panik je Bild auf 0) und hält die Panik in
jedem Tick auf 90 (Stufe 4) und die Ausdauer auf 1. Neun Phasen zu je 300
gezählten Ticks, im Wechsel ohne und mit Adrenaline Junkie; nach jedem
Umschalten und jeder Pause zählen 15 Ticks Anlauf nicht. Es zählen nur Ticks,
in denen die Figur geht: nicht steht, nicht rennt oder sprintet, nicht
schleicht, nicht zielt, nicht im Auto sitzt, nicht durch Bäume geht, keine
Last trägt und Panikstufe 4 hat. Bei 60 Bildern je Sekunde ist das knapp
eine Minute Gehen; Pausen verlängern nur.

Je Phase die Strecke je Multiplier (`tempo`) und das Mittel von `WalkSpeed`
und `getMoveSpeed`; jede Phase mit Trait gegen das Mittel ihrer Nachbarn
ohne, Toleranz 3 %. Erwartet:

| Wert | laut Code | was es heißt |
| --- | --- | --- |
| `walkspeed` | ×1,25 | das Grundtempo samt Deckel, wie `calculateWalkSpeed` es setzt |
| `getmovespeed` | ×1,10 | der Getter trägt das ×1,1; zeigt, dass Stufe 4 stand |
| `tempo` | ×1,25 | die gegangene Strecke; Trait Facts zeigt +25 % |
| `zusatz` | ×1,00 | `tempo` / `walkspeed`; 1,10 hieße, das ×1,1 aus `getMoveSpeed` wirkt doch |

`zusatz` rechnet gegen die eigene Variable des Spiels; Schuhe, Wärme und
Verletzungen kürzen sich dort heraus. `walkspeed` und `tempo` gelten nur mit
Schuhen: barfuß (`walkSpeedModifier` 0,85, Z. 9024-9027) greift der Deckel
nicht, und es wären ×1,31. Liegt `WalkSpeed` ohne Trait unter 0,78, sagt das
Fenster es; der Bericht nennt das Mittel im Kopf. Desensitized setzt die
Panik in jedem Update auf 0 (`BodyDamage.UpdatePanicState`, Z. 430-432) und
ist für die Dauer weg. Weil God Mode aus ist, sollte kein Zombie in der Nähe
sein. Am Ende bekommt die Figur Adrenaline Junkie wie vorher, Desensitized,
Panik, Ausdauer und God Mode zurück; Abbrechen und F9 räumen genauso auf.
Bericht: `Zomboid/Lua/TraitFacts_adrenalin.txt`.

### Klettern

Der Kletterlauf (F8 in 6.17.x, seit 6.18.0 im Fenster) liest den Kletterwert und das
Klettertempo am Bettlaken-Seil. Der Kletterwert entscheidet vor allem das Scheitern an hohen Zäunen
(ClimbOverWallState Z. 296-311); am Seil öffnet der Sturzwurf erst nach sehr langem Klettern am Stück
(Faktensweep 2, 23.09.2026; bis dahin stand hier "Klettersicherheit am Bettlaken-Seil"). Der Lauf liest
Werte des Spiels, er lässt die Figur weder klettern noch stürzen. `getClimbingFailChanceFloat()` liefert nur die ganzzahlige Wurzel
der Sicherheitspunkte; an einer neuen Figur (20 Punkte, Wurzel 4,47) verschwindet
ein Trait mit ±4 im Abrunden, so geschehen am 10.09.2026 bei All Thumbs,
Dextrous, Gymnast und Burglar. Deshalb geht der Lauf je Fall Fitness, Strength
und Nimble einzeln von 0 bis 10 durch: irgendwo kippt jede Summe über eine
Quadratzahl, und dort zeigt sich jeder Term. 21 Fälle: ohne Trait, Clumsy, High
und Very High Weight, Dextrous, All Thumbs, Gymnast, Burglar, Clumsy mit Dextrous
und mit High Weight (Reihenfolge von Halbieren und Addieren), die acht
Stufen-Traits und die übrigen Gewichts-Traits. Gelesen werden dazu
`getClimbRopeSpeed` hoch und runter und `getMaxWeight`. Oben im Bericht stehen die
Abweichungen gegen den Fall ohne Trait. Setzt das Spiel beim Stufenwechsel
Stufen-Traits, entfernt der Lauf sie vor dem Lesen und vermerkt sie als
`fremd=`. Danach stehen Stufen und Traits wie vorher. Nur mit einer
Wegwerf-Figur.

Ergebnis vom 13.09.2026 (6.19.0, `docs/messungen/messung-2026-09-13-klettern.txt`):
651 Punkte, keiner weicht von der Formel ab (2 × Fitness + 2 × Strength +
2 × Nimble, Gewicht ab, Clumsy halbiert, dann ±4, ganzzahlige Wurzel). Das
Seiltempo folgt Fitness und Strength gleich (Stufe 4 und 5 teilen sich 0,08),
Nimble gar nicht. Dextrous, Gymnast und Burglar +1 Stufe in beide Richtungen,
All Thumbs −1, High Weight −1 und Very High Weight −2 nur hoch, Clumsy am Seil
nichts. Die Stufen- und Untergewichts-Traits ändern an beidem nichts; das
Spiel setzte beim Stufenwechsel über `setPerkLevelDebug` keine Stufen-Traits
(`fremd=` kam nicht vor). `getMaxWeight` stand überall auf 12, weil God Mode
`UpdateStrength` überspringt.

Die XP-Leiter (F8 in 6.16.x, gemessen am 12.09.2026, Bericht in
`docs/messungen/messung-2026-09-12-xpleiter.txt`) steht im Fenster unter
Erledigt und läuft auch aus der Lua-Konsole: `TFMeasure.xpLeiter()`.

Testautos setzt seit 6.16.0 nur noch die Lua-Konsole: `TFMeasure.autoSetzen()`
geht die Liste `TFMeasure.AUTOS` der Reihe nach durch und fängt danach
wieder vorn an. Der Wagen ist repariert, der Tank voll und der Schlüssel liegt
im Inventar. Die fünf Fahrzeuge sind bewusst weit auseinander gewählt
(maxSpeed / engineForce / Masse aus `media/scripts`):

| Skript | maxSpeed | engineForce | Masse |
| --- | --- | --- | --- |
| SmallCar | 70 | 3600 | 650 |
| CarNormal | 90 | 4000 | 800 |
| SportsCar | 120 | 5700 | 800 |
| PickUpVan | 60 | 4000 | 1104 |
| StepVan | 70 | 3700 | 1160 |

Damit lässt sich prüfen, ob der gemessene Zugewinn von Speed Demon vom
Fahrzeug abhängt oder nicht.

### Neue Figur

Die Frage: wirkt der Tragefaktor, den die Mod für Strong (×1,5), Stout
(×1,25), Puny (×0,75) und Weak (×0,9) führt, oder zählt nur die
Strength-Stufe? Laut Code (gelesen am 13.09.2026) wirkt er bei einer normal
erschaffenen Figur nie. `maxWeightDelta` setzen nur die beiden
IsoPlayer-Konstruktoren, und die laufen vor `applyTraits`: die gewählten
Traits stehen dann noch gar nicht an der Figur. Die Kapazität ist
`(int)(8 × getWeightMod)` aus `BodyDamage.UpdateStrength`, 6 bis 20 von
Strength 0 bis 10. Nebenbei setzt `applyTraits` über `LevelPerk` die
Stufen-Traits neu: Fit mit Fitness Instructor endet laut Code mit Athletic und
Stout statt Fit, High Weight bekommt Out of Shape.

Das lässt sich nur an frisch erschaffenen Figuren prüfen. Der Test hat darum
keinen Start-Knopf: `OnNewGame` (feuert nur für neue Figuren) merkt die Figur
vor, zehn Ticks später liest das Mod sie, mit God Mode aus, weil das Spiel die
Kapazität nur ohne God Mode nachrechnet. Je Figur eine Zeile in
`TraitFacts_figur.txt`: Fall, Beruf, gewählte und vorhandene Traits, was das
Spiel dazugetan oder weggenommen hat, Strength, Fitness, `tragen`
(`getMaxWeight`), `stufe` (nur Stufe), `mitfaktor` (Stufe mal Faktor der Mod)
und `lesart`. Das Fenster zeigt die Fälle als Tabelle "Bisher erfasst"; nach
allen sieben steht der Test unter Erledigt. Von Hand erfassen:
`TFMeasure.figurErfassen()`.

Erwartet laut Code:

| Figur | Str / Fit | Kapazität | mit Faktor wäre es |
| --- | --- | --- | --- |
| ohne Trait | 5 / 5 | 12 | 12 |
| Strong | 9 / 5 | 18 | 27 |
| Stout | 7 / 5 | 15 | 18 |
| Puny | 0 / 5 | 6 | 4 |
| Weak | 3 / 5 | 9 | 8 |
| High Weight | 5 / 4 | 12 | 12 |
| Fit + Fitness Instructor | 6 / 10 | 14 | 14 |

Der klettern-Bericht zeigt `tragen` über alle Stufen als 12: er liest im
selben Tick, bevor das Spiel nachrechnet. Die Spalte sagt dort nichts.

Ergebnis vom 13.09.2026 (`docs/messungen/messung-2026-09-13-figur.txt`),
genau wie der Code: Strong 18, Stout 15, Puny 6, Weak 9, ohne Trait und High
Weight 12, Fit mit Fitness Instructor 14; `getMaxWeightDelta` überall 1,00.
**Der Tragefaktor wirkt nicht**, es zählt nur die Strength-Stufe. Trait Facts
führt die vier Werte seit 0.1.27 als wirkungslos, mit eigener Fußnote. Auch
die Stufen-Traits sind bestätigt: High Weight bekam Out of Shape, Fit mit
Fitness Instructor verlor Fit und bekam Athletic und Stout.

Seit 6.28.0 steht in jeder Zeile der Datei zusätzlich, was Trait Facts (ab
0.12.0) an Stufen-Traits vorhersagt: `tfdazu=`, `tfweg=` und `tf=gleich|anders`
(`TF.Summary.levelTraits`, verglichen nur über die acht Stufen-Traits). Läuft
Trait Facts nicht mit, steht dort `-`. Damit prüft jede frisch erschaffene Figur
die Übersicht der Charaktererstellung gegen das Spiel.

### Bildschirmlauf in der Charaktererstellung (seit 6.29.0, neun Szenarien seit 6.30.0)

`TFMeasureScreen.lua`, eine eigene Datei neben `TFMeasure.lua`. Fährt in der
Charaktererstellung acht Szenarien ab (leer, voller Build, Fit mit Fitness
Instructor, Park Ranger, Suche, Zahnrad-Fenster, Warnfenster der fehlenden Mods,
langer Hinweis, seit 6.30.0 zuletzt „allezeigen“: die ganze Übersicht über den
linken Spalten, nur in der schmalen Anordnung), bei jeder Fenstergröße von 1280×720 bis zur Ausgangsgröße, und
legt je Schritt zweierlei ab:

* `Zomboid/Screenshots/TF_<breite>x<höhe>_<nr>_<szenario>.png`
  (`takeScreenshot(name)`, im Jar nachgesehen)
* `Zomboid/Lua/TraitFacts_screen.txt`: Lage und Größe jedes Elements
  (`element|...`), Prüfungen mit `ok` oder `FEHL` (`pruef|...`) und Messwerte
  (`wert|...`). Geprüft wird: nichts Sichtbares ragt aus dem Bildschirm, die
  feste Aufteilung überdeckt sich nicht, Panel und Kopfzeilen-Knöpfe sind da,
  Spaltenbreite mindestens 250 px, gekürzte Trait-Namen, Übersicht im
  Spaltensatz und ohne Umbruch, Scrollhöhen von Übersicht und Startskill-Liste.

Bedienung: Charaktererstellung öffnen (Beruf und Traits), dann **Num 7** oder
**F7**. Mit **Strg** nur die jetzige Auflösung, ohne Wechsel. Dieselbe Taste
bricht ab. Die Auflösung wird im Fenstermodus gewechselt
(`getCore():setResolutionAndFullScreen`) und am Ende zurückgestellt, Vollbild
inklusive; die Ausgangseinstellung steht bis dahin in
`Zomboid/Lua/TraitFacts_screen_restore.txt`, und stürzt das Spiel mittendrin ab,
stellt der nächste Tastendruck sie zuerst wieder her. Ein ganzer Lauf dauert bei
vier Auflösungen rund eine Minute. Getaktet wird über die Uhr (`OnFETick` im
Hauptmenü, `OnTick` in der Welt).

Seit 6.31.0 misst der Lauf, was er vorfindet, statt es vorauszusetzen: Nach
jedem Wechsel bekommt der Bildschirm seine Startgröße (`variante=start`, Vanilla
setzt ihn sonst auf 75 % × 80 %), Borderless wird für den Lauf ab- und danach
wieder angeschaltet, `aufloesung-gegriffen` prüft die Fenstergröße, am Rand
steht der Fortschritt „n/xx“, und die Bildrate steht zweimal im Protokoll:
`fps=` ist der Durchschnitt des Spiels (`getAverageFPS`, glättet über mehrere
Szenarien), `fps-ruhe=` zählt der Lauf selbst über eine ruhige Sekunde vor der
Aufnahme. Zum Vergleich von Szenarien taugt nur `fps-ruhe=`. Welche Fassung ein
Protokoll geschrieben hat, steht in seiner ersten Zeile. Seit 6.31.1 nennt
eine `entfaellt`-Zeile den Grund des Szenarios selbst („breite Anordnung“ bei
„allezeigen“) statt pauschal ein fehlendes Trait Facts.

Nicht abgedeckt: die Schriftgrößen 1x bis 4x (der Wechsel lädt das Lua neu;
dafür müsste der Lauf seinen Stand in eine Datei legen und danach fortsetzen).

### Workshop-Bilder (seit 6.42.0)

**Shift + Num 7** (ohne Debug-Modus Shift + F7) nimmt in der jetzigen Auflösung
die Bilder für die Workshop-Seite auf, nach
`Zomboid/Screenshots/TF_WS_<breite>x<höhe>_<nr>_<name>.png`. Fünf Aufnahmen:
Übersicht mit einem Build, der die Spalte füllt, ohne zu scrollen; Tooltip von
Strong mit der grauen Zeile zur Tragkraft; Major Skills mit dem Tooltip, der die
Rechnung zeigt; Suche nach "panic"; Fenster der fehlenden Mods. Die
Fortschrittsanzeige bleibt aus, sie stünde sonst im Bild. Ein Lauf dauert rund
15 Sekunden.

Tooltips ohne Maus: für die Aufnahme liefern `getMouseX` und `getMouseY` die
Mitte der gewünschten Zeile, danach wieder die echte Maus. Die Lage wird bei
jeder Abfrage neu gerechnet, weil `ensureVisible` weich über mehrere Bilder
scrollt (erster Lauf 22.09.2026: Strong stand ganz unten, der Tooltip fehlte).
Für den Tooltip von Strong schaltet der Lauf "Show values that have no effect"
kurz ein und stellt die Wahl des Spielers danach zurück. Offene Listen-Tooltips
stehen als `element|...|tooltip:<liste>|...` im Protokoll; danach schneidet
`tools/workshop-bilder.py` die Bilder zu, in jeder Auflösung passend.

### Code-Werte

55 Werte in 30 Gruppen, die im Code von 42.20 genau stehen und sich an der
Figur lesen lassen, je einmal ohne und einmal mit Trait: Panikzuwachs
(`IncreasePanic`), Grundtempo bei Panik (`calculateBaseSpeed`), Ausdauer an
Türen (`exert`), Erholung (`getRecoveryMod`), Rückstoß (`processHitDamage`),
Zielverzögerung und Zielruhe, Sichtweite mit dem Gewehr, sechs Wundzeiten
und der Bruch (`BodyPart`), Gift aus Essen, verdorbenes Essen, verseuchtes
Wasser, Erkältung (`UpdateCold`), Infektionsdauer
(`pickMortalityDuration`), Lese-, Forschungs-, Umlager-, Bau- und
Barrikadenzeiten (die `maxTime` der Vanilla-Aktionen) und die XP von Crafty
und Reluctant Fighter. Die Fundstellen stehen im Code an jeder Messung.

Seit 6.24.0 dazu 16 Werte. Vier in drei Gruppen kommen aus Java-Methoden,
die Lua aufrufen darf, alle ohne Zufall (Inventive zählt doppelt: der
kaufbare Trait und der des Berufs):

| Gruppe | Stelle | laut Code |
| --- | --- | --- |
| Rohes Ei | `BodyDamage.JustAteFood` (Offsets 555-661) | Gift 15 × Portion; Iron Gut setzt die Chance bei Eiern auf 0 |
| Kritischer Treffer | `IsoPlayer.calculateCritChance` (Offsets 225-442, 817) | Marksman +10 im Fernkampf-Zweig, danach auf 10 bis 90 geklemmt; Pistole in der Hand, Ziel die Figur selbst, Aiming 0 und, falls ohne Trait über 70, längere Zielverzögerung |

Beim kritischen Treffer lag die Chance am 13.09.2026 mit Aiming 5 ohne und
mit Marksman an der Klemme 90: die Pistole bringt 20 + 6 je Aiming-Stufe,
und bei Abstand 0 kam noch einmal mindestens 40 dazu. Seit 6.24.1 misst der
Test mit Aiming 0 und sucht, falls die Chance ohne Trait noch über 70
liegt, die kleinste Zielverzögerung, die sie darunter bringt; welche, steht
im Log (`Code-Werte krit: Zielverzoegerung ...`).
| Forschungsstufe | `CraftRecipe.getResearchSkillLevel(chr)` | Inventive −2, danach auf 0 bis 10 geklemmt; Rezept MakeImprovisedLighter (Stufe 4) |

Die übrigen 12 aus Vanilla-Lua, aufgerufen wie im Spiel:

| Gruppe | Stelle | laut Code |
| --- | --- | --- |
| Grill anzünden, Anzünder bricht | `ISBBQLightFromKindle:update` | Outdoorsy 1/150 statt 1/300 (×2), 1/450 statt 1/300 (×0,667) |
| Lagerfeuer, dasselbe | `ISLightFromKindle:updateKindling` | Bushcrafter, Former Scout ebenso |
| Leiche umlagern | `ISInventoryTransferAction:update` | Unzufriedenheit Brave ×0,5, Cowardly ×2, Desensitized 0 |
| Blutige Sache umlagern | ebenda | Fear of Blood: Stress Blutwert × Multiplier / 10000 |
| Verbinden | `ISApplyBandage:complete` | Fear of Blood +50 Panik bei blutender Wunde |
| Gelesene Seiten | `ISReadABook.checkLevel` | Illiterate: sofort wieder 0 |

Zwei Kunstgriffe halten die Aufrufe folgenlos. Beim Feuer ersetzt das Mod
`ZombRand` für den einen Aufruf, schreibt jede Grenze mit und liefert 1
(eine 0 hieße Treffer); so zündet nichts und bricht nichts, und die Chance
ist 1/Grenze. Beim Umlagern ist der Quellbehälter ein Stellvertreter, der nur
`getType` (`inventorymale` für die Leiche) und `contains` kennt, und die
Aktion bekommt ein Stellvertreter-Aktionsobjekt, weil sie in keiner
Warteschlange steht. Absichtlich läuft dabei kein Fehler auf: das Spiel
meldet Fehler auch dann, wenn ein `pcall` sie abfängt.

Seit 6.25.0 dazu zwei Spielfehler aus der Engine-Recherche, sieben Werte in
drei Gruppen. Der Faktor laut Code ist hier der mit dem Fehler; wäre er
behoben, wiche die Zeile ab. Die Notiz im Bericht nennt den Spielfehler.

| Gruppe | Stelle | laut Code |
| --- | --- | --- |
| Metallbarrikade | `ISBarricadeAction:new` ruft `getDuration`, bevor es `isMetal` setzt | Metall wie Bretter: ohne 100 (gemeint 170 − 5 × MetalWelding), Handy ×0,8 (gemeint 150/170 = 0,882); Carpentry und MetalWelding auf 0 |
| Craften aus weiblicher Leiche | `ISCraftAction:update` (Z. 19-26) | Unzufriedenheit Brave ×0,5, Cowardly ×2, Desensitized 0 |
| Craften aus männlicher Leiche | ebenda | nichts: `getContainer() == "inventorymale"` vergleicht den Behälter mit einem Text; Differenz mit − ohne, ohne 0 |

Beim Craften ist der Behälter echt (`ItemContainer.new`, wie
`ISInventoryPage.lua:1531`) mit einem echten Hammer darin, damit der
Vergleich mit dem Text genau so ausgeht wie im Spiel; nur die Aktion ist ein
Stellvertreter ohne Rezept.

Zwei Einschränkungen gelten schon im Spiel, nicht erst in der Messung. Beim
Craften erreicht der Zweig für Leichen nur Rezepte, die vom Boden gehen:
sonst legt `ISInventoryPaneContextMenu.OnCraft` (Z. 3487-3503) die Zutaten
vorher ins Inventar der Figur, auch aus weiblichen Leichen. Die
Metallbarrikade gilt im Einzelspieler; im Mehrspieler fragt der Server
`getDuration` laut Review erst an der fertigen Aktion, nach `isMetal`, und
käme dann wohl auf 170 (nicht gemessen).

Ergebnis vom 13.09.2026 (Mess-Mod 6.25.0,
`docs/messungen/messung-2026-09-13d-werte.txt`): **alle 78 Werte stimmen**,
beide Spielfehler bestätigt. Die Metallbarrikade dauert ohne Trait 100 wie
Bretter und mit Handy 80. Aus der weiblichen Leiche gibt das Craften 0,008
Unzufriedenheit je Update, Brave ×0,4999, Cowardly ×2,0000, Desensitized 0;
aus der männlichen 0, mit und ohne Trait.

<!-- seit 6.26.0, je Paket zwischen seinen Markierungen -->
<!-- [paket-a] -->
Seit 6.26.0 dazu drei Stichproben, deren Zufall in der Engine sitzt, 18
Werte in sechs Gruppen. `DoLand` und `applyDamageFromVehicleHit` rufen je
Aufruf `BodyDamage.Update`, tausende davon in einem Tick wären ein
spürbarer Ruckler. Solche Gruppen tragen darum `proben` (n je Fall),
`jeTick`, `probe` und `auswerten` und laufen über mehrere Ticks
(`M.stichTick`): die Fälle (ohne und je Trait) wechseln sich von Probe zu
Probe ab wie im Schlaf-Test, und vor jeder Probe trägt die Figur genau den
Trait ihres Falls. So trifft alles, was sich während der Gruppe langsam
ändert, alle Fälle gleich. `probenVon` teilt die Proben zweier Gruppen,
`toleranz` ist eine feste Toleranz (bei Differenzen in Punkten). Die Zeilen
entstehen danach wie bei den anderen Gruppen, die Notiz nennt Proben und
Ticks, und der Balken im Fenster wandert auch während einer Stichprobe.

| Gruppe | Stelle | laut Code | n je Fall, Toleranz |
| --- | --- | --- | --- |
| Stolpern am Zaun | `ClimbOverFenceState.enter` (Z. 92-133) würfelt `shouldFallAfterVaultOver` (Z. 493-530) | ohne 10 %; Clumsy +10, Graceful -10, Obese +20, Overweight +10 Punkte | 3000, 4 Punkte |
| Zaun, Spielfehler zaun-veryunderweight | ebenda, Very Underweight in Z. 517 und 520 | Very Underweight +30, Underweight 0 | 3000, 4 Punkte |
| Sturzschaden | `DoLand(3.0)` ruft `handleLandingImpact` (Z. 2056-2160), der Schaden kommt aus `OnPlayerGetDamage` "FALLDOWN" (Z. 2117) | ×1,2 Very Underweight und Overweight, ×1,4 Emaciated und Obese; Faktor aus dem größten Schaden je Fall | 4000, 1 % |
| Sturzverletzung | ebenda, Z. 2121-2146 | Anteil Brüche unter den Verletzungen 32 %, +10 bzw. +20 Punkte (`PZMath.lerpFunc_EaseOutQuad` rechnet x², die Namen sind im Spiel vertauscht; der Messplan nahm 52 % an) | 4000, 6 Punkte |
| Unfallschaden | `IsoPlayer.applyDamageFromVehicleHit(auto, -1, 30)` (Z. 1960-1997) | verlorene Gesundheit ×0,8 Fast Healer, ×1,2 Slow Healer | 1200, 2 % |
| Unfall, Spielfehler unfallbruch | ebenda, `generateFracture` ohne Trait-Faktor (Z. 1983-1990, 8409-8419) | mittlere Bruchzeit ×0,920 und ×1,080 statt ×0,6 und ×1,8 | 1200, 4 % |

Ein Zaun ist nicht nötig: `setParams` nimmt den Boden aus dem Nachbarfeld,
und das Mod wählt die erste Richtung, in der `enter` nicht "falling"
meldet. Fitness steht auf 0; eine Probe, während die Figur rennt, zählt
nicht. Beim Sturz bleibt God Mode an (das `Update` im Sturz heilt dann
sofort, die Figur kann nicht sterben). "unsichtbar" und unbegrenztes Tragen
sind aus, weil `getCapacityWeight` sonst 0 meldet und jeder Schaden 0 wäre.
Fitness und Nimble stehen auf 0, ein Brett mit festem Gewicht bringt die
Last auf drei Viertel der Tragkraft (mindestens 3 frei), Kopfbedeckungen
kommen ab, weil `helmetFall` sie sonst auf den Boden wirft, und nach jeder
Landung nimmt `clearFallDamage` sie wieder aus der Animation. Beim Unfall
ist God Mode aus (`checkPVP` lehnt sonst ab), die Sandbox-Option "Player
Damage From Vehicle Impact" steht auf Normal (Voreinstellung und alle
Vanilla-Presets: None, dann gäbe es gar keinen Schaden), und ein CarNormal
steht zwei Felder daneben. Das Tempo -1 lässt `addBloodFromVehicleImpact`
jedes Mal aussteigen, es gibt kein Blut. Nach jeder Probe
`RestoreToFullHealth`. Am Ende und beim Abbruch bekommt die Figur alles
zurück: Schalter wie im Messfenster, Stufen, Last, Kopfbedeckung,
Sandbox-Option; das Auto verschwindet.

Die Bruchzeit beim Unfall hängt nur über den Schaden am Trait. Das Mod
rechnet den Faktor laut Code aus den Bruchzweigen und der Zeitformel
(`M.unfallBruchSoll`, bei Normal ×0,920 und ×1,080); eine Monte-Carlo-Rechnung
mit Überschneidungen am selben Körperteil gab 0,920 und 1,081.

Beim ersten Lauf im Spiel hinhören: jeder neue Bruch spielt
"FirstAidFracture" (bei Sturz und Unfall zusammen einige tausend Mal), über
5 Schaden kommt ein Schmerzlaut (laut Code `" PainFromFallLow"` mit
Leerzeichen, vielleicht findet das Spiel ihn nicht; einmal ins Log sehen),
und jeder Zaunversuch meldet der Musik "HopFence".
<!-- [/paket-a] -->

<!-- [paket-b] -->
Seit 6.26.0 (Paket B) dazu 17 Werte in 14 Gruppen, alle genau oder mit
großen Stichproben in einem Tick. Wo TF_Static nur einen Hinweis führt
(`info`) oder ein Vorher/Nachher (`fromto`), vergleicht die Zeile mit dem
Wert laut Code; die Notiz sagt es. Kann eine Gruppe an dieser Figur nicht
messen, meldet sie "nicht messbar" mit dem Grund, statt einen Fehler zu
werfen: Brille auf (Short Sighted), Sandbox ohne Ernährung oder God Mode
(Gewicht), klobige Handschuhe (Gehen), kein freies Außenfeld 5 bis 8 Felder
entfernt oder kein Zombie (Wind).

| Gruppe | Stelle | laut Code |
| --- | --- | --- |
| Sichtweite | `HandWeapon.getMaxSightRange(chr)` (Z. 1488-1493) | Short Sighted ohne Brille: Höchstweite = Mindestweite, Faktor min/max |
| Unschärfe | `updateVisionEffects`, `updateVisionEffectTargets` (Z. 14108-14116) | `getBlurFactor` 0 ohne, 1 mit; je 3000 Schritte, danach wieder scharf |
| Gewicht | `Nutrition.update` → `updateWeight` (Z. 115-167) | Kalorienschwelle bei 80 kg 1000, Weight Gain −300, Weight Loss +800; Bisektion über `isIncWeight`, God Mode für den Tick aus |
| Ladehemmung | `HandWeapon.checkUnJam` (Z. 2038-2054) | neue Pistole, Aiming 0, ruhig: 92 % gelöst, Dextrous +2, All Thumbs −2 Punkte; 20000 Proben je Fall, Toleranz 1,2 Punkte, Hülsenklang aus |
| Zutaten | `ISCraftingUI.ReturnItemToContainer` (Z. 13-23) | ohne Trait eine Umlager-Aktion, mit Disorganized keine; die Warteschlange zählt nur mit |
| Gehen | `ISHandcraftAction:new` (Z. 405-408) | `stopOnWalk` bei einem Rezept, bei dem man gehen darf: 0 ohne, 1 mit All Thumbs |
| Selbst lernen | `CraftRecipe.checkAutoLearnAnySkills` (Z. 877-919) | Inventive (beide Fassungen) lernt ein Rezept eine Skill-Stufe früher; Rezept mit genau einem Lern-Skill ab Stufe 2, danach wieder vergessen |
| Nikotin | `RecipeCodeOnEat.consumeNicotine` (Z. 22-55) | Smoker: Stress und Unzufriedenheit je + `stressChange` der Zigarette; Nichtraucher Übelkeit + `foodSicknessChange` (14), Smoker 0; ohne Husten |
| Wind | `IsoPlayer.calculateCritChance` → `CombatManager.getWeatherPenalty` (Z. 2065-2082) | Marksman ×0,6 auf die Windstrafe; Steigung der Kritchance über 101 Windstufen, Toleranz 3 % |
| Nährwerte | `Food.DoTooltip` (Z. 1360-1386) | Nutritionist: 5 Tooltip-Zeilen mehr an einem Apfel |
| Bleiche | `IsoGameCharacter.DrinkFluid` (Z. 5479-5506) | Spielfehler irongut-bleiche: verseuchtes Wasser mit Bleiche, Iron Gut ×0; Gegenprobe reine Bleiche ×1 |

Beim Wind setzt die Gruppe den Wind nicht über den Admin-Wert (der landet im
Spielstand), sondern über `ClimateFloat.setFinalValue` für den einen Tick;
Nebel und Niederschlag stehen dabei auf 0. Das nächste Klima-Update rechnet
alles ohnehin neu. Das Ziel ist ein Zombie auf einem Außenfeld, der im
selben Tick entsteht und wieder verschwindet; er bekommt kein Update und
kann nicht angreifen. Die Figur muss deshalb im Freien oder nahe am Freien
stehen. Die Kritchance ist eine ganze Zahl zwischen 10 und 90: gemessen
wird die Steigung, nicht ein einzelner Abzug. Den Tooltip misst die Gruppe
wie `ISToolTipInv` mit `setMeasureOnly(true)`; gezeichnet wird nichts.

Fear of Blood beim Kontextmenü (`hemophobic/medcheck`) misst seit Paket D
die Gruppe Medical Check (unten). Der frühere Hinweis hier, dafür auf die
eigene Figur zu klicken, war falsch: die Option gibt es nur für andere
Spieler.
<!-- [/paket-b] -->

<!-- [paket-c] -->
Seit 6.26.0 dazu drei Gruppen (Rang 11 der Messbarkeits-Recherche vom
13.09.2026), die nur mit gestartetem `-debug` messbar sind: die Reflection,
die private Felder liest, wirft ohne Debug-Modus eine Ausnahme, auch
innerhalb eines `pcall`, und das Spiel loggt sie selbst. Der Test fragt
`isDebugEnabled()` deshalb vor jedem Zugriff; ohne Debug-Modus liefert die
Gruppe den Text "kein -debug" statt einer Zahl, ohne Reflection und ohne
Lua-Fehler (auch der landete im Log), und die Zeilen stehen als "nicht
messbar" mit dieser Notiz. Im Log steht bei jedem Weltbetreten und nach F9, ob
`-debug` an ist (`Debug-Modus: an` bzw. `aus`).

| Gruppe | Stelle | laut Code |
| --- | --- | --- |
| Hörradius | `calculateVisibilityData()`, Feld `noiseDistance` | Basis 2,0; Keen Hearing +3,0, Hard of Hearing -1,0 |
| Schritte | `DoFootstepSound`, Feld `WorldSound.radius` | Graceful ×0,6, Clumsy ×1,2 |
| Albtraum | `SleepingEvent.setPlayerFallAsleep`, Feld `nightmareWakeUp` | ohne 5 %, Desensitized 10 % (Differenz +5 Punkte) |

Hörradius und Schritte lesen `VisibilityData.noiseDistance` bzw.
`WorldSound.radius` per Reflection, weil beide Klassen nicht für Lua
freigegeben sind. Den Hörradius teilt der Test durch
`getWornItemsHearingMultiplier`, damit Mütze oder Helm nichts verschieben.
Bei Schritten steht die Figur sichtbar (unsichtbar bricht
`DoFootstepSound` sofort ab), Lightfoot und Nimble stehen auf 0, und beim
Schleichen oder barfuß im Haus meldet die Gruppe "nicht messbar", weil das
Abrunden die Faktoren dann verschiebt. Das Geräusch bleibt stehen und
klingt nach 16 Updates ab wie jeder echte Schritt; aus der Liste genommen,
bliebe es in den Listen der Chunks hängen und lockte dort weiter Zombies
an. Albtraum zieht 1500 Proben je Fall über mehrere Ticks (60 je Tick, die
Fälle im Wechsel), weil jeder `setPlayerFallAsleep` das Gebäude der Figur
nach Herd, Fernseher, Radio, Fenstern und Türen durchsucht; Toleranz 2,5
Punkte. Die Figur schläft dabei nicht und bekommt ihren Stress zurück.
Geweckt wird sie nur, falls sie doch schläft: `wakeUp` gäbe sonst zwei
Sekunden Schwarzbild, eine Stunde Sperre fürs Schlafen im Auto und zu 10 %
Nackenschmerzen (Review vom 13.09.2026).
<!-- [/paket-c] -->

<!-- [paket-d-krank] -->
Mit Paket D (krank) dazu sieben Werte in drei Gruppen: Leichen-Krankheit
und Erkältung fangen (Rang 13 und 14 der Messbarkeits-Recherche vom
13.09.2026). Beides rechnet das Spiel im Update-Takt, die Gruppen lesen es
trotzdem in je einem Tick, ohne Zutun. Der Code-Werte-Lauf wird dadurch um
drei Ticks länger.

| Gruppe | Stelle | laut Code |
| --- | --- | --- |
| Leichen-Krankheit | `BodyDamage.UpdateIllness` (privat, Z. 2116-2139), erreicht über `BodyDamage.Update`; Rate aus `getCorpseSicknessRate` | Resilient ×0,75, sonst Prone to Illness ×1,25 auf die Grundrate `GetBaseCorpseSickness` (Z. 2141-2143) |
| Erkältung fangen | `BodyDamage.UpdateWetness` (Z. 661-757) | Zuwachs von `catchACold` 0,003 × delta × Multiplier; Prone to Illness ×1,7, Resilient ×0,45, Outdoorsman ×0,25 (Z. 734-743) |
| Erkältung, Spielfehler erkaeltung-schwelle | ebenda, Abbau Z. 751-756 | bei delta 0,12 bis 0,2: Resilient und Outdoorsman 0 statt ×0,45 und ×0,25 |

**Leichen-Krankheit.** Die Grundrate ist erst ab sechs Leichen über 0
(`getSicknessFromCorpsesRate`, Z. 2091-2114). Gezählt werden die Leichen
im 3×3-Chunk-Feld auf der Ebene der Figur, im Haus nur die im selben
Gebäude (`CorpseCount.getCorpseCount`, Bytecode). Die Gruppe legt deshalb
sechs Leichen per `createRandomDeadBody` (LuaManager Z. 8267-8290) auf das
Feld der Figur; der Konstruktor zählt sie sofort. God Mode ist für den Tick
aus, weil `BodyDamage.Update` sonst vor `UpdateIllness` zurückkehrt
(Z. 1821-1825); je Fall läuft `Update` einmal ganz, also ein Bild
Körper-Update. Gemessen wird Rate durch Grundrate, ohne Trait also 1. Steht
die Sandbox-Option "Decaying Corpse Health Impact" auf "None", stellt die
Gruppe sie für den Tick auf Normal. Eine Gasmaske oder ein Atemschutz
senkt die Rate (bei vollem Schutz: "nicht messbar"); ihr Filter verliert
dabei einen winzigen Rest, wie in jedem Bild neben Leichen.

**Erkältung fangen.** `UpdateWetness` baut `catchACold` nur auf, wenn
`Thermoregulator.getCatchAColdDelta` (Z. 429-458) über 0,1 liegt, und das
geht nur mit Haut unter 33 Grad. Die Haut kühlt allein in
`Thermoregulator.update`; ihr Ziel folgt dem Kern und bleibt über der
Lufttemperatur (`updateNodes`, Z. 861-920). Die Gruppe stellt deshalb für
den einen Tick den Kern auf 25 Grad (Wert TEMPERATURE, `update` zieht den
Kern halb dorthin), die Luft über `ClimateFloat.setFinalValue` auf 0 Grad
(wie beim Wind kein Admin-Wert, der im Spielstand landet) und hebt den
statischen `simulationMultiplier`, bis delta über 0,6 liegt; beides kommt
sofort zurück. Weil `UpdateWetness` die Thermo-Knoten nicht anfasst, bleibt
delta für den Rest des Ticks gleich. Je Fall dann `setCatchACold(0)`,
`UpdateWetness`, `getCatchACold`; geteilt durch 0,003 × delta × Multiplier
ist das ohne Trait 1. Welches delta erreicht wurde, steht im Log
(`Code-Werte erkaeltung: delta ...`). Im Haus mit Strom bleibt die Luft bei
22 Grad, das reicht noch; neben einem Ofen oder im geheizten Auto kann
delta unter 0,45 bleiben, dann steht "nicht messbar".

**Der Spielfehler erkaeltung-schwelle.** Nach dem Aufbau prüft
`UpdateWetness` den Abbau mit demselben delta, schon mit dem Trait-Faktor
malgenommen (Z. 751-756), und zieht dann 0,175 ab (`CatchAColdDecreaseRate`,
`defines.lua:40`, ohne Multiplier), ein Vielfaches dessen, was ein Bild
aufbaut. Mit Resilient wächst `catchACold` darum erst ab delta 0,22, mit
Outdoorsman erst ab 0,4; darunter bleibt es bei 0, die Figur fängt sich bei
mäßiger Kälte also gar nichts. Die Gruppe `erkaeltung` misst deshalb
oberhalb von 0,45, wo alle drei Faktoren genau gelten; die Gruppe
`erkaeltungschwelle` kühlt in kleinen Schritten nur auf delta 0,12 bis 0,2
und zeigt dort 0 für beide Traits.

**Was die Figur merkt.** Nichts: alles geschieht innerhalb eines Ticks,
das Spiel zeichnet dazwischen kein Bild und rechnet kein Update. Danach
bekommt die Figur zurück: Traits, God Mode, Übelkeit, `catchACold`,
Erkältung, Niesen, Kälteschaden-Stufe, Nässe von Körper und Kleidung, den
Wert TEMPERATURE, `simulationMultiplier`, Lufttemperatur und
Sandbox-Option; die Leichen verschwinden über `removeCorpse` wie im
Debug-Menü, samt Kleidung und Inhalt, auf den Boden fällt nichts. Die
Hauttemperaturen haben keinen Setter: `Thermoregulator.reset` stellt Kern
37 und Haut 33 Grad ein, danach gleicht sich die Haut in wenigen
Spielminuten wieder an. Beim Anlegen der Leichen feuern `OnDeadBodySpawn`
und `OnContainerUpdate`; andere Mods könnten darauf reagieren.
<!-- [/paket-d-krank] -->
<!-- [paket-d-bau] -->
Paket D bringt dazu den Spielfehler `handy-haltbarkeit`, zwei Werte in zwei
Gruppen:

| Gruppe | Stelle | laut Code |
| --- | --- | --- |
| Holzwand (`wand`) | `ISBuildIsoEntity:setInfo` (Z. 591-759, Lebenspunkte Z. 653-664) | Differenz mit − ohne 0: Handy gibt keine Lebenspunkte |
| Holzleben (`holzleben`) | `buildUtil.getWoodHealth` (ISBuildUtil.lua Z. 39-52) | Gegenprobe: Carpentry × 50, mit Handy +100 |

Das Baumenü von 42.20 baut über `ISBuildIsoEntity` (`ISBuildPanel` Z. 319,
Kontextmenü `ISWorldObjectContextMenu` Z. 3063); `ISBuildAction:perform` ruft
`create`, `create` je Kachel `setInfo` (Z. 584), und dort bekommt das neue
Objekt `health` aus dem Skript (Holzwand `WoodenWallLvl1`: 450) plus Bonus
plus Stufe × `skillBaseHealth` (20), ohne Handy. `getWoodHealth` mit dem +100
liest nur `ISBuildIsoEntity:getHealth`, und das ruft niemand auf; bei der
Holzwand gäbe es ohnehin 450 zurück, weil `health` nicht −1 ist. Das Mod ruft
`setInfo` selbst, wie `create` es tut, auf dem Feld zwei östlich der Figur,
liest `getMaxHealth()` der neuen Wand und nimmt sie im selben Tick wieder
weg, dazu einen Eckpfosten, falls `buildUtil.checkCorner` einen gesetzt hat.
Material, Hammer und Stufe braucht es dafür nicht: die Prüfungen von `create`
(Material, freies Feld) ändern die Lebenspunkte nicht. Die Wand steht nur
diesen einen Tick; man sieht sie nicht.
<!-- [/paket-d-bau] -->
<!-- [paket-d] -->
Seit Paket D (14.09.2026) dazu fünf Werte in drei Gruppen (Rang 10, 22 und
23 der Messbarkeits-Recherche). Alle drei laufen an einem
**Stellvertreter**, einer zweiten Figur aus `IsoPlayer.new(getCell())`.
`IsoGameCharacter` trägt eine Figur nur mit einer Koordinate ungleich 0 in
die Zelle ein (Z. 785-791); der Stellvertreter steht also auf keinem Feld,
bekommt kein Update und wird nicht gezeichnet. Blut auf dem Boden braucht ein
Feld (`splatBloodFloorBig`, Z. 4592-4596), Löcher und Rüstungsklang brauchen
Kleidung, und das Mod zieht ihn aus (`clearWornItems`). Wunden, Blut und
Infektion bleiben an ihm, nicht an der Figur und nicht in der Welt. Das Mod
legt einen je Sitzung an; sein `SurvivorDesc` liegt bis zum nächsten Laden in
`IsoWorld.survivorDescriptors`, einer Liste nur im Speicher (`SurvivorDesc`
Z. 189-193, `IsoWorld` Z. 1798).

| Gruppe | Stelle | laut Code | n je Fall, Toleranz |
| --- | --- | --- | --- |
| Medical Check | `ISWorldObjectContextMenuLogic.createMenuEntries` → `doClickedPlayerMenu` (Bytecode 41-93) | Option ohne Trait da, mit Fear of Blood nicht (Faktor 0) | ein Menü je Fall |
| Dose | `RecipeCodeOnCreate.openCan` (Z. 634-679) | Schnitt ohne 20 %, Dextrous -10, Clumsy +10 Punkte (Cooking 1, Short Blade 0) | 3000, 4 Punkte |
| Zombieangriff | `BodyDamage.AddRandomDamageFromZombie` (Z. 1101-1387) | ohne Verletzung, ohne Waffe: 11 %, Thick Skinned +3, Thin Skinned -3 Punkte | 12000, 1,5 Punkte |

**Medical Check** gibt es nur beim Rechtsklick auf einen anderen Spieler, nie
auf die eigene Figur: `createMenuEntries` ruft `doClickedPlayerMenu` nur mit
`fetch.safehouseAllowInteract` (Bytecode 495-511) und nur, wenn
`fetch.clickedPlayer` gesetzt und nicht der eigene Spieler ist (2770-2806);
`doPlayerMenu` prüft dasselbe (14-22). Fear of Blood fragt die klickende
Figur (`hasTrait(HEMOPHOBIC)` vor `ContextMenu_Medical_Check`). Im
Einzelspiel ohne zweiten Spieler zeigt sich der Trait also nie. Das Mod baut
das Menü wie Vanillas Test-Pfad (`ISMenuContextWorld.lua` Z. 48-53):
`ISContextMenu.get`, sofort `setVisible(false)`, `clearFetch`, dazu
`safehouseAllowInteract` und der Stellvertreter als `clickedPlayer`, dann
`createMenuEntries` mit dem Boden unter der Figur (mit `-debug` braucht
`DebugContextMenu.doDebugMenu` ein Objekt mit Feld); danach
`hideAndChildren` und `clear`. Gezeichnet wird nichts. Ein Kontextmenü, das
gerade offen ist, schließt sich dabei.

**Dose:** `openCan` würfelt je Zutat aus `data:getAllConsumedItems()`
`Rand.Next(20) <= woundChance`, und die Liste kommt aus `appliedItems`, die
erst das Verbrauchen füllt. Das Mod baut eine echte `CraftRecipeData`
(Handcraft, Items erlaubt), setzt das Rezept
`OpenCannedFoodWithKnifeOrSharpStoneFlake`, bietet ein Küchenmesser und eine
Dose Bohnen an und ruft `consumeInputs` mit leerer Ressourcen-Liste: dann
nimmt `consumeRecipeInputs` die angebotenen Items (Bytecode 302-365), und
`consumeInputItemInternal` trägt sie nur in `appliedItems` ein (Offset 310),
ohne sie aus einem Behälter zu nehmen. Das Messer (`mode:keep`) zählt nicht
als verbraucht, die Dose schon. Danach je Probe `openCan(data,
stellvertreter)`; ein Schnitt ist eine Wunde an Hand_L
(`DamageFromWeapon`, Z. 1014-1098), die sofort heilt. Messer und Dose liegen
in keinem Inventar, das Messer, das `openCan` für den Schnitt erzeugt, auch
nicht. Am Stellvertreter steht Cooking auf 1 und Short Blade auf 0, wie die
Notiz von TF_Static annimmt; Cooking 0 gäbe +1 (Z. 668-670), Short Blade ab
4 weniger.

**Zombieangriff:** ein Zombie aus `IsoZombie.new(getCell())`, ebenfalls
außerhalb der Welt, direkt vor dem Stellvertreter (`testDotSide` FRONT) und
nicht inaktiv (`makeInactive(false)`; inaktiv gäbe +20, Z. 1214-1218). Ohne
Feld zählt `getSurroundingAttackingZombies` 0, also einer, und niemand zieht
den Stellvertreter zu Boden. Ohne Waffe ist die Waffenstufe -1 und der
Nahkampf-Mod -5 (`getMeleeCombatMod` Z. 10074-10106), die Grundchance also
10: ohne 11 %, Thick Skinned (int)(10 × 1,3) = 13, also 14 %, Thin Skinned
(int)(10 / 1,3) = 7, also 8 % (Z. 1107, 1125-1130, 1228). Der Sollwert
rechnet mit der Grundchance, die das Mod am Stellvertreter abliest. TF_Static
führt +30 % und -23 % als Faktor auf die Chance; wegen des Abschneidens ist er
kleiner (hier ×1,27 und ×0,73, mit Waffenstufe 2 16, 20 und 12 %). Der Kratz-
und der Bissklang spielen nur bei `getHealth() > 0` (Z. 1244, 1280, 1316);
das Mod setzt die Gesundheit des Stellvertreters für die Gruppe auf 0 und
danach auf 100. Die Schmerzlaute (`playerVoiceSound`, `IsoPlayer`
Z. 6676-6682) gehen an den Emitter des Stellvertreters bei 0,0, weit weg von
der Figur, und das Mod hält ihn am Ende mit `stopAll` an. Ob davon etwas zu
hören ist, beim ersten Lauf prüfen. Ein Weltgeräusch für Zombies entsteht
nicht.

Die beiden Stichproben laufen über mehrere Ticks wie die aus Paket A (Dose
rund 30, Zombieangriff rund 120 Ticks, 300 Proben je Tick, die Fälle im
Wechsel). Vor jeder Probe trägt die Figur den Trait ihres Falls, und das Mod
gibt dem Stellvertreter dieselben. Am Ende und beim Abbruch verliert der
Stellvertreter seine Traits, die Hand heilt, die Gesundheit steht wieder auf
100, und sein Emitter schweigt.
<!-- [/paket-d] -->

Wo ohne Trait nichts passiert (Blut, Verbinden), vergleicht die Gruppe die
**Differenz** mit − ohne statt des Faktors (`differenz = true`); der Wert der
Mod kommt dann auch aus `kind = "flat"`, und die Notiz im Bericht sagt es.
Beim Blut steht der Sollwert erst mit der Messung fest (der Blutwert des
Gegenstands); dafür darf der Faktor laut Code eine Funktion sein.

Eine Gruppe je Tick; vor jeder nimmt der Test der Figur alle Traits ab, am
Ende bekommt sie genau ihre zurück, dazu Waffe, Stufen und Ausdauer-Schalter.
Wunden, Infektionsdauer und verdorbenes Essen gehen über Stichproben (500,
1000 Äpfel). Verglichen wird der Faktor mit dem Wert der Mod aus TF_Static
(`soll_mod`, nur wenn Trait Facts geladen ist), sonst mit dem aus dem Code
(`soll_code`); Toleranz 0,006, bei Stichproben 5 %, beim verdorbenen Essen
20 %. Im Bericht je Wert eine Zeile
`wert|id|trait|ohne|mit|faktor|soll_mod|soll_code|urteil|notiz`.

Nicht dabei, weil das Spiel sie nur im Update-Takt oder privat rechnet:
Sichtkegel, Schritte, Blut, Albtraum (Erkältung fangen und
Leichen-Krankheit misst Paket D, das Einblenden ein eigener Test). Müdigkeit, Hunger, Durst und alles rund um den Schlaf
messen seit 6.23.0 die Tests Wach und Schlaf über Spielzeit, den
Ausdauerverlust beim Rennen seit 6.25.0 der Test Laufen, das Einblenden
seit dem 14.09.2026 der Test Einblenden.

Ergebnis vom 13.09.2026 (Mess-Mod 6.22.0,
`docs/messungen/messung-2026-09-13-werte.txt`): **alle 55 Werte stimmen**,
keiner weicht ab, keiner war nicht messbar. Die genauen Werte treffen auf vier
Stellen (Brave ×0,3000, Rückstoß ×1,4000 und ×0,6000, Bruch ×0,6000 und
×1,8000, Lesezeit ×0,7000 und ×1,3000 usw.). Die Stichproben liegen im
Rauschen: Bisszeit ×0,6237 gegen 0,6154 laut Code, Infektionsdauer ×1,2354
gegen 1,25, verdorbenes Essen mit Iron Gut ×0,41 gegen 0,5 bei 1000 Äpfeln.
Damit sind 46 Werte der Mod von "nur im Code gelesen" auf "gemessen"
gewechselt (`docs/befunde/befunde.json`).

### Panik im Freien

Agoraphobic gibt im Freien je Bild `0,5 × getThirtyFPSMultiplier` Panik, bei
Spieltempo 1 also 15 je Sekunde, gleich bei welcher Bildrate
(`IsoGameCharacter.updateInternal`); im selben Bild baut `ReducePanic` für
jede Figur 1,8 je Sekunde ab. Erwartet: netto +13,2 mit Trait, −1,8 ohne, die
Wirkung 15,0.

Start, dann nach draußen gehen; das Mod wartet, bis
`getCurrentSquare():isInARoom()` falsch ist. Es schaltet God Mode aus (sonst
setzt das Spiel die Panik in jedem Bild auf 0) und das Heilen des Mess-Mods
ab, dann sechs Phasen zu zwei Sekunden im Wechsel mit und ohne Agoraphobic,
je mit einem Startwert (20 mit, 50 ohne). Eine Phase mit einem Sprung über 3
in einem Tick (ein Zombie im Bild gibt +7) oder mit einem Gang ins Haus zählt
nicht und wird wiederholt. Im Bericht `je_s` (Punkte je echter Sekunde) und
`je_30fps` (je Einheit des Bildraten-Faktors, erwartet 0,44 und −0,06).

Ergebnis vom 13.09.2026 (`docs/messungen/messung-2026-09-13-panik.txt`):
**+13,20 je Sekunde mit Agoraphobic, −1,80 ohne, die Wirkung 15,00**, je Bild
0,4400 und −0,0600 mal Bildraten-Faktor, genau wie im Code. Sechs Phasen,
keine verworfen; die drei Phasen je Seite liegen innerhalb von 0,02 je
Sekunde beieinander.

### Blut und Lärm: Blutpanik, Blutstress, Geräusche

Drei Einträge, die in der Befund-Datenbank noch "nur im Code gelesen"
stehen: `hemophobic/bloodpanic`, `hemophobic/bloodstress` und der
Stress-Teil von `deaf/sounds`. Gelesen am 14.09.2026 im dekompilierten
42.20:

| Wert | Stelle | laut Code |
| --- | --- | --- |
| Blutpanik | `IsoGameCharacter.updateInternal` Z. 8219-8221 | je Bild (Hemophobic 0,4, sonst 0,2) × del × ThirtyFPS, del = (1 - Gesundheit/100) × blutende Teile; Faktor 2,0 wie TF_Static |
| Blutstress | `updateStress` (privat) Z. 9221-9223, `getTotalBlood` Z. 12855-12872, `defines.lua:29` | je Update Blut × 0,0000003333 × Multiplier/0,8 × DeltaMinutesPerDay; TF_Static führt ihn als info |
| Geräusche | `updateStress` Z. 9209-9210, `WorldSoundManager.getStressFromSounds` Z. 311-326, `defines.lua:27` | ohne Deaf je Update getStressFromSounds × 0,00002 (ohne Multiplier), mit Deaf nichts |

Du startest und lässt die Figur an einer ruhigen Stelle stehen, am besten
ohne Zombies in der Nähe; den Rest macht das Mod in gut 80 Sekunden
(24 Phasen zu 3 s nach je 20 Ticks Vorlauf). God Mode ist dafür aus: er ruft
je Bild `RestoreToFullHealth`, und das setzt Panik und Stress zurück
(BodyDamage Z. 1821-1824, 1569-1571). Alle Traits sind für die Dauer weg, ein
Desensitized setzte die Panik sonst je Bild auf 0.

1. **Blutpanik**, zehn Phasen ohne Blutung, blutend ohne und blutend mit
   Hemophobic. `ReduceGeneralHealth` senkt die Gesundheit auf 62 (je Teil
   38/17/damageModifier, höchstens 22 Punkte an einer Hand). Der linke
   Unterarm bekommt nur das Flag `setBleeding(true)`, keine Blutungszeit:
   `getNumPartsBleeding` zählt das Flag, `BodyPart.DamageUpdate` zieht
   Gesundheit und tropft Blut aber nur bei `getBleedingTime() > 0`
   (Z. 161-168, 202-220). Ab Gesundheit 60 mit einer Blutung setzt
   `BodyDamage.Update` n = 0 (Z. 1827-1832), es landet also auch kein Blut am
   Boden. Die Gesundheit bleibt so fast fest (sie wächst nur mit der
   normalen Heilung); del liest das Mod trotzdem je Tick neu.
2. **Blutstress**, sieben Phasen im Wechsel ohne und mit Hemophobic, mit zwei
   Äxten mit Blut 1 in beiden Händen. `getTotalBlood` zählt je Gegenstand in
   der Hand `getBloodLevelAdjustedHigh` = Blut × 100 (InventoryItem
   Z. 4682-4687), zusammen also 200 plus das Blut an Kleidung und Haut; das
   Mod liest `getTotalBlood` je Tick.
3. **Geräusche**, sieben Phasen still, laut und laut mit Deaf. Je Tick setzt
   das Mod ein Geräusch auf das Feld der Figur, über die Fassung von
   `WorldSoundManager.addSound` mit 13 Parametern (Z. 107) und `flags = 2`:
   nur "stresshumans". Jede kürzere Fassung setzt dazu Bit 4,
   "stressZombies" (Z. 94); ohne das hört kein Zombie hin (`getSoundZomb`
   Z. 186, `getBiggestSoundZomb` Z. 230, `ZombiePopulationManager.addWorldSound`
   kehrt vorher zurück). Radius 3, stressMod 1. Ein Geräusch lebt 16 Updates
   (`WorldSound.init` Z. 465) und verschwindet dann von selbst aus beiden
   Listen (`WorldSoundManager.update` Z. 342-353, `IsoChunk.updateSounds`);
   nach dem letzten Tick ist nach 17 Bildern keines mehr da. Im Mittel
   stehen 17 zugleich auf dem Feld.

Die Reihenfolge je Bild steht im Bytecode von `IngameState.updateInternal`:
erst `IsoWorld.update` (die Figur rechnet), dann `UpdateStuff` mit
`GameTime.update` und `WorldSoundManager.update`, zuletzt OnTick. Was das Mod
in OnTick setzt und liest (Geräusch, Multiplier, Blut, Gesundheit), gilt also
für das nächste Update der Figur; so zählt es auch.

Stress und Panik ändern sich auch aus anderen Quellen (Abbau je Update,
Unbehagen, Zombies). Jede Messphase zieht deshalb die Grundrate der
nächsten Grundphase davor und danach ab: bei der Panik je ThirtyFPS, beim
Stress je Multiplier × DeltaMinutesPerDay. Übrig bleibt die Wirkung je
Einheit. Im Bericht fünf Werte, Toleranz 2 %:

- `bloodpanic`: Blutpanik mit / ohne Hemophobic, erwartet 2,0 (TF_Static und
  Code); `bloodpanic_ohne`: der Grundwert ohne Trait, erwartet 0,2;
- `bloodstress`: Stress je Blutpunkt und Einheit × 1e7, erwartet 3,333;
- `sounds`: der Anteil, den Deaf vom Geräusch-Stress übrig lässt, erwartet
  0 (Toleranz 0,02); `sounds_ohne`: der Stress je Einheit
  `getStressFromSounds` × 1e5 ohne Deaf, erwartet 2,0.

**Signal gegen Rauschen** (60 Bilder je Sekunde, Tageslänge eine Stunde,
also `getDeltaMinutesPerDay` 0,5): Eine Phase dauert 90 Einheiten
ThirtyFPS. Die Blutung bei del 0,38 bringt ohne Trait 6,8 Panikpunkte über
der Grundphase (-5,4), mit Hemophobic 13,7; im Panik-Test lagen die Phasen
einer Seite auf 0,06 Punkte je Phase beieinander, das ist unter 1 % des
Unterschieds. Der Blutstress bringt 200 × 0,0000003333 × 60 × 0,5 = 0,002
je Sekunde, 0,006 je Phase; die Rundung des float-Stresses bei 0,2 macht je
Phase höchstens 180 × 7,5e-9 = 1,4e-6 aus, 0,02 %. Bei einer Tageslänge von
24 Stunden sind es 0,00025 je Phase und 0,5 %. Die Geräusche bringen
17 × 0,00002 je Tick, 0,06 je Phase, gegen dieselbe Rundung. Ein Zombie, der
ins Bild kommt (+7 Panik), oder ein Sprung über 0,01 Stress in einem Tick
verwirft die Phase; sie wird wiederholt.

**Nebenwirkungen:** gut 80 Sekunden ohne God Mode (Hunger, Durst und
Müdigkeit laufen normal weiter), die Traits sind so lange weg, die
Gesundheit steht im ersten Teil auf 62 mit einer Blutungs-Stimmung, zwei
Äxte liegen im zweiten Teil in Inventar und Händen, im dritten stehen bis
zu 17 Geräusche auf dem Feld, die nur Menschen stressen. Am Ende und beim
Abbrechen (Knopf, F9, Tod, Fehler) bekommt die Figur jede Körperstelle mit
ihrer Gesundheit von vorher, das Blutungs-Flag, beide Hände, Traits,
Panik, Stress, Schmerz und God Mode zurück; die Äxte sind weg. Fällt die
Gesundheit unter 45 (etwa durch einen Zombie), bricht der Test ab; zum
Tod ist es dann noch weit. Bericht: `Zomboid/Lua/TraitFacts_blut.txt`.

### Wach: Müdigkeit, Durst, Hunger

Drei Raten, die das Spiel nur im Update-Takt rechnet und die deshalb nicht
in die Code-Werte passen, gemessen an einer stehenden Figur über Spielzeit
(`getWorldAgeHours`):

| Wert | Stelle | laut Code |
| --- | --- | --- |
| Müdigkeit | `IsoGameCharacter.updateStats_Awake` | Wakeful ×0,7, Sleepyhead ×1,3; im Sitzen oder Ruhen durch 1,5 |
| Durst | `IsoGameCharacter.updateThirst` | High Thirst ×2, Low Thirst ×0,5 |
| Hunger | `updateStats_Awake` mit `getAppetiteMultiplier` | (1 - Hunger) ×1,5 Hearty Appetite, ×0,75 Light Eater |

Alle drei rechnen mit `GameTime.getMultiplier`, Vorspulen ist also erlaubt
und spart Zeit. Weil der Hunger mit (1 - Hunger) wächst, zählt dort die
Rate von ln(1 - Hunger). Die Phasen wechseln dreimal ohne, b, ohne, c und
schließen mit ohne; b trägt Wakeful, High Thirst und Hearty Appetite, c
Sleepyhead, Low Thirst und Light Eater, jeder Trait wirkt auf einen anderen
Wert. Jede Phase dauert 30 Spielminuten und beginnt mit Müdigkeit 0,2,
Hunger und Durst 0,1. Verglichen wird jede Phase mit Trait gegen das Mittel
ihrer Nachbarn ohne, das hebt Drift durch Tageszeit und Temperatur auf;
Toleranz 2 %. Geht die Figur, setzt sie sich oder schläft sie ein, zählt die
Phase nicht.

Danach zwei Phasen satt, ohne und mit Hearty Appetite. Die Stimmung satt
hängt am `healthFromFoodTimer` (`Moodle.Update`); das Mod hält ihn über
`BodyDamage.setHealthFromFoodTimer` oben und in den übrigen Phasen auf 0.
Laut Code wächst der Hunger mit der Stimmung satt für jede Figur gar nicht
(`updateStats_Awake` fragt `FOOD_EATEN`), und damit wirkt auch Hearty
Appetite nicht (Spielfehler `appetit-satt`). Im Bericht steht
`satt|...|urteil=steht`, wenn beide Raten unter 1 % der normalen liegen.

God Mode muss aus sein, das Heilen setzt die drei Werte sonst in jedem Tick
zurück. Am Ende bekommt die Figur Traits, Werte und Satt-Timer zurück.

### Schlaf: Dauer, Einschlafen, Erholung

Du legst dich einmal hin, den Rest macht das Mod. Es setzt die Müdigkeit
vorher auf 0,9 und die Panik auf 0 (sonst lässt Vanilla die Figur nicht
schlafen, `ISWorldObjectContextMenu.lua:1061-1070`) und schaltet God Mode
aus. Dann drei Teile, während die Figur schläft:

1. **Schlafdauer.** Je Fall 200 Aufrufe von
   `ISWorldObjectContextMenu.onSleepWalkToComplete`, der Vanilla-Funktion
   fürs Hinlegen, mit Müdigkeit 0,9; gelesen wird die Weckzeit
   (`getForceWakeUpTime` minus Tageszeit). Laut Code Restless Sleeper ×0,5,
   Wakeful ×0,75, Sleepyhead ×1,18, dann auf 3 bis 16 Stunden geklemmt; bei
   Müdigkeit 0,9 klemmt keiner. Die Stunden kommen aus `ZombRand` in ganzen
   Zahlen (bei 0,9 sind es 8 bis 10 im guten Bett), das Verhältnis der
   größten Werte ist deshalb exakt; seit 6.23.3 ist es der Faktor, das Mittel
   steht daneben. Die Fälle wechseln sich von Aufruf zu Aufruf ab. Vanilla speichert nach jedem Hinlegen die
   Welt (`save(true)`, Z. 1129); für die Proben schaltet das Mod `save`
   stumm. Jeder Aufruf würfelt in `setPlayerFallAsleep` auch einen Albtraum.
   `SleepingEvent.update` weckt die Figur, sobald `(int) getAsleepTime()`
   dessen Stunde erreicht (mindestens 3); das Mod hält die Schlafzeit
   deshalb in jedem Tick auf 0 (`setAsleepTime`, sonst liest sie niemand).
   `SleepingEventData` ist nicht für Lua freigegeben; 6.23.0 rief dort
   `reset()` und bekam je Aufruf eine Ausnahme ins Log.
2. **Einschlafen.** `SleepingEvent.doDelayToSleep` (privat) setzt
   `delayToActuallySleep = Tageszeit + Rand(0, Deckel)`, Deckel 0,3
   Stunden, mit Restless Sleeper 1,0, Night Owl ×0,5, höchstens 2. Erholt
   wird erst, wenn `timeOfSleep` darüber liegt (`updateStats_Sleeping`). Das
   Mod ruft `setPlayerFallAsleep` und sucht den Zufallswert je Probe in 12
   Schritten: `setTimeOfSleep` probeweise verschieben, einen Tick warten,
   sinkt die Müdigkeit? Den Schritt, um den das Spiel `timeOfSleep` je Tick
   weiterzählt (1 / MinutesPerDay / 60 × Multiplier / 2), rechnet es heraus.
   Die Probe liegt einen Schritt unter der Mitte des Intervalls, damit der
   Vergleich des Spiels genau die Mitte prüft. Bis 6.23.3 lag sie auf der
   Mitte, und die Suche verschob nur die Grenzen um den Schritt: sobald das
   Intervall enger als ein Schritt war, meldete jede Probe "eingeschlafen",
   und jede Wartezeit blieb um bis zu einen halben Schritt ungenau. Im
   Schlaf läuft das Spiel schnell, 0,0093 Stunden je Tick; bei Night Owls
   Deckel von 0,12 Stunden ergab das am 13.09.2026 in zwei Läufen genau
   ×0,4832. Der Smoke-Test rechnete mit einem 400-mal kleineren Schritt und
   sah es nicht; seither misst er mit dem Schritt aus dem Spiel.
   Je Fall 300 Proben, die Fälle im Wechsel (bis 6.23.2: 150 Proben, ein
   Fall nach dem anderen). Geschätzt wird der Deckel
   aus dem größten Wert, × (n + 1) / n; bei einer Gleichverteilung ist das
   viel genauer als der Mittelwert. Toleranz 3 %. Im Bericht steht je Fall
   auch, wie viele Proben mit der Stimmung Stress oder Schmerz liefen
   (`doDelayToSleep` rechnet Stress ×1,2 und Schmerz + 1 + 0,2 je Stufe),
   dazu die mittlere Schrittweite. Das gute Bett rechnet ×0,8, der Deckel
   ohne Trait liegt dort bei 0,24 Stunden.
3. **Erholung.** 17 Phasen zu 20 Spielminuten im Wechsel ohne und mit
   Trait, je mit Müdigkeit 0,8 und abgelaufener Wartezeit
   (`setDelayToSleep(0)`). Über 0,3 baut der Schlaf 0,7 Punkte in 5 Stunden
   ab, geteilt durch 0,75 (Wakeful) oder 1,18 (Sleepyhead), mal 0,5
   (Restless Sleeper) oder 1,4 (Night Owl). Toleranz 1 %.

Die Weckzeit setzt das Mod laufend 6 Stunden voraus. Wacht die Figur
trotzdem auf, zählt die laufende Probe oder Phase nicht, und das Mod legt
sie einen Tick später selbst zurück ins Bett, über dieselbe Vanilla-Funktion
und ohne Speichern. Solange sie wach ist, hebt es die Sperre des
Kontextmenüs auf: eine Stunde nach dem Aufwachen verweigert es das Bett
("Can't get back to sleep", `ISWorldObjectContextMenuLogic.doSleepOption`,
`getHoursSurvived - getLastHourSleeped <= 1`); das Mod setzt
`setLastHourSleeped` zwei Stunden zurück. Am 13.09.2026 kam man mit 6.23.0
deshalb nicht zurück ins Bett. Am Ende weckt das Mod die Figur
(`SleepingEvent.wakeUp`) und gibt ihr Traits und Müdigkeit zurück.

### Einblenden: Eagle Eyed und Short Sighted

Neu am 14.09.2026. Wie schnell ein Zombie für die Figur einblendet.
`IsoObject.updateAlpha(IFF)` (Bytecode 79-135) hebt die Alpha je Update um
`0,28 × getMultiplier × mul`, höchstens bis zum Ziel. `mul` kommt aus
`getAlphaUpdateRateMul`: 0,25 auf einem Feld ohne Raum, ×2 in einem Raum
(`IsoObject`, Bytecode 0-26), dann in `IsoGameCharacter.getAlphaUpdateRateMul`
(Z. 6278-6289) ÷2 mit Short Sighted und ×1,5 mit Eagle Eyed. Es zählt der
Trait der Figur, der die Kamera folgt (`IsoCamera.getCameraCharacter`), und
nur der Trait: eine Brille ändert nichts. Die Methode ist `protected`, aus Lua
also nicht aufrufbar; das Mod misst die Wirkung. Erwartet ×1,5 und ×0,5,
ohne Trait draußen 0,25.

`updateAlpha` läuft je Spieler-Index aus `IsoGameCharacter.updateInternal`
(Z. 8136), im Rendern nicht (`isUpdateAlphaDuringRender` falsch, Z. 6291).
In jedem Bild setzt zuerst `FPSTracking.frameStep` den Bildraten-Faktor, dann
laufen die Zombies (`IsoWorld.update`), dann `GameTime.update`, dann
`OnTick` (`GameWindow.frameStep`, `IngameState.updateInternal`, Bytecode).
Das Mod setzt die Alpha des Zombies im OnTick auf 0 und liest sie im
nächsten; geteilt durch `0,28 × getMultiplier` desselben Ticks ist das genau
`mul`, die Bildrate kürzt sich heraus.

Du stellst dich bei Tag ins Freie, mit etwas freier Fläche, und tust nichts.
Der Test braucht rund 1100 Ticks, bei 60 Bildern je Sekunde also etwa 20
Sekunden, bei 30 doppelt so lange. Das Mod setzt einen Zombie auf das
nächste freie Außenfeld ohne Raum 5 bis 8 Felder entfernt
(`addZombiesInOutfit`), macht ihn `useless` (er jagt nicht, `IsoZombie`
Z. 1698 und 2003), schaltet „Zombies greifen nicht an“ ein und dreht die
Figur zu ihm (`faceLocation`). Sieht die Figur ihn 150 Ticks lang nicht
(Ziel-Alpha 1 setzt `IsoPlayer` Z. 5462), nimmt es ihn weg und versucht das
nächste Feld, höchstens acht.

Neun Phasen zu je 120 Proben: ohne, Eagle Eyed, ohne, Short Sighted, ohne,
Eagle Eyed, ohne, Short Sighted, ohne; die übrigen Traits der Figur bleiben.
Eine Probe zählt nur mit Ziel-Alpha 1, einem Zuwachs über 0 und unter dem
Ziel, dem Zombie mindestens 4,5 Felder weit (näher als 4 setzt `IsoPlayer`
das Spieltempo auf 1, näher als 2 die Alpha direkt auf 1, Z. 5471-5489), auf
einem Feld ohne Raum und mit genau den Traits der Phase. Außerdem muss der
Zombie im vollen Update-Takt laufen: der `MovingObjectUpdateScheduler`
rechnet ein Objekt seltener und dann mit einem vielfachen Multiplier, wenn
es nicht gezeichnet wird oder Alpha und Ziel beide unter 0,25 liegen
(`getUpdateSchedulerSimulationLevelForObject`, Bytecode). Das Mod liest die
Stufe (`getCurrentSimulationLevel`) und lässt HALF und darunter aus. Faktor
= Median der Phase mit Trait durch das Mittel der Mediane ihrer Nachbarn
ohne, Toleranz 2 %; daneben derselbe Faktor aus Summe Alpha durch Summe
`0,28 × Multiplier`. Im Bericht stehen auch die Grundrate ohne Trait (laut
Code 0,25), die Update-Stufen der Proben, warum wie viele Proben nicht
zählten, und ob die Figur eine Brille trug.

Nebenwirkungen: Der Zombie ist während des Tests fast unsichtbar, weil seine
Alpha jeden Tick auf 0 geht; mit Short Sighted wird das Bild in dessen
Phasen unscharf. Am Ende und beim Abbrechen (auch mit F9 oder wenn die Figur
stirbt) nimmt das Mod den Zombie weg (`removeFromWorld`, `removeFromSquare`;
er wurde nicht getötet, es bleibt keine Leiche) und gibt der Figur ihre
Traits und den Schalter „Zombies greifen nicht an“ so zurück, wie er vorher
stand. Steht die Debug-Option `Character.Debug.UpdateAlpha` auf aus oder ist
„See everyone“ an, steht die Alpha immer auf dem Ziel, und keine Probe
zählt. Bericht: `Zomboid/Lua/TraitFacts_einblenden.txt`.

### Laufen: Ausdauerverlust beim Rennen

Seit 6.25.0. `IsoPlayer.updateEndurance` ist privat und rechnet nur im
Update-Takt; also rennt die Figur (Shift), und das Mod liest in jedem Tick,
wie viel Ausdauer seit dem letzten weg ist. Laut Bytecode (Offsets 83-246)
zieht jeder Update beim Rennen

    runningEnduranceReduce × enddelta × 2,3 × getPacingMod × getHyperthermiaMod × 0,5 × asth × Multiplier

ab; `enddelta` 1,4, mit Overweight (High Weight) 2,9, mit Athletic 0,8, und
weil Athletic danach steht, schlägt es Overweight. `asth` ist 0,7, mit
Asthmatic (Short of Breath) 1,0. Erwartet also ×2,07, ×0,57 und ×1,43. Last
(`HEAVY_LOAD`, 1,5 bis 2,8) und Schleichen (1,5) kürzen sich im Verhältnis
heraus; Sprinten hat einen anderen Grundwert und zählt nicht.

Das Mod setzt die Ausdauer in jedem Tick auf 0,9 und liest im nächsten den
Abzug, geteilt durch den Multiplier; so hängt die Rate nicht an der
Bildrate. Es zählen nur Ticks, in denen die Figur rennt (nicht sprintet,
nicht schleicht, nicht im Auto), dieselbe Last wie im ersten gezählten Tick
des ganzen Tests und genau die Traits der Phase trägt und wirklich Ausdauer
verliert; beim Gehen erholt
sie sich (dieselbe Methode, Offsets 639-751). Die Gewichts-Traits setzt
`Nutrition.applyTraitFromWeight` alle 2000 Updates nach dem Gewicht neu;
stimmen sie nicht mehr, zählt der Tick nicht, und das Mod setzt sie zurück.

Neun Phasen zu je 400 gezählten Ticks: ohne, High Weight, ohne, Athletic,
ohne, Short of Breath, ohne, beide, ohne. Jede Phase mit Trait wird gegen das
Mittel ihrer Nachbarn ohne verglichen, weil die Hitze beim Rennen langsam
steigt (`getHyperthermiaMod`); Toleranz 2 %. Der Faktor kommt aus Summe
Abzug / Summe Multiplier, daneben steht der aus dem Median der Einzelwerte.
Die unbegrenzte Ausdauer ist für die Dauer aus (`setUnlimitedEndurance`
und das Auffüllen je Tick), God Mode auch: er setzt die Ausdauer in jedem
Bild zurück (`BodyDamage.Update` → `RestoreToFullHealth` →
`Stats.resetStats`), und mit ihm zählte kein Tick. Ändert sich die Last
unterwegs, zählt nichts mehr, bis sie wieder stimmt; das Fenster sagt es.
Am Ende bekommt die Figur Traits, Ausdauer, God Mode und den Schalter
zurück. Bericht: `Zomboid/Lua/TraitFacts_laufen.txt`.

Ergebnis vom 13.09.2026 (Mess-Mod 6.25.0,
`docs/messungen/messung-2026-09-13-laufen.txt`): **alle vier Werte stimmen**.
High Weight ×2,0719 (laut Code 2,0714), Athletic ×0,5720 (0,5714), Short of
Breath ×1,4280 (1,4286), beide zusammen ×0,5720: Athletic schlägt High
Weight. Die fünf Phasen ohne Trait liegen auf 0,0000351657 bis 0,0000351667
je Multiplier, also auf drei Hunderttausendstel gleich; die Hitze hat nichts
verschoben. Last 0, von 3600 Ticks zwei nicht gezählt; Faktor aus Summe und
aus Median sind gleich.

### Im Auto: Klaustrophobie und Kurzschließen

Seit 14.09.2026 (Test `imauto`, mit dir). Zwei Werte, die bisher nur aus dem
Code gelesen waren; du setzt dich dafür ans Steuer eines Autos.

**Claustrophobic** (`claustrophobic/panicin`). `IsoGameCharacter.updateInternal`
zählt ein Fahrzeug wie einen Raum mit 60 Feldern (Z. 8202, 8210-8217): je
Bild `0,6 × (1 − 60/70) × getThirtyFPSMultiplier` = 0,0857 × Bildraten-Faktor,
bei Spieltempo 1 also 2,57 je Sekunde. `ReducePanic` baut für jede Figur 1,8
je Sekunde ab (`BodyDamage` Z. 399-413). Erwartet: netto +0,77 mit Trait,
−1,80 ohne, die Wirkung 2,57 je Sekunde oder 0,0857 je Einheit des
Bildraten-Faktors. Trait Facts zeigt einen Bereich von 0 bis 18 je Sekunde
(je nach Raumgröße) mit dem Hinweis, dass ein Fahrzeug als 60 Felder zählt;
der Bericht sagt, ob der Messwert hineinfällt. Ablauf wie beim Panik-Test:
God Mode und das Heilen des Mess-Mods aus, sechs Phasen zu zwei Sekunden im
Wechsel mit und ohne Trait (Start 20 mit, 50 ohne). Agoraphobic ist in allen
Phasen ab, weil es im Auto unter freiem Himmel +0,5 je Bild gibt
(Z. 8207-8209; `isInARoom` fragt das Feld, nicht das Auto). Eine Phase mit
einem Sprung über 3 in einem Tick (Zombie im Bild), mit Aussteigen oder mit
Pause zählt nicht und wird wiederholt. Verglichen wird die Wirkung je Bild
mit dem Code, Toleranz 3 %; der Sitz ist egal.

**Kurzschließen** (`burglar/hotwire`). Reine Lua-Bedingung in
`ISVehicleMenu.showRadialMenu` (`client/Vehicles/ISUI/ISVehicleMenu.lua`
Z. 109-121): am Steuer, nicht kurzgeschlossen, Motor aus, Sandbox
`VehicleEasyUse` aus, kein Schlüssel im Zündschloss oder im Inventar; dann
mit Electricity ≥ 1 und Mechanics ≥ 2 oder Burglar die Scheibe
„Kurzschließen“ (`onHotwire`), sonst die gesperrte Scheibe
(`ContextMenu_VehicleHotwireSkill`, ohne Befehl). Das Mod ersetzt
`getPlayerRadialMenu` (`ISPlayerData.lua` Z. 143) für je einen Aufruf durch
einen Stellvertreter, der die Scheiben mitschreibt, und ruft
`showRadialMenu` fünfmal:

| Fall | Burglar | Electricity | Mechanics | laut Code |
| --- | --- | --- | --- | --- |
| `ohne` | nein | 0 | 0 | gesperrt |
| `burglar` | ja | 0 | 0 | angeboten |
| `e1m2` | nein | 1 | 2 | angeboten |
| `e0m2` | nein | 0 | 2 | gesperrt |
| `e1m1` | nein | 1 | 1 | gesperrt |

Die ersten beiden ergeben die Zeile `burglar/hotwire`, die übrigen drei
`burglar/hotwire:schwelle` (die Schwelle ohne Trait, die die Datenbank als
„ohne Electricity 1 und Mechanics 2“ führt). Trait Facts nennt dazu nur
einen Text, keine Zahl. Der Stellvertreter kann alles, was `showRadialMenu`
am Menü aufruft (`clear`, `isReallyVisible`, `setX`, `setY`, `getWidth`,
`getHeight`, `addSlice`, `addToUIManager`, `sounds`,
`setHideWhenButtonReleased`, Z. 67-78 und 228-239); was ein anderes Mod
sonst noch aufruft, tut nichts und steht im Bericht. Das echte Menü bleibt
zu, der Menü-Ton stumm, ein Controller-Eintrag ist für den Aufruf weg (sonst
bekäme der Stellvertreter den Fokus). Die Stufen setzt `setPerkLevelDebug`,
das nur die Stufe schreibt und keine XP (`IsoGameCharacter` Z. 4487-4500);
Stufen und Burglar sind im selben Tick zurück. Stimmt eine Bedingung nicht,
steht Kurzschließen als nicht messbar mit Grund im Bericht, statt eines
falschen Werts. Läuft der Motor, steckt der Schlüssel oder liegt er im
Inventar, wartet der Test 20 Sekunden, damit du es beheben kannst. Ein
pausiertes Spiel baut kein Menü (Z. 58-59), dann wartet der Test.

**Ablauf.** Sitzt du in keinem Auto und steht keines in der Nähe
(`getNearVehicle`, rund 4 Felder), stellt das Mod einen `Base.CarNormal`
ohne Schlüssel neben dich und schließt seine Türen auf; `Vehicles.Create.Door`
sperrt sie sonst je nach Sandbox `LockedCar` und Zufall. Legt das Spiel dabei
den Schlüssel ins Zündschloss (`trySpawnKey`, `BaseVehicle` Z. 7111-7119 und
1059-1064), kommt das Auto weg und ein neues her. Du setzt dich ans Steuer,
Motor aus, und fährst nicht; das Fenster sagt jederzeit, worauf der Test
wartet. Kurzschließen dauert einen Tick, die Panik-Phasen rund 12 Sekunden.
Am Ende bekommt die Figur Traits, Panik und God Mode zurück. Das gesetzte
Auto entfernt das Mod, wenn du schon ausgestiegen bist; sitzt du noch drin,
bleibt es stehen, und Fenster und Bericht sagen es. Beim Abbrechen gilt
dasselbe, ebenso wenn die Figur stirbt. Bericht:
`Zomboid/Lua/TraitFacts_imauto.txt`.

**Nicht dabei: Speed Demon rückwärts** (`speeddemon/reversenoise`).
`VehicleEngine.updateWorldSounds` (privat, Z. 257-277) rechnet den
Geräuschradius nur aus Lautstärke und Drehzahl und fragt keinen Trait;
`SPEED_DEMON` steht in `zombie/vehicles` nirgends. Die Drehzahl ist schon
gemessen (`speeddemon/rpmbuild`, ×3 rückwärts). Den Radius zu lesen bräuchte
Reflection in `WorldSoundManager` (nur mit `-debug`), und drei der vier
Geräusche entstehen per Zufall (Z. 266-273). Heraus käme wieder die Drehzahl,
nicht der Trait.

## Neu laden ohne Spielneustart

**F9** lädt das Mess-Mod zur Laufzeit neu und schaltet die Tests wieder scharf.
Damit kostet eine Änderung keinen Programmneustart mehr. Im Log steht danach
`Neu laden: ... ok` und über dem Kopf der Figur die neue Fassung.

Das Spiel liest Lua sonst nur einmal beim Programmstart, und zweimal ist
deshalb schon eine alte Fassung gelaufen, ohne dass es jemand merkte
(10.09.2026: der Autotest blieb stumm, weil noch 3.0.0 geladen war).

Neu geladen wird **nur das Mess-Mod**. Die ausgelieferte Mod bleibt außen vor:
ihre Hooks hängen sich beim Laden in den Charakterbildschirm ein, ein zweites
Laden hängt sie ein zweites Mal ein.

## Was von selbst läuft

Beim Betreten der Welt springt nur an, was noch offen ist, und seit 6.15.1
ist das nichts mehr. Fertige Tests würden stören: der Sprinttest greift zu,
sobald man zum Auto rennt, der Vollgas-Test will durchgehend Vollgas, und der
Beschleunigungstest stellt endlos "in ein Auto setzen" über den Kopf. Alle
drei gehen weiter von Hand aus einer Lua-Konsole.

| Test | Zustand | von Hand |
| --- | --- | --- |
| Messung der 97 Traits | läuft immer beim Weltbetreten | `TFMeasure.run()` |
| Sprinttempo | erledigt (4 Läufe; am 13.09.2026 Athletic 1,00, Unfit 1,00 bei 0,61 % Nachweisgrenze) | `TFMeasure.armSprint()` |
| Höchstgeschwindigkeit | erledigt (5 Wagen) | `TFMeasure.armCar()` |
| Motorkraft beim Anfahren | erledigt (SportsCar, PickUpVan) | `TFMeasure.armAccel()` |

Die drei Fahr- und Lauftests halten sich gegenseitig zurück: wer zuerst
anfängt zu messen, sperrt die anderen, solange er läuft.

## Ablauf im Spiel

1. Im Mod-Menü **Trait Facts Measure (dev)** aktivieren.
2. Neue Figur ohne Traits, Sandbox oder Debug, und ins Spiel starten.
   Wegwerf-Figur nehmen, nicht den laufenden Charakter.
3. Beim Betreten der Welt läuft die Messung einmal. Im Log steht eine Zeile
   `X Traits geprueft, Y Wirkungen, Z von N Groessen lesbar`.
   Direkt danach schaltet das Mod die Figur frei: unverwundbar, für Zombies
   unsichtbar und ohne Angriffe, unbegrenzte Ausdauer (dieselben Schalter
   wie im Admin-Panel). Zusätzlich wird die Ausdauer **jeden Tick auf voll
   zurückgesetzt**, solange das Mess-Mod läuft, so wie Vanilla es im
   Lauf-Debugfenster tut. Der Schalter allein ist ein Versprechen der Engine;
   der Bericht führt je Sprintphase mit, wie tief die Ausdauer vor dem
   Auffüllen wirklich stand (`ausdauer>=`). Zombies stören den Test also nicht; wer ganz ohne
   spielen will, wählt beim Anlegen zusätzlich "Zombies: keine".
4. **Sprinttest:** danach ins Freie gehen und rund 20 Sekunden am Stück
   sprinten, gern in einem Bogen.

   > **Sprint ist die Alt-Taste, nicht Shift.** Zomboid trennt Rennen und
   > Sprinten: Shift rennt nur, und `isSprinting()` meldet das nicht. Wer
   > Shift hält, sammelt keinen einzigen Tick und landet nach fünf Minuten im
   > Abbruch. Die Belegung steht in `Zomboid/Lua/keysB42.ini`
   > (`Run=key:42` = Shift, `Sprint=key:56` = Alt).

   Das Mod schaltet dabei
   Athletic und Unfit phasenweise an und aus und misst die Strecke je Tick.
   Pausen sind erlaubt, nur sprintende Ticks zählen.

   **Nicht nach der Uhr gehen, sondern nach dem Log.** Der Test braucht 1300
   sprintende Ticks in 13 Phasen, also drei Paare je Trait, abwechselnd
   Athletic und Unfit. Am Stück gemessen bekäme der zweite Trait die
   Messbedingungen der zweiten Hälfte: am 10.09.2026 ruckelte genau dort das
   Bild, und Unfit war deshalb nur auf 11 % genau bestimmbar, Athletic auf
   0,97 %. Die erste Phase ist
   ein Warmlauf und geht in keinen Faktor ein: aus dem Stand beschleunigt die
   Figur, und ohne den Warmlauf meldete der Bericht am 10.09.2026 für Athletic
   1,0510 statt 1,0105 - eine Wirkung, die es nicht gibt.

   Ticks, in denen die Sprinttaste hängt und die Figur trotzdem steht (Zaun,
   Auto, Baum), zählt der Test nicht mit und weist sie als `blockiert` aus.
   Der Bericht nennt neben den Faktoren eine `nachweisgrenze`: ein Faktor
   innerhalb dieser Spanne ist von der Streuung der Messung nicht zu
   unterscheiden und beweist nichts. Ein Tick ist ein Bild: bei 60 Bildern je
   Sekunde sind das 16 Sekunden, bei ruckelnder Anzeige entsprechend länger.
   Nach jeder Phase kommt eine Zeile `Sprinttest: Phase X von 8`. Fertig ist
   es erst mit `Sprinttest: abgeschlossen`; wer vorher aufhört oder das Spiel
   schließt, bekommt gar keinen `[sprint]`-Block.

   **Die Meldungen stehen über dem Kopf der Figur**, du musst also nirgends
   nachsehen: einfach sprinten, bis dort grün `Sprinttest: abgeschlossen`
   erscheint. Dieselben Zeilen gehen zusätzlich ins Log
   (`Zomboid/console.txt`), weil nur dort etwas stehen bleibt.
5. **Autotest:** was machen Speed Demon und Sunday Driver mit der
   Höchstgeschwindigkeit? Setz dich in ein Auto, Motor an, und fahr auf einer
   möglichst geraden Strecke Vollgas.
   Das Mod schaltet die beiden abwechselnd an und aus und misst je Phase das
   ausgefahrene Plateau, nicht das mittlere Tempo. Jede Phase schwingt erst
   ein und wird dann gemessen; wie lange das dauert, entscheidet das Auto.
   Beschleunigen **und** Abbremsen brauchen Zeit, und eine Phase ohne Trait
   kommt nach einer mit Trait von oben herunter. Kurven und Bremsen schaden
   nicht; nur ganz langsame Fahrt (unter 5 km/h) zählt gar nicht. Fertig ist es
   mit `Autotest: abgeschlossen` über dem Kopf.

   Rechne mit gut anderthalb Minuten Fahrt. Die Zeit geht fast vollständig ins
   Einschwingen nach jedem Trait-Wechsel, und wie lange das dauert, entscheidet
   das Auto: es muss erst auf sein neues Plateau kommen. Die eigentliche
   Messung sind nur 100 Ticks je Phase. Nimm eine lange gerade Strecke.

   Geprüft werden zwei Behauptungen. Speed Demon steht seit dem 10.09.2026 auf
   gemessenen +11 % (vorher +15 % aus einer Codelesung). Sunday Driver
   behauptet -25 % und ist noch nie gemessen worden.

   Kein Fahrzeug kommt über 122,4 km/h. Wer einen schnellen Wagen nimmt, misst
   deshalb an der Schranke und sieht keinen Unterschied; für den Test eignen
   sich Autos mit einem Skriptwert unter etwa 85 (`TFMeasure.autoSetzen()` in der Konsole setzt passende daneben).

6. **Beschleunigungstest:** was macht die Motorkraft? Der Autotest oben misst
   das Plateau, und dort ist die Kraft längst nicht mehr die Grenze - deshalb
   sah er bei Sunday Driver nichts. Hier wird die Kraft selbst mitgelesen,
   in Tempofenstern von 10 km/h, und dazu die Zeit von 10 auf 50 km/h.

   Ablauf je Phase: **anhalten** (unter 1,5 km/h), dann **Vollgas vorwärts,
   bis das Tempo steht** (seit 6.12.0 endet der Anlauf nicht mehr bei
   50 km/h; seit 6.13.0 gilt das Tempo als stehend, wenn der Höchstwert in
   drei Sekunden um weniger als 0,25 km/h gestiegen ist; ein schwerer Wagen
   braucht dafür gut 20 Sekunden Vollgas und eine lange Gerade), wieder anhalten, dann **Vollgas rückwärts, bis das Tempo steht**. Bremsen oder eine Kurve
   beenden den Anlauf nicht, sie lassen nur das Drei-Sekunden-Fenster von
   vorn beginnen. Erst wenn beide Richtungen liegen und der Wagen
   wieder steht, schaltet das Mod den Trait um und sagt es über dem Kopf;
   solange er rollt, bleibt der alte Trait gesetzt (seit 6.15.0). Vier Phasen: ohne Trait, Sunday Driver, ohne Trait, Speed Demon. Jeder Trait einmal, jeweils gegen die Phase ohne Trait direkt davor.

   Der Kopftext führt dich durch: welche Phase läuft, welcher Trait gesetzt
   ist, welche Richtung noch fehlt, und am Ende `Beschleunigungstest:
   abgeschlossen`.

   | Richtung | Uhr läuft ab | Zeitmarke | Anlauf endet |
   | --- | --- | --- | --- |
   | vorwärts | 10 km/h | 50 km/h | Höchstwert +0,25 km/h in 3 s unterschritten |
   | rückwärts | 2 km/h | 6 km/h | Höchstwert +0,25 km/h in 3 s unterschritten |

   Das Mod erkennt die Richtung am Vorzeichen des Tempos. Rückwärts zählt getrennt und hat eigene Schwellen. Für alle Wagen ist
   rückwärts bei 26,7 km/h Schluss (`tempo × 1,5 > maxSpeedReverse`, 40, in
   keinem Fahrzeugskript überschrieben; gemessen 27,1). Nur mit Sunday Driver
   senkt die Engine die Kraft schon ab 3,3 km/h und kommt bei 10 km/h auf
   null. Die frühere Annahme, rückwärts sei für alle bei 10 km/h Schluss, kam
   aus Läufen mit Sunday Driver. Seit 6.15.0 fährt der Test auch rückwärts,
   bis das Tempo steht.

   Wer unterwegs vom Gas geht, verwirft seinen eigenen Anlauf. Das ist kein
   Fehler, es kostet nur einen zweiten Versuch.

   Im Bericht stehen je Phase die Kraft, die Drehzahl, der Gang und alles
   Weitere, was der Wagen über sich sagt, je Tempofenster von 5 km/h, dazu
   die Höchstgeschwindigkeit der Phase als `tempofaktor` und absolut in der
   `phase|`-Zeile (`hoechst=`).

   **Welchen Wagen nehmen.** Seit 6.14.0 rechnet der Bericht die Schwellen
   selbst aus (`info|grenzen`), man muss sie also nicht mehr im Kopf haben.
   Die Regel dahinter: Sunday Driver senkt die Kraft ab 0,6 × maxSpeed, ohne
   Trait beginnt die Absenkung erst bei maxSpeed, Speed Demon bei
   1,15 × maxSpeed, und über allem liegt eine Schranke bei 122,4 km/h.

   | Wagen | maxSpeed | Sunday Driver ab | Höchsttempo ohne / SD / SpD |
   | --- | --- | --- | --- |
   | SmallCar | 70 | 42 | 90 / 72,5 / 100,5 |
   | CarNormal | 90 | 54 | 110 / 87,5 / 122,4 |
   | SportsCar | 120 | 72 | 122,4 / 110 / 122,4 |
   | PickUpVan | 60 | 36 | 80 / 65 / 89 |
   | StepVan | 70 | 42 | 90 / 72,5 / 100,5 |

   Daraus folgt: der **SportsCar taugt für Speed Demon nicht**, weil beide
   Werte an der Schranke liegen. Die **Zeit von 10 auf 50 km/h ist bei allen
   außer CarNormal und SportsCar verfälscht**, weil Sunday Drivers Schwelle
   mitten im Messfenster liegt; der Bericht schreibt dann `info|zeitfenster`
   dazu. Die **Kraft je Fenster bleibt überall sauber**, unterhalb der
   Schwelle glatt, darüber mit der ausgewiesenen Vorhersage.

   **Warum 6.14.0 nötig war:** der Bericht trug Erwartungen mit sich, die
   der eigene Befund schon widerlegt hatte (rückwärts 1,43 für Sunday
   Driver, 0,33 für Speed Demon), er nannte einen `tempofaktor` rückwärts,
   der bauartbedingt immer 1 ist, und ein durch die Reißleine beendeter
   Anlauf sah aus wie ein sauber ausgefahrener. Neu sind stattdessen: die
   Kraftvorhersage aus dem Bytecode neben jedem Messwert, Marken für steile
   Fenster, Drehzahlbegrenzer und Gangkanten, Millisekunden neben den Ticks
   (Ticks sind Bilder, die Bildrate schwankt) und `|REISSLEINE` an der
   betroffenen Phase.

   **Warum 6.13.0 nötig war:** bis 6.12.0 galt das Tempo als stehend, wenn
   180 Ticks lang kein einzelner Tick mehr als 0,05 km/h zulegte. Das ist
   keine Plateau-Erkennung, sondern eine Beschleunigungsschwelle von
   3 km/h je Sekunde, und die unterschreitet ein Wagen rund 7 bis 12 km/h
   vor seiner Grenze. Mit Sunday Driver (weniger Kraft) noch früher: der
   Test hätte mit Trait eine niedrigere Höchstgeschwindigkeit gemeldet als
   ohne, auch wenn der Trait dort gar nicht wirkt. Der Smoke-Test fährt
   seither asymptotisch an die Grenze und meldet mit der alten Logik
   0,73 statt 0,75.

   Bestätigt sind an SportsCar und PickUpVan (11.09.2026): Sunday Driver
   -25 % Motorkraft vorwärts, -30 % rückwärts, Speed Demons dreifache
   Drehzahl rückwärts. Vorwärts steht im Bericht roh 0,76 bis 0,78, weil die
   Drehzahl mit Trait höher liegt und `control_ForwardNew` die Kraft über
   `0,3 + Drehzahl / 30000` an sie bindet; herausgerechnet bleibt in allen
   acht Fenstern im ersten Gang 0,7500 (Auswertung 13.09.2026).
   Sunday Drivers Höchstgeschwindigkeit ist am PickUpVan aus dem Stand
   gemessen: 64,8 statt 79,9 km/h, die Formel sagt 65,0. Der Plateau-Test
   davor hatte den Trait bei voller Fahrt gesetzt und deshalb keine Senkung
   gesehen.

7. Ergebnis: `%USERPROFILE%\Zomboid\Lua\TraitFacts_measure.txt`.
8. Mod wieder abschalten.

Wiederholen geht mit `TFMeasure.run()`, wenn eine Lua-Konsole zur Hand ist.

## Was gemessen wird

Je Trait wird der Wert einmal ohne und einmal mit genau diesem Trait gelesen;
die Traits der Figur werden vorher gesichert und danach exakt zurückgesetzt.
Trait an- und abschalten ist eine unterstützte Operation, Vanilla macht es
selbst in `ISPlayerStatsUI`.

Der Bericht hat sieben Abschnitte:

| Abschnitt | Inhalt |
| --- | --- |
| `[groessen]` | welche Getter an dieser Figur lesbar sind, mit Basiswert und Herkunft. Ein als `SOLLTE DA SEIN` markierter Ausfall ist ein Befund. |
| `[wirkungen]` | `trait\|groesse\|basis\|mitTrait\|prozent\|faktor\|differenz`, alle drei Lesarten, weil `kind` erst in `TF_Static` entschieden wird |
| `[registry]` | Bezeichnung, Kosten, Berufs- und Multiplayer-Flags, Rezepte, gewährte und ausgeschlossene Traits, XP-Boosts |
| `[foraging]` | die Rohwerte aus `forageSystem.forageSkillDefinitions`: Sichtbonus, Wetter, Dunkelheit, Bedingung, Kategorien |
| `[xp]` | Faktor und Boost je Skill, die Leiter der Boost-Stufen an Woodwork (wenn `setPerkBoost` existiert) und die Faktoren von Fast und Slow Learner direkt aus `AddXP`. Schreibt 120 XP auf die Figur, deshalb die Wegwerf-Figur. |
| `[behaelter]` | Organized und Disorganized an einer erzeugten Tasche (`getEffectiveCapacity`), die nie in die Welt kommt |
| `[sprint]` | der Verhaltenstest zur "tot"-Behauptung: Strecke je Tick je Phase und der Faktor mit/ohne Athletic und Unfit. 1.00 heißt tot; 1.20 hieße, die Mod irrt. |
| `[ohne messbare wirkung]` | Traits, die auf keine gemessene Größe wirken. Das ist die Deckungsliste: steht dort ein Trait, dem wir eine dieser Größen zuschreiben, stimmt etwas nicht. |

Die Getter-Liste in `TFMeasure.PROBES` trennt zwei Sorten: `sicher = true`
steht so im dekompilierten Build 42.20.4 (mit Zeilennummer), alles andere ist
ein Kandidat, dessen Name aus dem Prüfbericht stammt. Ein Kandidat, den es
nicht gibt, kostet nichts und wird als `fehlt` gemeldet; findet er sich,
schließt er eine Lücke, die heute statisch bleibt (Klettern, Fallschaden,
Tempo, Lesen).

## Test

`python tools/smoke-test.py` fährt den Mod unter der Gruppe **Mess-Mod** mit
einer nachgebauten Figur durch: Abschnitte, alle drei Lesarten, fehlende
Kandidaten, Deckungsliste und die Rückgabe der Traits an die Figur. Die Gruppe
**Messfenster** baut dazu Vanillas UI-Bausteine, Bäume, die Fäll-Animation
und Schläge nach (ChopTreeSpeed und CombatSpeed 0,8 und 1,0) und prüft
Fenster, Stand-Datei, Axt-Test, Abbrechen, fehlenden Baum, abgelehnten
Lua-Schlag, F9 und dass jeder erfragte Text in der UI.json steht. Ein
Tippfehler kostet sonst eine ganze Spielsitzung.
