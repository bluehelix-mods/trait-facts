--- Trait Facts - die Gesamtuebersicht im Bildschirm der Charaktererstellung.
--
-- Der Tooltip sagt, was ein Trait tut. Dieses Panel sagt, was der ganze Build
-- tut, und rechnet dabei wie die Engine (siehe TF_Summary).
--
-- Platz: der Bildschirm hat drei volle Spalten ohne Freiflaeche, aber die
-- Startskill-Liste unten rechts ist fast immer halb leer. Sie wird auf ihre
-- Zeilen geschrumpft, der Rest der Spalte gehoert dem Panel. Vanilla setzt
-- Position und Hoehe in jedem prerender neu, deshalb korrigieren wir dort
-- ebenfalls in jedem Durchgang - einmalig gesetzte Werte haetten keinen
-- Bestand.
--
-- Aufgefrischt wird ueber checkXPBoost. Vanilla ruft das nach jeder Aenderung
-- an der Trait-Auswahl und am Beruf auf (neun Fundstellen in
-- CharacterCreationProfession), und es laeuft immer *nach* der Aenderung. Das
-- ist der einzige Punkt, an dem alle Pfade zusammenlaufen.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Panel = TF.Panel or {}
TF._orig = TF._orig or {}

local NL = " <LINE> "

-- Breite der Scrollleiste, aus ISScrollBar:instantiate (self.width = 17).
local SCROLLBAR_WIDTH = 17

-- Zeilenstreifen: jede zweite Zeile je Thema, weiss mit dieser Deckung ueber
-- dem halbtransparenten Schwarz des Panels. "Leicht" aus dem Mockup; "Hauch"
-- (0.035) war im Spiel zu wenig Unterschied (Rueckmeldung vom 10.09.2026).
local STRIPE_ALPHA = 0.05

-- Linie unter jeder Themen-Ueberschrift, in deren Blau (COLOR_HEADER), ein
-- Pixel hoch. "Linie darunter" aus dem Mockup.
local HEADER_LINE_ALPHA = 0.45
local HEADER_LINE_R, HEADER_LINE_G, HEADER_LINE_B = 0.45, 0.72, 1.0

-- Dieselben Stufen wie im Tooltip; die Palette setzt TF_Tooltip beim Laden.
local COLOR_HEADER = " <RGB:0.45,0.72,1.0> "

--- Das Zeichen, hinter dem die Legende steht (Entscheidung 15.09.2026,
-- Mockup mod-optionen): beim Ueberfahren sagt ein kleiner Tooltip, was die
-- Farben und Kaestchen bedeuten.
local LEGEND_MARK = "?"

--- Mindestens so viele Zeilen behaelt die Startskill-Liste, auch wenn sie
--- weniger Eintraege hat: darunter wirkt sie abgeschnitten statt kompakt.
local MIN_ROWS = 3

--- Abstand zwischen Startskill-Liste und Panel.
local GAP = 6
-- So viele Zeilen Uebersicht bleiben in der schmalen Anordnung unter der
-- Kopfzeile immer frei, auch wenn die Startskill-Liste dafuer scrollen muss.
local KEEP_LINES = 3
-- Die Zeilenhoehe, wenn die Schrift nichts sagt (Test). Sonst gilt die echte
-- Hoehe der Uebersichtsschrift (lineGuess): mit festen 20 px reservierte
-- KEEP_LINES bei 38px Schrift nur gut eine echte Zeile (Abnahme 21.09.2026).
local LINE_GUESS = 20
--- Die Symbole der Kopfzeile werden, wenn die Zeile nicht in die Spalte
-- passt, bis auf diese Groesse verkleinert (placeHeader).
local MIN_ICON = 20

local function lineGuess()
    local manager = getTextManager and getTextManager()
    local h = manager and manager.getFontHeight and manager:getFontHeight(UIFont.Small)
    if type(h) ~= "number" or h <= 0 then return LINE_GUESS end
    return h
end

--- Die gewaehlten Traits als Liste von Definitionen.
-- Beruf und gewaehrte Traits stehen bereits darin, Vanilla traegt sie selbst
-- in listboxTraitSelected ein.
local function chosenTraits(self)
    local traits = {}
    local list = self.listboxTraitSelected
    if list and type(list.items) == "table" then
        for _, item in ipairs(list.items) do
            if item.item then traits[#traits + 1] = item.item end
        end
    end
    return traits
end

--- Baut den Rich-Text der Uebersicht.
-- @param traits Liste von CharacterTraitDefinition
-- @param withTitle ob der Titel in den Text gehoert. In der eigenen Spalte
--                  steht er als Ueberschrift darueber, wie bei den anderen
--                  drei Spalten auch, und waere hier doppelt.
-- @return string
--- Baut den Text der Uebersicht und merkt sich, welche Bildschirmzeilen zu
-- welchem Stueck gehoeren.
--
-- @param width  nutzbare Breite des Panels in Pixeln. Ohne Angabe bleibt es
--               beim durchlaufenden Satz; das ist der Zustand in den Tests
--               und ueberall, wo kein Panel die Breite kennt.
-- @return table  { text = string, spans = { { from, to, kind, stripe } },
--                  lines = Anzahl der Bildschirmzeilen, die der Text ergibt }
--
-- Die Spannen zaehlen Bildschirmzeilen so, wie ISRichTextPanel:paginate sie
-- zaehlt: jeder <LINE>-Token beginnt eine neue, auch ein leerer. Ein Eintrag,
-- dessen Zelle umbricht, belegt mehrere; sein Streifen soll ueber alle gehen,
-- nicht ueber die erste allein.
function TF.Panel.compose(traits, withTitle, width, profession)
    local pieces, kinds = {}, {}
    local function push(text, kind)
        pieces[#pieces + 1] = text
        kinds[#kinds + 1] = kind
    end
    local function finish()
        local spans, line, stripe = {}, 1, false
        for index, piece in ipairs(pieces) do
            local count = 1
            local at = 1
            while true do
                local found = string.find(piece, "<LINE>", at, true)
                if not found then break end
                count = count + 1
                at = found + 6
            end
            local kind = kinds[index]
            if kind == "header" then
                -- Die Streifen fangen je Thema neu an: die erste Zeile nach
                -- der Ueberschrift bleibt frei, die zweite bekommt einen.
                stripe = false
                spans[#spans + 1] = { from = line, to = line + count - 1, kind = "header" }
            elseif kind == "entry" then
                spans[#spans + 1] = { from = line, to = line + count - 1,
                                      kind = "entry", stripe = stripe }
                stripe = not stripe
            end
            line = line + count
        end
        return { text = table.concat(pieces, NL), spans = spans, lines = line - 1 }
    end

    local palette = TF.fmt.palette or {}
    -- Ein durchlaufendes Stueck im Spaltensatz auf die Breite umbrechen: die
    -- Streifen zaehlen die Zeilen nach, und ein Stueck, das das Panel selbst
    -- umbricht, brachte die Zaehlung durcheinander (kein Streifen mehr,
    -- solange die Konfliktwarnung stand).
    local function fitted(text, color)
        if width and TF.Summary.columnsFor(width) then
            return TF.fmt.columns({ { text = text, color = color, x = 0, width = width } })
        end
        return (palette[color] or "") .. text
    end
    if withTitle ~= false then
        -- Das "?" der Legende als eigenes Segment ans Ende: TF.Panel.legendBox
        -- findet es dort, drawTagLayer rahmt es und zeigt beim Ueberfahren,
        -- was die Farben bedeuten. In der eigenen Spalte steht es neben der
        -- Ueberschrift ueber dem Panel (render-Hook), der Titel hier entfaellt.
        push(COLOR_HEADER .. TF.fmt.text("UI_TF_sum_title")
            .. (palette.note or "") .. " <SPACE> " .. TF.fmt.text("UI_TF_sum_subtitle")
            .. (palette.label or "") .. " <SPACE> " .. LEGEND_MARK, "title")
    end

    -- Laeuft eine Mod, die dieselben Tooltips oder Beschreibungen fuellt,
    -- stehen Wirkungen doppelt und die Zahlen widersprechen sich. Das gehoert
    -- nach oben, nicht nur ins Log.
    if TF.Conflict and TF.Conflict.active then
        local other, kind = TF.Conflict.active()
        if other then
            local key = TF.Conflict.messageKey and TF.Conflict.messageKey(kind)
                or "UI_TF_conflict"
            push(fitted(TF.fmt.text(key, other), "stale"), "warning")
        end
    end

    -- Ein anderer Spiel-Build als der der hinterlegten Werte: dieselbe
    -- Warnfarbe, derselbe Platz.
    if TF.buildMismatch then
        local stored, running = TF.buildMismatch()
        if stored then
            push(fitted(TF.fmt.text("UI_TF_build_mismatch", stored, running), "stale"), "warning")
        end
    end

    local groups = TF.Summary.build(traits, width, profession)
    if #groups == 0 then
        -- Zwei verschiedene Faelle, zwei verschiedene Saetze: noch nichts
        -- ausgewaehlt, oder ausgewaehlt und ohne Wirkung. Unfit und Out of
        -- Shape tragen nur den Sprint-Faktor, und der wirkt in 42.20.4
        -- nicht; wer sie waehlt, bekommt sonst "waehle Eigenschaften"
        -- angezeigt, obwohl er genau das getan hat.
        local key = (traits and #traits > 0) and "UI_TF_sum_noeffect"
            or "UI_TF_sum_empty"
        push("", "blank")
        push(fitted(TF.fmt.text(key), "note"), "hint")
        return finish()
    end

    for index, group in ipairs(groups) do
        -- Leerzeile vor jeder Gruppe: der leere Eintrag wird zwischen zwei
        -- <LINE> zu einer leeren Zeile. Ohne Titel darueber entfaellt sie vor
        -- der ersten Gruppe, sonst begaenne die Spalte mit einer Luecke.
        if #pieces > 0 or index > 1 then push("", "blank") end
        push(COLOR_HEADER .. TF.fmt.text("UI_TF_grp_" .. group.group), "header")
        for _, line in ipairs(group.lines) do
            push(line, "entry")
        end
    end

    -- Keine Schluesselzeile ("TOC The Only Cure") mehr unter der Uebersicht
    -- (Entscheidung 15.09.2026): sie wiederholte, was das Hover ueber jedem
    -- Kuerzel-Kaestchen ohnehin zeigt - Mod, Pakete, Version -, wie zuvor
    -- schon in den Tooltips (A+, 14.09.2026).
    return finish()
end

--- Nur der Text, fuer alle, die die Spannen nicht brauchen.
function TF.Panel.text(traits, withTitle, width, profession)
    return TF.Panel.compose(traits, withTitle, width, profession).text
end


--- Zeichnet die Streifen hinter jede zweite Zeile je Thema.
--
-- Laeuft im prerender, also nach Hintergrund und Rahmen und vor dem Text.
-- Der Stencil des Panels wird erst im render gesetzt; deshalb schneidet die
-- Funktion die Rechtecke selbst auf die Panelhoehe, sonst liefen sie beim
-- Scrollen ueber den Rand.
local function drawStripes(panel)
    local spans = panel.tfSpans
    if not spans or not panel.lineY or not panel.lines then return end

    -- Das Panel legt je Tag ein neues Segment an, nicht je Zeile: `lines`,
    -- `lineX` und `lineY` zaehlen Segmente (Vanilla paginate Z. 474,
    -- `lines = lines + 1` bei jedem Tag, auch bei <RGB:> und <SETX:>). Eine
    -- sichtbare Zeile ist die Menge der Segmente mit demselben lineY. Der
    -- erste Stand verglich #lines mit der Zeilenzahl des Textes und hielt
    -- 11 Segmente fuer 11 Zeilen; im Spiel blieben die Streifen darum aus
    -- (console.txt 09.09.2026: "Panel hat 11 Zeilen, der Text ergab 2").
    --
    -- Einmal je paginate, nicht je Frame: paginate legt lineY als neue
    -- Tabelle an, die Tabelle selbst ist darum der Schluessel. Sonst liefe
    -- hier bei 60 Bildern je Sekunde jedes Mal eine Schleife ueber einige
    -- hundert Segmente samt Sortierung.
    local ys = panel.tfYs
    if not ys or panel.tfYsFor ~= panel.lineY then
        local seen = {}
        ys = {}
        for _, y in pairs(panel.lineY) do
            if type(y) == "number" and not seen[y] then
                seen[y] = true
                ys[#ys + 1] = y
            end
        end
        table.sort(ys)
        panel.tfYs, panel.tfYsFor = ys, panel.lineY
    end

    -- Hat das Panel mehr Zeilen erzeugt als der Text ergab, ist irgendwo eine
    -- Zelle doch umgebrochen, und ab dort saessen die Streifen daneben.
    -- Dann lieber keine als falsche.
    if panel.tfExpectedLines and #ys ~= panel.tfExpectedLines then
        TF.warnOnce("stripes:lines", string.format(
            "Streifen ausgesetzt: Panel hat %d Zeilen, der Text ergab %d.",
            #ys, panel.tfExpectedLines))
        return
    end
    -- Gezeichnet wird in Inhaltskoordinaten: drawRect bekommt vom Java-
    -- Element den Scroll dazu, genau wie der Text in ISRichTextPanel:render
    -- (lineY + marginTop, ohne Scroll-Term). Der erste Stand addierte den
    -- Scroll selbst noch einmal, und die Streifen liefen beim Scrollen mit
    -- doppelter Geschwindigkeit vom Text weg (Review 10.09.2026). Nur der
    -- Ausschnitt rechnet mit dem Scroll: sichtbar ist der Inhalt von
    -- -scroll bis height - scroll.
    local scroll = panel:getYScroll() or 0
    local top = panel.marginTop or 0
    local height = panel:getHeight()
    local width = panel:getWidth()
    local manager = getTextManager and getTextManager()
    local lineHeight = (manager and manager.getFontHeight
        and manager:getFontHeight(panel.font)) or 0
    -- Die Hoehe einer Zeile ist der Abstand zur naechsten; die letzte hat
    -- keine, fuer sie gilt die Schrifthoehe.
    local function lineTop(k) return top + ys[k] end
    local function lineBottom(k)
        local h = (ys[k + 1] and (ys[k + 1] - ys[k])) or lineHeight
        return top + ys[k] + h
    end
    -- Ein Rechteck, auf den sichtbaren Ausschnitt beschnitten; nil, wenn
    -- nichts davon sichtbar ist.
    local function clipped(y0, y1)
        local lo, hi = -scroll, height - scroll
        if y0 < lo then y0 = lo end
        if y1 > hi then y1 = hi end
        if y1 <= y0 then return nil end
        return y0, y1
    end
    for _, span in ipairs(spans) do
        if ys[span.from] and ys[span.to] then
            local bottom = lineBottom(span.to)
            if span.kind == "entry" and span.stripe then
                local y0, y1 = clipped(lineTop(span.from), bottom)
                if y0 then
                    panel:drawRect(0, y0, width, y1 - y0, STRIPE_ALPHA, 1, 1, 1)
                end
            elseif span.kind == "header" then
                -- Ein Pixel unter der Ueberschrift, in ihrem Blau.
                local y0, y1 = clipped(bottom - 1, bottom)
                if y0 then
                    panel:drawRect(0, y0, width, y1 - y0, HEADER_LINE_ALPHA,
                        HEADER_LINE_R, HEADER_LINE_G, HEADER_LINE_B)
                end
            end
        end
    end
end

--- Ob ein Kaestchen ganz im sichtbaren Ausschnitt liegt. Inhaltskoordinaten
-- wie in drawStripes: sichtbar ist der Inhalt von -scroll bis height - scroll.
--
-- drawTagLayer laeuft nach dem Vanilla-render, und das hat das Stencil schon
-- wieder abgeschaltet; ein Kaestchen ausserhalb malte darum ueber den
-- Panelrand (Abschlussreview 14.09.2026, Fund 2). Ein halb sichtbares faellt
-- ganz weg, statt beschnitten zu werden: Text laesst sich hier nicht
-- beschneiden, und das Kuerzel selbst zeigt der Rich Text ohnehin, im
-- Stencil beschnitten.
local function boxVisible(panel, box)
    local scroll = panel:getYScroll() or 0
    return box.y >= -scroll and box.y + box.h <= panel:getHeight() - scroll
end

--- Kaestchen um die Kuerzel der Uebersicht, in Inhaltskoordinaten wie die
-- Streifen (drawRect bekommt den Scroll vom Java-Element dazu). Ein Segment
-- ist ein Kuerzel, wenn sein Text genau ein vergebenes Kuerzel ist,
-- hoechstens gefolgt von einem Trennzeichen ("," ";" ")"). Die Uebersicht
-- setzt ein Trennzeichen hinter einem Kuerzel inzwischen als eigenes
-- Segment eine <SPACE>-Breite weiter rechts, sonst laege die rechte
-- Rahmenlinie darauf (Befund im Spiel 14.09.2026); die Duldung bleibt fuer
-- anderen Text. Das Kaestchen umfasst nur
-- das Kuerzel. Die Kuerzel stehen im Text immer als eigenes Segment: sie
-- tragen den Palettennamen tag (TF_Tooltip), und jeder Farbwechsel beginnt
-- ein Segment. Alle Kaestchen, auch die ausserhalb des Ausschnitts; wer
-- zeichnet oder trifft, fragt boxVisible.
function TF.Panel.tagBoxes(panel)
    local out = {}
    if not (TF.Mods and TF.Mods.isTag) or type(panel.lines) ~= "table" then return out end
    -- Einmal je paginate, nicht je Bild, wie die Streifen (drawStripes):
    -- paginate legt lineY neu an, die Tabelle ist der Schluessel. Bis 0.12.0
    -- lief hier in jedem Bild ein string.match ueber jedes Segment, bei einem
    -- vollen Build rund 370, und fuer das Hover noch einmal; im Bildschirmlauf
    -- vom 20.09.2026 fiel die Bildrate mit vollem Build von ueber 50 auf unter
    -- 20. Der Stand der Pakete zaehlt mit, denn er bestimmt, was ein Kuerzel ist.
    local stamp = tostring(TF.Mods.done) .. "/" .. tostring(TF.Mods.epoch)
    if panel.tfTagBoxes and panel.tfTagBoxesFor == panel.lineY and panel.tfTagBoxesStamp == stamp then
        return panel.tfTagBoxes
    end
    local manager = getTextManager and getTextManager()
    local h = (manager and manager.getFontHeight and manager:getFontHeight(panel.font)) or 19
    for i, text in pairs(panel.lines) do
        local clean = type(text) == "string" and string.match(text, "^%s*(%w+)[,;%)]?%s*$") or nil
        if clean and TF.Mods.isTag(clean) and panel.lineX and panel.lineX[i] and panel.lineY and panel.lineY[i] then
            out[#out + 1] = { tag = clean, x = (panel.marginLeft or 0) + panel.lineX[i],
                              y = (panel.marginTop or 0) + panel.lineY[i],
                              w = TF.fmt.measure(clean, panel.font), h = h }
        end
    end
    panel.tfTagBoxes, panel.tfTagBoxesFor, panel.tfTagBoxesStamp = out, panel.lineY, stamp
    return out
end

--- Das Kuerzel unter einem Punkt (Inhaltskoordinaten), oder nil. Nur
-- sichtbare Kaestchen treffen: ein Hover-Tooltip zu einem Kaestchen, das
-- nicht gezeichnet ist, gehoert nicht auf den Schirm.
function TF.Panel.tagAt(panel, x, y)
    for _, box in ipairs(TF.Panel.tagBoxes(panel)) do
        if boxVisible(panel, box) and x >= box.x - 2 and x <= box.x + box.w + 2
                and y >= box.y and y <= box.y + box.h then
            return box.tag
        end
    end
    return nil
end

--- Die Zeilen des kleinen Tooltips zu einem Kuerzel, je mit Palettenfarbe.
--
-- Ein Mod-Kuerzel: Name, ID mit der installierten Fassung, dann je
-- lieferndem Paket "Werte fuer <Fassung>", bei mehr als einem mit der
-- Quelle in Klammern, damit man die Zeilen auseinanderhaelt. Ein veraltetes
-- Paket steht orange, sein Hinweis "installiert ist ..." direkt darunter.
-- Ein Paket ohne Fassung hat keine Zeile. Ein Paket-Kuerzel beschreibt
-- sein Paket wie bisher. Die erste Zeile traegt in `tag` das Kuerzel:
-- drawTagLayer setzt es vorn ins Kaestchen, in seiner Farbe, wie im Mockup
-- trait-auswahl-mod-farben (tagText).
-- @return table  { { text = string, color = "source"|"note"|"stale",
--                    tag = Kuerzel nur in der ersten Zeile }, ... }
function TF.Panel.tagLines(tag)
    local d = TF.Mods and TF.Mods.describeTag and TF.Mods.describeTag(tag)
    if not d then return { { text = tag, color = "note" } } end
    local out = { { text = d.name, color = "source", tag = tag } }
    if d.id then
        out[#out + 1] = { text = d.id .. (d.version and (" " .. d.version) or ""), color = "note" }
    end
    if d.nodata then
        out[#out + 1] = { text = TF.fmt.text("UI_TF_ext_tag_nodata"), color = "note" }
    elseif d.packages then
        local shown = {}
        for _, info in ipairs(d.packages) do
            if info.version then shown[#shown + 1] = info end
        end
        for _, info in ipairs(shown) do
            local text = TF.fmt.text("UI_TF_ext_tag_values", info.version)
            if #shown > 1 then text = text .. " (" .. tostring(info.source) .. ")" end
            out[#out + 1] = { text = text, color = info.stale and "stale" or "note" }
            if info.stale then
                out[#out + 1] = { text = TF.fmt.text("UI_TF_ext_tag_installed", info.installed), color = "stale" }
            end
        end
        return out
    elseif d.version then
        out[#out + 1] = { text = TF.fmt.text("UI_TF_ext_tag_values", d.version), color = "note" }
    end
    if d.stale then
        out[#out + 1] = { text = TF.fmt.text("UI_TF_ext_tag_installed", d.installed), color = "stale" }
    end
    return out
end

--- Wo das "?" der Legende steht, in Inhaltskoordinaten wie tagBoxes, oder
-- nil. In der eigenen Spalte steht es neben der Ueberschrift ueber dem
-- Panel; der render-Hook des Bildschirms legt die Stelle je Bild in
-- panel.tfLegendAnchor ab (Panel-Koordinaten ohne Scroll, `above`). Sonst
-- ist es das letzte Segment der Titelzeile (TF.Panel.compose).
function TF.Panel.legendBox(panel)
    local scroll = panel:getYScroll() or 0
    local a = panel.tfLegendAnchor
    if a then return { x = a.x, y = a.y - scroll, w = a.w, h = a.h, above = true } end
    if type(panel.lines) ~= "table" then return nil end
    -- Einmal je paginate, auch das "nicht gefunden": die Uebersicht steht seit
    -- 0.5.0 ohne Titelzeile im Panel, die Suche findet dort also nie etwas.
    -- Das Panel der ganzen Ansicht hat keinen Anker und suchte darum in jedem
    -- Bild ueber alle Segmente (Bildschirmlauf 20.09.2026: 43 statt 57 Bilder
    -- je Sekunde mit "Show all" bei 1366x768).
    if panel.tfLegendFor == panel.lineY then return panel.tfLegendBox or nil end
    local found = nil
    local manager = getTextManager and getTextManager()
    local h = (manager and manager.getFontHeight and manager:getFontHeight(panel.font)) or 19
    for i, text in pairs(panel.lines) do
        if type(text) == "string" and string.match(text, "^%s*%?%s*$")
                and panel.lineX and panel.lineX[i] and panel.lineY and panel.lineY[i] then
            found = { x = (panel.marginLeft or 0) + panel.lineX[i] - 3, y = (panel.marginTop or 0) + panel.lineY[i],
                      w = TF.fmt.measure(LEGEND_MARK, panel.font) + 6, h = h }
            break
        end
    end
    panel.tfLegendBox, panel.tfLegendFor = found or false, panel.lineY
    return found
end

--- Die Zeilen der Legende: je ein Muster (`sample`, in `sampleColor` oder
-- als Kaestchen mit `boxed`) und was es bedeutet, wie im Mockup
-- mod-optionen. Die Muster tragen die Farben des gewaehlten Schemas, die
-- Legende erklaert also, was gerade zu sehen ist. Der Hinweis auf die
-- Farbenblind-Option nur, solange sie aus ist.
function TF.Panel.legendLines()
    local function value(kind, v)
        return (TF.fmt.value and TF.fmt.value(kind, v)) or tostring(v)
    end
    local out = {
        { text = TF.fmt.text("UI_TF_legend_title"), color = "label" },
        { sample = value("pct", 40), sampleColor = "good", text = TF.fmt.text("UI_TF_legend_good"), color = "value" },
        { sample = value("pct", -60), sampleColor = "bad", text = TF.fmt.text("UI_TF_legend_bad"), color = "value" },
        -- Eine Wirkung ohne Zahl traegt an derselben Stelle ein Zeichen fuer
        -- ihre Richtung, in derselben Farbe (TF.Summary.valueCell).
        { sample = TF.fmt.text("UI_TF_sym_gain"), sampleColor = "good",
          text = TF.fmt.text("UI_TF_legend_gain"), color = "value" },
        { sample = TF.fmt.text("UI_TF_sym_lose"), sampleColor = "bad",
          text = TF.fmt.text("UI_TF_legend_lose"), color = "value" },
        -- Ohne Richtung: eine Zahl in der Farbe des Textes. Bis 0.12.12 stand
        -- hier das Zeichen fuer eine Aussage ohne Richtung; die gibt es in den
        -- eigenen Daten, im More-Traits-Paket und bei den live gelesenen Werten
        -- nicht mehr (nachgezaehlt 21.09.2026), wohl aber Zahlen ohne Richtung:
        -- Sleep length, Calories needed to gain weight. Die Legende zeigt, was
        -- man wirklich sieht; das Zeichen kann nur noch ein fremdes Paket bringen.
        { sample = value("pct", 18), sampleColor = "value",
          text = TF.fmt.text("UI_TF_legend_open"), color = "value" },
        { sample = value("mult", 1.5), sampleColor = "note", text = TF.fmt.text("UI_TF_legend_dead"), color = "value" },
        { sample = value("pct", -50), sampleColor = "stale", text = TF.fmt.text("UI_TF_legend_stale"), color = "value" },
        { sample = TF.fmt.text("UI_TF_legend_tagsample"), boxed = true,
          text = TF.fmt.text("UI_TF_legend_tag"), color = "value" },
    }
    -- Ohne wirkungslose Werte (Mod-Option) gibt es die graue Zahl nirgends,
    -- ihre Zeile faellt mit weg (Entscheidung 19.09.2026).
    if TF.Options and TF.Options.showDead and not TF.Options.showDead() then
        for i = #out, 1, -1 do
            if out[i].sampleColor == "note" then table.remove(out, i) end
        end
    end
    if (TF.fmt.scheme or "standard") == "standard" then
        out[#out + 1] = { text = TF.fmt.text("UI_TF_legend_option"), color = "note" }
    end
    return out
end

--- Ein kleiner Tooltip am Punkt (px, py), Inhaltskoordinaten. Eine Zeile mit
-- `tag` beginnt mit dem Kaestchen ihres Kuerzels (Hover ueber einem
-- Kuerzel); eine mit `sample` (Legende) mit ihrem Muster, rechtsbuendig in
-- einer gemeinsamen Spalte, oder als Kaestchen (`boxed`).
local function drawHover(panel, lines, px, py)
    local set = TF.fmt.rgb or {}
    local note = set.note or { 0.55, 0.55, 0.55 }
    local font = UIFont.Small
    local manager = getTextManager and getTextManager()
    local lh = (manager and manager.getFontHeight and manager:getFontHeight(font)) or 19
    local sampleW = 0
    for _, line in ipairs(lines) do
        if line.sample then
            sampleW = math.max(sampleW, TF.fmt.measure(line.sample, font) + (line.boxed and 4 or 0))
        end
    end
    -- Vorlauf einer Zeile mit Kuerzel: das Kaestchen (Text ab x + 8, Rahmen
    -- 2 px darum) und 5 px Luft bis zum Namen. Mit Muster: dessen Spalte und
    -- 10 px Luft.
    local function lead(line)
        if line.tag then return TF.fmt.measure(line.tag, font) + 9 end
        if line.sample then return sampleW + 10 end
        return 0
    end
    local widest = 0
    for _, line in ipairs(lines) do
        widest = math.max(widest, lead(line) + TF.fmt.measure(line.text, font))
    end
    local w, h = widest + 12, #lines * lh + 8
    local scroll = panel:getYScroll() or 0
    local x = math.min(math.max(4, px + 12), panel:getWidth() - w - 4)
    local y = math.min(math.max(-scroll + 4, py + 16), panel:getHeight() - scroll - h - 4)
    panel:drawRect(x, y, w, h, 0.95, 0.03, 0.03, 0.03)
    panel:drawRectBorder(x, y, w, h, 0.8, 0.6, 0.6, 0.6)
    for i, line in ipairs(lines) do
        local ly = y + 4 + (i - 1) * lh
        if line.tag then
            TF.fmt.tagBox(panel, x + 8, ly, line.tag, font)
        elseif line.sample and line.boxed then
            TF.fmt.tagBox(panel, x + 8, ly, line.sample, font)
        elseif line.sample then
            local s = set[line.sampleColor] or note
            panel:drawText(line.sample, x + 6 + sampleW - TF.fmt.measure(line.sample, font), ly,
                s[1], s[2], s[3], 1, font)
        end
        local c = set[line.color] or note
        panel:drawText(line.text, x + 6 + lead(line), ly, c[1], c[2], c[3], 1, font)
    end
end

local function drawTagLayer(panel)
    -- Derselbe Kaestchen-Look wie an den anderen beiden Stellen (TF_Hooks,
    -- TF_XpColumns): TF.fmt.tagBox zeichnet Rahmen und Text; hier faellt der
    -- Text mit dem schon gerenderten Rich-Text-Kuerzel zusammen, das kostet
    -- nichts weiter.
    for _, box in ipairs(TF.Panel.tagBoxes(panel)) do
        if boxVisible(panel, box) then
            TF.fmt.tagBox(panel, box.x, box.y, box.tag, panel.font)
        end
    end
    -- Der Hinweis nach Fehler melden und Build kopieren oder einfuegen steht
    -- seit 0.12.0 nicht mehr hier im Panel, sondern mittig im Bildschirm
    -- (TF.Panel.showToast): oben rechts in der Ecke uebersah man ihn (Test im
    -- Spiel 20.09.2026).
    -- Das "?" der Legende: in der Titelzeile hier gerahmt, ueber der eigenen
    -- Spalte rahmt es der render-Hook. Die Maus wird je Bild abgefragt statt
    -- ueber onMouseMove: ueber der Spalte liegt sie ausserhalb des Panels,
    -- und dort kommt kein onMouseMove an.
    local legend = TF.Panel.legendBox(panel)
    if legend then
        local shown = legend.above or boxVisible(panel, legend)
        if shown and not legend.above then
            local c = (TF.fmt.rgb and TF.fmt.rgb.note) or { 0.55, 0.55, 0.55 }
            panel:drawRectBorder(legend.x, legend.y, legend.w, legend.h, 0.9, c[1], c[2], c[3])
        end
        if shown and panel.getMouseX and panel.getMouseY then
            local mx, my = panel:getMouseX(), panel:getMouseY()
            if mx >= legend.x and mx <= legend.x + legend.w and my >= legend.y and my <= legend.y + legend.h then
                drawHover(panel, TF.Panel.legendLines(), mx, my)
                return
            end
        end
    end
    -- Der Tooltip nur, solange sein Kaestchen sichtbar unter dem Punkt
    -- liegt: nach dem Scrollen mit dem Mausrad kommt kein onMouseMove, und
    -- der gemerkte Treffer koennte laengst ausserhalb liegen.
    local tag = panel.tfHoverTag
    if not tag or TF.Panel.tagAt(panel, panel.tfHoverX or 0, panel.tfHoverY or 0) ~= tag then return end
    drawHover(panel, TF.Panel.tagLines(tag), panel.tfHoverX, panel.tfHoverY)
end

--- Legt das Panel an, falls es noch keines gibt.
--
-- Aufgerufen wird das aus dem create-Hook, also dort, wo Vanilla auch seine
-- eigenen Kinder anlegt. Waehrend prerender ein Kind einzuhaengen aendert die
-- Kinderliste mitten im Zeichnen; das ist der falsche Zeitpunkt, egal ob es
-- gutgeht.
--
-- Kein initialise(): Vanilla ruft es bei seinem eigenen ISRichTextPanel in
-- diesem Bildschirm auch nicht, addChild erledigt das noetige.
--- Ein Rich-Text-Panel mit allem, was die Uebersicht ausmacht: Streifen,
-- Kuerzel-Kaestchen, Hover, Scrollleiste. Eine Fabrik fuer zwei Panels: das
-- feste der Anordnung (ensurePanel) und das der ganzen Ansicht (TF.Panel.
-- showFull, seit 0.12.0). `parent` haengt es ein; ohne bleibt es frei.
local function newSummaryPanel(parent)
    local panel = ISRichTextPanel:new(0, 0, 10, 10)
    panel.autosetheight = false
    -- clip schaltet im render das Stencil ein; ohne das malte der Text ueber
    -- den Panelrand hinaus, sobald er laenger ist als der Platz.
    panel.clip = true
    panel.background = true
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    panel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    panel:setMargins(6, 4, 6, 4)
    if parent then parent:addChild(panel) end
    -- Scrollleiste: ISScrollBar zeichnet sich nur, wenn die Scrollhoehe
    -- groesser ist als die Panelhoehe (Vanilla ISScrollBar:render Z. 308).
    -- Sie erscheint also von selbst erst, wenn genug Zeilen da sind, und
    -- verschwindet wieder. Ohne sie war die Spalte zwar mit dem Mausrad
    -- scrollbar, aber nichts sagte, dass darunter noch etwas steht.
    panel:addScrollBars()
    -- Streifen hinter jede zweite Zeile. prerender kommt von ISPanel und malt
    -- Hintergrund und Rahmen; das Instanzfeld ueberdeckt es und ruft es
    -- zuerst, damit die Streifen ueber dem Hintergrund und unter dem Text
    -- liegen.
    local basePrerender = panel.prerender
    -- In den Huellen heisst das Panel `box`: `self` ist hier der Bildschirm.
    panel.prerender = function(box)
        if basePrerender then basePrerender(box) end
        TF.safe("summary:stripes", function() drawStripes(box) end)
    end
    -- Rahmen um die Kuerzel und der Tooltip beim Ueberfahren. render kommt
    -- nach prerender, also nach den Streifen und dem Text; render und
    -- onMouseMove sind Instanzfelder von ISPanel/ISUIElement, das Original
    -- also nie nil, aber der Aufruf bleibt geschuetzt wie ueberall sonst.
    local baseRender = panel.render
    panel.render = function(box)
        if baseRender then baseRender(box) end
        TF.safe("summary:tags", function() drawTagLayer(box) end)
    end
    local baseMove = panel.onMouseMove
    panel.onMouseMove = function(box, dx, dy)
        if baseMove then baseMove(box, dx, dy) end
        TF.safe("summary:hover", function()
            -- ISUIElement:getMouseY zieht den Scroll schon ab (ISUI/ISUIElement.lua
            -- ~346-350: `getMouseY()-getYScroll()-getAbsoluteY()`) und liefert damit
            -- Inhaltskoordinaten, genau wie tagAt sie erwartet. Ein zweiter Abzug
            -- hier verschob den Treffer um den Scroll (Bugjagd 14.09.2026).
            local mx, my = box:getMouseX(), box:getMouseY()
            box.tfHoverTag = TF.Panel.tagAt(box, mx, my)
            box.tfHoverX, box.tfHoverY = mx, my
        end)
    end
    local baseOut = panel.onMouseMoveOutside
    panel.onMouseMoveOutside = function(box, dx, dy)
        if baseOut then baseOut(box, dx, dy) end
        TF.safe("summary:hover", function() box.tfHoverTag = nil end)
    end
    return panel
end

local function ensurePanel(self)
    if self.tfSummary then return self.tfSummary end
    if not ISRichTextPanel then return nil end
    local panel = newSummaryPanel(self)
    panel:setAnchorLeft(true)
    panel:setAnchorRight(false)
    panel:setAnchorTop(false)
    panel:setAnchorBottom(true)
    self.tfSummary = panel
    return panel
end

--- Setzt den Text neu.
--- Bricht einen Hinweis an Wortgrenzen auf `maxWidth` Pixel um.
-- Ein einzelnes Wort, das allein zu lang ist, bleibt ganz: lieber eine Zeile
-- zu breit als ein Mod-Name mittendrin getrennt.
-- @return table  Liste der Zeilen
-- Der Hinweis sieht aus wie das Warnfenster der fehlenden Mods (Wunsch
-- 21.09.2026): doppelter Rand in der Farbe des Status, links oben ein Kaestchen
-- in derselben Farbe mit einem Symbol, daneben der Text. Vier Status: "ok"
-- (Haken, gruen), "warn" (Ausrufezeichen, orange), "error" (Kreuz, rot) und
-- ohne Angabe "info" (i, blau). Bis 0.12.10 trug nur der Rand die Farbe.
local TOAST_PAD, TOAST_GAP, TOAST_MIN = 10, 8, 160
local STATUS = {
    ok    = { color = "good",  fallback = { 0.45, 0.72, 0.48 }, glyph = "+", icon = "media/ui/TraitFacts/tf_toast_ok.png" },
    warn  = { color = "stale", fallback = { 0.88, 0.63, 0.31 }, glyph = "!", icon = "media/ui/TraitFacts/tf_toast_warn.png" },
    error = { color = "bad",   fallback = { 0.82, 0.50, 0.47 }, glyph = "x", icon = "media/ui/TraitFacts/tf_toast_error.png" },
    info  = { color = "blue",  fallback = { 0.45, 0.72, 1.00 }, glyph = "i", icon = "media/ui/TraitFacts/tf_toast_info.png" },
    -- Die Rueckfrage vor dem Ersetzen eines Builds (TF.Build.ask).
    ask   = { color = "blue",  fallback = { 0.45, 0.72, 1.00 }, glyph = "?", icon = "media/ui/TraitFacts/tf_toast_ask.png" },
}
TF.Panel.STATUS = STATUS

--- Die Farbe eines Status als { r, g, b }; unbekannt oder nil ist "info".
function TF.Panel.statusColor(kind)
    local status = STATUS[kind or "info"] or STATUS.info
    return (TF.fmt.rgb and TF.fmt.rgb[status.color]) or status.fallback
end

--- Das Kaestchen mit dem Symbol eines Status, `size` Pixel gross. Das Symbol
-- ist ein weisses Bild, dunkel gefaerbt; fehlt das Bild, steht ein Zeichen da.
-- Auch das Warnfenster der fehlenden Mods zeichnet sein "!" hierueber.
function TF.Panel.drawBadge(target, x, y, size, kind)
    local status = STATUS[kind or "info"] or STATUS.info
    local o = TF.Panel.statusColor(kind)
    target:drawRect(x, y, size, size, 1, o[1], o[2], o[3])
    local texture = getTexture and getTexture(status.icon) or nil
    if texture and target.drawTextureScaled then
        local inner = size - 6
        target:drawTextureScaled(texture, x + 3, y + 3, inner, inner, 1, 0.05, 0.03, 0)
    else
        local font = UIFont.Small
        target:drawText(status.glyph, x + (size - TF.fmt.measure(status.glyph, font)) / 2, y + 2, 0.05, 0.03, 0, 1, font)
    end
end

--- Zeilen und Masse eines Hinweises bei hoechstens `maxWidth` Breite.
-- Eine Stelle fuer drawToast und showToast, damit das Panel genau so hoch ist,
-- wie gezeichnet wird.
-- @return table lines, number w, number h, number lineHeight, number badge
function TF.Panel.toastSize(text, maxWidth)
    local font = UIFont.Small
    local manager = getTextManager and getTextManager()
    local lh = (manager and manager.getFontHeight and manager:getFontHeight(font)) or 19
    local badge = lh + 4
    if type(maxWidth) ~= "number" or maxWidth < TOAST_MIN then maxWidth = TOAST_MIN end
    local rand = TOAST_PAD * 2 + badge + TOAST_GAP
    local lines = TF.Panel.wrapToast(text, maxWidth - rand, font)
    local widest = 0
    for _, line in ipairs(lines) do widest = math.max(widest, TF.fmt.measure(line, font)) end
    return lines, widest + rand, math.max(badge, #lines * lh) + TOAST_PAD * 2, lh, badge
end

function TF.Panel.wrapToast(text, maxWidth, font)
    local lines, line = {}, ""
    local at = 1
    while true do
        local a, b = string.find(text, "%S+", at)
        if not a then break end
        local word = string.sub(text, a, b)
        local candidate = (line == "") and word or (line .. " " .. word)
        if line ~= "" and TF.fmt.measure(candidate, font) > maxWidth then
            lines[#lines + 1] = line
            line = word
        else
            line = candidate
        end
        at = b + 1
    end
    if line ~= "" then lines[#lines + 1] = line end
    return lines
end

--- Zeichnet den Hinweis als Kaestchen in `target`, umbrochen auf `maxWidth`.
-- Bis 0.12.0 war er eine einzige Zeile: "Build loaded: ... missing mod: ...;
-- 3 entries could not be read (...)" ist gut 900 px lang, das Panel in der
-- schmalen Anordnung keine 500, und der Text lief aus dem Bildschirm
-- (Bugjagd 20.09.2026).
-- @param align  "right" | "center" innerhalb von `maxWidth` ab `x`, sonst ab `x`
-- @param kind   die Farbe des Rahmens sagt, wie es ausging (seit 0.12.6, Wunsch aus
--               dem Abschlusstest): "ok" gruen (kopiert, geladen), "warn" orange
--               (geladen, aber etwas fehlt), "error" rot (nichts geladen); ohne
--               Angabe grau. Die Farben kommen aus dem gewaehlten Schema, mit
--               der Farbenblind-Option also Blau, Violett und Orange.
function TF.Panel.drawToast(target, text, x, y, maxWidth, align, kind)
    local font = UIFont.Small
    local lines, w, h, lh, badge = TF.Panel.toastSize(text, maxWidth)
    if type(maxWidth) ~= "number" or maxWidth < TOAST_MIN then maxWidth = TOAST_MIN end
    if align == "right" or align == true then
        x = math.max(x, x + maxWidth - w)
    elseif align == "center" then
        x = x + math.max(0, (maxWidth - w) / 2)
    end
    local o = TF.Panel.statusColor(kind)
    -- Deckend wie das Warnfenster: durch 0.96 schien der Text der Listen durch.
    target:drawRect(x, y, w, h, 1, 0.03, 0.03, 0.03)
    target:drawRectBorder(x, y, w, h, 1, o[1], o[2], o[3])
    target:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 1, o[1], o[2], o[3])
    TF.Panel.drawBadge(target, x + TOAST_PAD, y + TOAST_PAD, badge, kind)
    local c = (TF.fmt.rgb and TF.fmt.rgb.value) or { 0.85, 0.85, 0.85 }
    -- Eine einzelne Zeile steht mittig neben dem Kaestchen, mehrere beginnen oben.
    local textY = y + TOAST_PAD + ((#lines == 1) and math.floor((badge - lh) / 2) or 0)
    for i, line in ipairs(lines) do
        target:drawText(line, x + TOAST_PAD + badge + TOAST_GAP, textY + (i - 1) * lh, c[1], c[2], c[3], 1, font)
    end
    return #lines
end

--- Zeigt einen Hinweis fuer ein paar Sekunden mittig im Bildschirm, im oberen
-- Drittel ueber den Listen. Ein eigenes Kind des Bildschirms, zuletzt
-- angehaengt und nach vorn geholt: so liegt es ueber den Listen, egal ob das
-- Panel der Uebersicht sichtbar ist. Klicks gehen hindurch.
-- @param kind  "warn", wenn etwas nicht geladen werden konnte
function TF.Panel.showToast(screen, text, kind, ms)
    if not (screen and text and ISPanel and screen.addChild) then return nil end
    local toast = screen.tfToast
    if not toast then
        toast = ISPanel:new(0, 0, 10, 10)
        toast:initialise()
        toast.background = false
        toast.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        toast.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        for _, name in ipairs({ "onMouseDown", "onMouseUp", "onRightMouseDown", "onRightMouseUp", "onMouseWheel" }) do
            toast[name] = function() return false end
        end
        toast.prerender = function(t)
            local now = (getTimestampMs and getTimestampMs()) or 0
            if not t.tfUntil or now >= t.tfUntil then t:setVisible(false) end
        end
        toast.render = function(t)
            TF.safe("toast:draw", TF.Panel.drawToast, t, t.tfText or "", 0, 0, t:getWidth(), "center", t.tfKind)
        end
        screen:addChild(toast)
        screen.tfToast = toast
    end
    local sw = screen.getWidth and screen:getWidth() or 1200
    local sh = screen.getHeight and screen:getHeight() or 800
    local width = math.max(200, math.min(640, sw - 40))
    local _, _, height = TF.Panel.toastSize(text, width)
    toast.tfText, toast.tfKind = text, kind
    toast.tfUntil = ((getTimestampMs and getTimestampMs()) or 0) + (ms or 5000)
    toast:setWidth(width)
    toast:setHeight(height)
    toast:setX((sw - width) / 2)
    toast:setY(math.floor(sh * 0.30))
    toast:setVisible(true)
    if toast.bringToTop then toast:bringToTop() end
    return toast
end

--- Der Trait, auf dem ein Controller gerade steht, oder nil.
--
-- Mit dem Controller gibt es kein Ueberfahren und damit keinen Tooltip.
-- Vanilla zeigt die Beschreibung dann in einem Streifen von zwei Zeilen
-- Hoehe ohne Scrollbalken (tooltipRichText, autosetheight = false), und
-- ISRichTextPanel hoert an dessen Unterkante auf zu zeichnen: der ganze
-- Trait-Facts-Block faellt darunter weg (Audit 20.09.2026, U1). Solange eine
-- der drei Trait-Listen den Fokus hat, zeigt deshalb das Panel den Block
-- dieses Traits statt der Uebersicht; auf der Berufsliste steht wieder die
-- Uebersicht. Ohne Controller liefert das hier immer nil.
-- NICHT an Hardware geprueft (Stand 0.12.0).
-- Eine Tabelle, kein Wertepaar: TF.safe reicht nur den ersten Rueckgabewert
-- durch.
-- @return table|nil  { def = Definition, id = Kennung }
function TF.Panel.focusTrait(self)
    if not JoypadState then return nil end
    local pad = (JoypadState.getMainMenuJoypad and JoypadState.getMainMenuJoypad())
        or (CoopCharacterCreation and CoopCharacterCreation.getJoypad and CoopCharacterCreation.getJoypad())
    if not pad or (pad.isConnected and not pad:isConnected()) then return nil end
    for _, list in ipairs({ self.listboxTrait, self.listboxBadTrait, self.listboxTraitSelected }) do
        if list and list.joyfocus and list.getItem then
            local item = list:getItem()
            local def = item and item.item
            if def then return { def = def, id = TF.traitId(def) or tostring(def) } end
        end
    end
    return nil
end

function TF.Panel.refresh(self)
    local panel = ensurePanel(self)
    if not panel then return end
    local focused = TF.safe("summary:focus", TF.Panel.focusTrait, self)
    local focus = focused and focused.def or nil
    panel.tfFocusId = focused and focused.id or nil
    if focus then
        if TF.Options and TF.Options.sync then TF.safe("options:sync", TF.Options.sync) end
        local label = ""
        local ok, value = pcall(function() return focus:getLabel() end)
        if ok and value then label = TF.fmt.plain(value) end
        local block = TF.buildBlock and TF.safe("summary:focusblock", TF.buildBlock, focus) or nil
        panel:setText(COLOR_HEADER .. label .. (block and (NL .. block) or ""))
        panel.tfSpans, panel.tfExpectedLines = nil, nil
        panel.tfComposedWidth = panel:getWidth()
        panel:paginate()
        if panel.setYScroll then panel:setYScroll(0) end
        return
    end
    TF.Panel.fill(self, panel)
    -- Die ganze Ansicht (schmale Anordnung) zeigt dieselbe Uebersicht und
    -- folgt jeder Aenderung der Auswahl.
    if self.tfFull and self.tfFull.tfPanel then TF.safe("summary:full", TF.Panel.fill, self, self.tfFull.tfPanel) end
end

--- Setzt die Uebersicht des Bildschirms in `panel`, fuer dessen Breite.
function TF.Panel.fill(self, panel)
    -- Das Farbschema aus den Mod-Optionen, bevor der Text entsteht.
    if TF.Options and TF.Options.sync then TF.safe("options:sync", TF.Options.sync) end
    -- Die nutzbare Breite ist die Panelbreite ohne die eigenen Raender.
    -- ISRichTextPanel rechnet genauso (Vanilla, Z. 456).
    --
    -- Die Breite der Scrollleiste bleibt immer frei, auch wenn sie gerade
    -- nicht gezeichnet wird. Ob sie noetig ist, weiss man erst nach dem
    -- Umbrechen, und der Umbruch braucht die Breite vorher; die 17 Pixel
    -- stehenzulassen kostet in der Fussnotenspalte gut zwei Zeichen und
    -- erspart eine zweite Umbruchrunde samt ihrer Fehlerquellen.
    local nutzbar = panel:getWidth() - (panel.marginLeft or 0)
        - (panel.marginRight or 0) - SCROLLBAR_WIDTH
    -- Ohne Titelzeile: der Titel steht seit 0.5.0 in beiden Anordnungen in
    -- der Kopfzeile ueber dem Panel (placeHeader), mit ?, Zahnrad und
    -- Fehler melden. Im Text scrollte er mit.
    -- Der Beruf rechnet mit (seit 0.12.0): seine Foraging-Werte, seine
    -- Startstufen und damit die Stufen-Traits, die das Spiel selbst setzt.
    local profession = self.profession
    if not profession and self.getSelectedProf then
        profession = TF.safe("summary:prof", self.getSelectedProf, self)
    end
    local made = TF.Panel.compose(chosenTraits(self), false, nutzbar, profession)
    panel:setText(made.text)
    -- Streifen nur im Spaltensatz. Im durchlaufenden Satz bricht das Panel
    -- selbst um, die Zeilenzahl des Textes stimmt dann nicht, und
    -- drawStripes setzte mit einer Warnung aus - bei jedem schmalen
    -- Bildschirm. Ohne Spannen gibt es weder Streifen noch Warnung.
    panel.tfSpans = TF.Summary.columnsFor(nutzbar) and made.spans or nil
    panel.tfExpectedLines = made.lines
    -- Fuer welche Breite der Text gesetzt ist; der prerender-Hook setzt neu,
    -- sobald das Panel eine andere bekommt.
    panel.tfComposedWidth = panel:getWidth()
    panel:paginate()
end

--- Ab dieser Breite bekommt die Uebersicht eine eigene Spalte.
--
-- Die drei Vanilla-Spalten brauchen nur Platz fuer Namen und Kosten; auf einem
-- breiten Bildschirm steht rechts daneben viel leere Flaeche. Darunter wird es
-- eng, dann bleibt es beim Platz unter der Startskill-Liste.
local MIN_WIDTH_FOR_COLUMN = 1400

--- Anteil der Gesamtbreite je Vanilla-Spalte in der Vier-Spalten-Aufteilung.
--
-- Der Rest gehoert der Uebersicht, deren Zeilen deutlich laenger sind. Bei
-- 0.23 brach die laengste Zeile im Spiel noch um; ein Fuenftel je Spalte
-- reicht den Namen und Kosten weiterhin bequem und gibt der Uebersicht die
-- Breite, die ihre Zeilen brauchen.
local COLUMN_SHARE = 0.20

--- Breite, die wir der Uebersicht reservieren, oder 0.
--
-- Nicht selbst an den Vanilla-Listen ziehen: der erste Versuch hat genau das
-- getan (nach dem prerender setX und setWidth auf allen fuenf Listen), und im
-- Spiel zeichneten die vier Listen mit Scrollbalken danach keine einzige Zeile
-- mehr. Rahmen und Hintergrund kamen an, die Zeilen nicht, und die Tooltips
-- funktionierten weiter - die Eintraege waren also da, nur unsichtbar. Sie
-- werden zwischen setStencilRect und clearStencilRect gezeichnet, und der
-- Stencil haengt unter anderem an der Scrollbalken-Position, die einen Takt
-- hinterherlaeuft. Die einzige Liste ohne Scrollbalken war die einzige, die
-- funktionierte.
--
-- Deshalb jetzt andersherum: Vanilla rechnet seine Aufteilung selbst, nur mit
-- einer kleineren Breite. Es setzt Listen, Scrollbalken und Knoepfe dann so
-- zueinander, wie es das auch in einem schmaleren Fenster taete - ein Zustand,
-- den das Spiel taeglich hat.
local function reservedWidth(self)
    if not self.tfSummary then return 0 end
    local full = self:getWidth()
    -- Die Schwelle waechst mit der Schrift, wie MIN_NARROW_COLUMN in
    -- columnShift: bei Schriftgroesse 3x oder 4x blieben den Vanilla-Spalten
    -- auf 1920 px rund 380 px fuer doppelt so breite Buchstaben (Audit
    -- 20.09.2026). Nie unter 1400: eine kleinere Schrift macht die Spalte
    -- nicht frueher auf, dort ist der Stand im Spiel geprueft.
    local scale = TF.fmt.uiScale and TF.fmt.uiScale(UIFont and UIFont.Small or nil) or 1
    if type(scale) ~= "number" or scale < 1 then scale = 1 end
    if full < MIN_WIDTH_FOR_COLUMN * scale then return 0 end
    local reserve = math.floor(full * (1 - COLUMN_SHARE * 3))
    if reserve < 260 then return 0 end
    return reserve
end

--- Setzt die Uebersicht in die frei gewordene vierte Spalte.
local function placePanel(self, reserve)
    local panel = self.tfSummary
    local prof = self.listboxProf
    if not panel or not prof then return end

    -- UI_BORDER_SPACING ist in Vanilla eine Datei-lokale Variable (10), nie
    -- global. Hier war sie immer nil, und der Rand fiel auf 8 + 1 = 9 statt
    -- Vanillas 11 (CharacterCreationProfession.lua:170; Bugjagd 10.09.2026,
    -- Fund 7). tablePadX setzt Vanillas create() auf genau diesen Wert.
    local pad = self.tablePadX or 10
    local border = pad + 1
    local x = self:getWidth() - reserve + pad
    panel:setVisible(true)
    panel:setX(x)
    panel:setWidth(self:getWidth() - x - border)
    panel:setY(prof:getY())
    panel:setHeight(prof:getHeight())

    -- Einmal die gerechnete Aufteilung ins Log. Wenn im Spiel etwas nicht
    -- passt, steht die Ursache damit in console.txt statt in einer Vermutung.
    -- Als Hinweis, nicht als Warnung (seit 0.1.21): es ist keine Stoerung.
    local chosen = self.listboxTraitSelected
    TF.logOnce("panel:geometry", string.format(
        "Vier Spalten: Bildschirm %d, reserviert %d, Panel %d ab x=%d, Spalten %d/%d.",
        self:getWidth(), reserve, panel:getWidth(), x, prof:getWidth(),
        chosen and chosen:getWidth() or 0))
end

--- Hoehe der Kopfzeile (Titel, ?, Zahnrad, Fehler melden): die Schrift der
-- Vanilla-Ueberschriften, je Bild gemessen, damit eine andere
-- Schriftgroesse sofort gilt. FONT_HGT_MEDIUM ist in Vanilla Datei-lokal,
-- hier also nil; das "or 20" setzte die Beschriftung einst 9 px zu tief
-- (29 px bei Schriftgroesse 1x, bis 45 bei 4x; Bugjagd 10.09.2026, Funde 8
-- und 9).
local function headerHeight()
    local manager = getTextManager and getTextManager()
    local h = manager and manager.getFontHeight and manager:getFontHeight(UIFont.Medium)
    if type(h) ~= "number" or h <= 0 then h = 29 end
    return h
end

--- Schiebt Startskill-Liste und Panel zurecht.
local function layout(self)
    local panel = self.tfSummary
    local xp = self.listboxXpBoost
    if not panel or not xp then return end

    if self.tfWideColumn then return end

    local top = xp:getY()
    local bottom = top + xp:getHeight()

    local rows = 0
    if type(xp.items) == "table" then rows = #xp.items end
    if rows < MIN_ROWS then rows = MIN_ROWS end
    local rowH = xp.itemheight or 20
    local needed = rows * rowH
    -- Eine Zeile mit umbrochener Herkunft ist hoeher als itemheight. Vanilla
    -- legt die gezeichnete Hoehe je Eintrag in item.height ab
    -- (ISScrollingListBox:prerender); ohne sie scrollte die Liste, obwohl
    -- darunter Platz frei war (Audit 20.09.2026).
    if type(xp.items) == "table" and #xp.items > 0 then
        local sum = 0
        for _, item in ipairs(xp.items) do
            local h = type(item) == "table" and item.height or nil
            sum = sum + ((type(h) == "number" and h > 0) and h or rowH)
        end
        if #xp.items < MIN_ROWS then sum = sum + (MIN_ROWS - #xp.items) * rowH end
        if sum > needed then needed = sum end
    end
    needed = needed + 4
    if needed > xp:getHeight() then needed = xp:getHeight() end
    -- Die Liste scrollt, Trait Facts nicht: darum gibt sie Platz ab, bis die
    -- Kopfzeile und drei Zeilen Uebersicht darunter passen, aber nie unter
    -- MIN_ROWS eigene Zeilen. Bis 0.12.4 nahm sie sich, was sie brauchte. Nach
    -- dem Tod oeffnet das Spiel die Charaktererstellung auf 80 % der Hoehe, bei
    -- einem 1280x720-Fenster also 576 px, und mit den sieben Skills des Park
    -- Ranger verschwand Trait Facts dort ganz: keine Uebersicht, kein Zahnrad,
    -- kein Build kopieren, kein "Show all" (Bildschirmlauf in der Welt,
    -- 20.09.2026). Mit "Show all" in Reichweite ist die ganze Uebersicht einen
    -- Klick entfernt; ohne Kopfzeile war sie es nicht.
    local keep = GAP + headerHeight() + 4 + KEEP_LINES * lineGuess()
    local most = xp:getHeight() - keep
    local least = MIN_ROWS * rowH + 4
    if most < least then most = least end
    if needed > most then needed = most end

    xp:setHeight(needed)
    -- Der Scrollbalken der Liste behaelt sonst seine alte, kleinere Hoehe, und
    -- Vanilla zeichnet ihn, sobald der Inhalt hoeher ist als der Balken selbst
    -- (ISScrollBar:render): die Liste zeigte einen Balken, obwohl alle Zeilen
    -- hineinpassten (Bildschirmlauf 20.09.2026, 1280x720).
    if xp.vscroll and xp.vscroll.setHeight then xp.vscroll:setHeight(needed) end

    -- Ueber dem Panel ein Streifen fuer die Kopfzeile, wie die Ueberschrift
    -- ueber der eigenen Spalte (placeHeader). Stand der Titel samt "?" als
    -- erste Zeile im Panel, scrollte er mit, und Knoepfe dort lagen ueber
    -- dem Text (seit 0.5.0).
    local y = top + needed + GAP + headerHeight() + 4
    local height = bottom - y
    -- Bleibt zu wenig uebrig, verschwindet das Panel lieber, als eine
    -- Zeilenhoehe Text mit Rahmen zu zeigen.
    if height < 40 then
        panel:setVisible(false)
        -- Die Kopfzeile bleibt, solange sie selbst noch passt: mit dem Panel
        -- verschwanden bis 0.11.0 auch Zahnrad, Build kopieren und Fehler
        -- melden, ohne jeden Hinweis (Audit 20.09.2026). Das "?" der Legende
        -- reagiert ohne Panel nicht, es zeichnet seine Erklaerung dort hinein.
        local free = bottom - (top + needed + GAP)
        if free >= headerHeight() then
            self.tfHeaderOnly = { x = xp:getX(), y = top + needed + GAP, h = headerHeight() }
        else
            self.tfHeaderOnly = nil
        end
        return
    end
    self.tfHeaderOnly = nil
    panel:setVisible(true)
    panel:setX(xp:getX())
    panel:setWidth(xp:getWidth())
    panel:setY(y)
    panel:setHeight(height)
end

--- Anteil, um den Spalte 1 (Occupation) und 2 (Available Traits) schmaler
-- werden; Spalte 3 (Chosen Traits, Major Skills) bekommt beide Anteile dazu
-- (Wunsch 15.09.2026: bei 1920 px brach "Amputated Left Upper arm TOC" in
-- den Major Skills um; so wird Spalte 3 rund 100 px breiter).
local COLUMN_SHIFT_SHARE = 0.14

--- Schmaler als das (bei Schriftgroesse 1x) werden Spalte 1 und 2 nie: ein
-- langer Trait-Name mit Kuerzel und Kosten braucht rund 270 px. Bis 0.12.5
-- 300: nach dem Tod ist die Charaktererstellung bei einem 1920er Fenster nur
-- 1440 px breit, die Spalten standen damit bei 253 px, und zwei lange
-- More-Traits-Namen mit MTD-Kaestchen wurden gekuerzt (Bildschirmlauf in der
-- Welt, 20.09.2026; Entscheidung: dort breiter).
local MIN_NARROW_COLUMN = 330

--- Um wie viel Pixel Spalte 1 und 2 bei Vanillas gleicher Breite
-- `listWidth` schmaler werden; 0, wenn sie dann zu schmal wuerden.
local function columnShift(listWidth)
    if type(listWidth) ~= "number" then return 0 end
    local minimum = MIN_NARROW_COLUMN * TF.fmt.uiScale(UIFont and UIFont.Small or nil)
    local shift = math.floor(listWidth * COLUMN_SHIFT_SHARE)
    if listWidth - shift < minimum then shift = math.floor(listWidth - minimum) end
    if shift < 0 then return 0 end
    return shift
end

--- Laesst Vanillas prerender Spalte 1 und 2 schmaler und Spalte 3 breiter
-- setzen: fuer die Dauer des Aufrufs bekommt jede der fuenf Listen ein
-- eigenes setWidth, das Vanillas gleiche Breite umrechnet. Vanilla haengt
-- jede Spalte an getX() + getWidth() der linken Nachbarin und jeden Knopf an
-- getRight() seiner Liste (CharacterCreationProfession.lua 735-747), schiebt
-- also Spalte 2 und 3 samt Knoepfen und Ueberschriften selbst nach links.
-- Der rechte Rand von Spalte 3 bleibt, wo er war.
--
-- Nicht nach prerender selbst an den Listen ziehen: das ist schon einmal
-- schiefgegangen (siehe reservedWidth) - ein Bild lang Vanillas Breite, dann
-- unsere, und der Stencil der Listen lief hinterher. So setzt Vanilla jedes
-- Bild genau einmal dieselben Werte, wie in einem anders grossen Fenster.
-- @return function  setzt setWidth der Listen wieder auf den Stand vorher
local function shiftColumns(self)
    local plan = {
        { self.listboxProf, -1 }, { self.listboxTrait, -1 }, { self.listboxBadTrait, -1 },
        { self.listboxTraitSelected, 2 }, { self.listboxXpBoost, 2 },
    }
    local done = {}
    for _, p in ipairs(plan) do
        local list, factor = p[1], p[2]
        if list and type(list.setWidth) == "function" then
            local own = rawget(list, "setWidth")
            local setWidth = list.setWidth
            done[#done + 1] = { list = list, own = own }
            list.setWidth = function(element, w, ...)
                if type(w) == "number" then w = w + factor * columnShift(w) end
                return setWidth(element, w, ...)
            end
        end
    end
    return function()
        for _, d in ipairs(done) do rawset(d.list, "setWidth", d.own) end
    end
end

--- Kopfzeile der Uebersicht: Titel, "?" (Legende), Zahnrad (Optionen) und,
-- mit Abstand, Fehler melden (Entscheidung 16.09.2026, Mockup knoepfe). In
-- der eigenen Spalte steht sie ueber der Spalte wie Vanillas drei
-- Ueberschriften, sonst in dem Streifen, den layout ueber dem Panel frei
-- laesst. Die Knoepfe sind Kinder des Bildschirms, nicht des Panels, damit
-- sie nicht mitscrollen; placeHeader setzt sie je Bild.
local ICON_GEAR = "media/ui/inventoryPanes/Button_Settings.png"
local ICON_BUG = "media/ui/BugIcon.png"
-- Eigene Symbole: das Spiel bringt keines fuer Kopieren oder Einfuegen mit.
local ICON_COPY = "media/ui/TraitFacts/tf_copy.png"
local ICON_PASTE = "media/ui/TraitFacts/tf_paste.png"
-- Zwischen "?" und Zahnrad; beide gehoeren zur Anzeige.
local BUTTON_GAP = 6
-- Vor Fehler melden deutlich mehr: der Knopf fuehrt aus dem Spiel hinaus.
local BUG_GAP = 22

--- Die Stelle der Kopfzeile in Bildschirm-Koordinaten, oder nil.
local function headerRect(self)
    local panel = self.tfSummary
    if not panel then return nil end
    if panel.isVisible and not panel:isVisible() then
        local only = (not self.tfWideColumn) and self.tfHeaderOnly or nil
        return only and { x = only.x, y = only.y, h = only.h } or nil
    end
    local h = headerHeight()
    if self.tfWideColumn then
        local prof = self.listboxProf
        if not prof then return nil end
        return { x = panel:getX(), y = prof:getY() - h - 8, h = h }
    end
    return { x = panel:getX(), y = panel:getY() - h - 4, h = h }
end

--- Die Workshop-ID der laufenden Trait Facts, oder nil fuer eine lokale
-- Kopie (Entwicklung, kein Workshop). Wie Vanillas Mod-Auswahl
-- (ModInfoPanelParam): getModInfoByID(...):getWorkshopID().
function TF.Panel.workshopId()
    local ok, id = pcall(function() return getModInfoByID("TraitFacts"):getWorkshopID() end)
    if ok and id ~= nil and tostring(id) ~= "" then return tostring(id) end
    return nil
end

--- Das Wiki mit den Belegen: woher jede Zahl kommt und wie sie geprueft wurde
-- (seit 0.13.4). Erreichbar ueber das Zahnrad und ueber Optionen > Mods.
TF.Panel.WIKI_URL = "https://bluehelix-mods.github.io/trait-facts/"

--- Oeffnet eine Adresse im Steam-Overlay, sonst im Browser, wie Vanilla im
-- Hauptmenue (MainScreen). Verschickt wird nichts.
function TF.Panel.openUrl(url)
    if not url then return end
    if isSteamOverlayEnabled and isSteamOverlayEnabled() and activateSteamOverlayToWebPage then
        activateSteamOverlayToWebPage(url)
    elseif openUrl then
        openUrl(url)
    end
end

--- Wohin Fehler melden fuehrt: die Diskussionen der Workshop-Seite, oben der
-- angepinnte Thread "Bug reports". Ohne Workshop-ID (lokale Kopie, Mod
-- ausserhalb von Steam installiert) die Workshop-Suche nach "Trait Facts"
-- fuer Project Zomboid (App 108600): sie findet die Seite, sobald es sie
-- gibt, und der Knopf bleibt ueberall bedienbar und im Spiel pruefbar
-- (Wunsch 16.09.2026; bis dahin war er ohne ID grau).
function TF.Panel.reportUrl(id)
    id = id or TF.Panel.workshopId()
    if not id then
        return "https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=Trait+Facts"
    end
    return "https://steamcommunity.com/workshop/filedetails/discussions/" .. tostring(id) .. "/"
end

--- Zwei Zeilen fuer den Fehlerbericht, nur wenn es etwas zu sagen gibt: Hooks,
-- die nie liefen (ein anderer Mod hat die Funktion ersetzt), und was TF.safe
-- seit dem Start abgefangen hat. Ohne Befund leer, der Bericht bleibt kurz.
function TF.Panel.healthText()
    local out = ""
    local never = TF.hooksNeverRun and TF.hooksNeverRun() or {}
    if #never > 0 then
        out = out .. "Hooks that never ran (replaced by another mod?): " .. table.concat(never, ", ") .. "\n"
    end
    local caught = TF.caughtErrors and TF.caughtErrors() or {}
    if #caught > 0 then
        local shown = {}
        for i = 1, math.min(#caught, 8) do shown[i] = caught[i] end
        out = out .. "Caught errors (" .. #caught .. "): " .. table.concat(shown, ", ")
            .. ((#caught > 8) and ", ..." or "") .. "\n"
    end
    return out
end

--- Was Fehler melden in die Zwischenablage legt: Fassungen, Sprache,
-- Farbschema, fremde Trait-Mods, der Weg zum Log. Ein Link kann keinen Text
-- vorausfuellen, darum so. Englisch und nur ASCII: die Zeilen gehen an den
-- Autor, und ein Sonderzeichen direkt in einer .lua kam im Spiel schon
-- einmal falsch an (das Gradzeichen, siehe TF.Summary.valueCell).
function TF.Panel.reportText()
    local game, lang = "?", "?"
    pcall(function() game = tostring(getCore():getVersion()) end)
    pcall(function() lang = tostring(Translator.getLanguage()) end)
    local mods = {}
    for _, m in pairs((TF.Mods and TF.Mods.modCache) or {}) do
        if type(m) == "table" and m.name then
            mods[#mods + 1] = tostring(m.name) .. (m.version and (" " .. tostring(m.version)) or "")
        end
    end
    table.sort(mods)
    return "Trait Facts " .. tostring(TF.VERSION) .. " | game " .. game
        .. " | data " .. tostring(TF.DATA_BUILD) .. " | " .. lang
        .. " | colours: " .. tostring((TF.fmt and TF.fmt.scheme) or "standard") .. "\n"
        .. "Other trait mods: " .. ((#mods > 0) and table.concat(mods, ", ") or "none") .. "\n"
        .. TF.Panel.healthText()
        .. "If asked for a log: only the lines with TraitFacts from Zomboid/console.txt, "
        .. "the full file shows your Windows user name.\n\nWhat happened:\n"
end

--- Fehler melden: Versionsangaben in die Zwischenablage, dann die
-- Diskussionen oeffnen, im Steam-Overlay oder sonst im Browser, wie Vanilla
-- im Hauptmenue (MainScreen). Ein kurzer Hinweis im Panel sagt, was kopiert
-- wurde (drawTagLayer). Verschickt wird nichts.
local function reportBug(self)
    local url = TF.Panel.reportUrl()
    if not url then return end
    if Clipboard and Clipboard.setClipboard then
        TF.safe("bug:clipboard", function() Clipboard.setClipboard(TF.Panel.reportText()) end)
    end
    TF.safe("bug:open", TF.Panel.openUrl, url)
    TF.safe("bug:toast", TF.Panel.showToast, self, TF.fmt.text("UI_TF_opt_bug_copied"), "ok", 4000)
end

local function closeOptions(self)
    if self.tfOptionsPopup then self.tfOptionsPopup:setVisible(false) end
    if TF.OptionInfo and TF.OptionInfo.hide then TF.OptionInfo.hide() end
end

--- Bildschirmlage eines Elements; ohne getAbsoluteX (Test) ueber die Eltern.
local function absRect(el, parent)
    local x, y
    if el.getAbsoluteX then
        x, y = el:getAbsoluteX(), el:getAbsoluteY()
    else
        x, y = el:getX(), el:getY()
        if parent and parent.getAbsoluteX then
            x, y = x + parent:getAbsoluteX(), y + parent:getAbsoluteY()
        end
    end
    return x, y, el:getWidth(), el:getHeight()
end

local function hit(el, parent, mx, my)
    if not el then return false end
    local x, y, w, h = absRect(el, parent)
    return mx >= x and my >= y and mx < x + w and my < y + h
end

--- Ein Klick neben das Zahnrad-Fenster schliesst es (seit 0.13.8, Wunsch vom
-- 21.09.2026: etwa auf eine leere Stelle der Uebersicht). Gezaehlt wird der
-- Moment, in dem die linke Taste niedergeht, einmal je Druck. Ein Klick aufs
-- Zahnrad selbst bleibt dem Zahnrad, das ohnehin umschaltet.
-- @return boolean  true, wenn das Fenster dabei zugegangen ist
function TF.Panel.optionsClick(screen, mx, my, down)
    local popup = screen and screen.tfOptionsPopup
    if not (popup and popup:isVisible()) then return false end
    local was = popup.tfMouseWasDown
    popup.tfMouseWasDown = down == true
    if down ~= true or was then return false end
    if hit(popup, screen, mx, my) or hit(screen.tfGearButton, screen, mx, my) then return false end
    closeOptions(screen)
    return true
end

-- Die Checkboxen am Zahnrad, in dieser Reihenfolge; der Index ist der des
-- ISTickBox. Dieselben Optionen wie unter Optionen > Mods (TF_Options).
local POPUP_OPTIONS = {
    { id = "showdead", key = "UI_TF_opt_dead", get = "showDead", set = "setShowDead" },
    { id = "showexcludes", key = "UI_TF_opt_excludes", get = "showExcludes", set = "setShowExcludes" },
}

local function selectOptions(box)
    for i, opt in ipairs(POPUP_OPTIONS) do box:setSelected(i, TF.Options[opt.get]()) end
end

--- Das kleine Fenster am Zahnrad: Titel, die drei Checkboxen, die beim
-- Ueberfahren zeigen, was sie tun (TF_OptionInfo, seit 0.10.0), ein Satz,
-- dass sofort gespeichert wird, Schliessen. Entsteht beim ersten Klick, also nach
-- allen Listen, und liegt damit ueber ihnen.
local function ensureOptionsPopup(self)
    if self.tfOptionsPopup then return self.tfOptionsPopup end
    if not (ISPanel and ISTickBox and ISButton) then return nil end
    local font = UIFont.Small
    local manager = getTextManager and getTextManager()
    local lh = (manager and manager.getFontHeight and manager:getFontHeight(font)) or 19
    local pad = 10
    local title = TF.fmt.text("UI_TF_opt_title")
    local note = TF.fmt.text("UI_TF_opt_saved")
    local w = math.max(TF.fmt.measure(note, font), TF.fmt.measure(title, font))
    for _, opt in ipairs(POPUP_OPTIONS) do
        w = math.max(w, TF.fmt.measure(TF.fmt.text(opt.key), font) + 40)
    end
    w = w + 2 * pad
    local boxY = pad + lh + 8
    -- Die Hoehe der Checkboxen setzt ISTickBox:addOption selbst; was darunter
    -- steht, rueckt nach, sobald sie angelegt sind.
    local noteY, closeY = 0, 0
    local popup = ISPanel:new(0, 0, w, boxY + pad)
    popup:initialise()
    -- Deckend: durch 0.97 schien die Uebersicht darunter durch (Bildschirmlauf 20.09.2026).
    popup.backgroundColor = { r = 0.03, g = 0.03, b = 0.03, a = 1 }
    popup.borderColor = { r = 0.6, g = 0.6, b = 0.6, a = 0.8 }
    local baseRender = popup.render
    popup.render = function(p)
        if baseRender then baseRender(p) end
        p:drawText(title, pad, pad, 1, 1, 1, 1, font)
        local n = (TF.fmt.rgb and TF.fmt.rgb.note) or { 0.55, 0.55, 0.55 }
        p:drawText(note, pad, noteY, n[1], n[2], n[3], 1, font)
    end
    -- Erst einhaengen, dann die Kinder und die Option: Vanilla warnt, dass
    -- getKeepOnScreen sonst die Lage verschiebt (MainOptions, ISTickBox).
    self:addChild(popup)
    local box = ISTickBox:new(pad, boxY, w - 2 * pad, lh + 4, "", self, function(_, index, selected)
        local opt = POPUP_OPTIONS[index]
        if opt then TF.safe("options:" .. opt.get, TF.Options[opt.set], selected == true) end
    end)
    box:initialise()
    popup:addChild(box)
    for _, opt in ipairs(POPUP_OPTIONS) do box:addOption(TF.fmt.text(opt.key)) end
    selectOptions(box)
    local ids = {}
    for i, opt in ipairs(POPUP_OPTIONS) do ids[i] = opt.id end
    if TF.OptionInfo and TF.OptionInfo.watch then TF.safe("info:popup", TF.OptionInfo.watch, box, ids, popup) end
    noteY = boxY + math.max(box:getHeight(), #POPUP_OPTIONS * (lh + 4)) + 10
    closeY = noteY + lh + 10
    popup:setHeight(closeY + lh + 6 + pad)
    local wikiText = TF.fmt.text("UI_TF_opt_wiki")
    local wikiW = TF.fmt.measure(wikiText, font) + 24
    local closeW = TF.fmt.measure(TF.fmt.text("UI_TF_opt_close"), font) + 24
    -- Beide Knoepfe nebeneinander muessen hineinpassen.
    if wikiW + 8 + closeW + 2 * pad > w then
        w = wikiW + 8 + closeW + 2 * pad
        popup:setWidth(w)
    end
    local wiki = ISButton:new(pad, closeY, wikiW, lh + 6, wikiText, self,
        function() TF.safe("wiki:open", TF.Panel.openUrl, TF.Panel.WIKI_URL) end)
    wiki:initialise()
    if wiki.setTooltip then wiki:setTooltip(TF.fmt.text("UI_TF_opt_wiki_tooltip")) end
    popup:addChild(wiki)
    popup.tfWiki = wiki
    local close = ISButton:new(w - pad - closeW, closeY, closeW, lh + 6, TF.fmt.text("UI_TF_opt_close"), self,
        function(target) closeOptions(target) end)
    close:initialise()
    popup:addChild(close)
    popup.tfBox = box
    -- Klick daneben schliesst (TF.Panel.optionsClick). Nachgesehen wird in jedem
    -- Bild des offenen Fensters: ein Klick auf die Uebersicht oder eine Liste
    -- erreicht dieses Fenster sonst nicht, das Element darunter behaelt ihn.
    local basePrerender = popup.prerender
    popup.prerender = function(p)
        if basePrerender then basePrerender(p) end
        if getMouseX and isMouseButtonDown then
            TF.safe("options:outside", TF.Panel.optionsClick, self, getMouseX(), getMouseY(), isMouseButtonDown(0))
        end
    end
    popup:setVisible(false)
    self.tfOptionsPopup = popup
    return popup
end

local function toggleOptions(self)
    local popup = ensureOptionsPopup(self)
    if not popup then return end
    local show = not popup:isVisible()
    if show then
        -- Die Taste des Klicks, der das Fenster oeffnet, zaehlt nicht als Klick daneben.
        popup.tfMouseWasDown = true
        selectOptions(popup.tfBox)
        local gear = self.tfGearButton
        local x = gear:getX()
        if x + popup:getWidth() > self:getWidth() - 8 then x = self:getWidth() - 8 - popup:getWidth() end
        popup:setX(math.max(4, x))
        -- Unter dem Zahnrad, oder darueber, wenn es unten nicht passt. Bei
        -- grosser Schrift (38px) sitzt die Kopfzeile tief, und das Fenster lief
        -- unten aus dem Bild, auch bei 1920x1080 (Abnahme 21.09.2026).
        local y = gear:getY() + gear:getHeight() + 4
        local screenH = self.getHeight and self:getHeight() or nil
        if screenH and y + popup:getHeight() > screenH - 4 then
            y = gear:getY() - popup:getHeight() - 4
        end
        popup:setY(math.max(4, y))
    end
    popup:setVisible(show)
end

--- Nach einem Klick schweigt der Tooltip des Knopfs, bis die Maus ihn verlassen
-- hat und wieder darauf zeigt (seit 0.13.8, Wunsch vom 21.09.2026: nach dem
-- Klick aufs Zahnrad lag der Tooltip ueber dem Fenster, das er oeffnet).
-- Vanilla zeigt ihn in ISButton:updateTooltip, solange die Maus darauf steht.
function TF.Panel.quietTooltipAfterClick(button)
    if not button or button.tfQuietTip ~= nil then return end
    button.tfQuietTip = false
    local onclick = button.onclick
    if type(onclick) == "function" then
        button.onclick = function(target, b, ...)
            button.tfQuietTip = true
            return onclick(target, b, ...)
        end
    end
    local base = button.updateTooltip
    if type(base) ~= "function" then return end
    button.updateTooltip = function(b)
        if b.tfQuietTip then
            local over = b.isMouseOver and b:isMouseOver()
            if over then
                local tip = b.tooltipUI
                if tip and tip.getIsVisible and tip:getIsVisible() then
                    tip:setVisible(false)
                    tip:removeFromUIManager()
                end
                return
            end
            b.tfQuietTip = false
        end
        return base(b)
    end
end

--- Zahnrad und Fehler melden als echte Knoepfe mit den Symbolen des Spiels.
local function ensureButtons(self)
    if self.tfGearButton or not ISButton then return end
    local function iconButton(tooltipKey, icon, onclick)
        local size = headerHeight()
        local b = ISButton:new(0, 0, size, size, "", self, onclick)
        b:initialise()
        b.borderColor = { r = 0.81, g = 0.82, b = 0.81, a = 0.55 }
        b.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 1 }
        local texture = getTexture and getTexture(icon)
        if texture and b.setImage then
            b:setImage(texture)
            if b.forceImageSize then
                local inner = math.floor(size * 0.62)
                b:forceImageSize(inner, inner)
            end
        end
        if b.setTooltip then b:setTooltip(TF.fmt.text(tooltipKey)) end
        TF.Panel.quietTooltipAfterClick(b)
        self:addChild(b)
        return b
    end
    self.tfGearButton = iconButton("UI_TF_opt_title", ICON_GEAR, function(target)
        TF.safe("options:toggle", toggleOptions, target)
    end)
    self.tfBugButton = iconButton("UI_TF_opt_bug", ICON_BUG, function(target)
        TF.safe("bug:report", reportBug, target)
    end)
    -- "Show all": die ganze Uebersicht ueber den linken Spalten, nur in der
    -- schmalen Anordnung (TF.Panel.showFull).
    local allText = TF.fmt.text("UI_TF_sum_showall")
    local all = ISButton:new(0, 0, TF.fmt.measure(allText, UIFont.Small) + 20, headerHeight(), allText, self,
        function(target) TF.safe("full:toggle", TF.Panel.toggleFull, target) end)
    all:initialise()
    all.borderColor = { r = 0.81, g = 0.82, b = 0.81, a = 0.55 }
    all.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 1 }
    if all.setTooltip then all:setTooltip(TF.fmt.text("UI_TF_sum_showall_tooltip")) end
    self:addChild(all)
    self.tfShowAllButton = all
    -- Build als Text kopieren und einfuegen (TF_Build, seit 0.12.0).
    if TF.Build then
        self.tfCopyButton = iconButton("UI_TF_build_copy", ICON_COPY, function(target)
            TF.safe("build:copy", TF.Build.copy, target)
        end)
        self.tfPasteButton = iconButton("UI_TF_build_paste", ICON_PASTE, function(target)
            TF.safe("build:paste", TF.Build.paste, target)
        end)
    end
end

--- Legt je Bild fest, wo die Kopfzeile steht, und setzt die Knoepfe dorthin:
-- das Zahnrad direkt hinter das "?", Fehler melden mit Abstand dahinter.
-- Fehler melden ist immer bedienbar; ohne Workshop-ID fuehrt es auf die
-- Workshop-Suche (TF.Panel.reportUrl).
local function placeHeader(self)
    local rect = headerRect(self)
    self.tfHeader = rect
    if rect then
        local title = TF.fmt.text("UI_TF_sum_title")
        rect.qx = rect.x + TF.fmt.measure(title, UIFont.Medium) + 10
        rect.qw = TF.fmt.measure(LEGEND_MARK, UIFont.Medium) + 8
    end
    local gear, bug = self.tfGearButton, self.tfBugButton
    if not (gear and bug) then return end
    -- Reihenfolge: Zahnrad, Build kopieren, Build einfuegen, mit Abstand
    -- Fehler melden.
    local row = { gear }
    if self.tfCopyButton then row[#row + 1] = self.tfCopyButton end
    if self.tfPasteButton then row[#row + 1] = self.tfPasteButton end
    local all = self.tfShowAllButton
    if not rect then
        for _, b in ipairs(row) do b:setVisible(false) end
        bug:setVisible(false)
        if all then all:setVisible(false) end
        closeOptions(self)
        return
    end
    local size = rect.h
    local bugGap = BUG_GAP
    local start = rect.qx + rect.qw + BUTTON_GAP
    -- Passt die Zeile nicht in die Spalte, erst den Abstand vor Fehler melden
    -- einziehen, dann die Symbole verkleinern, nie unter MIN_ICON. Mit 38px
    -- Schrift war die Zeile gut 520 px breit; darunter lief "Show all" aus der
    -- Spalte und unter 1400 px Fensterbreite aus dem Bild, auch nach dem Tod
    -- bei 1920x1080 (dann 1536x864). Abnahme 21.09.2026.
    local narrow = all and not self.tfWideColumn
    local xp = self.listboxXpBoost
    if narrow and xp then
        local right = xp:getX() + xp:getWidth()
        -- Alles ausser den Symbolen selbst: die Abstaende und Show all.
        local fixed = (#row - 1) * BUTTON_GAP + BUTTON_GAP + all:getWidth()
        local function fits(s, gap) return start + (#row + 1) * s + fixed + gap <= right end
        local function largest(gap)
            return math.max(MIN_ICON, math.min(rect.h, math.floor((right - start - fixed - gap) / (#row + 1))))
        end
        if not fits(size, bugGap) then bugGap = BUTTON_GAP end
        if not fits(size, bugGap) then size = largest(bugGap) end
        if not fits(size, bugGap) then
            -- Letzter Ausweg: der Titel weicht, das "?" rueckt an den Anfang.
            -- Die Knoepfe tragen die Funktion, die Ueberschrift nur den Namen;
            -- lagen sonst uebereinander (Test mit 38px Schrift, 21.09.2026).
            rect.noTitle = true
            rect.qx = rect.x
            start = rect.qx + rect.qw + BUTTON_GAP
            size = largest(bugGap)
        end
    end
    -- Kleinere Symbole stehen mittig in der Hoehe der Kopfzeile.
    local y = rect.y + math.floor((rect.h - size) / 2)
    local x = start
    for _, b in ipairs(row) do
        b:setX(x)
        b:setY(y)
        b:setWidth(size)
        b:setHeight(size)
        b:setVisible(true)
        x = x + size + BUTTON_GAP
    end
    bug:setX(x - BUTTON_GAP + bugGap)
    bug:setY(y)
    bug:setWidth(size)
    bug:setHeight(size)
    bug:setVisible(true)
    if all then
        -- Rechtsbuendig an der Spalte, damit er nicht in den Knoepfen untergeht.
        all:setVisible(narrow == true)
        if narrow then
            local rightEdge = xp and (xp:getX() + xp:getWidth()) or (bug:getX() + size + bugGap + all:getWidth())
            all:setHeight(rect.h)
            local ax = math.max(bug:getX() + size + BUTTON_GAP, rightEdge - all:getWidth())
            -- Reicht selbst MIN_ICON nicht, bleibt er wenigstens im Bild.
            if self.getWidth then ax = math.min(ax, self:getWidth() - all:getWidth() - 4) end
            all:setX(ax)
            all:setY(rect.y)
        end
    end
end

local function install()
    if not CharacterCreationProfession then return end
    if TF._orig["panel:checkXPBoost"] then return end

    local original = CharacterCreationProfession.checkXPBoost
    if type(original) ~= "function" then
        TF.warn("CharacterCreationProfession.checkXPBoost nicht gefunden, "
            .. "die Gesamtuebersicht entfaellt.")
        return
    end
    TF._orig["panel:checkXPBoost"] = original
    CharacterCreationProfession.checkXPBoost = function(self, ...)
        TF.ran("panel:checkXPBoost")
        local result = TF._orig["panel:checkXPBoost"](self, ...)
        TF.safe("summary:refresh", TF.Panel.refresh, self)
        return result
    end

    -- Das Panel entsteht in create, wo Vanilla seine Kinder auch anlegt.
    local create = CharacterCreationProfession.create
    if type(create) == "function" then
        TF._orig["panel:create"] = create
        CharacterCreationProfession.create = function(self, ...)
            TF.ran("panel:create")
            local result = TF._orig["panel:create"](self, ...)
            TF.safe("summary:create", function()
                ensurePanel(self)
                ensureButtons(self)
                TF.Panel.refresh(self)
            end)
            return result
        end
    end

    local prerender = CharacterCreationProfession.prerender
    if type(prerender) ~= "function" then
        TF.warn("CharacterCreationProfession.prerender nicht gefunden, "
            .. "die Gesamtuebersicht bleibt ohne Platz.")
        return
    end
    TF._orig["panel:prerender"] = prerender
    CharacterCreationProfession.prerender = function(self, ...)
        TF.ran("panel:prerender")
        -- Vanilla rechnet in prerender `listWidth` aus `self:getWidth()` und
        -- verteilt daraus alle drei Spalten samt Knoepfen. Reservieren wir
        -- Platz, indem wir fuer die Dauer dieses Aufrufs eine kleinere Breite
        -- melden, macht es die schmalen Spalten selbst - mitsamt allem, was
        -- daran haengt. Danach ist die Methode wieder die geerbte.
        local reserve = 0
        TF.safe("summary:reserve", function() reserve = reservedWidth(self) end)

        if reserve > 0 then
            self.getWidth = function(element)
                return ISUIElement.getWidth(element) - reserve
            end
        end
        local restoreColumns = TF.safe("summary:columns", shiftColumns, self)
        local ok, err = pcall(TF._orig["panel:prerender"], self, ...)
        self.getWidth = nil
        if restoreColumns then TF.safe("summary:columns:restore", restoreColumns) end
        if not ok then
            TF.warnOnce("panel:prerender", "Vanilla-prerender fehlgeschlagen: " .. tostring(err))
            error(err)
        end

        local wide = reserve > 0
        local changed = self.tfWideColumn ~= wide
        self.tfWideColumn = wide
        if wide then
            TF.safe("summary:place", placePanel, self, reserve)
        else
            TF.safe("summary:layout", layout, self)
        end
        -- Kopfzeile und Knoepfe folgen dem Panel, das gerade gesetzt wurde.
        TF.safe("summary:header", placeHeader, self)
        -- Erst die Geometrie, dann der Text: der Umbruch braucht die Breite,
        -- die placePanel/layout gerade gesetzt haben. Der erste Stand setzte
        -- den Text davor, also fuer die 10 px des frischen Panels, und die
        -- Uebersicht stand bis zum ersten Klick durchlaufend statt in
        -- Spalten. Dieselbe Pruefung faengt eine geaenderte Fenstergroesse
        -- ab: weicht die Breite von der ab, fuer die der Text gesetzt wurde,
        -- wird neu gesetzt. Im Ruhezustand stimmen beide ueberein, dann
        -- passiert hier nichts (Review 10.09.2026).
        local panel = self.tfSummary
        -- Mit Controller folgt das Panel dem Trait unter dem Fokus
        -- (TF.Panel.focusTrait); ohne Controller ist beides immer nil.
        local focused = TF.safe("summary:focus", TF.Panel.focusTrait, self)
        local focusId = focused and focused.id or nil
        if changed or (panel and (panel.tfComposedWidth ~= panel:getWidth()
                or panel.tfFocusId ~= focusId)) then
            TF.safe("summary:refresh", TF.Panel.refresh, self)
        end
        -- Das Farbschema aus den Mod-Optionen, je Bild abgeglichen (ohne
        -- Aenderung nur ein Vergleich). Weicht es von dem ab, mit dem dieser
        -- Bildschirm zuletzt angereichert wurde, bekommen die drei Trait-
        -- Listen neue Bloecke, und checkXPBoost baut Startskill-Liste, deren
        -- Tooltips und die Uebersicht neu. Auch beim ersten Bild: der
        -- Bildschirm entsteht schon beim Spielstart, eine im Hauptmenue
        -- geaenderte Option trifft ihn erst hier. Bis 0.4.2 geschah das erst
        -- bei der naechsten Trait-Aenderung (Befund im Spiel 16.09.2026).
        TF.safe("summary:scheme", function()
            if TF.Options and TF.Options.sync then TF.Options.sync() end
            -- Seit 0.9.0 alle Optionen, die Tooltips praegen, nicht nur das
            -- Schema (TF.viewKey).
            local view = TF.viewKey and TF.viewKey()
            if self.tfView == view then return end
            self.tfView = view
            if TF.redecorateTraitLists then TF.redecorateTraitLists(self) end
            if self.checkXPBoost then self:checkXPBoost() end
        end)
    end

    -- In der eigenen Spalte bekommt die Uebersicht dieselbe Ueberschrift wie
    -- die drei daneben. Vanilla zeichnet seine drei in render(), auf derselben
    -- Hoehe und in derselben Schrift.
    local render = CharacterCreationProfession.render
    if type(render) ~= "function" then return end
    TF._orig["panel:render"] = render
    CharacterCreationProfession.render = function(self, ...)
        TF.ran("panel:render")
        TF._orig["panel:render"](self, ...)
        TF.safe("summary:caption", function()
            -- Die Stelle des "?" gilt nur fuer dieses Bild.
            local panel = self.tfSummary
            if panel then panel.tfLegendAnchor = nil end
            -- Die Kopfzeile in beiden Anordnungen (placeHeader, seit 0.5.0):
            -- ueber der eigenen Spalte auf Hoehe von Vanillas drei
            -- Ueberschriften, sonst im Streifen ueber dem Panel. Die Hoehe
            -- misst headerHeight je Bild, eine andere Schriftgroesse gilt
            -- also sofort.
            local rect = self.tfHeader
            if not panel or not rect then return end
            local title = TF.fmt.text("UI_TF_sum_title")
            -- Ohne Titel, wenn die Kopfzeile sonst nicht in die Spalte passt (placeHeader).
            if not rect.noTitle then self:drawText(title, rect.x, rect.y, 1, 1, 1, 1, UIFont.Medium) end
            -- Das "?" der Legende rechts daneben, gerahmt. Die Stelle geht in
            -- Panel-Koordinaten ans Panel; dort fragt drawTagLayer die Maus
            -- ab und zeichnet die Legende ueber dem Panel.
            local qx = rect.qx or (rect.x + TF.fmt.measure(title, UIFont.Medium) + 10)
            local qw = rect.qw or (TF.fmt.measure(LEGEND_MARK, UIFont.Medium) + 8)
            if self.drawRectBorder then
                local c = (TF.fmt.rgb and TF.fmt.rgb.note) or { 0.55, 0.55, 0.55 }
                self:drawRectBorder(qx, rect.y, qw, rect.h, 0.9, c[1], c[2], c[3])
            end
            self:drawText(LEGEND_MARK, qx + 4, rect.y, 1, 1, 1, 1, UIFont.Medium)
            panel.tfLegendAnchor = { x = qx - panel:getX(), y = rect.y - panel:getY(), w = qw, h = rect.h }
        end)
    end

    -- Esc schliesst das offene Zahnrad-Fenster und sonst nichts: ohne diese
    -- Huelle hiess Esc dort "Back" und verliess die Charaktererstellung
    -- (Audit 20.09.2026). Scheitert die Pruefung, laeuft Vanilla wie immer.
    local keyRelease = CharacterCreationProfession.onKeyRelease
    if type(keyRelease) == "function" and not TF._orig["panel:onKeyRelease"] then
        TF._orig["panel:onKeyRelease"] = keyRelease
        CharacterCreationProfession.onKeyRelease = function(self, key, ...)
            if TF.safe("panel:esc", TF.Panel.closeOnEscape, self, key) == true then return end
            return TF._orig["panel:onKeyRelease"](self, key, ...)
        end
    end
end

--- Die ganze Uebersicht als Fenster ueber den beiden linken Spalten.
--
-- Unter 1400 px Breite (auch Steam Deck, 1280x800) hat die Uebersicht keine
-- eigene Spalte und teilt sich das rechte untere Viertel mit den Major
-- Skills. Der Bildschirmlauf vom 20.09.2026 hat gemessen, was davon bleibt:
-- bei 1280x720 8 von 89 Zeilen, mit sieben Startskills 3 von 43. Der Knopf
-- "Show all" in der Kopfzeile legt sie deshalb ueber Occupation und Available
-- Traits (Entscheidung 20.09.2026, Mockup schmale-anordnung-2026-09-20,
-- Variante A): rund 35 Zeilen auf einmal, im Spaltensatz. Die gewaehlten
-- Traits und die Major Skills rechts bleiben sichtbar und bedienbar, auf sie
-- bezieht sich die Uebersicht; sie folgt jeder Aenderung.
--
-- Ein eigenes Fenster ganz oben, kein Kind des Bildschirms: Vanilla zeichnet
-- seine Spaltentitel in render, also nach den Kindern (siehe TF.Build.
-- showMissing). Ohne UI-Manager (Test) bleibt es ein Kind.
function TF.Panel.fullRect(self)
    local prof, good, bad = self.listboxProf, self.listboxTrait, self.listboxBadTrait
    if not (prof and good) then return nil end
    local head = headerHeight() + 8
    local x = prof:getX()
    local y = prof:getY() - head
    local right = good:getX() + good:getWidth()
    local bottom = prof:getY() + prof:getHeight()
    if bad then bottom = math.max(bottom, bad:getY() + bad:getHeight()) end
    return { x = x, y = y, w = right - x, h = bottom - y, head = head }
end

function TF.Panel.closeFull(self)
    local full = self and self.tfFull
    if not full then return false end
    self.tfFull = nil
    full:setVisible(false)
    if full.tfTopLevel and full.removeFromUIManager then
        full:removeFromUIManager()
    elseif self.removeChild then
        self:removeChild(full)
    end
    return true
end

function TF.Panel.showFull(self)
    if self.tfFull then return self.tfFull end
    if not (ISPanel and ISRichTextPanel and ISButton) then return nil end
    local rect = TF.Panel.fullRect(self)
    if not rect then return nil end
    local full = ISPanel:new(0, 0, rect.w, rect.h)
    full:initialise()
    full.backgroundColor = { r = 0.03, g = 0.03, b = 0.03, a = 1 }
    full.borderColor = { r = 0.6, g = 0.6, b = 0.6, a = 1 }
    local title, sub = TF.fmt.text("UI_TF_sum_title"), TF.fmt.text("UI_TF_sum_subtitle")
    local baseRender = full.render
    full.render = function(f)
        if baseRender then baseRender(f) end
        f:drawText(title, 8, 4, 1, 1, 1, 1, UIFont.Medium)
        local n = (TF.fmt.rgb and TF.fmt.rgb.note) or { 0.55, 0.55, 0.55 }
        f:drawText(sub, 8 + TF.fmt.measure(title, UIFont.Medium) + 10, 4 + (headerHeight() - 19) / 2,
            n[1], n[2], n[3], 1, UIFont.Small)
    end
    if full.addToUIManager then
        full:addToUIManager()
        if full.setAlwaysOnTop then full:setAlwaysOnTop(true) end
        full.tfTopLevel = true
    else
        self:addChild(full)
    end
    local panel = newSummaryPanel(full)
    panel.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    full.tfPanel = panel
    local closeText = TF.fmt.text("UI_TF_opt_close")
    local closeW = TF.fmt.measure(closeText, UIFont.Small) + 24
    local close = ISButton:new(0, 4, closeW, headerHeight() - 2, closeText, self,
        function(target) TF.Panel.closeFull(target) end)
    close:initialise()
    full:addChild(close)
    full.tfClose = close
    -- Lage je Bild: folgt einer geaenderten Fenstergroesse, und das Fenster
    -- geht mit dem Bildschirm (Back, Next) und mit der schmalen Anordnung.
    local function place(f)
        local r = TF.Panel.fullRect(self)
        if not r then return end
        local ox, oy = 0, 0
        if f.tfTopLevel then
            ox, oy = self:getAbsoluteX(), self:getAbsoluteY()
        end
        f:setX(ox + r.x)
        f:setY(oy + r.y)
        f:setWidth(r.w)
        f:setHeight(r.h)
        close:setX(r.w - closeW - 6)
        local resized = panel:getWidth() ~= r.w - 2 or panel:getHeight() ~= r.h - r.head - 1
        panel:setX(1)
        panel:setY(r.head)
        panel:setWidth(r.w - 2)
        panel:setHeight(r.h - r.head - 1)
        if resized then TF.Panel.fill(self, panel) end
    end
    local basePrerender = full.prerender
    full.prerender = function(f)
        local alive = not self.tfWideColumn
        if alive and self.isReallyVisible then
            local ok, visible = pcall(function() return self:isReallyVisible() end)
            alive = not ok or visible
        end
        if not alive then
            TF.Panel.closeFull(self)
            return
        end
        TF.safe("full:place", place, f)
        if basePrerender then basePrerender(f) end
    end
    self.tfFull = full
    place(full)
    TF.Panel.fill(self, panel)
    return full
end

function TF.Panel.toggleFull(self)
    if self.tfFull then return TF.Panel.closeFull(self) end
    return TF.Panel.showFull(self)
end

--- Schliesst das Zahnrad-Fenster, wenn es offen ist und `key` Esc ist.
-- @return boolean  true, wenn Vanilla die Taste nicht sehen soll
function TF.Panel.closeOnEscape(screen, key)
    if not (Keyboard and key == Keyboard.KEY_ESCAPE) then return false end
    -- Ebenso das Fenster der fehlenden Mods nach Build einfuegen (TF_Build).
    if TF.Build and TF.Build.closeMissing and TF.Build.closeMissing(screen) then return true end
    -- Die Rueckfrage vor dem Ersetzen eines Builds: Esc heisst Nein.
    if TF.Build and TF.Build.closeAsk and TF.Build.closeAsk(screen) then return true end
    if TF.Panel.closeFull(screen) then return true end
    local popup = screen and screen.tfOptionsPopup
    if not (popup and popup.isVisible and popup:isVisible()) then return false end
    popup:setVisible(false)
    if TF.OptionInfo and TF.OptionInfo.hide then TF.OptionInfo.hide() end
    return true
end

Events.OnGameBoot.Add(function()
    TF.safe("install:panel", install)
end)
