--- Trait Facts - Vorher/Nachher-Karte an den Mod-Optionen, seit 0.10.0.
--
-- Entscheidung 19.09.2026, Mockup docs/mockups/option-info-2026-09-19.html:
-- beim Ueberfahren einer Checkbox, im Zahnrad-Fenster der Uebersicht
-- (TF_Panel) und unter Optionen > Mods, eine Karte: Name der Option, ein
-- Satz, was sie tut, und derselbe Tooltip zweimal nebeneinander, links mit
-- der Option aus, rechts an. Die Seite, die gerade gilt, traegt einen blauen
-- Rahmen, sonst nichts (keine Beschriftung "Off"/"On", kein Abzeichen). Der
-- Teil, den die Option schaltet, hat links einen blauen Strich; wo er
-- fehlt, steht sein Name leise mit gestricheltem Strich. Beispiele fest:
-- Puny fuer wirkungslose Werte und Ausschluesse, weil er beides hat; Strong
-- und Puny fuer die Farben.
--
-- Bis 0.10.1 oeffnete ein eigenes "i" neben der Checkbox die Karte. Im Spiel
-- (19.09.2026) war das umstaendlich: wer vom "i" zur Checkbox wechselte,
-- verlor die Karte genau dort, wo er sie brauchte. Jetzt oeffnet die
-- Checkbox-Zeile selbst die Karte.
--
-- Die Karte ist ein eigenes Element im UIManager, immer oben, wie ISToolTip.
-- Sie wird bei jedem Oeffnen neu gebaut (zwei Vorschauen, TF.Tooltip.preview)
-- und schliesst sich selbst, sobald die Maus die Zeile verlaesst oder die
-- Checkbox unsichtbar wird: ein unsichtbares Element bekommt kein update mehr.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.OptionInfo = TF.OptionInfo or {}

-- Die Optionen mit "i", nach ihrer ID in TF_Options. `field` ist der
-- Schalter in TF.Tooltip.preview, `section` die Ueberschrift des Abschnitts,
-- den die Option schaltet (der Strich in der Karte).
local ITEMS = {
    showdead = { key = "UI_TF_opt_dead", get = "showDead", field = "dead", section = "UI_TF_tip_nodead" },
    showexcludes = { key = "UI_TF_opt_excludes", get = "showExcludes", field = "excludes",
                     section = "UI_TF_live_excludes" },
}
TF.OptionInfo.ITEMS = ITEMS

-- ISTickBox rechnet mit diesem Abstand zwischen seinen Zeilen, als lokale
-- Konstante (ISUI/ISTickBox.lua, UI_BORDER_SPACING = 10).
local TICK_SPACING = 10

-- Das Blau der Auswahl, wie im Mockup (#73b8ff).
local BLUE = { 0.45, 0.72, 1.0 }
local FRAME = { 0.29, 0.30, 0.29 }

local NL = " <LINE> "

local function trim(s)
    return (string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1"))
end

--- Ein Trait aus der Registry, nach seinem Schluessel (TF.traitKey).
local found = {}
function TF.OptionInfo.findTrait(name)
    if found[name] ~= nil then return found[name] or nil end
    local result = false
    local ok, all = pcall(function() return CharacterTraitDefinition.getTraits() end)
    if ok and all then
        local okSize, size = pcall(function() return all:size() end)
        for i = 0, (okSize and size or 0) - 1 do
            local def = all:get(i)
            if TF.traitKey(def) == name then result = def break end
        end
    end
    found[name] = result
    return result or nil
end

-- Registry-Schluessel der Beispiele. Der Trait, der im Spiel "Puny" heisst,
-- ist intern WEAK (siehe TF_Static).
local PUNY, STRONG = "weak", "strong"

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

--- Was die Karte einer Option zeigt.
-- @return { title, why, current, off, on, section } oder nil fuer eine
--         unbekannte Option; off/on fehlen, wenn das Beispiel fehlt (ein Mod
--         hat Puny entfernt), die Karte zeigt dann nur den Text
function TF.OptionInfo.content(id)
    local item = ITEMS[id]
    if not item then return nil end
    local out = { title = TF.fmt.text(item.key), why = TF.fmt.text(item.key .. "_tooltip"),
                  current = TF.Options[item.get]() == true, section = item.section }
    -- Bis 0.12.13 gab es hier eine Karte ohne `field`: die Farb-Option, links
    -- Gruen und Rot, rechts Blau und Orange. Die Farben kommen seitdem aus den
    -- Spieloptionen (TF.fmt.gameScheme); jede Option hier schaltet einen Abschnitt.
    if not item.field then return out end
    local puny = TF.OptionInfo.findTrait(PUNY)
    if puny then
        -- Die anderen Optionen, wie sie gerade stehen: die Vorschau zeigt,
        -- was der Spieler mit seinen Einstellungen saehe.
        local base = { scheme = TF.Options.scheme(), dead = TF.Options.showDead(),
                       excludes = TF.Options.showExcludes(), ghost = true }
        local off, on = copy(base), copy(base)
        off[item.field], on[item.field] = false, true
        out.off = TF.Tooltip.preview(puny, off)
        out.on = TF.Tooltip.preview(puny, on)
    end
    return out
end

--- Wo ein Abschnitt in einem gesetzten Rich-Text-Panel steht, in dessen
-- Inhaltskoordinaten (ohne Raender). `lines`/`lineY` sind Segmente, nicht
-- Zeilen (ISRichTextPanel:paginate beginnt bei jedem Tag ein neues). Der
-- Abschnitt beginnt mit der Ueberschrift `heading` (mit oder ohne
-- Doppelpunkt, ohne ist der leise Platzhalter) und endet vor der naechsten
-- bekannten Ueberschrift oder am Ende.
-- @return top, bottom oder nil
function TF.OptionInfo.span(lines, lineY, lineH, heading)
    local stops = {}
    for _, key in ipairs({ "UI_TF_tip_nodead", "UI_TF_live_excludes", "UI_TF_live_grants" }) do
        local text = TF.fmt.text(key)
        if text ~= heading then
            stops[text] = true
            stops[text .. ":"] = true
        end
    end
    local top, bottom = nil, 0
    for i, segment in ipairs(lines or {}) do
        local text, y = trim(segment), lineY[i] or 0
        -- Ein Tag beginnt ein Segment, oft ein leeres, schon auf der Zeile
        -- der naechsten Ueberschrift: es zaehlt nicht.
        if text == "" then
            -- nichts
        elseif top == nil then
            if text == heading or text == heading .. ":" then top, bottom = y, y + lineH end
        elseif y > top and stops[text] then
            break
        elseif y >= top then
            bottom = math.max(bottom, y + lineH)
        end
    end
    if top == nil then return nil end
    return top, bottom
end

local function fontHeight(font)
    local manager = getTextManager and getTextManager()
    return (manager and manager.getFontHeight and manager:getFontHeight(font)) or 19
end

local function tooltipFont()
    if ISToolTip and type(ISToolTip.GetFont) == "function" then
        local ok, font = pcall(ISToolTip.GetFont)
        if ok and font then return font end
    end
    return UIFont.NewSmall
end

local function richPanel()
    local panel = ISRichTextPanel:new(0, 0, 10, 10)
    panel.autosetheight = true
    panel.background = false
    panel:setMargins(8, 6, 8, 6)
    return panel
end

--- Setzt Text ohne Umbruch und macht das Panel so breit wie die breiteste
-- Zeile, wie ISToolTip:layoutContents.
local function fitText(panel, text, font)
    panel.defaultFont = font
    panel.text = text or ""
    panel.maxLineWidth = 1000
    panel:setWidth(panel.marginLeft + panel.marginRight)
    panel:paginate()
    local widest = 0
    for i, segment in ipairs(panel.lines or {}) do
        widest = math.max(widest, (panel.lineX[i] or 0) + TF.fmt.measure(trim(segment), font))
    end
    panel.maxLineWidth = nil
    panel:setWidth(widest + panel.marginLeft + panel.marginRight + 2)
    panel:paginate()
end

-- Die eine Karte; entsteht beim ersten Ueberfahren.
local card = nil

local function drawDashed(c, x, top, bottom)
    local y = top
    while y < bottom do
        c:drawRect(x, y, 2, math.min(3, bottom - y), 1, FRAME[1] + 0.1, FRAME[2] + 0.1, FRAME[3] + 0.1)
        y = y + 6
    end
end

local function drawFrames(c)
    for i, side in ipairs(c.tfSides or {}) do
        if side:isVisible() then
            local x, y, w, h = side:getX(), side:getY(), side:getWidth(), c.tfSideH or side:getHeight()
            if c.tfCurrent == i then
                c:drawRectBorder(x - 2, y - 2, w + 4, h + 4, 1, BLUE[1], BLUE[2], BLUE[3])
                c:drawRectBorder(x - 1, y - 1, w + 2, h + 2, 1, BLUE[1], BLUE[2], BLUE[3])
            else
                c:drawRectBorder(x - 1, y - 1, w + 2, h + 2, 1, FRAME[1], FRAME[2], FRAME[3])
            end
            local heading = c.tfSection and TF.fmt.text(c.tfSection)
            if heading then
                local top, bottom = TF.OptionInfo.span(side.lines, side.lineY, fontHeight(side.defaultFont), heading)
                if top then
                    local bx = x + side.marginLeft - 6
                    top, bottom = y + side.marginTop + top, y + side.marginTop + bottom
                    if i == 2 then
                        c:drawRect(bx, top, 2, bottom - top, 1, BLUE[1], BLUE[2], BLUE[3])
                    else
                        drawDashed(c, bx, top, bottom)
                    end
                end
            end
        end
    end
end

function TF.OptionInfo.hide()
    if not card or not card.tfOwner then return end
    card.tfOwner = nil
    card:setVisible(false)
    card:removeFromUIManager()
end

local function ensureCard()
    if card then return card end
    if not (ISPanel and ISRichTextPanel) then return nil end
    card = ISPanel:new(0, 0, 10, 10)
    card:initialise()
    card.backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.97 }
    card.borderColor = { r = 0.6, g = 0.6, b = 0.6, a = 0.8 }
    card.tfHead = richPanel()
    card:addChild(card.tfHead)
    card.tfSides = { richPanel(), richPanel() }
    for _, side in ipairs(card.tfSides) do card:addChild(side) end
    local basePrerender = card.prerender
    card.prerender = function(c)
        -- Schliesst sich selbst, wenn die Zeile nicht mehr unter der Maus
        -- liegt oder verschwunden ist (Zahnrad-Fenster zu, Optionsseite
        -- gewechselt).
        local owner = c.tfOwner
        local still = owner and TF.safe("info:owner", function()
            return owner:isReallyVisible() and owner:isMouseOver() and owner.mouseOverOption == c.tfRow
        end)
        if not still then
            TF.OptionInfo.hide()
            return
        end
        if basePrerender then basePrerender(c) end
    end
    local baseRender = card.render
    card.render = function(c)
        if baseRender then baseRender(c) end
        TF.safe("info:frames", drawFrames, c)
    end
    return card
end

--- Zeigt die Karte zur Option `id` neben Zeile `row` des ISTickBox `owner`.
-- @param ticked  (optional) ob das Haekchen der Zeile gerade gesetzt ist. Unter
--                Optionen > Mods gilt eine Checkbox erst nach "Apply"; die
--                gespeicherte Option sagt dort nicht, was der Spieler gerade
--                angeklickt hat, und der blaue Rahmen blieb nach dem Klick
--                stehen (Abschlusstest 20.09.2026, B6). Das Haekchen gewinnt.
function TF.OptionInfo.show(id, owner, row, ticked)
    local content = TF.OptionInfo.content(id)
    if not content then return end
    if ticked ~= nil then content.current = ticked == true end
    local c = ensureCard()
    if not c then return end
    local pad, gap = 10, 12
    local font = tooltipFont()
    local sides = c.tfSides
    local hasSides = content.off ~= nil and content.on ~= nil
    local core = getCore and getCore()
    local sw = core and core:getScreenWidth() or 1920
    local sh = core and core:getScreenHeight() or 1080
    local sidesW, sideH = 0, 0
    -- Nebeneinander, solange beide auf den Bildschirm passen; sonst
    -- untereinander, "aus" oben. Zwei Tooltips in grosser Schrift sind breiter
    -- als 1280 px, und geklemmt wurde nur links: die rechte Seite, also die
    -- mit der Option an, lief aus dem Bild (Audit 20.09.2026).
    local stacked = false
    -- Passt die Karte untereinander nicht in die Hoehe, eine Schrift kleiner.
    -- Mit Tooltip-Schrift Large und 38px lief sie selbst bei 1920x1080 unten
    -- aus dem Bild (Abnahme 21.09.2026). Die Karte ist eine Vorschau; eine
    -- kleinere Schrift ist besser als eine halbe Karte. Der Kopf braucht grob
    -- vier Zeilen, der Rand zweimal pad.
    local SMALLER = {}
    if UIFont.Large and UIFont.Medium then SMALLER[UIFont.Large] = UIFont.Medium end
    if UIFont.Medium and UIFont.Small then SMALLER[UIFont.Medium] = UIFont.Small end
    local manager = getTextManager and getTextManager()
    local headH = 4 * ((manager and manager.getFontHeight and manager:getFontHeight(UIFont.Small)) or 19)
    while hasSides do
        fitText(sides[1], content.off, font)
        fitText(sides[2], content.on, font)
        sidesW = sides[1]:getWidth() + gap + sides[2]:getWidth()
        sideH = math.max(sides[1]:getHeight(), sides[2]:getHeight())
        stacked = false
        if pad * 2 + sidesW > sw - 8 then
            stacked = true
            sidesW = math.max(sides[1]:getWidth(), sides[2]:getWidth())
            sideH = sides[1]:getHeight() + gap + sides[2]:getHeight()
        end
        local smaller = SMALLER[font]
        if not smaller or pad * 2 + headH + sideH <= sh - 8 then break end
        font = smaller
    end
    for _, side in ipairs(sides) do side:setVisible(hasSides) end
    local head = c.tfHead
    local width = math.max(sidesW, 320)
    head.defaultFont = UIFont.Small
    head.maxLineWidth = nil
    head:setWidth(width)
    head.text = TF.fmt.join({ { text = content.title, color = "label" } }) .. NL
        .. TF.fmt.join({ { text = content.why, color = "note" } })
    head:paginate()
    head:setX(pad - head.marginLeft + 8)
    head:setY(pad - head.marginTop)
    local sidesY = head:getY() + head:getHeight() + 4
    if hasSides then
        sides[1]:setX(pad)
        sides[1]:setY(sidesY)
        if stacked then
            sides[2]:setX(pad)
            sides[2]:setY(sidesY + sides[1]:getHeight() + gap)
        else
            sides[2]:setX(pad + sides[1]:getWidth() + gap)
            sides[2]:setY(sidesY)
        end
    end
    -- Die gemeinsame Rahmenhoehe gilt nur nebeneinander; untereinander
    -- rahmt drawFrames jede Seite in ihrer eigenen Hoehe.
    c.tfSideH = (not stacked) and sideH or nil
    c.tfCurrent = content.current and 2 or 1
    c.tfSection = content.section
    local w = pad * 2 + width
    local h = (hasSides and (sidesY + sideH) or (head:getY() + head:getHeight())) + pad
    c:setWidth(w)
    c:setHeight(h)
    -- Rechts neben die Zeile. Passt es dort nicht hin, links neben das ganze
    -- Element, zu dem sie gehoert (tfAvoid, das Zahnrad-Fenster): links nur
    -- neben die Stelle gesetzt, lag die Karte ueber den Checkboxen (Befund
    -- im Spiel 19.09.2026). Reicht auch dort der Platz nicht, darunter. Nie
    -- ueber den Bildschirmrand.
    row = row or 1
    local rowH = owner.itemHgt or owner:getHeight()
    local ox = owner:getAbsoluteX()
    local oy = owner:getAbsoluteY() + (row - 1) * (rowH + TICK_SPACING)
    local x = ox + owner:getWidth() + 8
    local y = oy - 8
    if x + w > sw - 4 then
        local avoid = owner.tfAvoid or owner
        x = avoid:getAbsoluteX() - w - 8
        if x < 4 then
            x = math.min(ox, sw - w - 4)
            y = avoid:getAbsoluteY() + avoid:getHeight() + 8
        end
    end
    c:setX(math.max(4, x))
    c:setY(math.max(4, math.min(y, sh - h - 4)))
    if not c.tfOwner then
        c:addToUIManager()
        if c.setAlwaysOnTop then c:setAlwaysOnTop(true) end
    end
    c.tfOwner, c.tfId, c.tfRow = owner, id, row
    c.tfView = TF.OptionInfo.view()
    c.tfTicked = ticked
    c:setVisible(true)
    return c
end

--- Der Stand aller Optionen, die die Karte praegen (TF.Options.view).
function TF.OptionInfo.view()
    return TF.Options and TF.Options.view and TF.Options.view() or ""
end

--- Laesst ein ISTickBox die Karte zeigen, solange die Maus ueber einer
-- seiner Zeilen steht (Vanilla fuehrt die Zeile in mouseOverOption,
-- ISTickBox:onMouseMove). `ids` nennt je Zeile die Option, `avoid` (optional)
-- was die Karte nicht verdecken soll, wenn sie links stehen muss
-- (TF.OptionInfo.show). Ueber update, das Vanilla je Bild ruft, solange das
-- Element sichtbar ist.
function TF.OptionInfo.watch(box, ids, avoid)
    if not box then return end
    box.tfInfoIds, box.tfAvoid = ids, avoid
    local baseUpdate = box.update
    box.update = function(s)
        if baseUpdate then baseUpdate(s) end
        TF.safe("info:hover", function()
            local row = s:isMouseOver() and s:isReallyVisible() and s.mouseOverOption or 0
            local id = row > 0 and s.tfInfoIds[row] or nil
            if id then
                -- Neu bauen auch, wenn sich eine Option geaendert hat, waehrend
                -- die Karte offen ist: ein Klick auf die Checkbox setzt den
                -- blauen Rahmen sofort um (Befund im Spiel 19.09.2026: bis
                -- 0.10.2 erst nach Verlassen und erneutem Ueberfahren).
                local ticked = nil
                if s.isSelected then
                    local ok, an = pcall(function() return s:isSelected(row) end)
                    if ok then ticked = an == true end
                end
                local fresh = card and card.tfOwner == s and card.tfRow == row
                    and card.tfView == TF.OptionInfo.view() and card.tfTicked == ticked
                if not fresh then TF.OptionInfo.show(id, s, row, ticked) end
            elseif card and card.tfOwner == s then
                TF.OptionInfo.hide()
            end
        end)
    end
end

--- Optionen > Mods: nach dem Aufbau der Seite zeigt jede unserer Checkboxen
-- die Karte beim Ueberfahren. Vanilla legt je Checkbox ein ISTickBox mit
-- einer leeren Option an (MainOptions:addYesNo) und merkt es sich in
-- option.element. Dessen eigener Tooltip (der Satz aus UI_TF_opt_*_tooltip)
-- faellt weg: die Karte zeigt denselben Satz, beide zugleich stuenden
-- uebereinander.
local function decorateModOptions()
    local data = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.Data
    for _, options in ipairs(data or {}) do
        if options.modOptionsID == TF.Options.ID then
            for _, option in ipairs(options.data or {}) do
                local tick = option.element
                if tick and ITEMS[option.id] then
                    tick.tooltip = nil
                    TF.OptionInfo.watch(tick, { option.id }, tick)
                end
            end
        end
    end
end

local function hookModOptions()
    if TF._orig["info:modoptions"] or not MainOptions then return end
    local original = MainOptions.addModOptionsPanel
    if type(original) ~= "function" then return end
    TF._orig["info:modoptions"] = original
    MainOptions.addModOptionsPanel = function(self, ...)
        local result = TF._orig["info:modoptions"](self, ...)
        TF.safe("info:modoptions", decorateModOptions)
        return result
    end
end

TF.safe("info:hook", hookModOptions)
if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(function() TF.safe("info:hook", hookModOptions) end)
end
