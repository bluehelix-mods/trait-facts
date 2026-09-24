--- Nachstellen (seit 6.41.0, 21.09.2026): Spielfehler mit eigenen Augen pruefen.
--
-- Die Tests im Messfenster rufen oft die Funktion des Spiels direkt auf. Das
-- beweist, was die Funktion rechnet, aber nicht, was ein Spieler erlebt. Am
-- 21.09.2026 trank eine Figur mit Iron Gut reine Bleiche und starb: die Messung
-- stimmte, der Titel im Wiki war missverstaendlich, und niemand hatte den Fund je
-- im Spiel nachgestellt. Dieses Fenster gibt je Fund die noetigen Gegenstaende
-- und schaltet den Trait an und ab; gespielt und geschaut wird von Hand.
--
-- Taste: Num 4 (ohne -debug auch F4 ist belegt, darum nur der Nummernblock).
-- An einer Wegwerf-Figur benutzen: die Traits werden nicht zurueckgesetzt.
--
-- Jeder Knopfdruck schreibt eine Zeile nach Zomboid/Lua/TraitFacts_nachstellen.txt,
-- damit hinterher feststeht, was gegeben und geschaltet wurde. Ohne Uhrzeit.

TFMeasureNachstellen = TFMeasureNachstellen or {}
local N = TFMeasureNachstellen
N.DATEI = "TraitFacts_nachstellen.txt"

--- Meldung mit Uhrzeit ueber TFMeasure.melde (seit 6.45.0), sonst wie bisher.
local function melde(text)
    if TFMeasure and TFMeasure.melde then return TFMeasure.melde("[TFMeasure] nachstellen:", text) end
    print("[TFMeasure] nachstellen: " .. tostring(text))
end

local function keyOf(traitType)
    local ok, name = pcall(function() return traitType:getName() end)
    if not ok or not name then return nil end
    return (tostring(name):lower():gsub("[^%a%d]", ""))
end

local function traitTypeNamed(wanted)
    local defs = CharacterTraitDefinition.getTraits()
    for index = 0, defs:size() - 1 do
        local traitType = defs:get(index):getType()
        if keyOf(traitType) == wanted then return traitType end
    end
    return nil
end

local function schreiben(text)
    pcall(function()
        local writer = getFileWriter(N.DATEI, true, true)
        if not writer then return end
        writer:write(text .. "\r\n")
        writer:close()
    end)
    melde(text)
end

local function sagen(player, text)
    pcall(function() HaloTextHelper.addText(player, text) end)
end

--- Gibt Gegenstaende; liste = { { "Base.Plank", 4 }, ... }.
local function geben(player, liste)
    local inv, namen = player:getInventory(), {}
    for _, eintrag in ipairs(liste) do
        for _ = 1, eintrag[2] or 1 do
            local ok, item = pcall(function() return inv:AddItem(eintrag[1]) end)
            if not (ok and item) then namen[#namen + 1] = eintrag[1] .. " FEHLT" end
        end
        namen[#namen + 1] = eintrag[1] .. " x" .. tostring(eintrag[2] or 1)
    end
    return table.concat(namen, ", ")
end

--- Eine Flasche mit vorgegebenem Inhalt; Mengen in Litern.
local function flasche(player, wasser, bleiche)
    local ok, fehler = pcall(function()
        local item = player:getInventory():AddItem("Base.WaterBottle")
        local fc = item:getFluidContainer()
        fc:Empty()
        if wasser > 0 then fc:addFluid(FluidType.TaintedWater, wasser) end
        if bleiche > 0 then fc:addFluid(FluidType.Bleach, bleiche) end
    end)
    return ok and string.format("Flasche %.1f l verseuchtes Wasser + %.1f l Bleiche", wasser, bleiche)
        or ("Flasche nicht erzeugbar: " .. tostring(fehler))
end

--- Schaltet einen Trait um und meldet den neuen Stand.
local function umschalten(player, key)
    local traitType = traitTypeNamed(key)
    if not traitType then return key .. ": Trait nicht gefunden" end
    local traits = player:getCharacterTraits()
    local hat = traits:get(traitType)
    if hat then traits:remove(traitType) else traits:add(traitType) end
    return key .. (hat and " AUS" or " AN")
end

-- Je Fund: was gegeben wird, welcher Trait dazugehoert, und was zu sehen sein muss.
-- `erwartet` steht im Fenster und im Protokoll; es ist die Aussage aus dem Wiki.
N.FAELLE = {
    -- durst: Wasserbehaelter bieten "Drink" nur bei Durst ueber 0.1 an
    -- (ISInventoryPaneContextMenu Z. 437); eine Testfigur hat keinen. Bleiche geht immer.
    { id = "bleiche", titel = "Iron Gut und Bleiche", trait = "irongut", durst = 0.6,
      erwartet = "Mischflasche: ohne Iron Gut krank, mit Iron Gut kein Gift. Reine Bleiche toetet immer, NICHT trinken.",
      geben = function(p)
          return flasche(p, 0.5, 0.1) .. "; " .. flasche(p, 0.5, 0.0) .. "; "
              .. geben(p, { { "Base.Bleach", 1 }, { "Base.WaterBottle", 1 } })
      end },
    { id = "metallbarrikade", titel = "Metallbarrikade", trait = "handy",
      erwartet = "Fenster ueber das Baumenue verbarrikadieren, einmal ohne und einmal mit Handy: das Protokoll schreibt die Bauzeit mit (erwartet 200 und 150).",
      geben = function(p)
          -- Die Metallplatte verlangt im Baumenue Schweissstaebe und MetalWelding 3
          -- (entity_barricade_metalsheet.txt); ohne beides blieb "Build" grau (21.09.2026).
          local stufe = "MetalWelding nicht setzbar"
          if pcall(function() p:setPerkLevelDebug(Perks.MetalWelding, 3) end) then stufe = "MetalWelding auf 3" end
          return geben(p, { { "Base.Plank", 6 }, { "Base.NailsBox", 1 }, { "Base.Hammer", 1 }, { "Base.SheetMetal", 3 },
                            { "Base.BlowTorch", 1 }, { "Base.WeldingRods", 2 }, { "Base.WeldingMask", 1 } }) .. "; " .. stufe
      end },
    { id = "axpert", titel = "Ax-pert Faelltempo", trait = "axeman",
      erwartet = "Gleichen Baum faellen mit und ohne Ax-pert: weniger Hiebe, aber derselbe Takt (rund 1.25 s je Hieb).",
      geben = function(p) return geben(p, { { "Base.Axe", 2 } }) end },
    { id = "appetit", titel = "Hearty Appetite, wenn satt", trait = "heartyappetite",
      erwartet = "Satt gegessen steigt der Hunger mit und ohne Trait gleich; erst hungrig wirkt der Trait.",
      geben = function(p) return geben(p, { { "Base.TinnedBeans", 4 }, { "Base.TinOpener", 1 } }) end },
}

local function fallVon(id)
    for _, fall in ipairs(N.FAELLE) do
        if fall.id == id then return fall end
    end
    return nil
end

--- Macht die Figur durstig, damit das Spiel "Drink" an Wasserbehaeltern anbietet.
function N.durst(player, wert)
    local ok = pcall(function() player:getStats():set(CharacterStat.THIRST, wert) end)
    return ok and string.format("Durst auf %.1f", wert) or "Durst nicht setzbar"
end

function N.geben(id)
    local player, fall = getSpecificPlayer(0), fallVon(id)
    if not (player and fall) then return end
    local text = fall.geben(player)
    if fall.durst then text = text .. "; " .. N.durst(player, fall.durst) end
    schreiben(id .. "|gegeben|" .. text)
    sagen(player, "Gegeben: " .. fall.titel)
end

function N.trait(id)
    local player, fall = getSpecificPlayer(0), fallVon(id)
    if not (player and fall) then return end
    local text = umschalten(player, fall.trait)
    if fall.durst then text = text .. "; " .. N.durst(player, fall.durst) end
    schreiben(id .. "|trait|" .. text)
    sagen(player, text)
end

--- Schreibt mit, welche Bauzeit das Spiel wirklich ansetzt (seit 21.09.2026).
--
-- Spieler verbarrikadieren in 42.20 ueber das Baumenue: ISBuildIsoEntity legt eine
-- ISBuildAction an, `time` kommt aus dem Rezept, Handy zieht 50 ab. Die alte
-- ISBarricadeAction, an der die Mess-Mod bisher mass, ruft nur noch die Testdatei
-- des Spiels auf. Hier wird nichts aufgerufen, nur mitgelesen, was beim echten
-- Bauen entsteht: Rezeptzeit, angesetzte Zeit und ob Handy an der Figur steht.
function N.bauzeitMitschreiben()
    if not ISBuildAction or ISBuildAction.tfNachstellen then return end
    local original = ISBuildAction.new
    ISBuildAction.tfNachstellen = original
    function ISBuildAction.new(self, character, item, x, y, z, north, spriteName, time, ...)
        local o = original(self, character, item, x, y, z, north, spriteName, time, ...)
        pcall(function()
            local handy = traitTypeNamed("handy")
            schreiben(string.format("bauzeit|sprite=%s|rezept=%s|angesetzt=%s|handy=%s|carpentry=%d|metalwelding=%d",
                tostring(spriteName), tostring(time), tostring(o and o.maxTime),
                tostring(handy and character:getCharacterTraits():get(handy) or false),
                character:getPerkLevel(Perks.Woodwork), character:getPerkLevel(Perks.MetalWelding)))
        end)
        return o
    end
end

--- Das Fenster: je Fund eine Zeile mit zwei Knoepfen und der Erwartung darunter.
function N.fenster()
    if N.offen and N.offen:isVisible() then
        N.offen:setVisible(false)
        N.offen:removeFromUIManager()
        N.offen = nil
        return
    end
    if not (ISCollapsableWindow and ISButton) then return end
    pcall(N.bauzeitMitschreiben)
    local zeile, breite = 58, 620
    local w = ISCollapsableWindow:new(80, 120, breite, 40 + zeile * #N.FAELLE + 30)
    w:initialise()
    w:setTitle("Trait Facts Measure: Nachstellen (Wegwerf-Figur)")
    w:setResizable(false)
    w:addToUIManager()
    local font = UIFont.Small
    for index, fall in ipairs(N.FAELLE) do
        local y = 26 + (index - 1) * zeile
        local titel = ISLabel:new(10, y, 20, fall.titel, 1, 1, 1, 1, font, true)
        titel:initialise()
        w:addChild(titel)
        local gib = ISButton:new(230, y, 150, 20, "Gegenstaende geben", w, function() N.geben(fall.id) end)
        gib:initialise()
        w:addChild(gib)
        local schalt = ISButton:new(390, y, 220, 20, "Trait " .. fall.trait .. " an/aus", w, function() N.trait(fall.id) end)
        schalt:initialise()
        w:addChild(schalt)
        local hinweis = ISLabel:new(10, y + 24, 16, fall.erwartet, 0.7, 0.7, 0.7, 1, font, true)
        hinweis:initialise()
        w:addChild(hinweis)
        breite = math.max(breite, 20 + getTextManager():MeasureStringX(font, fall.erwartet))
    end
    w:setWidth(breite)
    -- Unten die Zahlen, auf die es beim Trinken ankommt, in jedem Bild neu gelesen:
    -- Moodles zeigen Gift erst spaet und grob. Mit God Mode rechnet das Spiel den
    -- Koerper gar nicht (BodyDamage.Update kehrt vorher zurueck), darum steht er dabei.
    local zeichnen = w.prerender
    function w:prerender()
        zeichnen(self)
        -- Ein Fehler hier kaeme in jedem Bild wieder; lieber keine Zeile als ein volles Log.
        pcall(N.zahlen, self, font)
    end
    function N.zahlen(self, font)
        local p = getSpecificPlayer(0)
        if not p then return end
        local function stat(name)
            local ok, wert = pcall(function() return p:getStats():get(CharacterStat[name]) end)
            return (ok and type(wert) == "number") and string.format("%.2f", wert) or "?"
        end
        local gott = false
        pcall(function() gott = p:isGodMod() end)
        local ig = traitTypeNamed("irongut")
        local hat = ig and p:getCharacterTraits():get(ig)
        local text = "Gift " .. stat("POISON") .. "   Uebelkeit " .. stat("FOOD_SICKNESS")
            .. "   Gesundheit " .. string.format("%.0f", p:getBodyDamage():getOverallBodyHealth())
            .. "   Iron Gut " .. (hat and "AN" or "AUS")
            .. "   God Mode " .. (gott and "AN (Gift wirkt nicht!)" or "aus")
        self:drawText(text, 10, self.height - 22, gott and 1 or 0.6, gott and 0.6 or 0.9, 0.6, 1, font)
    end
    N.offen = w
end

function N.taste(key)
    if key ~= Keyboard.KEY_NUMPAD4 then return end
    -- Eine Zeile je Druck: so steht im Log, ob die Taste ankam und woran es sonst lag.
    local player = getSpecificPlayer(0)
    melde("Num 4, Figur " .. tostring(player ~= nil))
    if not player then return end
    local ok, fehler = pcall(N.fenster)
    if not ok then melde("Fenster FEHLGESCHLAGEN: " .. tostring(fehler)) end
end

if Events and Events.OnKeyPressed and not N.angemeldet then
    N.angemeldet = true
    Events.OnKeyPressed.Add(function(key) TFMeasureNachstellen.taste(key) end)
end
