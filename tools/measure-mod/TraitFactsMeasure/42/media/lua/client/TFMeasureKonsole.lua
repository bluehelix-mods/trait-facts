--- Mess-Mod: Knopf "Kopieren" in der Command Console des Spiels (seit 6.46.0).
--
-- Wunsch vom 24.09.2026: den Output Log der Command Console (Debug-Modus,
-- links unten) in die Zwischenablage legen koennen. Die Konsole ist Java
-- (zombie.ui.UIDebugConsole, eine NewWindow); UIManager.getDebugConsole() ist
-- fuer Lua freigegeben, ebenso UIElement und UITextBox2. Der Knopf ist ein
-- gewoehnlicher ISButton, eingehaengt als Kind der Konsole (AddChild): die
-- Konsole zeichnet ihre Kinder und reicht Mausklicks an sie weiter
-- (UIDebugConsole.onMouseDown/onMouseUp rufen super). Er sitzt rechts in der
-- Zeile "Output Log", ausserhalb des Randes, an dem die Konsole sich ziehen
-- laesst, und folgt ihr je Bild, auch nach dem Ziehen.
--
-- Kopiert wird der Text des Output Logs (UITextBox2:getText), mit den Zeilen
-- anderer Mods und des Spiels. Die Konsole haelt davon nur die letzten 8192
-- Zeichen (UIDebugConsole.handleOutput); das ganze Log seit dem Start steht
-- in Zomboid/console.txt. Seit 6.47.0 ohne die Doppel der Lua-Meldungen: die Konsole
-- bekommt jede Lua-Ausgabe zweimal, direkt als ":<Tab>Text" und als
-- "LOG  : Lua  f:N> :<Tab>Text". Die kurze Zeile faellt weg, wenn dieselbe
-- als LOG-Zeile im Text steht; die ohne LOG-Gegenstueck (vor dem Start des
-- Logs) bleiben.

TFMeasureKonsole = TFMeasureKonsole or {}
local K = TFMeasureKonsole

K.TITEL = "Kopieren"
K.KOPIERT_MS = 1500

local function log(text)
    if TFMeasure and TFMeasure.melde then return TFMeasure.melde("[TraitFactsMeasure] Konsole:", text) end
    print("[TraitFactsMeasure] Konsole: " .. tostring(text))
end

local function jetzt()
    local ok, t = pcall(function() return getTimestampMs() end)
    return (ok and type(t) == "number") and t or 0
end

--- Das Textfeld des Output Logs: unter den Kindern der Konsole das hoechste
-- UITextBox2 (die Befehlszeile und die Vorschlagszeile sind eine Zeile hoch).
function K.ausgabe(konsole)
    local beste, hoehe = nil, -1
    pcall(function()
        local kinder = konsole:getControls()
        for i = 0, kinder:size() - 1 do
            local kind = kinder:get(i)
            if instanceof(kind, "UITextBox2") then
                local h = kind:getHeight()
                if h > hoehe then beste, hoehe = kind, h end
            end
        end
    end)
    return beste
end

--- Der Text ohne die kurzen Doppel der Lua-Meldungen (siehe oben).
function K.ohneDoppel(text)
    local zeilen, lang = {}, {}
    local pos = 1
    while pos <= #text do
        local stop = string.find(text, "\n", pos, true) or (#text + 1)
        zeilen[#zeilen + 1] = string.sub(text, pos, stop - 1)
        pos = stop + 1
    end
    -- Verglichen ohne \r am Ende: die LOG-Zeilen kommen ueber System.out und
    -- enden unter Windows auf \r\n, die kurzen ueber den Print-Rueckruf nur
    -- auf \n (im Spiel am 24.09.2026, 6.47.0: 150 Zeilen, kein Doppel weg).
    local function rein(zeile) return (string.gsub(zeile, "\r+$", "")) end
    for _, zeile in ipairs(zeilen) do
        local inhalt = string.match(rein(zeile), "^LOG%s+:%s+Lua%s+f:%d+>%s*:\t(.*)$")
        if inhalt then lang[inhalt] = true end
    end
    local raus = {}
    for _, zeile in ipairs(zeilen) do
        local inhalt = string.match(rein(zeile), "^:\t(.*)$")
        if not (inhalt and lang[inhalt]) then raus[#raus + 1] = zeile end
    end
    local ende = (string.sub(text, -1) == "\n") and "\n" or ""
    return table.concat(raus, "\n") .. ende
end

--- Legt den Output Log in die Zwischenablage. @return number|nil  Zeilen
function K.kopieren(konsole)
    local feld = K.ausgabe(konsole)
    if not feld or not (Clipboard and Clipboard.setClipboard) then return nil end
    local text = nil
    pcall(function() text = feld:getText() end)
    if type(text) ~= "string" then return nil end
    text = K.ohneDoppel(text)
    local ok = pcall(function() Clipboard.setClipboard(text) end)
    if not ok then return nil end
    local _, zeilen = string.gsub(text, "\n", "")
    return zeilen
end

local function schrift()
    return (UIFont and (UIFont.DebugConsole or UIFont.Small))
end

local function knopfBauen(konsole)
    if not ISButton then return nil end
    local font = schrift()
    local tm = getTextManager()
    local breite = tm:MeasureStringX(font, K.TITEL) + 16
    local hoehe = tm:getFontHeight(font) + 2
    local b = ISButton:new(0, 0, breite, hoehe, K.TITEL, nil, function(_, knopf)
        local zeilen = K.kopieren(konsole)
        knopf.tfFertig = jetzt()
        knopf.tfOk = zeilen ~= nil
        if zeilen then
            knopf:setTitle("Kopiert: " .. zeilen .. " Zeilen")
            log("Output Log kopiert, " .. zeilen .. " Zeilen.")
        else
            knopf:setTitle("Nicht kopiert")
            log("Output Log nicht kopiert: kein Textfeld oder keine Zwischenablage.")
        end
    end)
    b.font = font
    b:initialise()
    b:instantiate()
    b.borderColor = { r = 0.7, g = 0.7, b = 1.0, a = 0.6 }
    b.backgroundColor = { r = 0.05, g = 0.05, b = 0.08, a = 0.9 }
    b.tooltip = "Legt den Output Log der Command Console in die Zwischenablage (die letzten 8192 Zeichen)."
    konsole:AddChild(b.javaObject)
    return b
end

--- Je Bild: Knopf an die aktuelle Konsole haengen und an seinen Platz setzen.
function K.tick()
    local konsole = UIManager and UIManager.getDebugConsole and UIManager.getDebugConsole() or nil
    if not konsole then return end
    if K.konsole ~= konsole then
        K.konsole, K.knopf = konsole, nil
        K.knopf = knopfBauen(konsole)
        if K.knopf then log("Knopf Kopieren in der Command Console angelegt.") end
    end
    local b, feld = K.knopf, nil
    if not b then return end
    feld = K.ausgabe(konsole)
    if not feld then return end
    -- Nach dem Kopieren kurz die Rueckmeldung im Titel, dann wieder "Kopieren".
    if b.tfFertig and jetzt() - b.tfFertig > K.KOPIERT_MS then
        b.tfFertig = nil
        b:setTitle(K.TITEL)
    end
    local font = b.font or schrift()
    local breite = getTextManager():MeasureStringX(font, b.title or K.TITEL) + 16
    if b:getWidth() ~= breite then b:setWidth(breite) end
    -- Rechts in der Zeile "Output Log", buendig mit dem Textfeld und ausserhalb
    -- der 10 px, an denen die Konsole sich ziehen laesst.
    local x = feld:getX() + feld:getWidth() - breite
    local y = feld:getY() - b:getHeight() - 1
    if b:getX() ~= x then b:setX(x) end
    if b:getY() ~= y then b:setY(y) end
end

if Events and not K.angemeldet then
    K.angemeldet = true
    local function sicher() pcall(K.tick) end
    if Events.OnTick then Events.OnTick.Add(sicher) end
    if Events.OnFETick then Events.OnFETick.Add(sicher) end
end
