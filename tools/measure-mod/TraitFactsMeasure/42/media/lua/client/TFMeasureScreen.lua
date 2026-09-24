--- Trait Facts Mess-Mod - Bildschirmlauf in der Charaktererstellung (seit 6.29.0).
--
-- Faehrt in der Charaktererstellung eine Reihe von Szenarien ab, bei jeder
-- Aufloesung einer Liste, und legt je Schritt zweierlei ab:
--
--   Zomboid/Screenshots/TF_<breite>x<hoehe>_<nr>_<szenario>.png
--   Zomboid/Lua/TraitFacts_screen.txt    Lage und Groesse jedes Elements,
--                                        dazu Pruefungen mit ok oder FEHL
--
-- Das Protokoll ist der verlaesslichere Teil: es sagt, ob zwei Elemente
-- uebereinanderliegen, ob etwas aus dem Bildschirm ragt, ob das Panel der
-- Uebersicht verschwunden ist, wie viele Trait-Namen gekuerzt wurden und ob
-- die Uebersicht umbricht. Die Bilder sind fuer den Blick, das Protokoll fuer
-- den Vergleich nach jeder Aenderung.
--
-- Bedienung: in der Charaktererstellung (Beruf und Traits) Num 7, ohne
-- Debug-Modus auch F7.
--   Num 7 / F7           ganzer Lauf, alle Aufloesungen
--   Strg + Num 7 / F7    nur die jetzige Aufloesung
--   Shift + Num 7 / F7   Workshop-Bilder (seit 6.42.0): nur die jetzige
--                        Aufloesung, ohne Fortschrittsanzeige, mit Tooltips;
--                        Zomboid/Screenshots/TF_WS_<breite>x<hoehe>_<nr>_<name>.png
--   waehrend des Laufs   dieselbe Taste bricht ab und stellt die Aufloesung zurueck
--
-- Die Tooltips der Workshop-Bilder entstehen ohne Maus: fuer die Aufnahme
-- liefern getMouseX und getMouseY die Mitte der gewuenschten Zeile, danach
-- wieder die echte Maus. Vanilla fragt beide in ISScrollingListBox:updateTooltip
-- und ISToolTip:render jedes Bild neu ab.
--
-- Die Aufloesung wird im Fenstermodus gewechselt (getCore():
-- setResolutionAndFullScreen, wie Vanillas Optionsmenue); ein randloses
-- Fenster (Borderless Window) wird dafuer ausgeschaltet und am Ende wieder an. Die Einstellung von
-- vorher steht in Zomboid/Lua/TraitFacts_screen_restore.txt, bis der Lauf sie
-- zurueckgestellt hat; bricht das Spiel mittendrin ab, stellt der naechste
-- Tastendruck sie zuerst wieder her.
--
-- Getaktet wird ueber die Uhr, nicht ueber Bilder: im Hauptmenue feuert
-- OnFETick, in einer laufenden Welt OnTick, und welcher von beiden kommt,
-- soll egal sein.
--
-- Braucht Trait Facts ab 0.12.0 (TraitFacts.Build, TraitFacts.Panel). Ohne
-- laufen nur die Szenarien, die Vanilla allein traegt; der Rest steht als
-- "entfaellt" im Protokoll.

TFMeasureScreen = TFMeasureScreen or {}
local M = TFMeasureScreen

--- Die Schrift, wie der Spieler sie unter Optionen > Anzeige sieht (seit 6.40.7).
-- Build 42 fuehrt Pixelstufen, nicht mehr 1x bis 4x. getOptionFontSize ist die
-- Wahl (1 bis 6, 6 = mit der Fensterhoehe), getOptionFontSizeReal die Stufe,
-- die daraus wirklich gilt (1 bis 5, Core.getOptionFontSizeReal).
-- Die Tooltip-Schrift ist eine eigene Wahl (Small, Medium, Large); sie
-- bestimmt die Groesse der Trait-Facts-Tooltips.
local PIXEL = { "16px", "19px", "26px", "33px", "38px" }
function M.fontLabel()
    local wahl, real, tooltip = nil, nil, "?"
    pcall(function() wahl = getCore():getOptionFontSize() end)
    pcall(function() real = getCore():getOptionFontSizeReal() end)
    pcall(function() tooltip = tostring(getCore():getOptionTooltipFont()) end)
    local groesse = PIXEL[real or 0] or tostring(real)
    if wahl == 6 then groesse = groesse .. " (mit der Fensterhoehe)" end
    return groesse .. ", Tooltip " .. tooltip
end

M.VERSION = "6.46.0"
M.LOGFILE = "TraitFacts_screen.txt"
M.RESTOREFILE = "TraitFacts_screen_restore.txt"

--- Fenstergroessen des ganzen Laufs. Groessere als die Ausgangsgroesse
-- entfallen: ein Fenster, das nicht auf den Monitor passt, sagt nichts.
M.SIZES = {
    { 1280, 720 }, { 1366, 768 }, { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 },
}

--- Wartezeiten in Millisekunden: nach einem Aufloesungswechsel, nach dem
-- Aufbau eines Szenarios (zwei, drei Bilder, bis Vanilla neu verteilt hat),
-- nach dem Ausloesen des Screenshots.
M.WAIT_RESOLUTION = 1800
M.WAIT_SETTLE = 700
M.WAIT_SHOT = 500
--- So lange zaehlt der Lauf Bilder, bevor er aufnimmt.
M.WAIT_FPS = 1000

local function log(text)
    if TFMeasure and TFMeasure.melde then return TFMeasure.melde("[TraitFactsMeasure] Bildschirm:", text) end
    print("[TraitFactsMeasure] Bildschirm: " .. tostring(text))
end

local function now()
    return (getTimestampMs and getTimestampMs()) or 0
end

local function TFX()
    return TraitFacts
end

--- Der Bildschirm "Beruf und Traits", wenn er gerade zu sehen ist.
function M.screen()
    local main = MainScreen and MainScreen.instance
    local screen = main and main.charCreationProfession
    if not screen then return nil end
    local ok, visible = pcall(function() return screen:isReallyVisible() end)
    if ok and visible then return screen end
    return nil
end

-- ---------------------------------------------------------------- Szenarien

-- ---------------------------------------------------------------- Maus fuer Tooltips

--- Die echten Mausfunktionen, einmal gemerkt (auch ueber ein Neuladen).
M.realMouseX = M.realMouseX or getMouseX
M.realMouseY = M.realMouseY or getMouseY

--- Setzt die Maus scheinbar auf Zeile `index` der Liste, bis M.unhover().
function M.hover(list, index)
    local item = list and list.items and list.items[index]
    if type(item) ~= "table" then return false end
    if list.ensureVisible then pcall(list.ensureVisible, list, index) end
    -- Die Lage wird bei jeder Abfrage neu gerechnet: ensureVisible scrollt weich
    -- ueber mehrere Bilder, ein fester Punkt zeigte danach neben die Zeile
    -- (erster Workshop-Lauf 22.09.2026: Strong ganz unten, kein Tooltip).
    M.fakeMouse = { list = list, index = index }
    getMouseX = function() return M.fakeMouse and M.fakePoint()[1] or M.realMouseX() end
    getMouseY = function() return M.fakeMouse and M.fakePoint()[2] or M.realMouseY() end
    return true
end

--- Bildschirmpunkt in der Mitte der vorgetaeuschten Zeile, beim jetzigen Scroll.
function M.fakePoint()
    local list, index = M.fakeMouse.list, M.fakeMouse.index
    local item = list.items and list.items[index]
    local yScroll = 0
    pcall(function() yScroll = list:getYScroll() end)
    local h = (type(item) == "table" and item.height) or list.itemheight or 20
    local top = list:topOfItem(index)
    return { list:getAbsoluteX() + math.floor(list:getWidth() * 0.3),
             list:getAbsoluteY() + top + math.floor(h / 2) + yScroll }
end

function M.unhover()
    M.fakeMouse = nil
    getMouseX, getMouseY = M.realMouseX, M.realMouseY
end

local function traitIndex(list, id)
    local tf = TFX()
    for index, item in ipairs((list and list.items) or {}) do
        local def = item and item.item
        local got = def and tf and tf.traitId and tf.traitId(def)
        if got == id then return index end
    end
    return nil
end

--- Zeigt fuer die Aufnahme auch die Werte ohne Wirkung; M.restoreOptions
-- stellt die Wahl des Spielers danach zurueck.
local function showDeadForShot()
    local tf = TFX()
    if not (tf and tf.Options and tf.Options.showDead and tf.Options.setShowDead) then return end
    if M.savedShowDead == nil then M.savedShowDead = tf.Options.showDead() == true end
    tf.Options.setShowDead(true)
end

function M.restoreOptions()
    local tf = TFX()
    if M.savedShowDead ~= nil and tf and tf.Options and tf.Options.setShowDead then
        tf.Options.setShowDead(M.savedShowDead)
    end
    M.savedShowDead = nil
end

local function closeAll(screen)
    M.unhover()
    M.restoreOptions()
    local tf = TFX()
    if tf and tf.Build and tf.Build.closeMissing then pcall(tf.Build.closeMissing, screen) end
    if tf and tf.Panel and tf.Panel.closeFull then pcall(tf.Panel.closeFull, screen) end
    if screen.tfOptionsPopup then pcall(function() screen.tfOptionsPopup:setVisible(false) end) end
    if tf and tf.OptionInfo and tf.OptionInfo.hide then pcall(tf.OptionInfo.hide) end
    if screen.tfToast then pcall(function() screen.tfToast:setVisible(false) end) end
    if screen.tfSearchField then
        pcall(function()
            screen.tfSearchField:setText("")
            screen.tfSearchField:unfocus()
        end)
    end
end

local function loadBuild(screen, text)
    local tf = TFX()
    if not (tf and tf.Build and tf.Build.parse and tf.Build.apply) then return false end
    local build = tf.Build.parse(text, screen)
    if not build then return false end
    tf.Build.apply(screen, build)
    return true
end

--- name, was es zeigt, Aufbau. Der Aufbau bekommt den Bildschirm und liefert
-- false, wenn das Szenario hier nicht geht (dann entfaellt es mit Vermerk).
M.SCENARIOS = {
    { name = "leer", run = function(screen)
        screen:resetBuild()
        return true
    end },
    { name = "build", run = function(screen)
        -- Viele Traits: die Liste der gewaehlten laeuft voll, die Uebersicht
        -- bekommt mehrere Themen, die Startskill-Liste mehrere Zeilen.
        return loadBuild(screen, "fireofficer;strong;brave;dextrous;fastlearner;keenhearing;outdoorsman;"
            .. "smoker;shortsighted;slowreader;hardofhearing;weakstomach")
    end },
    { name = "fitinstruktor", run = function(screen)
        return loadBuild(screen, "fitnessinstructor;fit")
    end },
    { name = "parkranger", run = function(screen)
        return loadBuild(screen, "parkranger;outdoorsman;herbalist")
    end },
    { name = "suche", run = function(screen)
        loadBuild(screen, "fireofficer;strong")
        if not screen.tfSearchField then return false end
        screen.tfSearchField:setText("panic")
        return true
    end },
    { name = "zahnrad", run = function(screen)
        if not (screen.tfGearButton and screen.tfGearButton.forceClick) then return false end
        screen.tfGearButton:forceClick()
        return true
    end },
    { name = "warnfenster", run = function(screen)
        local tf = TFX()
        if not (tf and tf.Build and tf.Build.showMissing) then return false end
        loadBuild(screen, "fireofficer;strong;brave")
        tf.Build.showMissing(screen, {
            { name = "moreTraitsDefinitive", url = "https://steamcommunity.com/sharedfiles/filedetails/?id=3799050151",
              count = 5, workshop = "3799050151" },
            { name = "SimpleOverhaulTraitsAndOccupations", url = "https://steamcommunity.com/", count = 12,
              workshop = "2840805724" },
            { name = "MyLocalTraits", url = "https://steamcommunity.com/", count = 1 },
        }, "excluded or not available: stout, weak; 2 entries could not be read (damaged text or another game version)")
        return true
    end },
    { name = "hinweis", run = function(screen)
        local tf = TFX()
        if not (tf and tf.Panel and tf.Panel.showToast) then return false end
        tf.Panel.showToast(screen, "Build loaded: excluded or not available: stout, weak; "
            .. "3 entries could not be read (damaged text or another game version)", "warn", 60000)
        return true
    end },
    -- Zuletzt, damit die Nummern der uebrigen Bilder bleiben: die ganze
    -- Uebersicht ueber den linken Spalten, nur in der schmalen Anordnung.
    { name = "allezeigen", run = function(screen)
        if screen.tfWideColumn then return false, "breite Anordnung: die Uebersicht hat ihre eigene Spalte" end
        if not (screen.tfShowAllButton and screen.tfShowAllButton.forceClick) then return false end
        if not loadBuild(screen, "fireofficer;strong;brave;dextrous;fastlearner;keenhearing;outdoorsman;"
            .. "smoker;shortsighted;slowreader;hardofhearing;weakstomach") then return false end
        screen.tfShowAllButton:forceClick()
        return screen.tfFull ~= nil
    end },
}

--- Die Bilder fuer die Workshop-Seite (seit 6.42.0, Wunsch 22.09.2026): jedes
-- zeigt eine Sache so gross, wie die jetzige Aufloesung es hergibt. Zugeschnitten
-- und gerahmt werden sie danach mit tools/workshop-bilder.py.
M.WORKSHOP = {
    -- 01 Die Uebersicht mit einem Build, der viele Themen fuellt, aber ohne
    -- Rollbalken in die Spalte passt.
    { name = "uebersicht", run = function(screen)
        -- Ohne Short Sighted und Keen Hearing (Laeufe 22.09.2026: die Spalte lief
        -- bei 1920x1080 um ein paar Zeilen ueber).
        return loadBuild(screen, "fireofficer;strong;brave;dextrous;outdoorsman;smoker;weakstomach")
    end },
    -- 02 Der Tooltip von Strong mit der grauen Zeile zur Tragkraft: Werte ohne
    -- Wirkung werden fuer die Aufnahme gezeigt und danach wieder wie vorher.
    { name = "tooltip-strong", run = function(screen)
        loadBuild(screen, "fireofficer")
        showDeadForShot()
        local tf = TFX()
        if tf and tf.Options and tf.Options.sync then pcall(tf.Options.sync) end
        local index = traitIndex(screen.listboxTrait, "base:strong")
        if not index then return false, "Strong nicht in der Liste" end
        return M.hover(screen.listboxTrait, index)
    end },
    -- 03 Major Skills mit dem Tooltip, der die Rechnung zeigt (Foraging, zwei Quellen).
    { name = "skills-tooltip", run = function(screen)
        loadBuild(screen, "parkranger;outdoorsman;herbalist")
        local list = screen.listboxXpBoost
        if not (list and list.items and #list.items > 0) then return false, "Major Skills leer" end
        return M.hover(list, 1)
    end },
    -- 04 Die Suche nach "panic".
    { name = "suche", run = M.SCENARIOS[5].run },
    -- 05 Build teilen: das Fenster fuer fehlende Mods.
    { name = "build-code", run = M.SCENARIOS[7].run },
}

-- ---------------------------------------------------------------- Protokoll

--- Elemente, deren Lage ins Protokoll kommt. `layout = true`: gehoert zur
-- festen Aufteilung und darf kein anderes solches Element ueberdecken.
M.ELEMENTS = {
    { key = "listboxProf", layout = true }, { key = "listboxTrait", layout = true },
    { key = "listboxBadTrait", layout = true }, { key = "listboxTraitSelected", layout = true },
    { key = "listboxXpBoost", layout = true }, { key = "tfSummary", layout = true },
    { key = "tfSearchField", layout = true }, { key = "removeTraitBtn", layout = true },
    { key = "tfGearButton", layout = true }, { key = "tfCopyButton", layout = true },
    { key = "tfPasteButton", layout = true }, { key = "tfBugButton", layout = true },
    { key = "tfOptionsPopup" }, { key = "tfMissingPopup" }, { key = "tfToast" }, { key = "tfFull" },
    { key = "tfShowAllButton" },
    { key = "playButton" }, { key = "backButton" }, { key = "resetButton" }, { key = "randomButton" },
    { key = "presetPanel" },
}

local function rectOf(element)
    local ok, r = pcall(function()
        return { x = element:getAbsoluteX(), y = element:getAbsoluteY(),
                 w = element:getWidth(), h = element:getHeight(),
                 visible = element:isReallyVisible() and true or false }
    end)
    if ok then return r end
    return nil
end

local function overlap(a, b)
    local w = math.min(a.x + a.w, b.x + b.w) - math.max(a.x, b.x)
    local h = math.min(a.y + a.h, b.y + b.h) - math.max(a.y, b.y)
    -- Ein Pixel Beruehrung am Rahmen ist kein Ueberlappen.
    if w > 1 and h > 1 then return w, h end
    return nil
end

--- Schreibt den Stand eines Szenarios: eine Zeile je Element, dann die
-- Pruefungen. @return number, number  bestanden, nicht bestanden
function M.record(writer, screen, size, scenario)
    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    local head = "res=" .. sw .. "x" .. sh .. "|szenario=" .. scenario
    local nl = "\r\n"
    writer:write("schritt|" .. head .. "|gewollt=" .. size[1] .. "x" .. size[2]
        .. "|schrift=" .. M.fontLabel() .. nl)
    -- Im Fenstermodus nimmt die Titelleiste dem Inhalt ein paar Pixel Hoehe
    -- (1920x1061 statt 1080); das ist kein Fehlschlag.
    local taken = sw == size[1] and math.abs(sh - size[2]) <= 80
    local own0 = rectOf(screen)
    local variant = (own0 and own0.w >= sw - 2) and "start" or "nach-wechsel"
    -- Bildrate zum Zeitpunkt der Aufnahme, gemittelt vom Spiel. Kein Pruefwert
    -- (sie haengt am Rechner), aber der Vergleich zwischen "leer" und "build"
    -- zeigt, was die Uebersicht kostet (20.09.2026: ueber 50 gegen unter 20).
    local fps = nil
    pcall(function() fps = getAverageFPS() end)
    if type(fps) == "number" then writer:write("wert|" .. head .. "|fps=" .. math.floor(fps) .. nl) end
    writer:write("wert|" .. head .. "|variante=" .. variant .. "|anordnung="
        .. (screen.tfWideColumn and "vier-spalten" or "schmal")
        .. "|ort=" .. (M.inWorld() and "welt" or "hauptmenue")
        .. "|bildschirm=" .. (own0 and (own0.w .. "x" .. own0.h) or "-") .. nl)

    local rects, okCount, failCount = {}, 0, 0
    local function check(name, passed, detail)
        if passed then okCount = okCount + 1 else failCount = failCount + 1 end
        writer:write("pruef|" .. head .. "|" .. name .. "|" .. (passed and "ok" or "FEHL")
            .. "|" .. tostring(detail or "") .. nl)
    end

    check("aufloesung-gegriffen", taken, "gewollt " .. size[1] .. "x" .. size[2] .. ", gemeldet " .. sw .. "x" .. sh)
    local own = rectOf(screen)
    if own then
        writer:write(string.format("element|%s|bildschirm|sichtbar=1|x=%d|y=%d|w=%d|h=%d", head, own.x, own.y, own.w, own.h) .. nl)
    end
    for _, e in ipairs(M.ELEMENTS) do
        local element = screen[e.key]
        local r = element and rectOf(element) or nil
        if r then
            rects[e.key] = r
            writer:write(string.format("element|%s|%s|sichtbar=%d|x=%d|y=%d|w=%d|h=%d", head, e.key,
                r.visible and 1 or 0, r.x, r.y, r.w, r.h) .. nl)
        else
            writer:write("element|" .. head .. "|" .. e.key .. "|fehlt" .. nl)
        end
    end
    -- Offene Listen-Tooltips (seit 6.42.0): tools/workshop-bilder.py schneidet
    -- die Workshop-Bilder danach zu. Kein Pruefwert, nur die Lage.
    for _, key in ipairs({ "listboxTrait", "listboxBadTrait", "listboxXpBoost" }) do
        local tip = screen[key] and screen[key].tooltipUI
        local r = tip and rectOf(tip) or nil
        if r and r.visible then
            writer:write(string.format("element|%s|tooltip:%s|sichtbar=1|x=%d|y=%d|w=%d|h=%d", head, key,
                r.x, r.y, r.w, r.h) .. nl)
        end
    end

    -- 1. Nichts Sichtbares ragt aus dem Bildschirm.
    for _, e in ipairs(M.ELEMENTS) do
        local r = rects[e.key]
        if r and r.visible then
            local inside = r.x >= 0 and r.y >= 0 and r.x + r.w <= sw and r.y + r.h <= sh
            check("im-bildschirm:" .. e.key, inside,
                string.format("x=%d..%d von %d, y=%d..%d von %d", r.x, r.x + r.w, sw, r.y, r.y + r.h, sh))
        end
    end
    -- 2. Die feste Aufteilung ueberdeckt sich nicht.
    for i = 1, #M.ELEMENTS do
        for j = i + 1, #M.ELEMENTS do
            local a, b = M.ELEMENTS[i], M.ELEMENTS[j]
            local ra, rb = rects[a.key], rects[b.key]
            if a.layout and b.layout and ra and rb and ra.visible and rb.visible then
                local w, h = overlap(ra, rb)
                if w then check("ueberlappt:" .. a.key .. "+" .. b.key, false, w .. "x" .. h .. " px") end
            end
        end
    end
    check("aufteilung-ohne-ueberlappung", true, "geprueft")
    -- 3. Panel und Kopfzeile sind da.
    local panel = rects.tfSummary
    check("panel-sichtbar", panel ~= nil and panel.visible, panel and (panel.w .. "x" .. panel.h) or "fehlt")
    for _, key in ipairs({ "tfGearButton", "tfCopyButton", "tfPasteButton", "tfBugButton" }) do
        check("kopfzeile:" .. key, rects[key] ~= nil and rects[key].visible, "")
    end
    -- 4. Spaltenbreiten: was den Namen bleibt.
    for _, key in ipairs({ "listboxProf", "listboxTrait", "listboxTraitSelected" }) do
        local r = rects[key]
        if r then check("spaltenbreite:" .. key, r.w >= 250, r.w .. " px (unter 250 wird es eng)") end
    end
    -- 5. Gekuerzte Trait-Namen in den drei Listen.
    --
    -- Kuerzen ist kein Fehler (Deutsch-Lauf 21.09.2026): "Spezialisierung:
    -- Lebensmittel & Landwirtschaft" aus More Traits passt in keine Spalte, und
    -- der Tooltip nennt den vollen Namen. Ein Fehler ist erst, wenn vom Namen zu
    -- wenig uebrig bleibt, um ihn zu erkennen (unter MIN_LESBAR Zeichen), oder
    -- wenn es so viele sind, dass die Spalte zu schmal ist (ueber MAX_ANTEIL).
    -- Bis 6.40.7 galt jede Kuerzung als FEHL; auf Deutsch waren das 22 Meldungen
    -- fuer drei lange Namen.
    -- Der Anteil zaehlt erst ab genug Zeilen: in einer Liste aus drei Zeilen
    -- ist eine gekuerzte kein Befund ueber die Spaltenbreite.
    local MIN_LESBAR, MAX_ANTEIL, GENUG = 12, 0.05, 20
    local shortened, rows, welche, zuKurz = 0, 0, {}, {}
    for _, key in ipairs({ "listboxTrait", "listboxBadTrait", "listboxTraitSelected" }) do
        local list = screen[key]
        for _, item in ipairs((list and list.items) or {}) do
            rows = rows + 1
            if type(item.tfShort) == "table" and item.tfShort.proxy then
                shortened = shortened + 1
                local name, kurz = "?", ""
                pcall(function() name = tostring(item.tfShort.def:getLabel()) end)
                pcall(function() kurz = tostring(item.tfShort.proxy:getLabel()) end)
                -- Seit 6.38.3 mit Namen: "2 von 177" sagte nicht, welche.
                if #welche < 6 then welche[#welche + 1] = name .. " -> " .. kurz end
                if #(string.gsub(kurz, "%.%.%.$", "")) < MIN_LESBAR then
                    zuKurz[#zuKurz + 1] = kurz
                end
            end
        end
    end
    local zuViele = rows >= GENUG and (shortened / rows) > MAX_ANTEIL
    check("gekuerzte-namen", #zuKurz == 0 and not zuViele,
        shortened .. " von " .. rows .. " Zeilen mit \"...\""
        .. ((#zuKurz > 0) and (", davon " .. #zuKurz .. " unkenntlich: " .. table.concat(zuKurz, ", "))
            or (zuViele and ", zu viele fuer die Spaltenbreite" or " (lesbar, voller Name im Tooltip)"))
        .. ((#welche > 0) and ("; " .. table.concat(welche, ", ")) or ""))
    -- 6. Die Uebersicht: Spaltensatz oder durchlaufend, und bricht sie um?
    local summary = screen.tfSummary
    if summary then
        -- Zeilen, nicht Segmente: ISRichTextPanel fuehrt in `lines` ein Stueck
        -- je Farbwechsel, mehrere je Bildschirmzeile. Eine Zeile ist, was
        -- dieselbe lineY traegt (erster Lauf 20.09.2026: 370 "Zeilen" statt 66).
        local lines, seenY = 0, {}
        if type(summary.lineY) == "table" then
            for _, y in ipairs(summary.lineY) do
                if not seenY[y] then
                    seenY[y] = true
                    lines = lines + 1
                end
            end
        elseif type(summary.lines) == "table" then
            lines = #summary.lines
        end
        local expected = summary.tfExpectedLines
        -- Spaltensatz und Umbruch sind nur in der eigenen Spalte ein Mangel;
        -- in der schmalen Anordnung setzt das Panel absichtlich durchlaufend.
        if screen.tfWideColumn then
            check("uebersicht-spaltensatz", summary.tfSpans ~= nil, "ohne Spannen setzt das Panel durchlaufend")
            if type(expected) == "number" then
                check("uebersicht-ohne-umbruch", lines <= expected + 1,
                    lines .. " Zeilen gesetzt, " .. expected .. " erwartet")
            end
        end
        -- Wie viel von der Uebersicht ohne Scrollen zu sehen ist: das ist die
        -- Zahl, an der die schmale Anordnung haengt.
        if panel and panel.visible and lines > 0 then
            local lh = 19
            pcall(function() lh = getTextManager():getFontHeight(UIFont.Small) end)
            local shown = math.min(lines, math.floor(panel.h / lh))
            -- Seit 6.38.2: in der schmalen Anordnung ist ein kleines Panel
            -- gewollt, dafuer gibt es "Show all". Ein Mangel ist es dort erst,
            -- wenn der Knopf fehlt oder nicht zu sehen ist: dann kommt der
            -- Spieler an den Rest nicht heran. Bis 6.38.1 zaehlte jedes kleine
            -- Panel als FEHL, im Lauf in der Welt 19-mal, und die eine echte
            -- Meldung (Trait Facts ganz weg) ging darin fast unter. Die Zahl der
            -- sichtbaren Zeilen steht weiter als Wert im Protokoll.
            local genug = shown >= math.min(lines, 8)
            local knopf = screen.tfShowAllButton
            local erreichbar = false
            if knopf then
                pcall(function() erreichbar = knopf:isVisible() == true or knopf:getIsVisible() == true end)
            end
            local text = shown .. " von " .. lines .. " Zeilen ohne Scrollen (Panel " .. math.floor(panel.h) .. " px hoch)"
            if screen.tfWideColumn then
                check("uebersicht-lesbar", genug, text)
            else
                check("uebersicht-lesbar", genug or erreichbar,
                    text .. (genug and "" or (erreichbar and "; der Rest ueber Show all" or "; Show all fehlt")))
            end
            writer:write("wert|" .. head .. "|uebersicht-zeilen|sichtbar=" .. shown .. "|gesamt=" .. lines .. nl)
        end
        local okScroll, scrollH = pcall(function() return summary:getScrollHeight() end)
        if okScroll and type(scrollH) == "number" and panel then
            writer:write("wert|" .. head .. "|uebersicht-hoehe|inhalt=" .. math.floor(scrollH)
                .. "|panel=" .. panel.h .. "|scrollt=" .. ((scrollH > panel.h) and 1 or 0) .. nl)
        end
    end
    -- 6b. Die ganze Ansicht ("Show all"): wie viel sie auf einmal zeigt.
    local full = screen.tfFull and screen.tfFull.tfPanel
    if full then
        local fullLines, seen = 0, {}
        for _, y in ipairs(type(full.lineY) == "table" and full.lineY or {}) do
            if not seen[y] then
                seen[y] = true
                fullLines = fullLines + 1
            end
        end
        local lh = 19
        pcall(function() lh = getTextManager():getFontHeight(UIFont.Small) end)
        local okH, fh = pcall(function() return full:getHeight() end)
        local shown = okH and math.min(fullLines, math.floor(fh / lh)) or 0
        check("alles-zeigen-lesbar", shown >= math.min(fullLines, 20),
            shown .. " von " .. fullLines .. " Zeilen ohne Scrollen")
        check("alles-zeigen-spaltensatz", full.tfSpans ~= nil, "")
    end
    -- 8. Tooltips gegen diese Fenstergroesse, einmal je Aufloesung (im leeren
    -- Szenario stehen alle Traits in den Listen). Der Menue-Prueflauf misst
    -- dasselbe, aber nur bei der Groesse, die gerade eingestellt ist.
    if scenario == "leer" and TFMeasureMenu and TFMeasureMenu.tooltipReport then
        local okTip, tip = pcall(TFMeasureMenu.tooltipReport, screen)
        if okTip and tip and tip.zahl > 0 then
            check("tooltips-passen", tip.zuGross == 0, tip.zahl .. " Tooltips, " .. tip.zuGross
                .. " passen nicht ins Fenster" .. ((#tip.liste > 0) and (": " .. table.concat(tip.liste, ", ")) or ""))
            if tip.hoechster then
                writer:write("wert|" .. head .. "|hoechster-tooltip|" .. tip.hoechster.id .. "|"
                    .. math.floor(tip.hoechster.w) .. "x" .. math.floor(tip.hoechster.h) .. nl)
            end
        end
    end
    -- 7. Die Startskill-Liste scrollt nicht ohne Not.
    local xp = screen.listboxXpBoost
    if xp and rects.listboxXpBoost then
        local okScroll, scrollH = pcall(function() return xp:getScrollHeight() end)
        if okScroll and type(scrollH) == "number" then
            writer:write("wert|" .. head .. "|startskills|inhalt=" .. math.floor(scrollH) .. "|liste="
                .. rects.listboxXpBoost.h .. "|zeilen=" .. tostring(xp.items and #xp.items or 0) .. nl)
        end
    end
    return okCount, failCount
end

-- ---------------------------------------------------------------- Aufloesung

local function readRestore()
    local reader = getFileReader(M.RESTOREFILE, false)
    if not reader then return nil end
    local line = reader:readLine()
    reader:close()
    if not line then return nil end
    local w, h, full, borderless = string.match(line, "^(%d+)x(%d+)|(%d)|?(%d?)$")
    if not w then return nil end
    return { tonumber(w), tonumber(h), full == "1", borderless == "1" }
end

local function writeRestore(value)
    local writer = getFileWriter(M.RESTOREFILE, true, false)
    if value then
        writer:write(value[1] .. "x" .. value[2] .. "|" .. (value[3] and "1" or "0") .. "|"
            .. (value[4] and "1" or "0") .. "\r\n")
    else
        writer:write("erledigt\r\n")
    end
    writer:close()
end

--- Ob das Spiel als randloses Fenster laeuft (Optionen, Anzeige, "Borderless
-- Window"). Dann ist das Fenster so gross wie der Desktop, und eine andere
-- Aufloesung greift nicht: der erste ganze Lauf (20.09.2026) schrieb alle
-- Groessen unter 1920x1080 uebereinander. Vanillas Optionsmenue schaltet den
-- Modus deshalb vor dem Wechsel selbst um (MainOptions:setResolutionAndFullScreen).
local function borderless()
    local ok, value = pcall(function() return getCore():getOptionBorderlessWindow() end)
    return ok and value == true
end

local function setSize(w, h, fullscreen, wantBorderless)
    local core = getCore()
    wantBorderless = wantBorderless == true
    if core:getScreenWidth() == w and core:getScreenHeight() == h and core:isFullScreen() == fullscreen
            and borderless() == wantBorderless then
        return false
    end
    pcall(function() core:setOptionBorderlessWindow(wantBorderless) end)
    core:setResolutionAndFullScreen(w, h, fullscreen)
    return true
end

--- Stellt eine Einstellung zurueck, die ein abgebrochener Lauf hinterlassen hat.
function M.restoreIfPending()
    local pending = readRestore()
    if not pending then return false end
    log("stelle die Aufloesung von vor dem letzten Lauf wieder her: " .. pending[1] .. "x" .. pending[2])
    pcall(setSize, pending[1], pending[2], pending[3], pending[4])
    writeRestore(nil)
    return true
end

--- Bringt die Charaktererstellung auf die Groesse, die sie beim Spielstart
-- hat: das ganze Fenster.
--
-- Vanilla behandelt die beiden Wege verschieden. Beim Start entsteht der
-- Bildschirm in voller Fenstergroesse; nach einem Aufloesungswechsel setzt
-- CharacterCreationProfession:onResolutionChange ihn auf 75 % der Breite und
-- 80 % der Hoehe, mittig. Der erste ganze Lauf (20.09.2026) mass deshalb bei
-- 1280 bis 1600 px einen Zustand, den nur sieht, wer in den Optionen die
-- Aufloesung wechselt und ohne Neustart weiterspielt: 960 px Bildschirm in
-- einem 1280er Fenster. Gemessen wird der Startzustand; `variante` im
-- Protokoll sagt, welcher es war.
--- In einer laufenden Welt (neue Figur nach dem Tod) ist der Startzustand ein
-- anderer: dort oeffnet das Spiel die Charaktererstellung auf 75 % der Breite
-- und 80 % der Hoehe, und so sieht der Spieler sie. Der Lauf vom 20.09.2026,
-- 20:53, zog sie trotzdem auf die volle Fenstergroesse und mass damit bei 1920
-- einen 1920er Bildschirm, wo der Spieler 1440 sieht. Seit 6.38.1 bleibt die
-- Groesse in der Welt, wie Vanilla sie nach dem Wechsel setzt.
function M.inWorld()
    local ok, player = pcall(function() return getPlayer and getPlayer() end)
    return ok and player ~= nil
end

function M.fullSize(screen)
    if M.inWorld() then return end
    local core = getCore()
    screen:setX(0)
    screen:setY(0)
    screen:setWidth(core:getScreenWidth())
    screen:setHeight(core:getScreenHeight())
    if screen.recalcSize then screen:recalcSize() end
end

-- ---------------------------------------------------------------- Fortschritt

--- Kleine Anzeige "5/32 1600x900 suche" am oberen Rand, rechts neben der
-- Ueberschrift des Bildschirms (Wunsch 20.09.2026): dort steht nichts, sie
-- verdeckt also auch in den Screenshots nichts. Ein eigenes Fenster ganz oben,
-- damit sie den Aufloesungswechsel ueberlebt. M.progress fuehrt den Stand
-- auch ohne Oberflaeche (Test).
function M.showProgress(text)
    M.progress = text
    if not ISPanel then return end
    local badge = M.badge
    if not badge then
        badge = ISPanel:new(0, 0, 10, 10)
        badge:initialise()
        badge.backgroundColor = { r = 0.03, g = 0.03, b = 0.03, a = 1 }
        badge.borderColor = { r = 0.45, g = 0.72, b = 1.0, a = 1 }
        local baseRender = badge.render
        badge.render = function(b)
            if baseRender then baseRender(b) end
            b:drawText(M.progress or "", 8, 3, 0.85, 0.85, 0.85, 1, UIFont.Small)
        end
        badge:addToUIManager()
        if badge.setAlwaysOnTop then badge:setAlwaysOnTop(true) end
        M.badge = badge
    end
    local width = 16
    pcall(function() width = getTextManager():MeasureStringX(UIFont.Small, text) + 16 end)
    local lh = 19
    pcall(function() lh = getTextManager():getFontHeight(UIFont.Small) end)
    local sw = getCore():getScreenWidth()
    badge:setWidth(width)
    badge:setHeight(lh + 6)
    badge:setX(math.min(sw - width - 140, math.floor(sw / 2) + 170))
    badge:setY(10)
    badge:setVisible(true)
end

function M.hideProgress()
    M.progress = nil
    if M.badge then
        pcall(function()
            M.badge:setVisible(false)
            M.badge:removeFromUIManager()
        end)
        M.badge = nil
    end
end

-- ---------------------------------------------------------------- Ablauf

--- Startet den Lauf. @param onlyCurrent  nur die jetzige Aufloesung
-- @param workshop  die Workshop-Bilder statt der Pruefszenarien (immer nur
-- die jetzige Aufloesung)
function M.start(onlyCurrent, workshop)
    if workshop then onlyCurrent = true end
    if M.run then return M.abort("von Hand abgebrochen") end
    if M.restoreIfPending() then return end
    local screen = M.screen()
    if not screen then
        log("bitte zuerst die Charaktererstellung oeffnen (Beruf und Traits), dann Num 7 oder F7.")
        return
    end
    local core = getCore()
    local original = { core:getScreenWidth(), core:getScreenHeight(), core:isFullScreen(), borderless() }
    local sizes = {}
    if onlyCurrent then
        sizes[1] = { original[1], original[2] }
    else
        for _, size in ipairs(M.SIZES) do
            if size[1] <= original[1] and size[2] <= original[2] then sizes[#sizes + 1] = size end
        end
        if #sizes == 0 then sizes[1] = { original[1], original[2] } end
        writeRestore(original)
    end
    local writer = getFileWriter(M.LOGFILE, true, false)
    writer:write("# Trait Facts Bildschirmlauf, Mess-Mod " .. M.VERSION .. ", Trait Facts "
        .. tostring(TFX() and TFX().VERSION or "fehlt") .. ", Spiel " .. tostring(core:getVersion()) .. "\r\n")
    writer:write("# schritt|element|pruef|wert je Aufloesung und Szenario; Bilder: Zomboid/Screenshots/TF_*.png\r\n")
    local scenarios = workshop and M.WORKSHOP or M.SCENARIOS
    M.run = { sizes = sizes, sizeIndex = 0, scenarioIndex = 0, phase = "size", due = now(),
              writer = writer, original = original, changed = not onlyCurrent,
              scenarios = scenarios, workshop = workshop == true,
              shots = 0, passed = 0, failed = 0, skipped = 0 }
    log("Lauf gestartet" .. (workshop and " (Workshop-Bilder)" or "") .. ": " .. #sizes .. " Aufloesung(en), "
        .. #scenarios .. " Szenarien. Dieselbe Taste bricht ab.")
end

function M.finish(reason)
    local run = M.run
    if not run then return end
    M.run = nil
    M.hideProgress()
    local summary = string.format("%d Bilder, %d Pruefungen ok, %d FEHL, %d Szenarien entfallen",
        run.shots, run.passed, run.failed, run.skipped)
    pcall(function()
        run.writer:write("ende|" .. tostring(reason or "fertig") .. "|" .. summary .. "\r\n")
        run.writer:close()
    end)
    local screen = M.screen()
    if screen then
        pcall(closeAll, screen)
        pcall(function() screen:resetBuild() end)
    end
    if run.changed then
        pcall(setSize, run.original[1], run.original[2], run.original[3], run.original[4])
        writeRestore(nil)
        -- Das Zurueckstellen loest Vanillas 75-Prozent-Regel noch einmal aus;
        -- danach bekommt der Bildschirm seine Startgroesse wieder.
        M.afterRun = { due = now() + M.WAIT_RESOLUTION }
    end
    log("Lauf " .. tostring(reason or "fertig") .. ": " .. summary .. ". Protokoll: Zomboid/Lua/" .. M.LOGFILE)
    if screen and TFX() and TFX().Panel and TFX().Panel.showToast then
        pcall(TFX().Panel.showToast, screen, "Measure run " .. tostring(reason or "done") .. ": " .. summary,
            run.failed > 0 and "warn" or nil, 8000)
    end
end

function M.abort(reason)
    M.finish("abgebrochen (" .. tostring(reason) .. ")")
end

--- Ein Schritt des Laufs. Aufgerufen aus jedem Takt; tut nur etwas, wenn
-- die Wartezeit des vorigen Schritts um ist.
--- Zaehlt Bilder, solange ein Messfenster offen ist. Jeder Takt ist ein Bild
-- (OnFETick im Menue, OnTick in der Welt).
function M.countFrame()
    local run = M.run
    if run and run.frames then run.frames = run.frames + 1 end
end

function M.pump()
    M.countFrame()
    -- Ein Tastendruck merkt nur vor (M.key); gestartet, abgebrochen und
    -- zurueckgestellt wird hier im Takt.
    if M.wanted then
        local wanted = M.wanted
        M.wanted = nil
        M.start(wanted.onlyCurrent, wanted.workshop)
        return
    end
    if M.afterRun and now() >= M.afterRun.due then
        M.afterRun = nil
        local s = M.screen()
        if s then pcall(M.fullSize, s) end
    end
    local run = M.run
    if not run or now() < run.due then return end
    local screen = M.screen()
    if not screen then return M.abort("die Charaktererstellung ist nicht mehr zu sehen") end

    if run.phase == "size" then
        run.sizeIndex = run.sizeIndex + 1
        local size = run.sizes[run.sizeIndex]
        if not size then return M.finish("fertig") end
        run.scenarioIndex = 0
        local changed = run.changed and setSize(size[1], size[2], false)
        run.phase = "fit"
        run.due = now() + (changed and M.WAIT_RESOLUTION or 100)
        log("Aufloesung " .. size[1] .. "x" .. size[2])
    elseif run.phase == "fit" then
        if run.changed then pcall(M.fullSize, screen) end
        run.phase = "setup"
        run.due = now() + M.WAIT_SETTLE
    elseif run.phase == "setup" then
        run.scenarioIndex = run.scenarioIndex + 1
        local scenario = run.scenarios[run.scenarioIndex]
        if not scenario then
            run.phase = "size"
            run.due = now()
            return
        end
        closeAll(screen)
        local size = run.sizes[run.sizeIndex]
        local step = (run.sizeIndex - 1) * #run.scenarios + run.scenarioIndex
        -- Die Workshop-Bilder laufen ohne Anzeige: sie stuende sonst im Bild.
        if run.workshop then
            M.hideProgress()
        else
            pcall(M.showProgress, string.format("Measure run %d/%d  %dx%d  %s", step, #run.sizes * #run.scenarios,
                size[1], size[2], scenario.name))
        end
        local ok, ready, why = pcall(scenario.run, screen)
        if ok and ready then
            -- Erst zur Ruhe kommen lassen, dann eine Sekunde lang Bilder
            -- zaehlen, dann aufnehmen. Die FPS-Anzeige des Spiels und
            -- getAverageFPS taugen dafuer nicht: die eine ist ein Momentwert
            -- direkt nach dem Laden des Builds, die andere glaettet ueber
            -- mehrere Szenarien (Lauf 20.09.2026: 19 gegen 51 im selben Bild).
            run.phase = "idle"
            run.due = now() + M.WAIT_SETTLE
        else
            run.skipped = run.skipped + 1
            local size = run.sizes[run.sizeIndex]
            pcall(function()
                run.writer:write("entfaellt|res=" .. size[1] .. "x" .. size[2] .. "|szenario=" .. scenario.name
                    .. "|" .. tostring(ok and (why or "nicht moeglich (Trait Facts fehlt oder ist aelter)") or ready) .. "\r\n")
            end)
            run.due = now()
        end
    elseif run.phase == "idle" then
        run.frames, run.framesFrom = 0, now()
        run.phase = "record"
        run.due = now() + M.WAIT_FPS
    elseif run.phase == "record" then
        local elapsed = now() - (run.framesFrom or now())
        run.fpsOwn = (run.frames and elapsed > 0) and math.floor(run.frames * 1000 / elapsed + 0.5) or nil
        run.frames = nil
        local size = run.sizes[run.sizeIndex]
        local scenario = run.scenarios[run.scenarioIndex]
        if run.fpsOwn then
            pcall(function()
                local core = getCore()
                run.writer:write("wert|res=" .. core:getScreenWidth() .. "x" .. core:getScreenHeight()
                    .. "|szenario=" .. scenario.name .. "|fps-ruhe=" .. run.fpsOwn
                    .. "|gezaehlt ueber " .. M.WAIT_FPS .. " ms vor der Aufnahme\r\n")
            end)
        end
        local ok, passed, failed = pcall(M.record, run.writer, screen, size, scenario.name)
        if ok then
            run.passed, run.failed = run.passed + passed, run.failed + failed
        else
            pcall(function() run.writer:write("fehler|" .. scenario.name .. "|" .. tostring(passed) .. "\r\n") end)
        end
        local core = getCore()
        local name = string.format("TF_%s%dx%d_%02d_%s.png", run.workshop and "WS_" or "",
            core:getScreenWidth(), core:getScreenHeight(), run.scenarioIndex, scenario.name)
        if takeScreenshot then
            pcall(takeScreenshot, name)
            run.shots = run.shots + 1
        end
        run.phase = "setup"
        run.due = now() + M.WAIT_SHOT
    end
end

--- Tastendruck: nur vormerken. Im Handler selbst passiert nichts, wie im
-- uebrigen Mess-Mod (TFMeasure.taste): Arbeit im Tasten-Handler hat am
-- 10.09.2026 das Spiel aufgehaengt. F7 nur ohne Debug-Modus, dort gehoeren
-- die F-Tasten dem Spiel.
function M.key(key)
    if not Keyboard then return end
    local ohneDebug = not (isDebugEnabled and isDebugEnabled())
    if not (key == Keyboard.KEY_NUMPAD7 or (ohneDebug and key == Keyboard.KEY_F7)) then return end
    local ctrl, shift = false, false
    pcall(function()
        ctrl = isCtrlKeyDown() and true or false
    end)
    pcall(function()
        shift = isShiftKeyDown() and true or false
    end)
    M.wanted = { onlyCurrent = ctrl, workshop = shift }
end

-- Genau einmal anmelden; die Huellen schlagen ueber die Tabelle nach, ein
-- Neuladen der Datei findet sie also unveraendert vor.
if not M.registered then
    M.registered = true
    Events.OnKeyPressed.Add(function(key) TFMeasureScreen.key(key) end)
    local function tick()
        local ok, err = pcall(TFMeasureScreen.pump)
        if not ok then
            log("Schritt fehlgeschlagen: " .. tostring(err))
            pcall(TFMeasureScreen.abort, "Fehler")
        end
    end
    if Events.OnFETick then Events.OnFETick.Add(tick) end
    if Events.OnTick then Events.OnTick.Add(tick) end
end

log("bereit (" .. M.VERSION .. "). In der Charaktererstellung: Num 7 oder F7 startet den Lauf, mit Strg nur die jetzige Aufloesung.")
