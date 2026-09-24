--- Trait Facts - Messung an einer lebenden Figur.
--
-- Diese Mod wird nie veroeffentlicht. Sie nimmt in einem Durchgang alles auf,
-- was sich zur Laufzeit ueber Traits sagen laesst, und schreibt es in eine
-- Datei. Daraus wird danach am Rechner gegen TF_Static geprueft.
--
-- Warum es eine Figur braucht: der Container CharacterTraits hat genau drei
-- rechnende Getter (Nahkampfschaden, Ausdauerverlust, Wetterstrafe), und die
-- misst Trait Facts bereits beim Start. Alles Weitere haengt an
-- IsoGameCharacter und existiert erst, wenn eine Figur in der Welt steht.
--
-- Vorgehen je Trait, wie bei der statischen Messung:
--     baseline  = f(ohne Traits)
--     withTrait = f(nur dieser Trait)
-- Traits an- und abschalten ist eine unterstuetzte Operation: Vanilla macht
-- es selbst in ISPlayerStatsUI (Z. 594 und 669) ueber
-- getCharacterTraits():add() und :remove().
--
-- Die Traits der Figur werden vorher gesichert und danach genau so wieder
-- gesetzt. Trotzdem gilt: an einer Wegwerf-Figur laufen lassen.
--
-- Erfasst werden sechs Dinge:
--   1. Wirkungen  je Trait und Groesse, als Basiswert, Messwert und Differenz
--   2. Registry   Kosten, Rezepte, gewaehrte und ausgeschlossene Traits
--   3. Foraging   die Tabellen des Foraging-Systems, roh
--   4. XP         die Leiter der Boost-Stufen und die Faktoren von Fast und
--                 Slow Learner, direkt aus AddXP
--   5. Behaelter  Organized und Disorganized an einer erzeugten Tasche
--   6. Deckung    welcher Trait auf keine gemessene Groesse wirkt

TFMeasure = TFMeasure or {}

-- Beim Neuladen zur Laufzeit (F9) laeuft diese Datei ein zweites Mal. Die
-- Tabelle TFMeasure ueberlebt das, ihre Felder zeigen hier also noch auf die
-- Funktionen der vorigen Fassung - genau die muessen abgehaengt werden,
-- bevor sie ueberschrieben werden. Kahlua vergleicht Funktionen nach
-- Identitaet, eine neu erzeugte Funktion findet den alten Handler nicht.
for ereignis, feld in pairs({ OnKeyPressed = "reloadTaste", OnGameStart = "starten" }) do
    if TFMeasure[feld] then pcall(function() Events[ereignis].Remove(TFMeasure[feld]) end) end
end
for _, feld in ipairs({ "sprintTick", "carTick", "ausdauerTick" }) do
    if TFMeasure[feld] then pcall(function() Events.OnTick.Remove(TFMeasure[feld]) end) end
end

-- Das Messfenster (seit 6.18.0) haengt am UI-Manager, nicht an einem
-- Ereignis. Beim Neuladen muss das alte weg: sonst stuenden zwei da, und das
-- alte liefe mit dem alten Code weiter. War es offen, kommt es im naechsten
-- Tick aus dem neuen Code wieder (ganz unten).
if TFMeasure.fenster then
    local okOffen, offen = pcall(function() return TFMeasure.fenster:isVisible() end)
    TFMeasure.fensterWarOffen = okOffen and offen == true
    pcall(function() TFMeasure.fenster:setVisible(false) end)
    pcall(function() TFMeasure.fenster:removeFromUIManager() end)
    TFMeasure.fenster = nil
end
TFMeasure.Fenster = nil

--- Fassung dieses Mess-Mods.
--
-- Wird bei jeder Aenderung am Mess-Mod hochgezaehlt und muss mit dem Feld
-- modversion in mod.info uebereinstimmen (check-data.py, Regel 22). Der
-- Mod-Waehler zeigt nur mod.info an, und eine Nummer, die nie wandert, sagt
-- nichts darueber, welcher Code wirklich geladen ist. Deshalb steht sie
-- zusaetzlich in der ersten Logzeile und im Kopf des Berichts.
TFMeasure.VERSION = "6.47.0"

--- Ausgabedatei, liegt danach in Zomboid/Lua/.
TFMeasure.FILE = "TraitFacts_measure.txt"

--- Ausgabedatei der XP-Leiter (F8), ebenfalls in Zomboid/Lua/. Eigene
-- Datei, damit der grosse Bericht vom Weltbetreten stehen bleibt.
TFMeasure.XPFILE = "TraitFacts_xp.txt"

--- Die XP-Leiter auf F8 (seit 6.16.0, 12.09.2026).
--
-- Die Startskill-Liste zeigt je Skill "6.64x as fast" (TF_XpColumns). Belegt
-- war das bisher an einem Skill (Woodwork) auf Skillstufe 0; offen war, ob
-- es fuer andere Skills gilt, ob Boost 4 und mehr wirklich wie 3 laufen und
-- ob das Tempo auf hoeheren Stufen gleich bleibt. Darum je Skill jede
-- Boost-Stufe auf jeder Skillstufe: setPerkLevelDebug und setXPToLevel wie
-- Vanillas Debug-Fenster (ISStatsAndBody.lua:229-230), setPerkBoost, dann
-- `menge` XP ueber AddXP und den Zuwachs lesen. Stufe 10 fehlt: dort gibt
-- es keine XP mehr. Sprinting fuer seine eigene Regel bei Boost 1,
-- Strength und Fitness, weil sie in beiden Ausschlusslisten stehen.
TFMeasure.XP = {
    skills = { "Woodwork", "Blacksmith", "Maintenance", "Cooking", "Aiming",
               "Sprinting", "Strength", "Fitness" },
    boostBis = 5,
    stufeBis = 9,
    menge = 20,
}

--- Ausgabedatei des Kletterlaufs, ebenfalls in Zomboid/Lua/.
TFMeasure.KLETTERFILE = "TraitFacts_klettern.txt"

--- Der Kletterlauf (F8 in 6.17.x, seit 6.18.0 ein Test im Messfenster;
-- 12.09.2026).
--
-- getClimbingFailChanceFloat liefert nur die ganzzahlige Wurzel der
-- Sicherheitspunkte (Fitness x2 + Strength x2 + Nimble x2, Gewicht ab,
-- Clumsy halbiert, danach +-4 von Dextrous, Gymnast, Burglar, All Thumbs).
-- An einer neuen Figur sind das 20 Punkte, Wurzel 4.47, gelesen 4: ein
-- Trait mit +-4 verschwindet im Abrunden. So stand es am 10.09.2026 im
-- Bericht, All Thumbs, Dextrous, Gymnast und Burglar ohne Wirkung. Deshalb
-- je Fall Fitness, Strength und Nimble einzeln von 0 bis 10 (die beiden
-- anderen auf 0): irgendwo kippt jede Summe ueber eine Quadratzahl, und dort
-- zeigt sich jeder Term. Dazu getClimbRopeSpeed hoch und runter (Tempo am
-- Seil aus der effektiven Staerke) und getMaxWeight, das beim Umschalten
-- stehen bleiben muss (der Delta faellt im Konstruktor, Messung 10.09.2026).
--
-- Die Stufen setzt setPerkLevelDebug wie Vanillas Debug-Fenster. Setzt das
-- Spiel dabei Stufen-Traits (Puny, Weak, ... XpUpdate.lua:207-244), werden
-- sie vor dem Lesen entfernt und im Bericht als fremd vermerkt.
TFMeasure.KLETTERN = {
    faelle = { {}, { "clumsy" }, { "overweight" }, { "obese" }, { "dextrous" },
               { "allthumbs" }, { "gymnast" }, { "burglar" },
               { "clumsy", "dextrous" }, { "clumsy", "overweight" },
               { "weak" }, { "feeble" }, { "stout" }, { "strong" },
               { "athletic" }, { "fit" }, { "outofshape" }, { "unfit" },
               { "emaciated" }, { "veryunderweight" }, { "underweight" } },
    skills = { "Fitness", "Strength", "Nimble" },
    bis = 10,
}

--- Die Groessen, die gemessen werden.
--
-- `sicher` heisst: die Methode steht so im dekompilierten Build 42.20.4, die
-- Zeilennummer daneben. Die uebrigen sind Kandidaten - ihre Namen stammen aus
-- dem Bericht, sind aber im Spiel nicht bestaetigt. Ein Kandidat, den es nicht
-- gibt, kostet nichts: er wird einmal versucht und als "fehlt" gemeldet.
TFMeasure.PROBES = {
    -- IsoGameCharacter, bestaetigt
    { id = "grapple",         sicher = true,  quelle = "IsoGameCharacter:7917",
      call = function(p) return p:calculateGrappleEffectivenessFromTraits() end },
    { id = "chopTreeSpeed",   sicher = true,  quelle = "IsoGameCharacter:12388",
      call = function(p) return p:getChopTreeSpeed() end },
    { id = "hearDistanceMod", sicher = true,  quelle = "IsoGameCharacter:13934",
      call = function(p) return p:getHearDistanceModifier() end },
    { id = "detectionRange",  sicher = true,  quelle = "IsoGameCharacter:13952",
      call = function(p) return p:getDetectionRange() end },
    { id = "blurFactor",      sicher = true,  quelle = "IsoGameCharacter:14118",
      call = function(p) return p:getBlurFactor() end },
    { id = "awkwardHands",    sicher = true,  quelle = "IsoGameCharacter:14876",
      call = function(p) return p:hasAwkwardHands() end },
    { id = "maxWeight",       sicher = true,  quelle = "in Vanilla-Lua benutzt",
      call = function(p) return p:getMaxWeight() end },

    -- CharacterTraits, dieselben drei, die Trait Facts beim Start misst.
    -- Hier laufen sie mit, damit der Bericht fuer sich steht.
    { id = "meleeDamage",     sicher = true,  quelle = "CharacterTraits:132",
      call = function(p) return p:getCharacterTraits():getTraitDamageDealtReductionModifier() end },
    { id = "enduranceLoss",   sicher = true,  quelle = "CharacterTraits:146",
      call = function(p) return p:getCharacterTraits():getTraitEnduranceLossModifier() end },
    { id = "weatherPenalty",  sicher = true,  quelle = "CharacterTraits:150",
      call = function(p) return p:getCharacterTraits():getTraitWeatherPenaltyModifier() end },

    -- Am 10.09.2026 im Spiel gefunden. climbFailChance antwortet auf Clumsy,
    -- Overweight und Obese (Basis 4.0 -> 3.0 / 2.0 / 0.0), aber nicht auf
    -- All Thumbs, Dextrous, Burglar oder Gymnast, obwohl CharacterTraits fuer
    -- die Konstanten fuehrt. Was die Zahl bedeutet, ist damit offen; sie geht
    -- erst in die Mod, wenn die Methode selbst gelesen ist.
    { id = "climbFailChance", call = function(p) return p:getClimbingFailChanceFloat() end },
    { id = "pathSpeed",       call = function(p) return p:getPathSpeed() end },
    { id = "moveSpeed",       call = function(p) return p:getMoveSpeed() end },
    { id = "combatSpeed",     call = function(p) return p:calculateCombatSpeed() end },
    { id = "runSpeedMod",     call = function(p) return p:getRunSpeedModifier() end },
    { id = "wornHearingMod",  call = function(p) return p:getWornItemsHearingModifier() end },
    { id = "wornHearingMult", call = function(p) return p:getWornItemsHearingMultiplier() end },
    { id = "hyperthermiaMod", call = function(p) return p:getHyperthermiaMod() end },
    -- Am 10.09.2026 nicht vorhanden, bleiben als Merkposten fuer den naechsten
    -- Build: getClimbingStrength, getFallDamageMultiplier, getReadingSpeed,
    -- getMaxSightRange, getLowLightBonus, getTemperature.
}

--- Felder, die eine Trait-Definition selbst hergibt.
-- Auch hier gilt: was fehlt, wird als "-" gemeldet statt zu werfen.
-- Am 10.09.2026 im Spiel bestaetigt; isProfessionTrait und isRemovedInSandbox
-- gibt es nicht, sie standen hier und haben nur das Fehlerprotokoll gefuellt:
-- pcall faengt die Ausnahme, Project Zomboid schreibt sie trotzdem mit.
TFMeasure.DEFINITION = {
    { id = "label",    call = function(d) return d:getLabel() end },
    { id = "cost",     call = function(d) return d:getCost() end },
    { id = "mpBanned", call = function(d) return d:isDisabledInMultiplayer() end },
}

--- Listen von Definitionen, die als Namensliste in den Bericht sollen.
--
-- Kein XP-Boost: die Definition gibt ihn ueber keinen der versuchten Getter
-- her. Er steht ohnehin in media/scripts/generated/characters/
-- character_traits.txt und laesst sich dort ohne Spiel nachlesen.
TFMeasure.DEFINITION_LISTS = {
    { id = "recipes",  call = function(d) return d:getGrantedRecipes() end },
    { id = "grants",   call = function(d) return d:getGrantedTraits() end },
    { id = "excludes", call = function(d) return d:getMutuallyExclusiveTraits() end },
}

--- Meldungen mit Uhrzeit (seit 6.45.0, Wunsch vom 24.09.2026). Jede Meldung
-- des Mess-Mods geht ueber TFMeasure.melde: in die Command Console und
-- console.txt wie bisher, jetzt mit der Uhrzeit (Stunde, Minute, Sekunde)
-- hinter dem Kennzeichen. Kopieren laesst sich der Output Log seit 6.46.0
-- in der Command Console selbst (TFMeasureKonsole).

--- Die Uhrzeit des Rechners als "HH:MM:SS". os.date gibt es in Kahlua
-- (Vanilla ISUsersList); sonst Calendar mit den Feldnummern von
-- java.util.Calendar (11 HOUR_OF_DAY, 12 MINUTE, 13 SECOND).
function TFMeasure.uhrzeit()
    local ok, t = pcall(function() return os.date("%H:%M:%S") end)
    if ok and type(t) == "string" and string.match(t, "^%d%d:%d%d:%d%d$") then return t end
    local okCal, text = pcall(function()
        local c = Calendar.getInstance()
        return string.format("%02d:%02d:%02d", c:get(11), c:get(12), c:get(13))
    end)
    if okCal and type(text) == "string" then return text end
    return "--:--:--"
end

--- Gibt eine Meldung mit Uhrzeit aus.
-- @param kennung  z.B. "[TraitFactsMeasure]" oder "[TraitFactsMeasure] Menue:"
function TFMeasure.melde(kennung, text)
    print(tostring(kennung) .. " " .. TFMeasure.uhrzeit() .. " " .. tostring(text))
end

local function log(text)
    TFMeasure.melde("[TraitFactsMeasure]", text)
end

--- Wie lange eine Zeile ueber dem Kopf stehen bleibt.
--
-- HaloTextHelper kennt keine Dauer: seine Zeilen schweben hoch und sind weg,
-- egal wie lang sie sind. Bei einer Anweisung wie "Bereit - jetzt Vollgas
-- vorwaerts bis 50 km/h oder RUECKWAERTS bis 8 km/h" reicht das nicht zum
-- Lesen. IsoGameCharacter.setHaloNote(text, r, g, b, dauer) kann beides,
-- Farbe und Dauer (Signatur aus dem Jar geprueft).
--
-- Wie eine stehende Zeile lange stehen bleibt.
--
-- setHaloNote hat eine Dauer im Namen, aber der letzte Parameter ist ein
-- Uhrenstand fuer TextDrawObject.setInternalTickClock, und wie der genau
-- wirkt, war aus dem Bytecode nicht sicher abzuleiten: 14 ergab eine halbe
-- Sekunde, -325 gar keine Anzeige mehr (beides im Spiel am 11.09.2026
-- probiert). Zweimal geraten, zweimal daneben - also nicht weiterraten.
--
-- HaloTextHelper funktioniert nachweislich, kennt aber keine Dauer. Die
-- Loesung kommt aus seiner eigenen Schnittstelle: overheadContains(index,
-- text) sagt, ob eine Zeile gerade zu sehen ist. Eine stehende Anweisung
-- wird also einfach neu gesetzt, sobald sie verschwunden ist, und bleibt so
-- sichtbar, bis der Zustand wechselt. Kein Stapeln, weil erst gefragt wird.
TFMeasure.HALO = {
    -- So oft wird nachgesehen, ob die stehende Zeile noch da ist.
    pruefeAlle = 15,
    -- Ohne overheadContains kann man nicht nachsehen, also wird die Zeile
    -- stur alle zwei Sekunden neu gesetzt. Sie taucht dann in Abstaenden
    -- wieder auf, statt durchgehend zu stehen - besser als einmal kurz.
    wiederholeAlle = 120,
}

--- Die Zeile, die stehen bleiben soll, bis der Zustand wechselt.
TFMeasure.stehendeZeile = nil

--- Dasselbe zusaetzlich ueber den Kopf der Figur.
--
-- Waehrend eines Tests haelt der Spieler eine Taste und sieht die Figur, nicht
-- die Konsole; eine Meldung, die nur ins Log geht, erreicht ihn dort nicht.
-- `gut` faerbt gruen, `false` rot, nil neutral.
--
-- Erst setHaloNote mit Dauer, und nur wenn es die Methode nicht gibt, der
-- Rueckfall auf HaloTextHelper (so macht es Vanilla in forageClient.lua:73).
local function halo(player, text, gut)
    log(text)
    if not player then return end
    if not HaloTextHelper then return end
    if gut == true and HaloTextHelper.addGoodText then
        HaloTextHelper.addGoodText(player, text)
    elseif gut == false and HaloTextHelper.addBadText then
        HaloTextHelper.addBadText(player, text)
    elseif HaloTextHelper.addText then
        HaloTextHelper.addText(player, text)
    end
end

--- Eine Java-Liste als Lua-Liste von Zeichenketten. Leere Liste, wenn die
-- Sammlung fehlt oder nicht zaehlbar ist.
local function toStrings(collection)
    local out = {}
    if not collection then return out end
    local ok = pcall(function()
        local size = collection:size()
        for index = 0, size - 1 do
            local item = collection:get(index)
            local text
            if type(item) == "string" or type(item) == "number" then
                -- Rezeptnamen kommen als String; ein getName darauf warf
                -- (Mod-Bericht vom 10.09.2026, zehn Meldungen).
                text = tostring(item)
            elseif type(item) == "userdata" then
                local okName = pcall(function() text = item:getName() end)
                if not okName or text == nil then text = tostring(item) end
            else
                text = tostring(item)
            end
            if text ~= nil then out[#out + 1] = tostring(text) end
        end
    end)
    if not ok then return {} end
    table.sort(out)
    return out
end

--- Zahl aus einem Rueckgabewert, auch aus true/false.
local function asNumber(value)
    if type(value) == "number" then return value end
    if value == true then return 1 end
    if value == false then return 0 end
    return nil
end

--- Liest alle verfuegbaren Groessen einmal ab.
local function readAll(player, probes)
    local out = {}
    for _, probe in ipairs(probes) do
        local ok, value = pcall(probe.call, player)
        if ok then
            local number = asNumber(value)
            if number ~= nil then out[probe.id] = number end
        end
    end
    return out
end

--- Registry-Pfad eines Trait-Typs, klein und ohne Sonderzeichen - derselbe
-- Schluessel, unter dem TF_Static seine Eintraege fuehrt.
local function keyOf(traitType)
    local ok, name = pcall(function() return traitType:getName() end)
    if not ok or not name then return nil end
    return (tostring(name):lower():gsub("[^%a%d]", ""))
end

--- Welche Groessen an dieser Figur ueberhaupt lesbar sind.
-- @return table verfuegbare Proben, table Zeilen fuer den Bericht
local function checkProbes(player)
    local available, lines = {}, {}
    for _, probe in ipairs(TFMeasure.PROBES) do
        local ok, value = pcall(probe.call, player)
        local number = ok and asNumber(value) or nil
        if number ~= nil then
            available[#available + 1] = probe
            lines[#lines + 1] = string.format("%s|lesbar|%.6f|%s",
                probe.id, number, probe.quelle or "Kandidat")
        else
            lines[#lines + 1] = string.format("%s|fehlt|-|%s",
                probe.id, probe.sicher and "SOLLTE DA SEIN" or "Kandidat")
        end
    end
    return available, lines
end

--- Die Definition eines Traits als eine Zeile.
local function definitionLine(key, def)
    local parts = { key }
    for _, field in ipairs(TFMeasure.DEFINITION) do
        local ok, value = pcall(field.call, def)
        if ok and value ~= nil then
            parts[#parts + 1] = field.id .. "=" .. tostring(value)
        end
    end
    for _, list in ipairs(TFMeasure.DEFINITION_LISTS) do
        local ok, collection = pcall(list.call, def)
        if ok and collection then
            local names = toStrings(collection)
            if #names > 0 then
                parts[#parts + 1] = list.id .. "=" .. table.concat(names, ",")
            end
        end
    end
    return table.concat(parts, "|")
end

--- Die Foraging-Tabelle als Zeilen. Sie liegt in Lua, nicht in Java, und
-- laesst sich deshalb direkt abschreiben.
local function forageLines()
    local out = {}
    -- Die Tabelle heisst in Build 42.20.4 forageSystem.forageSkillDefinitions.
    -- Bis 6.15.1 stand hier ein globales forageSkills, das es nie gab; der
    -- Abschnitt war in jedem Lauf leer, und die Meldung "nicht geladen" sah
    -- nach einem Ladeproblem aus statt nach einem falschen Namen (Bugjagd
    -- 10.09.2026, Fund 20). Die Meldung nennt jetzt den Namen, den sie sucht.
    local defs = forageSystem and forageSystem.forageSkillDefinitions
    if type(defs) ~= "table" then
        out[#out + 1] = "# forageSystem.forageSkillDefinitions nicht lesbar"
        return out
    end
    local names = {}
    for name, def in pairs(defs) do
        if type(def) == "table" and def.type == "trait" then names[#names + 1] = name end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local def = defs[name]
        local parts = { (name:lower():gsub("[^%a%d]", "")) }
        parts[#parts + 1] = "vision=" .. tostring(def.visionBonus)
        parts[#parts + 1] = "weather=" .. tostring(def.weatherEffect)
        parts[#parts + 1] = "darkness=" .. tostring(def.darknessEffect)
        local gated = false
        if type(def.testFuncs) == "table" then
            for _ in pairs(def.testFuncs) do gated = true break end
        end
        parts[#parts + 1] = "gated=" .. tostring(gated)
        if type(def.specialisations) == "table" then
            local cats = {}
            for category, bonus in pairs(def.specialisations) do
                cats[#cats + 1] = tostring(category) .. ":" .. tostring(bonus)
            end
            table.sort(cats)
            if #cats > 0 then parts[#parts + 1] = "cats=" .. table.concat(cats, ",") end
        end
        out[#out + 1] = table.concat(parts, "|")
    end
    return out
end

--- Trait-Typ zu einem Registry-Pfad, ueber die Definitionen.
local function traitTypeNamed(wanted)
    local defs = CharacterTraitDefinition.getTraits()
    for index = 0, defs:size() - 1 do
        local def = defs:get(index)
        local traitType = def:getType()
        if keyOf(traitType) == wanted then return traitType end
    end
    return nil
end

-- Fuer die Mess-Befehle (TFMeasureBefehle.lua, seit 6.44.0, 24.09.2026): dieselben
-- Helfer statt einer zweiten Fassung.
TFMeasure.keyOf = keyOf
TFMeasure.traitTypeNamed = traitTypeNamed

--- Die XP-Leiter, direkt aus der Engine.
--
-- TF_XpColumns behauptet: ein Skill ohne Boost lernt mit 0.25, mit Boost-
-- Stufe 1/2/3 mit 1.0/1.33/1.66, Fitness, Strength und Sprinting sind von
-- der Senkung ausgenommen. Das ist die mutigste Aussage der Mod, sie
-- widerspricht Vanillas eigener Anzeige "+75 %/+100 %/+125 %", und sie war
-- bisher nur gelesen. getXp():getMultiplier(perk) liefert genau diesen
-- Faktor; setPerkBoost ist ein Kandidat, ohne ihn bleibt es bei Stufe 0.
--
-- Fast und Slow Learner (x1.3 / x0.7, IsoGameCharacter$XP.AddXP 15542-15546)
-- werden ueber AddXP selbst gemessen: dieselbe Menge dreimal, ohne Trait,
-- mit Fast Learner, mit Slow Learner, und die Differenz im XP-Stand
-- verglichen. Das schreibt XP auf die Figur - darum die Wegwerf-Figur.
-- Die Menge ist klein genug, dass keine Stufe faellt: ein Stufenwechsel bei
-- Strength oder Fitness setzt sonst die Traits um (XpUpdate.lua:207-244).
local function xpLines(player, container)
    local out = {}
    local xp = player:getXp()
    if not xp then
        out[#out + 1] = "# getXp() liefert nichts"
        return out
    end

    -- 1. Boost je Skill, wie die Figur gerade steht, dazu getMultiplier.
    --    Achtung: getMultiplier ist NICHT die Leiter, sondern der Faktor
    --    aus gelesenen Buechern (ISReadABook.lua:114); im Lauf vom
    --    10.09.2026 stand er ueberall auf 0. Er laeuft nur zur Einordnung mit.
    local perks = {}
    local ok = pcall(function()
        local list = PerkFactory.PerkList
        for index = 0, list:size() - 1 do
            local perk = list:get(index)
            perks[#perks + 1] = { name = tostring(perk:getName()), type = perk:getType() }
        end
    end)
    if not ok or #perks == 0 then
        -- Rueckfall: die Namen, die TF_XpColumns selbst unterscheidet.
        for _, name in ipairs({ "Woodwork", "Fitness", "Strength", "Sprinting", "Cooking" }) do
            if Perks and Perks[name] then perks[#perks + 1] = { name = name, type = Perks[name] } end
        end
    end
    for _, perk in ipairs(perks) do
        local okMult, mult = pcall(function() return xp:getMultiplier(perk.type) end)
        local okBoost, boost = pcall(function() return xp:getPerkBoost(perk.type) end)
        out[#out + 1] = string.format("boost|%s|boost=%s|buchfaktor=%s", perk.name,
            okBoost and tostring(boost) or "-", okMult and tostring(mult) or "-")
    end

    -- 2. Die Leiter: Boost-Stufe setzen, AddXP geben, Zuwachs lesen,
    --    zuruecksetzen. Erwartet nach TF_XpColumns: 20 XP werden zu
    --    5 / 20 / 26.6 / 33.2 bei Stufe 0 / 1 / 2 / 3.
    local woodwork = Perks and Perks.Woodwork
    if woodwork then
        local okSet = pcall(function()
            local original = xp:getPerkBoost(woodwork)
            for level = 0, 3 do
                xp:setPerkBoost(woodwork, level)
                local before = xp:getXP(woodwork)
                xp:AddXP(woodwork, 20)
                local after = xp:getXP(woodwork)
                out[#out + 1] = string.format("leiter|Woodwork|boost=%d|20 gegeben|erhalten=%.4f (x%.3f)",
                    level, after - before, (after - before) / 20)
            end
            xp:setPerkBoost(woodwork, original)
        end)
        if not okSet then out[#out + 1] = "# setPerkBoost fehlt, Leiter nur fuer Stufe 0 messbar" end
    end

    -- 3. Fast und Slow Learner ueber AddXP, an Woodwork (wird gesenkt) und
    --    Strength (von der Senkung ausgenommen).
    local fast, slow = traitTypeNamed("fastlearner"), traitTypeNamed("slowlearner")
    for _, name in ipairs({ "Woodwork", "Strength", "Sprinting" }) do
        local perk = Perks and Perks[name]
        if perk then
            local function gain(traitType)
                if traitType then container:add(traitType) end
                local before = xp:getXP(perk)
                xp:AddXP(perk, 20)
                local after = xp:getXP(perk)
                if traitType then container:remove(traitType) end
                return after - before
            end
            local okGain, base, withFast, withSlow = pcall(function()
                return gain(nil), gain(fast), gain(slow)
            end)
            if okGain and base and base > 0 then
                out[#out + 1] = string.format("addxp|%s|20 gegeben|ohne=%.4f|fastlearner=%.4f (x%.3f)|slowlearner=%.4f (x%.3f)",
                    name, base, withFast, withFast / base, withSlow, withSlow / base)
            else
                out[#out + 1] = string.format("addxp|%s|nicht messbar", name)
            end
        end
    end
    return out
end

--- Behaelterkapazitaet mit Organized und Disorganized.
--
-- ItemContainer.getEffectiveCapacity (Z. 205-214): x1.3 (mindestens +1)
-- beziehungsweise x0.7 (mindestens 1), aber nur bei einem Behaelter, dessen
-- Eltern kein Charakter, keine Leiche und kein Boden ist. Das eigene
-- Inventar zaehlt also nicht; gemessen wird an einer erzeugten Tasche, die
-- nie in die Welt kommt.
local function containerLines(player, container)
    local out = {}
    -- instanceItem ist die Lua-Fabrik (Vanilla ueberall, z. B. fuer
    -- Base.Generator); InventoryItemFactory gibt es in Lua nicht - der
    -- Versuch stand im Mod-Bericht vom 10.09.2026 dreimal als Fehler.
    local inv = nil
    if type(instanceItem) == "function" then
        for _, name in ipairs({ "Base.Bag_Schoolbag", "Base.Bag_ALICEpack", "Base.Bag_DuffelBag" }) do
            local ok, item = pcall(instanceItem, name)
            if ok and item and item.getInventory then
                local okInv, got = pcall(function() return item:getInventory() end)
                if okInv and got then
                    inv = got
                    out[#out + 1] = "# Tasche: " .. name
                    break
                end
            end
        end
    end
    -- Rueckfall: ein Behaelter in der Naehe der Figur (Kueche, Schrank).
    if not inv then
        pcall(function()
            local square = player:getCurrentSquare()
            local cell = getCell()
            for dx = -3, 3 do
                for dy = -3, 3 do
                    local sq = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
                    if sq then
                        local objects = sq:getObjects()
                        for index = 0, objects:size() - 1 do
                            local obj = objects:get(index)
                            local got = obj.getContainer and obj:getContainer()
                            if got and not inv then
                                inv = got
                                out[#out + 1] = "# Behaelter in der Naehe: " .. tostring(got:getType())
                            end
                        end
                    end
                end
            end
        end)
    end
    if not inv then
        out[#out + 1] = "# weder Tasche noch Behaelter in der Naehe"
        return out
    end
    local function effective() return inv:getEffectiveCapacity(player) end
    local okBase, capacity, base = pcall(function() return inv:getCapacity(), effective() end)
    if not okBase then
        out[#out + 1] = "# getEffectiveCapacity fehlt"
        return out
    end
    out[#out + 1] = string.format("basis|capacity=%s|effective=%s", tostring(capacity), tostring(base))
    for _, key in ipairs({ "organized", "disorganized" }) do
        local traitType = traitTypeNamed(key)
        if traitType then
            container:add(traitType)
            local okWith, value = pcall(effective)
            container:remove(traitType)
            if okWith and base and base ~= 0 then
                out[#out + 1] = string.format("%s|effective=%s|faktor=%.4f|differenz=%s",
                    key, tostring(value), value / base, tostring(value - base))
            end
        end
    end
    return out
end

--- Misst und schreibt den Bericht.
-- @return Anzahl der gemessenen Wirkungen
--- Die Live-Werte von Trait Facts (TraitFacts.Probed) als Zeilen, sortiert.
-- @return table, number  Zeilen und wie viele vom gespeicherten Wert abweichen
function TFMeasure.liveLines()
    local lines, abweichend = {}, 0
    local tf = TraitFacts
    if not (tf and type(tf.Probed) == "table") then return lines, 0 end
    for key, entries in pairs(tf.Probed) do
        for id, record in pairs(entries) do
            local stand = tostring(record.status)
            if tf.STATUS and record.status == tf.STATUS.STALE then
                abweichend = abweichend + 1
                stand = "WEICHT AB"
            elseif tf.STATUS and record.status == tf.STATUS.UNMEASURABLE then
                stand = "nicht lesbar: " .. tostring(record.reason)
            else
                stand = "gleich"
            end
            lines[#lines + 1] = string.format("%s|%s|%s|%s|%s", tostring(key), tostring(id),
                tostring(record.value), tostring(record.static), stand)
        end
    end
    table.sort(lines)
    return lines, abweichend
end

function TFMeasure.run(player)
    player = player or getSpecificPlayer(0)
    if not player then
        log("Keine Figur gefunden, Messung entfaellt.")
        return 0
    end
    local container = player:getCharacterTraits()
    if not container then
        log("getCharacterTraits() liefert nichts, Messung entfaellt.")
        return 0
    end

    -- Schnappschuss der eigenen Traits, als flache Liste. Die Liste der
    -- Engine wird gleich veraendert, deshalb erst kopieren.
    local held = {}
    local known = container:getKnownTraits()
    if known then
        for index = 0, known:size() - 1 do held[#held + 1] = known:get(index) end
    end
    for _, traitType in ipairs(held) do container:remove(traitType) end

    local probes, probeLines = checkProbes(player)
    local baseline = readAll(player, probes)

    -- Groessen, die sich auch ohne Trait aendern. calculateCombatSpeed war am
    -- 10.09.2026 so eine: sie meldete fuer alle 97 Traits eine Wirkung, weil
    -- der Wert zwischen zwei Aufrufen von selbst wandert. Ohne diese Pruefung
    -- steht in jedem Bericht dieselbe Sorte Scheinwirkung.
    local unstable = {}

    local effects, registry, silent = {}, {}, {}
    local counted, withEffect = 0, 0

    local defs = CharacterTraitDefinition.getTraits()
    for index = 0, defs:size() - 1 do
        local def = defs:get(index)
        local traitType = def:getType()
        local key = keyOf(traitType)
        if key then
            counted = counted + 1
            registry[#registry + 1] = definitionLine(key, def)

            container:add(traitType)
            local values = readAll(player, probes)
            container:remove(traitType)
            -- Gegenprobe ohne den Trait: steht die Basis noch, wo sie stand?
            local recheck = readAll(player, probes)
            for _, probe in ipairs(probes) do
                local base, back = baseline[probe.id], recheck[probe.id]
                if base ~= nil and back ~= nil and math.abs(back - base) > 0.0001 then
                    unstable[probe.id] = true
                end
            end

            local hits = 0
            for _, probe in ipairs(probes) do
                local base, value = baseline[probe.id], values[probe.id]
                if base ~= nil and value ~= nil and not unstable[probe.id]
                        and math.abs(value - base) > 0.0001 then
                    hits = hits + 1
                    withEffect = withEffect + 1
                    -- Alle drei Lesarten mitschreiben; welche stimmt, haengt
                    -- am `kind` des Eintrags, und das steht in TF_Static.
                    local factor = (base ~= 0) and (value / base) or 0
                    local pct = (base ~= 0) and ((value / base - 1) * 100) or 0
                    effects[#effects + 1] = string.format(
                        "%s|%s|%.6f|%.6f|%.4f|%.6f|%.6f",
                        key, probe.id, base, value, pct, factor, value - base)
                end
            end
            if hits == 0 then silent[#silent + 1] = key end
        end
    end

    -- XP und Behaelter, solange die Figur noch ohne eigene Traits ist.
    local okXp, xpReport = pcall(xpLines, player, container)
    if not okXp then xpReport = { "# XP-Messung fehlgeschlagen: " .. tostring(xpReport) } end
    local okBag, bagReport = pcall(containerLines, player, container)
    if not okBag then bagReport = { "# Behaelter-Messung fehlgeschlagen: " .. tostring(bagReport) } end

    -- Genau die Traits zurueck, die die Figur vorher hatte.
    for _, traitType in ipairs(held) do container:add(traitType) end

    table.sort(effects)
    table.sort(registry)
    table.sort(silent)

    local ok = pcall(function()
        local writer = getFileWriter(TFMeasure.FILE, true, false)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        local function write(line) writer:write(line .. nl) end

        write("# Trait Facts, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        local version = "unbekannt"
        pcall(function() version = tostring(getCore():getVersionNumber()) end)
        write("# Build " .. version)
        write("# Traits geprueft: " .. tostring(counted)
            .. ", Wirkungen: " .. tostring(withEffect)
            .. ", Groessen lesbar: " .. tostring(#probes) .. " von " .. tostring(#TFMeasure.PROBES))
        write("")
        write("[groessen] name|zustand|basiswert|herkunft")
        for _, line in ipairs(probeLines) do write(line) end
        local shaky = {}
        for id in pairs(unstable) do shaky[#shaky + 1] = id end
        table.sort(shaky)
        write("# schwankt ohne Trait, deshalb verworfen: "
            .. ((#shaky > 0 and table.concat(shaky, ", ")) or "keine"))
        write("")
        write("[wirkungen] trait|groesse|basis|mitTrait|prozent|faktor|differenz")
        for _, line in ipairs(effects) do write(line) end
        write("")
        write("[registry] trait|felder...")
        for _, line in ipairs(registry) do write(line) end
        write("")
        write("[foraging] trait|felder...")
        for _, line in ipairs(forageLines()) do write(line) end
        write("")
        write("[xp] art|skill|felder...")
        for _, line in ipairs(xpReport) do write(line) end
        write("")
        write("[behaelter] fall|felder...")
        for _, line in ipairs(bagReport) do write(line) end
        write("")
        write("[ohne messbare wirkung] " .. tostring(#silent) .. " Traits")
        for _, key in ipairs(silent) do write(key) end
        -- Seit 6.36.0: was Trait Facts beim Start selbst aus dem Spiel liest,
        -- gegen das, was es gespeichert hat. Weicht etwas ab, hat ein Patch
        -- oder ein Mod den Wert geaendert: der Fruehwarner nach jedem Update.
        write("")
        local live, abweichend = TFMeasure.liveLines()
        write("[trait facts live] trait|eintrag|gelesen|gespeichert|stand (" .. tostring(#live) .. " Werte, "
            .. tostring(abweichend) .. " weichen ab)")
        for _, line in ipairs(live) do write(line) end
        writer:close()
    end)
    if not ok then
        log("Datei nicht schreibbar, die Wirkungen stehen stattdessen im Log:")
        for _, line in ipairs(effects) do log(line) end
    end

    log(string.format("%d Traits geprueft, %d Wirkungen, %d von %d Groessen lesbar. Datei: Zomboid/Lua/%s",
        counted, withEffect, #probes, #TFMeasure.PROBES, TFMeasure.FILE))
    local okLive, live, abweichend = pcall(TFMeasure.liveLines)
    if okLive and #live > 0 then
        log(string.format("Trait Facts live: %d Werte gelesen, %d weichen vom gespeicherten ab%s", #live, abweichend,
            (abweichend > 0) and " (siehe [trait facts live] in der Datei)" or ""))
    end
    return withEffect
end

--- Sprinttest: der Verhaltenstest fuer die "tot"-Behauptung.
--
-- Die Mod sagt, der Sprint-Faktor von Athletic, Unfit, Out of Shape und
-- Obese stehe im Code, wirke aber nicht (updateInternal2: die Variable wird
-- nur noch als Ja/Nein gelesen). Ein Getter kann das nicht widerlegen, denn
-- ein Faktor, der wirkt, wirkt nur beim Sprinten. Also: die Figur sprintet,
-- das Mod schaltet den Trait phasenweise an und aus und misst je Phase die
-- zurueckgelegte Strecke je Tick. Die Phasen wechseln sich ab (ohne / mit /
-- ohne / mit), damit die sinkende Ausdauer beide Seiten gleich trifft.
--
-- Ergebnis: Faktor mit/ohne je Trait. 1.00 heisst tot, 1.20 hiesse, die
-- Mod irrt und muss den Wert zeigen.
--
-- Gezaehlt werden nur Ticks, in denen die Figur wirklich sprintet; Pausen
-- verlaengern den Test, verfaelschen ihn aber nicht.
--
-- Sprint ist nicht Rennen. Zomboid hat dafuer zwei getrennte Tasten, und
-- isSprinting() meldet nur die zweite: Run liegt auf der linken
-- Umschalttaste (keysB42.ini: Run=key:42, 0x2A LSHIFT), Sprint auf der
-- linken Alt-Taste (Sprint=key:56, 0x38 LMENU). Wer Shift haelt, rennt nur;
-- der Test sieht keinen einzigen Tick und laeuft nach fuenf Minuten in den
-- Abbruch. Genau so endete der Lauf vom 10.09.2026.
TFMeasure.SPRINT = {
    phaseTicks = 100,
    -- Drei Paare je Trait statt zwei. Der Lauf vom 10.09.2026 lieferte
    -- Abweichungen von +1.0 % bis +2.6 % bei einem Rauschboden von 1.55 %:
    -- genug, um 20 % auszuschliessen, zu wenig, um 3 % zu beurteilen. Mit
    -- sechs Phasen ohne Trait steht die Nachweisgrenze auf mehr Werten.
    phases = { "warmup",
               "none", "athletic", "none", "unfit",
               "none", "athletic", "none", "unfit",
               "none", "athletic", "none", "unfit" },
    timeoutTicks = 60 * 60 * 8,   -- acht Minuten, dann Abbruch mit dem, was da ist
}

local sprint = nil
-- Muss hier stehen, nicht erst beim Autotest weiter unten: sprintTick liest
-- `car`, und eine erst danach deklarierte Ortsvariable waere fuer sie
-- unsichtbar - der Zugriff liefe still auf eine globale, immer leere.
local car = nil

local function sprintPhaseTrait(player, name)
    local container = player:getCharacterTraits()
    for _, key in ipairs({ "athletic", "unfit" }) do
        local traitType = traitTypeNamed(key)
        if traitType then container:remove(traitType) end
    end
    -- Warmlauf zaehlt wie eine Phase ohne Trait: beide sind oben schon entfernt.
    if name == "none" or name == "warmup" then return true end
    local traitType = traitTypeNamed(name)
    if not traitType then return false end
    container:add(traitType)
    -- Ruecklesen statt glauben: die Liste der Engine ist die Wahrheit.
    local known = container:getKnownTraits()
    if not known then return false end
    for index = 0, known:size() - 1 do
        if keyOf(known:get(index)) == name then return true end
    end
    return false
end

local function sprintFinish(player, reason)
    if not sprint then return end
    local state = sprint
    sprint = nil
    pcall(sprintPhaseTrait, player, "none")

    -- Strecke je Tick je Phase, dann Faktor mit/ohne je Trait.
    -- Median statt Mittel. Der Lauf vom 10.09.2026 21:41 zeigte die Richtung
    -- des Fehlers: ein Ruckler HEBT die Strecke je Tick, weil die Figur sich
    -- nach Zeit bewegt und ein langer Frame sie weiter traegt. Die drei
    -- Phasen mit einem groessten Schritt ueber 0.19 lagen im Mittel bei
    -- 0.092477, die neun ohne bei 0.090797; alle drei waren "none" und
    -- standen damit im Nenner, was beide Faktoren nach unten zog. Ein paar
    -- lange Frames unter hundert Ticks verschieben den Median nicht.
    local perPhase, perPhaseMittel = {}, {}
    for index, phase in ipairs(state.results) do
        perPhaseMittel[index] = phase.ticks > 0 and (phase.distance / phase.ticks) or 0
        if phase.ticks > 0 then
            local sortiert = {}
            for i = 1, phase.ticks do sortiert[i] = phase.steps[i] end
            table.sort(sortiert)
            local mitte = math.floor((phase.ticks + 1) / 2)
            if phase.ticks % 2 == 1 then
                perPhase[index] = sortiert[mitte]
            else
                perPhase[index] = (sortiert[mitte] + sortiert[mitte + 1]) / 2
            end
        else
            perPhase[index] = 0
        end
    end
    local lines = {}
    lines[#lines + 1] = "# " .. reason
    lines[#lines + 1] = "# je tick ist der Median der Tickstrecken; ein Ruckler hebt das Mittel"
    for index, phase in ipairs(state.results) do
        lines[#lines + 1] = string.format(
            "phase|%d|%s|ticks=%d|strecke=%.4f|je tick=%.6f|trait=%s"
            .. "|blockiert=%d|min=%.6f|max=%.6f|ms=%d|ausdauer>=%.3f|mittel=%.6f",
            index, phase.name, phase.ticks, phase.distance, perPhase[index],
            ((phase.name == "none" or phase.name == "warmup") and "-")
            or (phase.applied and "gesetzt" or "NICHT GESETZT"),
            phase.blocked or 0, phase.min or 0, phase.max or 0,
            (phase.tEnd or 0) - (phase.tStart or 0), phase.endMin or 1,
            perPhaseMittel[index])
    end
    -- Rauschboden: wie stark die Phasen ohne Trait untereinander schwanken.
    -- Ein Faktor, der naeher an 1 liegt als diese Streuung, sagt nichts.
    local ruhig = {}
    for index, phase in ipairs(state.results) do
        if phase.name == "none" and phase.ticks > 0 then ruhig[#ruhig + 1] = perPhase[index] end
    end
    if #ruhig >= 2 then
        local lo, hi, sum = ruhig[1], ruhig[1], 0
        for _, wert in ipairs(ruhig) do
            if wert < lo then lo = wert end
            if wert > hi then hi = wert end
            sum = sum + wert
        end
        local mittel = sum / #ruhig
        -- Standardabweichung der Phasen ohne Trait. Zweimal davon ist die
        -- Nachweisgrenze: ein Faktor, der naeher an 1 liegt, ist von der
        -- Streuung dieser Messung nicht zu unterscheiden. Ohne diese Zahl
        -- liest man 1.03 als Wirkung, obwohl die Messung selbst so schwankt.
        local quadrat = 0
        for _, wert in ipairs(ruhig) do quadrat = quadrat + (wert - mittel) * (wert - mittel) end
        local sd = math.sqrt(quadrat / ((#ruhig > 1 and (#ruhig - 1)) or 1))
        local grenze = (mittel > 0 and (2 * sd / mittel * 100)) or 0
        lines[#lines + 1] = string.format(
            "rauschen|ohne Trait|min=%.6f|max=%.6f|streuung=%.2f%%|sd=%.2f%%|aus %d Phasen",
            lo, hi, (mittel > 0 and ((hi - lo) / mittel * 100)) or 0,
            (mittel > 0 and (sd / mittel * 100)) or 0, #ruhig)
        lines[#lines + 1] = string.format(
            "nachweisgrenze|%.2f%%|ein Faktor zwischen %.4f und %.4f ist Rauschen",
            grenze, 1 - grenze / 100, 1 + grenze / 100)
    end

    local blockiert = 0
    for _, phase in ipairs(state.results) do blockiert = blockiert + (phase.blocked or 0) end
    if blockiert > 0 then
        lines[#lines + 1] = string.format(
            "# %d Ticks sprintend aber stehend (Hindernis), nicht mitgezaehlt", blockiert)
    end

    for _, key in ipairs({ "athletic", "unfit" }) do
        local mit, ohne, n, paare = 0, 0, 0, {}
        for index, phase in ipairs(state.results) do
            if phase.name == key and phase.ticks > 0 and state.results[index - 1]
                    and state.results[index - 1].ticks > 0 and perPhase[index - 1] > 0 then
                mit = mit + perPhase[index]
                ohne = ohne + perPhase[index - 1]
                n = n + 1
                paare[n] = perPhase[index] / perPhase[index - 1]
            end
        end
        if n > 0 and ohne > 0 then
            local einzeln = {}
            for _, wert in ipairs(paare) do einzeln[#einzeln + 1] = string.format("%.4f", wert) end
            local streuung = 0
            if n > 1 then
                local mittel = 0
                for _, wert in ipairs(paare) do mittel = mittel + wert end
                mittel = mittel / n
                local quadrat = 0
                for _, wert in ipairs(paare) do quadrat = quadrat + (wert - mittel) * (wert - mittel) end
                streuung = math.sqrt(quadrat / (n - 1)) * 100
            end
            lines[#lines + 1] = string.format(
                "faktor|%s|mit/ohne=%.4f|aus %d Paaren|einzeln=%s|streuung der Paare=%.2f%%",
                key, mit / ohne, n, table.concat(einzeln, ","), streuung)
        else
            lines[#lines + 1] = "faktor|" .. key .. "|nicht messbar"
        end
    end

    local ok = pcall(function()
        local writer = getFileWriter(TFMeasure.FILE, true, true)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        writer:write(nl .. "[sprint] phase|nr|trait|ticks|strecke|je tick" .. nl)
        for _, line in ipairs(lines) do writer:write(line .. nl) end
        writer:close()
    end)
    if not ok then
        for _, line in ipairs(lines) do log(line) end
    end
    halo(player, "Sprinttest: " .. reason, reason == "abgeschlossen")
    log(tostring(#lines) .. " Zeilen an Zomboid/Lua/" .. TFMeasure.FILE .. " angehaengt.")
end

--- Ein Tick des Sprinttests. Wird aus TFMeasure.rahmenTick aufgerufen und
-- nicht selbst bei OnTick angemeldet.
function TFMeasure.sprintTick()
    local state = sprint
    if not state then return end
    -- Alle drei Tests fassen den Trait-Container derselben Figur an. Laeuft
    -- ein anderer schon, haelt sich der Sprinttest zurueck.
    if car and car.started then return end
    if accel and accel.started then return end
    local player = state.player
    state.age = state.age + 1
    if state.age > TFMeasure.SPRINT.timeoutTicks then
        sprintFinish(player, "Zeit abgelaufen, Ergebnis unvollstaendig")
        return
    end

    local sprinting = false
    pcall(function() sprinting = player:isSprinting() end)
    -- Die Engine wird gefragt, ob die Figur sich bewegt, statt es aus der
    -- eigenen Strecke zu schliessen: wer Ticks nach ihrer gemessenen Strecke
    -- aussortiert, hebt damit den eigenen Mittelwert und misst sich selbst.
    -- isSprinting() meldet nur die gehaltene Taste; steht die Figur an einem
    -- Zaun, einem Auto oder einem Baum, bleibt das Flag wahr und der Tick
    -- traegt null Strecke bei. Solche Ticks zogen frueher die Strecke je Tick
    -- nach unten, und eine wirkende Phase saehe damit tot aus - genau der
    -- Befund, den der Test unterscheiden soll. Vanilla paart die beiden
    -- Abfragen ebenso (ISBaseIcon.lua:700).
    local moving = true
    pcall(function() moving = player:isPlayerMoving() end)
    local x, y = player:getX(), player:getY()
    if not sprinting then
        -- Pause: naechste Strecke erst wieder ab dem naechsten Sprint-Tick,
        -- sonst zaehlte der Sprung nach dem Stehen als Strecke.
        state.lastX, state.lastY = nil, nil
        return
    end
    if not state.started then
        state.started = true
        state.phase = 1
        state.results = {}
        halo(player, "Sprinttest laeuft, weiter sprinten", true)
    end
    local phaseName = TFMeasure.SPRINT.phases[state.phase]
    if not state.results[state.phase] then
        local applied = false
        pcall(function() applied = sprintPhaseTrait(player, phaseName) end)
        state.results[state.phase] = { name = phaseName, ticks = 0, distance = 0,
            applied = applied, blocked = 0, min = nil, max = nil, tStart = 0, tEnd = 0,
            endMin = nil, steps = {} }
        pcall(function()
            state.results[state.phase].tStart = getTimestampMs()
            state.results[state.phase].tEnd = state.results[state.phase].tStart
        end)
        state.lastX, state.lastY = nil, nil
        halo(player, string.format("Sprinttest: Phase %d von %d (%s%s)",
            state.phase, #TFMeasure.SPRINT.phases, phaseName,
            (phaseName ~= "none" and not applied) and ", TRAIT NICHT GESETZT" or ""),
            (phaseName ~= "none" and not applied) and false or nil)
    end
    local phase = state.results[state.phase]
    local ausdauer = TFMeasure.ausdauerVoll(player)
    if ausdauer ~= nil and (phase.endMin == nil or ausdauer < phase.endMin) then
        phase.endMin = ausdauer
    end
    if not moving then
        phase.blocked = phase.blocked + 1
        -- Die naechste Strecke erst wieder ab dem uebernaechsten Tick, sonst
        -- zaehlte der Sprung nach der Blockade als eine Tickstrecke.
        state.lastX, state.lastY = nil, nil
        return
    end
    if state.lastX then
        local dx, dy = x - state.lastX, y - state.lastY
        local step = math.sqrt(dx * dx + dy * dy)
        phase.distance = phase.distance + step
        phase.ticks = phase.ticks + 1
        phase.steps[phase.ticks] = step
        if phase.min == nil or step < phase.min then phase.min = step end
        if phase.max == nil or step > phase.max then phase.max = step end
        pcall(function() phase.tEnd = getTimestampMs() end)
    end
    state.lastX, state.lastY = x, y

    if phase.ticks >= TFMeasure.SPRINT.phaseTicks then
        state.phase = state.phase + 1
        if state.phase > #TFMeasure.SPRINT.phases then
            sprintFinish(player, "abgeschlossen")
        end
    end
end

--- Ausdauer auf voll, und melden, wie tief sie vorher stand.
--
-- setUnlimitedEndurance ist ein Schalter der Engine; ob er beim Sprinten
-- jeden Abzug abfaengt, steht nirgends. Der Lauf vom 10.09.2026 21:13 endete
-- mit zwei Phasen 7 % unter dem Rest, ohne die Ruckel-Merkmale der Phasen
-- davor (groesster Schritt und Dauer normal) - das passt zu nachlassender
-- Ausdauer, war aber nicht belegt.
--
-- Darum beides: erst lesen, dann auf voll zuruecksetzen, wie Vanilla es im
-- Lauf-Debugfenster tut (ISRunningDebugUI.lua:45). Bleibt der gelesene Wert
-- bei 1.0, fing der Schalter alles ab; faellt er, ist die Bremse gefunden.
-- Liefert der Rueckgabewert nichts, bleibt es beim Zuruecksetzen allein.
function TFMeasure.ausdauerVoll(player)
    local stand = nil
    pcall(function() stand = player:getStats():get(CharacterStat.ENDURANCE) end)
    pcall(function() player:getStats():reset(CharacterStat.ENDURANCE) end)
    return stand
end

--- Setzt eine Zeile, die stehen bleibt, bis eine andere sie ersetzt.
--
-- Fuer Anweisungen, die man lesen und befolgen soll. Einmalige Meldungen
-- ("Vorwaerts in 80 Ticks") laufen weiter ueber halo() und duerfen weg sein.
local function haloStehend(player, text)
    TFMeasure.stehendeZeile = text
    TFMeasure.haloWiederholung = 0
    halo(player, text)
end

--- Setzt die stehende Zeile neu, damit sie sichtbar bleibt.
--
-- Zwei Wege, je nachdem was die Engine hergibt:
--
--   overheadContains(index, text) sagt, ob die Zeile gerade zu sehen ist.
--   Dann wird sie genau dann neu gesetzt, wenn sie fehlt - kein Stapeln.
--
--   Gibt es die Funktion nicht, wird stur alle wiederholeAlle Ticks neu
--   gesetzt. Die Zeile blinkt dann in Abstaenden auf, statt zu stehen.
--
-- Wichtig ist die Abfrage `if ... then` statt eines pcall um den Aufruf: die
-- Methode steht zwar im Jar (zombie.characters.HaloTextHelper), ist in Lua
-- aber nicht freigegeben, und Project Zomboid meldet auch einen gefangenen
-- Fehler im Mod-Report. Am 11.09.2026 standen dort elf Meldungen aus genau
-- diesem pcall. Was es nicht gibt, ruft man nicht auf.
local function haloAuffrischen(player)
    local text = TFMeasure.stehendeZeile
    if not text or not player then return end
    if HaloTextHelper and HaloTextHelper.overheadContains then
        local dasteht = HaloTextHelper.overheadContains(0, text)
        if not dasteht then HaloTextHelper.addText(player, text) end
        return
    end
    TFMeasure.haloWiederholung = (TFMeasure.haloWiederholung or 0) + TFMeasure.HALO.pruefeAlle
    if TFMeasure.haloWiederholung >= TFMeasure.HALO.wiederholeAlle then
        TFMeasure.haloWiederholung = 0
        if HaloTextHelper and HaloTextHelper.addText then
            HaloTextHelper.addText(player, text)
        end
    end
end

--- Die Figur fuer den Test aus dem Spiel nehmen.
--
-- Dieselben Schalter, die Vanilla im Admin-Panel setzt (ISAdminPowerUI):
-- unverwundbar, fuer Zombies unsichtbar, von Zombies nicht angegriffen,
-- unbegrenzte Ausdauer. So laesst sich der Sprinttest ungestoert fahren,
-- und die Ausdauer bleibt voll, was die Strecke je Tick gleichmaessig haelt.
-- Alles nur an der Wegwerf-Figur, und jeder Schalter einzeln abgesichert.
--
-- Seit 6.18.0 lassen sie sich im Messfenster einzeln abschalten; `cheatStand`
-- haelt fest, was gerade gilt. "Ausdauer unbegrenzt" steuert dabei auch das
-- Auffuellen je Tick (ausdauerTick).
TFMeasure.CHEATS = {
    { id = "god",        setter = "setGodMod" },
    { id = "unsichtbar", setter = "setInvisible" },
    { id = "zombies",    setter = "setZombiesDontAttack" },
    { id = "ausdauer",   setter = "setUnlimitedEndurance" },
}
TFMeasure.cheatStand = TFMeasure.cheatStand or {}

--- Das Herunterziehen durch Zombies aus, solange God Mode an ist.
--
-- Sonst kann ein Zombie die Figur trotz God Mode zu Boden reissen und toeten;
-- so begruendet es Cheat Menu: Reloaded (CheatCore.lua dragDownDisable),
-- dessen God Mode hier seit 6.21.0 nachgebaut ist (6.20.0 setzte das Mod
-- voraus). Geaendert wird die Sandbox-Option nur, wenn sie an war, und nur
-- dann kommt sie beim Abschalten zurueck. Der Merker steht in der ModData der
-- Figur und ueberlebt so einen Neustart.
local DRAGDOWN = "ZombieLore.ZombiesDragDown"
local function dragDownSetzen(player, godAn)
    local optionen = getSandboxOptions()
    local daten = player:getModData()
    if godAn then
        local option = optionen:getOptionByName(DRAGDOWN)
        if option and option:getValue() == true then
            optionen:set(DRAGDOWN, false)
            daten.TFMeasureDragDown = true
        end
    elseif daten.TFMeasureDragDown then
        daten.TFMeasureDragDown = nil
        optionen:set(DRAGDOWN, true)
    end
end

--- Setzt einen der vier Schalter; zu God Mode gehoert das Herunterziehen,
-- und das Heilen je Tick (godTick).
local function schalterSetzen(player, cheat, an)
    local ok = pcall(function() player[cheat.setter](player, an) end)
    if cheat.id == "god" then pcall(dragDownSetzen, player, an) end
    return ok
end

--- Die vier Schalter ueber den Neustart hinaus (seit 6.47.0, Wunsch vom
-- 24.09.2026). Bis 6.46.0 schaltete jeder Start und jedes Neuladen alle an;
-- mit God Mode rechnet das Spiel das Tragegewicht nicht nach, und eine
-- Messung nach dem Laden las 8 statt 18. Jetzt steht in
-- Zomboid/Lua/TraitFacts_testfigur.txt, was im Messfenster zuletzt galt,
-- eine Zeile je Schalter ("god=0"). Ohne Datei oder ohne Zeile: an, wie
-- bisher. Tests, die einen Schalter brauchen, setzen ihn weiter selbst und
-- geben danach diesen Stand zurueck (cheatStand).
TFMeasure.CHEATFILE = "TraitFacts_testfigur.txt"

function TFMeasure.cheatsLesen()
    local gemerkt = {}
    pcall(function()
        local reader = getFileReader(TFMeasure.CHEATFILE, false)
        if not reader then return end
        while true do
            local zeile = reader:readLine()
            if zeile == nil then break end
            local id, wert = string.match(zeile, "^([%w_]+)=([01])$")
            if id then gemerkt[id] = wert == "1" end
        end
        reader:close()
    end)
    return gemerkt
end

function TFMeasure.cheatsSchreiben()
    pcall(function()
        local writer = getFileWriter(TFMeasure.CHEATFILE, true, false)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        writer:write("# Trait Facts Measure: Schalter der Testfigur, zuletzt im Messfenster" .. nl)
        for _, cheat in ipairs(TFMeasure.CHEATS) do
            writer:write(cheat.id .. "=" .. (TFMeasure.cheatStand[cheat.id] == false and "0" or "1") .. nl)
        end
        writer:close()
    end)
end

function TFMeasure.ungestoert(player)
    player = player or getSpecificPlayer(0)
    if not player then return {} end
    local gemerkt = TFMeasure.cheatsLesen()
    local gesetzt = {}
    for _, cheat in ipairs(TFMeasure.CHEATS) do
        local an = gemerkt[cheat.id] ~= false
        local ok = schalterSetzen(player, cheat, an)
        TFMeasure.cheatStand[cheat.id] = ok and an
        gesetzt[#gesetzt + 1] = cheat.setter .. (ok and (an and " an" or " aus") or " fehlt")
    end
    TFMeasure.ausdauerAus = TFMeasure.cheatStand.ausdauer ~= true
    log("Testfigur: " .. table.concat(gesetzt, ", ")
        .. (TFMeasure.ausdauerAus and "." or ", Ausdauer wird jeden Tick aufgefuellt."))
    return gesetzt
end

--- Sprinttest scharfschalten; er wartet, bis die Figur sprintet.
function TFMeasure.armSprint(player)
    player = player or getSpecificPlayer(0)
    if not player or not Events.OnTick then return end
    -- Ein alter Handler muss weg, sonst zaehlen zwei dieselbe Bewegung: im
    -- Test lief so jede Strecke halbiert, weil OnGameStart schon einmal
    -- scharfgeschaltet hatte. Seit 4.2.0 kann das nicht mehr passieren: es
    -- gibt genau einen Tick-Einstieg, und ob der Sprinttest laeuft, sagt
    -- allein dieser Zustand.
    sprint = { player = player, age = 0, started = false, phase = 0, results = {} }
    halo(getSpecificPlayer(0), "Sprinttest wartet: ins Freie gehen und sprinten (Alt)")
    log("Sprint ist die Alt-Taste, nicht Shift - Shift ist nur Rennen und zaehlt hier nicht mit.")
    log(string.format("Der Test braucht %d sprintende Ticks in %d Phasen. Bei ruckelnder "
        .. "Anzeige dauert das entsprechend laenger - nicht nach der Uhr gehen, sondern "
        .. "sprinten, bis hier 'Sprinttest: abgeschlossen' steht.",
        #TFMeasure.SPRINT.phases * TFMeasure.SPRINT.phaseTicks, #TFMeasure.SPRINT.phases))
end

--- ---------------------------------------------------------------------------
--- Der Autotest: wirkt Speed Demon auf die Hoechstgeschwindigkeit?
--- ---------------------------------------------------------------------------
--
-- Die Mod behauptet fuer Speed Demon +15 % Hoechstgeschwindigkeit. Die Zahl
-- steht auf zwei gelesenen Zeilen im entpackten Build 42.20.4
-- (CarController.control_ForwardNew, Z. 669-673: die Motorkraft faellt erst
-- ueber `maxSpeed * 1.15` ab statt ueber maxSpeed) und ist nie im Verhalten
-- geprueft worden. Direkt daneben steht eine "wirkt nur rueckwaerts"-Aussage
-- zum Drehzahl-Term, und genau diese Sorte lag bei Handys Bauwerks-Gesundheit
-- schon einmal falsch.
--
-- Aufbau wie beim Sprinttest: der Trait wird phasenweise an- und abgeschaltet
-- und die Phasen wechseln sich ab, damit eine Drift (Strasse, Steigung,
-- Motorzustand, Ruckler) beide Seiten gleich trifft.
--
-- Gemessen wird nicht das mittlere Tempo, sondern das erreichte Plateau: das
-- Auto braucht nach jedem Wechsel Zeit, bis es die neue Schranke ausfaehrt.
-- Darum je Phase der Median des oberen Viertels der Messwerte. Der Hoechstwert
-- allein waere ein einzelner Ausreisser, das Mittel enthielte die
-- Beschleunigungsstrecke.
TFMeasure.CAR = {
    -- Jede Phase schwingt erst ein und wird dann gemessen. Wie lange das
    -- Einschwingen dauert, entscheidet das Auto, nicht ein Zaehler.
    --
    -- Ein festes Fenster war zweimal zu kurz. Am 10.09.2026 stand die erste
    -- Phase ohne Trait bei 108.6 km/h, die beiden spaeteren bei 116.0: das
    -- Auto beschleunigte noch, und das erste Paar meldete +11.7 % statt der
    -- +4.8 % der sauberen Paare. Der zweite Fall ist heimtueckischer und
    -- faellt nur im Geruest auf: eine Phase ohne Trait kommt nach einer mit
    -- Trait von OBEN herunter, und Abbremsen dauert genauso lang wie
    -- Beschleunigen. Ihr oberes Viertel liegt dann zu hoch, der Faktor zu
    -- niedrig - der Test unterschaetzt die Wirkung, statt sie zu erfinden.
    --
    -- Erkannt wird das Plateau ueber blockweise Hoechstwerte: eine Kurve
    -- senkt das Tempo nur, der Hoechstwert eines Blocks bleibt davon
    -- unberuehrt. Zwei aufeinanderfolgende Bloecke, die sich um weniger als
    -- plateauBand unterscheiden, heissen: das Auto ist da, wo es hinwollte.
    -- Blocklaenge des Plateau-Suchers. Halbiert am 10.09.2026: die
    -- gemessenen Einschwingzeiten lagen bei 240 bis 1680 Ticks, und ein
    -- Auto, das oben angekommen ist, bleibt es auch in einem kuerzeren
    -- Fenster. Der Sucher braucht zwei aufeinanderfolgende Bloecke innerhalb
    -- des Bandes, mindestens also 2 x blockTicks.
    --
    -- Das Band bleibt bei 0.3 %: waehrend der Beschleunigung steigt der
    -- Hoechstwert je Block deutlich staerker, ein kuerzerer Block macht die
    -- Erkennung also schneller, nicht leichtglaeubiger.
    blockTicks = 60,
    plateauBand = 0.003,
    -- Mindest-Einschwingzeit, unabhaengig vom Sucher.
    --
    -- Im StepVan-Lauf vom 10.09.2026 meldete jede einzelne Phase nach genau
    -- 120 Ticks "eingeschwungen", also am Minimum von zweimal blockTicks.
    -- Das ist richtig, wenn sich nichts aendert - und der Trait aenderte
    -- nichts. Es waere aber auch das Bild, das ein sehr traeges Fahrzeug
    -- abgibt, das gerade erst anfaengt zu reagieren: zwei kurze Bloecke
    -- innerhalb von 0.3 % kann auch der Beginn einer langsamen Fahrt nach
    -- unten liefern. Der Sucher kann die beiden Faelle nicht trennen, eine
    -- Untergrenze schon.
    settleMinTicks = 360,
    settleMaxTicks = 3600,        -- Notbremse fuer ein Auto, das nie zur Ruhe kommt
    -- Eine Phase gilt als stetig, wenn ihr Plateau nah an ihrem eigenen
    -- Hoechstwert liegt. Faehrt jemand mittendrin gegen einen Baum oder
    -- bremst, faellt das Plateau ab, waehrend der Hoechstwert von vorher
    -- stehen bleibt - die Phase misst dann keine Hoechstgeschwindigkeit mehr.
    --
    -- Der Lauf vom 10.09.2026 mit dem PickUpVan zeigt, wie klar das trennt:
    -- sechs Phasen lagen bei 0.9997 bis 1.0000, die siebte bei 0.8837. Ohne
    -- die Pruefung mittelte der Bericht sie mit und meldete als Ergebnis
    -- 0.9084, also eine Bremswirkung von Speed Demon - aus zwei Paaren mit
    -- 1.1115 und 1.1102 und einem kaputten mit 0.5037.
    stetigBand = 0.98,
    -- Messzeit je Segment. Am 10.09.2026 verdreifacht: sie kostet wenig,
    -- weil das Einschwingen die Zeit macht, und nimmt dem Ergebnis den
    -- Einwand, die Fenster seien zu kurz gewesen, um eine langsame Wirkung
    -- zu sehen.
    phaseTicks = 300,
    -- Gemessen wird nur, was noch offen ist. Speed Demon ist am 10.09.2026
    -- an fuenf Wagen erledigt (rund +11 %, Schranke bei 122.4 km/h); ihn
    -- mitzumessen verdoppelte den Lauf ohne Gewinn. Offen ist Sunday Driver
    -- mit seiner Behauptung von -25 %, aus derselben Art Codelesung, die bei
    -- Speed Demon +15 % ergab.
    --
    -- Wer beide (oder wieder Speed Demon) messen will, traegt sie hier und in
    -- phases ein; die Auswertung laeuft ueber diese Liste.
    traits = { "sundaydriver" },
    phases = { "warmup",
               "none", "sundaydriver",
               "none", "sundaydriver",
               "none", "sundaydriver" },
    -- Abgeraeumt wird immer beides, unabhaengig davon, was gemessen wird.
    -- Sonst bliebe ein Trait haengen, sobald jemand die Messliste kuerzt -
    -- und die Figur faehre die ganze Messung mit ihm herum.
    abraeumen = { "speeddemon", "sundaydriver" },
    timeoutTicks = 60 * 60 * 10,  -- zehn Minuten, dann Abbruch mit dem, was da ist
}

--- Setzt Speed Demon fuer eine Phase und liest zurueck, ob er wirklich haengt.
local function carPhaseTrait(player, name)
    local container = player:getCharacterTraits()
    for _, key in ipairs(TFMeasure.CAR.abraeumen) do
        local traitType = traitTypeNamed(key)
        if traitType then container:remove(traitType) end
    end
    if name == "none" or name == "warmup" then return true end
    local traitType = traitTypeNamed(name)
    if not traitType then return false end
    container:add(traitType)
    -- Ruecklesen statt glauben: die Liste der Engine ist die Wahrheit.
    local known = container:getKnownTraits()
    if not known then return false end
    for index = 0, known:size() - 1 do
        if keyOf(known:get(index)) == name then return true end
    end
    return false
end

--- Das Fahrzeug, in dem die Figur selbst am Steuer sitzt; sonst nil.
local function fahrzeugAmSteuer(player)
    local vehicle = nil
    pcall(function() vehicle = player:getVehicle() end)
    if not vehicle then return nil end
    local faehrt = false
    pcall(function() faehrt = vehicle:isDriver(player) end)
    if not faehrt then return nil end
    return vehicle
end

--- Median des oberen Viertels: das ausgefahrene Plateau der Phase.
--
-- Das obere Viertel ist Reserve, kein tragender Teil: solange der Fahrer in
-- weniger als der Haelfte der Ticks vom Gas geht, liefert auch der einfache
-- Median dasselbe Plateau. Wer viel kurvt, bekommt sie geschenkt. Eine
-- Gegenprobe im Geruest faellt darum nicht um, wenn man das Viertel entfernt -
-- das ist kein blinder Fleck, sondern eine Reserve ohne Wirkung im Normalfall.
local function plateau(werte, anzahl)
    if anzahl < 1 then return 0 end
    local sortiert = {}
    for i = 1, anzahl do sortiert[i] = werte[i] end
    table.sort(sortiert)
    local ab = math.floor(anzahl * 0.75) + 1
    if ab > anzahl then ab = anzahl end
    local oben = {}
    for i = ab, anzahl do oben[#oben + 1] = sortiert[i] end
    local mitte = math.floor((#oben + 1) / 2)
    if #oben % 2 == 1 then return oben[mitte] end
    return (oben[mitte] + oben[mitte + 1]) / 2
end

local function carFinish(player, reason)
    if not car then return end
    local state = car
    car = nil
    pcall(carPhaseTrait, player, "none")

    local lines = {}
    lines[#lines + 1] = "# " .. reason
    lines[#lines + 1] = "# tempo ist der Median des oberen Viertels der Messwerte je Phase"
    lines[#lines + 1] = "# eingeschwungen: Ticks nach dem Trait-Wechsel, bis das Tempo stand;"
        .. " sie werden verworfen und nicht gemessen"
    if state.fahrzeug then
        lines[#lines + 1] = "# Fahrzeug: " .. tostring(state.fahrzeug)
            .. ", maxSpeed laut Skript: " .. string.format("%.1f", state.maxSpeed or 0)
    end
    local perPhase, stetig = {}, {}
    for index, phase in ipairs(state.results) do
        perPhase[index] = plateau(phase.samples, phase.ticks)
        stetig[index] = (phase.max or 0) > 0
            and perPhase[index] >= phase.max * TFMeasure.CAR.stetigBand
        lines[#lines + 1] = string.format(
            "phase|%d|%s|ticks=%d|tempo=%.3f|hoechst=%.3f|trait=%s|eingeschwungen=%d|stetig=%s",
            index, phase.name, phase.ticks, perPhase[index], phase.max or 0,
            ((phase.name == "none" or phase.name == "warmup") and "-")
            or (phase.applied and "gesetzt" or "NICHT GESETZT"),
            (phase.seen or 0) - phase.ticks,
            (stetig[index] and "ja") or "NEIN")
    end

    local unstet = {}
    for index, phase in ipairs(state.results) do
        if not stetig[index] then unstet[#unstet + 1] = tostring(index) end
    end
    if #unstet > 0 then
        lines[#lines + 1] = "# Phase(n) " .. table.concat(unstet, ", ")
            .. " haben ihr Plateau nicht gehalten (Bremsen, Kurve, Hindernis)"
            .. " und zaehlen nicht mit"
    end

    local ruhig = {}
    for index, phase in ipairs(state.results) do
        if phase.name == "none" and phase.ticks > 0 and stetig[index] then
            ruhig[#ruhig + 1] = perPhase[index]
        end
    end
    if #ruhig >= 2 then
        local sum = 0
        for _, wert in ipairs(ruhig) do sum = sum + wert end
        local mittel = sum / #ruhig
        local quadrat = 0
        for _, wert in ipairs(ruhig) do quadrat = quadrat + (wert - mittel) * (wert - mittel) end
        local sd = math.sqrt(quadrat / ((#ruhig > 1 and (#ruhig - 1)) or 1))
        local grenze = (mittel > 0 and (2 * sd / mittel * 100)) or 0
        lines[#lines + 1] = string.format(
            "nachweisgrenze|%.2f%%|ein Faktor zwischen %.4f und %.4f ist Rauschen",
            grenze, 1 - grenze / 100, 1 + grenze / 100)
    end

    -- Erwartungswerte aus TF_Static, damit beim Lesen sofort auffaellt, wo
    -- Messung und hinterlegter Wert auseinandergehen.
    -- Die Erwartung haengt am Wagen, nicht an einer festen Zahl. Bis 6.13.1
    -- stand hier { speeddemon = 1.11, sundaydriver = 0.75 }; die 0.75 ist
    -- Sunday Drivers KRAFTfaktor und hat mit seiner Hoechstgeschwindigkeit
    -- nichts zu tun, die 1.11 traf zufaellig auf Wagen mittlerer Groesse.
    --
    -- control_ForwardNew erschoepft die Kraft bei `Grenze + 20`, und dort
    -- steht das Tempo (Offsets 843 bis 978, gelesen am 11.09.2026):
    --
    --     ohne Trait      maxSpeed + 20
    --     Sunday Driver   maxSpeed * 0.75 + 20   (seine eigene Absenkung
    --                     ist frueher null als die gewoehnliche, die ihn
    --                     als Nicht-Speed-Demon zusaetzlich trifft)
    --     Speed Demon     maxSpeed * 1.15 + 20
    --
    -- Darueber liegt die Schranke von 34 m/s = 122.4 km/h. Wo sie zuerst
    -- greift, ist der Faktor 1, egal was der Trait verspricht - genau das
    -- hat der SportsCar am 10.09.2026 gezeigt.
    local erwartet = {}
    if state.maxSpeed and state.maxSpeed > 0 then
        local m = state.maxSpeed
        local schranke = 122.4
        local function deckel(v) return (v < schranke) and v or schranke end
        local ohne = deckel(m + 20)
        if ohne > 0 then
            erwartet.speeddemon = deckel(m * 1.15 + 20) / ohne
            erwartet.sundaydriver = deckel(m * 0.75 + 20) / ohne
        end
        lines[#lines + 1] = string.format(
            "info|grenzen|maxSpeed=%.1f|Hoechsttempo erwartet: ohne %.1f,"
            .. " SundayDriver %.1f, SpeedDemon %.1f|Schranke 122.4 (34 m/s)",
            m, ohne, deckel(m * 0.75 + 20), deckel(m * 1.15 + 20))
    end
    for _, key in ipairs(TFMeasure.CAR.traits) do
        local mit, ohne, n, paare = 0, 0, 0, {}
        for index, phase in ipairs(state.results) do
            if phase.name == key and phase.ticks > 0 and state.results[index - 1]
                    and state.results[index - 1].ticks > 0 and perPhase[index - 1] > 0
                    and stetig[index] and stetig[index - 1] then
                mit = mit + perPhase[index]
                ohne = ohne + perPhase[index - 1]
                n = n + 1
                paare[n] = perPhase[index] / perPhase[index - 1]
            end
        end
        if n > 0 and ohne > 0 then
            local einzeln = {}
            for _, wert in ipairs(paare) do einzeln[#einzeln + 1] = string.format("%.4f", wert) end
            lines[#lines + 1] = string.format(
                "faktor|%s|mit/ohne=%.4f|aus %d Paaren|einzeln=%s|erwartet=%s",
                key, mit / ohne, n, table.concat(einzeln, ","),
                erwartet[key] and string.format("%.4f", erwartet[key])
                    or "- (maxSpeed nicht lesbar)")
        else
            lines[#lines + 1] = "faktor|" .. key .. "|nicht messbar"
        end
    end

    local ok = pcall(function()
        local writer = getFileWriter(TFMeasure.FILE, true, true)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        writer:write(nl .. "[auto] phase|nr|trait|ticks|tempo|hoechst" .. nl)
        for _, line in ipairs(lines) do writer:write(line .. nl) end
        writer:close()
    end)
    if not ok then
        for _, line in ipairs(lines) do log(line) end
    end
    halo(player, "Autotest: " .. reason, reason == "abgeschlossen")
    log(tostring(#lines) .. " Zeilen an Zomboid/Lua/" .. TFMeasure.FILE .. " angehaengt.")
end

--- Ein Tick des Autotests. Wird aus TFMeasure.rahmenTick aufgerufen.
function TFMeasure.carTick()
    local state = car
    if not state then return end
    -- Sprint- und Autotest teilen sich den Trait-Container der Figur; sie
    -- duerfen sich nicht ins Gehege kommen. Entscheidend ist, ob der andere
    -- LAEUFT, nicht ob er scharf ist: beide werden beim Weltbetreten
    -- scharfgeschaltet und warten dann nebeneinander. Die Abfrage `if sprint`
    -- traf den wartenden Sprinttest mit und sperrte den Autotest damit fuer
    -- immer aus - im Spiel am 10.09.2026 blieb er stumm, obwohl die Figur
    -- am Steuer sass.
    if sprint and sprint.started then return end
    if accel and accel.started then return end
    local player = state.player
    state.age = state.age + 1
    if state.age > TFMeasure.CAR.timeoutTicks then
        carFinish(player, "Zeit abgelaufen, Ergebnis unvollstaendig")
        return
    end

    -- Solange der Test wartet, sagt er, woran es noch haengt - und zwar nur
    -- beim Wechsel, sonst stuende jede Sekunde dieselbe Zeile ueber dem Kopf.
    -- Ohne diese Rueckmeldung sieht ein wartender Test genauso aus wie ein
    -- kaputter: am 10.09.2026 sass die Figur im Auto und nichts geschah, und
    -- am Bildschirm war nicht zu unterscheiden, ob eine Bedingung fehlte oder
    -- der Test gar nicht mehr lief.
    local function hinweis(text)
        if state.started or state.hint == text then return end
        state.hint = text
        halo(player, text)
    end

    local imAuto = nil
    pcall(function() imAuto = player:getVehicle() end)
    if not imAuto then
        state.hint = nil
        return
    end
    local vehicle = fahrzeugAmSteuer(player)
    if not vehicle then
        hinweis("Autotest: du sitzt nicht am Steuer")
        return
    end
    local laeuft = false
    pcall(function() laeuft = vehicle:isEngineRunning() end)
    if not laeuft then
        hinweis("Autotest: Motor starten")
        return
    end
    local tempo = 0
    pcall(function() tempo = vehicle:getCurrentSpeedKmHour() end)
    if tempo < 0 then tempo = -tempo end
    -- Unter Schrittgeschwindigkeit steht das Auto oder rangiert; solche Ticks
    -- sagen nichts ueber die Hoechstgeschwindigkeit und wuerden das Plateau
    -- der Phase nur verwaessern.
    if tempo < 5 then
        hinweis("Autotest: losfahren, Vollgas auf gerader Strasse")
        return
    end

    if not state.started then
        state.started = true
        state.phase = 1
        state.results = {}
        pcall(function()
            state.fahrzeug = tostring(vehicle:getScript():getName())
            state.maxSpeed = vehicle:getMaxSpeed()
        end)
        halo(player, "Autotest laeuft, Vollgas halten", true)
    end

    local phaseName = TFMeasure.CAR.phases[state.phase]
    if not state.results[state.phase] then
        local applied = false
        pcall(function() applied = carPhaseTrait(player, phaseName) end)
        state.results[state.phase] = { name = phaseName, ticks = 0, max = 0,
            applied = applied, samples = {}, seen = 0,
            settled = false, blockMax = 0, blockTicks = 0, lastBlockMax = 0 }
        halo(player, string.format("Autotest: Phase %d von %d (%s%s)",
            state.phase, #TFMeasure.CAR.phases, phaseName,
            (phaseName ~= "none" and phaseName ~= "warmup" and not applied)
                and ", TRAIT NICHT GESETZT" or ""),
            (phaseName ~= "none" and phaseName ~= "warmup" and not applied) and false or nil)
    end
    local phase = state.results[state.phase]
    TFMeasure.ausdauerVoll(player)
    phase.seen = phase.seen + 1

    if not phase.settled then
        if tempo > phase.blockMax then phase.blockMax = tempo end
        phase.blockTicks = phase.blockTicks + 1
        if phase.blockTicks >= TFMeasure.CAR.blockTicks then
            if phase.lastBlockMax > 0 and phase.blockMax > 0
                    and math.abs(phase.blockMax - phase.lastBlockMax)
                        < phase.blockMax * TFMeasure.CAR.plateauBand then
                phase.settled = true
            end
            phase.lastBlockMax = phase.blockMax
            phase.blockMax = 0
            phase.blockTicks = 0
        end
        -- Die Untergrenze schlaegt den Sucher: was er vor settleMinTicks
        -- meldet, gilt nicht.
        if phase.settled and phase.seen < TFMeasure.CAR.settleMinTicks then
            phase.settled = false
        end
        if phase.seen >= TFMeasure.CAR.settleMaxTicks then phase.settled = true end
        -- Waehrend des Einschwingens wird nicht gemessen.
        return
    end

    phase.ticks = phase.ticks + 1
    phase.samples[phase.ticks] = tempo
    if tempo > phase.max then phase.max = tempo end

    if phase.ticks >= TFMeasure.CAR.phaseTicks then
        state.phase = state.phase + 1
        if state.phase > #TFMeasure.CAR.phases then
            carFinish(player, "abgeschlossen")
        end
    end
end

--- Nummer der laufenden Phase und wie viele Ticks sie schon GEMESSEN hat
-- (0, solange sie noch einschwingt). Beides 0, wenn der Test nicht laeuft.
--
-- Nur fuer den Smoke-Test: ohne diese Auskunft laesst sich eine Stoerung
-- nicht gezielt in das Messfenster einer bestimmten Phase legen, und die
-- Pruefung auf gestoerte Phasen haette keinen Fall zum Pruefen.
function TFMeasure.autoPhase()
    if car == nil or not car.started then return 0, 0 end
    local phase = car.results and car.results[car.phase]
    return car.phase or 0, (phase and phase.ticks) or 0
end

--- Laeuft der Autotest gerade? Nur fuer den Test; die Ortsvariable `car` ist
-- von aussen nicht sichtbar, und ohne diese Auskunft laesst sich nicht
-- pruefen, dass ein wartender Sprinttest ihn nicht aussperrt.
function TFMeasure.autotestLaeuft()
    return (car ~= nil) and (car.started == true)
end

--- Autotest scharfschalten; er wartet, bis die Figur ein Auto faehrt.
function TFMeasure.armCar(player)
    player = player or getSpecificPlayer(0)
    if not player then return end
    car = { player = player, age = 0, started = false, phase = 0, results = {}, hint = nil }
    halo(player, "Autotest wartet: in ein Auto setzen, Motor an, Vollgas auf gerader Strasse")
    log(string.format("Der Autotest faehrt erst warm, bis das Tempo nicht mehr steigt, "
        .. "und misst dann %d Phasen zu je %d Ticks. Nicht nach der Uhr gehen, "
        .. "sondern fahren, bis 'Autotest: abgeschlossen' dasteht.",
        #TFMeasure.CAR.phases - 1, TFMeasure.CAR.phaseTicks))
end

--- Haelt die Ausdauer dauerhaft voll, solange das Mess-Mod laeuft.
function TFMeasure.ausdauerTick()
    -- Waehrend des Sprinttests haelt sprintTick die Ausdauer selbst hoch. Zwei
    -- Auffueller je Tick waeren nicht nur doppelt, sondern schaedlich: der
    -- erste setzt auf voll zurueck, und der zweite liest dann immer 1.0. Die
    -- Spalte ausdauer>= im Bericht soll aber gerade zeigen, wie tief der Wert
    -- ohne das Auffuellen gefallen waere.
    if sprint then return end
    -- Der Lauf-Test (seit 6.25.0) setzt die Ausdauer selbst auf 0.9 und
    -- misst den Abzug bis zum naechsten Tick; ein Auffuellen auf 1.0
    -- dazwischen verfaelschte ihn.
    if TFMeasure.laufenZustand then return end
    -- Im Messfenster abgeschaltet (Kaestchen "Ausdauer unbegrenzt").
    if TFMeasure.ausdauerAus then return end
    local player = getSpecificPlayer(0)
    if player then TFMeasure.ausdauerVoll(player) end
end

--- ---------------------------------------------------------------------------
--- Neu laden ohne Spielneustart (F9)
--- ---------------------------------------------------------------------------
--
-- Das Spiel liest Lua einmal beim Programmstart. Jede Aenderung am Mess-Mod
-- kostete deshalb einen kompletten Neustart, und zweimal ist dabei eine alte
-- Fassung gelaufen, ohne dass es jemand merkte (10.09.2026: der Autotest blieb
-- stumm, weil noch 3.0.0 geladen war).
--
-- reloadLuaFile() gibt es in der Engine; das Debug-Fenster LuaFileBrowser
-- benutzt es, und die Pfadliste dafuer kommt aus getLoadedLua(). Beides
-- braucht keinen Debug-Modus.
--
-- Neu geladen wird nur das Mess-Mod. Die ausgelieferte Mod bleibt aussen vor:
-- ihre Hooks haengen sich beim Laden in den Charakterbildschirm, ein zweites
-- Laden haengt sie ein zweites Mal ein.

--- Alle geladenen Lua-Dateien des Mess-Mods, als Liste von Pfaden.
local function eigeneDateien()
    local treffer = {}
    local anzahl = 0
    pcall(function() anzahl = getLoadedLuaCount() end)
    for index = 0, anzahl - 1 do
        local pfad = nil
        pcall(function() pfad = getLoadedLua(index) end)
        if type(pfad) == "string" and string.find(pfad, "TraitFactsMeasure", 1, true) then
            treffer[#treffer + 1] = pfad
        end
    end
    return treffer
end

--- Die Dateien des Mess-Mods neben dieser hier.
TFMeasure.GESCHWISTER = { "TFMeasureMenu.lua", "TFMeasureScreen.lua", "TFMeasureNachstellen.lua", "TFMeasureBefehle.lua",
                          "TFMeasureKonsole.lua" }

--- Laedt das Mess-Mod neu und schaltet die Tests wieder scharf.
--
-- Oeffentlich, damit man es auch aus einer Lua-Konsole aufrufen kann.
function TFMeasure.neuLaden()
    local dateien = eigeneDateien()
    if #dateien == 0 then
        log("Neu laden: keine eigene Datei in der Liste der geladenen Lua-Dateien.")
        return false
    end
    for _, pfad in ipairs(dateien) do
        local ok = pcall(function() reloadLuaFile(pfad) end)
        log("Neu laden: " .. pfad .. (ok and " ok" or " FEHLGESCHLAGEN"))
    end
    -- Dateien, die seit dem Spielstart dazugekommen sind, stehen nicht in der
    -- Liste der geladenen (21.09.2026: Num 4 tat nichts, TFMeasureNachstellen.lua
    -- war neu). Sie liegen neben dieser Datei und werden hier das erste Mal geladen.
    local ordner = nil
    for _, pfad in ipairs(dateien) do
        ordner = ordner or string.match(pfad, "^(.*[/\\])TFMeasure%.lua$")
    end
    for _, name in ipairs(TFMeasure.GESCHWISTER) do
        local schon = false
        for _, pfad in ipairs(dateien) do
            if string.find(pfad, name, 1, true) then schon = true end
        end
        if ordner and not schon then
            local ok = pcall(function() reloadLuaFile(ordner .. name) end)
            log("Neu laden: " .. name .. " zum ersten Mal" .. (ok and " ok" or " FEHLGESCHLAGEN"))
        end
    end
    -- Nach dem Neuladen zeigen die TFMeasure-Felder auf die neuen Funktionen.
    local player = getSpecificPlayer(0)
    if player then
        pcall(TFMeasure.ungestoert, player)
        pcall(TFMeasure.scharfschalten, player)
        halo(player, "Mess-Mod neu geladen: Fassung " .. tostring(TFMeasure.VERSION), true)
    else
        log("Mess-Mod neu geladen: Fassung " .. tostring(TFMeasure.VERSION)
            .. ". Ohne Figur werden die Tests beim naechsten Weltbetreten scharf.")
    end
    return true
end

--- Fahrzeuge zum Messen, absichtlich weit auseinander.
--
-- Der SmallCar hat +11.6 % gezeigt. Ob das fuer jeden Wagen gilt, haengt am
-- Verhaeltnis von Motorkraft, Masse und Skript-Hoechstwert - also nimmt diese
-- Liste die Extreme mit. Werte aus media/scripts (maxSpeed, engineForce, Masse):
--   SmallCar     70 / 3600 /  650   leicht und schwach, schon gemessen
--   CarNormal    90 / 4000 /  800   die Mitte
--   SportsCar   120 / 5700 /  800   viel Kraft, hoher Hoechstwert
--   PickUpVan    60 / 4000 / 1104   schwer, niedriger Hoechstwert
--   StepVan      70 / 3700 / 1160   am schwersten bei wenig Kraft
TFMeasure.AUTOS = { "Base.SmallCar", "Base.CarNormal", "Base.SportsCar",
                    "Base.PickUpVan", "Base.StepVan" }

--- Setzt das naechste Fahrzeug der Liste neben die Figur, fahrbereit.
--
-- addVehicle gibt es in der Engine; das Debug-Menue benutzt es genauso
-- (DebugContextMenu.lua:1172). Repariert, mit Schluessel im Inventar und
-- vollem Tank, damit kein halber Wagen die Messung verdirbt.
function TFMeasure.autoSetzen(player)
    player = player or getSpecificPlayer(0)
    if not player then return false end
    local index = (TFMeasure.autoIndex or 0) + 1
    if index > #TFMeasure.AUTOS then index = 1 end
    TFMeasure.autoIndex = index
    local skript = TFMeasure.AUTOS[index]

    local fahrzeug = nil
    pcall(function()
        fahrzeug = addVehicle(skript, player:getX() + 2, player:getY(), player:getZ())
    end)
    if not fahrzeug then
        halo(player, "Auto " .. skript .. " liess sich nicht setzen", false)
        return false
    end
    pcall(function() fahrzeug:repair() end)
    pcall(function() player:getInventory():AddItem(fahrzeug:createVehicleKey()) end)
    pcall(function()
        local tank = fahrzeug:getPartById("GasTank")
        if tank then tank:setContainerContentAmount(tank:getContainerCapacity()) end
    end)
    local tempo = 0
    pcall(function() tempo = fahrzeug:getMaxSpeed() end)
    halo(player, string.format("%s gesetzt (%d von %d), maxSpeed %.0f, Schluessel im Inventar",
        skript, index, #TFMeasure.AUTOS, tempo), true)
    return true
end

--- ---------------------------------------------------------------------------
--- Der Beschleunigungstest: Motorkraft vorwaerts und rueckwaerts
--- ---------------------------------------------------------------------------
--
-- Der Autotest misst das Plateau, und dort ist die Motorkraft laengst nicht
-- mehr die Grenze. Genau deshalb sah er bei Sunday Driver nichts: dessen
-- -25 % Motorkraft koennen stimmen und blieben in jedem Plateau-Lauf
-- unsichtbar. Sichtbar wird Kraft beim Anfahren.
--
-- Gemessen wird die Zeit von `von` bis `bis` km/h, je Richtung getrennt.
-- getCurrentSpeedKmHour ist rueckwaerts negativ, das Vorzeichen sagt also die
-- Richtung; gerechnet wird mit dem Betrag.
--
-- Drei offene Behauptungen stehen hier auf dem Pruefstand:
--   Sunday Driver  -25 % Motorkraft vorwaerts   -> Zeit mal rund 1.33
--   Sunday Driver  -30 % Rueckwaertskraft       -> Zeit mal rund 1.43
--   Speed Demon    Drehzahlaufbau mal 3, und laut Code nur rueckwaerts
--
-- Seit 6.10.0 wird nicht mehr nur die Zeit genommen. BaseVehicle gibt die
-- Groessen, um die es geht, direkt heraus: getForce() die Motorkraft,
-- getEngineSpeed() die Drehzahl, getThrottle() die Gasstellung. Alle drei
-- sind public und stehen im Jar (nachgesehen am 11.09.2026). Damit ist die
-- Zeit nur noch die Probe aufs Exempel; die Zahl selbst wird abgelesen.
--
-- Rueckwaerts hat der Test eine harte Grenze, und sie ist keine Vermutung:
-- CarController.control_Reverse rechnet zuerst `v = tempo * 1.5` und senkt die
-- Motorkraft ab v < -5 mit dem Faktor `(15 + v) / 10`. Bei tempo = -3.33 km/h
-- faengt die Absenkung an, bei tempo = -10 km/h ist die Kraft null. Deshalb
-- kommt rueckwaerts kein Wagen ueber 10 km/h, unabhaengig von maxSpeed.
--
-- NACHTRAG 11.09.2026 (6.15.0): Das stimmt so nicht. Im Spiel faehrt ein
-- Wagen rueckwaerts deutlich schneller als 10 km/h, und der Lauf vom
-- 11.09.2026 las zwischen 6 und 8 km/h dieselbe Kraft wie zwischen 2 und 4
-- (-4538 gegen -4497), also keine Absenkung.
--
-- AUFLOESUNG (6.15.1, Lauf am PickUpVan, docs/messungen/messung-2026-09-11f-pickupvan.txt):
-- `tempo` ist km/h, aber die Absenkung `(15 + v) / 10` steht INNERHALB des
-- Sunday-Driver-Zweigs (control_Reverse, Offsets 271 bis 311, gleich nach
-- dem `* 0.7`). Nur mit Sunday Driver ist rueckwaerts bei 10 km/h Schluss,
-- gemessen 9.999. Fuer alle gilt die harte Grenze ab
-- tempo * 1.5 > maxSpeedReverse = 40, also 26.7 km/h; gemessen 27.1, weil
-- der Wagen ueber die Schwelle hinausrollt. Die fruehere Lesart kam aus
-- Laeufen, in denen Sunday Driver gesetzt war.
--
-- Fuer die Messung heisst das: das Fenster 2 bis 8 km/h liegt fast ganz in
-- der Absenkung, bei 8 km/h sind noch 30 % der Kraft uebrig. Die ZEIT dort
-- ist deshalb keine saubere Kraftmessung - eine kleinere Kraft braucht in
-- einem Feld, das selbst gegen null laeuft, ueberproportional laenger. Die
-- KRAFT je Tempofenster ist es sehr wohl: die Absenkung haengt nur am Tempo
-- und trifft die Phase mit Trait genauso wie die ohne.
--
-- Seit 6.12.0 endet ein Anlauf vorwaerts nicht mehr an der Zeitmarke,
-- sondern erst, wenn das Tempo steht. Drei Gruende, alle aus dem Lauf vom
-- 11.09.2026 am SportsCar:
--
--   1. Das Fenster 10 bis 50 km/h lag ganz im ersten Gang. getTransmission-
--      NumberLetter stand in jeder Phase durchgehend auf "1". Ueber die
--      Gaenge 2 bis 5 sagte der Test damit nichts, und control_ForwardNew
--      waehlt den Gang aus `tempo / (maxSpeed / gearRatioCount)`.
--   2. Die Hoechstgeschwindigkeit fiel dabei ganz aus der Messung, obwohl
--      derselbe Anlauf sie fast geschenkt mitnimmt.
--   3. control_ForwardNew senkt die Kraft erst weit oben, und zwar je nach
--      Trait an anderer Stelle: ohne Trait ab `maxSpeed`, mit Speed Demon ab
--      `maxSpeed * 1.15`, mit Sunday Driver schon ab `maxSpeed * 0.6`. Jeder
--      Faktor laeuft ueber `(Grenze + 20 - tempo) / 20` gegen null. Genau da
--      entsteht die Hoechstgeschwindigkeit, und genau da hat der Test bisher
--      nicht hingesehen.
--
-- Abgelesen wird in Tempofenstern, nicht als ein Mittel ueber den ganzen
-- Anlauf. Der Grund steht in CarController: dort gibt es `gears` und
-- `findGear`, die Kraft haengt also am Gang und der Gang am Tempo im
-- Verhaeltnis zu maxSpeed. Ein Trait, der maxSpeed anhebt, verschiebt damit
-- die Gangwechsel - und genau das erklaert, warum Speed Demon am SportsCar
-- vorwaerts LANGSAMER anfuhr (Zeit mal 1.2313) als ohne Trait. Ein Vergleich
-- bei gleichem Tempo trennt Gangwahl und Motorkraft, ein Mittelwert nicht.
--
-- Ein Lauf zaehlt erst, wenn die Figur unter `von` * 0.5 war (also praktisch
-- stand) und dann durchzieht. Wer zwischendrin vom Gas geht, verwirft seinen
-- eigenen Lauf, statt ihn zu verfaelschen.
TFMeasure.ACCEL = {
    -- Schwellen je Richtung. Rueckwaerts kommt ein Auto in Zomboid kaum ueber
    -- 10 km/h (im Spiel am 11.09.2026 beobachtet), ein Ziel von 50 waere dort
    -- nie erreichbar und der Anlauf nie fertig. Vorwaerts bleibt es bei 10 bis
    -- 50, rueckwaerts 2 bis 8 - eng genug, um sicher hineinzupassen, und weit
    -- genug fuer eine brauchbare Zahl von Ticks.
    -- `bis` ist in beiden Richtungen nur die Zeitmarke, nicht das Ende des
    -- Anlaufs. Bis 6.14.0 endete der Anlauf rueckwaerts bei 6 km/h, weil
    -- der Code "oberhalb ist von der Kraft nichts mehr uebrig" behauptete;
    -- im Spiel faehrt ein Wagen rueckwaerts weit schneller. Seit 6.15.0
    -- faehrt er in beiden Richtungen, bis das Tempo steht. Die 6 bleibt als
    -- Zeitmarke, damit die Zeiten mit den Laeufen davor vergleichbar sind.
    -- Rueckwaerts startet die Uhr bei 2, nicht bei 1.5: 1.5 ist zugleich
    -- die Schwelle, unter der ein Anlauf als abgebrochen gilt. Wer dort
    -- startet, verliert seinen Anlauf beim ersten Zittern, und zwischen
    -- 1.5 und dem ersten Fenster (ab2) sammelt er ohnehin nichts.
    von = { vor = 10, rueck = 2 },
    bis = { vor = 50, rueck = 6 },
    -- Darunter gilt die Figur als stehend und darf einen neuen Anlauf
    -- beginnen. Eigene Schwelle, weil im Stand die Richtung nicht feststeht.
    stillstand = 1.5,
    -- Eine Phase ist fertig, wenn JEDE dieser Richtungen ihre Anlaeufe hat.
    -- Damit misst ein einziger Lauf beide Richtungen, und ein neues Fahrzeug
    -- ist mit einem Durchgang erledigt.
    richtungen = { "vor", "rueck" },
    -- Ein Anlauf je Richtung und Phase reicht: die Verlaesslichkeit kommt aus
    -- den zwei Paaren je Trait, nicht aus zwei Anlaeufen in derselben Phase.
    laeufeJePhase = 1,
    -- Jeder Trait einmal, jeweils gegen die Phase ohne Trait direkt davor.
    -- Bis 6.14.0 waren es acht Phasen, zwei Paare je Trait. Die
    -- Verlaesslichkeit kommt heute aus dem Ablesen: die Kraft steht je Tick
    -- im Wagen, und ein Fenster traegt Dutzende bis Hunderte Werte. Ein
    -- zweites Paar verdoppelte nur die Fahrzeit.
    phases = { "none", "sundaydriver", "none", "speeddemon" },
    timeoutTicks = 60 * 60 * 20,
    -- Untergrenzen der Tempofenster, je Richtung. Ein Tick zaehlt in das
    -- letzte Fenster, dessen Untergrenze er erreicht hat; alles ueber der
    -- letzten Grenze faellt weg, weil der Anlauf dort ohnehin endet.
    fenster = {
        -- Ueber den ganzen Tempobereich, damit jeder Gang sein eigenes
        -- Fenster hat. Fenster oberhalb dessen, was ein Wagen schafft,
        -- bleiben einfach leer.
        -- 5 km/h breit, nicht 10. Oberhalb von maxSpeed senkt
        -- control_ForwardNew die Kraft linear ueber genau 20 km/h gegen
        -- null. In 10er-Fenstern sind das zwei Punkte, und zwei Punkte
        -- zeigen keinen Verlauf. In 5ern sind es vier, und man sieht, ob
        -- die Kraft faellt, wo sie faellt und ob sie das Vorzeichen
        -- wechselt. Leere Fenster kosten nichts, sie fallen aus dem
        -- Bericht.
        vor = { 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80,
                85, 90, 95, 100, 105, 110, 115, 120 },
        -- Rueckwaerts bis 50, weil der Anlauf seit 6.15.0 bis zum Plateau
        -- geht. Unten fein, damit ab2 dasselbe Fenster 2 bis 4 ist wie im
        -- Lauf vom 11.09.2026 (dort stand Sunday Drivers 0.7002).
        rueck = { 2, 4, 6, 8, 10, 12, 15, 20, 25, 30, 35, 40, 45, 50 },
    },
    -- Vorwaerts endet der Anlauf, wenn die Hoechstgeschwindigkeit ueber ein
    -- ganzes Zeitfenster kaum noch gestiegen ist.
    --
    -- Bis 6.12.0 stand hier ein Vergleich von Tick zu Tick: fertig, sobald
    -- 180 Ticks lang kein EINZELNER Tick mehr als 0.05 km/h zulegte. Das
    -- ist keine Plateau-Erkennung, das ist eine Beschleunigungsschwelle.
    -- 0.05 km/h je Bild sind bei 60 Bildern 3 km/h je Sekunde, und genau
    -- unterhalb davon liegt der ganze interessante Bereich:
    -- control_ForwardNew senkt die Kraft linear gegen null, der Wagen
    -- naehert sich seiner Grenze also asymptotisch und legt die letzten
    -- 10 bis 15 km/h mit weit weniger als 3 km/h je Sekunde zu. Der Anlauf
    -- waere rund 12 km/h unter der Grenze als "Tempo steht" durchgegangen.
    --
    -- Schlimmer als zu frueh war, dass es SCHIEF zu frueh war. Mit Sunday
    -- Driver ist die Kraft um ein Viertel kleiner, die Schwelle wird also
    -- noch weiter unterhalb der Grenze unterschritten. Der Test haette mit
    -- Trait eine niedrigere Hoechstgeschwindigkeit gemeldet als ohne, auch
    -- wenn der Trait auf die Hoechstgeschwindigkeit gar nicht wirkt - also
    -- genau den Effekt erfunden, den er entscheiden soll.
    --
    -- Jetzt zaehlt der Zuwachs des Hoechstwerts ueber ein Zeitfenster. Ob
    -- der in 60 oder in 300 Bildern anfaellt, ist egal; gemessen wird in
    -- km/h je Sekunde, nicht je Bild. 0.25 km/h in 3 s heisst bei der
    -- Zeitkonstanten eines schweren Wagens rund ein halbes km/h unter der
    -- wahren Grenze, mit und ohne Trait gleichermassen.
    plateauFensterMs = 3000,
    plateauZuwachs = 0.25,
    -- Das Fenster laeuft nur, solange der Wagen oben an seinem eigenen
    -- Hoechstwert faehrt. Wer bremst oder in die Kurve geht, faengt ein
    -- neues Fenster an, statt seine Bremsung als Plateau zu melden.
    plateauNah = 1.0,
    -- Reissleine, falls das Tempo nie steht (Steigung, Hindernis, Kollision).
    -- Der Wagen sagt es ueber dem Kopf, sonst sieht die abgeschnittene Zahl
    -- aus wie eine gemessene.
    plateauMaxMs = 90000,
}

local accel = nil

--- Alles, was ein Fahrzeug ueber sich sagt.
---
--- Jeder Name hier ist am 11.09.2026 im Jar nachgesehen: public, ohne
--- Argument, und der Rueckgabewert ist eine Zahl, ein Ja/Nein oder ein Text.
--- Erfunden ist keiner. Gefragt wird trotzdem vor jedem Aufruf, ob es die
--- Methode gibt: im Jar zu stehen und nach Lua durchgereicht zu sein, ist
--- nicht dasselbe - HaloTextHelper.overheadContains hat das am 10.09.2026
--- mit elf Eintraegen im Mod-Fehlerbericht gezeigt.
TFMeasure.AUTOINFO = {
    -- Fest waehrend eines Testlaufs: einmal je Fahrzeug in den Bericht.
    fahrzeug = {
        "getScriptName", "getVehicleType", "getMaxSpeed", "getEnginePower",
        "getEngineQuality", "getEngineLoudness", "getEngineCondition",
        "getMass", "getInitialMass", "getFudgedMass", "getBaseQuality",
        "getOffroadEfficiency", "getRemainingFuelPercentage", "getRust",
        "getMaxPassengers", "getMaxWheelSteering", "getMinWheelSkid",
    },
    skript = {
        "getName", "getFullType", "getFileName", "getEngineForce",
        "getEngineIdleSpeed", "getEngineQuality", "getEngineLoudness",
        "getEngineRPMType", "getMass", "getGearRatioCount", "getWheelCount",
        "getWheelFriction", "getRollInfluence", "getSteeringIncrement",
        "getSuspensionStiffness", "getSuspensionDamping", "getOffroadEfficiency",
        "getPlayerDamageProtection", "getSeats", "getStorageCapacity",
    },
    -- Aendert sich beim Fahren und ist eine Zahl: Median je Tempofenster.
    verlauf = {
        "getForce", "getEngineSpeed", "getThrottle", "getBrakingForce",
        "getClientForce", "getCurrentSpeedKmHour", "getCurrentAbsoluteSpeedKmHour",
        "getSpeed2D", "getTransmissionNumber", "getCurrentSteering",
        "getFakeSpeedModifier", "getRegulatorSpeed", "getEngineCondition",
    },
    -- Aendert sich beim Fahren, ist aber keine Zahl: gesammelt werden die
    -- Auspraegungen, die im Anlauf vorkamen.
    zustand = {
        "getTransmissionNumberLetter", "isGasPedalPressed", "isBrakePedalPressed",
        "isBraking", "isDoingOffroad", "isEngineRunning", "isRegulator",
        "isAtRest", "isStopped",
    },
}

--- Einen Wert abfragen, ohne einen Fehlerbericht zu riskieren.
---
--- Gibt nil zurueck, wenn es die Methode nicht gibt oder sie nicht traegt.
local function frage(objekt, name)
    if not objekt or not name then return nil end
    local methode = objekt[name]
    if not methode then return nil end
    local wert = nil
    pcall(function() wert = objekt[name](objekt) end)
    return wert
end

--- Einen abgefragten Wert so schreiben, dass er im Bericht lesbar bleibt.
local function alsText(wert)
    local art = type(wert)
    if art == "number" then
        if wert == math.floor(wert) and wert < 1000000000 and wert > -1000000000 then
            return string.format("%d", wert)
        end
        return string.format("%.3f", wert)
    end
    if art == "boolean" then return wert and "ja" or "nein" end
    return tostring(wert)
end

--- Der Steckbrief eines Fahrzeugs: alles Feste, was es ueber sich sagt.
local function steckbrief(vehicle)
    local zeilen = {}
    local skript = nil
    pcall(function() skript = vehicle:getScript() end)
    for quelle, objekt in pairs({ fahrzeug = vehicle, skript = skript }) do
        local objektNamen = TFMeasure.AUTOINFO[quelle]
        if objekt and objektNamen then
            local teile, fehlt = {}, {}
            for _, name in ipairs(objektNamen) do
                local wert = frage(objekt, name)
                if wert == nil then
                    fehlt[#fehlt + 1] = name
                else
                    teile[#teile + 1] = name .. "=" .. alsText(wert)
                end
            end
            if #teile > 0 then
                zeilen[#zeilen + 1] = "info|" .. quelle .. "|" .. table.concat(teile, "|")
            end
            if #fehlt > 0 then
                zeilen[#zeilen + 1] = "info|" .. quelle .. "|nicht lesbar: "
                    .. table.concat(fehlt, ",")
            end
        end
    end
    return zeilen
end

--- In welches Tempofenster faellt dieses Tempo? nil heisst: in keines.
local function fensterIndex(richtung, tempo)
    local grenzen = TFMeasure.ACCEL.fenster and TFMeasure.ACCEL.fenster[richtung]
    if not grenzen then return nil end
    local treffer = nil
    for i = 1, #grenzen do
        if tempo >= grenzen[i] then treffer = i end
    end
    return treffer
end

--- Untere und obere Kante eines Tempofensters.
local function fensterSpanne(richtung, index)
    local grenzen = TFMeasure.ACCEL.fenster and TFMeasure.ACCEL.fenster[richtung]
    if not grenzen or not grenzen[index] then return nil, nil end
    local unten = grenzen[index]
    local oben = grenzen[index + 1]
    if not oben then
        -- Letztes Fenster: nach oben offen. Als Kante die Schrittweite des
        -- Fensters davor, sonst die des ersten Paars.
        local schritt = (grenzen[index] - (grenzen[index - 1] or 0))
        if schritt <= 0 then schritt = 5 end
        oben = unten + schritt
    end
    return unten, oben
end

--- Vorhergesagter Kraftfaktor mit/ohne Trait bei diesem Tempo.
---
--- Aus CarController.control_ForwardNew, Offsets 826 bis 978, am 11.09.2026
--- aus dem Bytecode gelesen:
---
---     if sundayDriver:
---         engineForce *= 0.75
---         if speed > maxSpeed * 0.6:
---             engineForce *= (maxSpeed * 0.75 + 20 - speed) / 20
---     if speedDemon:
---         if speed > maxSpeed * 1.15:
---             engineForce *= (maxSpeed * 1.15 + 20 - speed) / 20
---     else:                                  # trifft auch Sunday Driver
---         if speed > maxSpeed:
---             engineForce *= (maxSpeed + 20 - speed) / 20
---
--- Zwei Dinge stehen nirgends sonst: Sunday Drivers eigener Faktor ist bei
--- seinem Einsatz GROESSER als 1 (bei 0.6 M ist er 1 + 0.0075 * M, beim
--- PickUpVan 1.45), und der letzte Zweig trifft Sunday Driver mit, weil er
--- kein Speed Demon ist. Fuer das Verhaeltnis mit/ohne kuerzt sich der
--- letzte Zweig weg, fuer Speed Demon nicht.
local function kraftVorhersage(key, tempo, maxSpeed)
    if not maxSpeed or maxSpeed <= 0 then return nil end
    if key == "sundaydriver" then
        local f = 0.75
        if tempo > maxSpeed * 0.6 then
            f = f * (maxSpeed * 0.75 + 20 - tempo) / 20
        end
        return f
    end
    if key == "speeddemon" then
        local mit = 1
        if tempo > maxSpeed * 1.15 then
            mit = (maxSpeed * 1.15 + 20 - tempo) / 20
        end
        local ohne = 1
        if tempo > maxSpeed then
            ohne = (maxSpeed + 20 - tempo) / 20
        end
        if ohne == 0 then return nil end
        return mit / ohne
    end
    return nil
end

--- Name eines Fensters fuer den Bericht, etwa "ab10".
local function fensterName(richtung, index)
    local grenzen = TFMeasure.ACCEL.fenster and TFMeasure.ACCEL.fenster[richtung]
    if not grenzen or not grenzen[index] then return "?" end
    return "ab" .. tostring(grenzen[index])
end

--- Median einer Liste von Zahlen.
local function median(werte)
    local n = #werte
    if n == 0 then return 0 end
    local sortiert = {}
    for i = 1, n do sortiert[i] = werte[i] end
    table.sort(sortiert)
    local mitte = math.floor((n + 1) / 2)
    if n % 2 == 1 then return sortiert[mitte] end
    return (sortiert[mitte] + sortiert[mitte + 1]) / 2
end

--- Teile von accelFinish (seit 6.26.2). Kahlua schreibt im Debug-Modus zu
-- jeder lokalen Variable die Zeile mit, in ein Feld mit 200 Plaetzen, und
-- zaehlt dafuer alle je in einer Funktion angelegten locals, auch die
-- versteckten jeder for-Schleife (LexState.new_localvar, Offsets 45-99:
-- actvarline[registerlocalvar()]). accelFinish legte 224 an; mit -debug
-- lud das Mess-Mod am 13.09.2026 deshalb gar nicht (ArrayIndexOutOfBounds
-- in LexState.new_localvar). Ohne -debug faellt es nie auf. Der Smoke-Test
-- prueft seither, dass keine Funktion mehr als 180 anlegt.
--
-- Der Kraftfaktor je Tempofenster, mit Vorhersage und Warnungen.
function TFMeasure.accelWertfaktoren(state, abgelesen, lines)
    -- Der Wertfaktor ist die eigentliche Antwort: gleiche Groesse, gleiche
    -- Richtung, gleiches Tempofenster, einmal mit und einmal ohne Trait.
    -- Anders als der Zeitfaktor haengt er nicht an der Gangwahl.
    for _, name in ipairs(TFMeasure.AUTOINFO.verlauf) do
        for _, key in ipairs({ "sundaydriver", "speeddemon" }) do
            for _, richtung in ipairs({ "vor", "rueck" }) do
                local grenzen = TFMeasure.ACCEL.fenster
                    and TFMeasure.ACCEL.fenster[richtung] or {}
                for f = 1, #grenzen do
                    local mit, ohne, n = 0, 0, 0
                    local einzeln = {}
                    for index, phase in ipairs(state.results) do
                        local hier = abgelesen[index] and abgelesen[index][richtung]
                            and abgelesen[index][richtung][f]
                        local davor = abgelesen[index - 1] and abgelesen[index - 1][richtung]
                            and abgelesen[index - 1][richtung][f]
                        local a = hier and hier[name]
                        local b = davor and davor[name]
                        local vorher = state.results[index - 1]
                        if phase.name == key and vorher and vorher.name == "none"
                                and a and b and b ~= 0 then
                            mit, ohne, n = mit + a, ohne + b, n + 1
                            einzeln[n] = string.format("%.4f", a / b)
                        end
                    end
                    if n > 0 and ohne ~= 0 then
                        -- Vorhersage und Warnungen nur an der Kraft und nur
                        -- vorwaerts: control_Reverse rechnet anders, und fuer
                        -- jede andere Groesse gibt es keine Formel.
                        local zusatz = ""
                        if name == "getForce" and richtung == "vor" then
                            local unten, oben = fensterSpanne(richtung, f)
                            local pMitte = unten and oben
                                and kraftVorhersage(key, (unten + oben) / 2, state.maxSpeed)
                            if pMitte then
                                zusatz = zusatz .. string.format("|vorhersage=%.4f", pMitte)
                                local pu = kraftVorhersage(key, unten, state.maxSpeed)
                                local po = kraftVorhersage(key, oben, state.maxSpeed)
                                if pu and po then
                                    local gross = math.max(math.abs(pu), math.abs(po), 0.01)
                                    if math.abs(pu - po) > 0.25 * gross then
                                        zusatz = zusatz .. "|STEIL"
                                    end
                                elseif pu or po then
                                    -- An einer Kante ist die Kraft ohne Trait
                                    -- null, das Verhaeltnis dort unendlich. Am
                                    -- PickUpVan stand im Fenster ab75 fuer
                                    -- Speed Demon 15.7 statt vorhergesagter 4.6,
                                    -- ohne Marke.
                                    zusatz = zusatz .. "|STEIL"
                                end
                            end
                            -- Der Drehzahlbegrenzer sitzt VOR den
                            -- Trait-Zweigen und trifft beide Phasen, aber
                            -- nicht gleich stark: er haengt an der Drehzahl,
                            -- und die unterscheidet sich mit Trait.
                            --
                            -- Nur die Phasen, die in dieses Verhaeltnis
                            -- eingehen: der Trait und die Phase ohne Trait
                            -- davor. Bis 6.15.0 zaehlten alle Phasen mit.
                            --
                            -- GANG UNGLEICH: beide Phasen fuhren im Fenster in
                            -- verschiedenen Gaengen. Am PickUpVan am 11.09.2026
                            -- mit Sunday Driver in ab30 und ab35 (Gang 3 gegen
                            -- 1): 0.50 und 0.67 statt 0.75 und 1.03, und keine
                            -- Marke, weil jede Phase fuer sich ganzzahlig war.
                            local warnung = {}
                            for index2, phase2 in ipairs(state.results) do
                                local vorher2 = state.results[index2 - 1]
                                if phase2.name == key and vorher2 and vorher2.name == "none" then
                                    local gangPaar = {}
                                    for _, i3 in ipairs({ index2 - 1, index2 }) do
                                        local hier2 = abgelesen[i3]
                                            and abgelesen[i3][richtung]
                                            and abgelesen[i3][richtung][f]
                                        if hier2 then
                                            local dz = hier2["getEngineSpeed"]
                                            if dz and dz > 6000 then warnung["BEGRENZER"] = true end
                                            local gang = hier2["getTransmissionNumber"]
                                            if gang then
                                                if gang ~= math.floor(gang) then
                                                    warnung["GANGKANTE"] = true
                                                end
                                                gangPaar[#gangPaar + 1] = gang
                                            end
                                        end
                                    end
                                    if #gangPaar == 2 and gangPaar[1] ~= gangPaar[2] then
                                        warnung["GANG UNGLEICH"] = true
                                    end
                                end
                            end
                            for _, w in ipairs({ "BEGRENZER", "GANGKANTE", "GANG UNGLEICH" }) do
                                if warnung[w] then zusatz = zusatz .. "|" .. w end
                            end
                        end
                        lines[#lines + 1] = string.format(
                            "wertfaktor|%s|%s|%s|%s|mit/ohne=%.4f|aus %d Paaren|einzeln=%s%s",
                            name, key, richtung, fensterName(richtung, f), mit / ohne, n,
                            table.concat(einzeln, ","), zusatz)
                    end
                end
            end
        end
    end
end

--- Hoechstgeschwindigkeit, nie lesbare Groessen und Zeitfaktor.
function TFMeasure.accelUebrige(state, werte, lines)
    -- Die Hoechstgeschwindigkeit, mit Trait gegen ohne. Sie faellt in
    -- demselben Anlauf ab, der die Beschleunigung misst, und sie ist die
    -- einzige Zahl hier, die nicht an einem Tempofenster haengt.
    for _, key in ipairs({ "sundaydriver", "speeddemon" }) do
        -- Beide Richtungen. 6.14.0 hatte rueckwaerts gestrichen, weil der
        -- Anlauf dort an einer festen Marke endete und der Faktor immer 1
        -- war; seit 6.15.0 faehrt auch rueckwaerts bis das Tempo steht.
        for _, richtung in ipairs({ "vor", "rueck" }) do
            local mit, ohne, n, einzeln = 0, 0, 0, {}
            for index, phase in ipairs(state.results) do
                local vorher = state.results[index - 1]
                local a = phase.hoechst and phase.hoechst[richtung]
                local b = vorher and vorher.hoechst and vorher.hoechst[richtung]
                -- Ein Anlauf, den die Reissleine beendet hat, hat sein
                -- Plateau nie erreicht; sein Hoechstwert ist eine
                -- Untergrenze und gehoert in keinen Faktor.
                local rissA = (phase.reissleine and phase.reissleine[richtung]) or 0
                local rissB = (vorher and vorher.reissleine
                    and vorher.reissleine[richtung]) or 0
                if phase.name == key and vorher and vorher.name == "none"
                        and rissA == 0 and rissB == 0
                        and a and #a > 0 and b and #b > 0 and median(b) > 0 then
                    local wa, wb = median(a), median(b)
                    mit, ohne, n = mit + wa, ohne + wb, n + 1
                    einzeln[n] = string.format("%.4f", wa / wb)
                end
            end
            if n > 0 and ohne > 0 then
                lines[#lines + 1] = string.format(
                    "tempofaktor|%s|%s|hoechst mit/ohne=%.4f|aus %d Paaren|einzeln=%s",
                    key, richtung, mit / ohne, n, table.concat(einzeln, ","))
            end
        end
    end

    -- Was in keinem einzigen Fenster eine Zahl geliefert hat. Ohne diese
    -- Zeile verschwindet eine Groesse, die die Build nicht durchreicht,
    -- lautlos aus dem Bericht - getFakeSpeedModifier hat das am 11.09.2026
    -- vorgemacht.
    local nie = {}
    for _, name in ipairs(TFMeasure.AUTOINFO.verlauf) do
        local gesehen = false
        for _, phase in ipairs(state.results) do
            for _, richtung in ipairs({ "vor", "rueck" }) do
                if phase.verlauf and phase.verlauf[richtung]
                        and phase.verlauf[richtung][name] then
                    gesehen = true
                end
            end
        end
        if not gesehen then nie[#nie + 1] = name end
    end
    if #nie > 0 then
        lines[#lines + 1] = "info|verlauf|nicht lesbar: " .. table.concat(nie, ",")
    end

    -- Ein Trait wird gegen die Phase ohne Trait davor gerechnet, je Richtung.
    -- Mehr Ticks heisst traeger, der Faktor ist also eine Zeit und keine Kraft.
    --
    -- Bis 6.13.1 stand hier eine Tabelle `erwartet` mit 1.33 / 1.43 / 1.00 /
    -- 0.33. Zwei dieser vier Zahlen waren am 11.09.2026 widerlegt, und der
    -- Bericht trug sie weiter als Sollwert: rueckwaerts ist die Zeit keine
    -- Kraftmessung (das schreibt der Bericht zwei Zeilen weiter oben selbst),
    -- und Speed Demons dreifache Drehzahl ist rund 10 % Kraft wert, nicht
    -- dreifache Beschleunigung. Eine Erwartung, die der eigene Befund schon
    -- widerlegt hat, ist schlimmer als gar keine. Die Kraft je Fenster traegt
    -- ihre Vorhersage jetzt selbst.
    for _, key in ipairs({ "sundaydriver", "speeddemon" }) do
        for _, richtung in ipairs({ "vor", "rueck" }) do
            local mit, ohne, n, paare = 0, 0, 0, {}
            for index, phase in ipairs(state.results) do
                local vorher = state.results[index - 1]
                if phase.name == key and vorher and vorher.name == "none"
                        and werte[index] and werte[index][richtung]
                        and werte[index - 1] and werte[index - 1][richtung]
                        and werte[index - 1][richtung] > 0 then
                    mit = mit + werte[index][richtung]
                    ohne = ohne + werte[index - 1][richtung]
                    n = n + 1
                    paare[n] = werte[index][richtung] / werte[index - 1][richtung]
                end
            end
            if n > 0 and ohne > 0 then
                local einzeln = {}
                for _, w in ipairs(paare) do einzeln[#einzeln + 1] = string.format("%.4f", w) end
                -- Die Zeit ist seit 6.10.0 nur noch die Probe aufs Exempel;
                -- die Zahl fuer die Mod steht in wertfaktor|getForce.
                local warnung = ""
                if richtung == "vor" and key == "sundaydriver" and state.maxSpeed
                        and state.maxSpeed * 0.6 < TFMeasure.ACCEL.bis.vor then
                    warnung = "|ZEITFENSTER UNSAUBER, siehe info|zeitfenster"
                end
                lines[#lines + 1] = string.format(
                    "faktor|%s|%s|zeit mit/ohne=%.4f|aus %d Paaren|einzeln=%s%s",
                    key, richtung, mit / ohne, n, table.concat(einzeln, ","), warnung)
            else
                lines[#lines + 1] = "faktor|" .. key .. "|" .. richtung .. "|nicht messbar"
            end
        end
    end
end

local function accelFinish(player, reason)
    if not accel then return end
    local state = accel
    accel = nil
    pcall(carPhaseTrait, player, "none")
    -- Nach dem Ende gibt es keine Anweisung mehr. Bis 6.15.0 blieb die letzte
    -- stehen und wurde endlos nachgesetzt: endete der Test mit einem
    -- Vorwaertsanlauf, stand "50 km/h nach N Ticks - jetzt Vollgas halten"
    -- ueber dem Kopf, bis das Spiel beendet war.
    TFMeasure.stehendeZeile = nil

    local lines = {}
    lines[#lines + 1] = "# " .. reason
    lines[#lines + 1] = "# streuung: wie weit die Anlaeufe einer Phase auseinanderliegen;"
        .. " ueber 10 % steht UNRUHIG daneben und der Wert taugt wenig"
    lines[#lines + 1] = "# info: alles, was Fahrzeug und Fahrzeugskript ueber sich sagen,"
        .. " einmal je Testlauf abgefragt"
    lines[#lines + 1] = "# probe: jede Groesse, die sich beim Fahren aendert, als Median je"
        .. " Tempofenster; was fehlt, steht als nicht lesbar im info-Block"
    lines[#lines + 1] = "# zustand: die Auspraegungen, die im Anlauf vorkamen (Gang, Pedale)"
    lines[#lines + 1] = "# hoechst: das hoechste Tempo dieses Anlaufs; beide Richtungen fahren"
        .. " bis das Tempo steht, damit Beschleunigung und Hoechstgeschwindigkeit aus einer Fahrt kommen"
    lines[#lines + 1] = "# tempofaktor: Hoechstgeschwindigkeit mit Trait geteilt durch ohne Trait,"
        .. " je Richtung"
    lines[#lines + 1] = "# vorhersage: der Kraftfaktor, den control_ForwardNew fuer die Mitte dieses"
        .. " Fensters ergibt; STEIL heisst, er aendert sich ueber das Fenster um mehr als ein Viertel"
    lines[#lines + 1] = "# BEGRENZER: in diesem Fenster stand die Drehzahl ueber 6000, dort senkt die"
        .. " Engine die Kraft trait-unabhaengig auf null bei 7000 - der Faktor misst dann den Begrenzer"
    lines[#lines + 1] = "# GANGKANTE: im Fenster lag ein Gangwechsel, der Median mischt zwei Gaenge"
    lines[#lines + 1] = "# wertfaktor: dieselbe Groesse mit Trait geteilt durch ohne Trait,"
        .. " im selben Tempofenster - getForce ist die Zahl, die in die Mod gehoert"
    lines[#lines + 1] = "# rueckwaerts ist die Kraft fuer alle null ab 26.7 km/h (tempo * 1.5 >"
        .. " maxSpeedReverse 40); nur mit Sunday Driver faellt sie schon ab 3.3 km/h und ist"
        .. " bei 10 km/h null"
    lines[#lines + 1] = string.format(
        "# Zeit in Ticks UND Millisekunden, Median je Phase und Richtung; vorwaerts von"
        .. " %s auf %s km/h, rueckwaerts von %s auf %s; abgebrochene Anlaeufe zaehlen nicht."
        .. " Ticks sind Bilder, die Millisekunden sind die Wanduhr - weichen die Faktoren"
        .. " voneinander ab, hat die Bildrate geschwankt und die Ticks luegen",
        tostring(TFMeasure.ACCEL.von.vor), tostring(TFMeasure.ACCEL.bis.vor),
        tostring(TFMeasure.ACCEL.von.rueck), tostring(TFMeasure.ACCEL.bis.rueck))
    -- Die Schwellen dieses Wagens, ausgerechnet statt geschaetzt. Ohne sie
    -- liest man einen Kraftfaktor von 0.9 im Fenster ab40 als Messfehler,
    -- obwohl er genau das ist, was der Bytecode dort vorschreibt.
    if state.maxSpeed and state.maxSpeed > 0 then
        local m = state.maxSpeed
        lines[#lines + 1] = string.format(
            "info|grenzen|maxSpeed=%.1f|SundayDriver senkt ab %.1f, Kraft null bei %.1f"
            .. "|ohne Trait senkt ab %.1f, null bei %.1f"
            .. "|SpeedDemon senkt ab %.1f, null bei %.1f"
            .. "|Schranke 122.4 (34 m/s)",
            m, m * 0.6, m * 0.75 + 20, m, m + 20, m * 1.15, m * 1.15 + 20)
        -- Die Zeitmarke ist fest, die Schwelle haengt am Wagen. Liegt sie
        -- dazwischen, enthaelt die gemessene Zeit den Sprung auf 1.45 und
        -- den Abfall danach und taugt als Kraftmass nicht.
        if m * 0.6 < TFMeasure.ACCEL.bis.vor then
            lines[#lines + 1] = string.format(
                "info|zeitfenster|UNSAUBER fuer sundaydriver: seine Schwelle %.1f liegt"
                .. " zwischen %s und %s km/h; nimm die Kraft je Fenster, nicht die Zeit",
                m * 0.6, tostring(TFMeasure.ACCEL.von.vor), tostring(TFMeasure.ACCEL.bis.vor))
        end
    end
    if state.fahrzeug then
        lines[#lines + 1] = "# Fahrzeug: " .. tostring(state.fahrzeug)
    end
    for _, zeile in ipairs(state.steckbrief or {}) do
        lines[#lines + 1] = zeile
    end

    -- Je Phase und Richtung ein Median.
    local werte = {}
    for index, phase in ipairs(state.results) do
        for _, richtung in ipairs({ "vor", "rueck" }) do
            local liste = phase.laeufe[richtung]
            if liste and #liste > 0 then
                werte[index] = werte[index] or {}
                werte[index][richtung] = median(liste)
                local roh = {}
                for _, t in ipairs(liste) do roh[#roh + 1] = tostring(t) end
                local lo, hi = liste[1], liste[1]
                for _, t in ipairs(liste) do
                    if t < lo then lo = t end
                    if t > hi then hi = t end
                end
                local streuung = (lo > 0) and ((hi - lo) / lo * 100) or 0
                local hoch = phase.hoechst and phase.hoechst[richtung]
                local msListe = phase.ms and phase.ms[richtung]
                local riss = (phase.reissleine and phase.reissleine[richtung]) or 0
                lines[#lines + 1] = string.format(
                    "phase|%d|%s|%s|laeufe=%d|ticks=%.1f|ms=%s|einzeln=%s|streuung=%.1f%%|hoechst=%s|trait=%s%s%s",
                    index, phase.name, richtung, #liste, werte[index][richtung],
                    (msListe and #msListe > 0) and string.format("%.0f", median(msListe)) or "-",
                    table.concat(roh, ","), streuung,
                    (hoch and #hoch > 0) and string.format("%.3f", median(hoch)) or "-",
                    (phase.name == "none" and "-")
                    or (phase.applied and "gesetzt" or "NICHT GESETZT"),
                    (streuung > 10) and "|UNRUHIG" or "",
                    -- Ein Anlauf, den die Reissleine beendet hat, hat sein
                    -- Plateau nie erreicht. Ohne diese Marke sieht sein
                    -- hoechst= aus wie ein ausgefahrenes.
                    (riss > 0) and "|REISSLEINE" or "")
            end
        end
    end

    -- Was abgelesen wurde, je Phase, Richtung und Tempofenster. Eine Zeile
    -- traegt alle Groessen nebeneinander, damit sich Kraft, Drehzahl und Gang
    -- im selben Fenster ohne Blaettern vergleichen lassen.
    local abgelesen = {}
    for index, phase in ipairs(state.results) do
        for _, richtung in ipairs({ "vor", "rueck" }) do
            local grenzen = TFMeasure.ACCEL.fenster and TFMeasure.ACCEL.fenster[richtung] or {}
            for f = 1, #grenzen do
                local teile = {}
                for _, name in ipairs(TFMeasure.AUTOINFO.verlauf) do
                    local topf = phase.verlauf and phase.verlauf[richtung]
                        and phase.verlauf[richtung][name]
                    local werte = topf and topf[f]
                    if werte and #werte > 0 then
                        local wert = median(werte)
                        abgelesen[index] = abgelesen[index] or {}
                        abgelesen[index][richtung] = abgelesen[index][richtung] or {}
                        abgelesen[index][richtung][f] = abgelesen[index][richtung][f] or {}
                        abgelesen[index][richtung][f][name] = wert
                        teile[#teile + 1] = name .. "=" .. string.format("%.3f", wert)
                    end
                end
                if #teile > 0 then
                    lines[#lines + 1] = string.format("probe|%d|%s|%s|%s|%s",
                        index, phase.name, richtung, fensterName(richtung, f),
                        table.concat(teile, "|"))
                end
            end
        end
    end

    -- Was kein Zahlenwert ist, aber trotzdem gesagt werden will: Gang, Pedale,
    -- Zustand. Gesammelt sind die Auspraegungen, die im Anlauf vorkamen.
    for index, phase in ipairs(state.results) do
        for _, richtung in ipairs({ "vor", "rueck" }) do
            local teile = {}
            for _, name in ipairs(TFMeasure.AUTOINFO.zustand) do
                local gesehen = phase.zustand and phase.zustand[richtung]
                    and phase.zustand[richtung][name]
                if gesehen then
                    local liste = {}
                    for wert in pairs(gesehen) do liste[#liste + 1] = wert end
                    table.sort(liste)
                    teile[#teile + 1] = name .. "=" .. table.concat(liste, "/")
                end
            end
            if #teile > 0 then
                lines[#lines + 1] = string.format("zustand|%d|%s|%s|%s",
                    index, phase.name, richtung, table.concat(teile, "|"))
            end
        end
    end

    TFMeasure.accelWertfaktoren(state, abgelesen, lines)
    TFMeasure.accelUebrige(state, werte, lines)

    local ok = pcall(function()
        local writer = getFileWriter(TFMeasure.FILE, true, true)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        writer:write(nl .. "[beschleunigung] phase|nr|trait|richtung|laeufe|ticks" .. nl)
        for _, line in ipairs(lines) do writer:write(line .. nl) end
        writer:close()
    end)
    if not ok then
        for _, line in ipairs(lines) do log(line) end
    end
    halo(player, "Beschleunigungstest: " .. reason, reason == "abgeschlossen")
    log(tostring(#lines) .. " Zeilen an Zomboid/Lua/" .. TFMeasure.FILE .. " angehaengt.")
end

--- Ein Tick des Beschleunigungstests.
--- Wanduhr in Millisekunden, mit Rueckfall auf die Tickzahl.
---
--- Ticks sind Bilder, keine Zeit: bei 30 Bildern dauert derselbe Tick
--- doppelt so lang wie bei 60. Alles, was eine Sekunde meint, muss deshalb
--- die Uhr fragen. getTimestampMs gibt es in der Build (der Sprinttest
--- benutzt es seit 2.0.0), gefragt wird trotzdem.
local uhrOk = nil
local function uhrzeit(ticks)
    if uhrOk == nil then
        uhrOk = false
        pcall(function()
            if type(getTimestampMs) == "function" then
                local t = getTimestampMs()
                if type(t) == "number" then uhrOk = true end
            end
        end)
    end
    if uhrOk then
        local t = nil
        pcall(function() t = getTimestampMs() end)
        if type(t) == "number" then return t end
    end
    -- Ohne Uhr bleibt nur die Annahme von 60 Bildern je Sekunde.
    return (ticks or 0) * 1000 / 60
end

--- Wie ein Trait ueber dem Kopf heisst. Die Kennung ("sundaydriver") ist
--- fuer den Bericht, der Fahrer liest den Namen aus dem Spiel.
local TRAITANZEIGE = { sundaydriver = "Sunday Driver", speeddemon = "Speed Demon" }
local function traitAnzeige(name)
    return TRAITANZEIGE[name] or tostring(name)
end

function TFMeasure.accelTick()
    local state = accel
    if not state then return end
    if car and car.started then return end
    if sprint and sprint.started then return end
    local player = state.player
    state.age = state.age + 1
    if state.age > TFMeasure.ACCEL.timeoutTicks then
        accelFinish(player, "Zeit abgelaufen, Ergebnis unvollstaendig")
        return
    end

    -- Sagt, was gerade dran ist, und nur beim Wechsel: sonst stuende jede
    -- Sekunde dieselbe Zeile ueber dem Kopf.
    local function hinweis(text)
        if state.hint == text then return end
        state.hint = text
        haloStehend(player, text)
    end

    local imAuto = nil
    pcall(function() imAuto = player:getVehicle() end)
    if not imAuto then
        hinweis("Beschleunigung: in ein Auto setzen")
        return
    end
    local vehicle = fahrzeugAmSteuer(player)
    if not vehicle then
        hinweis("Beschleunigung: du sitzt nicht am Steuer")
        return
    end
    local laeuft = false
    pcall(function() laeuft = vehicle:isEngineRunning() end)
    if not laeuft then
        hinweis("Beschleunigung: Motor starten")
        return
    end
    local roh = 0
    pcall(function() roh = vehicle:getCurrentSpeedKmHour() end)
    local tempo = (roh < 0) and -roh or roh
    local richtung = (roh < 0) and "rueck" or "vor"

    if not state.started then
        state.started = true
        state.phase = 1
        state.results = {}
        pcall(function() state.fahrzeug = tostring(vehicle:getScript():getName()) end)
        -- getMaxSpeed ist ein nacktes Feld, einmal in createPhysics aus dem
        -- Skript gesetzt (BaseVehicle, nachgesehen am 11.09.2026). Kein
        -- Trait fasst es an, es gilt also fuer alle Phasen dieses Laufs.
        pcall(function() state.maxSpeed = vehicle:getMaxSpeed() end)
        state.steckbrief = steckbrief(vehicle)
        for _, zeile in ipairs(state.steckbrief) do log(zeile) end
    end

    -- Der Trait wechselt erst im Stand. Bis 6.14.0 schaltete der Test in
    -- dem Tick um, in dem der letzte Anlauf der Phase fertig war - also
    -- mitten in der Fahrt, rueckwaerts bei 6 km/h oder vorwaerts auf dem
    -- Plateau. Gemessen wurde danach nichts, weil ein neuer Anlauf ohnehin
    -- erst nach dem Anhalten beginnt; aber ueber dem Kopf stand schon der
    -- naechste Trait, waehrend man noch mit dem alten fuhr, und niemand
    -- konnte sehen, welcher gerade galt. Jetzt gilt: solange der Wagen
    -- rollt, bleibt der alte Trait gesetzt, und die Zeile sagt, was nach
    -- dem Anhalten kommt.
    if state.phaseFertig then
        if tempo >= TFMeasure.ACCEL.stillstand then
            local naechste = TFMeasure.ACCEL.phases[state.phase + 1]
            hinweis((naechste == "none")
                and "Anhalten - danach geht es ohne Trait weiter"
                or ("Anhalten - danach wird " .. traitAnzeige(naechste) .. " gesetzt"))
            return
        end
        state.phaseFertig = false
        state.phase = state.phase + 1
    end

    local phaseName = TFMeasure.ACCEL.phases[state.phase]
    if not state.results[state.phase] then
        local applied = false
        pcall(function() applied = carPhaseTrait(player, phaseName) end)
        state.results[state.phase] = { name = phaseName, applied = applied,
            laeufe = { vor = {}, rueck = {} },
            ms = { vor = {}, rueck = {} },
            reissleine = { vor = 0, rueck = 0 },
            verlauf = { vor = {}, rueck = {} },
            zustand = { vor = {}, rueck = {} },
            hoechst = { vor = {}, rueck = {} } }
        state.bereit, state.laeuft = false, false
        state.hint = nil
        local anzeige
        if phaseName == "none" then
            anzeige = "ohne Trait"
        elseif applied then
            anzeige = traitAnzeige(phaseName) .. " gesetzt"
        else
            anzeige = traitAnzeige(phaseName) .. ": TRAIT NICHT GESETZT"
        end
        halo(player, string.format("Phase %d von %d: %s - einmal rueckwaerts, einmal vorwaerts",
            state.phase, #TFMeasure.ACCEL.phases, anzeige),
            (phaseName ~= "none" and not applied) and false or nil)
    end
    local phase = state.results[state.phase]
    TFMeasure.ausdauerVoll(player)

    -- Zustandsfolge je Anlauf: erst langsam genug (bereit), dann ueber `von`
    -- (Uhr laeuft), dann ueber `bis` (Lauf zaehlt). Wer unterwegs unter die
    -- halbe Startschwelle faellt, verwirft seinen Anlauf selbst.
    if not state.laeuft then
        if tempo < TFMeasure.ACCEL.stillstand then
            state.bereit = true
            local offen = {}
            for _, r in ipairs(TFMeasure.ACCEL.richtungen) do
                if #phase.laeufe[r] < TFMeasure.ACCEL.laeufeJePhase then
                    offen[#offen + 1] = (r == "vor")
                        and "vorwaerts bis das Tempo steht"
                        or "RUECKWAERTS bis das Tempo steht"
                end
            end
            hinweis("Bereit - jetzt Vollgas " .. table.concat(offen, " oder "))
        elseif state.bereit and tempo >= TFMeasure.ACCEL.von[richtung] then
            state.laeuft, state.bereit = true, false
            state.uhr, state.richtung = 0, richtung
            -- Frische Sammelbehaelter je Anlauf: ein verworfener Anlauf soll
            -- keine Werte in den naechsten schleppen.
            state.proben, state.gesehen = {}, {}
            state.hoechst, state.zeitBis = 0, nil
            state.fensterAb, state.fensterBasis = nil, 0
            state.laufAb, state.reissleine = uhrzeit(0), false
            -- Die Anweisung ist befolgt, sie muss nicht weiter stehen.
            TFMeasure.stehendeZeile = nil
            state.hint = nil
        elseif state.bereit then
            -- Angehalten und wieder am Rollen, aber noch unter der Marke, ab
            -- der die Uhr laeuft (vorwaerts 10 km/h). Das ist der normale
            -- Weg in den Anlauf, hier steht "Bereit" schon ueber dem Kopf.
            -- Bis 6.13.0 fiel dieser Fall in den Zweig darunter, und wer
            -- gerade losfuhr, las "Erst anhalten".
        else
            hinweis("Erst anhalten, dann geht es los")
        end
        return
    end

    state.uhr = state.uhr + 1

    -- Ablesen, solange der Anlauf laeuft. Ein Tick ohne Fenster (etwa knapp
    -- unter der ersten Grenze) wird nicht gezaehlt, statt in ein falsches
    -- Fenster zu rutschen.
    local f = fensterIndex(state.richtung, tempo)
    if f and state.proben then
        for _, name in ipairs(TFMeasure.AUTOINFO.verlauf) do
            local wert = frage(vehicle, name)
            if type(wert) == "number" then
                state.proben[name] = state.proben[name] or {}
                local topf = state.proben[name]
                topf[f] = topf[f] or {}
                topf[f][#topf[f] + 1] = wert
            end
        end
        for _, name in ipairs(TFMeasure.AUTOINFO.zustand) do
            local wert = frage(vehicle, name)
            if wert ~= nil then
                state.gesehen[name] = state.gesehen[name] or {}
                state.gesehen[name][alsText(wert)] = true
            end
        end
    end

    if richtung ~= state.richtung or tempo < TFMeasure.ACCEL.stillstand then
        state.laeuft = false
        state.hint = nil
        TFMeasure.stehendeZeile = nil
        halo(player, "Anlauf abgebrochen - noch einmal, ohne vom Gas zu gehen", false)
        return
    end

    -- Der Hoechstwert dieses Anlaufs ist die Hoechstgeschwindigkeit dieser
    -- Phase. Gemessen wird sein ZUWACHS ueber ein Zeitfenster; warum nicht
    -- von Tick zu Tick, steht an TFMeasure.ACCEL.
    if tempo > state.hoechst then state.hoechst = tempo end
    local jetzt = uhrzeit(state.uhr)
    if not state.fensterAb
            or tempo < (state.hoechst - TFMeasure.ACCEL.plateauNah) then
        state.fensterAb, state.fensterBasis = jetzt, state.hoechst
    end
    local steht = false
    if (jetzt - state.fensterAb) >= TFMeasure.ACCEL.plateauFensterMs then
        steht = (state.hoechst - state.fensterBasis)
            < TFMeasure.ACCEL.plateauZuwachs
        state.fensterAb, state.fensterBasis = jetzt, state.hoechst
    end
    -- Die Zeitmarke faellt unterwegs, sie beendet den Anlauf nicht mehr.
    if not state.zeitBis and tempo >= TFMeasure.ACCEL.bis[state.richtung] then
        state.zeitBis = state.uhr
        -- Ticks sind Bilder. Dieselbe Fahrt hat bei 80 Bildern je Sekunde ein
        -- Drittel mehr Ticks als bei 60, ohne dass sich irgendetwas am Wagen
        -- geaendert hat - der Ausreisser vom 11.09.2026 (165 statt 134) ist
        -- damit erklaerbar. Deshalb steht die Wanduhr daneben.
        state.msBis = jetzt - state.laufAb
        if state.richtung == "vor" then
            state.hint = nil
            haloStehend(player, string.format(
                "%d km/h nach %d Ticks - jetzt Vollgas halten, bis das Tempo steht",
                TFMeasure.ACCEL.bis.vor, state.uhr))
        end
    end

    local fertig = false
    if state.zeitBis then
        if steht then
            fertig = true
        elseif (jetzt - state.laufAb) >= TFMeasure.ACCEL.plateauMaxMs then
            fertig, state.reissleine = true, true
            halo(player, string.format(
                "Anlauf nach %d s abgebrochen - Hoechstwert %.1f km/h ist eine "
                .. "Untergrenze, nicht das Plateau",
                TFMeasure.ACCEL.plateauMaxMs / 1000, state.hoechst), false)
        end
    end
    if fertig then
        state.laeuft = false
        -- "Vollgas halten, bis das Tempo steht" ist jetzt erfuellt.
        TFMeasure.stehendeZeile = nil
        local liste = phase.laeufe[state.richtung]
        liste[#liste + 1] = state.zeitBis
        local msListe = phase.ms[state.richtung]
        msListe[#msListe + 1] = state.msBis or 0
        if state.reissleine then
            phase.reissleine[state.richtung] = phase.reissleine[state.richtung] + 1
        end
        local hoechste = phase.hoechst[state.richtung]
        hoechste[#hoechste + 1] = state.hoechst
        -- Je Groesse und Fenster den Median dieses Anlaufs merken. Mehrere
        -- Anlaeufe einer Phase legen mehrere Zahlen ab, aus denen der Bericht
        -- am Ende wieder den Median nimmt.
        if state.proben then
            local ziel = phase.verlauf[state.richtung]
            for name, quelle in pairs(state.proben) do
                ziel[name] = ziel[name] or {}
                for index, werte in pairs(quelle) do
                    if #werte > 0 then
                        ziel[name][index] = ziel[name][index] or {}
                        local topf = ziel[name][index]
                        topf[#topf + 1] = median(werte)
                    end
                end
            end
        end
        if state.gesehen then
            local ziel = phase.zustand[state.richtung]
            for name, werte in pairs(state.gesehen) do
                ziel[name] = ziel[name] or {}
                for wert in pairs(werte) do ziel[name][wert] = true end
            end
        end
        state.proben, state.gesehen = nil, nil
        -- Nur gezaehlte Richtungen bringen die Phase voran.
        local zaehlt = false
        for _, r in ipairs(TFMeasure.ACCEL.richtungen) do
            if r == state.richtung then zaehlt = true end
        end
        state.hint = nil
        -- Was der Phase noch fehlt, je Richtung.
        local offen = {}
        for _, r in ipairs(TFMeasure.ACCEL.richtungen) do
            if #phase.laeufe[r] < TFMeasure.ACCEL.laeufeJePhase then
                offen[#offen + 1] = (r == "vor") and "vorwaerts" or "rueckwaerts"
            end
        end
        halo(player, string.format("%s in %d Ticks, hoechstens %.1f km/h - %s",
            (state.richtung == "vor") and "Vorwaerts" or "Rueckwaerts",
            state.zeitBis, state.hoechst,
            (not zaehlt and "zaehlt hier nicht")
            or ((#offen == 0) and ((state.phase >= #TFMeasure.ACCEL.phases)
                and "letzte Phase fertig" or "Phase fertig, jetzt anhalten"))
            or ("jetzt noch " .. table.concat(offen, " und "))), zaehlt)
        if #offen == 0 then
            if state.phase >= #TFMeasure.ACCEL.phases then
                accelFinish(player, "abgeschlossen")
            else
                -- Umgeschaltet wird im naechsten Stand, siehe oben.
                state.phaseFertig = true
            end
        end
    end
end

--- Beschleunigungstest scharfschalten.
function TFMeasure.armAccel(player)
    player = player or getSpecificPlayer(0)
    if not player then return end
    accel = { player = player, age = 0, started = false, phase = 0, results = {},
              bereit = false, laeuft = false }
    halo(player, string.format("Beschleunigungstest: Auto suchen, Motor an. %d Phasen, "
        .. "je einmal aus dem Stand rueckwaerts und vorwaerts, jeweils bis das Tempo steht",
        #TFMeasure.ACCEL.phases))
    log(string.format("Beschleunigungstest: %d Phasen, je %d Anlaeufe. Vorwaerts von %d km/h "
        .. "an, die Zeit wird bei %d genommen, gefahren wird bis das Tempo steht - "
        .. "so kommen Beschleunigung, Gaenge und Hoechstgeschwindigkeit aus einer "
        .. "Fahrt. Rueckwaerts von %.1f an, die Zeit wird bei %d genommen, gefahren "
        .. "wird ebenfalls bis das Tempo steht. Zwischen den Anlaeufen unter %.1f km/h "
        .. "kommen; der Trait wechselt erst im Stand.",
        #TFMeasure.ACCEL.phases, TFMeasure.ACCEL.laeufeJePhase,
        TFMeasure.ACCEL.von.vor, TFMeasure.ACCEL.bis.vor,
        TFMeasure.ACCEL.von.rueck, TFMeasure.ACCEL.bis.rueck,
        TFMeasure.ACCEL.stillstand))
end

--- Laeuft der Beschleunigungstest? Nur fuer den Smoke-Test.
function TFMeasure.beschleunigungLaeuft()
    return (accel ~= nil) and (accel.started == true)
end

--- Ist ein Test scharf (wartend oder laufend)? Nur fuer den Smoke-Test.
-- Damit laesst sich festhalten, dass beim Weltbetreten nur der offene Test
-- anspringt und die beiden fertigen schweigen.
function TFMeasure.beschleunigungScharf() return accel ~= nil end
function TFMeasure.autotestScharf() return car ~= nil end
function TFMeasure.sprintLaeuftOderWartet() return sprint ~= nil end

--- Misst die XP-Leiter und schreibt TFMeasure.XPFILE (F8).
--
-- Veraendert die Figur: Skillstufen und XP. Boost und Stufe stellt die
-- Messung danach zurueck, auch wenn unterwegs etwas wirft; die XP innerhalb
-- der Stufe nicht. Also nur mit einer Wegwerf-Figur, wie alle Messungen hier.
function TFMeasure.xpLeiter(player)
    player = player or getSpecificPlayer(0)
    if not player then
        log("XP-Leiter: keine Figur gefunden.")
        return
    end
    local xp = player:getXp()
    local cfg = TFMeasure.XP
    local lines, summary = {}, {}

    for _, name in ipairs(cfg.skills) do
        local perk = Perks and Perks[name]
        if not perk then
            lines[#lines + 1] = "# " .. name .. ": Perk fehlt"
        else
            local okStart, boost0, level0 = pcall(function()
                return xp:getPerkBoost(perk), player:getPerkLevel(perk)
            end)
            local faktoren = {}
            local ok, err = pcall(function()
                for stufe = 0, cfg.stufeBis do
                    for boost = 0, cfg.boostBis do
                        player:setPerkLevelDebug(perk, stufe)
                        xp:setXPToLevel(perk, stufe)
                        xp:setPerkBoost(perk, boost)
                        local before = xp:getXP(perk)
                        xp:AddXP(perk, cfg.menge)
                        local gain = xp:getXP(perk) - before
                        local faktor = gain / cfg.menge
                        faktoren[boost] = faktoren[boost] or {}
                        table.insert(faktoren[boost], faktor)
                        lines[#lines + 1] = string.format(
                            "xpleiter|%s|stufe=%d|boost=%d|%d gegeben|erhalten=%.4f (x%.3f)",
                            name, stufe, boost, cfg.menge, gain, faktor)
                    end
                end
            end)
            if not ok then lines[#lines + 1] = "# " .. name .. ": " .. tostring(err) end
            -- Zurueck, auch nach einem Fehler mitten in der Schleife.
            if okStart then
                pcall(function()
                    xp:setPerkBoost(perk, boost0)
                    player:setPerkLevelDebug(perk, level0)
                    xp:setXPToLevel(perk, level0)
                end)
            end
            for boost = 0, cfg.boostBis do
                local werte = faktoren[boost]
                if werte and #werte > 0 then
                    local lo, hi = werte[1], werte[1]
                    for _, wert in ipairs(werte) do
                        if wert < lo then lo = wert end
                        if wert > hi then hi = wert end
                    end
                    local verlauf = (hi - lo < 0.0005)
                        and string.format("stufen 0-%d gleich", cfg.stufeBis)
                        or string.format("schwankt %.3f bis %.3f", lo, hi)
                    summary[#summary + 1] = string.format("zusammenfassung|%s|boost=%d|faktor=%.3f|%s",
                        name, boost, werte[1], verlauf)
                end
            end
        end
    end

    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.XPFILE, true, false)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        local function write(line) writer:write(line .. nl) end
        write("# XP-Leiter, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        local version = "unbekannt"
        pcall(function() version = tostring(getCore():getVersionNumber()) end)
        write("# Build " .. version)
        write(string.format("# je Skill: Skillstufe 0-%d, Boost 0-%d, je %d XP ueber AddXP",
            cfg.stufeBis, cfg.boostBis, cfg.menge))
        write("")
        write("[zusammenfassung] skill|boost|faktor auf stufe 0|ueber die stufen")
        for _, line in ipairs(summary) do write(line) end
        write("")
        write("[leiter] skill|stufe|boost|gegeben|erhalten (faktor)")
        for _, line in ipairs(lines) do write(line) end
        writer:close()
    end)
    if okWrite then
        log("XP-Leiter geschrieben: Zomboid/Lua/" .. TFMeasure.XPFILE)
        halo(player, "XP-Leiter geschrieben: " .. TFMeasure.XPFILE, true)
    else
        log("XP-Leiter nicht geschrieben: " .. tostring(errWrite))
    end
end

--- Der Kletterlauf (siehe TFMeasure.KLETTERN). Schreibt KLETTERFILE.
-- @return { faelle, abweichungen, geschrieben } fuer das Messfenster
function TFMeasure.klettern(player)
    player = player or getSpecificPlayer(0)
    if not player then
        log("Klettern: keine Figur gefunden.")
        return
    end
    local container = player:getCharacterTraits()
    local xp = player:getXp()
    local cfg = TFMeasure.KLETTERN

    local function alleTraits()
        local out = {}
        local liste = container:getKnownTraits()
        if liste then
            for index = 0, liste:size() - 1 do out[#out + 1] = liste:get(index) end
        end
        return out
    end

    -- Ausgangslage: die eigenen Traits und die drei Stufen.
    local held = alleTraits()
    local perks, stufen0 = {}, {}
    for _, name in ipairs(cfg.skills) do
        local perk = Perks and Perks[name]
        if perk then
            perks[name] = perk
            stufen0[name] = player:getPerkLevel(perk)
        end
    end
    local function setze(name, stufe)
        local perk = perks[name]
        if not perk then return end
        player:setPerkLevelDebug(perk, stufe)
        pcall(function() xp:setXPToLevel(perk, stufe) end)
    end

    -- Jede Methode nur so lange fragen, wie es sie gibt: ein gefangener
    -- Fehler landet in Project Zomboid trotzdem im Mod-Report, und das
    -- Raster fragt jede Groesse ueber 600 Mal.
    local fehlt = {}
    local function zahl(id, fn)
        if fehlt[id] then return "-" end
        local ok, wert = pcall(fn)
        if not ok then
            fehlt[id] = tostring(wert)
            return "-"
        end
        if type(wert) == "number" then return string.format("%.4f", wert) end
        return "-"
    end
    local function messen()
        return {
            sicherheit = zahl("sicherheit", function() return player:getClimbingFailChanceFloat() end),
            hoch = zahl("seil_hoch", function() return player:getClimbRopeSpeed(false) end),
            runter = zahl("seil_runter", function() return player:getClimbRopeSpeed(true) end),
            tragen = zahl("tragen", function() return player:getMaxWeight() end),
        }
    end

    local zeilen, abweichungen, basis = {}, {}, {}
    local ok, err = pcall(function()
        for _, fall in ipairs(cfg.faelle) do
            local label = (#fall == 0) and "-" or table.concat(fall, "+")
            local typen, fehlend = {}, nil
            for _, key in ipairs(fall) do
                local traitType = traitTypeNamed(key)
                if traitType then typen[#typen + 1] = traitType else fehlend = key end
            end
            if fehlend then
                zeilen[#zeilen + 1] = "# " .. label .. ": Trait " .. fehlend .. " fehlt in der Registry"
            else
                for _, achse in ipairs(cfg.skills) do
                    if perks[achse] then
                        for stufe = 0, cfg.bis do
                            -- Erst alle Traits weg, dann die Stufen: was danach
                            -- an der Figur haengt, hat das Spiel gesetzt.
                            for _, traitType in ipairs(alleTraits()) do container:remove(traitType) end
                            local lv = {}
                            for _, name in ipairs(cfg.skills) do
                                lv[name] = (name == achse) and stufe or 0
                                setze(name, lv[name])
                            end
                            local fremd = {}
                            for _, traitType in ipairs(alleTraits()) do
                                fremd[#fremd + 1] = keyOf(traitType) or "?"
                                container:remove(traitType)
                            end
                            for _, traitType in ipairs(typen) do container:add(traitType) end
                            local w = messen()
                            local punkt = string.format("%d|%d|%d",
                                lv.Fitness or 0, lv.Strength or 0, lv.Nimble or 0)
                            zeilen[#zeilen + 1] = string.format("klettern|%s|%s|%s|%s|%s|%s%s",
                                label, punkt, w.sicherheit, w.hoch, w.runter, w.tragen,
                                (#fremd > 0) and ("|fremd=" .. table.concat(fremd, ",")) or "")
                            if label == "-" then
                                basis[punkt] = w
                            elseif basis[punkt] then
                                local b = basis[punkt]
                                for _, groesse in ipairs({ "sicherheit", "hoch", "runter" }) do
                                    if b[groesse] ~= w[groesse] then
                                        abweichungen[#abweichungen + 1] = string.format(
                                            "abweichung|%s|%s=%d|%s|%s->%s", label,
                                            string.lower(achse), stufe, groesse, b[groesse], w[groesse])
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    if not ok then zeilen[#zeilen + 1] = "# Lauf abgebrochen: " .. tostring(err) end

    -- Zurueck, auch nach einem Fehler: erst die Stufen, dann genau die Traits
    -- von vorher, denn ein Stufenwechsel kann Traits setzen.
    pcall(function()
        for name, stufe in pairs(stufen0) do setze(name, stufe) end
        for _, traitType in ipairs(alleTraits()) do container:remove(traitType) end
        for _, traitType in ipairs(held) do container:add(traitType) end
    end)

    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.KLETTERFILE, true, false)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        local function write(line) writer:write(line .. nl) end
        write("# Klettern, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        local version = "unbekannt"
        pcall(function() version = tostring(getCore():getVersionNumber()) end)
        write("# Build " .. version)
        write(string.format("# je Fall %s einzeln 0-%d, die anderen auf 0",
            table.concat(cfg.skills, ", "), cfg.bis))
        write("# sicherheit = getClimbingFailChanceFloat(), seil = getClimbRopeSpeed(false/true),"
            .. " tragen = getMaxWeight()")
        local namen = {}
        for id, grund in pairs(fehlt) do namen[#namen + 1] = id .. " (" .. grund .. ")" end
        table.sort(namen)
        write("# nicht lesbar: " .. ((#namen > 0) and table.concat(namen, "; ") or "keine"))
        write("")
        write("[abweichungen] fall|achse=stufe|groesse|ohne Trait->mit Trait")
        for _, line in ipairs(abweichungen) do write(line) end
        write("")
        write("[klettern] fall|fitness|strength|nimble|sicherheit|seil_hoch|seil_runter|tragen")
        for _, line in ipairs(zeilen) do write(line) end
        writer:close()
    end)
    if okWrite then
        log("Kletterlauf geschrieben: Zomboid/Lua/" .. TFMeasure.KLETTERFILE)
        halo(player, "Kletterlauf geschrieben: " .. TFMeasure.KLETTERFILE, true)
    else
        log("Kletterlauf nicht geschrieben: " .. tostring(errWrite))
    end
    return { faelle = #cfg.faelle, abweichungen = #abweichungen, geschrieben = okWrite }
end

--- ---------------------------------------------------------------------------
--- Das Messfenster (F8, seit 6.18.0)
--- ---------------------------------------------------------------------------
--
-- F8 oeffnet ein Fenster mit allen Tests: links die offenen, darunter die
-- erledigten; rechts der gewaehlte mit Zweck, Schritten, Start und
-- Abbrechen, Live-Werten, Stand und Ergebnis; unten die vier Schalter der
-- Testfigur. Jeder Test ist ein Eintrag in TFMeasure.TESTS, das Fenster baut
-- sich daraus. Entwurf: docs/mockups/messfenster-2026-09-12.html, Variante A.
--
-- Die Texte stehen in media/lua/shared/Translate/EN/UI.json dieses Mods, auf
-- Deutsch und mit echten Umlauten; der Lua-Code bleibt ASCII. EN, weil jede
-- Spielsprache auf EN zurueckfaellt, wenn ihr ein Schluessel fehlt. Neue
-- Texte brauchen einen Programmstart: F9 laedt nur Lua.
--
-- Der Stand der Tests steht in Zomboid/Lua/TraitFacts_tests.txt und
-- ueberlebt so Neustarts und Spielstaende.

--- Die Texte des Mess-Mods, bei jedem Laden frisch aus der eigenen UI.json
-- (seit 6.23.4). Das Spiel liest Uebersetzungen nur beim Programmstart; jede
-- Textaenderung kostete deshalb einen Neustart, F9 reichte nur fuer Lua.
-- getModFileReader sucht im Versionsordner (42/), dann im gemeinsamen, und
-- liest UTF-8 (LuaManager.GlobalObject); die Umlaute kommen also an. Die
-- Datei ist ein flaches JSON, ein Eintrag je Zeile, ohne Escapes.
TFMeasure.TEXTDATEI = "media/lua/shared/Translate/EN/UI.json"
function TFMeasure.texteLaden()
    local texte, anzahl = {}, 0
    -- Ohne die Funktion (Testgeruest) still bei getText bleiben.
    if getModFileReader == nil then
        TFMeasure.texte = nil
        return 0
    end
    local ok, err = pcall(function()
        local reader = getModFileReader("TraitFactsMeasure", TFMeasure.TEXTDATEI, false)
        if not reader then return end
        while true do
            local zeile = reader:readLine()
            if zeile == nil then break end
            local _, _, key, wert = string.find(zeile, '^%s*"(UI_TFM_[^"]+)"%s*:%s*"(.*)"%s*,?%s*$')
            if key then
                texte[key] = wert
                anzahl = anzahl + 1
            end
        end
        reader:close()
    end)
    if not ok then log("Texte nicht aus der UI.json gelesen: " .. tostring(err)) end
    TFMeasure.texte = (anzahl > 0) and texte or nil
    return anzahl
end

--- Text aus der Uebersetzung des Mess-Mods. Argumente nur als Zeichenketten.
-- Wie getText: %1 bis %4 ersetzen, dann %% zu einem %. Ohne frisch gelesene
-- Texte (Testgeruest, Datei fehlt) bleibt es bei getText.
local function T(key, ...)
    local text = TFMeasure.texte and TFMeasure.texte["UI_TFM_" .. key]
    if not text then return getText("UI_TFM_" .. key, ...) end
    local args = { ... }
    for i = 1, 4 do
        if args[i] ~= nil then
            local ersatz = string.gsub(tostring(args[i]), "%%", "%%%%")
            text = string.gsub(text, "%%" .. i, ersatz)
        end
    end
    return (string.gsub(text, "%%%%", "%%"))
end
TFMeasure.text = T

--- Zahl mit Dezimalkomma; "-" ohne Wert.
local function komma(wert, stellen)
    if type(wert) ~= "number" then return "-" end
    local text = string.format("%." .. tostring(stellen) .. "f", wert)
    return (string.gsub(text, "%.", ","))
end

--- Zerlegt an einem Zeichen, ohne Muster (string.gmatch fehlt in Kahlua).
local function teile(text, zeichen)
    local out, pos = {}, 1
    while true do
        local fund = string.find(text, zeichen, pos, true)
        if not fund then
            out[#out + 1] = string.sub(text, pos)
            return out
        end
        out[#out + 1] = string.sub(text, pos, fund - 1)
        pos = fund + 1
    end
end

local function heute()
    local ok, datum = pcall(function() return os.date("%d.%m.%Y") end)
    if ok and type(datum) == "string" then return datum end
    return "?"
end

--- Die Uhr in Millisekunden. Ticks sind Bilder, und die Bildrate schwankt.
local function uhr()
    local t = nil
    if type(getTimestampMs) == "function" then
        t = getTimestampMs()
    else
        pcall(function() t = getTimestampMs() end)
    end
    if type(t) == "number" then return t end
    return nil
end

TFMeasure.STATUSFILE = "TraitFacts_tests.txt"

local function testNamed(id)
    for _, test in ipairs(TFMeasure.TESTS or {}) do
        if test.id == id then return test end
    end
    return nil
end

--- Stand eines Tests: aus der Datei, sonst das Datum, an dem er vor dem
-- Fenster gemessen wurde, sonst nil (offen).
--- true, wenn Fassung a aelter ist als b ("6.22.0" gegen "6.23.3").
function TFMeasure.fassungAelter(a, b)
    local ta, tb = teile(tostring(a), "."), teile(tostring(b), ".")
    for i = 1, math.max(#ta, #tb) do
        local x, y = tonumber(ta[i]) or 0, tonumber(tb[i]) or 0
        if x ~= y then return x < y end
    end
    return false
end

--- Der Stand eines Tests, nil heisst offen. Ein Test mit `seit` gilt erst mit
-- einem Ergebnis aus dieser Fassung des Mess-Mods oder einer neueren als
-- erledigt; ein aelteres stammt aus einer anderen Messung. Seit 6.23.4: der
-- umgebaute Schlaf-Test stand weiter unter Erledigt, weil der Stand nur Datum
-- und Ergebnis kannte. Ergebnisse ohne Fassung zaehlen bei `seit` nicht.
local function standVon(test)
    local eintrag = TFMeasure.stand and TFMeasure.stand[test.id]
    if eintrag then
        local fassung = eintrag.werte and eintrag.werte.fassung
        if test.seit and (not fassung or TFMeasure.fassungAelter(fassung, test.seit)) then return nil end
        return eintrag
    end
    if test.erledigt then return { datum = test.erledigt, werte = {} } end
    return nil
end

--- Liest den Stand aller Tests aus STATUSFILE.
--
-- Eine Zeile je Test: id|erledigt|datum|schluessel=wert|... Werte statt
-- fertiger Saetze: den Satz baut die Uebersetzung, und in der Datei stehen
-- so keine Umlaute, die an der Kodierung haengen. Zeilen fremder Tests
-- bleiben stehen, damit eine aeltere Fassung des Mods die Ergebnisse einer
-- neueren nicht wegwirft.
function TFMeasure.statusLesen()
    local stand, fremd, bekannt = {}, {}, {}
    for _, test in ipairs(TFMeasure.TESTS or {}) do bekannt[test.id] = true end
    local ok, err = pcall(function()
        local reader = getFileReader(TFMeasure.STATUSFILE, false)
        if not reader then return end
        while true do
            local zeile = reader:readLine()
            if zeile == nil then break end
            if zeile ~= "" and string.sub(zeile, 1, 1) ~= "#" then
                local felder = teile(zeile, "|")
                local id = felder[1]
                if not bekannt[id] then
                    fremd[#fremd + 1] = zeile
                elseif felder[2] == "erledigt" then
                    local werte = {}
                    for index = 4, #felder do
                        local gleich = string.find(felder[index], "=", 1, true)
                        if gleich then
                            local roh = string.sub(felder[index], gleich + 1)
                            werte[string.sub(felder[index], 1, gleich - 1)] = tonumber(roh) or roh
                        end
                    end
                    stand[id] = { datum = felder[3] or "?", werte = werte }
                end
            end
        end
        reader:close()
    end)
    if not ok then log("Stand der Tests nicht gelesen: " .. tostring(err)) end
    TFMeasure.stand, TFMeasure.standFremd = stand, fremd
    return stand
end

function TFMeasure.statusSchreiben()
    local stand = TFMeasure.stand or {}
    local ok, err = pcall(function()
        local writer = getFileWriter(TFMeasure.STATUSFILE, true, false)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        writer:write("# Trait Facts Measure: Stand der Tests (Mess-Mod " .. TFMeasure.VERSION .. ")" .. nl)
        writer:write("# id|erledigt|datum|schluessel=wert|..." .. nl)
        for _, test in ipairs(TFMeasure.TESTS) do
            local eintrag = stand[test.id]
            if eintrag then
                local namen = {}
                for name in pairs(eintrag.werte or {}) do namen[#namen + 1] = name end
                table.sort(namen)
                local felder = { test.id, "erledigt", eintrag.datum or "?" }
                for _, name in ipairs(namen) do
                    local wert = eintrag.werte[name]
                    if type(wert) == "number" then
                        if wert == math.floor(wert) then
                            wert = tostring(math.floor(wert))
                        else
                            wert = string.format("%.4f", wert)
                        end
                    end
                    felder[#felder + 1] = name .. "=" .. tostring(wert)
                end
                writer:write(table.concat(felder, "|") .. nl)
            end
        end
        for _, zeile in ipairs(TFMeasure.standFremd or {}) do writer:write(zeile .. nl) end
        writer:close()
    end)
    if not ok then log("Stand der Tests nicht geschrieben: " .. tostring(err)) end
end

--- Traegt einen Test mit heutigem Datum und seinen Werten als erledigt ein.
function TFMeasure.erledigen(id, werte)
    if not TFMeasure.stand then TFMeasure.statusLesen() end
    werte = werte or {}
    -- Mit welcher Fassung gemessen wurde; standVon vergleicht sie mit `seit`.
    werte.fassung = TFMeasure.VERSION
    -- Wann, fuer die Reihenfolge im Messfenster (seit 6.26.4): Minuten seit
    -- 1.1.2026 00:00 UTC, eine kleine ganze Zahl, die statusSchreiben ohne
    -- Exponent schreibt. Ohne Uhr (oder mit einer, die davor steht) bleibt
    -- es beim Datum.
    if type(getTimestampMs) == "function" then
        local ms = getTimestampMs()
        if type(ms) == "number" and ms > 1767225600000 then
            werte.zeit = math.floor(ms / 60000) - 29453760
        end
    end
    TFMeasure.stand[id] = { datum = heute(), werte = werte }
    TFMeasure.statusSchreiben()
end

--- ---------------------------------------------------------------------------
--- Der Axt-Test (seit 6.18.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- Drei Aussagen zu Ax-pert, alle aus dem Code von 42.20.4:
--   Faelltempo  Die Faell-Animation laeuft mit ChopTreeSpeed (chop_tree.xml,
--               m_SpeedScale), und getChopTreeSpeed() ist 1.0 mit Ax-pert,
--               0.8 ohne (IsoGameCharacter:12388).
--   Baumschaden IsoTree.WeaponHit:219-222 rechnet den Baumschaden der Axt mit
--               Ax-pert x1.5, danach als (int) aufs Baumleben.
--   Schwung     calculateCombatSpeed (IsoGameCharacter:8836) multipliziert bei
--               Aexten mit getChopTreeSpeed(), und CombatManager.pressedAttack
--               (:2660) setzt daraus CombatSpeed, das Tempo der
--               Schwung-Animation (2HDefault.xml, m_SpeedScale). Die Mod fuehrt
--               die Axt-Schwungzeit bisher als wirkungslos, weil
--               HandWeapon.getSpeedMod (x0.95) keinen Aufrufer hat. Nach dieser
--               Lesung schwingt aber jede Axt ohne Ax-pert mit 0.8.
--
-- Ablauf: den naechsten Baum suchen, eine Axt ins Inventar, Vanillas
-- doChopTree (ruestet aus, laeuft hin, faellt). Das Baumleben steht vor jedem
-- Treffer auf baumLeben, damit der Baum nicht faellt und jeder Treffer als
-- Differenz lesbar ist; am Ende bekommt er sein Leben zurueck. Danach
-- Schlaege in die Luft ueber AttemptAttack, vom Baum weggedreht; die Zeiten
-- kommen aus OnWeaponSwing und OnPlayerAttackFinished.
--
-- Faelltempo, Stand 6.43.0 (Faktensweep 23.09.2026): 6.18.0 und 6.19.0 massen
-- 1250 ms je Hieb mit und ohne Ax-pert (docs/messungen/messung-2026-09-13-axt.txt,
-- -13b-axt.txt), und die Mod fuehrte das Faelltempo darauf als wirkungslos.
-- Das Ergebnis taugt nicht: die Engine liest m_SpeedScale nur, wenn der
-- Animationsknoten startet (AnimLayer.startLiveNodeTracks), und ein Knoten,
-- der noch laeuft, wird wiederverwendet. 6.19.0 beendete die Aktion und
-- startete die naechste im selben Tick; chop_tree blieb dabei aktiv und
-- behielt das Tempo der ersten Phase, und die lief immer ohne Ax-pert:
-- 1.0 s / 0.8 = 1250 ms. Darum jetzt:
--   * Phase 1 MIT Ax-pert, danach im Wechsel. Laeuft die erste Phase mit
--     1000 ms, ist die Wirkung belegt, egal was danach kommt.
--   * Zwischen zwei Phasen eine Pause: Aktion beenden, warten, bis
--     PerformingAction nicht mehr "chop_tree" ist (Bedingung des Knotens in
--     AnimSets/player/actions/chop_tree.xml), dann noch pauseTicks stehen
--     (Ueberblenden 0.4 s), erst dann Trait setzen und neu anfangen.
--   * Das Protokoll fuehrt je Phase den Getter und ob die Animation vor dem
--     Neustart wirklich aus war.
-- Der erste Hieb einer Phase ist Anlauf (Ausholen, Einblenden), gemessen wird
-- der Abstand der folgenden.
--
-- Beim Schlag steht das Tempo ebenfalls mit dem Start fest (pressedAttack);
-- dort genuegt das Umschalten zwischen zwei Schlaegen, und der Takt eines
-- Schlags ist die Zeit bis zum naechsten Start. Ax-pert wechselt alle
-- jePhase Schlaege; Schlag 0 ist Warmlauf.
--
-- Der Baumschaden der Axt sinkt mit ihrer Schaerfe (HandWeapon.getTreeDamage
-- = treeDamage x getSharpnessMultiplier), am 13.09.2026 von 35 auf 33 nach
-- zehn Hieben. Der Bericht fuehrt ihn je Hieb mit, und der Wechsel der Phasen
-- verteilt das Stumpfwerden auf beide Seiten.
--
-- Ein Schlag aus Lua ist nicht sicher: pressedAttack verlangt eine bereite
-- Waffe und keine laufende Aktion. Kommt nach schlagStartTicks kein Schlag,
-- bittet das Fenster, die Angriffstaste zu halten; gezaehlt wird, was kommt.
TFMeasure.AXTFILE = "TraitFacts_axt.txt"
TFMeasure.AXT = {
    radius = 15,
    axt = "Base.Axe",
    skill = 3,
    -- Faellen: acht Phasen im Wechsel ohne/mit, je Phase eine neue Aktion
    -- mit einem Anlauf-Hieb und zwei gemessenen Abstaenden.
    phasen = 8,
    hiebeJePhase = 3,
    -- Pause zwischen zwei Faell-Phasen, damit chop_tree sicher neu startet.
    pauseTicks = 60 * 2,
    pauseMaxTicks = 60 * 15,
    schlaege = 20,
    jePhase = 2,
    baumLeben = 5000,
    ersterTrefferTicks = 60 * 60,
    trefferTicks = 60 * 15,
    schlagStartTicks = 60 * 3,
    schlagTicks = 60 * 120,
}

local function hatTrait(player, key)
    local liste = player:getCharacterTraits():getKnownTraits()
    if not liste then return false end
    for index = 0, liste:size() - 1 do
        if keyOf(liste:get(index)) == key then return true end
    end
    return false
end

--- getChopTreeSpeed() im Moment des Phasenstarts, fuers Protokoll.
local function chopTempo(player)
    local wert
    pcall(function() wert = player:getChopTreeSpeed() end)
    return wert
end

--- Laeuft der Faell-Knoten noch? Seine Bedingung ist PerformingAction = chop_tree.
local function animLaeuft(player)
    local wert
    pcall(function() wert = player:getVariableString("PerformingAction") end)
    return wert == "chop_tree"
end

local function axemanSetzen(player, z, an)
    local container = player:getCharacterTraits()
    if an then container:add(z.typ) else container:remove(z.typ) end
    z.mit = an
end

--- Traegt Nummer k (ab 1) Ax-pert? Paare im Wechsel: ohne, ohne, mit, mit ...
local function phaseMit(nummer)
    return (math.floor((nummer - 1) / TFMeasure.AXT.jePhase) % 2) == 1
end

local function stufeSetzen(player, perk, stufe)
    player:setPerkLevelDebug(perk, stufe)
    pcall(function() player:getXp():setXPToLevel(perk, stufe) end)
end
TFMeasure.stufeSetzen = stufeSetzen

local function mittelwert(liste, feld, mit, bis)
    local summe, anzahl = 0, 0
    for _, e in ipairs(liste) do
        if e.nr >= 1 and e.nr <= bis and e.mit == mit and type(e[feld]) == "number" then
            summe = summe + e[feld]
            anzahl = anzahl + 1
        end
    end
    if anzahl == 0 then return nil, 0 end
    return summe / anzahl, anzahl
end

local function verhaeltnis(mit, ohne)
    if mit and ohne and ohne ~= 0 then return mit / ohne end
    return nil
end

local function axtAuswertung(z)
    local cfg, a = TFMeasure.AXT, {}
    a.abstandOhne, a.nAbstandOhne = mittelwert(z.hiebe, "abstandMs", false, cfg.hiebeJePhase)
    a.abstandMit, a.nAbstandMit = mittelwert(z.hiebe, "abstandMs", true, cfg.hiebeJePhase)
    a.schadenOhne = mittelwert(z.hiebe, "schaden", false, cfg.hiebeJePhase)
    a.schadenMit = mittelwert(z.hiebe, "schaden", true, cfg.hiebeJePhase)
    a.taktOhne, a.nTaktOhne = mittelwert(z.schlaege, "taktMs", false, cfg.schlaege)
    a.taktMit, a.nTaktMit = mittelwert(z.schlaege, "taktMs", true, cfg.schlaege)
    a.dauerOhne = mittelwert(z.schlaege, "dauerMs", false, cfg.schlaege)
    a.dauerMit = mittelwert(z.schlaege, "dauerMs", true, cfg.schlaege)
    a.abstand = verhaeltnis(a.abstandMit, a.abstandOhne)
    a.schaden = verhaeltnis(a.schadenMit, a.schadenOhne)
    a.schwung = verhaeltnis(a.taktMit, a.taktOhne)
    a.dauer = verhaeltnis(a.dauerMit, a.dauerOhne)
    return a
end

--- Schreibt den Stand des Axt-Tests in TFMeasure.lauf, das Fenster liest ihn.
local function axtLive(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "axt" then return end
    local cfg = TFMeasure.AXT
    local a = axtAuswertung(z)
    local phase = z.mit and T("mit") or T("ohne")
    local function sekunden(ms) return ms and komma(ms / 1000, 2) or "-" end
    if z.phase == "faellen" or z.phase == "pause" then
        local gesamt = cfg.phasen * cfg.hiebeJePhase
        local n = #z.hiebe
        lauf.fortschritt = 0.6 * n / gesamt
        lauf.live = {
            { T("axt_live_treffer"), T("paar", tostring(n), tostring(gesamt)) },
            { T("axt_live_abstand"), T("paar_s", sekunden(a.abstandOhne), sekunden(a.abstandMit)) },
            { T("axt_live_schaden"), T("paar", komma(a.schadenOhne, 0), komma(a.schadenMit, 0)) },
        }
        if z.phase == "pause" then
            lauf.status = T("axt_status_pause", tostring(z.phaseNr + 1), tostring(cfg.phasen))
        elseif #z.hiebe > 0 then
            lauf.status = T("axt_status_faellen", tostring(n), tostring(gesamt), phase)
        end
    else
        local n = math.min(math.max(#z.schlaege - 1, 0), cfg.schlaege)
        lauf.fortschritt = 0.6 + 0.4 * n / cfg.schlaege
        lauf.live = {
            { T("axt_live_schlaege"), T("paar", tostring(n), tostring(cfg.schlaege)) },
            { T("axt_live_takt"), T("paar_s", sekunden(a.taktOhne), sekunden(a.taktMit)) },
            { T("axt_live_dauer"), T("paar_s", sekunden(a.dauerOhne), sekunden(a.dauerMit)) },
        }
        lauf.status = z.hinweis or T("axt_status_schwingen", tostring(n), tostring(cfg.schlaege), phase)
    end
end

--- Alles zurueck: Faellen beendet, Ax-pert wie vorher, Axt-Skill, Baumleben.
local function axtAufraeumen(player, z)
    if player then
        pcall(function() ISTimedActionQueue.clear(player) end)
        pcall(function() axemanSetzen(player, z, z.axeman0) end)
        if Perks and Perks.Axe and z.stufe0 then
            pcall(function() stufeSetzen(player, Perks.Axe, z.stufe0) end)
        end
    end
    pcall(function() z.baum:setHealth(z.leben0) end)
    TFMeasure.axtZustand = nil
end

local function axtZumSchlagen(player, z)
    ISTimedActionQueue.clear(player)
    pcall(function() z.baum:setHealth(z.leben0) end)
    z.phase = "schwingen"
    z.wartenSeit = z.tick
    axemanSetzen(player, z, false)
    -- Vom Baum weg: ein Schlag in seine Richtung traefe ihn, und das waere
    -- kein Schlag in die Luft mehr.
    local px, py = player:getX(), player:getY()
    local bx, by = z.baum:getX(), z.baum:getY()
    pcall(function() player:faceLocation(px + (px - bx), py + (py - by)) end)
    TFMeasure.lauf.erledigt = 4
end

local function axtFertig(player, z)
    local cfg = TFMeasure.AXT
    local a = axtAuswertung(z)
    local function ms(x) return x and string.format("%.1f", x) or "-" end
    local function f2(x) return x and string.format("%.2f", x) or "-" end
    local function f4(x) return x and string.format("%.4f", x) or "-" end
    local function ganz(x) return (type(x) == "number") and tostring(math.floor(x + 0.5)) or "-" end
    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.AXTFILE, true, false)
        local nl = (lineSeparator and lineSeparator()) or "\r\n"
        local function write(line) writer:write(line .. nl) end
        write("# Axt: Ax-pert, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        local version = "unbekannt"
        pcall(function() version = tostring(getCore():getVersionNumber()) end)
        write("# Build " .. version)
        write(string.format("# Axt %s (Baumschaden %s), Axt-Skill fest auf %d, Baumleben vor jedem Treffer auf %d",
            tostring(z.axtName or "?"), f2(z.axtSchaden), cfg.skill, cfg.baumLeben))
        write(string.format("# Faellen: %d Phasen im Wechsel mit/ohne (Phase 1 mit), je eine neue Aktion mit %d Hieben; "
            .. "der erste ist Anlauf", cfg.phasen, cfg.hiebeJePhase))
        write(string.format("# zwischen den Phasen Pause, bis PerformingAction nicht mehr chop_tree ist, dann %d Ticks; "
            .. "der Trait wird erst danach gesetzt", cfg.pauseTicks))
        write(string.format("# Schlaege: Ax-pert wechselt alle %d, Schlag 0 ist Warmlauf", cfg.jePhase))
        write("# erwartet laut Code: abstand 0.8, mit 1000 ms, ohne 1250 ms (ChopTreeSpeed 1.0 statt 0.8);")
        write("#   13.09.2026 gemessen 1.00, aber mit Neustart im selben Tick (Animation lief weiter),")
        write("#   schaden 1.5 vor dem (int),")
        write("#   schwung 0.8, wenn calculateCombatSpeed die Axt ohne Ax-pert mit 0.8 rechnet; 1.0 hiesse wirkungslos")
        if z.ohneLuaSchlag then write("# AttemptAttack fehlt; gezaehlt wurden Schlaege von der Taste") end
        write("")
        write("[ergebnis]")
        write(string.format("faellen|abstand|ohne_ms=%s|mit_ms=%s|mit/ohne=%s|abstaende=%d/%d",
            ms(a.abstandOhne), ms(a.abstandMit), f4(a.abstand), a.nAbstandOhne, a.nAbstandMit))
        write(string.format("faellen|schaden|ohne=%s|mit=%s|mit/ohne=%s",
            f2(a.schadenOhne), f2(a.schadenMit), f4(a.schaden)))
        write(string.format("schwung|takt|ohne_ms=%s|mit_ms=%s|mit/ohne=%s|schlaege=%d/%d",
            ms(a.taktOhne), ms(a.taktMit), f4(a.schwung), a.nTaktOhne, a.nTaktMit))
        write(string.format("schwung|dauer|ohne_ms=%s|mit_ms=%s|mit/ohne=%s",
            ms(a.dauerOhne), ms(a.dauerMit), f4(a.dauer)))
        write("")
        write("[phasen] phase|axeman|chopTreeSpeed|anim_war_aus|pause_ticks")
        for nr, ph in ipairs(z.phasen) do
            write(string.format("phase|%d|%d|%s|%d|%d", nr, ph.mit and 1 or 0, f2(ph.getter),
                ph.animAus and 1 or 0, ph.pauseTicks or 0))
        end
        write("")
        write("[hiebe] phase|nr|axeman|schaden|abstand_ms|abstand_ticks|baumschaden_axt")
        for _, h in ipairs(z.hiebe) do
            write(string.format("hieb|%d|%d|%d|%s|%s|%s|%s", h.phase, h.nr, h.mit and 1 or 0,
                ganz(h.schaden), ganz(h.abstandMs), ganz(h.abstandTicks), ganz(h.axt)))
        end
        write("")
        write("[schlaege] nr|axeman|takt_ms|dauer_ms")
        for _, s in ipairs(z.schlaege) do
            write(string.format("schlag|%d|%d|%s|%s", s.nr, s.mit and 1 or 0, ganz(s.taktMs), ganz(s.dauerMs)))
        end
        writer:close()
    end)
    axtAufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == "axt" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("axt", { abstand = a.abstand, schaden = a.schaden, schwung = a.schwung })
        log("Axt-Test geschrieben: Zomboid/Lua/" .. TFMeasure.AXTFILE)
        halo(player, T("axt_fertig", T("axt_ergebnis", komma(a.abstand, 2), komma(a.schaden, 2),
            komma(a.schwung, 2))), true)
    else
        log("Axt-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "axt", text = T("status_fehler", tostring(errWrite)) }
    end
end

--- Der naechste Baum im Umkreis, mit seinem Abstand in Feldern.
function TFMeasure.baumSuchen(player, radius)
    local cell = getCell()
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    local best, bestAbstand = nil, nil
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(px + dx, py + dy, pz)
            local baum = square and square:getTree()
            if baum then
                local abstand = math.sqrt(dx * dx + dy * dy)
                if not bestAbstand or abstand < bestAbstand then best, bestAbstand = baum, abstand end
            end
        end
    end
    return best, bestAbstand
end

function TFMeasure.axtStarten(player)
    local cfg = TFMeasure.AXT
    local baum, abstand = TFMeasure.baumSuchen(player, cfg.radius)
    if not baum then
        TFMeasure.meldung = { id = "axt", text = T("axt_keinbaum", tostring(cfg.radius)) }
        return
    end
    local typ = traitTypeNamed("axeman")
    if not typ then
        TFMeasure.meldung = { id = "axt", text = T("axt_keintrait") }
        return
    end
    local z = { baum = baum, leben0 = baum:getHealth(), typ = typ, axeman0 = hatTrait(player, "axeman"),
                phase = "faellen", phaseNr = 1, hiebInPhase = 0,
                hiebe = {}, schlaege = {}, phasen = {}, tick = 0, wartenSeit = 0 }
    if Perks and Perks.Axe then
        z.stufe0 = player:getPerkLevel(Perks.Axe)
        stufeSetzen(player, Perks.Axe, cfg.skill)
    end
    local hand, hatAxt = player:getPrimaryHandItem(), false
    if hand and ItemTag and ItemTag.CHOP_TREE then
        pcall(function() hatAxt = hand:hasTag(ItemTag.CHOP_TREE) end)
    end
    if not hatAxt then player:getInventory():AddItem(cfg.axt) end
    -- Phase 1 mit Ax-pert, gesetzt bevor die Aktion startet (seit 6.43.0).
    axemanSetzen(player, z, true)
    z.phasen[1] = { mit = true, getter = chopTempo(player), animAus = not animLaeuft(player), pauseTicks = 0 }
    baum:setHealth(cfg.baumLeben)
    TFMeasure.axtZustand = z
    TFMeasure.lauf = { id = "axt", erledigt = 0, fortschritt = 0,
                       status = T("axt_status_laufen", komma(abstand, 0)) }
    ISWorldObjectContextMenu.doChopTree(player, baum)
    axtLive(z)
end

function TFMeasure.axtTick()
    local z, lauf = TFMeasure.axtZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "axt" then
        TFMeasure.axtAbbrechen(T("axt_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    local cfg = TFMeasure.AXT
    z.tick = z.tick + 1
    if z.phase == "faellen" then
        local leben = z.baum:getHealth()
        if leben < cfg.baumLeben then
            local jetzt, vorher = uhr(), z.hiebe[#z.hiebe]
            z.hiebInPhase = z.hiebInPhase + 1
            local hieb = { phase = z.phaseNr, nr = z.hiebInPhase, mit = z.mit,
                           schaden = cfg.baumLeben - leben, ms = jetzt, tick = z.tick }
            -- Abstand nur innerhalb einer Aktion: vor dem ersten Hieb einer
            -- Phase liegen Aufhoeren, Neuanfang und Ausholen.
            if vorher and z.hiebInPhase >= 2 then
                hieb.abstandTicks = z.tick - vorher.tick
                if jetzt and vorher.ms then hieb.abstandMs = jetzt - vorher.ms end
            end
            pcall(function()
                local axt = player:getPrimaryHandItem()
                hieb.axt = axt:getTreeDamage()
                if not z.axtName then z.axtName, z.axtSchaden = axt:getFullType(), hieb.axt end
            end)
            z.hiebe[#z.hiebe + 1] = hieb
            z.baum:setHealth(cfg.baumLeben)
            z.wartenSeit = z.tick
            if Perks and Perks.Axe then stufeSetzen(player, Perks.Axe, cfg.skill) end
            lauf.erledigt = 2
            if z.hiebInPhase >= cfg.hiebeJePhase then
                if z.phaseNr >= cfg.phasen then
                    axtZumSchlagen(player, z)
                else
                    -- Neue Phase erst nach einer Pause, siehe Kopf des Abschnitts.
                    ISTimedActionQueue.clear(player)
                    z.phase, z.pauseSeit, z.animAusSeit = "pause", z.tick, nil
                end
            end
        else
            local grenze = (#z.hiebe == 0) and cfg.ersterTrefferTicks or cfg.trefferTicks
            if z.tick - z.wartenSeit > grenze then
                TFMeasure.axtAbbrechen(T("axt_keintreffer"))
                return
            end
        end
    elseif z.phase == "pause" then
        -- Ein spaeter Treffer nach dem Beenden zaehlt nicht.
        if z.baum:getHealth() < cfg.baumLeben then z.baum:setHealth(cfg.baumLeben) end
        if animLaeuft(player) then
            z.animAusSeit = nil
        else
            z.animAusSeit = z.animAusSeit or z.tick
        end
        local ruhig = z.animAusSeit and (z.tick - z.animAusSeit >= cfg.pauseTicks)
        local zuLang = z.tick - z.pauseSeit > cfg.pauseMaxTicks
        if ruhig or zuLang then
            -- Ungerade Phasen mit Ax-pert, gerade ohne.
            z.phaseNr, z.hiebInPhase = z.phaseNr + 1, 0
            axemanSetzen(player, z, z.phaseNr % 2 == 1)
            z.phasen[z.phaseNr] = { mit = z.mit, getter = chopTempo(player), animAus = ruhig and true or false,
                                    pauseTicks = z.tick - z.pauseSeit }
            z.phase, z.wartenSeit = "faellen", z.tick
            ISWorldObjectContextMenu.doChopTree(player, z.baum)
        end
    elseif z.phase == "schwingen" then
        -- Der Schlag nach dem letzten gemessenen schliesst dessen Takt.
        if #z.schlaege - 1 > cfg.schlaege or z.tick - z.wartenSeit > cfg.schlagTicks then
            axtFertig(player, z)
            return
        end
        if not z.ohneLuaSchlag then
            local ok = pcall(function() player:AttemptAttack() end)
            if not ok then z.ohneLuaSchlag = true end
        end
        if #z.schlaege == 0 and z.tick - z.wartenSeit > cfg.schlagStartTicks then
            z.hinweis = T("axt_hinweis_taste")
        end
    end
    axtLive(z)
end

--- OnWeaponSwing: ein Schlag beginnt. Sein Tempo steht jetzt fest, also
-- gilt ab hier der Trait fuer den naechsten.
function TFMeasure.schlagBeginn(wer, waffe)
    local z = TFMeasure.axtZustand
    local player = getSpecificPlayer(0)
    if not z or z.phase ~= "schwingen" or wer ~= player then return end
    local jetzt, vorher = uhr(), z.schlaege[#z.schlaege]
    if vorher and jetzt and vorher.ms then vorher.taktMs = jetzt - vorher.ms end
    z.schlaege[#z.schlaege + 1] = { nr = #z.schlaege, mit = z.mit, ms = jetzt }
    z.hinweis = nil
    z.wartenSeit = z.tick
    axemanSetzen(player, z, phaseMit(#z.schlaege))
end

--- OnPlayerAttackFinished: der laufende Schlag ist durch.
function TFMeasure.schlagEnde(wer, waffe)
    local z = TFMeasure.axtZustand
    if not z or z.phase ~= "schwingen" or wer ~= getSpecificPlayer(0) then return end
    local schlag, jetzt = z.schlaege[#z.schlaege], uhr()
    if schlag and not schlag.dauerMs and jetzt and schlag.ms then schlag.dauerMs = jetzt - schlag.ms end
end

--- Beendet den Axt-Test ohne Ergebnis und raeumt auf.
function TFMeasure.axtAbbrechen(grund)
    local z = TFMeasure.axtZustand
    if z then axtAufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == "axt" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "axt", text = grund or T("axt_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Adrenalin: Gehtempo bei Panik (Paket D, Spielfehler adrenaline-movespeed)
--- ---------------------------------------------------------------------------
--
-- Zwei Stellen in 42.20 heben das Tempo mit Adrenaline Junkie:
--   IsoGameCharacter.calculateBaseSpeed (Z. 8754-8764): 0.8, ab Panikstufe 3
--     plus (Stufe + 1) / 20, auf Stufe 4 also 1.05. calculateWalkSpeed
--     (Z. 8957-9005) deckelt das Gehtempo bei 1.0 (Z. 8985) und setzt es als
--     Animationsvariable WalkSpeed (Z. 9004): 1.0 gegen 0.8, x1.25.
--   IsoPlayer.getMoveSpeed (Z. 1633-1668): ab Panikstufe 4 x(1 + (Stufe+1)/50),
--     auf Stufe 4 x1.1. Gelesen nur von IsoPlayer.getPathSpeed (Z. 1024-1025),
--     und das ruft keine Klasse der Engine und keine Vanilla-Lua auf. Laut
--     Code wirkt die x1.1 also nicht.
-- Den Unterschied zeigt nur die Strecke: du gehst, das Mod haelt die Panik in
-- jedem Tick auf 90 (Stufe 4) und schaltet Adrenaline Junkie phasenweise. Je
-- gezaehltem Tick die Strecke seit dem letzten, der Multiplier, WalkSpeed und
-- getMoveSpeed. zusatz = Faktor der Strecke / Faktor von WalkSpeed ist laut
-- Code 1.0; 1.1 hiesse, die x1.1 aus getMoveSpeed wirkt doch. Weil zusatz
-- gegen die eigene Variable des Spiels rechnet, kuerzen sich Schuhe, Waerme
-- und Verletzungen dort heraus; walkspeed und tempo gelten nur mit Schuhen.
--
-- God Mode muss aus sein: RestoreToFullHealth setzt die Panik je Bild auf 0
-- (siehe Panik-Test), das Heilen des Mess-Mods pausiert (godPause).
-- Desensitized setzt sie in jedem Update auf 0 (BodyDamage.UpdatePanicState
-- Z. 430-432) und ist fuer die Dauer weg. Die Ausdauer steht je Tick auf 1:
-- die Stufe ENDURANCE zoege 0.15 je Stufe vom Grundtempo ab (Z. 8758), die
-- Last (HEAVY_LOAD, Z. 8759) ebenso; mit Last zaehlt kein Tick.
--
-- Dieser Abschnitt steht vor nl, buildNummer, statSetzen und SZ; was er davon
-- braucht, hat er in AD selbst.
local AD = {}
TFMeasure.ADRENALINFILE = "TraitFacts_adrenalin.txt"
TFMeasure.ADRENALIN = {
    phaseTicks = 300,   -- gezaehlte Ticks je Phase
    vorlauf = 15,       -- Ticks Gehen nach jedem Umschalten und jeder Pause, die nicht zaehlen
    panik = 90,         -- Stufe 4 ab 80 (Moodles)
    toleranz = 0.03,
    maxSchritt = 0.5,   -- mehr in einem Tick ist ein Sprung, kein Schritt
}
-- false = ohne, true = mit Adrenaline Junkie; jede Phase mit gegen ihre Nachbarn
TFMeasure.ADRENALIN_PLAN = { false, true, false, true, false, true, false, true, false }
TFMeasure.ADRENALIN_KURZ = { false, true, false, true, false }
-- Seit 6.33.0 drei Teile. Der Lauf vom 20.09.2026 mass beim Gehen auf Stufe 4
-- eine Strecke von nur x1.0813, wo WalkSpeed x1.25 zeigt; gefragt ist seitdem
-- der reale Wert, und der Code sagt mehr, als der Test bis dahin abdeckte:
-- der Zuschlag haengt an der Stufe ((Stufe + 1) / 20, also +0.20 auf Stufe 3
-- und +0.25 auf Stufe 4), und calculateWalkSpeed rechnet aus demselben
-- Grundtempo auch das Renntempo: (Grundtempo - 0.15) x fullSpeedMod +
-- Sprinting / 20, gedeckelt bei 1.0 (Z. 9179-9219); beim Rennen traegt die
-- Variable WalkSpeed das Renntempo. Teil 1 ist der Test wie bisher.
TFMeasure.ADRENALIN_TEILE = {
    { id = "gehen4", gang = "gehen", panik = 90, stufe = 4, plan = TFMeasure.ADRENALIN_PLAN },
    { id = "gehen3", gang = "gehen", panik = 70, stufe = 3, plan = TFMeasure.ADRENALIN_KURZ },
    { id = "rennen4", gang = "rennen", panik = 90, stufe = 4, plan = TFMeasure.ADRENALIN_KURZ },
    -- Seit 6.34.0: Sprinten mit Alt. calculateWalkSpeed setzt beim Rennen wie
    -- beim Sprinten dasselbe Renntempo in WalkSpeed (runOrSprint, Z. 9219);
    -- ob davon beim Sprint mehr oder weniger auf der Strecke ankommt als beim
    -- Rennen (x1.16 statt x1.35), sagt nur die Messung.
    { id = "sprint4", gang = "sprint", panik = 90, stufe = 4, plan = TFMeasure.ADRENALIN_KURZ },
    -- Seit 6.37.0: Rennen und Sprinten auch auf Stufe 3. Der Zuschlag greift
    -- ab Strong Panic, gemessen war er dort nur beim Gehen; im Spiel las sich
    -- "Walking at Strong, Running at Extreme" wie zwei verschiedene Regeln
    -- (Rueckfrage 20.09.2026). Laut Code +0.20 statt +0.25 aufs Grundtempo.
    { id = "rennen3", gang = "rennen", panik = 70, stufe = 3, plan = TFMeasure.ADRENALIN_KURZ },
    { id = "sprint3", gang = "sprint", panik = 70, stufe = 3, plan = TFMeasure.ADRENALIN_KURZ },
}
TFMeasure.ADRENALIN_WERTE = {
    { groesse = "walkspeed", code = 1.25, notiz = "Animationsvariable WalkSpeed, gedeckelt bei 1.0" },
    { groesse = "getmovespeed", code = 1.1, notiz = "IsoPlayer.getMoveSpeed; zeigt, dass Panikstufe 4 stand" },
    { groesse = "tempo", code = 1.25, effekt = "panicspeed",
      notiz = "Strecke je Multiplier: der reale Wert; laut Code x1.25 wie WalkSpeed" },
    -- Bis 6.33.0 tempo / walkspeed. Das setzte voraus, dass die Strecke dem
    -- Tempowert folgt; vier Laeufe am 20.09.2026 zeigten x1.08 gegen x1.25,
    -- die Zeile wich darum immer ab. Seitdem gegen den gemessenen Wert, den
    -- Trait Facts zeigt: 1.0 heisst, es ist bei den x1.08 geblieben.
    { groesse = "zusatz", code = 1.0,
      notiz = "tempo / Wert von Trait Facts (ohne Trait Facts / 1.08); Spielfehler adrenaline-movespeed:"
          .. " wirkte die x1.1 aus getMoveSpeed, waere es 1.1" },
}

--- Eine Ja/Nein-Frage an die Figur; fehlt die Methode, heisst es nein.
function AD.ja(frage)
    local ok, ja = pcall(frage)
    return ok and ja == true
end

function AD.stufe(player, typ)
    local ok, s = pcall(function() return player:getMoodles():getMoodleLevel(typ) end)
    return (ok and tonumber(s)) or 0
end

-- Seit 6.38.0 ein zweiter, kurzer Test aus denselben Bausteinen: nur Rennen und
-- Sprinten bei Strong Panic, je neun Phasen. Die beiden Werte stammten aus einem
-- einzigen Lauf mit zwei Phasenpaaren, und genau dort ruckelte das Spiel am
-- staerksten (Felder je Sekunde streuten um 19.8 %, der Messwert um 2.7 %).
-- Welche Teile laufen, unter welcher Kennung und in welche Datei, steht fuer
-- die Dauer des Laufs in AD.aktiv, AD.laufId und AD.datei.
TFMeasure.ADRENALIN_STRONGFILE = "TraitFacts_adrenalin_strong.txt"
TFMeasure.ADRENALIN_STRONG = {
    { id = "rennen3", gang = "rennen", panik = 70, stufe = 3, plan = TFMeasure.ADRENALIN_PLAN },
    { id = "sprint3", gang = "sprint", panik = 70, stufe = 3, plan = TFMeasure.ADRENALIN_PLAN },
}

function AD.teile() return AD.aktiv or TFMeasure.ADRENALIN_TEILE end
function AD.kennung() return AD.laufId or "adrenalin" end

--- Alle Phasen des Laufs hintereinander: { mit = boolean, teil = Teil }.
function AD.ablauf()
    local liste = {}
    for _, teil in ipairs(AD.teile()) do
        for _, mit in ipairs(teil.plan) do liste[#liste + 1] = { mit = mit, teil = teil } end
    end
    return liste
end

--- Warum der Tick nicht zaehlt, oder nil. `teil` sagt, welche Gangart und
-- welche Panikstufe gerade gemessen wird.
function AD.grund(player, teil)
    local ja = AD.ja
    teil = teil or AD.teile()[1]
    if not ja(function() return player:isPlayerMoving() end) then return "steht" end
    if teil.gang == "sprint" then
        if not ja(function() return player:isSprinting() end) then return "sprintnicht" end
    elseif teil.gang == "rennen" then
        if ja(function() return player:isSprinting() end) then return "sprintet" end
        if not ja(function() return player:isRunning() end) then return "gehtnur" end
    elseif ja(function() return player:isRunning() or player:isSprinting() end) then
        return "rennt"
    end
    if ja(function() return player:isSneaking() or player:isAiming() end) then return "anders" end
    if ja(function() return player:isInTrees() end) then return "anders" end
    if ja(function() return player:getVehicle() ~= nil end) then return "anders" end
    if AD.stufe(player, MoodleType.HEAVY_LOAD) > 0 then return "last" end
    if AD.stufe(player, MoodleType.PANIC) ~= teil.stufe then return "panik" end
    if AD.stufe(player, MoodleType.ENDURANCE) > 0 then return "ausdauer" end
    return nil
end

--- Rechnet die Bewegung seit dem letzten Tick der laufenden Phase zu; ihren
-- Trait und die Panik hat der letzte Tick gesetzt. Nach jeder Pause und jedem
-- Umschalten zaehlen erst die Ticks nach dem Anlauf.
function AD.zaehlen(player, z, grund)
    local cfg, ph = TFMeasure.ADRENALIN, z.phase
    local lx, ly, lms = z.lastX, z.lastY, z.lastMs
    z.lastX, z.lastY, z.lastMs = nil, nil, nil
    if grund or hatTrait(player, "adrenalinejunkie") ~= ph.mit then
        ph.vorlauf = 0
        if grund ~= "steht" then ph.aus = ph.aus + 1 end
        return
    end
    local x, y, jetzt = player:getX(), player:getY(), uhr()
    z.lastX, z.lastY, z.lastMs = x, y, jetzt
    if not lx then return end
    local dx, dy = x - lx, y - ly
    local d = math.sqrt(dx * dx + dy * dy)
    local m = getGameTime():getMultiplier()
    -- Ein Sprint legt je Tick mehr zurueck als Gehen; die Grenze fuer einen
    -- "Sprung" waechst darum mit dem Multiplier (bei 20 Bildern je Sekunde
    -- sind es sonst schon beim Sprinten ueber 0.5 Felder).
    if d > cfg.maxSchritt * math.max(1, m or 1) or type(m) ~= "number" or m <= 0 then
        ph.aus = ph.aus + 1
        return
    end
    if ph.vorlauf < cfg.vorlauf then
        ph.vorlauf = ph.vorlauf + 1
        return
    end
    ph.ticks = ph.ticks + 1
    ph.strecke, ph.mult = ph.strecke + d, ph.mult + m
    if jetzt and lms then ph.ms = ph.ms + (jetzt - lms) end
    local okW, ws = pcall(function() return player:getVariableFloat("WalkSpeed", 0) end)
    if okW and type(ws) == "number" then ph.ws, ph.wsN, z.wsJetzt = ph.ws + ws, ph.wsN + 1, ws end
    local okG, gm = pcall(function() return player:getMoveSpeed() end)
    if okG and type(gm) == "number" then ph.gm, ph.gmN = ph.gm + gm, ph.gmN + 1 end
end

function AD.phaseZu(z)
    local ph = z.phase
    ph.tempo = (ph.mult > 0) and (ph.strecke / ph.mult) or nil
    ph.walkspeed = (ph.wsN > 0) and (ph.ws / ph.wsN) or nil
    ph.getmovespeed = (ph.gmN > 0) and (ph.gm / ph.gmN) or nil
    z.phasen[#z.phasen + 1] = ph
    z.phase = nil
end

--- Trait, Panik und Ausdauer fuer den naechsten Update.
function AD.setzen(player, z)
    if hatTrait(player, "adrenalinejunkie") ~= z.phase.mit then
        local c = player:getCharacterTraits()
        if z.phase.mit then c:add(z.typ) else c:remove(z.typ) end
    end
    local stats = player:getStats()
    stats:set(CharacterStat.PANIC, (z.phase.teil and z.phase.teil.panik) or TFMeasure.ADRENALIN.panik)
    stats:set(CharacterStat.ENDURANCE, 1)
end

function AD.live(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= AD.kennung() then return end
    local plan, cfg, ph = z.ablauf, TFMeasure.ADRENALIN, z.phase
    local ticks = ph and ph.ticks or 0
    lauf.fortschritt = (#z.phasen + ticks / cfg.phaseTicks) / #plan
    local mit = plan[#z.phasen + 1] and plan[#z.phasen + 1].mit
    lauf.live = {
        { T("adrenalin_live_phasen"), T("paar", tostring(#z.phasen), tostring(#plan)) },
        { T("adrenalin_live_ticks"), T("paar", tostring(ticks), tostring(cfg.phaseTicks)) },
        { T("adrenalin_live_gruppe"), (mit == nil) and "-"
            or T(mit and "adrenalin_gruppe_mit" or "adrenalin_gruppe_ohne") },
    }
end

function AD.status(player, z, grund)
    local lauf = TFMeasure.lauf
    if grund == "rennt" then
        lauf.status = T("adrenalin_status_rennt")
    elseif grund == "gehtnur" then
        lauf.status = T("adrenalin_status_shift")
    elseif grund == "sprintet" then
        lauf.status = T("adrenalin_status_sprintet")
    elseif grund == "sprintnicht" then
        lauf.status = T("adrenalin_status_alt")
    elseif grund == "anders" then
        lauf.status = T("adrenalin_status_anders")
    elseif grund == "panik" then
        lauf.status = T("adrenalin_status_panik", tostring(z.phase.teil.stufe))
    elseif grund == "last" then
        lauf.status = T("adrenalin_status_last", tostring(AD.stufe(player, MoodleType.HEAVY_LOAD)))
    elseif grund then
        lauf.status = T("adrenalin_status_warten")
    elseif not z.phase.mit and z.phase.teil.gang == "gehen" and type(z.wsJetzt) == "number" and z.wsJetzt < 0.78 then
        -- Nur beim Gehen: das Renntempo ohne Trait liegt regulaer bei 0.65.
        lauf.status = T("adrenalin_status_schuhe", komma(z.wsJetzt, 2))
    else
        lauf.status = T("adrenalin_status_misst", tostring(#z.phasen + 1), tostring(#z.ablauf),
            T(z.phase.mit and "adrenalin_gruppe_mit" or "adrenalin_gruppe_ohne"))
        -- Ab dem zweiten Teil sagt das Fenster dazu, was gerade dran ist.
        if z.phase.teil.id ~= "gehen4" then
            lauf.status = lauf.status .. " " .. T("adrenalin_teil_" .. z.phase.teil.id)
        end
        lauf.erledigt = math.max(lauf.erledigt or 0, 2)
    end
    AD.live(z)
end

--- Jede Phase mit Trait gegen das Mittel ihrer Nachbarn ohne; das hebt
-- langsame Drift (Bildrate, Gelaende) auf.
function AD.nachbar(phasen, feld, teil)
    local summe, n = 0, 0
    for i, ph in ipairs(phasen) do
        if ph.mit and type(ph[feld]) == "number" and (teil == nil or ph.teil == teil) then
            local s, k = 0, 0
            for _, j in ipairs({ i - 1, i + 1 }) do
                local nb = phasen[j]
                if nb and not nb.mit and nb.teil == ph.teil and type(nb[feld]) == "number" then
                    s, k = s + nb[feld], k + 1
                end
            end
            if k > 0 and s ~= 0 then summe, n = summe + ph[feld] / (s / k), n + 1 end
        end
    end
    if n == 0 then return nil, 0 end
    return summe / n, n
end

--- Der Wert der Mod als Faktor, aus TF_Static; nil ohne Trait Facts.
function AD.soll(effekt, stufe)
    local liste = TraitFacts and TraitFacts.Static and TraitFacts.Static["adrenalinejunkie"]
    if type(liste) ~= "table" then return nil end
    for _, e in ipairs(liste) do
        -- Seit Trait Facts 0.12.4 fuehren Rennen und Sprinten eine Spanne in
        -- Prozent: unten Strong Panic (Stufe 3), oben Extreme Panic (Stufe 4).
        if e.id == effekt and (e.kind == "range" or e.kind == "pctrange") and type(e.value) == "table" then
            local v = e.value[(stufe == 3) and 1 or 2]
            if type(v) == "number" then return 1 + v / 100 end
        end
        if e.id == effekt and type(e.value) == "number" then
            if e.kind == "pct" then return 1 + e.value / 100 end
            if e.kind == "mult" then return e.value end
        end
    end
    return nil
end

--- Renntempo laut Code mit / ohne Trait auf Stufe 4, bei Sprinting-Stufe s:
-- (0.8 + 0.25 - 0.15) + s / 20 gegen (0.8 - 0.15) + s / 20, beide bei 1.0
-- gedeckelt (ohne Last und mit Schuhen ist fullSpeedMod 1).
function AD.rennSoll(s, stufe)
    local zuschlag = ((stufe or 4) + 1) / 20
    return math.min(1, 0.65 + zuschlag + s / 20) / math.min(1, 0.65 + s / 20)
end

--- Die Zeilen der Teile 2 und 3: je die Variable des Spiels und die Strecke.
function AD.zeilenWeiter(z, zeilen)
    local toleranz = TFMeasure.ADRENALIN.toleranz
    for _, teil in ipairs(AD.teile()) do
        if teil.id ~= "gehen4" then
            local schnell = teil.gang ~= "gehen"
            local soll = schnell and AD.rennSoll(z.sprinten or 0, teil.stufe) or 1.25
            local namen = ({ rennen = { "runspeed", "tempo_rennen", "Rennen", "panicrun" },
                             sprint = { "sprintspeed", "tempo_sprint", "Sprinten", "panicsprint" } })[teil.gang]
            if namen then
                -- Stufe 4 traegt die Namen von 6.33/6.34 weiter; Stufe 3 haengt _stufe3 an.
                -- Verglichen wird mit der Spanne von Trait Facts: unten Stufe 3, oben Stufe 4.
                local dran = (teil.stufe == 3) and "_stufe3" or ""
                namen = { namen[1] .. dran, namen[2] .. dran, namen[3] .. " auf Stufe " .. teil.stufe,
                          namen[4] }
            else
                namen = { "walkspeed_stufe3", "tempo_stufe3", "Gehen auf Stufe 3", "panicspeed" }
            end
            local paare = {
                { namen[1], "walkspeed",
                  schnell and ("Variable WalkSpeed beim " .. ((teil.gang == "sprint") and "Sprinten" or "Rennen")
                      .. " (traegt das Renntempo), Sprinting " .. tostring(z.sprinten or 0))
                      or "Animationsvariable WalkSpeed auf Panikstufe 3: 0.8 + 0.20" },
                { namen[2], "tempo", "Strecke je Multiplier, " .. namen[3] .. ": der reale Wert" },
            }
            for _, paar in ipairs(paare) do
                local wert, n = AD.nachbar(z.phasen, paar[2], teil)
                local e = { groesse = paar[1], code = soll, notiz = paar[3], faktor = wert, n = n }
                -- Die Strecke vergleicht sich mit dem Wert von Trait Facts, wie in Teil 1.
                if paar[2] == "tempo" then e.mod = AD.soll(namen[4], teil.stufe) end
                local ziel = e.mod or soll
                if type(wert) ~= "number" then
                    e.urteil = "nicht messbar"
                else
                    e.urteil = (math.abs(wert - ziel) <= math.max(0.006, toleranz * ziel)) and "stimmt" or "weicht ab"
                end
                zeilen[#zeilen + 1] = e
            end
        end
    end
    return zeilen
end

function AD.zeilen(z)
    local f = {}
    local erster = AD.teile()[1]
    -- Ohne den ersten Teil (Gehen auf Stufe 4) gibt es dessen vier Zeilen nicht.
    if erster.id ~= "gehen4" then return AD.zeilenWeiter(z, {}) end
    for _, feld in ipairs({ "walkspeed", "getmovespeed", "tempo" }) do
        local wert, n = AD.nachbar(z.phasen, feld, erster)
        f[feld] = { wert = wert, n = n }
    end
    local tp, basis = f.tempo.wert, AD.soll("panicspeed") or 1.08
    f.zusatz = { wert = tp and (tp / basis) or nil, n = f.tempo.n }
    local zeilen = {}
    for _, def in ipairs(TFMeasure.ADRENALIN_WERTE) do
        local e = { groesse = def.groesse, code = def.code, notiz = def.notiz,
                    faktor = f[def.groesse].wert, n = f[def.groesse].n }
        if def.effekt then e.mod = AD.soll(def.effekt) end
        local soll = e.mod or e.code
        if type(e.faktor) ~= "number" then
            e.urteil = "nicht messbar"
        else
            local toleranz = math.max(0.006, TFMeasure.ADRENALIN.toleranz * math.abs(soll))
            e.urteil = (math.abs(e.faktor - soll) <= toleranz) and "stimmt" or "weicht ab"
        end
        zeilen[#zeilen + 1] = e
    end
    return AD.zeilenWeiter(z, zeilen)
end

--- Mittel eines Feldes ueber die Phasen ohne (mit = false) oder mit Trait,
-- aus dem ersten Teil (Gehen auf Stufe 4).
function AD.mittel(z, mit, feld)
    local summe, n = 0, 0
    for _, ph in ipairs(z.phasen) do
        if ph.mit == mit and ph.teil == AD.teile()[1] and type(ph[feld]) == "number" then
            summe, n = summe + ph[feld], n + 1
        end
    end
    if n == 0 then return nil end
    return summe / n
end

function AD.schreiben(z, zeilen, stimmen, abweichend, fehlt)
    local cfg = TFMeasure.ADRENALIN
    local writer = getFileWriter(AD.datei or TFMeasure.ADRENALINFILE, true, false)
    local trenner = (lineSeparator and lineSeparator()) or "\r\n"
    local function write(line) writer:write(line .. trenner) end
    local function z4(x) return (type(x) == "number") and string.format("%.4f", x) or "-" end
    local function z6(x) return (type(x) == "number") and string.format("%.6f", x) or "-" end
    local build = "unbekannt"
    pcall(function() build = tostring(getCore():getVersionNumber()) end)
    write("# Adrenalin: Gehtempo bei Panik mit Adrenaline Junkie, Messung an einer lebenden Figur")
    write("# Mess-Mod " .. TFMeasure.VERSION)
    write("# Build " .. build)
    write(string.format("# je Phase %d gezaehlte Ticks Gehen (ohne Shift), nach jedem Umschalten und jeder Pause"
        .. " %d Ticks Anlauf; Panik in jedem Tick auf %d (Stufe 4), Ausdauer auf 1; God Mode aus",
        cfg.phaseTicks, cfg.vorlauf, cfg.panik))
    write("# WalkSpeed ohne Trait im Mittel " .. z4(AD.mittel(z, false, "walkspeed"))
        .. " (0.8000 mit Schuhen, ohne Last, bei normaler Waerme)")
    write("# tempo = Summe Strecke / Summe Multiplier; walkspeed und getmovespeed = Mittel der gezaehlten Ticks;"
        .. " felder_je_s aus der Uhr")
    write("# faktor = Phase mit Trait / Mittel der Nachbarphasen ohne, Toleranz 3 %; zusatz = faktor tempo /"
        .. " faktor walkspeed")
    write("# laut Code: calculateBaseSpeed (IsoGameCharacter Z. 8754-8764) 0.8, mit Adrenaline Junkie ab"
        .. " Panikstufe 3 +(Stufe+1)/20, auf Stufe 4 1.05; calculateWalkSpeed deckelt bei 1.0 (Z. 8985): x1.25")
    write("# laut Code: IsoPlayer.getMoveSpeed (Z. 1662-1666) x1.1 auf Stufe 4, gelesen nur von getPathSpeed"
        .. " (Z. 1024-1025) ohne Aufrufer: zusatz 1.0 (Spielfehler adrenaline-movespeed)")
    write("")
    write("[ergebnis]")
    write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d|phasen=%d",
        #zeilen, stimmen, abweichend, fehlt, #z.phasen))
    write("")
    write("[werte] wert|groesse|trait|faktor|soll_mod|soll_code|urteil|phasen|notiz")
    for _, e in ipairs(zeilen) do
        write(string.format("wert|%s|adrenalinejunkie|%s|%s|%s|%s|%d|%s", e.groesse, z4(e.faktor), z4(e.mod),
            z4(e.code), e.urteil, e.n or 0, e.notiz))
    end
    write("")
    write("[teile] teil|id|gangart|panikstufe|phasen (seit 6.33.0; die Werte mit _stufe3 und _rennen gehoeren"
        .. " zu Teil 2 und 3)")
    local von = 1
    for _, teil in ipairs(AD.teile()) do
        local zahl = 0
        for _, ph in ipairs(z.phasen) do if ph.teil == teil then zahl = zahl + 1 end end
        if zahl > 0 then
            write(string.format("teil|%s|%s|%d|%d-%d", teil.id, teil.gang, teil.stufe, von, von + zahl - 1))
            von = von + zahl
        end
    end
    write("")
    write("[phasen] phase|nr|adrenalinejunkie|ticks|tempo|felder_je_s|walkspeed|getmovespeed|nicht_gezaehlt")
    for i, ph in ipairs(z.phasen) do
        local jeS = (ph.ms > 0) and (ph.strecke / ph.ms * 1000) or nil
        write(string.format("phase|%d|%d|%d|%s|%s|%s|%s|%d", i, ph.mit and 1 or 0, ph.ticks, z6(ph.tempo),
            z4(jeS), z4(ph.walkspeed), z6(ph.getmovespeed), ph.aus))
    end
    writer:close()
end

--- Traits (Adrenaline Junkie wie vorher, Desensitized zurueck), Panik,
-- Ausdauer und God Mode zurueck.
function AD.aufraeumen(player, z)
    if player then
        pcall(function()
            local c = player:getCharacterTraits()
            if z.trait0 then c:add(z.typ) else c:remove(z.typ) end
            for _, typ in ipairs(z.stoerer or {}) do c:add(typ) end
        end)
        pcall(function() player:getStats():set(CharacterStat.PANIC, z.panik0 or 0) end)
        pcall(function() player:getStats():set(CharacterStat.ENDURANCE, z.ausdauer0 or 1) end)
        if z.godAus then pcall(function() player:setGodMod(TFMeasure.cheatStand.god ~= false) end) end
    end
    TFMeasure.godPause = nil
    TFMeasure.adrenalinZustand = nil
    AD.aktiv, AD.laufId, AD.datei = nil, nil, nil
end

function AD.fertig(player, z)
    local zeilen = AD.zeilen(z)
    local stimmen, abweichend, fehlt = 0, 0, 0
    for _, e in ipairs(zeilen) do
        if e.urteil == "stimmt" then
            stimmen = stimmen + 1
        elseif e.urteil == "weicht ab" then
            abweichend = abweichend + 1
        else
            fehlt = fehlt + 1
        end
    end
    local okWrite, errWrite = pcall(AD.schreiben, z, zeilen, stimmen, abweichend, fehlt)
    local kennung, datei = AD.kennung(), AD.datei or TFMeasure.ADRENALINFILE
    if TFMeasure.lauf and TFMeasure.lauf.id == kennung then TFMeasure.lauf = nil end
    AD.aufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == AD.kennung() then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen(kennung, { werte = #zeilen, stimmen = stimmen, abweichend = abweichend,
                                            fehlt = fehlt })
        log("Adrenalin-Test geschrieben: Zomboid/Lua/" .. datei)
        halo(player, T("adrenalin_fertig", T("adrenalin_ergebnis", tostring(#zeilen), tostring(stimmen),
            tostring(abweichend), tostring(fehlt))), true)
    else
        log("Adrenalin-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = kennung, text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.adrenalinStarten(player, wahl)
    wahl = wahl or {}
    local typ = traitTypeNamed("adrenalinejunkie")
    if not typ then
        TFMeasure.meldung = { id = wahl.id or "adrenalin", text = T("adrenalin_keintrait") }
        return
    end
    AD.aktiv, AD.laufId, AD.datei = wahl.teile, wahl.id, wahl.datei
    local stats = player:getStats()
    local z = { typ = typ, trait0 = hatTrait(player, "adrenalinejunkie"), phasen = {}, stoerer = {},
                panik0 = stats:get(CharacterStat.PANIC), ausdauer0 = stats:get(CharacterStat.ENDURANCE),
                ablauf = AD.ablauf(), sprinten = 0 }
    pcall(function() z.sprinten = player:getPerkLevel(Perks.Sprinting) end)
    local desensitized = traitTypeNamed("desensitized")
    if desensitized and hatTrait(player, "desensitized") then
        player:getCharacterTraits():remove(desensitized)
        z.stoerer[1] = desensitized
    end
    player:setGodMod(false)
    TFMeasure.godPause = true
    z.godAus = true
    TFMeasure.adrenalinZustand = z
    TFMeasure.lauf = { id = AD.kennung(), erledigt = 0, fortschritt = 0, status = T("adrenalin_status_warten") }
    AD.live(z)
end

--- Ein Tick: erst die Bewegung seit dem letzten Tick zaehlen, dann die Phase
-- abschliessen oder die naechste beginnen, zuletzt Trait, Panik und Ausdauer
-- fuer den naechsten Update setzen.
function TFMeasure.adrenalinTick()
    local z, lauf = TFMeasure.adrenalinZustand, TFMeasure.lauf
    if not z then return end
    local player = getSpecificPlayer(0)
    if not lauf or lauf.id ~= AD.kennung() or not player or AD.ja(function() return player:isDead() end) then
        TFMeasure.adrenalinAbbrechen(T("adrenalin_abgebrochen"))
        return
    end
    local naechste = z.ablauf[#z.phasen + 1]
    local grund = AD.grund(player, (z.phase and z.phase.teil) or (naechste and naechste.teil))
    if z.phase then AD.zaehlen(player, z, grund) end
    if z.phase and z.phase.ticks >= TFMeasure.ADRENALIN.phaseTicks then AD.phaseZu(z) end
    if not z.phase then
        local eintrag = z.ablauf[#z.phasen + 1]
        if eintrag == nil then
            lauf.erledigt = 4
            AD.fertig(player, z)
            return
        end
        z.phase = { mit = eintrag.mit, teil = eintrag.teil, ticks = 0, vorlauf = 0, strecke = 0, mult = 0, ms = 0,
                    ws = 0, wsN = 0, gm = 0, gmN = 0, aus = 0 }
        -- Wechselt die Gangart, faengt der Grund fuer den neuen Teil an.
        grund = AD.grund(player, eintrag.teil)
    end
    AD.setzen(player, z)
    AD.status(player, z, grund)
end

--- Beendet den Adrenalin-Test ohne Bericht und raeumt auf.
function TFMeasure.adrenalinAbbrechen(grund)
    local z = TFMeasure.adrenalinZustand
    local kennung = AD.kennung()
    if TFMeasure.lauf and TFMeasure.lauf.id == kennung then TFMeasure.lauf = nil end
    if z then AD.aufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == AD.kennung() then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = kennung, text = grund or T("adrenalin_abgebrochen") }
end

local function nl()
    return (lineSeparator and lineSeparator()) or "\r\n"
end

local function buildNummer()
    local version = "unbekannt"
    pcall(function() version = tostring(getCore():getVersionNumber()) end)
    return version
end

local function ganz(x)
    return (type(x) == "number") and tostring(math.floor(x + 0.5)) or "-"
end

--- Die Felder einer Berichtszeile "art|schluessel=wert|..." als Tabelle.
local function felderLesen(zeile)
    local werte = {}
    for _, feld in ipairs(teile(zeile, "|")) do
        local gleich = string.find(feld, "=", 1, true)
        if gleich then
            local roh = string.sub(feld, gleich + 1)
            werte[string.sub(feld, 1, gleich - 1)] = tonumber(roh) or roh
        end
    end
    return werte
end

--- Nimmt der Figur alle Traits ab. Die Liste wird erst kopiert: die der
-- Engine aendert sich beim Entfernen.
local function alleTraitsAb(container)
    local known, liste = container:getKnownTraits(), {}
    if known then
        for index = 0, known:size() - 1 do liste[#liste + 1] = known:get(index) end
    end
    for _, typ in ipairs(liste) do container:remove(typ) end
end

--- ---------------------------------------------------------------------------
--- Neue Figur (seit 6.22.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- Die Mod fuehrt fuer Strong, Stout, Puny und Weak einen Tragefaktor (x1.5,
-- x1.25, x0.75, x0.9). Laut Code wirkt er bei einer normal erschaffenen Figur
-- nie: maxWeightDelta setzen nur die beiden IsoPlayer-Konstruktoren
-- (IsoPlayer:592-600 und 656-664), und die laufen vor applyTraits
-- (IsoWorld:2200 und 2211), wenn die gewaehlten Traits noch nicht an der Figur
-- stehen. Die Kapazitaet folgt dann allein der Strength-Stufe:
-- (int)(8 x getWeightMod) in BodyDamage.UpdateStrength, 6 bis 20 von Stufe 0
-- bis 10. Pruefen laesst sich das nur an frisch erschaffenen Figuren, eine je
-- Fall.
--
-- Nebenbei: applyTraits ruft LevelPerk je Stufe (IsoGameCharacter:10441), und
-- XpUpdate.levelPerk setzt dabei die Stufen-Traits neu. Fit mit Fitness
-- Instructor endet so laut Code mit Athletic und Stout statt Fit. Die Zeile
-- nennt, was gewaehlt war (IsoWorld.getLuaTraits, samt Berufs-Traits) und was
-- die Figur danach traegt.
--
-- Ablauf: OnNewGame (nur fuer neue Figuren, IsoWorld:2233) merkt die Figur
-- vor. Gelesen wird ein paar Ticks spaeter: das Spiel rechnet die Kapazitaet
-- erst im Update nach, und mit God Mode gar nicht (BodyDamage.Update kehrt
-- vorher zurueck, 1817-1821). God Mode ist darum fuer diese Ticks aus.
TFMeasure.FIGURFILE = "TraitFacts_figur.txt"
TFMeasure.FIGUR = {
    ticks = 10,
    -- Reihenfolge der Tabelle; faktor ist der Tragefaktor der Mod.
    faelle = {
        { id = "ohne" },
        { id = "strong", faktor = 1.5 },
        { id = "stout", faktor = 1.25 },
        { id = "weak", faktor = 0.75 },
        { id = "feeble", faktor = 0.9 },
        { id = "overweight" },
        { id = "fit" },
    },
    -- Kapazitaet je Strength-Stufe, falls getWeightMod nicht lesbar ist.
    stufen = { [0] = 6, 7, 8, 9, 11, 12, 14, 15, 16, 18, 20 },
}

--- Der Fall zu einer Auswahl: der erste der Liste, dessen Trait gewaehlt ist.
local function figurFall(gewaehlt)
    local faelle = TFMeasure.FIGUR.faelle
    for index = 2, #faelle do
        if gewaehlt[faelle[index].id] then return faelle[index] end
    end
    return faelle[1]
end

local function kommaliste(liste)
    table.sort(liste)
    return (#liste > 0) and table.concat(liste, ",") or "-"
end

--- Die erfassten Figuren aus FIGURFILE, je Fall die letzte.
function TFMeasure.figurLesen()
    local figuren = {}
    pcall(function()
        local reader = getFileReader(TFMeasure.FIGURFILE, false)
        if not reader then return end
        while true do
            local zeile = reader:readLine()
            if zeile == nil then break end
            if string.sub(zeile, 1, 6) == "figur|" then
                local werte = felderLesen(zeile)
                if werte.fall then figuren[werte.fall] = werte end
            end
        end
        reader:close()
    end)
    TFMeasure.figuren = figuren
    return figuren
end

--- Liest die Figur und traegt eine Zeile in FIGURFILE ein.
-- Auch von Hand aus einer Lua-Konsole: TFMeasure.figurErfassen()
function TFMeasure.figurErfassen(player)
    player = player or getSpecificPlayer(0)
    if not player then return nil end
    local gewaehlt, gewaehltListe = {}, {}
    pcall(function()
        local auswahl = getWorld():getLuaTraits()
        for index = 0, auswahl:size() - 1 do
            local key = keyOf(auswahl:get(index))
            if key and not gewaehlt[key] then
                gewaehlt[key] = true
                gewaehltListe[#gewaehltListe + 1] = key
            end
        end
    end)
    local jetzt, jetztListe = {}, {}
    local known = player:getCharacterTraits():getKnownTraits()
    for index = 0, known:size() - 1 do
        local key = keyOf(known:get(index))
        if key and not jetzt[key] then
            jetzt[key] = true
            jetztListe[#jetztListe + 1] = key
        end
    end
    local dazu, weg = {}, {}
    for _, key in ipairs(jetztListe) do
        if not gewaehlt[key] then dazu[#dazu + 1] = key end
    end
    for _, key in ipairs(gewaehltListe) do
        if not jetzt[key] then weg[#weg + 1] = key end
    end
    local beruf = "-"
    pcall(function()
        local key = keyOf(player:getDescriptor():getCharacterProfession())
        if key then beruf = key end
    end)

    local strength = player:getPerkLevel(Perks.Strength)
    local fitness = player:getPerkLevel(Perks.Fitness)
    local tragen = player:getMaxWeight()
    local stufe = TFMeasure.FIGUR.stufen[strength]
    pcall(function() stufe = math.floor(player:getMaxWeightBase() * player:getWeightMod()) end)
    if type(stufe) ~= "number" then stufe = tragen end
    local delta = nil
    pcall(function() delta = player:getMaxWeightDelta() end)
    local fall = figurFall(gewaehlt)
    local mitfaktor = fall.faktor and math.floor(stufe * fall.faktor) or nil
    local lesart = "-"
    if fall.faktor then
        if tragen == stufe then
            lesart = "stufe"
        elseif tragen == mitfaktor then
            lesart = "faktor"
        else
            lesart = "anders"
        end
    end

    -- Was Trait Facts fuer diese Figur vorhersagt (seit 6.28.0). Seit Trait
    -- Facts 0.12.0 zeigt die Uebersicht die Stufen-Traits, die das Spiel bei
    -- der Erschaffung setzt (TF.Summary.levelTraits); hier steht die Vorhersage
    -- neben dem, was die Figur wirklich traegt. Verglichen werden nur die acht
    -- Stufen-Traits: dazu und weg fuehren auch anderes (Berufs-Traits).
    -- tf = "gleich" | "anders" | "-" (Trait Facts laeuft nicht oder ist aelter).
    local tfDazu, tfWeg, tfUrteil = "-", "-", "-"
    pcall(function()
        local TFX = TraitFacts
        if not (TFX and TFX.Summary and TFX.Summary.levelTraits) then return end
        local defs = {}
        local auswahl = getWorld():getLuaTraits()
        for index = 0, auswahl:size() - 1 do
            local okDef, def = pcall(function()
                return CharacterTraitDefinition.getCharacterTraitDefinition(auswahl:get(index))
            end)
            if okDef and def then defs[#defs + 1] = def end
        end
        local prof = CharacterProfessionDefinition.getCharacterProfessionDefinition(
            player:getDescriptor():getCharacterProfession())
        local vorhersage = TFX.Summary.levelTraits(defs, prof)
        if not vorhersage then return end
        local BAND = { weak = true, feeble = true, stout = true, strong = true,
                       unfit = true, outofshape = true, fit = true, athletic = true }
        local function nurBand(liste)
            local out = {}
            for _, key in ipairs(liste) do
                if BAND[key] then out[#out + 1] = key end
            end
            table.sort(out)
            return out
        end
        local sollDazu, sollWeg = {}, {}
        for _, key in ipairs(vorhersage.add or {}) do sollDazu[#sollDazu + 1] = key end
        for key in pairs(vorhersage.drop or {}) do sollWeg[#sollWeg + 1] = key end
        sollDazu, sollWeg = nurBand(sollDazu), nurBand(sollWeg)
        tfDazu, tfWeg = kommaliste(sollDazu), kommaliste(sollWeg)
        local gleich = kommaliste(nurBand(dazu)) == tfDazu and kommaliste(nurBand(weg)) == tfWeg
        tfUrteil = gleich and "gleich" or "anders"
    end)

    local zeile = string.format("figur|fall=%s|beruf=%s|gewaehlt=%s|jetzt=%s|dazu=%s|weg=%s|strength=%s"
        .. "|fitness=%s|tragen=%s|stufe=%s|mitfaktor=%s|delta=%s|lesart=%s",
        fall.id, beruf, kommaliste(gewaehltListe), kommaliste(jetztListe), kommaliste(dazu),
        kommaliste(weg), ganz(strength), ganz(fitness), ganz(tragen), ganz(stufe),
        mitfaktor and ganz(mitfaktor) or "-", delta and string.format("%.2f", delta) or "-", lesart)
        .. "|tfdazu=" .. tfDazu .. "|tfweg=" .. tfWeg .. "|tf=" .. tfUrteil
    local okWrite, errWrite = pcall(function()
        local reader = getFileReader(TFMeasure.FIGURFILE, false)
        local neu = (reader == nil)
        if reader then reader:close() end
        local writer = getFileWriter(TFMeasure.FIGURFILE, true, true)
        if neu then
            writer:write("# Neue Figur: Tragekapazitaet und Stufen-Traits bei der Erschaffung" .. nl())
            writer:write("# eine Zeile je frisch erschaffener Figur, gelesen " .. TFMeasure.FIGUR.ticks
                .. " Ticks nach OnNewGame, mit God Mode aus" .. nl())
            writer:write("# stufe = (int)(getMaxWeightBase x getWeightMod), mitfaktor = stufe x Tragefaktor"
                .. " der Mod; lesart: welche der beiden getMaxWeight zeigt" .. nl())
            writer:write("# gewaehlt = IsoWorld.getLuaTraits (Erstellung, samt Berufs-Traits), jetzt ="
                .. " Traits der Figur, dazu/weg = was das Spiel dabei geaendert hat" .. nl())
            writer:write("# tfdazu/tfweg = was Trait Facts (ab 0.12.0) an Stufen-Traits vorhersagt, tf ="
                .. " gleich|anders gegen dazu/weg, nur die acht Stufen-Traits verglichen" .. nl())
        end
        writer:write("# Mess-Mod " .. TFMeasure.VERSION .. ", Build " .. buildNummer() .. ", " .. heute() .. nl())
        writer:write(zeile .. nl())
        writer:close()
    end)
    if not okWrite then log("Neue Figur nicht geschrieben: " .. tostring(errWrite)) end

    local figuren = TFMeasure.figuren or TFMeasure.figurLesen()
    figuren[fall.id] = felderLesen(zeile)
    TFMeasure.figuren = figuren
    local erfasst, lesarten = 0, {}
    for _, f in ipairs(TFMeasure.FIGUR.faelle) do
        local e = figuren[f.id]
        if e then
            erfasst = erfasst + 1
            if f.faktor then lesarten[tostring(e.lesart)] = true end
        end
    end
    if erfasst >= #TFMeasure.FIGUR.faelle then
        local gesamt = "gemischt"
        if lesarten.stufe and not lesarten.faktor and not lesarten.anders then
            gesamt = "stufe"
        elseif lesarten.faktor and not lesarten.stufe and not lesarten.anders then
            gesamt = "faktor"
        end
        TFMeasure.erledigen("figur", { erfasst = erfasst, lesart = gesamt })
    end
    log("Neue Figur erfasst: " .. zeile)
    halo(player, T("figur_erfasst", T("figur_fall_" .. fall.id), ganz(tragen)), true)
    return zeile
end

--- OnNewGame: die Figur vormerken, gelesen wird im Tick.
function TFMeasure.neueFigur()
    TFMeasure.figurWartet = { ticks = 0 }
end

local function figurTick()
    local w = TFMeasure.figurWartet
    if not w then return end
    local player = getSpecificPlayer(0)
    if not player then return end
    if w.ticks == 0 then pcall(function() player:setGodMod(false) end) end
    w.ticks = w.ticks + 1
    if w.ticks < TFMeasure.FIGUR.ticks then return end
    TFMeasure.figurWartet = nil
    local ok, err = pcall(TFMeasure.figurErfassen, player)
    if not ok then log("Neue Figur nicht erfasst: " .. tostring(err)) end
    pcall(function() player:setGodMod(TFMeasure.cheatStand.god ~= false) end)
end

--- Die Tabelle "Bisher erfasst": Kopf und je Fall eine Zeile.
local function figurTabelle()
    local figuren = TFMeasure.figuren or TFMeasure.figurLesen()
    local kopf = { T("figur_spalte_figur"), T("figur_spalte_stufen"), T("figur_spalte_tragen"),
                   T("figur_spalte_faktor"), T("figur_spalte_dazu") }
    local zeilen = {}
    for _, fall in ipairs(TFMeasure.FIGUR.faelle) do
        local e = figuren[fall.id]
        if e then
            local faktor = "-"
            if type(e.tragen) == "number" and type(e.stufe) == "number" and e.stufe > 0 then
                faktor = T("figur_faktor", komma(e.tragen / e.stufe, 2))
            end
            local spiel = {}
            if e.dazu and e.dazu ~= "-" then
                spiel[#spiel + 1] = (string.gsub(tostring(e.dazu), ",", ", "))
            end
            if e.weg and e.weg ~= "-" then
                spiel[#spiel + 1] = T("figur_weg", (string.gsub(tostring(e.weg), ",", ", ")))
            end
            zeilen[#zeilen + 1] = { T("figur_fall_" .. fall.id),
                                    tostring(e.strength) .. " / " .. tostring(e.fitness),
                                    tostring(e.tragen), faktor,
                                    (#spiel > 0) and table.concat(spiel, "; ") or "-" }
        else
            zeilen[#zeilen + 1] = { T("figur_fall_" .. fall.id), "-", "-", "-", "-" }
        end
    end
    return kopf, zeilen
end

local function figurWartetText()
    local figuren = TFMeasure.figuren or TFMeasure.figurLesen()
    local n = 0
    for _, f in ipairs(TFMeasure.FIGUR.faelle) do
        if figuren[f.id] then n = n + 1 end
    end
    return T("figur_wartet", tostring(n), tostring(#TFMeasure.FIGUR.faelle))
end

--- ---------------------------------------------------------------------------
--- Panik im Freien (seit 6.22.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- Agoraphobic: IsoGameCharacter.updateInternal (8207-8209) gibt je Bild
-- 0.5 x getThirtyFPSMultiplier Panik, solange die Figur in keinem Raum steht
-- (getCurrentSquare():isInARoom(), IsoGridSquare:8759). Bei Spieltempo 1 sind
-- das 15 je Sekunde, bei jeder Bildrate. Im selben Bild baut ReducePanic fuer
-- jede Figur 0.06 x ThirtyFPS ab (BodyDamage:399-413), 1.8 je Sekunde, dazu
-- 0.06 je ueberlebtem Monat, bei einer neuen Figur 0. Netto also +13.2 mit
-- Trait und -1.8 ohne; der Unterschied ist die Wirkung, 15.0.
--
-- God Mode muss aus sein: das Spiel ruft dann je Bild RestoreToFullHealth
-- (BodyDamage:1818), und das setzt alle Werte zurueck, die Panik mit
-- (resetStats, 1569). Aus demselben Grund pausiert das Heilen des Mess-Mods
-- (godTick). Ein Zombie, der neu ins Bild kommt, gibt +7 und laesst den
-- Abbau in diesem Bild aus (IsoPlayer:5424-5438); eine Phase mit so einem
-- Sprung zaehlt nicht, ebenso eine, in der die Figur ins Haus geht. Beide
-- werden wiederholt.
TFMeasure.PANIKFILE = "TraitFacts_panik.txt"
TFMeasure.PANIK = {
    phasen = 6,         -- im Wechsel mit, ohne, mit ...
    phaseMs = 2000,
    mindestTicks = 30,
    startMit = 20,      -- steigt in 2 s auf rund 46
    startOhne = 50,     -- faellt in 2 s auf rund 46
    sprung = 3,         -- mehr Zuwachs in einem Tick heisst: Zombie im Bild
    maxVerworfen = 20,
}

local function dreissig()
    local m = nil
    pcall(function() m = getGameTime():getThirtyFPSMultiplier() end)
    return m
end

local function panikMittel(z, mit, feld)
    local summe, n = 0, 0
    for _, ph in ipairs(z.phasen) do
        if ph.mit == mit and type(ph[feld]) == "number" then
            summe = summe + ph[feld]
            n = n + 1
        end
    end
    if n == 0 then return nil end
    return summe / n
end

local function panikLive(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "panik" then return end
    local cfg = TFMeasure.PANIK
    lauf.fortschritt = #z.phasen / cfg.phasen
    lauf.live = {
        { T("panik_live_phasen"), T("paar", tostring(#z.phasen), tostring(cfg.phasen)) },
        { T("panik_live_mit"), komma(panikMittel(z, true, "jeS"), 1) },
        { T("panik_live_ohne"), komma(panikMittel(z, false, "jeS"), 1) },
    }
end

local function panikTraitSetzen(player, z, an)
    local container = player:getCharacterTraits()
    if an then container:add(z.typ) else container:remove(z.typ) end
end

local function panikAufraeumen(player, z)
    if player then
        pcall(panikTraitSetzen, player, z, z.trait0)
        pcall(function() player:getStats():reset(CharacterStat.PANIC) end)
        if z.godAus then pcall(function() player:setGodMod(TFMeasure.cheatStand.god ~= false) end) end
    end
    TFMeasure.godPause = nil
    TFMeasure.panikZustand = nil
end

local function panikFertig(player, z)
    local cfg = TFMeasure.PANIK
    local mitS, ohneS = panikMittel(z, true, "jeS"), panikMittel(z, false, "jeS")
    local mit30, ohne30 = panikMittel(z, true, "je30"), panikMittel(z, false, "je30")
    local wirkung = (mitS and ohneS) and (mitS - ohneS) or nil
    local function f2(x) return x and string.format("%.2f", x) or "-" end
    local function f4(x) return x and string.format("%.4f", x) or "-" end
    local tempo = "?"
    pcall(function() tempo = tostring(getGameSpeed()) end)
    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.PANIKFILE, true, false)
        local function write(line) writer:write(line .. nl()) end
        write("# Panik im Freien: Agoraphobic, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        write("# Build " .. buildNummer())
        write(string.format("# Spieltempo %s (1 = normal); je Phase %d ms, Start mit Trait %d, ohne %d",
            tempo, cfg.phaseMs, cfg.startMit, cfg.startOhne))
        write("# erwartet laut Code: Agoraphobic +0.5 je Bild x ThirtyFPS = 15 je Sekunde; ReducePanic fuer alle")
        write("#   -0.06 x ThirtyFPS = -1.8 je Sekunde; netto +13.2 mit, -1.8 ohne, der Trait 15.0")
        write("# je_30fps = Aenderung geteilt durch die Summe von getThirtyFPSMultiplier: 0.44 mit, -0.06 ohne")
        write("")
        write("[ergebnis]")
        write(string.format("ergebnis|mit_je_s=%s|ohne_je_s=%s|trait_je_s=%s|mit_je_30fps=%s|ohne_je_30fps=%s"
            .. "|phasen=%d|verworfen=%d", f2(mitS), f2(ohneS), f2(wirkung), f4(mit30), f4(ohne30),
            #z.phasen, z.verworfen))
        write("")
        write("[phasen] nr|agoraphobic|ticks|ms|von|bis|je_s|je_30fps")
        for index, ph in ipairs(z.phasen) do
            write(string.format("phase|%d|%d|%d|%s|%s|%s|%s|%s", index, ph.mit and 1 or 0, ph.ticks,
                ganz(ph.ms), f2(ph.von), f2(ph.bis), f2(ph.jeS), f4(ph.je30)))
        end
        writer:close()
    end)
    panikAufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == "panik" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("panik", { mit = mitS, ohne = ohneS, trait = wirkung })
        log("Panik-Test geschrieben: Zomboid/Lua/" .. TFMeasure.PANIKFILE)
        halo(player, T("panik_fertig", T("panik_ergebnis", komma(mitS, 1), komma(ohneS, 1),
            komma(wirkung, 1))), true)
    else
        log("Panik-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "panik", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.panikStarten(player)
    local typ = traitTypeNamed("agoraphobic")
    if not typ then
        TFMeasure.meldung = { id = "panik", text = T("panik_keintrait") }
        return
    end
    local z = { typ = typ, trait0 = hatTrait(player, "agoraphobic"), phasen = {}, verworfen = 0 }
    TFMeasure.panikZustand = z
    TFMeasure.lauf = { id = "panik", erledigt = 0, fortschritt = 0, status = T("panik_status_raum") }
    panikLive(z)
end

function TFMeasure.panikTick()
    local z, lauf = TFMeasure.panikZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "panik" then
        TFMeasure.panikAbbrechen(T("panik_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    local cfg = TFMeasure.PANIK
    local stats = player:getStats()
    local feld = player:getCurrentSquare()
    local draussen = (feld ~= nil) and not feld:isInARoom()
    if not draussen then
        if z.phase then
            z.phase = nil
            z.verworfen = z.verworfen + 1
        end
        lauf.status = T("panik_status_raum")
        panikLive(z)
        return
    end
    if not z.godAus then
        player:setGodMod(false)
        TFMeasure.godPause = true
        z.godAus = true
        lauf.erledigt = 2
    end
    local mit = (#z.phasen % 2) == 0
    if not z.phase then
        panikTraitSetzen(player, z, mit)
        local start = mit and cfg.startMit or cfg.startOhne
        stats:set(CharacterStat.PANIC, start)
        z.phase = { mit = mit, von = start, vorher = start, ms0 = uhr(), ticks = 0, summe30 = 0 }
        lauf.status = T("panik_status_misst", tostring(#z.phasen + 1), tostring(cfg.phasen),
            mit and T("panik_mit") or T("panik_ohne"))
        panikLive(z)
        return
    end
    local ph = z.phase
    local p = stats:get(CharacterStat.PANIC)
    ph.ticks = ph.ticks + 1
    ph.summe30 = ph.summe30 + (dreissig() or 0)
    if p - ph.vorher > cfg.sprung or p >= 100 or p <= 0 then
        z.phase = nil
        z.verworfen = z.verworfen + 1
        if z.verworfen > cfg.maxVerworfen then TFMeasure.panikAbbrechen(T("panik_zuoft")) end
        return
    end
    ph.vorher = p
    local jetzt = uhr()
    if jetzt and ph.ms0 and jetzt - ph.ms0 >= cfg.phaseMs and ph.ticks >= cfg.mindestTicks then
        ph.bis, ph.ms = p, jetzt - ph.ms0
        ph.jeS = (p - ph.von) / (ph.ms / 1000)
        if ph.summe30 > 0 then ph.je30 = (p - ph.von) / ph.summe30 end
        z.phasen[#z.phasen + 1] = ph
        z.phase = nil
        if #z.phasen >= cfg.phasen then
            panikFertig(player, z)
            return
        end
    end
    panikLive(z)
end

--- Beendet den Panik-Test ohne Ergebnis: Trait und God Mode zurueck.
function TFMeasure.panikAbbrechen(grund)
    local z = TFMeasure.panikZustand
    if z then panikAufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == "panik" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "panik", text = grund or T("panik_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Blut und Laerm: Blutpanik, Blutstress, Stress aus Geraeuschen (14.09.2026)
--- ---------------------------------------------------------------------------
--
-- Drei Wirkungen, die bisher nur im Code gelesen waren, an einer stehenden
-- Figur ohne Zutun. Gelesen am 14.09.2026 im dekompilierten 42.20:
--
--   Blutpanik   IsoGameCharacter.updateInternal (Z. 8219-8221): je Bild
--               (Hemophobic 0.4, sonst 0.2) x del x ThirtyFPS, del = (1 -
--               getOverallBodyHealth / 100) x getNumPartsBleeding. Gezaehlt
--               wird nur das Flag BodyPart.bleeding (BodyDamage Z. 1434-1441).
--               Das Mod setzt es mit setBleeding(true) ohne Blutungszeit: dann
--               zieht BodyPart.DamageUpdate keine Gesundheit ab und tropft
--               kein Blut, beides fragt getBleedingTime() > 0 (BodyPart
--               Z. 161-168, 202-220). Die Gesundheit senkt ReduceGeneralHealth
--               auf 62 (Z. 932-943, je Teil val/17/damageModifier, hoechstens
--               22 Punkte an der Hand); ab 60 mit einer Blutung setzt
--               BodyDamage.Update n = 0 (Z. 1827-1832), also kein Blut am Boden.
--               Abbau fuer alle: ReducePanic -0.06 x ThirtyFPS (Z. 399-413).
--   Blutstress  IsoGameCharacter.updateStress (privat, Z. 9221-9223): mit
--               Hemophobic je Update getTotalBlood x StressFromHemophobic
--               (defines.lua:29, 0.0000003333) x getMultiplier / 0.8 x
--               getDeltaMinutesPerDay. getTotalBlood (public, Z. 12855-12872)
--               zaehlt je Gegenstand in der Hand getBloodLevelAdjustedHigh =
--               Blut x 100 (InventoryItem Z. 4682-4687); zwei Aexte mit Blut 1
--               (HandWeapon.setBloodLevel, Z. 1879) geben 200.
--   Geraeusche  IsoGameCharacter.updateStress (Z. 9209-9210): ohne Deaf je
--               Update getStressFromSounds(x, y, z) x StressFromSoundsMultiplier
--               (defines.lua:27, 0.00002), ohne Multiplier; mit Deaf nichts.
--               Die Geraeusche setzt WorldSoundManager.addSound mit 13
--               Parametern (Z. 107) und flags = 2: nur stresshumans. Jede
--               kuerzere Fassung setzt dazu das Bit 4, stressZombies (Z. 94).
--               Ohne es hoert kein Zombie hin (getSoundZomb Z. 186,
--               getBiggestSoundZomb Z. 230; ZombiePopulationManager.addWorldSound
--               kehrt ohne stressZombies und unter Radius 50 zurueck, Bytecode
--               Offset 7-32). Radius 3. Ein WorldSound lebt 16 Updates
--               (WorldSound.init Z. 465) und verschwindet dann von selbst aus
--               beiden Listen (WorldSoundManager.update Z. 342-353,
--               IsoChunk.updateSounds Offset 42-58).
--
-- Reihenfolge je Bild (IngameState.updateInternal, Bytecode): IsoWorld.update
-- (Offset 1067, die Figur rechnet), UpdateStuff (1283: GameTime.update, dann
-- WorldSoundManager.update), zuletzt onTick (1331, OnTick). Was das Mod in
-- OnTick setzt und liest, gilt also fuer das naechste Update der Figur: je
-- Tick zaehlen die Werte, die im vorigen Tick gelesen wurden.
--
-- Stress und Panik aendern sich auch aus anderen Quellen. Je Teil wechseln
-- darum Grundphasen (ohne Blutung, ohne Hemophobic, ohne Geraeusch) mit
-- Messphasen; jede Messphase zieht die Grundrate ihrer naechsten Grundphasen
-- davor und danach ab. God Mode ist aus: er ruft je Bild RestoreToFullHealth
-- (BodyDamage Z. 1821-1824), und das setzt Panik und Stress zurueck
-- (Z. 1569-1571). Alle Traits sind fuer die Dauer weg; ein Desensitized
-- setzte die Panik je Bild auf 0 (Z. 430-432).
local BL = {}
TFMeasure.BLUTFILE = "TraitFacts_blut.txt"
TFMeasure.BLUT = {
    phaseMs = 3000,           -- echte Zeit je Phase nach dem Vorlauf
    mindestTicks = 60,
    vorlauf = 20,             -- Ticks nach dem Setzen; ein Geraeusch lebt 17 Updates
    gesundheit = 62,          -- Panik-Teil; ab 60 mit einer Blutung kein Blut am Boden
    abbruchGesundheit = 45,   -- darunter bricht der Test ab, weit vor jeder Gefahr
    panikStart = 30,
    stressStart = 0.2,
    panikSprung = 3,          -- mehr in einem Tick: ein Zombie kam ins Bild (+7)
    stressSprung = 0.01,
    schallRadius = 3,
    schallMod = 1,
    blutMin = 50,             -- so viel muss getTotalBlood mit den Aexten zeigen
    toleranz = 0.02,
    maxVerworfen = 20,
}
-- Je Teil: der gemessene Wert und seine Grenzen, die Grundphase, je Phase
-- die Traits, dazu die Blutung (panik) und das Geraeusch (schall). skala
-- macht die winzigen Koeffizienten lesbar; schritt ist die Zeile im Fenster.
BL.TEIL = {
    panik = { stat = "PANIC", start = "panikStart", sprung = "panikSprung", max = 100, basis = "leer",
              skala = 1, schritt = 1,
              traits = { leer = {}, ohne = {}, mit = { "hemophobic" } }, blutet = { ohne = true, mit = true } },
    blut = { stat = "STRESS", start = "stressStart", sprung = "stressSprung", max = 1, basis = "ohne",
             skala = 1e7, schritt = 2, traits = { ohne = {}, mit = { "hemophobic" } } },
    schall = { stat = "STRESS", start = "stressStart", sprung = "stressSprung", max = 1, basis = "still",
               skala = 1e5, schritt = 3,
               traits = { still = {}, laut = {}, taub = { "deaf" } }, laut = { laut = true, taub = true } },
}

--- Die Phasen in ihrer Reihenfolge; symmetrisch, damit Drift sich aufhebt.
function BL.planBauen()
    local plan = {}
    local folge = {
        { "panik", { "leer", "ohne", "mit", "leer", "mit", "ohne", "leer", "ohne", "mit", "leer" } },
        { "blut", { "ohne", "mit", "ohne", "mit", "ohne", "mit", "ohne" } },
        { "schall", { "still", "laut", "taub", "still", "taub", "laut", "still" } },
    }
    for _, teil in ipairs(folge) do
        for _, art in ipairs(teil[2]) do plan[#plan + 1] = { teil = teil[1], art = art } end
    end
    return plan
end
BL.PLAN = BL.planBauen()

function BL.stat(player, name) return player:getStats():get(CharacterStat[name]) end

function BL.setzeStat(player, name, wert)
    if type(wert) == "number" then player:getStats():set(CharacterStat[name], wert) end
end

function BL.traitsMerken(player)
    local held, known = {}, player:getCharacterTraits():getKnownTraits()
    if known then
        for i = 0, known:size() - 1 do held[#held + 1] = known:get(i) end
    end
    return held
end

function BL.traitsNur(player, keys)
    local container = player:getCharacterTraits()
    alleTraitsAb(container)
    for _, key in ipairs(keys or {}) do
        local typ = traitTypeNamed(key)
        if typ then container:add(typ) end
    end
end

function BL.traitsZurueck(player, held)
    local container = player:getCharacterTraits()
    alleTraitsAb(container)
    for _, typ in ipairs(held or {}) do container:add(typ) end
end

--- Der Code-Wert aus defines.lua (ZomboidGlobals ist dort eine Lua-Tabelle),
-- sonst der von 42.20.
function BL.global(name, sonst)
    local g = ZomboidGlobals
    if type(g) == "table" and type(g[name]) == "number" then return g[name] end
    return sonst
end

--- Der Eintrag der Mod: eine Zahl (mult, pct), sonst seine Art ("info");
-- nil ohne Trait Facts.
function BL.mod(trait, effekt)
    local liste = TraitFacts and TraitFacts.Static and TraitFacts.Static[trait]
    if type(liste) ~= "table" then return nil end
    for _, e in ipairs(liste) do
        if e.id == effekt then
            if e.kind == "mult" and type(e.value) == "number" then return e.value end
            if e.kind == "pct" and type(e.value) == "number" then return 1 + e.value / 100 end
            return tostring(e.kind)
        end
    end
    return nil
end

function BL.schritt(lauf, n) lauf.erledigt = math.max(lauf.erledigt or 0, n) end

function BL.artText(e) return e and T("blut_art_" .. e.teil .. "_" .. e.art) or "-" end

function BL.live(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "blut" then return end
    lauf.fortschritt = (z.nr - 1) / #BL.PLAN
    lauf.live = {
        { T("blut_live_phasen"), T("paar", tostring(#z.phasen), tostring(#BL.PLAN)) },
        { T("blut_live_verworfen"), tostring(z.verworfen) },
        { T("blut_live_gerade"), BL.artText(BL.PLAN[z.nr]) },
    }
end

--- Panik-Teil: Gesundheit auf 62, der linke Unterarm bekommt spaeter das
-- Blutungs-Flag. Liefert einen Grund, wenn der Teil nicht messbar ist.
function BL.panikVorbereiten(player, z)
    local cfg = TFMeasure.BLUT
    if not traitTypeNamed("hemophobic") then return "Hemophobic fehlt in der Registry" end
    local bd = player:getBodyDamage()
    local h = bd:getOverallBodyHealth()
    if h < cfg.gesundheit then return string.format("Gesundheit %.1f, schon unter %d", h, cfg.gesundheit) end
    if bd:getNumPartsBleeding() > 0 then return "die Figur blutet schon" end
    local teile, alt = bd:getBodyParts(), {}
    for i = 0, teile:size() - 1 do alt[#alt + 1] = teile:get(i):getHealth() end
    z.gesundheit0 = alt
    local arm = bd:getBodyPart(BodyPartType.ForeArm_L)
    z.arm, z.armBlutet0, z.armZeit0 = arm, arm:bleeding(), arm:getBleedingTime()
    bd:ReduceGeneralHealth(h - cfg.gesundheit)
    bd:calculateOverallHealth()
    return nil
end

--- Blutung weg, jede Stelle wieder mit ihrer Gesundheit von vorher.
function BL.panikZurueck(player, z)
    local bd = player:getBodyDamage()
    if z.arm then
        pcall(function() z.arm:setBleedingTime(z.armZeit0 or 0) end)
        pcall(function() z.arm:setBleeding(z.armBlutet0 == true) end)
        z.arm = nil
    end
    if z.gesundheit0 then
        pcall(function()
            local teile = bd:getBodyParts()
            for i, h in ipairs(z.gesundheit0) do teile:get(i - 1):SetHealth(h) end
            bd:calculateOverallHealth()
        end)
        z.gesundheit0 = nil
    end
end

function BL.blutung(z, an)
    if z.arm then z.arm:setBleeding(an) end
end

--- Blutstress-Teil: zwei Aexte mit Blut 1 in beide Haende.
function BL.blutVorbereiten(player, z)
    if not traitTypeNamed("hemophobic") then return "Hemophobic fehlt in der Registry" end
    local inv = player:getInventory()
    z.hand0, z.hand1 = player:getPrimaryHandItem(), player:getSecondaryHandItem()
    z.axt1 = inv:AddItem("Base.Axe")
    z.axt2 = inv:AddItem("Base.Axe")
    if not z.axt1 or not z.axt2 then return "keine Axt im Inventar" end
    z.axt1:setBloodLevel(1.0)
    z.axt2:setBloodLevel(1.0)
    z.haendeGesetzt = true
    player:setPrimaryHandItem(z.axt1)
    player:setSecondaryHandItem(z.axt2)
    return nil
end

--- Die Haende wie vorher, die Aexte wieder aus dem Inventar.
function BL.blutZurueck(player, z)
    if z.haendeGesetzt then
        pcall(function() player:setPrimaryHandItem(z.hand0) end)
        pcall(function() player:setSecondaryHandItem(z.hand1) end)
        z.haendeGesetzt = nil
    end
    local inv = player:getInventory()
    for _, feld in ipairs({ "axt1", "axt2" }) do
        if z[feld] then
            local axt = z[feld]
            pcall(function() inv:Remove(axt) end)
            z[feld] = nil
        end
    end
end

--- Ein Geraeusch auf dem Feld der Figur. Die 13 Parameter: Quelle, x, y, z,
-- Radius, Lautstaerke, zombieIgnoreDist, stressMod, sourceIsZombie, doSend,
-- remote, repeating, flags (2 = nur stresshumans, kein Zombie hoert es).
--
-- Seit 6.32.1 mit Ausweichweg: die Fassung mit flags nimmt ein short, und
-- Kahlua macht aus einer Lua-Zahl keins ("No implementation found", Lauf vom
-- 20.09.2026; Deaf blieb damit unmessbar). Die Fassung mit neun Parametern
-- (Quelle, x, y, z, Radius, Lautstaerke, stressHumans, zombieIgnoreDist,
-- stressMod; WorldSoundManager Z. 115) setzt stresshumans ueber ein boolean,
-- dazu aber immer das Bit 4: Zombies im Radius hoeren mit. Bei Radius 3 und
-- der ruhigen Stelle, die der Test ohnehin verlangt, stoert das nicht; der
-- Stress fuer die Figur ist derselbe (getStressFromSounds fragt nur
-- stresshumans, Z. 345).
function BL.schallSetzen(player)
    local cfg = TFMeasure.BLUT
    local wsm = getWorldSoundManager()
    local x, y, zz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    -- 6.32.1 versuchte die Fassung mit flags zuerst und wich dann aus. Ein
    -- pcall faengt den Fehler, das Spiel schreibt ihn aber trotzdem rot ins
    -- Log (Lauf vom 20.09.2026, 18:04); seit 6.33.1 gleich der Weg, der geht.
    wsm:addSound(player, x, y, zz, cfg.schallRadius, 1, true, 0, cfg.schallMod)
end

function BL.schallLesen(player)
    return getWorldSoundManager():getStressFromSounds(math.floor(player:getX()), math.floor(player:getY()),
        math.floor(player:getZ()))
end

--- Geraeusch-Teil: ein Probe-Geraeusch; es ist vor dem Ende des Vorlaufs
-- der ersten (stillen) Phase wieder verschwunden.
function BL.schallVorbereiten(player, z)
    if not traitTypeNamed("deaf") then return "Deaf fehlt in der Registry" end
    if type(getWorldSoundManager) ~= "function" then return "getWorldSoundManager fehlt" end
    local ok, err = pcall(BL.schallSetzen, player)
    if not ok then return "addSound geht nicht: " .. tostring(err) end
    local ok2, s = pcall(BL.schallLesen, player)
    if not ok2 or type(s) ~= "number" then return "getStressFromSounds geht nicht: " .. tostring(s) end
    return nil
end

BL.VORBEREITEN = { panik = "panikVorbereiten", blut = "blutVorbereiten", schall = "schallVorbereiten" }
BL.ZURUECK = { panik = "panikZurueck", blut = "blutZurueck" }

--- Raeumt den alten Teil weg und bereitet den neuen vor; ein Grund sperrt ihn.
function BL.teilWechsel(player, z, neu)
    local alt = z.teil and BL.ZURUECK[z.teil]
    if alt then BL[alt](player, z) end
    z.teil = neu
    if not neu then return end
    local lauf = TFMeasure.lauf
    if lauf and lauf.id == "blut" then BL.schritt(lauf, BL.TEIL[neu].schritt) end
    local ok, grund = pcall(BL[BL.VORBEREITEN[neu]], player, z)
    if not ok then grund = tostring(grund) end
    if grund then
        z.grund[neu] = grund
        log("Blut-Test: " .. neu .. " nicht messbar: " .. grund)
    end
end

--- Der naechste Eintrag des Plans; wechselt den Teil und ueberspringt einen
-- gesperrten. nil am Ende, dann ist auch der letzte Teil weggeraeumt.
function BL.naechste(player, z)
    while true do
        local e = BL.PLAN[z.nr]
        if not e then
            BL.teilWechsel(player, z, nil)
            return nil
        end
        if z.teil ~= e.teil then BL.teilWechsel(player, z, e.teil) end
        if not z.grund[e.teil] then return e end
        z.nr = z.nr + 1
    end
end

function BL.phaseStart(player, z, e)
    local cfg, def = TFMeasure.BLUT, BL.TEIL[e.teil]
    BL.traitsNur(player, def.traits[e.art])
    if e.teil == "panik" then BL.blutung(z, def.blutet[e.art] == true) end
    if def.laut and def.laut[e.art] then BL.schallSetzen(player) end
    BL.setzeStat(player, def.stat, cfg[def.start])
    z.phase = { teil = e.teil, art = e.art, vorlauf = cfg.vorlauf, ticks = 0, sf = 0, smd = 0, su = 0, sx = 0 }
    TFMeasure.lauf.status = T("blut_status_misst", tostring(z.nr), tostring(#BL.PLAN), BL.artText(e))
    BL.live(z)
end

--- Was die Figur im naechsten Update rechnet: f = ThirtyFPS, md = Multiplier
-- x DeltaMinutesPerDay (die Grundrate des Stresses), u = die Einheit der
-- Wirkung, x = der Wert dahinter (Gesundheit, Blut, Geraeusch).
function BL.einheit(player, teil)
    local gt = getGameTime()
    local f, m, d = gt:getThirtyFPSMultiplier(), gt:getMultiplier(), gt:getDeltaMinutesPerDay()
    local e = { f = f, md = m * d, u = 0, x = 0 }
    if teil == "panik" then
        local bd = player:getBodyDamage()
        e.n, e.x = bd:getNumPartsBleeding(), bd:getOverallBodyHealth()
        e.u = (1 - e.x / 100) * e.n * f
    elseif teil == "blut" then
        e.x = player:getTotalBlood()
        e.u = e.x * (m / 0.8) * d
    else
        e.x = BL.schallLesen(player)
        e.u = e.x
    end
    return e
end

--- Im Panik-Teil muss genau die Blutung der Phase da sein: keine in der
-- Grundphase, eine in den anderen.
function BL.gueltig(ph, e)
    if ph.teil ~= "panik" then return true end
    return e.n == ((ph.art == BL.TEIL.panik.basis) and 0 or 1)
end

--- Verwirft die laufende Phase; true, wenn der Test deshalb abbricht.
function BL.verwerfen(z)
    z.phase = nil
    z.verworfen = z.verworfen + 1
    if z.verworfen > TFMeasure.BLUT.maxVerworfen then
        TFMeasure.blutAbbrechen(T("blut_zuoft"))
        return true
    end
    return false
end

--- Millisekunden seit dem Ende des Vorlaufs; ohne Uhr 60 Ticks je Sekunde.
function BL.vergangen(ph)
    local jetzt = uhr()
    if jetzt and ph.ms0 then return jetzt - ph.ms0 end
    return ph.ticks * 1000 / 60
end

function BL.phaseTick(player, z)
    local cfg, ph = TFMeasure.BLUT, z.phase
    local def = BL.TEIL[ph.teil]
    if ph.teil == "panik" then BL.blutung(z, def.blutet[ph.art] == true) end
    if def.laut and def.laut[ph.art] then BL.schallSetzen(player) end
    local v = BL.stat(player, def.stat)
    local neu = BL.einheit(player, ph.teil)
    if ph.vorlauf > 0 then
        ph.vorlauf = ph.vorlauf - 1
        if ph.vorlauf == 0 then
            if not BL.gueltig(ph, neu) then BL.verwerfen(z) return end
            ph.v0, ph.vorher, ph.ms0, ph.letzt = v, v, uhr(), neu
        end
        return
    end
    if math.abs(v - ph.vorher) > cfg[def.sprung] or v <= 0 or v >= def.max or not BL.gueltig(ph, neu) then
        BL.verwerfen(z)
        return
    end
    local l = ph.letzt
    ph.sf, ph.smd, ph.su, ph.sx = ph.sf + l.f, ph.smd + l.md, ph.su + l.u, ph.sx + l.x
    ph.ticks, ph.letzt, ph.vorher = ph.ticks + 1, neu, v
    if ph.ticks >= cfg.mindestTicks and BL.vergangen(ph) >= cfg.phaseMs then
        ph.delta, ph.v1, ph.ms = v - ph.v0, v, BL.vergangen(ph)
        z.phasen[#z.phasen + 1] = ph
        z.phase = nil
        z.nr = z.nr + 1
    end
    BL.live(z)
end

--- Die Grundrate der naechsten Grundphase davor und danach (im selben Teil):
-- je ThirtyFPS bei der Panik, je Multiplier x DeltaMinutesPerDay beim Stress.
function BL.basis(phasen, i)
    local teil = phasen[i].teil
    local art = BL.TEIL[teil].basis
    local s, k = 0, 0
    for _, schritt in ipairs({ -1, 1 }) do
        local j = i + schritt
        while phasen[j] and phasen[j].teil == teil do
            local ph = phasen[j]
            if ph.art == art then
                local nenner = (teil == "panik") and ph.sf or ph.smd
                if nenner > 0 then s, k = s + ph.delta / nenner, k + 1 end
                break
            end
            j = j + schritt
        end
    end
    if k == 0 then return nil end
    return s / k
end

--- Die Wirkung je Einheit: Aenderung minus Grundrate, geteilt durch die
-- Summe der Einheit.
function BL.koeffizient(phasen, i)
    local ph = phasen[i]
    local a = BL.basis(phasen, i)
    if not a or ph.su <= 0 then return nil end
    local nenner = (ph.teil == "panik") and ph.sf or ph.smd
    return (ph.delta - a * nenner) / ph.su
end

--- Mittel der Koeffizienten einer Phasenart und wie viele eingingen.
function BL.mittel(phasen, teil, art)
    local s, n = 0, 0
    for i, ph in ipairs(phasen) do
        if ph.teil == teil and ph.art == art then
            ph.k = BL.koeffizient(phasen, i)
            if ph.k then s, n = s + ph.k, n + 1 end
        end
    end
    if n == 0 then return nil, 0 end
    return s / n, n
end

--- Mittel des Werts x (Gesundheit, Blut, Geraeusch) ueber eine Phasenart.
function BL.mittelX(phasen, teil, art)
    local s, n = 0, 0
    for _, ph in ipairs(phasen) do
        if ph.teil == teil and ph.art == art and ph.ticks > 0 then s, n = s + ph.sx / ph.ticks, n + 1 end
    end
    if n == 0 then return nil end
    return s / n
end

function BL.urteil(e, z)
    local grund = z.grund[e.teil]
    if grund then
        e.urteil = "nicht messbar (" .. grund .. ")"
        return
    end
    if type(e.faktor) ~= "number" then
        e.urteil = "nicht messbar (keine gueltige Phase)"
        return
    end
    local soll = (type(e.mod) == "number") and e.mod or e.code
    local tol = e.absolut or math.max(0.006, TFMeasure.BLUT.toleranz * math.abs(soll))
    e.urteil = (math.abs(e.faktor - soll) <= tol) and "stimmt" or "weicht ab"
end

function BL.zaehlen(zeilen)
    local stimmen, abweichend, fehlt = 0, 0, 0
    for _, e in ipairs(zeilen) do
        if e.urteil == "stimmt" then
            stimmen = stimmen + 1
        elseif e.urteil == "weicht ab" then
            abweichend = abweichend + 1
        else
            fehlt = fehlt + 1
        end
    end
    return stimmen, abweichend, fehlt
end

--- Fuenf Werte: der Faktor der Blutpanik (mit / ohne) und ihr Grundwert
-- ohne Trait, der Blutstress je Blutpunkt, der Anteil, den Deaf vom
-- Geraeusch-Stress uebrig laesst, und dieser Stress ohne Deaf.
function BL.zeilen(z)
    local P = z.phasen
    local cOhne, nO = BL.mittel(P, "panik", "ohne")
    local cMit, nM = BL.mittel(P, "panik", "mit")
    local kBlut, nB = BL.mittel(P, "blut", "mit")
    local kLaut, nL = BL.mittel(P, "schall", "laut")
    local kTaub, nT = BL.mittel(P, "schall", "taub")
    local blut = BL.mittelX(P, "blut", "mit")
    if not z.grund.blut and blut and blut < TFMeasure.BLUT.blutMin then
        z.grund.blut = string.format("nur %.0f Blutpunkte, die Aexte zaehlen nicht", blut)
    end
    local function teilt(a, b) return (a and b and b ~= 0) and a / b or nil end
    local function mal(a, s) return a and a * s or nil end
    local sb, ss = BL.TEIL.blut.skala, BL.TEIL.schall.skala
    local zeilen = {
        { name = "bloodpanic", trait = "hemophobic", teil = "panik", faktor = teilt(cMit, cOhne),
          mod = BL.mod("hemophobic", "bloodpanic"), code = 0.4 / 0.2, n = math.min(nO, nM) },
        { name = "bloodpanic_ohne", trait = "-", teil = "panik", faktor = cOhne, code = 0.2, n = nO },
        { name = "bloodstress", trait = "hemophobic", teil = "blut", faktor = mal(kBlut, sb),
          mod = BL.mod("hemophobic", "bloodstress"), code = BL.global("StressFromHemophobic", 0.0000003333) * sb,
          n = nB },
        { name = "sounds", trait = "deaf", teil = "schall", faktor = teilt(kTaub, kLaut),
          mod = BL.mod("deaf", "sounds"), code = 0, n = math.min(nL, nT), absolut = 0.02 },
        { name = "sounds_ohne", trait = "-", teil = "schall", faktor = mal(kLaut, ss),
          code = BL.global("StressFromSoundsMultiplier", 0.00002) * ss, n = nL },
    }
    for _, e in ipairs(zeilen) do BL.urteil(e, z) end
    return zeilen
end

--- Vier Stellen; ein Rest unter der letzten Stelle ist 0, nicht "-0.0000".
function BL.z4(x)
    if type(x) ~= "number" then return "-" end
    if math.abs(x) < 0.00005 then x = 0 end
    return string.format("%.4f", x)
end
function BL.z6(x) return (type(x) == "number") and string.format("%.6f", x) or "-" end
function BL.modText(m)
    if type(m) == "number" then return BL.z4(m) end
    return m or "-"
end

function BL.kopf(write, z)
    local cfg = TFMeasure.BLUT
    local tempo = "?"
    pcall(function() tempo = tostring(getGameSpeed()) end)
    write("# Blut und Laerm: Blutpanik, Blutstress, Stress aus Geraeuschen, Messung an einer lebenden Figur")
    write("# Mess-Mod " .. TFMeasure.VERSION)
    write("# Build " .. buildNummer())
    write(string.format("# Spieltempo %s; je Phase %d ms nach %d Ticks Vorlauf; Gesundheit im Panik-Teil %d,"
        .. " Start Panik %d, Stress %s; Geraeusch Radius %d, stressMod %s", tempo, cfg.phaseMs, cfg.vorlauf,
        cfg.gesundheit, cfg.panikStart, tostring(cfg.stressStart), cfg.schallRadius, tostring(cfg.schallMod)))
    write("# Blutpanik laut Code (updateInternal Z. 8219-8221): je Bild (Hemophobic 0.4, sonst 0.2) x del x ThirtyFPS,")
    write("#   del = (1 - Gesundheit/100) x blutende Teile; bloodpanic = mit/ohne (TF_Static x2.0),")
    write("#   bloodpanic_ohne = Panik je del und ThirtyFPS ohne Trait (0.2)")
    write("# Blutstress laut Code (updateStress Z. 9221-9223): je Update getTotalBlood x StressFromHemophobic x")
    write("#   Multiplier/0.8 x DeltaMinutesPerDay; bloodstress = Stress je Blutpunkt und Einheit x 1e7")
    write("#   (defines.lua 3.333); TF_Static fuehrt bloodstress als info")
    write("# Geraeusche laut Code (updateStress Z. 9209-9210): je Update getStressFromSounds x")
    write("#   StressFromSoundsMultiplier, mit Deaf nichts; sounds = Anteil mit Deaf (laut Code 0),")
    write("#   sounds_ohne = Stress je Einheit getStressFromSounds x 1e5 (defines.lua 2.0); TF_Static: sounds info")
    write("# je Messphase: (Aenderung - Grundrate der naechsten Grundphasen x Summe ThirtyFPS bzw. Multiplier x")
    write("#   DeltaMinutesPerDay) / Summe der Einheit; Toleranz 2 %, beim Anteil mit Deaf 0.02")
    for _, teil in ipairs({ "panik", "blut", "schall" }) do
        if z.grund[teil] then write("# nicht messbar, " .. teil .. ": " .. z.grund[teil]) end
    end
end

function BL.bericht(z, zeilen, stimmen, abweichend, fehlt)
    local writer = getFileWriter(TFMeasure.BLUTFILE, true, false)
    local function write(line) writer:write(line .. nl()) end
    BL.kopf(write, z)
    write("")
    write("[ergebnis]")
    write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d|phasen=%d|verworfen=%d",
        #zeilen, stimmen, abweichend, fehlt, #z.phasen, z.verworfen))
    write("")
    write("[werte] wert|trait|faktor|soll_mod|soll_code|phasen|urteil")
    for _, e in ipairs(zeilen) do
        write(string.format("wert|%s|%s|%s|%s|%s|%d|%s", e.name, e.trait, BL.z4(e.faktor), BL.modText(e.mod),
            BL.z4(e.code), e.n or 0, e.urteil))
    end
    write("")
    write("[phasen] nr|teil|art|ticks|ms|von|bis|mittel_x|koeffizient (x skala)")
    for i, ph in ipairs(z.phasen) do
        write(string.format("phase|%d|%s|%s|%d|%s|%s|%s|%s|%s", i, ph.teil, ph.art, ph.ticks, ganz(ph.ms),
            BL.z6(ph.v0), BL.z6(ph.v1), BL.z4(ph.ticks > 0 and ph.sx / ph.ticks or nil),
            BL.z4(ph.k and ph.k * BL.TEIL[ph.teil].skala)))
    end
    writer:close()
end

--- Alles zurueck: Teil (Gesundheit, Blutung, Haende, Aexte), Traits, Panik,
-- Stress, Schmerz, God Mode und das Heilen des Mess-Mods.
function BL.aufraeumen(player, z)
    if player then
        pcall(BL.teilWechsel, player, z, nil)
        pcall(BL.traitsZurueck, player, z.held)
        pcall(BL.setzeStat, player, "PANIC", z.panik0)
        pcall(BL.setzeStat, player, "STRESS", z.stress0)
        pcall(BL.setzeStat, player, "PAIN", z.schmerz0)
        if z.godAus then pcall(function() player:setGodMod(TFMeasure.cheatStand.god ~= false) end) end
    end
    TFMeasure.godPause = nil
    TFMeasure.blutZustand = nil
end

function BL.fertig(player, z)
    local zeilen = BL.zeilen(z)
    local stimmen, abweichend, fehlt = BL.zaehlen(zeilen)
    local okWrite, errWrite = pcall(BL.bericht, z, zeilen, stimmen, abweichend, fehlt)
    BL.aufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == "blut" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("blut", { werte = #zeilen, stimmen = stimmen, abweichend = abweichend, fehlt = fehlt })
        log("Blut-Test geschrieben: Zomboid/Lua/" .. TFMeasure.BLUTFILE)
        halo(player, T("blut_fertig", T("blut_ergebnis", tostring(#zeilen), tostring(stimmen),
            tostring(abweichend), tostring(fehlt))), true)
    else
        log("Blut-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "blut", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.blutStarten(player)
    local z = { held = BL.traitsMerken(player), phasen = {}, verworfen = 0, nr = 1, grund = {},
                panik0 = BL.stat(player, "PANIC"), stress0 = BL.stat(player, "STRESS"),
                schmerz0 = BL.stat(player, "PAIN") }
    TFMeasure.blutZustand = z
    TFMeasure.lauf = { id = "blut", erledigt = 0, fortschritt = 0, status = T("blut_status_bereit") }
    BL.live(z)
end

function TFMeasure.blutTick()
    local z, lauf = TFMeasure.blutZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "blut" then
        TFMeasure.blutAbbrechen(T("blut_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    if not player or player:isDead()
        or player:getBodyDamage():getOverallBodyHealth() < TFMeasure.BLUT.abbruchGesundheit then
        TFMeasure.blutAbbrechen(T("blut_verletzt"))
        return
    end
    if not z.godAus then
        player:setGodMod(false)
        TFMeasure.godPause = true
        z.godAus = true
        BL.schritt(lauf, 1)
        return
    end
    local e = BL.naechste(player, z)
    if not e then
        BL.fertig(player, z)
        return
    end
    if not z.phase then
        BL.phaseStart(player, z, e)
        return
    end
    BL.phaseTick(player, z)
end

--- Beendet den Blut-Test ohne Bericht und gibt der Figur alles zurueck.
function TFMeasure.blutAbbrechen(grund)
    local z = TFMeasure.blutZustand
    if z then BL.aufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == "blut" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "blut", text = grund or T("blut_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Code-Werte (seit 6.22.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- Rund 30 Werte, die im Code von 42.20 genau stehen und sich an der Figur
-- ueber eine oeffentliche Methode oder eine Vanilla-Aktion lesen lassen, je
-- einmal ohne und einmal mit Trait. Gelesen am 13.09.2026 im dekompilierten
-- Jar; die Fundstellen stehen an jeder Messung. Verglichen wird der Faktor
-- mit/ohne mit dem Wert der Mod (TF_Static, wenn Trait Facts geladen ist),
-- sonst mit dem Wert aus dem Code. Beide stehen im Bericht.
--
-- Nicht dabei, weil nur im Update-Takt oder privat gerechnet: Ausdauerverlust
-- beim Laufen, Sichtkegel, Einblenden, Schritte, Blut, Albtraum, Erkaeltung
-- fangen, Leichen-Krankheit. Muedigkeit, Hunger, Durst und der Schlaf haben
-- seit 6.23.0 eigene Tests ueber Spielzeit (Wach und Schlaf, weiter unten).
--
-- Eine Gruppe je Tick: das Fenster zeigt den Fortschritt, und kein Bild dauert
-- lange. Jede Gruppe raeumt im selben Tick auf; ein Abbruch zwischen zwei
-- Ticks hinterlaesst nichts. Vor jeder Gruppe nimmt der Test der Figur alle
-- Traits ab: das Spiel setzt Gewichts-Traits im Update aus dem Koerpergewicht
-- neu (Nutrition.applyTraitFromWeight), und so ein Trait verfaelschte das
-- "ohne". Am Ende bekommt sie genau ihre Traits zurueck.
--
-- Wunden und Zufallswerte gehen ueber Stichproben; das Mittel aus 500
-- Wuerfen trifft die Bereichsmitte auf rund 1 %. Ein Biss setzt am
-- Koerperteil die Infektion. Jede Probe heilt den Unterarm deshalb sofort
-- (BodyPart.RestoreToFullHealth, 514); auf den Koerper geht die Infektion
-- erst in BodyDamage.Update ueber (1857), und das laeuft waehrend der Gruppe
-- nicht.
TFMeasure.WERTEFILE = "TraitFacts_werte.txt"
TFMeasure.WERTE_PROBEN = 500
TFMeasure.WERTE_ESSEN = 1000

local function statSetzen(player, name, wert) player:getStats():set(CharacterStat[name], wert) end
local function statLesen(player, name) return player:getStats():get(CharacterStat[name]) end

local function unterarmVon(player)
    return player:getBodyDamage():getBodyPart(BodyPartType.ForeArm_L)
end

--- Mittel aus Proben. erzeugen(teil) setzt eine Wunde (false verwirft die
-- Probe), lesen(teil) liest ihre Zeit.
local function wundProbe(player, erzeugen, lesen)
    local teil = unterarmVon(player)
    local summe, n = 0, 0
    for _ = 1, TFMeasure.WERTE_PROBEN do
        teil:RestoreToFullHealth()
        if erzeugen(teil) ~= false then
            local v = lesen(teil)
            if type(v) == "number" and v > 0 then
                summe = summe + v
                n = n + 1
            end
        end
    end
    teil:RestoreToFullHealth()
    if n == 0 then error("keine Probe") end
    return summe / n
end

local M = {}

-- BodyDamage.IncreasePanic (371-397): 7 je neuem Zombie im Bild; Brave x0.3,
-- Cowardly x2, Desensitized setzt auf 0. Im Fahrzeug waere es n/2.
function M.panik(p)
    statSetzen(p, "PANIC", 0)
    p:getBodyDamage():IncreasePanic(1)
    local v = statLesen(p, "PANIC")
    statSetzen(p, "PANIC", 0)
    return v
end

-- calculateBaseSpeed (IsoGameCharacter:8754): 0.8, mit Adrenaline Junkie ab
-- Panikstufe 3 plus (Stufe + 1) / 20. Die Stufe setzt Moodles:Update aus der
-- Panik (Grenzen 6, 30, 65, 80). Beim Gehen deckelt calculateWalkSpeed bei
-- 1.0, darum bleibt es auch auf Stufe 4 bei +25 % Gehtempo.
local function tempo(p, panik)
    statSetzen(p, "PANIC", panik)
    p:getMoodles():Update()
    local v = p:calculateBaseSpeed()
    statSetzen(p, "PANIC", 0)
    p:getMoodles():Update()
    return v
end
function M.tempo3(p) return tempo(p, 70) end
function M.tempo4(p) return tempo(p, 90) end

-- exert (IsoGameCharacter:9366): Tueren und Fenster; Runner verliert 10 %
-- weniger Ausdauer. Braucht "Ausdauer unbegrenzt" aus.
function M.tuer(p)
    statSetzen(p, "ENDURANCE", 1)
    p:exert(0.1)
    local v = 1 - statLesen(p, "ENDURANCE")
    statSetzen(p, "ENDURANCE", 1)
    return v
end

-- getRecoveryMod (IsoGameCharacter:4309-4356): Erholung der Ausdauer.
function M.erholung(p) return p:getRecoveryMod() end

-- Seit 6.35.0 dazu die Wirkung selbst, nicht nur der Faktor: nach dem Fund bei
-- Adrenaline Junkie (20.09.2026: der Tempowert stimmte, die Strecke nicht) gilt
-- ein gelesener Getter nicht mehr als Beleg fuer das, was der Spieler spuert.
-- IsoPlayer.updateEnduranceWhileSitting (public, Z. 3221-3226) addiert
-- imobileEnduranceReduce x Sandbox x getRecoveryMod x sittingEnduranceMultiplier
-- x (1 - 0.8 x Muedigkeit) x Multiplier auf die Ausdauer; gemessen wird der
-- Zuwachs von 0.5 aus, bei Muedigkeit 0. Alles ausser getRecoveryMod ist im
-- Tick fuer alle Faelle gleich, der Faktor mit / ohne ist der des Traits.
function M.erholungSitzen(p)
    local muede, ausdauer = statLesen(p, "FATIGUE"), statLesen(p, "ENDURANCE")
    statSetzen(p, "FATIGUE", 0)
    statSetzen(p, "ENDURANCE", 0.5)
    p:updateEnduranceWhileSitting()
    local v = statLesen(p, "ENDURANCE") - 0.5
    statSetzen(p, "FATIGUE", muede)
    statSetzen(p, "ENDURANCE", ausdauer)
    if type(v) ~= "number" or v <= 0 then return "nicht messbar: die Ausdauer stieg nicht" end
    return v
end

-- processHitDamage (IsoGameCharacter:5773-5777): Rueckstoss x1.4 / x0.6, nur
-- im Nahkampf. Der Aufruf setzt hitForce; der alte Wert kommt zurueck.
function M.rueckstoss(p, z)
    local alt = p:getHitForce()
    p:processHitDamage(z.keule, p, 0.2, false, 1.0)
    local v = p:getHitForce()
    p:setHitForce(alt)
    return v
end

-- resetAimingDelay (IsoGameCharacter:10036): Startverzoegerung der Waffe in
-- der Hand, Dextrous x0.8, All Thumbs x1.2.
function M.zielzeit(p)
    p:resetAimingDelay()
    return p:getAimingDelay()
end

-- updateAimingDelay (10046): Abbau je Aufruf 0.625 x Multiplier x (1 +
-- 0.05 x Aiming + 0.1 mit Marksman); bei Aiming 0 also x1.1.
function M.zielruhe(p)
    p:setIsAiming(true)
    p:setAimingDelay(100)
    p:updateAimingDelay()
    local v = 100 - p:getAimingDelay()
    p:setIsAiming(false)
    p:resetAimingDelay()
    return v
end

-- HandWeapon.getMaxSightRange(chr) (1488): Eagle Eyed x1.2.
function M.sicht(p, z) return z.gewehr:getMaxSightRange(p) end

-- BodyPart (601-874): Biss 50-80 (Fast Healer 30-50, Slow 80-150), Schnitt
-- 10-20 (5-10, 20-30), Kratzer 7-15 (4-10, 15-25), Waffenkratzer 5-10 (1-5,
-- 10-20), Fensterkratzer 12-20 (5-10, 20-30), tiefe Wunde 15-20 (11-15,
-- 20-32), jeweils gleichverteilt. Jeder siebte Fensterkratzer ist eine
-- Glaswunde ohne Kratzzeit (852); die Probe zaehlt nicht.
function M.biss(p)
    return wundProbe(p, function(t) t:SetBitten(true) end, function(t) return t:getBiteTime() end)
end
function M.schnitt(p)
    return wundProbe(p, function(t) t:setCut(true) end, function(t) return t:getCutTime() end)
end
function M.kratzer(p)
    return wundProbe(p, function(t) t:setScratched(true, true) end, function(t) return t:getScratchTime() end)
end
function M.waffenkratzer(p)
    return wundProbe(p, function(t) t:SetScratchedWeapon(true) end, function(t) return t:getScratchTime() end)
end
function M.fensterkratzer(p)
    return wundProbe(p, function(t)
        t:setScratchTime(0)
        t:SetScratchedWindow(true)
        if t:haveGlass() then return false end
    end, function(t) return t:getScratchTime() end)
end
function M.tiefewunde(p)
    return wundProbe(p, function(t) t:generateDeepWound() end, function(t) return t:getDeepWoundTime() end)
end

-- generateFractureNew (BodyPart:828): Bruchzeit x0.6 / x1.8. Die kleine
-- Vorgabe verhindert das Geraeusch (822); wirkt nur mit der Sandbox-Option
-- Knochenbrueche.
function M.bruch(p)
    local t = unterarmVon(p)
    t:RestoreToFullHealth()
    t:setFractureTime(0.001)
    t:generateFractureNew(10)
    local v = t:getFractureTime()
    t:setFractureTime(0)
    t:RestoreToFullHealth()
    return v
end

-- BodyDamage.JustAteFood (527-642): Gift aus Essen x0.5 / x2. Ein neuer Apfel
-- je Aufruf, falls das Essen sein Gift verbraucht.
function M.gift(p)
    local apfel = instanceItem("Base.Apple")
    apfel:setPoisonPower(10)
    statSetzen(p, "POISON", 0)
    p:getBodyDamage():JustAteFood(apfel, 1.0, false)
    local v = statLesen(p, "POISON")
    statSetzen(p, "POISON", 0)
    return v
end

-- Verdorbenes Essen macht mit 2/5 = 40 % krank (Iron Gut 20, Weak Stomach
-- 80; 611-627). Ein Treffer gibt 8 Gift, ein Fehlwurf 3.2. Gezaehlt wird der
-- Anteil der Treffer.
function M.verdorben(p)
    local bd, apfel, treffer = p:getBodyDamage(), instanceItem("Base.Apple"), 0
    for _ = 1, TFMeasure.WERTE_ESSEN do
        apfel:setOffAge(5)
        apfel:setOffAgeMax(10)
        apfel:setAge(12)
        statSetzen(p, "POISON", 0)
        bd:JustAteFood(apfel, 1.0, false)
        if statLesen(p, "POISON") > 5 then treffer = treffer + 1 end
    end
    statSetzen(p, "POISON", 0)
    return treffer / TFMeasure.WERTE_ESSEN
end

-- DrinkFluid (IsoGameCharacter:5470-5509): verseuchtes Wasser 14 Gift je
-- Liter x0.75; Iron Gut 0, Weak Stomach x1.2. Befuellt wie Vanillas
-- Regentonne (SRainBarrelSystem.lua:58).
function M.wasser(p)
    local fc = instanceItem("Base.WaterBottle"):getFluidContainer()
    fc:Empty()
    fc:addFluid(FluidType.TaintedWater, 1.0)
    statSetzen(p, "POISON", 0)
    statSetzen(p, "FOOD_SICKNESS", 0)
    p:DrinkFluid(fc, 1.0, false)
    local v = statLesen(p, "POISON")
    statSetzen(p, "POISON", 0)
    return v
end

-- BodyDamage.UpdateCold (830-873): Verlauf x0.8 / x1.2, solange die Figur sich
-- nicht erholt (Muedigkeit ueber 0.5); Erholung doppelt, x1.5 / x0.5. Braucht
-- ein laufendes Spiel (Multiplier ueber 0).
function M.kaelteverlauf(p)
    local bd = p:getBodyDamage()
    local muede = statLesen(p, "FATIGUE")
    bd:setHasACold(true)
    bd:setColdStrength(50)
    bd:setColdReduction(0)
    statSetzen(p, "FATIGUE", 0.6)
    bd:UpdateCold()
    local v = bd:getColdStrength() - 50
    bd:setHasACold(false)
    bd:setColdStrength(0)
    bd:setColdReduction(0)
    statSetzen(p, "FATIGUE", muede)
    return v
end
function M.kaelteerholung(p)
    local bd = p:getBodyDamage()
    bd:setHasACold(true)
    bd:setColdStrength(50)
    bd:setColdReduction(1)
    bd:UpdateCold()
    local v = 50 - bd:getColdStrength()
    bd:setHasACold(false)
    bd:setColdStrength(0)
    bd:setColdReduction(0)
    return v
end

-- pickMortalityDuration (BodyDamage:1789-1807): Zeit von der Infektion bis
-- zum Tod; Resilient x1.25, Prone to Illness x0.75. Ohne Nebenwirkung.
function M.zombie(p)
    local bd, summe = p:getBodyDamage(), 0
    for _ = 1, TFMeasure.WERTE_PROBEN do summe = summe + bd:pickMortalityDuration() end
    return summe / TFMeasure.WERTE_PROBEN
end

-- Vanilla-Aktionen: :new rechnet die Dauer in maxTime und hat keine
-- Nebenwirkung; die Aktion kommt nie in die Warteschlange.
--   ISReadABook (shared/TimedActions/ISReadABook.lua:443-509): x0.7 / x1.3
--   ISResearchRecipe (ISResearchRecipe.lua:94-163): Fast / Slow Learner
--   ISInventoryTransferAction (client/TimedActions, 764-862): x0.5 / x2
--   ISBuildAction (257-272): Handy -50 von der Rezeptzeit, bei 200 also -25 %
--   ISBarricadeAction, ISUnbarricadeAction: 100 und 200 - 5 x Carpentry,
--     Handy -20; gemessen bei Carpentry 0
function M.lesen(p, z) return ISReadABook:new(p, z.buch).maxTime end
function M.forschen(p, z) return ISResearchRecipe:new(p, z.apfel).maxTime end
function M.umlagern(p, z) return ISInventoryTransferAction:new(p, z.hammer, p:getInventory(), z.tasche).maxTime end
function M.bauen(p) return ISBuildAction:new(p, nil, 0, 0, 0, false, "", 200).maxTime end
function M.barrikade(p) return ISBarricadeAction:new(p, nil, false, false).maxTime end
function M.abbauen(p) return ISUnbarricadeAction:new(p, nil).maxTime end

-- AddXP (IsoGameCharacter:15482-15563): Crafty x1.3 auf die Handwerks-Skills,
-- Reluctant Fighter x0.75 auf die Kampf-Skills. Boost 1 heisst Faktor 1.0;
-- danach wird die XP ohne Faktoren zurueckgenommen.
local function xpMessen(p, perk)
    local xp = p:getXp()
    local boost = xp:getPerkBoost(perk)
    xp:setPerkBoost(perk, 1)
    local vor = xp:getXP(perk)
    xp:AddXP(perk, 20, false, true, false)
    local v = xp:getXP(perk) - vor
    xp:AddXP(perk, -v, false, false, false)
    xp:setPerkBoost(perk, boost)
    return v
end
function M.xpcrafty(p) return xpMessen(p, Perks.Woodwork) end
function M.xppacifist(p) return xpMessen(p, Perks.Axe) end

local function woodworkNull(p, z)
    z.woodwork0 = p:getPerkLevel(Perks.Woodwork)
    stufeSetzen(p, Perks.Woodwork, 0)
end
local function woodworkZurueck(p, z)
    if z.woodwork0 then stufeSetzen(p, Perks.Woodwork, z.woodwork0) end
    z.woodwork0 = nil
end

-- ------------------------------------------------------------ seit 6.24.0
-- Feuer anzuenden, Leichen und Blut beim Umlagern, Verbinden, Lesen. Alles
-- Vanilla-Lua, aufgerufen wie im Spiel; was der Aufruf sonst noch taete,
-- faengt ein Stellvertreter ab, damit nichts wirklich brennt oder bricht.
-- Absichtlich ohne Fehler im Ablauf: das Spiel meldet einen Fehler auch
-- dann, wenn ein pcall ihn abfaengt (13.09.2026, reset() im Schlaf-Test).

--- ZombRand kurz ersetzt: schreibt jede Grenze n mit und liefert 1. Eine 0
-- hiesse Treffer (Feuer an, Anzuender kaputt); so tut die Aktion nichts.
function M.zufallsgrenzen(fn)
    local alt, grenzen = ZombRand, {}
    ZombRand = function(n) grenzen[#grenzen + 1] = n return 1 end
    local ok, err = pcall(fn)
    ZombRand = alt
    if not ok then error(err) end
    return grenzen
end

--- Eine Aktion ohne Warteschlange: getJobDelta und Co. fragen sonst die
-- Java-Aktion, die es nicht gibt. 0.5 liegt ueber der Schwelle 0.2 der
-- Anzuender.
function M.ohneWarteschlange(o)
    o.getJobDelta = function() return 0.5 end
    o.action = { getJobDelta = function() return 0.5 end, forceStop = function() end,
                 forceComplete = function() end }
    return o
end

-- ISBBQLightFromKindle:update (shared/TimedActions, Z. 34-39): ZombRand(300)
-- zum Anzuenden, ZombRand(300) zum Brechen; Outdoorsy 150 und 450. Den Trait
-- liest :new (Z. 154).
function M.grill(p, z)
    local o = M.ohneWarteschlange(ISBBQLightFromKindle:new(p, z.brett, z.anzuender, z.boden))
    return M.zufallsgrenzen(function() o:update() end)
end
function M.grillZuenden(p, z) return 1 / M.grill(p, z)[1] end
function M.grillBrechen(p, z) return 1 / M.grill(p, z)[2] end

-- ISLightFromKindle:updateKindling (shared/Camping/TimedActions, Z. 36-41):
-- dasselbe am Lagerfeuer, mit Bushcrafter oder Former Scout.
function M.lager(p, z)
    local o = M.ohneWarteschlange(ISLightFromKindle:new(p, z.brett, z.anzuender, nil))
    return M.zufallsgrenzen(function() o:updateKindling() end)
end
function M.lagerZuenden(p, z) return 1 / M.lager(p, z)[1] end
function M.lagerBrechen(p, z) return 1 / M.lager(p, z)[2] end

--- Die Chance ist 1/n, der Faktor mit/ohne also (1/150) / (1/300) = 2 und
-- (1/450) / (1/300) = 0.667. Der Grill dreht die Figur zum Boden.
function M.feuerVorher(p, z)
    z.brett = instanceItem("Base.Plank")
    z.anzuender = instanceItem("Base.Plank")
    z.boden = p:getCurrentSquare():getFloor()
    z.ausdauer0 = statLesen(p, "ENDURANCE")
end
function M.feuerNachher(p, z) statSetzen(p, "ENDURANCE", z.ausdauer0) end

-- ISInventoryTransferAction:update (client/TimedActions, Z. 129-144): aus
-- einer Leiche (Behaelter inventorymale) Unzufriedenheit rate / 100 je Tick,
-- rate = Multiplier; Cowardly x2, Brave /2, Desensitized gar nicht. Mit Fear
-- of Blood Stress getBloodLevelAdjustedLow x Multiplier / 10000, solange der
-- Gegenstand Blut traegt. Der Behaelter ist ein Stellvertreter: das Update
-- fragt nur getType und contains.
function M.umlagernUpdate(p, z, item, typ)
    local o = M.ohneWarteschlange(ISInventoryTransferAction:new(p, item, p:getInventory(), z.tasche))
    o.srcContainer = { getType = function() return typ end, contains = function() return true end }
    o:update()
end
function M.leiche(p, z)
    statSetzen(p, "UNHAPPINESS", 10)
    M.umlagernUpdate(p, z, z.hammer, "inventorymale")
    local v = statLesen(p, "UNHAPPINESS") - 10
    statSetzen(p, "UNHAPPINESS", z.unglueck0)
    return v
end
--- Geteilt durch Multiplier / 10000 bleibt der Blutwert des Gegenstands.
function M.blutsache(p, z)
    statSetzen(p, "STRESS", 0.1)
    local m = getGameTime():getMultiplier()
    M.umlagernUpdate(p, z, z.blutig, "none")
    local v = (statLesen(p, "STRESS") - 0.1) * 10000 / m
    statSetzen(p, "STRESS", z.stress0)
    return v
end
function M.umlagernVorher(p, z)
    z.hammer = instanceItem("Base.Hammer")
    z.blutig = instanceItem("Base.Axe")
    z.blutig:setBloodLevel(1.0)
    z.tasche = instanceItem("Base.Bag_Schoolbag"):getInventory()
    z.unglueck0, z.stress0 = statLesen(p, "UNHAPPINESS"), statLesen(p, "STRESS")
end

-- ISApplyBandage:complete (shared/TimedActions, Z. 105-106): mit Fear of
-- Blood +50 Panik, wenn die Wunde blutet. doIt false: kein Verband, nur der
-- Zweig ohne Binde; am Unterarm, der danach wieder heil ist.
function M.verbinden(p, z)
    local teil = unterarmVon(p)
    teil:RestoreToFullHealth()
    teil:setBleedingTime(5)
    statSetzen(p, "PANIC", 0)
    ISApplyBandage:new(p, p, z.binde, teil, false):complete()
    local v = statLesen(p, "PANIC")
    statSetzen(p, "PANIC", 0)
    teil:RestoreToFullHealth()
    return v
end

-- ISReadABook.checkLevel (shared/TimedActions, Z. 120-133): mit Illiterate
-- sind die gelesenen Seiten sofort wieder 0. Tischlern 1 bei Stufe 0, damit
-- die Stufenregel nicht selbst zuschlaegt; der Lesestand der Figur kommt
-- zurueck.
function M.lesenSeiten(p, z)
    local typ = z.buch:getFullType()
    local alt = p:getAlreadyReadPages(typ)
    z.buch:setAlreadyReadPages(5)
    ISReadABook.checkLevel(p, z.buch)
    local v = z.buch:getAlreadyReadPages()
    p:setAlreadyReadPages(typ, alt)
    return v
end

-- BodyDamage.JustAteFood (Offsets 555-661): rohes, gefaehrliches Essen
-- vergiftet ohne Wurf mit 15 x Portion, sobald die Chance ueber 0 liegt; 75,
-- bei Eiern 5, Iron Gut halbiert und setzt Eier auf 0. Base.Egg hat
-- DangerousUncooked und das Tag egg (food.txt:5416-5440). Nebenbei aendert
-- das Essen Langeweile, Unzufriedenheit und den Satt-Timer; alles zurueck.
function M.ei(p, z)
    local bd = p:getBodyDamage()
    local vorher = {}
    for _, name in ipairs({ "POISON", "PAIN", "BOREDOM", "UNHAPPINESS" }) do vorher[name] = statLesen(p, name) end
    local timer = bd:getHealthFromFoodTimer()
    statSetzen(p, "POISON", 0)
    bd:JustAteFood(instanceItem("Base.Egg"), 1.0, false)
    local v = statLesen(p, "POISON")
    for name, wert in pairs(vorher) do statSetzen(p, name, wert) end
    bd:setHealthFromFoodTimer(timer)
    return v
end

-- IsoPlayer.calculateCritChance (Offsets 225-442, 817): im Zweig fuer
-- Fernkampfwaffen nach Wetter- und Bewegungsabzug +10 mit Marksman, am Ende
-- auf 10 bis 90 geklemmt und abgeschnitten; ohne Zufall. Ziel ist die Figur
-- selbst (Abstand 0). Die Pistole bringt 20 + 6 je Aiming-Stufe
-- (weapon.txt:11002, 11018); bei Abstand 0 kam am 13.09.2026 mit Aiming 5
-- noch so viel dazu, dass ohne und mit Marksman 90 herauskam, die Klemme.
-- Seit 6.24.1 deshalb Aiming 0 und, falls ohne Trait noch ueber 70 bleibt,
-- eine laengere Zielverzoegerung (getAimDelayPenalty); welche, steht im
-- Bericht.
TFMeasure.KRIT_VERZUG = { 0, 5, 10, 20, 40, 80, 160 }
function M.krit(p, z)
    p:setAimingDelay(z.kritVerzug or 0)
    return p:calculateCritChance(p)
end
function M.kritVorher(p, z)
    z.hand0 = p:getPrimaryHandItem()
    z.aiming0 = p:getPerkLevel(Perks.Aiming)
    stufeSetzen(p, Perks.Aiming, 0)
    z.waffe = p:getInventory():AddItem("Base.Pistol")
    p:setPrimaryHandItem(z.waffe)
    -- Die Gruppe beginnt ohne Traits: die kleinste Verzoegerung, bei der die
    -- Chance ohne Marksman hoechstens 70 ist, damit +10 unter der Klemme bleibt.
    local chance = nil
    for _, verzug in ipairs(TFMeasure.KRIT_VERZUG) do
        z.kritVerzug = verzug
        p:setAimingDelay(verzug)
        chance = p:calculateCritChance(p)
        if chance <= 70 then break end
    end
    log("Code-Werte krit: Zielverzoegerung " .. tostring(z.kritVerzug) .. ", Chance ohne Marksman "
        .. tostring(chance))
end
function M.kritNachher(p, z)
    p:setPrimaryHandItem(z.hand0)
    if z.waffe then p:getInventory():Remove(z.waffe) end
    if z.aiming0 then stufeSetzen(p, Perks.Aiming, z.aiming0) end
    p:resetAimingDelay()
    z.waffe, z.hand0, z.aiming0 = nil, nil, nil
end

-- CraftRecipe.getResearchSkillLevel(chr): mit isInventive() -2, danach auf 0
-- bis 10 geklemmt. MakeImprovisedLighter hat Forschungsstufe 4
-- (recipes_electrical.txt:156-164), die -2 bleiben also sichtbar.
function M.forschungsstufe(p, z) return z.rezept:getResearchSkillLevel(p) end

-- ------------------------------------------------------------ seit 6.25.0
-- Zwei Spielfehler aus der Engine-Recherche (docs/befunde, spielfehler).
--
-- metallbarrikade: ISBarricadeAction:new (shared/TimedActions, Z. 191-194)
-- ruft getDuration, bevor es isMetal setzt; auch Metall dauert darum
-- 100 - 5 x Carpentry, Handy -20. Gemeint waere 170 - 5 x MetalWelding, mit
-- Handy also 150/170 = 0.882 statt 0.8. Carpentry und MetalWelding stehen
-- auf 0; ohne Trait zeigt der Bericht dann 100 statt 170.
function M.barrikadeMetall(p) return ISBarricadeAction:new(p, nil, true, false).maxTime end
function M.metallNull(p, z)
    woodworkNull(p, z)
    z.metall0 = p:getPerkLevel(Perks.MetalWelding)
    stufeSetzen(p, Perks.MetalWelding, 0)
end
function M.metallZurueck(p, z)
    woodworkZurueck(p, z)
    if z.metall0 then stufeSetzen(p, Perks.MetalWelding, z.metall0) end
    z.metall0 = nil
end

-- leichenstress-craft: ISCraftAction:update (shared/TimedActions, Z. 19-26)
-- gibt Unzufriedenheit rate / 100 je Tick, wenn der Gegenstand in einer
-- Leiche liegt, und fragt dafuer getContainer():getType() == "inventoryfemale"
-- oder getContainer() == "inventorymale". Der zweite Vergleich stellt den
-- Behaelter selbst einem Text gegenueber und ist nie wahr. Gemessen an einem
-- echten Behaelter (ItemContainer.new wie ISInventoryPage.lua:1531) mit einem
-- echten Hammer darin; nur die Aktion ist ein Stellvertreter ohne
-- Warteschlange und ohne Rezept, das Update fragt keins.
function M.craftUpdate(p, typ)
    local behaelter = ItemContainer.new(typ, nil, nil)
    local item = behaelter:AddItem("Base.Hammer")
    local o = M.ohneWarteschlange(setmetatable({ character = p, item = item }, { __index = ISCraftAction }))
    o:update()
end
--- Das Update gibt neben der Unzufriedenheit auch Stress (rate / 10000);
-- beides kommt zurueck, sonst behielte die Figur nach jedem Lauf etwas davon.
function M.craftLeiche(typ)
    return function(p, z)
        statSetzen(p, "UNHAPPINESS", 10)
        M.craftUpdate(p, typ)
        local v = statLesen(p, "UNHAPPINESS") - 10
        statSetzen(p, "UNHAPPINESS", z.unglueck0)
        statSetzen(p, "STRESS", z.stress0)
        return v
    end
end
function M.unglueckMerken(p, z) z.unglueck0, z.stress0 = statLesen(p, "UNHAPPINESS"), statLesen(p, "STRESS") end

-- ------------------------------------------------------------ seit 6.26.0
-- Drei Pakete aus docs/berichte/2026-09-13-messbarkeit.md. Jedes steht
-- zwischen seinen Markierungen, damit sie getrennt entstehen koennen.
--
-- Paket A: Stichproben ueber mehrere Ticks (Zaun, Sturz, Unfall).
-- [paket-a]
-- Stolpern am Zaun, Sturz und Unfall (docs/berichte/2026-09-13-messbarkeit.md,
-- Rang 1, 2 und 7). Alle drei wuerfelt das Spiel mit Rand, das sich aus Lua
-- nicht ersetzen laesst: also Stichproben. DoLand und
-- applyDamageFromVehicleHit rufen je Aufruf BodyDamage.Update; darum laufen
-- die Gruppen ueber mehrere Ticks (proben, jeTick, probe, auswerten; siehe
-- M.stichTick bei werteGruppe). Streuung eines Anteils sqrt(p (1 - p) / n).
TFMeasure.ZAUN = { proben = 3000, jeTick = 300, toleranz = 4 }
TFMeasure.STURZ = { tempo = 3.0, proben = 4000, jeTick = 125, toleranz = 6, last = 0.75, frei = 3 }
TFMeasure.UNFALL = { schaden = 30, proben = 1200, jeTick = 50, skript = "Base.CarNormal", stufe = 3 }

--- Ein Wert aus den Sandbox-Optionen, wie dragDownSetzen ihn liest; nil,
-- wenn es die Option nicht gibt.
function M.sandboxWert(name)
    local wert = nil
    pcall(function()
        local option = getSandboxOptions():getOptionByName(name)
        if option then wert = option:getValue() end
    end)
    return wert
end

--- Anteil der Einsen in Prozent.
function M.anteilProzent(liste)
    if #liste == 0 then return nil end
    local summe = 0
    for _, v in ipairs(liste) do summe = summe + v end
    return 100 * summe / #liste
end

-- ------------------------------------------------ Stolpern am Zaun
-- ClimbOverFenceState (Build 42.20): das oeffentliche enter (Z. 92-133)
-- wuerfelt shouldFallAfterVaultOver (privat, Z. 493-530), sobald die Variable
-- VaultOverRun oder VaultOverSprint gesetzt ist (Z. 110), und schreibt dann
-- "fall" in ClimbFenceOutcome (Z. 111). Chance 10 fuer den Sprung aus dem
-- Sprint (Z. 499-501), dazu Moodles (Z. 502-507) und Unterkoerper-Schmerz
-- (Z. 508-510), fuer alle Faelle gleich, Traits (Z. 511-528) und minus
-- Fitness (Z. 529): Clumsy +10, Graceful -10, Very Underweight +20 und gleich
-- noch einmal +10 (Z. 517 und 520, Spielfehler zaun-veryunderweight), Obese
-- +20, Overweight +10; Underweight kommt nicht vor. setParams (public,
-- Z. 581-630) setzt vorher SOLID_FLOOR aus dem Feld in Richtung dir; ohne
-- Boden setzt enter "falling" (Z. 118-120) und verdeckt den Wurf. RUN und
-- SPRINT nimmt setParams von der stehenden Figur (falsch: kein Ausdauerabzug,
-- Z. 97-103). exit (Z. 227-240) raeumt die Variablen und gibt die Bewegung
-- frei. Je enter feuert triggerMusicIntensityEvent("HopFence") (Z. 124-127).
-- Ein Zaun ist nicht noetig. Zeilen nach dem CFR-Baum mit Kopfzeilen
-- (Faktensweep 2, 23.09.2026; vorher je 3 zu niedrig).
function M.zaunVersuch(p, st, richtung)
    st:setParams(p, richtung)
    p:setVariable("VaultOverSprint", true)
    st:enter(p)
    local ausgang = p:getVariableString("ClimbFenceOutcome")
    st:exit(p)
    return ausgang
end

--- Fitness 0 (sie zieht ab, und Graceful laege sonst unter 0, wo nichts
-- mehr faellt) und eine Richtung mit Boden: je ein Versuch nach N, S, W, E,
-- der erste ohne "falling" oder "rope" (Z. 118-123) gilt.
function M.zaunVorher(p, z)
    z.zaunFitness0 = p:getPerkLevel(Perks.Fitness)
    stufeSetzen(p, Perks.Fitness, 0)
    z.zaunRichtung, z.zaunGrund = nil, nil
    if not (ClimbOverFenceState and ClimbOverFenceState.instance and IsoDirections) then
        z.zaunGrund = "ClimbOverFenceState fehlt"
        return
    end
    z.zaunZustand = ClimbOverFenceState.instance()
    for _, richtung in ipairs({ IsoDirections.N, IsoDirections.S, IsoDirections.W, IsoDirections.E }) do
        local ausgang = M.zaunVersuch(p, z.zaunZustand, richtung)
        if ausgang ~= "falling" and ausgang ~= "rope" then
            z.zaunRichtung = richtung
            break
        end
    end
    if not z.zaunRichtung then z.zaunGrund = "kein Feld mit Boden neben der Figur" end
end

function M.zaunNachher(p, z)
    if z.zaunFitness0 then stufeSetzen(p, Perks.Fitness, z.zaunFitness0) end
    z.zaunFitness0, z.zaunZustand, z.zaunRichtung, z.zaunGrund = nil, nil, nil, nil
end

--- Eine Probe: 1 gestolpert, 0 nicht. Rennt oder sprintet die Figur, zaehlt
-- sie nicht: setParams naehme RUN oder SPRINT mit, und enter zoege Ausdauer ab.
function M.zaunProbe(p, z)
    if not z.zaunRichtung then return nil, z.zaunGrund end
    if p:isRunning() or p:isSprinting() then return nil, "Figur rennt" end
    local ausgang = M.zaunVersuch(p, z.zaunZustand, z.zaunRichtung)
    -- Ohne Boden in der Richtung ("falling", "rope", Z. 118-123) verdeckt enter
    -- den Wurf; das passiert, wenn die Figur waehrend der Gruppe weitergeht.
    if ausgang == "falling" or ausgang == "rope" then return nil, "kein Boden in der Richtung" end
    return (ausgang == "fall") and 1 or 0
end

-- ------------------------------------------------ Sturz
-- IsoGameCharacter (Build 42.20): DoLand (public, Z. 2042-2054) ruft
-- handleLandingImpact (protected, Z. 2056-2160). Tempo 3.0 ist ein leichter
-- Sturz mit Schaden (FallingConstants Z. 14-18: Schaden ab 2.236, hart ab
-- 3.873): kein fallenOnKnees, kein dropHandItems, nur helmetFall(false)
-- (Z. 2098-2103). Schaden = lerpFunc_EaseOutQuad(3.0 / 3.873) = 0.600 x 115 x
-- U(0.5, 1) x Last (getCapacityWeight / getMaxWeight, Z. 2074-2076) x 0.8 auf
-- Gras x Trait (Obese, Emaciated 1.4; Overweight, Very Underweight 1.2;
-- Z. 2083-2087) x (1 - 0.05 Fitness) x (1 - 0.05 Nimble) x
-- FallingWhileInjured (nach RestoreToFullHealth 1). Mit 1/80 ist er 0
-- (unscratch, Z. 2068, auf Gras noch 1/65): dann kein Ereignis, die Probe
-- zaehlt nicht. Den Schaden meldet das Spiel ueber
-- OnPlayerGetDamage(figur, "FALLDOWN", schaden) (Z. 2117).
-- Danach verletzt Rand.Next(100) < Schaden (Z. 2121) ein Bein (Z. 2136):
-- Bruch mit rand / 100, sonst tiefe Wunde mit (rand + 10) / 100, sonst
-- Steifheit 100 (Z. 2137-2146); rand = (int)(0.600 x 55) = 32, +20
-- Obese/Emaciated, +10 Overweight/Very Underweight (Z. 2127-2131), Fitness
-- ueber 4 und Nimble ziehen ab (Z. 2132-2135), weniger als 2 frei legt dazu
-- (Z. 2124-2126). Jeder neue Bruch spielt "FirstAidFracture" (BodyPart
-- Z. 822-824), ueber 5 Schaden kommt ein Schmerzlaut
-- (playPainVoicesFromFallDamage, IsoPlayer Z. 2591-2594; playerVoiceSound
-- spielt ihn nicht doppelt, Z. 6676-6682).
-- PZMath.lerpFunc_EaseOutQuad rechnet x * x (Bytecode fload_0 fload_0
-- fmul), die Namen von EaseIn und EaseOut sind im Spiel vertauscht. Der
-- Messplan rechnete mit 1 - (1 - x)^2 = 0.949 und erwartete 52 % Brueche;
-- gemessen und laut Bytecode richtig sind 32 % (Recherche 14.09.2026).
-- God Mode bleibt an: das Update in Z. 2114 heilt dann sofort
-- (BodyDamage.Update Z. 1821-1825), die Verletzung danach steht, bis die
-- Probe sie gelesen hat; die Figur kann so nicht sterben.

--- Merkt den Schaden der wartenden Probe (Ereignis am Ende der Datei
-- angemeldet). Das Spiel meldet ueber OnPlayerGetDamage auch Blutungen je
-- Bild (BodyPart Z. 164), darum nur FALLDOWN und nur, solange eine Probe
-- wartet.
function TFMeasure.sturzHoeren(wer, art, menge)
    if TFMeasure.sturzWert == false and art == "FALLDOWN" then TFMeasure.sturzWert = menge end
end

--- "unsichtbar" ist der Ghost Mode (IsoPlayer.isGhostMode = isInvisible, Z.
-- 1055-1057); im Debug-Modus meldet getCapacityWeight dann 0, ebenso mit
-- unbegrenztem Tragen (ItemContainer Z. 2134-2144), und jeder Schaden waere 0.
-- Fitness und Nimble auf 0 (Schaden und rand, siehe oben). Kopfbedeckungen
-- mit getChanceToFall > 0 ab: helmetFall(false) wirft sie sonst mit dieser
-- Chance je Probe auf den Boden (Z. 7542-7566). Last: ein Brett mit festem
-- Gewicht bis 0.75 x getMaxWeight, mindestens 3 frei.
function M.sturzVorher(p, z)
    local s = { huete = {} }
    z.sturz = s
    p:setInvisible(false)
    if p:isUnlimitedCarry() then
        s.tragen = true
        p:setUnlimitedCarry(false)
    end
    p:setGodMod(true)
    s.fitness0, s.nimble0 = p:getPerkLevel(Perks.Fitness), p:getPerkLevel(Perks.Nimble)
    stufeSetzen(p, Perks.Fitness, 0)
    stufeSetzen(p, Perks.Nimble, 0)
    local getragen = p:getWornItems()
    if getragen then
        for i = 0, getragen:size() - 1 do
            local item = getragen:getItemByIndex(i)
            if item and instanceof(item, "Clothing") and item:getChanceToFall() > 0 then
                s.huete[#s.huete + 1] = item
            end
        end
    end
    for _, item in ipairs(s.huete) do p:removeWornItem(item) end
    local inv = p:getInventory()
    local max = inv:getMaxWeight()
    local fehlt = math.min(TFMeasure.STURZ.last * max, max - TFMeasure.STURZ.frei) - inv:getCapacityWeight()
    if fehlt > 0.1 then
        s.brett = inv:AddItem("Base.Plank")
        if s.brett then s.brett:setActualWeight(fehlt) end
    end
    s.last = (max > 0) and (inv:getCapacityWeight() / max) or 0
    TFMeasure.sturzWert = nil
    -- Am 14.09.2026 stand hier 0.51 und 0.34 statt 0.75. Die Zahlen dahinter
    -- im Log klaeren beim naechsten Lauf, woran es liegt; das Ergebnis
    -- aendert die Last nicht (Faktor aus den Maxima, Anteil aus rand).
    local kg = 0
    if s.brett then pcall(function() kg = s.brett:getActualWeight() end) end
    log(string.format("Code-Werte sturz: Last %.2f von getMaxWeight, %d Kopfbedeckung(en) abgenommen"
        .. " (getCapacityWeight %.2f, getMaxWeight %.2f, fehlte %.2f, Brett %.2f kg)",
        s.last, #s.huete, inv:getCapacityWeight(), max, fehlt, kg))
end

function M.sturzNachher(p, z)
    local s = z.sturz
    z.sturz = nil
    TFMeasure.sturzWert = nil
    if not s then return end
    pcall(function() p:getBodyDamage():RestoreToFullHealth() end)
    pcall(function() p:clearFallDamage() end)
    if s.brett then pcall(function() p:getInventory():Remove(s.brett) end) end
    for _, item in ipairs(s.huete) do
        pcall(function()
            if p:getInventory():contains(item) then p:setWornItem(item:getBodyLocation(), item) end
        end)
    end
    if s.fitness0 then pcall(stufeSetzen, p, Perks.Fitness, s.fitness0) end
    if s.nimble0 then pcall(stufeSetzen, p, Perks.Nimble, s.nimble0) end
    if s.tragen then pcall(function() p:setUnlimitedCarry(true) end) end
    pcall(function() p:setGodMod(TFMeasure.cheatStand.god ~= false) end)
    pcall(function() p:setInvisible(TFMeasure.cheatStand.unsichtbar ~= false) end)
end

--- Was die Probe verletzt hat: "bruch" vor "tief" vor "steif", nil wenn nichts.
function M.sturzArt(bd)
    local art = nil
    for i = 0, BodyPartType.ToIndex(BodyPartType.MAX) - 1 do
        local teil = bd:getBodyPart(BodyPartType.FromIndex(i))
        if teil:getFractureTime() > 0 then return "bruch" end
        if teil:isDeepWounded() then
            art = "tief"
        elseif not art and teil:getStiffness() >= 100 then
            art = "steif"
        end
    end
    return art
end

--- Eine Landung. Danach steht sie noch in fallDamage (FallDamage
-- .setLandingImpact) und damit in der Animationsvariablen bLandLight;
-- clearFallDamage (Z. 2034-2036) nimmt sie weg.
function M.sturzProbe(p, z)
    if not TFMeasure.sturzAngemeldet then return nil, "OnPlayerGetDamage fehlt" end
    if not z.sturz or z.sturz.last <= 0 then return nil, "Inventar ohne Gewicht" end
    local bd = p:getBodyDamage()
    bd:RestoreToFullHealth()
    TFMeasure.sturzWert = false
    p:DoLand(TFMeasure.STURZ.tempo)
    local wert = TFMeasure.sturzWert
    TFMeasure.sturzWert = nil
    p:clearFallDamage()
    local art = nil
    if type(wert) == "number" then art = M.sturzArt(bd) end
    bd:RestoreToFullHealth()
    if type(wert) ~= "number" then return nil end
    return { schaden = wert, art = art }
end

--- falldamage: der groesste Schaden je Fall. U(0.5, 1) erreicht bei ueber
-- 3000 Proben sein oberes Ende auf 0.02 %, das Verhaeltnis der Maxima ist
-- also der Trait-Faktor; das Mittel schwankt um 19 % je Probe.
function M.sturzGroesster(liste)
    local gross = nil
    for _, v in ipairs(liste) do
        if not gross or v.schaden > gross then gross = v.schaden end
    end
    return gross
end

--- fallinjury: Anteil Brueche unter den verletzten Proben, in Prozent.
function M.sturzBruchAnteil(liste)
    if M.sandboxWert("BoneFracture") == false then return nil, "Sandbox: Knochenbrueche aus" end
    local verletzt, bruch = 0, 0
    for _, v in ipairs(liste) do
        if v.art then
            verletzt = verletzt + 1
            if v.art == "bruch" then bruch = bruch + 1 end
        end
    end
    if verletzt == 0 then return nil, "keine Verletzung" end
    return 100 * bruch / verletzt
end

-- ------------------------------------------------ Unfall
-- IsoPlayer.applyDamageFromVehicleHit (public, Z. 1960-1997). Das Fahrzeug
-- dient nur CombatManager.checkPVP (Z. 1499-1507): ohne Fahrer wahr, ausser
-- die Figur hat God Mode (Z. 1502-1503); God Mode also aus. Schaden d =
-- damage x DamageToPlayerFromHitByACar (Z. 1964; DamageModifier NONE 0, LOW
-- 0.5, STANDARD 1, HIGH 2, EXTREME 5, Option 1 bis 5). Voreinstellung ist NONE
-- (SandboxOptions.<init>), auch in allen Vanilla-Presets
-- (media/lua/shared/Sandbox, = 1): dann gaebe es gar keinen Schaden. Die
-- Gruppe stellt die Option fuer ihre Dauer auf 3 (Normal). (int)(2 + d x
-- 0.07) Teile (Z. 1968), je max(U(d - 15, d), 5) x 0.8 (Fast Healer) oder 1.2
-- (Slow Healer) x InjurySeverity x 0.9 (Z. 1972-1979) ueber AddDamage
-- (BodyPart Z. 130-132, 450-452). Mit d = 30: 4 Teile zu je 10.8 bis 32.4.
-- Gemessen: Summe der verlorenen Gesundheit aller Teile; je Probe schwankt
-- sie um 9.6 %. Das eine BodyDamage.Update je Aufruf (Z. 1992) heilt nur
-- 0.002 x Multiplier (BodyDamage Z. 1907, 1928), ein Bruch kostet darin
-- 0.018 (BodyPart Z. 179-181), beides vernachlaessigbar.
-- Brueche setzt der Aufruf direkt ueber generateFracture (Z. 1983-1990) mit
-- VehicleHitDamageConstants.generateFractureTime (Z. 8409-8413) bzw.
-- generateFractureTimeGroin fuer die Beine (Z. 8415-8419), ohne den
-- Trait-Faktor von generateFractureNew (Spielfehler unfallbruch). Jeder neue
-- Bruch spielt "FirstAidFracture" (BodyPart Z. 822-824).
-- vehicleSpeed dient nur addBloodFromVehicleImpact (Z. 1993); das kehrt bei
-- Rand.Next(10) > speed zurueck (IsoGameCharacter Z. 13326-13329), mit -1
-- also immer: kein Blut.
function M.unfallVorher(p, z)
    local u = {}
    z.unfall = u
    local stufe = TFMeasure.UNFALL.stufe
    u.stufe0 = M.sandboxWert("DamageToPlayerFromHitByACar")
    if u.stufe0 ~= stufe then
        u.stufeGesetzt = true
        pcall(function() getSandboxOptions():set("DamageToPlayerFromHitByACar", stufe) end)
    end
    if M.sandboxWert("DamageToPlayerFromHitByACar") ~= stufe then
        u.grund = "Sandbox DamageToPlayerFromHitByACar liess sich nicht setzen"
    end
    p:setGodMod(false)
    -- Wie TFMeasure.autoSetzen: addVehicle neben der Figur, danach wieder weg.
    pcall(function() u.auto = addVehicle(TFMeasure.UNFALL.skript, p:getX() + 2, p:getY(), p:getZ()) end)
    if not u.auto then u.grund = u.grund or "kein Fahrzeug gesetzt" end
end

function M.unfallNachher(p, z)
    local u = z.unfall
    z.unfall = nil
    if not u then return end
    pcall(function() p:getBodyDamage():RestoreToFullHealth() end)
    if u.auto then pcall(function() u.auto:permanentlyRemove() end) end
    if u.stufeGesetzt and u.stufe0 then
        pcall(function() getSandboxOptions():set("DamageToPlayerFromHitByACar", u.stufe0) end)
    end
    pcall(function() p:setGodMod(TFMeasure.cheatStand.god ~= false) end)
end

function M.unfallProbe(p, z)
    local u = z.unfall
    if not u then return nil, "Aufbau fehlt" end
    if u.grund then return nil, u.grund end
    local bd = p:getBodyDamage()
    bd:RestoreToFullHealth()
    p:applyDamageFromVehicleHit(u.auto, -1, TFMeasure.UNFALL.schaden)
    local verlust, brueche = 0, {}
    for i = 0, BodyPartType.ToIndex(BodyPartType.MAX) - 1 do
        local teil = bd:getBodyPart(BodyPartType.FromIndex(i))
        verlust = verlust + (100 - teil:getHealth())
        if teil:getFractureTime() > 0 then brueche[#brueche + 1] = teil:getFractureTime() end
    end
    bd:RestoreToFullHealth()
    if verlust <= 0 then return nil, "kein Schaden (God Mode oder Sandbox)" end
    return { verlust = verlust, brueche = brueche }
end

--- vehdamage: mittlere verlorene Gesundheit je Aufprall.
function M.unfallVerlust(liste)
    if #liste == 0 then return nil end
    local summe = 0
    for _, v in ipairs(liste) do summe = summe + v.verlust end
    return summe / #liste
end

--- unfallbruch: mittlere Bruchzeit ueber alle Brueche des Falls.
function M.unfallBruchzeit(liste)
    local summe, n = 0, 0
    for _, v in ipairs(liste) do
        for _, zeit in ipairs(v.brueche) do
            summe = summe + zeit
            n = n + 1
        end
    end
    if n == 0 then return nil, "kein Bruch (Sandbox Knochenbrueche aus?)" end
    return summe / n
end

--- Erwartete Bruchzeit je Bruch (IsoPlayer Z. 1970-1990, 8409-8419), Mittel
-- ueber r = max(U(d - 15, d), 5) x f x s x 0.9. Je Treffer: Bein (6 von 17
-- Teilen) mit 61/100 die Groin-Zeit (ueberschreibt), sonst mit 39/100 x
-- 11/100 die normale; Kopf (1/17) die normale mit 1 - 89/100 x (1 - 81/100
-- bei r > 30); die uebrigen 10/17 mit 11/100. Alles nur bei r > 10. Eine
-- Zeit ist U(U(10, r + 10), U(r + 20, r + 30)), im Mittel 17.5 + 0.75 r;
-- fuer Beine U(U(10, r + 20), U(r + 30, r + 40)), 25 + 0.75 r. Mit d = 30,
-- s = 1: Fast Healer x0.9202, Slow Healer x1.0798 (Monte-Carlo mit
-- Ueberschneidungen am selben Teil 13.09.2026: 0.9199 und 1.0814), statt der
-- 0.6 und 1.8 aus generateFractureNew.
function M.unfallZeitErwartet(f, d, s)
    local num, den, schritte = 0, 0, 600
    for i = 1, schritte do
        local r = math.max((d - 15) + 15 * (i - 0.5) / schritte, 5) * f * s * 0.9
        if r > 10 then
            local kopf = 1 - 0.89 * (1 - ((r > 30) and 0.81 or 0))
            local wBein = 6 / 17 * 0.61
            local wNormal = 6 / 17 * 0.39 * 0.11 + 10 / 17 * 0.11 + 1 / 17 * kopf
            num = num + wBein * (25 + 0.75 * r) + wNormal * (17.5 + 0.75 * r)
            den = den + wBein + wNormal
        end
    end
    if den == 0 then return nil end
    return num / den
end

--- Der Faktor laut Code als Funktion: er haengt an InjurySeverity (Option
-- 1 bis 3, x0.5, x1, x1.5, wie generateFractureNew Z. 834-842).
function M.unfallBruchSoll(f)
    return function()
        local stufe = M.sandboxWert("InjurySeverity")
        local s = 1.0
        if stufe == 1 then s = 0.5 elseif stufe == 3 then s = 1.5 end
        local d = TFMeasure.UNFALL.schaden
        local mit, ohne = M.unfallZeitErwartet(f, d, s), M.unfallZeitErwartet(1, d, s)
        if not mit or not ohne then return nil end
        return mit / ohne
    end
end
-- [/paket-a]
--
-- Paket B: genaue Werte (Short Sighted, Gewicht, Ladehemmung, Lua-Regeln,
-- Nikotin, Wind, Menue und Tooltip, Bleiche).
-- [paket-b]
-- Alles in einem Tick und ohne Fehler im Ablauf: kann eine Gruppe an dieser
-- Figur nicht messen (Brille, Sandbox, kein Aussenfeld), gibt messen einen
-- Text statt einer Zahl zurueck. Die Zeile heisst dann "nicht messbar" und
-- traegt den Text als Notiz ("ohne Trait: nicht messbar: ...").

--- Short Sighted wirkt nur ohne Brille; mit Brille dreht updateVisionEffects
-- die Regel sogar um (IsoGameCharacter Z. 14112-14116).
function M.kurzsichtBrille(p)
    if p:isWearingGlasses() then return "nicht messbar: die Figur traegt eine Brille" end
    return nil
end

-- Short Sighted, Sichtweite: HandWeapon.getMaxSightRange(chr) (Z. 1488-1493)
-- gibt mit Short Sighted ohne Brille getMinSightRange(chr) zurueck
-- (Z. 1476-1478). Faktor mit/ohne = min/max; der Sollwert rechnet beide an
-- derselben Figur nach der Messung (Aiming geht in beide ein).
function M.sichtKurz(p, z) return M.kurzsichtBrille(p) or z.gewehr:getMaxSightRange(p) end
function M.sichtKurzSoll(p, z) return z.gewehr:getMinSightRange(p) / z.gewehr:getMaxSightRange(p) end

-- Short Sighted, Unschaerfe: updateVisionEffects (IsoGameCharacter
-- Z. 14112-14116) setzt das Ziel auf 1 mit Short Sighted ohne Brille, sonst
-- 0; updateVisionEffectTargets (Z. 14108-14110) naehert blurFactor um 0.1
-- an, abwaerts um 0.01. 3000 Aufrufe reichen in beide Richtungen
-- (0.99^3000 ~ 1e-13). Alles im selben Tick, das Bild sieht die Unschaerfe
-- nie; nachher laeuft dasselbe ohne Trait, damit die Figur scharf bleibt,
-- aber nicht mit Brille: dort waere das Ziel ohne Trait 1 (Z. 14115). Das
-- Ziel der echten Figur setzt am Ende werteTraitsZurueck.
TFMeasure.UNSCHAERFE_SCHRITTE = 3000
function M.unschaerfeAngleichen(p)
    p:updateVisionEffects()
    for _ = 1, TFMeasure.UNSCHAERFE_SCHRITTE do p:updateVisionEffectTargets() end
    return p:getBlurFactor()
end
function M.unschaerfe(p) return M.kurzsichtBrille(p) or M.unschaerfeAngleichen(p) end

-- God Mode aus fuer eine Gruppe, danach wie das Kaestchen im Messfenster.
function M.godAus(p, z)
    z.godAusB = true
    pcall(function() p:setGodMod(false) end)
end
function M.godZurueck(p, z)
    if z.godAusB then pcall(function() p:setGodMod(TFMeasure.cheatStand.god ~= false) end) end
    z.godAusB = nil
end

-- Gewichtszunahme: Nutrition.update (Z. 61-78) ruft updateWeight
-- (Z. 115-167): zunehmen, wenn die Kalorien ueber 1000 + (Gewicht - 80) x 40
-- liegen; Weight Gain 700 (unter 90 kg, Z. 122-124), Weight Loss 1800 (ueber
-- 70 kg, Z. 125-127). Bei 80 kg also 1000, 700, 1800, gesucht per Bisektion
-- ueber isIncWeight. update zieht vorher die Kalorien eines Updates ab
-- (Z. 72-75); das ist mit und ohne Trait dasselbe und faellt in der
-- Differenz heraus. update kehrt ohne Sandbox Nutrition (Z. 62) und mit God
-- Mode (Z. 68) sofort zurueck; setCalories klemmt auf -2200 bis 3700
-- (Z. 272-280). 24 Schritte: 3700 / 2^24 = 0.0002 Kalorien. Danach Gewicht,
-- Kalorien und Naehrstoffe zurueck; updatedWeight zaehlt je Aufruf eins hoch
-- (Z. 161), erst bei 2000 setzt das Spiel die Gewichts-Traits neu.
TFMeasure.GEWICHT_SCHRITTE = 24
function M.gewichtProbe(n, kalorien)
    n:setWeight(80)
    n:setCalories(kalorien)
    n:update()
    return n:isIncWeight()
end
function M.zunahme(p)
    if SandboxVars and SandboxVars.Nutrition == false then return "nicht messbar: Sandbox Nutrition aus" end
    if p:isGodMod() then return "nicht messbar: God Mode ist an" end
    local n = p:getNutrition()
    local alt = { n:getWeight(), n:getCalories(), n:getCarbohydrates(), n:getLipids(), n:getProteins(),
                  n:isIncWeight(), n:isIncWeightLot(), n:isDecWeight() }
    local lo, hi, v = 0, 3700, nil
    if M.gewichtProbe(n, lo) or not M.gewichtProbe(n, hi) then
        v = "nicht messbar: isIncWeight folgt den Kalorien nicht"
    else
        for _ = 1, TFMeasure.GEWICHT_SCHRITTE do
            local mitte = (lo + hi) / 2
            if M.gewichtProbe(n, mitte) then hi = mitte else lo = mitte end
        end
        v = hi
    end
    n:setWeight(alt[1])
    n:setCalories(alt[2])
    n:setCarbohydrates(alt[3])
    n:setLipids(alt[4])
    n:setProteins(alt[5])
    n:setIncWeight(alt[6])
    n:setIncWeightLot(alt[7])
    n:setDecWeight(alt[8])
    return v
end

-- Ladehemmung: HandWeapon.checkUnJam (Z. 2038-2054) bleibt haengen mit
-- 8 - 0.5 x Aiming + 3 x (Panik + Stress + Rausch), Dextrous -2, All Thumbs
-- +2, mindestens 1, plus Verschleiss (Max - Zustand) / (8 x Zustand / Max),
-- in Prozent; gewuerfelt mit Rand.Next(0, 1). Neue Pistole (Zustand voll),
-- Aiming 0, Panik, Stress und Rausch 0: geloest 92 %, 94 %, 90 %. 20000
-- Proben je Fall, Streuung 0.19 Punkte. Jede Loesung spielt shellFallSound
-- (Z. 2049-2051); die Probe-Pistole hat fuer die Messung keinen.
TFMeasure.HEMMUNG_PROBEN = 20000
TFMeasure.HEMMUNG_STATS = { "PANIC", "STRESS", "INTOXICATION" }
function M.hemmung(p, z)
    local geloest = 0
    for _ = 1, TFMeasure.HEMMUNG_PROBEN do
        z.pistole:setJammed(true)
        if not z.pistole:checkUnJam(p) then geloest = geloest + 1 end
    end
    z.pistole:setJammed(false)
    return 100 * geloest / TFMeasure.HEMMUNG_PROBEN
end
function M.hemmungVorher(p, z)
    z.pistole = instanceItem("Base.Pistol")
    z.schall = z.pistole:getShellFallSound()
    z.pistole:setShellFallSound(nil)
    z.aimingHemmung = p:getPerkLevel(Perks.Aiming)
    stufeSetzen(p, Perks.Aiming, 0)
    z.gemuetHemmung = {}
    for _, name in ipairs(TFMeasure.HEMMUNG_STATS) do
        z.gemuetHemmung[name] = statLesen(p, name)
        statSetzen(p, name, 0)
    end
    p:getMoodles():Update()
    -- checkUnJam schreibt je Aufruf eine Zeile in den Kanal Combat
    -- (DebugType.Combat.debugln, Offsets 129-172); mit -debug waeren das
    -- 60000 Zeilen je Lauf. Fuer die Gruppe steht der Kanal auf Off, wie
    -- ihn Vanillas DebugLogSettings.lua:32 setzt; nachher zurueck.
    if DebugType and DebugType.Combat and LogSeverity and LogSeverity.Off then
        z.combatStufe = DebugType.Combat:getLogSeverity()
        DebugType.Combat:setLogSeverity(LogSeverity.Off)
    end
end
function M.hemmungNachher(p, z)
    if z.gemuetHemmung then
        for name, wert in pairs(z.gemuetHemmung) do statSetzen(p, name, wert) end
        p:getMoodles():Update()
    end
    if z.aimingHemmung then stufeSetzen(p, Perks.Aiming, z.aimingHemmung) end
    if z.pistole then z.pistole:setShellFallSound(z.schall) end
    if z.combatStufe then DebugType.Combat:setLogSeverity(z.combatStufe) end
    z.pistole, z.schall, z.aimingHemmung, z.gemuetHemmung, z.combatStufe = nil, nil, nil, nil, nil
end

-- Disorganized: ISCraftingUI.ReturnItemToContainer (client/ISUI/
-- ISCraftingUI.lua Z. 13-23) kehrt mit dem Trait sofort zurueck (Z. 15);
-- ohne ihn stellt es eine Umlager-Aktion in die Warteschlange (Z. 18-21).
-- ISTimedActionQueue.add zaehlt fuer den einen Aufruf nur mit, wie der
-- ZombRand-Kniff beim Feuer; die Aktion selbst ist nur ein :new.
function M.zutaten(p, z)
    if not (ISCraftingUI and ISCraftingUI.ReturnItemToContainer and ISTimedActionQueue) then
        return "nicht messbar: ISCraftingUI.ReturnItemToContainer fehlt"
    end
    local alt, n = ISTimedActionQueue.add, 0
    ISTimedActionQueue.add = function() n = n + 1 end
    local ok = pcall(ISCraftingUI.ReturnItemToContainer, p, z.hammer, z.tasche)
    ISTimedActionQueue.add = alt
    if not ok then return "nicht messbar: ReturnItemToContainer brach ab" end
    return n
end

-- All Thumbs beim Craften: ISHandcraftAction:new (shared/Entity/
-- TimedActions/ISHandcraftAction.lua Z. 391-419) setzt stopOnWalk = not
-- isCanWalk() und mit All Thumbs oder klobigen Handschuhen immer true
-- (Z. 405-408). manualInputs muss eine Tabelle sein: convertToPZNetTable
-- (Z. 400; LuaManager Z. 2827-2834) liest sie ohne nil-Pruefung. getDuration
-- (Z. 253-261) fragt nur das Rezept; ohne Warteschlange passiert nichts.
function M.rezeptZumGehen()
    local alle = getScriptManager():getAllCraftRecipes()
    for i = 0, alle:size() - 1 do
        local r = alle:get(i)
        if r:isCanWalk() then return r end
    end
    return nil
end
function M.gehen(p, z)
    -- Am 14.09.2026: kein Rezept in 42.20 setzt CanWalk (CraftRecipe.Load,
    -- Offsets 1345-1363; media/scripts ohne Treffer). stopOnWalk ist dann
    -- fuer jede Figur wahr, All Thumbs aendert daran nichts.
    if not z.rezeptGehen then
        return "nicht messbar: kein Rezept setzt CanWalk, Handwerk bricht beim Gehen immer ab"
    end
    if p:isWearingAwkwardGloves() then return "nicht messbar: klobige Handschuhe an" end
    local o = ISHandcraftAction:new(p, z.rezeptGehen, nil, nil, nil, {}, nil, nil, 1, nil)
    return o.stopOnWalk and 1 or 0
end

-- Inventive: CraftRecipe.checkAutoLearnAnySkills(chr) (Z. 877-889) lernt
-- das Rezept, sobald validateHasAutoLearnAnySkill (Z. 905-919) passt; mit
-- isInventive() zaehlt jede Stufe eins weniger, mindestens 1. Gemessen die
-- kleinste Stufe, bei der das Rezept gelernt wird, an einem Rezept mit genau
-- einem Skill ab Stufe 2 (sonst schneidet max(1, ...) ab), das die Figur
-- noch nicht kennt. Danach vergisst die Figur es wieder (getKnownRecipes,
-- Java-Liste, remove mit dem Namen; learnRecipe Z. 10587-10596 legt genau
-- den Namen ab). setPerkLevelDebug (Z. 4487-4500) loest kein LevelPerk aus,
-- also lernt die Figur dabei nichts anderes. Je Lernen eine DebugLog-Zeile
-- (Z. 884).
function M.lernRezept(p)
    local alle = getScriptManager():getAllCraftRecipes()
    for i = 0, alle:size() - 1 do
        local r = alle:get(i)
        if r:needToBeLearn() and r:getAutoLearnAnySkillCount() == 1 and not p:isRecipeActuallyKnown(r) then
            local s = r:getAutoLearnAnySkill(0)
            local perk = s:getPerk()
            if s:getLevel() >= 2 and s:getLevel() <= 10 and perk ~= Perks.Fitness and perk ~= Perks.Strength then
                return r, perk, s:getLevel()
            end
        end
    end
    return nil
end
function M.lernVorher(p, z)
    local stufe
    z.rezeptLernen, z.lernPerk, stufe = M.lernRezept(p)
    if not z.rezeptLernen then return end
    z.lernStufe0 = p:getPerkLevel(z.lernPerk)
    log("Code-Werte autolernen: Rezept " .. tostring(z.rezeptLernen:getName()) .. ", " .. tostring(z.lernPerk)
        .. " ab Stufe " .. tostring(stufe))
end
function M.lernstufe(p, z)
    local r = z.rezeptLernen
    if not r then return "nicht messbar: kein Rezept mit genau einem Lern-Skill ab Stufe 2" end
    if z.lernRest or p:isRecipeActuallyKnown(r) then return "nicht messbar: die Figur kennt das Rezept schon" end
    for stufe = 0, 10 do
        stufeSetzen(p, z.lernPerk, stufe)
        r:checkAutoLearnAnySkills(p)
        if p:isRecipeActuallyKnown(r) then
            p:getKnownRecipes():remove(r:getName())
            if p:isRecipeActuallyKnown(r) then z.lernRest = true end
            return stufe
        end
    end
    return "nicht messbar: bis Stufe 10 nicht gelernt"
end
function M.lernNachher(p, z)
    if z.lernPerk and z.lernStufe0 then stufeSetzen(p, z.lernPerk, z.lernStufe0) end
    if z.lernRest then
        log("Code-Werte autolernen: " .. tostring(z.rezeptLernen:getName()) .. " liess sich nicht vergessen")
    end
    z.rezeptLernen, z.lernPerk, z.lernStufe0, z.lernRest = nil, nil, nil, nil
end

-- Nikotin: RecipeCodeOnEat.consumeNicotine(Food, chr, percent) (Z. 53-55)
-- ruft consumeNicotineLogic (Z. 22-47). Smoker: Unzufriedenheit und Stress
-- je + stressChange x percent (Z. 30-31), Entzug auf 0 und
-- setTimeSinceLastSmoke (Z. 32-34). Nichtraucher: Uebelkeit +
-- foodSicknessChange x percent (Z. 37). Alle: Hunger -0.03 (Z. 39). Den
-- Husten (Z. 40-45: Sprechblase, Stimme, Weltgeraeusch Radius 35, triggerCough
-- Z. 13969-13979) haelt die Probe-Zigarette aus: beide Husten-Chancen 0.
-- Nur die Wirkung beim Rauchen; den Entzug ueber Zeit (BodyDamage) misst das
-- nicht. Startwerte mitten in den Bereichen (Stress 0 bis 1, Unzufriedenheit
-- 0 bis 100, CharacterStat Z. 20-34), damit nichts an einer Grenze klemmt.
TFMeasure.NIKOTIN_STATS = { "STRESS", "UNHAPPINESS", "FOOD_SICKNESS", "HUNGER", "NICOTINE_WITHDRAWAL" }
TFMeasure.NIKOTIN_START = { STRESS = 0.5, UNHAPPINESS = 50, FOOD_SICKNESS = 0, NICOTINE_WITHDRAWAL = 0.25 }
function M.nikotinVorher(p, z)
    z.zigarette = instanceItem("Base.CigaretteSingle")
    z.zigarette:setInverseCoughProbability(0)
    z.zigarette:setInverseCoughProbabilitySmoker(0)
    z.nikotin0 = {}
    for _, name in ipairs(TFMeasure.NIKOTIN_STATS) do z.nikotin0[name] = statLesen(p, name) end
    z.rauch0 = p:getTimeSinceLastSmoke()
end
function M.nikotinNachher(p, z)
    if z.nikotin0 then
        for name, wert in pairs(z.nikotin0) do statSetzen(p, name, wert) end
    end
    if z.rauch0 then p:setTimeSinceLastSmoke(z.rauch0) end
    z.zigarette, z.nikotin0, z.rauch0 = nil, nil, nil
end
function M.nikotin(name)
    return function(p, z)
        for stat, wert in pairs(TFMeasure.NIKOTIN_START) do statSetzen(p, stat, wert) end
        local vor = statLesen(p, name)
        RecipeCodeOnEat.consumeNicotine(z.zigarette, p, 1.0)
        local v = statLesen(p, name) - vor
        for stat, wert in pairs(z.nikotin0) do statSetzen(p, stat, wert) end
        p:setTimeSinceLastSmoke(z.rauch0)
        return v
    end
end
function M.nikotinStressSoll(p, z) return z.zigarette:getStressChange() end

-- Windstrafe: IsoPlayer.calculateCritChance (Z. 3599-3689) zieht im
-- Fernkampf-Zweig CombatManager.getWeatherPenalty ab (Z. 3643; CombatManager
-- Z. 2065-2082): Wind x (6 - 0.2 x Aiming) x Abstand x (Marksman 0.6, sonst
-- 1.0; CombatConfigKey Z. 46-49), nur wenn das Zielfeld draussen ist; danach
-- x 1.5 ohne Outdoorsman (CharacterTraits Z. 150-152), fuer beide Faelle
-- gleich. getWindIntensity liest den finalValue des ClimateFloat
-- (ClimateManager, Bytecode 0-7), und ClimateFloat.setFinalValue ist public:
-- der Wind laesst sich im Tick setzen und zurueckstellen, ohne Admin-Wert
-- (der landet im Spielstand, saveAdmin). ClimateManager.update rechnet den
-- finalValue ohnehin in jedem Tick neu (ClimateFloat.calculate). Nebel und
-- Niederschlag stehen fuer die Messung auf 0; sie gehen ohne Marksman-Faktor
-- ein und senken nur den Startwert. Die Chance ist eine ganze Zahl, auf 10
-- bis 90 geklemmt (Z. 3689): gemessen wird darum die Steigung der Chance
-- ueber 101 Windstufen zwischen 0 und der groessten Stufe ohne Klemme. Das
-- Abschneiden verzerrt sie um rund 1/n^2 bei n Punkten Abfall; unter 15
-- Punkten meldet die Gruppe "nicht messbar". Faktor mit/ohne laut Code 0.6.
-- Ziel ist ein Zombie auf einem freien Aussenfeld 5 bis 8 Felder weit
-- (addZombiesInOutfit wie ISSpawnHordeUI.lua:276, LuaManager Z. 8343-8402).
-- Er entsteht in vorher und verschwindet in nachher (removeFromWorld und
-- removeFromSquare wie DebugContextMenu.lua:605-606), beides im selben Tick:
-- kein Update erreicht ihn, er kann nicht angreifen.
TFMeasure.WIND_FELDER = { 6, 7, 5, 8 }
TFMeasure.WIND_RICHTUNGEN = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }
TFMeasure.WIND_PUNKTE = 101
TFMeasure.WIND_MIN_ABFALL = 15
function M.klimaFloats()
    local cm = getClimateManager()
    return { cm:getClimateFloat(ClimateManager.FLOAT_WIND_INTENSITY),
             cm:getClimateFloat(ClimateManager.FLOAT_FOG_INTENSITY),
             cm:getClimateFloat(ClimateManager.FLOAT_PRECIPITATION_INTENSITY) }
end
--- Merkt Wind, Nebel und Niederschlag, setzt die beiden letzten auf 0 und
-- gibt den Wind zurueck.
function M.klimaMerken(z)
    local f = M.klimaFloats()
    z.klima0 = { f[1]:getFinalValue(), f[2]:getFinalValue(), f[3]:getFinalValue() }
    f[2]:setFinalValue(0)
    f[3]:setFinalValue(0)
    return f[1]
end
function M.klimaZurueck(z)
    if not z.klima0 then return end
    local f = M.klimaFloats()
    for i = 1, 3 do f[i]:setFinalValue(z.klima0[i]) end
    z.klima0 = nil
end
function M.windKrit(p, z, wind, w)
    wind:setFinalValue(w)
    return p:calculateCritChance(z.windZiel)
end
function M.zombieWeg(zombie)
    zombie:removeFromWorld()
    zombie:removeFromSquare()
end
--- Ein Zombie auf dem ersten freien Aussenfeld; bleibt einer aus, kommt
-- kein zweiter Versuch (jeder schreibt eine Warnung ins Log).
function M.windZielSetzen(p)
    local cell = getCell()
    local px, py, pz = math.floor(p:getX()), math.floor(p:getY()), math.floor(p:getZ())
    for _, weit in ipairs(TFMeasure.WIND_FELDER) do
        for _, r in ipairs(TFMeasure.WIND_RICHTUNGEN) do
            local x, y = px + r[1] * weit, py + r[2] * weit
            local sq = cell:getGridSquare(x, y, pz)
            if sq and sq:isOutside() and sq:isFree(false) then
                local liste = addZombiesInOutfit(x, y, pz, 1, nil, 50)
                if not liste or liste:size() == 0 then
                    return nil, "nicht messbar: kein Zombie entstanden (Sandbox ohne Zombies?)"
                end
                local zombie = liste:get(0)
                local feld = zombie:getCurrentSquare()
                if feld and feld:isOutside() then return zombie end
                M.zombieWeg(zombie)
                return nil, "nicht messbar: der Zombie stand nicht draussen"
            end
        end
    end
    return nil, "nicht messbar: kein freies Aussenfeld 5 bis 8 Felder entfernt"
end
-- Aiming waehlt die Gruppe selbst (seit 6.26.3): mit Aiming 0 lag die
-- Chance ohne Wind am 14.09.2026 bei 22, bis zur Klemme 10 fiel sie also
-- hoechstens um 12, und die Gruppe meldete "nicht messbar". Aiming hebt
-- die Chance (Pistole 20 + 6 je Stufe) und senkt die Strafe je Feld
-- (6 - 0.2 x Aiming); das Verhaeltnis mit/ohne Marksman (0.6) haengt nicht
-- daran. Zu hoch darf es nicht sein: ueber 70 ohne Wind laege Marksman
-- (+10) an der Klemme 90. Darum die hoechste Stufe ab 10 abwaerts, bei
-- der die Chance ohne Wind mit einer der Zielverzoegerungen hoechstens 70
-- ist; welche, steht im Log.
TFMeasure.WIND_AIMING = 10
function M.windVorher(p, z)
    z.windHand0 = p:getPrimaryHandItem()
    z.aimingWind = p:getPerkLevel(Perks.Aiming)
    z.windWaffe = p:getInventory():AddItem("Base.Pistol")
    p:setPrimaryHandItem(z.windWaffe)
    z.windZiel, z.windFehler = M.windZielSetzen(p)
    if not z.windZiel then return end
    -- Wie kritVorher: die kleinste Zielverzoegerung, bei der die Chance ohne
    -- Wind und ohne Marksman hoechstens 70 ist, damit +10 unter der Klemme
    -- bleibt.
    local wind = M.klimaMerken(z)
    local chance = nil
    for stufe = TFMeasure.WIND_AIMING, 0, -1 do
        z.windAiming = stufe
        stufeSetzen(p, Perks.Aiming, stufe)
        for _, verzug in ipairs(TFMeasure.KRIT_VERZUG) do
            z.windVerzug = verzug
            p:setAimingDelay(verzug)
            chance = M.windKrit(p, z, wind, 0)
            if chance <= 70 then break end
        end
        if chance <= 70 then break end
    end
    M.klimaZurueck(z)
    log(string.format("Code-Werte wind: Ziel %.1f Felder entfernt, Aiming %s, Zielverzoegerung %s,"
        .. " Chance ohne Wind %s", p:DistToProper(z.windZiel), tostring(z.windAiming),
        tostring(z.windVerzug), tostring(chance)))
end
function M.windSteigung(p, z)
    if not z.windZiel then return z.windFehler or "nicht messbar: kein Ziel" end
    p:setAimingDelay(z.windVerzug or 0)
    local wind = M.klimaMerken(z)
    local c0 = M.windKrit(p, z, wind, 0)
    local v
    if c0 <= 10 or c0 >= 90 then
        v = "nicht messbar: Chance ohne Wind " .. tostring(c0) .. ", an der Klemme"
    else
        local wmax = 0
        for i = 1, 50 do
            if M.windKrit(p, z, wind, i / 50) > 10 then wmax = i / 50 else break end
        end
        if wmax == 0 or c0 - M.windKrit(p, z, wind, wmax) < TFMeasure.WIND_MIN_ABFALL then
            v = "nicht messbar: die Chance faellt ohne Klemme um weniger als " .. TFMeasure.WIND_MIN_ABFALL
        else
            local n, sw, sc, sww, swc = TFMeasure.WIND_PUNKTE, 0, 0, 0, 0
            for i = 0, n - 1 do
                local w = wmax * i / (n - 1)
                local c = M.windKrit(p, z, wind, w)
                sw, sc, sww, swc = sw + w, sc + c, sww + w * w, swc + w * c
            end
            v = -(n * swc - sw * sc) / (n * sww - sw * sw)
        end
    end
    M.klimaZurueck(z)
    return v
end
function M.windNachher(p, z)
    M.klimaZurueck(z)
    if z.windZiel then M.zombieWeg(z.windZiel) end
    p:setPrimaryHandItem(z.windHand0)
    if z.windWaffe then p:getInventory():Remove(z.windWaffe) end
    if z.aimingWind then stufeSetzen(p, Perks.Aiming, z.aimingWind) end
    p:resetAimingDelay()
    z.windZiel, z.windFehler, z.windVerzug, z.windHand0, z.windWaffe, z.aimingWind = nil, nil, nil, nil, nil, nil
    z.windAiming = nil
end

-- Nutritionist: Food.DoTooltip(ObjectTooltip, Layout) (Z. 1241-1387)
-- schreibt Naehrwerte, Kalorien, Kohlenhydrate, Eiweiss und Fett (5 Zeilen,
-- Z. 1372-1386) nur mit Nutritionist (auch der Berufsfassung) oder lesbarer
-- Verpackung; die Figur kommt aus tooltip:getCharacter() (Z. 1360). Gezaehlt
-- werden die Zeilen: Layout.render gibt die Hoehe zurueck, jede einzeilige
-- Zeile ist lineSpacing hoch (LayoutItem.calcSizes, Bytecode 232-238). Mit
-- setMeasureOnly(true) kehrt jedes Draw* sofort zurueck (ObjectTooltip.
-- DrawText, DrawTextRight, DrawProgressBar, Bytecode 0-7), wie
-- ISToolTipInv.lua:64 misst; gezeichnet wird also nichts, und das geht auch
-- im Tick. Apfel: unverpackt, nicht kochbar.
function M.naehrwerte(p, z)
    local tt = ObjectTooltip.new()
    tt:setCharacter(p)
    tt:setMeasureOnly(true)
    local layout = tt:beginLayout()
    z.apfel:DoTooltip(tt, layout)
    local hoehe = layout:render(0, 0, tt)
    tt:endLayout(layout)
    return hoehe / tt:getLineSpacing()
end

-- Spielfehler irongut-bleiche: DrinkFluid (IsoGameCharacter Z. 5470-5519)
-- nimmt isTaintedWater = fluidCont.isTainted() (Z. 5479) fuer den ganzen
-- Behaelter, und isTainted ist wahr, sobald irgendetwas verseuchtes Wasser
-- drin ist (FluidContainer Z. 625-631). Mit Iron Gut ist das Gift dann 0
-- (Z. 5500-5502), auch das der Bleiche (Poison maxEffect Deadly,
-- fluids.txt:191-196). Reine Bleiche halbiert Iron Gut nicht (isBleach,
-- Z. 5503); das zeigt die Gegenprobe. Der Behaelter ist eine Bleichflasche
-- (normal.txt:3554-3563, 1 Liter), geleert und neu befuellt. DrinkFluid
-- aendert Durst, Hunger und mehr (Z. 5474-5495); alles kommt zurueck.
-- Uebelkeit 0 vor dem Trinken, sonst liefe der Zweig Z. 5511-5515.
TFMeasure.BLEICHE_STATS = { "THIRST", "HUNGER", "ENDURANCE", "STRESS", "FATIGUE", "BOREDOM", "UNHAPPINESS",
                            "POISON", "FOOD_SICKNESS" }
function M.trinken(wasser, bleiche)
    return function(p, z)
        local fc = instanceItem("Base.Bleach"):getFluidContainer()
        fc:Empty()
        if wasser > 0 then fc:addFluid(FluidType.TaintedWater, wasser) end
        if bleiche > 0 then fc:addFluid(FluidType.Bleach, bleiche) end
        if math.abs(fc:getAmount() - wasser - bleiche) > 0.001 or fc:isTainted() ~= (wasser > 0) then
            return "nicht messbar: Wasser und Bleiche liessen sich nicht mischen"
        end
        local bd, n = p:getBodyDamage(), p:getNutrition()
        local vorher = {}
        for _, name in ipairs(TFMeasure.BLEICHE_STATS) do vorher[name] = statLesen(p, name) end
        local rest = { bd:getHealthFromFoodTimer(), bd:getPainReduction(), bd:getColdReduction(),
                       n:getCalories(), n:getCarbohydrates(), n:getProteins(), n:getLipids() }
        statSetzen(p, "POISON", 0)
        statSetzen(p, "FOOD_SICKNESS", 0)
        p:DrinkFluid(fc, 1.0, false)
        local v = statLesen(p, "POISON")
        for name, wert in pairs(vorher) do statSetzen(p, name, wert) end
        bd:setHealthFromFoodTimer(rest[1])
        bd:setPainReduction(rest[2])
        bd:setColdReduction(rest[3])
        n:setCalories(rest[4])
        n:setCarbohydrates(rest[5])
        n:setProteins(rest[6])
        n:setLipids(rest[7])
        return v
    end
end
-- [/paket-b]
--
-- Paket C: nur mit -debug (Hoerradius, Schritte, Albtraum).
-- [paket-c]
-- Rang 11 aus der Messbarkeits-Recherche (docs/berichte/2026-09-13-
-- messbarkeit.md): drei Groessen, die nur ueber Reflection auf private
-- Felder lesbar sind, und Reflection gibt es nur im Debug-Modus.
-- getClassField/getClassFieldVal werfen ohne ihn "Not in debug" (LuaManager
-- Z. 6292-6305, 6400-6408), auch innerhalb eines pcall, und das Spiel loggt
-- die Ausnahme selbst. Darum fragt jede Gruppe VOR jedem Reflection-Zugriff
-- TFMeasure.debugFehlt und liefert ohne Debug-Modus den Text "kein -debug"
-- statt einer Zahl; werteGruppe macht daraus "nicht messbar" mit Notiz.
-- Kein eigener Lua-Fehler: auch der landete trotz pcall im Log (so wie am
-- 13.09.2026 im Schlaf-Test "attempted index: reset of non-table").
function TFMeasure.debugFehlt()
    if not (isDebugEnabled and isDebugEnabled()) then return "kein -debug" end
    return nil
end

--- Liest ein Feld per Reflection: getNumClassFields/getClassField/
-- getClassFieldVal sind im Debug-Modus auch fuer private Felder frei
-- (LuaManager Z. 6292-6305, 6400-6408). tostring(feld) traegt "Klasse.name".
function TFMeasure.feldWert(obj, name)
    for i = 0, getNumClassFields(obj) - 1 do
        local feld = getClassField(obj, i)
        if string.find(tostring(feld), "%." .. name .. "$") then return getClassFieldVal(obj, feld) end
    end
    return nil
end

-- Keen Hearing, Hard of Hearing (/noise): calculateVisibilityData() ist
-- public und ohne Nebenwirkung (Z. 15169-15194); VisibilityData selbst ist
-- nicht freigegeben, noiseDistance also nur per Reflection lesbar. Basis
-- 2.0, Keen Hearing +3.0, Hard of Hearing -1.0 (TF_Static "noise").
function M.hoerradius(p)
    local fehlt = TFMeasure.debugFehlt()
    if fehlt then return fehlt end
    local wert = TFMeasure.feldWert(p:calculateVisibilityData(), "noiseDistance")
    -- noiseDistance ist schon mit getWornItemsHearingMultiplier verrechnet
    -- (Z. 15194); Muetze oder Helm skalierten sonst +3 und -1.
    local mul = p.getWornItemsHearingMultiplier and p:getWornItemsHearingMultiplier()
    if type(wert) == "number" and type(mul) == "number" and mul > 0 then return wert / mul end
    return wert
end

-- Graceful, Clumsy (/footsteps): DoFootstepSound(float) ist public
-- (Z. 5297-5340), wuerfelt aber nur mit 1/2 (Rand.Next(2), Z. 5334) ein
-- neues Weltgeraeusch; bis zu SCHRITT_VERSUCHE Versuche, bis eins entsteht.
-- WorldSoundManager.soundList und WorldSound.radius sind oeffentliche
-- Felder, aber Kahlua liest keine Felder, nur Reflection kommt heran. Das
-- Geraeusch bleibt stehen und klingt nach 16 Updates ab wie jeder echte
-- Schritt: aus soundList genommen, bliebe es in den Listen der Chunks
-- haengen, die nur ueber seine Lebenszeit aufraeumen (WorldSoundManager
-- Z. 135-143, 352), und lockte dort weiter Zombies an.
-- Unsichtbar muss aus sein (sonst bricht DoFootstepSound sofort ab,
-- Querschnitt Punkt 2 der Recherche); die Lautstaerke 1/1.4 haelt den
-- ceil(10 x 1.4 x Lautstaerke x ...) auf dem reinen Trait-Faktor, wenn
-- Lightfoot und Nimble 0 sind (vorher). Schleichen und barfuss im Haus
-- ((int)(r x 0.5), Z. 5310-5335) verschieben das Runden: nicht messbar.
TFMeasure.SCHRITT_VERSUCHE = 60
function M.schritt(p)
    local fehlt = TFMeasure.debugFehlt()
    if fehlt then return fehlt end
    if p:isSneaking() then return "nicht messbar: die Figur schleicht" end
    local feld = p:getCurrentSquare()
    local schuhe = ItemBodyLocation and ItemBodyLocation.SHOES and p:getWornItem(ItemBodyLocation.SHOES)
    if feld and feld.isInARoom and feld:isInARoom() and not schuhe then
        return "nicht messbar: barfuss im Haus"
    end
    local liste = TFMeasure.feldWert(getWorldSoundManager(), "soundList")
    for _ = 1, TFMeasure.SCHRITT_VERSUCHE do
        local vor = liste:size()
        p:DoFootstepSound(1 / 1.4)
        if liste:size() > vor then
            return TFMeasure.feldWert(liste:get(liste:size() - 1), "radius")
        end
    end
    return "kein Schrittgeraeusch in " .. TFMeasure.SCHRITT_VERSUCHE .. " Versuchen"
end
function M.schrittVorher(p, z)
    z.unsichtbar0 = TFMeasure.cheatStand.unsichtbar
    p:setInvisible(false)
    z.schrittStufen = {}
    for _, name in ipairs({ "Lightfoot", "Nimble" }) do
        local perk = Perks[name]
        if perk then
            z.schrittStufen[name] = p:getPerkLevel(perk)
            stufeSetzen(p, perk, 0)
        end
    end
end
function M.schrittNachher(p, z)
    p:setInvisible(z.unsichtbar0 ~= false)
    for name, stufe in pairs(z.schrittStufen or {}) do stufeSetzen(p, Perks[name], stufe) end
    z.unsichtbar0, z.schrittStufen = nil, nil
end

-- Desensitized (/nightmare): SleepingEvent.setPlayerFallAsleep setzt die
-- Schlafdaten bei jedem Aufruf neu (Z. 55) und wuerfelt checkNightmare
-- (Z. 185-198): 5 %, mit Desensitized 10 %, ab drei Stunden Schlaf; mit
-- Stress 0 bleibt es bei der Grundchance. Wie im Schlaf-Test haelt ein
-- sofortiges setAsleepTime(0) die Schlafzeit fern, damit SleepingEvent.update
-- nicht weckt; save bleibt unberuehrt, weil nur onSleepWalkToComplete
-- speichert, nicht setPlayerFallAsleep. Die Figur schlaeft dabei nicht:
-- setPlayerFallAsleep setzt nur die Schlafdaten, timeOfSleep und
-- delayToActuallySleep (Bytecode, Offsets 1-76); Getter fuer die beiden
-- gibt es nicht, und das naechste echte Hinlegen setzt sie ohnehin neu.
-- Jeder Aufruf durchsucht aber das Gebaeude der Figur nach Herd,
-- Fernseher, Radio, Fenstern und Tueren (Offsets 255-608); 3000 Aufrufe
-- in einem Tick hielten das Spiel in einem grossen Haus spuerbar an. Die
-- Proben laufen darum ueber mehrere Ticks (M.stichTick), die Faelle im
-- Wechsel. nachher gibt Stress zurueck und weckt die Figur nur, falls sie
-- doch schlaeft. Toleranz 2.5 Punkte: die Differenz streut bei 1500 Proben
-- je Fall um 0.8 bis 1.0 Punkte; mit 4 hiesse auch ein fehlender Effekt
-- in rund jedem zehnten Lauf "stimmt" (Review 13.09.2026).
TFMeasure.ALBTRAUM = { proben = 1500, jeTick = 60, toleranz = 2.5 }
function M.albtraumProbe(p)
    local fehlt = TFMeasure.debugFehlt()
    if fehlt then return nil, fehlt end
    getSleepingEvent():setPlayerFallAsleep(p, 8)
    p:setAsleepTime(0)
    local wach = TFMeasure.feldWert(p:getOrCreateSleepingEventData(), "nightmareWakeUp")
    if type(wach) ~= "number" then return nil, "nightmareWakeUp nicht lesbar" end
    return (wach > -1) and 1 or 0
end
function M.albtraumVorher(p, z)
    z.stress0 = statLesen(p, "STRESS")
    statSetzen(p, "STRESS", 0)
end
function M.albtraumNachher(p, z)
    -- wakeUp nur, wenn die Figur wirklich schlaeft: setPlayerFallAsleep legt
    -- sie nicht hin, und wakeUp blendet sonst zwei Sekunden schwarz, sperrt
    -- das Schlafen im Auto fuer eine Stunde (setLastHourSleeped) und gibt im
    -- Durchschnittsbett zu 10 % Nackenschmerzen (SleepingEvent Z. 408-471).
    if p:isAsleep() then getSleepingEvent():wakeUp(p) end
    p:setAsleepTime(0)
    if z.stress0 then statSetzen(p, "STRESS", z.stress0) end
    z.stress0 = nil
end
-- [/paket-c]
--
-- Paket D, krank: Leichen-Krankheit und Erkaeltung fangen, je in einem Tick.
-- [paket-d-krank]
-- Rang 13 und 14 aus docs/berichte/2026-09-13-messbarkeit.md. Beides rechnet
-- das Spiel im Update-Takt; gelesen wird es trotzdem in einem Tick.
--
-- Leichen-Krankheit (resilient/corpsesick, pronetoillness/corpsesick):
-- BodyDamage.UpdateIllness (privat, Z. 2116-2139) nimmt die Grundrate aus
-- GetBaseCorpseSickness (public, Z. 2141-2143), mindert sie um den Schutz
-- einer Maske (IsoGameCharacter.getCorpseSicknessDefense ab Z. 13809) und
-- rechnet Resilient x0.75, sonst Prone to Illness x1.25 (Z. 2124-2127);
-- setCorpseSicknessRate haelt das Ergebnis (Z. 2131), getCorpseSicknessRate
-- ist public (IsoGameCharacter Z. 14375). UpdateIllness laeuft nur aus
-- BodyDamage.Update (Z. 1853), und das kehrt mit God Mode vorher zurueck
-- (Z. 1821-1825): God Mode ist fuer die Gruppe aus, Update laeuft je Fall
-- einmal ganz (ein Bild Koerper-Update). Uebelkeit, catchACold und die Rate
-- kommen danach zurueck.
-- Die Grundrate ist erst ab sechs Leichen ueber 0 (getSicknessFromCorpsesRate
-- Z. 2091-2114) und immer 0 mit der Sandbox DecayingCorpseHealthImpact 1;
-- dann stellt die Gruppe sie fuer den Tick auf 3 (Normal), wie der Unfall
-- seine Option. CorpseCount.getCorpseCount (Bytecode 0-270) zaehlt die
-- Leichen im 3x3-Chunk-Feld auf der Ebene der Figur, im Haus nur die im
-- selben Gebaeude: darum sechs Leichen per createRandomDeadBody (LuaManager
-- Z. 8267-8290) auf das Feld der Figur. Der Konstruktor legt sie aufs Feld
-- und zaehlt sie sofort (IsoDeadBody.<init>, Bytecode 346-361 und
-- 1575-1590); dabei feuern OnDeadBodySpawn und OnContainerUpdate. Weg kommen
-- sie wie im Debug-Menue (DebugContextMenu.lua:693) ueber removeCorpse
-- (IsoGridSquare Z. 2610-2630: removeFromWorld zaehlt sie ab, dann
-- removeFromSquare); Kleidung und Inhalt gehoeren der Leiche, auf den Boden
-- faellt nichts. Gemessen wird Rate / Grundrate, ohne Maske ohne Trait 1.
TFMeasure.LEICHEN = { anzahl = 6, stufe = 3 }
function M.leichenVorher(p, z)
    M.godAus(p, z)
    local l = { koerper = {}, rate0 = p:getCorpseSicknessRate() }
    z.leichen = l
    l.stufe0 = M.sandboxWert("DecayingCorpseHealthImpact")
    if l.stufe0 == 1 then
        l.stufeGesetzt = true
        pcall(function() getSandboxOptions():set("DecayingCorpseHealthImpact", TFMeasure.LEICHEN.stufe) end)
    end
    l.feld = p:getCurrentSquare()
    if not l.feld then
        l.grund = "nicht messbar: die Figur steht auf keinem Feld"
        return
    end
    -- Jede Leiche kommt sofort in die Liste: bricht createRandomDeadBody
    -- mittendrin ab, raeumt nachher die schon gelegten weg.
    for _ = 1, TFMeasure.LEICHEN.anzahl do
        local body = createRandomDeadBody(l.feld, 0)
        if body then l.koerper[#l.koerper + 1] = body end
    end
end
function M.leichenMessen(p, z)
    local l = z.leichen
    if not l then return "nicht messbar: Aufbau fehlt" end
    if l.grund then return l.grund end
    local bd = p:getBodyDamage()
    local basis = bd:GetBaseCorpseSickness()
    if not (basis > 0) then
        return string.format("nicht messbar: Grundrate 0 bei %d neuen Leichen (Sandbox DecayingCorpseHealthImpact %s)",
            #l.koerper, tostring(M.sandboxWert("DecayingCorpseHealthImpact")))
    end
    local uebel, fang = statLesen(p, "FOOD_SICKNESS"), bd:getCatchACold()
    bd:Update()
    local rate = p:getCorpseSicknessRate()
    statSetzen(p, "FOOD_SICKNESS", uebel)
    bd:setCatchACold(fang)
    if not (rate > 0) then return "nicht messbar: Rate 0, wohl eine Gasmaske" end
    return rate / basis
end
function M.leichenNachher(p, z)
    local l = z.leichen
    z.leichen = nil
    if l then
        for _, body in ipairs(l.koerper) do
            pcall(function()
                local feld = body:getSquare() or l.feld
                feld:removeCorpse(body, false)
            end)
        end
        if l.stufeGesetzt then
            pcall(function() getSandboxOptions():set("DecayingCorpseHealthImpact", l.stufe0) end)
        end
        pcall(function() p:setCorpseSicknessRate(l.rate0 or 0) end)
    end
    M.godZurueck(p, z)
end

-- Erkaeltung fangen (resilient/cold, pronetoillness/cold, outdoorsman/cold):
-- BodyDamage.UpdateWetness (public, Z. 661-757) mehrt catchACold um
-- CatchAColdIncreaseRate (0.003, defines.lua:39) x delta x Multiplier
-- (Z. 743), mit Prone to Illness x1.7, Resilient x0.45, Outdoorsman x0.25
-- (Z. 734-742, nacheinander auf delta), nur ohne Erkaeltung und nur bei
-- delta > 0.1. delta ist Thermoregulator.getCatchAColdDelta (public,
-- Z. 429-458) und waechst nur, wenn die Haut unter 33 Grad liegt. Die Haut
-- kuehlt allein in Thermoregulator.update (Z. 658-670): ihr Ziel ist Kern - 4,
-- bei einem Kern unter dem Sollwert 37 tiefer, nie unter der Luft
-- (updateNodes Z. 861-920). Beides stellt die Gruppe fuer den einen Tick:
-- den Kern ueber den Wert TEMPERATURE (update zieht den Kern halb dorthin,
-- updateHeatDeltas Z. 827-846), die Luft ueber ClimateFloat.setFinalValue
-- wie die Gruppe wind (getTemperature liest den finalValue, ClimateManager
-- Bytecode 0-7; im Haus mit Strom bleibt es bei 22 Grad). Je update rueckt
-- die Haut um Multiplier x 0.0025 x simulationMultiplier ihres Abstands vor
-- (Z. 583-624, 906-916); den statischen simulationMultiplier (Z. 94-96) hebt
-- die Gruppe nur fuer ihre eigenen Aufrufe und stellt ihn gleich zurueck.
-- UpdateWetness aendert danach nur Naesse und Kleidung, nicht die
-- Thermo-Knoten (die liest calculateInsulation erst im naechsten update):
-- delta bleibt im Tick gleich. Je Fall setCatchACold(0), UpdateWetness,
-- getCatchACold; geteilt durch 0.003 x delta x Multiplier ist ohne Trait 1.
--
-- Spielfehler erkaeltung-schwelle: der Abbau fragt danach dasselbe delta,
-- schon mit dem Trait-Faktor (Z. 751-756), und zieht dann 0.175 ab
-- (CatchAColdDecreaseRate, defines.lua:40, ohne Multiplier), weit mehr als
-- ein Update aufbaut. Mit Resilient waechst catchACold darum erst ab delta
-- 0.22, mit Outdoorsman erst ab 0.4; darunter bleibt es bei 0. Die Gruppe
-- erkaeltung kuehlt deshalb bis delta ueber 0.6 (bis 0.45 "nicht messbar"),
-- die Gruppe erkaeltungschwelle in kleinen Schritten nur auf 0.12 bis 0.2,
-- wo beide Traits laut Code 0 bringen.
--
-- Danach Thermoregulator.reset (Z. 176-193: Kern 37, Haut 33), der Wert
-- TEMPERATURE wie vorher (das naechste update zieht den Kern dorthin),
-- catchACold, Erkaeltung, Niesen, Kaelteschaden-Stufe und die Naesse von
-- Koerper und Kleidung wie vorher. Die Hauttemperaturen selbst haben keinen
-- Setter; nach reset gleichen sie sich in wenigen Spielminuten wieder an.
-- God Mode bleibt, wie er ist: weder UpdateWetness noch
-- Thermoregulator.update fragen ihn.
TFMeasure.KAELTE = { kern = 25, luft = 0, rate = 0.003, schritt = 0.25, versuche = 40, ziel = 0.6,
                     mindest = 0.45, fensterSchritt = 0.03, fensterVersuche = 200, fenster = { 0.12, 0.2 } }

--- Naesse der Koerperteile, des Werts WETNESS und der getragenen Kleidung;
-- UpdateWetness gleicht die Teile an und trocknet die Kleidung (ClothingWetness
-- .updateWetness, Z. 57-172).
function M.kaelteNaesseMerken(p, bd)
    local n = { stat = statLesen(p, "WETNESS"), teile = {}, kleider = {} }
    local teile = bd:getBodyParts()
    for i = 0, teile:size() - 1 do n.teile[i + 1] = teile:get(i):getWetness() end
    local getragen = p:getWornItems()
    for i = 0, getragen:size() - 1 do
        local item = getragen:getItemByIndex(i)
        if item and instanceof(item, "Clothing") then n.kleider[#n.kleider + 1] = { item, item:getWetness() } end
    end
    return n
end
function M.kaelteNaesseZurueck(p, bd, n)
    local teile = bd:getBodyParts()
    for i = 0, teile:size() - 1 do
        if n.teile[i + 1] then teile:get(i):setWetness(n.teile[i + 1]) end
    end
    for _, e in ipairs(n.kleider) do e[1]:setWetness(e[2]) end
    statSetzen(p, "WETNESS", n.stat)
end

--- Kuehlt die Haut, bis delta ueber unten liegt, mit hoechstens versuche
-- Aufrufen von update; schritt ist der Anteil des Abstands je Aufruf.
-- simulationMultiplier und Luft stellt M.kaelteKlimaZurueck zurueck, auch
-- nach einem Fehler.
function M.kaelteAbkuehlen(p, k, schritt, versuche, unten)
    local cfg = TFMeasure.KAELTE
    k.sim0 = k.thermo:getSimulationMultiplier()
    local luft = getClimateManager():getClimateFloat(ClimateManager.FLOAT_TEMPERATURE)
    k.luftFloat, k.luft0 = luft, luft:getFinalValue()
    k.gekuehlt = true
    Thermoregulator.setSimulationMultiplier(schritt / (0.0025 * k.mult))
    luft:setFinalValue(cfg.luft)
    k.aufrufe = 0
    for _ = 1, versuche do
        statSetzen(p, "TEMPERATURE", cfg.kern)
        k.thermo:update()
        k.aufrufe = k.aufrufe + 1
        if k.thermo:getCatchAColdDelta() > unten then break end
    end
end
function M.kaelteKlimaZurueck(k)
    if k.sim0 then Thermoregulator.setSimulationMultiplier(k.sim0) end
    if k.luftFloat then k.luftFloat:setFinalValue(k.luft0) end
    k.sim0, k.luftFloat = nil, nil
end

--- Nil, wenn delta passt, sonst der Grund.
function M.kaelteDeltaPruefen(delta, fenster)
    local cfg = TFMeasure.KAELTE
    if fenster then
        if delta > cfg.fenster[1] and delta <= cfg.fenster[2] then return nil end
        return string.format("nicht messbar: delta %.3f, gebraucht %.2f bis %.2f", delta, cfg.fenster[1],
            cfg.fenster[2])
    end
    if delta > cfg.mindest then return nil end
    return string.format("nicht messbar: delta %.3f, gebraucht ueber %.2f (Outdoorsman x0.25 muss ueber 0.1"
        .. " bleiben)", delta, cfg.mindest)
end

--- Aufbau fuer beide Gruppen: fenster kuehlt in kleinen Schritten nur bis
-- ins Fenster des Spielfehlers, sonst bis ziel.
function M.kaelteAufbau(p, z, fenster)
    local cfg, bd = TFMeasure.KAELTE, p:getBodyDamage()
    local k = { thermo = bd:getThermoregulator() }
    z.kaelte = k
    if not k.thermo then
        k.grund = "nicht messbar: die Figur hat keinen Thermoregulator"
        return
    end
    k.temp0, k.fang0, k.kalt0 = statLesen(p, "TEMPERATURE"), bd:getCatchACold(), bd:isHasACold()
    k.staerke0, k.niesen0, k.frost0 = bd:getColdStrength(), bd:getTimeToSneezeOrCough(), bd:getColdDamageStage()
    k.nass = M.kaelteNaesseMerken(p, bd)
    k.mult = getGameTime():getMultiplier()
    if not (k.mult > 0) then
        k.grund = "nicht messbar: das Spiel steht (Multiplier 0)"
        return
    end
    local ok, fehler
    if fenster then
        ok, fehler = pcall(M.kaelteAbkuehlen, p, k, cfg.fensterSchritt, cfg.fensterVersuche, cfg.fenster[1])
    else
        ok, fehler = pcall(M.kaelteAbkuehlen, p, k, cfg.schritt, cfg.versuche, cfg.ziel)
    end
    M.kaelteKlimaZurueck(k)
    if not ok then
        k.grund = "nicht messbar: " .. tostring(fehler)
        return
    end
    k.delta = k.thermo:getCatchAColdDelta()
    log(string.format("Code-Werte %s: delta %.3f nach %d Aufrufen von update",
        fenster and "erkaeltungschwelle" or "erkaeltung", k.delta, k.aufrufe or 0))
    k.grund = M.kaelteDeltaPruefen(k.delta, fenster)
end
function M.kaelteVorher(p, z) M.kaelteAufbau(p, z, false) end
function M.kaelteSchwelleVorher(p, z) M.kaelteAufbau(p, z, true) end

function M.kaelteMessen(p, z)
    local k = z.kaelte
    if not k then return "nicht messbar: Aufbau fehlt" end
    if k.grund then return k.grund end
    local bd = p:getBodyDamage()
    M.kaelteNaesseZurueck(p, bd, k.nass)
    bd:setHasACold(false)
    bd:setCatchACold(0)
    bd:UpdateWetness()
    local v = bd:getCatchACold()
    if k.thermo:getCatchAColdDelta() ~= k.delta then return "nicht messbar: delta aenderte sich im Tick" end
    return v / (TFMeasure.KAELTE.rate * k.delta * k.mult)
end
function M.kaelteNachher(p, z)
    local k = z.kaelte
    z.kaelte = nil
    if not k then return end
    M.kaelteKlimaZurueck(k)
    local bd = p:getBodyDamage()
    if k.gekuehlt then
        pcall(function()
            k.thermo:reset()
            statSetzen(p, "TEMPERATURE", k.temp0)
        end)
    end
    if k.nass then pcall(M.kaelteNaesseZurueck, p, bd, k.nass) end
    if k.fang0 then
        bd:setCatchACold(k.fang0)
        bd:setHasACold(k.kalt0)
        bd:setColdStrength(k.staerke0)
        bd:setTimeToSneezeOrCough(k.niesen0)
        bd:setColdDamageStage(k.frost0)
    end
end
-- [/paket-d-krank]

-- [paket-d-bau]
-- Spielfehler handy-haltbarkeit (Paket D). buildUtil.getWoodHealth
-- (server/BuildingObjects/ISBuildUtil.lua Z. 39-52) gibt Carpentry x 50, mit
-- Handy +100. Das Baumenue von 42.20 baut aber ueber ISBuildIsoEntity
-- (ISBuildPanel Z. 319, Kontextmenue ISWorldObjectContextMenu Z. 3063):
-- ISBuildAction:perform ruft create (ISBuildAction.lua Z. 229), create ruft je
-- Kachel setInfo (ISBuildIsoEntity.lua Z. 584), und setInfo rechnet die
-- Lebenspunkte ohne Handy: health aus dem Skript + BonusHealth (Sandbox
-- ConstructionBonusPoints) + Stufe x skillBaseHealth (Z. 653-664). Die
-- Holzwand WoodenWallLvl1 (scripts/generated/entities/walls/
-- entity_wood_walllvl1.txt) hat health 450 und skillBaseHealth 20.
-- getWoodHealth liest nur ISBuildIsoEntity:getHealth (Z. 38-44), das niemand
-- aufruft; bei der Holzwand gaebe es ohnehin 450 zurueck, weil health nicht
-- -1 ist.
--   wand       setInfo selbst, auf dem Feld zwei oestlich der Figur;
--              getMaxHealth der neuen Wand, danach im selben Tick weg, samt
--              Eckpfosten, falls buildUtil.checkCorner (ISBuildUtil.lua
--              Z. 57-86) einen gesetzt hat. Die Pruefungen von create
--              (Material, freies Feld, Z. 534-554) laufen nicht; sie aendern
--              die Lebenspunkte nicht. Differenz mit - ohne, laut Code 0.
--   holzleben  getWoodHealth selbst, die Gegenprobe: dort steht +100.
TFMeasure.WAND = { sprite = "walls_exterior_wooden_01_44", dx = 2 }

--- Die Sonderobjekte der neun Felder um (x, y), je mit ihrem Feld.
function M.wandObjekte(x, y, h)
    local liste = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            local feld = getCell():getGridSquare(x + dx, y + dy, h)
            local objekte = feld and feld:getSpecialObjects()
            if objekte then
                for i = 0, objekte:size() - 1 do
                    liste[#liste + 1] = { feld = feld, obj = objekte:get(i), mitte = (dx == 0 and dy == 0) }
                end
            end
        end
    end
    return liste
end

--- Was nach dem Bau neu dasteht.
function M.wandNeu(vorher, nachher)
    local neu = {}
    for _, e in ipairs(nachher) do
        local alt = false
        for _, v in ipairs(vorher) do
            if v.obj == e.obj then
                alt = true
                break
            end
        end
        if not alt then neu[#neu + 1] = e end
    end
    return neu
end

function M.wand(p)
    if not ISBuildIsoEntity or not SpriteConfigManager or not ISInventoryPaneContextMenu then
        return "nicht messbar: ISBuildIsoEntity fehlt"
    end
    local info = SpriteConfigManager.getObjectInfoFromSprite(TFMeasure.WAND.sprite)
    if not info or not info:getScript() or not info:getRecipe() then
        return "nicht messbar: keine Holzwand im Baumenue"
    end
    local x, y, h = math.floor(p:getX()) + TFMeasure.WAND.dx, math.floor(p:getY()), math.floor(p:getZ())
    local feld = getCell():getGridSquare(x, y, h)
    if not feld then return "nicht messbar: kein Feld neben der Figur" end
    local vorher = M.wandObjekte(x, y, h)
    local bau = ISBuildIsoEntity:new(p, info, 1, ISInventoryPaneContextMenu.getContainers(p))
    bau.player = p:getPlayerNum()
    local ok, err = pcall(bau.setInfo, bau, feld, false, TFMeasure.WAND.sprite, false)
    local leben = nil
    for _, e in ipairs(M.wandNeu(vorher, M.wandObjekte(x, y, h))) do
        if e.mitte and leben == nil then pcall(function() leben = e.obj:getMaxHealth() end) end
        e.feld:transmitRemoveItemFromSquare(e.obj)
        e.feld:RecalcAllWithNeighbours(true)
    end
    if not ok then return "nicht messbar: setInfo " .. tostring(err) end
    if type(leben) ~= "number" then return "nicht messbar: keine neue Wand auf dem Feld" end
    return leben
end

function M.holzleben(p)
    if not buildUtil or not buildUtil.getWoodHealth then return "nicht messbar: buildUtil fehlt" end
    return buildUtil.getWoodHealth({ player = p:getPlayerNum() })
end
-- [/paket-d-bau]
-- Paket D: Medical Check, Schnitt beim Dosenoeffnen, Verletzung durch
-- Zombies, alle an einem Stellvertreter ausserhalb der Welt.
-- [paket-d]
-- Rang 10, 22 und 23 aus der Messbarkeits-Recherche (docs/berichte/
-- 2026-09-13-messbarkeit.md). Alle drei brauchen eine zweite Figur: Medical
-- Check gibt es nur beim Klick auf einen anderen Spieler, und Schnitt und
-- Zombiebiss lassen an der eigenen Figur Blut auf dem Boden, Loecher in der
-- Kleidung und Infektion zurueck. Der Stellvertreter steht auf keinem Feld;
-- was ihm geschieht, trifft weder die Figur noch die Welt.
local PD = {}

--- Der Stellvertreter: IsoPlayer.new(getCell()) ruft IsoPlayer(cell, nil,
-- 0, 0, 0) (IsoPlayer Z. 535-537, 616-678). IsoGameCharacter traegt eine
-- Figur nur mit einer Koordinate ungleich 0 in die Zelle ein (Z. 785-791):
-- er steht auf keinem Feld (getCurrentSquare liefert das Feld current,
-- IsoMovingObject Z. 1819), bekommt kein Update und wird nicht gezeichnet.
-- Blut auf dem Boden braucht ein Feld (splatBloodFloorBig, IsoGameCharacter
-- Z. 4592-4596). Ausgezogen gibt es keine Loecher, keinen Ruestungsklang und
-- keine Abwehr der Kleidung (DamageFromWeapon Z. 1034-1049,
-- AddRandomDamageFromZombie Z. 1242-1260). Der Konstruktor legt seinen
-- SurvivorDesc in IsoWorld.survivorDescriptors ab (SurvivorDesc Z. 189-193),
-- einer Liste nur im Speicher, die das Spiel beim Laden leert (IsoWorld
-- Z. 1798); darum einer je Sitzung und nicht einer je Lauf. Er haengt an
-- TFMeasure und nicht an PD, weil PD mit F9 neu entsteht: sonst bliebe je
-- F9 ein Stellvertreter samt drei Sound-Emittern in SoundManager.emitters
-- liegen, die das Spiel erst beim Beenden leert (Review 14.09.2026).
function PD.stellvertreter()
    local s = TFMeasure.pdFigur
    if not s then
        if not (IsoPlayer and IsoPlayer.new and getCell) then return nil, "IsoPlayer.new fehlt" end
        s = IsoPlayer.new(getCell())
        if not s then return nil, "nicht angelegt" end
        TFMeasure.pdFigur = s
    end
    if s:getCurrentSquare() then return nil, "steht auf einem Feld" end
    s:clearWornItems()
    s:setInvisible(false)
    alleTraitsAb(s:getCharacterTraits())
    return s
end

--- vorher jeder Gruppe: der Stellvertreter oder ein Grund, warum nicht.
function PD.fremdVorher(p, z)
    local ok, s, grund = pcall(PD.stellvertreter)
    if ok and s then
        z.pdFremd = s
    else
        z.pdGrund = "kein Stellvertreter: " .. tostring(ok and grund or s)
    end
end

--- nachher jeder Gruppe, auch beim Abbruch (M.stichEnde): keine Traits,
-- Hand heil, Gesundheit 100, Klaenge seines Emitters aus.
function PD.fremdNachher(p, z)
    local s = z.pdFremd
    z.pdFremd, z.pdGrund, z.pdDose, z.pdZombie, z.pdBasis = nil, nil, nil, nil, nil
    if not s then return end
    alleTraitsAb(s:getCharacterTraits())
    local bd = s:getBodyDamage()
    bd:getBodyPart(BodyPartType.Hand_L):RestoreToFullHealth()
    bd:setOverallBodyHealth(100)
    local klang = s:getEmitter()
    if klang then klang:stopAll() end
end

--- Vor jeder Probe traegt die Figur genau den Trait ihres Falls
-- (M.stichTick); der Stellvertreter bekommt dieselben.
function PD.traitsWie(p, s)
    local ziel = s:getCharacterTraits()
    alleTraitsAb(ziel)
    local known = p:getCharacterTraits():getKnownTraits()
    for i = 0, known:size() - 1 do ziel:add(known:get(i)) end
end

-- Fear of Blood (/medcheck): die Option baut
-- ISWorldObjectContextMenuLogic.doClickedPlayerMenu (privat) und fragt
-- vorher hasTrait(HEMOPHOBIC) der klickenden Figur (Bytecode 41-93). Die
-- einzige oeffentliche Tuer ist createMenuEntries; es ruft den Zweig nur mit
-- fetch.safehouseAllowInteract (Offsets 495-511) und nur, wenn
-- fetch.clickedPlayer gesetzt und nicht der eigene Spieler ist (2770-2806).
-- doPlayerMenu prueft dasselbe (14-22): auf der eigenen Figur gibt es die
-- Option nie. Das Menue entsteht wie in Vanillas Test-Pfad
-- (ISMenuContextWorld.lua Z. 48-53): ISContextMenu.get, sofort
-- setVisible(false), danach hideAndChildren und clear; gezeichnet wird
-- nichts. Mit -debug braucht DebugContextMenu.doDebugMenu ein Objekt mit Feld
-- (DebugContextMenu.lua Z. 36-47), darum der Boden unter der Figur.
function PD.medcheck(p, z)
    local s = z.pdFremd
    if not s then return z.pdGrund or "kein Stellvertreter" end
    local feld = p:getCurrentSquare()
    local boden = feld and feld:getFloor()
    if not boden then return "nicht messbar: kein Boden unter der Figur" end
    local nr = p:getPlayerNum()
    local menue = ISContextMenu.get(nr, 0, 0)
    menue:setVisible(false)
    ISWorldObjectContextMenu.clearFetch()
    local fetch = ISWorldObjectContextMenu.fetchVars
    fetch.safehouseAllowInteract, fetch.clickedPlayer = true, s
    -- Seit 6.36.2: ohne dieses Feld haelt createMenuEntries die Stelle fuer ein
    -- fremdes Safehouse und schreibt der Figur rot "You do not have permission
    -- to interact with objects in this safehouse" ueber den Kopf
    -- (ISWorldObjectContextMenuLogic, HaloTextHelper.addBadText). Harmlos, aber
    -- es sah im Lauf vom 20.09.2026 wie ein Fehler des Tests aus.
    fetch.safehouseAllowLoot = true
    local ok, err = pcall(ISWorldObjectContextMenuLogic.createMenuEntries, fetch, menue, nr, { boden }, 0, 0, false)
    local da = ok and menue:getOptionFromName(getText("ContextMenu_Medical_Check")) ~= nil
    PD.menueWeg(menue)
    if not ok then return "Kontextmenue: " .. (string.gsub(tostring(err), "[|\r\n]", " ")) end
    return da and 1 or 0
end

function PD.menueWeg(menue)
    menue:setVisible(false)
    if menue.hideAndChildren then menue:hideAndChildren() end
    menue:clear()
    ISWorldObjectContextMenu.clearFetch()
end

-- Dextrous, Clumsy (/canwound): RecipeCodeOnCreate.openCan (Z. 634-679)
-- wuerfelt je verbrauchter Zutat Rand.Next(20) <= woundChance: 3, Dextrous
-- -2, Clumsy +2, Cooking 0 +1 (bei Short Blade bis 3), also 20, 10, 30 %.
-- Die Zutaten kommen aus getAllConsumedItems, und die Liste fuellt erst das
-- Verbrauchen (appliedItems, CacheData.addAppliedItemsToList).
-- consumeInputs(Liste) gibt als Items null weiter (Bytecode 0-11); dann nimmt
-- consumeRecipeInputs die angebotenen Items (Offsets 302-365), und
-- consumeInputItemInternal traegt sie nur in appliedItems ein (Offset 310),
-- ohne sie aus einem Behaelter zu nehmen. Das Messer ist mode:keep und zaehlt
-- nicht als verbraucht, die Dose schon. Messer und Dose liegen in keinem
-- Inventar; das Messer, das openCan fuer den Schnitt erzeugt (Z. 677), auch
-- nicht. Ein Schnitt ist eine Wunde an Hand_L des Stellvertreters.
PD.DOSE = { proben = 3000, jeTick = 300, toleranz = 4, rezept = "OpenCannedFoodWithKnifeOrSharpStoneFlake" }
function PD.doseVorher(p, z)
    PD.fremdVorher(p, z)
    local s = z.pdFremd
    if not s then return end
    -- Cooking 1 wie die Notiz von TF_Static (cooking1), Short Blade 0
    stufeSetzen(s, Perks.Cooking, 1)
    stufeSetzen(s, Perks.SmallBlade, 0)
    z.pdDose, z.pdGrund = PD.doseDaten()
end

--- Eine CraftRecipeData mit verbrauchter Dose: Handcraft, Items erlaubt,
-- Ressourcen nicht (Konstruktor Offsets 155-182).
function PD.doseDaten()
    if not (CraftRecipeData and CraftMode and RecipeCodeOnCreate and ArrayList) then
        return nil, "Crafting-Klassen fehlen"
    end
    local rezept = getScriptManager():getCraftRecipe(PD.DOSE.rezept)
    if not rezept then return nil, "Rezept " .. PD.DOSE.rezept .. " fehlt" end
    local messer, dose = instanceItem("Base.KitchenKnife"), instanceItem("Base.TinnedBeans")
    if not (messer and dose) then return nil, "Messer oder Dose fehlt" end
    local daten = CraftRecipeData.new(CraftMode.Handcraft, false, true, false, true)
    daten:setRecipe(rezept)
    if not (daten:offerAndReplaceInputItem(messer) and daten:offerAndReplaceInputItem(dose)) then
        return nil, "Rezept nimmt Messer oder Dose nicht an"
    end
    daten:consumeInputs(ArrayList.new())
    local n = daten:getAllConsumedItems():size()
    if n ~= 1 then return nil, "verbrauchte Zutaten: " .. tostring(n) .. " statt 1" end
    return daten
end

function PD.doseProbe(p, z)
    local s, daten = z.pdFremd, z.pdDose
    if not (s and daten) then return nil, z.pdGrund or "Dose nicht vorbereitet" end
    PD.traitsWie(p, s)
    local hand = s:getBodyDamage():getBodyPart(BodyPartType.Hand_L)
    hand:RestoreToFullHealth()
    RecipeCodeOnCreate.openCan(daten, s)
    local schnitt = hand:HasInjury() and 1 or 0
    hand:RestoreToFullHealth()
    return schnitt
end

-- Thick Skinned, Thin Skinned (/zombieinjury): AddRandomDamageFromZombie
-- (BodyDamage Z. 1101-1387) verletzt nicht, wenn Rand.Next(100) <=
-- baseChance (Z. 1228); baseChance 15 + getMeleeCombatMod (Z. 1107), Thick
-- Skinned (int)(x 1.3), Thin Skinned (int)(/ 1.3) (Z. 1125-1130). Ohne Waffe
-- ist die Waffenstufe -1 und der Mod -5 (Z. 10074-10106, 10115-10123): 11,
-- 14 und 8 %. Der Zombie aus IsoZombie.new(getCell()) steht ebenfalls
-- ausserhalb der Welt (IsoZombie Z. 368-416), direkt vor dem Stellvertreter
-- (testDotSide FRONT, Z. 11914-11937) und nicht inaktiv (makeInactive,
-- Z. 4346-4362; inaktiv gaebe +20, Z. 1214-1218). Ohne Feld zaehlt
-- getSurroundingAttackingZombies 0 (Z. 12426-12431), also einer, und niemand
-- zieht ihn zu Boden. Kratzer- und Bissklang spielen nur mit getHealth() > 0
-- (Z. 1244, 1280, 1316, getHealth = OverallBodyHealth Z. 1425); die Gruppe
-- setzt die Gesundheit des Stellvertreters auf 0 und danach auf 100. Blut
-- (Z. 1351-1358) braucht ein Feld, Infektion bleibt an ihm; Schmerzlaute
-- (playerVoiceSound, IsoPlayer Z. 6676-6682) gehen an seinen Emitter, den
-- nachher mit stopAll anhaelt. Toleranz 1.5 Punkte: die Differenz streut bei
-- 12000 Proben je Fall um 0.43 Punkte.
PD.ZOMBIE = { proben = 12000, jeTick = 300, toleranz = 1.5 }
PD.VORNE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
function PD.zombieVorher(p, z)
    PD.fremdVorher(p, z)
    local s = z.pdFremd
    if not s then return end
    z.pdHand = BodyPartType.ToIndex(BodyPartType.Hand_L)
    z.pdBasis = 15 + s:getMeleeCombatMod()
    s:getBodyDamage():setOverallBodyHealth(0)
    z.pdZombie, z.pdGrund = PD.zombieVorFremd(s)
end

--- Wie der Stellvertreter einer je Sitzung an TFMeasure (Review 14.09.2026:
-- jeder neue Zombie liess drei Sound-Emitter bis zum Beenden liegen).
function PD.zombieVorFremd(s)
    local zombie = TFMeasure.pdZombie
    if not zombie then
        if not (IsoZombie and IsoZombie.new) then return nil, "IsoZombie.new fehlt" end
        zombie = IsoZombie.new(getCell())
        TFMeasure.pdZombie = zombie
    end
    if not zombie or zombie:getCurrentSquare() then return nil, "Zombie nicht ausserhalb der Welt" end
    zombie:makeInactive(false)
    for _, d in ipairs(PD.VORNE) do
        zombie:setX(s:getX() + d[1])
        zombie:setY(s:getY() + d[2])
        if s:testDotSide(zombie) == "FRONT" then return zombie end
    end
    return nil, "kein Platz vor dem Stellvertreter"
end

function PD.zombieProbe(p, z)
    local s, zombie = z.pdFremd, z.pdZombie
    if not (s and zombie) then return nil, z.pdGrund or "Zombie nicht vorbereitet" end
    PD.traitsWie(p, s)
    local bd = s:getBodyDamage()
    local hand = bd:getBodyPart(BodyPartType.Hand_L)
    hand:RestoreToFullHealth()
    bd:AddRandomDamageFromZombie(zombie, "Bite", z.pdHand)
    local heil = hand:HasInjury() and 0 or 1
    hand:RestoreToFullHealth()
    return heil
end

--- Sollwert in Punkten aus der Grundchance des Stellvertreters, wie Java
-- abschneidet: (int)(b x 1.3) bzw. (int)(b / 1.3), minus b.
function PD.zombieSoll(z, dick)
    local b = z.pdBasis or 10
    local mit = dick and math.floor(b * 1.3) or math.floor(b / 1.3)
    return mit - b
end
-- [/paket-d]

--- Die Gruppen. traits: je Trait der Faktor laut Code. effekt: der Eintrag in
-- TF_Static, dessen Wert verglichen wird. stichprobe: true = 5 % Toleranz,
-- eine Zahl = diese Toleranz; sonst 0.006. aus: Mittel der Faktoren dieser
-- Gruppen statt einer eigenen Messung. differenz (seit 6.24.0): faktor =
-- mit - ohne statt mit/ohne, fuer Wirkungen, die ohne Trait 0 sind; der
-- Wert der Mod kommt dann auch aus kind "flat". Der Faktor laut Code darf
-- eine Funktion (player, z) sein; sie laeuft nach der Messung.
TFMeasure.WERTE = {
    { id = "panik", effekt = "panic", messen = M.panik,
      traits = { { "brave", 0.3 }, { "cowardly", 2.0 }, { "desensitized", 0 } } },
    -- Ohne effekt: Trait Facts zeigt seit 0.12.1 die gemessene Strecke (+8 %),
    -- nicht mehr diesen Wert aus calculateBaseSpeed; verglichen wird mit dem Code.
    { id = "tempo3", messen = M.tempo3, traits = { { "adrenalinejunkie", 1.25 } },
      notiz = "Grundtempo laut Code; die Strecke misst der Test Adrenalin" },
    { id = "tempo4", messen = M.tempo4, traits = { { "adrenalinejunkie", 1.05 / 0.8 } } },
    { id = "tuer", effekt = "enduranceloss", messen = M.tuer, traits = { { "jogger", 0.9 } },
      vorher = function(p, z) p:setUnlimitedEndurance(false) end,
      nachher = function(p, z) p:setUnlimitedEndurance(TFMeasure.cheatStand.ausdauer ~= false) end },
    { id = "erholung", effekt = "enduranceregen", messen = M.erholung,
      traits = { { "veryunderweight", 0.7 }, { "emaciated", 0.3 }, { "overweight", 0.7 }, { "obese", 0.4 } } },
    -- seit 6.35.0: dieselben vier am Zuwachs der Ausdauer beim Sitzen
    { id = "erholungsitzen", effekt = "enduranceregen", messen = M.erholungSitzen,
      notiz = "Zuwachs der Ausdauer je Aufruf von updateEnduranceWhileSitting, von 0.5 aus, Muedigkeit 0",
      traits = { { "veryunderweight", 0.7 }, { "emaciated", 0.3 }, { "overweight", 0.7 }, { "obese", 0.4 } },
      vorher = function(p, z) p:setUnlimitedEndurance(false) end,
      nachher = function(p, z) p:setUnlimitedEndurance(TFMeasure.cheatStand.ausdauer ~= false) end },
    { id = "rueckstoss", effekt = "knockback", messen = M.rueckstoss,
      traits = { { "strong", 1.4 }, { "weak", 0.6 } },
      vorher = function(p, z) z.keule = instanceItem("Base.BaseballBat") end },
    { id = "zielzeit", effekt = "aimdelay", messen = M.zielzeit,
      traits = { { "dextrous", 0.8 }, { "allthumbs", 1.2 } },
      vorher = function(p, z)
          z.hand0 = p:getPrimaryHandItem()
          z.waffe = p:getInventory():AddItem("Base.Pistol")
          p:setPrimaryHandItem(z.waffe)
      end,
      nachher = function(p, z)
          p:setPrimaryHandItem(z.hand0)
          if z.waffe then p:getInventory():Remove(z.waffe) end
          p:resetAimingDelay()
          z.waffe, z.hand0 = nil, nil
      end },
    { id = "zielruhe", effekt = "aimsteady", messen = M.zielruhe, traits = { { "marksman", 1.1 } },
      vorher = function(p, z)
          z.aiming0 = p:getPerkLevel(Perks.Aiming)
          stufeSetzen(p, Perks.Aiming, 0)
      end,
      nachher = function(p, z)
          if z.aiming0 then stufeSetzen(p, Perks.Aiming, z.aiming0) end
          z.aiming0 = nil
      end },
    { id = "sicht", effekt = "weaponsight", messen = M.sicht, traits = { { "eagleeyed", 1.2 } },
      vorher = function(p, z) z.gewehr = instanceItem("Base.HuntingRifle") end },
    { id = "biss", effekt = "bitewound", messen = M.biss, stichprobe = true,
      traits = { { "fasthealer", 40 / 65 }, { "slowhealer", 115 / 65 } } },
    { id = "schnitt", messen = M.schnitt, stichprobe = true,
      traits = { { "fasthealer", 7.5 / 15 }, { "slowhealer", 25 / 15 } } },
    { id = "kratzer", messen = M.kratzer, stichprobe = true,
      traits = { { "fasthealer", 7 / 11 }, { "slowhealer", 20 / 11 } } },
    { id = "waffenkratzer", messen = M.waffenkratzer, stichprobe = true,
      traits = { { "fasthealer", 3 / 7.5 }, { "slowhealer", 15 / 7.5 } } },
    { id = "fensterkratzer", messen = M.fensterkratzer, stichprobe = true,
      traits = { { "fasthealer", 7.5 / 16 }, { "slowhealer", 25 / 16 } } },
    -- Die Mod fuehrt Schnitte und Kratzer als eine Zeile, das Mittel der vier.
    { id = "schnittkratzer", effekt = "cutwound", stichprobe = true,
      aus = { "schnitt", "kratzer", "waffenkratzer", "fensterkratzer" },
      traits = { { "fasthealer", (7.5 / 15 + 7 / 11 + 3 / 7.5 + 7.5 / 16) / 4 },
                 { "slowhealer", (25 / 15 + 20 / 11 + 15 / 7.5 + 25 / 16) / 4 } } },
    { id = "tiefewunde", effekt = "deepwound", messen = M.tiefewunde, stichprobe = true,
      traits = { { "fasthealer", 13 / 17.5 }, { "slowhealer", 26 / 17.5 } } },
    { id = "bruch", effekt = "fracture", messen = M.bruch,
      traits = { { "fasthealer", 0.6 }, { "slowhealer", 1.8 } } },
    { id = "gift", effekt = "poison", messen = M.gift,
      traits = { { "irongut", 0.5 }, { "weakstomach", 2.0 } } },
    { id = "verdorben", effekt = "foodsick", messen = M.verdorben, stichprobe = 0.2,
      traits = { { "irongut", 0.5 }, { "weakstomach", 2.0 } } },
    { id = "wasser", effekt = "taintedwater", messen = M.wasser,
      traits = { { "irongut", 0 }, { "weakstomach", 1.2 } } },
    { id = "kaelteverlauf", effekt = "coldprogress", messen = M.kaelteverlauf,
      traits = { { "resilient", 0.8 }, { "pronetoillness", 1.2 } } },
    { id = "kaelteerholung", effekt = "coldrecovery", messen = M.kaelteerholung,
      traits = { { "resilient", 1.5 }, { "pronetoillness", 0.5 } } },
    { id = "zombie", effekt = "zombification", messen = M.zombie, stichprobe = true,
      traits = { { "resilient", 1.25 }, { "pronetoillness", 0.75 } } },
    { id = "lesen", effekt = "readtime", messen = M.lesen,
      traits = { { "fastreader", 0.7 }, { "slowreader", 1.3 } },
      vorher = function(p, z) z.buch = instanceItem("Base.BookCarpentry1") end },
    { id = "forschen", effekt = "researchtime", messen = M.forschen,
      traits = { { "fastlearner", 0.7 }, { "slowlearner", 1.3 } },
      vorher = function(p, z) z.apfel = instanceItem("Base.Apple") end },
    { id = "umlagern", effekt = "transfer", messen = M.umlagern,
      traits = { { "dextrous", 0.5 }, { "allthumbs", 2.0 } },
      vorher = function(p, z)
          z.hammer = instanceItem("Base.Hammer")
          z.tasche = instanceItem("Base.Bag_Schoolbag"):getInventory()
      end },
    { id = "bauen", effekt = "buildtime", messen = M.bauen, traits = { { "handy", 0.75 } } },
    { id = "barrikade", effekt = "barricade", messen = M.barrikade, traits = { { "handy", 0.8 } },
      vorher = woodworkNull, nachher = woodworkZurueck },
    { id = "abbauen", effekt = "unbarricade", messen = M.abbauen, traits = { { "handy", 0.9 } },
      vorher = woodworkNull, nachher = woodworkZurueck },
    { id = "xp", effekt = "xp", messen = M.xpcrafty, traits = { { "crafty", 1.3 } } },
    { id = "xp", effekt = "xp", messen = M.xppacifist, traits = { { "pacifist", 0.75 } } },
    -- seit 6.24.0. Ohne effekt seit 6.43.1 (Faktensweep 2, 23.09.2026): der
    -- Test liest die Wuerfelgrenze je Tick, Trait Facts zeigt seit 0.14.1 den
    -- Wert je Versuch (Zuenden und Brechen als Wettlauf, x1.5 und x0.5);
    -- verglichen wird darum mit dem Code je Wurf.
    { id = "grillfeuer", messen = M.grillZuenden, traits = { { "outdoorsman", 2.0 } },
      vorher = M.feuerVorher, nachher = M.feuerNachher },
    { id = "grillbruch", messen = M.grillBrechen, traits = { { "outdoorsman", 300 / 450 } },
      vorher = M.feuerVorher, nachher = M.feuerNachher },
    { id = "lagerfeuer", messen = M.lagerZuenden,
      traits = { { "wildernessknowledge", 2.0 }, { "formerscout", 2.0 } },
      vorher = M.feuerVorher, nachher = M.feuerNachher },
    { id = "lagerbruch", messen = M.lagerBrechen,
      traits = { { "wildernessknowledge", 300 / 450 }, { "formerscout", 300 / 450 } },
      vorher = M.feuerVorher, nachher = M.feuerNachher },
    { id = "leiche", effekt = "corpsestress", messen = M.leiche,
      traits = { { "brave", 0.5 }, { "cowardly", 2.0 }, { "desensitized", 0 } }, vorher = M.umlagernVorher },
    { id = "blutsache", effekt = "blooditems", differenz = true, messen = M.blutsache,
      traits = { { "hemophobic", function(p, z) return z.blutig:getBloodLevelAdjustedLow() end } },
      vorher = M.umlagernVorher },
    { id = "verbinden", effekt = "treatpanic", differenz = true, messen = M.verbinden,
      traits = { { "hemophobic", 50 } }, vorher = function(p, z) z.binde = instanceItem("Base.Bandage") end },
    { id = "lesenseiten", effekt = "reading", messen = M.lesenSeiten, traits = { { "illiterate", 0 } },
      vorher = function(p, z)
          woodworkNull(p, z)
          z.buch = instanceItem("Base.BookCarpentry1")
      end,
      nachher = woodworkZurueck },
    { id = "ei", effekt = "rawegg", messen = M.ei, traits = { { "irongut", 0 } } },
    { id = "krit", effekt = "critchance", differenz = true, messen = M.krit, traits = { { "marksman", 10 } },
      vorher = M.kritVorher, nachher = M.kritNachher },
    { id = "forschungsstufe", effekt = "research", differenz = true, messen = M.forschungsstufe,
      traits = { { "inventive", -2 }, { "inventiveprof", -2 } },
      vorher = function(p, z) z.rezept = getScriptManager():getCraftRecipe("MakeImprovisedLighter") end },
    -- seit 6.25.0: zwei Spielfehler. Der Faktor laut Code ist der mit dem
    -- Fehler; waere er behoben, wiche die Zeile ab.
    { id = "barrikademetall", messen = M.barrikadeMetall, traits = { { "handy", 0.8 } },
      notiz = "Spielfehler metallbarrikade: laut Code ohne 100 wie Bretter, gemeint 170",
      vorher = M.metallNull, nachher = M.metallZurueck },
    { id = "craftweiblich", effekt = "corpsestress", messen = M.craftLeiche("inventoryfemale"),
      traits = { { "brave", 0.5 }, { "cowardly", 2.0 }, { "desensitized", 0 } }, vorher = M.unglueckMerken },
    { id = "craftmaennlich", differenz = true, messen = M.craftLeiche("inventorymale"),
      traits = { { "brave", 0 }, { "cowardly", 0 }, { "desensitized", 0 } }, vorher = M.unglueckMerken,
      notiz = "Spielfehler leichenstress-craft: laut Code ohne 0, keine Wirkung aus maennlichen Leichen" },
    -- seit 6.26.0, je Paket zwischen seinen Markierungen
    -- [paket-a-gruppen]
    -- Stolpern am Zaun: Anteil gestolpert in Prozent, Differenz mit - ohne
    -- (TF_Static fuehrt trip als flat). Ohne 10 %, 3000 Proben je Fall:
    -- Streuung der Differenz hoechstens 1.05 Punkte (40 gegen 10 %), Toleranz
    -- 4 Punkte, fast 4 Streuungen.
    { id = "zaun", effekt = "trip", differenz = true, proben = TFMeasure.ZAUN.proben,
      jeTick = TFMeasure.ZAUN.jeTick, toleranz = TFMeasure.ZAUN.toleranz, probe = M.zaunProbe,
      auswerten = M.anteilProzent, vorher = M.zaunVorher, nachher = M.zaunNachher,
      traits = { { "clumsy", 10 }, { "graceful", -10 }, { "obese", 20 }, { "overweight", 10 } } },
    -- Der Spielfehler: Very Underweight zweimal (+30), Underweight nie (0);
    -- die Proben ohne Trait kommen aus "zaun".
    { id = "zaunfehler", effekt = "trip", differenz = true, probenVon = "zaun", proben = TFMeasure.ZAUN.proben,
      jeTick = TFMeasure.ZAUN.jeTick, toleranz = TFMeasure.ZAUN.toleranz, probe = M.zaunProbe,
      auswerten = M.anteilProzent, vorher = M.zaunVorher, nachher = M.zaunNachher,
      traits = { { "veryunderweight", 30 }, { "underweight", 0 } },
      notiz = "Spielfehler zaun-veryunderweight: laut Code Very Underweight +30 (zweimal abgefragt) und"
          .. " Underweight 0, gemeint wohl +20 und +10" },
    -- Sturz aus Tempo 3.0, 4000 Proben je Fall. Schaden: der groesste je
    -- Fall, das Verhaeltnis ist der Trait-Faktor; Toleranz 1 %.
    { id = "sturzschaden", effekt = "falldamage", probenVon = "sturz", proben = TFMeasure.STURZ.proben,
      jeTick = TFMeasure.STURZ.jeTick, stichprobe = 0.01, probe = M.sturzProbe, auswerten = M.sturzGroesster,
      vorher = M.sturzVorher, nachher = M.sturzNachher, notiz = "Faktor aus dem groessten Schaden je Fall",
      traits = { { "veryunderweight", 1.2 }, { "emaciated", 1.4 }, { "overweight", 1.2 }, { "obese", 1.4 } } },
    -- Verletzung: Anteil Brueche unter den verletzten Proben, laut Code 32 %,
    -- +10 und +20 Punkte. Rund 18 bis 38 % der Proben verletzen: Streuung der
    -- Differenz 2 bis 2.4 Punkte, Toleranz 6. Dieselben Proben wie der
    -- Schaden.
    { id = "sturzverletzung", effekt = "fallinjury", differenz = true, probenVon = "sturz",
      proben = TFMeasure.STURZ.proben, jeTick = TFMeasure.STURZ.jeTick, toleranz = TFMeasure.STURZ.toleranz,
      probe = M.sturzProbe, auswerten = M.sturzBruchAnteil, vorher = M.sturzVorher, nachher = M.sturzNachher,
      notiz = "Anteil Brueche unter den verletzten Proben in Prozent",
      traits = { { "veryunderweight", 10 }, { "emaciated", 20 }, { "overweight", 10 }, { "obese", 20 } } },
    -- Unfall: verlorene Gesundheit je Aufprall, Mittel mit / ohne; 1200 Proben
    -- je Fall, Streuung des Faktors 0.4 %, Toleranz 2 %.
    { id = "unfall", effekt = "vehdamage", probenVon = "unfall", proben = TFMeasure.UNFALL.proben,
      jeTick = TFMeasure.UNFALL.jeTick, stichprobe = 0.02, probe = M.unfallProbe, auswerten = M.unfallVerlust,
      vorher = M.unfallVorher, nachher = M.unfallNachher,
      traits = { { "fasthealer", 0.8 }, { "slowhealer", 1.2 } } },
    -- Der Spielfehler: mittlere Bruchzeit mit / ohne, laut Code 0.920 und
    -- 1.080 (M.unfallBruchSoll) statt 0.6 und 1.8. Rund 1.15 Brueche je
    -- Probe, 28 % Streuung je Bruch: Faktor auf 1.1 %, Toleranz 4 %.
    { id = "unfallbruch", probenVon = "unfall", proben = TFMeasure.UNFALL.proben,
      jeTick = TFMeasure.UNFALL.jeTick, stichprobe = 0.04, probe = M.unfallProbe, auswerten = M.unfallBruchzeit,
      vorher = M.unfallVorher, nachher = M.unfallNachher,
      notiz = "Spielfehler unfallbruch: Bruchzeit ohne den Faktor aus generateFractureNew (0.6 und 1.8),"
          .. " nur ueber den Schaden",
      traits = { { "fasthealer", M.unfallBruchSoll(0.8) }, { "slowhealer", M.unfallBruchSoll(1.2) } } },
    -- [/paket-a-gruppen]
    --
    -- [paket-b-gruppen]
    -- Paket B: genaue Werte in einem Tick. Wo TF_Static nur "info" oder
    -- "fromto" fuehrt, vergleicht die Zeile mit dem Wert laut Code; die
    -- Notiz sagt es.
    { id = "kurzsicht", effekt = "sightrange", messen = M.sichtKurz,
      traits = { { "shortsighted", M.sichtKurzSoll } },
      notiz = "TF_Static fuehrt sightrange als info; laut Code max = min, Faktor min/max",
      vorher = function(p, z) z.gewehr = instanceItem("Base.HuntingRifle") end },
    { id = "unschaerfe", effekt = "blur", differenz = true, messen = M.unschaerfe,
      traits = { { "shortsighted", 1 } },
      notiz = "TF_Static fuehrt blur als info; blurFactor ohne 0, mit 1",
      nachher = function(p, z) if not p:isWearingGlasses() then M.unschaerfeAngleichen(p) end end },
    { id = "gewicht", effekt = "gainweight", differenz = true, messen = M.zunahme,
      traits = { { "weightgain", -300 }, { "weightloss", 800 } },
      notiz = "Kalorienschwelle zum Zunehmen bei 80 kg",
      vorher = M.godAus, nachher = M.godZurueck },
    { id = "hemmung", effekt = "jam", differenz = true, stichprobe = 0.6, messen = M.hemmung,
      traits = { { "dextrous", 2 }, { "allthumbs", -2 } },
      notiz = "Prozent geloest aus 20000 Proben; TF_Static fuehrt jam als fromto (92 zu 94 bzw. 90), verglichen mit"
          .. " der Differenz laut Code",
      vorher = M.hemmungVorher, nachher = M.hemmungNachher },
    { id = "zutaten", effekt = "ingredients", messen = M.zutaten, traits = { { "disorganized", 0 } },
      notiz = "Umlager-Aktionen aus ReturnItemToContainer; TF_Static fuehrt ingredients als info",
      vorher = function(p, z)
          z.hammer = instanceItem("Base.Hammer")
          z.tasche = instanceItem("Base.Bag_Schoolbag"):getInventory()
      end },
    { id = "gehen", effekt = "craftwalk", differenz = true, messen = M.gehen, traits = { { "allthumbs", 1 } },
      notiz = "stopOnWalk (1: Handwerk bricht beim Gehen ab); TF_Static fuehrt craftwalk als info",
      vorher = function(p, z) z.rezeptGehen = M.rezeptZumGehen() end },
    { id = "autolernen", effekt = "autolearn", differenz = true, messen = M.lernstufe,
      traits = { { "inventive", -1 }, { "inventiveprof", -1 } },
      notiz = "kleinste Skill-Stufe, bei der das Rezept von selbst gelernt wird",
      vorher = M.lernVorher, nachher = M.lernNachher },
    { id = "nikotinstress", effekt = "nicotine", differenz = true, messen = M.nikotin("STRESS"),
      traits = { { "smoker", M.nikotinStressSoll } },
      notiz = "Stress beim Rauchen, laut Code stressChange der Zigarette; TF_Static fuehrt nicotine als info",
      vorher = M.nikotinVorher, nachher = M.nikotinNachher },
    { id = "nikotinunglueck", effekt = "nicotine", differenz = true, messen = M.nikotin("UNHAPPINESS"),
      traits = { { "smoker", M.nikotinStressSoll } },
      notiz = "Unzufriedenheit beim Rauchen, laut Code ebenfalls stressChange; TF_Static fuehrt nicotine als info",
      vorher = M.nikotinVorher, nachher = M.nikotinNachher },
    { id = "nikotinuebel", effekt = "nicotine", messen = M.nikotin("FOOD_SICKNESS"),
      traits = { { "smoker", 0 } },
      notiz = "Uebelkeit beim Rauchen, nur ohne Smoker; TF_Static fuehrt nicotine als info",
      vorher = M.nikotinVorher, nachher = M.nikotinNachher },
    { id = "wind", effekt = "windpenalty", stichprobe = 0.03, messen = M.windSteigung,
      traits = { { "marksman", 0.6 } },
      notiz = "Kritchance-Verlust je Windstaerke (Steigung); 3 % Toleranz wegen der ganzzahligen Chance",
      vorher = M.windVorher, nachher = M.windNachher },
    { id = "naehrwerte", effekt = "nutrition", differenz = true, messen = M.naehrwerte,
      traits = { { "nutritionist", 5 } },
      notiz = "Tooltip-Zeilen eines Apfels; TF_Static fuehrt nutrition als info",
      vorher = function(p, z) z.apfel = instanceItem("Base.Apple") end },
    { id = "bleiche", messen = M.trinken(0.5, 0.1), traits = { { "irongut", 0 } },
      notiz = "Spielfehler irongut-bleiche: 0.5 l verseuchtes Wasser mit 0.1 l Bleiche, laut Code nullt Iron Gut"
          .. " das Gift des ganzen Schlucks" },
    { id = "bleicherein", messen = M.trinken(0, 0.1), traits = { { "irongut", 1.0 } },
      notiz = "Gegenprobe zu irongut-bleiche: reine Bleiche, Iron Gut halbiert laut Code nicht" },
    -- [/paket-b-gruppen]
    --
    -- [paket-c-gruppen]
    -- Nur mit -debug (Rang 11): ohne ihn liefern die Gruppen vor jedem
    -- Reflection-Zugriff den Text "kein -debug" (TFMeasure.debugFehlt), die
    -- Zeilen stehen dann als "nicht messbar" mit dieser Notiz.
    { id = "hoerradius", effekt = "noise", differenz = true, messen = M.hoerradius,
      traits = { { "keenhearing", 3.0 }, { "hardofhearing", -1.0 } },
      notiz = "Nur mit -debug (Reflection)" },
    { id = "schritt", effekt = "footsteps", messen = M.schritt,
      traits = { { "graceful", 0.6 }, { "clumsy", 1.2 } },
      vorher = M.schrittVorher, nachher = M.schrittNachher,
      notiz = "Nur mit -debug (Reflection)" },
    { id = "albtraum", effekt = "nightmare", differenz = true, proben = TFMeasure.ALBTRAUM.proben,
      jeTick = TFMeasure.ALBTRAUM.jeTick, toleranz = TFMeasure.ALBTRAUM.toleranz, probe = M.albtraumProbe,
      auswerten = M.anteilProzent, traits = { { "desensitized", 5 } },
      vorher = M.albtraumVorher, nachher = M.albtraumNachher,
      notiz = "Nur mit -debug (Reflection)" },
    -- [/paket-c-gruppen]
    --
    -- [paket-d-krank-gruppen]
    -- Rang 13 und 14, je in einem Tick (Fundstellen an M.leichenVorher und
    -- TFMeasure.KAELTE).
    { id = "leichenkrank", effekt = "corpsesick", messen = M.leichenMessen,
      traits = { { "resilient", 0.75 }, { "pronetoillness", 1.25 } },
      vorher = M.leichenVorher, nachher = M.leichenNachher,
      notiz = "Rate / Grundrate mit sechs Leichen auf dem Feld der Figur, God Mode fuer den Tick aus" },
    { id = "erkaeltung", effekt = "cold", messen = M.kaelteMessen,
      traits = { { "resilient", 0.45 }, { "pronetoillness", 1.7 }, { "outdoorsman", 0.25 } },
      vorher = M.kaelteVorher, nachher = M.kaelteNachher,
      notiz = "Zuwachs von catchACold / (0.003 x delta x Multiplier), Haut fuer den Tick gekuehlt, delta ueber 0.45" },
    { id = "erkaeltungschwelle", messen = M.kaelteMessen,
      traits = { { "resilient", 0 }, { "outdoorsman", 0 } },
      vorher = M.kaelteSchwelleVorher, nachher = M.kaelteNachher,
      notiz = "Spielfehler erkaeltung-schwelle: bei delta 0.12 bis 0.2 zieht der Abbau (0.175) nach dem Trait-Faktor"
          .. " alles wieder ab, laut Code 0 statt x0.45 bzw. x0.25" },
    -- [/paket-d-krank-gruppen]
    -- [paket-d-bau-gruppen]
    -- Spielfehler handy-haltbarkeit: der Faktor laut Code ist der mit dem
    -- Fehler (0); die Gegenprobe zeigt, wo die +100 der Mod stehen.
    { id = "wand", differenz = true, messen = M.wand, traits = { { "handy", 0 } },
      notiz = "Spielfehler handy-haltbarkeit: ISBuildIsoEntity:setInfo rechnet die Lebenspunkte ohne Handy" },
    { id = "holzleben", effekt = "durability", differenz = true, messen = M.holzleben,
      traits = { { "handy", 100 } },
      notiz = "Gegenprobe: buildUtil.getWoodHealth, von keinem Bau im Baumenue gelesen" },
    -- [/paket-d-bau-gruppen]
    -- [paket-d]
    -- Paket D (Rang 10, 22, 23): alle drei an einem Stellvertreter
    -- ausserhalb der Welt (PD.stellvertreter). Wo TF_Static nur "info",
    -- "fromto" oder einen Faktor fuehrt, vergleicht die Zeile mit dem Wert
    -- laut Code; die Notiz sagt es.
    { id = "medcheck", effekt = "medcheck", messen = PD.medcheck, traits = { { "hemophobic", 0 } },
      vorher = PD.fremdVorher, nachher = PD.fremdNachher,
      notiz = "1 = Option Medical Check im Menue fuer einen anderen Spieler (Stellvertreter), 0 = fehlt;"
          .. " TF_Static fuehrt medcheck als info" },
    { id = "dose", effekt = "canwound", differenz = true, proben = PD.DOSE.proben, jeTick = PD.DOSE.jeTick,
      toleranz = PD.DOSE.toleranz, probe = PD.doseProbe, auswerten = M.anteilProzent,
      vorher = PD.doseVorher, nachher = PD.fremdNachher,
      traits = { { "dextrous", -10 }, { "clumsy", 10 } },
      notiz = "Schnitt in Prozent beim Oeffnen mit Kuechenmesser am Stellvertreter (Cooking 1, Short Blade 0);"
          .. " TF_Static fuehrt canwound als fromto 20 zu 10 bzw. 30" },
    { id = "zombieangriff", differenz = true, proben = PD.ZOMBIE.proben, jeTick = PD.ZOMBIE.jeTick,
      toleranz = PD.ZOMBIE.toleranz, probe = PD.zombieProbe, auswerten = M.anteilProzent,
      vorher = PD.zombieVorher, nachher = PD.fremdNachher,
      traits = { { "thickskinned", function(p, z) return PD.zombieSoll(z, true) end },
                 { "thinskinned", function(p, z) return PD.zombieSoll(z, false) end } },
      notiz = "Prozent ohne Verletzung, ein Zombie von vorn, Stellvertreter ohne Waffe (Grundchance 15 - 5);"
          .. " TF_Static fuehrt zombieinjury als pct +30 bzw. -23 auf die Chance" },
    -- [/paket-d]
}

--- Der Wert der Mod als Faktor, aus TF_Static; nil ohne Trait Facts oder
-- ohne Zahl (kind "info"). Mit flach (Gruppen mit differenz, seit 6.24.0)
-- auch ein kind "flat", als Differenz.
local function sollAusMod(trait, effekt, flach)
    local liste = TraitFacts and TraitFacts.Static and TraitFacts.Static[trait]
    if type(liste) ~= "table" then return nil end
    for _, e in ipairs(liste) do
        if e.id == effekt and type(e.value) == "number" then
            if e.kind == "pct" then return 1 + e.value / 100 end
            if e.kind == "mult" then return e.value end
            if flach and e.kind == "flat" then return e.value end
        end
    end
    return nil
end

local function werteAnzahl()
    local n = 0
    for _, g in ipairs(TFMeasure.WERTE) do n = n + #g.traits end
    return n
end

local function urteilen(zeile, g)
    local soll = zeile.mod or zeile.code
    if type(zeile.faktor) ~= "number" or type(soll) ~= "number" then
        zeile.urteil = "nicht messbar"
        return
    end
    local rel = 0
    if g.stichprobe == true then rel = 0.05 elseif type(g.stichprobe) == "number" then rel = g.stichprobe end
    local toleranz = math.max(0.006, rel * math.abs(soll))
    -- Seit 6.26.0: toleranz ist eine feste Toleranz in Einheiten des Faktors
    -- (bei differenz in Punkten), fuer Stichproben, deren Sollwert 0 sein
    -- kann oder deren Streuung nicht mit dem Sollwert waechst.
    if type(g.toleranz) == "number" then toleranz = g.toleranz end
    zeile.urteil = (math.abs(zeile.faktor - soll) <= toleranz) and "stimmt" or "weicht ab"
end

local function werteLive(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "werte" then return end
    local gesamt = werteAnzahl()
    -- Seit 6.26.0 zaehlt eine laufende Stichprobe anteilig (z.stichTeil,
    -- M.stichTick), damit der Balken auch ueber viele Ticks wandert.
    lauf.fortschritt = (#z.zeilen + (z.stichTeil or 0)) / gesamt
    lauf.live = {
        { T("werte_live_werte"), T("paar", tostring(#z.zeilen), tostring(gesamt)) },
        { T("werte_live_stimmen"), tostring(z.stimmen) },
        { T("werte_live_abweichend"), tostring(z.abweichend) },
    }
    lauf.status = T("werte_status", tostring(#z.zeilen), tostring(gesamt))
end

local function einzeilig(text)
    return (string.gsub(tostring(text), "[|\r\n]", " "))
end

local function werteGruppe(player, g, z)
    local container = player:getCharacterTraits()
    if g.vorher then
        local ok, err = pcall(g.vorher, player, z)
        if not ok then log("Code-Werte " .. g.id .. " vorher: " .. tostring(err)) end
    end
    local okOhne, ohne = true, nil
    if g.messen then okOhne, ohne = pcall(g.messen, player, z) end
    for _, paar in ipairs(g.traits) do
        local key = paar[1]
        local zeile = { id = g.id, trait = key, code = paar[2] }
        if g.effekt then zeile.mod = sollAusMod(key, g.effekt, g.differenz) end
        if g.differenz then zeile.notiz = "Differenz mit - ohne" end
        if g.notiz then zeile.notiz = zeile.notiz and (zeile.notiz .. "; " .. g.notiz) or g.notiz end
        if g.aus then
            local summe, n = 0, 0
            for _, andere in ipairs(z.zeilen) do
                for _, id in ipairs(g.aus) do
                    if andere.id == id and andere.trait == key and type(andere.faktor) == "number" then
                        summe = summe + andere.faktor
                        n = n + 1
                    end
                end
            end
            if n == #g.aus then zeile.faktor = summe / n else zeile.fehler = "nicht alle Wundarten messbar" end
        else
            local typ = traitTypeNamed(key)
            if not typ then
                zeile.fehler = "Trait fehlt in der Registry"
            elseif not okOhne or type(ohne) ~= "number" then
                zeile.fehler = "ohne Trait: " .. einzeilig(ohne)
            else
                container:add(typ)
                local okMit, mit = pcall(g.messen, player, z)
                container:remove(typ)
                if okMit and type(mit) == "number" then
                    zeile.ohne, zeile.mit = ohne, mit
                    if g.differenz then
                        zeile.faktor = mit - ohne
                    elseif ohne ~= 0 then
                        zeile.faktor = mit / ohne
                    else
                        zeile.fehler = "ohne Trait 0"
                    end
                else
                    zeile.fehler = "mit Trait: " .. einzeilig(mit)
                end
            end
        end
        -- Ein Sollwert, der erst mit der Messung feststeht (seit 6.24.0),
        -- etwa der Blutwert des Gegenstands.
        if type(zeile.code) == "function" then
            local okCode, code = pcall(zeile.code, player, z)
            zeile.code = (okCode and type(code) == "number") and code or nil
        end
        urteilen(zeile, g)
        if zeile.urteil == "stimmt" then
            z.stimmen = z.stimmen + 1
        elseif zeile.urteil == "weicht ab" then
            z.abweichend = z.abweichend + 1
        else
            z.fehlt = z.fehlt + 1
        end
        z.zeilen[#z.zeilen + 1] = zeile
    end
    if g.nachher then
        local ok, err = pcall(g.nachher, player, z)
        if not ok then log("Code-Werte " .. g.id .. " nachher: " .. tostring(err)) end
    end
end

--- ---------------------------------------------------------------------------
--- Stichproben ueber mehrere Ticks (seit 6.26.0)
--- ---------------------------------------------------------------------------
--
-- Manche Proben sind schwer: DoLand und applyDamageFromVehicleHit rufen je
-- Aufruf BodyDamage.Update, tausende davon in einem Tick waeren ein
-- spuerbarer Ruckler. Eine Gruppe mit proben laeuft darum ueber mehrere
-- Ticks:
--   proben    Proben je Fall (ohne und je Trait)
--   jeTick    Proben je Tick ueber alle Faelle
--   probe     function(p, z): eine Probe; nil zaehlt nicht, ein zweiter
--             Rueckgabewert nennt den Grund
--   auswerten function(liste, z): die Zahl des Falls aus seinen Proben
--             (Mittel, Maximum, Anteil); nil und ein Grund, wenn keine
--   probenVon teilt die Proben mit Gruppen gleicher probe: was dort schon
--             gezogen ist, wird nicht noch einmal gezogen
--   toleranz  feste Toleranz, siehe urteilen
-- Die Faelle wechseln sich von Probe zu Probe ab, wie im Schlaf-Test: was
-- sich waehrend der Gruppe langsam aendert (Musik, Stimmungen, der Boden
-- unter der Figur), trifft alle Faelle gleich, und ein Maximum sieht in jedem
-- Fall dieselben Umstaende. Vor jeder Probe traegt die Figur genau den Trait
-- ihres Falls. vorher laeuft vor der ersten Probe (nicht, wenn schon alles
-- gezogen ist), nachher am Ende und beim Abbruch. Die Zeilen baut danach
-- werteGruppe mit einem messen, das den ausgewerteten Wert des Falls
-- zurueckgibt: Felder, Differenz, Notiz, Code als Funktion und Urteil bleiben
-- so genau wie bei den anderen Gruppen. Gruppen ohne proben laufen wie immer
-- in einem Tick.
TFMeasure.STICH_LEER = 100   -- so viele Versuche ohne gezaehlte Probe, dann gibt ein Fall auf

function M.stichFertig(d, g)
    return d.kaputt or #d.liste >= g.proben or d.versuche >= 2 * g.proben
        or (#d.liste == 0 and d.versuche >= TFMeasure.STICH_LEER)
end

--- Die Faelle einer Gruppe: ohne und jeder Trait, den es gibt; Proben aus
-- einer frueheren Gruppe mit demselben probenVon bleiben.
function M.stichBeginn(g, z)
    z.stichDaten = z.stichDaten or {}
    local familie = g.probenVon or g.id
    local daten = z.stichDaten[familie] or { faelle = {}, ticks = 0 }
    z.stichDaten[familie] = daten
    local st = { g = g, daten = daten, faelle = {}, zug = 0 }
    local keys = { "ohne" }
    for _, paar in ipairs(g.traits) do keys[#keys + 1] = paar[1] end
    for _, key in ipairs(keys) do
        local typ = nil
        if key ~= "ohne" then typ = traitTypeNamed(key) end
        if key == "ohne" or typ then
            local d = daten.faelle[key] or { liste = {}, versuche = 0 }
            daten.faelle[key] = d
            st.faelle[#st.faelle + 1] = { key = key, typ = typ, d = d }
        end
    end
    return st
end

--- Zieht bis zu jeTick Proben, die Faelle im Wechsel; true, sobald die
-- Gruppe ihre Zeilen hat.
function M.stichTick(player, g, z)
    local st = z.stich
    if not st or st.g ~= g then
        st = M.stichBeginn(g, z)
        z.stich = st
    end
    local container = player:getCharacterTraits()
    local gezogen = 0
    while gezogen < (g.jeTick or 100) do
        local fall = nil
        for _ = 1, #st.faelle do
            st.zug = st.zug % #st.faelle + 1
            if not M.stichFertig(st.faelle[st.zug].d, g) then
                fall = st.faelle[st.zug]
                break
            end
        end
        if not fall then break end
        if not st.vorherGelaufen then
            st.vorherGelaufen = true
            if g.vorher then
                local ok, err = pcall(g.vorher, player, z)
                if not ok then log("Code-Werte " .. g.id .. " vorher: " .. tostring(err)) end
            end
        end
        alleTraitsAb(container)
        if fall.typ then container:add(fall.typ) end
        local ok, wert, grund = pcall(g.probe, player, z)
        local d = fall.d
        d.versuche = d.versuche + 1
        if not ok then
            -- Ein Fehler kommt meist wieder: der Fall gibt gleich auf.
            d.grund, d.kaputt = einzeilig(wert), true
        elseif wert ~= nil then
            d.liste[#d.liste + 1] = wert
        elseif grund and not d.grund then
            d.grund = grund
        end
        gezogen = gezogen + 1
    end
    alleTraitsAb(container)
    if gezogen > 0 then st.daten.ticks = st.daten.ticks + 1 end
    local stand, offen = 0, false
    for _, f in ipairs(st.faelle) do
        if M.stichFertig(f.d, g) then
            stand = stand + 1
        else
            offen = true
            stand = stand + #f.d.liste / g.proben
        end
    end
    z.stichTeil = stand / #st.faelle * #g.traits
    if offen then return false end
    M.stichZeilen(player, g, z, st)
    return true
end

--- Wertet jeden Fall aus und laesst werteGruppe die Zeilen bauen.
function M.stichZeilen(player, g, z, st)
    local werte, kleinste, groesste = {}, nil, 0
    for _, f in ipairs(st.faelle) do
        local ok, wert, grund = pcall(g.auswerten, f.d.liste, z)
        if ok and type(wert) == "number" then
            werte[f.key] = wert
        else
            werte[f.key] = (not ok and einzeilig(wert)) or grund or f.d.grund or "keine Probe"
        end
        kleinste = math.min(kleinste or #f.d.liste, #f.d.liste)
        groesste = math.max(groesste, #f.d.liste)
    end
    local info = string.format("%d bis %d Proben je Fall ueber %d Ticks", kleinste or 0, groesste,
        st.daten.ticks)
    local zeilenGruppe = setmetatable({
        vorher = false, nachher = false,
        notiz = g.notiz and (g.notiz .. "; " .. info) or info,
        messen = function(p)
            for _, paar in ipairs(g.traits) do
                if hatTrait(p, paar[1]) then return werte[paar[1]] end
            end
            return werte.ohne
        end,
    }, { __index = g })
    werteGruppe(player, zeilenGruppe, z)
    M.stichEnde(player, z)
end

--- nachher der laufenden Gruppe, falls ihr vorher lief; auch beim Abbruch.
function M.stichEnde(player, z)
    local st = z.stich
    z.stich, z.stichTeil = nil, nil
    if st and st.vorherGelaufen and st.g.nachher then
        local ok, err = pcall(st.g.nachher, player, z)
        if not ok then log("Code-Werte " .. st.g.id .. " nachher: " .. tostring(err)) end
    end
end

local function werteTraitsZurueck(player, z)
    local container = player:getCharacterTraits()
    alleTraitsAb(container)
    for _, typ in ipairs(z.held) do container:add(typ) end
    -- Die Unschaerfe folgt einem Ziel, das nur updateVisionEffects setzt
    -- (sonst nur beim Umziehen, IsoGameCharacter Z. 14166-14169); ohne
    -- diesen Aufruf bliebe es beim Stand der Gruppe unschaerfe, eine
    -- kurzsichtige Figur mit Brille saehe verschwommen (seit 6.26.0).
    if player.updateVisionEffects then player:updateVisionEffects() end
end

local function werteFertig(player, z)
    pcall(werteTraitsZurueck, player, z)
    local function f4(x) return (type(x) == "number") and string.format("%.4f", x) or "-" end
    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.WERTEFILE, true, false)
        local function write(line) writer:write(line .. nl()) end
        write("# Code-Werte: Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        write("# Build " .. buildNummer())
        write("# je Wert ohne und mit Trait gemessen, faktor = mit/ohne; soll_mod aus TF_Static (fehlt ohne"
            .. " Trait Facts oder ohne Zahl), soll_code aus dem gelesenen Code von 42.20")
        write("# verglichen mit soll_mod, sonst soll_code; Toleranz 0.006, bei Stichproben 5 % (verdorbenes"
            .. " Essen 20 %)")
        write(string.format("# Stichproben: je %d Wunden oder Infektionsdauern, %d verdorbene Aepfel",
            TFMeasure.WERTE_PROBEN, TFMeasure.WERTE_ESSEN))
        write("# Gruppen mit differenz (seit 6.24.0): faktor = mit - ohne, weil ohne Trait nichts passiert;"
            .. " die Notiz sagt es")
        write("# Gruppen mit proben (seit 6.26.0): Stichproben ueber mehrere Ticks, die Faelle im Wechsel;"
            .. " toleranz fest in Einheiten des Faktors; die Notiz nennt Proben und Ticks")
        write("")
        write("[ergebnis]")
        write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d",
            #z.zeilen, z.stimmen, z.abweichend, z.fehlt))
        write("")
        write("[werte] id|trait|ohne|mit|faktor|soll_mod|soll_code|urteil|notiz")
        for _, e in ipairs(z.zeilen) do
            local zeile = string.format("wert|%s|%s|%s|%s|%s|%s|%s|%s", e.id, e.trait, f4(e.ohne), f4(e.mit),
                f4(e.faktor), f4(e.mod), f4(e.code), e.urteil)
            local notiz = e.fehler or e.notiz
            if notiz then zeile = zeile .. "|" .. notiz end
            write(zeile)
        end
        writer:close()
    end)
    TFMeasure.werteZustand = nil
    if TFMeasure.lauf and TFMeasure.lauf.id == "werte" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("werte", { werte = #z.zeilen, stimmen = z.stimmen, abweichend = z.abweichend,
                                        fehlt = z.fehlt })
        log("Code-Werte geschrieben: Zomboid/Lua/" .. TFMeasure.WERTEFILE)
        halo(player, T("werte_fertig", T("werte_ergebnis", tostring(#z.zeilen), tostring(z.stimmen),
            tostring(z.abweichend), tostring(z.fehlt))), true)
    else
        log("Code-Werte nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "werte", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.werteStarten(player)
    local z = { held = {}, gruppe = 1, zeilen = {}, stimmen = 0, abweichend = 0, fehlt = 0 }
    local known = player:getCharacterTraits():getKnownTraits()
    if known then
        for index = 0, known:size() - 1 do z.held[#z.held + 1] = known:get(index) end
    end
    TFMeasure.werteZustand = z
    TFMeasure.lauf = { id = "werte", erledigt = 0, fortschritt = 0 }
    werteLive(z)
end

--- Eine Gruppe je Tick; nach der letzten der Bericht.
function TFMeasure.werteTick()
    local z, lauf = TFMeasure.werteZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "werte" then
        TFMeasure.werteAbbrechen(T("werte_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    local g = TFMeasure.WERTE[z.gruppe]
    if not g then
        lauf.erledigt = 2
        werteFertig(player, z)
        return
    end
    alleTraitsAb(player:getCharacterTraits())
    -- Seit 6.26.0 laeuft eine Gruppe mit proben ueber mehrere Ticks
    -- (M.stichTick); die naechste kommt erst, wenn ihre Zeilen stehen.
    if g.proben then
        if not M.stichTick(player, g, z) then
            lauf.erledigt = 1
            werteLive(z)
            return
        end
    else
        werteGruppe(player, g, z)
    end
    z.gruppe = z.gruppe + 1
    lauf.erledigt = 1
    werteLive(z)
end

--- Beendet die Code-Werte ohne Bericht; die Figur bekommt ihre Traits zurueck.
function TFMeasure.werteAbbrechen(grund)
    local z = TFMeasure.werteZustand
    if z then
        -- Seit 6.26.0: eine laufende Stichprobe raeumt auf (ihr nachher).
        if z.stich then pcall(M.stichEnde, getSpecificPlayer(0), z) end
        pcall(werteTraitsZurueck, getSpecificPlayer(0), z)
    end
    TFMeasure.werteZustand = nil
    if TFMeasure.lauf and TFMeasure.lauf.id == "werte" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "werte", text = grund or T("werte_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Wach und Schlaf: gemeinsame Helfer (seit 6.23.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- Alles haengt an einer Tabelle: der Hauptteil dieser Datei hat schon sehr
-- viele lokale Namen, und Lua 5.1 erlaubt je Funktion hoechstens 200.
local SZ = {}

function SZ.stunden()
    local h = nil
    pcall(function() h = getGameTime():getWorldAgeHours() end)
    return h
end

function SZ.tageszeit()
    local h = nil
    pcall(function() h = getGameTime():getTimeOfDay() end)
    return h
end

--- Eine Stunde auf 0 bis unter 24.
function SZ.uhrzeit(h)
    return h - math.floor(h / 24) * 24
end

function SZ.z4(x)
    return (type(x) == "number") and string.format("%.4f", x) or "-"
end

function SZ.traitsMerken(player)
    local held = {}
    local known = player:getCharacterTraits():getKnownTraits()
    if known then
        for index = 0, known:size() - 1 do held[#held + 1] = known:get(index) end
    end
    return held
end

function SZ.traitsZurueck(player, held)
    local container = player:getCharacterTraits()
    alleTraitsAb(container)
    for _, typ in ipairs(held or {}) do container:add(typ) end
end

--- Nimmt der Figur alle Traits ab und setzt genau diese. Das Spiel setzt
-- Gewichts-Traits im Update neu; so ein Trait verfaelschte sonst "ohne".
function SZ.traitsNur(player, keys)
    local container = player:getCharacterTraits()
    alleTraitsAb(container)
    for _, key in ipairs(keys or {}) do
        local typ = traitTypeNamed(key)
        if typ then container:add(typ) end
    end
end

--- Faktor gegen den Wert der Mod, sonst gegen den aus dem Code; rel ist die
-- Toleranz relativ zum Sollwert, mindestens 0.006 wie bei den Code-Werten.
function SZ.urteil(zeile, rel)
    local soll = zeile.mod or zeile.code
    if type(zeile.faktor) ~= "number" or type(soll) ~= "number" then
        zeile.urteil = "nicht messbar"
        return
    end
    local toleranz = math.max(0.006, rel * math.abs(soll))
    zeile.urteil = (math.abs(zeile.faktor - soll) <= toleranz) and "stimmt" or "weicht ab"
end

function SZ.zaehlen(zeilen)
    local stimmen, abweichend, fehlt = 0, 0, 0
    for _, e in ipairs(zeilen) do
        if e.urteil == "stimmt" then
            stimmen = stimmen + 1
        elseif e.urteil == "weicht ab" then
            abweichend = abweichend + 1
        else
            fehlt = fehlt + 1
        end
    end
    return stimmen, abweichend, fehlt
end

--- Jede Phase einer Gruppe gegen das Mittel ihrer Nachbarn ohne Trait; das
-- hebt langsame Drift (Tageszeit, Temperatur) auf. Liefert das Mittel der
-- Verhaeltnisse und wie viele Phasen eingingen.
function SZ.nachbarFaktor(phasen, gruppe, feld)
    local summe, n = 0, 0
    for i, ph in ipairs(phasen) do
        if ph.gruppe == gruppe and type(ph[feld]) == "number" then
            local s, k = 0, 0
            for _, j in ipairs({ i - 1, i + 1 }) do
                local nachbar = phasen[j]
                if nachbar and nachbar.gruppe == "ohne" and type(nachbar[feld]) == "number" then
                    s, k = s + nachbar[feld], k + 1
                end
            end
            if k > 0 and s ~= 0 then
                summe, n = summe + ph[feld] / (s / k), n + 1
            end
        end
    end
    if n == 0 then return nil, 0 end
    return summe / n, n
end

--- God Mode aus und das Heilen des Mess-Mods angehalten: es setzt
-- Muedigkeit, Hunger und Durst in jedem Tick zurueck (godTick).
function SZ.godAus(player, z)
    if z.godAus then return end
    player:setGodMod(false)
    TFMeasure.godPause = true
    z.godAus = true
end

function SZ.godZurueck(player, z)
    if z.godAus and player then
        pcall(function() player:setGodMod(TFMeasure.cheatStand.god ~= false) end)
    end
    TFMeasure.godPause = nil
end

--- Die Schritte im Fenster laufen nur vorwaerts, auch wenn die Figur kurz
-- aufwacht oder sich bewegt.
function SZ.schritt(lauf, n)
    lauf.erledigt = math.max(lauf.erledigt or 0, n)
end

--- ---------------------------------------------------------------------------
--- Wach: Muedigkeit, Durst, Hunger (seit 6.23.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- Drei Raten, die das Spiel nur im Update-Takt rechnet, an einer stehenden
-- Figur ueber Spielzeit (getWorldAgeHours). Alle drei rechnen mit
-- GameTime.getMultiplier, Vorspulen aendert also nichts. Gelesen am
-- 13.09.2026 im Bytecode:
--   Muedigkeit  IsoGameCharacter.updateStats_Awake (Z. 9137-9148): x0.7
--               Wakeful, x1.3 Sleepyhead; im Sitzen oder Ruhen durch 1.5
--   Hunger      ebenda: x getAppetiteMultiplier = (1 - Hunger) x1.5 Hearty
--               Appetite, x0.75 Light Eater; nur solange die Stimmung satt
--               (FOOD_EATEN) auf 0 steht, sonst waechst er gar nicht
--   Durst       IsoGameCharacter.updateThirst (Z. 9234): x2 High Thirst, x0.5
--               Low Thirst
-- Weil der Hunger mit (1 - Hunger) waechst, zaehlt dort die Rate von
-- ln(1 - Hunger); die haengt nicht davon ab, wo er gerade steht.
--
-- Die Phasen wechseln ohne, b, ohne, c und schliessen mit ohne; b traegt
-- Wakeful, High Thirst und Hearty Appetite, c Sleepyhead, Low Thirst und
-- Light Eater. Jeder Trait wirkt auf einen anderen Wert. Danach zwei Phasen
-- satt: die Stimmung haelt BodyDamage.setHealthFromFoodTimer (Moodle.Update,
-- Offset 2338). Dort sollte der Hunger mit und ohne Hearty Appetite stehen
-- (Spielfehler appetit-satt). Eine Phase, in der die Figur geht, sich setzt,
-- aufsteht oder einschlaeft, zaehlt nicht und wird wiederholt.
TFMeasure.WACHFILE = "TraitFacts_wach.txt"
TFMeasure.WACH = {
    runden = 3,             -- je Runde ohne, b, ohne, c
    phaseStunden = 0.5,     -- Spielzeit je Phase
    vorlauf = 2,            -- Ticks nach dem Setzen, bis gemessen wird
    muede = 0.2, hunger = 0.1, durst = 0.1,
    sattTimer = 3000,       -- healthFromFoodTimer in den Phasen satt
    toleranz = 0.02,
    maxVerworfen = 20,
}
TFMeasure.WACH_GRUPPEN = {
    ohne = {}, satt = {},
    b = { "needslesssleep", "highthirst", "heartyappetite" },
    c = { "needsmoresleep", "lowthirst", "lighteater" },
    sattb = { "heartyappetite" },
}
-- Je Wert: das Feld der Phase, der Eintrag in TF_Static und je Trait der
-- Faktor laut Code und die Gruppe, in der er steckt.
TFMeasure.WACH_WERTE = {
    { feld = "muede", effekt = "tiredness",
      traits = { { "needslesssleep", 0.7, "b" }, { "needsmoresleep", 1.3, "c" } } },
    { feld = "durst", effekt = "thirst",
      traits = { { "highthirst", 2.0, "b" }, { "lowthirst", 0.5, "c" } } },
    { feld = "hunger", effekt = "appetite",
      traits = { { "heartyappetite", 1.5, "b" }, { "lighteater", 0.75, "c" } } },
}

function SZ.wachPlan()
    local plan = {}
    for _ = 1, TFMeasure.WACH.runden do
        for _, gruppe in ipairs({ "ohne", "b", "ohne", "c" }) do plan[#plan + 1] = gruppe end
    end
    plan[#plan + 1] = "ohne"
    plan[#plan + 1] = "satt"
    plan[#plan + 1] = "sattb"
    return plan
end

--- Sitzen und Ruhen teilen die Muedigkeit durch 1.5 (updateStats_Awake).
function SZ.sitzt(player)
    for _, name in ipairs({ "isSitOnGround", "isSittingOnFurniture", "isResting" }) do
        local ok, ja = pcall(function() return player[name](player) end)
        if ok and ja == true then return true end
    end
    return false
end

function SZ.sattStufe(player)
    local stufe = 0
    pcall(function() stufe = player:getMoodles():getMoodleLevel(MoodleType.FOOD_EATEN) end)
    return tonumber(stufe) or 0
end

function SZ.wachWerte(player)
    return statLesen(player, "FATIGUE"), statLesen(player, "HUNGER"), statLesen(player, "THIRST")
end

function SZ.wachLive(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "wach" then return end
    lauf.fortschritt = #z.phasen / #z.plan
    local gruppe = z.plan[#z.phasen + 1]
    lauf.live = {
        { T("wach_live_phasen"), T("paar", tostring(#z.phasen), tostring(#z.plan)) },
        { T("wach_live_verworfen"), tostring(z.verworfen) },
        { T("wach_live_gruppe"), gruppe and T("wach_gruppe_" .. gruppe) or "-" },
    }
end

function SZ.wachAufraeumen(player, z)
    if player then
        pcall(SZ.traitsZurueck, player, z.held)
        pcall(function()
            statSetzen(player, "FATIGUE", z.muede0)
            statSetzen(player, "HUNGER", z.hunger0)
            statSetzen(player, "THIRST", z.durst0)
        end)
        pcall(function() player:getBodyDamage():setHealthFromFoodTimer(z.satt0 or 0) end)
    end
    SZ.godZurueck(player, z)
    TFMeasure.wachZustand = nil
end

--- Verwirft die laufende Phase; true, wenn der Test deshalb abbricht.
function SZ.wachVerwerfen(z)
    z.phase = nil
    z.verworfen = z.verworfen + 1
    if z.verworfen > TFMeasure.WACH.maxVerworfen then
        TFMeasure.wachAbbrechen(T("wach_zuoft"))
        return true
    end
    return false
end

function SZ.wachFertig(player, z)
    local cfg = TFMeasure.WACH
    local normal, satt = {}, {}
    for _, ph in ipairs(z.phasen) do
        if ph.gruppe == "satt" or ph.gruppe == "sattb" then
            satt[ph.gruppe] = ph
        else
            normal[#normal + 1] = ph
        end
    end
    local zeilen = {}
    for _, w in ipairs(TFMeasure.WACH_WERTE) do
        for _, paar in ipairs(w.traits) do
            local faktor, n = SZ.nachbarFaktor(normal, paar[3], w.feld)
            local zeile = { feld = w.feld, trait = paar[1], code = paar[2], mod = sollAusMod(paar[1], w.effekt),
                            faktor = faktor, n = n }
            SZ.urteil(zeile, cfg.toleranz)
            zeilen[#zeilen + 1] = zeile
        end
    end
    local stimmen, abweichend, fehlt = SZ.zaehlen(zeilen)
    -- Der Hunger je Stunde ohne Trait, zum Vergleich mit den Phasen satt.
    local summe, n = 0, 0
    for _, ph in ipairs(normal) do
        if ph.gruppe == "ohne" and type(ph.hungerRoh) == "number" then
            summe, n = summe + ph.hungerRoh, n + 1
        end
    end
    local hungerNormal = (n > 0) and summe / n or nil
    local so, sb = satt.satt, satt.sattb
    local sattUrteil = "nicht messbar"
    if so and sb and hungerNormal and hungerNormal > 0 and so.stufe > 0 and sb.stufe > 0 then
        local grenze = 0.01 * hungerNormal
        local steht = math.abs(so.hungerRoh) <= grenze and math.abs(sb.hungerRoh) <= grenze
        sattUrteil = steht and "steht" or "waechst"
    end
    local tempo = "?"
    pcall(function() tempo = tostring(getGameSpeed()) end)
    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.WACHFILE, true, false)
        local function write(line) writer:write(line .. nl()) end
        write("# Wach: Muedigkeit, Durst, Hunger, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        write("# Build " .. buildNummer())
        write(string.format("# Spieltempo am Ende %s; je Phase %s Spielstunden, Start Muedigkeit %s, Hunger %s,"
            .. " Durst %s", tempo, tostring(cfg.phaseStunden), tostring(cfg.muede), tostring(cfg.hunger),
            tostring(cfg.durst)))
        write("# je Wert die Rate je Spielstunde; beim Hunger die von ln(1 - Hunger), weil er mit (1 - Hunger)"
            .. " waechst (getAppetiteMultiplier)")
        write("# faktor = Phase mit Trait / Mittel der Nachbarphasen ohne, ueber alle Runden gemittelt;"
            .. " Toleranz 2 %")
        write("# laut Code: updateStats_Awake Wakeful x0.7, Sleepyhead x1.3; updateThirst x2, x0.5;"
            .. " getAppetiteMultiplier x1.5, x0.75")
        write("")
        write("[ergebnis]")
        write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d|satt=%s|phasen=%d"
            .. "|verworfen=%d", #zeilen, stimmen, abweichend, fehlt, sattUrteil, #z.phasen, z.verworfen))
        write("")
        write("[werte] wert|trait|faktor|soll_mod|soll_code|urteil|phasen")
        for _, e in ipairs(zeilen) do
            write(string.format("wert|%s|%s|%s|%s|%s|%s|%d", e.feld, e.trait, SZ.z4(e.faktor), SZ.z4(e.mod),
                SZ.z4(e.code), e.urteil, e.n or 0))
        end
        write("")
        write("[satt] Hunger je Spielstunde; stufe ist die Stimmung satt (FOOD_EATEN), steht = beide Raten"
            .. " unter 1 % der normalen")
        write(string.format("satt|normal_ohne=%s|satt_ohne=%s|satt_hearty=%s|stufe_ohne=%d|stufe_hearty=%d"
            .. "|urteil=%s", SZ.z4(hungerNormal), SZ.z4(so and so.hungerRoh), SZ.z4(sb and sb.hungerRoh),
            so and so.stufe or -1, sb and sb.stufe or -1, sattUrteil))
        write("")
        write("[phasen] nr|gruppe|stunden|muede_je_h|durst_je_h|hunger_je_h|hunger_ln_je_h|sitzt|satt_stufe")
        for index, ph in ipairs(z.phasen) do
            write(string.format("phase|%d|%s|%s|%s|%s|%s|%s|%d|%d", index, ph.gruppe, SZ.z4(ph.stunden),
                SZ.z4(ph.muede), SZ.z4(ph.durst), SZ.z4(ph.hungerRoh), SZ.z4(ph.hunger), ph.sitzt and 1 or 0,
                ph.stufe or 0))
        end
        writer:close()
    end)
    SZ.wachAufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == "wach" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("wach", { werte = #zeilen, stimmen = stimmen, abweichend = abweichend, fehlt = fehlt,
                                      satt = sattUrteil })
        log("Wach-Test geschrieben: Zomboid/Lua/" .. TFMeasure.WACHFILE)
        halo(player, T("wach_fertig", T("wach_ergebnis", tostring(#zeilen), tostring(stimmen),
            tostring(abweichend), tostring(fehlt))), true)
    else
        log("Wach-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "wach", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.wachStarten(player)
    local muede, hunger, durst = SZ.wachWerte(player)
    local satt0 = 0
    pcall(function() satt0 = player:getBodyDamage():getHealthFromFoodTimer() end)
    local z = { held = SZ.traitsMerken(player), plan = SZ.wachPlan(), phasen = {}, verworfen = 0,
                muede0 = muede, hunger0 = hunger, durst0 = durst, satt0 = satt0 }
    TFMeasure.wachZustand = z
    TFMeasure.lauf = { id = "wach", erledigt = 0, fortschritt = 0, status = T("wach_status_ruhig") }
    SZ.wachLive(z)
end

function TFMeasure.wachTick()
    local z, lauf = TFMeasure.wachZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "wach" then
        TFMeasure.wachAbbrechen(T("wach_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    local cfg = TFMeasure.WACH
    SZ.godAus(player, z)
    local gruppe = z.plan[#z.phasen + 1]
    if not gruppe then
        SZ.schritt(lauf, 5)
        SZ.wachFertig(player, z)
        return
    end
    local satt = (gruppe == "satt" or gruppe == "sattb")
    SZ.schritt(lauf, satt and 3 or 2)
    -- Die Stimmung satt haengt am Timer, der im Spiel herunterzaehlt; er wird
    -- deshalb in jedem Tick gesetzt, ausserhalb der Phasen satt auf 0.
    player:getBodyDamage():setHealthFromFoodTimer(satt and cfg.sattTimer or 0)
    if player:isAsleep() or player:isPlayerMoving() then
        if z.phase and SZ.wachVerwerfen(z) then return end
        lauf.status = T("wach_status_ruhig")
        SZ.wachLive(z)
        return
    end
    if not z.phase then
        SZ.traitsNur(player, TFMeasure.WACH_GRUPPEN[gruppe])
        statSetzen(player, "FATIGUE", cfg.muede)
        statSetzen(player, "HUNGER", cfg.hunger)
        statSetzen(player, "THIRST", cfg.durst)
        z.phase = { gruppe = gruppe, ticks = 0, sitzt = SZ.sitzt(player) }
        lauf.status = T("wach_status_misst", tostring(#z.phasen + 1), tostring(#z.plan),
            T("wach_gruppe_" .. gruppe))
        SZ.wachLive(z)
        return
    end
    local ph = z.phase
    ph.ticks = ph.ticks + 1
    if SZ.sitzt(player) ~= ph.sitzt then
        SZ.wachVerwerfen(z)
        return
    end
    if ph.ticks < cfg.vorlauf then return end
    if ph.ticks == cfg.vorlauf then
        ph.stufe = SZ.sattStufe(player)
        -- Mit der Stimmung satt waechst der Hunger nicht; ausserhalb der
        -- Phasen satt muss sie weg sein.
        if not satt and ph.stufe > 0 then
            SZ.wachVerwerfen(z)
            return
        end
        ph.t0 = SZ.stunden()
        ph.m0, ph.h0, ph.d0 = SZ.wachWerte(player)
        return
    end
    local jetzt = SZ.stunden()
    if not jetzt or not ph.t0 or jetzt - ph.t0 < cfg.phaseStunden then
        SZ.wachLive(z)
        return
    end
    local m1, h1, d1 = SZ.wachWerte(player)
    ph.stunden = jetzt - ph.t0
    ph.muede = (m1 - ph.m0) / ph.stunden
    ph.durst = (d1 - ph.d0) / ph.stunden
    ph.hungerRoh = (h1 - ph.h0) / ph.stunden
    if h1 < 1 and ph.h0 < 1 then ph.hunger = math.log((1 - ph.h0) / (1 - h1)) / ph.stunden end
    z.phasen[#z.phasen + 1] = ph
    z.phase = nil
    SZ.wachLive(z)
end

--- Beendet den Wach-Test ohne Bericht: Traits, Werte, Satt-Timer und God
-- Mode zurueck.
function TFMeasure.wachAbbrechen(grund)
    local z = TFMeasure.wachZustand
    if z then SZ.wachAufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == "wach" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "wach", text = grund or T("wach_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Schlaf: Dauer, Einschlafen, Erholung (seit 6.23.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- Die Figur legt sich einmal hin; alles Weitere macht der Test, solange sie
-- schlaeft. Vorher setzt er die Muedigkeit auf 0.9 und die Panik auf 0, sonst
-- laesst Vanilla sie nicht schlafen (ISWorldObjectContextMenu.lua:1061-1070).
--
-- 1. Schlafdauer: je Fall 200 Aufrufe der Vanilla-Funktion fuers Hinlegen,
--    ISWorldObjectContextMenu.onSleepWalkToComplete (Z. 1054-1131), mit
--    Muedigkeit 0.9; gelesen wird die Weckzeit. Laut Code x0.5 Restless
--    Sleeper, x0.75 Wakeful, x1.18 Sleepyhead, dann auf 3 bis 16 Stunden
--    geklemmt. Vanilla speichert nach jedem Hinlegen die Welt (save(true),
--    Z. 1129); fuer die Proben ist save stumm. Jeder Aufruf wuerfelt in
--    setPlayerFallAsleep auch einen Albtraum; damit er nicht weckt, haelt der
--    Test die Schlafzeit jeden Tick auf 0 (schlafdatenWeg).
-- 2. Einschlafen: SleepingEvent.doDelayToSleep (privat) setzt
--    delayToActuallySleep = Tageszeit + Rand(0, Deckel), Deckel 0.3 Stunden,
--    mit Restless Sleeper 1.0, Night Owl x0.5, hoechstens 2 (Offsets
--    0-272). Erholt wird erst, wenn timeOfSleep darueber liegt
--    (IsoPlayer.updateStats_Sleeping, Offsets 245-288). Der Test ruft
--    setPlayerFallAsleep und sucht den Zufallswert je Probe durch
--    Intervallhalbierung: setTimeOfSleep probeweise verschieben, einen Tick
--    warten, sinkt die Muedigkeit? Den Schritt, um den das Spiel timeOfSleep
--    je Tick weiterzaehlt, rechnet er heraus. Geschaetzt wird der Deckel aus
--    dem groessten Wert, x (n + 1) / n; bei einer Gleichverteilung ist das
--    viel genauer als der Mittelwert.
-- 3. Erholung: Phasen zu 20 Spielminuten im Wechsel ohne und mit Trait, je
--    mit Muedigkeit 0.8 und abgelaufener Wartezeit. Ueber 0.3 baut der
--    Schlaf 0.7 Punkte in 5 Stunden ab, geteilt durch 0.75 (Wakeful) oder
--    1.18 (Sleepyhead), mal 0.5 (Restless Sleeper) oder 1.4 (Night Owl).
--
-- Die Weckzeit setzt der Test laufend 6 Stunden voraus. Wacht die Figur
-- trotzdem auf, zaehlt die laufende Probe oder Phase nicht, und er legt sie
-- selbst zurueck ins Bett (SZ.hinlegen); die Sperre des Kontextmenues hebt er
-- auf, solange sie wach ist. Am Ende weckt er sie (SleepingEvent.wakeUp) und gibt
-- Traits und Muedigkeit zurueck.
TFMeasure.SCHLAFFILE = "TraitFacts_schlaf.txt"
TFMeasure.SCHLAF = {
    muede = 0.9,            -- vor dem Hinlegen und vor jeder Dauer-Probe
    dauerProben = 200,
    dauerJeTick = 50,
    einschlafProben = 300,  -- bis 6.23.2: 150; beim Deckel reisst der Zufall 3 % dann nur noch mit 0.01 %
    suchSchritte = 12,      -- 2 Stunden / 2^12 = rund 2 Sekunden Spielzeit
    suchBis = 2.0,          -- Deckel der Wartezeit in doDelayToSleep
    erholStart = 0.8,       -- ueber 0.3: der Abschnitt mit 0.7 Punkten in 5 Stunden
    erholStunden = 1 / 3,
    erholRunden = 2,
    vorlauf = 2,
    weckIn = 6,
    maxVerworfen = 20,
}
-- Je Fall der Trait und sein Faktor laut Code.
TFMeasure.SCHLAF_DAUER = {
    { "ohne" }, { "insomniac", 0.5 }, { "needslesssleep", 0.75 }, { "needsmoresleep", 1.18 },
}
TFMeasure.SCHLAF_EINSCHLAFEN = { { "ohne" }, { "insomniac", 1.0 / 0.3 }, { "nightowl", 0.5 } }
TFMeasure.SCHLAF_ERHOLUNG = {
    { "needslesssleep", 1 / 0.75 }, { "needsmoresleep", 1 / 1.18 }, { "insomniac", 0.5 }, { "nightowl", 1.4 },
}

function SZ.schlafPlan()
    local plan = {}
    for _ = 1, TFMeasure.SCHLAF.erholRunden do
        for _, fall in ipairs(TFMeasure.SCHLAF_ERHOLUNG) do
            plan[#plan + 1] = "ohne"
            plan[#plan + 1] = fall[1]
        end
    end
    plan[#plan + 1] = "ohne"
    return plan
end

function SZ.nurFall(player, key)
    SZ.traitsNur(player, (key ~= "ohne") and { key } or nil)
end

--- Haelt die Weckereignisse des Spiels fern. SleepingEvent.update weckt die
-- Figur, sobald (int) getAsleepTime() die gewuerfelte Albtraum- oder
-- Einbrecher-Stunde erreicht (Offsets 97-213, mindestens Stunde 3); sonst
-- liest niemand die Schlafzeit, und Vanilla setzt sie beim Hinlegen selbst
-- auf 0. Die SleepingEventData ist nicht fuer Lua freigegeben: 6.23.0 rief
-- dort reset() und bekam je Aufruf eine Ausnahme ins Log.
function SZ.schlafdatenWeg(player)
    pcall(function() player:setAsleepTime(0) end)
end

--- Legt die Figur mit Vanillas Funktion ins bekannte Bett, ohne Speichern
-- (Vanilla speichert nach jedem Hinlegen, ISWorldObjectContextMenu.lua:1127).
-- Das Kontextmenue sperrt eine Stunde nach dem Aufwachen ("Can't get back to
-- sleep"); die Funktion selbst fragt das nicht.
function SZ.hinlegen(player, z)
    local nummer = 0
    pcall(function() nummer = player:getPlayerNum() end)
    local altSave = save
    save = function() end
    local ok, err = pcall(function() ISWorldObjectContextMenu.onSleepWalkToComplete(nummer, z.bett) end)
    save = altSave
    SZ.schlafdatenWeg(player)
    if not ok then error(err) end
end

function SZ.weckzeit(player)
    local tag = SZ.tageszeit()
    if tag then player:setForceWakeUpTime(SZ.uhrzeit(tag + TFMeasure.SCHLAF.weckIn)) end
end

--- Um wie viel updateStats_Sleeping timeOfSleep je Tick weiterzaehlt
-- (Offsets 245-266): 1 / MinutesPerDay / 60 x Multiplier / 2.
function SZ.schlafSchrittweite()
    local d = 0
    pcall(function()
        local gt = getGameTime()
        d = 1 / gt:getMinutesPerDay() / 60 * gt:getMultiplier() / 2
    end)
    return d
end

function SZ.mittel(liste)
    if not liste or #liste == 0 then return nil end
    local summe = 0
    for _, v in ipairs(liste) do summe = summe + v end
    return summe / #liste
end

function SZ.grenzen(liste)
    local klein, gross = nil, nil
    for _, v in ipairs(liste or {}) do
        if not klein or v < klein then klein = v end
        if not gross or v > gross then gross = v end
    end
    return klein, gross
end

--- Deckel einer Gleichverteilung auf [0, Deckel]: groesster Wert x (n + 1) / n.
function SZ.deckel(liste)
    local _, gross = SZ.grenzen(liste)
    if not gross then return nil end
    return gross * (#liste + 1) / #liste
end

function SZ.schlafLive(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "schlaf" then return end
    local cfg = TFMeasure.SCHLAF
    local gesamt = #TFMeasure.SCHLAF_DAUER * cfg.dauerProben
        + #TFMeasure.SCHLAF_EINSCHLAFEN * cfg.einschlafProben + #z.plan
    local erledigt = #z.phasen
    for _, liste in pairs(z.dauer) do erledigt = erledigt + #liste end
    for _, liste in pairs(z.einschlafen) do erledigt = erledigt + #liste end
    lauf.fortschritt = erledigt / gesamt
    lauf.live = {
        { T("schlaf_live_teil"), T("schlaf_teil_" .. z.teil) },
        { T("schlaf_live_stand"), T("paar", tostring(erledigt), tostring(gesamt)) },
        { T("schlaf_live_verworfen"), tostring(z.verworfen) },
    }
end

function SZ.schlafAufraeumen(player, z)
    if player then
        pcall(SZ.traitsZurueck, player, z.held)
        SZ.schlafdatenWeg(player)
        pcall(function() statSetzen(player, "FATIGUE", z.muede0) end)
        if z.hingelegt then
            pcall(function() getSleepingEvent():wakeUp(player) end)
            pcall(function()
                if player:isAsleep() then player:setForceWakeUpTime(SZ.uhrzeit(SZ.tageszeit() + 0.05)) end
            end)
        end
    end
    SZ.godZurueck(player, z)
    TFMeasure.schlafZustand = nil
end

--- Verwirft die laufende Probe oder Phase; true, wenn der Test abbricht.
function SZ.schlafVerwerfen(z)
    z.probe, z.phase = nil, nil
    z.verworfen = z.verworfen + 1
    if z.verworfen > TFMeasure.SCHLAF.maxVerworfen then
        TFMeasure.schlafAbbrechen(T("schlaf_zuoft"))
        return true
    end
    return false
end

--- Der naechste Fall im Wechsel, der noch Proben braucht; nil, wenn alle
-- voll sind. Seit 6.23.3 wechseln die Faelle von Probe zu Probe: am
-- 13.09.2026 kam Night Owl als letzter Fall allein am Ende dran und lag 3.4 %
-- unter dem Code, die beiden anderen Faelle auf 0.1 %. Im Wechsel trifft
-- jede Drift alle Faelle gleich.
function SZ.naechsterFall(listen, faelle, soll, z, feld)
    for _ = 1, #faelle do
        z[feld] = (z[feld] or 0) % #faelle + 1
        if #(listen[z[feld]] or {}) < soll then return z[feld] end
    end
    return nil
end

function SZ.stimmung(player, name)
    local stufe = 0
    pcall(function() stufe = player:getMoodles():getMoodleLevel(MoodleType[name]) end)
    return tonumber(stufe) or 0
end

--- Teil 1: je Tick bis zu dauerJeTick Aufrufe der Vanilla-Funktion, die
-- Faelle im Wechsel von Aufruf zu Aufruf.
function SZ.schlafDauer(player, z, lauf)
    local cfg = TFMeasure.SCHLAF
    local faelle = TFMeasure.SCHLAF_DAUER
    local nummer = 0
    pcall(function() nummer = player:getPlayerNum() end)
    local altSave = save
    save = function() end
    local fertig = false
    local ok, err = pcall(function()
        for _ = 1, cfg.dauerJeTick do
            local index = SZ.naechsterFall(z.dauer, faelle, cfg.dauerProben, z, "dauerZug")
            if not index then
                fertig = true
                break
            end
            local proben = z.dauer[index] or {}
            z.dauer[index] = proben
            SZ.nurFall(player, faelle[index][1])
            statSetzen(player, "FATIGUE", cfg.muede)
            statSetzen(player, "PANIC", 0)
            player:setForceWakeUpTime(-1)
            local tag = SZ.tageszeit()
            ISWorldObjectContextMenu.onSleepWalkToComplete(nummer, z.bett)
            local weck = player:getForceWakeUpTime()
            if weck < 0 then
                z.abgelehnt = z.abgelehnt + 1
            else
                proben[#proben + 1] = SZ.uhrzeit(weck - tag)
            end
            SZ.schlafdatenWeg(player)
        end
    end)
    save = altSave
    SZ.weckzeit(player)
    if not ok then error(err) end
    if z.abgelehnt > cfg.dauerProben then
        TFMeasure.schlafAbbrechen(T("schlaf_abgelehnt"))
        return
    end
    if fertig then
        z.teil = "einschlafen"
        return
    end
    local n = 0
    for index = 1, #faelle do n = n + #(z.dauer[index] or {}) end
    lauf.status = T("schlaf_status_misst", T("schlaf_teil_dauer"), tostring(n),
        tostring(cfg.dauerProben * #faelle), T("schlaf_fall_" .. faelle[z.dauerZug or 1][1]))
end

--- Setzt die naechste Probe. Das Spiel zaehlt timeOfSleep vor dem Vergleich
-- um einen Schritt weiter; damit der Vergleich genau die Mitte des
-- Intervalls prueft, liegt die Probe einen Schritt darunter. Bis 6.23.3 lag
-- sie auf der Mitte, und die Grenzen wurden um den Schritt verschoben: sobald
-- das Intervall enger als ein Schritt war, meldete jede Probe "offen", die
-- Suche lernte nichts mehr, und jede Wartezeit blieb um bis zu einen halben
-- Schritt ungenau. Im Schlaf waren das 0.0093 Stunden je Tick; bei Night
-- Owls Deckel von 0.12 Stunden ergab das in zwei Laeufen genau x0.4832.
function SZ.probeSetzen(player, pr)
    pr.schritt = SZ.schlafSchrittweite()
    pr.mitte = (pr.lo + pr.hi) / 2
    player:setTimeOfSleep(pr.t0 + pr.mitte - pr.schritt)
    statSetzen(player, "FATIGUE", TFMeasure.SCHLAF.erholStart)
end

--- Teil 2: eine Probe ist ein Aufruf von setPlayerFallAsleep und dann je
-- Tick ein Schritt der Intervallhalbierung; die Faelle wechseln von Probe zu
-- Probe. Je Probe merkt sich der Test die Stimmungen Stress und Schmerz, die
-- doDelayToSleep einrechnet (Stress x1.2, Schmerz + 1 + 0.2 je Stufe), und
-- die Schrittweite, damit sich eine Abweichung erklaeren laesst.
function SZ.schlafEinschlafen(player, z, lauf)
    local cfg = TFMeasure.SCHLAF
    local faelle = TFMeasure.SCHLAF_EINSCHLAFEN
    local pr = z.probe
    if not pr then
        local index = SZ.naechsterFall(z.einschlafen, faelle, cfg.einschlafProben, z, "einschlafZug")
        if not index then
            z.teil = "erholung"
            return
        end
        SZ.nurFall(player, faelle[index][1])
        statSetzen(player, "PANIC", 0)
        local tag = SZ.tageszeit()
        getSleepingEvent():setPlayerFallAsleep(player, 8)
        SZ.schlafdatenWeg(player)
        SZ.weckzeit(player)
        pr = { index = index, t0 = tag, lo = 0, hi = cfg.suchBis, schritte = 0,
               stress = SZ.stimmung(player, "STRESS"), schmerz = SZ.stimmung(player, "PAIN") }
        z.probe = pr
        SZ.probeSetzen(player, pr)
        local n = 0
        for i = 1, #faelle do n = n + #(z.einschlafen[i] or {}) end
        lauf.status = T("schlaf_status_misst", T("schlaf_teil_einschlafen"), tostring(n),
            tostring(cfg.einschlafProben * #faelle), T("schlaf_fall_" .. faelle[index][1]))
        return
    end
    -- Im Tick dazwischen hat updateStats_Sleeping timeOfSleep um einen
    -- Schritt weitergezaehlt und erst dann verglichen, also genau an der
    -- Mitte: sinkt die Muedigkeit, liegt die Wartezeit darunter.
    if statLesen(player, "FATIGUE") < cfg.erholStart - 1e-6 then
        pr.hi = pr.mitte
    else
        pr.lo = pr.mitte
    end
    pr.schritte = pr.schritte + 1
    if pr.schritte < cfg.suchSchritte then
        SZ.probeSetzen(player, pr)
        return
    end
    local proben = z.einschlafen[pr.index] or {}
    z.einschlafen[pr.index] = proben
    proben[#proben + 1] = (pr.lo + pr.hi) / 2
    z.einschlafMehr = z.einschlafMehr or {}
    local mehr = z.einschlafMehr[pr.index] or { stress = 0, schmerz = 0, schritt = 0 }
    z.einschlafMehr[pr.index] = mehr
    if pr.stress > 0 then mehr.stress = mehr.stress + 1 end
    if pr.schmerz > 0 then mehr.schmerz = mehr.schmerz + 1 end
    mehr.schritt = mehr.schritt + (pr.schritt or 0)
    z.probe = nil
end

--- Teil 3: die Erholung je Spielstunde, Phase fuer Phase.
function SZ.schlafErholung(player, z, lauf)
    local cfg = TFMeasure.SCHLAF
    local gruppe = z.plan[#z.phasen + 1]
    if not gruppe then
        SZ.schritt(lauf, 5)
        SZ.schlafFertig(player, z)
        return
    end
    lauf.status = T("schlaf_status_misst", T("schlaf_teil_erholung"), tostring(#z.phasen + 1), tostring(#z.plan),
        T("schlaf_fall_" .. gruppe))
    if not z.phase then
        SZ.nurFall(player, gruppe)
        statSetzen(player, "FATIGUE", cfg.erholStart)
        -- Die Wartezeit ist vorbei: delayToActuallySleep unter timeOfSleep.
        player:setDelayToSleep(0)
        SZ.weckzeit(player)
        SZ.schlafdatenWeg(player)
        z.phase = { gruppe = gruppe, ticks = 0 }
        return
    end
    local ph = z.phase
    ph.ticks = ph.ticks + 1
    if ph.ticks < cfg.vorlauf then return end
    if ph.ticks == cfg.vorlauf then
        ph.t0, ph.von = SZ.stunden(), statLesen(player, "FATIGUE")
        return
    end
    local jetzt = SZ.stunden()
    if not jetzt or not ph.t0 or jetzt - ph.t0 < cfg.erholStunden then return end
    ph.bis = statLesen(player, "FATIGUE")
    ph.stunden = jetzt - ph.t0
    ph.rate = (ph.von - ph.bis) / ph.stunden
    z.phasen[#z.phasen + 1] = ph
    z.phase = nil
end

function SZ.schlafFertig(player, z)
    local zeilen = {}
    -- Die Stunden kommen aus ZombRand in ganzen Zahlen: das Verhaeltnis der
    -- groessten Werte ist exakt, das Mittel schwankt um rund 1 %.
    local _, dauerOhne = SZ.grenzen(z.dauer[1])
    for index, fall in ipairs(TFMeasure.SCHLAF_DAUER) do
        if index > 1 then
            local _, mit = SZ.grenzen(z.dauer[index])
            local zeile = { teil = "dauer", trait = fall[1], code = fall[2],
                            mod = sollAusMod(fall[1], "sleepduration") }
            if mit and dauerOhne and dauerOhne > 0 then zeile.faktor = mit / dauerOhne end
            SZ.urteil(zeile, 0.02)
            zeilen[#zeilen + 1] = zeile
        end
    end
    local deckelOhne = SZ.deckel(z.einschlafen[1])
    for index, fall in ipairs(TFMeasure.SCHLAF_EINSCHLAFEN) do
        if index > 1 then
            local deckel = SZ.deckel(z.einschlafen[index])
            local zeile = { teil = "einschlafen", trait = fall[1], code = fall[2],
                            mod = sollAusMod(fall[1], "fallasleep") }
            if deckel and deckelOhne and deckelOhne > 0 then zeile.faktor = deckel / deckelOhne end
            SZ.urteil(zeile, 0.03)
            zeilen[#zeilen + 1] = zeile
        end
    end
    for _, fall in ipairs(TFMeasure.SCHLAF_ERHOLUNG) do
        local faktor, n = SZ.nachbarFaktor(z.phasen, fall[1], "rate")
        local zeile = { teil = "erholung", trait = fall[1], code = fall[2],
                        mod = sollAusMod(fall[1], "sleeprecovery"), faktor = faktor, n = n }
        SZ.urteil(zeile, 0.01)
        zeilen[#zeilen + 1] = zeile
    end
    local stimmen, abweichend, fehlt = SZ.zaehlen(zeilen)
    local bett = "?"
    pcall(function() bett = tostring(player:getBedType()) end)
    local cfg = TFMeasure.SCHLAF
    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.SCHLAFFILE, true, false)
        local function write(line) writer:write(line .. nl()) end
        write("# Schlaf: Dauer, Einschlafen, Erholung, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        write("# Build " .. buildNummer())
        write(string.format("# Bett %s; Dauer: je Fall %d Aufrufe von onSleepWalkToComplete bei Muedigkeit %s;"
            .. " Einschlafen: je Fall %d Proben, %d Suchschritte bis %s Stunden", bett, cfg.dauerProben,
            tostring(cfg.muede), cfg.einschlafProben, cfg.suchSchritte, tostring(cfg.suchBis)))
        write("# Dauer: faktor = groesster Wert mit / ohne (ZombRand in ganzen Stunden, exakt), Toleranz 2 %;"
            .. " Einschlafen: faktor = Deckel mit / Deckel ohne, Deckel = groesster Wert x (n + 1) / n, Toleranz 3 %;"
            .. " beide Teile mit den Faellen im Wechsel")
        write("# Erholung: Muedigkeit weniger je Spielstunde, faktor = Phase mit Trait / Mittel der"
            .. " Nachbarphasen ohne, Toleranz 1 %")
        write("")
        write("[ergebnis]")
        write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d|abgelehnt=%d"
            .. "|verworfen=%d", #zeilen, stimmen, abweichend, fehlt, z.abgelehnt, z.verworfen))
        write("")
        write("[werte] wert|teil|trait|faktor|soll_mod|soll_code|urteil")
        for _, e in ipairs(zeilen) do
            write(string.format("wert|%s|%s|%s|%s|%s|%s", e.teil, e.trait, SZ.z4(e.faktor), SZ.z4(e.mod),
                SZ.z4(e.code), e.urteil))
        end
        write("")
        write("[dauer] fall|trait|proben|mittel|kleinster|groesster|geklemmt (Stunden)")
        for index, fall in ipairs(TFMeasure.SCHLAF_DAUER) do
            local liste = z.dauer[index] or {}
            local klein, gross = SZ.grenzen(liste)
            local geklemmt = 0
            for _, v in ipairs(liste) do
                if math.abs(v - 3) < 1e-4 or math.abs(v - 16) < 1e-4 then geklemmt = geklemmt + 1 end
            end
            write(string.format("dauer|%s|%d|%s|%s|%s|%d", fall[1], #liste, SZ.z4(SZ.mittel(liste)),
                SZ.z4(klein), SZ.z4(gross), geklemmt))
        end
        write("")
        write("[einschlafen] fall|trait|proben|mittel|groesster|deckel (Stunden)|stress und schmerz: Proben mit"
            .. " der Stimmung|schritt: mittlere Schrittweite je Tick")
        for index, fall in ipairs(TFMeasure.SCHLAF_EINSCHLAFEN) do
            local liste = z.einschlafen[index] or {}
            local _, gross = SZ.grenzen(liste)
            local mehr = (z.einschlafMehr or {})[index] or { stress = 0, schmerz = 0, schritt = 0 }
            write(string.format("einschlafen|%s|%d|%s|%s|%s|stress=%d|schmerz=%d|schritt=%s", fall[1], #liste,
                SZ.z4(SZ.mittel(liste)), SZ.z4(gross), SZ.z4(SZ.deckel(liste)), mehr.stress, mehr.schmerz,
                SZ.z4((#liste > 0) and mehr.schritt / #liste or nil)))
        end
        write("")
        write("[erholung] nr|gruppe|stunden|von|bis|je_h")
        for index, ph in ipairs(z.phasen) do
            write(string.format("phase|%d|%s|%s|%s|%s|%s", index, ph.gruppe, SZ.z4(ph.stunden), SZ.z4(ph.von),
                SZ.z4(ph.bis), SZ.z4(ph.rate)))
        end
        writer:close()
    end)
    SZ.schlafAufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == "schlaf" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("schlaf", { werte = #zeilen, stimmen = stimmen, abweichend = abweichend,
                                        fehlt = fehlt })
        log("Schlaf-Test geschrieben: Zomboid/Lua/" .. TFMeasure.SCHLAFFILE)
        halo(player, T("schlaf_fertig", T("schlaf_ergebnis", tostring(#zeilen), tostring(stimmen),
            tostring(abweichend), tostring(fehlt))), true)
    else
        log("Schlaf-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "schlaf", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.schlafStarten(player)
    local z = { held = SZ.traitsMerken(player), muede0 = statLesen(player, "FATIGUE"), teil = "warten", fall = 1,
                dauer = {}, einschlafen = {}, abgelehnt = 0, plan = SZ.schlafPlan(), phasen = {},
                verworfen = 0 }
    TFMeasure.schlafZustand = z
    TFMeasure.lauf = { id = "schlaf", erledigt = 0, fortschritt = 0, status = T("schlaf_status_bett") }
    SZ.schlafLive(z)
end

function TFMeasure.schlafTick()
    local z, lauf = TFMeasure.schlafZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "schlaf" then
        TFMeasure.schlafAbbrechen(T("schlaf_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    local cfg = TFMeasure.SCHLAF
    SZ.godAus(player, z)
    SZ.schritt(lauf, 1)
    if not player:isAsleep() then
        if (z.probe or z.phase) and SZ.schlafVerwerfen(z) then return end
        -- Wach: muede und ohne Panik halten, damit Vanilla das Hinlegen annimmt.
        -- Dazu die Sperre des Kontextmenues aufheben: eine Stunde nach dem
        -- Aufwachen verweigert es das Bett (ISWorldObjectContextMenuLogic
        -- .doSleepOption: getHoursSurvived - getLastHourSleeped <= 1, "Can't get
        -- back to sleep"; am 13.09.2026 kam man so nicht zurueck ins Bett).
        statSetzen(player, "PANIC", 0)
        if statLesen(player, "FATIGUE") < cfg.muede then statSetzen(player, "FATIGUE", cfg.muede) end
        pcall(function() player:setLastHourSleeped(math.floor(player:getHoursSurvived()) - 2) end)
        z.wachTicks = (z.wachTicks or 0) + 1
        -- Lag die Figur schon, legt der Test sie selbst zurueck ins Bett: einen
        -- Tick spaeter, damit die Stimmung der gesenkten Panik folgt, und danach
        -- jede Sekunde, falls Vanilla ablehnt (Zombies in Sicht).
        if z.hingelegt and z.bett and z.wachTicks % 60 == 2 then
            local ok, err = pcall(SZ.hinlegen, player, z)
            if not ok then log("Schlaf-Test: Hinlegen fehlgeschlagen: " .. tostring(err)) end
        end
        lauf.status = z.hingelegt and T("schlaf_status_wach") or T("schlaf_status_bett")
        SZ.schlafLive(z)
        return
    end
    z.wachTicks = 0
    -- Jeden Tick: kein Albtraum und keine Einbrecher weckt die Figur.
    SZ.schlafdatenWeg(player)
    z.hingelegt = true
    z.bett = player:getBed() or z.bett
    if z.teil == "warten" then z.teil = "dauer" end
    if z.teil == "dauer" then
        SZ.schritt(lauf, 2)
        SZ.schlafDauer(player, z, lauf)
    elseif z.teil == "einschlafen" then
        SZ.schritt(lauf, 3)
        SZ.schlafEinschlafen(player, z, lauf)
    elseif z.teil == "erholung" then
        SZ.schritt(lauf, 4)
        SZ.schlafErholung(player, z, lauf)
    end
    if TFMeasure.schlafZustand == z then SZ.schlafLive(z) end
end

--- Beendet den Schlaf-Test ohne Bericht: Traits, Muedigkeit und God Mode
-- zurueck, die Figur wird geweckt.
function TFMeasure.schlafAbbrechen(grund)
    local z = TFMeasure.schlafZustand
    if z then SZ.schlafAufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == "schlaf" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "schlaf", text = grund or T("schlaf_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Einblenden: Eagle Eyed und Short Sighted (neu am 14.09.2026)
--- ---------------------------------------------------------------------------
--
-- Wie schnell ein Zombie fuer die Figur einblendet. IsoObject.updateAlpha(IFF)
-- (Bytecode 79-135, 42.20): liegt die Alpha unter dem Ziel, waechst sie je
-- Update um 0.28 x GameTime.getMultiplier x mul, hoechstens bis zum Ziel.
-- mul kommt aus getAlphaUpdateRateMul: IsoObject 0.25, x2 wenn das Feld des
-- Objekts in einem Raum liegt (Bytecode 0-26); IsoGameCharacter (Z. 6278-6289)
-- teilt durch 2 mit Short Sighted und nimmt x1.5 mit Eagle Eyed. Gefragt wird
-- die Figur der Kamera (IsoCamera.getCameraCharacter), nicht der Zombie, und
-- nur der Trait: eine Brille aendert nichts. Das Ausblenden teilt durch
-- getAlphaUpdateRateDiv (14) und kennt keinen Trait. getAlphaUpdateRateMul
-- ist protected, aus Lua also nicht aufrufbar; gemessen wird die Wirkung.
--
-- Aufgerufen je Spieler-Index aus IsoGameCharacter.updateInternal (Z. 8136,
-- updateAlpha() -> updateAlpha(I) -> updateAlpha(IFF), Bytecode), nicht im
-- Rendern (isUpdateAlphaDuringRender false, Z. 6291). Die Reihenfolge im
-- Bild (GameWindow.frameStep und IngameState.updateInternal, Bytecode):
-- FPSTracking.frameStep setzt fpsMultiplier, dann IsoWorld.update mit dem
-- Zombie, dann GameTime.update (UpdateStuff), dann OnTick. getMultiplier im
-- OnTick ist also der Wert, mit dem der Zombie im selben Bild gerechnet hat.
-- Der Test setzt die Alpha im OnTick auf 0 und liest sie im naechsten; der
-- Zuwachs geteilt durch 0.28 x Multiplier ist genau mul, die Bildrate
-- kuerzt sich heraus.
--
-- Der MovingObjectUpdateScheduler rechnet einen Zombie nur dann in jedem
-- Bild (Stufe FULL), wenn er gezeichnet wird und nicht Alpha und Ziel beide
-- unter 0.25 liegen (getUpdateSchedulerSimulationLevelForObject, Bytecode
-- 0-372); sonst seltener, mit perObjectMultiplier 2, 4 ... im Multiplier
-- (MovingObjectUpdateSchedulerUpdateBucket.update). Eine Probe zaehlt darum
-- nur mit Ziel 1 (die Figur sieht ihn, IsoPlayer Z. 5462), Zuwachs ueber 0
-- und unter dem Ziel, Stufe nicht erkennbar niedriger als FULL
-- (getCurrentSimulationLevel), Feld ohne Raum und genau den Traits der Phase.
-- Naeher als 4 Felder setzt IsoPlayer das Spieltempo auf 1 (Z. 5471-5475),
-- naeher als 2 die Alpha auf 1 (Z. 5488-5489). Der Zombie steht deshalb 5
-- bis 8 Felder weit auf einem freien Aussenfeld, ist useless (IsoZombie
-- Z. 1698, 2003: kein Ziel, keine Jagd), und "Zombies greifen nicht an" ist
-- an. Er verschwindet am Ende mit removeFromWorld und removeFromSquare wie in
-- der Wind-Gruppe (M.zombieWeg): nicht getoetet, also keine Leiche.
--
-- Phasen im Wechsel ohne, Eagle Eyed, ohne, Short Sighted, ... ohne, jede
-- gegen das Mittel ihrer Nachbarn ohne. Die uebrigen Traits der Figur
-- bleiben, nur diese zwei wechseln.
TFMeasure.EINBLENDENFILE = "TraitFacts_einblenden.txt"
TFMeasure.EINBLENDEN = {
    proben = 120,        -- gezaehlte Proben je Phase
    toleranz = 0.02,
    rate = 0.28,         -- IsoObject.updateAlpha(IFF), Bytecode 89
    grund = 0.25,        -- IsoObject.getAlphaUpdateRateMul, draussen
    felder = { 5, 6, 7, 8 },
    mindestAbstand = 4.5,
    warten = 150,        -- so viele Ticks ungesehen, dann das naechste Feld
    drehen = 30,         -- so oft dreht der Test die Figur zum ungesehenen Zombie
    maxVersuche = 8,
}
TFMeasure.EINBLENDEN_TRAITS = { "eagleeyed", "shortsighted" }
TFMeasure.EINBLENDEN_GRUPPEN = { ohne = {}, adler = { "eagleeyed" }, kurz = { "shortsighted" } }
TFMeasure.EINBLENDEN_PLAN = { "ohne", "adler", "ohne", "kurz", "ohne", "adler", "ohne", "kurz", "ohne" }
-- Je Zeile im Bericht: Trait, Faktor laut Code, Gruppe.
TFMeasure.EINBLENDEN_WERTE = { { "eagleeyed", 1.5, "adler" }, { "shortsighted", 0.5, "kurz" } }

local EB = {}

function EB.inGruppe(gruppe, key)
    for _, k in ipairs(TFMeasure.EINBLENDEN_GRUPPEN[gruppe] or {}) do
        if k == key then return true end
    end
    return false
end

--- Hat die Figur Eagle Eyed und Short Sighted genau so, wie die Gruppe will?
function EB.traitsStimmen(player, gruppe)
    for _, key in ipairs(TFMeasure.EINBLENDEN_TRAITS) do
        if hatTrait(player, key) ~= EB.inGruppe(gruppe, key) then return false end
    end
    return true
end

--- Setzt nur diese zwei Traits; die anderen der Figur bleiben.
function EB.traitsSetzen(player, gruppe)
    local container = player:getCharacterTraits()
    for _, key in ipairs(TFMeasure.EINBLENDEN_TRAITS) do
        local soll = EB.inGruppe(gruppe, key)
        local typ = traitTypeNamed(key)
        if typ and hatTrait(player, key) ~= soll then
            if soll then container:add(typ) else container:remove(typ) end
        end
    end
end

--- Liegt das Feld in einem Raum? So fragt getAlphaUpdateRateMul (square.room).
function EB.imRaum(feld)
    if not feld then return false end
    local ok, raum = pcall(function() return feld:getRoom() end)
    return ok and raum ~= nil
end

--- Die Update-Stufe des Zombies als Text ("FULL", "HALF" ...), nil wenn
-- nicht lesbar. Das Enum ist nicht fuer Lua freigegeben; tostring liefert
-- seinen Namen.
function EB.stufe(zombie)
    local ok, s = pcall(function() return tostring(zombie:getCurrentSimulationLevel()) end)
    if ok and type(s) == "string" then return s end
    return nil
end

--- Nur eine erkennbar niedrigere Stufe schliesst eine Probe aus; einen
-- unbekannten Text laesst sie gelten (er steht im Bericht).
function EB.seltener(stufe)
    if not stufe then return false end
    for _, name in ipairs({ "HALF", "QUARTER", "EIGHTH", "SIXTEENTH" }) do
        if string.find(stufe, name, 1, true) then return true end
    end
    return false
end

function EB.tot(player)
    local ok, tot = pcall(function() return player:isDead() end)
    return ok and tot == true
end

--- Ist der Zombie noch da und lebt?
function EB.zombieDa(zombie)
    local ok, da = pcall(function() return (not zombie:isDead()) and zombie:getCurrentSquare() ~= nil end)
    return ok and da == true
end

--- Freie Aussenfelder ohne Raum 5 bis 8 Felder um die Figur, die naechsten
-- zuerst; die Richtungen wie in der Wind-Gruppe.
function EB.felderSuchen(player)
    local cell, liste = getCell(), {}
    local px, py, pz = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for _, weit in ipairs(TFMeasure.EINBLENDEN.felder) do
        for _, r in ipairs(TFMeasure.WIND_RICHTUNGEN) do
            local x, y = px + r[1] * weit, py + r[2] * weit
            local sq = cell:getGridSquare(x, y, pz)
            if sq and sq:isOutside() and sq:isFree(false) and not EB.imRaum(sq) then
                liste[#liste + 1] = { x = x, y = y, z = pz, weit = weit }
            end
        end
    end
    return liste
end

--- Den Zombie auf das naechste Feld der Liste setzen; nil und Grund, wenn
-- keins mehr da ist oder keiner entsteht.
function EB.zombieSetzen(player, z)
    local cfg = TFMeasure.EINBLENDEN
    z.versuch = z.versuch + 1
    local feld = z.felder[z.versuch]
    if #z.felder == 0 then return nil, T("einblenden_keinfeld") end
    if not feld or z.versuch > cfg.maxVersuche then return nil, T("einblenden_keinesicht") end
    local liste = addZombiesInOutfit(feld.x, feld.y, feld.z, 1, nil, 50)
    if not liste or liste:size() == 0 then return nil, T("einblenden_keinzombie") end
    local zombie = liste:get(0)
    pcall(function() zombie:setUseless(true) end)
    z.zombie, z.feld, z.ungesehen, z.gesetzt = zombie, feld, 0, false
    pcall(function() player:faceLocation(feld.x + 0.5, feld.y + 0.5) end)
    return zombie
end

function EB.neuePhase(gruppe)
    return { gruppe = gruppe, werte = {}, n = 0, summeA = 0, summeM = 0, aus = 0 }
end

--- Eine Probe: der Zuwachs seit dem letzten Tick geteilt durch 0.28 x
-- Multiplier. Liefert eine Tabelle oder nil und den Grund, warum sie nicht
-- zaehlt.
function EB.probe(player, z)
    local zombie, cfg = z.zombie, TFMeasure.EINBLENDEN
    local ziel = zombie:getTargetAlpha(z.index)
    if ziel < 0.999 then return nil, "sicht" end
    if not z.gesetzt then return nil, "neu" end
    local a = zombie:getAlpha(z.index)
    local m = getGameTime():getMultiplier()
    if a <= 0 or a >= ziel or m <= 0 then return nil, "zuwachs" end
    local stufe = EB.stufe(zombie) or "?"
    z.stufen[stufe] = (z.stufen[stufe] or 0) + 1
    if EB.seltener(stufe) then return nil, "takt" end
    if EB.imRaum(zombie:getCurrentSquare()) then return nil, "raum" end
    local dx, dy = zombie:getX() - player:getX(), zombie:getY() - player:getY()
    local abstand = math.sqrt(dx * dx + dy * dy)
    if abstand < cfg.mindestAbstand then return nil, "nah" end
    if not EB.traitsStimmen(player, z.phase.gruppe) then return nil, "traits" end
    return { wert = a / (cfg.rate * m), a = a, m = m, abstand = abstand }
end

--- Ungesehen: die Figur ab und zu zum Zombie drehen, nach `warten` Ticks
-- den Zombie wegnehmen; im naechsten Tick kommt einer aufs naechste Feld.
function EB.ungesehen(player, z, lauf)
    local cfg = TFMeasure.EINBLENDEN
    z.ungesehen = z.ungesehen + 1
    lauf.status = T("einblenden_status_sicht")
    if z.ungesehen % cfg.drehen == 0 then
        pcall(function() player:faceLocation(z.feld.x + 0.5, z.feld.y + 0.5) end)
    end
    if z.ungesehen >= cfg.warten then
        pcall(M.zombieWeg, z.zombie)
        z.zombie = nil
    end
end

--- Die Probe dieses Ticks der laufenden Phase zuschreiben und eine volle
-- Phase abschliessen.
function EB.auswerten(player, z, lauf)
    local cfg, ph = TFMeasure.EINBLENDEN, z.phase
    local probe, grund = EB.probe(player, z)
    if probe then
        ph.n = ph.n + 1
        ph.werte[ph.n] = probe.wert
        ph.summeA = ph.summeA + probe.a
        ph.summeM = ph.summeM + cfg.rate * probe.m
        ph.abstand = probe.abstand
        z.ungesehen = 0
        SZ.schritt(lauf, 3)
        lauf.status = T("einblenden_status_misst", tostring(#z.phasen + 1), tostring(#TFMeasure.EINBLENDEN_PLAN),
            T("einblenden_gruppe_" .. ph.gruppe))
    elseif grund ~= "neu" then
        ph.aus = ph.aus + 1
        z.gruende[grund] = (z.gruende[grund] or 0) + 1
        if grund == "sicht" then EB.ungesehen(player, z, lauf) end
    end
    if ph.n < cfg.proben then return end
    ph.median = SZ.median(ph.werte)
    ph.rate = ph.summeA / ph.summeM
    ph.werte = nil
    z.phasen[#z.phasen + 1] = ph
    local gruppe = TFMeasure.EINBLENDEN_PLAN[#z.phasen + 1]
    if not gruppe then
        SZ.schritt(lauf, 4)
        EB.fertig(player, z)
        return
    end
    z.phase = EB.neuePhase(gruppe)
end

--- Fuer den naechsten Update: Traits der Phase, Alpha auf 0.
function EB.vorbereiten(player, z)
    if not EB.traitsStimmen(player, z.phase.gruppe) then EB.traitsSetzen(player, z.phase.gruppe) end
    z.zombie:setAlpha(z.index, 0)
    z.gesetzt = true
end

function EB.live(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "einblenden" then return end
    local plan, cfg, ph = TFMeasure.EINBLENDEN_PLAN, TFMeasure.EINBLENDEN, z.phase
    local n = ph and ph.n or 0
    lauf.fortschritt = (#z.phasen + n / cfg.proben) / #plan
    lauf.live = {
        { T("einblenden_live_phasen"), T("paar", tostring(#z.phasen), tostring(#plan)) },
        { T("einblenden_live_proben"), T("paar", tostring(n), tostring(cfg.proben)) },
        { T("einblenden_live_gruppe"), ph and T("einblenden_gruppe_" .. ph.gruppe) or "-" },
    }
end

function EB.aufraeumen(player, z)
    if z.zombie then pcall(M.zombieWeg, z.zombie) end
    z.zombie = nil
    if player then
        pcall(SZ.traitsZurueck, player, z.held)
        local an = z.zda0
        if an == nil then an = TFMeasure.cheatStand.zombies ~= false end
        pcall(function() player:setZombiesDontAttack(an) end)
    end
    TFMeasure.einblendenZustand = nil
end

--- Mittel der Mediane aller Phasen ohne Trait; laut Code 0.25 draussen.
function EB.grundrate(z)
    local summe, n = 0, 0
    for _, ph in ipairs(z.phasen) do
        if ph.gruppe == "ohne" and type(ph.median) == "number" then summe, n = summe + ph.median, n + 1 end
    end
    if n == 0 then return nil end
    return summe / n
end

--- "a=1, b=2" aus einer Zaehl-Tabelle, sortiert.
function EB.zaehlText(t)
    local keys, teile = {}, {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do teile[#teile + 1] = k .. "=" .. tostring(t[k]) end
    return (#teile > 0) and table.concat(teile, ", ") or "-"
end

function EB.z6(x)
    return (type(x) == "number") and string.format("%.6f", x) or "-"
end

function EB.schreiben(z, zeilen, zahl)
    local cfg = TFMeasure.EINBLENDEN
    local writer = getFileWriter(TFMeasure.EINBLENDENFILE, true, false)
    local function write(line) writer:write(line .. nl()) end
    local brille = (z.brille == true) and "getragen" or ((z.brille == false) and "keine" or "?")
    write("# Einblenden: Tempo, mit dem ein Zombie fuer die Figur einblendet, Messung an einer lebenden Figur")
    write("# Mess-Mod " .. TFMeasure.VERSION)
    write("# Build " .. buildNummer())
    write(string.format("# je Phase %d Proben: Alpha des Zombies im OnTick auf 0, im naechsten gelesen;"
        .. " Zombie zuletzt %s Felder entfernt, draussen, useless", cfg.proben, tostring(z.feld and z.feld.weit or "?")))
    write("# wert je Probe = Alpha / (0.28 x getMultiplier); laut Code getAlphaUpdateRateMul 0.25 draussen ohne"
        .. " Trait (x2 im Raum)")
    write("# faktor = Median der Phase mit Trait / Mittel der Mediane der Nachbarphasen ohne, Toleranz 2 %;"
        .. " faktor_rate ebenso aus Summe Alpha / Summe (0.28 x Multiplier)")
    write("# laut Code: IsoGameCharacter.getAlphaUpdateRateMul Z. 6278-6289, Short Sighted /2, Eagle Eyed x1.5,"
        .. " Trait der Kamerafigur; IsoObject.updateAlpha(IFF) Bytecode 79-135")
    write("# Brille: " .. brille .. " (laut Code ohne Einfluss, die Abfrage kennt nur den Trait)")
    write(string.format("# Grundrate ohne Trait: %s (laut Code %s)", EB.z6(zahl.grund), EB.z6(cfg.grund)))
    write("# Update-Stufen der Proben: " .. EB.zaehlText(z.stufen))
    write("# nicht gezaehlt: " .. EB.zaehlText(z.gruende) .. "; Felder versucht: " .. tostring(z.versuch))
    write("")
    write("[ergebnis]")
    write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d|phasen=%d|grundrate=%s",
        #zeilen, zahl.stimmen, zahl.abweichend, zahl.fehlt, #z.phasen, SZ.z4(zahl.grund)))
    write("")
    write("[werte] wert|trait|faktor|faktor_rate|soll_mod|soll_code|urteil|phasen")
    for _, e in ipairs(zeilen) do
        write(string.format("wert|%s|%s|%s|%s|%s|%s|%d", e.trait, SZ.z4(e.faktor), SZ.z4(e.rate),
            SZ.z4(e.mod), SZ.z4(e.code), e.urteil, e.n or 0))
    end
    write("")
    write("[phasen] phase|nr|gruppe|proben|median|rate|nicht_gezaehlt|abstand")
    for index, ph in ipairs(z.phasen) do
        write(string.format("phase|%d|%s|%d|%s|%s|%d|%s", index, ph.gruppe, ph.n, EB.z6(ph.median),
            EB.z6(ph.rate), ph.aus, (type(ph.abstand) == "number") and string.format("%.1f", ph.abstand) or "-"))
    end
    writer:close()
end

function EB.fertig(player, z)
    local cfg = TFMeasure.EINBLENDEN
    local zeilen = {}
    for _, w in ipairs(TFMeasure.EINBLENDEN_WERTE) do
        local faktor, n = SZ.nachbarFaktor(z.phasen, w[3], "median")
        local rate = SZ.nachbarFaktor(z.phasen, w[3], "rate")
        local zeile = { trait = w[1], code = w[2], mod = sollAusMod(w[1], "fadein"), faktor = faktor,
                        rate = rate, n = n }
        SZ.urteil(zeile, cfg.toleranz)
        zeilen[#zeilen + 1] = zeile
    end
    local stimmen, abweichend, fehlt = SZ.zaehlen(zeilen)
    local zahl = { stimmen = stimmen, abweichend = abweichend, fehlt = fehlt, grund = EB.grundrate(z) }
    local okWrite, errWrite = pcall(EB.schreiben, z, zeilen, zahl)
    EB.aufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == "einblenden" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("einblenden", { werte = #zeilen, stimmen = stimmen, abweichend = abweichend,
                                            fehlt = fehlt })
        log("Einblende-Test geschrieben: Zomboid/Lua/" .. TFMeasure.EINBLENDENFILE)
        halo(player, T("einblenden_fertig", T("einblenden_ergebnis", tostring(#zeilen), tostring(stimmen),
            tostring(abweichend), tostring(fehlt))), true)
    else
        log("Einblende-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "einblenden", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.einblendenStarten(player)
    for _, key in ipairs(TFMeasure.EINBLENDEN_TRAITS) do
        if not traitTypeNamed(key) then
            TFMeasure.meldung = { id = "einblenden", text = T("einblenden_keintrait") }
            return
        end
    end
    local z = { held = SZ.traitsMerken(player), phasen = {}, versuch = 0, ungesehen = 0, gruende = {},
                stufen = {}, felder = EB.felderSuchen(player), index = 0,
                phase = EB.neuePhase(TFMeasure.EINBLENDEN_PLAN[1]) }
    pcall(function() z.index = player:getPlayerNum() or 0 end)
    pcall(function() z.zda0 = player:isZombiesDontAttack() end)
    pcall(function() z.brille = player:isWearingGlasses() end)
    player:setZombiesDontAttack(true)
    TFMeasure.einblendenZustand = z
    TFMeasure.lauf = { id = "einblenden", erledigt = 0, fortschritt = 0, status = T("einblenden_status_start") }
    EB.live(z)
end

--- Ein Tick: erst die Probe des letzten Updates lesen, dann Traits setzen
-- und die Alpha fuer den naechsten auf 0.
function TFMeasure.einblendenTick()
    local z, lauf = TFMeasure.einblendenZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "einblenden" then
        TFMeasure.einblendenAbbrechen(T("einblenden_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    if not player or EB.tot(player) then
        TFMeasure.einblendenAbbrechen(T("einblenden_abgebrochen"))
        return
    end
    if not z.zombie then
        local zombie, grund = EB.zombieSetzen(player, z)
        if not zombie then
            TFMeasure.einblendenAbbrechen(grund)
            return
        end
        SZ.schritt(lauf, 2)
        lauf.status = T("einblenden_status_zombie", tostring(z.feld.weit), tostring(z.versuch),
            tostring(math.min(TFMeasure.EINBLENDEN.maxVersuche, #z.felder)))
        EB.live(z)
        return
    end
    if not EB.zombieDa(z.zombie) then
        TFMeasure.einblendenAbbrechen(T("einblenden_zombieweg"))
        return
    end
    EB.auswerten(player, z, lauf)
    if TFMeasure.einblendenZustand ~= z then return end
    if z.zombie then EB.vorbereiten(player, z) end
    EB.live(z)
end

--- Beendet den Einblende-Test ohne Bericht: Zombie weg, Traits und der
-- Schalter "Zombies greifen nicht an" zurueck.
function TFMeasure.einblendenAbbrechen(grund)
    local z = TFMeasure.einblendenZustand
    if z then EB.aufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == "einblenden" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "einblenden", text = grund or T("einblenden_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Laufen: Ausdauerverlust beim Rennen (seit 6.25.0, 13.09.2026)
--- ---------------------------------------------------------------------------
--
-- IsoPlayer.updateEndurance ist privat und rechnet nur im Update-Takt. Die
-- Figur rennt also, und der Test liest in jedem Tick, wie viel Ausdauer seit
-- dem letzten weg ist. Gelesen am 13.09.2026 im Bytecode (Offsets 83-246):
-- rennt die Figur (isRunning, currentSpeed > 0), zieht jeder Update
--   runningEnduranceReduce x enddelta x 2.3 x getPacingMod
--   x getHyperthermiaMod x 0.5 x asth x Multiplier
-- ab; enddelta 1.4, mit Overweight 2.9, mit Athletic 0.8 (steht danach,
-- schlaegt also Overweight), asth 0.7, mit Asthmatic (Short of Breath) 1.0.
-- Mit Last (HEAVY_LOAD) kommt 1.5 bis 2.8 dazu, beim Schleichen 1.5, beim
-- Sprinten ein anderer Grundwert. Beim Gehen erholt sich die Ausdauer
-- (dieselbe Methode, Offsets 639-751).
--
-- Der Test setzt die Ausdauer in jedem Tick auf 0.9 und liest im naechsten
-- den Abzug; geteilt durch den Multiplier ist das eine Rate, die von der
-- Bildrate nicht abhaengt. Es zaehlen nur Ticks, in denen die Figur rennt,
-- nicht sprintet, nicht schleicht, nicht im Auto sitzt, dieselbe Last traegt
-- wie im ersten gezaehlten Tick des ganzen Tests (nur dann kuerzt sie sich
-- zwischen den Phasen heraus), genau die Traits der Phase hat und wirklich
-- Ausdauer verliert. God Mode ist aus: er setzt die Ausdauer in jedem Bild
-- zurueck (BodyDamage.Update -> RestoreToFullHealth -> Stats.resetStats). Die Gewichts-Traits setzt Nutrition.applyTraitFromWeight alle
-- 2000 Updates nach dem Gewicht neu; stimmen sie nicht mehr, zaehlt der Tick
-- nicht, und der Test setzt sie wieder.
--
-- Phasen im Wechsel ohne, High Weight, ohne, Athletic, ohne, Short of Breath,
-- ohne, beide, ohne; jede gegen das Mittel ihrer Nachbarn ohne Trait, weil
-- die Hitze beim Rennen langsam steigt (getHyperthermiaMod).
TFMeasure.LAUFENFILE = "TraitFacts_laufen.txt"
TFMeasure.LAUFEN = {
    phaseTicks = 400,   -- gezaehlte Ticks je Phase
    start = 0.9,        -- Ausdauer, auf die jeder Tick zuruecksetzt
    toleranz = 0.02,
    leerGrenze = 600,   -- so viele Ticks Rennen ohne Abzug, dann ein Hinweis
}
TFMeasure.LAUFEN_GRUPPEN = {
    ohne = {}, dick = { "overweight" }, athlet = { "athletic" }, atem = { "asthmatic" },
    beide = { "overweight", "athletic" },
}
TFMeasure.LAUFEN_PLAN = { "ohne", "dick", "ohne", "athlet", "ohne", "atem", "ohne", "beide", "ohne" }
-- Je Zeile im Bericht: Trait, Faktor laut Code, Gruppe. "beide" hat keinen
-- Wert in der Mod; laut Code gilt dort nur Athletic.
TFMeasure.LAUFEN_WERTE = {
    { "overweight", 2.9 / 1.4, "dick" },
    { "athletic", 0.8 / 1.4, "athlet" },
    { "asthmatic", 1.0 / 0.7, "atem" },
    { "overweight+athletic", 0.8 / 1.4, "beide" },
}

--- Rennt die Figur so, wie updateEndurance es mit dem Grundwert fuers
-- Rennen rechnet?
function SZ.rennt(player)
    local ok, ja = pcall(function()
        return player:isRunning() and not player:isSprinting() and not player:isSneaking()
            and player:getVehicle() == nil
    end)
    return ok and ja == true
end

function SZ.lastStufe(player)
    local stufe = 0
    pcall(function() stufe = player:getMoodles():getMoodleLevel(MoodleType.HEAVY_LOAD) end)
    return tonumber(stufe) or 0
end

--- Hat die Figur genau diese Traits und keine anderen?
function SZ.traitsGenau(player, typen)
    local known = player:getCharacterTraits():getKnownTraits()
    if not known or known:size() ~= #typen then return false end
    for _, typ in ipairs(typen) do
        if not player:hasTrait(typ) then return false end
    end
    return true
end

function SZ.median(liste)
    local n = #liste
    if n == 0 then return nil end
    local k = {}
    for i, v in ipairs(liste) do k[i] = v end
    table.sort(k)
    if n % 2 == 1 then return k[(n + 1) / 2] end
    return (k[n / 2] + k[n / 2 + 1]) / 2
end

--- Die Raten sind klein (Ausdauer je Einheit Multiplier); vier Stellen
-- reichten nicht.
function SZ.z10(x)
    return (type(x) == "number") and string.format("%.10f", x) or "-"
end

function SZ.laufenLive(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "laufen" then return end
    local plan, cfg, ph = TFMeasure.LAUFEN_PLAN, TFMeasure.LAUFEN, z.phase
    local ticks = ph and ph.ticks or 0
    lauf.fortschritt = (#z.phasen + ticks / cfg.phaseTicks) / #plan
    local gruppe = plan[#z.phasen + 1]
    lauf.live = {
        { T("laufen_live_phasen"), T("paar", tostring(#z.phasen), tostring(#plan)) },
        { T("laufen_live_ticks"), T("paar", tostring(ticks), tostring(cfg.phaseTicks)) },
        { T("laufen_live_gruppe"), gruppe and T("laufen_gruppe_" .. gruppe) or "-" },
    }
end

function SZ.laufenAufraeumen(player, z)
    if player then
        pcall(SZ.traitsZurueck, player, z.held)
        pcall(statSetzen, player, "ENDURANCE", z.ausdauer0 or 1)
        pcall(function() player:setUnlimitedEndurance(TFMeasure.cheatStand.ausdauer ~= false) end)
    end
    SZ.godZurueck(player, z)
    TFMeasure.laufenZustand = nil
end

function SZ.laufenFertig(player, z)
    local cfg = TFMeasure.LAUFEN
    local zeilen = {}
    for _, w in ipairs(TFMeasure.LAUFEN_WERTE) do
        local faktor, n = SZ.nachbarFaktor(z.phasen, w[3], "rate")
        local median = SZ.nachbarFaktor(z.phasen, w[3], "median")
        local zeile = { trait = w[1], code = w[2], mod = sollAusMod(w[1], "enduranceloss"), faktor = faktor,
                        median = median, n = n }
        SZ.urteil(zeile, cfg.toleranz)
        zeilen[#zeilen + 1] = zeile
    end
    local stimmen, abweichend, fehlt = SZ.zaehlen(zeilen)
    local god = "?"
    pcall(function() god = player:isGodMod() and "an" or "aus" end)
    local okWrite, errWrite = pcall(function()
        local writer = getFileWriter(TFMeasure.LAUFENFILE, true, false)
        local function write(line) writer:write(line .. nl()) end
        write("# Laufen: Ausdauerverlust beim Rennen, Messung an einer lebenden Figur")
        write("# Mess-Mod " .. TFMeasure.VERSION)
        write("# Build " .. buildNummer())
        write(string.format("# je Phase %d Ticks Rennen (Shift, nicht Sprint); Ausdauer in jedem Tick auf %s;"
            .. " God Mode %s", cfg.phaseTicks, tostring(cfg.start), god))
        write("# Last (Stufe HEAVY_LOAD) in allen gezaehlten Ticks: " .. tostring(z.last))
        write("# rate = Summe Abzug / Summe Multiplier; median = Median der Einzelwerte Abzug / Multiplier")
        write("# faktor = Phase mit Trait / Mittel der Nachbarphasen ohne, Toleranz 2 %; faktor_median ebenso"
            .. " aus median")
        write("# laut Code: IsoPlayer.updateEndurance enddelta 1.4, Overweight 2.9, Athletic 0.8 (schlaegt"
            .. " Overweight); asth 0.7, Asthmatic 1.0")
        write("")
        write("[ergebnis]")
        write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d|phasen=%d",
            #zeilen, stimmen, abweichend, fehlt, #z.phasen))
        write("")
        write("[werte] wert|trait|faktor|faktor_median|soll_mod|soll_code|urteil|phasen")
        for _, e in ipairs(zeilen) do
            write(string.format("wert|%s|%s|%s|%s|%s|%s|%d", e.trait, SZ.z4(e.faktor), SZ.z4(e.median),
                SZ.z4(e.mod), SZ.z4(e.code), e.urteil, e.n or 0))
        end
        write("")
        write("[phasen] phase|nr|gruppe|ticks|rate|median|last|nicht_gezaehlt")
        for index, ph in ipairs(z.phasen) do
            write(string.format("phase|%d|%s|%d|%s|%s|%d|%d", index, ph.gruppe, ph.ticks, SZ.z10(ph.rate),
                SZ.z10(ph.median), ph.last or 0, ph.aus or 0))
        end
        writer:close()
    end)
    SZ.laufenAufraeumen(player, z)
    if TFMeasure.lauf and TFMeasure.lauf.id == "laufen" then TFMeasure.lauf = nil end
    if okWrite then
        TFMeasure.meldung = nil
        TFMeasure.erledigen("laufen", { werte = #zeilen, stimmen = stimmen, abweichend = abweichend, fehlt = fehlt })
        log("Lauf-Test geschrieben: Zomboid/Lua/" .. TFMeasure.LAUFENFILE)
        halo(player, T("laufen_fertig", T("laufen_ergebnis", tostring(#zeilen), tostring(stimmen),
            tostring(abweichend), tostring(fehlt))), true)
    else
        log("Lauf-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "laufen", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.laufenStarten(player)
    for _, keys in pairs(TFMeasure.LAUFEN_GRUPPEN) do
        for _, key in ipairs(keys) do
            if not traitTypeNamed(key) then error("Trait fehlt in der Registry: " .. key) end
        end
    end
    local z = { held = SZ.traitsMerken(player), phasen = {}, ausdauer0 = statLesen(player, "ENDURANCE"),
                leer = 0 }
    player:setUnlimitedEndurance(false)
    -- God Mode setzt die Ausdauer in jedem Bild zurueck, das Heilen des
    -- Mess-Mods ebenso (godTick); mit einem von beiden zaehlte kein Tick.
    SZ.godAus(player, z)
    TFMeasure.laufenZustand = z
    TFMeasure.lauf = { id = "laufen", erledigt = 0, fortschritt = 0, status = T("laufen_status_warten") }
    SZ.laufenLive(z)
end

--- Ein Tick: erst den Abzug seit dem letzten Tick der laufenden Phase
-- zuschreiben (ihre Traits hat der letzte Tick gesetzt), dann die Phase
-- abschliessen oder die naechste beginnen, zuletzt Traits und Ausdauer fuer
-- den naechsten Update setzen.
function TFMeasure.laufenTick()
    local z, lauf = TFMeasure.laufenZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "laufen" then
        TFMeasure.laufenAbbrechen(T("laufen_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    local cfg = TFMeasure.LAUFEN
    local ph = z.phase
    local e = statLesen(player, "ENDURANCE")
    local m = getGameTime():getMultiplier()
    local rennt = SZ.rennt(player)
    if ph and z.gesetzt and rennt then
        local d = z.gesetzt - e
        -- Die Last gilt fuer den ganzen Test: der erste Tick, der sonst
        -- zaehlte, legt sie fest. Mit einer anderen Last kuerzte sie sich
        -- zwischen den Phasen nicht heraus (x1.5 bis x2.8).
        local last = SZ.lastStufe(player)
        local gut = d > 0 and m > 0 and SZ.traitsGenau(player, ph.typen)
        if gut and z.last == nil then z.last = last end
        if gut and last == z.last then
            ph.ticks = ph.ticks + 1
            ph.verlust = ph.verlust + d
            ph.mult = ph.mult + m
            ph.raten[#ph.raten + 1] = d / m
            z.leer, z.lastAnders = 0, nil
            SZ.schritt(lauf, 2)
        else
            ph.aus = ph.aus + 1
            if d <= 0 then z.leer = z.leer + 1 end
            if gut then z.lastAnders = last end
        end
    end
    if ph and ph.ticks >= cfg.phaseTicks then
        ph.rate = ph.verlust / ph.mult
        ph.last = z.last
        ph.median = SZ.median(ph.raten)
        ph.raten = nil
        z.phasen[#z.phasen + 1] = ph
        z.phase = nil
    end
    if not z.phase then
        local gruppe = TFMeasure.LAUFEN_PLAN[#z.phasen + 1]
        if not gruppe then
            SZ.schritt(lauf, 4)
            SZ.laufenFertig(player, z)
            return
        end
        local typen = {}
        for _, key in ipairs(TFMeasure.LAUFEN_GRUPPEN[gruppe]) do typen[#typen + 1] = traitTypeNamed(key) end
        z.phase = { gruppe = gruppe, typen = typen, ticks = 0, verlust = 0, mult = 0, raten = {}, aus = 0 }
    end
    if not SZ.traitsGenau(player, z.phase.typen) then
        SZ.traitsNur(player, TFMeasure.LAUFEN_GRUPPEN[z.phase.gruppe])
    end
    statSetzen(player, "ENDURANCE", cfg.start)
    z.gesetzt = statLesen(player, "ENDURANCE")
    if z.leer >= cfg.leerGrenze then
        lauf.status = T("laufen_status_nichts")
    elseif z.lastAnders then
        lauf.status = T("laufen_status_last", tostring(z.lastAnders), tostring(z.last))
    elseif rennt then
        lauf.status = T("laufen_status_misst", tostring(#z.phasen + 1), tostring(#TFMeasure.LAUFEN_PLAN),
            T("laufen_gruppe_" .. z.phase.gruppe))
    else
        lauf.status = T("laufen_status_warten")
    end
    SZ.laufenLive(z)
end

--- Beendet den Lauf-Test ohne Bericht: Traits, Ausdauer und der Schalter
-- fuer unbegrenzte Ausdauer zurueck.
function TFMeasure.laufenAbbrechen(grund)
    local z = TFMeasure.laufenZustand
    if z then SZ.laufenAufraeumen(getSpecificPlayer(0), z) end
    if TFMeasure.lauf and TFMeasure.lauf.id == "laufen" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "laufen", text = grund or T("laufen_abgebrochen") }
end

--- ---------------------------------------------------------------------------
--- Im Auto: Klaustrophobie und Kurzschliessen (seit 14.09.2026)
--- ---------------------------------------------------------------------------
--
-- Zwei Werte, fuer die du im Auto sitzen musst.
--
-- Claustrophobic: IsoGameCharacter.updateInternal zaehlt ein Fahrzeug wie
-- einen Raum mit n = 60 Feldern (Z. 8202 inVehicle, Z. 8210-8217): je Bild
-- 0.6 x (1 - 60/70) x getThirtyFPSMultiplier = 0.0857 x ThirtyFPS, bei
-- Spieltempo 1 also 2.57 je Sekunde. Im selben Bild baut ReducePanic fuer
-- jede Figur 0.06 x ThirtyFPS ab (BodyDamage Z. 399-413; dazu 0.06 je
-- ueberlebtem Monat, das kuerzt sich im Unterschied heraus). Netto +0.77 mit
-- Trait, -1.80 ohne. Agoraphobic gibt im Auto unter freiem Himmel +0.5 je
-- Bild (Z. 8207-8209, isInARoom fragt das Feld, nicht das Auto) und ist
-- deshalb in allen Phasen ab. Ablauf wie der Panik-Test: sechs Phasen zu
-- zwei Sekunden im Wechsel mit und ohne Trait, God Mode aus (sonst setzt
-- RestoreToFullHealth die Panik in jedem Bild auf 0).
--
-- Kurzschliessen: reine Lua-Bedingung in ISVehicleMenu.showRadialMenu
-- (client/Vehicles/ISUI/ISVehicleMenu.lua Z. 109-121). Am Steuer, nicht
-- kurzgeschlossen, Motor weder gestartet noch laufend, Sandbox
-- VehicleEasyUse aus, kein Schluessel im Zuendschloss oder im Inventar; dann
-- mit Electricity >= 1 und Mechanics >= 2 oder Burglar die Scheibe
-- "ContextMenu_VehicleHotwire" mit onHotwire, sonst die gesperrte Scheibe
-- "ContextMenu_VehicleHotwireSkill" ohne Befehl. Das Mod ersetzt
-- getPlayerRadialMenu (ISPlayerData.lua Z. 143) fuer je einen Aufruf durch
-- einen Stellvertreter, der die Scheiben mitschreibt. Auf dem Menue ruft
-- showRadialMenu clear, isReallyVisible, setX, setY, getWidth, getHeight,
-- addSlice und addToUIManager, setzt sounds.undisplay und ruft mit
-- Controller setHideWhenButtonReleased und setJoypadFocus (Z. 67-78,
-- 228-239). Der Stellvertreter kann all das; der Controller-Eintrag ist fuer
-- den Aufruf weg, der Menue-Ton stumm, das echte Menue bleibt unberuehrt. Ein
-- pausiertes Spiel kehrt in Z. 58-59 sofort zurueck, darum wartet der Test
-- dann. Die Stufen setzt setPerkLevelDebug (IsoGameCharacter Z. 4487-4500),
-- das nur info.level schreibt und keine XP; zurueck noch im selben Tick.
--
-- Ein gesetztes Auto: addVehicle (LuaManager Z. 8529) ruft addToWorld, und
-- das legt mit etwas Glueck den Schluessel ins Zuendschloss (trySpawnKey,
-- BaseVehicle Z. 7111-7119 und 1059-1064); so ein Auto kommt wieder weg. Die
-- Tueren sperrt Vehicles.Create.Door je nach Sandbox LockedCar und Zufall
-- (Vehicles.lua Z. 133-173); das Mod schliesst sie auf. Einen Schluessel
-- bekommst du nicht, sonst fehlte die Scheibe.
--
-- Speed Demon beim Rueckwaertsfahren (speeddemon/reversenoise) fehlt mit
-- Absicht. VehicleEngine.updateWorldSounds (privat, Z. 257-277) rechnet den
-- Radius nur aus loudness und der Drehzahl, einen Trait fragt es nicht
-- (SPEED_DEMON steht in zombie/vehicles nirgends). Die Drehzahl ist schon
-- gemessen (speeddemon/rpmbuild). Den Radius zu lesen hiesse, per Reflection
-- (-debug) in WorldSoundManager zu greifen, und drei der vier Geraeusche
-- entstehen nur per Zufall (Rand.Next, Z. 266-273): es kaeme wieder die
-- Drehzahl heraus, nicht der Trait.
TFMeasure.IMAUTOFILE = "TraitFacts_imauto.txt"
TFMeasure.IMAUTO = {
    skript = "Base.CarNormal",
    setzVersuche = 4,   -- ein Auto mit Schluessel im Zuendschloss kommt wieder weg
    phasen = 6,         -- im Wechsel mit, ohne, mit ...
    phaseMs = 2000,
    mindestTicks = 30,
    startMit = 20,      -- steigt in 2 s auf rund 21.5
    startOhne = 50,     -- faellt in 2 s auf rund 46.4
    sprung = 3,         -- mehr Zuwachs in einem Tick heisst: Zombie im Bild
    maxVerworfen = 20,
    code30 = 0.6 * (1 - 60 / 70),
    toleranz = 0.03,    -- relativ zum Code-Wert je Bild
    kurzWartenMs = 20000,
    -- Burglar, Electricity, Mechanics und was Z. 116-119 dann zeigt
    faelle = {
        { id = "ohne",    burglar = false, e = 0, m = 0, soll = "gesperrt" },
        { id = "burglar", burglar = true,  e = 0, m = 0, soll = "angeboten" },
        { id = "e1m2",    burglar = false, e = 1, m = 2, soll = "angeboten" },
        { id = "e0m2",    burglar = false, e = 0, m = 2, soll = "gesperrt" },
        { id = "e1m1",    burglar = false, e = 1, m = 1, soll = "gesperrt" },
    },
    -- Gruende, die du selbst beheben kannst; so lange wartet der Test.
    warten = { motor = true, zuendung = true, schluessel = true },
    gruende = {
        menue = "ISVehicleMenu.showRadialMenu, getPlayerRadialMenu oder Perks fehlt",
        easyuse = "Sandbox VehicleEasyUse an",
        kurzgeschlossen = "das Auto war schon kurzgeschlossen",
        motor = "der Motor lief",
        zuendung = "Schluessel im Zuendschloss",
        schluessel = "Schluessel zu diesem Auto im Inventar",
        stufen = "Electricity, Mechanics oder Burglar liessen sich nicht setzen",
        leer = "das Radialmenue baute keine Scheibe",
        fehler = "Fehler beim Aufruf, siehe Log",
    },
}

function SZ.imautoErgebnis(w)
    local text = T("imauto_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
        tostring(w.abweichend or 0), tostring(w.fehlt or 0))
    if w.auto == "bleibt" then text = text .. " " .. T("imauto_auto_bleibt") end
    return text
end

function SZ.imautoLive(z)
    local lauf = TFMeasure.lauf
    if not lauf or lauf.id ~= "imauto" then return end
    local cfg = TFMeasure.IMAUTO
    local kurz = "-"
    if z.faelle then
        kurz = T("imauto_kurz_gemessen")
    elseif z.kurzGrund then
        kurz = T("imauto_grund_" .. z.kurzGrund)
    end
    local mitS, ohneS = panikMittel(z, true, "jeS"), panikMittel(z, false, "jeS")
    lauf.fortschritt = ((z.kurzFertig and 1 or 0) + #z.phasen) / (cfg.phasen + 1)
    lauf.live = {
        { T("imauto_live_kurz"), kurz },
        { T("imauto_live_phasen"), T("paar", tostring(#z.phasen), tostring(cfg.phasen)) },
        { T("imauto_live_wirkung"), (mitS and ohneS) and komma(mitS - ohneS, 2) or "-" },
    }
end

function SZ.imautoFahrzeug(player)
    local auto = nil
    pcall(function() auto = player:getVehicle() end)
    return auto
end

function SZ.imautoName(auto)
    local name = "?"
    pcall(function() name = tostring(auto:getScriptName()) end)
    return name
end

--- Steht das Spiel? showRadialMenu kehrt dann sofort zurueck (Z. 58-59).
function SZ.imautoPause()
    local pause = false
    pcall(function()
        local tempo = UIManager.getSpeedControls()
        pause = tempo ~= nil and tempo:getCurrentGameSpeed() == 0
    end)
    return pause
end

function SZ.imautoAufschliessen(auto)
    local n = 0
    pcall(function() n = auto:getPartCount() end)
    for i = 0, n - 1 do
        pcall(function()
            local tuer = auto:getPartByIndex(i):getDoor()
            if tuer then tuer:setLocked(false) end
        end)
    end
end

--- Setzt ein Auto ohne Schluessel neben die Figur, wenn sie in keinem sitzt
-- und keines nah steht (getNearVehicle, IsoPlayer Z. 4030: rund 4 Felder).
function SZ.imautoSetzen(player, z)
    local da = nil
    pcall(function() da = player:getVehicle() or player:getNearVehicle() end)
    if da then return end
    local cfg = TFMeasure.IMAUTO
    for _ = 1, cfg.setzVersuche do
        local auto = nil
        pcall(function() auto = addVehicle(cfg.skript, player:getX() + 2, player:getY(), player:getZ()) end)
        if not auto then break end
        local steckt = false
        pcall(function() steckt = auto:isKeysInIgnition() end)
        if not steckt then
            pcall(function() auto:repair() end)
            SZ.imautoAufschliessen(auto)
            z.auto = auto
            return
        end
        pcall(function() auto:permanentlyRemove() end)
    end
    z.keinAuto = true
end

--- Das gesetzte Auto kommt weg, wenn die Figur nicht mehr darin sitzt;
-- sonst bleibt es stehen (removeFromWorld liesse es mit ihr darin ohnehin
-- stehen, BaseVehicle Z. 7128-7134). Liefert "entfernt", "bleibt" oder nil.
function SZ.imautoAutoWeg(player, z)
    if not z.auto then return z.autoStand end
    local drin = false
    pcall(function() drin = player ~= nil and player:getVehicle() == z.auto end)
    if drin then return "bleibt" end
    pcall(function() z.auto:permanentlyRemove() end)
    z.auto = nil
    return "entfernt"
end

--- Warum Kurzschliessen gerade nicht messbar ist; nil, wenn alles passt.
-- Dieselben Bedingungen wie ISVehicleMenu.lua Z. 109-115.
function SZ.imautoKurzGrund(player, auto)
    if not (ISVehicleMenu and ISVehicleMenu.showRadialMenu and ISVehicleMenu.onHotwire)
        or type(getPlayerRadialMenu) ~= "function" or not (Perks and Perks.Electricity and Perks.Mechanics) then
        return "menue"
    end
    if SandboxVars and SandboxVars.VehicleEasyUse then return "easyuse" end
    if auto:isHotwired() then return "kurzgeschlossen" end
    if auto:isEngineStarted() or auto:isEngineRunning() then return "motor" end
    if auto:isKeysInIgnition() then return "zuendung" end
    if player:getInventory():haveThisKeyId(auto:getKeyId()) then return "schluessel" end
    return nil
end

--- Der Stellvertreter fuer das Radialmenue: schreibt die Scheiben mit und
-- tut sonst nichts. Was ein anderes Mod am Menue noch aufruft, tut ebenfalls
-- nichts und steht im Bericht.
function SZ.imautoErsatz(scheiben, unbekannt)
    local ersatz = { sounds = {} }
    function ersatz:clear() for i = #scheiben, 1, -1 do scheiben[i] = nil end end
    function ersatz:isReallyVisible() return false end
    function ersatz:undisplay() end
    function ersatz:setX(x) end
    function ersatz:setY(y) end
    function ersatz:getWidth() return 200 end
    function ersatz:getHeight() return 200 end
    function ersatz:addSlice(text, bild, befehl)
        scheiben[#scheiben + 1] = { text = text, befehl = befehl }
    end
    function ersatz:addToUIManager() end
    function ersatz:setHideWhenButtonReleased(taste) end
    setmetatable(ersatz, { __index = function(_, name)
        unbekannt[tostring(name)] = true
        return function() end
    end })
    return ersatz
end

--- Was die Scheiben zum Kurzschliessen sagen: "angeboten" (Befehl
-- onHotwire), "gesperrt" (Text HotwireSkill ohne Befehl) oder "fehlt".
function SZ.imautoLesen(scheiben)
    if #scheiben == 0 then return nil, "leer" end
    for _, s in ipairs(scheiben) do
        if s.befehl ~= nil and s.befehl == ISVehicleMenu.onHotwire then return "angeboten" end
    end
    local sperre = getText("ContextMenu_VehicleHotwireSkill")
    for _, s in ipairs(scheiben) do
        if s.text == sperre then return "gesperrt" end
    end
    return "fehlt"
end

--- Ein Aufruf von showRadialMenu mit dem Stellvertreter. Menue, Ton und
-- Controller-Eintrag sind danach wieder die alten, auch nach einem Fehler.
function SZ.imautoMenue(player, z)
    local scheiben = {}
    local ersatz = SZ.imautoErsatz(scheiben, z.unbekannt)
    local altMenue, altTon = getPlayerRadialMenu, getSoundManager
    local nr = player:getPlayerNum()
    local joy = (type(JoypadState) == "table") and JoypadState.players or nil
    local joyAlt = joy and joy[nr + 1]
    getPlayerRadialMenu = function(_) return ersatz end
    getSoundManager = function() return { playUISound = function(_, name) end } end
    if joy then joy[nr + 1] = nil end
    local ok, err = pcall(ISVehicleMenu.showRadialMenu, player)
    getPlayerRadialMenu, getSoundManager = altMenue, altTon
    if joy then joy[nr + 1] = joyAlt end
    if not ok then
        log("Im Auto: showRadialMenu warf " .. tostring(err))
        return nil, "fehler"
    end
    return SZ.imautoLesen(scheiben)
end

function SZ.imautoFallSchleife(player, z, faelle)
    local traits = player:getCharacterTraits()
    local elektrik, mechanik = Perks.Electricity, Perks.Mechanics
    for _, f in ipairs(TFMeasure.IMAUTO.faelle) do
        local r = { id = f.id, burglar = f.burglar, e = f.e, m = f.m, soll = f.soll }
        if f.burglar then traits:add(z.burglar) else traits:remove(z.burglar) end
        player:setPerkLevelDebug(elektrik, f.e)
        player:setPerkLevelDebug(mechanik, f.m)
        if player:getPerkLevel(elektrik) ~= f.e or player:getPerkLevel(mechanik) ~= f.m
            or hatTrait(player, "burglar") ~= f.burglar then
            r.grund = "stufen"
        else
            r.gesehen, r.grund = SZ.imautoMenue(player, z)
        end
        if r.gesehen then
            r.urteil = (r.gesehen == r.soll) and "stimmt" or "weicht ab"
        else
            r.urteil = "nicht messbar"
        end
        faelle[#faelle + 1] = r
    end
end

--- Alle Faelle in einem Tick; Stufen und Traits sind danach die alten.
function SZ.imautoKurz(player, z)
    local elektrik, mechanik = Perks.Electricity, Perks.Mechanics
    local e0, m0 = player:getPerkLevel(elektrik), player:getPerkLevel(mechanik)
    local faelle = {}
    local ok, err = pcall(SZ.imautoFallSchleife, player, z, faelle)
    pcall(function() player:setPerkLevelDebug(elektrik, e0) end)
    pcall(function() player:setPerkLevelDebug(mechanik, m0) end)
    pcall(SZ.traitsZurueck, player, z.held)
    if not ok then
        log("Im Auto: Kurzschliessen nicht gemessen: " .. tostring(err))
        z.kurzGrund = "fehler"
        return
    end
    z.faelle = faelle
end

--- Schritt 2: warten, bis die Figur am Steuer sitzt, dann Kurzschliessen.
function SZ.imautoSitzen(player, auto, z, lauf)
    local cfg = TFMeasure.IMAUTO
    local amSteuer = false
    if auto then pcall(function() amSteuer = auto:isDriver(player) end) end
    if not amSteuer then
        z.warten0 = nil
        if auto then
            lauf.status = T("imauto_status_fahrer")
        elseif z.auto then
            lauf.status = T("imauto_status_sitzen_gesetzt")
        elseif z.keinAuto then
            lauf.status = T("imauto_status_keinauto")
        else
            lauf.status = T("imauto_status_sitzen")
        end
        return
    end
    SZ.schritt(lauf, 2)
    if SZ.imautoPause() then
        lauf.status = T("imauto_status_pause")
        return
    end
    local okGrund, grund = pcall(SZ.imautoKurzGrund, player, auto)
    if not okGrund then
        log("Im Auto: Bedingungen nicht lesbar: " .. tostring(grund))
        grund = "fehler"
    end
    if grund and cfg.warten[grund] then
        local jetzt = uhr()
        z.warten0 = z.warten0 or jetzt
        if jetzt and z.warten0 and jetzt - z.warten0 < cfg.kurzWartenMs then
            lauf.status = T("imauto_status_warte_" .. grund)
            return
        end
    end
    z.fahrzeug, z.imTestauto = SZ.imautoName(auto), (z.auto ~= nil and auto == z.auto)
    if grund then z.kurzGrund = grund else SZ.imautoKurz(player, z) end
    z.kurzFertig = true
    SZ.schritt(lauf, 3)
end

function SZ.imautoTraits(player, z, mit)
    local traits = player:getCharacterTraits()
    if z.agora then traits:remove(z.agora) end
    if mit then traits:add(z.klaus) else traits:remove(z.klaus) end
end

function SZ.imautoVerwerfen(z)
    if not z.phase then return end
    z.phase = nil
    z.verworfen = z.verworfen + 1
    if z.verworfen > TFMeasure.IMAUTO.maxVerworfen then TFMeasure.imautoAbbrechen(T("imauto_zuoft")) end
end

--- Schritt 4: Panik-Phasen wie im Panik-Test, solange die Figur im Auto
-- sitzt (auf welchem Sitz auch immer) und das Spiel laeuft.
function SZ.imautoPanik(player, auto, z, lauf)
    local cfg = TFMeasure.IMAUTO
    if not auto or SZ.imautoPause() then
        lauf.status = auto and T("imauto_status_pause") or T("imauto_status_einsteigen")
        SZ.imautoVerwerfen(z)
        return
    end
    SZ.godAus(player, z)
    local stats = player:getStats()
    if not z.phase then
        local mit = (#z.phasen % 2) == 0
        SZ.imautoTraits(player, z, mit)
        local start = mit and cfg.startMit or cfg.startOhne
        stats:set(CharacterStat.PANIC, start)
        z.panik = true
        z.phase = { mit = mit, von = start, vorher = start, ms0 = uhr(), ticks = 0, summe30 = 0 }
        lauf.status = T("imauto_status_misst", tostring(#z.phasen + 1), tostring(cfg.phasen),
            mit and T("imauto_mit") or T("imauto_ohne"))
        return
    end
    local ph = z.phase
    local p = stats:get(CharacterStat.PANIC)
    ph.ticks = ph.ticks + 1
    ph.summe30 = ph.summe30 + (dreissig() or 0)
    if p - ph.vorher > cfg.sprung or p >= 100 or p <= 0 then
        SZ.imautoVerwerfen(z)
        return
    end
    ph.vorher = p
    local jetzt = uhr()
    if jetzt and ph.ms0 and jetzt - ph.ms0 >= cfg.phaseMs and ph.ticks >= cfg.mindestTicks then
        ph.bis, ph.ms = p, jetzt - ph.ms0
        ph.jeS = (p - ph.von) / (ph.ms / 1000)
        if ph.summe30 > 0 then ph.je30 = (p - ph.von) / ph.summe30 end
        z.phasen[#z.phasen + 1] = ph
        z.phase = nil
        if #z.phasen >= cfg.phasen then
            SZ.schritt(lauf, 4)
            SZ.imautoFertig(player, z)
        end
    end
end

function SZ.imautoTF(trait, effekt)
    local liste = TraitFacts and TraitFacts.Static and TraitFacts.Static[trait]
    if type(liste) ~= "table" then return nil end
    for _, e in ipairs(liste) do
        if e.id == effekt then return e end
    end
    return nil
end

--- Claustrophobic: die Wirkung je Bild (mit minus ohne, geteilt durch den
-- Bildraten-Faktor) gegen den Code; Trait Facts zeigt nur einen Bereich je
-- Sekunde, dort steht, ob der Messwert hineinfaellt.
function SZ.imautoKlausZeile(z)
    local cfg = TFMeasure.IMAUTO
    local mit30, ohne30 = panikMittel(z, true, "je30"), panikMittel(z, false, "je30")
    local mitS, ohneS = panikMittel(z, true, "jeS"), panikMittel(z, false, "jeS")
    local e = { id = "claustrophobic/panicin",
                code = string.format("%.4f je Bild x ThirtyFPS = %.2f je s", cfg.code30, cfg.code30 * 30) }
    e.faktor = (mit30 and ohne30) and (mit30 - ohne30) or nil
    e.jeS = (mitS and ohneS) and (mitS - ohneS) or nil
    if e.faktor then
        e.gemessen = string.format("%.4f je Bild x ThirtyFPS = %s je s", e.faktor,
            e.jeS and string.format("%.2f", e.jeS) or "-")
    end
    local tf = SZ.imautoTF("claustrophobic", "panicin")
    if tf and type(tf.value) == "table" and type(tf.value[1]) == "number" and type(tf.value[2]) == "number" then
        local lo, hi = tf.value[1], tf.value[2]
        local lage = ""
        if e.jeS then lage = (e.jeS >= lo and e.jeS <= hi) and ", Messwert im Bereich" or ", Messwert ausserhalb" end
        e.mod = string.format("%s bis %s je s, Fahrzeug = 60 Felder%s", ganz(lo), ganz(hi), lage)
    end
    if not e.faktor then
        e.urteil, e.grund = "nicht messbar", "keine vollstaendige Phase"
    else
        e.urteil = (math.abs(e.faktor - cfg.code30) <= cfg.toleranz * cfg.code30) and "stimmt" or "weicht ab"
    end
    return e
end

--- Eine Zeile aus mehreren Faellen: stimmt nur, wenn jeder Fall stimmt.
function SZ.imautoKurzZeile(z, id, ids, mod)
    local cfg = TFMeasure.IMAUTO
    local plan, nach = {}, {}
    for _, f in ipairs(cfg.faelle) do plan[f.id] = f end
    for _, f in ipairs(z.faelle or {}) do nach[f.id] = f end
    local gesehen, soll = {}, {}
    local ab, grund = false, nil
    for _, fid in ipairs(ids) do
        local f = nach[fid]
        soll[#soll + 1] = fid .. "=" .. plan[fid].soll
        gesehen[#gesehen + 1] = fid .. "=" .. ((f and f.gesehen) or "-")
        if not f or f.urteil == "nicht messbar" then
            grund = grund or cfg.gruende[(f and f.grund) or z.kurzGrund or "fehler"] or "nicht gemessen"
        elseif f.urteil == "weicht ab" then
            ab = true
        end
    end
    local e = { id = id, mod = mod, gemessen = table.concat(gesehen, " "), code = table.concat(soll, " ") }
    if ab then
        e.urteil = "weicht ab"
    elseif grund then
        e.urteil, e.grund = "nicht messbar", grund
    else
        e.urteil = "stimmt"
    end
    return e
end

function SZ.imautoZeilen(z)
    local mod = SZ.imautoTF("burglar", "hotwire") and "nur Text: ohne die sonst noetigen Skills" or nil
    return {
        SZ.imautoKlausZeile(z),
        SZ.imautoKurzZeile(z, "burglar/hotwire", { "ohne", "burglar" }, mod),
        SZ.imautoKurzZeile(z, "burglar/hotwire:schwelle", { "e1m2", "e0m2", "e1m1" }, nil),
    }
end

function SZ.imautoKopf(write, z)
    local cfg = TFMeasure.IMAUTO
    local tempo = "?"
    pcall(function() tempo = tostring(getGameSpeed()) end)
    write("# Im Auto: Claustrophobic und Kurzschliessen (Burglar), Messung an einer lebenden Figur")
    write("# Mess-Mod " .. TFMeasure.VERSION)
    write("# Build " .. buildNummer())
    write(string.format("# Fahrzeug %s (%s); Testauto: %s", z.fahrzeug or "?",
        z.imTestauto and "vom Mod gesetzt" or "schon da", z.autoStand or "keins gesetzt"))
    write(string.format("# Spieltempo %s (1 = normal); je Phase %d ms, Start mit Trait %d, ohne %d",
        tempo, cfg.phaseMs, cfg.startMit, cfg.startOhne))
    write("# laut Code Claustrophobic: IsoGameCharacter.updateInternal Z. 8202 und 8210-8217, im Fahrzeug n = 60:")
    write("#   0.6 x (1 - 60/70) = 0.0857 je Bild x ThirtyFPS = 2.57 je s; ReducePanic fuer alle -0.06 x ThirtyFPS")
    write("#   (BodyDamage Z. 399-413); netto +0.77 mit, -1.80 ohne; Agoraphobic in allen Phasen ab")
    write("# laut Code Kurzschliessen: ISVehicleMenu.showRadialMenu Z. 109-121; am Steuer, nicht kurzgeschlossen,")
    write("#   Motor aus, Sandbox VehicleEasyUse aus, kein Schluessel; Electricity >= 1 und Mechanics >= 2 oder Burglar")
    write("# gesehen = Scheibe im Radialmenue: angeboten (onHotwire), gesperrt (HotwireSkill), fehlt")
    local fremd = {}
    for name in pairs(z.unbekannt or {}) do fremd[#fremd + 1] = name end
    if #fremd > 0 then
        table.sort(fremd)
        write("# Stellvertreter: unbekannte Methoden " .. table.concat(fremd, ", "))
    end
end

function SZ.imautoSchreiben(z, zeilen, stimmen, abweichend, fehlt)
    local gruende = TFMeasure.IMAUTO.gruende
    local writer = getFileWriter(TFMeasure.IMAUTOFILE, true, false)
    local function write(line) writer:write(line .. nl()) end
    local function f2(x) return x and string.format("%.2f", x) or "-" end
    SZ.imautoKopf(write, z)
    write("")
    write("[ergebnis]")
    write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d|phasen=%d|verworfen=%d",
        #zeilen, stimmen, abweichend, fehlt, #z.phasen, z.verworfen))
    write("")
    write("[werte] wert|id|gemessen|soll_mod|soll_code|urteil|grund")
    for _, e in ipairs(zeilen) do
        write(string.format("wert|%s|%s|%s|%s|%s|%s", e.id, e.gemessen or "-", e.mod or "-", e.code or "-",
            e.urteil, e.grund or "-"))
    end
    write("")
    write("[faelle] fall|id|burglar|electricity|mechanics|erwartet|gesehen|urteil|grund")
    for _, f in ipairs(z.faelle or {}) do
        write(string.format("fall|%s|%d|%d|%d|%s|%s|%s|%s", f.id, f.burglar and 1 or 0, f.e, f.m, f.soll,
            f.gesehen or "-", f.urteil, f.grund and (gruende[f.grund] or f.grund) or "-"))
    end
    write("")
    write("[phasen] phase|nr|claustrophobic|ticks|ms|von|bis|je_s|je_30fps")
    for index, ph in ipairs(z.phasen) do
        write(string.format("phase|%d|%d|%d|%s|%s|%s|%s|%s", index, ph.mit and 1 or 0, ph.ticks, ganz(ph.ms),
            f2(ph.von), f2(ph.bis), f2(ph.jeS), SZ.z4(ph.je30)))
    end
    writer:close()
end

--- Traits, Panik, God Mode zurueck; das gesetzte Auto weg, wenn niemand
-- darin sitzt. Stufen und Burglar sind schon im Tick des Kurzschliessens
-- zurueck.
function SZ.imautoAufraeumen(player, z)
    if player then
        pcall(SZ.traitsZurueck, player, z.held)
        if z.panik then pcall(function() player:getStats():reset(CharacterStat.PANIC) end) end
    end
    SZ.godZurueck(player, z)
    z.autoStand = SZ.imautoAutoWeg(player, z)
    TFMeasure.imautoZustand = nil
end

function SZ.imautoFertig(player, z)
    SZ.imautoAufraeumen(player, z)
    local zeilen = SZ.imautoZeilen(z)
    local stimmen, abweichend, fehlt = SZ.zaehlen(zeilen)
    local okWrite, errWrite = pcall(SZ.imautoSchreiben, z, zeilen, stimmen, abweichend, fehlt)
    if TFMeasure.lauf and TFMeasure.lauf.id == "imauto" then TFMeasure.lauf = nil end
    if okWrite then
        local w = { werte = #zeilen, stimmen = stimmen, abweichend = abweichend, fehlt = fehlt,
                    auto = z.autoStand }
        TFMeasure.meldung = nil
        TFMeasure.erledigen("imauto", w)
        log("Im-Auto-Test geschrieben: Zomboid/Lua/" .. TFMeasure.IMAUTOFILE)
        halo(player, T("imauto_fertig", SZ.imautoErgebnis(w)), true)
    else
        log("Im-Auto-Test nicht geschrieben: " .. tostring(errWrite))
        TFMeasure.meldung = { id = "imauto", text = T("status_fehler", tostring(errWrite)) }
    end
end

function TFMeasure.imautoStarten(player)
    local klaus, burglar = traitTypeNamed("claustrophobic"), traitTypeNamed("burglar")
    if not klaus or not burglar then
        TFMeasure.meldung = { id = "imauto", text = T("imauto_keintrait") }
        return
    end
    local z = { held = SZ.traitsMerken(player), klaus = klaus, burglar = burglar,
                agora = traitTypeNamed("agoraphobic"), phasen = {}, verworfen = 0, unbekannt = {} }
    SZ.imautoSetzen(player, z)
    TFMeasure.imautoZustand = z
    TFMeasure.lauf = { id = "imauto", erledigt = 1, fortschritt = 0, status = T("imauto_status_sitzen") }
    SZ.imautoLive(z)
end

function TFMeasure.imautoTick()
    local z, lauf = TFMeasure.imautoZustand, TFMeasure.lauf
    if not z then return end
    if not lauf or lauf.id ~= "imauto" then
        TFMeasure.imautoAbbrechen(T("imauto_abgebrochen"))
        return
    end
    local player = getSpecificPlayer(0)
    local tot = player == nil
    if player then pcall(function() tot = player:isDead() == true end) end
    if tot then
        TFMeasure.imautoAbbrechen(T("imauto_tot"))
        return
    end
    local auto = SZ.imautoFahrzeug(player)
    if not z.kurzFertig then
        SZ.imautoSitzen(player, auto, z, lauf)
    else
        SZ.imautoPanik(player, auto, z, lauf)
    end
    SZ.imautoLive(z)
end

--- Beendet den Test ohne Bericht: Traits, Panik, God Mode zurueck, das
-- gesetzte Auto weg, wenn du nicht darin sitzt.
function TFMeasure.imautoAbbrechen(grund)
    local z = TFMeasure.imautoZustand
    local text = grund or T("imauto_abgebrochen")
    if z then
        SZ.imautoAufraeumen(getSpecificPlayer(0), z)
        if z.autoStand == "bleibt" then text = text .. " " .. T("imauto_auto_bleibt") end
    end
    if TFMeasure.lauf and TFMeasure.lauf.id == "imauto" then TFMeasure.lauf = nil end
    TFMeasure.meldung = { id = "imauto", text = text }
end

--- ---------------------------------------------------------------------------
--- Die Tests des Fensters, in der Reihenfolge der Liste
--- ---------------------------------------------------------------------------
--
-- id        Schluessel der Texte: UI_TFM_<id>_name, _kurz, _zweck, _s1 ...
-- art       "auto" laeuft ohne Zutun, "du" braucht jemanden an der Tastatur
-- schritte  je Schritt, wer ihn tut: "mod" oder "du"
-- datei     der Bericht in Zomboid/Lua
-- erledigt  Datum, falls schon vor dem Fenster gemessen; ohne Zeile in
--           STATUSFILE steht der Test damit unter Erledigt
-- seit      Fassung, ab der ein Ergebnis zaehlt (seit 6.23.4); ein aelteres
--           oder eines ohne Fassung laesst den Test wieder offen stehen
-- start     function(player), laeuft im Tick. Ein kurzer Test misst sofort und
--           traegt sich selbst ein; ein langer setzt TFMeasure.lauf.
-- stop      function(), beendet einen langen Test sauber
-- ergebnis  function(werte), der Satz fuer das Fenster
TFMeasure.TESTS = {
    { id = "axt", art = "auto", datei = TFMeasure.AXTFILE,
      schritte = { "mod", "mod", "mod", "mod", "mod" },
      start = function(player) TFMeasure.axtStarten(player) end,
      stop = function() TFMeasure.axtAbbrechen(T("axt_abgebrochen")) end,
      ergebnis = function(w)
          return T("axt_ergebnis", komma(w.abstand, 2), komma(w.schaden, 2), komma(w.schwung, 2))
      end },
    -- Paket D: Spielfehler adrenaline-movespeed
    -- seit 6.33.0 drei Teile (Gehen Stufe 4, Gehen Stufe 3, Rennen Stufe 4), seit 6.34.0 dazu
    -- Sprinten, seit 6.37.0 Rennen und Sprinten auch auf Stufe 3
    { id = "adrenalin", art = "du", datei = TFMeasure.ADRENALINFILE, seit = "6.37.0",
      schritte = { "du", "mod", "mod", "mod" },
      start = function(player) TFMeasure.adrenalinStarten(player) end,
      stop = function() TFMeasure.adrenalinAbbrechen(T("adrenalin_abgebrochen")) end,
      ergebnis = function(w)
          return T("adrenalin_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    -- seit 6.38.0: nur Rennen und Sprinten bei Strong Panic, je neun Phasen
    { id = "adrenalinstrong", art = "du", datei = TFMeasure.ADRENALIN_STRONGFILE,
      schritte = { "du", "mod", "mod", "mod" },
      start = function(player)
          TFMeasure.adrenalinStarten(player, { id = "adrenalinstrong", teile = TFMeasure.ADRENALIN_STRONG,
                                               datei = TFMeasure.ADRENALIN_STRONGFILE })
      end,
      stop = function() TFMeasure.adrenalinAbbrechen(T("adrenalin_abgebrochen")) end,
      ergebnis = function(w)
          return T("adrenalin_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    { id = "klettern", art = "auto", datei = TFMeasure.KLETTERFILE,
      schritte = { "mod", "mod" },
      start = function(player)
          local summe = TFMeasure.klettern(player)
          if summe and summe.geschrieben then
              TFMeasure.erledigen("klettern", { faelle = summe.faelle, abweichungen = summe.abweichungen })
          end
      end,
      ergebnis = function(w)
          return T("klettern_ergebnis", komma(w.faelle, 0), komma(w.abweichungen, 0))
      end },
    -- Ohne start: erfasst wird beim Weltbetreten einer neuen Figur.
    { id = "figur", art = "figuren", datei = TFMeasure.FIGURFILE,
      schritte = { "du", "mod", "mod" },
      tabelle = function() return figurTabelle() end,
      spalten = { 0, 170, 240, 320, 380 },
      wartet = function() return figurWartetText() end,
      ergebnis = function(w)
          return T("figur_ergebnis_" .. tostring(w.lesart or "gemischt"), tostring(w.erfasst or 0))
      end },
    -- seit 6.24.0 mit Feuer, Leichen, Blut, Verbinden, Lesen, Ei, Krit und
    -- Forschung; seit 6.24.1 der kritische Treffer unter der Klemme; seit
    -- 6.25.0 zwei Spielfehler (Metallbarrikade, Leichenstress beim Craften);
    -- seit 6.26.0 die drei Pakete aus der Messbarkeits-Recherche; seit 6.27.0
    -- Paket D (Leichen, Erkaeltung, Holzwand, Medical Check, Dose, Zombie)
    -- seit 6.35.0 die Erholung beim Sitzen als Zuwachs
    { id = "werte", art = "auto", datei = TFMeasure.WERTEFILE, seit = "6.35.0",
      schritte = { "mod", "mod" },
      start = function(player) TFMeasure.werteStarten(player) end,
      stop = function() TFMeasure.werteAbbrechen(T("werte_abgebrochen")) end,
      ergebnis = function(w)
          return T("werte_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    { id = "panik", art = "halb", datei = TFMeasure.PANIKFILE,
      schritte = { "du", "mod", "mod" },
      start = function(player) TFMeasure.panikStarten(player) end,
      stop = function() TFMeasure.panikAbbrechen(T("panik_abgebrochen")) end,
      ergebnis = function(w)
          return T("panik_ergebnis", komma(w.mit, 1), komma(w.ohne, 1), komma(w.trait, 1))
      end },
    -- Blutpanik und Blutstress (Hemophobic), Stress aus Geraeuschen (Deaf)
    -- seit 6.32.1 kommt das Geraeusch an (Deaf); aeltere Laeufe zaehlen nicht
    { id = "blut", art = "halb", datei = TFMeasure.BLUTFILE, seit = "6.32.1",
      schritte = { "du", "mod", "mod", "mod", "mod" },
      start = function(player) TFMeasure.blutStarten(player) end,
      stop = function() TFMeasure.blutAbbrechen(T("blut_abgebrochen")) end,
      ergebnis = function(w)
          return T("blut_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    { id = "wach", art = "halb", datei = TFMeasure.WACHFILE,
      schritte = { "du", "mod", "mod", "mod", "mod" },
      start = function(player) TFMeasure.wachStarten(player) end,
      stop = function() TFMeasure.wachAbbrechen(T("wach_abgebrochen")) end,
      ergebnis = function(w)
          return T("wach_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    -- seit 6.23.3 im Wechsel und mit 300 Proben, seit 6.23.4 mit der Probe
    -- einen Schritt unter der Mitte; aeltere Laeufe zaehlen nicht
    { id = "schlaf", art = "halb", datei = TFMeasure.SCHLAFFILE, seit = "6.23.4",
      schritte = { "mod", "du", "mod", "mod", "mod", "mod" },
      start = function(player) TFMeasure.schlafStarten(player) end,
      stop = function() TFMeasure.schlafAbbrechen(T("schlaf_abgebrochen")) end,
      ergebnis = function(w)
          return T("schlaf_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    -- neu am 14.09.2026: Eagle Eyed und Short Sighted beim Einblenden
    { id = "einblenden", art = "halb", datei = TFMeasure.EINBLENDENFILE,
      schritte = { "du", "mod", "mod", "mod" },
      start = function(player) TFMeasure.einblendenStarten(player) end,
      stop = function() TFMeasure.einblendenAbbrechen(T("einblenden_abgebrochen")) end,
      ergebnis = function(w)
          return T("einblenden_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    -- seit 6.25.0
    { id = "laufen", art = "du", datei = TFMeasure.LAUFENFILE,
      schritte = { "du", "mod", "mod", "mod" },
      start = function(player) TFMeasure.laufenStarten(player) end,
      stop = function() TFMeasure.laufenAbbrechen(T("laufen_abgebrochen")) end,
      ergebnis = function(w)
          return T("laufen_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    -- seit 14.09.2026: Claustrophobic und Kurzschliessen, du sitzt im Auto
    { id = "imauto", art = "du", datei = TFMeasure.IMAUTOFILE,
      schritte = { "mod", "du", "mod", "mod", "mod" },
      start = function(player) TFMeasure.imautoStarten(player) end,
      stop = function() TFMeasure.imautoAbbrechen(T("imauto_abgebrochen")) end,
      ergebnis = function(w) return SZ.imautoErgebnis(w) end },
    -- seit 6.36.0: die Baender der Stufen-Traits, das Spiel laeuft die Leiter selbst ab
    { id = "stufen", art = "auto", datei = TFMeasure.STUFENFILE,
      schritte = { "mod", "mod", "mod" },
      start = function(player) TFMeasure.stufenTest(player) end,
      ergebnis = function(w)
          return T("werte_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    -- seit 6.39.0: applyTraits an der Testfigur, elf Faelle, statt neuer Figuren von Hand
    { id = "erschaffung", art = "auto", datei = TFMeasure.ERSCHAFFUNGFILE,
      schritte = { "mod", "mod", "mod" },
      start = function(player) TFMeasure.erschaffungTest(player) end,
      ergebnis = function(w)
          return T("werte_ergebnis", tostring(w.werte or 0), tostring(w.stimmen or 0),
              tostring(w.abweichend or 0), tostring(w.fehlt or 0))
      end },
    { id = "xp", art = "auto", datei = TFMeasure.XPFILE, erledigt = "12.09.2026",
      schritte = { "mod", "mod" },
      start = function(player)
          TFMeasure.xpLeiter(player)
          TFMeasure.erledigen("xp", {})
      end },
    { id = "sprint", art = "du", datei = TFMeasure.FILE, erledigt = "10.09.2026",
      schritte = { "du", "mod" },
      start = function(player)
          TFMeasure.armSprint(player)
          TFMeasure.lauf = { id = "sprint", extern = true }
      end,
      stop = function() sprint = nil TFMeasure.stehendeZeile = nil end },
    { id = "auto", art = "du", datei = TFMeasure.FILE, erledigt = "11.09.2026",
      schritte = { "du", "mod" },
      start = function(player)
          TFMeasure.armAccel(player)
          TFMeasure.lauf = { id = "auto", extern = true }
      end,
      stop = function() accel = nil TFMeasure.stehendeZeile = nil end },
}

--- Merkt sich den Start; gestartet wird im naechsten Tick, wie bei F8 und F9.
function TFMeasure.starteTest(id)
    if TFMeasure.lauf or TFMeasure.startGewuenscht then return false end
    TFMeasure.startGewuenscht = id
    return true
end

--- Beendet den laufenden Test ohne Ergebnis.
function TFMeasure.stoppeTest()
    TFMeasure.kette = nil
    local lauf = TFMeasure.lauf
    if not lauf then return false end
    local test = testNamed(lauf.id)
    if test and test.stop then
        local ok, err = pcall(test.stop)
        if not ok then log("Abbrechen: " .. tostring(err)) end
    end
    TFMeasure.lauf = nil
    return true
end

local function testStarten(id)
    local test = testNamed(id)
    local player = getSpecificPlayer(0)
    if not test or not test.start or not player or TFMeasure.lauf then return end
    TFMeasure.meldung = nil
    local ok, err = pcall(test.start, player)
    if not ok then
        log("Test " .. id .. " nicht gestartet: " .. tostring(err))
        if test.stop then pcall(test.stop) end
        TFMeasure.lauf = nil
        TFMeasure.meldung = { id = id, text = T("status_fehler", tostring(err)) }
    end
end

--- ---------------------------------------------------------------------------
--- Stufen-Traits (seit 6.36.0): die Baender von Trait Facts gegen das Spiel
--- ---------------------------------------------------------------------------
--
-- Trait Facts sagt in der Charaktererstellung voraus, welche Stufen-Traits das
-- Spiel setzt (Weak, Feeble, Stout, Strong; Unfit, Out of Shape, Fit,
-- Athletic). Geprueft war das nur ueber frisch erschaffene Figuren, eine je
-- Fall. Hier laeuft das Spiel selbst die Leiter ab: IsoGameCharacter.LevelPerk
-- hebt die Stufe und feuert das Ereignis LevelPerk, auf das Vanillas
-- xpUpdate.levelPerk (server/XpSystem/XpUpdate.lua:202-247) die vier Traits
-- des Skills abnimmt und den zur Stufe passenden setzt. Je Stufe 1 bis 10 liest
-- der Test, welcher der vier jetzt da ist, und haelt ihn gegen
-- TraitFacts.Summary.levelTraitFor. setPerkLevelDebug loest kein LevelPerk aus
-- (IsoGameCharacter Z. 4487-4500) und dient nur zum Zuruecksetzen.
--
-- Nicht abgedeckt: der Sonderfall der Erschaffung (bei Stufe 0 faellt dort
-- kein LevelPerk, der gewaehlte Trait bleibt); dafuer bleibt der Test Neue Figur.
TFMeasure.STUFENFILE = "TraitFacts_stufen.txt"
TFMeasure.STUFEN = {
    { skill = "strength", perk = "Strength", traits = { "weak", "feeble", "stout", "strong" } },
    { skill = "fitness", perk = "Fitness", traits = { "unfit", "outofshape", "fit", "athletic" } },
}

function TFMeasure.stufenTest(player)
    local tf = TraitFacts
    local soll = tf and tf.Summary and tf.Summary.levelTraitFor
    local zeilen, stimmen, abweichend, fehlt = {}, 0, 0, 0
    local c = player:getCharacterTraits()
    for _, fall in ipairs(TFMeasure.STUFEN) do
        local perk = Perks[fall.perk]
        local stufe0 = player:getPerkLevel(perk)
        -- Den Typ gleich mit merken: was die Figur traegt, kommt auch dann zurueck,
        -- wenn die Registry den Trait unter diesem Namen nicht hergibt.
        local hatte = {}
        local bekannt = c:getKnownTraits()
        for index = 0, (bekannt and bekannt:size() or 0) - 1 do
            local typ = bekannt:get(index)
            for _, key in ipairs(fall.traits) do
                if keyOf(typ) == key then hatte[key] = typ end
            end
        end
        -- Auf 0 ohne Ereignis, die vier Traits weg: von hier laeuft das Spiel selbst.
        stufeSetzen(player, perk, 0)
        for _, key in ipairs(fall.traits) do
            local typ = traitTypeNamed(key)
            if typ then c:remove(typ) end
        end
        for stufe = 1, 10 do
            local ok = pcall(function() player:LevelPerk(perk) end)
            local erreicht = player:getPerkLevel(perk)
            local da = {}
            for _, key in ipairs(fall.traits) do
                if hatTrait(player, key) then da[#da + 1] = key end
            end
            local spiel = (#da > 0) and table.concat(da, "+") or "-"
            local mod = soll and (soll(fall.skill, stufe) or "-") or nil
            local urteil
            if not ok or erreicht ~= stufe then
                urteil, fehlt = "nicht messbar", fehlt + 1
            elseif mod == nil then
                urteil, fehlt = "ohne Trait Facts", fehlt + 1
            elseif mod == spiel then
                urteil, stimmen = "stimmt", stimmen + 1
            else
                urteil, abweichend = "weicht ab", abweichend + 1
            end
            zeilen[#zeilen + 1] = string.format("stufe|%s|%d|%s|%s|%s", fall.skill, stufe, spiel, tostring(mod or "-"),
                urteil)
        end
        -- Zurueck: Stufe wie vorher, Traits wie vorher.
        stufeSetzen(player, perk, stufe0)
        for _, key in ipairs(fall.traits) do
            local typ = hatte[key] or traitTypeNamed(key)
            if typ then
                if hatte[key] then c:add(typ) else c:remove(typ) end
            end
        end
    end
    local okWrite, err = pcall(function()
        local writer = getFileWriter(TFMeasure.STUFENFILE, true, false)
        local z = nl()
        writer:write("# Stufen-Traits: die Baender von Trait Facts gegen das Spiel" .. z)
        writer:write("# Mess-Mod " .. TFMeasure.VERSION .. z)
        writer:write("# Build " .. buildNummer() .. ", " .. heute() .. z)
        writer:write("# je Skill von Stufe 0 aus zehnmal LevelPerk; gelesen, welcher der vier Stufen-Traits danach da ist"
            .. z)
        writer:write(z .. "[ergebnis]" .. z)
        writer:write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d", #zeilen, stimmen,
            abweichend, fehlt) .. z)
        writer:write(z .. "[stufen] stufe|skill|stufe|spiel|trait_facts|urteil" .. z)
        for _, zeile in ipairs(zeilen) do writer:write(zeile .. z) end
        writer:close()
    end)
    if not okWrite then
        TFMeasure.meldung = { id = "stufen", text = T("status_fehler", tostring(err)) }
        return
    end
    TFMeasure.erledigen("stufen", { werte = #zeilen, stimmen = stimmen, abweichend = abweichend, fehlt = fehlt })
    log("Stufen-Traits geschrieben: Zomboid/Lua/" .. TFMeasure.STUFENFILE)
end

--- ---------------------------------------------------------------------------
--- Erschaffung (seit 6.39.0): Stufen-Traits einer neuen Figur, ohne neue Figur
--- ---------------------------------------------------------------------------
--
-- Der Test Stufen-Traits laeuft die Leiter ab; offen blieb der Weg, den das
-- Spiel bei der ERSCHAFFUNG geht: IsoGameCharacter.applyTraits (public,
-- Z. 10395-10440 in 42.20.4) setzt die gewaehlten Traits, zaehlt 5 plus alle
-- Boosts aus Traits und Beruf (descriptor.getXPBoostMap) je Skill zusammen,
-- deckelt bei 0 und 10 und ruft so oft LevelPerk. Bei 0 faellt kein LevelPerk,
-- der gewaehlte Stufen-Trait bleibt dann stehen (Spielfehler
-- stufentraits-erschaffung). Bisher brauchte es dafuer je Fall eine frisch
-- erschaffene Figur von Hand.
--
-- Hier ruft der Test applyTraits an der Testfigur selbst, je Fall einmal:
--   vorher  alle Skill-Stufen merken und auf 0, alle Traits merken und weg,
--           Gewicht merken, die XP-Boosts der Figur sichern (HashMap-Kopie,
--           ohne Umweg ueber Lua-Zahlen: ein Double in der Map braeche die
--           Casts der Engine) und mit setProfessionSkills auf den Stand
--           setzen, den sie bei der Erschaffung haben (nur der Beruf);
--   danach  lesen, welche der acht Stufen-Traits die Figur traegt, und gegen
--           TraitFacts.Summary.levelTraits halten; dann alles zurueck.
-- Laesst sich die Map nicht sichern (HashMap nicht erreichbar), laeuft der Test
-- nicht: lieber kein Ergebnis als eine Testfigur mit verbogenen XP-Boosts.
TFMeasure.ERSCHAFFUNGFILE = "TraitFacts_erschaffung.txt"
TFMeasure.ERSCHAFFUNG = {
    { "unfit", "obese" },        -- Fitness rechnerisch unter 0: der Sonderfall
    { "unfit" },
    { "outofshape" },
    { "fit" },
    { "athletic" },
    { "fit", "obese" },          -- hebt sich auf Stufe 5 auf: Fit faellt
    { "feeble" },
    { "weak" },
    { "stout" },
    { "strong" },
    { "strong", "athletic" },
}
local ERSCH = { BAND = { "weak", "feeble", "stout", "strong", "unfit", "outofshape", "fit", "athletic" } }

--- Traegt die Figur den Trait mit diesem Schluessel? Wie hatTrait, als Menge.
function ERSCH.traegt(player)
    local out = {}
    local liste = player:getCharacterTraits():getKnownTraits()
    for index = 0, (liste and liste:size() or 0) - 1 do out[keyOf(liste:get(index))] = liste:get(index) end
    return out
end

function ERSCH.einFall(player, fall, prof)
    local c = player:getCharacterTraits()
    -- Stufen auf 0, Traits weg, Boosts wie bei der Erschaffung.
    local perks = PerkFactory.PerkList
    for index = 0, perks:size() - 1 do player:setPerkLevelDebug(perks:get(index), 0) end
    for _, typ in pairs(ERSCH.traegt(player)) do c:remove(typ) end
    player:getDescriptor():setProfessionSkills(prof)
    local liste, defs = ArrayList.new(), {}
    for _, key in ipairs(fall) do
        local typ = traitTypeNamed(key)
        if not typ then return nil, "Trait " .. key .. " fehlt in der Registry" end
        liste:add(typ)
        defs[#defs + 1] = CharacterTraitDefinition.getCharacterTraitDefinition(typ)
    end
    player:applyTraits(liste)
    local jetzt = ERSCH.traegt(player)
    local spiel = {}
    for _, key in ipairs(ERSCH.BAND) do
        if jetzt[key] then spiel[#spiel + 1] = key end
    end
    table.sort(spiel)
    -- Was Trait Facts vorhersagt: gewaehlt minus drop plus add, nur die acht.
    local soll = nil
    local tf = TraitFacts
    if tf and tf.Summary and tf.Summary.levelTraits then
        local v = tf.Summary.levelTraits(defs, prof)
        if v then
            local menge = {}
            for _, key in ipairs(fall) do menge[key] = true end
            for key in pairs(v.drop or {}) do menge[key] = nil end
            for _, key in ipairs(v.add or {}) do menge[key] = true end
            soll = {}
            for _, key in ipairs(ERSCH.BAND) do
                if menge[key] then soll[#soll + 1] = key end
            end
            table.sort(soll)
        end
    end
    return { spiel = table.concat(spiel, "+"), soll = soll and table.concat(soll, "+") or nil,
             fitness = player:getPerkLevel(Perks.Fitness), strength = player:getPerkLevel(Perks.Strength) }
end

function TFMeasure.erschaffungTest(player)
    local desc = player:getDescriptor()
    local prof = CharacterProfessionDefinition.getCharacterProfessionDefinition(desc:getCharacterProfession())
    local boosts = desc:getXPBoostMap()
    -- Sichern, ohne dass eine Zahl durch Lua geht.
    local okKopie, kopie = pcall(function()
        local k = HashMap.new()
        k:putAll(boosts)
        return k
    end)
    if not okKopie or not kopie or not prof then
        TFMeasure.meldung = { id = "erschaffung", text = T("erschaffung_nichtsicher") }
        return
    end
    local stufen, perks = {}, PerkFactory.PerkList
    for index = 0, perks:size() - 1 do stufen[index] = player:getPerkLevel(perks:get(index)) end
    local traits = ERSCH.traegt(player)
    local gewicht = nil
    pcall(function() gewicht = player:getNutrition():getWeight() end)
    local god = true
    pcall(function() god = player:isGodMod() == true end)

    local zeilen, stimmen, abweichend, fehlt = {}, 0, 0, 0
    for _, fall in ipairs(TFMeasure.ERSCHAFFUNG) do
        local ok, r, grund = pcall(ERSCH.einFall, player, fall, prof)
        local name = table.concat(fall, "+")
        if not ok or not r then
            fehlt = fehlt + 1
            zeilen[#zeilen + 1] = "fall|" .. name .. "|-|-|-|-|nicht messbar|" .. tostring(ok and grund or r)
        else
            local urteil
            if r.soll == nil then
                urteil, fehlt = "ohne Trait Facts", fehlt + 1
            elseif r.soll == r.spiel then
                urteil, stimmen = "stimmt", stimmen + 1
            else
                urteil, abweichend = "weicht ab", abweichend + 1
            end
            zeilen[#zeilen + 1] = string.format("fall|%s|%d|%d|%s|%s|%s|", name, r.fitness, r.strength,
                (r.spiel ~= "") and r.spiel or "-", (r.soll and r.soll ~= "") and r.soll or (r.soll and "-" or "?"), urteil)
        end
    end

    -- Alles zurueck, in jedem Fall.
    pcall(function()
        local c = player:getCharacterTraits()
        for _, typ in pairs(ERSCH.traegt(player)) do c:remove(typ) end
        for _, typ in pairs(traits) do c:add(typ) end
    end)
    for index = 0, perks:size() - 1 do pcall(stufeSetzen, player, perks:get(index), stufen[index]) end
    pcall(function()
        boosts:clear()
        boosts:putAll(kopie)
    end)
    if gewicht then pcall(function() player:getNutrition():setWeight(gewicht) end) end
    pcall(function() player:setGodMod(god) end)

    local okWrite, err = pcall(function()
        local writer = getFileWriter(TFMeasure.ERSCHAFFUNGFILE, true, false)
        local z = nl()
        writer:write("# Erschaffung: Stufen-Traits nach applyTraits gegen die Vorhersage von Trait Facts" .. z)
        writer:write("# Mess-Mod " .. TFMeasure.VERSION .. z)
        writer:write("# Build " .. buildNummer() .. ", " .. heute() .. ", Beruf der Testfigur: "
            .. tostring(desc:getCharacterProfession()) .. z)
        writer:write("# je Fall: Stufen auf 0, Traits weg, XP-Boosts wie bei der Erschaffung (setProfessionSkills),"
            .. " dann applyTraits mit den gewaehlten Traits; danach alles zurueck" .. z)
        writer:write(z .. "[ergebnis]" .. z)
        writer:write(string.format("ergebnis|werte=%d|stimmen=%d|weichen_ab=%d|nicht_messbar=%d", #zeilen, stimmen,
            abweichend, fehlt) .. z)
        writer:write(z .. "[faelle] fall|gewaehlt|fitness|strength|spiel|trait_facts|urteil|grund" .. z)
        for _, zeile in ipairs(zeilen) do writer:write(zeile .. z) end
        writer:close()
    end)
    if not okWrite then
        TFMeasure.meldung = { id = "erschaffung", text = T("status_fehler", tostring(err)) }
        return
    end
    TFMeasure.erledigen("erschaffung", { werte = #zeilen, stimmen = stimmen, abweichend = abweichend, fehlt = fehlt })
    log("Erschaffung geschrieben: Zomboid/Lua/" .. TFMeasure.ERSCHAFFUNGFILE)
end

--- ---------------------------------------------------------------------------
--- Patch-Tag-Lauf (seit 6.32.0): alle automatischen Tests am Stueck
--- ---------------------------------------------------------------------------
--
-- Kommt ein neuer Build des Spiels, ist die Frage immer dieselbe: stimmen die
-- Werte noch? Bis 6.31 hiess das, vier Tests einzeln zu starten und vier
-- Berichte zu lesen. Die Kette startet sie nacheinander und schreibt am Ende
-- eine Datei, die je Test sagt, was herauskam, und ganz oben, ob irgendwo
-- etwas abweicht. Hinein kommen nur Tests, die ohne jemanden an der Tastatur
-- laufen (art "auto"); was dich braucht, bleibt beim Messfenster.
--
-- Die Code-Werte zuerst: sie sind der groesste Teil und brauchen nichts aus
-- der Umgebung. Der Axt-Test braucht einen Baum in der Naehe; fehlt er, steht
-- das im Bericht, und die Kette geht weiter.
TFMeasure.KETTENFILE = "TraitFacts_patchtag.txt"
TFMeasure.KETTE = { "werte", "stufen", "erschaffung", "axt", "klettern", "xp" }

local function ketteSchreiben(kette)
    local ok, err = pcall(function()
        local writer = getFileWriter(TFMeasure.KETTENFILE, true, false)
        local z = nl()
        local abweichend, fehlt, ohne = 0, 0, 0
        for _, e in ipairs(kette.ergebnisse) do
            -- Nur `abweichend` zaehlt: Wert gegen Sollwert. Die `abweichungen`
            -- des Kletterlaufs sind sein Messergebnis (wo ein Trait den
            -- Kletterwert aendert, 528 Stellen), kein Fehler; bis 6.32.1
            -- standen sie mit in der Summe, und der erste Lauf im Spiel
            -- (20.09.2026) meldete "528 abweichend", obwohl alles stimmte.
            abweichend = abweichend + (tonumber(e.werte and e.werte.abweichend) or 0)
            fehlt = fehlt + (tonumber(e.werte and e.werte.fehlt) or 0)
            if not e.fertig then ohne = ohne + 1 end
        end
        writer:write("# Trait Facts Patch-Tag-Lauf, Mess-Mod " .. TFMeasure.VERSION .. ", Build "
            .. buildNummer() .. ", " .. heute() .. z)
        writer:write("# test|stand|schluessel=wert|...; Einzelheiten im Bericht des Tests" .. z)
        writer:write("gesamt|abweichend=" .. abweichend .. "|fehlt=" .. fehlt .. "|ohne-ergebnis=" .. ohne
            .. "|tests=" .. #kette.ergebnisse .. z)
        for _, e in ipairs(kette.ergebnisse) do
            local felder = { e.id, e.fertig and "fertig" or "ohne-ergebnis" }
            local namen = {}
            for name in pairs(e.werte or {}) do namen[#namen + 1] = name end
            table.sort(namen)
            for _, name in ipairs(namen) do
                local wert = e.werte[name]
                if type(wert) == "number" and wert ~= math.floor(wert) then wert = string.format("%.4f", wert) end
                felder[#felder + 1] = name .. "=" .. tostring(wert)
            end
            if e.grund then felder[#felder + 1] = "grund=" .. tostring(e.grund) end
            local test = testNamed(e.id)
            if test and test.datei then felder[#felder + 1] = "bericht=" .. tostring(test.datei) end
            writer:write(table.concat(felder, "|") .. z)
        end
        writer:close()
        kette.summe = { abweichend = abweichend, fehlt = fehlt, ohne = ohne }
    end)
    if not ok then log("Patch-Tag-Lauf nicht geschrieben: " .. tostring(err)) end
end

--- Startet die Kette. @return boolean  false, wenn gerade etwas laeuft
function TFMeasure.ketteStarten()
    if TFMeasure.lauf or TFMeasure.startGewuenscht or TFMeasure.kette then return false end
    local ids = {}
    for _, id in ipairs(TFMeasure.KETTE) do
        local test = testNamed(id)
        if test and test.start and test.art == "auto" then ids[#ids + 1] = id end
    end
    if #ids == 0 then return false end
    TFMeasure.kette = { ids = ids, index = 0, ergebnisse = {} }
    log("Patch-Tag-Lauf: " .. table.concat(ids, ", "))
    return true
end

--- Ein Schritt je Tick, solange kein Test laeuft: das Ergebnis des letzten
-- festhalten, den naechsten starten, am Ende schreiben. Ein Test gilt als
-- fertig, wenn sein Stand nach dem Start neu geschrieben wurde; sonst steht
-- der Grund aus TFMeasure.meldung im Bericht.
function TFMeasure.ketteTick()
    local kette = TFMeasure.kette
    if not kette or TFMeasure.lauf or TFMeasure.startGewuenscht then return end
    if kette.wartet then
        -- Der Start liegt einen Tick zurueck; ein langer Test hat jetzt lauf
        -- gesetzt (dann kaemen wir nicht hierher), ein kurzer ist fertig.
        local id = kette.ids[kette.index]
        local stand = TFMeasure.stand and TFMeasure.stand[id]
        local neu = stand ~= nil and stand ~= kette.vorher
        local grund = nil
        if not neu and TFMeasure.meldung and TFMeasure.meldung.id == id then grund = TFMeasure.meldung.text end
        kette.ergebnisse[#kette.ergebnisse + 1] = { id = id, fertig = neu, werte = neu and stand.werte or nil,
                                                    grund = grund or (not neu and "kein Ergebnis") or nil }
        kette.wartet = nil
    end
    if kette.index >= #kette.ids then
        ketteSchreiben(kette)
        TFMeasure.kette = nil
        local s = kette.summe or {}
        TFMeasure.meldung = { id = "kette", text = T("kette_fertig", tostring(#kette.ergebnisse),
            tostring(s.abweichend or "?"), tostring(s.fehlt or "?"), tostring(s.ohne or "?"), TFMeasure.KETTENFILE) }
        log("Patch-Tag-Lauf fertig: " .. TFMeasure.KETTENFILE)
        return
    end
    kette.index = kette.index + 1
    local id = kette.ids[kette.index]
    if not TFMeasure.stand then TFMeasure.statusLesen() end
    kette.vorher = TFMeasure.stand and TFMeasure.stand[id]
    kette.wartet = true
    TFMeasure.startGewuenscht = id
end

--- Sprint und Autos laufen mit ihrem eigenen Zustand; fertig sind sie, wenn
-- der verschwunden ist.
local function laufPruefen()
    local lauf = TFMeasure.lauf
    if not lauf or not lauf.extern then return end
    local laeuft = (lauf.id == "sprint" and sprint ~= nil) or (lauf.id == "auto" and accel ~= nil)
    if not laeuft then
        TFMeasure.lauf = nil
        TFMeasure.erledigen(lauf.id, {})
    end
end

--- God Mode im Mess-Mod heilt laufend, wie der von Cheat Menu: Reloaded
-- (CheatMenuToggleManager.lua, hier seit 6.21.0 nachgebaut).
--
-- setGodMod schuetzt nur vor Schaden, nicht vor Steifheit: jeder Axthieb ruft
-- addCombatMuscleStrain (ISChopTreeAction.animEvent), und das fragt God Mode
-- nicht (IsoGameCharacter:14581). Am 13.09.2026 stand die Testfigur nach dem
-- Axt-Test mit Zerrung an beiden Armen und Schmerzen da. Solange das
-- Kaestchen God Mode an ist, heilt dieser Tick die Figur deshalb ganz:
-- RestoreToFullHealth (setzt auch die Steifheit auf 0, BodyPart:551), dazu
-- Muedigkeit, Hunger und Durst zurueck, wie Vanilla es in
-- LastStand/Challenge1.lua:192-194 tut. Die Ausdauer bleibt beim Kaestchen
-- "Ausdauer unbegrenzt" (ausdauerTick), damit sie sich getrennt abschalten
-- laesst. Ein Test, der Verletzungen oder Heilung misst, braucht God Mode aus.
function TFMeasure.godTick()
    if TFMeasure.cheatStand.god ~= true then return end
    -- Der Panik-Test (seit 6.22.0) braucht die Panik ungeheilt:
    -- RestoreToFullHealth setzt sie mit allen anderen Werten zurueck.
    if TFMeasure.godPause then return end
    local player = getSpecificPlayer(0)
    if not player or not player.getBodyDamage then return end
    player:getBodyDamage():RestoreToFullHealth()
    local stats = player:getStats()
    if stats and CharacterStat then
        for _, name in ipairs({ "FATIGUE", "HUNGER", "THIRST" }) do
            if CharacterStat[name] then stats:reset(CharacterStat[name]) end
        end
    end
end

function TFMeasure.cheatSetzen(id, an)
    local player = getSpecificPlayer(0)
    for _, cheat in ipairs(TFMeasure.CHEATS) do
        if cheat.id == id then
            if player then schalterSetzen(player, cheat, an) end
            TFMeasure.cheatStand[id] = an
            if id == "ausdauer" then TFMeasure.ausdauerAus = not an end
        end
    end
    TFMeasure.cheatsSchreiben()
end

--- ---------------------------------------------------------------------------
--- Das Fenster selbst
--- ---------------------------------------------------------------------------

local LISTE = 230
-- Die Liste links scrollt (seit 6.26.3): das Fenster richtet seine Hoehe
-- nach der rechten Seite, mindestens LISTE_MIN, und was darunter nicht
-- passt, erreicht das Mausrad. Vorher wuchs das Fenster mit der Liste.
TFMeasure.LISTE_MIN = 360
TFMeasure.LISTE_RAD = 36
TFMeasure.BALKEN_BREITE = 6
local RAND = 10
local FARBE = {
    text  = { 0.90, 0.90, 0.90 },
    leise = { 0.60, 0.60, 0.60 },
    thema = { 0.45, 0.72, 1.00 },
    gut   = { 0.45, 0.72, 0.48 },
    warn  = { 0.90, 0.71, 0.31 },
    weiss = { 1.00, 1.00, 1.00 },
}

local function schrifthoehe(font)
    local ok, hoehe = pcall(function() return getTextManager():getFontHeight(font) end)
    if ok and type(hoehe) == "number" and hoehe > 0 then return hoehe end
    return 16
end

--- Breite eines Textes; ohne MeasureStringX (Testgeruest) 7 px je Zeichen.
local function textbreite(font, text)
    local tm = getTextManager()
    if tm and tm.MeasureStringX then return tm:MeasureStringX(font, text) end
    return #text * 7
end

--- Kuerzt einen Text mit "..." auf die Breite (seit 6.23.1: "Wach: Muedigkeit,
-- Durst, Hunger" lief in der Liste in die Marke "halbautomatisch"). Ein
-- Zeichen ueber 127 am Schnitt faellt mit weg; im Testgeruest zaehlt
-- string.sub Bytes, und ein halbes Umlaut-Zeichen waere kaputtes UTF-8.
function SZ.kuerzen(font, text, breite)
    if textbreite(font, text) <= breite then return text end
    local n = #text
    while n > 0 do
        n = n - 1
        while n > 0 and string.byte(text, n) >= 128 do n = n - 1 end
        local kurz = (string.gsub(string.sub(text, 1, n), "[%s,:;]+$", "")) .. "..."
        if textbreite(font, kurz) <= breite then return kurz end
    end
    return "..."
end
TFMeasure.kuerzen = SZ.kuerzen

local function umbrechen(text, font, breite)
    local zeilen, zeile = {}, ""
    for _, wort in ipairs(teile(text, " ")) do
        local probe = (zeile == "") and wort or (zeile .. " " .. wort)
        if zeile ~= "" and textbreite(font, probe) > breite then
            zeilen[#zeilen + 1] = zeile
            zeile = wort
        else
            zeile = probe
        end
    end
    if zeile ~= "" then zeilen[#zeilen + 1] = zeile end
    return zeilen
end

local function schreibe(el, text, x, y, farbe, font)
    el:drawText(text, x, y, farbe[1], farbe[2], farbe[3], 1, font or UIFont.Small)
end

local function schreibeRechts(el, text, x, y, farbe, font)
    el:drawTextRight(text, x, y, farbe[1], farbe[2], farbe[3], 1, font or UIFont.Small)
end

--- Reihenfolge der Liste im Messfenster: Offen wie in TESTS, Erledigt die
-- zuletzt gelaufenen oben. Schluessel der Reihe nach: zeit (schreibt
-- erledigen seit 6.26.4 mit, Minuten seit 1.1.2026 UTC), das Datum, die
-- Fassung, mit der gemessen wurde (seit 6.23.4 im Stand; ein Test mit
-- juengerer Fassung lief spaeter), zuletzt die Reihenfolge in TESTS. In
-- 6.26.4 fehlte die Fassung: am 14.09.2026 standen alle Tests vom 13.09.
-- (das Datum rechnet os.date in UTC) in der Reihenfolge von TESTS, die Axt
-- oben, obwohl zuletzt die Code-Werte gelaufen waren.
function SZ.fassungZahl(fassung)
    local a, b, c = string.match(tostring(fassung or ""), "^(%d+)%.(%d+)%.?(%d*)")
    if not a then return -1 end
    return tonumber(a) * 1000000 + tonumber(b) * 1000 + (tonumber(c) or 0)
end

function SZ.standSchluessel(stand)
    local werte = stand.werte or {}
    local t, m, j = string.match(tostring(stand.datum or ""), "^(%d+)%.(%d+)%.(%d+)")
    local datum = t and (tonumber(j) * 10000 + tonumber(m) * 100 + tonumber(t)) or 0
    return tonumber(werte.zeit) or -1, datum, SZ.fassungZahl(werte.fassung)
end

function SZ.listenFolge(gruppe)
    local liste = {}
    for index, test in ipairs(TFMeasure.TESTS) do
        local stand = standVon(test)
        if (gruppe == "erledigt") == (stand ~= nil) then
            local e = { test = test, stand = stand, index = index, zeit = -1, datum = 0, fassung = -1 }
            if stand then e.zeit, e.datum, e.fassung = SZ.standSchluessel(stand) end
            liste[#liste + 1] = e
        end
    end
    if gruppe == "erledigt" then
        table.sort(liste, function(a, b)
            if a.zeit ~= b.zeit then return a.zeit > b.zeit end
            if a.datum ~= b.datum then return a.datum > b.datum end
            if a.fassung ~= b.fassung then return a.fassung > b.fassung end
            return a.index < b.index
        end)
    end
    return liste
end

local function kurzdatum(datum)
    if type(datum) == "string" and #datum >= 6 then return string.sub(datum, 1, 6) end
    return tostring(datum)
end

local function ersteOffene()
    for _, test in ipairs(TFMeasure.TESTS) do
        if not standVon(test) then return test.id end
    end
    return TFMeasure.TESTS[1] and TFMeasure.TESTS[1].id
end

--- Die Fensterklasse, einmal je geladenem Code. Erst beim ersten F8 gebaut:
-- dann steht ISCollapsableWindow sicher bereit.
local function fensterKlasse()
    if TFMeasure.Fenster then return TFMeasure.Fenster end
    if not ISCollapsableWindow then return nil end
    local F = ISCollapsableWindow:derive("TFMeasureFenster")

    function F:new(x, y, breite, hoehe)
        local o = ISCollapsableWindow.new(self, x, y, breite, hoehe)
        o.title = T("fenster_titel")
        o.resizable = false
        o.zeilen = {}
        return o
    end

    function F:createChildren()
        ISCollapsableWindow.createChildren(self)
        local fh = schrifthoehe(UIFont.Small)
        local knopfHoehe = math.max(26, fh + 8)
        self.startKnopf = ISButton:new(LISTE + 14, 0, 120, knopfHoehe, T("knopf_start"), self, F.onStart)
        self.startKnopf:initialise()
        self.startKnopf.borderColor = { r = 0.45, g = 0.72, b = 1.0, a = 1 }
        self:addChild(self.startKnopf)
        local stopTitel = T("knopf_abbrechen")
        self.stopKnopf = ISButton:new(LISTE + 142, 0, textbreite(UIFont.Small, stopTitel) + 24, knopfHoehe,
            stopTitel, self, F.onStop)
        self.stopKnopf:initialise()
        self:addChild(self.stopKnopf)
        local kettenTitel = T("knopf_kette")
        self.kettenKnopf = ISButton:new(LISTE + 270, 0, textbreite(UIFont.Small, kettenTitel) + 24, knopfHoehe,
            kettenTitel, self, F.onKette)
        self.kettenKnopf:initialise()
        self.kettenKnopf.tooltip = T("knopf_kette_tipp")
        self:addChild(self.kettenKnopf)
        self.cheatBoxen = {}
        local x = RAND + textbreite(UIFont.Small, T("fuss_testfigur")) + 12
        for _, cheat in ipairs(TFMeasure.CHEATS) do
            local box = ISTickBox:new(x, 0, 20, fh, "", self, F.onCheat, cheat.id)
            box:initialise()
            box:addOption(T("cheat_" .. cheat.id))
            box:setSelected(1, TFMeasure.cheatStand[cheat.id] == true)
            box:setWidthToFit()
            self:addChild(box)
            self.cheatBoxen[cheat.id] = box
            x = x + box:getWidth() + 14
        end
    end

    function F:onStart()
        if self.wahl then TFMeasure.starteTest(self.wahl) end
    end

    function F:onStop()
        TFMeasure.stoppeTest()
    end

    function F:onKette()
        TFMeasure.ketteStarten()
    end

    function F:onCheat(index, an, id)
        TFMeasure.cheatSetzen(id, an)
    end

    -- Ziehen nur an der Titelleiste; ein Klick in die Liste waehlt den Test,
    -- aber nur im sichtbaren Teil (die Liste scrollt).
    function F:onMouseDown(x, y)
        if y < self:titleBarHeight() then return ISCollapsableWindow.onMouseDown(self, x, y) end
        -- Der Balken (seit 6.26.4): ein Klick neben den Griff setzt ihn mittig
        -- an die Stelle, danach laesst er sich ziehen (onMouseMove).
        local b = self.listeBalken
        if b and x >= b.x - 2 and x < LISTE and y >= self.listeOben and y < self.listeUnten then
            if y < b.gy or y >= b.gy + b.griff then self:listeAufBalken(y - b.griff / 2) end
            self.listeZiehen = { maus = y, scroll = self.listeScroll }
            return true
        end
        if x < LISTE and y >= (self.listeOben or 0) and y < (self.listeUnten or self.height) then
            for _, zeile in ipairs(self.zeilen) do
                if y >= zeile.y0 and y < zeile.y1 then
                    self.wahl = zeile.id
                    return true
                end
            end
        end
        return true
    end

    --- Mausrad ueber der Liste: scrollen. Die Grenzen setzt zeichneListe.
    function F:onMouseWheel(del)
        local mx = self.getMouseX and self:getMouseX() or 0
        if mx >= LISTE then return false end
        self.listeScroll = (self.listeScroll or 0) + del * TFMeasure.LISTE_RAD
        return true
    end

    --- Scrollt so, dass der Griff oben bei griffY steht.
    function F:listeAufBalken(griffY)
        local b = self.listeBalken
        if not b then return end
        local sichtbar = self.listeUnten - self.listeOben
        local frei = sichtbar - b.griff
        if frei <= 0 then return end
        local anteil = math.max(0, math.min(1, (griffY - self.listeOben) / frei))
        self.listeScroll = anteil * (self.listeInhalt - sichtbar)
    end

    --- Ziehen am Griff; sonst bewegt ISCollapsableWindow das Fenster wie
    -- bisher. Losgelassen wird auch ausserhalb des Fensters.
    function F:onMouseMove(dx, dy)
        if self.listeZiehen then
            local b, zug = self.listeBalken, self.listeZiehen
            local my = self.getMouseY and self:getMouseY()
            if b and my then
                local sichtbar = self.listeUnten - self.listeOben
                local frei = sichtbar - b.griff
                if frei > 0 then
                    self.listeScroll = zug.scroll + (my - zug.maus) * (self.listeInhalt - sichtbar) / frei
                end
            end
            return true
        end
        if ISCollapsableWindow.onMouseMove then return ISCollapsableWindow.onMouseMove(self, dx, dy) end
    end
    function F:onMouseMoveOutside(dx, dy)
        if self.listeZiehen then return self:onMouseMove(dx, dy) end
        if ISCollapsableWindow.onMouseMoveOutside then
            return ISCollapsableWindow.onMouseMoveOutside(self, dx, dy)
        end
    end
    function F:onMouseUp(x, y)
        self.listeZiehen = nil
        if ISCollapsableWindow.onMouseUp then return ISCollapsableWindow.onMouseUp(self, x, y) end
    end
    function F:onMouseUpOutside(x, y)
        self.listeZiehen = nil
        if ISCollapsableWindow.onMouseUpOutside then return ISCollapsableWindow.onMouseUpOutside(self, x, y) end
    end

    --- Zeichnet die Liste zwischen oben und unten, um listeScroll nach oben
    -- versetzt und auf ihren Bereich beschnitten (setStencilRect wie
    -- ISScrollingListBox); rechts ein Balken, wenn sie nicht ganz passt.
    function F:zeichneListe(oben, unten)
        local fh = schrifthoehe(UIFont.Small)
        local laeuft = TFMeasure.lauf and TFMeasure.lauf.id
        local sichtbar = unten - oben
        local hoechstens = math.max(0, (self.listeInhalt or 0) - sichtbar)
        self.listeScroll = math.max(0, math.min(self.listeScroll or 0, hoechstens))
        self.listeOben, self.listeUnten = oben, unten
        local beschnitten = self.setStencilRect ~= nil and self.clearStencilRect ~= nil
        if beschnitten then self:setStencilRect(0, oben, LISTE, sichtbar) end
        local y = oben - self.listeScroll
        self.zeilen = {}
        for _, gruppe in ipairs({ "offen", "erledigt" }) do
            schreibe(self, T("gruppe_" .. gruppe), RAND, y, FARBE.thema)
            y = y + fh + 2
            self:drawRect(RAND, y, LISTE - 2 * RAND, 1, 0.35, 0.45, 0.72, 1.0)
            y = y + 4
            for _, eintrag in ipairs(SZ.listenFolge(gruppe)) do
                local test, stand = eintrag.test, eintrag.stand
                do
                    local hoehe = 2 * fh + 8
                    if test.id == self.wahl then
                        self:drawRect(0, y, LISTE, hoehe, 0.18, 0.45, 0.72, 1.0)
                        self:drawRect(0, y, 2, hoehe, 1, 0.45, 0.72, 1.0)
                    end
                    local marke, farbe
                    if laeuft == test.id then
                        marke, farbe = T("art_laeuft"), FARBE.weiss
                    elseif stand then
                        marke, farbe = kurzdatum(stand.datum), FARBE.gut
                    else
                        marke, farbe = T("art_" .. test.art), (test.art == "auto") and FARBE.thema or FARBE.warn
                    end
                    -- Der Name bekommt, was neben der Marke frei bleibt.
                    local platz = LISTE - 2 * RAND - textbreite(UIFont.Small, marke) - 8
                    schreibe(self, SZ.kuerzen(UIFont.Small, T(test.id .. "_name"), platz), RAND, y + 4, FARBE.weiss)
                    schreibeRechts(self, marke, LISTE - RAND, y + 4, farbe)
                    schreibe(self, SZ.kuerzen(UIFont.Small, T(test.id .. "_kurz"), LISTE - 2 * RAND), RAND,
                        y + 4 + fh, FARBE.leise)
                    self.zeilen[#self.zeilen + 1] = { id = test.id, y0 = y, y1 = y + hoehe }
                    y = y + hoehe
                end
            end
            y = y + 6
        end
        self.listeInhalt = y + self.listeScroll - oben
        -- Der Balken: eine Spur ueber die ganze Hoehe und darauf der Griff,
        -- BALKEN_BREITE Pixel am rechten Rand der Liste. Gezeichnet noch im
        -- Beschnitt, wie die Zeilen: 6.26.3 und 6.26.4 zeichneten ihn erst nach
        -- clearStencilRect, und im Spiel war er beide Male nicht zu sehen
        -- (14.09.2026), die Zeilen im Beschnitt dagegen schon.
        self.listeBalken = nil
        if self.listeInhalt > sichtbar then
            local breite = TFMeasure.BALKEN_BREITE
            local bx = LISTE - breite - 2
            local griff = math.max(24, sichtbar * sichtbar / self.listeInhalt)
            local gy = oben + (sichtbar - griff) * self.listeScroll / (self.listeInhalt - sichtbar)
            self:drawRect(bx, oben, breite, sichtbar, 0.8, 0.22, 0.24, 0.26)
            self:drawRect(bx, gy, breite, griff, 1.0, 0.70, 0.74, 0.78)
            self.listeBalken = { x = bx, gy = gy, griff = griff }
        end
        if beschnitten then self:clearStencilRect() end
        -- Einmal je neuer Groesse ins Log: laesst sich ein fehlender Balken
        -- nachvollziehen, ohne das Fenster zu sehen.
        local merk = math.floor(sichtbar) .. "/" .. math.floor(self.listeInhalt)
        if self.listeMerk ~= merk then
            self.listeMerk = merk
            log("Messfenster: Liste sichtbar/Inhalt " .. merk .. " Pixel, Balken "
                .. ((self.listeBalken ~= nil) and "ja" or "nein"))
        end
        return unten
    end

    function F:zeichneDetail(y)
        local test = testNamed(self.wahl)
        if not test then return y end
        local x = LISTE + 14
        local breite = self.width - x - 14
        local fh, fhm = schrifthoehe(UIFont.Small), schrifthoehe(UIFont.Medium)
        local lauf = TFMeasure.lauf
        local meiner = (lauf ~= nil and lauf.id == test.id)
        local stand = standVon(test)

        schreibe(self, T(test.id .. "_name"), x, y, FARBE.weiss, UIFont.Medium)
        y = y + fhm + 4
        for _, zeile in ipairs(umbrechen(T(test.id .. "_zweck"), UIFont.Small, breite)) do
            schreibe(self, zeile, x, y, FARBE.leise)
            y = y + fh
        end
        y = y + 8

        if #test.schritte > 0 then
            local y0 = y
            schreibe(self, T("kasten_schritte"), x + 8, y + 4, FARBE.thema)
            y = y + fh + 6
            local kasten = math.max(fh - 8, 8)
            for index, wer in ipairs(test.schritte) do
                local wer_text = T("wer_" .. wer)
                schreibeRechts(self, wer_text, x + breite - 8, y, FARBE.leise)
                self:drawRectBorder(x + 8, y + (fh - kasten) / 2, kasten, kasten, 0.6, 1, 1, 1)
                if meiner and (lauf.erledigt or 0) >= index then
                    self:drawRect(x + 10, y + (fh - kasten) / 2 + 2, kasten - 4, kasten - 4, 0.9,
                        FARBE.gut[1], FARBE.gut[2], FARBE.gut[3])
                end
                local platz = breite - kasten - 30 - textbreite(UIFont.Small, wer_text)
                for _, zeile in ipairs(umbrechen(T(test.id .. "_s" .. index), UIFont.Small, platz)) do
                    schreibe(self, zeile, x + 8 + kasten + 6, y, FARBE.text)
                    y = y + fh
                end
                y = y + 2
            end
            y = y + 4
            self:drawRectBorder(x, y0, breite, y - y0, 0.14, 1, 1, 1)
            y = y + 8
        end

        -- Eine Tabelle, wenn der Test eine hat (Neue Figur: "Bisher erfasst").
        -- Die letzte Spalte bricht um, statt ueber den Rand zu laufen.
        if test.tabelle then
            local ok, kopf, zeilen = pcall(test.tabelle)
            if ok and type(kopf) == "table" then
                local y0 = y
                local spalten = test.spalten or {}
                local function spalteX(index) return x + 8 + (spalten[index] or 0) end
                schreibe(self, T("kasten_erfasst"), x + 8, y + 4, FARBE.thema)
                y = y + fh + 6
                for index, text in ipairs(kopf) do schreibe(self, text, spalteX(index), y, FARBE.leise) end
                y = y + fh + 2
                for _, zeile in ipairs(zeilen or {}) do
                    local hoehe = 1
                    for index, text in ipairs(zeile) do
                        local ende = spalten[index + 1] and (spalteX(index + 1) - 6) or (x + breite - 8)
                        local stuecke = umbrechen(tostring(text), UIFont.Small, ende - spalteX(index))
                        for n, stueck in ipairs(stuecke) do
                            schreibe(self, stueck, spalteX(index), y + (n - 1) * fh,
                                (index == 1) and FARBE.text or FARBE.weiss)
                        end
                        if #stuecke > hoehe then hoehe = #stuecke end
                    end
                    y = y + hoehe * fh
                end
                y = y + 6
                self:drawRectBorder(x, y0, breite, y - y0, 0.14, 1, 1, 1)
                y = y + 8
            end
        end

        if self.startKnopf then
            local titel = stand and T("knopf_erneut") or T("knopf_start")
            self.startKnopf:setTitle(titel)
            self.startKnopf:setWidth(textbreite(UIFont.Small, titel) + 24)
            self.startKnopf:setX(x)
            self.startKnopf:setY(y)
            local frei = test.start ~= nil and lauf == nil and TFMeasure.startGewuenscht == nil
            if self.startKnopf.enable ~= frei then self.startKnopf:setEnable(frei) end
            self.stopKnopf:setX(x + self.startKnopf:getWidth() + 8)
            self.stopKnopf:setY(y)
            local stoppbar = (meiner and test.stop ~= nil) or TFMeasure.kette ~= nil
            if self.stopKnopf.enable ~= stoppbar then self.stopKnopf:setEnable(stoppbar) end
            if self.kettenKnopf then
                self.kettenKnopf:setX(self.stopKnopf:getX() + self.stopKnopf:getWidth() + 8)
                self.kettenKnopf:setY(y)
                local kettenFrei = lauf == nil and TFMeasure.startGewuenscht == nil and TFMeasure.kette == nil
                if self.kettenKnopf.enable ~= kettenFrei then self.kettenKnopf:setEnable(kettenFrei) end
            end
            y = y + self.startKnopf:getHeight() + 8
        end

        if meiner and lauf.live then
            local anzahl = #lauf.live
            local zelle = (breite - (anzahl - 1) * 6) / anzahl
            for index, eintrag in ipairs(lauf.live) do
                local zx = x + (index - 1) * (zelle + 6)
                self:drawRectBorder(zx, y, zelle, fhm + fh + 8, 0.12, 1, 1, 1)
                schreibe(self, eintrag[2], zx + 6, y + 3, FARBE.weiss, UIFont.Medium)
                schreibe(self, eintrag[1], zx + 6, y + 3 + fhm, FARBE.leise)
            end
            y = y + fhm + fh + 16
        end

        local anteil = 0
        if meiner then anteil = lauf.fortschritt or 0 elseif stand then anteil = 1 end
        self:drawRect(x, y, breite, 6, 0.1, 1, 1, 1)
        if anteil > 0 then
            self:drawRect(x, y, breite * math.min(anteil, 1), 6, 1, FARBE.thema[1], FARBE.thema[2], FARBE.thema[3])
        end
        y = y + 14

        local status
        if meiner then
            status = lauf.status or T("status_extern")
        elseif TFMeasure.meldung and (TFMeasure.meldung.id == test.id or TFMeasure.meldung.id == "kette") then
            -- Das Ergebnis des Patch-Tag-Laufs gehoert zu keinem einzelnen
            -- Test; es steht, bis der naechste Start die Meldung loescht.
            status = TFMeasure.meldung.text
        elseif lauf then
            status = T("status_anderer")
        elseif stand then
            status = T("status_erledigt", tostring(stand.datum or "?"))
        elseif test.wartet then
            local ok, text = pcall(test.wartet)
            status = (ok and type(text) == "string") and text or T("status_bereit")
        else
            status = T("status_bereit")
        end
        for _, zeile in ipairs(umbrechen(status, UIFont.Small, breite)) do
            schreibe(self, zeile, x, y, FARBE.text)
            y = y + fh
        end

        if stand and test.ergebnis and not meiner then
            local ok, satz = pcall(test.ergebnis, stand.werte or {})
            if ok and type(satz) == "string" then
                y = y + 2
                for _, zeile in ipairs(umbrechen(satz, UIFont.Small, breite)) do
                    schreibe(self, zeile, x, y, FARBE.gut)
                    y = y + fh
                end
            end
        end
        y = y + 4
        schreibe(self, T("bericht", test.datei), x, y, FARBE.leise)
        return y + fh
    end

    function F:zeichneFuss(y)
        local fh = schrifthoehe(UIFont.Small)
        self:drawRect(0, y, self.width, 1, 0.15, 1, 1, 1)
        y = y + 6
        schreibe(self, T("fuss_testfigur"), RAND, y, FARBE.thema)
        for _, cheat in ipairs(TFMeasure.CHEATS) do
            local box = self.cheatBoxen and self.cheatBoxen[cheat.id]
            if box then
                box:setY(y)
                box:setSelected(1, TFMeasure.cheatStand[cheat.id] == true)
            end
        end
        y = y + fh + 6
        if TFMeasure.cheatStand.god == false then schreibe(self, T("fuss_godaus"), RAND, y, FARBE.warn) end
        schreibeRechts(self, T("fuss_hinweis"), self.width - RAND, y, FARBE.leise)
        return y + fh + 8
    end

    -- Alles in prerender: der Hintergrund liegt dann schon, und die Knoepfe
    -- zeichnet das Spiel danach obendrauf.
    function F:prerender()
        ISCollapsableWindow.prerender(self)
        if not TFMeasure.stand then TFMeasure.statusLesen() end
        if not self.wahl then self.wahl = (TFMeasure.lauf and TFMeasure.lauf.id) or ersteOffene() end
        local th = self:titleBarHeight()
        schreibeRechts(self, T("fenster_fassung", TFMeasure.VERSION), self.width - th - 6, 1, FARBE.leise)
        -- Die Liste zuerst, wie bisher; ihre Hoehe richtet sich nach der
        -- rechten Seite aus dem vorigen Bild (ein Bild Verzug, unsichtbar).
        local listeUnten = math.max(self.detailUnten or 0, th + 4 + TFMeasure.LISTE_MIN)
        self:zeichneListe(th + 4, listeUnten)
        local rechts = self:zeichneDetail(th + 8)
        self.detailUnten = rechts
        local unten = math.max(rechts, listeUnten)
        self:drawRect(LISTE, th, 1, unten - th, 0.15, 1, 1, 1)
        local hoehe = self:zeichneFuss(unten + 10)
        if self.height ~= hoehe then self:setHeight(hoehe) end
    end

    TFMeasure.Fenster = F
    return F
end

--- Num 8 (ohne -debug auch F8): Fenster auf und zu. Beim ersten Mal wird
-- es gebaut.
function TFMeasure.fensterUmschalten()
    local fenster = TFMeasure.fenster
    if fenster then
        if fenster:isVisible() then
            fenster:setVisible(false)
        else
            fenster:setVisible(true)
            fenster:bringToTop()
        end
        return
    end
    local F = fensterKlasse()
    if not F then
        log("Messfenster: ISCollapsableWindow fehlt.")
        return
    end
    local breite, hoehe = 780, 560
    local sx, sy = 1280, 720
    pcall(function() sx, sy = getCore():getScreenWidth(), getCore():getScreenHeight() end)
    fenster = F:new(math.floor((sx - breite) / 2), math.floor((sy - hoehe) / 2), breite, hoehe)
    fenster:initialise()
    fenster:addToUIManager()
    fenster:setVisible(true)
    TFMeasure.fenster = fenster
end

--- Num 9 laedt neu, Num 8 oeffnet und schliesst das Messfenster (seit
-- 6.26.2; in 6.26.1 Pos1 und Einfg). Beides merkt sich nur den Wunsch;
-- ausgefuehrt wird im naechsten
-- Tick. Im Tastendurchlauf darf es nicht passieren: das Neuladen fasst
-- Zustand an, den derselbe Durchlauf gerade benutzt.
--
-- Bis 6.26.0 waren es F9 und F8. Mit -debug gehoeren beide dem Spiel
-- (IngameState.updateInternal, Offsets 616-745: F8 Weltkarten-, Sprite-
-- und Kachel-Editor, F9 Seam-Editor; F2 und F7 ebenso), und am 13.09.2026
-- ging statt des Messfensters der Weltkarten-Editor auf. F1 bis F6, F10
-- und F11 belegt keyBinding.lua, F12 Steam; den Nummernblock belegt
-- keins von beiden. Num 8 und Num 9 wie F8 und F9. Ohne -debug gelten F8
-- und F9 weiter.
function TFMeasure.taste(key)
    local ohneDebug = not (isDebugEnabled and isDebugEnabled())
    if key == Keyboard.KEY_NUMPAD9 or (ohneDebug and key == Keyboard.KEY_F9) then
        TFMeasure.reloadGewuenscht = true
    end
    -- Das Messfenster (seit 6.18.0; in 6.17.x lag hier der Kletterlauf, in
    -- 6.16.x die XP-Leiter, beide jetzt Tests im Fenster).
    if key == Keyboard.KEY_NUMPAD8 or (ohneDebug and key == Keyboard.KEY_F8) then
        TFMeasure.fensterGewuenscht = true
    end
end

--- Der eine Tick-Einstieg des Mess-Mods.
--
-- Alle Aufgaben haengen an dieser einen Huelle, statt sich einzeln bei OnTick
-- an- und abzumelden. Genau dieses An- und Abmelden zur Laufzeit hat am
-- 10.09.2026 das Spiel aufgehaengt: F9 loeschte den eigenen Handler aus der
-- Tastenliste und haengte ihn hinten wieder an, waehrend das Spiel gerade
-- ueber diese Liste lief - und traf ihn dabei erneut, endlos. Ob eine Aufgabe
-- laeuft, sagt jetzt ihr Zustand, nicht ihre Anwesenheit in einer Liste.
function TFMeasure.rahmenTick()
    if TFMeasure.reloadGewuenscht then
        TFMeasure.reloadGewuenscht = false
        pcall(TFMeasure.neuLaden)
        return
    end
    if TFMeasure.xpGewuenscht then
        TFMeasure.xpGewuenscht = false
        local ok, err = pcall(TFMeasure.xpLeiter)
        if not ok then log("XP-Leiter fehlgeschlagen: " .. tostring(err)) end
        return
    end
    if TFMeasure.fensterGewuenscht then
        TFMeasure.fensterGewuenscht = false
        local ok, err = pcall(TFMeasure.fensterUmschalten)
        if not ok then log("Messfenster: " .. tostring(err)) end
        return
    end
    if TFMeasure.kette and not TFMeasure.lauf and not TFMeasure.startGewuenscht then
        local ok, err = pcall(TFMeasure.ketteTick)
        if not ok then
            log("Patch-Tag-Lauf abgebrochen: " .. tostring(err))
            TFMeasure.kette = nil
        end
    end
    if TFMeasure.startGewuenscht then
        local id = TFMeasure.startGewuenscht
        TFMeasure.startGewuenscht = nil
        testStarten(id)
        return
    end
    TFMeasure.haloTakt = (TFMeasure.haloTakt or 0) + 1
    if TFMeasure.haloTakt >= TFMeasure.HALO.pruefeAlle then
        TFMeasure.haloTakt = 0
        pcall(haloAuffrischen, getSpecificPlayer(0))
    end
    if sprint then pcall(TFMeasure.sprintTick) end
    if car then pcall(TFMeasure.carTick) end
    if accel then pcall(TFMeasure.accelTick) end
    if TFMeasure.axtZustand then
        local ok, err = pcall(TFMeasure.axtTick)
        if not ok then
            log("Axt-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.axtAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.adrenalinZustand then
        local ok, err = pcall(TFMeasure.adrenalinTick)
        if not ok then
            log("Adrenalin-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.adrenalinAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    pcall(figurTick)
    if TFMeasure.panikZustand then
        local ok, err = pcall(TFMeasure.panikTick)
        if not ok then
            log("Panik-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.panikAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.blutZustand then
        local ok, err = pcall(TFMeasure.blutTick)
        if not ok then
            log("Blut-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.blutAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.werteZustand then
        local ok, err = pcall(TFMeasure.werteTick)
        if not ok then
            log("Code-Werte abgebrochen: " .. tostring(err))
            pcall(TFMeasure.werteAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.wachZustand then
        local ok, err = pcall(TFMeasure.wachTick)
        if not ok then
            log("Wach-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.wachAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.schlafZustand then
        local ok, err = pcall(TFMeasure.schlafTick)
        if not ok then
            log("Schlaf-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.schlafAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.laufenZustand then
        local ok, err = pcall(TFMeasure.laufenTick)
        if not ok then
            log("Lauf-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.laufenAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.einblendenZustand then
        local ok, err = pcall(TFMeasure.einblendenTick)
        if not ok then
            log("Einblende-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.einblendenAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    if TFMeasure.imautoZustand then
        local ok, err = pcall(TFMeasure.imautoTick)
        if not ok then
            log("Im-Auto-Test abgebrochen: " .. tostring(err))
            pcall(TFMeasure.imautoAbbrechen, T("status_fehler", tostring(err)))
        end
    end
    pcall(laufPruefen)
    pcall(TFMeasure.ausdauerTick)
    pcall(TFMeasure.godTick)
end

--- Schaltet die Tests scharf, die noch etwas zu messen haben.
--
-- Eine Stelle fuer alle Wege hierher: Weltbetreten und Neuladen mit F9. Vorher
-- stand die Liste zweimal da, und die Umstellung von 6.1.0 traf nur die eine -
-- F9 schaltete weiter Sprint- und Vollgas-Test scharf und das Anfahren gar
-- nicht. Wer danach ins Auto stieg, bekam die Meldungen des falschen Tests.
--
-- Fertige Tests springen nicht von selbst an; sie wuerden nur stoeren, weil
-- der Sprinttest zugreift, sobald man zum Auto rennt, und der Plateau-Test
-- durchgehend Vollgas will. Von Hand aus einer Lua-Konsole:
--
--   TFMeasure.armSprint()   Sprinttempo, erledigt am 10.09.2026 (3 Laeufe)
--   TFMeasure.armCar()      Hoechstgeschwindigkeit, erledigt (5 Wagen)
--   TFMeasure.armAccel()    Motorkraft, erledigt am 11.09.2026 (SportsCar,
--                           PickUpVan)
--
-- Seit 6.15.1 ist kein Test mehr offen, die Liste ist also leer. Nach dem
-- Lauf am PickUpVan hing sonst jeder F9 den fertigen Beschleunigungstest neu
-- ein, und ueber dem Kopf stand endlos "in ein Auto setzen". Die Funktion
-- bleibt als die eine Stelle, an die ein neuer offener Test gehoert.
TFMeasure.OFFEN = {}
function TFMeasure.scharfschalten(player)
    player = player or getSpecificPlayer(0)
    for _, name in ipairs(TFMeasure.OFFEN) do
        local arm = TFMeasure[name]
        if arm then
            local ok, err = pcall(arm, player)
            if not ok then log(name .. " nicht gestartet: " .. tostring(err)) end
        end
    end
end

-- Einmal beim Betreten der Welt. Danach jederzeit von Hand wiederholbar,
-- wenn eine Lua-Konsole zur Hand ist: TFMeasure.run()
function TFMeasure.starten()
    log("Fassung " .. TFMeasure.VERSION .. ", Messung laeuft.")
    if isDebugEnabled then log("Debug-Modus: " .. (isDebugEnabled() and "an" or "aus")) end
    -- Ein Fenster aus einer vorigen Welt haengt nicht mehr im UI-Manager.
    if TFMeasure.fenster then
        pcall(function() TFMeasure.fenster:removeFromUIManager() end)
        TFMeasure.fenster = nil
    end
    pcall(TFMeasure.statusLesen)
    local ok, err = pcall(TFMeasure.run)
    if not ok then log("Messung fehlgeschlagen: " .. tostring(err)) end
    pcall(TFMeasure.ungestoert)
    local ok2, err2 = pcall(TFMeasure.scharfschalten)
    if not ok2 then log("Tests nicht scharfgeschaltet: " .. tostring(err2)) end
end

-- Genau einmal, und nie wieder. Die Huellen schlagen ueber die Tabelle nach,
-- ein Neuladen findet sie also unveraendert vor und sie zeigen trotzdem auf
-- den neuen Code. Kein Add und kein Remove zur Laufzeit, damit nichts eine
-- Liste anfasst, ueber die das Spiel gerade laeuft.
if not TFMeasure.angemeldet then
    TFMeasure.angemeldet = true
    Events.OnGameStart.Add(function() TFMeasure.starten() end)
    Events.OnKeyPressed.Add(function(key) TFMeasure.taste(key) end)
    Events.OnTick.Add(function() TFMeasure.rahmenTick() end)
end
-- Die Schlag-Ereignisse fuer den Axt-Test (seit 6.18.0). Ein eigener Merker:
-- ein Spiel, das eine aeltere Fassung geladen hat, hat `angemeldet` schon
-- gesetzt und liefe nach F9 sonst ohne sie.
if not TFMeasure.schlagAngemeldet and Events.OnWeaponSwing and Events.OnPlayerAttackFinished then
    TFMeasure.schlagAngemeldet = true
    Events.OnWeaponSwing.Add(function(wer, waffe) TFMeasure.schlagBeginn(wer, waffe) end)
    Events.OnPlayerAttackFinished.Add(function(wer, waffe) TFMeasure.schlagEnde(wer, waffe) end)
end

-- Neue Figuren (seit 6.22.0): OnNewGame feuert nur fuer eine frisch
-- erschaffene Figur (IsoWorld:2233). Eigener Merker wie bei den Schlaegen.
if not TFMeasure.figurAngemeldet and Events.OnNewGame then
    TFMeasure.figurAngemeldet = true
    Events.OnNewGame.Add(function(player, square) TFMeasure.neueFigur(player) end)
end

-- Sturzschaden (seit 6.26.0): handleLandingImpact meldet ihn nur ueber
-- OnPlayerGetDamage (IsoGameCharacter Z. 2117). Eigener Merker wie bei den
-- Schlaegen, die Huelle schlaegt ueber die Tabelle nach; F9 haengt nichts
-- doppelt ein.
if not TFMeasure.sturzAngemeldet and Events.OnPlayerGetDamage then
    TFMeasure.sturzAngemeldet = true
    Events.OnPlayerGetDamage.Add(function(wer, art, menge) TFMeasure.sturzHoeren(wer, art, menge) end)
end

-- Ein Test, der beim Neuladen lief, verliert hier seinen Code: sauber
-- beenden (Baum, Trait, Stufe, God Mode zurueck), statt ihn halb weiterlaufen
-- zu lassen.
if TFMeasure.axtZustand then pcall(TFMeasure.axtAbbrechen, T("axt_abgebrochen")) end
if TFMeasure.adrenalinZustand then pcall(TFMeasure.adrenalinAbbrechen, T("adrenalin_abgebrochen")) end
if TFMeasure.panikZustand then pcall(TFMeasure.panikAbbrechen, T("panik_abgebrochen")) end
if TFMeasure.blutZustand then pcall(TFMeasure.blutAbbrechen, T("blut_abgebrochen")) end
if TFMeasure.werteZustand then pcall(TFMeasure.werteAbbrechen, T("werte_abgebrochen")) end
if TFMeasure.wachZustand then pcall(TFMeasure.wachAbbrechen, T("wach_abgebrochen")) end
if TFMeasure.schlafZustand then pcall(TFMeasure.schlafAbbrechen, T("schlaf_abgebrochen")) end
if TFMeasure.laufenZustand then pcall(TFMeasure.laufenAbbrechen, T("laufen_abgebrochen")) end
if TFMeasure.einblendenZustand then pcall(TFMeasure.einblendenAbbrechen, T("einblenden_abgebrochen")) end
if TFMeasure.imautoZustand then pcall(TFMeasure.imautoAbbrechen, T("imauto_abgebrochen")) end
TFMeasure.lauf = nil
TFMeasure.startGewuenscht = nil
TFMeasure.kette = nil
if TFMeasure.fensterWarOffen then
    TFMeasure.fensterWarOffen = nil
    TFMeasure.fensterGewuenscht = true
end

-- Die Texte frisch aus der eigenen UI.json, bei jedem Laden und damit bei
-- jedem F9 (seit 6.23.4).
TFMeasure.texteAnzahl = TFMeasure.texteLaden()
log("Texte: " .. tostring(TFMeasure.texteAnzahl) .. " aus der UI.json"
    .. ((TFMeasure.texteAnzahl == 0) and ", es bleibt bei getText" or ""))
if isDebugEnabled then log("Debug-Modus: " .. (isDebugEnabled() and "an" or "aus")) end
log("Mess-Mod " .. TFMeasure.VERSION .. " bereit. Num 9 laedt neu, Num 8 oeffnet das Messfenster"
    .. " (ohne -debug auch F9 und F8).")
