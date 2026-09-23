--- Trait Facts - Schicht 1: was die Engine live hergibt.
--
-- Diese Zeilen brauchen keinen Versionsstempel und veralten nicht: sie werden
-- bei jedem Oeffnen frisch gelesen. Aendert ein Patch die Ausschluesse oder die
-- Foraging-Werte, steht es sofort richtig da.
--
-- Bewusst nicht enthalten: Punktkosten und XP-Boni. Beides zeigt Vanilla schon
-- selbst - die Kosten in der Liste, die XP-Boni haengt getDescription() an die
-- Beschreibung an ("+4 Strength" bei Strong). Ein Nachbau stuende doppelt im
-- Tooltip.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Live = TF.Live or {}

--- Ruft eine Methode geschuetzt auf.
-- Nicht jede Engine-Version fuehrt jede Methode. Fehlt sie, entfaellt die Zeile
-- still statt den Tooltip zu zerreissen.
local function call(obj, method)
    if obj == nil then return nil end
    local ok, result = pcall(function() return obj[method](obj) end)
    if not ok then
        TF.warnOnce("call:" .. method, method .. "() nicht verfuegbar: " .. tostring(result))
        return nil
    end
    return result
end

--- Java-Collection in eine Lua-Liste. Java zaehlt ab 0.
local function toList(collection)
    local out = {}
    if collection == nil then return out end
    local ok, size = pcall(function() return collection:size() end)
    if not ok or type(size) ~= "number" then return out end
    for i = 0, size - 1 do
        local okItem, item = pcall(function() return collection:get(i) end)
        if okItem and item ~= nil then
            out[#out + 1] = item
        end
    end
    return out
end

--- Anzeigename eines Traits, ausgehend von seinem Registry-Typ.
local function traitLabel(traitType)
    local ok, def = pcall(function()
        return CharacterTraitDefinition.getCharacterTraitDefinition(traitType)
    end)
    if not ok or def == nil then return nil end
    local label = call(def, "getLabel")
    if label and label ~= "" then return tostring(label) end
    return nil
end

--- Sortierte Namensliste aus einer Collection von Trait-Typen.
--
-- `skipLabel` faellt heraus. Das ist noetig, weil sechs Traits paarweise
-- denselben Anzeigenamen tragen: eine kaufbare Fassung und eine Berufsfassung
-- mit Kosten 0, die sich gegenseitig ausschliessen, damit man den Trait nicht
-- doppelt bekommt (BLACKSMITH/BLACKSMITH2, COOK/COOK2, HERBALIST/HERBALIST_PROF,
-- INVENTIVE/INVENTIVE_PROF, MECHANICS/MECHANICS2, NUTRITIONIST/NUTRITIONIST2).
-- Ungefiltert stuende im Tooltip "Schliesst aus: Blacksmith Knowledge" auf genau
-- diesem Trait - fuer den Spieler sinnlos, weil beide gleich heissen.
--
-- Ein Name aus einem fremden Mod traegt das Kuerzel seines Mods (Spec 6.3)
-- und meldet es ueber `useTag`: der Tooltip nennt oben jedes Kuerzel, das
-- nur hier auftaucht, mit dem Mod-Namen (Layout A+, 14.09.2026; vorher in
-- der Schluesselzeile unter dem Block).
-- @param useTag  optional: Funktion (Kuerzel, Mod-Name) oder Tabelle
--                Kuerzel -> Mod-Name
-- @return table  Liste von { label, tag }, nach Namen sortiert; tag nil fuer
--                einen Vanilla-Trait
local function traitNames(collection, skipLabel, useTag)
    local names = {}
    for _, traitType in ipairs(toList(collection)) do
        local label = traitLabel(traitType)
        if label and label ~= skipLabel then
            -- Derselbe Abgleich wie in TF.traitId, ueber TF.parseTraitId:
            -- eine Stelle fuer die Regel, welches Mod einen Trait besitzt.
            local okId, raw = pcall(function() return tostring(traitType) end)
            local ns = okId and TF.parseTraitId(raw) or nil
            local mod = ns and ns ~= "base" and TF.Mods and TF.Mods.modFor and TF.Mods.modFor(ns) or nil
            names[#names + 1] = { label = label, tag = mod and mod.tag or nil,
                                  modName = mod and mod.name or nil }
        end
    end
    table.sort(names, function(a, b) return a.label < b.label end)
    -- Erst nach dem Sortieren melden: dann stehen die Kuerzel oben in der
    -- Reihenfolge, in der sie unten in der Liste auftauchen.
    for _, n in ipairs(names) do
        if n.tag then
            if type(useTag) == "function" then
                useTag(n.tag, n.modName)
            elseif type(useTag) == "table" then
                useTag[n.tag] = n.modName
            end
        end
    end
    return names
end

-- Der Foraging-Index wird einmal gebaut und dann gehalten: die Definitionen
-- aendern sich zur Laufzeit nicht.
local forageIndex = nil
local foreignReplayed = false
-- Dasselbe fuer Berufe (type = "occupation"); forageSystem sucht sie beim
-- Namen des Berufs (skillDefs.occupation[profession:getName()]).
local occupationIndex = nil

--- Nimmt eine Trait-Definition in den Index auf; die erste gewinnt, wie in
-- forageSystem.addSkillDef.
local function remember(def)
    if type(def) == "table" and def.type == "trait" and def.name then
        local key = TF.normalize(def.name)
        local index = forageIndex
        if index and key and index[key] == nil then index[key] = def end
    end
end

--- Foraging-Definition zu einem normalisierten Trait-Schluessel.
--
-- `forageSystem.forageSkillDefinitions` fuehrt Berufe und Traits gemischt, je
-- Eintrag unterschieden durch `type`. Der Schluessel der Tabelle ist nicht
-- verlaesslich der Trait-Name, wohl aber das Feld `name`. Nach dem Laden der
-- Karte stehen zusaetzlich alle angemeldeten Definitionen in
-- forageSystem.skillDefs.trait, auch die fremder Mods.
local function forageDef(key)
    if forageIndex == nil then
        forageIndex = {}
        if forageSystem == nil or type(forageSystem.forageSkillDefinitions) ~= "table" then
            TF.warnOnce("forage",
                "forageSystem.forageSkillDefinitions nicht lesbar, Foraging-Zeilen entfallen.")
        else
            for _, def in pairs(forageSystem.forageSkillDefinitions) do remember(def) end
            local skillDefs = forageSystem.skillDefs
            if type(skillDefs) == "table" and type(skillDefs.trait) == "table" then
                for _, def in pairs(skillDefs.trait) do remember(def) end
            end
        end
    end
    return forageIndex[key]
end

--- Holt die Definitionen fremder Mods, die es in der Charaktererstellung noch
-- nicht gibt.
--
-- Mods melden sie ueber das Ereignis preAddSkillDefs an (More Traits
-- Definitive: MT_ForageDefinitions.lua). Das feuert forageSystem.init, und die
-- laeuft erst bei OnLoadedMapZones, also nach der Charaktererstellung. 0.7.0
-- suchte sie deshalb vergeblich (Befund im Spiel 19.09.2026). Hier wird das
-- Ereignis einmal je Sitzung nachgespielt, mit einem Sammler statt des echten
-- Systems: addSkillDef landet im Index, alles andere reicht __index an
-- forageSystem durch. Was ein Listener dabei ins echte System schreibt, ist
-- harmlos: forageSystem.init leert vor dem eigenen Ereignis alle
-- Definitionstabellen (clearTables) und spielt die Anmeldungen neu ab.
local function replayForeign()
    if foreignReplayed then return end
    foreignReplayed = true
    if forageSystem == nil or type(triggerEvent) ~= "function" then return end
    local sammler = setmetatable({ addSkillDef = function(def) remember(def) end },
                                 { __index = forageSystem })
    local ok, err = pcall(triggerEvent, "preAddSkillDefs", sammler)
    if not ok then
        TF.warnOnce("forage:replay", "preAddSkillDefs nachgespielt, Fehler: " .. tostring(err))
    end
    -- Ein Listener, der nicht das uebergebene System benutzt, sondern das
    -- globale forageSystem.addSkillDef ruft, schreibt am Sammler vorbei ins
    -- echte System. Der Index stand da schon; darum hier noch einmal
    -- nachlesen (Audit 20.09.2026). remember laesst die erste Definition
    -- gewinnen, doppelt Gelesenes aendert also nichts.
    for _, source in ipairs({ forageSystem.forageSkillDefinitions or false,
                              type(forageSystem.skillDefs) == "table" and forageSystem.skillDefs.trait or false }) do
        if type(source) == "table" then
            for _, def in pairs(source) do remember(def) end
        end
    end
end

--- Foraging-Definition eines Traits.
-- forageSystem fuehrt seine Traits beim Namen. Vanilla-Traits heissen dort
-- wie ihr Pfad ("Herbalist"); ein fremder Trait wird nur ueber seine volle
-- Kennung gesucht, sonst zeigte "xyz:herbalist" die Boni von Herbalist, die
-- das Spiel nur dem Vanilla-Trait gibt (Review 15.09.2026). Fremde Mods
-- melden ihre Definition unter genau dieser Kennung an (More Traits
-- Definitive: name = "ToadTraits:wildsman", MT_ForageDefinitions.lua); bis
-- 0.6.0 blieben sie ungelesen und das Datenpaket hielt eine Abschrift, die
-- in der Uebersicht nicht mit den Vanilla-Werten zusammenfiel (Befund im
-- Spiel 19.09.2026).
local function forageFor(traitDef)
    if TF.traitNamespace(traitDef) == "base" then
        local key = TF.traitKey(traitDef)
        return key and forageDef(key) or nil
    end
    local id = TF.traitId(traitDef)
    if not id then return nil end
    local key = TF.normalize(id)
    local def = forageDef(key)
    if def == nil then
        replayForeign()
        def = forageIndex and forageIndex[key] or nil
    end
    return def
end

--- Wirft den Foraging-Index weg, damit er neu gebaut wird.
-- Nur fuer den Test: im Spiel aendern sich die Definitionen nicht zur Laufzeit.
function TF.Live.forgetIndex()
    forageIndex = nil
    foreignReplayed = false
    occupationIndex = nil
end

--- Foraging-Definition eines Berufs, oder nil.
local function occupationDef(profDef)
    if occupationIndex == nil then
        occupationIndex = {}
        if forageSystem ~= nil then
            local skillDefs = forageSystem.skillDefs
            for _, source in ipairs({ forageSystem.forageSkillDefinitions or false,
                                      type(skillDefs) == "table" and skillDefs.occupation or false }) do
                if type(source) == "table" then
                    for _, def in pairs(source) do
                        if type(def) == "table" and def.type == "occupation" and def.name then
                            local key = TF.normalize(def.name)
                            if key and occupationIndex[key] == nil then occupationIndex[key] = def end
                        end
                    end
                end
            end
        end
    end
    local ok, name = pcall(function() return profDef:getType():getName() end)
    if not ok or not name then return nil end
    return occupationIndex[TF.normalize(name)]
end

--- Uebersetzter Name einer Foraging-Kategorie, sonst der rohe Schluessel.
--
-- Zwei Schluesselfamilien: die Namen aus dem Suchmodus, und fuer Kategorien,
-- die Vanilla dort versteckt (categoryHidden), die aus der Sammel-Oberflaeche.
-- FishBait hat nur die zweite; Angler zeigte deshalb "FishBait" statt "Fish
-- Bait" (Bugjagd 10.09.2026, Fund 6). Weggelassen wird eine Kategorie nie:
-- sie traegt einen echten Bonus.
-- Danach eigene Texte fuer Kategorien, die das Spiel absichtlich nicht
-- benennt: ForestRarities ist categoryHidden und erscheint dort nur als
-- "Other" (ISZoneDisplay.lua:540). Wir nennen Kategorien beim Namen, auch das
-- ebenso versteckte Ammunition; roh stand "ForestRarities" in der Uebersicht
-- (Befund im Spiel 19.09.2026, Scrounger). Zuletzt wie das Spiel die
-- uebergeordnete typeCategory, erst dann der rohe Schluessel.
local function categoryLabel(name)
    for _, family in ipairs({ "IGUI_SearchMode_Categories_", "IGUI_ScavengeUI_", "UI_TF_forcat_" }) do
        local translated = getTextOrNull(family .. tostring(name))
        if translated and translated ~= "" then return translated end
    end
    local defs = forageSystem and forageSystem.categoryDefinitions
    local def = type(defs) == "table" and defs[name] or nil
    if type(def) == "table" and def.typeCategory then
        local parent = getTextOrNull("IGUI_SearchMode_Categories_" .. tostring(def.typeCategory))
        if parent and parent ~= "" then return parent end
    end
    return tostring(name)
end

--- Die Stufen-Traits und die Stufe, fuer die sie stehen.
--
-- XpUpdate.lua:207-244: bei jedem Stufenwechsel in Strength oder Fitness
-- nimmt das Spiel die vier Traits des Skills weg und setzt den, der zur neuen
-- Stufe passt (0-1, 2-4, 6-8, ab 9; auf Stufe 5 keinen). Der Trait ist also
-- das Etikett der Stufe. Die Zahl dazu, die Startstufe, liest TF.Live.entries
-- aus getXpBoosts; hier steht nur der Satz, dass der Trait der Stufe folgt.
--
-- Ein Satz je Trait, nicht je Band (seit 0.1.19, Entscheidung 12.09.2026,
-- Mockup major-skills-tooltip, W2): "stands for level 2 to 4 and changes
-- with it" liess offen, was da wechselt. Jetzt steht der Skill dabei und der
-- Trait, der beim naechsten Stufenwechsel kommt. Die Namen der Nachbarn
-- stehen in der Uebersetzung, in der Sprache des Spiels.
local LEVEL_BANDS = {
    weak = "UI_TF_note_band_weak",   feeble = "UI_TF_note_band_feeble",
    stout = "UI_TF_note_band_stout", strong = "UI_TF_note_band_strong",
    unfit = "UI_TF_note_band_unfit", outofshape = "UI_TF_note_band_outofshape",
    fit = "UI_TF_note_band_fit",     athletic = "UI_TF_note_band_athletic",
}

--- Konsolenhilfe: zeigt, was getGrantedRecipes() wirklich liefert.
--
-- Hintergrund: die Trait-Definitionen mischen dreierlei in denselben Aufruf.
-- Gardener bekommt 64 Eintraege, davon 49 vom Typ SeasonRecipe - das sind
-- Anbauzeiten, keine Bauanleitungen. Mason bekommt 7, davon 6 vom Typ
-- EntityKey, also Bauwerke. Blacksmith bekommt eine Sammelkonstante, die sich
-- erst zur Laufzeit entfaltet.
--
-- Inzwischen im Jar geklaert: getGrantedRecipes() liefert eine
-- ArrayList<String>, die Anbauzeiten sind als "Carrot Growing Season"
-- registriert und werden an diesem Namensende erkannt. Die EntityKey-Bauwerke
-- ("Advanced_Forge", "Blast_Furnace") tragen kein solches Merkmal und zaehlen
-- weiter als Rezepte; das betrifft im Wesentlichen Mason mit sechs Eintraegen.
-- Diese Funktion bleibt als Kontrollmoeglichkeit. Aufruf in der Lua-Konsole:
--
--     TraitFacts.Live.dumpRecipes("Gardener")
--
-- @param registryName Registry-Name des Traits, Schreibweise egal
function TF.Live.dumpRecipes(registryName)
    local wanted = TF.normalize(registryName)
    local all = CharacterTraitDefinition.getTraits()
    for i = 0, all:size() - 1 do
        local def = all:get(i)
        if TF.traitKey(def) == wanted then
            local entries = toList(call(def, "getGrantedRecipes"))
            TF.log(tostring(call(def, "getLabel")) .. ": " .. #entries .. " Eintraege")
            for index, entry in ipairs(entries) do
                TF.log(string.format("  %2d  %-12s %s", index, type(entry), tostring(entry)))
            end
            return #entries
        end
    end
    TF.warn("Trait nicht gefunden: " .. tostring(registryName))
    return nil
end

--- Einrueckung der Punkte unter "Excludes:" / "Also grants:", in Pixeln
-- bei der kleinen Schrift in Standardgroesse (TF.fmt.uiScale skaliert).
local BULLET_INDENT = 8

--- Zeilen zum Verhaeltnis gegenueber anderen Traits.
--
-- Bewusst getrennt von den Wirkungszeilen: das ist eine andere Art von
-- Auskunft. Der Tooltip setzt sie hinter eine Leerzeile.
--
-- @param traitDef CharacterTraitDefinition
-- @param useTag   optional: Funktion (Kuerzel, Mod-Name) oder Tabelle
--                 Kuerzel -> Mod-Name; erfaehrt die Kuerzel fremder Traits
--                 in Ausschluessen und Gewaehrtem
-- @param font     optional: die Schrift des Tooltips (ISToolTip.GetFont), fuer
--                 die Einrueckung der Punkte; ohne Angabe NewSmall, wie
--                 TF.fmt.uiScale es ohnehin annimmt
-- @param excludesMode optional: "hide" laesst die Liste "Excludes" weg
--                 (Mod-Option, TF_Options), "ghost" setzt an ihre Stelle nur
--                 ihren Namen, leise (Vorschau am "i" der Optionen);
--                 "Also grants" bleibt in beiden Faellen
-- @return table  Liste fertiger Zeilen, moeglicherweise leer
function TF.Live.relations(traitDef, useTag, font, excludesMode)
    if not TF.traitKey(traitDef) then return {} end

    local lines = {}

    -- Der eigene Anzeigename, um die gleichnamige Zwillingsfassung auszusieben.
    local ownLabel = call(traitDef, "getLabel")

    -- Seit 14.09.2026 eine Liste (Mockup tooltip-fremde-traits): die
    -- Beschriftung allein, darunter je Trait eine Zeile mit Punkt. Vorher
    -- standen alle Namen durch Kommas getrennt hinter "Excludes:", und mit
    -- Kuerzeln wurde die Zeile unlesbar lang. Das Wort und der Punkt sind
    -- Beiwerk und stehen leise, die Namen im Grau-Lila der Quellenspalte wie
    -- ueberall (Rueckmeldung vom 10.09.2026), das Kuerzel eines fremden
    -- Traits in der Farbe seines Mods. Der Punkt kommt aus der Uebersetzung:
    -- Sonderzeichen stehen nie im Lua-Quelltext.
    local bullet = TF.fmt.text("UI_TF_bullet")
    -- Die Punkte stehen eingerueckt, ein paar Pixel rechts vom Anfang der
    -- Beschriftung wie im Mockup (Nachtrag 14.09.2026). <SETX:> und nicht
    -- <INDENT:>: INDENT gilt in Vanilla (ISRichTextPanel.processCommand) bis
    -- zum naechsten INDENT und saesse in allem, was danach kommt; ein
    -- <SPACE> am Zeilenanfang rueckt dort nicht vor (nur bei x > 0). Das
    -- Leerzeichen vor dem Tag ist Pflicht (siehe TF.fmt.columns). Ohne
    -- Palette (reiner Text) keine Einrueckung.
    --
    -- Skaliert mit der Schrift des Tooltips (font), nicht mit NewSmall: sonst
    -- blieb der Einzug bei grosser Tooltip-Schrift auf dem Mass der kleinen
    -- stehen, waehrend setRows daneben mit fontScale(font) rechnet - die
    -- Punkte ruecken dann nicht mehr mit dem Rest des Blocks mit (Review
    -- 15.09.2026).
    local indent = ""
    if TF.fmt.palette then
        indent = " <SETX:" .. tostring(math.floor(BULLET_INDENT * TF.fmt.uiScale(font) + 0.5)) .. "> "
    end
    local function list(key, names)
        if #names == 0 then return end
        lines[#lines + 1] = TF.fmt.join({ { text = TF.fmt.text(key) .. ":", color = "note" } })
        for _, n in ipairs(names) do
            local parts = { { text = bullet, color = "note" }, { text = TF.fmt.plain(n.label), color = "source" } }
            if n.tag then parts[#parts + 1] = { text = n.tag, color = TF.fmt.tagKey(n.tag) } end
            lines[#lines + 1] = indent .. TF.fmt.join(parts)
        end
    end
    if excludesMode == "ghost" then
        -- Ohne useTag: die Kuerzel ausgeblendeter Namen gehoeren nicht nach oben.
        if #traitNames(call(traitDef, "getMutuallyExclusiveTraits"), ownLabel, nil) > 0 then
            lines[#lines + 1] = TF.fmt.join({ { text = TF.fmt.text("UI_TF_live_excludes"), color = "ghost" } })
        end
    elseif excludesMode ~= "hide" then
        list("UI_TF_live_excludes", traitNames(call(traitDef, "getMutuallyExclusiveTraits"), ownLabel, useTag))
    end
    list("UI_TF_live_grants", traitNames(call(traitDef, "getGrantedTraits"), ownLabel, useTag))

    return lines
end

--- Die freien Rezepte einer Definition als Zaehl-Eintraege.
--
-- Nur die Anzahl: Tailor und Gardener bringen je rund 60 Eintraege mit, eine
-- Namensliste waere im Tooltip unlesbar.
--
-- getGrantedRecipes() liefert eine ArrayList<String>, und darin steckt
-- zweierlei. Neben echten Bauanleitungen stehen dort die Anbauzeiten aus
-- SeasonRecipe, registriert als "Carrot Growing Season" und so weiter. Bei
-- Gardener sind 49 von 64 Eintraegen solche Anbauzeiten - "Rezepte: 64"
-- waere schlicht falsch. Beide werden deshalb getrennt gezaehlt.
--
-- Die Namen laufen als Menge mit: in der Gesamtuebersicht lehren zwei
-- Traits oft dieselben Rezepte, und die Figur lernt jedes einmal. Trait- und
-- Berufsdefinition fuehren dieselbe Methode (CharacterTraitDefinition und
-- CharacterProfessionDefinition, je ArrayList<String>), darum eine Funktion
-- fuer beide (Faktensweep 2, 23.09.2026).
-- @param def  Trait- oder Berufsdefinition
-- @param out  Liste, an die die Eintraege angehaengt werden
local function recipeEntries(def, out)
    local recipes, seasons = 0, 0
    local recipeSet, seasonSet = {}, {}
    for _, entry in ipairs(toList(call(def, "getGrantedRecipes"))) do
        local name = TF.normalize(entry)
        if name and name:sub(-13) == "growingseason" then
            if not seasonSet[name] then
                seasonSet[name] = true
                seasons = seasons + 1
            end
        elseif name then
            if not recipeSet[name] then
                recipeSet[name] = true
                recipes = recipes + 1
            end
        end
    end
    if recipes > 0 then
        out[#out + 1] = { id = "recipes", kind = "count", value = recipes,
                          text = "UI_TF_live_recipes", items = recipeSet }
    end
    if seasons > 0 then
        out[#out + 1] = { id = "seasons", kind = "count", value = seasons,
                          text = "UI_TF_live_seasons", items = seasonSet }
    end
end

--- Die live gelesenen Werte als Eintraege, in derselben Form wie TF_Static.
--
-- Daraus baut TF.Live.effects seine Tooltip-Zeilen und TF.Summary seine
-- Summen. Eine Quelle fuer beides: sonst driftet die Uebersicht vom Tooltip
-- weg, ohne dass es jemandem auffaellt.
--
-- Nicht enthalten sind die Kategorie-Boni beim Fundglueck. Sie gehoeren in den
-- Tooltip des einzelnen Traits; in der Gesamtuebersicht waeren es bis zu acht
-- Zeilen je Foraging-Trait, und die Uebersicht soll den Build zeigen, nicht
-- ihn zudecken.
--
-- @param traitDef CharacterTraitDefinition
-- @return table  Liste von Eintraegen, moeglicherweise leer
function TF.Live.entries(traitDef)
    local key = TF.traitKey(traitDef)
    if not key then return {} end

    local out = {}
    local function add(id, text, kind, value, unit, note, scope, items)
        if type(value) ~= "number" or value == 0 then return end
        out[#out + 1] = { id = id, kind = kind, value = value,
                          text = text, unit = unit, note = note, scope = scope,
                          items = items }
    end

    -- Freie Rezepte und Anbauzeiten (recipeEntries).
    recipeEntries(traitDef, out)

    -- Startstufen in Strength und Fitness, gelesen wie Vanillas checkXPBoost:
    -- getXpBoosts ist eine Map Perk -> Integer. Bis 0.1.14 stand bei den
    -- Stufen-Traits nur das neutrale Zeichen (vier Punkte) und "Set by your
    -- Strength level"; die Zahl,
    -- die der Trait bei der Erstellung wirklich tut (Puny -5, Athletic +4),
    -- stand nirgends (Entscheidung 12.09.2026). Die Gewichts-Traits
    -- verschieben Fitness ebenfalls und bekommen dieselbe Zeile, nur ohne den
    -- Stufen-Satz. Der Satz ist ein hint: in einer Summe mehrerer Traits
    -- gehoert er keinem allein.
    local boosts = call(traitDef, "getXpBoosts")
    if boosts ~= nil and Perks and transformIntoKahluaTable then
        local ok, map = pcall(transformIntoKahluaTable, boosts)
        if ok and type(map) == "table" then
            for perk, level in pairs(map) do
                local text = (perk == Perks.Strength and "UI_TF_eff_startstrength")
                    or (perk == Perks.Fitness and "UI_TF_eff_startfitness") or nil
                local n = level
                if type(n) ~= "number" then
                    local okN, v = pcall(function() return level:intValue() end)
                    n = okN and v or nil
                end
                if text and type(n) == "number" and n ~= 0 then
                    out[#out + 1] = { id = "startlevel:" .. text, kind = "flat", value = n,
                                      text = text, unit = "UI_TF_unit_levels",
                                      hint = (TF.traitNamespace(traitDef) == "base") and LEVEL_BANDS[key] or nil }
                end
            end
        end
    end

    local forage = forageFor(traitDef)
    if forage then
        -- Der Trait-Bonus geht in Kacheln auf minVisionRadius (3) und
        -- maxVisionRadius (10) des Foraging-Systems. Ohne Einheit und Basis
        -- ist ein "+1" nicht einzuordnen. Ueber mehrere Traits summiert das
        -- System die Boni (forageSystem: `traitBonus + traitDef.visionBonus`),
        -- ebenso Wetter, Dunkelheit und die Kategorien.
        --
        -- Traegt die Definition testFuncs, gilt der Bonus nur unter einer
        -- Bedingung. In Vanilla ist das genau einmal der Fall: Short Sighted
        -- verliert die -2 Kacheln, sobald eine Brille getragen wird
        -- (forageSystem.doGlassesCheck).
        -- Kein next(): das gibt es in Kahlua nicht. Der Aufruf hat die
        -- Charaktererstellung beim ersten Oeffnen zerlegt (Fehlerlog vom
        -- 09.09.2026, "Object tried to call nil in effects"). pairs benutzt
        -- Vanilla ueberall, next im ganzen Spiel genau einmal.
        local gated = false
        if type(forage.testFuncs) == "table" then
            for _ in pairs(forage.testFuncs) do
                gated = true
                break
            end
        end
        -- Der Geltungsbereich trennt den bedingten Bonus vom unbedingten. In
        -- der Gesamtuebersicht kommt dadurch die Summe als eigene Zeile dazu,
        -- denn das Spiel addiert beide.
        add("forageRadius", "UI_TF_live_sight", "flat", forage.visionBonus,
            "UI_TF_unit_tiles",
            gated and "UI_TF_live_sight_noglasses" or "UI_TF_live_sight_note",
            gated and "foragenoglasses" or "forageradius")
        -- Ein Abzug trifft auf die Untergrenze von 3 Kacheln. Im Suchradius
        -- (ISSearchManager.lua:1016-1052) sind es 3 + Bonus + 0.7 x Stufe,
        -- Short Sighted (-2) und Agoraphobic (-1.5) kosten bei Nahrungssuche 0
        -- nichts, 0,7 Kacheln je Stufe mehr und ab Stufe 3 ganz. Beim Entdecken
        -- eines Gegenstands (ISBaseIcon.lua:318-376) 3 + 0.5 x Stufe + Bonus,
        -- mindestens 3, dann x (Stufe + 1)/10 und x (ln Gewicht + 0.5), danach
        -- wieder mindestens 3 x visionBonus: bei leichten Gegenstaenden oft
        -- auch auf hoher Stufe nichts (Faktensweep 2 und 3, 23.09.2026; bis
        -- 0.14.1 stand hier "ab Stufe 4 bzw. 3 ganz"). Eine condition, keine Fussnote: die
        -- Fussnote bestimmt den Eimer der Uebersicht, und Agoraphobic muss
        -- mit den positiven Radien zusammen rechnen. TF.Summary nimmt die
        -- Bedingung wieder heraus, wenn die Summe nicht mehr negativ ist.
        local last = out[#out]
        if last and last.id == "forageRadius" and last.value < 0 then
            last.condition = "UI_TF_note_sightfloor"
        end
        -- weatherEffect und darknessEffect sind Prozentwerte, um die die Strafe
        -- *sinkt*, deshalb mit umgekehrtem Vorzeichen anzeigen.
        add("forageWeather", "UI_TF_live_weather", "pct", -(forage.weatherEffect or 0))
        add("forageDarkness", "UI_TF_live_darkness", "pct", -(forage.darknessEffect or 0))
    end

    return out
end

--- Zeilen zur Wirkung des Traits: Rezepte, Foraging, Fundglueck.
-- @param traitDef CharacterTraitDefinition
-- @return table  Liste fertiger Zeilen, moeglicherweise leer
--- Die Fundchancen je Kategorie, nach Bonushoehe gruppiert.
--
-- Kategorien nach Bonushoehe gruppieren statt einzeln aufzuzaehlen: Keen
-- Cook hat sieben Kategorien, davon sechs mit demselben Wert; als Einzelliste
-- wird die Zeile unlesbar breit und der Prozentwert wiederholt sich sinnlos.
-- Groesster Bonus zuerst, innerhalb einer Gruppe alphabetisch.
--
-- @return table  Liste von { value = Bonus in Prozent, text = fertiger Wert,
--                categories = "Animals, Berries" }
function TF.Live.spotting(traitDef)
    local forage = forageFor(traitDef)
    if not forage then return {} end

    local groups, values = {}, {}
    if type(forage.specialisations) == "table" then
        for name, bonus in pairs(forage.specialisations) do
            if type(bonus) == "number" and bonus ~= 0 then
                if not groups[bonus] then
                    groups[bonus] = {}
                    values[#values + 1] = bonus
                end
                local group = groups[bonus]
                group[#group + 1] = categoryLabel(name)
            end
        end
    end

    table.sort(values, function(a, b) return a > b end)
    local out = {}
    for _, bonus in ipairs(values) do
        local value = TF.fmt.value("pct", bonus)
        if value then
            table.sort(groups[bonus])
            out[#out + 1] = { value = bonus, text = value,
                              categories = table.concat(groups[bonus], ", ") }
        end
    end
    return out
end

--- Die Kategorie-Boni als Eintraege fuer die Gesamtuebersicht.
--
-- Eine Zeile je Kategorie (Entscheidung 12.09.2026, Variante A2): so kann
-- die Uebersicht je Kategorie summieren, wie forageSystem.getCategoryBonus
-- es tut (1 + Summe/100 ueber Beruf und alle Traits). Der Tooltip des
-- einzelnen Traits zeigt dieselben Boni weiter gruppiert (TF.Live.spotting);
-- deshalb stehen sie nicht in TF.Live.entries, sonst stuenden sie dort
-- doppelt. Bis 0.1.13 fehlten sie in der Uebersicht ganz, und wer dort nur
-- "+0.2 tiles" las, hielt das fuer den eingeschraenkten Wert.
--
-- @return table  Liste von Eintraegen; `textArg` ist der Kategoriename
function TF.Live.categoryEntries(traitDef)
    local forage = forageFor(traitDef)
    if not forage or type(forage.specialisations) ~= "table" then return {} end
    local out = {}
    for name, bonus in pairs(forage.specialisations) do
        if type(bonus) == "number" and bonus ~= 0 then
            out[#out + 1] = { id = "forageCategory:" .. tostring(name), kind = "pct",
                              value = bonus, text = "UI_TF_live_spotfor",
                              textArg = categoryLabel(name) }
        end
    end
    return out
end

--- Was der Beruf selbst zur Uebersicht beitraegt (seit 0.12.0).
--
-- Die gewaehrten Traits des Berufs stehen schon in der Liste der gewaehlten
-- Traits. Es fehlten seine Foraging-Werte, seine Startstufen und seine
-- Rezepte (unten): forageSystem
-- addiert den Beruf in Sichtradius, Wetter, Dunkelheit und jede Kategorie
-- mit den Traits zusammen (getProfessionVisionBonus, getCategoryBonus), und
-- die 75er-Kappe lag bis 0.11.0 auf einer Summe ohne ihn (Audit 20.09.2026,
-- L1). Dieselben Texte, Einheiten, Fussnoten und Geltungsbereiche wie in
-- TF.Live.entries, damit die Zeilen mit denen der Traits zusammenfallen.
-- Skills ausser Strength und Fitness zeigt die Startskill-Liste.
--
-- Seit dem Faktensweep 2 (23.09.2026) auch die freien Rezepte des Berufs:
-- das Spiel lernt sie beim Start aus der Berufsdefinition (IsoWorld.java:
-- 2212-2215, im Mehrspieler applyProfessionRecipes), nicht aus dessen
-- gewaehrten Traits. 15 Vanilla-Berufe tun das, und alle 15 lernen ihre
-- Berufsrezepte nur so: die gewaehrten Traits haben keine (Burglar, Cook2,
-- Mechanics2, Blacksmith2, Inventive, Desensitized) oder andere (Herbalist
-- beim Park Ranger), 8 Berufe gewaehren gar keinen Trait. Bis 0.14.0 fehlten
-- die Berufsrezepte in der Uebersicht bei allen 15 (Faktensweep 3,
-- 23.09.2026; hier standen bis dahin nur Chef, Mechanic, Metalworker, Smither).
-- Die Namensmengen fallen in TF.Summary.merge mit denen der Traits zusammen.
-- @return table  Liste von Eintraegen, moeglicherweise leer
function TF.Live.professionEntries(profDef)
    if not profDef then return {} end
    local out = {}
    recipeEntries(profDef, out)
    local boosts = call(profDef, "getXpBoosts")
    if boosts ~= nil and Perks and transformIntoKahluaTable then
        local ok, map = pcall(transformIntoKahluaTable, boosts)
        if ok and type(map) == "table" then
            for perk, level in pairs(map) do
                local text = (perk == Perks.Strength and "UI_TF_eff_startstrength")
                    or (perk == Perks.Fitness and "UI_TF_eff_startfitness") or nil
                local n = level
                if type(n) ~= "number" then
                    local okN, v = pcall(function() return level:intValue() end)
                    n = okN and v or nil
                end
                if text and type(n) == "number" and n ~= 0 then
                    out[#out + 1] = { id = "startlevel:" .. text, kind = "flat", value = n,
                                      text = text, unit = "UI_TF_unit_levels" }
                end
            end
        end
    end
    local forage = occupationDef(profDef)
    if forage then
        local function add(id, text, kind, value, unit, note, scope)
            if type(value) ~= "number" or value == 0 then return end
            out[#out + 1] = { id = id, kind = kind, value = value, text = text,
                              unit = unit, note = note, scope = scope }
        end
        add("forageRadius", "UI_TF_live_sight", "flat", forage.visionBonus,
            "UI_TF_unit_tiles", "UI_TF_live_sight_note", "forageradius")
        add("forageWeather", "UI_TF_live_weather", "pct", -(forage.weatherEffect or 0))
        -- Die Dunkelheit des Berufs wendet das Spiel nie an: getDarknessEffect-
        -- Reduction (forageSystem.lua:1869) schlaegt skillDefs.occupation mit dem
        -- CharacterProfession-Objekt nach statt mit :getName(), findet also nie
        -- etwas; die Geschwister fuer Wetter (Z. 1820), Sichtradius (Z. 1910) und
        -- Kategorien (Z. 1711) nehmen den Namen und wirken. Darum dead mit
        -- Fussnote, und die Uebersicht laesst die Zeile aus der Summe
        -- (Faktensweep 23.09.2026, Spielfehler sammeln-dunkelheit-beruf).
        add("forageDarkness", "UI_TF_live_darkness", "pct", -(forage.darknessEffect or 0))
        local last = out[#out]
        if last and last.id == "forageDarkness" then
            last.dead = true
            last.note = "UI_TF_note_deadforageprof"
        end
        if type(forage.specialisations) == "table" then
            for name, bonus in pairs(forage.specialisations) do
                if type(bonus) == "number" and bonus ~= 0 then
                    out[#out + 1] = { id = "forageCategory:" .. tostring(name), kind = "pct",
                                      value = bonus, text = "UI_TF_live_spotfor",
                                      textArg = categoryLabel(name) }
                end
            end
        end
    end
    return out
end

--- Die Definition eines Vanilla-Traits zu seinem normalisierten Schluessel.
-- Fuer die Stufen-Traits, die das Spiel bei der Erschaffung selbst setzt
-- (TF.Summary.gather). Einmal je Sitzung aus der Registry gelesen.
local baseDefs = nil
function TF.Live.baseTrait(key)
    if baseDefs == nil then
        baseDefs = {}
        local ok, all = pcall(function() return CharacterTraitDefinition.getTraits() end)
        if ok and all ~= nil then
            for _, def in ipairs(toList(all)) do
                if TF.traitNamespace(def) == "base" then
                    local k = TF.traitKey(def)
                    if k and baseDefs[k] == nil then baseDefs[k] = def end
                end
            end
        end
    end
    return baseDefs[key]
end

function TF.Live.effects(traitDef)
    local key = TF.traitKey(traitDef)
    if not key then return {} end

    local lines = {}
    for _, entry in ipairs(TF.Live.entries(traitDef)) do
        local line = TF.fmt.entry(entry)
        if line then lines[#lines + 1] = line end
    end

    for _, spot in ipairs(TF.Live.spotting(traitDef)) do
        lines[#lines + 1] = TF.fmt.line(TF.fmt.text("UI_TF_live_spot", spot.text),
            spot.categories)
    end

    return lines
end
