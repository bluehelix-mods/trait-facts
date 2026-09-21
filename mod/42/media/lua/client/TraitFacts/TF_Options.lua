--- Trait Facts - Mod-Optionen (Optionen > Mods), seit 0.4.0.
--
-- Drei Checkboxen, dieselben im Zahnrad neben der Uebersicht (TF_Panel):
--   colorblind    Farben fuer Farbenblinde, Blau und Orange statt Gruen und
--                 Rot (Entscheidung 15.09.2026, Mockup mod-optionen; seit
--                 0.5.0 eine Checkbox statt einer Auswahlliste, Mockup knoepfe)
--   showdead      wirkungslose Werte im Tooltip, der Abschnitt "No effect in
--                 the game" und die Zeile zur grauen Zahl in der Legende
--   showexcludes  die Liste "Excludes" im Tooltip; "Also grants" bleibt
-- Die beiden letzten seit 0.9.0 (Entscheidung 19.09.2026, Mockup
-- option-wirkungslos), Vorgabe an. Was sonst als Schalter denkbar war, ist
-- Optik oder weicht den Kern auf; die Herkunftsmarker der SPEC entfallen als
-- zu detailliert. Die Legende ist keine Option, sondern das "?" der Uebersicht.
--
-- Vanilla (PZAPI/ModOptions.lua, OptionScreens/MainOptions.lua): create legt
-- die Optionen an, MainOptions:addModOptionsPanel liest ModOptions.ini (load)
-- erst beim Bau des Optionsfensters, "Anwenden" ruft options:apply() und
-- speichert. Namen und Tooltips uebersetzt Vanilla selbst (getText), hier
-- stehen nur die Schluessel. Die Werte werden darum nicht beim Laden dieser
-- Datei gelesen, sondern jedes Mal, wenn sie gebraucht werden
-- (TF.Options.sync): beim Bau eines Tooltips, der Uebersicht und je Bild der
-- Charaktererstellung.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Options = TF.Options or {}

TF.Options.ID = "TraitFacts"

local options = nil

-- Ohne PZAPI (aeltere Fassung, Test) haelt die Mod die Werte selbst, damit
-- das Zahnrad trotzdem schaltet; gespeichert werden sie dann nicht. Zugleich
-- die Vorgaben.
local fallback = { showdead = true, showexcludes = true }

local function create()
    if not (PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.create) then return end
    options = PZAPI.ModOptions:create(TF.Options.ID, "UI_TF_sum_title")
    -- Bis 0.12.13 stand hier "colorblind" (davor "colors"). Die Farben kommen
    -- seitdem aus den Spieloptionen (TF.fmt.gameScheme); die alte Zeile in
    -- ModOptions.ini kennt load() nicht mehr und laesst sie wirkungslos stehen.
    options:addTickBox("showdead", "UI_TF_opt_dead", fallback.showdead, "UI_TF_opt_dead_tooltip")
    options:addTickBox("showexcludes", "UI_TF_opt_excludes", fallback.showexcludes, "UI_TF_opt_excludes_tooltip")
    -- Der Weg zu den Belegen (seit 0.13.4): woher jede Zahl kommt.
    if options.addButton then
        options:addButton("wiki", "UI_TF_opt_wiki", "UI_TF_opt_wiki_tooltip", function()
            if TF.Panel and TF.Panel.openUrl then TF.safe("wiki:open", TF.Panel.openUrl, TF.Panel.WIKI_URL) end
        end)
    end
    -- "Anwenden" im Optionsfenster: gilt sofort, nicht erst beim naechsten
    -- Start (die Charaktererstellung gleicht je Bild ab, TF_Panel).
    options.apply = function() TF.safe("options:apply", TF.Options.sync) end
end

local function get(id)
    local option = options and options:getOption(id)
    if option then return option:getValue() == true end
    return fallback[id]
end

-- Setzt eine Option aus dem Zahnrad der Uebersicht und speichert sofort, wie
-- "Anwenden" im Optionsfenster; die Charaktererstellung zeichnet mit dem
-- naechsten Bild neu (TF_Panel, prerender).
local function set(id, on)
    on = on == true
    local option = options and options:getOption(id)
    if option then
        option:setValue(on)
        if PZAPI.ModOptions.save then
            TF.safe("options:save", function() PZAPI.ModOptions:save() end)
        end
    else
        fallback[id] = on
    end
    TF.Options.sync()
end

--- Ob der Tooltip wirkungslose Werte zeigt (und die Legende ihre Zeile).
function TF.Options.showDead() return get("showdead") end

--- Ob der Tooltip die Liste "Excludes" zeigt.
function TF.Options.showExcludes() return get("showexcludes") end

function TF.Options.setShowDead(on) set("showdead", on) end
function TF.Options.setShowExcludes(on) set("showexcludes", on) end

--- Das Farbschema: "game", wenn der Spieler die Hervorhebungsfarben des
-- Spiels geaendert hat, sonst "standard" (TF.fmt.gameScheme).
function TF.Options.scheme()
    return TF.fmt and TF.fmt.gameScheme and TF.fmt.gameScheme() or "standard"
end

--- Alle Einstellungen, die fertige Tooltips praegen, in einem Wort. Wer
-- Tooltips vorhaelt (die Trait-Listen, der Bildschirm), vergleicht damit und
-- baut bei einer Abweichung neu. Bis 0.8.x genuegte der Name des Schemas.
function TF.Options.view()
    return TF.Options.scheme() .. (TF.Options.showDead() and "|dead" or "|nodead")
        .. (TF.Options.showExcludes() and "|excludes" or "|noexcludes")
end

-- Was die beiden Anzeige-Optionen beim letzten Abgleich sagten; das Schema
-- merkt sich TF.fmt.useScheme selbst.
local lastShown = nil

--- Gleicht Farbschema und Anzeige mit den Optionen ab. Billig genug fuer
-- jeden Aufbau: ohne Aenderung nur zwei Vergleiche. Fertige Tooltip-Bloecke
-- fallen bei jeder Aenderung weg (useScheme tut das fuers Schema selbst).
function TF.Options.sync()
    if TF.fmt and TF.fmt.useScheme then TF.fmt.useScheme(TF.Options.scheme()) end
    local shown = tostring(TF.Options.showDead()) .. tostring(TF.Options.showExcludes())
    if shown ~= lastShown then
        lastShown = shown
        if TF.Tooltip and TF.Tooltip.forget then TF.Tooltip.forget() end
    end
end

TF.safe("options:create", create)
