--- Trait Facts - Gesamtuebersicht: was der ganze Build zusammen ergibt.
--
-- Der Tooltip beantwortet "was tut dieser Trait". Diese Schicht beantwortet
-- "was tut meine Figur", und das ist nicht dasselbe: die Engine rechnet
-- Faktoren multiplikativ, nicht additiv. Resilient und Outdoorsy ergeben bei
-- der Erkaeltungsgefahr 0.45 x 0.25 = x0.11, also -89 %, nicht -130 %. (Bis
-- zum Faktensweep 23.09.2026 stand hier Grapple mit +72 % und der Sprint;
-- beide Werte sind wirkungslos und kommen in keine Summe.)
--
-- Die Regeln stammen aus dem Engine-Code, nicht aus der Anschauung
-- (Nachtrag 4b im Extraktionsbericht):
--
--   Faktoren (pct, mult)  multiplizieren.  BodyDamage: `delta *= 0.45` und
--     danach `delta *= 0.25` hintereinander; ISWorldObjectContextMenu:
--     `sleepFor` bekommt seine Trait-Faktoren nacheinander aufmultipliziert;
--     Ausdauerverlust laeuft ueber zwei getrennte Faktoren im selben Produkt.
--   Punkte (flat)         addieren.  getClimbingFailChanceFloat und
--     getClimbRopeSpeed addieren ihre Trait-Beitraege, ebenso die
--     Stolperchance und die Foraging-Werte.
--   Vorher/Nachher        addiert die Aenderungen auf dieselbe Basis.
--   Spannen und Aussagen  werden nicht verrechnet, nur aufgelistet.
--
-- Zusammengefasst wird nur, was wirklich dasselbe ist: gleicher Name, gleiche
-- Einheit, gleiche Fussnote. "XP gain (all Crafting skills)" und "XP gain
-- (melee skills and Aiming)" bleiben deshalb zwei Zeilen, und Outdoorsy an
-- Grill, Kamin und Ofen mischt sich nicht mit Bushcrafter am Lagerfeuer.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Summary = TF.Summary or {}

--- Reihenfolge der Themen. Vom Handfesten zum Beilaeufigen.
TF.Summary.ORDER = {
    "combat", "movement", "health", "mind", "food", "sleep",
    "senses", "learning", "crafting", "vehicles", "foraging",
}

--- Thema je Stat, ueber den Uebersetzungsschluessel des Namens.
--
-- Der Schluessel des Namens ist die Identitaet eines Stats: zwei Traits, die
-- dasselbe veraendern, benutzen denselben. check-data.py besteht darauf, dass
-- jeder benutzte Name hier steht - sonst faellt eine Zeile still in kein Thema.
TF.Summary.GROUP = {
    -- Kampf
    UI_TF_eff_aimdelay      = "combat",
    UI_TF_eff_aimsteady     = "combat",
    -- Seit 0.1.24 eine Wirkung im Kampf (Schlagtempo mit Aexten), vorher als
    -- wirkungslos unter Handwerk.
    UI_TF_eff_axeswing      = "combat",
    UI_TF_eff_critchance    = "combat",
    UI_TF_eff_grapple       = "combat",
    UI_TF_eff_hitchance     = "combat",
    UI_TF_eff_jam           = "combat",
    UI_TF_eff_knockback     = "combat",
    UI_TF_eff_meleedamage   = "combat",
    UI_TF_eff_sightrange    = "combat",
    UI_TF_eff_weaponsight   = "combat",
    UI_TF_eff_weatherpen    = "combat",
    UI_TF_eff_windpenalty   = "combat",
    UI_TF_eff_zombieinjury  = "combat",

    -- Bewegung und Ausdauer
    UI_TF_eff_carry         = "movement",
    UI_TF_eff_climb         = "movement",
    UI_TF_eff_climbstrength = "movement",
    UI_TF_eff_enduranceloss = "movement",
    UI_TF_eff_enduranceregen = "movement",
    UI_TF_eff_falldamage    = "movement",
    UI_TF_eff_lungefall     = "movement",
    UI_TF_eff_panicspeed    = "movement",
    UI_TF_eff_panicrun      = "movement",
    UI_TF_eff_panicsprint   = "movement",
    UI_TF_eff_sprintspeed   = "movement",
    UI_TF_eff_swingendurance = "movement",
    UI_TF_eff_trip          = "movement",

    -- Gesundheit und Verletzungen
    UI_TF_eff_bitewound     = "health",
    UI_TF_eff_canwound      = "health",
    UI_TF_eff_cold          = "health",
    UI_TF_eff_coldmild      = "health",
    UI_TF_eff_coldprogress  = "health",
    UI_TF_eff_coldrecovery  = "health",
    UI_TF_eff_corpsesick    = "health",
    UI_TF_eff_cutwound      = "health",
    UI_TF_eff_deepwound     = "health",
    UI_TF_eff_foodsick      = "health",
    UI_TF_eff_fallinjury    = "health",
    UI_TF_eff_fracture      = "health",
    UI_TF_eff_poison        = "health",
    UI_TF_eff_rawegg        = "health",
    UI_TF_eff_taintedwater  = "health",
    UI_TF_eff_treescratch   = "health",
    UI_TF_eff_vehdamage     = "health",
    UI_TF_eff_zombification = "health",

    -- Psyche
    UI_TF_eff_blooditems    = "mind",
    UI_TF_eff_bloodpanic    = "mind",
    UI_TF_eff_bloodstress   = "mind",
    UI_TF_eff_corpsestress  = "mind",
    UI_TF_eff_nightmare     = "mind",
    UI_TF_eff_nocorpsestress = "mind",
    UI_TF_eff_nomedcheck    = "mind",
    UI_TF_eff_nopanic       = "mind",
    UI_TF_eff_panic         = "mind",
    UI_TF_eff_panicin       = "mind",
    UI_TF_eff_panicout      = "mind",
    UI_TF_eff_smoker        = "mind",
    UI_TF_eff_treatpanic    = "mind",

    -- Essen und Trinken
    UI_TF_eff_appetite      = "food",
    UI_TF_eff_gainweight    = "food",
    UI_TF_eff_nutrition     = "food",
    UI_TF_eff_thirst        = "food",

    -- Schlaf
    UI_TF_eff_fallasleep    = "sleep",
    UI_TF_eff_sleepduration = "sleep",
    UI_TF_eff_sleeprecovery = "sleep",
    UI_TF_eff_tiredness     = "sleep",

    -- Wahrnehmung und Heimlichkeit
    UI_TF_eff_blur          = "senses",
    UI_TF_eff_detection     = "senses",
    UI_TF_eff_fadein        = "senses",
    UI_TF_eff_footsteps     = "senses",
    UI_TF_eff_hearing       = "senses",
    UI_TF_eff_lightcone     = "senses",
    UI_TF_eff_nightcone     = "senses",
    UI_TF_eff_nightambient  = "senses",
    UI_TF_eff_noiseradius   = "senses",
    UI_TF_eff_nosounds      = "senses",
    UI_TF_eff_spotted       = "senses",

    -- Skills und Lernen
    UI_TF_eff_autolearn     = "learning",
    UI_TF_eff_illiterate    = "learning",
    UI_TF_eff_readtime      = "learning",
    UI_TF_eff_research      = "learning",
    UI_TF_eff_researchtime  = "learning",
    UI_TF_eff_xp            = "learning",

    -- Handwerk, Bauen, Inventar
    UI_TF_eff_barricade     = "crafting",
    UI_TF_eff_buildtime     = "crafting",
    UI_TF_eff_chopspeed     = "crafting",
    UI_TF_eff_container     = "crafting",
    UI_TF_eff_durability    = "crafting",
    UI_TF_eff_firelight     = "crafting",
    UI_TF_eff_hotwire       = "crafting",
    UI_TF_eff_ingredients   = "crafting",
    UI_TF_eff_kindling      = "crafting",
    UI_TF_eff_transfer      = "crafting",
    UI_TF_eff_craftwalk     = "crafting",
    UI_TF_eff_startstrength = "learning",
    UI_TF_eff_startfitness  = "learning",
    UI_TF_eff_treedamage    = "crafting",
    UI_TF_eff_unbarricade   = "crafting",
    UI_TF_eff_windowlock    = "crafting",
    UI_TF_live_recipes      = "crafting",
    UI_TF_live_seasons      = "crafting",

    -- Fahrzeuge
    UI_TF_eff_engineforce   = "vehicles",
    UI_TF_eff_reverseforce  = "vehicles",
    UI_TF_eff_reversenoise  = "vehicles",
    UI_TF_eff_reversespeed  = "vehicles",
    UI_TF_eff_rpmbuild      = "vehicles",
    UI_TF_eff_topspeed      = "vehicles",

    -- Foraging und Rezepte (Schicht 1)
    UI_TF_live_darkness     = "foraging",
    UI_TF_live_sight        = "foraging",
    UI_TF_live_spotfor      = "foraging",
    UI_TF_live_weather      = "foraging",
}

--- Wirkrichtung je Stat: hilft ein hoeherer Wert der Figur oder schadet er?
--
-- Das ist die Angabe, die der Uebersicht bisher gefehlt hat. Ein Spieler liest
-- "Fracture healing time: +80 %" und muss selbst darauf kommen, dass mehr hier
-- schlechter ist; bei "Time to research a recipe: -30 %" ist weniger besser.
-- Mit dieser Tabelle traegt der Wert selbst die Antwort, gruen oder rot.
--
--   "up"    ein hoeherer Wert hilft   (Tragkraft, Trefferchance, XP)
--   "down"  ein hoeherer Wert schadet (Heilzeit, Panik, Fallschaden)
--   "open"  kommt darauf an           (bleibt grau, siehe unten)
--
-- Wo die Richtung nicht aus dem Stat selbst folgt, steht "open" und die Zeile
-- bleibt farblos. Das ist kein Versaeumnis, sondern die einzige ehrliche
-- Antwort: bei der Schlafdauer ziehen Wakeful (Vorteil, Kosten 3) und Restless
-- Sleeper (Buerde, Kosten -6) den Wert in dieselbe Richtung. Eine Farbe waere
-- dort eine Behauptung, die diese Mod nicht belegen kann.
TF.Summary.BETTER = {
    -- Kampf
    UI_TF_eff_aimdelay      = "down",
    UI_TF_eff_aimsteady     = "up",
    UI_TF_eff_critchance    = "up",
    UI_TF_eff_grapple       = "up",
    UI_TF_eff_hitchance     = "up",
    UI_TF_eff_jam           = "up",
    UI_TF_eff_knockback     = "up",
    UI_TF_eff_meleedamage   = "up",
    UI_TF_eff_sightrange    = "down",
    UI_TF_eff_weaponsight   = "up",
    UI_TF_eff_weatherpen    = "down",
    UI_TF_eff_windpenalty   = "down",
    UI_TF_eff_zombieinjury  = "up",

    -- Bewegung und Ausdauer
    UI_TF_eff_carry         = "up",
    UI_TF_eff_climb         = "up",
    UI_TF_eff_climbstrength = "up",
    UI_TF_eff_enduranceloss = "down",
    UI_TF_eff_enduranceregen = "up",
    UI_TF_eff_falldamage    = "down",
    UI_TF_eff_lungefall     = "down",
    UI_TF_eff_panicspeed    = "up",
    UI_TF_eff_panicrun      = "up",
    UI_TF_eff_panicsprint   = "up",
    UI_TF_eff_sprintspeed   = "up",
    UI_TF_eff_swingendurance = "down",
    UI_TF_eff_trip          = "down",

    -- Gesundheit und Verletzungen
    UI_TF_eff_bitewound     = "down",
    UI_TF_eff_canwound      = "down",
    UI_TF_eff_cold          = "down",
    UI_TF_eff_coldmild      = "up",
    UI_TF_eff_coldprogress  = "down",
    UI_TF_eff_coldrecovery  = "up",
    UI_TF_eff_corpsesick    = "down",
    UI_TF_eff_cutwound      = "down",
    UI_TF_eff_deepwound     = "down",
    UI_TF_eff_fallinjury    = "down",
    UI_TF_eff_foodsick      = "down",
    UI_TF_eff_fracture      = "down",
    UI_TF_eff_poison        = "down",
    UI_TF_eff_rawegg        = "up",
    UI_TF_eff_taintedwater  = "down",
    UI_TF_eff_treescratch   = "down",
    UI_TF_eff_vehdamage     = "down",
    -- Laenger bis zur Verwandlung ist mehr Zeit zu handeln.
    UI_TF_eff_zombification = "up",

    -- Psyche
    UI_TF_eff_blooditems    = "down",
    UI_TF_eff_bloodpanic    = "down",
    UI_TF_eff_bloodstress   = "down",
    UI_TF_eff_corpsestress  = "down",
    UI_TF_eff_nightmare     = "down",
    UI_TF_eff_nocorpsestress = "up",
    UI_TF_eff_nomedcheck    = "down",
    UI_TF_eff_nopanic       = "up",
    UI_TF_eff_panic         = "down",
    UI_TF_eff_panicin       = "down",
    UI_TF_eff_panicout      = "down",
    -- Die Zeile nennt Nutzen (Stress, Unzufriedenheit) und Last (Entzug,
    -- Husten, den Zombies hoeren); eine Richtung waere geraten. Bis 0.14.0
    -- "up", also das gruene Gewinnzeichen an einem Trait, der -3 kostet
    -- (Faktensweep 2, 23.09.2026).
    UI_TF_eff_smoker        = "open",
    UI_TF_eff_treatpanic    = "down",

    -- Essen und Trinken
    UI_TF_eff_appetite      = "down",
    -- Mehr Kalorien bis zur Gewichtszunahme schuetzt vor Uebergewicht und
    -- gefaehrdet bei Untergewicht. Beides kommt vor, also keine Farbe.
    UI_TF_eff_gainweight    = "open",
    UI_TF_eff_nutrition     = "up",
    UI_TF_eff_thirst        = "down",

    -- Schlaf
    UI_TF_eff_fallasleep    = "down",
    -- Wakeful verkuerzt den Schlaf als Vorteil, Restless Sleeper als Buerde.
    UI_TF_eff_sleepduration = "open",
    UI_TF_eff_sleeprecovery = "up",
    UI_TF_eff_tiredness     = "down",

    -- Wahrnehmung und Heimlichkeit
    UI_TF_eff_blur          = "down",
    UI_TF_eff_detection     = "up",
    UI_TF_eff_fadein        = "up",
    UI_TF_eff_footsteps     = "down",
    -- getHearDistanceModifier: Hard of Hearing multipliziert mit 4.5.
    -- Geraeusche werden behandelt, als kaemen sie aus 4,5-facher
    -- Entfernung; ein hoeherer Wert heisst also schlechter hoeren.
    UI_TF_eff_hearing       = "down",
    UI_TF_eff_lightcone     = "up",
    UI_TF_eff_nightcone     = "up",
    UI_TF_eff_nightambient  = "up",
    UI_TF_eff_noiseradius   = "up",
    UI_TF_eff_nosounds      = "down",
    UI_TF_eff_spotted       = "down",

    -- Skills und Lernen
    UI_TF_eff_autolearn     = "down",
    UI_TF_eff_illiterate    = "down",
    UI_TF_eff_readtime      = "down",
    UI_TF_eff_research      = "down",
    UI_TF_eff_researchtime  = "down",
    UI_TF_eff_xp            = "up",

    -- Handwerk, Bauen, Inventar
    UI_TF_eff_axeswing      = "down",
    UI_TF_eff_barricade     = "down",
    UI_TF_eff_buildtime     = "down",
    UI_TF_eff_chopspeed     = "up",
    UI_TF_eff_container     = "up",
    UI_TF_eff_durability    = "up",
    UI_TF_eff_firelight     = "up",
    UI_TF_eff_hotwire       = "up",
    UI_TF_eff_ingredients   = "down",
    UI_TF_eff_kindling      = "down",
    UI_TF_eff_transfer      = "down",
    UI_TF_eff_craftwalk     = "down",
    -- Seit 0.1.14 eine Zahl (Stufen gegenueber der Grundstufe 5), keine
    -- Zuordnung mehr: eine hoehere Startstufe hilft der Figur, darum "up"
    -- (Faktensweep 2, 23.09.2026; der alte Satz "weder gut noch schlecht"
    -- stand noch darueber).
    UI_TF_eff_startstrength = "up",
    UI_TF_eff_startfitness  = "up",
    UI_TF_eff_treedamage    = "up",
    UI_TF_eff_unbarricade   = "down",
    UI_TF_eff_windowlock    = "down",

    -- Fahrzeuge
    UI_TF_eff_engineforce   = "up",
    UI_TF_eff_reverseforce  = "up",
    UI_TF_eff_reversenoise  = "down",
    UI_TF_eff_reversespeed  = "up",
    UI_TF_eff_rpmbuild      = "up",
    UI_TF_eff_topspeed      = "up",

    -- Foraging und Rezepte (Schicht 1)
    UI_TF_live_darkness     = "down",
    UI_TF_live_recipes      = "up",
    UI_TF_live_seasons      = "up",
    UI_TF_live_sight        = "up",
    UI_TF_live_spotfor      = "up",
    UI_TF_live_weather      = "down",
}

--- Hilft der Wert dieses Eintrags der Figur?
-- @return "gut"|"schlecht"|nil   nil, wenn die Richtung offen ist
function TF.Summary.direction(text, value, kind)
    local better = TF.Summary.BETTER[text]
    if not better or better == "open" then return nil end
    -- Aussagen ohne Zahl (kind "info") haben keinen Wert, den man vergleichen
    -- koennte: dort zaehlt die Richtung des Stats selbst.
    if kind == "info" then
        return better == "up" and "gut" or "schlecht"
    end
    local delta
    if kind == "mult" then
        delta = value - 1
    elseif kind == "fromto" then
        if type(value) ~= "table" then return nil end
        delta = value[2] - value[1]
    elseif kind == "pctrange" or kind == "range" then
        -- Beide Enden auf derselben Seite der Null, sonst gibt es keine Richtung.
        -- "range" kam bis zum Faktensweep 23.09.2026 hier nicht vor und blieb
        -- darum immer farblos, auch wo die Richtung eindeutig ist (Gimp -67,5
        -- bis -22,5 %, Quick Rest 5,5 bis 12 %). Eine Spanne ab 0 ("0 bis
        -- 60 min") zaehlt nach dem Ende, das nicht 0 ist: die beiden, die es
        -- gibt (Claustrophobic 0 bis 18 Panik je s, Restless Sleeper 0 bis 60
        -- min), sind reine Lasten, und die Legende nennt die neutrale Farbe
        -- "fuer sich weder gut noch schlecht". Bis 0.14.1 blieben sie farblos
        -- (Faktensweep 3, 23.09.2026). Nur Enden mit verschiedenem Vorzeichen
        -- haben keine Richtung; beide 0 ergibt delta 0 und damit auch keine.
        if type(value) ~= "table" or type(value[1]) ~= "number" or type(value[2]) ~= "number" then return nil end
        if value[1] * value[2] < 0 then return nil end
        delta = (value[1] ~= 0) and value[1] or value[2]
    elseif type(value) == "number" then
        delta = value
    else
        return nil
    end
    if delta == 0 then return nil end
    if better == "up" then
        return delta > 0 and "gut" or "schlecht"
    end
    return delta > 0 and "schlecht" or "gut"
end

--- Spaltenmasse der Uebersicht, in Pixeln.
--
-- Die Breiten kommen aus den Daten, nicht aus dem Gefuehl: 66 verschiedene
-- Werte, davon 90 % unter 15 Zeichen; 95 Bezeichnungen mit Median 24 und
-- 90 % unter 49; 49 Fussnoten mit Median 28. Damit bleibt der Grossteil der
-- Zeilen einzeilig, und was laenger ist, bricht in seiner Spalte um.
TF.Summary.LAYOUT = { value = 110, label = 300, gap = 12 }

--- Ab dieser nutzbaren Breite lohnt der Spaltensatz.
--
-- Darunter bliebe fuer die dritte Spalte zu wenig, und jede zweite Zeile
-- braeche um. Dann ist der durchlaufende Satz besser lesbar.
TF.Summary.MIN_COLUMN_WIDTH = 560

--- Die drei Spalten fuer eine nutzbare Breite, oder nil.
function TF.Summary.columnsFor(width)
    -- Die Masse gelten fuer die kleine Schrift in Standardgroesse; bei einer
    -- groesseren Schrift wachsen sie mit (TF.fmt.uiScale).
    local scale = (TF.fmt.uiScale and TF.fmt.uiScale()) or 1
    if type(width) ~= "number" or width < TF.Summary.MIN_COLUMN_WIDTH * scale then
        return nil
    end
    local l = TF.Summary.LAYOUT
    local value = math.floor(l.value * scale + 0.5)
    local label = math.floor(l.label * scale + 0.5)
    local gap = math.floor(l.gap * scale + 0.5)
    local restX = value + gap + label + gap
    return {
        value = { x = 0, width = value },
        label = { x = value + gap, width = label },
        note  = { x = restX, width = width - restX },
    }
end

--- Stats, die sich nicht stapeln.
--
-- ISLightFromKindle.lua prueft `WILDERNESS_KNOWLEDGE or SCOUT` und setzt dann
-- einen festen Wert. Wer beide hat, bekommt trotzdem nur einmal die Wirkung.
-- Multiplizieren waere hier schlicht falsch.
TF.Summary.NOSTACK = {
    UI_TF_eff_firelight = true,
    UI_TF_eff_kindling  = true,
}

--- Prozentwerte, die die Engine addiert statt multipliziert.
--
-- Der Regelfall ist multiplizieren: BodyDamage, AddXP, die Schlafdauer und die
-- Ausdauer reihen ihre Trait-Faktoren als Produkt. Das Foraging-System tut es
-- anders und summiert erst die Prozente, bevor es daraus einen Faktor macht
-- (forageSystem: `effectReduction + traitDef.weatherEffect`, danach
-- `1 - effectReduction/100`). Zweimal 13 % ergeben dort 26 %, nicht 24,3 %.
TF.Summary.ADDPCT = {
    UI_TF_live_weather  = true,
    UI_TF_live_darkness = true,
    -- Kategorie-Boni: getCategoryBonus summiert die Prozente von Beruf und
    -- Traits und macht erst dann 1 + Summe/100 daraus.
    UI_TF_live_spotfor  = true,
}

--- Geltungsbereiche, die sich ueberschneiden.
--
-- Zwei Zeilen zum selben Stat mit verschiedener Fussnote sind normalerweise
-- zwei getrennte Faelle: Outdoorsy hilft am Grill, Bushcrafter am Lagerfeuer,
-- die begegnen sich nie. Beim XP-Gewinn ist es anders. Fast Learner gilt fuer
-- alles ausser Fitness und Strength, Reluctant Fighter fuer Nahkampf und
-- Aiming - auf einem Nahkampf-Skill wirken also beide, 1.3 x 0.75 = -2.5 %.
--
-- Jedes Paar nennt den breiten und den engen Geltungsbereich (der enge liegt
-- ganz im breiten) und die Namen der beiden Faelle, die daraus werden:
--   both  die Schnittmenge, in der beide wirken   ("melee skills and Aiming")
--   rest  der Rest des breiten Bereichs            ("other skills")
-- Aus drei Zeilen (breit, eng, zusammen) werden so zwei, und jede sagt, wofuer
-- sie gilt. Der enge Beitrag allein entfaellt: sobald der breite Trait dabei
-- ist, gibt es keinen Skill, auf dem der enge allein wirkt.
--
-- In Vanilla kombinierbar sind laut Registry nur Fast Learner oder Slow
-- Learner mit Reluctant Fighter; Fast Learner, Slow Learner und Crafty
-- schliessen einander aus. Fuer Vanilla reicht darum der paarweise Vergleich.
-- Mit More Traits kommen die Spezialisierungen und Anti-Gun dazu: sie
-- schliessen nur einander aus, Specialization: Guns dazu Anti-Gun
-- (ToadTraits.txt:887-947, :53), und lassen sich mit
-- Fast/Slow Learner, Crafty und Reluctant Fighter waehlen. Die Faktoren
-- multiplizieren sich: das Spiel rechnet die Vanilla-Faktoren in AddXP, das
-- Ereignis AddXP traegt den fertigen Betrag (IsoGameCharacter.java:15622),
-- und MT zieht davon 75 % bzw. 25 % mit doXPBoost false ab (MT_XP.lua:86-101,
-- MT.lua:85-86); die Abzuege der Mod zusammen hoechstens 95 %. Fast Learner
-- ausserhalb der Spezialisierung also 1.3 x 0.25 = 0.325. Die Paketzeilen
-- tragen keinen scope, die Uebersicht zeigt sie getrennt, jede fuer sich
-- richtig; den kombinierten Fall zeigt sie nicht (Faktensweep 3, 23.09.2026).
TF.Summary.OVERLAP = {
    { broad = "xpmost",         narrow = "xpcombat",
      both = "UI_TF_note_combatskills", rest = "UI_TF_case_otherskills" },
    { broad = "xpmost",         narrow = "xpcrafting",
      both = "UI_TF_note_crafting",     rest = "UI_TF_case_otherskills" },
    { broad = "xpmostnosprint", narrow = "xpcombat",
      both = "UI_TF_note_combatskills", rest = "UI_TF_case_otherskills" },
    { broad = "xpmostnosprint", narrow = "xpcrafting",
      both = "UI_TF_note_crafting",     rest = "UI_TF_case_otherskills" },
    -- Short Sighted zieht 2 Kacheln ab, aber nur ohne Brille. Alle anderen
    -- Foraging-Traits geben ihre Kacheln immer. Das Spiel summiert beides
    -- (forageSystem: `traitBonus + traitDef.visionBonus`); der Fall ohne
    -- Brille ist die Summe, der Fall mit Brille der Rest.
    { broad = "forageradius",   narrow = "foragenoglasses",
      both = "UI_TF_live_sight_noglasses", rest = "UI_TF_case_withglasses" },
}

--- Das Paar zu zwei Geltungsbereichen, oder nil.
-- @return pair, broadIsA   broadIsA sagt, ob `a` der breite Bereich ist
local function overlapPair(a, b)
    if not a or not b then return nil end
    for _, pair in ipairs(TF.Summary.OVERLAP) do
        if pair.broad == a and pair.narrow == b then return pair, true end
        if pair.broad == b and pair.narrow == a then return pair, false end
    end
    return nil
end

--- Obergrenzen, die die Engine selbst zieht.
--
-- forageSystem klemmt die aufsummierte Minderung von Wetter und Dunkelheit auf
-- effectReductionMax = 75 %. Sechs Foraging-Traits kaemen rechnerisch auf 78 %;
-- angezeigt waeren das drei Prozentpunkte, die es im Spiel nicht gibt.
TF.Summary.CAP = {
    UI_TF_live_weather  = 75,
    UI_TF_live_darkness = 75,
}

-- Nach einem Farbtag frisst das Panel das Leerzeichen; <SPACE> ersetzt es.
local SPACE = " <SPACE> "

--- Vorzeichen der Traits, die nichts kosten.
--
-- Bei allen anderen sagen die Punktkosten, ob ein Trait gut oder schlecht ist.
-- Fuenfzehn kosten nichts, weil sie ueber den Beruf oder das Startgewicht
-- kommen; ihre Kosten sind 0 und taugen nicht als Hinweis. Die Liste stammt
-- aus der Registry (docs/engine/trait_id_cost_name.txt, Spalte Kosten = 0).
--
-- Was hier nicht steht - etwa ein kostenloser Trait aus einer fremden Mod -
-- bleibt farblich neutral. Lieber keine Aussage als eine geratene.
TF.Summary.FREE_SIGN = {
    -- Berufsvorteile
    axeman = 1, blacksmith2 = 1, burglar = 1, cook2 = 1, desensitized = 1,
    herbalistprof = 1, inventiveprof = 1, marksman = 1, mechanics2 = 1,
    nightowl = 1, nutritionist2 = 1,
    -- Startgewicht: diese vier Zustaende sind Buerden. Emaciated fehlt hier
    -- mit Absicht - es kostet laut Registry -10 und wird schon ueber die
    -- Punkte roetlich.
    veryunderweight = -1, underweight = -1, overweight = -1, obese = -1,
}

--- Die Quellenliste einer Zeile, jeder Trait in der Farbe seines Vorzeichens.
--
-- Positiv gruenlich, negativ roetlich, kostenlos (Beruf) in der ruhigen Farbe
-- der Fussnote. Damit sieht man auf einen Blick, ob eine Zeile von etwas
-- Gutem oder etwas Schlechtem kommt, ohne die Kostenspalte danebenzulegen.
--
-- Das Komma bleibt in der Farbe des Namens davor: es haengt ohne Tag an ihm.
-- Hinter einem Kuerzel dagegen bekommt jedes Satzzeichen ein eigenes
-- Segment nach einem <SPACE> (im Spiel 5 px rechts): im Segment "TOC," lag
-- die rechte Rahmenlinie des Kaestchens auf dem Komma (Befund im Spiel
-- 14.09.2026). Nach dem letzten Kuerzel steht das <SPACE> am Ende; was
-- folgt, ")" aus TF.fmt.line, beginnt dort. Vor dem Trenner zur Fussnote
-- nimmt TF.Summary.build es wieder weg (seit 24.09.2026).
function TF.Summary.sourceText(sources, palette)
    local out = {}
    for index, source in ipairs(sources) do
        if index > 1 then out[#out + 1] = (sources[index - 1].tag and SPACE or "") .. "," end
        local tag = ""
        if palette then
            -- Kostet der Trait nichts, entscheidet die Liste der kostenlosen.
            local sign = source.cost
            if sign == 0 or sign == nil then
                sign = TF.Summary.FREE_SIGN[source.key or ""] or 0
            end
            if sign > 0 then
                tag = palette.good or ""
            elseif sign < 0 then
                tag = palette.bad or ""
            else
                tag = palette.note or ""
            end
        end
        if index > 1 then
            out[#out + 1] = (tag ~= "" and (tag .. SPACE) or " ") .. source.name
        else
            out[#out + 1] = tag .. source.name
        end
        -- Ein fremder Trait nennt hinter seinem Namen das Kuerzel seines
        -- Mods oder Pakets, in dessen Farbe (TF.fmt.tagKey; Mod-Farben seit
        -- 14.09.2026, vorher das Grau der Fussnote).
        if source.tag then
            out[#out + 1] = TF.fmt.paint(palette, TF.fmt.tagKey(source.tag)) .. SPACE .. source.tag
            if index == #sources then out[#out + 1] = SPACE end
        end
    end
    return table.concat(out, "")
end

--- Wie ein Stat verrechnet wird.
-- @return "factor"|"flat"|"fromto"|"list"
local function mergeKind(kind, text)
    -- Addierte Prozente laufen ueber denselben Weg wie Punkte: Werte
    -- aufsummieren, Darstellung bleibt Prozent.
    -- Nur Zahlen: eine Paketzeile mit dem Text eines addierten Stats, aber
    -- kind range oder fromto, warf sonst in der Summe (Audit 20.09.2026).
    if TF.Summary.ADDPCT[text] and kind ~= "range" and kind ~= "fromto" and kind ~= "pctrange"
            and kind ~= "bool" and kind ~= "info" then return "flat" end
    if kind == "pct" or kind == "mult" then return "factor" end
    if kind == "flat" or kind == "count" then return "flat" end
    if kind == "fromto" then return "fromto" end
    if kind == "range" or kind == "pctrange" then return "range" end
    return "list"
end

--- Ein Eintrag als Faktor. pct 40 -> 1.4, mult 1.4 -> 1.4.
local function asFactor(entry)
    if entry.kind == "mult" then return entry.value end
    return 1 + (entry.value / 100)
end

--- Sammelt die Eintraege aller uebergebenen Traits.
-- @param traitDefs Liste von CharacterTraitDefinition
-- @return table  Liste von { entry = ..., source = Anzeigename }
--- Stufen-Traits: welcher Trait zu welcher Stufe gehoert.
--
-- Das Spiel setzt sie bei der Erschaffung selbst: applyTraits ruft LevelPerk
-- je Stufe, XpUpdate.levelPerk nimmt die vier Stufen-Traits des Skills ab
-- und setzt den zur Stufe passenden; die letzte Stufe gewinnt (Engine-
-- Recherche 13.09.2026, an sieben frischen Figuren gemessen). Fit mit
-- Fitness Instructor (Fitness 10) verliert Fit und bekommt Athletic, High
-- Weight (Fitness 4) bekommt Out of Shape dazu. Stufe 5 traegt keinen, und
-- bei Stufe 0 faellt kein LevelPerk, dort bleibt, was gewaehlt wurde.
local BANDS = {
    UI_TF_eff_startstrength = { low1 = "weak", low2 = "feeble", high1 = "stout", high2 = "strong" },
    UI_TF_eff_startfitness = { low1 = "unfit", low2 = "outofshape", high1 = "fit", high2 = "athletic" },
}

local function bandFor(text, level)
    local band = BANDS[text]
    if level <= 1 then return band.low1 end
    if level <= 4 then return band.low2 end
    if level == 5 then return nil end
    if level <= 8 then return band.high1 end
    return band.high2
end

--- Der Stufen-Trait zu einer Stufe, wie die Uebersicht ihn ansetzt; nil auf
-- Stufe 5. Oeffentlich, damit der Mess-Mod die Baender gegen das Spiel halten
-- kann (Test Stufen-Traits, seit Mess-Mod 6.36.0).
-- @param skill "strength" oder "fitness"
function TF.Summary.levelTraitFor(skill, level)
    local text = (skill == "strength") and "UI_TF_eff_startstrength" or "UI_TF_eff_startfitness"
    return bandFor(text, level)
end

--- Welche Stufen-Traits die Figur nach der Erschaffung wirklich traegt.
--
-- Nur mit Beruf: ohne ihn ist die Startstufe nicht bekannt, und die
-- Uebersicht zeigt wie bisher, was gewaehlt ist.
-- @return table|nil  { drop = { [schluessel] = true }, add = { schluessel, ... } }
function TF.Summary.levelTraits(traitDefs, profession)
    if not (profession and TF.Live and TF.Live.entries and TF.Live.professionEntries) then return nil end
    local sums = { UI_TF_eff_startstrength = 0, UI_TF_eff_startfitness = 0 }
    local function count(entries)
        for _, entry in ipairs(entries or {}) do
            if sums[entry.text] and type(entry.value) == "number" then
                sums[entry.text] = sums[entry.text] + entry.value
            end
        end
    end
    local chosen = {}
    for _, traitDef in ipairs(traitDefs or {}) do
        count(TF.Live.entries(traitDef))
        if TF.traitNamespace(traitDef) == "base" then
            local key = TF.traitKey(traitDef)
            if key then chosen[key] = true end
        end
    end
    count(TF.Live.professionEntries(profession))
    local result = { drop = {}, add = {}, levels = {} }
    for text, sum in pairs(sums) do
        local level = 5 + sum
        if level < 0 then level = 0 end
        if level > 10 then level = 10 end
        result.levels[text] = level
        if level > 0 then
            local keep = bandFor(text, level)
            for _, key in pairs(BANDS[text]) do
                if chosen[key] and key ~= keep then result.drop[key] = true end
            end
            if keep and not chosen[keep] then result.add[#result.add + 1] = keep end
        end
    end
    table.sort(result.add)
    return result
end

--- @param opts table|nil  { living = true } fuer eine lebende Figur im Spiel
--               (Charakterfenster, TF_CharWindow, seit 0.14.6): ihre Traits
--               sind der Stand nach dem Start, das Spiel hat die Stufen-Traits
--               also schon gesetzt oder abgeloest. Die Vorhersage aus den
--               Startstufen (TF.Summary.levelTraits) entfaellt dann; sie
--               nahm sonst einen Trait weg, den die Figur durch Training
--               wirklich traegt, oder setzte einen dazu, den sie verloren hat.
function TF.Summary.gather(traitDefs, profession, opts)
    local found = {}
    -- Arbeitsliste: die gewaehlten Traits, dazu die Stufen-Traits, die das
    -- Spiel selbst setzt. Ein abgeloester Stufen-Trait (Fit bei Fitness 10)
    -- behaelt seine Startstufen-Zeile, denn die Stufen zaehlen weiter, und
    -- verliert seine hinterlegten Wirkungen; ein gesetzter (Athletic) bringt
    -- nur die hinterlegten mit, seine +4 Stufen hat niemand gewaehlt.
    local bands = nil
    if not (opts and opts.living) then
        bands = TF.safe("summary:bands", TF.Summary.levelTraits, traitDefs, profession)
    end
    local work = {}
    for _, traitDef in ipairs(traitDefs or {}) do
        local dropped = bands and TF.traitNamespace(traitDef) == "base"
            and bands.drop[TF.traitKey(traitDef) or ""] or false
        work[#work + 1] = { def = traitDef, static = not dropped, live = true }
    end
    for _, key in ipairs((bands and bands.add) or {}) do
        local def = TF.Live.baseTrait and TF.Live.baseTrait(key)
        if def then work[#work + 1] = { def = def, static = true, live = false, set = true } end
    end
    for _, item in ipairs(work) do
        local traitDef = item.def
        local key = TF.traitKey(traitDef)
        local label, cost
        local ok, value = pcall(function() return traitDef:getLabel() end)
        if ok and value then label = tostring(value) end
        -- Die Punktkosten sagen, ob der Trait gut oder schlecht ist; genau so
        -- faerbt Vanilla die Namen in seinen Listen ein.
        local okCost, points = pcall(function() return traitDef:getCost() end)
        if okCost and type(points) == "number" then cost = points end
        local source = label and { name = TF.fmt.plain(label), cost = cost, key = key,
                                   id = TF.traitId(traitDef) } or nil

        -- Das Mod eines fremden Traits, oder nil fuer Vanilla; sein Kuerzel
        -- steht dann an jeder Quelle dieses Traits.
        local mod = TF.Mods and TF.Mods.traitMod and TF.Mods.traitMod(traitDef) or nil
        if source and mod then source.tag = mod.tag end
        local entries = TF.Mods and TF.Mods.entriesFor and TF.Mods.entriesFor(traitDef)
            or TF.staticFor(traitDef)
        if not item.static then entries = {} end
        for _, entry in ipairs(entries) do
            -- `dead` heisst: die Zahl steht in der Engine, wirkt dort aber
            -- nicht mehr. Der Tooltip zeigt sie samt Begruendung, diese
            -- Uebersicht nicht: sie beantwortet "was tut meine Figur", und
            -- ein wirkungsloser Wert gehoert nicht in eine Summe.
            if not entry.dead then
                -- Gibt es eine Messung, gilt sie - wie im Tooltip. Eine
                -- Paketzeile wird nie gemessen, das Probe kennt nur unsere
                -- eigenen ids.
                local record = (entry.origin ~= "package") and TF.Probe and TF.Probe.get
                    and TF.Probe.get(key, entry.id)
                local shown = entry
                if record and record.value ~= nil and type(entry.value) == "number" then
                    shown = {}
                    for field, item in pairs(entry) do shown[field] = item end
                    shown.value = record.value
                    -- Weicht die Messung ab, markiert der Tooltip die Zeile;
                    -- die Uebersicht zeigte denselben Messwert bis 0.10.3
                    -- unauffaellig (Audit 20.09.2026).
                    if record.status == TF.STATUS.STALE then shown.measuredStale = true end
                end
                -- Ein vom Spiel gesetzter Stufen-Trait sagt, woher er kommt.
                if item.set and not shown.condition then
                    if shown == entry then
                        shown = {}
                        for field, value in pairs(entry) do shown[field] = value end
                    end
                    shown.condition = "UI_TF_note_bandset"
                end
                local src = source
                -- Eine Paketzeile an einem Vanilla-Trait nennt ihr Paket.
                if source and entry.origin == "package" and not mod and entry.pkg then
                    src = { name = source.name, cost = source.cost, key = source.key, id = source.id,
                            tag = entry.pkg.tag }
                end
                found[#found + 1] = { entry = shown, source = src }
            end
        end

        if item.live and TF.Live and TF.Live.entries then
            for _, entry in ipairs(TF.Live.entries(traitDef) or {}) do
                found[#found + 1] = { entry = entry, source = source }
            end
        end
        -- Die Kategorie-Boni nur hier, nicht in TF.Live.entries: der Tooltip
        -- zeigt sie gruppiert und eigens (TF.Live.spotting).
        if item.live and TF.Live and TF.Live.categoryEntries then
            for _, entry in ipairs(TF.Live.categoryEntries(traitDef) or {}) do
                found[#found + 1] = { entry = entry, source = source }
            end
        end
    end
    -- Der Beruf selbst: Foraging-Werte und Startstufen (TF.Live.professionEntries).
    if profession and TF.Live and TF.Live.professionEntries then
        local label
        -- Berufe fuehren ihren Anzeigenamen unter getUIName (Vanilla,
        -- populateProfessionList), nicht unter getLabel wie die Traits.
        local ok, value = pcall(function() return profession:getUIName() end)
        if ok and value then label = tostring(value) end
        if not label then
            local okName, name = pcall(function() return profession:getType():getName() end)
            label = okName and name and tostring(name) or nil
        end
        local source = label and { name = TF.fmt.plain(label), key = "profession", id = "profession" } or nil
        for _, entry in ipairs(TF.safe("summary:profession", TF.Live.professionEntries, profession) or {}) do
            -- Wie bei den Traits: ein wirkungsloser Wert gehoert nicht in die
            -- Summe. Betrifft die Dunkelheit der Berufe beim Sammeln, die das
            -- Spiel nie anwendet (forageSystem.lua:1869, Faktensweep 23.09.2026).
            if not entry.dead then
                found[#found + 1] = { entry = entry, source = source }
            end
        end
    end
    -- Athletic ersetzt den Ausdauer-Faktor von High Weight, statt mit ihm zu
    -- multiplizieren: IsoPlayer.updateEndurance setzt enddelta erst auf 2.9
    -- (OVERWEIGHT) und ueberschreibt ihn dann mit 0.8 (ATHLETIC). Gemessen am
    -- 13.09.2026: zusammen 0.5720 wie Athletic allein. Ohne diese Regel zeigte
    -- die Uebersicht 0.57 x 2.07 = x1.18 (Faktensweep 23.09.2026). Das Paar
    -- entsteht, wenn das Spiel Athletic aus der Startstufe setzt.
    local athletic = false
    for _, item in ipairs(found) do
        if item.entry.text == "UI_TF_eff_enduranceloss" and item.entry.note == "UI_TF_note_enddelta"
                and item.source and item.source.key == "athletic" then
            athletic = true
        end
    end
    if athletic then
        local kept = {}
        for _, item in ipairs(found) do
            local replaced = item.entry.text == "UI_TF_eff_enduranceloss"
                and item.entry.note == "UI_TF_note_enddelta"
                and item.source and item.source.key == "overweight"
            if not replaced then kept[#kept + 1] = item end
        end
        found = kept
    end
    return found
end

--- Ein Faktor, der auf eine Spanne desselben Stats trifft, skaliert sie.
--
-- Insomniac setzt die Einschlafverzoegerung auf 0 bis 60 Minuten, Night Owl
-- halbiert sie (SleepingEvent.doDelayToSleep: `delay = 1.0f`, spaeter
-- `delay *= 0.5f`). Die beiden landen in verschiedenen Eimern, weil ihre
-- Verrechnungsart verschieden ist - Spanne gegen Faktor -, und standen darum
-- als zwei Zeilen da, die der Leser selbst verrechnen musste. Zusammen sind
-- es 0 bis 30 Minuten, und genau das soll die Uebersicht sagen.
--
-- Skaliert wird nur, wenn Text, Einheit und Geltungsbereich gleich sind;
-- der Faktor-Eimer geht dann in der Spanne auf.
--
-- Nicht auf pctrange (Faktensweep 2, 23.09.2026): das ist eine Spanne von
-- Aenderungen in Prozent, und ein Faktor darauf waere (1 + p) x f - 1, nicht
-- p x f. Heute trifft das keine Zeile, aber eine Paketzeile koennte es. Die
-- Fussnote des Faktors zaehlt hier bewusst nicht mit: Night Owl traegt seit
-- dem Faktensweep 2 eine (nightowlcap) und muss Insomniacs Spanne trotzdem
-- halbieren.
local function scaleRanges(order)
    local kept = {}
    for _, bucket in ipairs(order) do
        local absorbed = false
        if bucket.how == "factor" then
            for _, other in ipairs(order) do
                -- Ein Faktor ist einheitenlos; die Spanne traegt ihre Einheit
                -- (Minuten). Die Einheit zaehlt nur, wenn der Faktor selbst
                -- eine hat - sonst passte "-50 %" nie auf "0 bis 60 min".
                if other.how == "range" and other.kind ~= "pctrange" and other.text == bucket.text
                        and (bucket.unit == nil or other.unit == bucket.unit)
                        and other.scope == bucket.scope then
                    local f = asFactor(bucket)
                    other.value = { other.value[1] * f, other.value[2] * f }
                    -- Die Fussnote der Spanne nennt die Basis ohne den
                    -- Faktor ("Basis 0 bis 60 min"); nach dem Skalieren
                    -- stimmt sie nicht mehr. Lieber keine als eine falsche.
                    other.note = nil
                    other.count = other.count + bucket.count
                    for _, source in ipairs(bucket.sources) do
                        other.sources[#other.sources + 1] = source
                    end
                    absorbed = true
                    break
                end
            end
        end
        if not absorbed then kept[#kept + 1] = bucket end
    end
    return kept
end

--- Fasst gesammelte Eintraege zusammen.
--
-- Der Eimer, in den ein Eintrag faellt, ist "Name + Einheit + Fussnote". Nur
-- was in allen dreien uebereinstimmt, ist derselbe Stat im selben Zusammenhang.
--
-- @return table  Liste von { group, text, kind, value, unit, note, sources }
--- Stats, deren Wert eine Stufe relativ zur Grundstufe 5 ist.
local LEVEL_TEXTS = { UI_TF_eff_startstrength = true, UI_TF_eff_startfitness = true }

function TF.Summary.merge(found)
    local buckets, order = {}, {}
    for _, item in ipairs(found) do
        local entry = item.entry
        local how = mergeKind(entry.kind, entry.text)
        -- `textArg` gehoert dazu: "Foraging radius for %1" ist je Kategorie
        -- ein eigener Stat.
        local id = tostring(entry.text) .. "|" .. tostring(entry.textArg)
            .. "|" .. tostring(entry.unit)
            .. "|" .. tostring(entry.note) .. "|" .. tostring(entry.scope) .. "|" .. how
        -- Spannen und Aussagen werden nicht verrechnet; identische Zeilen
        -- fallen trotzdem zusammen, sonst stuende "Cannot read books" doppelt.
        -- Bei einer Spanne gehoert deshalb der Wert zum Eimer (Bugjagd
        -- 20.09.2026): zwei Traits mit verschiedenen Spannen fielen sonst in
        -- eine Zeile, die nur die erste Spanne zeigte und beide als Quelle nannte.
        if how == "range" and type(entry.value) == "table" then
            id = id .. "|" .. tostring(entry.kind) .. "|" .. tostring(entry.value[1])
                .. "|" .. tostring(entry.value[2])
        end
        local bucket = buckets[id]
        if not bucket then
            bucket = {
                group = TF.Summary.GROUP[entry.text] or "crafting",
                text = entry.text, textArg = entry.textArg,
                unit = entry.unit, note = entry.note,
                kind = entry.kind, how = how, value = entry.value,
                scope = entry.scope, sources = {}, count = 0,
                -- Eine Zaehlung traegt ihre Menge mit (Rezeptnamen), damit
                -- zwei Traits, die dasselbe Rezept lehren, es nicht doppelt
                -- zaehlen. Kopie, nicht Verweis: der Eimer waechst.
                items = entry.items and (function()
                    local copy = {}
                    for name in pairs(entry.items) do copy[name] = true end
                    return copy
                end)() or nil,
                -- Der Geltungsbereich als Fallname, falls der Eintrag einen
                -- traegt. Nur der Eintrag weiss, ob seine Fussnote den
                -- Bereich einschraenkt oder den Wert erklaert.
                case = entry.case,
                -- Fuer den Fall, dass am Ende nur dieser eine Eintrag in
                -- der Zeile steht; sonst faellt die Bemerkung weg.
                hint = entry.hint,
                -- Stammt der erste Eintrag aus einer moeglicherweise
                -- veralteten Paketzeile, gilt das fuer die ganze Zeile.
                stale = entry.pkg and entry.pkg.stale or nil,
                -- Gemessen und abweichend vom hinterlegten Wert (TF.Probe).
                measuredStale = entry.measuredStale or nil,
            }
            buckets[id] = bucket
            order[#order + 1] = bucket
        else
            if how == "factor" then
                if TF.Summary.NOSTACK[entry.text] then
                    -- Nicht stapelbar: der staerkere Einzelwert gewinnt. Der
                    -- Hinweis darauf kommt erst, wenn wirklich mehr als ein
                    -- Trait beitraegt - sonst stuende er auch dort, wo es
                    -- nichts zu stapeln gibt.
                    bucket.nostacked = true
                    local old, new = asFactor(bucket), asFactor(entry)
                    if math.abs(new - 1) > math.abs(old - 1) then
                        bucket.kind, bucket.value = entry.kind, entry.value
                    end
                else
                    -- Erst rechnen, dann umstellen. Andersherum liest
                    -- asFactor den alten pct-Wert bereits als Faktor: aus
                    -- -54 % und -50 % wurden so -2800 % statt -77 %.
                    local product = asFactor(bucket) * asFactor(entry)
                    bucket.kind = "mult"
                    bucket.value = product
                end
            elseif how == "flat" then
                if bucket.items and entry.items then
                    -- Zaehlung von Mengen: die Figur lernt die Vereinigung,
                    -- nicht die Summe. Gardener und Herbalist lehren beide
                    -- dieselben Anbauzeiten; addiert stuende "98", gelernt
                    -- sind 49 (Review 10.09.2026).
                    for name in pairs(entry.items) do bucket.items[name] = true end
                    local n = 0
                    for _ in pairs(bucket.items) do n = n + 1 end
                    bucket.value = n
                else
                    bucket.value = bucket.value + entry.value
                end
            elseif how == "fromto" then
                -- Beide gehen von derselben Basis aus, also die Aenderungen
                -- addieren: 20 -> 10 und 20 -> 30 ergibt zusammen 20 -> 20.
                bucket.value = { bucket.value[1],
                    bucket.value[2] + (entry.value[2] - entry.value[1]) }
            end
            -- Traegt ein weiterer Eintrag eine moeglicherweise veraltete
            -- Paketzeile bei, gilt das fuer die ganze Zeile, auch wenn der
            -- erste Eintrag selbst nicht veraltet war.
            if entry.pkg and entry.pkg.stale then bucket.stale = true end
            if entry.measuredStale then bucket.measuredStale = true end
        end

        bucket.count = bucket.count + 1
        -- Eine Bedingung gilt der ganzen Zeile: sie sagt, wann die Zahl genau
        -- stimmt, und das aendert sich nicht, wenn ein Trait mitrechnet, der
        -- davon unberuehrt ist. Anders als `hint` bleibt sie deshalb auch in
        -- der Summe stehen, jede nur einmal.
        if entry.condition then
            bucket.conditions = bucket.conditions or {}
            local known = false
            for _, condition in ipairs(bucket.conditions) do
                if condition == entry.condition then known = true break end
            end
            if not known then bucket.conditions[#bucket.conditions + 1] = entry.condition end
        end
        if item.source then
            local seen = false
            for _, source in ipairs(bucket.sources) do
                -- Zwei Quellen desselben Namens sind verschieden, wenn sie
                -- aus unterschiedlichen Paketen stammen (Strong DEMO gegen
                -- Strong eines anderen Pakets).
                if source.name == item.source.name and source.tag == item.source.tag then
                    seen = true break
                end
            end
            if not seen then bucket.sources[#bucket.sources + 1] = item.source end
        end
    end
    -- Die Startstufe bleibt zwischen 0 und 10: applyTraits addiert zur 5
    -- die Boosts der Traits und des Berufs und klemmt dann in beide
    -- Richtungen (IsoGameCharacter.java:10437-10438). Die Zeile zeigt die
    -- Summe aus Traits und Beruf (TF.Live.professionEntries, seit 0.12.0);
    -- ohne Beruf nur die Traits. Unter -5 sagt eine Bedingung, dass die Figur
    -- trotzdem bei 0 bleibt (Unfit und Very High Weight: -6, Audit
    -- 12.09.2026), ueber +5, dass sie bei 10 bleibt (Athletic +4 mit Fitness
    -- Instructor +3: +7, die Figur startet mit Fitness 10; Faktensweep 2,
    -- 23.09.2026). Die Zahl selbst bleibt die Summe: ohne Beruf ist die
    -- Startstufe nicht bekannt, und eine gekappte Zahl stimmte dann nicht.
    for _, bucket in ipairs(order) do
        if LEVEL_TEXTS[bucket.text] and type(bucket.value) == "number" then
            if bucket.value < -5 then
                bucket.conditions = bucket.conditions or {}
                bucket.conditions[#bucket.conditions + 1] = "UI_TF_note_levelfloor"
            elseif bucket.value > 5 then
                bucket.conditions = bucket.conditions or {}
                bucket.conditions[#bucket.conditions + 1] = "UI_TF_note_levelceil"
            end
        end
    end
    return scaleRanges(order)
end

--- Baut die fertigen Zeilen, nach Thema sortiert.
--
-- @param traitDefs Liste von CharacterTraitDefinition
-- @return table  Liste von { group = Schluessel, lines = { string, ... } }
--- Loest eine Ueberschneidung in ihre zwei Faelle auf.
--
-- @return table|nil  { both = Bucket, rest = Bucket } oder nil, wenn sich die
--                    beiden nicht ueberschneiden
local function splitOverlap(a, b)
    if a.text ~= b.text or a.unit ~= b.unit then return nil end
    if a.how ~= b.how then return nil end
    if a.how ~= "factor" and a.how ~= "flat" then return nil end
    local pair, aIsBroad = overlapPair(a.scope, b.scope)
    if not pair then return nil end
    local broad, narrow = a, b
    if not aIsBroad then broad, narrow = b, a end

    local sources = {}
    for _, name in ipairs(broad.sources) do sources[#sources + 1] = name end
    for _, name in ipairs(narrow.sources) do sources[#sources + 1] = name end

    local kind, value = broad.kind, nil
    if broad.how == "factor" then
        kind, value = "mult", asFactor(broad) * asFactor(narrow)
    else
        value = broad.value + narrow.value
    end

    -- Der Fall, in dem beide wirken. Die Fussnote der Teile entfaellt: der
    -- Fallname sagt schon, wofuer die Zeile gilt.
    local both = {
        group = broad.group, text = broad.text, unit = broad.unit,
        kind = kind, how = broad.how, value = value,
        sources = sources, count = broad.count + narrow.count,
        case = pair.both,
        -- Eine Markierung an einem der beiden Teile gilt auch fuer ihre Summe.
        stale = broad.stale or narrow.stale or nil,
        measuredStale = broad.measuredStale or narrow.measuredStale or nil,
        textArg = broad.textArg,
    }
    -- Die Bedingungen beider Teile gelten auch fuer ihre Summe; bis zum
    -- Faktensweep 2 (23.09.2026) fielen sie hier weg. Ein hint braucht das
    -- nicht: "both" hat immer mehr als einen Eintrag, und dann zeigt build
    -- keinen hint.
    for _, part in ipairs({ broad, narrow }) do
        for _, condition in ipairs(part.conditions or {}) do
            both.conditions = both.conditions or {}
            local known = false
            for _, have in ipairs(both.conditions) do
                if have == condition then known = true break end
            end
            if not known then both.conditions[#both.conditions + 1] = condition end
        end
    end
    -- Der Rest des breiten Bereichs: nur der breite Trait, mit seiner eigenen
    -- Fussnote ("except Fitness and Strength").
    local rest = {}
    for field, item in pairs(broad) do rest[field] = item end
    rest.case = pair.rest
    return { both = both, rest = rest }
end

--- Die Wertzelle einer Zeile: was vorn steht, und in welcher Farbe.
--
-- Der Wert steht vorn, und seine Farbe sagt, ob er hilft oder schadet. Eine
-- Aussage ohne Zahl traegt an derselben Stelle ein + oder ein x - dieselbe
-- Auskunft, nur ohne Groesse. Uebersicht und Tooltip nehmen beide diese
-- Funktion; die Farbe eines Werts darf zwischen den beiden nicht springen.
--
-- @param text   Uebersetzungsschluessel des Stats (Zeile in BETTER)
-- @param kind   Wertart des Eintrags
-- @param value  roher Wert des Eintrags (Zahl oder Vorher/Nachher-Paar)
-- @param shown  fertig formatierter Wert, oder nil bei einer Aussage ohne Zahl
-- @return string, string  Zellentext und Palettenname
function TF.Summary.valueCell(text, kind, value, shown)
    local richtung = TF.Summary.direction(text, value, kind)
    local farbe = (richtung == "gut" and "good")
        or (richtung == "schlecht" and "bad") or "value"

    -- Ohne Zahl steht das Zeichen fuer die Richtung. Es kommt aus der
    -- Uebersetzung, nicht aus dem Code: das Gradzeichen stand einmal als
    -- Literal in einer .lua und kam im Spiel falsch an. Ist die Richtung
    -- offen, bleibt die Spalte leer - lieber keine Auskunft als eine geratene.
    -- Eine Aussage ohne Richtung bekommt ein neutrales Zeichen. Bis zum
    -- 10.09.2026 gab es keine; mit "Folgt der Strength-Stufe" stuende die
    -- Bezeichnung sonst ohne alles in der zweiten Spalte, als fehlte etwas.
    local vorn = shown
    if not vorn then
        vorn = (richtung == "gut" and TF.fmt.text("UI_TF_sym_gain"))
            or (richtung == "schlecht" and TF.fmt.text("UI_TF_sym_lose"))
            or TF.fmt.text("UI_TF_sym_open")
    end
    return vorn, farbe
end

--- Eine fertige Zeile, wahlweise in Spalten oder durchlaufend.
--
-- Der Spaltensatz beantwortet die Frage, die die Uebersicht bisher offen
-- liess: der Wert steht vorn, alle Zahlen fluchten untereinander, und seine
-- Farbe sagt, ob er hilft oder schadet.
local function renderLine(bucket, value, note, spalten)
    -- `textArg` fuellt das %1 der Bezeichnung: der Kategoriename in
    -- "Foraging radius for %1".
    local label = bucket.textArg and TF.fmt.text(bucket.text, bucket.textArg)
        or TF.fmt.text(bucket.text)
    -- Eine Bezeichnung steht einmal, oder jede ihrer Zeilen sagt selbst,
    -- wofuer sie gilt. `case` ist ein Uebersetzungsschluessel: aus OVERLAP
    -- bei einer Ueberschneidung, sonst der Geltungsbereich des Eintrags.
    if bucket.case then
        label = label .. ", " .. TF.fmt.text(bucket.case)
    end
    if not spalten then
        return TF.fmt.line(label, value, note)
    end

    local vorn, farbe = TF.Summary.valueCell(bucket.text, bucket.kind, bucket.value, value)
    -- Eine moeglicherweise veraltete Paketzeile sticht die Richtungsfarbe:
    -- erst zaehlt, dass die Zahl unsicher ist, dann, ob sie hilft.
    if bucket.stale or bucket.measuredStale then farbe = "stale" end

    return TF.fmt.columns({
        { text = vorn, color = farbe, align = "right",
          x = spalten.value.x, width = spalten.value.width },
        { text = label, color = "label",
          x = spalten.label.x, width = spalten.label.width },
        { runs = note, x = spalten.note.x, width = spalten.note.width },
    })
end

--- Die 3-Kachel-Untergrenze beim Sammeln (Faktensweep 2, 23.09.2026).
--
-- Zwei Radien, beide mit Untergrenze 3 (Faktensweep 3, 23.09.2026; bis
-- 0.14.1 stand hier fuer beide "je Stufe eine halbe Kachel"). Der Suchradius
-- im Suchmodus (ISSearchManager.lua:1016-1052, im Spiel "Search Radius"):
-- 3 + Bonus + 0.7 x Stufe, geklemmt auf mindestens 3; ein Abzug kostet bei
-- Nahrungssuche 0 nichts und je Stufe 0,7 Kacheln mehr, bis er ganz wirkt
-- (Short Sighted und Agoraphobic ab Stufe 3). Das Entdecken eines
-- Gegenstands (ISBaseIcon.lua:318-376): 3 + 0.5 x Stufe + Bonus, geklemmt
-- auf mindestens 3, dann x (Stufe + 1)/10 und x (ln Gewicht + 0.5)
-- (forageSystem.lua:1773-1779), danach wieder mindestens 3 x visionBonus.
-- Bei leichten Gegenstaenden liegt das oft auch auf hoher Stufe auf der
-- Untergrenze. TF.Live gibt jedem negativen Radius die Bedingung mit; sie
-- gilt aber nur, solange auch die Zeile negativ ist. In einer Summe mit
-- positiven Radien (Agoraphobic mit Eagle Eyed) faellt sie weg, und in der
-- Schnittmenge einer Ueberschneidung (ohne Brille) kommt sie dazu, wenn die
-- Summe dort negativ ist. Neue Tabelle statt Aenderung an Ort und Stelle:
-- der Rest einer Ueberschneidung teilt sie sonst mit seinem Ursprung.
local SIGHT_FLOOR = "UI_TF_note_sightfloor"
local function sightFloor(bucket)
    if bucket.text ~= "UI_TF_live_sight" then return end
    local kept = {}
    for _, condition in ipairs(bucket.conditions or {}) do
        if condition ~= SIGHT_FLOOR then kept[#kept + 1] = condition end
    end
    if type(bucket.value) == "number" and bucket.value < -0.0001 then
        kept[#kept + 1] = SIGHT_FLOOR
    end
    bucket.conditions = (#kept > 0) and kept or nil
end

--- @param width number  nutzbare Breite des Panels; ab TF.Summary.MIN_COLUMN_WIDTH
--                entsteht der Spaltensatz, darunter der durchlaufende Text
-- @param opts table|nil  an TF.Summary.gather durchgereicht ({ living = true })
function TF.Summary.build(traitDefs, width, profession, opts)
    local spalten = TF.Summary.columnsFor(width)
    local merged = TF.Summary.merge(TF.Summary.gather(traitDefs, profession, opts))

    -- Ueberschneidungen aufloesen: aus breit und eng werden zwei Faelle, und
    -- der enge Beitrag allein entfaellt. Benannter Fall zuerst, der Rest
    -- danach - "all other skills" ist ein Rueckverweis und braucht etwas,
    -- worauf er sich bezieht.
    local ordered, used = {}, {}
    for index, bucket in ipairs(merged) do
        if not used[index] then
            local split, partner = nil, nil
            for later = index + 1, #merged do
                if not used[later] then
                    split = splitOverlap(bucket, merged[later])
                    if split then partner = later break end
                end
            end
            if split then
                used[partner] = true
                ordered[#ordered + 1] = split.both
                ordered[#ordered + 1] = split.rest
            else
                ordered[#ordered + 1] = bucket
            end
        end
    end

    -- Die Kategorie-Zeilen gehoeren direkt unter die Kachel-Zeile, groesster
    -- Bonus zuerst, bei Gleichstand nach Namen. Nach erstem Auftreten
    -- standen die Kategorien eines zweiten Traits sonst hinter dem
    -- Wetterabzug. Ohne Kachel-Zeile (Angler, Whittler, Mason geben nur
    -- Prozente) stehen sie am Ende ihres Themas.
    local kategorien, uebrige = {}, {}
    for _, bucket in ipairs(ordered) do
        if bucket.text == "UI_TF_live_spotfor" then
            kategorien[#kategorien + 1] = bucket
        else
            uebrige[#uebrige + 1] = bucket
        end
    end
    if #kategorien > 0 then
        table.sort(kategorien, function(a, b)
            local va, vb = tonumber(a.value) or 0, tonumber(b.value) or 0
            if va ~= vb then return va > vb end
            return tostring(a.textArg) < tostring(b.textArg)
        end)
        local nach = 0
        for index, bucket in ipairs(uebrige) do
            if bucket.text == "UI_TF_live_sight" then nach = index end
        end
        ordered = {}
        if nach == 0 then nach = #uebrige end
        if nach == 0 then
            for _, bucket in ipairs(kategorien) do ordered[#ordered + 1] = bucket end
        end
        for index, bucket in ipairs(uebrige) do
            ordered[#ordered + 1] = bucket
            if index == nach then
                for _, kategorie in ipairs(kategorien) do ordered[#ordered + 1] = kategorie end
            end
        end
    end

    -- Kommt eine Bezeichnung in einem Thema mehr als einmal vor, sagt jede
    -- Zeile, wofuer sie gilt: Outdoorsy am Grill, Bushcrafter am Lagerfeuer.
    -- Den Fallnamen bringt der Eintrag selbst mit (`case`); steht er in der
    -- Fussnote, entfaellt sie dort, sonst stuende der Bereich zweimal. Ohne
    -- eigenen Fallnamen bleibt die Bezeichnung, wie sie ist: bei Clumsy und
    -- Dextrous an der Kletter-Sicherheit ist die Fussnote eine Erklaerung
    -- ("base 20 for a new character"), kein Bereich, und gehoert nicht in
    -- die Bezeichnung. Die erste Fassung hat genau das getan.
    local perText = {}
    for _, bucket in ipairs(ordered) do
        local key = tostring(bucket.group) .. "|" .. tostring(bucket.text)
        perText[key] = (perText[key] or 0) + 1
    end
    for _, bucket in ipairs(ordered) do
        local key = tostring(bucket.group) .. "|" .. tostring(bucket.text)
        if perText[key] > 1 and bucket.case and bucket.case == bucket.note then
            bucket.note = nil
        end
        -- Steht die Bezeichnung nur einmal, braucht sie keinen Fallnamen; die
        -- Fussnote sagt dann, wofuer der Wert gilt. Ueberschneidungen sind
        -- die Ausnahme: dort ist der Fallname die einzige Stelle, die die
        -- beiden Faelle auseinanderhaelt.
        if perText[key] == 1 and bucket.case == bucket.note then
            bucket.case = nil
        end
    end

    -- Traits, die in mindestens einer gezeigten Zeile als Quelle stehen, nach
    -- voller ID (TF.traitId). Ein fremder Trait darunter braucht keinen
    -- Eintrag unter "Nicht hinterlegt" mehr, er ist oben schon zu sehen. Mit
    -- dem Pfad allein (0.3.3) verschwand ein fremder "xyz:resilient" ohne
    -- Daten, sobald Vanilla-Resilient oben stand (Review 15.09.2026).
    local shownIds = {}

    local byGroup = {}
    for _, bucket in ipairs(ordered) do
        sightFloor(bucket)
        -- Ein Faktor, der auf genau 1.0 herauskommt, hebt sich auf. Die Zeile
        -- "+0 %" waere korrekt und trotzdem nutzlos - ausser sie traegt eine
        -- Bedingung: dann heben sich die Traits nur in diesem einen Fall auf.
        -- Thin-skinned (x2) mit Outdoorsy (x0.5) ergibt bei den Kratzern von
        -- Baeumen genau 1.0, aber nur beim Gehen ohne Kleidung; rennend sind
        -- es -25 %, mit 30 Punkten Kleidung +23 % (IsoGameCharacter.java:
        -- 3854-3872, aeusserer und innerer Wurf). Bis 0.14.0 verschwand die
        -- Zeile samt Bedingung, und die Uebersicht sagte damit "hebt sich auf"
        -- (Faktensweep 2, 23.09.2026). UI_TF_note_bandset zaehlt nicht: sie
        -- sagt, woher ein Trait kommt, nicht wann die Zahl stimmt.
        local drop = false
        if bucket.how == "factor" and math.abs(asFactor(bucket) - 1) < 0.0001 then
            local bedingt = false
            for _, condition in ipairs(bucket.conditions or {}) do
                if condition ~= "UI_TF_note_bandset" then bedingt = true end
            end
            if bedingt then
                -- Genau 1, damit keine Rundung "-0 %" daraus macht.
                bucket.kind, bucket.value = "mult", 1
            else
                drop = true
            end
        end
        -- Mit Toleranz wie die beiden Nachbarregeln: flat-Werte werden in
        -- Gleitkomma summiert, und -1.5 + 0.4 + 0.4 + 0.7 ist -1.1e-16, nicht 0.
        -- Exakt verglichen blieb eine rote Zeile "-0 tiles" stehen (Bugjagd
        -- 10.09.2026, Fund 4). Die Typpruefung haelt die Regel so wurffest
        -- wie den alten Vergleich.
        if bucket.how == "flat" and type(bucket.value) == "number"
                and math.abs(bucket.value) < 0.0001 then
            drop = true
        end
        -- Vorher/Nachher mit gleichem Ende behauptet eine Aenderung, die es
        -- nicht gibt: Clumsy und Dextrous heben sich bei der Dose auf.
        if bucket.how == "fromto" and type(bucket.value) == "table"
                and math.abs(bucket.value[2] - bucket.value[1]) < 0.0001 then
            drop = true
        end

        if not drop then
            local palette = TF.fmt.palette
            for _, source in ipairs(bucket.sources or {}) do
                if source.id then shownIds[source.id] = true end
            end

            -- Die Zusatzangaben einmal sammeln: sie sind in beiden Satzarten
            -- dieselben, nur die Farbgebung unterscheidet sich.
            local zusatz = {}
            if bucket.stale then zusatz[#zusatz + 1] = TF.fmt.text("UI_TF_ext_stale_short") end
            if bucket.measuredStale then zusatz[#zusatz + 1] = TF.fmt.text("UI_TF_stale") end
            if bucket.note then zusatz[#zusatz + 1] = TF.fmt.text(bucket.note) end
            -- Eine Randbemerkung gilt einem einzelnen Trait, nicht einer
            -- Summe. Steht in der Zeile genau ein Eintrag, ist sie eindeutig
            -- seine; sobald mehrere zusammenfallen, waere unklar, auf welchen
            -- Anteil sie sich bezieht.
            if bucket.hint and bucket.count == 1 then
                zusatz[#zusatz + 1] = TF.fmt.text(bucket.hint)
            end
            for _, condition in ipairs(bucket.conditions or {}) do
                zusatz[#zusatz + 1] = TF.fmt.text(condition)
            end
            if bucket.nostacked then
                zusatz[#zusatz + 1] = TF.fmt.text("UI_TF_note_nostack")
            end

            -- Im Spaltensatz traegt der Name seine eigene Farbe und die
            -- Fussnote ihre. Ein fremder Trait bekommt sein Kuerzel als
            -- eigenen Lauf dahinter, mit seinem eigenen Farbnamen
            -- (TF.fmt.tagKey, die Farbe seines Mods), also beginnt
            -- TF.fmt.columns davor und danach ein neues Segment, und
            -- TF.Panel.tagBoxes findet das Kuerzel. Mit "note" klebte die
            -- Fussnote daran ("TOC; may be outdated", Abschlussreview
            -- 14.09.2026, Fund 1). Das Komma haengt am vorigen Namen, sonst
            -- stuende im Umbruch ein Leerzeichen davor. Hinter einem Kuerzel
            -- ist es dessen tail: es bricht mit ihm um, steht aber als
            -- eigenes Segment eine <SPACE>-Breite rechts, in der Farbe der
            -- Namen wie in der Startskill-Liste. Im Segment "TOC," lag die
            -- rechte Rahmenlinie des Kaestchens auf dem Komma, und es war im
            -- Spiel nicht zu sehen (Befund 14.09.2026).
            --
            -- Namen und Fussnote trennt seit 24.09.2026 der Trenner " U+00B7 "
            -- (TF.fmt.sep, bis 0.14.4 ein ";" am letzten Namen), ebenso die
            -- Zusatzangaben untereinander. Er steht vorn im Lauf der
            -- Fussnote; TF.fmt.columns haengt ihn fuer den Umbruch an den
            -- letzten Namen und setzt ihn blau (Palettenname "sep").
            local mark = TF.fmt.sep()
            local runs = nil
            if spalten then
                runs = {}
                for index, source in ipairs(bucket.sources) do
                    local sep = (index == #bucket.sources) and "" or ","
                    if source.tag then
                        runs[#runs + 1] = { text = source.name, color = "source" }
                        runs[#runs + 1] = { text = source.tag, color = TF.fmt.tagKey(source.tag),
                                            tail = sep, tailColor = "source" }
                    else
                        runs[#runs + 1] = { text = source.name .. sep, color = "source" }
                    end
                end
                if #zusatz > 0 then
                    runs[#runs + 1] = { text = mark .. " " .. table.concat(zusatz, " " .. mark .. " "),
                                        color = "note", sepColor = "sep" }
                end
            end

            -- Durchlaufend: TF.fmt.line faerbt die Trenner (TF_Format,
            -- paintSeps) und kehrt danach zur Farbe der Fussnote zurueck;
            -- darum steht hier kein eigenes Farbtag mehr. Ein <SPACE> am
            -- Ende (hinter einem Kuerzel) faellt weg, sonst stuende der
            -- Punkt eine Leerzeichenbreite zu weit rechts.
            local note = TF.Summary.sourceText(bucket.sources, palette)
            if #zusatz > 0 then
                if #note >= #SPACE and string.sub(note, -#SPACE) == SPACE then
                    note = string.sub(note, 1, #note - #SPACE)
                end
                note = TF.fmt.sepJoin(note, table.concat(zusatz, " " .. mark .. " "))
            end
            -- Was die Engine deckelt, deckeln wir auch.
            local shown = bucket.value
            local cap = TF.Summary.CAP[bucket.text]
            if cap and type(shown) == "number" then
                if shown > cap then shown = cap end
                if shown < -cap then shown = -cap end
            end

            local value
            if bucket.kind ~= "info" then
                value = TF.fmt.value(bucket.kind, shown)
                if value then value = value .. TF.fmt.unit(bucket.unit, shown) end
            end
            if value ~= nil or bucket.kind == "info" then
                byGroup[bucket.group] = byGroup[bucket.group] or {}
                local lines = byGroup[bucket.group]
                lines[#lines + 1] = { text = bucket.text,
                    line = renderLine(bucket, value, runs or note, spalten) }
            end
        end
    end

    local result = {}
    for _, group in ipairs(TF.Summary.ORDER) do
        local entries = byGroup[group]
        if entries then
            -- Zeilen zum selben Stat gehoeren nebeneinander. Ohne das stand im
            -- Spiel zwischen zwei Foraging-Radien eine Zeile ueber Rezepte, und
            -- zwei Zeilen zur Kletter-Sicherheit lagen weit auseinander.
            -- Die Reihenfolge der Stats bleibt die des ersten Auftretens.
            local order, seen = {}, {}
            for _, item in ipairs(entries) do
                if not seen[item.text] then
                    seen[item.text] = true
                    order[#order + 1] = item.text
                end
            end
            local lines = {}
            for _, text in ipairs(order) do
                for _, item in ipairs(entries) do
                    if item.text == text then lines[#lines + 1] = item.line end
                end
            end
            result[#result + 1] = { group = group, lines = lines }
        end
    end

    -- Fremde Traits ohne Paketzeilen: eigenes Thema am Ende (Spec 6.4). Ein
    -- Trait mit mindestens einer Paketzeile steht schon oben in seinem
    -- eigenen Thema und darf hier nicht doppelt auftauchen. Seit 15.09.2026
    -- ebenso ein Trait, der mit live gelesenen Werten oben steht (Amputee aus
    -- The Only Cure: Startskills, Rezepte): die Zeile hier wiederholte nur,
    -- was der Tooltip schon sagt ("only live values are shown"). Das Thema
    -- bleibt fuer fremde Traits, die sonst nirgends in der Uebersicht staenden.
    -- Eine Zeile je Mod, nicht je Trait (seit 0.5.0): More Traits Definitive
    -- definiert 96 Traits (mit ihren Untermods Disable Prepared und Disable
    -- Specialization bis zu 15 weniger), und eine Liste aus lauter gleichen Zeilen
    -- ("Trait X, Wirkungen aus ...") sagte nichts und schob die Themen
    -- darueber aus dem Bild (Befund im Spiel 16.09.2026). Gezaehlt wird je
    -- Mod, in der Reihenfolge des ersten Treffers.
    local seen, order = {}, {}
    for _, traitDef in ipairs(traitDefs or {}) do
        local mod = TF.Mods and TF.Mods.traitMod and TF.Mods.traitMod(traitDef) or nil
        local traitId = TF.traitId(traitDef)
        if mod and not TF.Mods.hasPackageRows(traitDef) and not (traitId and shownIds[traitId]) then
            local key = tostring(mod.id or mod.name)
            local entry = seen[key]
            if not entry then
                entry = { mod = mod, count = 0 }
                seen[key] = entry
                order[#order + 1] = entry
            end
            entry.count = entry.count + 1
        end
    end
    local missing = {}
    for _, entry in ipairs(order) do
        local mod, count = entry.mod, entry.count
        local note = TF.fmt.text(count == 1 and "UI_TF_ext_nodata_one" or "UI_TF_ext_nodata", count)
        local name = TF.fmt.plain(mod.name)
        if spalten then
            missing[#missing + 1] = TF.fmt.columns({
                { text = "", color = "value", align = "right", x = spalten.value.x, width = spalten.value.width },
                { runs = { { text = name, color = "source" }, { text = mod.tag, color = TF.fmt.tagKey(mod.tag) } },
                  x = spalten.label.x, width = spalten.label.width },
                { text = note, color = "note", x = spalten.note.x, width = spalten.note.width },
            })
        else
            -- Das Kuerzel bekommt ein eigenes Farbtag, kein blosses
            -- Anhaengen: Aufgabe 5 sucht es als eigenen Rich-Text-
            -- Abschnitt, wie am Namen in TF.Summary.sourceText.
            local palette = TF.fmt.palette
            local tagged = name .. TF.fmt.paint(palette, TF.fmt.tagKey(mod.tag)) .. SPACE .. mod.tag
            missing[#missing + 1] = TF.fmt.line(tagged, nil, note)
        end
    end
    if #missing > 0 then result[#result + 1] = { group = "notonfile", lines = missing } end
    return result
end
