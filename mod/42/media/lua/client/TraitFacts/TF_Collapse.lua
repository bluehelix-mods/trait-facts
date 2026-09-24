--- Trait Facts - Themen der Uebersicht ein- und ausklappen, seit 0.14.12.
--
-- Entscheidung 24.09.2026, Mockup docs/mockups/kategorien-klappen-2026-09-24,
-- Variante B: ein Klick auf die Ueberschrift eines Themas klappt es zu oder
-- auf. Links davor ein kleiner Pfeil, nach unten offen, nach rechts zu; er
-- dreht sich in 0,16 s mit. Zugeklappt steht hinter dem Namen die Zahl der
-- Zeilen, "(9)". Dazu "Collapse all" und "Expand all": im Charakterfenster als
-- Knoepfe in der Fusszeile (TF_CharWindow), in der Charaktererstellung als
-- zwei Symbole in der Kopfzeile (TF_Panel).
--
-- Gilt fuer beide Uebersichten gleich und ueber den Neustart hinaus. Der
-- Zustand steht in Zomboid/Lua/TraitFacts_ui.txt, eine Zeile
-- "collapsed=combat,foraging". Nicht in den Mod-Optionen: dort waere er ein
-- sichtbares Feld, das niemand von Hand pflegen soll. Neue Themen starten
-- offen.
--
-- Wer eine Uebersicht haelt, vergleicht TF.Collapse.epoch mit dem Stand, fuer
-- den er zuletzt gesetzt hat, und setzt bei einer Abweichung neu (TF_Panel
-- prerender, TF.CharWindow.refresh).

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Collapse = TF.Collapse or {}
local C = TF.Collapse

C.FILE = "TraitFacts_ui.txt"
--- Zaehlt jede Aenderung; die Uebersichten setzen bei einer Abweichung neu.
C.epoch = C.epoch or 0
--- Dauer der Drehung in Millisekunden, wie im Mockup.
C.TURN_MS = 160

local closed = nil          -- Menge der zugeklappten Themen, nach dem ersten Lesen
local turns = {}            -- Thema -> { from, to, t0 } fuer die Drehung

local function now()
    local ok, t = pcall(function() return getTimestampMs() end)
    if ok and type(t) == "number" then return t end
    return 0
end

--- Liest die Datei einmal je Sitzung.
local function load()
    if closed then return closed end
    closed = {}
    pcall(function()
        local reader = getFileReader(C.FILE, false)
        if not reader then return end
        while true do
            local line = reader:readLine()
            if line == nil then break end
            local list = string.match(line, "^collapsed=(.*)$")
            if list then
                local start = 1
                while start <= #list do
                    local stop = string.find(list, ",", start, true) or (#list + 1)
                    local id = string.sub(list, start, stop - 1)
                    if string.match(id, "^[%w_]+$") then closed[id] = true end
                    start = stop + 1
                end
            end
        end
        reader:close()
    end)
    return closed
end

local function save()
    local ids = {}
    for id in pairs(load()) do ids[#ids + 1] = id end
    table.sort(ids)
    pcall(function()
        local writer = getFileWriter(C.FILE, true, false)
        if not writer then return end
        writer:write("collapsed=" .. table.concat(ids, ",") .. "\n")
        writer:close()
    end)
end

--- Ob ein Thema zugeklappt ist.
function C.isClosed(group)
    return group ~= nil and load()[group] == true
end

--- Wie weit der Pfeil gerade gedreht ist: 0 offen (nach unten), 1 zu (nach
-- rechts). Waehrend der Drehung dazwischen, mit derselben Kurve wie ueberall
-- (cubic-bezier(.32,.72,.4,1), hier als Ease-out angenaehert).
function C.turn(group)
    local target = C.isClosed(group) and 1 or 0
    local t = turns[group]
    if not t then return target end
    local p = (now() - t.t0) / C.TURN_MS
    if p >= 1 or p < 0 then
        turns[group] = nil
        return target
    end
    local eased = 1 - (1 - p) * (1 - p) * (1 - p)
    return t.from + (t.to - t.from) * eased
end

--- Setzt ein Thema auf zu oder offen. @return boolean  true, wenn sich etwas aenderte
local function put(group, shut)
    local set = load()
    if (set[group] == true) == shut then return false end
    turns[group] = { from = C.turn(group), to = shut and 1 or 0, t0 = now() }
    set[group] = shut or nil
    return true
end

function C.set(group, shut)
    if not group then return end
    if put(group, shut == true) then
        C.epoch = C.epoch + 1
        save()
    end
end

function C.toggle(group)
    C.set(group, not C.isClosed(group))
end

--- Alle genannten Themen zu oder auf, mit einem Speichern.
function C.setAll(groups, shut)
    local changed = false
    for _, group in ipairs(groups or {}) do
        if put(group, shut == true) then changed = true end
    end
    if changed then
        C.epoch = C.epoch + 1
        save()
    end
end

--- Wie viele der genannten Themen zu sind.
function C.countClosed(groups)
    local n = 0
    for _, group in ipairs(groups or {}) do
        if C.isClosed(group) then n = n + 1 end
    end
    return n
end

--- Nur fuer Tests: vergisst den gelesenen Stand.
function C.reset()
    closed, turns = nil, {}
    C.epoch = C.epoch + 1
end

--- Zeichnet ein gefuelltes Dreieck, gedreht: bei t = 0 zeigt es nach unten,
-- bei t = 1 nach rechts. Zeile fuer Zeile mit drawRect, ein Pixel hoch; das
-- Spiel hat kein gedrehtes Polygon.
-- @param ui    Element, auf dem gezeichnet wird (Koordinaten wie drawRect)
-- @param cx, cy  Mitte
-- @param size  Kantenlaenge in Pixeln
function C.drawArrow(ui, cx, cy, size, t, r, g, b, a)
    local h = size * 0.5
    -- Nach unten: oben links, oben rechts, Spitze unten.
    local pts = { { -h, -h * 0.55 }, { h, -h * 0.55 }, { 0, h * 0.75 } }
    local angle = -math.pi / 2 * t
    local ca, sa = math.cos(angle), math.sin(angle)
    local ys, poly = {}, {}
    for i, p in ipairs(pts) do
        local x = p[1] * ca - p[2] * sa
        local y = p[1] * sa + p[2] * ca
        poly[i] = { cx + x, cy + y }
        ys[i] = cy + y
    end
    local top = math.floor(math.min(ys[1], ys[2], ys[3]))
    local bottom = math.ceil(math.max(ys[1], ys[2], ys[3]))
    for row = top, bottom - 1 do
        local yc = row + 0.5
        local lo, hi = nil, nil
        for i = 1, 3 do
            local p, q = poly[i], poly[i % 3 + 1]
            if (p[2] <= yc and q[2] > yc) or (q[2] <= yc and p[2] > yc) then
                local x = p[1] + (yc - p[2]) * (q[1] - p[1]) / (q[2] - p[2])
                if not lo or x < lo then lo = x end
                if not hi or x > hi then hi = x end
            end
        end
        if lo and hi and hi - lo >= 0.5 then
            local x0 = math.floor(lo + 0.5)
            local w = math.max(1, math.floor(hi + 0.5) - x0)
            ui:drawRect(x0, row, w, 1, a, r, g, b)
        end
    end
end
