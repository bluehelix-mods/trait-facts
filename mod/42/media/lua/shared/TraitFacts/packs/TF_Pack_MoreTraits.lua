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
--   nicht nur am amputierten Arm (MT_Combat.lua:696). Zu gross, um es
--   ungeprueft als Tatsache hinzuschreiben.
-- * Was im Code steht, aber nie greift: die Ausdauer- und Stresswerte von
--   Gourmand (tote Variablen), SuperImmuneFirstInfectionBonus und
--   QuickSuperImmune (nie geschrieben), die Scrounger-Hervorhebung.
--
-- Gym-Goer steht mit dem, was der Code tut (+10 % XP beim Training), nicht
-- mit dem, was die Beschreibung verspricht ("doppelt so wirksam").
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

rows["toadtraits:problade"] = {
    { id = "mtdamage", kind = "pct",  value = 12, text = "UI_TF_eff_meleedamage",
      note = "UI_TF_note_mt_bladeonly" },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_critchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critblade" },
    { id = "mtrepair", kind = "flat", value = 34, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_repairblade",
      better = "up", group = "combat" },
}

rows["toadtraits:problunt"] = {
    { id = "mtdamage", kind = "pct",  value = 12, text = "UI_TF_eff_meleedamage",
      note = "UI_TF_note_mt_bluntonly" },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_critchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critblunt" },
    { id = "mtrepair", kind = "flat", value = 34, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_repairblunt" },
}

rows["toadtraits:prospear"] = {
    { id = "mtdamage", kind = "pct",  value = 12, text = "UI_TF_eff_meleedamage",
      note = "UI_TF_note_mt_spearonly" },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_critchance",
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
    { id = "mtdamage", kind = "pct",  value = 10, text = "UI_TF_eff_meleedamage",
      note = "UI_TF_note_mt_improvised" },
    { id = "mtrepair", kind = "flat", value = 51, text = "UI_TF_eff_mt_weaponrepair",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_improvrepair" },
}

rows["toadtraits:actionhero"] = {
    { id = "mtcrowd", kind = "range", value = { 0.5, 25.5 }, text = "UI_TF_eff_mt_crowdbonus",
      unit = "UI_TF_unit_pct", note = "UI_TF_note_mt_crowd",
      better = "up", group = "combat" },
    { id = "mtcrit",  kind = "flat", value = 11, text = "UI_TF_eff_critchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critcrowd" },
}

rows["toadtraits:martial"] = {
    { id = "mtdamage", kind = "pct",  value = 10, text = "UI_TF_eff_meleedamage",
      note = "UI_TF_note_mt_barehands" },
    { id = "mtcrit",   kind = "flat", value = 6,  text = "UI_TF_eff_critchance",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_critbare" },
}

rows["toadtraits:unwavering"] = {
    { id = "mtdamage", kind = "pct", value = 125, text = "UI_TF_eff_meleedamage",
      note = "UI_TF_note_mt_unwavering" },
}

rows["toadtraits:mundane"] = {
    { id = "mtcritfix", kind = "info", text = "UI_TF_eff_mt_critfixed",
      better = "down", group = "combat" },
}

rows["toadtraits:terminator"] = {
    { id = "mtgundmg", kind = "pct",  value = 25,  text = "UI_TF_eff_mt_gundamage",
      note = "UI_TF_note_mt_terminator", better = "up", group = "combat" },
    { id = "mtrange",  kind = "flat", value = 5,   text = "UI_TF_eff_weaponsight",
      unit = "UI_TF_unit_tiles", note = "UI_TF_note_mt_terminator" },
    { id = "mtjam",    kind = "mult", value = 0.5, text = "UI_TF_eff_mt_jamchance",
      better = "down", group = "combat" },
    { id = "mtaim",    kind = "mult", value = 2,   text = "UI_TF_eff_aimdelay" },
    { id = "mtpanic",  kind = "flat", value = -10, text = "UI_TF_eff_mt_aimpanic",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_aimcalm",
      better = "down", group = "mind" },
    { id = "mtlevels", kind = "info", text = "UI_TF_eff_mt_startlevels",
      note = "UI_TF_note_mt_lv_terminator", better = "up", group = "learning" },
}

rows["toadtraits:antigun"] = {
    { id = "mtrange", kind = "flat", value = -5,  text = "UI_TF_eff_weaponsight",
      unit = "UI_TF_unit_tiles", note = "UI_TF_note_mt_rangefloor" },
    { id = "mtaim",   kind = "mult", value = 0.8, text = "UI_TF_eff_aimdelay" },
    { id = "mtmood",  kind = "flat", value = 0.6, text = "UI_TF_eff_mt_unhappyaim",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_aiming",
      better = "down", group = "mind" },
    { id = "mtxp",    kind = "pct",  value = -25, text = "UI_TF_eff_xp",
      note = "UI_TF_note_mt_aimxp" },
}

rows["toadtraits:batteringram"] = {
    { id = "mtram",    kind = "info", text = "UI_TF_eff_mt_rammed",
      better = "up", group = "combat" },
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
    { id = "mtarm",   kind = "info", text = "UI_TF_eff_mt_armheals",
      better = "up", group = "health" },
}

rows["toadtraits:burned"] = {
    { id = "mtfire",   kind = "info", text = "UI_TF_eff_mt_nofire",
      note = "UI_TF_note_mt_firetoggle", better = "down", group = "crafting" },
    { id = "mtinjury", kind = "info", text = "UI_TF_eff_mt_startinjury",
      note = "UI_TF_note_mt_inj_burned", better = "down", group = "health" },
}

rows["toadtraits:leadfoot"] = {
    { id = "mtstomp", kind = "mult", value = 2, text = "UI_TF_eff_mt_stomp",
      note = "UI_TF_note_mt_stomp", better = "up", group = "combat" },
}

-- Bewegung und Tragen ----------------------------------------------------

rows["toadtraits:fast"] = {
    { id = "mtmove", kind = "range", value = { 25, 75 }, text = "UI_TF_eff_mt_movedist",
      unit = "UI_TF_unit_pct", note = "UI_TF_note_mt_movedist",
      better = "up", group = "movement" },
}

rows["toadtraits:gimp"] = {
    { id = "mtmove", kind = "range", value = { -67.5, -22.5 }, text = "UI_TF_eff_mt_movedist",
      unit = "UI_TF_unit_pct", note = "UI_TF_note_mt_movedistgimp" },
}

rows["toadtraits:packmule"] = {
    { id = "mtcarry", kind = "flat", value = 2, text = "UI_TF_eff_carry",
      note = "UI_TF_note_mt_carrymule" },
}

rows["toadtraits:packmouse"] = {
    { id = "mtcarry", kind = "flat", value = -2, text = "UI_TF_eff_carry",
      note = "UI_TF_note_mt_carrymouse" },
}

rows["toadtraits:fitted"] = {
    { id = "mtclothw", kind = "mult", value = 0.5, text = "UI_TF_eff_mt_clothweight",
      better = "down", group = "movement" },
    { id = "mtcloths", kind = "info", text = "UI_TF_eff_mt_clothspeed",
      better = "up", group = "movement" },
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

rows["toadtraits:superimmune"] = {
    { id = "mtfever", kind = "range", value = { 10, 30 }, text = "UI_TF_eff_mt_feverdays",
      unit = "UI_TF_unit_days", note = "UI_TF_note_mt_fever",
      better = "down", group = "health" },
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

rows["toadtraits:restfulsleeper"] = {
    { id = "mtsleep", kind = "range", value = { 5, 20 }, text = "UI_TF_eff_mt_sleepfatigue",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_sleepfat",
      better = "up", group = "sleep" },
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

rows["toadtraits:drinker"] = {
    { id = "mtcrave",  kind = "flat", value = 7,  text = "UI_TF_eff_mt_drinkneed",
      unit = "UI_TF_unit_of100", note = "UI_TF_note_mt_drink",
      better = "down", group = "mind" },
    { id = "mtpoison", kind = "flat", value = 14, text = "UI_TF_eff_poison",
      unit = "UI_TF_unit_points", note = "UI_TF_note_mt_poison" },
    { id = "mtgear",   kind = "info", text = "UI_TF_eff_mt_startgear",
      note = "UI_TF_note_mt_gear_drinker", better = "up", group = "crafting" },
}

-- Lernen -----------------------------------------------------------------
-- Die Spezialisierungen kuerzen XP auf allen Skills ausserhalb ihrer Liste
-- (MT_XP.lua:44-104, SPEC_PERKS in Zeile 5). Die Boosts selbst liest Trait
-- Facts live, sie stehen unter den Startskills.

for _, key in ipairs({ "specweapons", "specfood", "specguns", "specmove",
                       "speccrafting", "specaid" }) do
    rows["toadtraits:" .. key] = {
        { id = "mtxp", kind = "pct", value = -75, text = "UI_TF_eff_xp",
          note = "UI_TF_note_mt_specxp" },
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
rows["toadtraits:noodlelegs"] = {
    { id = "mttrip", kind = "info", text = "UI_TF_eff_mt_trip",
      note = "UI_TF_note_mt_framerate", better = "down", group = "movement" },
    { id = "mttripsprint", kind = "mult", value = 1.67, text = "UI_TF_eff_mt_tripchance",
      note = "UI_TF_note_mt_tripsprint", better = "down", group = "movement" },
    { id = "mttripskill", kind = "mult", value = 0.67, text = "UI_TF_eff_mt_tripchance",
      note = "UI_TF_note_mt_tripskill" },
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
-- Beschreibung nennt zwei und "sie". 5 von 100 je Wurf, danach 60 Bilder Pause;
-- alle drei Werte sind Sandbox-Optionen.
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
-- (ToadTraits.txt ohne GrantedRecipes, kein Lua-Bezug).
rows["toadtraits:scrapper"] = {
    { id = "mtboosts",  kind = "info", text = "UI_TF_eff_mt_boostsonly" },
    { id = "mtrecipes", kind = "info", text = "UI_TF_eff_mt_norecipes",
      better = "down", group = "crafting" },
}

rows["toadtraits:wildsman"] = {
    { id = "mtrecipes", kind = "info", text = "UI_TF_eff_mt_norecipes" },
}

-- Handwerk und Start -----------------------------------------------------

rows["toadtraits:ingenuitive"] = {
    { id = "mtrecipes", kind = "info", text = "UI_TF_eff_mt_allrecipes",
      better = "up", group = "crafting" },
}

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

rows["toadtraits:deprived"] = {
    { id = "mtbare", kind = "info", text = "UI_TF_eff_mt_startbare",
      note = "UI_TF_note_mt_deprived", better = "down", group = "crafting" },
}

-- Fahrzeuge --------------------------------------------------------------

rows["toadtraits:expertdriver"] = {
    -- MT_World.lua:202: setEngineFeature(Qualitaet x2, Lautstaerke x0.25, Kraft x6).
    { id = "mtengine", kind = "mult", value = 6,    text = "UI_TF_eff_engineforce",
      note = "UI_TF_note_mt_driver" },
    { id = "mtspeed",  kind = "mult", value = 1.25, text = "UI_TF_eff_topspeed",
      note = "UI_TF_note_mt_driver" },
    { id = "mtbrake",  kind = "mult", value = 2,    text = "UI_TF_eff_mt_braking",
      note = "UI_TF_note_mt_driver", better = "up", group = "vehicles" },
}

rows["toadtraits:poordriver"] = {
    -- MT_World.lua:211: Kraft x0.5; die 0.66 gehoeren zum Tempomat (Z. 214).
    { id = "mtengine", kind = "mult", value = 0.5,  text = "UI_TF_eff_engineforce",
      note = "UI_TF_note_mt_driver" },
    { id = "mtspeed",  kind = "mult", value = 0.75, text = "UI_TF_eff_topspeed",
      note = "UI_TF_note_mt_driver" },
    { id = "mtbrake",  kind = "mult", value = 0.5,  text = "UI_TF_eff_mt_braking",
      note = "UI_TF_note_mt_driver" },
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
    traits = rows,
}
