-- Trait Facts Measure: Menue-Prueflauf (seit 6.36.0)
--
-- Der Bildschirmlauf (TFMeasureScreen) prueft, wie die Charaktererstellung
-- AUSSIEHT, an neun handgewaehlten Szenarien. Dieser Lauf prueft, ob Trait
-- Facts dort HAELT: jeder Beruf und jeder Trait einmal, Zufalls-Builds durch
-- den Build-Code hin und zurueck, jeder Tooltip gegen die Fenstergroesse, der
-- Controller-Pfad ohne Controller, und ob unsere Hooks ueberhaupt laufen.
--
--   Num 6 in der Charaktererstellung startet und bricht ab (kein F6: das belegt Vanilla)
--   Num 5 dasselbe, danach laeuft von selbst der Bildschirmlauf (wie Num 7)
--   Zomboid/Lua/TraitFacts_menu.txt   das Protokoll
--
-- Zeilen:
--   klick|art|id|ok oder FEHL|was                 jeder Beruf, jeder Trait
--   zufall|nr|ok oder FEHL|code|was               Build hin und zurueck
--   tooltip|liste|id|breite|hoehe|ok oder FEHL    geschaetzt, siehe M.tooltipSize
--   pruef|name|ok oder FEHL|was                   Hooks, Controller, Summen
--   ende|...
--
-- Gearbeitet wird im Takt (OnFETick / OnTick), ein paar Schritte je Bild, wie
-- im Bildschirmlauf; der Tastendruck merkt nur vor.
--
-- Braucht Trait Facts ab 0.12.2 (TraitFacts.Build, TraitFacts.caughtErrors,
-- TraitFacts.hooksNeverRun). Was fehlt, steht als "entfaellt" im Protokoll.

TFMeasureMenu = TFMeasureMenu or {}
local M = TFMeasureMenu

M.LOGFILE = "TraitFacts_menu.txt"
M.PER_TICK = 3          -- Schritte je Bild
M.RANDOM_BUILDS = 100
M.RANDOM_TRAITS = 8     -- Versuche je Zufalls-Build; was sich ausschliesst, faellt weg
M.TOOLTIP_MARGIN = 40   -- so viel Rand braucht ein Tooltip zum Fenster

local function log(text)
    if TFMeasure and TFMeasure.melde then return TFMeasure.melde("[TraitFactsMeasure] Menue:", text) end
    print("[TraitFactsMeasure] Menue: " .. tostring(text))
end

local function TFX() return TraitFacts end

local function version()
    return (TFMeasure and TFMeasure.VERSION) or (TFMeasureScreen and TFMeasureScreen.VERSION) or "?"
end

function M.screen()
    if TFMeasureScreen and TFMeasureScreen.screen then return TFMeasureScreen.screen() end
    return nil
end

--- Kennung eines Berufs oder Traits, wie Trait Facts sie im Build-Code fuehrt.
local function idOf(def)
    if not def then return nil end
    local tf = TFX()
    local id = tf and tf.traitId and tf.traitId(def)
    if id then return id end
    local ok, name = pcall(function() return def:getType():getName() end)
    if ok and name then return "base:" .. string.lower(tostring(name)) end
    return nil
end

local function idsOf(list)
    local out = {}
    for _, item in ipairs((list and list.items) or {}) do
        local id = item and item.item and idOf(item.item)
        if id then out[#out + 1] = id end
    end
    return out
end

local function indexOf(list, id)
    for index, item in ipairs((list and list.items) or {}) do
        if item and item.item and idOf(item.item) == id then return index end
    end
    return nil
end

--- Was TF.safe seit dem Start abgefangen hat, als Menge.
local function caught()
    local tf, set = TFX(), {}
    if tf and tf.caughtErrors then
        for _, key in ipairs(tf.caughtErrors()) do set[key] = true end
    end
    return set
end

--- Neue Eintraege von `after` gegenueber `before`, als Text; "" ohne.
local function newErrors(before, after)
    local out = {}
    for key in pairs(after) do
        if not before[key] then out[#out + 1] = key end
    end
    table.sort(out)
    return table.concat(out, ", ")
end

local function selectProf(screen, id)
    local index = indexOf(screen.listboxProf, id)
    if not index then return false end
    screen.listboxProf.selected = index
    screen:onSelectProf(screen:getSelectedProf())
    return true
end

--- Fuegt einen Trait hinzu wie ein Klick auf "Add". @return boolean  steht er danach bei den gewaehlten
local function addTrait(screen, id)
    if indexOf(screen.listboxTraitSelected, id) then return true end
    local lists = {
        { box = screen.listboxTrait, internal = "ADDTRAIT", button = screen.addTraitBtn },
        { box = screen.listboxBadTrait, internal = "ADDBADTRAIT", button = screen.addBadTraitBtn },
    }
    for _, entry in ipairs(lists) do
        local index = indexOf(entry.box, id)
        if index then
            entry.box.selected = index
            screen:onOptionMouseDown(entry.button or { internal = entry.internal })
            return indexOf(screen.listboxTraitSelected, id) ~= nil
        end
    end
    return false
end

local function summaryText(screen)
    local panel = screen.tfSummary
    return panel and type(panel.text) == "string" and panel.text or nil
end

-- ---------------------------------------------------------------- Schritte

local STEP = {}

--- Hooks: laufen die, die jede offene Charaktererstellung durchlaeuft?
function STEP.hooks(run, screen)
    local tf = TFX()
    if not (tf and tf.hooksNeverRun) then
        return run:line("entfaellt|hooks|Trait Facts fehlt oder ist aelter als 0.12.2")
    end
    local never = tf.hooksNeverRun()
    run:check("hooks-laufen", #never == 0,
        (#never == 0) and "alle Hooks der Charaktererstellung liefen"
        or ("nie gelaufen (von einem anderen Mod ersetzt?): " .. table.concat(never, ", ")))
    local vorher = tf.caughtErrors and tf.caughtErrors() or {}
    run:check("fehler-vor-dem-lauf", #vorher == 0,
        (#vorher == 0) and "nichts abgefangen" or (#vorher .. " abgefangen: " .. table.concat(vorher, ", ")))
end

--- Ein Beruf: waehlen, dann muss er gewaehlt sein, die Uebersicht stehen und nichts abgefangen sein.
function STEP.prof(run, screen, step)
    local before = caught()
    screen:resetBuild()
    local ok = selectProf(screen, step.id)
    if screen.checkXPBoost then screen:checkXPBoost() end
    local jetzt = idOf(screen:getSelectedProf())
    local neu = newErrors(before, caught())
    local leck = run.leak(summaryText(screen))
    local gut = ok and jetzt == step.id and neu == "" and (not TFX() or summaryText(screen) ~= nil) and not leck
    run:click("beruf", step.id, gut, (leck and ("unuebersetzt: " .. leck)) or (not ok and "nicht in der Liste")
        or (jetzt ~= step.id and ("gewaehlt ist " .. tostring(jetzt)))
        or (neu ~= "" and ("abgefangen: " .. neu)) or "")
end

--- Ein Trait: von einem leeren Build aus hinzufuegen.
function STEP.trait(run, screen, step)
    local before = caught()
    screen:resetBuild()
    local punkteVorher = screen.pointToSpend
    local ok = addTrait(screen, step.id)
    if screen.checkXPBoost then screen:checkXPBoost() end
    local neu = newErrors(before, caught())
    local text = summaryText(screen)
    local leck = run.leak(text)
    local gut = ok and neu == "" and (not TFX() or text ~= nil) and not leck
    local was = (leck and ("unuebersetzt: " .. leck)) or (not ok and "liess sich nicht hinzufuegen")
        or (neu ~= "" and ("abgefangen: " .. neu)) or ""
    -- Kein Fehler, aber wissenswert: ein Trait, zu dem Trait Facts nichts zeigt.
    if gut and TFX() and text == "" then was = "Uebersicht leer" end
    if gut and type(punkteVorher) == "number" and screen.pointToSpend == punkteVorher then
        was = (was ~= "" and (was .. "; ") or "") .. "Punkte unveraendert"
    end
    run:click("trait", step.id, gut, was)
end

--- Ein Zufalls-Build: exportieren, lesen, setzen, wieder exportieren.
function STEP.zufall(run, screen, step)
    local tf = TFX()
    if not (tf and tf.Build and tf.Build.export and tf.Build.parse and tf.Build.apply) then
        if step.nr == 1 then run:line("entfaellt|zufall|Trait Facts fehlt oder hat keinen Build-Code") end
        return
    end
    local before = caught()
    screen:resetBuild()
    if #run.profs > 0 then selectProf(screen, run.profs[ZombRand(#run.profs) + 1]) end
    for _ = 1, M.RANDOM_TRAITS do
        -- Jedes Mal aus den Listen, wie sie jetzt sind: was sich ausschliesst, steht nicht mehr drin.
        local pool = idsOf(screen.listboxTrait)
        for _, id in ipairs(idsOf(screen.listboxBadTrait)) do pool[#pool + 1] = id end
        if #pool == 0 then break end
        addTrait(screen, pool[ZombRand(#pool) + 1])
    end
    local code1 = tf.Build.export(screen)
    local build, reason = tf.Build.parse(code1, screen)
    local was, code2 = "", nil
    if not build then
        was = "nicht lesbar: " .. tostring(reason)
    else
        local result = tf.Build.apply(screen, build)
        code2 = tf.Build.export(screen)
        if code2 ~= code1 then
            was = "nach dem Einfuegen anders: " .. tostring(code2)
            -- Ein einseitig erklaerter Ausschluss (seit 6.40.2): das Spiel traegt einen
            -- Ausschluss aus einem Skript nur beim erklaerenden Trait ein
            -- (CharacterTraitDefinition.addMutuallyExclusive, ohne den Abgleich von
            -- setMutualExclusive). Restful Sleeper aus More Traits schliesst Insomniac aus,
            -- Insomniac aber nicht Restful Sleeper: von Hand gehen beide, je nach
            -- Reihenfolge der Klicks, und beim Einfuegen laesst Vanilla einen weg. Das ist
            -- kein Fehler des Build-Codes; es steht als Hinweis da, nicht als FEHL.
            local grund = M.oneSided(screen, build)
            if grund then
                run.einseitig = run.einseitig or {}
                run.einseitig[grund] = true
                was = ""
            end
        elseif result and ((result.missing and #result.missing > 0) or (result.unknown or 0) > 0) then
            was = "als fehlend gemeldet: " .. table.concat(result.missing or {}, ",")
        end
    end
    local neu = newErrors(before, caught())
    if neu ~= "" then was = (was ~= "" and (was .. "; ") or "") .. "abgefangen: " .. neu end
    run.longest = math.max(run.longest or 0, #tostring(code1))
    run:random(step.nr, was == "", tostring(code1), was)
end

--- Fehlt nach dem Einfuegen genau das, was ein gewaehlter Trait einseitig
-- ausschliesst? @return string|nil  "verloren gegen gewaehlt", sonst nil
function M.oneSided(screen, build)
    local byId = {}
    pcall(function()
        local all = CharacterTraitDefinition.getTraits()
        for i = 0, all:size() - 1 do
            local def = all:get(i)
            local id = idOf(def)
            if id then byId[id] = def end
        end
    end)
    local gruende = {}
    for _, id in ipairs(build.traits or {}) do
        if string.sub(id, 1, 1) ~= "?" and not indexOf(screen.listboxTraitSelected, id) then
            local def, grund = byId[id], nil
            for _, item in ipairs(screen.listboxTraitSelected.items or {}) do
                local other = item.item
                local ok, aus = pcall(function()
                    return def:isMutuallyExclusive(other) or other:isMutuallyExclusive(def)
                end)
                if def and other and ok and aus then grund = id .. " gegen " .. tostring(idOf(other)) end
            end
            if not grund then return nil end
            gruende[#gruende + 1] = grund
        end
    end
    if #gruende == 0 then return nil end
    return table.concat(gruende, ", ")
end

--- Breite und Hoehe eines Tooltip-Textes, geschaetzt wie ISToolTip sie setzt:
-- das Panel wird so breit wie seine breiteste Zeile (layoutContents: lineX
-- plus gemessene Breite), und die Listen setzen maxLineWidth auf 1000.
function M.tooltipSize(text)
    if not (ISRichTextPanel and type(text) == "string" and text ~= "") then return nil end
    local panel = ISRichTextPanel:new(0, 0, 1000, 10)
    panel.autosetheight = true
    panel.maxLineWidth = 1000
    panel:setMargins(10, 10, 10, 10)
    panel:setText(text)
    panel:paginate()
    local breite, unten = 0, 0
    local tm = getTextManager()
    if not (tm and tm.MeasureStringX) then return nil end
    for i, line in pairs(panel.lines or {}) do
        if type(line) == "string" and panel.lineX and panel.lineX[i] then
            local w = panel.lineX[i] + tm:MeasureStringX(panel.font or UIFont.Small, line)
            if w > breite then breite = w end
        end
        if panel.lineY and type(panel.lineY[i]) == "number" and panel.lineY[i] > unten then unten = panel.lineY[i] end
    end
    -- Die Hoehe aus der untersten Zeile plus Schrifthoehe und Raender. Bis 6.36.0
    -- aus getScrollHeight: ein Panel, das nirgends eingehaengt ist, liefert dort 0,
    -- und der erste Lauf im Spiel (20.09.2026) pruefte darum nur die Breite ("883x0").
    local zeile = 19
    pcall(function() zeile = tm:getFontHeight(panel.font or UIFont.Small) end)
    return breite + 20, unten + zeile + 20
end

--- Alle Tooltips aller Listen gegen die jetzige Fenstergroesse, ohne Lauf und
-- ohne Protokoll: fuer den Bildschirmlauf, der die Aufloesungen selbst
-- wechselt (seit 6.36.2; Wunsch 20.09.2026: "kann das der Mod nicht selbst?").
-- @return table  { zahl, zuGross, hoechster = {id,w,h}, breitester = {id,w,h}, liste = { "id WxH", ... } }
function M.tooltipReport(screen)
    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    local out = { zahl = 0, zuGross = 0, liste = {} }
    for _, name in ipairs({ "listboxTrait", "listboxBadTrait", "listboxProf" }) do
        local list = screen[name]
        for _, item in ipairs((list and list.items) or {}) do
            local id = item.item and idOf(item.item)
            local ok, breite, hoehe = pcall(M.tooltipSize, item.tooltip)
            if id and ok and breite then
                out.zahl = out.zahl + 1
                if hoehe > (out.hoechster and out.hoechster.h or 0) then out.hoechster = { id = id, w = breite, h = hoehe } end
                if breite > (out.breitester and out.breitester.w or 0) then out.breitester = { id = id, w = breite, h = hoehe } end
                if breite > sw - M.TOOLTIP_MARGIN or hoehe > sh - M.TOOLTIP_MARGIN then
                    out.zuGross = out.zuGross + 1
                    if #out.liste < 12 then
                        out.liste[#out.liste + 1] = string.format("%s %dx%d", id, math.floor(breite), math.floor(hoehe))
                    end
                end
            end
        end
    end
    return out
end

--- Alle Tooltips einer Liste gegen die Fenstergroesse.
function STEP.tooltips(run, screen, step)
    screen:resetBuild()
    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    local list = screen[step.list]
    local zahl, zuGross = 0, 0
    for _, item in ipairs((list and list.items) or {}) do
        local id = item.item and idOf(item.item)
        local ok, breite, hoehe = pcall(M.tooltipSize, item.tooltip)
        local leck = id and run.leak(item.tooltip)
        if leck then
            run:line("tooltip|" .. step.list .. "|" .. id .. "|-|-|FEHL|unuebersetzt: " .. leck)
            run.failed = run.failed + 1
        end
        if id and ok and breite then
            zahl = zahl + 1
            local passt = breite <= sw - M.TOOLTIP_MARGIN and hoehe <= sh - M.TOOLTIP_MARGIN
            if not passt then zuGross = zuGross + 1 end
            if hoehe > (run.tallest and run.tallest.h or 0) then run.tallest = { id = id, w = breite, h = hoehe } end
            if breite > (run.widest and run.widest.w or 0) then run.widest = { id = id, w = breite, h = hoehe } end
            if not passt then
                run:line(string.format("tooltip|%s|%s|%d|%d|FEHL", step.list, id, math.floor(breite), math.floor(hoehe)))
                run.failed = run.failed + 1
            end
        elseif id and not ok then
            run:line("tooltip|" .. step.list .. "|" .. id .. "|-|-|FEHL|" .. tostring(breite))
            run.failed = run.failed + 1
        end
    end
    run:check("tooltips-" .. step.list, zuGross == 0,
        string.format("%d Tooltips, %d passen nicht in %dx%d", zahl, zuGross, sw, sh))
    -- Ein Test, der nichts misst, soll das sagen statt "ok".
    if zahl > 0 and (not run.tallest or run.tallest.h <= 20) then
        run:check("tooltips-hoehe-gemessen", false, "keine Hoehe lesbar, geprueft ist nur die Breite")
    end
end

--- Der Controller-Pfad ohne Controller: ein angeschlossenes Pad vortaeuschen,
-- einer Trait-Liste den Fokus geben, dann muss die Uebersicht den Block dieses
-- Traits zeigen statt der Uebersicht, und danach wieder die Uebersicht.
function STEP.controller(run, screen)
    local tf = TFX()
    if not (tf and tf.Panel and tf.Panel.refresh and tf.Panel.focusTrait and JoypadState) then
        return run:line("entfaellt|controller|Trait Facts oder JoypadState fehlt")
    end
    screen:resetBuild()
    local list = screen.listboxTrait
    if not (list and list.items and #list.items > 0) then
        return run:line("entfaellt|controller|keine Traits in der Liste")
    end
    local before = caught()
    local alt, altFokus, altWahl = JoypadState.getMainMenuJoypad, list.joyfocus, list.selected
    local ok, err = pcall(function()
        JoypadState.getMainMenuJoypad = function() return { isConnected = function() return true end } end
        list.selected = 1
        list.joyfocus = true
        tf.Panel.refresh(screen)
        local def = list.items[1].item
        local label = tostring(def:getLabel())
        local text = summaryText(screen) or ""
        run:check("controller-fokus", string.find(text, label, 1, true) ~= nil
            and screen.tfSummary.tfFocusId == idOf(def),
            "Fokus auf " .. tostring(idOf(def)) .. ": das Panel zeigt " .. (string.find(text, label, 1, true)
                and "seinen Block" or "etwas anderes"))
        list.joyfocus = false
        tf.Panel.refresh(screen)
        run:check("controller-zurueck", screen.tfSummary.tfFocusId == nil, "ohne Fokus wieder die Uebersicht")
    end)
    JoypadState.getMainMenuJoypad = alt
    list.joyfocus, list.selected = altFokus, altWahl
    pcall(tf.Panel.refresh, screen)
    if not ok then run:check("controller-fokus", false, "Fehler: " .. tostring(err)) end
    local neu = newErrors(before, caught())
    run:check("controller-ohne-fehler", neu == "", (neu == "") and "nichts abgefangen" or ("abgefangen: " .. neu))
end

-- ---------------------------------------------------------------- Abnahme
--
-- Seit 6.40.0: was bis dahin von Hand abzuhaken war (Abschlusstest, Bloecke
-- Paket, Hinweise, Anzeige), prueft der Lauf selbst. Jede Pruefung liest den
-- Zustand, den Trait Facts im Spiel wirklich hat; gezeichnet wird nichts.

--- Ein Beruf oder Trait aus den Listen des Bildschirms, nach Kennung.
local function defOf(screen, id)
    for _, name in ipairs({ "listboxProf", "listboxTrait", "listboxBadTrait", "listboxTraitSelected" }) do
        local list = screen[name]
        local index = indexOf(list, id)
        if index then return list.items[index].item end
    end
    return nil
end

local function count(text, needle)
    local n, at = 0, 1
    while true do
        local a, b = string.find(text, needle, at, true)
        if not a then return n end
        n, at = n + 1, b + 1
    end
end

--- Paket: laeuft die Fassung aus mod.info, woher, und sind alle Symbole da?
function STEP.paket(run, screen)
    local tf = TFX()
    if not tf then return run:line("entfaellt|paket|Trait Facts fehlt") end
    local ok, info = pcall(function() return getModInfoByID("TraitFacts") end)
    if not (ok and info) then ok, info = pcall(function() return getModInfoByID("\\TraitFacts") end) end
    local fassung, ordner = nil, nil
    if ok and info then
        pcall(function() fassung = tostring(info:getModVersion()) end)
        pcall(function() ordner = tostring(info:getDir()) end)
    end
    run:check("paket-fassung", fassung == tostring(tf.VERSION),
        "mod.info " .. tostring(fassung) .. ", TF.VERSION " .. tostring(tf.VERSION))
    local woher = "unbekannt"
    if ordner then
        local klein = string.lower(ordner)
        if string.find(klein, "steamapps", 1, true) then woher = "steam"
        elseif string.find(klein, "workshop", 1, true) then woher = "workshop-paket"
        else woher = "entwicklung" end
    end
    run.woher = woher
    run:line("wert|paket-quelle|" .. woher .. "|" .. tostring(ordner))
    for _, pfad in ipairs({ "media/ui/TraitFacts/tf_copy.png", "media/ui/TraitFacts/tf_paste.png",
                            "media/ui/TraitFacts/tf_arrow_on.png", "media/ui/TraitFacts/tf_arrow_off.png",
                            -- seit Trait Facts 0.12.11: die Symbole der Hinweise
                            "media/ui/TraitFacts/tf_toast_ok.png", "media/ui/TraitFacts/tf_toast_warn.png",
                            "media/ui/TraitFacts/tf_toast_error.png", "media/ui/TraitFacts/tf_toast_info.png",
                            "media/ui/TraitFacts/tf_toast_ask.png" }) do
        local da = false
        pcall(function() da = getTexture(pfad) ~= nil end)
        run:check("paket-bild-" .. string.match(pfad, "([^/]+)%.png$"), da, da and "geladen" or "fehlt")
    end
    -- Die Knoepfe haengen am Bildschirm, nicht am Panel (ensureButtons(self) in create;
    -- 6.40.0 sah am Panel nach und meldete vier Knoepfe als fehlend).
    for _, name in ipairs({ "tfGearButton", "tfBugButton", "tfCopyButton", "tfPasteButton" }) do
        local b = screen[name]
        run:check("kopfzeile-" .. name, b ~= nil and b.image ~= nil,
            (not b and "Knopf fehlt") or (b.image and "Knopf mit Symbol") or "Knopf ohne Symbol (weisses Quadrat)")
    end
end

--- Hinweise: Kopieren, Einfuegen, halber Code, kein Code, Phantom-Mod. Immer
-- von einem leeren Build aus, dann fragt Trait Facts nicht nach.
function STEP.hinweise(run, screen)
    local tf = TFX()
    if not (tf and tf.Build and tf.Build.copy and tf.Build.paste and Clipboard and Clipboard.getClipboard) then
        return run:line("entfaellt|hinweise|Trait Facts, Build-Code oder Zwischenablage fehlt")
    end
    local vorher = nil
    pcall(function() vorher = Clipboard.getClipboard() end)
    local before = caught()
    local function art() return screen.tfToast and screen.tfToast.tfKind or nil end
    local function waehle(reihenfolge)
        screen:resetBuild()
        selectProf(screen, "base:fireofficer")
        for _, id in ipairs(reihenfolge) do addTrait(screen, id) end
    end

    waehle({ "base:strong", "base:brave" })
    local code = tf.Build.copy(screen)
    local inAblage = nil
    pcall(function() inAblage = Clipboard.getClipboard() end)
    run:check("hinweis-kopieren", code ~= nil and inAblage == code and art() == "ok",
        "Code " .. tostring(code) .. ", Hinweis " .. tostring(art()))
    waehle({ "base:brave", "base:strong" })
    local anders = tf.Build.export(screen)
    run:check("code-reihenfolge-egal", code ~= nil and anders == code, tostring(code) .. " / " .. tostring(anders))

    if code then
        screen:resetBuild()
        Clipboard.setClipboard(code)
        tf.Build.paste(screen)
        run:check("hinweis-einfuegen", tf.Build.export(screen) == code and art() == "ok",
            "danach " .. tostring(tf.Build.export(screen)) .. ", Hinweis " .. tostring(art()))

        -- Der halbe Code: der Beruf und ein Stueck, das sich nicht lesen laesst.
        screen:resetBuild()
        Clipboard.setClipboard(string.sub(code, 1, #code - 4))
        tf.Build.paste(screen)
        run:check("hinweis-halber-code", art() == "warn" and idOf(screen:getSelectedProf()) == "base:fireofficer",
            string.sub(code, 1, #code - 4) .. ": Hinweis " .. tostring(art()) .. ", Beruf "
                .. tostring(idOf(screen:getSelectedProf())))
        if tf.Build.closeMissing then pcall(tf.Build.closeMissing, screen) end

        waehle({ "base:strong" })
        local stand = tf.Build.export(screen)
        -- Ein Satz ist kein Build; gefragt wird davor nie, die Auswahl bleibt.
        Clipboard.setClipboard("Das ist kein Build.")
        tf.Build.paste(screen)
        run:check("hinweis-kein-code", art() == "error" and tf.Build.export(screen) == stand,
            "Hinweis " .. tostring(art()) .. ", Auswahl " .. (tf.Build.export(screen) == stand and "unveraendert" or "veraendert"))

        screen:resetBuild()
        Clipboard.setClipboard(code .. "(tfmessphantom:bar)")
        tf.Build.paste(screen)
        local phantom = tf.Mods and tf.Mods.modCache and tf.Mods.modCache.tfmessphantom ~= nil
        run:check("kein-phantom-mod", not phantom,
            phantom and "tfmessphantom steht im Mod-Speicher" or "der Mod-Speicher bleibt sauber")
        if tf.Build.closeMissing then pcall(tf.Build.closeMissing, screen) end
    end
    if screen.tfToast and screen.tfToast.setVisible then screen.tfToast:setVisible(false) end
    pcall(function() Clipboard.setClipboard(vorher or "") end)
    screen:resetBuild()
    local neu = newErrors(before, caught())
    run:check("hinweise-ohne-fehler", neu == "", (neu == "") and "nichts abgefangen" or ("abgefangen: " .. neu))
end

--- Anzeige: die Spannen von Adrenaline Junkie, die Zeile zur leichten Kaelte.
function STEP.anzeige(run, screen)
    local tf = TFX()
    if not (tf and tf.buildBlock and tf.fmt and tf.fmt.value and tf.KINDS and tf.KINDS.pctrange) then
        return run:line("entfaellt|anzeige|Trait Facts fehlt oder ist aelter als 0.12.6")
    end
    local aj = defOf(screen, "base:adrenalinejunkie")
    if aj then
        local block = tostring(tf.buildBlock(aj) or "")
        -- Spannen wie in TF_Static seit Trait Facts 0.13.6.
        local rennen, sprint = tf.fmt.value("pctrange", { 12, 17 }), tf.fmt.value("pctrange", { 10, 15 })
        local beide = string.find(block, rennen, 1, true) ~= nil and string.find(block, sprint, 1, true) ~= nil
        local _, farbe = tf.Summary.valueCell("UI_TF_eff_panicrun", "pctrange", { 12, 17 }, rennen)
        run:check("spannen-adrenaline", beide and string.sub(rennen, 1, 1) == "+" and farbe == "good",
            rennen .. " und " .. sprint .. (beide and " stehen im Block" or " FEHLEN im Block") .. ", Farbe " .. tostring(farbe))
    else
        run:line("entfaellt|spannen-adrenaline|Adrenaline Junkie steht in keiner Liste")
    end
    -- Spielfarben (seit Trait Facts 0.12.14): steht eine Hervorhebungsfarbe des Spiels
    -- auf ihrer Vorgabe, gilt unser gedaempfter Ton, sonst genau die Farbe des Spielers.
    local gelesen, farben = pcall(function()
        local core = getCore()
        local g, b = core:getGoodHighlitedColor(), core:getBadHighlitedColor()
        return { good = { g:getR(), g:getG(), g:getB() }, bad = { b:getR(), b:getG(), b:getB() } }
    end)
    if gelesen and farben and tf.fmt.gameScheme and tf.fmt.rgb then
        local VORGABE = { good = { 0, 1, 0 }, bad = { 1, 0, 0 } }
        local UNSER = { good = { 0.45, 0.72, 0.48 }, bad = { 0.82, 0.50, 0.47 } }
        local function gleich(a, b)
            return math.abs(a[1] - b[1]) < 0.006 and math.abs(a[2] - b[2]) < 0.006 and math.abs(a[3] - b[3]) < 0.006
        end
        local teile, gut = {}, true
        for _, key in ipairs({ "good", "bad" }) do
            local geaendert = not gleich(farben[key], VORGABE[key])
            local soll = geaendert and farben[key] or UNSER[key]
            local ist = tf.fmt.rgb[key]
            if not gleich(ist, soll) then gut = false end
            teile[#teile + 1] = string.format("%s %s: %.2f,%.2f,%.2f", key, geaendert and "vom Spieler" or "Vorgabe",
                ist[1], ist[2], ist[3])
        end
        run:check("spielfarben", gut, table.concat(teile, "; ") .. ", Schema " .. tostring(tf.fmt.scheme))
    else
        run:line("entfaellt|spielfarben|Trait Facts aelter als 0.12.14 oder das Spiel nennt die Farben nicht")
    end
    screen:resetBuild()
    if addTrait(screen, "base:resilient") and addTrait(screen, "base:outdoorsman") then
        if tf.Panel and tf.Panel.refresh then pcall(tf.Panel.refresh, screen) end
        local zeile = tf.fmt.text("UI_TF_eff_coldmild")
        local n = count(summaryText(screen) or "", zeile)
        run:check("leichte-kaelte-eine-zeile", n == 1 and string.sub(zeile, 1, 6) ~= "UI_TF_",
            "\"" .. zeile .. "\" steht " .. n .. " mal in der Uebersicht")
    else
        run:line("entfaellt|leichte-kaelte|Resilient oder Outdoorsy liess sich nicht waehlen")
    end
    screen:resetBuild()
end

--- Optionskarte: der blaue Rahmen folgt dem Haekchen, die Karte bleibt im Bild.
function STEP.optionskarte(run, screen)
    local tf = TFX()
    if not (tf and tf.OptionInfo and tf.OptionInfo.show and tf.OptionInfo.hide and tf.OptionInfo.ITEMS) then
        return run:line("entfaellt|optionskarte|Trait Facts fehlt oder hat keine Optionskarte")
    end
    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    local owner = { itemHgt = 20, tfMess = true,
        getAbsoluteX = function() return sw - 260 end, getAbsoluteY = function() return 200 end,
        getWidth = function() return 240 end, getHeight = function() return 20 end,
        isReallyVisible = function() return true end, isMouseOver = function() return true end,
        mouseOverOption = 1 }
    local before = caught()
    for id in pairs(tf.OptionInfo.ITEMS) do
        local an = tf.OptionInfo.show(id, owner, 1, true)
        local rahmenAn = an and an.tfCurrent
        local aus = tf.OptionInfo.show(id, owner, 1, false)
        local rahmenAus = aus and aus.tfCurrent
        local imBild = aus ~= nil and aus:getX() >= 0 and aus:getY() >= 0
            and aus:getX() + aus:getWidth() <= sw and aus:getY() + aus:getHeight() <= sh
        run:check("optionskarte-" .. tostring(id), rahmenAn == 2 and rahmenAus == 1 and imBild,
            "Haken an: Rahmen " .. tostring(rahmenAn) .. ", Haken aus: Rahmen " .. tostring(rahmenAus)
                .. (imBild and ", Karte im Bild" or ", Karte ragt aus dem Bild"))
    end
    pcall(tf.OptionInfo.hide)
    local neu = newErrors(before, caught())
    run:check("optionskarte-ohne-fehler", neu == "", (neu == "") and "nichts abgefangen" or ("abgefangen: " .. neu))
end

--- Startskill-Liste, erster Halbschritt: Beruf waehlen und ein Bild warten,
-- damit Trait Facts die Spalten fuer genau diese Liste rechnet.
function STEP.skillsWahl(run, screen, step)
    screen:resetBuild()
    selectProf(screen, step.id)
    if screen.checkXPBoost then screen:checkXPBoost() end
    if screen.listboxXpBoost then screen.listboxXpBoost.tfCols = nil end
    return "warten"
end

--- Zweiter Halbschritt: kein Skill-Name reicht in die Herkunftsspalte, die
-- Herkunft endet vor dem rechten Rand.
function STEP.skillsPruef(run, screen, step)
    local tf = TFX()
    local list = screen.listboxXpBoost
    local cols = list and list.tfCols
    if not (tf and tf.fmt and tf.fmt.kuerze and list) then
        if not run.skillsEntfaellt then
            run.skillsEntfaellt = true
            run.skillsGeplant = false
            run:line("entfaellt|startskills|Trait Facts fehlt oder ist aelter als 0.12.8")
        end
        return
    end
    if not cols or not cols.labelW then return end -- leere Liste, nichts gezeichnet
    local font = UIFont.Small
    local schlecht = {}
    for _, item in ipairs(list.items or {}) do
        if type(item.item) == "table" then
            local name = tostring(item.text)
            local kurz = tf.fmt.kuerze(name, cols.labelW, font)
            local ende = cols.label + tf.fmt.measure(kurz, font)
            if kurz ~= name then
                run.gekuerzt = run.gekuerzt or {}
                run.gekuerzt[name] = kurz
            end
            if ende > cols.source or kurz == "..." then schlecht[#schlecht + 1] = name end
        end
    end
    local rechts = cols.source + (cols.sourceW or 0)
    if rechts > list.width then schlecht[#schlecht + 1] = "Herkunft bis " .. math.floor(rechts) .. " von " .. list.width end
    run.skillsGeprueft = (run.skillsGeprueft or 0) + 1
    if #schlecht > 0 then
        run.skillsSchlecht = (run.skillsSchlecht or 0) + 1
        run:line("startskills|" .. step.id .. "|FEHL|" .. table.concat(schlecht, ", "))
    end
end

--- Schluessel statt Text: steht irgendwo "UI_TF_", fehlt eine Uebersetzung.
local function leak(text)
    return type(text) == "string" and string.match(text, "UI_TF_[%w_]+") or nil
end

-- ---------------------------------------------------------------- Ablauf

local function newRun(writer)
    local run = { writer = writer, passed = 0, failed = 0, clicks = 0, randoms = 0, steps = {}, index = 0,
                  leak = leak }
    function run:line(text)
        pcall(function() self.writer:write(text .. "\r\n") end)
    end
    function run:check(name, ok, was)
        if ok then self.passed = self.passed + 1 else self.failed = self.failed + 1 end
        self:line("pruef|" .. name .. "|" .. (ok and "ok" or "FEHL") .. "|" .. tostring(was or ""))
    end
    function run:click(art, id, ok, was)
        self.clicks = self.clicks + 1
        if ok then self.passed = self.passed + 1 else self.failed = self.failed + 1 end
        -- Jeder Klick steht im Protokoll: wer wissen will, ob ein Trait dran war, findet ihn.
        self:line("klick|" .. art .. "|" .. tostring(id) .. "|" .. (ok and "ok" or "FEHL") .. "|" .. tostring(was or ""))
    end
    function run:random(nr, ok, code, was)
        self.randoms = self.randoms + 1
        if ok then self.passed = self.passed + 1 else self.failed = self.failed + 1 end
        self:line("zufall|" .. nr .. "|" .. (ok and "ok" or "FEHL") .. "|" .. code .. "|" .. tostring(was or ""))
    end
    return run
end

function M.start()
    if M.run then return M.finish("abgebrochen (von Hand)") end
    local screen = M.screen()
    if not screen then
        log("bitte zuerst die Charaktererstellung oeffnen (Beruf und Traits), dann Num 6.")
        return
    end
    local tf = TFX()
    local writer = getFileWriter(M.LOGFILE, true, false)
    local run = newRun(writer)
    run:line("# Trait Facts Menue-Prueflauf, Mess-Mod " .. version() .. ", Trait Facts "
        .. tostring(tf and tf.VERSION or "fehlt") .. ", Spiel " .. tostring(getCore():getVersion()))
    run:line("# klick|art|id|urteil|was; zufall|nr|urteil|code|was; tooltip|liste|id|breite|hoehe|urteil; pruef|name|urteil|was")
    -- Welche Mods an sind, gehoert zum Befund: "0 FEHL" sagt nur etwas ueber genau diese.
    local mods = {}
    pcall(function()
        local aktiv = getActivatedMods()
        for i = 0, aktiv:size() - 1 do mods[#mods + 1] = tostring(aktiv:get(i)) end
    end)
    run:line("wert|mods|" .. #mods .. "|" .. table.concat(mods, ", "))
    screen:resetBuild()
    run.profs = idsOf(screen.listboxProf)
    local traits = idsOf(screen.listboxTrait)
    for _, id in ipairs(idsOf(screen.listboxBadTrait)) do traits[#traits + 1] = id end
    run.steps[#run.steps + 1] = { kind = "hooks" }
    run.steps[#run.steps + 1] = { kind = "paket" }
    run.steps[#run.steps + 1] = { kind = "hinweise" }
    run.steps[#run.steps + 1] = { kind = "anzeige" }
    run.steps[#run.steps + 1] = { kind = "optionskarte" }
    run.skillsGeplant = true
    for _, id in ipairs(run.profs) do
        run.steps[#run.steps + 1] = { kind = "skillsWahl", id = id }
        run.steps[#run.steps + 1] = { kind = "skillsPruef", id = id }
    end
    for _, id in ipairs(run.profs) do run.steps[#run.steps + 1] = { kind = "prof", id = id } end
    for _, id in ipairs(traits) do run.steps[#run.steps + 1] = { kind = "trait", id = id } end
    for nr = 1, M.RANDOM_BUILDS do run.steps[#run.steps + 1] = { kind = "zufall", nr = nr } end
    for _, list in ipairs({ "listboxTrait", "listboxBadTrait", "listboxProf" }) do
        run.steps[#run.steps + 1] = { kind = "tooltips", list = list }
    end
    run.steps[#run.steps + 1] = { kind = "controller" }
    run:line(string.format("# %d Berufe, %d Traits, %d Zufalls-Builds", #run.profs, #traits, M.RANDOM_BUILDS))
    M.run = run
    log("Lauf gestartet: " .. #run.steps .. " Schritte. Dieselbe Taste bricht ab.")
end

function M.finish(reason)
    local run = M.run
    if not run then return end
    M.run = nil
    if run.tallest then
        run:line(string.format("wert|hoechster-tooltip|%s|%dx%d", run.tallest.id, math.floor(run.tallest.w), math.floor(run.tallest.h)))
    end
    if run.widest then
        run:line(string.format("wert|breitester-tooltip|%s|%dx%d", run.widest.id, math.floor(run.widest.w), math.floor(run.widest.h)))
    end
    if run.longest then run:line("wert|laengster-build-code|" .. run.longest .. " Zeichen") end
    local einseitig = {}
    for grund in pairs(run.einseitig or {}) do einseitig[#einseitig + 1] = grund end
    table.sort(einseitig)
    if #einseitig > 0 then
        run:line("hinweis|einseitiger-ausschluss|" .. #einseitig .. "|" .. table.concat(einseitig, "; "))
    end
    if run.skillsGeplant then
        -- Ohne ein einziges gezeichnetes Bild waere "0 schlecht" kein Befund.
        run:check("startskills-spalten", (run.skillsGeprueft or 0) > 0 and (run.skillsSchlecht or 0) == 0,
            string.format("%d Berufe mit Startskills geprueft, bei %d liegt ein Name ueber der Herkunft",
                run.skillsGeprueft or 0, run.skillsSchlecht or 0))
        local namen = {}
        for name, kurz in pairs(run.gekuerzt or {}) do namen[#namen + 1] = name .. " -> " .. kurz end
        table.sort(namen)
        run:line("wert|gekuerzte-skillnamen|" .. #namen .. "|" .. table.concat(namen, "; "))
    end
    local sprache = "?"
    pcall(function() sprache = tostring(Translator.getLanguage()) end)
    local schrift = "?"
    if TFMeasureScreen and TFMeasureScreen.fontLabel then
        pcall(function() schrift = TFMeasureScreen.fontLabel() end)
    else
        pcall(function() schrift = tostring(getCore():getOptionFontSizeReal()) end)
    end
    run:line("wert|umgebung|sprache=" .. sprache .. "|schrift=" .. schrift .. "|fenster="
        .. getCore():getScreenWidth() .. "x" .. getCore():getScreenHeight() .. "|quelle=" .. tostring(run.woher))
    local summary = string.format("%d Klicks, %d Zufalls-Builds, %d ok, %d FEHL", run.clicks, run.randoms,
        run.passed, run.failed)
    run:line("ende|" .. tostring(reason or "fertig") .. "|" .. summary)
    pcall(function() run.writer:close() end)
    if TFMeasureScreen and TFMeasureScreen.hideProgress then pcall(TFMeasureScreen.hideProgress) end
    local screen = M.screen()
    if screen then pcall(function() screen:resetBuild() end) end
    log("Lauf " .. tostring(reason or "fertig") .. ": " .. summary .. ". Protokoll: Zomboid/Lua/" .. M.LOGFILE)
    local weiter = M.thenScreen and reason == "fertig"
    M.thenScreen = nil
    if weiter and TFMeasureScreen then
        log("weiter mit dem Bildschirmlauf.")
        TFMeasureScreen.wanted = { onlyCurrent = false }
    end
    local tf = TFX()
    if screen and tf and tf.Panel and tf.Panel.showToast then
        pcall(tf.Panel.showToast, screen, "Menu check " .. tostring(reason or "done") .. ": " .. summary,
            run.failed > 0 and "warn" or nil, 8000)
    end
end

function M.pump()
    if M.wanted then
        M.wanted = nil
        M.start()
        return
    end
    local run = M.run
    if not run then return end
    local screen = M.screen()
    if not screen then return M.finish("abgebrochen (die Charaktererstellung ist nicht mehr zu sehen)") end
    for _ = 1, M.PER_TICK do
        run.index = run.index + 1
        local step = run.steps[run.index]
        if not step then return M.finish("fertig") end
        local ok, err = pcall(STEP[step.kind], run, screen, step)
        if not ok then
            run.failed = run.failed + 1
            run:line("fehler|" .. step.kind .. "|" .. tostring(step.id or step.nr or step.list or "")
                .. "|" .. tostring(err))
        elseif err == "warten" then
            -- Der naechste Schritt braucht ein gezeichnetes Bild dazwischen.
            break
        end
    end
    if TFMeasureScreen and TFMeasureScreen.showProgress and run.index % 9 == 0 then
        pcall(TFMeasureScreen.showProgress, string.format("Menu check %d/%d", run.index, #run.steps))
    end
end

--- Tastendruck: nur vormerken (siehe TFMeasureScreen.key).
function M.key(key)
    if not Keyboard then return end
    if key == Keyboard.KEY_NUMPAD6 then M.wanted = true end
    -- Num 5 (seit 6.40.0): derselbe Lauf, und danach von selbst der Bildschirmlauf (Num 7).
    if key == Keyboard.KEY_NUMPAD5 then
        M.wanted = true
        M.thenScreen = not M.run
    end
end

if not M.registered then
    M.registered = true
    Events.OnKeyPressed.Add(function(key) TFMeasureMenu.key(key) end)
    local function tick()
        local ok, err = pcall(TFMeasureMenu.pump)
        if not ok then
            log("Schritt fehlgeschlagen: " .. tostring(err))
            pcall(TFMeasureMenu.finish, "abgebrochen (Fehler)")
        end
    end
    if Events.OnFETick then Events.OnFETick.Add(tick) end
    if Events.OnTick then Events.OnTick.Add(tick) end
end

log("bereit. In der Charaktererstellung: Num 6 startet den Prueflauf.")
