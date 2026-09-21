--- Trait Facts - Textaufbau.
-- Baut aus den Eintraegen eines Traits den Block, der an die Vanilla-
-- Beschreibung angehaengt wird.
--
-- Darstellung: der Tooltip der Trait-Liste landet als `description` in einem
-- ISToolTip und wird von dessen ISRichTextPanel gerendert. Damit stehen die
-- Rich-Text-Tags zur Verfuegung - <LINE> als Zeilenumbruch, <RGB:r,g,b> fuer
-- Farbe (Werte von 0 bis 1) und <SETX:n> fuer eine feste Spalte.
--
-- Der Block steht in denselben drei Spalten wie die Gesamtuebersicht: Wert
-- vorn und farbig, dann die Bezeichnung, dann die Fussnote. Wer die
-- Uebersicht gelesen hat, liest den Tooltip ohne Umdenken (Entscheidung vom
-- 09.09.2026 am Mockup docs/mockups/tooltip.html, Variante "kompakt").
--
-- Eigenheiten des Panels, die den Aufbau hier bestimmen:
--  * Tags werden als eigene Token zwischen Leerzeichen erkannt, deshalb steht
--    um jedes Tag ein Leerzeichen.
--  * <RGB:> gilt fuer die ganze Zeile, nicht ab der Position. Jede Zeile setzt
--    ihre Farbe deshalb selbst, statt sich auf die vorherige zu verlassen.
--  * Gross-/Kleinschreibung zaehlt: <LINE> wirkt, <line> und <br> nicht.
--  * ISToolTip macht das Panel so breit wie seine breiteste Zeile (Vanilla
--    layoutContents: lineX plus gemessene Breite), und ISScrollingListBox
--    setzt maxLineWidth auf 1000, bricht also selbst nichts um. Ein Trait mit
--    kurzen Zeilen bekommt darum einen schmalen Tooltip; die Spaltenmasse
--    unten sind die Obergrenze, ab der die Fussnote umbricht.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Tooltip = TF.Tooltip or {}

local NL = " <LINE> "

-- <BR> rueckt um zwei Zeilenhoehen vor und erzeugt damit eine Leerzeile. Die
-- braucht es genau einmal: zwischen der Vanilla-Beschreibung und unserem Block,
-- damit beides nicht als ein Absatz gelesen wird.
local GAP = " <BR> "

--- Nimmt die fuehrende Leerzeile wieder weg.
-- Fuer den Fall, dass vor unserem Block nichts steht: dann waere die Leerzeile
-- keine Trennung, sondern eine Luecke ueber der ersten Zeile.
function TF.stripLeadingGap(block)
    if type(block) ~= "string" then return block end
    if block:sub(1, #GAP) == GAP then return block:sub(#GAP + 1) end
    return block
end

-- Drei Helligkeitsstufen, Entscheidung vom 09.09.2026 am Mockup:
--   Bezeichnung weiss, Wert im bisherigen Grau, Beiwerk (Versionsstempel,
--   Fussnoten, "Excludes:") leise. Bezeichnung und Wert sind das Wichtige,
--   die duerfen nicht zuruecktreten. 0.55 auf dem Tooltip-Grund liegt bei
--   rund 5.5:1 Kontrast, also noch ueber der 4.5:1-Grenze.
--
-- Das Panel legt bei jedem Tag ein neues Segment mit eigener Farbe an, deshalb
-- koennen Bezeichnung und Wert auf einer Zeile verschieden gefaerbt sein. Ein
-- Zeilenumbruch innerhalb eines Segments behaelt dessen Farbe.
local COLOR_LABEL  = " <RGB:1.0,1.0,1.0> "
local COLOR_VALUE  = " <RGB:0.85,0.85,0.85> "
local COLOR_NOTE   = " <RGB:0.55,0.55,0.55> "
-- Der Trait-Name in der Uebersicht. Grau-Lila statt eines weiteren Graus:
-- Name und Fussnote stehen in derselben Spalte hintereinander, und ein
-- Helligkeitsunterschied allein trennt sie zu schwach.
local COLOR_SOURCE = " <RGB:0.72,0.65,0.86> "

-- Die drei Farben, die etwas bewerten, je Farbschema (Mod-Option seit 0.4.0,
-- TF_Options). Rich-Text-Tag und dieselbe Farbe als Zahlen.
--
-- standard: der Wert, je nachdem ob er der Figur hilft oder schadet,
-- gruenlich oder roetlich. Gedaempft, damit die Zeile ruhig bleibt und die
-- Farbe nur einordnet, statt zu schreien; beide ueber der 4.5:1-Grenze auf
-- dem Tooltip-Grund. `stale` ist eine Zeile, deren Messung dem hinterlegten
-- Wert widerspricht: auffaellig, aber nicht schreiend, sie ist nicht falsch,
-- nur neuer als die Daten.
--
-- game (seit 0.12.14, Entscheidung 21.09.2026): die Farben des Spielers aus
-- den Spieloptionen, Barrierefreiheit, 'Good' und 'Bad' Highlight Color. Bis
-- 0.12.13 gab es dafuer eine eigene Option "Farben fuer Farbenblinde" (Blau
-- und Orange); das Spiel hat die Einstellung laengst, und wer sie dort trifft,
-- soll sie hier nicht noch einmal treffen muessen. Jede der beiden Farben fuer
-- sich: steht sie auf der Vorgabe des Spiels (reines Gruen 0,1,0, reines Rot
-- 1,0,0), bleibt unser gedaempfter Ton; hat der Spieler sie geaendert, gilt
-- genau seine Farbe. Das Schema entsteht in TF.fmt.gameScheme.
local SCHEMES = {
    standard = {
        rich = { good = " <RGB:0.45,0.72,0.48> ", bad = " <RGB:0.82,0.50,0.47> ", stale = " <RGB:1.0,0.75,0.3> " },
        rgb = { good = { 0.45, 0.72, 0.48 }, bad = { 0.82, 0.50, 0.47 }, stale = { 1.0, 0.75, 0.3 } },
    },
}
-- Die Warnfarbe, wenn eine Farbe des Spielers beim Orange landet: Rotviolett,
-- sonst truegen zwei Bedeutungen dieselbe Farbe (Entscheidung 15.09.2026).
local STALE_ROSE = { 0.80, 0.47, 0.65 }
local GAME_DEFAULT = { good = { 0, 1, 0 }, bad = { 1, 0, 0 } }
local COLOR_STALE = SCHEMES.standard.rich.stale
local COLOR_GOOD  = SCHEMES.standard.rich.good
local COLOR_BAD   = SCHEMES.standard.rich.bad

-- Palette fuer TF.fmt.line und TF.fmt.columns: gilt fuer hinterlegte und
-- live gelesene Zeilen, im Tooltip wie in der Uebersicht.
--
-- Ein Kuerzel eines Mods oder Pakets steht in der Farbe seines Mods, unter
-- dem Farbnamen "tag:XYZ" (TF.fmt.tagKey, TF.fmt.paint; Entscheidung
-- 14.09.2026, Mockup trait-auswahl-mod-farben). TF.fmt.columns beginnt ein
-- Segment bei jedem Namenswechsel; mit eigenem Namen steht das Kuerzel immer
-- als eigenes Segment, auch direkt vor einer Fussnote ("DEMO; melee only"),
-- und TF.Panel.tagBoxes findet es (Abschlussreview 14.09.2026, Fund 1).
-- `tag` bleibt das Grau fuer ein Kuerzel ohne Farbe (nie belegt).
--
-- `ghost` ist leiser als die Fussnote: der Name eines ausgeblendeten
-- Abschnitts in der Vorschau am "i" der Optionen (TF_OptionInfo). Er steht
-- fuer etwas, das fehlt, und soll nicht als Inhalt gelesen werden.
TF.fmt.palette = { label = COLOR_LABEL, value = COLOR_VALUE, note = COLOR_NOTE,
                   good = COLOR_GOOD, bad = COLOR_BAD, stale = COLOR_STALE,
                   source = COLOR_SOURCE, tag = COLOR_NOTE, ghost = " <RGB:0.40,0.40,0.40> " }

-- Dieselben Farben als Zahlen, fuer Stellen, die selbst zeichnen statt Rich
-- Text zu setzen: die Startskill-Liste (TF_XpColumns). `off` ist der graue
-- Umriss eines leeren Boost-Pfeils. Aendert sich oben eine Farbe, hier mit.
TF.fmt.rgb = { label = { 1.0, 1.0, 1.0 }, value = { 0.85, 0.85, 0.85 },
               note = { 0.55, 0.55, 0.55 }, tag = { 0.55, 0.55, 0.55 },
               source = { 0.72, 0.65, 0.86 },
               good = { 0.45, 0.72, 0.48 }, bad = { 0.82, 0.50, 0.47 },
               off = { 0.42, 0.42, 0.42 }, stale = { 1.0, 0.75, 0.3 }, ghost = { 0.40, 0.40, 0.40 } }

--- Das Farbschema, das gerade gilt (TF.fmt.useScheme).
TF.fmt.scheme = "standard"

local function richOf(c)
    return " <RGB:" .. string.format("%.2f", c[1]) .. "," .. string.format("%.2f", c[2]) .. ","
        .. string.format("%.2f", c[3]) .. "> "
end

--- Farbton in Grad, oder nil fuer Grau.
local function hueOf(c)
    local mx, mn = math.max(c[1], c[2], c[3]), math.min(c[1], c[2], c[3])
    local d = mx - mn
    if d < 0.12 then return nil end
    local h
    if mx == c[1] then h = ((c[2] - c[3]) / d) % 6
    elseif mx == c[2] then h = (c[3] - c[1]) / d + 2
    else h = (c[1] - c[2]) / d + 4 end
    return h * 60
end

--- Liest die beiden Hervorhebungsfarben des Spiels und legt daraus das Schema
-- "game" an. Einmal je Lua-Sitzung: das Spiel laedt das Lua neu, wenn der
-- Spieler eine der Farben aendert (MainOptions, gameOption.apply: resetLua).
-- @param force  true liest neu (Tests)
-- @return string  "game", wenn der Spieler mindestens eine Farbe geaendert hat, sonst "standard"
function TF.fmt.gameScheme(force)
    if TF.fmt.gameSchemeName and not force then return TF.fmt.gameSchemeName end
    -- Neu gelesen heisst neu gesetzt: useScheme vergleicht nur den Namen, und
    -- "game" kann nach dem Lesen andere Farben tragen.
    if force then TF.fmt.scheme = nil end
    local picked = {}
    pcall(function()
        local core = getCore()
        local g, b = core:getGoodHighlitedColor(), core:getBadHighlitedColor()
        picked.good = { g:getR(), g:getG(), g:getB() }
        picked.bad = { b:getR(), b:getG(), b:getB() }
    end)
    local std = SCHEMES.standard.rgb
    local rgb, changed = { stale = std.stale }, false
    for _, key in ipairs({ "good", "bad" }) do
        local c, def = picked[key], GAME_DEFAULT[key]
        local touched = c ~= nil and type(c[1]) == "number" and (math.abs(c[1] - def[1]) > 0.004
            or math.abs(c[2] - def[2]) > 0.004 or math.abs(c[3] - def[3]) > 0.004)
        rgb[key] = touched and c or std[key]
        if touched then
            changed = true
            local hue, amber = hueOf(c), hueOf(std.stale)
            if hue then
                local d = math.abs(hue - amber) % 360
                if math.min(d, 360 - d) < 35 then rgb.stale = STALE_ROSE end
            end
        end
    end
    SCHEMES.game = nil
    if changed then
        SCHEMES.game = { rgb = rgb, rich = { good = richOf(rgb.good), bad = richOf(rgb.bad), stale = richOf(rgb.stale) } }
    end
    TF.fmt.gameSchemeName = changed and "game" or "standard"
    return TF.fmt.gameSchemeName
end

--- Setzt ein Farbschema ("standard", "game"; unbekannt gilt als
-- standard). Getauscht werden nur gut, schlecht und abweichend, in Palette
-- und Zahlen; beide Tabellen bleiben dieselben, jeder liest sie beim
-- Zeichnen. Fertige Tooltip-Bloecke tragen die alte Farbe im Text und fallen
-- darum weg. @return boolean  true, wenn sich etwas geaendert hat
function TF.fmt.useScheme(name)
    if not SCHEMES[name] then name = "standard" end
    if TF.fmt.scheme == name then return false end
    local scheme = SCHEMES[name]
    for _, key in ipairs({ "good", "bad", "stale" }) do
        TF.fmt.palette[key] = scheme.rich[key]
        TF.fmt.rgb[key] = scheme.rgb[key]
    end
    TF.fmt.scheme = name
    if TF.Tooltip and TF.Tooltip.forget then TF.Tooltip.forget() end
    return true
end

--- Fuehrt fn mit einem anderen Farbschema aus und stellt das geltende danach
-- wieder her, auch wenn fn wirft. Fuer die Vorschau am "i" der Optionen
-- (TF_OptionInfo): sie zeigt beide Schemata nebeneinander, ohne die Option
-- zu aendern. Anders als useScheme vergisst das keine fertigen Bloecke; was
-- fn baut, darf darum nicht in den Speicher (TF.Tooltip.preview tut das nicht).
-- @return der erste Rueckgabewert von fn, nil bei einem Fehler
function TF.fmt.withScheme(name, fn)
    local scheme = SCHEMES[name] or SCHEMES.standard
    local saved = {}
    for _, key in ipairs({ "good", "bad", "stale" }) do
        saved[key] = { TF.fmt.palette[key], TF.fmt.rgb[key] }
        TF.fmt.palette[key] = scheme.rich[key]
        TF.fmt.rgb[key] = scheme.rgb[key]
    end
    local ok, result = pcall(fn)
    for key, pair in pairs(saved) do
        TF.fmt.palette[key], TF.fmt.rgb[key] = pair[1], pair[2]
    end
    if not ok then
        TF.warnOnce("err:withScheme", "withScheme fehlgeschlagen: " .. tostring(result))
        return nil
    end
    return result
end

--- Hoechstmasse der Tooltip-Spalten, in Pixeln bei der kleinen Schrift.
--
-- Dieselben drei Spalten wie die Uebersicht, nur enger. Der Wert behaelt
-- seine 110: "92 % auf 94 %" braucht die Breite, und ein umgebrochener Wert
-- zerreisst die Flucht der Zahlen. Bezeichnung 230 statt 300, Fussnote 220.
-- Zusammen 584 px: der Tooltip schwebt neben der Trait-Liste, und breiter
-- liest er sich nicht mehr als Tooltip. Die dritte Spalte ist die Fussnote
-- allein; eine Quellenspalte braucht es nicht, der Tooltip gehoert genau
-- einem Trait.
--
-- Das sind Obergrenzen, keine festen Spaltenanfaenge. Wert- und
-- Bezeichnungsspalte sind je Block so breit wie ihr breitester Inhalt
-- (TF.Tooltip.columns): Crafty hat eine einzige Zeile "+30%  XP gain", und
-- mit festen Anfaengen stand seine Fussnote 240 px weiter rechts im Leeren.
TF.Tooltip.LAYOUT = { value = 110, label = 230, note = 220, gap = 12 }

--- Die Schrift des Tooltips.
--
-- Der Spieler kann sie in den Optionen auf Medium oder Large stellen
-- (Vanilla ISToolTip.GetFont). Gemessen wird dann in dieser Schrift, und die
-- Spalten wachsen im selben Verhaeltnis mit; sonst liefe der Text bei
-- grosser Schrift quer durch die Nachbarspalte.
local function tooltipFont()
    if ISToolTip and type(ISToolTip.GetFont) == "function" then
        local ok, font = pcall(ISToolTip.GetFont)
        if ok and font then return font end
    end
    return UIFont and UIFont.NewSmall or nil
end

--- Verhaeltnis der Tooltip-Schrift zur Referenzhoehe der Masse.
--
-- Nicht zur aktuellen kleinen Schrift: stellt der Spieler die Schriftgroesse
-- global hoeher, wachsen beide, und das Verhaeltnis bliebe 1, waehrend die
-- Texte breiter werden (siehe TF.fmt.REFERENCE_HEIGHT).
local function fontScale(font)
    return TF.fmt.uiScale(font)
end

--- Die drei Spalten eines Blocks.
--
-- @param scale       Verhaeltnis der Tooltip-Schrift zur kleinen Schrift
-- @param valueWidth  Breite, die der breiteste Wert braucht (mit
--                    Sicherheitsabstand); nil = Hoechstmass
-- @param labelWidth  dasselbe fuer die Bezeichnungen
-- @return table  { value = { x, width }, label = { x, width }, note = { x, width } }
--
-- Eine Spalte ist so breit wie ihr Inhalt, hoechstens so breit wie LAYOUT
-- erlaubt; erst darueber bricht der Inhalt um. Die Fussnote hat keine rechte
-- Nachbarin, ihre Breite ist nur die Umbruchgrenze.
function TF.Tooltip.columns(scale, valueWidth, labelWidth)
    scale = scale or 1
    local l = TF.Tooltip.LAYOUT
    local function px(n) return math.floor(n * scale + 0.5) end
    -- Ganze Pixel: <SETX:> bekommt die Zahl als Text, und die Messung kann
    -- bei skalierter Schrift Nachkommastellen liefern.
    local value = math.floor(math.min(px(l.value), valueWidth or px(l.value)))
    local label = math.floor(math.min(px(l.label), labelWidth or px(l.label)))
    local gap = px(l.gap)
    return {
        value = { x = 0, width = value },
        label = { x = value + gap, width = label },
        note  = { x = value + gap + label + gap, width = px(l.note) },
    }
end

--- Eine Zeile in Spalten: Wert | Bezeichnung | Fussnote.
-- @param zeile  { vorn, farbe, label, tag, note, noteColor, noteRuns };
--               noteRuns ersetzt note, wenn die Fussnote zwei Farben hat
local function row(spalten, font, zeile)
    local label = { text = zeile.label, color = "label",
                    x = spalten.label.x, width = spalten.label.width }
    if zeile.tag then
        -- Kuerzel des Pakets hinter der Bezeichnung, in der Farbe seines
        -- Pakets (Spec 6.3; Mod-Farben seit 14.09.2026).
        label = { runs = { { text = zeile.label, color = "label" },
                           { text = zeile.tag, color = TF.fmt.tagKey(zeile.tag) } },
                  x = spalten.label.x, width = spalten.label.width }
    end
    local note = { text = zeile.note or "", color = zeile.noteColor or "note",
                   x = spalten.note.x, width = spalten.note.width }
    if zeile.noteRuns then
        note = { runs = zeile.noteRuns, x = spalten.note.x, width = spalten.note.width }
    end
    return TF.fmt.columns({
        { text = zeile.vorn, color = zeile.farbe, align = "right",
          x = spalten.value.x, width = spalten.value.width },
        label,
        note,
    }, nil, font)
end

--- Setzt die gesammelten Zeilen, mit Spalten so breit wie ihr Inhalt.
--
-- Die Breite kommt vom breitesten Wert und der breitesten Bezeichnung des
-- Blocks, plus dem Sicherheitsabstand, den TF.fmt.columns beim Umbruch
-- wieder abzieht: so bricht nichts um, was in das Hoechstmass passt.
local function setRows(zeilen, font)
    local valueWidth, labelWidth = 0, 0
    for _, zeile in ipairs(zeilen) do
        valueWidth = math.max(valueWidth, TF.fmt.measure(zeile.vorn, font))
        labelWidth = math.max(labelWidth, TF.fmt.measure(zeile.label
            .. (zeile.tag and (" " .. zeile.tag) or ""), font))
    end
    local spalten = TF.Tooltip.columns(fontScale(font),
        valueWidth + TF.fmt.SAFETY, labelWidth + TF.fmt.SAFETY)
    local lines = {}
    for _, zeile in ipairs(zeilen) do
        lines[#lines + 1] = row(spalten, font, zeile)
    end
    return lines
end

--- Wert und Farbe eines Eintrags, ueber dieselbe Logik wie die Uebersicht.
-- Defensiv: laedt TF_Summary nicht, bleibt der Wert wenigstens grau.
local function valueCell(entry, shown)
    if TF.Summary and TF.Summary.valueCell then
        return TF.Summary.valueCell(entry.text, entry.kind, entry.value, shown)
    end
    return shown or "", "value"
end

--- Fertige Bloecke je Trait und Schrift.
--
-- Vanilla baut die Trait-Listen bei jedem Klick auf einen Trait neu
-- (repopulateTraitLists), mit frischen Eintraegen, also ohne unseren Block.
-- Jeder Block misst seine Zellen ueber MeasureStringX in Java, fuer alle 75
-- Traits rund 2200 Aufrufe je Aufbau. Der Block eines Traits aendert sich
-- waehrend der Charaktererstellung aber nicht: Daten, Uebersetzung und
-- Live-Werte stehen fest, nur eine neue Messung (TF.Probe.run) oder eine
-- andere Tooltip-Schrift ergibt einen anderen Block. Beides ist der
-- Schluessel beziehungsweise leert den Speicher.
local cache = {}

--- Vergisst alle fertigen Bloecke; TF.Probe.run ruft das vor jeder Messung.
function TF.Tooltip.forget()
    cache = {}
    -- Dieselben Grundlagen tragen den Suchtext (TF_Search).
    if TF.Search and TF.Search.forget then TF.Search.forget() end
end

--- Eine Kopfzeile "<Kuerzel> <Name>": das Kuerzel in der Farbe seines Mods,
-- der Name in der Quellenfarbe wie jeder Trait- und Mod-Name. Der Name kommt
-- aus einem fremden Mod oder Paket, darum maskiert (TF.fmt.plain).
local function tagLine(tag, name)
    return TF.fmt.paint(TF.fmt.palette, TF.fmt.tagKey(tag)) .. tag
        .. COLOR_SOURCE .. " <SPACE> " .. TF.fmt.plain(name)
end

--- Die Zeile eines liefernden Pakets, leise: woher die Werte kommen. Bei
-- einem veralteten Paket in Orange, fuer welche Fassung sie geschrieben sind
-- und welche installiert ist.
--
-- @param multiple  mehr als ein Paket traegt zu diesem Trait bei (mehrere
--                  Pakete desselben Mods, oder mehrere Pakete am selben
--                  Kuerzel eines Vanilla-Traits). Dann nennt eine veraltete
--                  Zeile zusaetzlich ihre Quelle: sonst war nicht zu
--                  unterscheiden, welches der mehreren Pakete veraltet ist
--                  (Review 15.09.2026). Mit nur einem Paket bleibt die kurze
--                  Zeile, wie bisher.
local function packageLine(info, multiple)
    -- Quelle und Fassungen schreibt ein fremdes Paket: maskiert wie in tagLine.
    local source = TF.fmt.plain(info.source)
    local version, installed = TF.fmt.plain(info.version), TF.fmt.plain(info.installed)
    if info.stale then
        -- Aus der Palette, nicht COLOR_STALE: die Farbe folgt dem Schema.
        local stale = TF.fmt.palette.stale
        if multiple then
            return stale .. TF.fmt.text("UI_TF_ext_stalepkg_named", source, version, installed)
        end
        return stale .. TF.fmt.text("UI_TF_ext_stalepkg", version, installed)
    end
    if info.version then
        return COLOR_NOTE .. TF.fmt.text("UI_TF_ext_valuesfrom", source, version)
    end
    return COLOR_NOTE .. TF.fmt.text("UI_TF_ext_valuesfrom_nover", source)
end

--- Eine Anzeige-Option: aus `view`, wenn dort gesetzt, sonst aus TF_Options;
-- ohne TF_Options an.
local function viewFlag(view, field, getter)
    if view and view[field] ~= nil then return view[field] == true end
    local get = TF.Options and TF.Options[getter]
    return not get or get() == true
end

--- Der Block eines Traits, Aufbau "A+" (Entscheidung 14.09.2026, Mockup
-- docs/mockups/tooltip-fremde-traits-2026-09-14.html): eine Leerzeile statt
-- des frueheren Kopfs "Trait Facts", kein Stempel "verified for build".
-- Oben steht alles zur Herkunft: bei einem fremden Trait sein Mod mit
-- Kuerzel, darunter je lieferndem Paket eine Zeile oder der Hinweis, dass
-- keines hinterlegt ist; danach die Kuerzel anderer Herkunft (Paketkuerzel
-- an einem Vanilla-Trait, fremde Traits aus den Beziehungen) mit ihrem
-- Namen. Dann die Wertzeilen, zuletzt die Beziehungen als Liste. Eine
-- Schluesselzeile unter dem Block gibt es nicht mehr: sie wiederholte, was
-- jetzt oben steht.
--
-- Eine Warnung bei abweichendem Spiel-Build gab es nie (der Stempel nannte
-- nur TF.DATA_BUILD); es faellt also keine weg.
--
-- `view` (optional) setzt die Anzeige-Optionen fuer diesen einen Aufbau,
-- statt sie aus TF_Options zu lesen: { dead, excludes, ghost }. Nur die
-- Vorschau am "i" der Optionen braucht das (TF.Tooltip.preview); `ghost`
-- zeigt dort, wo ein Abschnitt ausgeblendet ist, seinen Namen leise.
local function build(traitDef, key, font, view)
    -- Erst sammeln, dann setzen: die Spaltenbreiten haengen von allen
    -- Zeilen des Blocks ab.
    local zeilen = {}

    -- Zuerst die hinterlegten und die Paketwerte: das sind die eigentlichen
    -- Auswirkungen. Danach die live gelesenen: Ausschluesse, Rezepte,
    -- Foraging - Umfeld. TF.Mods.entriesFor liefert fuer base dieselbe Liste
    -- wie TF.staticFor, dazu die Zeilen fremder Pakete.
    local entries = TF.Mods and TF.Mods.entriesFor and TF.Mods.entriesFor(traitDef)
        or TF.staticFor(traitDef)
    local mod = TF.Mods and TF.Mods.traitMod and TF.Mods.traitMod(traitDef) or nil
    -- Kuerzel anderer Herkunft, die oben eine eigene Zeile bekommen, in der
    -- Reihenfolge ihres ersten Auftretens: je Kuerzel der Name und, fuer ein
    -- Paketkuerzel, die liefernden Pakete (fuer den Hinweis "veraltet").
    --
    -- tagPkg haelt eine Liste, kein einzelnes Paket: benutzen zwei Pakete
    -- desselben Mods dasselbe Kuerzel an einem Vanilla-Trait (geteiltes
    -- Kuerzel), und nur das zweite ist veraltet, hielte ein einzelner Wert
    -- nur das zuerst gesehene Paket fest - die Staleness des zweiten ginge
    -- stillschweigend unter (Review 15.09.2026).
    local tags, tagOrder, tagPkg = {}, {}, {}
    local function useTag(tag, name, info)
        if not tag then return end
        if not tags[tag] then tags[tag] = name tagOrder[#tagOrder + 1] = tag end
        if info then
            tagPkg[tag] = tagPkg[tag] or {}
            local schon = false
            for _, bekannt in ipairs(tagPkg[tag]) do
                if bekannt == info then schon = true break end
            end
            if not schon then tagPkg[tag][#tagPkg[tag] + 1] = info end
        end
    end
    -- Die liefernden Pakete, in der Reihenfolge ihrer ersten Zeile.
    local packages, seenPkg = {}, {}
    for _, entry in ipairs(entries) do
        -- Gibt es eine Messung, gilt sie. Weicht sie vom hinterlegten Wert ab,
        -- wird die Zeile sichtbar markiert: nach einem Patch soll die Mod nicht
        -- still falsch sein, sondern auffallen. Nur bei hinterlegten Werten:
        -- eine Paketzeile hat keine Messung.
        local record = (entry.origin ~= "package") and TF.Probe and TF.Probe.get and TF.Probe.get(key, entry.id)
        local shown, stale = entry, false
        if record and record.value ~= nil then
            if record.status == TF.STATUS.STALE then stale = true end
            -- Flache Kopie mit dem gemessenen Wert; die Vorlage bleibt heil.
            shown = {}
            for field, value in pairs(entry) do shown[field] = value end
            shown.value = record.value
        end

        local teile = TF.fmt.parts(shown)
        if teile then
            local vorn, farbe = valueCell(shown, teile.value)
            local note, noteColor, noteRuns = teile.note, "note", nil
            -- Wirkungslos (siehe TF.fmt.parts): die Zahl steht in der leisen
            -- Farbe der Fussnote, nicht gruen oder rot - sie tut ja nichts.
            if teile.dead then farbe = "note" end
            if stale then
                -- Der Hinweis verdraengt Fussnote und Randbemerkung des
                -- Eintrags: die Abweichung ist wichtiger. Wert und Hinweis
                -- stehen orange, die Bezeichnung bleibt weiss, damit die
                -- Zeile im Block nicht aus der Reihe faellt.
                farbe, note, noteColor = "stale", TF.fmt.text("UI_TF_stale"), "stale"
            end
            local tag = nil
            if entry.origin == "package" and entry.pkg then
                local info = entry.pkg
                if not seenPkg[info] then
                    seenPkg[info] = true
                    packages[#packages + 1] = info
                end
                if info.stale then
                    -- Ein veraltetes Paket: jede Zeile sagt nur kurz
                    -- "moeglicherweise veraltet", Fassung und installierte
                    -- Fassung stehen einmal oben (Layout A+). Die eigene
                    -- Fussnote der Zeile bleibt leise dahinter stehen, wie im
                    -- Mockup ("may be outdated; example value").
                    farbe = "stale"
                    local short = TF.fmt.text("UI_TF_ext_stale_short")
                    if note then
                        noteRuns = { { text = short .. ";", color = "stale" }, { text = note, color = "note" } }
                    else
                        note, noteColor = short, "stale"
                    end
                end
                -- Bei einem fremden Trait nennt die Mod-Zeile oben das Paket;
                -- nur eine Paketzeile an einem Vanilla-Trait traegt ihr Kuerzel.
                if not mod then
                    tag = info.tag
                    useTag(tag, info.source, info)
                end
            end
            zeilen[#zeilen + 1] = { vorn = vorn, farbe = farbe, label = teile.label,
                                    tag = tag, note = note, noteColor = noteColor, noteRuns = noteRuns,
                                    dead = teile.dead }
        end
    end

    -- Defensiv: laedt TF_Live nicht, bleiben wenigstens die hinterlegten Werte.
    local hasLive = TF.Live and TF.Live.entries and TF.Live.relations
    if hasLive then
        for _, entry in ipairs(TF.Live.entries(traitDef)) do
            local teile = TF.fmt.parts(entry)
            if teile then
                local vorn, farbe = valueCell(entry, teile.value)
                zeilen[#zeilen + 1] = { vorn = vorn, farbe = farbe, label = teile.label,
                                        note = teile.note }
            end
        end
        -- Die Fundchancen je Kategorie: Wert vorn, die Kategorien als
        -- Fussnote. Mehr Chance ist immer besser, die Farbe folgt dem
        -- Vorzeichen.
        for _, spot in ipairs(TF.Live.spotting and TF.Live.spotting(traitDef) or {}) do
            zeilen[#zeilen + 1] = { vorn = spot.text,
                                    farbe = (spot.value > 0) and "good" or "bad",
                                    label = TF.fmt.text("UI_TF_live_spotting"),
                                    note = spot.categories }
        end
    end
    -- Wirkungslose Zeilen ans Ende, abgesetzt mit eigener Ueberschrift
    -- (Entscheidung 19.09.2026, Mockup tooltip-wirkungslos-2026-09-19,
    -- Variante B). Bis 0.8.1 standen sie in der Reihenfolge der Daten
    -- zwischen den Werten, die wirken; nur die graue Zahl verriet sie. Ein
    -- setRows fuer alle, damit die Spalten ueber den ganzen Block gleich stehen.
    local aktiv, tot = {}, {}
    for _, zeile in ipairs(zeilen) do
        if zeile.dead then tot[#tot + 1] = zeile else aktiv[#aktiv + 1] = zeile end
    end
    local sortiert = {}
    for _, zeile in ipairs(aktiv) do sortiert[#sortiert + 1] = zeile end
    for _, zeile in ipairs(tot) do sortiert[#sortiert + 1] = zeile end
    local gesetzt = setRows(sortiert, font)
    local lines, deadLines = {}, {}
    -- Die Mod-Option (seit 0.9.0) nimmt den Abschnitt ganz heraus. Die Zeilen
    -- laufen trotzdem durch setRows: die Spalten stehen dann gleich, egal ob
    -- er gezeigt wird.
    local showDead = viewFlag(view, "dead", "showDead")
    for i, line in ipairs(gesetzt) do
        if i <= #aktiv then
            lines[#lines + 1] = line
        elseif showDead then
            deadLines[#deadLines + 1] = line
        end
    end
    -- Die Vorschau am "i" der Optionen (TF_OptionInfo) zeigt an der Stelle
    -- des ausgeblendeten Abschnitts seinen Namen, leise: dort fehlt etwas.
    local deadGhost = view and view.ghost and not showDead and #tot > 0
    -- Die Beziehungen melden die Kuerzel fremder Traits in der Reihenfolge,
    -- in der sie unten stehen; sie kommen nach denen der Paketzeilen. Ohne
    -- die Liste "Excludes" (Mod-Option) fallen auch deren Kuerzel weg.
    local excludesMode = nil
    if not viewFlag(view, "excludes", "showExcludes") then
        excludesMode = (view and view.ghost) and "ghost" or "hide"
    end
    local relations = hasLive
        and TF.Live.relations(traitDef, function(tag, name) useTag(tag, name) end, font, excludesMode) or {}

    -- Oben, was die Herkunft sagt (siehe Kopf dieser Funktion).
    local top = {}
    if mod then
        top[#top + 1] = tagLine(mod.tag, mod.name)
        local mehrerePakete = #packages > 1
        for _, info in ipairs(packages) do top[#top + 1] = packageLine(info, mehrerePakete) end
        if #packages == 0 then
            -- Fremder Trait ohne Paketzeilen: der Block entsteht immer. Stehen
            -- live gelesene Werte darunter, sagt der Hinweis das; sonst gilt
            -- die Beschreibung des Mods.
            top[#top + 1] = COLOR_NOTE .. TF.fmt.text((#zeilen > 0) and "UI_TF_ext_nopackage_live"
                or "UI_TF_ext_nopackage")
        end
    end
    for _, tag in ipairs(tagOrder) do
        -- Das eigene Kuerzel nennt die Mod-Zeile schon.
        if not (mod and tag == mod.tag) then
            top[#top + 1] = tagLine(tag, tags[tag])
            local infos = tagPkg[tag]
            if infos then
                -- Mehr als ein Paket am selben Kuerzel: eine veraltete Zeile
                -- nennt dann ihre Quelle, sonst waere nicht zu unterscheiden,
                -- welches der Pakete gemeint ist.
                local mehrere = #infos > 1
                for _, info in ipairs(infos) do
                    if info.stale then top[#top + 1] = packageLine(info, mehrere) end
                end
            end
        end
    end

    if #lines == 0 and #deadLines == 0 and #relations == 0 and #top == 0 and not deadGhost then return nil end

    -- Die Leerzeile vorn trennt den Block von der Vanilla-Beschreibung; die
    -- Kopfzeilen stehen ohne Luecke ueber den Wertzeilen, wie im Mockup.
    local body = {}
    for _, line in ipairs(top) do body[#body + 1] = line end
    for _, line in ipairs(lines) do body[#body + 1] = line end
    local block = GAP .. table.concat(body, NL)
    -- Eine Leerzeile vor jedem weiteren Abschnitt, aber nur, wenn darueber
    -- schon etwas steht: sonst klafften zwei Luecken uebereinander.
    local filled = #body > 0
    if #deadLines > 0 then
        local head = TF.fmt.join({ { text = TF.fmt.text("UI_TF_tip_nodead") .. ":", color = "note" } })
        block = block .. (filled and GAP or "") .. head .. NL .. table.concat(deadLines, NL)
        filled = true
    elseif deadGhost then
        block = block .. (filled and GAP or "") .. TF.fmt.join({ { text = TF.fmt.text("UI_TF_tip_nodead"), color = "ghost" } })
        filled = true
    end
    if #relations > 0 then
        block = block .. (filled and GAP or "") .. table.concat(relations, NL)
    end
    return block
end

-- Passt der Block nicht in die Hoehe des Bildschirms, eine Schrift kleiner
-- (seit 0.13.1, Entscheidung 21.09.2026, Variante A). Mit Tooltip-Schrift
-- Large waren sechs Tooltips von More Traits hoeher als 1080 px, und unten
-- fehlte ein Stueck. Die Vanilla-Beschreibung darueber bleibt, wie sie ist;
-- nur der eigene Block wechselt die Groesse, ueber <SIZE:...> des Rich Texts
-- (ISRichTextPanel: small, medium, large). Die meisten spielen mit kleiner
-- Tooltip-Schrift; dort greift das nie.
local function smallerFont(font)
    if not UIFont then return nil end
    if UIFont.Large and font == UIFont.Large then return UIFont.Medium, " <SIZE:medium> " end
    if UIFont.Medium and font == UIFont.Medium then return UIFont.NewSmall or UIFont.Small, " <SIZE:small> " end
    return nil
end

--- Grobe Hoehe eines Blocks: eine Zeile je <LINE>, zwei je <BR>. Umbrueche
-- in langen Fussnoten zaehlt das nicht; die Grenze laesst dafuer Luft.
local function blockHeight(block, font)
    local _, lines = string.gsub(block, "<LINE>", "")
    local _, gaps = string.gsub(block, "<BR>", "")
    local manager = getTextManager and getTextManager()
    local lh = (manager and manager.getFontHeight and manager:getFontHeight(font)) or TF.fmt.REFERENCE_HEIGHT or 19
    return (lines + 2 * gaps + 1) * lh
end

--- Der Block, notfalls in kleinerer Schrift. Drei Viertel der Bildschirmhoehe
-- bleiben ihm; der Rest gehoert der Vanilla-Beschreibung und dem Rand.
local function fitHeight(traitDef, key, block, font, screenH)
    if not block or not screenH then return block end
    local limit = screenH * 0.75
    local tag = nil
    while blockHeight(block, font) > limit do
        local smaller, smallerTag = smallerFont(font)
        if not smaller then break end
        local rebuilt = build(traitDef, key, smaller)
        if not rebuilt then break end
        block, font, tag = rebuilt, smaller, smallerTag
    end
    if not tag then return block end
    -- Hinter die Leerzeile, die den Block von der Beschreibung trennt:
    -- TF.stripLeadingGap erkennt sie nur am Anfang.
    if block:sub(1, #GAP) == GAP then return GAP .. tag .. block:sub(#GAP + 1) end
    return tag .. block
end

--- Baut den Zusatzblock fuer einen Trait.
-- @param traitDef CharacterTraitDefinition
-- @return string|nil  nil, wenn es zu diesem Trait nichts zu zeigen gibt
function TF.buildBlock(traitDef)
    local key = TF.traitKey(traitDef)
    if not key then return nil end
    -- Das Farbschema aus den Mod-Optionen vor dem Blick in den Speicher: ein
    -- Wechsel leert ihn (TF.fmt.useScheme).
    if TF.Options and TF.Options.sync then TF.safe("options:sync", TF.Options.sync) end
    -- Neu angemeldete Pakete zuerst lesen, vor dem Blick in den Speicher
    -- (Spec 4.2: bei jedem Aufbau). Kommt etwas dazu, leert drain den
    -- Speicher ueber TF.Tooltip.forget, und der alte Block wird nicht mehr
    -- gefunden. Vorher las nur ein Speicher-Fehlgriff die Warteschlange, und
    -- ein spaet angemeldetes Paket blieb unsichtbar (Abschlussreview
    -- 14.09.2026, Fund 5).
    if TF.Mods and TF.Mods.drain then TF.Mods.drain() end

    local font = tooltipFont()
    local screenH = nil
    pcall(function() screenH = getCore():getScreenHeight() end)
    -- Die volle ID im Speicherschluessel: sonst teilen sich "base:resilient"
    -- und "xyz:resilient" den Speicher, und der zuerst gebaute Block gilt
    -- fuer beide. Die Bildschirmhoehe gehoert dazu, weil fitHeight an ihr
    -- entscheidet, ob der Block kleiner wird.
    local cacheKey = (TF.traitId(traitDef) or key) .. "|" .. tostring(font) .. "|" .. tostring(screenH)
    local known = cache[cacheKey]
    if known ~= nil then
        -- false steht fuer "nichts zu zeigen", damit auch das nicht jedes
        -- Mal neu gesucht wird.
        return known or nil
    end
    local block = fitHeight(traitDef, key, build(traitDef, key, font), font, screenH)
    cache[cacheKey] = block or false
    return block
end

--- Der Anzeigename eines Traits; ohne ihn der Schluessel.
local function labelOf(traitDef)
    local ok, label = pcall(function() return traitDef:getLabel() end)
    if ok and label and tostring(label) ~= "" then return tostring(label) end
    return TF.traitKey(traitDef) or "?"
end

--- Der Tooltip eines Traits, wie er mit bestimmten Optionen aussaehe: fuer
-- die Vorschau am "i" der Optionen (TF_OptionInfo, Entscheidung 19.09.2026,
-- Mockup option-info-2026-09-19). Oben der Name des Traits, darunter der
-- Block. Geht am Speicher vorbei und aendert keine Option.
-- @param view  { scheme, dead, excludes, ghost }; was fehlt, kommt aus TF_Options
-- @return string|nil
function TF.Tooltip.preview(traitDef, view)
    local key = TF.traitKey(traitDef)
    if not key then return nil end
    if TF.Mods and TF.Mods.drain then TF.Mods.drain() end
    local font = tooltipFont()
    local function make() return build(traitDef, key, font, view) end
    local block
    if view and view.scheme then block = TF.fmt.withScheme(view.scheme, make) else block = make() end
    local head = TF.fmt.join({ { text = TF.fmt.plain(labelOf(traitDef)), color = "label" } })
    if not block then return head end
    return head .. NL .. TF.stripLeadingGap(block)
end

--- Einige Wertzeilen mehrerer Traits in einem Farbschema, der Trait-Name als
-- Fussnote: die Vorschau der Farben-Option. Wirkungslose Zeilen zaehlen
-- nicht, sie tragen keine Farbe.
-- @param items   Liste { def = CharacterTraitDefinition, max = Anzahl }
-- @param scheme  "standard" oder "game"
-- @return string
function TF.Tooltip.sampleRows(items, scheme)
    local font = tooltipFont()
    return TF.fmt.withScheme(scheme, function()
        local zeilen = {}
        for _, item in ipairs(items) do
            local entries = TF.Mods and TF.Mods.entriesFor and TF.Mods.entriesFor(item.def)
                or TF.staticFor(item.def)
            local name, taken = labelOf(item.def), 0
            for _, entry in ipairs(entries or {}) do
                if taken >= item.max then break end
                local teile = TF.fmt.parts(entry)
                if teile and not teile.dead then
                    local vorn, farbe = valueCell(entry, teile.value)
                    zeilen[#zeilen + 1] = { vorn = vorn, farbe = farbe, label = teile.label,
                                            note = name, noteColor = "source" }
                    taken = taken + 1
                end
            end
        end
        return table.concat(setRows(zeilen, font), NL)
    end)
end
