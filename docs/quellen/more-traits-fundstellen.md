# More Traits Definitive: Fundstellen je Zeile des Datenpakets

Stand 21.09.2026, nachgetragen nach den beiden Faktensweeps vom 23.09.2026
(Abschnitte unten). Geprüft wurde jede Zeile von
`mod/42/media/lua/shared/TraitFacts/packs/TF_Pack_MoreTraits.lua` gegen den
installierten Code von More Traits Definitive (Workshop 3799050151). Die Zahlen
sind aus dessen Code gelesen, nicht gemessen.

Pfade sind relativ zum Mod-Ordner `moreTraitsDefinitive/42.0/`. Kürzel:
`S/` = `media/lua/shared/MT/`, `Tick` = `S/MT_Tick.lua`, `SBX` =
`media/sandbox-options.txt` (Zeile der Vorgabe), `DEF` =
`media/scripts/ToadTraits.txt`.

## Ergebnis

Von 129 Zeilen stimmten 95 so, wie sie dastanden. 8 waren falsch und sind seit
Trait Facts 0.13.7 berichtigt, 17 sind unklar (Zahl richtig, Fußnote oder
Bedingung ungenau), bei 9 fehlt der Hinweis auf die Sandbox-Option. Jede Zeile
hat eine Fundstelle, und jede genannte Funktion wird in der Mod wirklich
aufgerufen (verdrahtet in `Tick:153-163`, Erschaffung in
`S/MT_Creation.lua:458-460`).

Chancen: `ZombRand(0,101) <= N` ergibt (N+1) von 101. Das Paket schreibt N+1.

Nicht geprüft: die Mehrspieler-Pfade in `server/MT_ServerCommands.lua`. Ob das
`damage`-Argument von OnWeaponHitCharacter der wirklich abgezogenen Gesundheit
entspricht, ist seit dem Faktensweep 23.09.2026 entschieden: nein, siehe dort.

### Berichtigt in 0.13.7

| Trait | Zeile | vorher | im Code | Fundstelle |
| --- | --- | --- | --- | --- |
| Pro Blade, Pro Blunt, Pro Spear | mtcrit | 5 von 100 | `ZombRand(0,101) <= 5`, also 6 von 101 | S/MT_Combat.lua:24, :57 |
| Quick Rest | mtrest | 3,3 bis 7,2 % je Spielstunde | 0.055 am Boden, 0.12 auf Möbeln, auf dem Balken 0 bis 1, je Spielminute: 5,5 und 12 % | S/MT_Rest.lua:161-168, Tick:114 |
| Expert Driver | mtengine | x3 | Motorkraft x6 | S/MT_World.lua:202 |
| Poor Driver | mtengine | x0.66 | Motorkraft x0.5; die 0.66 gehören zum Tempomat | S/MT_World.lua:211, :214 |
| Second Wind | Fußnote | einmal je 7 Spieltage | lädt nach dem ersten Mal nie wieder auf: `SecondWindRecharge` kehrt zurück, solange `secondwinddisabled` wahr ist, und nur es selbst setzte das zurück | S/MT_Rest.lua:57, :50, :71 |
| Indefatigable | Fußnote | einmal je Figur | lädt nach 7 x 24 Stunden wieder auf, auch mit One Use | S/MT_Indefatigable.lua:84-86, :94-113 |
| Bouncer | Fußnote | 5 von 100 | 6 von 101 | S/MT_State.lua:525-527 |

More Traits wurde am 17. und 18.09.2026 aktualisiert, `MTModVersion` blieb dabei
42.20. Ob das Paket bei den Fahrer-Traits und den beiden Fußnoten ältere Werte
trug, lässt sich nicht mehr prüfen. Die Versionsangabe taugt nicht als Warnung
vor Änderungen.

### Unklar, noch offen

Stand nach dem Faktensweep 23.09.2026. Die übrigen Zeilen, die hier standen
(scrounger, actionhero, badteeth, drinker, anemic/thickblood, mundane,
gourmand/ascetic, lucky/unlucky, burned und der Wortlaut von glassbody), sind
entschieden und berichtigt, siehe Abschnitt "Faktensweep 23.09.2026".

| Trait / Zeile | Was nicht passt | Fundstelle |
| --- | --- | --- |
| glassbody / mtglass | Fußnote berichtigt. Offen, als möglicher Fehler der Mod: der Bezugswert ist der zwischengespeicherte Gesamtwert (`getOverallBodyHealth`, erst am Ende von `BodyDamage.Update` neu gerechnet, BodyDamage.java:2045), und OnPlayerGetDamage "BLEEDING" feuert in der Schleife davor (BodyPart.java:162-164). Der eigene Zusatzschaden zählt beim nächsten Ereignis also wieder als Verlust und kann sich je Tick verdoppeln, bis ein Unterschied über 50 liegt. Nur aus dem Code gelesen; messen (Glass Body, eine kleine blutende Wunde, Gesamtgesundheit je Tick), bevor es in die Fußnote kommt | S/MT_State.lua:44, :58-60, :83 |
| terminator, antigun / mtaim | Code stimmt (x2, x0.8 auf setAimingTime). Die Beschreibung der Mod sagt das Gegenteil | S/MT_Combat.lua:442, :449 |
| butterfingers / mtdrop | Zeile stimmt. Es würfelt je Spielminute, nicht je Bild: 0,2 % je Spielminute ohne Last wären als Zahl möglich | S/MT_State.lua:216-256; Tick:100 |
| quickworker, slowworker / mtaction | berichtigt (beim Umlagern nur das erste Stück), aber nur aus dem Code gelesen; vor der Veröffentlichung mit dem Mess-Mod prüfen: 5 gleiche Gegenstände umlagern, maxTime je Stück | Spiel client/TimedActions/ISInventoryTransferAction.lua:478-529, :739 |
| expertdriver, poordriver / mtbrake, mtspeed | berichtigt (hält nur bis zum Verschleiß oder zum Laden), nur aus dem Code gelesen; im Spiel prüfen | BaseVehicle.java:878, :8205 |

Den Hinweis auf die Sandbox-Option vermissten bis 0.13.9 progun/mtammo,
martial/mtdamage, packmule und packmouse/mtcarry, graverobber/mtcorpse,
incomprehensive/mtlost, injured/mtinjury, gordanite/mtcrowbar und
ingenuitive/mtrecipes. Seit dem Faktensweep 23.09.2026 nennt jede dieser
Fußnoten ihre Option.

## Faktensweep 23.09.2026

Grundlage: `docs/berichte/2026-09-23-faktensweep.md` (Pakete mtd-1, mtd-2,
mtd-3 und die MTD-Funde aus data-consistency). Jeder Fund ist noch einmal
gegen den Code der Mod und das dekompilierte Spiel gelesen. Alle Zahlen weiter
aus dem Code, nicht gemessen. Das Paket hat jetzt 131 Zeilen (vorher 129:
Mundane und Burn Ward Patient haben je eine zweite Zeile), weiter für 93 Traits.

### Zusatzschaden: kein Prozent auf den Nahkampfschaden

OnWeaponHitCharacter übergibt `damageSplit` vor allen Multiplikatoren des
Spiels (IsoGameCharacter.java:5705, vor processHitDamage :5758ff und
hitConsequences :5816-5818). Das Spiel rechnet danach Entfernung (0,3 bis 2),
x1,5 von hinten, x1,5 für Nicht-Spieler, Waffenstufe 0,3 + 0,1 x Stufe,
kritischen Treffer (mindestens x2) und für Nahkampf x0,15
(CombatConfigKey.java:11-14, :61; CombatManager.java:3195-3205). Die Mod zieht
ihren Anteil dagegen direkt ab (MT.lua:271-276). Ein normaler Nahkampftreffer
nimmt bei Entfernungsfaktor 1 ohne Krit 1,5 x 0,3 x 0,15 = 6,75 % des Wurfs
(Stufe 0) bis 1,5 x 1,3 x 0,15 x 1,5 = 44 % (Stufe 10 von hinten). 12 % des
Wurfs sind also +27 % bis +178 % eines normalen Treffers, mit Krit und größter
Entfernung nur +7 %. Das Paket zeigt diese Zeilen jetzt als "Zusätzlicher
Schaden je Treffer" in "% des Schadenswurfs" (kind flat) mit dem Vergleich als
`condition`, nicht mehr auf der Vanilla-Zeile "Nahkampfschaden", wo die
Übersicht sie mit Puny und Weak multipliziert hätte.

Martial: ein Schubser mit bloßen Händen macht im Spiel keinen Schaden
(CombatManager.java:1121-1124 doShove, IsoGameCharacter.java:5700-5702
bIgnoreDamage). Der Schaden von Martial ist dort also der ganze Schaden; nur
beim Tritt (Schubser zum Boden) kommt er obendrauf. Darum ohne den Vergleich.

### Berichtigt

| Trait / Zeile | bis 0.13.9 | jetzt | Fundstelle |
| --- | --- | --- | --- |
| problade, problunt, prospear / mtdamage | Nahkampfschaden +12 % | Zusatzschaden +12 % des Schadenswurfs, nur gegen Zombies, nicht mit Mundane | S/MT_Combat.lua:6, :22, :57-61 |
| problade, problunt, prospear / mtcrit | Kritische Trefferchance 6 von 100 | Chance, dass der Zusatzschaden sich verdoppelt; der Wurf setzt nie den kritischen Treffer des Spiels (kein setCriticalHit in der Mod) | S/MT_Combat.lua:57-59 |
| problade, problunt, prospear / mtrepair | "wenn der Treffer Zustand gekostet hat" | wenn der Treffer davor Zustand gekostet hat: das Spiel senkt den Zustand erst nach dem Ereignis (CombatManager.java:1010, SwipeStatePlayer.java:244); nicht mit Mundane | S/MT_Combat.lua:63-67, :131 |
| tavernbrawler / mtdamage, mtrepair | Nahkampfschaden +10 % | Zusatzschaden +10 % des Wurfs; Reparatur beim improvisierten Speer 1 von 100 (26 sehr zerbrechlich) | S/MT_Combat.lua:95-123 |
| actionhero / mtcrowd | Spanne 0,5 bis 25,5 % | Grundwert 0,5 % des Wurfs, +5/+2/+1 je Zombie unter 2/5/10 Feldern, ohne Obergrenze; jede Waffe, auch Schusswaffen; ohne isZombie-Prüfung | S/MT_Combat.lua:134-182 |
| actionhero / mtcrit | Kritische Trefferchance 11 von 100 | Chance, dass der Zusatzschaden sich verfünffacht; nur gegen Zombies, nicht mit Mundane | S/MT_Combat.lua:176-177 |
| martial / mtdamage | Nahkampfschaden +10 % | Zusatzschaden 10 % des Wurfs; Schubser machen sonst keinen Schaden; Optionen MartialWeapons und MartialScaling genannt | S/MT_Combat.lua:264-295; SBX:88-91, :203-207 |
| martial / mtcrit | Kritische Trefferchance 6 von 100 | Chance, dass der Zusatzschaden sich vervierfacht | S/MT_Combat.lua:272-292 |
| unwavering / mtdamage | Nahkampfschaden +125 % | Zusatzschaden 125 % des Wurfs; jede Waffe, auch Schusswaffen, gegen jede Figur | S/MT_Combat.lua:210-246 |
| mundane / mtcritfix | "sinken auf 1 von 100" | setzt den Grundwert der Waffe auf 1; das Spiel klemmt auf mindestens 10 (IsoPlayer.java:3689), Nahkampf +3 je Stufe (:3672), +5 von hinten (CombatManager.java:2754), Close Kill von hinten immer kritisch (:2765-2768); gilt ab dem zweiten Treffer, weil der Wurf vor dem Ereignis fällt | S/MT_Combat.lua:184-208 |
| mundane / mtproff (neu) | fehlte | schaltet die drei Pro-Traits ganz ab und die Krit-Würfe von Action Hero und Martial; Pro Gun nicht | S/MT_Combat.lua:22, :176, :290 |
| terminator, antigun / mtrange | "Visier-Reichweite" | "Reichweite der Schusswaffe": MaxRange, nicht MaxSightRange | S/MT_Combat.lua:443, :450; HandWeapon.java:813-817, :1488-1492 |
| batteringram / mtram | ohne Fußnote | Fußnote zum Zusatzschaden mit Martial (0,1 bis 0,6, ohne MartialWeapons nur unbewaffnet). Der Geistermodus steht im Kopf des Pakets als absichtlich fehlend: PlayerCheats nimmt INVISIBLE nur im Mehrspieler oder mit -debug an | S/MT_Combat.lua:486-490, :537-556, :571; PlayerCheats.java:25-41 |
| burned / mtfire, mtmolotov (neu) | eine Zeile, die Option schalte alles ab | zwei Zeilen: Feuer und Leichen (Option Burned Ward Fire Aversion), Molotow und Flammenfallen in der Haupthand (immer) | MT_BurnWard.lua:4, :101-113; S/MT_Combat.lua:722-737 |
| amputee / mtarm | "heilen von selbst" | im Nu vollständig, Bisse eingeschlossen, alle 31 Bilder; nicht mit dem Mod Amputation | S/MT_Combat.lua:669-694 |
| leadfoot / mtstomp | x2 | +140 bis +225 % (x2,4 schwere Stiefel, x3 normale Schuhe, x3,25 Hausschuhe); im Faktensweep 2 berichtigt, siehe dort | S/MT_World.lua:256 |
| fast, gimp / mtmove | kind range, ohne Vorzeichen und Farbe | kind pctrange | - |
| packmule, packmouse / mtcarry | +2 / -2 Tragekapazität | Spanne der wirklichen Änderung, +2 bis +10 / -5 bis -2: die Mod setzt die Basis, Stärke vervielfacht sie (0,8 bis 2,5) | S/MT_Weight.lua:7-18; BodyDamage.java:1779; IsoGameCharacter.java:4372-4405 |
| evasive / mtdodge | "neue Verletzung ganz verschwindet", "je neu verletztem Körperteil" | "neue Wunde verschwindet"; gewürfelt nur in der Trefferreaktion bei einem Schadensereignis: Schnitte und Bisse bluten, ein einfacher Kratzer meist nicht; verlorene Gesundheit bleibt, außer bei Bissen | S/MT_State.lua:86-173; BodyPart.java:161-164, :719-745 |
| anemic, thickblood / mtbleed | "Gesundheit je blutender Wunde" | Gesundheit des blutenden Körperteils; die Gesamtgesundheit ändert sich nur um dessen Anteil (Hand 0,1, Kopf 0,6). "Nur ohne Verband" stimmt: setBandaged löscht bleeding (BodyPart.java:558-561) | S/MT_State.lua:614-676; BodyDamage.java:2079-2088 |
| superimmune / mtfever | better "down" | better "open": die Übersicht färbt jetzt auch kind range, rot wären die Fiebertage falsch, sie ersetzen die Zombifizierung | - |
| immunocompromised / mtinfect | "neue Wunde infiziert dich" | Zombie-Infektion (setInfected, BodyDamage.java:2013-2040), ein Wurf je Treffer, nur solange nicht infiziert; Optionsname "Immunocompromised Chance" | S/MT_State.lua:174-194 |
| glassbody / mtglass | "ein zweites Mal abgezogen" | das Doppelte des Verlusts, zusammen das Dreifache; Bruch über 0,33, Kratzer über 0,1; ein verfehlter Wurf nimmt den Verlust mit; nicht im Zeitraffer | S/MT_State.lua:20, :44, :49-60, :71, :83; BodyDamage.java:938-941, :2079-2088 |
| selfdestructive / mtharm | "ein Drittel" | mit Depressive die Hälfte | S/MT_State.lua:362-363 |
| badteeth / mteat | "Trinken zählt nicht" | dazu die zweite Quelle: jeder Anstieg von HealthFromFoodTimer über 1000 bringt 1 % davon als Kopfschmerz (satt essen, Getränke mit Hungerwert). Einzelspiel 25 je Mahlzeit; ein dedizierter Server hängt den Wrapper zweimal an (50), weil er Server-Lua vor OnGameBoot lädt | S/MT_State.lua:420-456, Tick:43; BodyDamage.java:579-587; IsoGameCharacter.java:5489-5490; server/MT_EatFood.lua:25-47 |
| indefatigable / mtlast | "lädt nach 7 Spieltagen" | heilt auch die Zombie-Infektion, bei jedem Auslösen; löst auch beim Zu-Boden-Ziehen aus; Aufladen 7, 14 oder 28 Tage | S/MT_Indefatigable.lua:17, :36-40, :61-76, :94-113 |
| gourmand, ascetic / mtcook | ohne Bedingung | nur für Essen, das vor dem Kochen im Hauptinventar war | S/MT_Nutrition.lua:218-236 |
| gourmand / mtfresh | ohne Einschränkung | bei gemischten Stücken kann ein frisches getauscht werden, das neue ist ungekocht | S/MT_Containers.lua:786-803 |
| scrounger / mtloot | "rund 30 % mehr" | 2 bis 4 gleiche etwa noch einmal so viele (2: +2, 3: +3, 4: +5), ab 5 das 2,6-Fache dazu, Einzelstück 21/16/11 von 100; Optionen genannt | S/MT_Containers.lua:8-12, :34, :51-78 |
| incomprehensive / mtlost | "ein Gegenstand, zwei ab fünf" | je Gegenstandsart 1, ab fünf 2; Einzelstück 6/16/11 von 100; Option genannt | S/MT_Containers.lua:133-208 |
| graverobber / mtcorpse | ohne Option | Optionen; Lucky und Scrounger höher, Unlucky und Incomprehensive niedriger | S/MT_Containers.lua:430-443, :729-730 |
| lucky, unlucky / mtluck | "skaliert über Luck Impact" | Luck Impact gilt nur in der Sitzung der Erschaffung, danach 100 % | S/MT.lua:10; S/MT_Creation.lua:293-295 |
| paranoia / mtscare | ohne Stress | jeder Schreck +25 Panik und +10 % Stress | S/MT_State.lua:258-303 |
| depressive / mtmood | "dazu 25 Unzufriedenheit" | hebt um 25, dann senkt die Mod je Bild um 0,01 bis knapp unter 25; kein neuer Wurf während des Schubs; 4 von 100 mit Unlucky und Self-Destructive | S/MT_State.lua:305-351; Tick:37, :132 |
| drinker / mtpoison | 14, "wächst jede Stunde" | 14,6 (Stunde 73 / 5), gesetzt, danach alle 12 bis 23 Stunden neu; nur solange das Verlangen läuft | S/MT_Alcohol.lua:145-197; Tick:127-128 |
| drinker / mtcrave | "nach dem letzten Trinken" | nachdem die Trunkenheit zuletzt unter 10 fiel | S/MT_Alcohol.lua:28-33 |
| bouncer / mtbounce | "6 von 100 je Versuch" | je Bild für jeden Zombie ab dem dritten, danach 60 Bilder Pause | S/MT_State.lua:514-549; Tick:42 |
| gymgoer / mtstiff | "kein anhaltender Muskelkater", Option "No Exercise Fatigue" | wird gelöscht, sobald etwa die Hälfte eingesetzt hat (removeStiffnessValue mit Körperteilnamen statt der Schlüssel arms/legs/chest/abs); Option "Gym Goer Exercise Fatigue", abschalten durch Abwählen | S/MT_XP.lua:143-221; Fitness.java:264-266 |
| ingenuitive / mtrecipes | "jedes Rezept" | jedes Handwerksrezept; nicht die 32 geschweißten Bauten aus Entity-Komponenten; Limit-Optionen genannt | S/MT_Creation.lua:246-282; ScriptManager.java:876, :985-986 |
| quickworker, slowworker / mtaction | "jede Handlung" | beim Umlagern mehrerer Stücke nur das erste; die Fußnoten nennen den Glückswurf in beide Richtungen (11 von 100, mit Lucky und Dextrous sofort); das Lesen seit dem Faktensweep 2 | S/MT.lua:288-343; client/MT/MT_QuickSlowWorker.lua:22-37 |
| expertdriver, poordriver / mtbrake, mtspeed | wie die Motorkraft | eigene Fußnote: Bremskraft bis zum ersten Verschleiß oder Laden, Höchstgeschwindigkeit bis zum Laden | S/MT_World.lua:186-216; BaseVehicle.java:878, :8205 |
| kind range in der Übersicht | ohne Richtung, farblos | TF.Summary.direction behandelt range wie pctrange (beide Enden auf einer Seite der Null) | TF_Summary.lua, direction |

Kleinere Fußnoten nach denselben Lesungen: idealweight "bis 78 kg" (`<=`),
restfulsleeper "ab 60" (`>=`), albino mit Schirm halb so schnell, secondwind
Müdigkeit auf 40 statt null, hardy aus vollem Balken zurückgezahlt, ascetic
verpackte Nahrung sättigt weiter, fearful "über Panik 5", deutsche Texte mit
den deutschen Namen der Mod und des Spiels (Unglücksrabe, Gewandt, Schusslig,
Anmutig, Tollpatschig) und ihren deutschen Optionsnamen.

### Absichtlich nicht als Zeile

Im Kopf des Pakets unter "Was hier absichtlich fehlt", mit Grund: der
Geistermodus von Battering Ram (nur Mehrspieler), die Speed-Modifier und die
Biss-Animation von Unwavering (nach dem ersten Laden weg), die
bildtaktgebundenen Nebenwirkungen von Alcoholic, die Nebenwirkungen der
Fahrer-Traits (Qualität, Offroad je Modell, Tempomat, Lautstärke, die bei
Student Driver sinkt statt steigt) und die mögliche Kette von Made of Glass.
Seit dem Faktensweep 2 dazu: die Nebenwirkung des Mundane-Handlers für alle
Figuren (siehe unten).

## Faktensweep 2, 23.09.2026

Grundlage: `docs/berichte/2026-09-23-faktensweep-2.md` (Pakete fix-mtd und
mtd-coverage). Jeder Fund ist noch einmal gegen den Code der Mod und das
dekompilierte Spiel gelesen; weiter alles aus dem Code, nicht gemessen. Das
Paket hat jetzt 133 Zeilen: dazu kommen zwei an Vanilla-Traits (Tailor,
Smoker), weiter für 93 Traits der Mod.

| Trait / Zeile | bis 0.14.0 | jetzt | Fundstelle |
| --- | --- | --- | --- |
| leadfoot / mtstomp | +140 bis +225 %, "+200 % bei normalen Schuhen" nach Clothing.java:75 | +120 bis +225 %. Clothing.java:75 ist nur der Vorgabewert, Item.java:1616/:1760 setzt den Script-Wert. Normale Schuhe 2,1 (x2,48, +148 %), Sneakers 1,8 (+156 %), BlackBoots und RidingBoots 2,2 (+145 %), schwerste Stiefel 2,5 (+140 %), Antique Boots der Mod 5,0 (x2,2, +120 %), Fußwickel ohne Wert 1,0 (+200 %), Hausschuhe und Flip-Flops 0,8 (+225 %) | S/MT_World.lua:250-259; clothing.txt; ToadTems.txt AntiqueBoots |
| leadfoot / mtstomp | als bleibende Wirkung | Fußnote: einmal je Paar gesetzt, nach dem Laden weg. stompPower steht nicht in Clothing.save (Clothing.java:595-670), das Flag stompState in modData schon, und es verhindert das Neusetzen | S/MT_World.lua:250-259; InventoryItem.java:1551, :1822 |
| terminator / mtjam | "Chance, dass die Waffe klemmt" x0,5 | "Eigener Klemmwert der Waffe" x0,5 mit Fußnote: checkJam rechnet Verschleiß und schwache Hand dazu, die bleiben; Wert 0 klemmt nie; jamGunChance steht nicht in HandWeapon.save, MTstate schon, also nach dem Laden weg | S/MT_Combat.lua:389-396, :441-447; HandWeapon.java:2022-2034 |
| Pro-Traits, Tavern Brawler, Action Hero, Unwavering / Vergleich (rollcompare) | "7 bis 44 % (Waffenskill 0 bis 10), also 2- bis 15-mal" | von vorn bei halber Reichweite 7 bis 29 %, x1,5 von hinten oder der Seite; Entfernungsfaktor 0,3 bis 2; Krit und Angriff auf einen Zombie am Boden nur auf den normalen Treffer. Das "2- bis 15-mal" ist gestrichen (tatsächlich etwa 1- bis 50-mal) | IsoGameCharacter.java:5705, :5765, :5789-5799, :5803-5806; CombatManager.java:830-833, :3195-3214 |
| immunocompromised / mtinfect | "Wurf, wenn ein Treffer eine neue Wunde macht" | nur in der Trefferreaktion bei einem Schadensereignis: Schnitte und Bisse bluten und werden gewürfelt, ein einfacher Kratzer meist nicht (setScratched startet keine Blutung); mit Evasive nie, dessen Schleife nimmt jede neue Wunde zuerst | S/MT_State.lua:104-199; Tick:77-79, :160; BodyPart.java:161-164, :719-744 |
| quickworker, slowworker / mtaction | Lesen nicht erwähnt | beim Lesen mit Fast Reader x0,375 / x1,375, mit Slow Reader x0,625 / x1,625 (Vorgabe 50), auf die schon vom Leser-Trait geänderte Lesezeit | S/MT.lua:308-316; ISReadABook.lua:443-466, :509 |
| mundane / mtcritfix | "ab dem zweiten Treffer" | dazu "nach jedem Laden erneut": criticalChance steht nicht in HandWeapon.save | S/MT_Combat.lua:197-207 |
| unwavering / mtdamage | Stufen 150/200 % nur nach Ausdauer | auch mit Müdigkeit 70/80 % oder Schmerz 50/75 | S/MT_Combat.lua:232-237 |
| base:tailor, base:smoker / mtgear (neu) | fehlte | Tailor bekommt immer ein Nähset (Schere, Nadel, 4 Faden), Smoker eine Zigarettenschachtel und ein Feuerzeug, abschaltbar mit SmokerStart | S/MT_Creation.lua:221-243; SBX:23-27 |

Neu im Kopf des Pakets unter den Nebenwirkungen: der Mundane-Handler
(S/MT_Combat.lua:184-208) läuft bei jedem Treffer jeder Figur, auch ohne
Mundane. Er friert die Kritisch-Chance einer Waffe auf den Wert beim ersten
Treffer ein, bei Klingen samt Schärfe (HandWeapon.java:1136-1141); danach
zählt die Schärfe doppelt, und Gordanites Krit-Zuwachs durch spätere Stufen
(S/MT_Weapons.lua:55-101) geht beim nächsten Treffer verloren.

Offen, im Spiel zu messen: Lead Foot und Terminator nach dem Laden, der
Kratzer bei Immunocompromised, der Mundane-Handler bei stumpfen Klingen
(Messvorschläge im Bericht, Abschnitt "Messen").

## Fundstelle je Zeile

Kampf
- problade, problunt, prospear / mtdamage: S/MT_Combat.lua:61 (Krit verdoppelt :57-59, Waffenklassen :26-49)
- problade, problunt, prospear / mtcrit: S/MT_Combat.lua:24, :33-36, :44, :47, :57
- problade, problunt, prospear / mtrepair: S/MT_Combat.lua:63-67
- progun / mtammo: S/MT_Combat.lua:331-333, :362-368; SBX:270
- progun / mtrepair: S/MT_Combat.lua:348-352
- tavernbrawler / mtdamage: S/MT_Combat.lua:95-115
- tavernbrawler / mtrepair: S/MT_Combat.lua:96, :103, :110-111, :117-123
- actionhero / mtcrowd: S/MT_Combat.lua:146, :151-153, :160-168, :176-181
- actionhero / mtcrit: S/MT_Combat.lua:151, :161, :164, :167, :176
- martial / mtdamage: S/MT_Combat.lua:267-271, :278-295; SBX:90, :205
- martial / mtcrit: S/MT_Combat.lua:272-276, :289
- unwavering / mtdamage: S/MT_Combat.lua:229-238, :244; SBX:200
- mundane / mtcritfix: S/MT_Combat.lua:184-208; IsoPlayer.java:3631, :3672, :3689; CombatManager.java:2754, :2764-2768
- mundane / mtproff: S/MT_Combat.lua:22, :176, :290
- terminator / mtgundmg: S/MT_Combat.lua:445-446; mtrange :443; mtjam :444 (einmal je Waffe, Flag MTstate :389-396, :447; HandWeapon.checkJam :2022-2034); mtaim :442
- terminator / mtpanic: S/MT_Combat.lua:415-417, :429; je Spielminute, Tick:107
- terminator / mtlevels: S/MT_Creation.lua:398-402
- antigun / mtrange: S/MT_Combat.lua:450; mtaim :449; mtmood :419-421, :435; mtxp S/MT_XP.lua:92-94
- batteringram / mtram: S/MT_Combat.lua:486, :496-532, Martial :537-556; SBX:93-97; mtramend :513-514, :534-535
- gordanite / mtcrowbar: S/MT_Weapons.lua:73-103; Auslöser S/MT_Combat.lua:740-748; SBX:85
- amputee / mthands: S/MT_Combat.lua:715-720, :751-762; mtarm :679-694
- burned / mtfire: media/lua/shared/TimedActions/MT_BurnWard.lua:1-15, :101-113; SBX:283
- burned / mtmolotov: S/MT_Combat.lua:710-738 (nur OnEquipPrimary)
- burned / mtinjury: S/MT_Creation.lua:355-364
- leadfoot / mtstomp: S/MT_World.lua:250-259 (einmal je Paar, Flag stompState); StompPower je Schuh in media/scripts/generated/items/clothing.txt, Antique Boots media/scripts/ToadTems.txt (StompPower 5.0), Fund S/MT_Containers.lua:295-313

Bewegung und Tragen
- fast / mtmove: S/MT_World.lua:138-145, :173-175; SBX:304/309/314
- gimp / mtmove: S/MT_World.lua:146-153, :169-171; SBX:319/324/329
- packmule / mtcarry: S/MT_Weight.lua:7, :13; SBX:160
- packmouse / mtcarry: S/MT_Weight.lua:9, :13; SBX:165
- fitted / mtclothw: S/MT_World.lua:308-311; mtcloths :294-307

Gesundheit
- evasive / mtdodge: S/MT_State.lua:116-119; SBX:100
- anemic / mtbleed: S/MT_State.lua:636-641, :659
- thickblood / mtbleed: S/MT_State.lua:642-647, :671
- idealweight / mtcal: S/MT_Nutrition.lua:254-261
- superimmune / mtfever: S/MT_SuperImmune.lua:31-52; SBX:240/245
- immunocompromised / mtinfect: S/MT_State.lua:175-199 (nur in PlayerHitReactionState, aus OnPlayerGetDamage, Tick:77-79, :160; Evasive davor :104-172); SBX:265; mtwound :688, :696-702
- glassbody / mtglass: S/MT_State.lua:34-56
- selfdestructive / mtharm: S/MT_State.lua:362-366, :374
- badteeth / mteat: media/lua/server/MT_EatFood.lua:25-26; zweite Quelle S/MT_State.lua:420-456, Tick:43
- hardy / mtreserve: S/MT_State.lua:472-475, :480-495; S/MT.lua:32-33; SBX:235
- secondwind / mtwind: S/MT_Rest.lua:12, :21, :30-33, :50; Aufladen :57-72; SBX:230
- indefatigable / mtlast: S/MT_Indefatigable.lua:9, :15-17, :27-35, :46-55, :61-76, :84-86; Aufladen :89-116 (x2 nach geheilter Infektion, x2 nach Zu-Boden-Ziehen, :96-104); SBX:75/80
- quickrest / mtrest: S/MT_Rest.lua:161, :164, :168
- restfulsleeper / mtsleep: S/MT_Rest.lua:90-96; Aufwachen :114-115
- albino / mtsun: S/MT_World.lua:74-81, :42, :51
- injured / mtinjury: S/MT_Creation.lua:306-342; SBX:15
- broke / mtinjury: S/MT_Creation.lua:344-353

Essen
- gourmand / mtcook: S/MT_Nutrition.lua:65-68; mtfood :71-120; mtfresh S/MT_Containers.lua:767, :786-787
- ascetic / mtcook: S/MT_Nutrition.lua:142-145; mtfood :152-212

Fundglück
- scrounger / mtloot: S/MT_Containers.lua:8-12, :34, :62-71; SBX:135/140
- incomprehensive / mtlost: S/MT_Containers.lua:133-135, :148, :167-186; SBX:145
- vagabond / mtbin: S/MT_Containers.lua:331-332, :347-352, :388; SBX:150/155
- antique / mtantique: S/MT_Containers.lua:225-226, :290-294; SBX:210/215
- graverobber / mtcorpse: S/MT_Containers.lua:430-443, :729-730; SBX:120/125
- lucky, unlucky / mtluck: S/MT.lua:158-165; S/MT_Creation.lua:293-295; SBX:30

Psyche
- paranoia / mtscare: S/MT_State.lua:263-276, :283-284, :301
- depressive / mtmood: S/MT_State.lua:305-351; Tick:37, :132
- fearful / mtscream: S/MT_State.lua:578-605
- drinker / mtcrave: S/MT_Alcohol.lua:109-136; SBX:35; mtpoison :154-191; SBX:40; mtgear S/MT_Creation.lua:217-219; SBX:20

Lernen
- specweapons, specfood, specguns, specmove, speccrafting, specaid / mtxp: S/MT_XP.lua:5-42, :61-66, :86-89, :97; SBX:45
- gymgoer / mtxp: S/MT_XP.lua:125-138; SBX:65; mtstiff :144-222; SBX:70
- noxpshooter / mtlevels: S/MT_Creation.lua:371-373; noxptechnician :375-378; noxpfirstaid :380-382; noxpaxe :384-387; noxpmaintenance :389-391; noxpsneaky :393-396

An den Bildtakt gebunden
- noodlelegs / mttrip, mttripsprint, mttripskill: S/MT_Combat.lua:596-623
- butterfingers / mtdrop: S/MT_State.lua:216-256 (je Spielminute, Tick:100); SBX:115
- bouncer / mtbounce: S/MT_State.lua:515-551; SBX:50/55/60
- blissful / mtbliss: S/MT_State.lua:384-418

Nur Boosts
- bladetwirl DEF:99-107; blunttwirl DEF:121-129; flexible DEF:259-267; grunt DEF:338-346; olympian DEF:576-584; quiet DEF:799-807; swift DEF:961-969; tinkerer DEF:1004-1012. Keiner davon kommt im Lua der Mod vor.
- scrapper / mtboosts, mtrecipes: DEF:822-831, keine GrantedRecipes, kein Lua-Verweis; die Beschreibung verspricht Rezepte
- wildsman / mtrecipes: DEF:1047-1056

Handwerk und Start
- ingenuitive / mtrecipes: S/MT_Creation.lua:246-282, :366-369; Tick:135-138
- quickworker / mtaction: S/MT.lua:288-343, Lesen :308-316; media/lua/client/MT/MT_QuickSlowWorker.lua:9-20; der Patch auf ISInventoryTransferAction:new (:22-37) erreicht zusammengelegte Stücke nicht; SBX:180
- slowworker / mtaction: S/MT.lua:305, Lesen :308-316, :337-339; SBX:185
- preparedfood / mtgear: S/MT_Creation.lua:21-41; preparedammo :42-63; preparedweapon :64-68; preparedmedical :69-97; preparedrepair :98-115; preparedcamp :116-144; preparedpack :145-149; preparedcar :150-177; preparedcoordination :178-215
- deprived / mtbare: S/MT_Creation.lua:11-19; SBX:220
- base:tailor / mtgear: S/MT_Creation.lua:221-236 (ohne Option)
- base:smoker / mtgear: S/MT_Creation.lua:238-243; SBX:23-27 (SmokerStart, Vorgabe an)

Fahrzeuge
- expertdriver / mtengine: S/MT_World.lua:202; mtspeed :203; mtbrake :201
- poordriver / mtengine: S/MT_World.lua:211; mtspeed :212; mtbrake :210
- Beides gilt nur am Steuer (:183) und nicht mit der Mod Driving Skill (:179). Einmal je Auto gesetzt (sState, :200-216): die Bremskraft setzt BaseVehicle.updatePartStats (:8205) zurück, die Höchstgeschwindigkeit createPhysics (:878).

## Traits ohne eigene Zeile

Die Mod meldet 99 Traits an, 96 davon mit Definition. Drei haben keine eigene
Zeile und lesen ihre Werte live aus dem Spiel: Gun Specialist (DEF:349-359,
XP-Boosts; Sammeln media/lua/shared/Foraging/MT_ForageDefinitions.lua:118-128),
Natural (DEF:489-498, XP-Boosts; Sammeln ebenda :73-86) und Generator
(DEF:271-281, nur ein Rezept). Ohne Definition und darum nicht wählbar: brooding, heavydrinker,
lightdrinker.

Die beiden Untermods auf demselben Workshop-Eintrag,
`moreTraitsDefinitive_DisablePrepared` und `_DisableSpecialization`, bringen
keinen eigenen Code. Die Mod selbst entfernt mit ihnen beim Spielstart die 9
Prepared- und die 6 Specialization-Traits aus der Registry
(`client/CharacterCreation/MT_HideTraits.lua:16-26`, `:31-58`, OnGameBoot
`:72`); mit beiden gibt es 81 Traits. Trait Facts zeigt Zeilen nur zu Traits,
die in der Registry stehen (TF.Mods.entriesFor je traitDef), die entfernten
tauchen also nirgends auf. Dieselbe Datei entfernt Expert Driver mit dem Mod
Driving Skill und Scrounger mit ScavengingSkill (Faktensweep 2, 23.09.2026,
mtd-coverage).
