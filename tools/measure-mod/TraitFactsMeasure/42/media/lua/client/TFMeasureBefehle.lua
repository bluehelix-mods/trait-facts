--- Mess-Befehle (seit 6.44.0, 24.09.2026): Konsolenzeilen aus einer Datei.
--
-- Die Messliste vom 23.09.2026 (docs/berichte/2026-09-23-messliste.md) hat
-- viele Punkte "Konsole": eine Zeile in der Lua-Konsole tippen und die Zahl
-- abschreiben. Hier schreibt man die Zeile stattdessen in eine Datei, und die
-- Antwort steht danach in einer zweiten Datei, zum Einlesen am Rechner:
--
--     Zomboid/Lua/TraitFacts_befehle.txt    je Zeile "<id> <befehl> [argumente]"
--     Zomboid/Lua/TraitFacts_antworten.txt  je Zeile "<id> ok <wert>" oder
--                                           "<id> fehler <grund>"
--
-- SICHERHEIT: die Datei fuehrt keinen Code aus. Sie waehlt nur einen Eintrag
-- aus der festen Tabelle B.BEFEHLE unten. Kein loadstring, kein load, kein
-- dofile, kein require, und kein Global und keine Funktion wird ueber einen
-- Namen aus der Datei gesucht. Argumente sind geprueft: Trait-Schluessel
-- (Muster, dann ueber die Trait-Registry aufgeloest), Gegenstandstyp (Muster,
-- dann im ScriptManager vorhanden), Skill und Stat nur aus festen Listen,
-- Zahlen ueber tonumber in einem Bereich. Alles andere wird mit "fehler"
-- beantwortet.
--
-- Aktiv nur im Debug-Modus (Spiel mit -debug gestartet); ohne ihn liest das
-- Mod die Datei gar nicht erst.
--
-- Jede id laeuft einmal: gemerkt im Speicher, und ids, die schon in der
-- Antwortdatei stehen, werden uebersprungen (auch nach einem Neustart).
--
-- Ereignis: OnTickEvenPaused, wenn es das gibt. In 42.20.4 feuert es
-- IngameState.updateInternal und, bei angehaltenem Spiel, GameWindow.logic
-- (Bytecode geprueft am 24.09.2026); die Befehle laufen also auch in der
-- Pause. Sonst OnTick.

TFMeasureBefehle = TFMeasureBefehle or {}
local B = TFMeasureBefehle

B.DATEI = "TraitFacts_befehle.txt"
B.ANTWORTEN = "TraitFacts_antworten.txt"
--- So viele Ticks zwischen zwei Blicken in die Datei (etwa eine Sekunde).
B.ALLE = 60
--- Hoechstens so viele neue Befehle je Blick; der Rest kommt beim naechsten.
B.JE_BLICK = 20
--- Laengere Zeilen und mehr Zeilen werden nicht gelesen.
B.ZEILE_MAX = 200
B.ZEILEN_MAX = 500

local function log(text)
    if TFMeasure and TFMeasure.melde then return TFMeasure.melde("[TraitFactsMeasure]", text) end
    print("[TraitFactsMeasure] " .. tostring(text))
end

-- ---------------------------------------------------------------- Pruefen

--- Debug-Modus an? Nur die zwei festen Engine-Funktionen.
function B.debugAn()
    local an = false
    pcall(function()
        if isDebugEnabled and isDebugEnabled() then an = true end
    end)
    if not an then
        pcall(function()
            if getDebug and getDebug() then an = true end
        end)
    end
    return an
end

--- Skills, die perk und perk_set annehmen. Nur diese Namen erreichen Perks.
B.PERKS = {
    "Aiming", "Axe", "Blacksmith", "Blunt", "Butchering", "Carving", "Cooking",
    "Doctor", "Electricity", "Farming", "Fishing", "Fitness", "FlintKnapping",
    "Glassmaking", "Husbandry", "Lightfoot", "LongBlade", "Maintenance",
    "Masonry", "Mechanics", "MetalWelding", "Nimble", "PlantScavenging",
    "Pottery", "Reloading", "SmallBlade", "SmallBlunt", "Sneak", "Spear",
    "Sprinting", "Strength", "Tailoring", "Tracking", "Trapping", "Woodwork",
}

--- Stats, die stat annimmt. Nur diese Namen erreichen CharacterStat.
B.STATS = { "HUNGER", "THIRST", "FATIGUE", "STRESS", "PANIC", "UNHAPPINESS",
            "ENDURANCE", "POISON" }

B.MT_WAHL = { "terminator", "leadfoot" }

--- Der Eintrag aus einer festen Liste, der genau gleich ist; sonst nil.
-- Zurueck kommt der Eintrag der Liste, nicht die Eingabe.
local function ausListe(liste, wert)
    for _, eintrag in ipairs(liste) do
        if eintrag == wert then return eintrag end
    end
    return nil
end

--- Trait-Typ zu einem Schluessel ("strong", "base:strong", "toadtraits:leadfoot").
-- Aufgeloest ueber TFMeasure.traitTypeNamed (Registry-Pfad); mit Namensraum
-- muss die volle ID (tostring des Typs) dazu passen.
function B.traitAufloesen(roh)
    if type(roh) ~= "string" or #roh > 64 or not string.find(roh, "^[%w_:]+$") then
        return nil, "ungueltiger Trait-Schluessel"
    end
    if not (TFMeasure and TFMeasure.traitTypeNamed) then
        return nil, "Trait-Registry des Mess-Mods fehlt"
    end
    local klein = string.lower(roh)
    local ns, pfad = string.match(klein, "^([%w_]+):([%w_]+)$")
    if string.find(klein, ":", 1, true) and not ns then
        return nil, "ungueltiger Trait-Schluessel"
    end
    local schluessel = string.gsub(pfad or klein, "[^%a%d]", "")
    local typ = TFMeasure.traitTypeNamed(schluessel)
    if not typ then return nil, "unbekannter Trait " .. klein end
    if ns then
        local voll = nil
        pcall(function() voll = string.lower(tostring(typ)) end)
        if voll ~= klein then return nil, "unbekannter Trait " .. klein end
    end
    return typ
end

--- Gegenstandstyp "Modul.Typ", der im ScriptManager steht.
function B.gegenstandPruefen(roh)
    if type(roh) ~= "string" or #roh > 80 or not string.find(roh, "^[%w_]+%.[%w_]+$") then
        return nil, "ungueltiger Gegenstandstyp"
    end
    local gefunden = nil
    pcall(function() gefunden = getScriptManager():getItem(roh) end)
    if not gefunden then
        pcall(function() gefunden = ScriptManager.instance:FindItem(roh) end)
    end
    if not gefunden then return nil, "unbekannter Gegenstand " .. roh end
    return roh
end

--- Pruefer je Argumentart. Jeder gibt den geprueften Wert oder nil, grund.
B.ARTEN = {
    trait = B.traitAufloesen,
    gegenstand = B.gegenstandPruefen,
    perk = function(roh)
        local name = ausListe(B.PERKS, roh)
        if not name then return nil, "unbekannter Skill" end
        local perk = nil
        pcall(function() perk = Perks[name] end)
        if not perk then return nil, "Skill " .. name .. " fehlt im Spiel" end
        return perk
    end,
    stufe = function(roh)
        -- Erst das Muster: tonumber naehme auch "0x5" und "1e1".
        local zahl = string.find(roh, "^%d%d?$") and tonumber(roh) or nil
        if not zahl or zahl > 10 then
            return nil, "Stufe muss eine ganze Zahl von 0 bis 10 sein"
        end
        return zahl
    end,
    stat = function(roh)
        local name = ausListe(B.STATS, roh)
        if not name then return nil, "unbekannter Stat" end
        return name
    end,
    mt = function(roh)
        local name = ausListe(B.MT_WAHL, roh)
        if not name then return nil, "nur terminator oder leadfoot" end
        return name
    end,
}

-- ---------------------------------------------------------------- Lesen

local function zahl(wert)
    if wert == nil then return "-" end
    return tostring(wert)
end

local function methode(objekt, name)
    local fn = nil
    pcall(function() fn = objekt[name] end)
    return fn
end

local function stompText(player)
    local schuhe = player:getClothingItem_Feet()
    if not schuhe then return nil, "keine Schuhe an den Fuessen" end
    local md = schuhe:getModData()
    return "stomp=" .. zahl(schuhe:getStompPower()) .. " stompState=" .. zahl(md and md.stompState)
        .. " schuhe=" .. zahl(schuhe:getFullType())
end

local function jamText(player)
    local item = player:getPrimaryHandItem()
    if not item then return nil, "nichts in der Haupthand" end
    if not methode(item, "getJamGunChance") then return nil, "keine Schusswaffe in der Haupthand" end
    local md = item:getModData()
    return "jam=" .. zahl(item:getJamGunChance()) .. " MTstate=" .. zahl(md and md.MTstate)
        .. " waffe=" .. zahl(item:getFullType())
end

local function traitsText(player)
    local liste = player:getCharacterTraits():getKnownTraits()
    local namen = {}
    for index = 0, liste:size() - 1 do
        local typ = liste:get(index)
        local name = nil
        pcall(function() name = string.lower(tostring(typ)) end)
        if not (name and string.find(name, "^[%w_%.%-]+:[%w_%.%-]+$")) then
            name = TFMeasure and TFMeasure.keyOf and TFMeasure.keyOf(typ) or tostring(typ)
        end
        namen[#namen + 1] = name
    end
    table.sort(namen)
    if #namen == 0 then return "anzahl=0" end
    return "anzahl=" .. tostring(#namen) .. " " .. table.concat(namen, ",")
end

local function hatTrait(player, typ)
    local hat = false
    pcall(function() hat = player:getCharacterTraits():get(typ) == true end)
    return hat
end

-- ---------------------------------------------------------------- Befehle

--- Die feste Liste. Jeder Eintrag: args (Argumentarten, genau so viele),
-- ohneFigur (laeuft ohne Figur), run(player, a) -> text oder nil, grund.
B.BEFEHLE = {
    version = { args = {}, ohneFigur = true, run = function()
        local spiel = nil
        pcall(function() spiel = getCore():getVersion() end)
        local tf = TraitFacts and TraitFacts.VERSION
        return "messmod=" .. zahl(TFMeasure and TFMeasure.VERSION)
            .. " bildschirmlauf=" .. zahl(TFMeasureScreen and TFMeasureScreen.VERSION)
            .. " traitfacts=" .. zahl(tf) .. " spiel=" .. zahl(spiel)
            .. " debug=" .. (B.debugAn() and "1" or "0")
            .. " moretraits=" .. ((MT and MT.Combat) and "1" or "0")
    end },

    traits = { args = {}, run = function(p) return traitsText(p) end },

    trait_add = { args = { "trait" }, run = function(p, a)
        p:getCharacterTraits():add(a[1])
        return "trait=" .. zahl(tostring(a[1])) .. " hat=" .. (hatTrait(p, a[1]) and "1" or "0")
    end },

    trait_remove = { args = { "trait" }, run = function(p, a)
        p:getCharacterTraits():remove(a[1])
        return "trait=" .. zahl(tostring(a[1])) .. " hat=" .. (hatTrait(p, a[1]) and "1" or "0")
    end },

    perk = { args = { "perk" }, run = function(p, a)
        return "stufe=" .. zahl(p:getPerkLevel(a[1]))
    end },

    perk_set = { args = { "perk", "stufe" }, run = function(p, a)
        if not (TFMeasure and TFMeasure.stufeSetzen) then return nil, "stufeSetzen fehlt" end
        TFMeasure.stufeSetzen(p, a[1], a[2])
        return "stufe=" .. zahl(p:getPerkLevel(a[1]))
    end },

    maxweight = { args = {}, run = function(p)
        local delta = nil
        pcall(function() delta = p:getMaxWeightDelta() end)
        return "maxweight=" .. zahl(p:getMaxWeight()) .. " delta=" .. zahl(delta)
    end },

    stomp = { args = {}, run = function(p) return stompText(p) end },

    jam = { args = {}, run = function(p) return jamText(p) end },

    darkness = { args = {}, run = function(p)
        if not (forageSystem and forageSystem.getDarknessEffectReduction) then
            return nil, "forageSystem.getDarknessEffectReduction fehlt"
        end
        return "reduktion=" .. zahl(forageSystem.getDarknessEffectReduction(p))
    end },

    recipes = { args = {}, run = function(p)
        return "rezepte=" .. zahl(p:getKnownRecipes():size())
    end },

    spawn = { args = { "gegenstand" }, run = function(p, a)
        local item = p:getInventory():AddItem(a[1])
        if not item then return nil, "AddItem gab nichts zurueck" end
        return "gegeben=" .. zahl(item:getFullType())
    end },

    equip = { args = { "gegenstand" }, run = function(p, a)
        -- Nur das Hauptinventar: ein Gegenstand in einer Tasche gehoert erst
        -- umgelagert, bevor er in die Hand kommt. spawn legt ihn dorthin.
        local item = p:getInventory():getFirstType(a[1])
        if not item then return nil, a[1] .. " nicht im Hauptinventar" end
        p:setPrimaryHandItem(item)
        local beide = false
        pcall(function() beide = item:isTwoHandWeapon() == true end)
        if beide then p:setSecondaryHandItem(item) end
        return "haupthand=" .. zahl(item:getFullType()) .. " beidhaendig=" .. (beide and "1" or "0")
    end },

    crit = { args = {}, run = function(p)
        if not methode(p, "calculateCritChance") then return nil, "calculateCritChance fehlt" end
        local liste = getCell():getZombieList()
        local naechster, abstand = nil, nil
        for index = 0, liste:size() - 1 do
            local z = liste:get(index)
            local dx, dy = z:getX() - p:getX(), z:getY() - p:getY()
            local d = math.sqrt(dx * dx + dy * dy)
            if not abstand or d < abstand then naechster, abstand = z, d end
        end
        if not naechster then return nil, "kein Zombie in der Zelle" end
        local waffe = p:getPrimaryHandItem()
        return "chance=" .. zahl(p:calculateCritChance(naechster))
            .. " abstand=" .. string.format("%.2f", abstand)
            .. " waffe=" .. zahl(waffe and waffe:getFullType())
    end },

    stat = { args = { "stat" }, run = function(p, a)
        local wert = nil
        for _, name in ipairs(B.STATS) do
            if name == a[1] then wert = p:getStats():get(CharacterStat[name]) end
        end
        return a[1] .. "=" .. zahl(wert)
    end },

    gametime = { args = {}, ohneFigur = true, run = function()
        local gt = getGameTime()
        local stunden = gt:getWorldAgeHours()
        return "tage=" .. zahl(math.floor(stunden / 24)) .. " stunde=" .. zahl(gt:getHour())
            .. " minute=" .. zahl(gt:getMinutes()) .. " weltstunden=" .. zahl(stunden)
            .. " datum=" .. zahl(gt:getDay() + 1) .. "." .. zahl(gt:getMonth() + 1) .. "." .. zahl(gt:getYear())
    end },

    -- Feste Verweise auf die Funktionen von More Traits Definitive
    -- (MT_Combat.lua:376 und :770, MT_World.lua:235 und :328, je (player)).
    -- Die Funktion setzt nur, solange der Merker in der modData nicht schon
    -- "Terminator" beziehungsweise "LeadFoot" sagt; die Antwort zeigt ihn mit.
    mt_apply = { args = { "mt" }, run = function(p, a)
        if not MT then return nil, "More Traits nicht geladen" end
        if a[1] == "terminator" then
            local fn = MT.Combat and MT.Combat.TerminatorGun
            if type(fn) ~= "function" then return nil, "MT.Combat.TerminatorGun fehlt" end
            fn(p)
            return jamText(p)
        end
        local fn = MT.World and MT.World.LeadFoot
        if type(fn) ~= "function" then return nil, "MT.World.LeadFoot fehlt" end
        fn(p)
        return stompText(p)
    end },
}

-- ---------------------------------------------------------------- Ablauf

--- Eine Antwort ohne Zeilenumbruch.
local function einzeilig(text)
    return (string.gsub(tostring(text), "[\r\n]+", " "))
end

--- Zerlegt an Leerraum (string.gmatch fehlt in Kahlua).
local function woerter(zeile)
    local out, pos = {}, 1
    while true do
        local von, bis, wort = string.find(zeile, "(%S+)", pos)
        if not von then return out end
        out[#out + 1] = wort
        pos = bis + 1
    end
end

--- Fuehrt eine zerlegte Zeile aus. Gibt "ok", wert oder "fehler", grund.
function B.ausfuehren(teile)
    local name = teile[2]
    local befehl = nil
    -- Nur ein Treffer in der festen Tabelle zaehlt; pairs statt B.BEFEHLE[name],
    -- damit nichts ueber Metatabellen oder geerbte Felder hineinkommt.
    for eintrag, def in pairs(B.BEFEHLE) do
        if eintrag == name then befehl = def end
    end
    if not befehl then return "fehler", "unbekannter Befehl" end
    local anzahl = #teile - 2
    if anzahl ~= #befehl.args then
        return "fehler", "erwartet " .. tostring(#befehl.args) .. " Argument(e), nicht " .. tostring(anzahl)
    end
    local args = {}
    for index, art in ipairs(befehl.args) do
        local wert, grund = B.ARTEN[art](teile[index + 2])
        if wert == nil then return "fehler", grund or "ungueltiges Argument" end
        args[index] = wert
    end
    local player = getSpecificPlayer and getSpecificPlayer(0) or nil
    if not player and not befehl.ohneFigur then return "fehler", "keine Figur in der Welt" end
    local ok, wert, grund = pcall(befehl.run, player, args)
    if not ok then return "fehler", "Laufzeitfehler: " .. tostring(wert) end
    if wert == nil then return "fehler", grund or "kein Wert" end
    return "ok", wert
end

--- Liest eine Datei aus Zomboid/Lua als Liste von Zeilen (leer, wenn sie fehlt).
local function zeilenLesen(datei)
    local zeilen = {}
    pcall(function()
        local reader = getFileReader(datei, false)
        if not reader then return end
        while #zeilen < B.ZEILEN_MAX do
            local zeile = reader:readLine()
            if zeile == nil then break end
            zeilen[#zeilen + 1] = zeile
        end
        reader:close()
    end)
    return zeilen
end

local function antworten(liste)
    if #liste == 0 then return end
    local ok, err = pcall(function()
        local writer = getFileWriter(B.ANTWORTEN, true, true)
        for _, zeile in ipairs(liste) do writer:write(zeile .. "\r\n") end
        writer:close()
    end)
    if not ok then log("Mess-Befehle: Antwort nicht geschrieben: " .. tostring(err)) end
end

--- ids, die schon eine Antwort haben: einmal je Laden aus der Datei.
local function erledigtLaden()
    local erledigt = {}
    for _, zeile in ipairs(zeilenLesen(B.ANTWORTEN)) do
        local id = string.match(zeile, "^%s*(%S+)")
        if id then erledigt[id] = true end
    end
    return erledigt
end

--- Ein Blick in die Befehlsdatei.
function B.blick()
    if not B.erledigt then B.erledigt = erledigtLaden() end
    local neu, antwortZeilen = 0, {}
    for nummer, roh in ipairs(zeilenLesen(B.DATEI)) do
        if neu >= B.JE_BLICK then break end
        local zeile = string.gsub(roh, "^%s+", "")
        if zeile ~= "" and string.sub(zeile, 1, 1) ~= "#" then
            local teile = woerter(zeile)
            local id = teile[1]
            if #zeile > B.ZEILE_MAX or not string.find(id, "^[%w_%-%.]+$") or #id > 40 then
                -- Ohne gueltige id keine Antwort unter ihr; einmal je Zeile melden.
                local merker = "zeile:" .. tostring(nummer) .. ":" .. zeile
                if not B.erledigt[merker] then
                    B.erledigt[merker] = true
                    neu = neu + 1
                    antwortZeilen[#antwortZeilen + 1] = "- fehler Zeile " .. tostring(nummer)
                        .. ": ungueltige id oder Zeile zu lang"
                end
            elseif not B.erledigt[id] then
                B.erledigt[id] = true
                neu = neu + 1
                local stand, wert = B.ausfuehren(teile)
                antwortZeilen[#antwortZeilen + 1] = id .. " " .. stand .. " " .. einzeilig(wert)
                log("Mess-Befehl " .. id .. " " .. tostring(teile[2]) .. ": " .. stand)
            end
        end
    end
    antworten(antwortZeilen)
end

local zaehler = 0
local gemeldet = false

--- Der Tick. Kein Fehler kommt hier heraus.
function B.tick()
    pcall(function()
        zaehler = zaehler + 1
        if zaehler < B.ALLE then return end
        zaehler = 0
        if not TFMeasure then return end
        if not B.debugAn() then return end
        if not gemeldet then
            gemeldet = true
            log("Mess-Befehle aktiv: Zomboid/Lua/" .. B.DATEI)
        end
        B.blick()
    end)
end

-- Genau einmal anmelden; die Huelle schlaegt ueber die Tabelle nach, ein
-- Neuladen (Num 9) findet sie also vor und laeuft trotzdem mit neuem Code.
if Events and not B.angemeldet then
    if Events.OnTickEvenPaused and Events.OnTickEvenPaused.Add then
        B.angemeldet = "OnTickEvenPaused"
        Events.OnTickEvenPaused.Add(function() TFMeasureBefehle.tick() end)
    elseif Events.OnTick and Events.OnTick.Add then
        B.angemeldet = "OnTick"
        Events.OnTick.Add(function() TFMeasureBefehle.tick() end)
    end
end
