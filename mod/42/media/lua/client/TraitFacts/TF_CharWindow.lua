--- Trait Facts - das Charakterfenster im Spiel (Taste C), seit 0.14.6.
--
-- Entscheidung 24.09.2026, Mockup docs/mockups/charakterfenster-2026-09-24
-- (Stand 3, freigegeben). Zwei Teile:
--
--  1. Die Trait-Symbole im Reiter Info (ISCharacterScreen) zeigen beim
--     Ueberfahren denselben Tooltip wie die Trait-Listen der
--     Charaktererstellung: Vanillas Name und Beschreibung, darunter der Block
--     aus TF.buildBlock (Wertzeilen, "No effect in the game", Beziehungen),
--     mit denselben Mod-Optionen. Vanilla setzt dort in loadTraits nur
--     setMouseOverText(Name .. "\n" .. Beschreibung); wir haengen nach jedem
--     loadTraits an, auch nach dem aus render, wenn sich Traits geaendert
--     haben (traitsChanged).
--
--  2. Ein Reiter "Trait Facts" an zweiter Stelle, direkt nach Info: die
--     Uebersicht des ganzen Builds (TF.Panel.fillWith) fuer die lebende
--     Figur, schmal unter rund 620 px Breite, breit mit eigener Spalte
--     darueber (TF.Summary.columnsFor). Nur die Liste scrollt, darunter eine
--     Fusszeile mit der Zahl der Traits, dem Beruf und dem Zahnrad der
--     Optionen (dasselbe Fenster wie in der Charaktererstellung).
--
-- Groesse: nur dieser Reiter laesst das Fenster ziehen (rechter Rand, unterer
-- Rand, Ecke; mindestens 390 x 300, hoechstens bis zum Bildschirmrand). Er
-- startet 500 px hoch in der Breite des Reiters Info. Die anderen Reiter
-- setzen ihre Groesse wie bisher selbst in render (ISCharacterScreen:render
-- ueber setWidthAndParentWidth); das tun sie nur, solange sie sichtbar sind,
-- also kaempft hier nichts gegeneinander. Die gezogene Groesse gilt je
-- Spielerin und Spieler (playerNum) und kommt beim Zurueckwechseln wieder;
-- fuer Spieler 1 (playerNum 0) steht sie ausserdem im Layout-Speicher des
-- Spiels (layout.ini ueber ISLayoutManager, dort meldet Vanilla nur dieses
-- eine Fenster an) und gilt damit auch nach dem Neustart.
--
-- Aktualitaet: Traits aendern sich im Spiel (Gewicht, Stufen-Traits, Mods,
-- die Traits vergeben). Der Reiter liest den Stand neu, wenn er sichtbar
-- wird, und vergleicht danach etwa alle 30 Bilder eine billige Kennung der
-- Traits und des Berufs; nur wenn sie sich aendert (oder die Breite, oder
-- eine Mod-Option), entsteht die Uebersicht neu, mit gleicher Scrollstelle.
--
-- Oberste Regel wie ueberall: Vanilla laeuft immer zuerst und unveraendert,
-- jeder eigene Schritt unter TF.safe.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.CharWindow = TF.CharWindow or {}
TF._orig = TF._orig or {}

local CW = TF.CharWindow

--- Kleinste Groesse des Fensters mit diesem Reiter, Starthoehe, und wie oft
-- (in Bildern) der Stand der Figur verglichen wird.
CW.MIN_W, CW.MIN_H = 390, 300
CW.START_H = 500
CW.CHECK_FRAMES = 30

--- Die gezogene Groesse je playerNum: { w = Breite, h = Hoehe } des Fensters.
CW.sizes = CW.sizes or {}

-- Innenabstand des Reiters; der Griff am rechten Rand ist schmaler und liegt
-- damit nie ueber der Scrollleiste der Liste.
local PAD = 8
local GRIP = 6
-- Abstand zwischen Liste und Fusszeile.
local GAP = 4

--- Der Name des Reiters. Der Schluessel UI_TF_charTab heisst in jeder
-- Sprache "Trait Facts"; fehlt er (oder liefert das Spiel den Schluessel
-- selbst zurueck), gilt der Name direkt.
function CW.tabName()
    local text = getTextOrNull and getTextOrNull("UI_TF_charTab") or nil
    if type(text) ~= "string" or text == "" or text == "UI_TF_charTab" then return "Trait Facts" end
    return text
end

local function fontHeight(font)
    local manager = getTextManager and getTextManager()
    local h = manager and manager.getFontHeight and manager:getFontHeight(font)
    if type(h) ~= "number" or h <= 0 then return 19 end
    return h
end

--- Hoehe der Fusszeile: die eines Vanilla-Knopfs (FONT_HGT_SMALL + 6).
local function footerHeight()
    return fontHeight(UIFont and UIFont.Small) + 6
end

local function setSize(el, w, h)
    if not el then return end
    if w and el:getWidth() ~= w then el:setWidth(w) end
    if h and el:getHeight() ~= h then el:setHeight(h) end
end

local function titleBar(win)
    if win.titleBarHeight then return win:titleBarHeight() end
    return 16
end

local function resizeBar(win)
    if win.resizeWidgetHeight then return win:resizeWidgetHeight() end
    return 0
end

--- Der Bildschirmbereich dieser Spielerin oder dieses Spielers: im
-- geteilten Bildschirm das eigene Viertel, sonst der ganze Bildschirm.
-- @return number, number, number|nil, number|nil  links, oben, Breite, Hoehe
local function screenBox(playerNum)
    local left, top, w, h = 0, 0, nil, nil
    pcall(function()
        left, top = getPlayerScreenLeft(playerNum), getPlayerScreenTop(playerNum)
        w, h = getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum)
    end)
    if type(w) ~= "number" or w <= 0 or type(h) ~= "number" or h <= 0 then
        left, top, w, h = 0, 0, nil, nil
        pcall(function() w, h = getCore():getScreenWidth(), getCore():getScreenHeight() end)
    end
    if type(left) ~= "number" then left = 0 end
    if type(top) ~= "number" then top = 0 end
    return left, top, w, h
end

--- Klemmt eine Fenstergroesse auf das Erlaubte: hoechstens bis zum Rand des
-- Bildschirms, mindestens MIN_W x MIN_H (das Minimum gewinnt, wenn das
-- Fenster schon nah am Rand steht).
function CW.clamp(win, w, h, playerNum)
    local left, top, sw, sh = screenBox(playerNum)
    w, h = math.floor((w or CW.MIN_W) + 0.5), math.floor((h or CW.START_H) + 0.5)
    if sw and win and win.getX then
        local most = left + sw - win:getX()
        if w > most then w = math.floor(most) end
    end
    if sh and win and win.getY then
        local most = top + sh - win:getY()
        if h > most then h = math.floor(most) end
    end
    if w < CW.MIN_W then w = CW.MIN_W end
    if h < CW.MIN_H then h = CW.MIN_H end
    return w, h
end

--- Die Startgroesse: die Breite des Reiters Info, 500 px hoch.
local function defaultSize(win)
    local w = CW.MIN_W
    local screen = win and win.charScreen
    if screen and screen.getWidth then
        local own = screen:getWidth()
        if type(own) == "number" and own > w then w = own end
    end
    return { w = w, h = CW.START_H }
end

local function remember(playerNum, w, h)
    local s = CW.sizes[playerNum]
    if not s then
        CW.sizes[playerNum] = { w = w, h = h }
    elseif s.w ~= w or s.h ~= h then
        s.w, s.h = w, h
    end
end

-- ---------------------------------------------------------------------------
-- Stand der Figur

--- Traits und Beruf der lebenden Figur, dazu eine Kennung, die sich genau
-- dann aendert, wenn sich einer von beiden aendert. Alle bekannten Traits,
-- nicht nur die mit Symbol wie in Vanillas Reiter Info.
-- @return table, userdata|nil, string  Definitionen, Berufsdefinition, Kennung
function CW.readCharacter(playerNum)
    local player = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    if not player then return {}, nil, "none" end
    local traits, parts = {}, {}
    pcall(function()
        local known = player:getCharacterTraits():getKnownTraits()
        for i = 0, known:size() - 1 do
            local trait = known:get(i)
            parts[#parts + 1] = tostring(trait)
            local def = CharacterTraitDefinition.getCharacterTraitDefinition(trait)
            if def then traits[#traits + 1] = def end
        end
    end)
    local profession = nil
    pcall(function()
        local descriptor = player:getDescriptor()
        local prof = descriptor and descriptor:getCharacterProfession()
        if prof then
            parts[#parts + 1] = "prof:" .. tostring(prof)
            profession = CharacterProfessionDefinition.getCharacterProfessionDefinition(prof)
        end
    end)
    return traits, profession, table.concat(parts, ",")
end

--- Die Fusszeile: "Traits: 9 . Park Ranger", mit Vanillas Wort fuer Traits
-- (IGUI_char_Traits, dasselbe wie im Reiter Info) und dem Anzeigenamen des
-- Berufs. Keine eigene Uebersetzung noetig.
function CW.footerText(count, profession)
    local label = getTextOrNull and getTextOrNull("IGUI_char_Traits") or nil
    if type(label) ~= "string" or label == "" then label = "Traits" end
    local text = label .. ": " .. tostring(count or 0)
    if profession then
        local ok, name = pcall(function() return profession:getUIName() end)
        if ok and name and tostring(name) ~= "" then
            text = text .. " " .. TF.fmt.sep() .. " " .. tostring(name)
        end
    end
    return text
end

--- Die tiefste erlaubte Scrollstelle (negativ; 0 = ganz oben). Ohne
-- bekannte Scrollhoehe bleibt der Wert, wie er ist.
local function clampScroll(panel, y)
    local total = panel.getScrollHeight and panel:getScrollHeight() or nil
    if type(total) ~= "number" then return y end
    local lowest = math.min(0, panel:getHeight() - total)
    if y > 0 then y = 0 end
    if y < lowest then y = lowest end
    return y
end

--- Baut die Uebersicht neu, wenn sich Figur, Breite oder Anzeige-Optionen
-- geaendert haben, oder immer mit `force`. Die Scrollstelle bleibt.
-- @return boolean  true, wenn neu gebaut wurde
function CW.refresh(view, force)
    local panel = view and view.tfPanel
    if not (panel and TF.Panel and TF.Panel.fillWith) then return false end
    local traits, profession, sig = CW.readCharacter(view.playerNum)
    local key = sig .. "#" .. tostring(TF.viewKey and TF.viewKey() or "") .. "#" .. tostring(panel:getWidth())
    if not force and key == view.tfKey then return false end
    view.tfKey = key
    local scroll = panel.getYScroll and panel:getYScroll() or 0
    TF.Panel.fillWith(panel, traits, profession, { living = true })
    if panel.setYScroll and type(scroll) == "number" and scroll ~= 0 then
        panel:setYScroll(clampScroll(panel, scroll))
    end
    view.tfFooter = CW.footerText(#traits, profession)
    view.tfBuilds = (view.tfBuilds or 0) + 1
    return true
end

-- ---------------------------------------------------------------------------
-- Groesse und Anordnung

--- Setzt Liste, Fusszeile und Zahnrad in die aktuelle Groesse des Reiters.
local function layoutContent(view)
    local w, h = view:getWidth(), view:getHeight()
    local fh = footerHeight()
    local panel = view.tfPanel
    local footY = h - fh - GAP
    if panel then
        panel:setX(PAD)
        panel:setY(PAD)
        setSize(panel, math.max(10, w - 2 * PAD), math.max(10, footY - GAP - PAD))
    end
    view.tfFootY = footY
    local gear = view.tfGearButton
    if gear then
        gear:setX(w - PAD - fh)
        gear:setY(footY)
        setSize(gear, fh, fh)
    end
end

--- Stellt die Griffe an die Raender des Fensters: Vanillas Ecke und
-- Unterkante folgen ihren Ankern ohnehin, der eigene rechte Griff auch;
-- hier stehen sie trotzdem je Bild ausdruecklich, falls ein Anker einmal
-- nicht greift.
local function placeGrips(win, w, h, th, rh)
    local corner, bottom, right = win.resizeWidget, win.resizeWidget2, win.tfGrip
    if corner then corner:setX(w - rh) corner:setY(h - rh) end
    if bottom then bottom:setX(0) bottom:setY(h - rh) setSize(bottom, w - rh, nil) end
    if right then
        right:setX(w - GRIP)
        right:setY(th)
        setSize(right, GRIP, math.max(1, h - th - rh))
    end
end

--- Gibt dem Fenster die Groesse w x h und setzt Reiterleiste, Reiter und
-- Griffe hinein. Die Leiste unten (Vanillas Ziehleiste, rh hoch) bleibt frei.
local function layoutMain(view, w, h)
    local win = view.tfWindow
    local th, rh = titleBar(win), resizeBar(win)
    local tabH = (win.panel and win.panel.tabHeight) or 0
    setSize(win, w, h)
    setSize(win.panel, w, h - th - rh)
    setSize(view, w, h - th - rh - tabH)
    placeGrips(win, w, h, th, rh)
    layoutContent(view)
end

--- Das Hauptfenster wieder fest: nicht ziehbar, alte Mindestgroesse, und
-- die Groesse von vor dem Reiter. Die Vanilla-Reiter setzen danach in
-- ihrem render ohnehin ihre eigene; die alte Groesse gilt fuer jeden, der
-- das nicht tut.
local function leaveMain(win)
    local before = win and win.tfBefore
    if not before then return end
    win.tfBefore = nil
    if win.setResizable then win:setResizable(false) end
    win.minimumWidth, win.minimumHeight = before.minW, before.minH
    if win.tfGrip then win.tfGrip:setVisible(false) end
    setSize(win, before.w, before.h)
    if win.panel and before.pw then setSize(win.panel, before.pw, before.ph) end
end

--- Der Reiter wird sichtbar: im Fenster ziehbar machen und die gemerkte
-- Groesse setzen. Haengt er abgerissen in einem eigenen Fenster, wird das
-- Hauptfenster wieder fest (TF.CharWindow.tornOff kuemmert sich um das
-- neue).
local function enter(view)
    local win = view.tfWindow
    if not win then return end
    view.tfDirty = true
    view.tfFrames = 0
    if view.parent ~= win.panel then
        leaveMain(win)
        return
    end
    if not win.tfBefore then
        win.tfBefore = { w = win:getWidth(), h = win:getHeight(),
                         pw = win.panel and win.panel:getWidth(), ph = win.panel and win.panel:getHeight(),
                         minW = win.minimumWidth, minH = win.minimumHeight }
    end
    if win.setResizable then win:setResizable(true) end
    win.minimumWidth, win.minimumHeight = CW.MIN_W, CW.MIN_H
    if win.tfGrip then win.tfGrip:setVisible(true) end
    local size = CW.sizes[view.playerNum] or defaultSize(win)
    local w, h = CW.clamp(win, size.w, size.h, view.playerNum)
    layoutMain(view, w, h)
    remember(view.playerNum, w, h)
end

local function leave(view)
    local win = view.tfWindow
    if win and view.parent == win.panel then leaveMain(win) end
    if view.tfOptionsPopup and TF.Panel and TF.Panel.closeOptions then TF.Panel.closeOptions(view) end
end

--- Je Bild, solange der Reiter sichtbar ist: die Groesse aus dem Fenster
-- lesen (der Spieler zieht am Fenster, nicht am Reiter), klemmen, merken,
-- alles darin setzen; dann, wenn faellig, den Stand der Figur vergleichen.
function CW.frame(view)
    local win = view.tfWindow
    if not win then return end
    local host = view.parent
    local w, h
    if host == win.panel then
        if not win.tfBefore then enter(view) end
        w, h = CW.clamp(win, win:getWidth(), win:getHeight(), view.playerNum)
        layoutMain(view, w, h)
    elseif host and host.getWidth then
        -- Abgerissen (ISTabPanel:onMouseUpOutside): der Reiter fuellt sein
        -- eigenes Fenster unter dessen Titelleiste.
        w, h = CW.clamp(host, host:getWidth(), host:getHeight(), view.playerNum)
        setSize(host, w, h)
        local th = titleBar(host)
        local rh = (host.resizable and resizeBar(host)) or 0
        setSize(view, w, h - th - rh)
        layoutContent(view)
    else
        return
    end
    remember(view.playerNum, w, h)
    local panel = view.tfPanel
    view.tfFrames = (view.tfFrames or 0) + 1
    local widthChanged = panel and panel.tfComposedWidth ~= panel:getWidth()
    if view.tfDirty or widthChanged or view.tfFrames >= CW.CHECK_FRAMES then
        local force = view.tfDirty
        view.tfDirty = false
        view.tfFrames = 0
        CW.refresh(view, force)
    end
end

--- Der Reiter wurde abgerissen (vanilla onTabTornOff hat das neue Fenster
-- eben auf nicht ziehbar gesetzt): das neue Fenster ziehbar, in der
-- gemerkten Groesse; das Hauptfenster wieder fest.
function CW.tornOff(win, view, window)
    leaveMain(win)
    if not window then return end
    if window.setResizable then window:setResizable(true) end
    window.minimumWidth, window.minimumHeight = CW.MIN_W, CW.MIN_H
    local size = CW.sizes[view.playerNum] or defaultSize(win)
    local w, h = CW.clamp(window, size.w, size.h, view.playerNum)
    setSize(window, w, h)
    view.tfDirty = true
end

-- ---------------------------------------------------------------------------
-- Der Reiter selbst

local function scrollBy(view, dy)
    local panel = view.tfPanel
    if not (panel and panel.getYScroll and panel.setYScroll) then return end
    panel:setYScroll(clampScroll(panel, panel:getYScroll() + dy))
end

--- Die Fusszeile, gezeichnet nach den Kindern: eine Linie ueber ihr, links
-- Traits und Beruf in der leisen Farbe der Fussnoten, notfalls gekuerzt,
-- damit sie nicht unter das Zahnrad laeuft.
local function drawFooter(view)
    local y = view.tfFootY
    if not y then return end
    local w = view:getWidth()
    local fh = footerHeight()
    view:drawRect(PAD, y - GAP / 2, w - 2 * PAD, 1, 0.6, 0.3, 0.3, 0.3)
    local text = view.tfFooter
    if not text or text == "" then return end
    local font = UIFont and UIFont.Small
    local room = w - 3 * PAD - fh
    if TF.fmt.kuerze and TF.fmt.measure(text, font) > room then text = TF.fmt.kuerze(text, room, font) end
    local c = (TF.fmt.rgb and TF.fmt.rgb.note) or { 0.55, 0.55, 0.55 }
    view:drawText(text, PAD, y + (fh - fontHeight(font)) / 2, c[1], c[2], c[3], 1, font)
end

local function gearButton(view)
    if not ISButton then return nil end
    local size = footerHeight()
    local b = ISButton:new(0, 0, size, size, "", view, function(target)
        if TF.Panel and TF.Panel.toggleOptions then TF.safe("charwin:options", TF.Panel.toggleOptions, target) end
    end)
    b:initialise()
    b.borderColor = { r = 0.81, g = 0.82, b = 0.81, a = 0.55 }
    b.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 1 }
    local texture = getTexture and getTexture((TF.Panel and TF.Panel.ICON_GEAR) or "media/ui/inventoryPanes/Button_Settings.png")
    if texture and b.setImage then
        b:setImage(texture)
        if b.forceImageSize then
            local inner = math.floor(size * 0.62)
            b:forceImageSize(inner, inner)
        end
    end
    if b.setTooltip then b:setTooltip(TF.fmt.text("UI_TF_opt_title")) end
    if TF.Panel and TF.Panel.quietTooltipAfterClick then TF.Panel.quietTooltipAfterClick(b) end
    view:addChild(b)
    return b
end

--- Legt den Reiter an: ein ISPanelJoypad wie Vanillas Reiter, mit der
-- Uebersicht (TF.Panel.newSummaryPanel) und dem Zahnrad als Kindern. Die
-- Methoden haengen an der Instanz, nicht an einer eigenen Klasse: dann
-- braucht es beim Laden der Datei kein ISPanelJoypad.
function CW.newView(win)
    local base = ISPanelJoypad or ISPanel
    if not base then return nil end
    local view = base:new(0, 8, math.max(CW.MIN_W, win:getWidth()), 200)
    view:initialise()
    if view.noBackground then view:noBackground() end
    view.playerNum = win.playerNum or 0
    view.tfWindow = win
    view.tfTraitFacts = true

    local baseSetVisible = view.setVisible
    view.setVisible = function(v, visible, ...)
        local result = baseSetVisible(v, visible, ...)
        if visible then TF.safe("charwin:enter", enter, v) else TF.safe("charwin:leave", leave, v) end
        return result
    end
    local basePrerender = view.prerender
    view.prerender = function(v, ...)
        if basePrerender then basePrerender(v, ...) end
        TF.safe("charwin:frame", CW.frame, v)
    end
    local baseRender = view.render
    view.render = function(v, ...)
        if baseRender then baseRender(v, ...) end
        TF.safe("charwin:footer", drawFooter, v)
    end
    -- Controller: die Schultertasten wechseln den Reiter wie ueberall im
    -- Fenster, B schliesst es, hoch und runter scrollen die Liste.
    view.onJoypadDown = function(v, button)
        local window = getPlayerInfoPanel and getPlayerInfoPanel(v.playerNum) or nil
        if not (Joypad and window) then return end
        if button == Joypad.LBumper or button == Joypad.RBumper then
            window:onJoypadDown(button)
        elseif button == Joypad.BButton then
            window:close()
        end
    end
    view.onJoypadDirUp = function(v) scrollBy(v, 3 * fontHeight(UIFont and UIFont.Small)) end
    view.onJoypadDirDown = function(v) scrollBy(v, -3 * fontHeight(UIFont and UIFont.Small)) end
    return view
end

--- Kinder des Reiters, nachdem er im Fenster haengt (addChild instanziert
-- ihn; Kinder davor anzulegen hiesse, sie an ein Element ohne Java-Objekt
-- zu haengen).
local function buildContent(view)
    if TF.Panel and TF.Panel.newSummaryPanel and ISRichTextPanel then
        view.tfPanel = TF.Panel.newSummaryPanel(view)
    end
    view.tfGearButton = gearButton(view)
    layoutContent(view)
end

--- Der rechte Griff: ein ISResizeWidget, das nur die Breite zieht. Vanilla
-- kennt nur die Ecke (beides) und die Unterkante (yonly).
local function newGrip(win)
    if not ISResizeWidget then return nil end
    local th = titleBar(win)
    local grip = ISResizeWidget:new(win:getWidth() - GRIP, th, GRIP, math.max(1, win:getHeight() - th), win, false)
    grip.anchorLeft, grip.anchorRight, grip.anchorTop, grip.anchorBottom = false, true, true, true
    grip:initialise()
    grip.tfXOnly = true
    local function drag(g)
        if g.resizing then g:resize(g:getMouseX() - g.downX, 0) end
    end
    grip.onMouseMove = function(g) g.mouseOver = true drag(g) end
    grip.onMouseMoveOutside = function(g) g.mouseOver = false drag(g) end
    -- Beim Ueberfahren und Ziehen ein blauer Streifen, sonst unsichtbar (Mockup).
    grip.render = function(g)
        if g.mouseOver or g.resizing then
            g:drawRect(0, 0, g:getWidth(), g:getHeight(), 0.35, 0.45, 0.72, 1.0)
        end
    end
    grip:setVisible(false)
    win:addChild(grip)
    return grip
end

--- Haengt den Reiter an zweiter Stelle ein. ISTabPanel:addView haengt ans
-- Ende und vergibt die id nach der Laenge der Liste; der Eintrag wird danach
-- nur in viewList verschoben, die id bleibt eindeutig (activateViewById).
function CW.addTab(win)
    local panel = win and win.panel
    if not (panel and panel.addView and type(panel.viewList) == "table") or win.tfView then return end
    local view = CW.newView(win)
    if not view then return end
    win.tfGrip = newGrip(win)
    win.tfView = view
    panel:addView(CW.tabName(), view)
    local list = panel.viewList
    local last = list[#list]
    if last and last.view == view and #list > 2 then
        table.remove(list, #list)
        table.insert(list, 2, last)
    end
    buildContent(view)
    -- Stand der letzten Sitzung: war dieser Reiter offen, ist er es wieder.
    if win.tfRestoreCurrent and panel.activateView then
        win.tfRestoreCurrent = nil
        panel:activateView(CW.tabName())
    end
end

-- ---------------------------------------------------------------------------
-- Tooltips an den Trait-Symbolen im Reiter Info

--- Setzt den Text: Vanillas Name und Beschreibung, darunter der Block.
local function tipText(image)
    image.tfView = TF.viewKey and TF.viewKey() or nil
    local vanilla = image.tfVanillaText
    local block = TF.buildBlock and TF.buildBlock(image.trait) or nil
    local text = vanilla
    if block and vanilla and vanilla ~= "" then
        text = vanilla .. block
    elseif block then
        text = TF.stripLeadingGap(block)
    end
    if image.setMouseOverText then image:setMouseOverText(text) else image.mouseovertext = text end
end

--- Reichert ein Trait-Symbol an, einmal je Symbol: loadTraits legt bei jeder
-- Aenderung neue ISImage an, die unmarkiert sind. Der Grund dunkelt ab und
-- die Kuerzel bekommen Kaestchen wie in den Trait-Listen (TF.darkenTooltip);
-- aendert sich eine Mod-Option, entsteht der Text beim naechsten Ueberfahren
-- neu.
function CW.attachTooltip(image)
    if type(image) ~= "table" or not image.trait or image.tfTip then return end
    image.tfTip = true
    image.tfVanillaText = image.mouseovertext
    TF.safe("charwin:tiptext", tipText, image)
    if TF.darkenTooltip then TF.darkenTooltip(image) end
    local inner = image.updateTooltip
    if type(inner) ~= "function" then return end
    image.updateTooltip = function(img, ...)
        if img.mouseover and TF.viewKey and img.tfView ~= TF.viewKey() then
            TF.safe("charwin:tiptext", tipText, img)
        end
        return inner(img, ...)
    end
end

function CW.decorateTraits(screen)
    for _, image in ipairs((screen and screen.traits) or {}) do
        CW.attachTooltip(image)
    end
end

-- ---------------------------------------------------------------------------
-- Einhaengen

local function wrap(class, name, key, after)
    if TF._orig[key] then return end
    local original = class[name]
    if type(original) ~= "function" then
        TF.warn(tostring(name) .. " nicht gefunden, das Charakterfenster bleibt ohne Trait Facts.")
        return
    end
    TF._orig[key] = original
    class[name] = function(self, ...)
        local result = TF._orig[key](self, ...)
        TF.safe(key, after, self, ...)
        return result
    end
end

--- Merkt die Groesse fuer den Layout-Speicher. Vanilla loescht width und
-- height (die Groesse setzen die Reiter selbst); unsere steht unter
-- eigenen Namen daneben.
local function saveLayout(win, _, layout)
    if type(layout) ~= "table" then return end
    local s = CW.sizes[win.playerNum or 0]
    if s then
        layout.tfWidth = tostring(math.floor(s.w))
        layout.tfHeight = tostring(math.floor(s.h))
    end
    local view = win.tfView
    local open = view and win.panel and view.parent == win.panel
        and win.panel.getActiveView and win.panel:getActiveView() == view
    layout.tfCurrent = open and "true" or nil
end

local function restoreLayout(win, _, layout)
    if type(layout) ~= "table" then return end
    local w, h = tonumber(layout.tfWidth), tonumber(layout.tfHeight)
    if w and h then
        CW.sizes[win.playerNum or 0] = { w = math.max(CW.MIN_W, w), h = math.max(CW.MIN_H, h) }
    end
    win.tfRestoreCurrent = layout.tfCurrent == "true"
end

local function install()
    if ISCharacterScreen then
        wrap(ISCharacterScreen, "loadTraits", "charwin:loadTraits", CW.decorateTraits)
    end
    if not ISCharacterInfoWindow then return end
    -- RestoreLayout laeuft innerhalb von createChildren (RegisterWindow),
    -- also vor addTab: die Groesse steht bereit, wenn der Reiter entsteht.
    wrap(ISCharacterInfoWindow, "RestoreLayout", "charwin:RestoreLayout", restoreLayout)
    wrap(ISCharacterInfoWindow, "SaveLayout", "charwin:SaveLayout", saveLayout)
    wrap(ISCharacterInfoWindow, "createChildren", "charwin:createChildren", CW.addTab)
    -- createChildren reicht ISCharacterInfoWindow.onTabTornOff als Wert an
    -- die Reiterleiste (setOnTabTornOff); die Huelle muss also vor dem
    -- ersten Fenster stehen, wie alles hier (OnGameBoot).
    wrap(ISCharacterInfoWindow, "onTabTornOff", "charwin:onTabTornOff", function(win, view, window)
        if view and view == win.tfView then CW.tornOff(win, view, window) end
    end)
end

Events.OnGameBoot.Add(function()
    TF.safe("install:charwin", install)
end)
