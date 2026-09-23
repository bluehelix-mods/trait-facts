--- Trait Facts - Schicht 3: hinterlegte Werte.
--
-- Herkunft: der Spielcode von Build 42.20.4, gelesen und wo moeglich im Spiel
-- gemessen. Fundstellen und Belege stehen im
-- Extraktionsbericht (docs/berichte/2026-09-08-extraktion.md); die Abschnittsangaben
-- in den Kommentaren verweisen dorthin.
--
-- Schluessel sind die normalisierten Registry-Namen, siehe TF.traitKey. Achtung
-- bei den Namenspaaren: der Trait, der im Spiel "Puny" heisst, ist intern WEAK,
-- und "Weak" ist FEEBLE. Ebenso "Outdoorsy" = OUTDOORSMAN, "Cat's Eyes" =
-- NIGHT_VISION, "Runner" = JOGGER, "Short of Breath" = ASTHMATIC,
-- "Restless Sleeper" = INSOMNIAC, "Reluctant Fighter" = PACIFIST.
--
-- Eintraege mit `probe` werden ab Phase 3 zur Laufzeit gegengemessen; bis dahin
-- gilt der hier hinterlegte Wert.
--
-- Nicht aufgenommen: Effekte, die Vanilla ohnehin anzeigt (Punktkosten,
-- XP-Boni), und die 37 Traits, deren einzige Wirkung XP-Boni und Rezepte sind.
-- Fuer die zeigt Schicht 1 bereits alles, was es zu zeigen gibt.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Static = TF.Static or {}

-- ---------------------------------------------------------------------------
-- Nahkampf, Kraft, Tragen (Bericht 1.1, 1.2, "Nahkampf, Kraft, Tragen")
-- ---------------------------------------------------------------------------
--
-- Messstand 10.09.2026 (tools/measure-mod, an einer blanken Figur im Spiel):
-- 19 Werte wurden gegen die laufende Engine gemessen, alle 19 stimmen auf die
-- Nachkommastelle. Bestaetigt sind damit die Rueckgabewerte der neun
-- Grapple-Faktoren, der drei Nahkampfschaeden, der drei Erkennungsradien,
-- Hoerweite x4.5, Faellgeschwindigkeit +25 %, Wetterstrafe x0.667 und der
-- Ausdauerverlust von Asthmatic. Ein Getter zeigt nur, was er liefert, nicht,
-- ob jemand den Wert liest: die neun Grapple-Faktoren sind seit dem
-- Faktensweep 23.09.2026 dead (siehe "Grapple" weiter unten).
-- Die Messung schaltet je Trait einzeln zu und liest den Wert; die Berichte
-- liegen als docs/messungen/messung-2026-09-10*.txt im Repo. Der dritte Lauf hat dazu
-- die Behaelterkapazitaet bestaetigt (Schultasche 15: Organized 19,
-- Disorganized 10, also x1.3 und x0.7 mit Abrundung) und die XP-Leiter
-- samt Fast und Slow Learner (siehe TF_XpColumns).

-- Knockback: IsoGameCharacter.processHitDamage(), hitForce x 1.4 / x 0.6,
-- jeweils nur wenn !weapon.isRanged().
-- Tragekapazitaet: maxWeightDelta setzen nur die IsoPlayer-Konstruktoren
-- (Z. 592-600, 656-664; if/else if, Strong vor Weak vor Feeble vor Stout).
-- Die laufen aber vor applyTraits (IsoWorld Z. 2200 und 2211): die
-- gewaehlten Traits stehen dann noch nicht an der Figur, der Delta bleibt
-- 1.0, und die Kapazitaet folgt allein der Strength-Stufe, (int)(8 x
-- getWeightMod) in BodyDamage.UpdateStrength. Einzige Ausnahme ist Last
-- Stand, das STRONG im Konstruktor setzt. Darum seit 0.1.27 dead.
-- Gemessen am 13.09.2026 an sieben frisch erschaffenen Figuren (Test Neue
-- Figur, docs/messungen/messung-2026-09-13-figur.txt): Strong 18 statt 27,
-- Stout 15 statt 18, Puny 6 statt 4, Weak 9 statt 8, getMaxWeightDelta
-- ueberall 1.00. Die frueheren Messwerte (Basis 8.0 am 10.09., 12 auf jeder
-- Stufe im Kletterlauf) waren gelesen, bevor das Spiel nachrechnete; mit God
-- Mode rechnet es gar nicht nach (BodyDamage.Update kehrt vorher zurueck).
-- Grapple: IsoGameCharacter.calculateGrappleEffectivenessFromTraits(),
-- multiplikativ auf Basis 1.0. Seit dem Faktensweep 23.09.2026 dead, alle neun
-- Zeilen (Strong, Athletic, Speed Demon, Brave, Cowardly und die vier
-- Gewichts-Traits): die zwei Aufrufer (IsoGameCharacter.pickUpCorpse Z.
-- 7912-7913, SwipeStatePlayer Z. 524-530) reichen den Wert an Grappled
-- weiter, und dort liest ihn nur die Schwelle `< 0.5f` (BaseGrappleable Z. 75,
-- IsoDeadBody Z. 1775), danach niemand mehr. Unter 0.5 kommt keine
-- Kombination: das Spiel haelt genau einen Gewichts-Trait
-- (Nutrition.applyTraitFromWeight), das Minimum ist Emaciated x Cowardly =
-- 0.54. Die Getter-Messungen vom 10.09.2026 bleiben als Rueckgabewert
-- stehen. Spielfehler grapple-schwelle.

TF.Static["strong"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
    { id = "knockback",   kind = "pct",  value = 40,   text = "UI_TF_eff_knockback",
      note = "UI_TF_note_meleeonly" },
    { id = "carryweight", kind = "mult", value = 1.5,  text = "UI_TF_eff_carry",
      dead = true, note = "UI_TF_note_deadcarry" },
    { id = "grapple",     kind = "mult", value = 1.25, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
}

TF.Static["stout"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
    { id = "carryweight", kind = "mult", value = 1.25, text = "UI_TF_eff_carry",
      dead = true, note = "UI_TF_note_deadcarry" },
}

-- Registry-Name WEAK, im Spiel heisst der Trait "Puny".
TF.Static["weak"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
    { id = "knockback",   kind = "pct",  value = -40,  text = "UI_TF_eff_knockback",
      note = "UI_TF_note_meleeonly" },
    { id = "carryweight", kind = "mult", value = 0.75, text = "UI_TF_eff_carry",
      dead = true, note = "UI_TF_note_deadcarry" },
}

-- Registry-Name FEEBLE, im Spiel heisst der Trait "Weak". Kein Knockback-
-- Modifikator - das unterscheidet ihn von Puny.
TF.Static["feeble"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
    { id = "carryweight", kind = "mult", value = 0.9,  text = "UI_TF_eff_carry",
      dead = true, note = "UI_TF_note_deadcarry" },
}

-- Ax-pert: getChopTreeSpeed() liefert 1.0 statt 0.8, im Getter +25 % (Probe
-- chopTreeSpeed). Die Faell-Animation (AnimSets/player/actions/chop_tree.xml)
-- fuehrt ChopTreeSpeed als m_SpeedScale, der Clip dauert 1.0 s, der Hieb
-- faellt bei 0.35: mit Ax-pert ein Hieb je 1.0 s, ohne je 1.25 s, x1.25.
-- Bis 0.13.9 stand die Zeile als dead, weil der Takt am 13.09.2026 in drei
-- Laeufen mit und ohne Ax-pert bei 1250 ms blieb. Das war ein Artefakt des
-- Tests (Faktensweep 23.09.2026): das Spiel liest die Geschwindigkeit nur,
-- wenn der Animationsknoten startet (AnimLayer.startLiveNodeTracks), und der
-- Test schaltete den Trait um, waehrend der Knoten weiterlief (clear und
-- doChopTree im selben Tick); jede Phase lief so mit dem Tempo der ersten,
-- und die war immer ohne Ax-pert. Eine Figur, die Ax-pert schon beim Start
-- des Faellens hat, ist nie gemessen worden. Darum jetzt Stand code; die
-- Nachmessung mit dem Trait vor dem Start ist geplant (Mess-Mod 6.43.0).
-- Der Baumschaden steigt auf x 1.5, nur fuer Waffen der Kategorie AXE;
-- gemessen am 13.09.2026: 35 -> 53 je Hieb, 1.50 ueber 24 Hiebe.
-- Axt-Schwungzeit: dieselbe 0.8 bremst ohne Ax-pert jeden Schlag mit einer
-- Axt. calculateCombatSpeed (IsoGameCharacter:8836) multipliziert bei Aexten
-- mit getChopTreeSpeed(), und CombatManager.pressedAttack (:2660) macht daraus
-- CombatSpeed, das Tempo der Schwung-Animation. Die 0.8 trifft aber nur den
-- Grundterm 0.8 x BaseSpeed; danach kommen ohne Trait-Bezug +0.03 je
-- Waffenstufe, +0.02 je Fitness-Stufe und -0.07 je Stufe Erschoepfung und
-- Ueberladung dazu, dann Rand.Next(1.1, 1.2) und die Klemme 0.8 bis 1.6.
-- Laut Code also kein fester Faktor: rund -18 % bei einer neuen Figur (Axt 0,
-- Fitness 5), -16 % bei Axt 3, -12 % bei Axt 10 und Fitness 10 (Faktensweep
-- 23.09.2026; bis dahin stand hier "ein Schlag dauert also x 0.8").
-- Gemessen am 13.09.2026 (docs/messungen/messung-2026-09-13-axt.txt, Axt-Skill
-- fest auf 3, Fitness nicht mitgeschrieben): Schlagdauer mit/ohne 0.788, Takt
-- 0.792, also -20 %; das ist mehr, als das lineare Modell bei Axt 3 erwartet,
-- die Schlagdauer folgt 1/CombatSpeed also nicht genau. Die Zeile zeigt die
-- gemessenen -20 % fuer eine neue Figur, die Fussnote die Spanne. Bis 0.1.23
-- stand hier -5 %, wirkungslos: die x 0.95 in HandWeapon.getSpeedMod hat
-- wirklich keinen Aufrufer (Spielfehler speedmod-axeman), aber sie ist nicht
-- der Weg, auf dem Ax-pert wirkt.
TF.Static["axeman"] = {
    { id = "chopspeed",  kind = "pct", value = 25,  text = "UI_TF_eff_chopspeed",
      probe = "chopTreeSpeed", note = "UI_TF_note_chophit" },
    { id = "axeswing",   kind = "pct", value = -20, text = "UI_TF_eff_axeswing",
      note = "UI_TF_note_axeswing" },
    { id = "treedamage", kind = "pct", value = 50,  text = "UI_TF_eff_treedamage",
      note = "UI_TF_note_axeonly" },
}

-- ---------------------------------------------------------------------------
-- Gewicht (Bericht "Nahkampf, Kraft, Tragen", "Ausdauer", "Klettern")
-- ---------------------------------------------------------------------------

TF.Static["underweight"] = {
    { id = "meleedamage", kind = "pct", value = -20, text = "UI_TF_eff_meleedamage",
      probe = "damageDealt" },
}

-- Stolpern: ClimbOverFenceState.shouldFallAfterVaultOver wuerfelt Rand.Next(100)
-- gegen einen Zaehler, Basis 0 (10 beim Sprinten), also Prozentpunkte. Der
-- Engine-Bug ist im Bericht belegt: VERY_UNDERWEIGHT wird zweimal abgefragt
-- (+20, dann +10), gemeint war vermutlich UNDERWEIGHT. Effektiv +30.
--
-- Klettern: IsoGameCharacter.getClimbingFailChanceFloat ist trotz des Namens
-- ein Sicherheitswert (hoeher = seltener Absturz vom Bettlaken-Seil), Basis
-- Fitness x 2 + Strength x 2 + Nimble x 2, bei einer neuen Figur 20.
-- getClimbRopeSpeed nimmt max(Strength, Fitness) und rechnet die Trait-Stufen
-- dazu; die Stufe bestimmt das Klettertempo.
-- IsoGameCharacter.attackFromWindowsLunge: springt ein Zombie, der gerade
-- ueber einen Zaun oder durch ein Fenster klettert (oder aus einem geworfen
-- wird), eine nahe Figur an und trifft, geraet sie ins Taumeln, und ein
-- eigener Wurf entscheidet, ob sie auch stuerzt (Faktensweep 23.09.2026:
-- klettern tut der Zombie, nicht die Figur). Nur mit der Sandbox-Option
-- Zombie Lunge (Standard an). Basis 30 von 100, dazu
-- Betrunken x3, Muede x3 und Schwere Last x5 je Moodle-Stufe sowie
-- Unterkoerper-Schmerz ueber 20 geteilt durch 10; abgezogen werden Fitness x2
-- und Nimble x1, das Ergebnis nie unter 5. Das ist ein anderer Wurf als die
-- Stolperchance aus ClimbOverFenceState, darum eine eigene Zeile.
-- IsoGameCharacter.handleLandingImpact: nach einem schaedigenden Sturz
-- entscheidet ein zweiter Wurf ueber Knochenbruch, tiefe Wunde oder nur
-- Steifheit. Die Schwelle beginnt bei Sturzhoehe x 55, plus bis zu 20, wenn
-- das Inventar fast voll ist, minus 1,5 je Fitness-Stufe ueber 4 und je
-- Nimble-Stufe. Der Bruchwurf ist Rand.Next(100) < Schwelle, der Wundwurf
-- laeuft mit Schwelle + 10 nur, wenn der Bruchwurf danebenging.
TF.Static["veryunderweight"] = {
    { id = "meleedamage",  kind = "pct",  value = -40,  text = "UI_TF_eff_meleedamage",
      probe = "damageDealt" },
    { id = "grapple",      kind = "mult", value = 0.8,  text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
    { id = "trip",         kind = "flat", value = 30,   text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase",
      hint = "UI_TF_note_enginebug" },
    -- Auch hier steht die Abfrage zweimal hintereinander im Code, +20 und
    -- dann +10; wie beim Zaun sieht das nach einem Versehen aus.
    { id = "lungefall",    kind = "flat", value = 30,   text = "UI_TF_eff_lungefall",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_lungebase",
      hint = "UI_TF_note_enginebug" },
    { id = "fallinjury",   kind = "flat", value = 10,   text = "UI_TF_eff_fallinjury",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_fallinjurybase" },
    { id = "falldamage",   kind = "pct",  value = 20,   text = "UI_TF_eff_falldamage" },
    { id = "enduranceregen", kind = "mult", value = 0.7, text = "UI_TF_eff_enduranceregen" },
}

TF.Static["emaciated"] = {
    { id = "meleedamage",  kind = "pct",  value = -60,  text = "UI_TF_eff_meleedamage",
      probe = "damageDealt" },
    { id = "grapple",      kind = "mult", value = 0.6,  text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
    { id = "falldamage",   kind = "pct",  value = 40,   text = "UI_TF_eff_falldamage" },
    { id = "fallinjury",   kind = "flat", value = 20,   text = "UI_TF_eff_fallinjury",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_fallinjurybase" },
    { id = "enduranceregen", kind = "mult", value = 0.3, text = "UI_TF_eff_enduranceregen" },
}

TF.Static["overweight"] = {
    { id = "grapple",       kind = "mult", value = 1.1,  text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
    -- Sprint-Faktor 0.99, wirkungslos wie bei den anderen vier (Kommentar
    -- "Zum dead an sprintspeed"). Fehlte bis 0.1.7 (Bugjagd 10.09.2026, Fund 12).
    { id = "sprintspeed",   kind = "pct",  value = -1,   text = "UI_TF_eff_sprintspeed",
      dead = true, note = "UI_TF_note_deadspeed" },
    -- getClimbingFailChanceFloat zieht das Gewicht ab, BEVOR Clumsy halbiert;
    -- die Punkte von Dextrous, Gymnast, Burglar und All Thumbs kommen danach.
    -- Eigene Fussnote, damit die Uebersicht beides nicht in eine Zeile legt
    -- (Bugjagd 10.09.2026, Fund 2). Gilt gleich fuer Obese.
    --
    -- Gemessen am 13.09.2026 (Kletterlauf, Mess-Mod 6.19.0, docs/messungen/
    -- messung-2026-09-13-klettern.txt): 21 Faelle, Fitness, Strength und
    -- Nimble je 0 bis 10, 651 Punkte, keiner weicht von der Formel ab
    -- (2 x Fitness + 2 x Strength + 2 x Nimble, Gewicht ab, Clumsy halbiert,
    -- dann +-4, ganzzahlige Wurzel). Das Seiltempo folgt Fitness und Strength
    -- gleich, Nimble nicht; Dextrous, Gymnast, Burglar +1 Stufe in beide
    -- Richtungen, All Thumbs -1, High Weight -1 und Very High Weight -2 nur
    -- hoch, Clumsy gar nicht. Die acht Stufen-Traits und die drei
    -- Untergewichts-Traits aendern an Sicherheit und Seil nichts.
    { id = "climb",         kind = "flat", value = -15,  text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbweight" },
    -- getClimbRopeSpeed zieht das Gewicht nur im Zweig !down ab, also nur
    -- beim Hochklettern. Eigene Fussnote, damit die Uebersicht es nicht mit
    -- Gymnasts +1 (hoch und runter) zu null verrechnet (Audit 12.09.2026).
    { id = "climbstrength", kind = "flat", value = -1,   text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbup" },
    { id = "trip",          kind = "flat", value = 10,   text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase" },
    { id = "lungefall",     kind = "flat", value = -5,   text = "UI_TF_eff_lungefall",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_lungebase" },
    { id = "falldamage",    kind = "pct",  value = 20,   text = "UI_TF_eff_falldamage" },
    { id = "fallinjury",    kind = "flat", value = 10,   text = "UI_TF_eff_fallinjury",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_fallinjurybase" },
    { id = "enduranceloss", kind = "mult", value = 2.07, text = "UI_TF_eff_enduranceloss",
      note = "UI_TF_note_enddelta", case = "UI_TF_note_enddelta" },
    { id = "enduranceregen", kind = "mult", value = 0.7, text = "UI_TF_eff_enduranceregen" },
}

TF.Static["obese"] = {
    { id = "grapple",       kind = "mult", value = 1.05, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
    { id = "sprintspeed",   kind = "pct",  value = -15,  text = "UI_TF_eff_sprintspeed",
      dead = true, note = "UI_TF_note_deadspeed" },
    { id = "climb",         kind = "flat", value = -25,  text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbweight" },
    { id = "climbstrength", kind = "flat", value = -2,   text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbup" },
    { id = "trip",          kind = "flat", value = 20,   text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase" },
    { id = "lungefall",     kind = "flat", value = -10,  text = "UI_TF_eff_lungefall",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_lungebase" },
    { id = "falldamage",    kind = "pct",  value = 40,   text = "UI_TF_eff_falldamage" },
    { id = "fallinjury",    kind = "flat", value = 20,   text = "UI_TF_eff_fallinjury",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_fallinjurybase" },
    { id = "enduranceregen", kind = "mult", value = 0.4, text = "UI_TF_eff_enduranceregen" },
}

-- ---------------------------------------------------------------------------
-- Haut und Verletzungen (Bericht 1.3, "Heilung und Verletzungen")
-- ---------------------------------------------------------------------------

-- baseChance ist die Chance, *nicht* verletzt zu werden. x 1.3 bzw. / 1.3.
-- Der Kratzer-Wurf laeuft ueber Rand.NextBool(n) mit Wahrscheinlichkeit 1/n:
-- 1/6 normal, mit Thick-skinned 1/13, mit Thin-skinned 1/3.
-- BodyDamage.AddRandomDamageFromZombie: der Faktor trifft die Zwischensumme
-- 15 + getMeleeCombatMod - 10 je weiterem Angreifer (unbewaffnet 15 - 5 = 10),
-- mit Abrunden, vor den Abzuegen fuer Angriffe von hinten (-15) und von der
-- Seite (-30; Rear Vulnerability Hoch, der Standard). Verletzt wird bei
-- Rand.Next(100) > Summe, ohne Verletzung bleibt man also mit (Summe + 1) %.
-- Von vorn gegen einen Zombie unbewaffnet 10 -> 13 (Thick) bzw. 7 (Thin),
-- 11 % -> 14 % bzw. 8 %, je +27 % und -27 %; mit Waffenskill (Summe 13 bis
-- 22) +21 bis +29 % und -21 bis -27 %. Die frueheren +30 / -23 waren die
-- Faktoren x1.3 und /1.3 auf den inneren Wert (Faktensweep 23.09.2026; bis
-- dahin stand hier auch Seite und hinten vertauscht und "16 % auf 20 %", das
-- ist Summe 15). Von der Seite oder gegen drei liegt die Summe schon bei 0,
-- dann aendert der Trait nichts; von hinten nur mit geuebter Waffe.
TF.Static["thickskinned"] = {
    { id = "zombieinjury", kind = "pct", value = 27,  text = "UI_TF_eff_zombieinjury",
      note = "UI_TF_note_zombieinjury" },
    { id = "treescratch",  kind = "pct", value = -54, text = "UI_TF_eff_treescratch" },
}

TF.Static["thinskinned"] = {
    { id = "zombieinjury", kind = "pct", value = -27,  text = "UI_TF_eff_zombieinjury",
      note = "UI_TF_note_zombieinjury" },
    { id = "treescratch",  kind = "pct", value = 100,  text = "UI_TF_eff_treescratch" },
}

-- Wundzeiten sind Punktebereiche in BodyPart (Biss 50-80, Schnitt 10-20,
-- Kratzer 7-15 / 5-10 / 12-20, tiefe Wunde 15-20), die je Frame abgebaut
-- werden; die Umrechnung in Stunden haengt an Verband und Tageslaenge. Fuer
-- den Tooltip gilt deshalb das Verhaeltnis der Bereichsmitten:
--   Fast Healer: Biss 40/65 = -38 %, Schnitte und Kratzer rund -50 %,
--                tiefe Wunde 13/17.5 = -26 %
--   Slow Healer: Biss 115/65 = +77 %, Schnitte und Kratzer rund +76 %,
--                tiefe Wunde 26/17.5 = +49 %
-- Der Bruchfaktor sitzt in BodyPart.generateFractureNew, und diese Methode
-- rufen nur die beiden Sturzstellen in IsoGameCharacter. Fahrzeugunfaelle
-- (IsoPlayer, BaseVehicle) rufen generateFracture direkt, ohne Trait-Abfrage;
-- dort wirkt der Trait nur ueber den Unfallschaden, Fast Healer x0.8 (kleiner),
-- Slow Healer x1.2 (groesser). Die Fussnote sagt beides; bis 0.13.9 nannte
-- sie nur den kleineren Schaden, auch bei Slow Healer (Faktensweep 23.09.2026).
TF.Static["fasthealer"] = {
    { id = "fracture",  kind = "mult", value = 0.6, text = "UI_TF_eff_fracture",
      note = "UI_TF_note_fracturefall" },
    { id = "vehdamage", kind = "mult", value = 0.8, text = "UI_TF_eff_vehdamage" },
    { id = "bitewound", kind = "pct", value = -38, text = "UI_TF_eff_bitewound",
      note = "UI_TF_note_midpoint" },
    -- Hinter "Schnitte und Kratzer" stehen in BodyPart vier Generatoren mit
    -- eigenen Spannen: Fast Healer -50 % (Schnitt), -36 % (Kratzer), -60 %
    -- (Waffe) und -53 % (Fenster), je Mitte der Spanne; bis 0.1.25 stand
    -- hier -45 statt -50 (Engine-Recherche 13.09.2026). Gemessen am
    -- 13.09.2026 (Code-Werte) im Mittel x0.498. -50 ist ihr Mittel; die
    -- Fussnote nennt die Spanne statt einer
    -- "Mitte des gewuerfelten Bereichs", die es nicht gibt (Bugjagd
    -- 10.09.2026, Fund 13). Tiefe Wunden haben einen Generator und behalten
    -- ihre Fussnote.
    { id = "cutwound",  kind = "pct", value = -50, text = "UI_TF_eff_cutwound",
      note = "UI_TF_note_cutspread_fast" },
    { id = "deepwound", kind = "pct", value = -26, text = "UI_TF_eff_deepwound",
      note = "UI_TF_note_midpoint" },
}

TF.Static["slowhealer"] = {
    { id = "fracture",  kind = "mult", value = 1.8, text = "UI_TF_eff_fracture",
      note = "UI_TF_note_fracturefall" },
    { id = "vehdamage", kind = "mult", value = 1.2, text = "UI_TF_eff_vehdamage" },
    { id = "bitewound", kind = "pct", value = 77, text = "UI_TF_eff_bitewound",
      note = "UI_TF_note_midpoint" },
    -- Slow Healer: +67 %, +82 %, +100 % und +56 % je Generator (Fund 13),
    -- im Mittel +76 %. Bis 0.1.22 stand hier +70, obwohl die vier Werte
    -- daneben standen (Audit 12.09.2026).
    { id = "cutwound",  kind = "pct", value = 76, text = "UI_TF_eff_cutwound",
      note = "UI_TF_note_cutspread_slow" },
    { id = "deepwound", kind = "pct", value = 49, text = "UI_TF_eff_deepwound",
      note = "UI_TF_note_midpoint" },
}

-- ---------------------------------------------------------------------------
-- Lernen (Bericht "Erfahrung / Lernen")
-- ---------------------------------------------------------------------------

TF.Static["fastlearner"] = {
    { id = "xp", kind = "pct", value = 30,  text = "UI_TF_eff_xp",
      note = "UI_TF_note_notfitstr", scope = "xpmost" },
    { id = "researchtime", kind = "mult", value = 0.7, text = "UI_TF_eff_researchtime" },
}

TF.Static["slowlearner"] = {
    { id = "xp", kind = "pct", value = -30, text = "UI_TF_eff_xp",
      note = "UI_TF_note_notsprintfitstr", scope = "xpmostnosprint" },
    { id = "researchtime", kind = "mult", value = 1.3, text = "UI_TF_eff_researchtime" },
}

TF.Static["crafty"] = {
    { id = "xp", kind = "pct", value = 30,  text = "UI_TF_eff_xp",
      note = "UI_TF_note_crafting", scope = "xpcrafting" },
}

-- Registry-Name PACIFIST, im Spiel "Reluctant Fighter".
TF.Static["pacifist"] = {
    { id = "xp", kind = "pct", value = -25, text = "UI_TF_eff_xp",
      note = "UI_TF_note_combatskills", scope = "xpcombat" },
}

-- ---------------------------------------------------------------------------
-- Schusswaffen (Bericht "Schusswaffen")
-- ---------------------------------------------------------------------------

-- Treffer- und Kritchance rechnet die Engine auf einer 0-100-Skala; die
-- Boni sind Additionen darauf. Die Basis haengt an Waffe, Distanz und
-- Skill, deshalb "+20 von 100" mit Beispiel statt Vorher/Nachher.
TF.Static["marksman"] = {
    { id = "hitchance",   kind = "flat", value = 20,  text = "UI_TF_eff_hitchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_hitexample" },
    { id = "critchance",  kind = "flat", value = 10,  text = "UI_TF_eff_critchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_rangedonly" },
    { id = "windpenalty", kind = "pct",  value = -40, text = "UI_TF_eff_windpenalty" },
    -- IsoGameCharacter.updateAimingDelay: die aimingDelay faellt je Tick um
    -- 0.625 x Multiplier x (1.0 + 0.05 x Aiming + 0.1 mit Marksman). Der
    -- Trait addiert also 0,1 auf den Abbaufaktor: bei Aiming 0 wird aus 1,0
    -- eine 1,1 (+10 % Tempo), bei Aiming 10 aus 1,5 eine 1,6 (+6,7 %). Nicht
    -- zu verwechseln mit dem Startwert der Zielverzoegerung, an dem
    -- Dextrous und All Thumbs drehen.
    { id = "aimsteady",   kind = "pct",  value = 10,  text = "UI_TF_eff_aimsteady",
      note = "UI_TF_note_aimsteady" },
}

-- aimdelay: resetAimingDelay setzt den Startwert beim Anheben der Waffe auf
-- aimingTime x0.8 (Dextrous) bzw. x1.2 (All Thumbs). Was jeder Schuss danach
-- dazugibt (CombatManager Z. 3355-3358), ist fuer alle gleich und auf die volle
-- aimingTime gedeckelt, ohne Trait-Faktor. Darum die Fussnote (Faktensweep
-- 23.09.2026).
TF.Static["dextrous"] = {
    { id = "transfer", kind = "mult", value = 0.5,  text = "UI_TF_eff_transfer" },
    { id = "aimdelay", kind = "mult", value = 0.8,  text = "UI_TF_eff_aimdelay",
      note = "UI_TF_note_aimdelay" },
    -- HandWeapon.checkUnJam: Fehlchance 8 - 0.5 x Aiming + 3 je Moodle-Stufe
    -- (Panik, Stress, Betrunken), Dextrous -2, All Thumbs +2, mindestens 1;
    -- Loesechance = 100 % minus das, minus Waffenschaden. Bei Aiming 0 und
    -- ruhig also 92 %, mit Dextrous 94 %, mit All Thumbs 90 %.
    { id = "jam",      kind = "fromto", value = { 92, 94 }, text = "UI_TF_eff_jam",
      note = "UI_TF_note_aiming0" },
    -- RecipeCodeOnCreate.openCan: Zaehler 3, Dextrous -2, Clumsy +2, dann
    -- eine else-if-Kette: Short Blade ueber 5 -2, ueber 3 -1, sonst Cooking 0
    -- +1; unter 1 wird der Zaehler 1 und der Wurf Rand.Next(30). Wurf
    -- Rand.Next(20) <= Zaehler. Ab Cooking 1 und bis Short Blade 3 also 20 %,
    -- mit Dextrous 10 %, mit Clumsy 30 % (Faktensweep 23.09.2026: die
    -- Short-Blade-Bedingung fehlte in der Fussnote).
    { id = "canwound", kind = "fromto", value = { 20, 10 }, text = "UI_TF_eff_canwound",
      note = "UI_TF_note_cooking1" },
    { id = "climb",    kind = "flat", value = 4,    text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase" },
    -- getClimbRopeSpeed: All Thumbs --effectiveStrength, Dextrous ++, im
    -- selben if-else. Die Sonde dazu gab es schon, benutzt hat sie niemand.
    { id = "climbstrength", kind = "flat", value = 1, text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbstrengthbase" },
}

TF.Static["allthumbs"] = {
    { id = "transfer", kind = "mult", value = 2.0,  text = "UI_TF_eff_transfer" },
    -- ISHandcraftAction.lua:405: stopOnWalk = not craftRecipe:isCanWalk(), vor
    -- der Abfrage auf All Thumbs oder klobige Handschuhe (Z. 406-408), die den
    -- Wert nur noch einmal mehr auf true setzt. Der Fund vom 10.09.2026 hatte
    -- offen gelassen, ob ein Rezept isCanWalk() je erlaubt. Gemessen am
    -- 14.09.2026: CraftRecipe.Load liest den Schluessel, aber media/scripts
    -- setzt ihn in Build 42.20 in keinem einzigen Rezept. stopOnWalk ist damit
    -- fuer jede Figur immer true, mit oder ohne All Thumbs - der Trait
    -- aendert hier nichts. Darum seit 0.1.29 dead.
    { id = "craftwalk", kind = "info", text = "UI_TF_eff_craftwalk",
      dead = true, note = "UI_TF_note_deadcraftwalk" },
    { id = "aimdelay", kind = "mult", value = 1.2,  text = "UI_TF_eff_aimdelay",
      note = "UI_TF_note_aimdelay" },
    { id = "jam",      kind = "fromto", value = { 92, 90 }, text = "UI_TF_eff_jam",
      note = "UI_TF_note_aiming0" },
    { id = "climb",    kind = "flat", value = -4,   text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase" },
    { id = "climbstrength", kind = "flat", value = -1, text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbstrengthbase" },
}

-- IsoGameCharacter.getAlphaUpdateRateMul: Short Sighted teilt die Rate durch
-- 2, Eagle Eyed nimmt sie mal 1,5. Massgeblich ist der Trait der Figur, der
-- die Kamera folgt (IsoCamera.getCameraCharacter), nicht der der gesehenen.
-- Betroffen ist nur das Einblenden; das Ausblenden laeuft ueber
-- getAlphaUpdateRateDiv und bleibt unveraendert. Eine Brille aendert nichts:
-- die Abfrage kennt nur den Trait.
TF.Static["shortsighted"] = {
    { id = "sightrange", kind = "info", text = "UI_TF_eff_sightrange" },
    { id = "blur",       kind = "info", text = "UI_TF_eff_blur" },
    { id = "fadein",     kind = "mult", value = 0.5, text = "UI_TF_eff_fadein" },
}

-- ---------------------------------------------------------------------------
-- Panik, Stress, Furcht (Bericht "Panik, Stress, Furcht")
-- ---------------------------------------------------------------------------

TF.Static["brave"] = {
    -- Nur die Panik aus BodyDamage.IncreasePanic, also beim Anblick neuer
    -- Zombies; Agoraphobic, Claustrophobic, Blutungen und Fear of Blood
    -- schreiben direkt auf den Wert (Audit 12.09.2026).
    { id = "panic",   kind = "pct",  value = -70, text = "UI_TF_eff_panic",
      note = "UI_TF_note_panicseen" },
    { id = "corpsestress", kind = "mult", value = 0.5, text = "UI_TF_eff_corpsestress" },
    { id = "grapple", kind = "mult", value = 1.1, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
}

TF.Static["cowardly"] = {
    { id = "panic",   kind = "pct",  value = 100, text = "UI_TF_eff_panic",
      note = "UI_TF_note_panicseen" },
    { id = "corpsestress", kind = "mult", value = 2.0, text = "UI_TF_eff_corpsestress" },
    { id = "grapple", kind = "mult", value = 0.9, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
}

TF.Static["desensitized"] = {
    { id = "panic",     kind = "info", text = "UI_TF_eff_nopanic" },
    { id = "corpses",   kind = "info", text = "UI_TF_eff_nocorpsestress" },
    -- SleepingEvent.checkNightmare: Rand.Next(100) < 5, mit Desensitized 10,
    -- einmal je Schlaf ab drei Stunden.
    { id = "nightmare", kind = "fromto", value = { 5, 10 }, text = "UI_TF_eff_nightmare",
      note = "UI_TF_note_nostress" },
}

-- Registry-Name HEMOPHOBIC, im Spiel "Fear of Blood". Die +50 (stats:add
-- (PANIC, 50), Panik laeuft von 0 bis 100) stehen in acht Aktionen, nicht nur
-- beim Verbinden:
--   nur bei blutender Wunde (getBleedingTime() > 0): ISApplyBandage,
--     ISComfreyCataplasm, ISGarlicCataplasm, ISPlantainCataplasm
--   immer, ohne jede Bedingung: ISStitch (naehen und Naht entfernen),
--     ISCleanBurn (Verbrennung auswaschen), ISRemoveBullet, ISRemoveGlass
-- Darum heisst die Zeile "Verletzung" und nicht "blutende Wunde": eine
-- Verbrennung auszuwaschen ist keine Wunde und blutet nicht.
TF.Static["hemophobic"] = {
    { id = "bloodpanic", kind = "mult", value = 2.0, text = "UI_TF_eff_bloodpanic" },
    { id = "treatpanic", kind = "flat", value = 50, text = "UI_TF_eff_treatpanic",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_treatpanic" },
    { id = "medcheck",   kind = "info", text = "UI_TF_eff_nomedcheck" },
    -- IsoGameCharacter.updateStress: getTotalBlood() x StressFromHemophobic
    -- (0.0000003333) / 0.8. Im selben Takt kostet eine offene Bisswunde
    -- StressFromBiteOrScratch (0.00005); 0.00005 x 0.8 / 0.0000003333 = 120,
    -- also wiegen 120 Blutpunkte so schwer wie ein offener Biss.
    -- getTotalBlood summiert Clothing.getBloodlevel je getragenem Teil (0
    -- bis 100), das Blut an Erst- und Zweithandgegenstand und
    -- HumanVisual.getTotalBlood (in Summe hoechstens rund 19).
    { id = "bloodstress", kind = "info", text = "UI_TF_eff_bloodstress",
      note = "UI_TF_note_bloodstress" },
    -- Eine zweite Stelle, am 13.09.2026 bei der Fundstellen-Suche fuer die
    -- Befund-Datenbank gefunden: beim Umlagern
    -- (client/TimedActions/ISInventoryTransferAction.lua:139-144) gibt jeder
    -- Aktionstick getBloodLevelAdjustedLow() x Multiplier / 10000 Stress,
    -- solange der Gegenstand Blut traegt. Unabhaengig vom Blut an der Figur.
    -- Die gleiche Abfrage in shared/TimedActions/ISCraftAction.lua:28-32 ist
    -- in 42.20.4 unerreichbar: ISCraftAction braucht ein Rezept alter Art, und
    -- davon gibt es keines mehr; ISHandcraftAction fragt HEMOPHOBIC nicht ab
    -- (Spielfehler leichenstress-craft). Darum sagt die Zeile seit dem
    -- Faktensweep 23.09.2026 nur noch "umlagern", nicht mehr "craften".
    { id = "blooditems", kind = "info", text = "UI_TF_eff_blooditems",
      note = "UI_TF_note_blooditems" },
}

-- IsoGameCharacter.update: 0.5 bzw. 0.6 x (1 - Raumgroesse/70) je Frame, mit
-- getThirtyFPSMultiplier, also je echter Sekunde x 30 unabhaengig von der
-- Bildrate: 15 Punkte je Sekunde im Freien, bis 18 in winzigen Raeumen. Zum
-- Vergleich baut BodyDamage.ReducePanic 0.06 x 30 = 1.8 je Sekunde ab.
-- "Im Freien" heisst: das Feld liegt in keinem Raum (updateInternal Z. 8207,
-- !isInARoom), ohne Abfrage auf ein Fahrzeug; im Auto draussen gilt es also
-- auch (Faktensweep 23.09.2026, darum "auch im Fahrzeug" in der Zeile).
TF.Static["agoraphobic"] = {
    { id = "panicout", kind = "flat", value = 15, text = "UI_TF_eff_panicout",
      unit = "UI_TF_unit_panicsec", note = "UI_TF_note_panicdecay" },
}

TF.Static["claustrophobic"] = {
    { id = "panicin", kind = "range", value = { 0, 18 }, text = "UI_TF_eff_panicin",
      unit = "UI_TF_unit_panicsec", note = "UI_TF_note_roomsize" },
}

-- IsoGameCharacter.calculateBaseSpeed: Basis 0.8, ab Panikstufe 3 plus
-- (Stufe + 1) / 20. Stufe 3 gibt +0.20 = +25 %, Stufe 4 +0.25. Aber
-- calculateWalkSpeed deckelt das Gehtempo bei 1.0: aus 1.05 wird 1.0, also
-- bleibt es auch bei extremer Panik +25 %. Beim Rennen zaehlt
-- (Basis - 0.15) + Sprinting / 20, gedeckelt bei 1.0: ohne Sprinting +31 %
-- bis +38 %, ab Sprinting 7 nichts mehr. Die Fussnote mit +31,3 % bei
-- extremer Panik war darum falsch (Audit 12.09.2026).
--
-- Der frueher genannte Faktor 1.1 aus IsoPlayer.getMoveSpeed steht hier
-- bewusst nicht mehr: getMoveSpeed wird nur von getPathSpeed gelesen, und auf
-- getPathSpeed verweist im ganzen Jar keine andere Klasse (Konstantenpool von
-- 23740 .class-Dateien, Treffer nur IsoPlayer selbst). Ein Wert ohne
-- nachweisbaren Abnehmer gehoert nicht in den Tooltip.
-- Seit 0.12.1 die gemessene Strecke, nicht der Wert im Code. calculateBaseSpeed
-- hebt das Grundtempo ab Panikstufe 3 um (Stufe + 1) / 20, die Variable
-- WalkSpeed steigt damit von 0.8 auf 1.0 (x1.25); zurueckgelegt wird beim Gehen
-- aber nur x1.080 (vier Laeufe am 20.09.2026: 1.0813, 1.0802, auf Stufe 3
-- 1.0804) und beim Rennen x1.158 statt x1.35 (Stufe 4, Sprinting 1). Die
-- Animation setzt WalkSpeed nicht eins zu eins in Strecke um. Der Spieler
-- fragt, wie viel schneller er wegkommt; das ist die Strecke. Der Lauf mit
-- Sprinten (18:21) bestaetigte Gehen (x1.0835, x1.0823) und Rennen (x1.1628)
-- und mass den Sprint mit x1.1336: derselbe Tempowert wie beim Rennen, auf
-- der Strecke etwas weniger.
--
-- Wortlaut (Rueckmeldung aus dem Spiel, 20.09.2026): alle drei Zeilen sagen
-- dasselbe, "from Strong Panic": dort beginnt der Zuschlag. 0.12.3 nannte
-- ueberall "Extreme Panic" mit der Fussnote "same at Strong Panic" nur beim
-- Gehen, und das las sich, als gaelten Rennen und Sprinten erst ab Extreme. Die Fussnoten
-- sagen nur, was der Spieler wissen muss (beim Gehen gilt es ab Strong Panic
-- genauso, beim Rennen und Sprinten schrumpft es mit dem Sprinting-Skill), nicht,
-- wie gemessen wurde: das steht im Wiki.
TF.Static["adrenalinejunkie"] = {
    { id = "panicspeed", kind = "pct", value = 8, text = "UI_TF_eff_panicspeed",
      note = "UI_TF_note_panicspeed4" },
    -- Seit 0.12.4 als Spanne von Strong Panic bis Extreme Panic: der Lauf vom
    -- 20.09.2026, 20:25 (Mess-Mod 6.37.0) mass Rennen x1.1305 auf Stufe 3 und
    -- x1.1661 auf Stufe 4, Sprinten x1.1028 und x1.1465 (davor x1.1336). Gehen
    -- ist auf beiden Stufen gleich (x1.0930 und x1.0855), darum eine Zahl.
    -- Spannen seit 0.13.6 nach allen sauberen Laeufen (20. und 21.09.2026): Rennen
    -- x1.1213 bis x1.1698, Sprinten x1.1028 bis x1.1465. Bis dahin 13-16 und 10-14:
    -- die 13 kam aus einem Lauf, in dem der Sprinting-Skill mitten in der Phase stieg.
    { id = "panicrun", kind = "pctrange", value = { 12, 17 }, text = "UI_TF_eff_panicrun",
      note = "UI_TF_note_panicrun" },
    { id = "panicsprint", kind = "pctrange", value = { 10, 15 }, text = "UI_TF_eff_panicsprint",
      note = "UI_TF_note_panicrun" },
}

-- ---------------------------------------------------------------------------
-- Krankheit, Nahrung, Gift (Bericht "Krankheit, Nahrung, Gift")
-- ---------------------------------------------------------------------------

-- poison: BodyDamage.JustAteFood halbiert (Iron Gut) bzw. verdoppelt (Weak
-- Stomach) nur das eigene Gift eines Essens (getPoisonPower > 0). Vom Regen
-- verseuchtes Essen (isTainted, Z. 549-558) gibt fest 20 x Portion Gift, ohne
-- Trait-Abfrage; Erhitzen nimmt die Verseuchung weg (Food Z. 372-373,
-- 474-475). Bei Getraenken zaehlt das Bleichmittel nur, wenn es den groessten
-- Anteil hat (IsoGameCharacter.DrinkFluid Z. 5480: getPrimaryFluid); mit
-- mehr sauberem Wasser halbiert Iron Gut auch das Bleichgift. Beides seit
-- dem Faktensweep 23.09.2026 in den Fussnoten.
TF.Static["irongut"] = {
    { id = "poison",   kind = "mult", value = 0.5, text = "UI_TF_eff_poison",
      note = "UI_TF_note_notbleach" },
    -- BodyDamage.JustAteFood: der Faktor wirkt nur im Wurf fuer verdorbenes
    -- Essen. Rohes gefaehrliches Essen vergiftet immer mit 15 x Portion,
    -- sobald die Chance ueber 0 liegt, mit und ohne Trait (Audit 12.09.2026).
    { id = "foodsick", kind = "mult", value = 0.5, text = "UI_TF_eff_foodsick",
      note = "UI_TF_note_spoiledonly" },
    -- IsoGameCharacter.DrinkFluid(FluidContainer, float, boolean), Z. 5496-5506:
    -- verseuchtes Wasser erst *0.75, mit Iron Gut dann poisonModified = 0.
    -- Genullt wird das Gift des ganzen Schlucks: liegt auch Bleichmittel im
    -- selben Behaelter, faellt es mit weg. Der alte Wert 0.5 stammte aus
    -- ISDrinkFromBottle.lua (basePoison 10, Iron Gut 5, Weak Stomach 15).
    -- Diese Datei ist in 42.20.4 unerreichbar: ISDrinkFromBottle wird nur
    -- von onDrinkForThirst erzeugt, das nur doDrinkForThirstMenu anbietet,
    -- und das ruft niemand mehr auf (Lua-Abgleich 10.09.2026). Getrunken
    -- wird ueber doDrinkFluidMenu -> ISDrinkFluidAction -> DrinkFluid.
    { id = "taintedwater", kind = "mult", value = 0.0, text = "UI_TF_eff_taintedwater",
      note = "UI_TF_note_taintedall" },
    { id = "rawegg",   kind = "info", text = "UI_TF_eff_rawegg" },
}

TF.Static["weakstomach"] = {
    { id = "poison",   kind = "mult", value = 2.0, text = "UI_TF_eff_poison",
      note = "UI_TF_note_nottainted" },
    -- Die verdoppelte Chance geht in Rand.Next(100) < Chance und ist damit bei
    -- 100 % am Ende. Die Grundchance ist (Tage ueber verdorben, 1 bis 5) /
    -- (DaysTotallyRotten - DaysFresh) x 100; bei den meisten Speisen liegt die
    -- Spanne bei 2 bis 4 Tagen, dort ist die Grundchance ein bis zwei Tage nach
    -- dem Verderben schon 50 % und mehr, und Weak Stomach aendert nichts mehr.
    -- Eigene Fussnote, Iron Gut behaelt spoiledonly: dessen x0.5 gilt immer
    -- (Faktensweep 23.09.2026).
    { id = "foodsick", kind = "mult", value = 2.0, text = "UI_TF_eff_foodsick",
      note = "UI_TF_note_spoiledcap" },
    -- IsoGameCharacter.DrinkFluid(FluidContainer, float, boolean), Z. 5507-5509:
    -- poisonModified = isTaintedWater ? *1.2f : *2.0f. Der Faktor 0.75 davor
    -- gilt fuer jeden Charakter und faellt beim Vergleich mit/ohne Trait
    -- heraus. Der alte Wert 1.5 kam aus dem toten ISDrinkFromBottle-Pfad.
    { id = "taintedwater", kind = "mult", value = 1.2, text = "UI_TF_eff_taintedwater" },
}

-- coldmild (seit 0.12.7, Entscheidung 20.09.2026, Mockup erkaeltung-fussnote,
-- Variante B): bei leichter Kaelte bringen Resilient und Outdoorsy keine
-- kleinere, sondern gar keine Erkaeltungsgefahr (Spielfehler
-- erkaeltung-schwelle, gemessen mit den Code-Werten). Eine eigene Zeile ohne
-- Zahl; beide Traits tragen denselben Text, die Uebersicht nennt sie in einer Zeile.
TF.Static["resilient"] = {
    { id = "cold",          kind = "mult", value = 0.45, text = "UI_TF_eff_cold" },
    { id = "coldmild",      kind = "info", text = "UI_TF_eff_coldmild", note = "UI_TF_note_gamequirk" },
    { id = "coldprogress",  kind = "mult", value = 0.8,  text = "UI_TF_eff_coldprogress" },
    { id = "coldrecovery",  kind = "mult", value = 1.5,  text = "UI_TF_eff_coldrecovery" },
    { id = "corpsesick",    kind = "mult", value = 0.75, text = "UI_TF_eff_corpsesick" },
    { id = "zombification", kind = "mult", value = 1.25, text = "UI_TF_eff_zombification" },
}

TF.Static["pronetoillness"] = {
    { id = "cold",          kind = "mult", value = 1.7,  text = "UI_TF_eff_cold" },
    { id = "coldprogress",  kind = "mult", value = 1.2,  text = "UI_TF_eff_coldprogress" },
    { id = "coldrecovery",  kind = "mult", value = 0.5,  text = "UI_TF_eff_coldrecovery" },
    { id = "corpsesick",    kind = "mult", value = 1.25, text = "UI_TF_eff_corpsesick" },
    { id = "zombification", kind = "mult", value = 0.75, text = "UI_TF_eff_zombification" },
}

-- Registry-Name OUTDOORSMAN, im Spiel "Outdoorsy".
TF.Static["outdoorsman"] = {
    { id = "cold",         kind = "mult", value = 0.25, text = "UI_TF_eff_cold" },
    { id = "coldmild",     kind = "info", text = "UI_TF_eff_coldmild", note = "UI_TF_note_gamequirk" },
    { id = "firelight",    kind = "mult", value = 2.0,   text = "UI_TF_eff_firelight",
      note = "UI_TF_note_bbqonly", case = "UI_TF_note_bbqonly" },
    { id = "kindling",     kind = "mult", value = 0.667, text = "UI_TF_eff_kindling",
      note = "UI_TF_note_bbqonly", case = "UI_TF_note_bbqonly" },
    -- getTraitWeatherPenaltyModifier liefert 1.0 statt 1.5, also exakt zwei
    -- Drittel. Als gerundete -33 % hat die Selbstpruefung angeschlagen; der
    -- Faktor ist der genauere Eintrag. Einzige Aufrufstelle ist
    -- CombatManager.getWeatherPenalty: der Wind- und Regenanteil der
    -- Trefferstrafe beim Schiessen im Freien.
    { id = "weatherpen",   kind = "mult", value = 0.6667, text = "UI_TF_eff_weatherpen",
      probe = "weatherPenalty" },
    -- Outdoorsy veraendert den AEUSSEREN Wurf in damageWhileInTrees: Basis 50,
    -- 30 beim Rennen, dazu der Kleidungsschutz des getroffenen Koerperteils.
    -- -50 % gilt genau beim Gehen ohne Kleidung, beim Rennen sind es -62,5 %,
    -- mit 30 Punkten Kleidung -38,5 % (Bugjagd 10.09.2026, Fund 14). Eine
    -- condition, keine Fussnote: mit Thick Skinned zusammen rechnet die
    -- Uebersicht sonst nicht mehr, und deren -77 % ist richtig. Und kein hint:
    -- der fiel in der Summe weg, obwohl die Bedingung auch fuer die -77 % gilt
    -- (Thick Skinned wirkt auf den inneren Wurf, den Kleidung und Rennen nicht
    -- beruehren; Hinweis 12.09.2026).
    { id = "treescratch",  kind = "pct",  value = -50,  text = "UI_TF_eff_treescratch",
      condition = "UI_TF_note_treebase" },
}

TF.Static["heartyappetite"] = {
    { id = "appetite", kind = "mult", value = 1.5,  text = "UI_TF_eff_appetite" },
}

TF.Static["lighteater"] = {
    { id = "appetite", kind = "mult", value = 0.75, text = "UI_TF_eff_appetite" },
}

TF.Static["highthirst"] = {
    { id = "thirst", kind = "mult", value = 2.0, text = "UI_TF_eff_thirst" },
}

TF.Static["lowthirst"] = {
    { id = "thirst", kind = "mult", value = 0.5, text = "UI_TF_eff_thirst" },
}

-- WEIGHT_GAIN heisst im Spiel "Slow Metabolism", WEIGHT_LOSS "Fast Metabolism".
-- Nutrition.java:122-129: caloriesToGainWeight ist 1000; mit Slow Metabolism
-- 700, solange das Gewicht unter 90 liegt, mit Fast Metabolism 1800, solange
-- es ueber 70 liegt. Danach kommt fuer alle (Gewicht - 80) * 40 dazu.
--
-- Das ist ein Tausch der Basis, kein Faktor. Bis 0.1.2 stand hier mult 0.7
-- und 1.8, und das stimmt nur bei Gewicht genau 80: bei 85 sind es 900 gegen
-- 1200, also -25 %, nicht -30 % (Bugjagd 10.09.2026, Fund 3). Dazu setzen
-- die Gewichts-Traits, die beide mitbringen, das Startgewicht auf 95 und 70:
-- Slow Metabolism wirkt beim Start gar nicht, Fast Metabolism ab dem ersten
-- Gramm ueber 70.
--
-- Weil der Aufschlag fuer alle derselbe ist, unterscheidet sich die Figur mit
-- Trait im Fenster immer um genau -300 und +800 Kalorien, bei jedem Gewicht.
-- Das steht als Wert da; die Basis 1000 und den Aufschlag nennt die Fussnote.
-- Ein Vorher/Nachher "1000 auf 700 Kalorien" passte nicht in die Wertspalte.
TF.Static["weightgain"] = {
    { id = "gainweight", kind = "flat", value = -300, text = "UI_TF_eff_gainweight",
      unit = "UI_TF_unit_calories", note = "UI_TF_note_gainweight_slow" },
}

TF.Static["weightloss"] = {
    { id = "gainweight", kind = "flat", value = 800, text = "UI_TF_eff_gainweight",
      unit = "UI_TF_unit_calories", note = "UI_TF_note_gainweight_fast" },
}

-- ---------------------------------------------------------------------------
-- Ausdauer und Bewegung (Bericht "Ausdauer und Bewegung")
-- ---------------------------------------------------------------------------

-- Zum `dead` an sprintspeed, einmal fuer alle fuenf Traits:
-- IsoPlayer.updateInternal2 legt in Z. 2139 `float delta = 1.0f` an und
-- multipliziert die Trait-Faktoren hinein (Athletic 1.2, Unfit 0.8, Out of
-- Shape 0.99, Obese 0.85, Overweight 0.99). Gelesen wird delta danach genau
-- einmal, in Z. 2357: `isWalking = delta > 0.0f`. Alle Faktoren sind positiv
-- und koennen das Vorzeichen nicht kippen, also aendern sie auch das Flag
-- nicht. Das gefahrene Tempo kommt aus calculateBaseSpeed, wo keiner der fuenf
-- Traits vorkommt. Die Zahl steht im Code und wirkt trotzdem nirgends.
--
-- Am 10.09.2026 zusaetzlich im Verhalten bestaetigt, weil eine "tot"-Aussage
-- die Aufruferliste braucht und nicht nur die Fundstelle (Lehre aus Handys
-- Bauwerks-Gesundheit). Drei Sprintlaeufe an einer lebenden Figur, je Phase
-- 100 sprintende Ticks, Trait an und aus im Wechsel, Ausdauer gehalten:
-- Athletic 1.0495, 0.9966 und 0.9940, Unfit 1.0112, 1.0082 und 0.9878 (Lauf d
-- ohne Aufwaermen und ohne Streuungsschaetzung; bis zum Faktensweep 23.09.2026
-- stand hier 1.0073 statt 1.0082 und ein gepaartes 1.0007 / 0.9993, das kein
-- Bericht enthaelt). Massgeblich ist der Lauf vom 13.09.2026
-- (docs/messungen/messung-2026-09-13-sprint.txt): Athletic 1.0012, Unfit
-- 0.9988. Ein Faktor 1.2 laege weit ausserhalb jeder dieser Streuungen.
-- Berichte in docs/messungen/messung-2026-09-10{d,e,f}-sprint.txt.
TF.Static["athletic"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
    { id = "sprintspeed",  kind = "pct",  value = 20,  text = "UI_TF_eff_sprintspeed",
      dead = true, note = "UI_TF_note_deadspeed" },
    { id = "enduranceloss", kind = "mult", value = 0.57, text = "UI_TF_eff_enduranceloss",
      note = "UI_TF_note_enddelta", case = "UI_TF_note_enddelta" },
    { id = "grapple",      kind = "mult", value = 1.25, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
}

TF.Static["unfit"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
    { id = "sprintspeed", kind = "pct", value = -20, text = "UI_TF_eff_sprintspeed",
      dead = true, note = "UI_TF_note_deadspeed" },
}

-- Fit hat sonst keine eigene Wirkung im Code: die Fitness-Stufe 6 bis 8 ist
-- alles, wofuer der Trait steht.
TF.Static["fit"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
}

TF.Static["outofshape"] = {
    -- Startstufe und Stufen-Satz: TF.Live.entries (getXpBoosts, seit 0.1.15).
    { id = "sprintspeed", kind = "pct", value = -1, text = "UI_TF_eff_sprintspeed",
      dead = true, note = "UI_TF_note_deadspeed" },
}

-- Registry-Name JOGGER, im Spiel "Runner". Der Trait wirkt ausschliesslich in
-- IsoGameCharacter.exert(), und diese Methode hat im gesamten Jar nur drei
-- Aufrufer: IsoDoor, OpenWindowState, CloseWindowState. Trotz des Namens hat
-- der Trait also nichts mit Laufen zu tun. Aufruferliste am 10.09.2026 mit
-- tools/jar-callers.py (Methodref-Eintraege aller 23740 Klassen) und einem
-- grep ueber media/lua bestaetigt.
TF.Static["jogger"] = {
    { id = "enduranceloss", kind = "pct", value = -10, text = "UI_TF_eff_enduranceloss",
      note = "UI_TF_note_doorswindows", case = "UI_TF_note_doorswindows" },
}

-- Registry-Name ASTHMATIC, im Spiel "Short of Breath". 1.0 statt 0.7 beim
-- Laufen und Tragen sind +42,9 %; beim Schwingen sind es getrennte +20 %.
-- Die +20 % treffen nur die Kosten je Schwung (CombatManager.processWeapon-
-- Endurance, Z. 1039-1040, Basis 0.18); was ein Treffer zusaetzlich kostet
-- (applyMeleeEnduranceLoss, Z. 3217-3242, Basis 0.28), kennt keinen Trait.
-- Ein voller Treffer kostet also insgesamt rund +8 % (Faktensweep 23.09.2026).
TF.Static["asthmatic"] = {
    { id = "enduranceloss", kind = "pct", value = 43, text = "UI_TF_eff_enduranceloss",
      note = "UI_TF_note_enddelta", case = "UI_TF_note_enddelta" },
    { id = "swingendurance", kind = "pct", value = 20, text = "UI_TF_eff_swingendurance",
      probe = "enduranceLoss", note = "UI_TF_note_swingonly" },
}

-- CarController.control_ForwardNew, Z. 669-673: die Motorkraft faellt erst
-- ueber `maxSpeed * 1.15` ab, statt ueber maxSpeed. Die 1.15 steht als
-- Konstante in CarController (tools/jar-constants.py, 10.09.2026).
--
-- Die Mod fuehrte daraus lange "+15 % Hoechstgeschwindigkeit". Der Schluss
-- war falsch: `maxSpeed * 1.15` ist kein Tempolimit, sondern der Punkt, ab
-- dem die Motorkraft abfaellt, und ein Auto faehrt weit darueber. Am
-- 10.09.2026 an fuenf Wagen gemessen (docs/messungen/messung-2026-09-10{h,i,j,k}-auto):
--
--   SmallCar   Skript  70   89.98 -> 100.43   1.1162
--   StepVan    Skript  70   90.14 -> 100.35   1.1133
--   PickUpVan  Skript  60   80.04 ->  88.92   1.1109
--   CarNormal  Skript  90  110.08 -> 122.40   1.1120   an der Schranke
--   SportsCar  Skript 120  122.40 -> 122.40   1.0000   schon ohne Trait dort
--
-- Nachweisgrenzen 0.13 bis 0.28 % je Lauf. Also rund +11 %, und zwar quer
-- ueber Masse 650 bis 1160 und Skriptwerte 60 bis 120.
--
-- Die Messungen folgen einer einfachen Regel, die alle fuenf Wagen ohne Trait
-- und alle fuenf mit Speed Demon auf zwei Zehntel km/h trifft:
--
--   erreichtes Tempo = Skript-maxSpeed * Trait-Faktor + 20, gekappt bei 122.4
--
-- Die 20 und die 34 (das sind 122.4 km/h in m/s) stehen beide als Konstanten
-- in zombie/vehicles/BaseVehicle. Der prozentuale Gewinn haengt damit am
-- Wagen: 11.25 % am PickUpVan, 11.7 % am SmallCar, nichts an einem, der schon
-- ohne Trait an der Schranke faehrt. Die +11 % sind der belegte Mittelwert.
--
-- Die Schranke: kein Fahrzeug kam ueber 122.400 km/h, exakt 34.0 m/s. Zwei
-- Wagen zeigten den Wert unabhaengig voneinander in je drei Phasen auf drei
-- Nachkommastellen gleich. 34.0 steht in zombie/vehicles/BaseVehicle, unter
-- allen 347 Klassen mit "vehicle" im Pfad nur dort. Belegt ist die Schranke
-- damit im Verhalten; die Konstante stuetzt sie, beweist sie aber nicht.
--
-- Wen es trifft: wer ohne Trait schon an der Schranke faehrt, gewinnt nichts.
-- Das sind die schnellen Wagen ab etwa 95 Skriptpunkten - CarLuxury (105),
-- SportsCar und CarRacecar (120), die Polizeiwagen (100).
TF.Static["speeddemon"] = {
    { id = "grapple",  kind = "mult", value = 1.15, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
    { id = "topspeed", kind = "pct",  value = 11,   text = "UI_TF_eff_topspeed",
      note = "UI_TF_note_topspeedcap" },
    -- Der addEngineSpeed-Term rechnet mit 0.06 statt 0.02, also Faktor 3 auf
    -- den Drehzahlaufbau. Uebrig ist davon nur control_Reverse, Z. 694-698:
    -- vorwaerts laeuft control_ForwardNew, und das hat den Term gar nicht.
    -- Die zweite Fassung control_Forward (Z. 463) traegt ihn zwar samt der
    -- Tempogrenze 50 statt 30, ist aber privat und hat in ihrer eigenen Datei
    -- keinen Aufrufer - update() ruft in Z. 236 control_ForwardNew.
    -- Rueckwaerts binden beide Zweige gleich: die Schranke `30.0f - speed`
    -- greift nie, weil speed dort negativ ist. Darum keine Tempoangabe.
    -- Aufruferliste am 10.09.2026 mit tools/jar-callers.py bestaetigt:
    -- control_Forward hat null Aufrufer, control_ForwardNew und
    -- control_Reverse je einen (CarController.update), Lua ruft keine.
    -- Am 11.09.2026 am SportsCar direkt abgelesen, nicht aus der Zeit
    -- erschlossen (docs/messungen/messung-2026-09-11e-beschleunigung.txt): die Drehzahl
    -- steigt rueckwaerts mit Trait auf das 2,52- bis 3,13-fache, je weiter
    -- der Anlauf, desto naeher an 3. Der Faktor 3 steht damit fest.
    --
    -- Was er wert ist, steht ebenfalls fest, und es ist wenig. Die Kraft
    -- haengt nur schwach an der Drehzahl:
    --
    --   engineForce = -enginePower * (0.75 + Drehzahl / 24000)
    --
    -- Aus dreifacher Drehzahl werden so 1.076 bis 1.124 an Kraft (SportsCar,
    -- bis 8 km/h) und 1.112 bis 1.181 (PickUpVan, bis 20 km/h). Gerechnet
    -- und gemessen weichen um hoechstens 0,25 % voneinander ab. In der Zeit
    -- sind es 11 statt 12 Ticks, also rund 8 % schneller rueckwaerts anfahren.
    -- Die Fussnote nennt darum 7.6 bis 18 % (bis zum Faktensweep 23.09.2026
    -- 10 bis 18 %, die 10 hatte keine Quelle).
    --
    -- Eine "mal 3" ohne diese Fussnote laese sich als dreifache
    -- Beschleunigung, und das waere die vierte falsche Fahrzeugzahl gewesen.
    { id = "rpmbuild", kind = "mult", value = 3.0,  text = "UI_TF_eff_rpmbuild",
      note = "UI_TF_note_rpmbuildreverse" },
    -- Die Drehzahl ist zugleich die Lautstaerke fuer Zombies.
    -- VehicleEngine.updateWorldSounds, am 12.09.2026 aus dem Bytecode gelesen:
    --
    --   R = loudness * Drehzahl / 2500
    --   jeden Tick Radius max(8, R/6), dazu je Tick mit 1/10 max(8, R/4),
    --   mit 1/35 max(8, R/2) und mit 1/120 max(8, R)
    --
    -- Aufgerufen aus VehicleEngine.update, sobald der Motor nicht aus ist, und
    -- BaseVehicle.update ruft das jeden Tick. loudness ist der Skriptwert mal
    -- Sandbox-Zombieanziehung durch 2, mit dem Auspuff-Zustand verrechnet
    -- (BaseVehicle.updatePartStats). In der ganzen Kette steht kein Trait:
    -- Speed Demon wirkt allein ueber die Drehzahl, und die ist rueckwaerts
    -- direkt abgelesen das 2.6- bis 3.4-fache (PickUpVan,
    -- docs/messungen/messung-2026-09-11f-pickupvan.txt, Fenster 2 bis 25 km/h), am
    -- SportsCar das 2.5- bis 3.1-fache. Vorwaerts 1.02, also nichts.
    --
    -- Der Faktor 3 gilt fuer die seltenen grossen Geraeusche. Die haeufigen
    -- kleinen haben eine Untergrenze von 8 Feldern und wachsen erst, wenn
    -- R/6 darueber liegt; ohne Trait liegt es rueckwaerts meist darunter.
    { id = "reversenoise", kind = "mult", value = 3.0, text = "UI_TF_eff_reversenoise",
      note = "UI_TF_note_reversenoise" },
}

-- CarController.control_ForwardNew, Offsets 826 bis 978, am 11.09.2026 aus
-- dem Bytecode gelesen: engineForce *= 0.75, und ab `maxSpeed * 0.6`
-- zusaetzlich `(maxSpeed * 0.75 + 20 - tempo) / 20`. Bei `0.75 M + 20` ist
-- die Kraft null, und dort endet das Tempo. Rueckwaerts (control_Reverse,
-- Offsets 271 bis 311): engineForce *= 0.7, und ab 3.3 km/h
-- `(15 + 1.5 * tempo) / 10`, null bei 10 km/h. Beide Absenkungen stehen im
-- Sunday-Driver-Zweig; ohne den Trait gibt es sie nicht.
--
-- Die Hoechstgeschwindigkeit war vom 10.09. bis 11.09.2026 gestrichen, weil
-- der Plateau-Test an PickUpVan und SmallCar keine Senkung sah (0.9999 und
-- 0.9977). Das war ein Artefakt des Tests: er setzte den Trait bei voller
-- Fahrt, also bei `maxSpeed + 20`, wo die gewoehnliche Absenkung null ist.
-- Das Produkt beider Faktoren ist dort praktisch null, der Wagen rollt nur
-- ganz langsam aus. Aus dem Stand gemessen
-- (docs/messungen/messung-2026-09-11f-pickupvan.txt, Auswertung im Lua-Abgleich):
--
--   PickUpVan vorwaerts   ohne 79.89 / 79.93   mit Trait 64.80   Formel 65.0
--   PickUpVan rueckwaerts ohne 27.11 / 27.13   mit Trait  9.999  Formel 10.0
--
-- -19 % gilt fuer gewoehnliche Wagen: (0.75 M + 20) / (M + 20) ist bei
-- maxSpeed 60 bis 90 minus 19 bis 21 %. Wer ohne Trait schon an der
-- Schranke von 122.4 km/h faehrt (SportsCar), verliert rund 10 %.
-- Rueckwaerts sind es 10 statt 27 km/h, bei jedem Wagen gleich, weil
-- maxSpeedReverse in keinem Fahrzeugskript ueberschrieben ist.
TF.Static["sundaydriver"] = {
    { id = "engineforce",  kind = "pct", value = -25, text = "UI_TF_eff_engineforce",
      note = "UI_TF_note_forcesunday" },
    { id = "topspeed",     kind = "pct", value = -19, text = "UI_TF_eff_topspeed",
      note = "UI_TF_note_topspeedsunday" },
    { id = "reverseforce", kind = "pct", value = -30, text = "UI_TF_eff_reverseforce" },
    { id = "reversespeed", kind = "pct", value = -63, text = "UI_TF_eff_reversespeed",
      note = "UI_TF_note_reversespeedsunday" },
}

TF.Static["gymnast"] = {
    { id = "climb",         kind = "flat", value = 4, text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase" },
    { id = "climbstrength", kind = "flat", value = 1, text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbstrengthbase" },
}

TF.Static["graceful"] = {
    { id = "footsteps", kind = "pct",  value = -40, text = "UI_TF_eff_footsteps" },
    { id = "trip",      kind = "flat", value = -10, text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase" },
    { id = "lungefall", kind = "flat", value = -10, text = "UI_TF_eff_lungefall",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_lungebase" },
}

TF.Static["clumsy"] = {
    { id = "footsteps", kind = "pct",  value = 20, text = "UI_TF_eff_footsteps" },
    { id = "trip",      kind = "flat", value = 10, text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase" },
    { id = "lungefall", kind = "flat", value = 10, text = "UI_TF_eff_lungefall",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_lungebase" },
    -- getClimbingFailChanceFloat: failChance /= 2, also die halbe Sicherheit.
    -- Die Halbierung trifft die Zwischensumme aus Skills, Moodles und
    -- Gewicht; die +-4 von Dextrous, Gymnast, Burglar, All Thumbs und
    -- Handschuhen kommen erst danach dazu. Mit Clumsy und Dextrous zusammen
    -- sind das (20 - ...) / 2 + 4, nicht (20 + 4) / 2. Darum bleiben es zwei
    -- Zeilen, und diese sagt, dass sie zuerst dran ist.
    { id = "climb",     kind = "pct",  value = -50, text = "UI_TF_eff_climb", note = "UI_TF_note_climbhalved" },
    { id = "canwound",  kind = "fromto", value = { 20, 30 }, text = "UI_TF_eff_canwound",
      note = "UI_TF_note_cooking1" },
}

-- ---------------------------------------------------------------------------
-- Schlaf (Bericht "Schlaf")
-- ---------------------------------------------------------------------------

-- NEEDS_LESS_SLEEP heisst im Spiel "Wakeful", NEEDS_MORE_SLEEP "Sleepyhead",
-- INSOMNIAC "Restless Sleeper".
-- Schlafdauer: ISWorldObjectContextMenu.lua rechnet die Stunden, die die Figur
-- schlaeft, aus der Muedigkeit, dann x 0.75 (Wakeful), x 1.18 (Sleepyhead),
-- x 0.5 (Restless Sleeper), und klemmt das Ergebnis auf 3 bis 16 Stunden.
-- IsoPlayer.updateStats_Sleeping: die noetigen Schlafstunden werden mit
-- traitMul multipliziert (Wakeful 0.75, Sleepyhead 1.18), und traitMul steht
-- im Nenner. Die Erholungsrate ist also 1/0.75 = +33 % und 1/1.18 = -15 %.
-- Der Schlaf laeuft in zwei Abschnitten: ueber Muedigkeit 0.3 baut er in
-- 5 Stunden 0.7 Punkte ab, darunter in 7 Stunden die restlichen 0.3; von
-- ganz muede bis ganz erholt sind das 12 Stunden Basis.
TF.Static["needslesssleep"] = {
    { id = "tiredness",     kind = "pct", value = -30, text = "UI_TF_eff_tiredness" },
    { id = "sleeprecovery", kind = "pct", value = 33,  text = "UI_TF_eff_sleeprecovery" },
    { id = "sleepduration", kind = "pct", value = -25, text = "UI_TF_eff_sleepduration",
      note = "UI_TF_note_sleepclamp" },
}

TF.Static["needsmoresleep"] = {
    { id = "tiredness",     kind = "pct", value = 30,  text = "UI_TF_eff_tiredness" },
    { id = "sleeprecovery", kind = "pct", value = -15, text = "UI_TF_eff_sleeprecovery" },
    { id = "sleepduration", kind = "pct", value = 18,  text = "UI_TF_eff_sleepduration",
      note = "UI_TF_note_sleepclamp" },
}

TF.Static["insomniac"] = {
    { id = "sleeprecovery", kind = "pct",  value = -50, text = "UI_TF_eff_sleeprecovery" },
    { id = "sleepduration", kind = "pct",  value = -50, text = "UI_TF_eff_sleepduration",
      note = "UI_TF_note_sleepclamp" },
    -- SleepingEvent.doDelayToSleep: `delay = 0.3f`, mit Insomniac `delay =
    -- 1.0f`; danach Schmerz, Stress und Bettqualitaet, dann Night Owl
    -- `delay *= 0.5f`, Deckel bei 2.0, und die Wartezeit wird gleichverteilt
    -- darunter gewuerfelt. Night Owl halbiert also auch diese Spanne - die
    -- Uebersicht verrechnet das (TF.Summary, scaleRanges), der Tooltip
    -- nennt nur den eigenen Wert.
    { id = "fallasleep",    kind = "range", value = { 0, 60 }, text = "UI_TF_eff_fallasleep",
      unit = "UI_TF_unit_minutes", note = "UI_TF_note_fallasleepbase" },
}

TF.Static["nightowl"] = {
    { id = "sleeprecovery", kind = "pct", value = 40,  text = "UI_TF_eff_sleeprecovery" },
    { id = "fallasleep",    kind = "pct", value = -50, text = "UI_TF_eff_fallasleep" },
}

-- ---------------------------------------------------------------------------
-- Wahrnehmung, Geraeusch, Stealth (Bericht "Wahrnehmung, Geraeusch, Stealth")
-- ---------------------------------------------------------------------------

-- Zwei getrennte Radien, beide in Kacheln, beide ums Hoeren:
--
--   getDetectionRange   in dem ein Zombie ausserhalb des Sichtkegels trotzdem
--                       bemerkt wird (TestIfSeen: dist < detectionRange).
--                       Basis 3.5, Deaf 2.0, Keen Hearing +3.0, Hard of
--                       Hearing -1.0.
--   noiseDistance       in dem eine Kachel behandelt wird, als laege sie im
--                       Sichtkegel (IsoGridSquare: dot = -1). Basis 2.0, Keen
--                       Hearing +3.0, Hard of Hearing -1.0. Bei Deaf laeuft
--                       die Pruefung gar nicht erst (`&& !hasTrait(DEAF)`),
--                       die Basis faellt also ersatzlos weg - im Ergebnis -2.
--
-- noiseDistance rechnet calculateVisibilityData, und gelesen wird er an genau
-- einer Stelle, in IsoGridSquare.CalcVisibility (Z. 7729-7735). Beide ruft nur
-- der ServerLOS-Thread (ServerLOS Z. 271, 277), den allein GameServer.main
-- startet (Z. 831, dort server = true in Z. 408). Und in CalcVisibility steht
-- die Pruefung samt Deaf-Abfrage in `if (!GameServer.server)`: auf dem Server,
-- der sie als einziger ausfuehrt, faellt sie weg. Im Einzelspiel und auf dem
-- Client sieht die Figur ueber LightingJNI.playerSet (updatePlayer Z.
-- 481-484); von den Hoerradien kommt dort nur getDetectionRange an, dazu
-- Kegel, Muedigkeit und das Short-Sighted-Flag. Der Radius wird also
-- berechnet und nie gelesen, in keiner Spielart. Seit dem Faktensweep
-- 23.09.2026 dead; bis dahin sagte die Fussnote "nur auf Multiplayer-Servern"
-- (Audit 12.09.2026), und das hatte die Server-Abfrage uebersehen.
-- Spielfehler noisedistance-mp.
TF.Static["deaf"] = {
    { id = "detection", kind = "flat", value = -1.5, text = "UI_TF_eff_detection",
      unit = "UI_TF_unit_tiles", note = "UI_TF_note_detectionbase" },
    { id = "noise",     kind = "flat", value = -2.0, text = "UI_TF_eff_noiseradius",
      unit = "UI_TF_unit_tiles", dead = true, note = "UI_TF_note_noisedeaf" },
    -- Gemessen ist der Stress: Weltgeraeusche geben einer tauben Figur keinen
    -- (IsoGameCharacter.updateStress Z. 9209). Nicht hoeren, Wecker und
    -- Radiotext stehen im Code (Radio, WaveSignalDevice, AlarmClock); den Ton
    -- selbst stellt FMOD ueber ParameterDeaf stumm, das ist aus Java nicht
    -- lesbar. Text seit dem Faktensweep 23.09.2026 mit dem Stress vorn.
    { id = "sounds",    kind = "info", text = "UI_TF_eff_nosounds" },
}

TF.Static["keenhearing"] = {
    { id = "detection", kind = "flat", value = 3.0, text = "UI_TF_eff_detection",
      unit = "UI_TF_unit_tiles", note = "UI_TF_note_detectionbase" },
    { id = "noise",     kind = "flat", value = 3.0, text = "UI_TF_eff_noiseradius",
      unit = "UI_TF_unit_tiles", dead = true, note = "UI_TF_note_noisebase" },
}

TF.Static["hardofhearing"] = {
    { id = "detection", kind = "flat", value = -1.0, text = "UI_TF_eff_detection",
      unit = "UI_TF_unit_tiles", note = "UI_TF_note_detectionbase" },
    { id = "noise",     kind = "flat", value = -1.0, text = "UI_TF_eff_noiseradius",
      unit = "UI_TF_unit_tiles", dead = true, note = "UI_TF_note_noisebase" },
    -- getHearDistanceModifier (x4.5) lesen im Einzelspiel nur AlarmClock
    -- (Z. 181) und AlarmClockClothing (Z. 191): ein Wecker weckt erst aus
    -- 1/4.5 seiner Reichweite. FMODParameterUtils.getClosestListener und
    -- ParameterFirearmInside kehren bei einem einzigen Spieler vorher zurueck
    -- und waehlen damit nur bei mehreren lokalen Spielern den Hoerer, ohne die
    -- Lautstaerke zu aendern. Den gedaempften Klang setzt ParameterHardOfHearing,
    -- nur an oder aus, ohne die 4.5. Bis zum Faktensweep 23.09.2026 hiess die
    -- Zeile "Geraeusche wirken weiter weg", die Fussnote nannte die Daempfung.
    { id = "hearing",   kind = "mult", value = 4.5,  text = "UI_TF_eff_hearing",
      probe = "hearDistance", note = "UI_TF_note_hearingalarm" },
}

-- Sichtfeld: im Einzelspiel und auf dem Client kommt der Kegel aus
-- LightingJNI.calculateVisionCone und geht an LightingJNI.playerSet, und das
-- ist der Kegel, mit dem die Figur wahrnimmt. Dort steht
-- `cone += 36 * dayLightStrength` fuer Eagle Eyed, also nur bei Tag, 144 auf
-- 180 Grad - und Cat's Eyes bekommt in derselben Methode
-- `cone += 36 * dayLightStrengthInverted`, also nur bei Nacht. Die beiden
-- ergaenzen sich zu rund 36 Grad ueber den ganzen Tag, sie summieren sich
-- nicht auf 72. Darum tragen sie verschiedene Bezeichnungen: wer zweimal
-- "Field of view: +36 Grad" untereinander liest, addiert sie im Kopf.
--
-- Die +0.2 in calculateVisibilityData, die bis 0.1.22 hier als
-- tageszeitunabhaengig stand, rechnet nur der ServerLOS-Thread eines
-- Multiplayer-Servers (Audit 12.09.2026); dort wirkt sie, denn der Kegel wird
-- in CalcVisibility ausserhalb der Server-Abfrage gelesen (Z. 7737). Trait
-- Facts zeigt sie nicht; mit dem Hoerradius (Spielfehler noisedistance-mp)
-- hat die +36-Grad-Zeile nichts zu tun (Faktensweep 23.09.2026).
TF.Static["eagleeyed"] = {
    { id = "lightcone",   kind = "flat", value = 36, unit = "UI_TF_sym_deg",
      text = "UI_TF_eff_lightcone", note = "UI_TF_note_conedeg" },
    { id = "weaponsight", kind = "mult", value = 1.2, text = "UI_TF_eff_weaponsight" },
    { id = "fadein",      kind = "mult", value = 1.5, text = "UI_TF_eff_fadein" },
}

-- Registry-Name NIGHT_VISION, im Spiel "Cat's Eyes".
-- Cat's Eyes kommt nur in LightingJNI.calculateVisionCone vor, und das ist im
-- Einzelspiel der Wahrnehmungskegel (siehe Eagle Eyed): nachts 18 auf 54
-- Grad, der Zuschlag verblasst mit dem Tageslicht. Bis 0.1.22 stand hier,
-- er weite nur den gezeichneten Kegel; das galt nur fuer den Server.
TF.Static["nightvision"] = {
    { id = "nightcone", kind = "flat", value = 36, unit = "UI_TF_sym_deg",
      text = "UI_TF_eff_nightcone", note = "UI_TF_note_conenight" },
    -- RenderSettings.PlayerRenderSettings.updateRenderSettings: liegt der
    -- Ambient-Wert unter 0.20, wird er auf 0.20 gehoben - und erst danach
    -- laeuft die Umrechnung ambient = ambientMin + (1 - ambientMin) x
    -- ambient. Auf dem Bildschirm kommt also nie 0.20 an, sondern bei der
    -- Standardeinstellung Nachtdunkelheit 3 (ambientMin 0.15) rund 0.32.
    -- Weder Prozent noch Faktor: eine Untergrenze auf einer Zwischengroesse,
    -- darum kind = "info" mit der Rechnung in der Fussnote.
    { id = "ambient",   kind = "info", text = "UI_TF_eff_nightambient",
      note = "UI_TF_note_nightambient" },
}

-- IsoZombie.spotted verzweigt an SandboxOptions.lore.spottedLogic (Vanilla
-- nennt den Schalter "New Stealth System", Standard an). spottedNew rechnet
-- traitMod 0.8 / 1.2, spottedOld dagegen chance *= 0.5 / 2.0. Wer die Option
-- ausschaltet, bekommt also ganz andere Zahlen; jeder Trait nennt in seiner
-- Fussnote nur die eigene.
TF.Static["inconspicuous"] = {
    { id = "spotted", kind = "pct", value = -20, text = "UI_TF_eff_spotted",
      note = "UI_TF_note_spotted_low" },
}

TF.Static["conspicuous"] = {
    { id = "spotted", kind = "pct", value = 20,  text = "UI_TF_eff_spotted",
      note = "UI_TF_note_spotted_high" },
}

-- Smoker wirkt in BodyDamage (Nikotinentzug, Erkaeltungslogik) und in
-- RecipeCodeOnEat. Die Zahlen stehen im jeweiligen Item, nicht im Trait.
TF.Static["smoker"] = {
    { id = "nicotine", kind = "info", text = "UI_TF_eff_smoker" },
}

-- ---------------------------------------------------------------------------
-- Inventar, Bauen, Handwerk (Bericht "Inventar, Bauen, Handwerk")
-- ---------------------------------------------------------------------------

-- ItemContainer.getEffectiveCapacity: der Bonus faellt nur weg, wenn der
-- Behaelter das Hauptinventar einer Figur ist (parent instanceof
-- IsoGameCharacter), eine Leiche, oder den Typ "floor" traegt. Getragene
-- Taschen und Fahrzeugbehaelter sind also dabei - die alte Fussnote
-- "world containers only, not carried bags" sagte das Gegenteil. Dazu je
-- eine Untergrenze: Organized mindestens capacity + 1, Disorganized nie
-- unter 1.
TF.Static["organized"] = {
    { id = "container", kind = "pct", value = 30, text = "UI_TF_eff_container",
      note = "UI_TF_note_container_more" },
}

TF.Static["disorganized"] = {
    { id = "container",   kind = "pct", value = -30, text = "UI_TF_eff_container",
      note = "UI_TF_note_container_less" },
    { id = "ingredients", kind = "info", text = "UI_TF_eff_ingredients" },
}

-- Handy zieht feste Betraege von Aktionsdauern ab, deren Basis mit Carpentry
-- sinkt. Aktionseinheiten sagen dem Spieler nichts, deshalb steht hier der
-- Prozentwert bei Carpentry 0 mit dem Hinweis, dass er mit der Stufe waechst:
--   Bauen (ISBuildAction):        200 - 5 x Carpentry, minus 50  -> -25 % .. -33 %
--   Barrikadieren (Bretter):      100 - 5 x Carpentry, minus 20  -> -20 % .. -40 %
--   Barrikade entfernen:          200 - 5 x Carpentry, minus 20  -> -10 % .. -13 %
-- Lebenspunkte: die +100 stehen in buildUtil.getWoodHealth, erreichbar nur
-- ueber ISBuildIsoEntity:getHealth (kein Aufrufer) und die Altklassen
-- ISWoodenWall, ISSimpleFurniture, ISWoodenDoor und Geschwister. Die werden
-- in 42.20.4 nur noch im Tutorial und in Debug-Szenarien erzeugt. Was das
-- Baumenue setzt, rechnet ISBuildIsoEntity:setInfo aus Skriptwerten
-- (baseHealth + bonusHealth + Skillstufe x skillBaseHealth), ohne jede
-- Trait-Abfrage. Der Wert steht also im Code und wirkt im Spiel nicht.
TF.Static["handy"] = {
    -- Bauen im neuen System (ISBuildIsoEntity): die Dauer ist die Rezeptzeit
    -- (Waende 200), Handy zieht fest 50 ab. -25 % gilt fuer Waende auf jeder
    -- Carpentry-Stufe; kurze Rezepte verlieren anteilig mehr, lange weniger
    -- (Audit 12.09.2026). 200 - 5 x Carpentry gilt nur noch in den Altklassen.
    -- ISBuildAction.lua Z. 268-270 zieht ohne Untergrenze ab: Rezepte mit Zeit
    -- 50 (etwa die Haelfte des Baumenues, alle Moebel) landen bei 0, und
    -- BaseAction.finished ist dann im ersten Tick wahr, der Bau geht sofort.
    -- Nur aus dem Code gelesen, nicht im Spiel nachgebaut. Auf einem
    -- MP-Server rechnet der Server die Dauer selbst (BuildAction.getDuration:
    -- 200 - 5 x Carpentry, Handy -50), dort -25 bis -33 % (Faktensweep
    -- 23.09.2026).
    { id = "buildtime",   kind = "pct",  value = -25, text = "UI_TF_eff_buildtime",
      note = "UI_TF_note_buildflat" },
    -- buildUtil.getWoodHealth: Carpentry x 50, mit Handy + 100. Gelesen nur
    -- von ISBuildIsoEntity:getHealth, das niemand aufruft, und von den
    -- Altklassen (ISWoodenWall und Geschwister), die in 42.20.4 nur Tutorial,
    -- Tests, Debug-Befehle und Trailer-Szenarien erzeugen; ISEmptyGraves aus
    -- dem Kontextmenue ruft getHealth nicht auf. Der Lua-Abgleich vom
    -- 10.09.2026 hatte das Gegenteil eingetragen, die Aufruferliste
    -- widerlegt ihn (Audit 12.09.2026). Also dead.
    { id = "durability",  kind = "flat", value = 100, text = "UI_TF_eff_durability",
      unit = "UI_TF_unit_hp", dead = true, note = "UI_TF_note_deadspeed" },
    -- ISBarricadeAction:getDuration (100 - 5 x Carpentry, Handy -20). Seit 0.13.5
    -- dead: die Aktion ruft in 42.20.4 nur noch die Testdatei des Spiels auf
    -- (client/Tests/TimedActionsTests.lua). Spieler verbarrikadieren ueber das
    -- Baumenue (ISWorldObjectContextMenu.onBarricade, ISBuildIsoEntity), Rezeptzeit
    -- 200 fuer Bretter wie Metallplatte, Handy zieht dort 50 ab wie bei jedem Bau;
    -- das deckt die Zeile buildtime ab. Aufgefallen am 21.09.2026 beim Nachstellen
    -- im Spiel: gemessen war die Aktion selbst, nicht der Weg des Spielers.
    { id = "barricade",   kind = "pct",  value = -20, text = "UI_TF_eff_barricade",
      dead = true, note = "UI_TF_note_deadbarricade" },
    { id = "unbarricade", kind = "pct",  value = -10, text = "UI_TF_eff_unbarricade",
      note = "UI_TF_note_carp0" },
}

TF.Static["illiterate"] = {
    { id = "reading", kind = "info", text = "UI_TF_eff_illiterate" },
}

TF.Static["nutritionist"] = {
    { id = "nutrition", kind = "info", text = "UI_TF_eff_nutrition" },
}

-- Die kostenlose Berufsfassung mit derselben Wirkung: Food.DoTooltip prueft
-- NUTRITIONIST oder NUTRITIONIST2 in derselben ODER-Kette. Die
-- Foraging-Werte des Traits stehen ohnehin in forageSkills.lua und kommen
-- ueber TF_Live; hier fehlte nur die Naehrwertzeile.
TF.Static["nutritionist2"] = TF.Static["nutritionist"]

TF.Static["wildernessknowledge"] = {
    { id = "firelight", kind = "mult", value = 2.0,   text = "UI_TF_eff_firelight",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly" },
    { id = "kindling",  kind = "mult", value = 0.667, text = "UI_TF_eff_kindling",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly" },
}

-- Registry-Pfad "formerscout", im Spiel "Former Scout". Das Java-Feld heisst
-- CharacterTrait.SCOUT, aber getType():getName() liefert den Registry-Pfad,
-- nicht den Feldnamen (Registries.CHARACTER_TRAIT.getLocation(this).getPath()).
-- Bis zum Review am 10.09.2026 stand hier "scout", und der Trait fand seine
-- beiden Zeilen nie. Einziger Trait, bei dem Feld und Pfad auseinanderliegen.
TF.Static["formerscout"] = {
    { id = "firelight", kind = "mult", value = 2.0,   text = "UI_TF_eff_firelight",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly" },
    { id = "kindling",  kind = "mult", value = 0.667, text = "UI_TF_eff_kindling",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly" },
}

TF.Static["burglar"] = {
    -- OpenWindowState: Rand.Next(100) < 10, mit Burglar 5, nur fuer ein
    -- verschlossenes Fenster, das von aussen aufgebrochen wird.
    { id = "windowlock", kind = "pct",  value = -50, text = "UI_TF_eff_windowlock",
      note = "UI_TF_note_windowforced" },
    { id = "hotwire",    kind = "info", text = "UI_TF_eff_hotwire" },
    { id = "climb",      kind = "flat", value = 4,   text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase" },
    { id = "climbstrength", kind = "flat", value = 1, text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbstrengthbase" },
}

-- ---------------------------------------------------------------------------
-- Zweiter Extraktionsdurchgang: Wirkungen, die ueber Zugriffsmethoden oder
-- ueber Lua laufen und dem ersten Durchgang deshalb entgangen sind.
-- ---------------------------------------------------------------------------

-- Inventive wird in der Engine nur ueber den Getter isInventive() geprueft
-- (`return this.hasTrait(INVENTIVE, INVENTIVE_PROF)`). Die Wirkung steht in
-- zombie/scripting/entity/components/crafting/CraftRecipe:
--   validateHasAutoLearnAnySkill und validateHasAutoLearnAllSkill: --level,
--     danach max(1, level)
--   Forschungsstufe: level -= 2
-- Beide Fassungen des Traits, die kaufbare und die des Berufs, wirken gleich.
TF.Static["inventive"] = {
    { id = "autolearn", kind = "flat", value = -1, text = "UI_TF_eff_autolearn",
      unit = "UI_TF_unit_levels" },
    { id = "research",  kind = "flat", value = -2, text = "UI_TF_eff_research",
      unit = "UI_TF_unit_levels" },
}
-- Die Berufsfassung wirkt identisch, isInventive() prueft beide.
TF.Static["inventiveprof"] = TF.Static["inventive"]

-- Fast Reader und Slow Reader stehen im gesamten Jar nur in der Registry und im
-- Definitions-Generator. Ihre Wirkung liegt in Lua:
-- shared/TimedActions/ISReadABook.lua, `time = time * 0.7` bzw. `* 1.3`, wobei
-- `time` die Lesedauer ist.
-- Zeit ist nicht Tempo: -30 % Zeit sind +42,9 % Tempo (1 / 0.7), +30 % Zeit
-- sind -23,1 % Tempo (1 / 1.3). Genau diese Verwechslung war der Anlass der
-- Mod; der Hinweis sagt es dem Spieler am Trait selbst (Audit 20.09.2026).
-- Als hint: in einer Summe mehrerer Traits gehoert er keinem allein.
TF.Static["fastreader"] = {
    { id = "readtime", kind = "mult", value = 0.7, text = "UI_TF_eff_readtime",
      hint = "UI_TF_note_readfast" },
}

TF.Static["slowreader"] = {
    { id = "readtime", kind = "mult", value = 1.3, text = "UI_TF_eff_readtime",
      hint = "UI_TF_note_readslow" },
}
