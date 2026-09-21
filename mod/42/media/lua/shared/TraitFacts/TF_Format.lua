--- Trait Facts - Formatierung.
-- Wandelt einen Eintrag (id/kind/value/text/note) in eine fertige Textzeile.
--
-- Sprachabhaengiges (Dezimaltrennzeichen, Prozent-Abstand) kommt aus der
-- Uebersetzung statt aus einer Sprachliste im Code. Wer eine Sprache ergaenzt,
-- pflegt damit alles an einer Stelle.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.fmt = TF.fmt or {}

--- Uebersetzt einen Schluessel. Fehlt er, wird der Schluesselname angezeigt
-- statt zu werfen - so faellt eine Luecke auf, ohne den Tooltip zu zerstoeren.
function TF.fmt.text(key, ...)
    if not key then return "" end
    local translated = getTextOrNull(key, ...)
    if translated == nil or translated == "" then
        -- Klartext aus einem Paket (TF_Mods): steht so da, ohne Warnung.
        if TF.Mods and TF.Mods.literal and TF.Mods.literal[key] then return tostring(key) end
        TF.warnOnce("i18n:" .. tostring(key), "Uebersetzungsschluessel fehlt: " .. tostring(key))
        return tostring(key)
    end
    return translated
end

--- Fremder Text fuer den Rich-Text: "<" und ">" als &lt; und &gt;.
-- Der Parser wirft bei einem Token mit beiden Klammern alles vor dem "<"
-- weg und liest den Rest als Befehl (siehe TF.fmt.columns); aus
-- "My<Cool>Pack" wurde "Pack", "Super<RED>Mod" faerbte die Zeile rot
-- (Bugjagd 15.09.2026). Vanilla wandelt &lt;/&gt; im Text wieder zurueck
-- (ISRichTextPanel.paginate). Nur fuer Namen aus fremden Mods und Paketen;
-- unsere eigenen Texte tragen keine Klammern.
function TF.fmt.plain(s)
    if s == nil then return "" end
    return (tostring(s):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

--- Zahl mit hoechstens `digits` Nachkommastellen, ohne ueberfluessige Nullen,
-- mit dem Dezimaltrennzeichen der aktiven Sprache.
local function num(value, digits)
    digits = digits or 2
    local s = string.format("%." .. tostring(digits) .. "f", value)
    -- Nur kuerzen, wenn ueberhaupt ein Trennzeichen da ist: sonst wuerde aus
    -- "10" eine "1". Gesucht wird der Punkt woertlich (plain = true), deshalb
    -- steht hier "." und nicht das Muster "%.".
    if s:find(".", 1, true) then
        s = s:gsub("0+$", ""):gsub("%.$", "")
    end
    local sep = getTextOrNull("UI_TF_decimalsep")
    if sep and sep ~= "" and sep ~= "." then
        s = s:gsub("%.", sep)
    end
    return s
end

TF.fmt.num = num

--- Stellt einer Zahl das Vorzeichen voran. Null bleibt vorzeichenlos.
local function signed(value, digits)
    if value > 0 then return "+" .. num(value, digits) end
    return num(value, digits)
end

--- Formatiert den Wert eines Eintrags gemaess `kind`.
-- @return string|nil  nil bei unbekanntem kind oder unbrauchbarem Wert
function TF.fmt.value(kind, value)
    if kind == "pct" then
        if type(value) ~= "number" then return nil end
        return TF.fmt.text("UI_TF_fmt_pct", signed(value, 1))
    elseif kind == "mult" then
        -- Faktoren werden als Prozentaenderung angezeigt, damit im Tooltip
        -- durchgehend dieselbe Schreibweise steht. In den Daten bleibt der
        -- Faktor stehen: das ist die Zahl aus der Engine, und die Messung in
        -- Schicht 2 liefert ebenfalls Verhaeltnisse, keine Prozentwerte.
        if type(value) ~= "number" then return nil end
        return TF.fmt.value("pct", (value - 1) * 100)
    elseif kind == "flat" then
        if type(value) ~= "number" then return nil end
        return signed(value, 2)
    elseif kind == "count" then
        -- Eine Anzahl bekommt kein Vorzeichen, aber ein "x": "Free recipes:
        -- 15x", nicht "+15" und nicht die nackte "15" (Entscheidung
        -- 12.09.2026: der Buchstabe x, nicht das Malzeichen).
        if type(value) ~= "number" then return nil end
        return num(value, 0) .. "x"
    elseif kind == "range" then
        if type(value) ~= "table" or #value < 2 then return nil end
        return TF.fmt.text("UI_TF_fmt_range", num(value[1], 2), num(value[2], 2))
    elseif kind == "pctrange" then
        -- "+13 to +16%": beide Enden mit Vorzeichen, das Prozentzeichen einmal.
        if type(value) ~= "table" or #value < 2 then return nil end
        if type(value[1]) ~= "number" or type(value[2]) ~= "number" then return nil end
        return TF.fmt.text("UI_TF_fmt_range", signed(value[1], 1),
            TF.fmt.text("UI_TF_fmt_pct", signed(value[2], 1)))
    elseif kind == "fromto" then
        -- Beide Werte sind Prozent ohne Vorzeichen: "from 92% to 94%".
        if type(value) ~= "table" or #value < 2 then return nil end
        return TF.fmt.text("UI_TF_fmt_fromto",
            TF.fmt.text("UI_TF_fmt_pct", num(value[1], 1)),
            TF.fmt.text("UI_TF_fmt_pct", num(value[2], 1)))
    elseif kind == "bool" then
        -- In Lua ist nur nil und false falsch, die 0 ist wahr. Ohne diese
        -- Pruefung machte ein versehentliches `value = 0` aus einem Nein ein
        -- Ja - still, denn die Zeile entstuende ja. Lieber keine Zeile.
        if type(value) ~= "boolean" then return nil end
        return TF.fmt.text(value and "UI_TF_yes" or "UI_TF_no")
    end
    return nil
end

--- Einheit hinter dem Wert.
--
-- Zwei Sorten, am Schluessel unterscheidbar:
--   UI_TF_sym_*   Symbol, haengt direkt am Wert: "+36 Grad"
--   UI_TF_unit_*  Wort, mit Leerzeichen: "+20 out of 100". Gibt es dazu eine
--                 Einzahl (Schluessel .. "_one"), gilt sie bei Betrag 1.
--
-- Beide kommen aus der Uebersetzung, nie als Literal aus den Daten. Das
-- Gradzeichen stand einmal direkt in TF_Static.lua und kam im Spiel falsch an;
-- Vanilla haelt es genauso, Sonderzeichen stehen ausschliesslich in den
-- JSON-Dateien. Ein Literal wird der Rueckwaertskompatibilitaet halber noch
-- durchgereicht, aber check-data.py laesst keines mehr zu.
--
-- Der Grund fuer die Einheit ueberhaupt: ein nacktes "+2" sagt nichts. Jeder
-- Wert, der kein Prozentwert ist, traegt seine Einheit am Wert, nicht im Namen.
function TF.fmt.unit(unit, value)
    if not unit or unit == "" then return "" end
    if unit:sub(1, 10) == "UI_TF_sym_" then return TF.fmt.text(unit) end
    if unit:sub(1, 3) ~= "UI_" then return unit end
    -- Einzahl nach dem angezeigten Wert, nicht nach dem gerechneten: eine
    -- Summe aus Foraging-Boni ist 0.9999999999999999, angezeigt "+1", und
    -- verlangt "tile" (Bugjagd 10.09.2026, Fund 11). Zwei Stellen, wie flat
    -- sie zeigt. Die Typpruefung zuerst: range reicht eine Tabelle herein.
    if type(value) == "number" and math.floor(math.abs(value) * 100 + 0.5) == 100 then
        local one = getTextOrNull(unit .. "_one")
        if one and one ~= "" then return " " .. one end
    end
    return " " .. TF.fmt.text(unit)
end

--- Farben je Zeilenteil, als fertige Rich-Text-Tags mit Leerzeichen drumherum.
--
-- Ohne Palette (nil) entstehen reine Textzeilen; das ist der Zustand in den
-- Tests und ueberall, wo kein ISRichTextPanel rendert. Der Tooltip setzt die
-- Palette beim Laden (TF_Tooltip).
--
-- Felder: label, value, note. Fehlt eines, bleibt der Teil ohne eigenes Tag
-- und erbt die Farbe des vorigen Segments.
TF.fmt.palette = TF.fmt.palette or nil

--- Der Farbname eines Kuerzels, fuer Teile und Laeufe: "tag:TOC".
--
-- Jedes Kuerzel traegt seine eigene Farbe, die seines Mods oder Pakets
-- (Entscheidung 14.09.2026, Mockup trait-auswahl-mod-farben, Zustand 2), und
-- damit einen eigenen Namen. TF.fmt.columns beginnt bei jedem Namenswechsel
-- ein Segment: ein Kuerzel steht so immer allein in seinem Segment, auch
-- neben der Fussnote oder einem anderen Kuerzel gleicher Farbe, und
-- TF.Panel.tagBoxes findet es.
function TF.fmt.tagKey(tag)
    return "tag:" .. tostring(tag)
end

--- Das Rich-Text-Farbtag zu einem Farbnamen.
-- Palettennamen ("note", "source", ...) kommen aus der Palette, "tag:XYZ" in
-- der Farbe des Kuerzels (TF.Mods.tagRich), ein unbekanntes im Grau von
-- `tag`. Ohne Palette leer: dann entsteht reiner Text.
function TF.fmt.paint(palette, name)
    if not palette or name == nil then return "" end
    local fixed = palette[name]
    if fixed then return fixed end
    if type(name) == "string" and string.sub(name, 1, 4) == "tag:" then
        local rich = TF.Mods and TF.Mods.tagRich and TF.Mods.tagRich(string.sub(name, 5))
        return rich or palette.tag or palette.note or ""
    end
    return ""
end

-- ISRichTextPanel beginnt bei jedem Tag ein neues Segment und trimmt den
-- Text davor und danach. Ein Leerzeichen zwischen "Bezeichnung:" und Wert
-- ueberlebt das nicht; dafuer gibt es das Tag <SPACE>, das den Cursor um
-- eine Leerzeichenbreite vorrueckt.
local SPACE = " <SPACE> "

--- Fuegt Teile zu einer Zeile, jeder Teil in seiner Farbe.
-- @param parts  Liste von { text = string, color = Farbname }; Farbname ist
--               ein Palettenname oder "tag:XYZ" (TF.fmt.tagKey)
-- @param palette  optional, sonst TF.fmt.palette
local function joinParts(parts, palette)
    palette = palette or TF.fmt.palette
    if not palette then
        local plain = {}
        for _, part in ipairs(parts) do plain[#plain + 1] = part.text end
        return table.concat(plain, " ")
    end
    local out = {}
    for index, part in ipairs(parts) do
        local tag = TF.fmt.paint(palette, part.color)
        if index > 1 then
            -- Nach einem Farbtag faellt das Leerzeichen weg; SPACE ersetzt es.
            out[#out + 1] = (tag ~= "" and (tag .. SPACE) or " ") .. part.text
        else
            out[#out + 1] = tag .. part.text
        end
    end
    return table.concat(out, "")
end

--- Fuegt Teile zu einer durchlaufenden Zeile (siehe joinParts): die
-- Beziehungslisten im Tooltip und der durchlaufende Satz der Uebersicht.
TF.fmt.join = joinParts

--- Eine Zeile "Bezeichnung: Wert (Fussnote)" mit Farben je Teil.
-- `value` und `note` duerfen nil sein.
-- @param valueColor  optional, ersetzt "value" als Farbe des Werts
function TF.fmt.line(label, value, note, palette, valueColor)
    local parts = {}
    if value ~= nil and value ~= "" then
        parts[#parts + 1] = { text = label .. ":", color = "label" }
        parts[#parts + 1] = { text = value, color = valueColor or "value" }
    else
        parts[#parts + 1] = { text = label, color = "label" }
    end
    if note and note ~= "" then
        parts[#parts + 1] = { text = "(" .. note .. ")", color = "note" }
    end
    return joinParts(parts, palette)
end

--- Die drei Teile eines Eintrags, noch ohne Satz.
--
-- Der durchlaufende Text (TF.fmt.entry) und der Spaltensatz des Tooltips
-- brauchen dieselben Teile, nur anders angeordnet. Hier steht die eine
-- Stelle, die kind prueft, den Wert formatiert und Fussnote und Randbemerkung
-- zusammensetzt; wer die Teile anders setzt, rechnet nichts davon nach.
--
-- @return table|nil  { label, value, note, dead }; value ist nil bei
--                    kind "info", note nil ohne Fussnote. nil, wenn die
--                    Zeile zu ueberspringen ist.
function TF.fmt.parts(entry)
    if type(entry) ~= "table" then return nil end

    if not TF.KINDS[entry.kind] then
        TF.warnOnce("kind:" .. tostring(entry.kind),
            "Unbekannter kind '" .. tostring(entry.kind) .. "' bei Eintrag '"
            .. tostring(entry.id) .. "', Zeile uebersprungen.")
        return nil
    end

    -- kind = "info" traegt keinen Wert: die Zeile ist der Text selbst.
    local value
    if entry.kind ~= "info" then
        value = TF.fmt.value(entry.kind, entry.value)
        if value == nil then
            TF.warnOnce("value:" .. tostring(entry.id),
                "Unbrauchbarer Wert bei Eintrag '" .. tostring(entry.id) .. "', Zeile uebersprungen.")
            return nil
        end
        value = value .. TF.fmt.unit(entry.unit, entry.value)
    end
    local note = entry.note and TF.fmt.text(entry.note) or nil
    -- `hint` ist eine Randbemerkung zu genau diesem Trait, kein
    -- Geltungsbereich. Der Unterschied zaehlt: `note` bestimmt mit, ob zwei
    -- Zeilen in der Gesamtuebersicht derselbe Stat sind, `hint` nicht.
    -- Stuende der Doppelzaehl-Hinweis von Very Low Weight in `note`, wuerde
    -- seine Stolperchance nicht mehr mit der von Clumsy zusammenfallen und
    -- die Uebersicht zeigte zwei Zeilen statt einer Summe.
    -- `condition` ebenso wenig; sie nennt, wann die Zahl genau stimmt, und
    -- bleibt anders als `hint` auch in der Summe stehen (TF.Summary.merge).
    -- Ueber die Feldnamen laufen, nicht ueber { entry.hint, entry.condition }:
    -- ipairs endet am ersten nil, ohne hint kaeme die condition nie an.
    for _, field in ipairs({ "hint", "condition" }) do
        if entry[field] then
            local text = TF.fmt.text(entry[field])
            note = (note and (note .. "; " .. text)) or text
        end
    end
    -- `dead = true`: die Zahl steht so in der Engine, erreicht dort aber
    -- keine Groesse mehr (Beispiel: der Sprint-Faktor in updateInternal2
    -- landet in einer lokalen Variablen, die nur noch als Ja/Nein gelesen
    -- wird). Weglassen waere falsch - andere Mods und das Wiki nennen die
    -- Zahl, und wer sie sucht, soll erfahren warum sie nichts tut. Sie
    -- bekommt darum die leise Farbe der Fussnote statt die des Werts und
    -- faellt aus der Gesamtuebersicht heraus (TF.Summary.gather).
    return { label = TF.fmt.text(entry.text), value = value, note = note,
             dead = entry.dead and true or false }
end

--- Baut die vollstaendige Zeile eines Eintrags: "Bezeichnung: Wert (Fussnote)".
-- @param palette  optional, ueberschreibt TF.fmt.palette (z. B. fuer eine
--                 abweichende Messung, deren Wert orange steht)
-- @return string|nil  nil, wenn die Zeile zu ueberspringen ist
function TF.fmt.entry(entry, palette)
    local teile = TF.fmt.parts(entry)
    if not teile then return nil end
    local valueColor = teile.dead and "note" or nil
    return TF.fmt.line(teile.label, teile.value, teile.note, palette, valueColor)
end


-- ---------------------------------------------------------------------------
-- Spaltensatz
-- ---------------------------------------------------------------------------
--
-- ISRichTextPanel kennt keine Zellen. `<SETX:n>` setzt den Cursor auf eine
-- feste Spalte, aber eine rechte Zellenkante gibt es nicht: der Text liefe bis
-- zum Panelrand und braeche dort um, quer durch die naechste Spalte. Wer
-- Spalten will, muss den Umbruch selbst rechnen.
--
-- Das ist die ganze Schwierigkeit dieser Darstellung, und sie ist der Preis
-- dafuer, dass in der Uebersicht der Wert vorn steht, die Zahlen untereinander
-- fluchten und nichts abgeschnitten wird.

--- Zeilenhoehe von UIFont.NewSmall, bei der die Spaltenmasse gelten.
--
-- Alle Pixelmasse in TF.Summary.LAYOUT und TF.Tooltip.LAYOUT sind fuer die
-- kleine Schrift in Standardgroesse gerechnet (media/fonts/EN/1x/
-- zomboidSmall.fnt: lineHeight 19). Stellt der Spieler die Schriftgroesse
-- in den Optionen hoeher, waechst NewSmall mit, die Messung liefert
-- breitere Texte, und feste Spalten wuerden zu eng: der Wert braeche um.
-- TF.fmt.uiScale liefert das Verhaeltnis dazu; die Masse werden damit
-- multipliziert. Das Verhaeltnis der Tooltip-Schrift zur kleinen Schrift
-- allein (der erste Stand) hob sich bei einer globalen Schriftgroesse
-- gerade auf (Review 10.09.2026).
TF.fmt.REFERENCE_HEIGHT = 19

--- Verhaeltnis der Hoehe von `font` (sonst NewSmall) zur Referenzhoehe.
function TF.fmt.uiScale(font)
    local manager = getTextManager and getTextManager()
    if not (manager and manager.getFontHeight and UIFont) then return 1 end
    local ok, scale = pcall(function()
        local hoehe = manager:getFontHeight(font or UIFont.NewSmall)
        if type(hoehe) == "number" and hoehe > 0 then
            return hoehe / TF.fmt.REFERENCE_HEIGHT
        end
        return 1
    end)
    if ok and type(scale) == "number" and scale > 0 then return scale end
    return 1
end

--- Breite eines Textes in Pixeln, in der Schrift des Panels.
--
-- ISRichTextPanel setzt defaultFont = UIFont.NewSmall (Vanilla, Z. 765). Fehlt
-- der TextManager - im Test, oder wenn ein Build die Schrift umbenennt -, gilt
-- eine Schaetzung. Sie ist absichtlich grosszuegig: lieber einmal zu frueh
-- umbrechen als eine Zeile, die in die Nachbarspalte laeuft.
-- @param font  optional; der Tooltip misst in seiner eigenen Schrift, die
--              der Spieler in den Optionen auf Medium oder Large stellen kann
function TF.fmt.measure(text, font)
    if not text or text == "" then return 0 end
    local manager = getTextManager and getTextManager()
    if manager and manager.MeasureStringX and UIFont then
        local ok, width = pcall(function()
            return manager:MeasureStringX(font or UIFont.NewSmall, text)
        end)
        if ok and type(width) == "number" then return width end
    end
    return #text * 7
end

--- Kaestchen um ein Kuerzel: Rahmen (Deckung 0.8, 2 px Polsterung ueber den
-- Text hinaus in jede Richtung) und Text in der Farbe des Kuerzels
-- (TF.Mods.tagColor; seit 14.09.2026 die seines Mods, vorher das Grau der
-- Fussnote), volle Deckung. Eine Stelle fuer alle drei Orte, die ein Kuerzel zeichnen:
-- die Trait-Listen (TF_Hooks), die Startskill-Liste (TF_XpColumns) und die
-- Uebersicht (TF_Panel, drawTagLayer). Vorher hatte jede Stelle ihr eigenes
-- Rechteck mit eigener Textdeckung (0.9 bzw. 1); jetzt ein Satz Konstanten,
-- eine Deckung (Review 14.09.2026: die drei Stellen sollen gleich aussehen).
-- @param ui    Listbox oder Panel mit drawRectBorder und drawText
-- @return number  Breite des Kuerzels in Pixeln, ohne die Polsterung
function TF.fmt.tagBox(ui, x, y, text, font)
    local manager = getTextManager and getTextManager()
    local h = (manager and manager.getFontHeight and manager:getFontHeight(font)) or TF.fmt.REFERENCE_HEIGHT
    local w = TF.fmt.measure(text, font)
    local c = (TF.Mods and TF.Mods.tagColor and TF.Mods.tagColor(text))
        or (TF.fmt.rgb and (TF.fmt.rgb.tag or TF.fmt.rgb.note)) or { 0.55, 0.55, 0.55 }
    ui:drawRectBorder(x - 2, y, w + 4, h, 0.8, c[1], c[2], c[3])
    ui:drawText(text, x, y, c[1], c[2], c[3], 1, font)
    return w
end

--- Zerlegt einen Text an den Leerzeichen.
--
-- Von Hand, weil Kahlua kein string.gmatch hat. Das ist keine Vorsicht: der
-- Aufruf wirft im Spiel, waehrend er im Test mit echtem Lua durchlaeuft - so
-- ist der next()-Absturz entstanden.
local function words(text)
    local out, start = {}, 1
    while true do
        local space = string.find(text, " ", start, true)
        if not space then
            if start <= #text then out[#out + 1] = string.sub(text, start) end
            return out
        end
        if space > start then out[#out + 1] = string.sub(text, start, space - 1) end
        start = space + 1
    end
end

--- Bricht `text` auf `width` Pixel um.
-- @return table  Liste von Zeilen, mindestens eine (auch bei leerem Text)
function TF.fmt.wrap(text, width, font)
    if not text or text == "" then return { "" } end
    if TF.fmt.measure(text, font) <= width then return { text } end

    local lines, current = {}, ""
    for _, word in ipairs(words(text)) do
        local probe = (current == "") and word or (current .. " " .. word)
        if TF.fmt.measure(probe, font) <= width or current == "" then
            -- Ein einzelnes Wort, das breiter ist als die Spalte, bleibt
            -- ungebrochen stehen. Mitten im Wort zu trennen waere schlimmer
            -- als der Ueberstand, und es kommt bei diesen Texten nicht vor.
            current = probe
        else
            lines[#lines + 1] = current
            current = word
        end
    end
    if current ~= "" then lines[#lines + 1] = current end
    return lines
end

--- Die Woerter einer Zelle, jedes mit seiner Farbe.
--
-- Eine Zelle traegt entweder einen Text in einer Farbe (`text` + `color`)
-- oder mehrere Abschnitte (`runs`). Zweiteres braucht die dritte Spalte: dort
-- steht der Trait-Name in Lila und die Fussnote dahinter in Grau, und beide
-- muessen zusammen umbrechen koennen. Ein Umbruch mitten im Namen soll die
-- Farbe der Folgezeile nicht verlieren.
--
-- `tail` eines Laufs (ein Satzzeichen dahinter) haengt fuer den Umbruch am
-- letzten Wort, damit es nie allein an einen Zeilenanfang rutscht; gesetzt
-- wird es in TF.fmt.columns als eigenes Segment.
local function cellWords(cell)
    local out = {}
    local runs = cell.runs or { { text = cell.text or "", color = cell.color } }
    for _, run in ipairs(runs) do
        local list = words(run.text or "")
        for index, word in ipairs(list) do
            local item = { text = word, color = run.color }
            if index == #list and type(run.tail) == "string" and run.tail ~= "" then
                item.text, item.tail = word .. run.tail, run.tail
                item.tailColor = run.tailColor or run.color
            end
            out[#out + 1] = item
        end
    end
    return out
end

--- Ist das Byte ein UTF-8-Folgebyte (die zweite Haelfte eines Umlauts)?
--
-- Im Test sind Strings Bytes, im Spiel Java-Zeichen. Dort ist kein Umlaut
-- ein Folgebyte; ein Zeichen wie das Malzeichen (U+00D7) haelt die Pruefung faelschlich dafuer,
-- und das verschiebt den Schnitt nur um eine Stelle. Gefaehrlich waere nur
-- das Gegenteil, ein halbes Zeichen im Test.
local function folgebyte(text, index)
    local b = string.byte(text, index)
    return b ~= nil and b >= 128 and b < 192
end

--- Kuerzt `text` mit angehaengten "..." auf hoechstens `breite` Pixel.
-- Zeichenweise von hinten, nie mitten in einem Umlaut (folgebyte). Bis 0.12.7
-- lag das nur in TF_Hooks; seit die Startskill-Liste ihre Namen auch kuerzt
-- (Bugjagd 20.09.2026), liegt es hier.
-- @return string  gekuerzter Text; unveraendert, wenn er schon passt
function TF.fmt.kuerze(text, breite, font)
    if TF.fmt.measure(text, font) <= breite then return text end
    local ENDE = "..."
    local rest = text
    while #rest > 0 do
        local j = #rest
        while j > 1 and folgebyte(rest, j) do j = j - 1 end
        rest = string.sub(rest, 1, j - 1)
        if rest == "" then return ENDE end
        if TF.fmt.measure(rest .. ENDE, font) <= breite then return rest .. ENDE end
    end
    return ENDE
end

--- Zerlegt ein Wort, das allein breiter ist als die Spalte.
--
-- Letzter Ausweg, damit das Panel nie selbst umbricht: sein Umbruch springt
-- an den linken Rand und setzt die Streifen aus. "Standard-Nachtdunkelheit"
-- ist 159 px breit, die Fussnotenspalte bei schmalem Bildschirm 126, und der
-- deutsche Vanilla-Name "Ernaehrungswissenschaftler" landet in derselben
-- Spalte (Bugjagd 10.09.2026, Fund 1).
--
-- Getrennt wird bevorzugt hinter einem Bindestrich, sonst am letzten Zeichen,
-- hinter dem ein angehaengtes "-" noch passt. Passt nicht einmal ein Zeichen,
-- geht ein ganzes Zeichen allein, damit die Schleife weiterkommt.
local function splitWord(word, width, font)
    local pieces, rest, guard = {}, word.text, 0
    while #rest > 1 and TF.fmt.measure(rest, font) > width and guard < 200 do
        guard = guard + 1
        local hyphenCut, plainCut = nil, nil
        for i = 1, #rest - 1 do
            if not folgebyte(rest, i + 1) then
                local head = string.sub(rest, 1, i)
                if string.sub(head, -1) == "-" then
                    if TF.fmt.measure(head, font) <= width then hyphenCut = i end
                elseif TF.fmt.measure(head .. "-", font) <= width then
                    plainCut = i
                end
            end
        end
        local piece
        if hyphenCut then
            piece, rest = string.sub(rest, 1, hyphenCut), string.sub(rest, hyphenCut + 1)
        elseif plainCut then
            piece, rest = string.sub(rest, 1, plainCut) .. "-", string.sub(rest, plainCut + 1)
        else
            local j = 1
            while j < #rest and folgebyte(rest, j + 1) do j = j + 1 end
            piece, rest = string.sub(rest, 1, j), string.sub(rest, j + 1)
        end
        pieces[#pieces + 1] = { text = piece, color = word.color }
    end
    if rest ~= "" then pieces[#pieces + 1] = { text = rest, color = word.color } end
    return pieces
end

--- Bricht eine Wortliste auf `width` um.
-- @return table  Liste von Zeilen, jede eine Liste von { text, color }
--
-- Bis 0.1.3 durfte ein Wort, das allein zu breit war, ungebrochen stehen
-- (`or #current == 0`). Jetzt wird es zerlegt; alles andere bleibt, wie es war.
local function wrapWords(list, width, font)
    if #list == 0 then return { {} } end
    local lines, current, text = {}, {}, ""
    for _, word in ipairs(list) do
        local probe = (text == "") and word.text or (text .. " " .. word.text)
        if TF.fmt.measure(probe, font) <= width then
            current[#current + 1] = word
            text = probe
        else
            if #current > 0 then lines[#lines + 1] = current end
            local pieces = splitWord(word, width, font)
            for i = 1, #pieces - 1 do lines[#lines + 1] = { pieces[i] } end
            local last = pieces[#pieces]
            current, text = { last }, last.text
        end
    end
    if #current > 0 then lines[#lines + 1] = current end
    return lines
end

--- Setzt eine Zeile in Spalten.
--
-- @param cells  Liste von Zellen, jede mit `x` und `width` und entweder
--               { text = string, color = Palettenname } oder
--               { runs = { { text, color }, ... } }; `align = "right"` setzt
--               die Zelle rechtsbuendig an ihre Kante x + width - SAFETY.
--               Ein Lauf darf `tail` (Satzzeichen) und `tailColor`
--               (Palettenname) tragen: umgebrochen mit dem letzten Wort,
--               gesetzt als eigenes Segment eine <SPACE>-Breite dahinter
-- @param palette  optional, sonst TF.fmt.palette
-- @param font     optional, Schrift fuer die Messung (siehe TF.fmt.measure)
-- @return string  eine oder mehrere Zeilen, mit <LINE> verbunden
--
-- Jede Zelle wird einzeln umgebrochen; die Zeile ist so hoch wie die
-- hoechste Zelle. Abgeschnitten wird nichts.
--- Sicherheitsabstand beim Umbruch, in Pixeln.
--
-- Meine Messung und die des Panels sind nicht auf das Pixel gleich. Das Panel
-- prueft `chunkX + pixLen > maxLineWidth` je Abschnitt, und jeder Farbwechsel
-- kostet zusaetzlich ein <SPACE>, also Leerzeichenbreite plus 2 px, die in
-- einer Messung des zusammenhaengenden Textes nicht stecken.
--
-- Wird es dadurch auch nur um ein Pixel zu breit, bricht das Panel selbst um -
-- und sein Umbruch springt auf `indent`, also an den linken Rand. Im Spiel sah
-- das so aus: "... together;" am Ende der Zeile, "without" ganz links, und
-- "glasses" wieder in der Spalte. Lieber ein Wort zu frueh umbrechen.
TF.fmt.SAFETY = 10

function TF.fmt.columns(cells, palette, font)
    palette = palette or TF.fmt.palette
    local gebrochen, hoehe = {}, 0
    for index, cell in ipairs(cells) do
        local breite = (cell.width or 9999) - TF.fmt.SAFETY
        gebrochen[index] = wrapWords(cellWords(cell), breite, font)
        if #gebrochen[index] > hoehe then hoehe = #gebrochen[index] end
    end

    local zeilen = {}
    for row = 1, hoehe do
        local teile = {}
        for index, cell in ipairs(cells) do
            local woerter = gebrochen[index][row]
            if woerter and #woerter > 0 then
                -- SETX schiebt den Cursor nur nach rechts; steht er schon
                -- weiter, ueberschriebe der Text die Nachbarspalte. Genau
                -- dagegen ist der Umbruch oben da.
                --
                -- Das Leerzeichen davor ist Pflicht, nicht Kosmetik: der
                -- Parser zerlegt den Text an Leerzeichen und wirft, sobald ein
                -- Token sowohl "<" als auch ">" enthaelt, alles vor dem "<"
                -- weg (Vanilla ISRichTextPanel Z. 462-465). Ohne den Abstand
                -- verschluckte "delay<SETX:122>" das Wort "delay" - im Spiel
                -- fehlte jeder Zelle ihr letztes Wort.
                --
                -- Rechtsbuendig (die Wertspalte, Entscheidung 12.09.2026):
                -- die Zelle beginnt so weit rechts, dass sie an der Kante des
                -- breitesten Werts endet; das % steht dann untereinander,
                -- Zehner unter Zehnern. Ganze Pixel, weil SETX die Zahl als
                -- Text bekommt; gerundet, nicht abgerundet: die Spaltenbreite
                -- ist schon abgerundet, ein zweites Abrunden liess die Kanten
                -- um mehr als ein Pixel springen. Ein halbes Pixel nach
                -- rechts bleibt weit vor der Luecke zur Nachbarspalte.
                local x = cell.x
                if cell.align == "right" and cell.width then
                    local stuecke = {}
                    for _, word in ipairs(woerter) do stuecke[#stuecke + 1] = word.text end
                    local rest = cell.width - TF.fmt.SAFETY
                        - TF.fmt.measure(table.concat(stuecke, " "), font)
                    if rest > 0 then x = cell.x + math.floor(rest + 0.5) end
                end
                teile[#teile + 1] = " <SETX:" .. tostring(x) .. "> "
                local farbe, offen, erster = nil, {}, true
                local function schliessen()
                    if #offen == 0 then return end
                    local tag = TF.fmt.paint(palette, farbe)
                    -- Nach einem Farbtag frisst das Panel das Leerzeichen;
                    -- <SPACE> ersetzt es. Ohne das stand im Spiel
                    -- "Low Weight;base 0" statt "Low Weight; base 0".
                    local trenn = ""
                    if not erster then
                        trenn = (tag ~= "" and " <SPACE> ") or " "
                    end
                    teile[#teile + 1] = tag .. trenn .. table.concat(offen, " ")
                    offen, erster = {}, false
                end
                for _, word in ipairs(woerter) do
                    if word.color ~= farbe then
                        schliessen()
                        farbe = word.color
                    end
                    -- Ein tail steht als eigenes Segment hinter seinem Wort,
                    -- nach einem <SPACE>: im Spiel 5 px rechts vom Wortende.
                    -- Das braucht das Kuerzel, dessen Kaestchen 2 px
                    -- ueber den Text hinausreicht; im selben Segment ("TOC,")
                    -- lag die rechte Rahmenlinie auf dem Komma (Befund im
                    -- Spiel 14.09.2026). Folgende Woerter in der Farbe des
                    -- tail teilen sein Segment (", Vehicle Knowledge").
                    -- Ohne Farbe fuer den tail bleibt das Wort ganz.
                    local tail = word.tail
                    if tail and TF.fmt.paint(palette, word.tailColor) ~= ""
                            and #word.text > #tail and string.sub(word.text, -#tail) == tail then
                        offen[#offen + 1] = string.sub(word.text, 1, #word.text - #tail)
                        schliessen()
                        farbe = word.tailColor
                        offen[#offen + 1] = tail
                    else
                        offen[#offen + 1] = word.text
                    end
                end
                schliessen()
            end
        end
        zeilen[#zeilen + 1] = table.concat(teile, "")
    end
    -- Auch hier gehoert das Leerzeichen davor: der Parser wirft alles vor
    -- einem "<" weg, sobald das Token auch ein ">" enthaelt.
    return table.concat(zeilen, " <LINE> ")
end
