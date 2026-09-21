--- Trait Facts - Suche in den Vorratslisten der Charaktererstellung.
--
-- Ein Suchfeld zwischen der Liste der guten und der schlechten Traits
-- filtert beide beim Tippen auf die Traits, deren Name, Mod oder Wirkung
-- passt (Entscheidung 19.09.2026, Mockup trait-suche-2026-09-19, Variante
-- B). Spec: docs/specs/2026-09-19-trait-suche-design.md.
--
-- Gefiltert wird in der Zeichenhuelle der Listen (TF_Hooks, makeTagDraw):
-- eine nicht passende Zeile gibt ihr y zurueck und ist damit 0 hoch, die
-- Eintraege bleiben in der Liste. Hier stehen Abgleich, Zeilenfilter und
-- das Suchfeld.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Search = TF.Search or {}
TF._orig = TF._orig or {}

local cache = {}

--- Leert den Suchtext-Speicher. Aufgerufen aus TF.Tooltip.forget: neue
-- Pakete und ein Farbschema-Wechsel verwerfen dort dieselben Grundlagen.
function TF.Search.forget()
    cache = {}
end

--- Zerlegt die Eingabe in kleingeschriebene Woerter. Ohne string.gmatch,
-- das gibt es in Kahlua nicht. Steuerzeichen fallen vorher weg: Strg+A
-- kann eines im Text des Felds hinterlassen, und als Suchwort passte es auf
-- nichts (Befund im Spiel 19.09.2026).
-- @return table  Liste der Woerter, leer bei leerer Eingabe
function TF.Search.words(text)
    local out = {}
    if type(text) ~= "string" then return out end
    local s = string.lower((string.gsub(text, "%c", "")))
    local at = 1
    while true do
        local a, b = string.find(s, "%S+", at)
        if not a then break end
        out[#out + 1] = string.sub(s, a, b)
        at = b + 1
    end
    return out
end

local function labelOf(def)
    local ok, v = pcall(function() return def:getLabel() end)
    if ok and v then return tostring(v) end
    return ""
end

--- Haengt die Beschriftung jeder Zeile an, einmal je Text. Fussnoten zaehlen
-- nicht: sie machten "zombie" oder "level" zu Treffern ueberall. Wirkungslose
-- Zeilen (dead) ebenso wenig: "carry" fand sonst Puny ueber eine
-- Tragekapazitaet, die nie greift (Befund im Spiel 19.09.2026).
local function addRows(effects, seen, list)
    if type(list) ~= "table" then return end
    for _, entry in ipairs(list) do
        if type(entry) == "table" and type(entry.text) == "string" and not entry.dead then
            local text
            if entry.textArg ~= nil then
                text = TF.fmt.text(entry.text, entry.textArg)
            else
                text = TF.fmt.text(entry.text)
            end
            if type(text) == "string" and text ~= "" and not seen[text] then
                seen[text] = true
                effects[#effects + 1] = { text = text, lower = string.lower(text) }
            end
        end
    end
end

--- Suchtext eines Traits: Name, Kuerzel und Name seines Mods, Beschriftung
-- jeder Wirkung aus hinterlegten, Paket- und live gelesenen Zeilen. Je volle
-- Trait-ID gespeichert, bis TF.Search.forget.
function TF.Search.haystack(def)
    local id = TF.traitId(def) or tostring(def)
    local known = cache[id]
    if known then return known end
    local mod = TF.Mods and TF.Mods.traitMod and TF.safe("search:mod", TF.Mods.traitMod, def) or nil
    local effects, seen = {}, {}
    addRows(effects, seen, TF.safe("search:static", TF.staticFor, def))
    if TF.Mods and TF.Mods.entriesFor then
        addRows(effects, seen, TF.safe("search:package", TF.Mods.entriesFor, def))
    end
    if TF.Live and TF.Live.entries then
        addRows(effects, seen, TF.safe("search:live", TF.Live.entries, def))
    end
    if TF.Live and TF.Live.categoryEntries then
        addRows(effects, seen, TF.safe("search:categories", TF.Live.categoryEntries, def))
    end
    local modText = ""
    if mod then modText = string.lower(tostring(mod.tag or "") .. " " .. tostring(mod.name or "")) end
    local hay = { name = string.lower(labelOf(def)), mod = modText, effects = effects }
    cache[id] = hay
    return hay
end

local function has(text, word)
    return string.find(text, word, 1, true) ~= nil
end

--- Passt der Trait zu den Woertern?
-- @return nil wenn nicht; sonst { reason = "all" | "name" | "mod" | "effect",
--         text = Beschriftung der Wirkung bei "effect" }
function TF.Search.match(def, words)
    if type(words) ~= "table" or #words == 0 then return { reason = "all" } end
    local hay = TF.Search.haystack(def)
    for _, w in ipairs(words) do
        local found = has(hay.name, w) or has(hay.mod, w)
        if not found then
            for _, e in ipairs(hay.effects) do
                if has(e.lower, w) then found = true; break end
            end
        end
        if not found then return nil end
    end
    local allInName = true
    for _, w in ipairs(words) do
        if not has(hay.name, w) then allInName = false; break end
    end
    if allInName then return { reason = "name" } end
    -- Die erste Wirkung, die ein Wort traegt, das nicht schon im Namen steht.
    for _, e in ipairs(hay.effects) do
        for _, w in ipairs(words) do
            if not has(hay.name, w) and has(e.lower, w) then
                return { reason = "effect", text = e.text }
            end
        end
    end
    return { reason = "mod" }
end

--- Setzt den Suchtext eines Bildschirms. Leere Eingabe hebt die Suche auf.
function TF.Search.setText(screen, text)
    if not screen then return end
    -- Der rohe Text, gegen den TF.Search.place in jedem Bild abgleicht.
    local raw = type(text) == "string" and text or ""
    -- Ein neuer Suchtext beginnt oben: war eine Liste heruntergescrollt und
    -- schrumpft unter dem Filter, standen die Treffer oder "No trait
    -- matches." sonst ausserhalb des sichtbaren Bereichs (Audit 20.09.2026).
    if raw ~= (screen.tfSearchRaw or "") then
        for _, list in ipairs({ screen.listboxTrait, screen.listboxBadTrait }) do
            if list and list.setYScroll then TF.safe("search:scroll", list.setYScroll, list, 0) end
        end
    end
    screen.tfSearchRaw = raw
    local words = TF.Search.words(text)
    if #words == 0 then
        screen.tfSearch = nil
    else
        screen.tfSearch = { text = text, words = words, results = {} }
    end
end

local function stateFor(box)
    local screen = box and box.tfSearchOwner
    local state = screen and screen.tfSearch
    if state and state.words and #state.words > 0 then return state end
    return nil
end

local function drawNoMatch(box, y)
    local h = box.fontHgt or 19
    local dy = ((box.itemheight or h) - h) / 2
    box:drawText(TF.fmt.text("UI_TF_search_nomatch"), 10, y + dy, 0.55, 0.55, 0.55, 1,
        UIFont and UIFont.Small or nil)
end

--- Aufgerufen aus der Zeichenhuelle fuer jede Zeile, vor Vanilla.
--
-- Zaehlt die sichtbaren Zeilen je Bild (item.index setzt Vanillas prerender
-- vor jedem doDrawItem) und legt die Summe in box.tfShown ab. Faellt der
-- ausgewaehlte Eintrag aus der Suche, wird er abgewaehlt, damit kein
-- unsichtbarer Trait ausgewaehlt bleibt. Scheitert der Abgleich, wird die
-- Zeile gezeigt, nicht versteckt.
-- @return boolean hide, table|nil match
function TF.Search.filterRow(box, y, item)
    local index = item and item.index or 0
    if index == 1 then box.tfShownCount = 0 end
    local state = stateFor(box)
    local match = nil
    if state then
        local def = item and item.item
        local id = def and (TF.traitId(def) or tostring(def)) or "?"
        local known = state.results[id]
        if known == nil then
            local ok, r = pcall(TF.Search.match, def, state.words)
            if not ok then
                TF.warnOnce("search:match", "Suche fehlgeschlagen: " .. tostring(r))
                r = { reason = "all" }
            end
            known = r or false
            state.results[id] = known
        end
        match = known or nil
    end
    local hide = state ~= nil and match == nil
    if hide then
        if box.selected == index then box.selected = -1 end
    else
        box.tfShownCount = (box.tfShownCount or 0) + 1
    end
    if type(box.items) == "table" and index == #box.items then
        box.tfShown = box.tfShownCount or 0
        if state and box.tfShown == 0 then TF.safe("search:nomatch", drawNoMatch, box, y) end
        -- Zusaetzlich zum Reset bei index == 1: haengt sich ein fremdes
        -- doDrawItem irgendwann vor Zeile 1 aus, zaehlt sonst jedes weitere
        -- Bild auf die alte Summe drauf, und Trefferzahl wie "No trait
        -- matches." driften auseinander (Abschlusspruefung 19.09.2026).
        box.tfShownCount = 0
    end
    return hide, match
end

--- Zeichnet die Trefferzahl rechts im Feld, vor dem Loeschknopf der Engine.
local function drawCount(screen, box)
    if not screen.tfSearch then return end
    local n = (screen.listboxTrait and screen.listboxTrait.tfShown or 0)
        + (screen.listboxBadTrait and screen.listboxBadTrait.tfShown or 0)
    local text = tostring(n)
    local font = UIFont and UIFont.Small or nil
    local w = TF.fmt.measure(text, font)
    local h = box.fontHgt or 19
    box:drawText(text, box:getWidth() - 24 - w, (box:getHeight() - h) / 2, 0.55, 0.55, 0.55, 1, font)
end

--- Legt das Feld in die Zeile zwischen den Vorratslisten, ueber die volle
-- Breite, und blendet beide "Add Trait >" aus (Entscheidung 19.09.2026: der
-- Doppelklick reicht). Ausblenden, nicht entfernen: Vanilla schaltet die
-- Knoepfe weiter mit setEnable und setzt ihre Position in prerender.
-- Laeuft in jedem prerender, weil Vanilla und TF_Panel die Spalten dort
-- jedes Mal neu verteilen.
function TF.Search.place(screen)
    local field = screen and screen.tfSearchField
    if not field then return end
    local list, btn = screen.listboxTrait, screen.addTraitBtn
    field:setX(list:getX())
    field:setWidth(list:getWidth())
    if btn then
        field:setY(btn:getY())
        field:setHeight(btn:getHeight())
    end
    -- Merkt sich, was Vanillas prerender gerade gesetzt hat, bevor wir es
    -- ueberschreiben: TF.Search.restoreAdd braucht diesen Stand, um ihn vor
    -- dem naechsten prerender wiederherzustellen (siehe dort).
    if screen.addTraitBtn and screen.addTraitBtn.isVisible then
        screen.tfAddShown = screen.addTraitBtn:isVisible()
    end
    -- Seit 0.12.9 auch "< Remove Trait" (Wunsch 20.09.2026: ohne die beiden
    -- Add-Knoepfe stand er allein da; der Doppelklick entfernt genauso). Er
    -- braucht keine Wiederherstellung: Vanillas Umschalter liest nur
    -- addTraitBtn:isVisible() (siehe TF.Search.restoreAdd) und blendet ihn
    -- beim Wechsel von Controller auf Maus selbst wieder ein, danach wir aus.
    for _, b in ipairs({ screen.addTraitBtn, screen.addBadTraitBtn, screen.removeTraitBtn }) do
        if b and b.setVisible then b:setVisible(false) end
    end
    -- Die Suche folgt dem Text, der im Feld steht, nicht nur onTextChange:
    -- Strg+A und Entf leerten das Feld, ohne dass die Suche es erfuhr, und
    -- die Listen blieben gefiltert (Befund im Spiel 19.09.2026). Nur bei einer
    -- Aenderung neu aufbauen, sonst ginge der Trefferspeicher jedes Bild verloren.
    if field.getText then
        local text = field:getText() or ""
        if text ~= (screen.tfSearchRaw or "") then TF.Search.setText(screen, text) end
    end
    -- Fuer TF.Search.swallowKey: der Fokus-Stand dieses Bildes. Die Engine
    -- kann dem Feld bei Enter oder Esc den Fokus nehmen, bevor onKeyRelease
    -- den Bildschirm erreicht; dann zaehlt, was hier zuletzt galt.
    screen.tfSearchHadFocus = field.isFocused and field:isFocused() or false
end

--- Enter und Esc im fokussierten Suchfeld.
--
-- Im Spiel erreichen beide Tasten den Bildschirm gar nicht, solange das Feld
-- den Fokus hat (Test im Spiel 20.09.2026: Enter und Esc taten nichts, der
-- Cursor blieb im Feld). Die Engine gibt sie dem Textfeld: Enter ueber
-- onCommandEntered, alles andere ueber onOtherKey, so wie Vanilla es im Chat
-- und im Teleport-Fenster nutzt. Enter gibt den Fokus ab und laesst den Text
-- stehen, Esc leert die Suche und gibt den Fokus ab.
function TF.Search.fieldKey(screen, field, key)
    if not (Keyboard and screen and field) then return end
    if key ~= Keyboard.KEY_ESCAPE and key ~= Keyboard.KEY_RETURN then return end
    screen.tfSearchGuard = { key = key, at = (getTimestampMs and getTimestampMs()) or 0 }
    if key == Keyboard.KEY_ESCAPE then TF.Search.clear(screen) end
    if field.unfocus then field:unfocus() end
    screen.tfSearchHadFocus = false
end

--- Gehoert der Tastendruck dem Suchfeld? MainScreen:onKeyRelease reicht Esc
-- und Return ohne Blick auf den Fokus an den Bildschirm, und dort heisst Esc
-- "Back" und Return "Play" (CharacterCreationProfession.lua 1198-1207): wer
-- im Suchfeld Enter drueckt, startete das Spiel (Audit 20.09.2026). Vanilla
-- sperrt an gleicher Stelle selbst (LoadGameScreen, isFocused).
-- Esc leert die Suche und gibt den Fokus ab, Return gibt nur den Fokus ab;
-- der naechste Druck derselben Taste erreicht Vanilla wieder.
-- @return boolean  true, wenn Vanilla die Taste nicht sehen soll
function TF.Search.swallowKey(screen, key)
    local field = screen and screen.tfSearchField
    if not field or not Keyboard then return false end
    if key ~= Keyboard.KEY_ESCAPE and key ~= Keyboard.KEY_RETURN then return false end
    -- Hat das Feld die Taste selbst schon behandelt (TF.Search.fieldKey),
    -- gehoert auch ihr Loslassen ihm: sonst hiesse Esc nach dem Leeren doch
    -- noch "Back". Die Sperre gilt fuer genau diese Taste und verfaellt nach
    -- einer Sekunde, falls das Loslassen den Bildschirm nie erreicht.
    local guard = screen.tfSearchGuard
    if guard then
        screen.tfSearchGuard = nil
        local now = (getTimestampMs and getTimestampMs()) or 0
        if guard.key == key and now - guard.at < 1000 then return true end
    end
    local focused = (field.isFocused and field:isFocused()) or screen.tfSearchHadFocus
    if not focused then return false end
    if key == Keyboard.KEY_ESCAPE then TF.Search.clear(screen) end
    if field.unfocus then field:unfocus() end
    screen.tfSearchHadFocus = false
    return true
end

--- Vor Vanillas prerender: setzt addTraitBtn/addBadTraitBtn auf den Stand
-- zurueck, den Vanilla vor unserem letzten Ausblenden gesehen hat.
--
-- Vanilla benutzt addTraitBtn:isVisible() als Maus/Joypad-Umschalter
-- (CharacterCreationProfession.lua 767-785, Abschlusspruefung 19.09.2026):
-- steht er dauerhaft auf false, weil wir ihn ausblenden, greift der Zweig
-- fuer den Joypad-Wechsel nie mehr. Dann bleibt tooltipRichText fuer immer
-- unsichtbar - die einzige Stelle, an der Controller-Spieler ueberhaupt
-- eine Trait-Beschreibung lesen, samt jedem Trait-Facts-Text -, und
-- removeTraitBtn bleibt sichtbar stehen. In der Maus greift der Zweig ohne
-- diese Wiederherstellung nur zufaellig, weil Vanilla dort ohnehin jedes
-- Bild neu einblendet.
function TF.Search.restoreAdd(screen)
    if not screen or screen.tfAddShown == nil then return end
    local addBtn, badBtn = screen.addTraitBtn, screen.addBadTraitBtn
    if addBtn and addBtn.setVisible then addBtn:setVisible(screen.tfAddShown) end
    if badBtn and badBtn.setVisible then badBtn:setVisible(screen.tfAddShown) end
end

--- Legt das Suchfeld an, einmal je Bildschirm.
function TF.Search.attach(screen)
    if not screen then return nil end
    if screen.tfSearchField then return screen.tfSearchField end
    if not (ISTextEntryBox and screen.listboxTrait and screen.listboxBadTrait) then return nil end
    local list, btn = screen.listboxTrait, screen.addTraitBtn
    -- Seed fuer TF.Search.restoreAdd: der Stand, den Vanilla gerade gesetzt
    -- hat, bevor TF.Search.place ihn zum ersten Mal ausblendet.
    if btn and btn.isVisible then screen.tfAddShown = btn:isVisible() end
    local y = btn and btn:getY() or (list:getY() + list:getHeight() + 4)
    local h = btn and btn:getHeight() or 24
    local field = ISTextEntryBox:new("", list:getX(), y, list:getWidth(), h)
    field:initialise()
    field:instantiate()
    if field.setClearButton then field:setClearButton(true) end
    if field.setPlaceholderText then field:setPlaceholderText(TF.fmt.text("UI_TF_search_placeholder")) end
    field.onCommandEntered = function(box)
        TF.safe("search:enter", TF.Search.fieldKey, screen, box, Keyboard and Keyboard.KEY_RETURN)
    end
    field.onOtherKey = function(box, key)
        TF.safe("search:key", TF.Search.fieldKey, screen, box, key)
    end
    field.onTextChange = function(box)
        TF.safe("search:type", function() TF.Search.setText(screen, box:getText()) end)
    end
    local baseRender = field.render
    field.render = function(box)
        if baseRender then baseRender(box) end
        TF.safe("search:count", drawCount, screen, box)
    end
    screen:addChild(field)
    screen.tfSearchField = field
    list.tfSearchOwner = screen
    screen.listboxBadTrait.tfSearchOwner = screen
    TF.Search.place(screen)
    return field
end

--- Leert Feld und Suche. Berufswechsel, "Reset Traits" und "Random" laufen
-- alle ueber onSelectProf (Entscheidung 19.09.2026).
function TF.Search.clear(screen)
    if not screen then return end
    local field = screen.tfSearchField
    if field and field.setText then field:setText("") end
    screen.tfSearch, screen.tfSearchRaw = nil, ""
end

-- `before` ist optional und laeuft vor dem Original (z.B. TF.Search.restoreAdd
-- muss vor Vanillas prerender wieder herstellen, was Vanillas eigener
-- Maus/Joypad-Umschalter sieht); `after` laeuft immer danach, wie bisher.
-- Beide unter TF.safe, der Rueckgabewert des Originals bleibt unveraendert.
local function wrap(name, key, after, before)
    if TF._orig[key] then return end
    local original = CharacterCreationProfession[name]
    if type(original) ~= "function" then
        TF.warn("CharacterCreationProfession." .. name .. " nicht gefunden, die Trait-Suche entfaellt.")
        return
    end
    TF._orig[key] = original
    CharacterCreationProfession[name] = function(self, ...)
        if before then TF.safe(key .. ":before", before, self) end
        local result = TF._orig[key](self, ...)
        TF.safe(key, after, self)
        return result
    end
end

local function install()
    if not CharacterCreationProfession then return end
    wrap("create", "search:create", TF.Search.attach)
    wrap("prerender", "search:prerender", TF.Search.place, TF.Search.restoreAdd)
    wrap("onSelectProf", "search:onSelectProf", TF.Search.clear)
    -- Eigene Huelle: hier entscheidet das Ergebnis, ob Vanilla ueberhaupt
    -- laeuft. Scheitert die Pruefung, laeuft Vanilla wie immer.
    local key = "search:onKeyRelease"
    if not TF._orig[key] and type(CharacterCreationProfession.onKeyRelease) == "function" then
        TF._orig[key] = CharacterCreationProfession.onKeyRelease
        CharacterCreationProfession.onKeyRelease = function(self, pressed, ...)
            if TF.safe(key, TF.Search.swallowKey, self, pressed) == true then return end
            return TF._orig[key](self, pressed, ...)
        end
    end
end

Events.OnGameBoot.Add(function()
    TF.safe("install:search", install)
end)
