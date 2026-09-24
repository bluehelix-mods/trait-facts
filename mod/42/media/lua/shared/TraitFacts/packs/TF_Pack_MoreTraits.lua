--- Trait Facts - Datenpaket fuer More Traits Definitive (Workshop 3799050151).
--
-- Angemeldet ueber dieselbe oeffentliche Schnittstelle, die auch ein fremder
-- Mod-Autor benutzt (docs/api.md). modId sorgt dafuer, dass das Paket nur
-- gelesen wird, solange More Traits Definitive laeuft; sonst kostet es nichts.
-- Arbeitsweg und Regeln: docs/datenpakete.md.
--
-- Fundstellen je Zeile (Datei und Zeile im Code der Mod) und das Ergebnis der
-- Nachpruefung vom 21.09.2026: docs/quellen/more-traits-fundstellen.md. Acht Zeilen
-- waren falsch und sind seit 0.13.7 berichtigt: die Kritisch-Chance der drei
-- Pro-Traits (6 statt 5, ZombRand(0,101) <= 5), Quick Rest (je Spielminute, nicht je
-- Stunde), die Motorkraft der beiden Fahrer-Traits (x6 und x0.5), und die Fussnoten
-- zu Second Wind (laedt in dieser Fassung nie wieder auf) und Indefatigable (laedt
-- auch mit One Use wieder auf). More Traits wurde am 17. und 18.09.2026 aktualisiert,
-- ohne dass sich MTModVersion aenderte; die Versionsangabe taugt nicht als Warnung.
--
-- Faktensweep 23.09.2026 (docs/berichte/2026-09-23-faktensweep.md): der
-- Zusatzschaden der Kampf-Traits ist kein Prozent auf den Nahkampfschaden,
-- sondern ein Anteil am Schadenswurf, den OnWeaponHitCharacter vor allen
-- Multiplikatoren des Spiels uebergibt (IsoGameCharacter.java:5705 gegen
-- processHitDamage :5758ff und hitConsequences :5817); MT.KillZombie zieht ihn
-- direkt mit setHealth ab (MT.lua:271-276). Ein normaler Nahkampftreffer nimmt
-- modDelta x 1.5 x (0.3 + 0.1 x Stufe) x 0.15 dieses Wurfs, x1.5 von hinten
-- oder der Seite (IsoGameCharacter.java:5789-5799); bei halber Reichweite von
-- vorn (modDelta 1) 7 bis 27 % (Aexte 29 %), insgesamt 2 bis 81 % (Aexte
-- 88 %; Entfernungsfaktor 0.3 bis 2, CombatManager.java:830-833). Bis 0.14.0
-- stand hier "7 bis 44 %", und die Fussnote schrieb die ganze Spanne dem
-- Waffenskill zu (Faktensweep 2, 23.09.2026). Bis 0.14.1 "7 bis 29 %" fuer
-- alle Waffen: getWeaponLevel setzt nur bei der Axt die Stufe gleich dem
-- Skill, jede andere Kategorie beginnt bei -1 und addiert den Skill, Skill 10
-- ist dort Stufe 9 (IsoGameCharacter.java:10123-10150; Faktensweep 3,
-- 23.09.2026). Schusswaffen: kein x0.15 (nur Nahkampf, CombatManager.java:
-- 3195-3199), modDelta fest 1 (Schrotflinten mit RangeFalloff 2, :831-833),
-- Waffenstufe 0, weil sie keine Nahkampf-Kategorie haben; ein normaler Schuss
-- nimmt also 1.5 x 0.3 = 45 % des Wurfs von vorn, x1.5 von hinten. Das steht
-- in den Fussnoten von Unwavering und Action Hero, den beiden Zeilen, die
-- Schusswaffen einschliessen (Faktensweep 3, 23.09.2026).
-- Eigene Zeile "Zusatzschaden je Treffer" mit Einheit "% des Schadenswurfs"
-- und dem Vergleich als condition. Dazu: die Krit-Wuerfe der Mod sind eigene
-- Wuerfe auf ihren Zusatzschaden, Mundane laesst dem Spiel mindestens 10 von
-- 100, Action Hero hat keine Obergrenze, Lead Foot ist x2.4 bis x3.25, Pack
-- Mule und Pack Mouse aendern die Basis, die Staerke vervielfacht, und rund
-- dreissig Fussnoten waren ungenau. Einzelheiten je Zeile in der Fundstellen-
-- Datei, Abschnitt "Faktensweep 23.09.2026".
--
-- Herkunft der Zahlen: Lesung des Lua-Codes der Mod am 16. und 19.09.2026,
-- Fassung 42.20 (MTModVersion in MT.lua). Kein version-Feld: die mod.info von
-- More Traits Definitive fuehrt kein modversion, ein Abgleich ueber
-- getModVersion wuerde jede Zeile grundlos als veraltet faerben.
--
-- Was hier absichtlich fehlt:
-- * Kosten, Ausschluesse, gewaehrte Traits, XP-Boosts, freie Rezepte und
--   seit 0.7.0 auch das Sammeln (Radius, Kategorien, Wetter, Dunkelheit).
--   Das liest Trait Facts im Spiel live aus der Engine; doppelt hinterlegt
--   waere es eine zweite Wahrheit, die veraltet, und in der Uebersicht fiel
--   die Abschrift nicht mit den Vanilla-Werten zusammen (Befund 19.09.2026).
-- * Wie oft etwas passiert, das am Bildtakt haengt (Noodle Legs, Blissful,
--   Bouncer: sie wuerfeln in OnPlayerUpdate; Butterfingers wuerfelt je
--   Spielminute, MT_Tick.lua:100). Ohne belegte
--   Bildrate waere jede Angabe je Sekunde geraten. Seit 0.12.9 stehen diese
--   vier trotzdem da, mit dem, was nicht an der Bildrate haengt: was passiert,
--   wann, und die Verhaeltnisse (Sprinten gegen Rennen, Stufe 10 gegen 0).
-- * Burn Ward Patient in Feuernaehe: der Code setzt Panik auf hoechstens 1,0,
--   statt sie zu erhoehen (MT_Weapons.lua:43). Bis das im Spiel geprueft ist,
--   steht hier keine Wirkung.
-- * Amputee und die Zombie-Infektion: der Code loescht jede neue Infektion,
--   nicht nur am amputierten Arm (MT_Combat.lua:696), aber nur einmal.
--   Gemessen am 24.09.2026 (docs/messungen/messung-2026-09-24-moretraits.txt):
--   nach MT.Combat.Amputee ist die Figur nicht mehr infiziert, der Hals aber
--   schon (ClearInfection setzt nur BodyDamage, MT.lua:152-156), und das
--   naechste BodyDamage.Update setzt die Infektion wieder
--   (BodyDamage.java:1857-1871). MT_Tick.lua:18-25 hat bWasInfected dann
--   schon gesetzt und meldet keine neue Infektion mehr: der Schutz schiebt
--   die Infektion um weniger als 31 Ticks hinaus, er verhindert sie nicht.
--   Darum weiter keine Zeile.
-- * Was im Code steht, aber nie greift: die Ausdauer- und Stresswerte von
--   Gourmand (tote Variablen), SuperImmuneFirstInfectionBonus und
--   QuickSuperImmune (nie geschrieben), die Scrounger-Hervorhebung.
-- * Battering Ram, Geistermodus beim Sprinten (MT_Combat.lua:486-490, :571
--   setGhostMode): das setzt die Cheat-Flagge INVISIBLE, und PlayerCheats
--   nimmt sie nur im Mehrspieler oder mit -debug an (isCheatAllowed). Im
--   Einzelspieler wirkt es nicht; im Mehrspieler verlieren Zombies dich als
--   Ziel, und andere Spieler sehen dich nicht. Das Paket beschreibt das
--   Einzelspiel (Faktensweep 23.09.2026). Keine eigene Zeile, aber seit dem
--   Faktensweep 3 (23.09.2026) sagt die Fussnote der Ram-Zeile es, ebenso
--   die Fussnoten von Indefatigable (Schwelle 25 im Mehrspieler, kein
--   Zu-Boden-Ziehen, MT_Indefatigable.lua:15, :17, :37) und Restful Sleeper
--   (condition mpsleep: auf Servern schlaeft standardmaessig niemand).
-- * Unwavering, Verletzungen bremsen weniger (MT_Combat.lua:633-667: +30/+30/
--   +60/+60 auf die Speed-Modifier je Koerperteil): BodyDamage speichert die
--   Modifier nicht, das Flag in modData bleibt aber gesetzt, also ist es nach
--   dem ersten Laden weg. Dazu eine eigene Biss-Animation (MT_State.lua:201-208),
--   die keine Zahl hat.
-- * Alcoholic, was am Bildtakt haengt (MT_Alcohol.lua:28-77): ab Trunkenheit 10
--   Wut und Stress je Bild auf 0, betrunken Muedigkeit -0.01 auf 6 von 31
--   Bildern, im Verlangen ab 36 Stunden Schmerz je Bild und Wut und Stress
--   nach oben.
-- * Expert Driver und Student Driver, Nebenwirkungen (MT_World.lua:202-214):
--   Motorqualitaet x2/x0.5, Offroad-Wert x2/x0.5 auf dem Fahrzeug-Script, also
--   fuer jedes Auto dieses Modells, Tempomat x2/x0.66, und die Lautstaerke:
--   setEngineFeature schreibt sie durch einen Setter, der sie jedes Mal mit
--   0.37 multipliziert (VehicleEngine.java:90-93), am Ende x0.09 und x0.56;
--   das Auto von Student Driver wird also leiser, nicht lauter, bis
--   updatePartStats sie vom Auspuff neu setzt. Zu verwickelt fuer eine Zeile,
--   und keine davon zeigt das Spiel selbst als Wert.
-- * Made of Glass, die Kette: der Bezugswert ist der zwischengespeicherte
--   Gesamtwert (getOverallBodyHealth vor calculateOverallHealth), der eigene
--   Zusatzschaden zaehlt beim naechsten Ereignis also wieder als Verlust. Nur
--   aus dem Code gelesen, nicht gemessen; die Fussnote nennt es nicht.
-- * Nebenwirkung fuer alle, auch ohne Mundane: der Mundane-Handler
--   (MT_Combat.lua:184-208) laeuft bei jedem Treffer jeder Figur. Er merkt
--   sich beim ersten Treffer getCriticalChance() der Waffe, bei Klingen also
--   schon mal Schaerfe (HandWeapon.java:1136-1141), und setzt den Grundwert
--   danach bei jeder Abweichung darauf zurueck; die Schaerfe zaehlt dann
--   doppelt (Wert x Schaerfe beim ersten Treffer x Schaerfe jetzt). Eine
--   stumpf zuerst benutzte Klinge behaelt den Abzug auch nach dem Schleifen,
--   nach jedem Laden neu (criticalChance steht nicht in HandWeapon.save).
--   Gordanites Krit-Zuwachs durch spaetere Stufen (MT_Weapons.lua:55-101)
--   setzt derselbe Handler beim naechsten Treffer zurueck. Kein Trait, darum
--   keine Zeile; nur aus dem Code gelesen (Faktensweep 2, 23.09.2026).
--
-- Gym-Goer steht mit dem, was der Code tut (+10 % XP beim Training), nicht
-- mit dem, was die Beschreibung verspricht ("doppelt so wirksam"). Bei
-- Strength sind es +15 % bzw. +7 %: der Bonus geht ueber MT.AddXP
-- (doXPBoost false) noch einmal durch AddXP, und der Protein-Faktor x1.5
-- (Proteine ueber 50 und unter 300) bzw. x0.7 (unter -300) steht dort vor
-- dem doXPBoost-Block (IsoGameCharacter.java:15500-15508), auf einem Betrag,
-- der ihn schon enthaelt (:15622). Faktensweep 3, 23.09.2026. Gemessen am
-- 24.09.2026 (messung-2026-09-24-moretraits.txt): Fitness beim Training
-- x1.10, ohne Training x1.0; Strength mit Proteinen nicht gemessen.
--
-- Sandbox-Optionen: die Werte unten sind die Vorgaben der Mod. Eine Zeile,
-- die sich verstellen laesst, sagt das in ihrer Fussnote. Gerechnet wird
-- nicht: diese Datei laeuft beim Start des Spiels, SandboxVars traegt dort
-- noch nicht zwingend die Einstellungen der gerade gewaehlten Partie.

local rows = {}

-- Kampf ------------------------------------------------------------------
--
-- Die Reparaturchance der vier Pro-Traits traegt je Waffenklasse eine eigene
-- Fussnote: MT_Combat wuerfelt die 33 nur, wenn die Waffe zur Klasse des
-- Traits passt. Mit gemeinsamer Fussnote fielen die Zeilen in einen Eimer,
-- und die Uebersicht zeigte 68, 102 oder 136 "von 100" (Audit 20.09.2026).
--
-- Zusatzschaden (Faktensweep 23.09.2026): bis 0.13.9 standen die Pro-Traits,
-- Tavern Brawler, Martial und Unwavering als "Nahkampfschaden +12 %" auf der
-- Vanilla-Zeile, die Puny und Weak als echten Faktor fuehren; die Uebersicht
-- haette 1.12 mit deren Faktor multipliziert. Tatsaechlich zieht die Mod
-- x % des Schadenswurfs aus OnWeaponHitCharacter direkt ab, an allen
-- Multiplikatoren des Spiels vorbei (Kopf der Datei). Darum eine eigene
-- Zeile, kind flat (mehrere solche Treffer addieren sich wirklich), Einheit
-- "% des Schadenswurfs", und der Vergleich mit einem normalen Treffer als
-- condition: er erklaert den Wert und schraenkt nichts ein. Martial fehlt
-- dort mit Absicht: ein Schubser im Stehen macht im Spiel gar keinen Schaden
-- (IsoGameCharacter.java:5700-5702 bIgnoreDamage), der Vergleich passt nicht.
--
-- Die Krit-Wuerfe der Mod (MT_Combat.lua:57-61, :176-177, :288-292) setzen nie
-- den kritischen Treffer des Spiels, sie vervielfachen nur den eigenen
-- Zusatzschaden (x2, x5, x4). Eigene Schluessel je Faktor statt der
-- Vanilla-Zeile "Kritische Trefferchance" von Marksman.

local ROLL = "UI_TF_note_mt_rollcompare"

rows["toadtraits:problade"] = {
    -- MT_Combat.lua:6 (nur Zombies), :22 (nicht mit Mundane), :61 damage x 1.2 x 0.1
    { id = "mtdamage", kind = "flat", value = 12, text = "UI_TF_eff_mt_extradamage",
      unit = "UI_TF_unit_mt_ofroll", note = "UI_TF_note_mt_bladeonly", condition = ROLL,
      better = "up", group = "combat" },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_mt_bonuscrit2",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critblade",
      better = "up", group = "combat" },
    { id = "mtrepair", kind = "flat", value = 34, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_repairblade",
      better = "up", group = "combat" },
}

rows["toadtraits:problunt"] = {
    { id = "mtdamage", kind = "flat", value = 12, text = "UI_TF_eff_mt_extradamage",
      unit = "UI_TF_unit_mt_ofroll", note = "UI_TF_note_mt_bluntonly", condition = ROLL },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_mt_bonuscrit2",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critblunt" },
    { id = "mtrepair", kind = "flat", value = 34, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_repairblunt" },
}

rows["toadtraits:prospear"] = {
    { id = "mtdamage", kind = "flat", value = 12, text = "UI_TF_eff_mt_extradamage",
      unit = "UI_TF_unit_mt_ofroll", note = "UI_TF_note_mt_spearonly", condition = ROLL },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_mt_bonuscrit2",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critspear" },
    { id = "mtrepair", kind = "flat", value = 34, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_repairspear" },
}

rows["toadtraits:progun"] = {
    { id = "mtammo",   kind = "flat", value = 11, text = "UI_TF_eff_mt_ammoback",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_ammoback",
      better = "up", group = "combat" },
    { id = "mtrepair", kind = "flat", value = 34, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_repairgun" },
}

rows["toadtraits:tavernbrawler"] = {
    -- MT_Combat.lua:95-115: damage x 1 x 0.1, Mundane schaltet es nicht ab
    { id = "mtdamage", kind = "flat", value = 10, text = "UI_TF_eff_mt_extradamage",
      unit = "UI_TF_unit_mt_ofroll", note = "UI_TF_note_mt_improvised", condition = ROLL },
    { id = "mtrepair", kind = "flat", value = 51, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_improvrepair" },
}

-- Action Hero (MT_Combat.lua:134-182): damage x 0.5 x Multiplikator x 0.1, der
-- Multiplikator beginnt bei 0.1 und waechst je gesehenem Zombie um 1.0 (unter 2
-- Feldern), 0.4 (unter 5) oder 0.2 (unter 10), ohne Obergrenze. Bis 0.13.9 eine
-- Spanne 0.5 bis 25.5, als waere 25.5 das Hoechste; jetzt der Grundwert mit der
-- Staffel in der Fussnote. Kein Nahkampf-Test: gilt auch fuer Schusswaffen.
rows["toadtraits:actionhero"] = {
    { id = "mtcrowd", kind = "flat", value = 0.5, text = "UI_TF_eff_mt_crowdbonus",
      unit = "UI_TF_unit_mt_ofroll", note = "UI_TF_note_mt_crowd", condition = ROLL,
      better = "up", group = "combat" },
    { id = "mtcrit",  kind = "flat", value = 11, text = "UI_TF_eff_mt_bonuscrit5",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critcrowd",
      better = "up", group = "combat" },
}

rows["toadtraits:martial"] = {
    -- MT_Combat.lua:264-295: damage x 0.1 x Ausdauerfaktor x MartialScaling/100
    { id = "mtdamage", kind = "flat", value = 10, text = "UI_TF_eff_mt_extradamage",
      unit = "UI_TF_unit_mt_ofroll", note = "UI_TF_note_mt_barehands" },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_mt_bonuscrit4",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critbare",
      better = "up", group = "combat" },
}

rows["toadtraits:unwavering"] = {
    -- MT_Combat.lua:210-246: damage x 1.25/1.5/2.0 ohne Faktor 0.1, jede Waffe
    { id = "mtdamage", kind = "flat", value = 125, text = "UI_TF_eff_mt_extradamage",
      unit = "UI_TF_unit_mt_ofroll", note = "UI_TF_note_mt_unwavering", condition = ROLL },
}

-- Mundane (MT_Combat.lua:184-208) setzt nur den Grundwert der Waffe auf 1. Das
-- Spiel rechnet darauf 3 je Waffenskill-Stufe und klemmt auf 10 bis 90
-- (IsoPlayer.java:3672, :3689), von hinten kommen 5 dazu (CombatManager.java:
-- 2754), ein Close Kill von hinten ist immer kritisch (:2765-2768). Der Wurf
-- faellt vor OnWeaponHitCharacter, also gilt die 1 erst ab dem zweiten
-- Treffer. Dazu schaltet Mundane die drei Pro-Traits ganz ab (:22) und die
-- Krit-Wuerfe von Action Hero und Martial (:176, :290).
rows["toadtraits:mundane"] = {
    { id = "mtcritfix", kind = "info", text = "UI_TF_eff_mt_critfixed",
      note = "UI_TF_note_mt_critfixed", better = "down", group = "combat" },
    { id = "mtproff",   kind = "info", text = "UI_TF_eff_mt_mundaneoff",
      note = "UI_TF_note_mt_mundaneoff", better = "down", group = "combat" },
}

-- Terminator und Anti-Gun aendern MaxRange (Trefferreichweite), nicht
-- MaxSightRange, das Eagle Eyed vergroessert (MT_Combat.lua:443, :450 gegen
-- HandWeapon.java:813-817 und :1488-1492). Bis 0.13.9 unter "Visier-Reichweite".
rows["toadtraits:terminator"] = {
    { id = "mtgundmg", kind = "pct",  value = 25,  text = "UI_TF_eff_mt_gundamage",
      note = "UI_TF_note_mt_terminator", better = "up", group = "combat" },
    { id = "mtrange",  kind = "flat", value = 5,   text = "UI_TF_eff_mt_gunrange",
      unit = "UI_TF_unit_tiles", note = "UI_TF_note_mt_terminator",
      better = "up", group = "combat" },
    -- MT_Combat.lua:441-447 halbiert nur jamGunChance, den eigenen Wert der
    -- Waffe. HandWeapon.checkJam (HandWeapon.java:2022-2034) rechnet dazu
    -- 0.5 fuer schwache Hand (Aiming und Strength niedrig) und den Verschleiss;
    -- die bleiben. Eine Waffe mit Wert 0 klemmt nie. jamGunChance steht nicht
    -- in HandWeapon.save, das Flag MTstate in modData schon: nach dem Laden
    -- ist der Wert zurueck, und die Mod setzt ihn fuer diese Waffe nie wieder
    -- (Faktensweep 2, 23.09.2026, nur aus dem Code gelesen).
    { id = "mtjam",    kind = "mult", value = 0.5, text = "UI_TF_eff_mt_jamchance",
      note = "UI_TF_note_mt_jam", better = "down", group = "combat" },
    { id = "mtaim",    kind = "mult", value = 2,   text = "UI_TF_eff_aimdelay" },
    { id = "mtpanic",  kind = "flat", value = -10, text = "UI_TF_eff_mt_aimpanic",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_aimcalm",
      better = "down", group = "mind" },
    { id = "mtlevels", kind = "info", text = "UI_TF_eff_mt_startlevels",
      note = "UI_TF_note_mt_lv_terminator", better = "up", group = "learning" },
}

rows["toadtraits:antigun"] = {
    { id = "mtrange", kind = "flat", value = -5,  text = "UI_TF_eff_mt_gunrange",
      unit = "UI_TF_unit_tiles", note = "UI_TF_note_mt_rangefloor" },
    { id = "mtaim",   kind = "mult", value = 0.8, text = "UI_TF_eff_aimdelay" },
    { id = "mtmood",  kind = "flat", value = 0.6, text = "UI_TF_eff_mt_unhappyaim",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_aiming",
      better = "down", group = "mind" },
    { id = "mtxp",    kind = "pct",  value = -25, text = "UI_TF_eff_xp",
      note = "UI_TF_note_mt_aimxp" },
}

-- Battering Ram: der Geistermodus beim Sprinten hat keine eigene Zeile (Kopf
-- der Datei). Die Fussnote nennt den Zusatzschaden mit Martial (MT_Combat.lua:
-- 537-556) und seit dem Faktensweep 3 (23.09.2026) den Geistermodus im
-- Mehrspieler (:566-585, server/MT_ServerCommands.lua:473-480).
rows["toadtraits:batteringram"] = {
    { id = "mtram",    kind = "info", text = "UI_TF_eff_mt_rammed",
      note = "UI_TF_note_mt_rammartial", better = "up", group = "combat" },
    { id = "mtramend", kind = "range", value = { 1, 10 }, text = "UI_TF_eff_mt_ramendurance",
      unit = "UI_TF_unit_pct", note = "UI_TF_note_mt_ramend",
      better = "down", group = "combat" },
}

rows["toadtraits:gordanite"] = {
    { id = "mtcrowbar", kind = "info", text = "UI_TF_eff_mt_crowbarplus",
      note = "UI_TF_note_mt_crowbar", better = "up", group = "combat" },
}

rows["toadtraits:amputee"] = {
    { id = "mthands", kind = "info", text = "UI_TF_eff_mt_notwohand",
      better = "down", group = "combat" },
    -- MT_Combat.lua:669-694: alle 31 Bilder RestoreToFullHealth, Bisse eingeschlossen
    { id = "mtarm",   kind = "info", text = "UI_TF_eff_mt_armheals",
      note = "UI_TF_note_mt_arm", better = "up", group = "health" },
}

-- Burned: die Option Fire Aversion sperrt nur die Feuer-Aktionen
-- (MT_BurnWard.lua:4, :101-113); das Verbot von Molotow und Flammenfallen in der
-- Haupthand gilt immer (MT_Combat.lua:722-737, nur OnEquipPrimary). Bis 0.13.9 eine Zeile mit der
-- Fussnote, die Option schalte alles ab.
rows["toadtraits:burned"] = {
    { id = "mtfire",   kind = "info", text = "UI_TF_eff_mt_nofire",
      note = "UI_TF_note_mt_firetoggle", better = "down", group = "crafting" },
    { id = "mtmolotov", kind = "info", text = "UI_TF_eff_mt_nomolotov",
      better = "down", group = "combat" },
    { id = "mtinjury", kind = "info", text = "UI_TF_eff_mt_startinjury",
      note = "UI_TF_note_mt_inj_burned", better = "down", group = "health" },
}

-- Lead Foot (MT_World.lua:256): Trittkraft x 2 + 1. Normale Schuhe haben
-- StompPower 2.1 (clothing.txt; Item.java:1760 setzt den Script-Wert,
-- Clothing.java:75 ist nur der Vorgabewert), also x2.48; Turnschuhe 1.8
-- x2.56; BlackBoots und RidingBoots 2.2 x2.45; die schwersten Stiefel 2.5
-- x2.4; die Antique Boots der Mod (ToadTems.txt, StompPower 5.0, Fund fuer
-- Antique Collector) x2.2; die Wickel ohne Wert 1.0 x3; Hausschuhe und
-- Flip-Flops 0.8 x3.25. Bis 0.13.9 stand x2, das bei keinem Schuh gilt; bis
-- 0.14.0 "+200 % bei normalen Schuhen" und +140 als Untergrenze (Faktensweep 2,
-- 23.09.2026).
-- Die Mod setzt den Wert einmal je Paar und merkt sich das in modData
-- (stompState, MT_World.lua:250-259); stompPower steht nicht in
-- Clothing.save, also ist er nach dem Laden zurueck, und das Flag verhindert
-- das Neusetzen. Nur aus dem Code gelesen; die Fussnote sagt es.
rows["toadtraits:leadfoot"] = {
    { id = "mtstomp", kind = "pctrange", value = { 120, 225 }, text = "UI_TF_eff_mt_stomp",
      note = "UI_TF_note_mt_stomp", better = "up", group = "combat" },
}

-- Bewegung und Tragen ----------------------------------------------------

-- Fast und Gimp als pctrange (seit dem Faktensweep 23.09.2026): so tragen
-- beide Enden ihr Vorzeichen, und die Spanne bekommt ihre Farbe.
rows["toadtraits:fast"] = {
    { id = "mtmove", kind = "pctrange", value = { 25, 75 }, text = "UI_TF_eff_mt_movedist",
      note = "UI_TF_note_mt_movedist", better = "up", group = "movement" },
}

rows["toadtraits:gimp"] = {
    { id = "mtmove", kind = "pctrange", value = { -67.5, -22.5 }, text = "UI_TF_eff_mt_movedist",
      note = "UI_TF_note_mt_movedistgimp" },
}

-- Pack Mule und Pack Mouse setzen die Basis (MT_Weight.lua:7, :9, :13, :18),
-- das Spiel multipliziert sie mit dem Staerke-Faktor 0.8 bis 2.5
-- (BodyDamage.java:1779, IsoGameCharacter.java:4372-4405). Bis 0.13.9 stand
-- +2 und -2 auf "Tragekapazitaet", das gilt nur bei Staerke 0 bis 2. Jetzt die
-- wirkliche Aenderung ueber alle Staerke-Stufen: Pack Mule +2 bis +10,
-- Pack Mouse -2 bis -5 (Staerke 5: 17 statt 12 und 9 statt 12).
rows["toadtraits:packmule"] = {
    { id = "mtcarry", kind = "range", value = { 2, 10 }, text = "UI_TF_eff_carry",
      note = "UI_TF_note_mt_carrymule" },
}

rows["toadtraits:packmouse"] = {
    { id = "mtcarry", kind = "range", value = { -5, -2 }, text = "UI_TF_eff_carry",
      note = "UI_TF_note_mt_carrymouse" },
}

-- Fitted (MT_World.lua:262-316) setzt RunSpeedModifier und
-- CombatSpeedModifier getragener Kleidung auf 1.0. Den RunSpeedModifier von
-- Kleidung liest in 42.20.4 nur calcRunSpeedModByClothing
-- (IsoGameCharacter.java:8799-8817), und das ruft niemand auf (auch nicht im
-- Bytecode); updateSpeedModifiers (:9008-9029) setzt runSpeedModifier auf 1.0
-- und senkt ihn nur ohne oder mit kaputten Schuhen. Kleidung bremst also nie
-- die Bewegung, es gibt nichts zu entfernen. Wirklich ist nur der Angriff:
-- CombatSpeedModifier geht ueber updateSpeedModifiers (:9016-9017) in
-- calculateCombatSpeed (:8847). Bis 0.14.1 stand "Bewegung und Angriffe" in
-- der Gruppe Bewegung (Faktensweep 3, 23.09.2026). Nach dem Laden gehen die
-- Werte nicht verloren: onCreatePlayer loescht sState jedes getragenen
-- Stuecks (MT_Creation.lua:414-421), ClothingUpdate setzt sie neu.
rows["toadtraits:fitted"] = {
    { id = "mtclothw", kind = "mult", value = 0.5, text = "UI_TF_eff_mt_clothweight",
      better = "down", group = "movement" },
    { id = "mtcloths", kind = "info", text = "UI_TF_eff_mt_clothspeed",
      note = "UI_TF_note_mt_clothspeed", better = "up", group = "combat" },
}

-- Gesundheit -------------------------------------------------------------

rows["toadtraits:evasive"] = {
    { id = "mtdodge", kind = "flat", value = 33, text = "UI_TF_eff_mt_dodge",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_dodge",
      better = "up", group = "health" },
}

rows["toadtraits:anemic"] = {
    { id = "mtbleed", kind = "flat", value = -24, text = "UI_TF_eff_mt_bleedhealth",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_bleed",
      better = "up", group = "health" },
}

rows["toadtraits:thickblood"] = {
    { id = "mtbleed", kind = "flat", value = 9, text = "UI_TF_eff_mt_bleedhealth",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_bleed" },
}

rows["toadtraits:idealweight"] = {
    { id = "mtcal", kind = "pct", value = 50, text = "UI_TF_eff_mt_caloriegain",
      note = "UI_TF_note_mt_calories", better = "open", group = "food" },
}

-- better "open": seit dem Faktensweep 23.09.2026 faerbt die Uebersicht auch
-- kind range. Mit "down" stuenden die Fiebertage rot, obwohl sie an die Stelle
-- der Zombifizierung treten; gut oder schlecht ist hier keine Frage der Zahl.
rows["toadtraits:superimmune"] = {
    { id = "mtfever", kind = "range", value = { 10, 30 }, text = "UI_TF_eff_mt_feverdays",
      unit = "UI_TF_unit_days", note = "UI_TF_note_mt_fever",
      better = "open", group = "health" },
}

rows["toadtraits:immunocompromised"] = {
    { id = "mtinfect", kind = "flat", value = 25, text = "UI_TF_eff_mt_infectwound",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_immuno",
      better = "down", group = "health" },
    { id = "mtwound",  kind = "flat", value = 3, text = "UI_TF_eff_mt_woundinfect",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_woundinfect",
      better = "down", group = "health" },
}

rows["toadtraits:glassbody"] = {
    { id = "mtglass", kind = "flat", value = 34, text = "UI_TF_eff_mt_glassbreak",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_glass",
      better = "down", group = "health" },
}

rows["toadtraits:selfdestructive"] = {
    { id = "mtharm", kind = "flat", value = -9, text = "UI_TF_eff_mt_selfharm",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_selfharm",
      better = "up", group = "health" },
}

rows["toadtraits:badteeth"] = {
    { id = "mteat", kind = "flat", value = 25, text = "UI_TF_eff_mt_eatpain",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_eatpain",
      better = "down", group = "health" },
}

rows["toadtraits:hardy"] = {
    { id = "mtreserve", kind = "pct", value = 25, text = "UI_TF_eff_mt_endreserve",
      note = "UI_TF_note_mt_hardy", better = "up", group = "health" },
}

rows["toadtraits:secondwind"] = {
    { id = "mtwind", kind = "info", text = "UI_TF_eff_mt_secondwind",
      note = "UI_TF_note_mt_secondwind", better = "up", group = "health" },
}

rows["toadtraits:indefatigable"] = {
    { id = "mtlast", kind = "info", text = "UI_TF_eff_mt_lastwind",
      note = "UI_TF_note_mt_lastwind", better = "up", group = "health" },
}

rows["toadtraits:quickrest"] = {
    -- MT_Rest.lua:161-168: 0.055 am Boden, 0.12 auf Moebeln, auf dem Balken von 0 bis 1,
    -- in EveryOneMinute, mal (1 - Muedigkeit x 0.8). Bis 0.13.6 stand hier 3.3 bis 7.2 je
    -- Spielstunde: 0.055 x 60 ohne die Umrechnung auf Prozent, also um den Faktor 100 zu klein.
    { id = "mtrest", kind = "range", value = { 5.5, 12 }, text = "UI_TF_eff_mt_restendurance",
      unit = "UI_TF_unit_pct", note = "UI_TF_note_mt_quickrest",
      better = "up", group = "health" },
}

-- Nur im Schlaf (MT_Rest.lua:78 isAsleep). Auf einem Server schlaeft
-- standardmaessig niemand: SleepAllowed und SleepNeeded sind aus
-- (ServerOptions.java:107-108), calculateStats setzt die Muedigkeit dort auf
-- 0 (IsoGameCharacter.java:9100-9102). Dieselbe condition wie die
-- Schlafzeilen von Night Owl und Hard of Hearing (Faktensweep 3, 23.09.2026).
rows["toadtraits:restfulsleeper"] = {
    { id = "mtsleep", kind = "range", value = { 5, 20 }, text = "UI_TF_eff_mt_sleepfatigue",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_sleepfat",
      condition = "UI_TF_note_mpsleep", better = "up", group = "sleep" },
}

rows["toadtraits:albino"] = {
    { id = "mtsun", kind = "flat", value = 40, text = "UI_TF_eff_mt_sunpain",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_sun",
      better = "down", group = "health" },
}

rows["toadtraits:injured"] = {
    { id = "mtinjury", kind = "info", text = "UI_TF_eff_mt_startinjury",
      note = "UI_TF_note_mt_inj_injured" },
}

rows["toadtraits:broke"] = {
    { id = "mtinjury", kind = "info", text = "UI_TF_eff_mt_startinjury",
      note = "UI_TF_note_mt_inj_broke" },
}

-- Nahrung ----------------------------------------------------------------

rows["toadtraits:gourmand"] = {
    { id = "mtcook",  kind = "mult", value = 0.5, text = "UI_TF_eff_mt_cooktime",
      note = "UI_TF_note_mt_gourmandcook", better = "down", group = "food" },
    { id = "mtfood",  kind = "mult", value = 1.5, text = "UI_TF_eff_mt_foodhunger",
      note = "UI_TF_note_mt_gourmandfood", better = "up", group = "food" },
    { id = "mtfresh", kind = "flat", value = 33, text = "UI_TF_eff_mt_freshfind",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_fresh",
      better = "up", group = "food" },
}

rows["toadtraits:ascetic"] = {
    { id = "mtcook", kind = "mult", value = 1.5,  text = "UI_TF_eff_mt_cooktime",
      note = "UI_TF_note_mt_asceticcook" },
    { id = "mtfood", kind = "mult", value = 0.75, text = "UI_TF_eff_mt_foodhunger",
      note = "UI_TF_note_mt_asceticfood" },
}

-- Fundglueck -------------------------------------------------------------

rows["toadtraits:scrounger"] = {
    { id = "mtloot", kind = "flat", value = 11, text = "UI_TF_eff_mt_extraloot",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_scrounge",
      better = "up", group = "crafting" },
}

rows["toadtraits:incomprehensive"] = {
    { id = "mtlost", kind = "flat", value = 11, text = "UI_TF_eff_mt_lostloot",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_lost",
      better = "down", group = "crafting" },
}

rows["toadtraits:vagabond"] = {
    { id = "mtbin", kind = "flat", value = 34, text = "UI_TF_eff_mt_binloot",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_bin",
      better = "up", group = "foraging" },
}

rows["toadtraits:antique"] = {
    { id = "mtantique", kind = "flat", value = 0.73, text = "UI_TF_eff_mt_antiquefind",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_antique",
      better = "up", group = "crafting" },
}

rows["toadtraits:graverobber"] = {
    { id = "mtcorpse", kind = "flat", value = 1.1, text = "UI_TF_eff_mt_corpseloot",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_corpse",
      better = "up", group = "crafting" },
}

rows["toadtraits:lucky"] = {
    { id = "mtluck", kind = "info", text = "UI_TF_eff_mt_luckgood",
      note = "UI_TF_note_mt_luck", better = "up", group = "mind" },
}

rows["toadtraits:unlucky"] = {
    { id = "mtluck", kind = "info", text = "UI_TF_eff_mt_luckbad",
      note = "UI_TF_note_mt_luck", better = "down", group = "mind" },
}

-- Kopf -------------------------------------------------------------------

rows["toadtraits:paranoia"] = {
    { id = "mtscare", kind = "flat", value = 1, text = "UI_TF_eff_mt_scare",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_scare",
      better = "down", group = "mind" },
}

rows["toadtraits:depressive"] = {
    { id = "mtmood", kind = "flat", value = 2, text = "UI_TF_eff_mt_lowmood",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_lowmood",
      better = "down", group = "mind" },
}

rows["toadtraits:fearful"] = {
    { id = "mtscream", kind = "info", text = "UI_TF_eff_mt_scream",
      note = "UI_TF_note_mt_scream", better = "down", group = "mind" },
}

-- Alcoholic, Gift (MT_Alcohol.lua:154-191): gesetzt, nicht addiert, auf Stunden
-- ohne Drink / 5; fruehestens bei Stunde 73 (EveryHours zaehlt erst hoch,
-- MT_Tick.lua:127-128), also 14.6, danach alle 12 bis 23 Stunden neu. Bis
-- 0.13.9 stand 14 (Faktensweep 23.09.2026).
rows["toadtraits:drinker"] = {
    { id = "mtcrave",  kind = "flat", value = 7,  text = "UI_TF_eff_mt_drinkneed",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_drink",
      better = "down", group = "mind" },
    { id = "mtpoison", kind = "flat", value = 14.6, text = "UI_TF_eff_poison",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_poison" },
    { id = "mtgear",   kind = "info", text = "UI_TF_eff_mt_startgear",
      note = "UI_TF_note_mt_gear_drinker", better = "up", group = "crafting" },
}

-- Lernen -----------------------------------------------------------------
-- Die Spezialisierungen kuerzen XP auf allen Skills ausserhalb ihrer Liste
-- (MT_XP.lua:44-104, SPEC_PERKS in Zeile 5). Die Boosts selbst liest Trait
-- Facts live, sie stehen unter den Startskills.
--
-- Specialization: Food hat eine eigene Fussnote (Faktensweep 3, 23.09.2026):
-- ihre Liste nennt an sechster Stelle Perks.Foraging (MT_XP.lua:21). Das
-- gibt es in 42.20 nicht, der Skill heisst PlantScavenging (PerkFactory.java:
-- 95, :320); Perks ist eine Kahlua-Tabelle (CustomPerks.java:63), der
-- Eintrag also nil, und ipairs (MT_XP.lua:74) bricht dort ab. Tracking,
-- Husbandry und Butchering, die der Trait selbst mit +4 boostet
-- (ToadTraits.txt:910), verlieren darum auch 75 %. Gemessen am 24.09.2026
-- (messung-2026-09-24-moretraits.txt, Perks.Foraging = nil): Tracking,
-- Husbandry und Butchering x0.25, Fishing (fuenfte Stelle) x1.0. Fuer alle
-- sechs Spezialisierungen dort ebenso: Skills ausserhalb x0.25, eigene x1.0.
local SPEC_NOTE = { specfood = "UI_TF_note_mt_specxp_food" }
for _, key in ipairs({ "specweapons", "specfood", "specguns", "specmove",
                       "speccrafting", "specaid" }) do
    rows["toadtraits:" .. key] = {
        { id = "mtxp", kind = "pct", value = -75, text = "UI_TF_eff_xp",
          note = SPEC_NOTE[key] or "UI_TF_note_mt_specxp" },
    }
end

rows["toadtraits:gymgoer"] = {
    { id = "mtxp",    kind = "pct",  value = 10, text = "UI_TF_eff_xp",
      note = "UI_TF_note_mt_gym" },
    { id = "mtstiff", kind = "info", text = "UI_TF_eff_mt_nostiff",
      note = "UI_TF_note_mt_nostiff", better = "up", group = "health" },
}

-- Startstufen setzt die Mod per Lua beim Spielstart (MT_Creation.lua:371-402),
-- an der Engine vorbei; die Startskill-Liste zeigt sie deshalb nicht.
local LEVELS = {
    noxpshooter = "UI_TF_note_mt_lv_shooter",
    noxptechnician = "UI_TF_note_mt_lv_technician",
    noxpfirstaid = "UI_TF_note_mt_lv_firstaid",
    noxpaxe = "UI_TF_note_mt_lv_axe",
    noxpmaintenance = "UI_TF_note_mt_lv_maintenance",
    noxpsneaky = "UI_TF_note_mt_lv_sneaky",
}
for key, note in pairs(LEVELS) do
    rows["toadtraits:" .. key] = {
        { id = "mtlevels", kind = "info", text = "UI_TF_eff_mt_startlevels", note = note },
    }
end

-- Am Bildtakt (seit 0.12.9, siehe Kopf). Gelesen am 20.09.2026.
--
-- Noodle Legs (MT_Combat.lua:587-631): nur beim Rennen und Sprinten, Wurf
-- ZombRand(0, N) <= 100 mit N = 500001 + 12500 x (Nimble + Sprinting); beim
-- Sprinten N x 0.6, also 1/0.6 = 1.67-mal so oft; mit beiden Skills auf 10
-- N = 750001, also 0.67-mal so oft. Graceful N x 1.2, Clumsy N x 0.8.
-- Die Skill-Zeile vergleicht den Trait mit sich selbst (Stufe 10 gegen 0),
-- nicht mit "ohne Trait", und ohne Trait stolpert niemand. Bis 0.14.1 teilte
-- sie den Text mit der Sprint-Zeile und erbte deren "down": ein gruenes
-- -33 % an einem Trait, der -6 kostet. Darum eigener Text mit "open"; BETTER
-- haengt am Text, ein Feld je Zeile reichte nicht (Faktensweep 3, 23.09.2026).
-- Mit Luck Impact 0 stolpert eine Figur mit Lucky oder Unlucky bei jedem Bild
-- (tripChance x 0, ZombRand(0, 0) ist 0), bis zum naechsten Laden; nur in der
-- Fundstellen-Datei, keine Zeile.
rows["toadtraits:noodlelegs"] = {
    { id = "mttrip", kind = "info", text = "UI_TF_eff_mt_trip",
      note = "UI_TF_note_mt_framerate", better = "down", group = "movement" },
    { id = "mttripsprint", kind = "mult", value = 1.67, text = "UI_TF_eff_mt_tripchance",
      note = "UI_TF_note_mt_tripsprint", better = "down", group = "movement" },
    { id = "mttripskill", kind = "mult", value = 0.67, text = "UI_TF_eff_mt_tripchanceskill",
      note = "UI_TF_note_mt_tripskill", better = "open", group = "movement" },
}

-- Butterfingers (MT_State.lua:217-255): nur in Bewegung; Grundwert 3, dazu 1 je
-- 5 Gewicht, 5 beim Rennen, 10 beim Sprinten, gegen ZombRand(2000), Sandbox
-- ButterfingersChance. Dextrous und Pack Mule -1, All Thumbs und Pack Mouse +1.
rows["toadtraits:butterfingers"] = {
    { id = "mtdrop", kind = "info", text = "UI_TF_eff_mt_drop",
      note = "UI_TF_note_mt_drop", better = "down", group = "combat" },
}

-- Bouncer (MT_State.lua:515-551): erst ab dem dritten Zombie innerhalb von
-- 1.75 Feldern, und nur dieser eine taumelt (setStaggerBack, dann break); die
-- Beschreibung nennt zwei und "sie". 6 von 101 je Bild und Zombie ab dem
-- dritten, danach 60 Bilder Pause; alle drei Werte sind Sandbox-Optionen.
-- Bei 60 Bildern je Sekunde trifft der Wurf fast immer binnen einer Sekunde
-- (1 - 0.94^60 = 97 %); die Fussnote sagt darum "je Bild", ohne Zahl je Sekunde.
rows["toadtraits:bouncer"] = {
    { id = "mtbounce", kind = "info", text = "UI_TF_eff_mt_bounce",
      note = "UI_TF_note_mt_bounce", better = "up", group = "combat" },
}

-- Blissful (MT_State.lua:384-420): je Bild Unglueck -0.01 (solange ueber 0.05)
-- und Langeweile -0.005 (solange ueber 0.02).
rows["toadtraits:blissful"] = {
    { id = "mtbliss", kind = "info", text = "UI_TF_eff_mt_bliss",
      note = "UI_TF_note_mt_framerate", better = "up", group = "mind" },
}

-- Traits, deren ganze Wirkung die Boosts unter den Startskills sind. Ohne
-- Zeile stuenden sie unter "noch ohne Zahlen", obwohl es nichts weiter gibt.
for _, key in ipairs({ "bladetwirl", "blunttwirl", "flexible", "grunt", "olympian",
                       "quiet", "swift", "tinkerer" }) do
    rows["toadtraits:" .. key] = {
        { id = "mtboosts", kind = "info", text = "UI_TF_eff_mt_boostsonly",
          better = "up", group = "learning" },
    }
end

-- Die Beschreibung verspricht Rezepte, die Definition vergibt keine
-- (ToadTraits.txt ohne GrantedRecipes, kein Lua-Bezug). Gegenueber "ohne
-- Trait" verliert die Figur nichts, sie bekommt nur ein Versprechen nicht:
-- "open" statt "down" (bis 0.14.1 das rote Verlustzeichen; Faktensweep 3,
-- 23.09.2026).
rows["toadtraits:scrapper"] = {
    { id = "mtboosts",  kind = "info", text = "UI_TF_eff_mt_boostsonly" },
    { id = "mtrecipes", kind = "info", text = "UI_TF_eff_mt_norecipes",
      better = "open", group = "crafting" },
}

rows["toadtraits:wildsman"] = {
    { id = "mtrecipes", kind = "info", text = "UI_TF_eff_mt_norecipes" },
}

-- Handwerk und Start -----------------------------------------------------

-- Ingenuitive (MT_Creation.lua:246-282) laeuft ueber getAllCraftRecipes, die
-- geschweissten Bauten stecken als CraftRecipe-Komponente in Entities und
-- fehlen dort (ScriptManager.java:985-986 gegen :876). Fussnote seit dem
-- Faktensweep 23.09.2026.
rows["toadtraits:ingenuitive"] = {
    { id = "mtrecipes", kind = "info", text = "UI_TF_eff_mt_allrecipes",
      note = "UI_TF_note_mt_allrecipes", better = "up", group = "crafting" },
}

-- Beim Lesen aendert die Mod den Faktor noch einmal (S/MT.lua:308-316): mit
-- Fast Reader x1.25 (Quick Worker) bzw. x0.75 (Slow Worker), mit Slow Reader
-- umgekehrt. Bei der Vorgabe 50 also x0.375 / x0.625 und x1.375 / x1.625,
-- auf die Lesezeit, die der Leser-Trait schon geaendert hat
-- (ISReadABook.lua:443-466 getDuration, :509). Steht in den
-- Fussnoten (Faktensweep 2, 23.09.2026).
rows["toadtraits:quickworker"] = {
    { id = "mtaction", kind = "mult", value = 0.5, text = "UI_TF_eff_mt_actiontime",
      note = "UI_TF_note_mt_worker", better = "down", group = "crafting" },
}

rows["toadtraits:slowworker"] = {
    { id = "mtaction", kind = "mult", value = 1.5, text = "UI_TF_eff_mt_actiontime",
      note = "UI_TF_note_mt_workerslow" },
}

-- Startausruestung (MT_Creation.lua:5-244).
local GEAR = {
    preparedfood = "UI_TF_note_mt_gear_food",
    preparedammo = "UI_TF_note_mt_gear_ammo",
    preparedweapon = "UI_TF_note_mt_gear_weapon",
    preparedmedical = "UI_TF_note_mt_gear_medical",
    preparedrepair = "UI_TF_note_mt_gear_repair",
    preparedcamp = "UI_TF_note_mt_gear_camp",
    preparedpack = "UI_TF_note_mt_gear_pack",
    preparedcar = "UI_TF_note_mt_gear_car",
    preparedcoordination = "UI_TF_note_mt_gear_maps",
}
for key, note in pairs(GEAR) do
    rows["toadtraits:" .. key] = {
        { id = "mtgear", kind = "info", text = "UI_TF_eff_mt_startgear", note = note },
    }
end

-- Zwei Vanilla-Traits bekommen von der Mod Startausruestung
-- (S/MT_Creation.lua:221-244, aus onNewGame :448): Tailor immer ein Naehset
-- mit Schere, Nadel und 4 Faeden, Smoker eine Packung Zigaretten und ein
-- Feuerzeug, solange die Option SmokerStart an ist (Vorgabe an). Paketzeilen
-- an Vanilla-Traits nennen ihr Paket (TF.Summary.gather); seit dem
-- Faktensweep 2 (23.09.2026).
rows["base:tailor"] = {
    { id = "mtgear", kind = "info", text = "UI_TF_eff_mt_startgear", note = "UI_TF_note_mt_gear_tailor" },
}

rows["base:smoker"] = {
    { id = "mtgear", kind = "info", text = "UI_TF_eff_mt_startgear", note = "UI_TF_note_mt_gear_smoker" },
}

rows["toadtraits:deprived"] = {
    { id = "mtbare", kind = "info", text = "UI_TF_eff_mt_startbare",
      note = "UI_TF_note_mt_deprived", better = "down", group = "crafting" },
}

-- Fahrzeuge --------------------------------------------------------------
--
-- Die Mod setzt die Werte einmal je Auto und merkt sich das in sState, das mit
-- dem Auto gespeichert wird (MT_World.lua:200-216). Die Motorkraft haelt,
-- weil das Spiel sie mitspeichert. Die Bremskraft setzt updatePartStats bei
-- jedem Verschleiss eines Teils und beim Laden neu (BaseVehicle.java:8205),
-- die Hoechstgeschwindigkeit createPhysics beim Laden (:878). Eigene Fussnote
-- fuer diese zwei Zeilen seit dem Faktensweep 23.09.2026.

rows["toadtraits:expertdriver"] = {
    -- MT_World.lua:202: setEngineFeature(Qualitaet x2, Lautstaerke x0.25, Kraft x6).
    { id = "mtengine", kind = "mult", value = 6,    text = "UI_TF_eff_engineforce",
      note = "UI_TF_note_mt_driver" },
    { id = "mtspeed",  kind = "mult", value = 1.25, text = "UI_TF_eff_topspeed",
      note = "UI_TF_note_mt_driverfade" },
    { id = "mtbrake",  kind = "mult", value = 2,    text = "UI_TF_eff_mt_braking",
      note = "UI_TF_note_mt_driverfade", better = "up", group = "vehicles" },
}

rows["toadtraits:poordriver"] = {
    -- MT_World.lua:211: Kraft x0.5; die 0.66 gehoeren zum Tempomat (Z. 214).
    { id = "mtengine", kind = "mult", value = 0.5,  text = "UI_TF_eff_engineforce",
      note = "UI_TF_note_mt_driver" },
    { id = "mtspeed",  kind = "mult", value = 0.75, text = "UI_TF_eff_topspeed",
      note = "UI_TF_note_mt_driverfade" },
    { id = "mtbrake",  kind = "mult", value = 0.5,  text = "UI_TF_eff_mt_braking",
      note = "UI_TF_note_mt_driverfade" },
}

-- better und group gelten fuer einen Schluessel, nicht fuer eine Zeile. Sie
-- stehen oben meist nur an einer der Zeilen, die ihn teilen; pairs laeuft
-- die Traits aber in keiner festen Reihenfolge ab. Darum hier auf alle
-- Zeilen mit demselben text uebertragen, damit es egal ist, welche Trait
-- Facts zuerst sieht.
local meta = {}
for _, list in pairs(rows) do
    for _, row in ipairs(list) do
        if row.better or row.group then
            local m = meta[row.text] or {}
            m.better = m.better or row.better
            m.group = m.group or row.group
            meta[row.text] = m
        end
    end
end
for _, list in pairs(rows) do
    for _, row in ipairs(list) do
        local m = meta[row.text]
        if m then
            row.better = row.better or m.better
            row.group = row.group or m.group
        end
    end
end

TraitFactsAPI = TraitFactsAPI or {}
TraitFactsAPI.queue = TraitFactsAPI.queue or {}
TraitFactsAPI.queue[#TraitFactsAPI.queue + 1] = {
    format = 1,
    source = "Trait Facts",
    modId  = "moreTraitsDefinitive",
    -- Das Kuerzel des Mods, nicht eines aus "Trait Facts" (seit 0.14.14,
    -- Befund im Spiel 24.09.2026): die Zeilen an Vanilla-Traits (Tailor,
    -- Smoker: Startausruestung von More Traits) trugen sonst "TF". Gleich dem
    -- Kuerzel des Mods teilen sich Paket und Mod eines (TF.Mods.accept).
    tag    = "MTD",
    traits = rows,
}
