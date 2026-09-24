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
-- jeweils nur wenn !weapon.isRanged(). Gemessen ist der Getter. Verbraucht
-- wird hitForce im Einzelspiel vor allem als Schwelle: die Taumel-Animation des
-- Zombies waehlt ueber 0.4 den langen Stoss-Taumel (Zombie_ShoveStagger_2m,
-- AnimSets/zombie/staggerback/defaultStaggerBack.xml), darunter den kurzen
-- (GeneralStagger.xml, smallFromFront.xml). Von hinten spielen beide Zweige
-- denselben Clip (smallFromBehind.xml erbt Zombie_PushedFwd_FromBehind von
-- fromBehind.xml), dort sieht man keinen Unterschied; darum sagt die Fussnote
-- seit dem Faktensweep 3 (23.09.2026) "von vorn oder von der Seite".
-- StaggerBackState.getMaxStaggerTime liest hitForce ausserdem als 35 x Kraft,
-- geklemmt auf 20 bis 30 (Z. 57-65). Bis 0.14.14 stand hier, bei Stosskraeften
-- um 0.4 bis 0.56 greife die Untergrenze 20: 0.4 / 0.56 waren aber im Zweig
-- des Waffentreffers gemessen, der die Kraft fuer Spieler verdoppelt
-- (IsoGameCharacter Z. 5786-5788); echte Stoesse liegen bei 0.04 bis 0.79.
-- Im Spiel ausgespielt am 24. und 25.09.2026 (Test Schubsen, je 110 Stoesse,
-- docs/messungen/messung-2026-09-25-schubsen.txt): die Schwelle 0.4
-- entscheidet in 110 von 110 Stoessen zwischen langem und kurzem Taumel. Von
-- vorn gegen einen bekleideten Zombie bekam der lange Taumel ohne Trait 13 %,
-- mit Strong 50 %, mit Puny 0 %; Kleidung am getroffenen Teil schluckt den
-- groessten Teil eines Stosses (CombatManager Z. 928-949, 3245-3300). Beide
-- Taumel schieben den Zombie fast gleich weit, lang 0.66 m, kurz 0.59 m, beide
-- rund 77 Ticks; der Clipname "2m" taeuscht. Die Fussnote sagte bis 0.14.14
-- "etwa 2 m zurueck oder nur einen Schritt", seit 0.14.15 "etwa eine halbe
-- Kachel". StaggerBack gibt es nur ohne
-- ZombieHitReaction (CombatManager Z. 2410-2416), und jede Nahkampf-
-- Schwunganimation setzt eine; es bleiben also die Stoesse. Die zur Kraft
-- proportionale Schubstrecke (calcHitDir, Z. 13628-13643) ruft nur
-- HitReactionNetworkAI im Multiplayer. Darum heisst die Zeile seit dem
-- Faktensweep 2 (23.09.2026) "Schlagkraft" mit der Schwelle in der Fussnote,
-- nicht mehr "Rueckstoss".
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
      note = "UI_TF_note_hitforce" },
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
      note = "UI_TF_note_hitforce" },
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

-- Ax-pert: getChopTreeSpeed() liefert 1.0 statt 0.8, im Getter +25 %. Die
-- Probe chopTreeSpeed stand hier bis zum Faktensweep 2 (23.09.2026) ohne
-- Eintrag in TF.Probes, lief also nie; das Wiki zeigte trotzdem "Live".
-- Die Faell-Animation (AnimSets/player/actions/chop_tree.xml)
-- fuehrt ChopTreeSpeed als m_SpeedScale, der Clip dauert 1.0 s, der Hieb
-- faellt bei 0.35: mit Ax-pert ein Hieb je 1.0 s, ohne je 1.25 s, x1.25.
-- Bis 0.13.9 stand die Zeile als dead, weil der Takt am 13.09.2026 in drei
-- Laeufen mit und ohne Ax-pert bei 1250 ms blieb. Das war ein Artefakt des
-- Tests (Faktensweep 23.09.2026): das Spiel liest die Geschwindigkeit nur,
-- wenn der Animationsknoten startet (AnimLayer.startLiveNodeTracks), und der
-- Test schaltete den Trait um, waehrend der Knoten weiterlief (clear und
-- doChopTree im selben Tick); jede Phase lief so mit dem Tempo der ersten,
-- und die war immer ohne Ax-pert. Nachgemessen am 23.09.2026 mit Mess-Mod
-- 6.43.1 (Trait vor dem Start, Pause bis die Animation aus ist,
-- docs/messungen/messung-2026-09-23-axt.txt): mit 997,6 ms, ohne 1249,9 ms
-- je Hieb, 0.7982. Die +25 % stimmen, Stand gemessen. Wiederholt am
-- 25.09.2026 (messung-2026-09-25-axt.txt): 999.0 gegen 1248.1 ms, 0.8004.
-- Das alles gilt nur im Einzelspiel (Faktensweep 2, 23.09.2026): im
-- Multiplayer, auch beim Hosten, landet der Server die Hiebe selbst
-- (ISChopTreeAction.lua Z. 64-68 nur `not isClient()`, serverStart Z. 108-111
-- emulateAnimEvent(1500, "ChopTree"), LuaManager Z. 9585-9589,
-- AnimEventEmulator.update wiederholt alle 1500 ms), mit und ohne Ax-pert
-- ein Hieb alle 1,5 s. Der Baumschaden x 1.5 laeuft dort ebenfalls auf dem
-- Server und gilt weiter. Die Fussnote sagt es.
-- Der Baumschaden steigt auf x 1.5, nur fuer Waffen der Kategorie AXE;
-- gemessen am 13.09.2026: 35 -> 53 je Hieb, 1.50 ueber 24 Hiebe; am
-- 25.09.2026 wieder 35 -> 53.
-- Axt-Schwungzeit: dieselbe 0.8 bremst ohne Ax-pert jeden Schlag mit einer
-- Axt. calculateCombatSpeed (IsoGameCharacter:8836) multipliziert bei Aexten
-- mit getChopTreeSpeed(), und CombatManager.pressedAttack (:2660) macht daraus
-- CombatSpeed, das Tempo der Schwung-Animation. Die 0.8 trifft aber nur den
-- Grundterm 0.8 x BaseSpeed; danach kommen ohne Trait-Bezug +0.03 je
-- Waffenstufe, +0.02 je Fitness-Stufe und -0.07 je Stufe Erschoepfung und
-- Ueberladung dazu, dann Rand.Next(1.1, 1.2) und die Klemme 0.8 bis 1.6.
-- Laut Code also kein fester Faktor. Ax-pert gibt es nur ueber den Beruf
-- Lumberjack (character_professions.txt Z. 124-132). Langsame Waffen der
-- Kategorie Axt (Spitzhacke BaseSpeed 0.8, Cudgel 0.85, ScrapCleaver 0.9)
-- liegen ohne Trait an oder nahe der Klemme 0.8, dort bringt der Trait
-- deutlich weniger.
-- Bis 0.14.14 standen hier und in der Fussnote Zahlen aus diesem Modell
-- (Axt 2 -17 %, Axt 3 -16 %, Axt 10 mit Fitness 10 -12 %, Spitzhacke -6 bis
-- -13 %). Gemessen ist mehr: die Schwungdauer folgt 1/CombatSpeed nicht.
-- Schlaege in die Luft, Takt mit/ohne (Axt: Ax-pert und Axt-Schwung bei
-- anderem Skill, 13.09. bis 25.09.2026): Axt bei Axt 3 und Fitness 5 0.79 bis
-- 0.80 (13. und 23.09.) und 0.763 (25.09.), bei Axt 0 und Fitness 5 0.790
-- (25.09., am 24.09. 0.769), bei Axt 10 und Fitness 10 0.833 (am 24.09.
-- 0.817); Spitzhacke bei Axt 0 und Fitness 5 0.934 (am 24.09. 0.919). Mit der
-- Axt also -17 bis -24 %, mit der Spitzhacke -7 bis -8 %. Die Zeile zeigt
-- weiter -20 %, die Fussnote seit 0.14.15 die gemessene Spanne. Bis 0.1.23
-- stand hier -5 %, wirkungslos: die x 0.95 in HandWeapon.getSpeedMod hat
-- wirklich keinen Aufrufer (Spielfehler speedmod-axeman), aber sie ist nicht
-- der Weg, auf dem Ax-pert wirkt.
TF.Static["axeman"] = {
    { id = "chopspeed",  kind = "pct", value = 25,  text = "UI_TF_eff_chopspeed",
      note = "UI_TF_note_chophit" },
    { id = "axeswing",   kind = "pct", value = -20, text = "UI_TF_eff_axeswing",
      note = "UI_TF_note_axeswing" },
    { id = "treedamage", kind = "pct", value = 50,  text = "UI_TF_eff_treedamage",
      note = "UI_TF_note_axeonly" },
}

-- ---------------------------------------------------------------------------
-- Gewicht (Bericht "Nahkampf, Kraft, Tragen", "Ausdauer", "Klettern")
-- ---------------------------------------------------------------------------

-- Nahkampfschaden: CombatManager Z. 819-821 multipliziert den Schaden jedes
-- Nahkampftreffers mit getTraitDamageDealtReductionModifier. Ein Tritt auf
-- einen liegenden Zombie (isAimAtFloor und isDoShove) ueberschreibt
-- damageSplit danach mit eigener Formel (Z. 846-850), der Trait faellt dort
-- weg; ein Stoss im Stehen macht ohnehin keinen Schaden (Z. 593-595). Darum
-- die Fussnote (Faktensweep 2, 23.09.2026).
TF.Static["underweight"] = {
    { id = "meleedamage", kind = "pct", value = -20, text = "UI_TF_eff_meleedamage",
      probe = "damageDealt", note = "UI_TF_note_meleeswings" },
}

-- Stolpern: ClimbOverFenceState.shouldFallAfterVaultOver wuerfelt Rand.Next(100)
-- gegen einen Zaehler, Basis 0 (10 beim Sprinten), also Prozentpunkte. Der
-- Engine-Bug ist im Bericht belegt: VERY_UNDERWEIGHT wird zweimal abgefragt
-- (+20, dann +10), gemeint war vermutlich UNDERWEIGHT. Effektiv +30.
-- Der Wurf ist Rand.Next(100) < Zaehler - Fitness (Z. 529): ein negativer
-- Zaehler wirkt wie 0. Im Laufen ohne Moodles liegt die Basis schon ab
-- Fitness 1 unter 0 und schluckt einen Teil der Trait-Punkte. Die
-- Gewichts-Traits senken die Fitness nur, wenn sie bei der Erschaffung
-- vergeben werden (XPBoosts wirken nur in applyTraits). Das gibt es nur fuer
-- High Weight, ueber Slow Metabolism (GrantedTraits, Fitness 4). Very High
-- Weight, Very Low Weight und Emaciated sind IsProfessionTrait mit Kosten 0
-- bzw. -10, in der Charaktererstellung nicht waehlbar, und nichts vergibt
-- sie; sie kommen nur im Spiel ueber Nutrition.applyTraitFromWeight, und die
-- Fitness bleibt (Faktensweep 3, 23.09.2026; bis dahin rechneten die hints
-- mit einer neuen Figur mit Fitness 3, die es nicht gibt). Laufen/Sprinten:
-- ohne Trait 0/5 %, High Weight (neue Figur, Fitness 4) 6/16 %, Very High
-- Weight bei Fitness 5 15/25 %, Very Low Weight bei Fitness 5 25/35 %,
-- Graceful 0/0 %, Clumsy 5/15 %.
-- Im Laufen gemessen am 24. und 25.09.2026 (Code-Werte, Gruppe zaunrennen,
-- VaultOverRun bei Fitness 5, je 3000 Proben): ohne Trait 0 %, High Weight
-- +5.1 und +5.2, Very High Weight +15.2 und +14.3, Very Low Weight +26.6 und
-- +26.3, Clumsy +5.2 und +4.8, Graceful 0 Punkte (laut Code +5/+15/+25/+5/0).
-- Der Zaehler steigt je Stufe des Erschoepfungs-Moodles (MoodleType.ENDURANCE,
-- im Spiel "Ausser Atem" und schlimmer) um 10, nicht mit Muedigkeit; ab Stufe
-- 3 ist isRunning() falsch und der Wurf im Laufen entfaellt (Faktensweep 3).
-- Die Beispiele stehen je Trait als hint, damit die Uebersicht die Punkte
-- mehrerer Traits weiter in einer Zeile summiert (Faktensweep 2, 23.09.2026).
--
-- Klettern: IsoGameCharacter.getClimbingFailChanceFloat ist trotz des Namens
-- ein Sicherheitswert, Basis Fitness x 2 + Strength x 2 + Nimble x 2, bei
-- einer neuen Figur 20, davon die ganzzahlige Wurzel. Verbraucht wird er vor
-- allem an hohen Zaeunen (ClimbOverWallState Z. 296-311): scheitern mit 1 zu
-- Wurzel; bei Wurzel 0 gelingt es nur mit (Strength + 1) %, mit Schwerer Last
-- nie, und die Wegfindung fuehrt nicht mehr ueber hohe Zaeune
-- (PathFindRequest Z. 77). Wurzel 1 (Summe 1 bis 3) scheitert immer, weil
-- Rand.NextBool(1) immer wahr ist (RandInterface Z. 24-25), schlechter als 0
-- (Spielfehler kletterwert-eins). Mit echtem Wurf gemessen am 24. und
-- 25.09.2026 (Code-Werte, Gruppen zaunhoch bis zaunhochneuwurf, Fitness 5,
-- Strength 5, Nimble 0, ohne Handschuhe): Fehlschlag ohne Trait 25 %, High
-- Weight 50 %, Very High Weight 94 %, Beruf Burglar 20 % (im Wurf 50.2, 94.0
-- und 20.9 %); eine neue Figur mit High Weight (Fitness 4) scheitert immer.
-- Am Bettlaken-Seil oeffnet der Sturzwurf
-- erst nach (Wurzel + 1) x 100 x Seiltempo Stockwerken am Stueck
-- (ClimbSheetRopeState Z. 76, 83, 261-266), bei einer neuen Figur 40
-- Stockwerke, runter das Dreifache: dort wirkt der Wert praktisch nie
-- (Faktensweep 2, 23.09.2026; bis dahin stand hier "seltener Absturz vom
-- Bettlaken-Seil").
-- getClimbRopeSpeed nimmt max(Strength, Fitness) und rechnet die Trait-Stufen
-- dazu; die Stufe bestimmt das Klettertempo.
-- IsoGameCharacter.attackFromWindowsLunge: springt ein Zombie, der gerade
-- ueber einen Zaun oder durch ein Fenster klettert (oder aus einem geworfen
-- wird), eine nahe Figur an und trifft, geraet sie ins Taumeln, und ein
-- eigener Wurf entscheidet, ob sie auch stuerzt (Faktensweep 23.09.2026:
-- klettern tut der Zombie, nicht die Figur). Nur mit der Sandbox-Option
-- Zombie Lunge (Standard an, in der Voreinstellung Rising aus). Basis 30 von
-- 100, dazu Betrunken x3, Erschoepfung (Endurance-Moodle, bis zum
-- Faktensweep 3 stand hier "Muede") x3 und Schwere Last x5 je Moodle-Stufe sowie
-- Unterkoerper-Schmerz ueber 20 geteilt durch 10; abgezogen werden Fitness x2
-- und Nimble x1, das Ergebnis nie unter 5. Das ist ein anderer Wurf als die
-- Stolperchance aus ClimbOverFenceState, darum eine eigene Zeile.
-- IsoGameCharacter.handleLandingImpact: nach einem schaedigenden Sturz
-- entscheidet zuerst Rand.Next(100) < Schaden (Z. 2119), ob er ueberhaupt
-- verletzt; der Schaden haengt an Fallhoehe, Inventarlast (leeres Inventar:
-- 0) und den Gewichts-Traits (x1.2 / x1.4, eigene Zeile falldamage). Erst dann
-- entscheidet ein zweiter Wurf ueber Knochenbruch, tiefe Wunde oder nur
-- Steifheit. Die Schwelle beginnt bei (Aufprallgeschwindigkeit / Schwelle
-- harter Sturz)^2 x 55, also Fallhoehe / 1,5 x 55 (bis zum Faktensweep 2,
-- 23.09.2026, stand hier "Sturzhoehe x 55"), plus bis zu 20, wenn
-- das Inventar fast voll ist, minus 1,5 je Fitness-Stufe ueber 4 und je
-- Nimble-Stufe. Der Bruchwurf ist Rand.Next(100) < Schwelle, der Wundwurf
-- laeuft mit Schwelle + 10 nur, wenn der Bruchwurf danebenging.
-- Faktensweep 3 (23.09.2026), beides in der Fussnote: ab etwa drei
-- Stockwerken liegt die Schwelle schon ohne Trait ueber 100 (Fitness 5: 34,
-- 71, 108 fuer 1, 2, 3 Stockwerke), dann ist der Bruch ohnehin sicher. Mit
-- der Sandbox-Option Bone Fracture aus (Voreinstellung Rising) scheitert der
-- Bruchwurf immer (Z. 2137, 2149), und die Punkte heben nur die tiefe Wunde.
-- Lunge: Very Low Weight und Very High Weight gibt es nur im Spiel (siehe
-- Stolpern), bei Fitness 5 also 50 bzw. 10 statt 20, das deckt die Fussnote
-- "neue Figur 20" mit dem Wert ab. High Weight ueber Slow Metabolism hat
-- Fitness 4: 30 - 8 - 5 = 17 statt 20, dafuer der hint lungehigh.
TF.Static["veryunderweight"] = {
    { id = "meleedamage",  kind = "pct",  value = -40,  text = "UI_TF_eff_meleedamage",
      probe = "damageDealt", note = "UI_TF_note_meleeswings" },
    { id = "grapple",      kind = "mult", value = 0.8,  text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
    { id = "trip",         kind = "flat", value = 30,   text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase",
      hint = "UI_TF_note_triplow" },
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
      probe = "damageDealt", note = "UI_TF_note_meleeswings" },
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
    -- Seit dem Faktensweep 2 (23.09.2026) je Trait eine Fussnote mit dem
    -- Ergebnis an hohen Zaeunen: eine neue Figur mit High Weight hat Fitness 4
    -- (XPBoosts Fitness=-1), also 18 - 15 = 3, Wurzel 1, und scheitert immer;
    -- Very High Weight gibt es nur im Spiel, die Fitness bleibt (4 oder 5):
    -- 18 oder 20 - 25, auf 0 gekappt, Wurzel 0, rund 94 % (bis zum
    -- Faktensweep 3, 23.09.2026, stand hier "Fitness 3").
    -- Mit der Sandbox-Option Easy Climbing (Voreinstellung Rising) gelingt
    -- jedes Klettern ohne Wurf, der Seil-Sturzwurf faellt weg und die
    -- Wegfindung fuehrt immer ueber hohe Zaeune (ClimbOverWallState Z. 292-294,
    -- ClimbSheetRopeState Z. 93, ClimbDownSheetRopeState Z. 83,
    -- PathFindRequest Z. 77); die Fussnoten sagen es seit dem Faktensweep 3.
    { id = "climb",         kind = "flat", value = -15,  text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbweight" },
    -- getClimbRopeSpeed zieht das Gewicht nur im Zweig !down ab, also nur
    -- beim Hochklettern. Eigene Fussnote, damit die Uebersicht es nicht mit
    -- Gymnasts +1 (hoch und runter) zu null verrechnet (Audit 12.09.2026).
    -- Die Stufen 4 und 5 haben dasselbe Tempo (kein case 4/5, Z. 14827-14865):
    -- eine neue Figur ohne Handschuhe (Stufe 5) verliert mit -1 nichts,
    -- Very High Weight (5 -> 3) klettert rund 56 % langsamer (Faktensweep 2,
    -- 23.09.2026).
    { id = "climbstrength", kind = "flat", value = -1,   text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbup" },
    { id = "trip",          kind = "flat", value = 10,   text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase",
      hint = "UI_TF_note_triphigh" },
    { id = "lungefall",     kind = "flat", value = -5,   text = "UI_TF_eff_lungefall",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_lungebase",
      hint = "UI_TF_note_lungehigh" },
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
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbobese" },
    { id = "climbstrength", kind = "flat", value = -2,   text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbupobese" },
    { id = "trip",          kind = "flat", value = 20,   text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase",
      hint = "UI_TF_note_tripveryhigh" },
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
-- 22) +21 bis +29 % und -21 bis -26 % (die Summen sind 13 und 15 bis 22,
-- getMeleeCombatMod Z. 10074-10106; bis zum Faktensweep 2, 23.09.2026, stand
-- hier -27, das gaebe nur die unerreichbare 14; seitdem je Trait eine
-- Fussnote). Die frueheren +30 / -23 waren die
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
      note = "UI_TF_note_zombieinjury_thin" },
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
-- (IsoPlayer, BaseVehicle) rufen generateFracture direkt, ohne den
-- Bruchzeit-Faktor 0.6 / 1.8; dort wirkt der Trait nur ueber den
-- Unfallschaden, Fast Healer x0.8 (kleiner), Slow Healer x1.2 (groesser), und
-- der entscheidet ueber Bruchchance und Bruchzeit. Die Fussnote sagt beides;
-- bis 0.13.9 nannte sie nur den kleineren Schaden, auch bei Slow Healer
-- (Faktensweep 23.09.2026). Mit der Sandbox-Option Bone Fracture aus
-- (Voreinstellung Rising) gibt es gar keine Brueche (BodyPart Z. 818-821,
-- IsoGameCharacter Z. 2137 und 2149); seit dem Faktensweep 3 (23.09.2026) in
-- der Fussnote.
-- Tiefe Wunde (Faktensweep 3): der Trait setzt nur die Startzeit. Naehen
-- (ISStitch.lua Z. 108 -> BodyPart.setStitched, Z. 876-881) setzt
-- deepWoundTime auf 0, danach heilt die Naht ueber stitchTime ohne Trait;
-- ohne Verband bleibt die Zeit bei 3 stehen (Z. 358-363). Die -26 / +49 %
-- gelten also nur, solange die Wunde verbunden und nicht genaeht ist; eigene
-- Fussnote deepstitch statt midpoint. Blutung, Schmerz und Hinken leiten
-- sich aus den Wundzeiten ab (generateBleeding Z. 1780-1793, getPain Z.
-- 904-921), die cutspread-Fussnoten sagen es.
-- Fahrzeug (Faktensweep 3): angefahren werden macht im Standard keinen
-- Schaden, DamageToPlayerFromHitByACar steht in jeder Voreinstellung auf
-- Keine (SandboxOptions Z. 185, Multiplikator 0, IsoPlayer Z. 1964-1966). Im
-- Standard gilt der Faktor bei Unfaellen im Wagen (BaseVehicle Z. 8510-8513,
-- PlayerDamageFromCrash an). Darum heisst die Zeile "Verletzung bei
-- Fahrzeugunfaellen", das Angefahrenwerden steht in der Fussnote vehhit, und
-- der Stand ist code: gemessen war nur der Weg beim Angefahrenwerden mit der
-- Option auf Normal.
TF.Static["fasthealer"] = {
    { id = "fracture",  kind = "mult", value = 0.6, text = "UI_TF_eff_fracture",
      note = "UI_TF_note_fracturefall" },
    { id = "vehdamage", kind = "mult", value = 0.8, text = "UI_TF_eff_vehdamage",
      note = "UI_TF_note_vehhit" },
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
      note = "UI_TF_note_deepstitch" },
}

TF.Static["slowhealer"] = {
    { id = "fracture",  kind = "mult", value = 1.8, text = "UI_TF_eff_fracture",
      note = "UI_TF_note_fracturefall" },
    { id = "vehdamage", kind = "mult", value = 1.2, text = "UI_TF_eff_vehdamage",
      note = "UI_TF_note_vehhit" },
    { id = "bitewound", kind = "pct", value = 77, text = "UI_TF_eff_bitewound",
      note = "UI_TF_note_midpoint" },
    -- Slow Healer: +67 %, +82 %, +100 % und +56 % je Generator (Fund 13),
    -- im Mittel +76 %. Bis 0.1.22 stand hier +70, obwohl die vier Werte
    -- daneben standen (Audit 12.09.2026).
    { id = "cutwound",  kind = "pct", value = 76, text = "UI_TF_eff_cutwound",
      note = "UI_TF_note_cutspread_slow" },
    { id = "deepwound", kind = "pct", value = 49, text = "UI_TF_eff_deepwound",
      note = "UI_TF_note_deepstitch" },
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
-- Kritchance: IsoPlayer.calculateCritChance klemmt nach dem +10 auf 10 bis 90
-- (Z. 3689). Eine Schrotflinte (CriticalChance 70) liegt aus der Naehe schon
-- ohne Trait bei 90, dort bringt Marksman nichts; darum seit dem Faktensweep
-- 2 (23.09.2026) eine eigene Fussnote.
TF.Static["marksman"] = {
    { id = "hitchance",   kind = "flat", value = 20,  text = "UI_TF_eff_hitchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_hitexample" },
    { id = "critchance",  kind = "flat", value = 10,  text = "UI_TF_eff_critchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_critcap" },
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
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase",
      hint = "UI_TF_note_climbdextrous" },
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
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase",
      hint = "UI_TF_note_climbalone" },
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

-- Leichen und blutige Gegenstaende (Faktensweep 3, 23.09.2026): die
-- Unzufriedenheit und der Stress beim Umlagern stehen nur in
-- client/TimedActions/ISInventoryTransferAction.lua:update (Z. 129-144), als
-- blosses stats:add ohne Senden. Im Multiplayer laedt der Server kein
-- client-Lua, die Uebertragung laeuft dort als Java-Transaction ohne diese
-- Werte, und der Server ueberschreibt die Werte des Clients jede Sekunde
-- (PlayerStatsPacket, Stats.load). Darum die condition sponlyclient; aus dem
-- Code geschlossen, im Multiplayer nicht gemessen.
TF.Static["brave"] = {
    -- Nur die Panik aus BodyDamage.IncreasePanic, also beim Anblick neuer
    -- Zombies; Agoraphobic, Claustrophobic, Blutungen und Fear of Blood
    -- schreiben direkt auf den Wert (Audit 12.09.2026).
    { id = "panic",   kind = "pct",  value = -70, text = "UI_TF_eff_panic",
      note = "UI_TF_note_panicseen" },
    { id = "corpsestress", kind = "mult", value = 0.5, text = "UI_TF_eff_corpsestress",
      condition = "UI_TF_note_sponlyclient" },
    { id = "grapple", kind = "mult", value = 1.1, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
}

TF.Static["cowardly"] = {
    { id = "panic",   kind = "pct",  value = 100, text = "UI_TF_eff_panic",
      note = "UI_TF_note_panicseen" },
    { id = "corpsestress", kind = "mult", value = 2.0, text = "UI_TF_eff_corpsestress",
      condition = "UI_TF_note_sponlyclient" },
    { id = "grapple", kind = "mult", value = 0.9, text = "UI_TF_eff_grapple",
      dead = true, note = "UI_TF_note_deadgrapple" },
}

TF.Static["desensitized"] = {
    { id = "panic",     kind = "info", text = "UI_TF_eff_nopanic" },
    { id = "corpses",   kind = "info", text = "UI_TF_eff_nocorpsestress",
      condition = "UI_TF_note_sponlyclient" },
    -- SleepingEvent.checkNightmare: Rand.Next(100) < 5, mit Desensitized 10,
    -- einmal je Schlaf ab drei Stunden. Nur im Einzelspiel (Faktensweep 3,
    -- 23.09.2026): checkNightmare kehrt auf dem Client zurueck (Z. 186-188),
    -- und setPlayerFallAsleep ruft im Multiplayer niemand
    -- (ISWorldObjectContextMenu.lua Z. 1114-1121 kehrt vorher zurueck).
    { id = "nightmare", kind = "fromto", value = { 5, 10 }, text = "UI_TF_eff_nightmare",
      note = "UI_TF_note_nostress", condition = "UI_TF_note_sponlysleep" },
}

-- Registry-Name HEMOPHOBIC, im Spiel "Fear of Blood". Die +50 (stats:add
-- (PANIC, 50), Panik laeuft von 0 bis 100) stehen in acht Aktionen, nicht nur
-- beim Verbinden:
--   nur bei blutender Wunde (getBleedingTime() > 0): ISApplyBandage,
--     ISComfreyCataplasm, ISGarlicCataplasm, ISPlantainCataplasm
--   immer, ohne jede Bedingung: ISStitch (naehen und Naht entfernen),
--     ISCleanBurn (Verbrennung auswaschen), ISRemoveBullet, ISRemoveGlass
-- Darum hiess die Zeile "Verletzung" und nicht "blutende Wunde": eine
-- Verbrennung auszuwaschen ist keine Wunde und blutet nicht. Seit dem
-- Faktensweep 3 (23.09.2026) nennt sie die vier Aktionen ohne Bedingung
-- einzeln: Desinfizieren (ISDisinfect), Schienen (ISSplint) und Binden
-- reinigen (ISCleanBandage) fragen HEMOPHOBIC gar nicht ab, "beim Behandeln
-- einer Verletzung" versprach dort Panik. Die Abfrage in ISApplyBandage steht
-- vor der Verzweigung auf doIt (Z. 105 gegen 111), gilt also auch beim
-- Abnehmen einer Binde; ISStitch ebenso beim Faedenziehen (Z. 94 gegen 108).
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
      note = "UI_TF_note_blooditems", condition = "UI_TF_note_sponlyclient" },
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
    -- Spannen von 0.13.6 bis 0.14.14 nach den Laeufen vom 20. und 21.09.2026:
    -- Rennen 12-17, Sprinten 10-15. Bis dahin 13-16 und 10-14: die 13 kam aus
    -- einem Lauf, in dem der Sprinting-Skill mitten in der Phase stieg.
    -- Seit 0.14.15 nur Paare, in denen beide Phasen die WalkSpeed laut Code
    -- zeigen (Sprinting 0: ohne 0.65, mit 0.90 auf Stufe 4, 0.85 auf Stufe 3),
    -- jede Phase mit Trait gegen ihre sauberen Nachbarn ohne; Laeufe 20d,
    -- 21.09., 25.09. und 25.09. nur Stufe 3. Rennen Stufe 3 x1.134-1.138, im
    -- Mittel 1.136 (8 Paare), Stufe 4 x1.161-1.172, Mittel 1.169 (5 Paare);
    -- Sprinten Stufe 3 x1.111-1.130, Mittel 1.119 (6 Paare), Stufe 4
    -- x1.143-1.148, Mittel 1.145 (5 Paare). Die Spanne reicht von Mittel zu
    -- Mittel: 14-17 und 12-15. Bestaetigt im Kontrolllauf vom 25.09.2026
    -- (Mess-Mod 6.53.0, Grundtempo je Tick geprueft, kein Paar verworfen):
    -- Rennen x1.1680 / x1.1339, Sprinten x1.1439 / x1.1147, Gehen x1.0825 /
    -- x1.0807. Die alten Untergrenzen 12 und 10 kamen aus
    -- Laeufen bei Sprinting 1 (x1.1213, x1.1028); hoeheres Sprinting senkt den
    -- Anteil, das sagt die Fussnote, es setzt aber nicht die Spanne.
    -- Nicht gewertet: am 25.09.2026 die Phasen 17-22 (Stufe 4, Rennen und
    -- Sprinten); dort lag das Grundtempo tiefer (WalkSpeed ohne 0.44 bis 0.60,
    -- mit 0.65), am ehesten nasser Naturboden im Freien (IsoGameCharacter
    -- Z. 8787-8789, bis -0.25; Sand -0.05, Z. 8791-8792), also nicht x1.2028
    -- und x1.0942. Modell: Renntempo = (0.8 + Zuschlag - 0.15) x fullSpeedMod +
    -- Sprinting / 20, gedeckelt bei 1.0 (Z. 8964-8967, 8986), Zuschlag
    -- (Stufe + 1) / 20 ab Stufe 3 (Z. 8761-8764); Rennen und Sprinten nehmen
    -- denselben Wert (runOrSprint, Z. 8963, 9004).
    { id = "panicrun", kind = "pctrange", value = { 14, 17 }, text = "UI_TF_eff_panicrun",
      note = "UI_TF_note_panicrun" },
    { id = "panicsprint", kind = "pctrange", value = { 12, 15 }, text = "UI_TF_eff_panicsprint",
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
    -- Verdorbenes Essen vergiftet immer (Z. 625-639): der Wurf entscheidet nur
    -- zwischen der schweren Dosis (5 x Hunger x 10 x Portion) und der leichten
    -- (2 x ...). Die Zeile heisst darum seit dem Faktensweep 2 (23.09.2026)
    -- "Chance auf die schwere Dosis". Erwartetes Gift 2 + 3c: bei c = 40 %
    -- mit Iron Gut rund -20 %, mit Weak Stomach rund +40 %.
    -- Die Grundchance (int)(Tage verdorben / Spanne x 100), Tage bis 5
    -- gedeckelt, ist selbst nicht auf 100 gedeckelt (Z. 616-619). Iron Gut
    -- halbiert sie ganzzahlig, gewuerfelt wird Rand.Next(100) < Chance: der
    -- wirksame Faktor ist min(b/2, 100) / min(b, 100), also x0.5 nur bis b =
    -- 100, ab b = 200 gar nichts mehr. Bei den 205 Speisen mit Spanne 2
    -- (etwa Kohl, offene Dosen) ist das nach 4 Tagen verdorben so weit
    -- (Faktensweep 3, 23.09.2026, seitdem in der Fussnote).
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
    -- Eigene Fussnote, Iron Gut behaelt spoiledonly (Faktensweep 23.09.2026).
    -- Bis zum Faktensweep 3 stand hier "dessen x0.5 gilt immer"; das war
    -- falsch, auch Iron Gut laeuft bei langer Verderbnis in den Deckel (siehe
    -- oben bei Iron Gut).
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
-- cold (Faktensweep 3, 23.09.2026): kein Wuerfelwurf. Der Faktor skaliert,
-- wie schnell sich catchACold fuellt, solange delta ueber 0,1 liegt
-- (BodyDamage Z. 733-743); bei 100 beginnt die Erkaeltung ohne Wurf (Z.
-- 744-749), sonst sinkt der Zaehler je Update fest um 0,175 ohne Multiplier
-- (Z. 751-756), voll ist er nach rund 570 Updates leer. Darum heisst die
-- Zeile "Erkaeltungsaufbau bei Kaelte" statt "Chance, sich zu erkaelten",
-- mit der Fussnote coldmeter; die Faktoren bleiben.
TF.Static["resilient"] = {
    { id = "cold",          kind = "mult", value = 0.45, text = "UI_TF_eff_cold",
      note = "UI_TF_note_coldmeter" },
    { id = "coldmild",      kind = "info", text = "UI_TF_eff_coldmild", note = "UI_TF_note_gamequirk" },
    { id = "coldprogress",  kind = "mult", value = 0.8,  text = "UI_TF_eff_coldprogress" },
    { id = "coldrecovery",  kind = "mult", value = 1.5,  text = "UI_TF_eff_coldrecovery" },
    { id = "corpsesick",    kind = "mult", value = 0.75, text = "UI_TF_eff_corpsesick" },
    { id = "zombification", kind = "mult", value = 1.25, text = "UI_TF_eff_zombification" },
}

TF.Static["pronetoillness"] = {
    { id = "cold",          kind = "mult", value = 1.7,  text = "UI_TF_eff_cold",
      note = "UI_TF_note_coldmeter" },
    { id = "coldprogress",  kind = "mult", value = 1.2,  text = "UI_TF_eff_coldprogress" },
    { id = "coldrecovery",  kind = "mult", value = 0.5,  text = "UI_TF_eff_coldrecovery" },
    { id = "corpsesick",    kind = "mult", value = 1.25, text = "UI_TF_eff_corpsesick" },
    { id = "zombification", kind = "mult", value = 0.75, text = "UI_TF_eff_zombification" },
}

-- Registry-Name OUTDOORSMAN, im Spiel "Outdoorsy".
TF.Static["outdoorsman"] = {
    { id = "cold",         kind = "mult", value = 0.25, text = "UI_TF_eff_cold",
      note = "UI_TF_note_coldmeter" },
    { id = "coldmild",     kind = "info", text = "UI_TF_eff_coldmild", note = "UI_TF_note_gamequirk" },
    -- Je Versuch statt je Wurf (Faktensweep 2, 23.09.2026): ISBBQLightFromKindle
    -- wuerfelt ab 20 % Fortschritt jeden Tick erst Zuenden (1/300, mit Trait
    -- 1/150), nur wenn das nicht trifft das Brechen (1/300, mit Trait 1/450);
    -- isValid beendet die Aktion, sobald das Feuer brennt oder der Stock weg
    -- ist. Das ist ein Wettlauf: je Versuch brennt es ohne Trait in 300/599 =
    -- 50 %, mit Trait in 450/599 = 75 %, der Stock bricht in 50 % bzw. 25 %.
    -- Also x1.5 und x0.5 je Versuch; bis dahin standen hier die Wurffaktoren
    -- x2.0 und x0.667. Nur die Wuerfelphase halbiert sich (300 -> 150 Ticks);
    -- jeder Versuch laeuft vorher 20 % seiner Dauer ohne Wurf (300 von 1500
    -- Einheiten), bei 2,0 statt 1,33 Versuchen sind es rund 0,6 der Zeit
    -- (Faktensweep 3, 23.09.2026; bis dahin stand hier "halbiert sich").
    -- Im Spiel ausgespielt am 24.09.2026 (Test Feuer, je Fall 500 Versuche am
    -- Grill mit dem echten ZombRand, zwei Laeufe): gezuendet 47 % ohne, 73 und
    -- 76 % mit Outdoorsy; der Stock brach in 53 % ohne, 27 und 24 % mit; Zeit
    -- je Feuer x0.58 und x0.57 (laut Code 0.61). Am Lagerfeuer bringt Outdoorsy
    -- nichts (x0.98, x0.97). Die Kochgrube (isFireInteractionObject) ist nicht
    -- gemessen, keine stand in der Naehe.
    { id = "firelight",    kind = "mult", value = 1.5,   text = "UI_TF_eff_firelight",
      note = "UI_TF_note_bbqonly", case = "UI_TF_note_bbqonly",
      hint = "UI_TF_note_firelightrace" },
    { id = "kindling",     kind = "mult", value = 0.5,   text = "UI_TF_eff_kindling",
      note = "UI_TF_note_bbqonly", case = "UI_TF_note_bbqonly",
      hint = "UI_TF_note_kindlingrace" },
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
-- 100 (Lauf d: 120) sprintende Ticks, Trait an und aus im Wechsel, Ausdauer
-- gehalten ab Lauf f (d und e loggen sie nicht): Athletic 1.0495, 0.9966 und
-- 0.9940, Unfit 1.0112, 1.0082 und 0.9878 (Verhaeltnis der Summen, wie das
-- Log es druckt; Lauf d ohne Aufwaermen und ohne Streuungsschaetzung). Bis zum
-- Faktensweep 23.09.2026 stand hier fuer Lauf e Unfit 1.0073, das Mittel der
-- Paarquotienten statt des geloggten Summenverhaeltnisses, und ein gepaartes
-- 1.0007 / 0.9993 aus den ruckelfreien Paaren von Lauf f (Athletic 3/2; Unfit
-- 9/8 und 13/12; die none-Phasen 4, 6 und 10 haben Ticks ueber 0.19), so
-- auch in docs/berichte/2026-09-10-lua-abgleich.md. Die Klammer nannte beides
-- bis zum Faktensweep 2 (23.09.2026) unbelegt; das war falsch, beide Zahlen
-- stehen in den Logs. Massgeblich ist der Lauf vom 13.09.2026
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
-- grep ueber media/lua bestaetigt. Bei den Fenstern ruft nur onAttemptFinished
-- exert, und das loest nur die Animation "trying" aus, im Ausgang struggle:
-- beim Oeffnen ein dauerhaft verriegeltes oder ein verriegeltes Fenster von
-- aussen (OpenWindowState Z. 127-131), beim Schliessen ein dauerhaft
-- verriegeltes oder eins, durch das jemand klettert (CloseWindowState Z.
-- 117-121). Normales Oeffnen und Schliessen kostet keine Ausdauer; die
-- Fussnote sagt es seit dem Faktensweep 3 (23.09.2026). Im Spiel gespielt am
-- 25.09.2026 (Test Fenster aufbrechen, Fitness 5): 0.0060 Ausdauer je
-- Versuch ohne, 0.0054 mit Runner (x0.90); Oeffnen und Schliessen kostete 0.
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
--
-- Multiplayer (Faktensweep 3, 23.09.2026), auch beim Hosten: der Client
-- rechnet mit dem Tempo mal Lerp(1, 120 / Tempolimit, (v / Limit)^2)
-- (CarController Z. 130-136, BaseVehicle.getFakeSpeedModifier) und schaltet
-- die Kraft ab echtem Tempolimit ab (Z. 681-683, Standard 70). Aus der
-- Plateau-Regel folgen auf Standard-Servern rund +5 bis +7 % bei gewoehnlichen
-- Wagen, nichts bei schnellen; Sunday Driver rund -12 %, Sportwagen -4 %.
-- Nur gerechnet, im Multiplayer nicht gemessen; die Fussnoten sagen es
-- vorsichtig. Bis dahin hiess es "Server begrenzen standardmaessig auf 70",
-- das war das echte Tempo, der Tacho zeigt dort 120.
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
-- Die -30 % Rueckwaertskraft gelten nur bis etwa 3,3 km/h; darueber sinkt
-- der Faktor linear bis 0 bei 10 km/h (0,63 bei 4, 0,42 bei 6, 0,21 bei 8
-- km/h). Gemessen ist nur das Fenster 2 bis 4 km/h; seit dem Faktensweep 3
-- (23.09.2026) nennt die Fussnote reverseforcesunday die Grenze.
TF.Static["sundaydriver"] = {
    { id = "engineforce",  kind = "pct", value = -25, text = "UI_TF_eff_engineforce",
      note = "UI_TF_note_forcesunday" },
    { id = "topspeed",     kind = "pct", value = -19, text = "UI_TF_eff_topspeed",
      note = "UI_TF_note_topspeedsunday" },
    { id = "reverseforce", kind = "pct", value = -30, text = "UI_TF_eff_reverseforce",
      note = "UI_TF_note_reverseforcesunday" },
    { id = "reversespeed", kind = "pct", value = -63, text = "UI_TF_eff_reversespeed",
      note = "UI_TF_note_reversespeedsunday" },
}

-- Gymnast bringt Nimble +1 mit (XPBoosts), also 22 + 4 = 26, Wurzel 5: eine
-- neue Figur scheitert an hohen Zaeunen mit 20 statt 25 %. Dextrous und All
-- Thumbs allein aendern bei 20 nichts (24 und 16 bleiben Wurzel 4), darum je
-- ein hint; die gemeinsame Fussnote bleibt, damit die Uebersicht die Punkte
-- weiter summiert (Faktensweep 2, 23.09.2026).
-- Faktensweep 3 (23.09.2026): Burglar gibt es nur ueber den Beruf Burglar,
-- der Nimble 2 mitbringt (character_professions.txt Z. 3-11). Jeder Burglar
-- startet also bei 24 (Wurzel 4), mit dem Trait 28 (Wurzel 5): 20 statt 25 %.
-- Bis dahin stand Burglar hier in der Liste "aendert allein nichts"; eigener
-- hint climbburglar. Die Berufe mit Fitness-, Strength- oder Nimble-Bonus
-- (Farmer, Firefighter, Lumberjack, Nurse, Police Officer, Rancher: 22 bzw.
-- 24) steigen mit Dextrous auf 26 bzw. 28, also Wurzel 5; eigener hint
-- climbdextrous. All Thumbs aendert nur beim Fitness Instructor etwas (28 ->
-- 24, Wurzel 5 -> 4), das sagt climbalone.
TF.Static["gymnast"] = {
    { id = "climb",         kind = "flat", value = 4, text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase",
      hint = "UI_TF_note_climbgymnast" },
    { id = "climbstrength", kind = "flat", value = 1, text = "UI_TF_eff_climbstrength",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_climbstrengthbase" },
}

-- Schritte: DoFootstepSound (IsoGameCharacter Z. 5297-5344) gibt FMOD die
-- Lautstaerke vor den Trait-Faktoren (parameterVolume, Z. 5306/5325); was
-- der Spieler hoert, bleibt gleich. Der Faktor trifft nur den Radius, den
-- Zombies hoeren: ceil(Lautstaerke x 10), drinnen halbiert und abgeschnitten.
-- Mit Schuhen draussen bei Fertigkeit 0, Schleichen/Gehen/Laufen/Sprinten:
-- ohne 4/7/11/14, Graceful 3/5/7/9, Clumsy 5/9/13/17 Felder (draussen;
-- drinnen (int)(x0.5): 2/3/5/7, 1/2/3/4, 2/4/6/8). Die Werte draussen sind
-- am 24.09.2026 im Spiel gemessen (Test Schritte, DoFootstepSound je Gangart,
-- Schuhe, 15 von 15 wie laut Code). Bis zum Faktensweep 3
-- (23.09.2026) stand hier Graceful 2 und Clumsy 4 beim Schleichen und in der
-- Fussnote "beim Schleichen keine Aenderung": das liess den Faktor 1.2 in
-- getSneakSpotMod aus (0.95 x 1.2 bei Sneak 0). Seitdem nennen die Fussnoten
-- auch "draussen" und "drinnen etwa die Haelfte". Bis zum Faktensweep 2
-- (23.09.2026) hiess die Zeile "Schrittlautstaerke", ohne Fussnote.
TF.Static["graceful"] = {
    { id = "footsteps", kind = "pct",  value = -40, text = "UI_TF_eff_footsteps",
      note = "UI_TF_note_footgraceful" },
    { id = "trip",      kind = "flat", value = -10, text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase",
      hint = "UI_TF_note_tripgraceful" },
    { id = "lungefall", kind = "flat", value = -10, text = "UI_TF_eff_lungefall",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_lungebase" },
}

TF.Static["clumsy"] = {
    { id = "footsteps", kind = "pct",  value = 20, text = "UI_TF_eff_footsteps",
      note = "UI_TF_note_footclumsy" },
    { id = "trip",      kind = "flat", value = 10, text = "UI_TF_eff_trip",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_tripbase",
      hint = "UI_TF_note_tripclumsy" },
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
-- Multiplayer (Faktensweep 3, 23.09.2026), auch beim Hosten: SleepAllowed und
-- SleepNeeded sind standardmaessig aus (ServerOptions Z. 107-108), dann
-- haelt der Server die Muedigkeit auf 0 und bietet keinen Schlaf an. Vanilla
-- blendet Wakeful, Sleepyhead und Restless Sleeper dann aus
-- (CharacterCreationProfession.lua Z. 888-892), Night Owl und Hard of
-- Hearing nicht; deren Schlafzeilen tragen die condition mpsleep. Die
-- Einschlafverzoegerung und der Albtraum laufen im Multiplayer auch mit
-- Schlaf nie (setPlayerFallAsleep wird dort nicht gerufen,
-- ISWorldObjectContextMenu.lua Z. 1114-1121), darum condition sponlysleep.
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
    -- Die 0 bis 60 gelten im normalen Bett ohne Schmerz, Stress und
    -- Schlaftabletten: Bett und Stress multiplizieren beide Faelle, Schmerz
    -- gibt 1 + 0,2 je Stufe Stunden dazu, dann greift der Deckel 2,0; mit
    -- Tabletten 0,1 fuer alle (SleepingEvent Z. 144-182). Seit dem
    -- Faktensweep 3 (23.09.2026) in der Fussnote.
    { id = "fallasleep",    kind = "range", value = { 0, 60 }, text = "UI_TF_eff_fallasleep",
      unit = "UI_TF_unit_minutes", note = "UI_TF_note_fallasleepbase",
      condition = "UI_TF_note_sponlysleep" },
}

-- SleepingEvent.doDelayToSleep (Z. 144-182): Night Owl halbiert vor dem
-- Deckel 2.0 und vor den Schlaftabletten (die setzen 0.1). Liegt die
-- Wartezeit ohne Night Owl ueber 2 Stunden (Schmerz, Boden, Stress), bleibt
-- weniger als die Haelfte, mit Tabletten nichts. Fussnote seit dem
-- Faktensweep 2 (23.09.2026).
TF.Static["nightowl"] = {
    { id = "sleeprecovery", kind = "pct", value = 40,  text = "UI_TF_eff_sleeprecovery",
      condition = "UI_TF_note_mpsleep" },
    { id = "fallasleep",    kind = "pct", value = -50, text = "UI_TF_eff_fallasleep",
      note = "UI_TF_note_nightowlcap", condition = "UI_TF_note_sponlysleep" },
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
    -- Ein getragener oder mitgefuehrter Wecker klingelt auf dem Feld der Figur
    -- (getAlarmSquare, AlarmClock Z. 78-94), Abstand 0, und weckt immer; die
    -- 4.5 zaehlt nur fuer einen abgelegten Wecker weiter als Radius / 4.5
    -- (Wecker 15 -> 3,3 Felder, Uhr 7 -> 1,6). Im Spiel gemessen am 24. und
    -- 25.09.2026 (Test Wecker, je 23 von 23 Proben wie laut Code): abgestellte
    -- Uhr weckt mit dem Trait bis 1 Feld, abgestellter Wecker bis 3 Felder,
    -- getragen oder im Inventar immer. Die Fussnote sagte bis 0.14.14 "only
    -- from about 3 tiles", das las sich wie "erst ab"; seit 0.14.15 "within".
    -- Die Probe hearDistance stand
    -- hier ohne Eintrag in TF.Probes und lief nie (Faktensweep 2, 23.09.2026).
    -- Wecker wirken nur im Schlaf; auf Standard-Servern schlaeft niemand
    -- (siehe Schlaf), darum seit dem Faktensweep 3 (23.09.2026) die condition
    -- mpsleep. Der Wecker selbst laeuft im Multiplayer beim Client.
    { id = "hearing",   kind = "mult", value = 4.5,  text = "UI_TF_eff_hearing",
      note = "UI_TF_note_hearingalarm", condition = "UI_TF_note_mpsleep" },
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
    -- getMaxSightRange x 1.2 (HandWeapon Z. 1491). Treffer- und Kritchance
    -- rechnen damit ein Glockenband um (min + max) / 2 (CombatManager Z.
    -- 2031-2042): das Band rueckt nach aussen, nah am unteren Ende sinkt der
    -- Bonus (Pistole, Aiming 0: schlechter von 2 bis rund 4 Feldern).
    -- Fussnote seit dem Faktensweep 2 (23.09.2026).
    { id = "weaponsight", kind = "mult", value = 1.2, text = "UI_TF_eff_weaponsight",
      note = "UI_TF_note_weaponsight" },
    { id = "fadein",      kind = "mult", value = 1.5, text = "UI_TF_eff_fadein" },
}

-- Registry-Name NIGHT_VISION, im Spiel "Cat's Eyes".
-- Cat's Eyes kommt nur in LightingJNI.calculateVisionCone vor, und das ist im
-- Einzelspiel der Wahrnehmungskegel (siehe Eagle Eyed): zu Fuss nachts 18
-- auf 54 Grad, der Zuschlag verblasst mit dem Tageslicht. Bis 0.1.22 stand
-- hier, er weite nur den gezeichneten Kegel; das galt nur fuer den Server.
-- Im Fahrzeug (LightingJNI Z. 433-454) beginnt der Kegel bei 324 - 540 x
-- Dunkelheit, nachts also -216, mit Trait -180; beides hebt die Scheinwerfer-
-- Untergrenze 36 oder die Klemme 18 auf denselben Wert. Dort wirkt Cat's
-- Eyes nur in der Daemmerung, hoechstens rund +20 Grad (Faktensweep 2,
-- 23.09.2026; bis dahin sagte die Fussnote "auch im Fahrzeug").
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
-- Faktensweep 3 (23.09.2026): consumeNicotineLogic (Z. 21-44) gibt Rauchern
-- den stressChange des Items auf STRESS (0 bis 1) und auf UNHAPPINESS (0 bis
-- 100); die -0,05 einer Zigarette sind dort nicht spuerbar, darum sagt die
-- Zeile nicht mehr "senkt Unzufriedenheit". Den stressChange bekommt ueber
-- Eat (IsoGameCharacter Z. 5382, BodyDamage Z. 514) jeder, Raucher also
-- doppelt; dazu beendet Rauchen den Nikotinentzug. Husten je Rauchen:
-- Raucher 1 zu 2 (InverseCoughProbabilitySmoker), Nichtraucher 1 zu 4 bis 1
-- zu 10, Kautabak nie.
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

-- ingredients: ISCraftingUI.ReturnItemToContainer kehrt bei Disorganized
-- sofort zurueck (Z. 13-15). Es traegt nicht nur uebrige Zutaten zurueck,
-- sondern alles, was aus Taschen oder Behaeltern geholt wurde: Werkzeug beim
-- Handwerk, Essen und Feuerzeug beim Essen und Rauchen, Feuerzeug und Stock
-- am Lagerfeuer (ISWidgetHandCraftControl, ISInventoryPaneContextMenu,
-- ISCampingMenu). Beim Trinken aus einer Flasche laeuft das Zuruecklegen fuer
-- niemanden (onDrinkForThirst reicht die undefinierte Variable item), darum
-- nennt die Zeile das Trinken nicht (Faktensweep 3, 23.09.2026).
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
    -- 50 (etwa die Haelfte des Baumenues, alle Moebel) landen bei 0, und der
    -- Bau ist fertig in dem Tick, in dem die Figur sich fertig zur Baustelle
    -- gedreht hat (ISBuildAction.waitToStart gibt shouldBeTurning zurueck;
    -- bis 0.14.14 stand hier "im ersten Tick"). Gemessen am 24. und 25.09.2026
    -- (Test Bauen): Holzstuhl 50 -> 0, fertig im ersten Tick mit gedrehter
    -- Figur; Holzwand 200 -> 150 (x0.75). Nur im Einzelspiel. Auf einem
    -- MP-Server rechnet der Server die Dauer selbst (BuildAction.getDuration:
    -- 200 - 5 x Carpentry, Handy -50), dort -25 bis -33 % (Faktensweep
    -- 23.09.2026). Das gilt auch beim Hosten, denn dort laeuft ein eigener
    -- Server-Prozess; seit dem Faktensweep 2 (23.09.2026) sagt es die Fussnote,
    -- vorher nannte sie das "sofort" ohne Einschraenkung.
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

-- Illiterate: Menue und Doppelklick sperren Buecher, Notizen und
-- Medienbeschriftungen (ISInventoryPaneContextMenu Z. 1054, 2815;
-- ISInventoryPane Z. 1102), die Kartennotizen (ISWorldMapSymbols Z.
-- 1367-1373), die Naehrwerte auf Packungen (Food.DoTooltip Z. 1363-1391) und
-- das Rezept in Reichweite (ItemContainer.hasRecipe Z. 3446-3453, ausser mit
-- dem Tag PictureBook). Seit dem Faktensweep 3 (23.09.2026) Stand code: die
-- Messung vom 13.09.2026 traf ISReadABook.checkLevel, das eine Figur mit
-- Illiterate im Spiel nie erreicht.
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

-- ISLightFromKindle: derselbe Wettlauf wie am Grill (siehe Outdoorsy), mit
-- forceComplete bei beidem Ausgang; perform stellt den naechsten Versuch mit
-- dem naechsten Stock an, solange das Feuer aus ist. Je Stock 50 % -> 75 %
-- gezuendet, 50 % -> 25 % gebrochen (Faktensweep 2, 23.09.2026). Im Spiel
-- ausgespielt am 24.09.2026 (Test Feuer, je Fall 500 Versuche am Lagerfeuer,
-- zwei Laeufe): gezuendet 51 und 54 % ohne, 75 % mit Wilderness Knowledge,
-- 76 und 78 % als Former Scout; gebrochen 49 und 46 % ohne, 25 und 22 bis
-- 25 % mit. Am Grill bringt Wilderness Knowledge nichts (x1.08, x1.15).
TF.Static["wildernessknowledge"] = {
    { id = "firelight", kind = "mult", value = 1.5,   text = "UI_TF_eff_firelight",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly",
      hint = "UI_TF_note_firelightrace" },
    { id = "kindling",  kind = "mult", value = 0.5,   text = "UI_TF_eff_kindling",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly",
      hint = "UI_TF_note_kindlingrace" },
}

-- Registry-Pfad "formerscout", im Spiel "Former Scout". Das Java-Feld heisst
-- CharacterTrait.SCOUT, aber getType():getName() liefert den Registry-Pfad,
-- nicht den Feldnamen (Registries.CHARACTER_TRAIT.getLocation(this).getPath()).
-- Bis zum Review am 10.09.2026 stand hier "scout", und der Trait fand seine
-- beiden Zeilen nie. Einziger Trait, bei dem Feld und Pfad auseinanderliegen.
TF.Static["formerscout"] = {
    { id = "firelight", kind = "mult", value = 1.5,   text = "UI_TF_eff_firelight",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly",
      hint = "UI_TF_note_firelightrace" },
    { id = "kindling",  kind = "mult", value = 0.5,   text = "UI_TF_eff_kindling",
      note = "UI_TF_note_campfireonly", case = "UI_TF_note_campfireonly",
      hint = "UI_TF_note_kindlingrace" },
}

TF.Static["burglar"] = {
    -- OpenWindowState: Rand.Next(100) < 10, mit Burglar 5, nur fuer ein
    -- verschlossenes Fenster, das von aussen aufgebrochen wird. Gewuerfelt
    -- wird je Versuch (onAttemptFinished Z. 153-190, bei jedem Durchlauf der
    -- Schleife "trying"), und die Figur versucht es weiter, bis das Fenster
    -- aufgeht oder klemmt. Je Fenster also p / (p + (1 - p) x s), s = Chance,
    -- dass ein Versuch es oeffnet (Strength 5: 1 - 0.94 x 0.96 x 0.98 =
    -- 11,6 %): ohne Trait 49 %, mit Burglar 31 %. Strength 0-1: 85 -> 73 %,
    -- ab 8: 23 -> 13 %. Seit dem Faktensweep 2 (23.09.2026) zeigt die Zeile
    -- das je Fenster fuer eine neue Figur; bis dahin -50 % je Versuch.
    -- Im Spiel gespielt am 24. und 25.09.2026 (Test Fenster aufbrechen, drei
    -- Laeufe zu je 40 Fenstern ohne und 40 mit Burglar, Strength 5): 61 von
    -- 120 = 51 % ohne, 31 von 120 = 26 % mit Burglar; je Versuch klemmte es in
    -- 10 % ohne und 4 % mit Burglar (laut Code 10 und 5). Die Zeile zeigt
    -- weiter die Werte aus dem Code.
    { id = "windowlock", kind = "fromto", value = { 49, 31 }, text = "UI_TF_eff_windowlock",
      note = "UI_TF_note_windowforced" },
    { id = "hotwire",    kind = "info", text = "UI_TF_eff_hotwire" },
    { id = "climb",      kind = "flat", value = 4,   text = "UI_TF_eff_climb",
      unit = "UI_TF_unit_points", note = "UI_TF_note_climbbase",
      hint = "UI_TF_note_climbburglar" },
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
--   Forschungsstufe: level -= 2, danach normalizeSkillLevel auf 0 bis 10
--     (Z. 1232-1242); unter 1 ist jedes Rezept erforschbar (Z. 1304-1307)
-- Beide Fassungen des Traits, die kaufbare und die des Berufs, wirken gleich.
-- Die Untergrenzen stehen seit dem Faktensweep 3 (23.09.2026) in den
-- Fussnoten: eine Lernstufe 1 bleibt 1 (19 von rund 375 Anforderungen in
-- media/scripts), eine Forschungsstufe 1 sinkt nur auf 0 (rund ein Viertel
-- der erforschbaren Rezepte).
TF.Static["inventive"] = {
    { id = "autolearn", kind = "flat", value = -1, text = "UI_TF_eff_autolearn",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_autolearnfloor" },
    { id = "research",  kind = "flat", value = -2, text = "UI_TF_eff_research",
      unit = "UI_TF_unit_levels", note = "UI_TF_note_researchfloor" },
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
