--- Trait Facts - die Startskill-Liste.
--
-- Vanilla zeigt in dieser Liste rechts "+ 75%", "+ 100%" oder "+ 125%". Diese
-- Zahlen stehen in keinem Verhaeltnis zu dem, was die Engine rechnet.
--
-- IsoGameCharacter$XP.AddXP, Build 42.20.4, sinngemaess: der Faktor ist bei
-- Boost-Stufe 1 gleich 1.0, bei Stufe 2 gleich 1.33 und bei Stufe 3 gleich
-- 1.66 (Stufe 2 und 3 nur, wenn der Skill nicht von der Erhoehung
-- ausgenommen ist); ein Skill ohne jeden Boost bekommt am Ende 0.25, sofern
-- er nicht von der Absenkung ausgenommen ist.
--
-- Entscheidend ist der letzte Schritt: ein Skill **ohne** Boost laeuft auf 0.25.
-- Der Boost hebt also nicht von 1.0 aus an, sondern von einem Viertel. Relativ
-- zu einem Skill ohne Boost lernt man mit
--
--     Stufe 1: 1.00 / 0.25 = 4.00x
--     Stufe 2: 1.33 / 0.25 = 5.32x
--     Stufe 3: 1.66 / 0.25 = 6.64x
--
-- Zwei Ausnahmen, beide aus den Ausschlusslisten der Engine:
--   isSkillExcludedFromSpeedReduction = Sprinting, Fitness, Strength
--   isSkillExcludedFromSpeedIncrease  = Fitness, Strength
-- Fitness und Strength stehen in beiden und bleiben deshalb immer auf 1.0.
-- Sprinting entgeht nur der Senkung: ohne Boost 1.0, mit Stufe 1 dann 1.25.
--
-- Jeder Eintrag bekommt einen Tooltip mit der Leiter - die Listbox ist eine
-- gewoehnliche ISScrollingListBox und bringt die Mechanik dafuer mit.
--
-- Seit 0.1.16 zeichnet Trait Facts die Zeilen auch selbst (Entscheidung
-- 12.09.2026, Mockup major-skills, Variante A mit Pfeilen): Stufe vorn und
-- farbig, Skill weiss, Herkunft lila, Boost-Stufe als drei Pfeile, Lerntempo
-- grau, Streifen wie in der Uebersicht. Nicht Vanillas Zeichencode kopiert,
-- sondern eigener; die Listbox selbst (Scrollen, Tooltips, Controller) bleibt
-- Vanillas. Wirft das eigene Zeichnen, zeichnet Vanilla weiter.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF._orig = TF._orig or {}

local NL = " <LINE> "
-- Die Zeilenfarben kommen aus TF.fmt.palette (gesetzt in TF_Tooltip), damit
-- dieser Tooltip dieselbe Hierarchie hat wie der der Trait-Liste. Einen Kopf
-- "Trait Facts" mit Build-Stempel hat er seit Layout A+ nicht mehr
-- (Entscheidung 14.09.2026, Mockup tooltip-fremde-traits).

-- Die Leiter aus AddXP, Boost-Stufe -> Multiplikator.
--
-- Am 10.09.2026 an einer lebenden Figur gemessen (tools/measure-mod, dritter
-- Lauf): 20 XP an Woodwork wurden bei Boost 0/1/2/3 zu 5.0 / 20.0 / 26.6 /
-- 33.2, also genau diese vier Faktoren. Fast Learner x1.300, Slow Learner
-- x0.700; Strength blieb in allen Faellen bei x1.0, Sprinting ohne Boost bei
-- x1.0 und mit Fast Learner bei x1.3, mit Slow Learner unveraendert.
--
-- Und im Bytecode (IsoGameCharacter$XP.AddXP, 42.20.4, am 12.09.2026 gegen
-- die Behauptung "1.0 / 1.25 / 1.5" nachgesehen): Boost 2 -> `ldc 1.33`
-- (Offset 438), Boost >= 3 -> `ldc 1.66` (Offset 482), beide nur ohne
-- isSkillExcludedFromSpeedIncrease; ohne Boost `ldc 0.25` (Offset 507).
-- Vanillas "+ 75/100/125 %" in derselben Liste passt zu keiner der beiden.
local LADDER = { [0] = 0.25, [1] = 1.0, [2] = 1.33, [3] = 1.66 }

--- Multiplikator eines Skills ohne jeden Boost.
local NO_BOOST = 0.25

--- Startlevel, das Fitness und Strength ohne jeden Bonus haben.
-- checkXPBoost addiert +5, genau wie applyTraits in der Engine.
local PASSIVE_BASE = 5

local function isPassive(perk)
    return Perks ~= nil and (perk == Perks.Fitness or perk == Perks.Strength)
end

local function isSprinting(perk)
    return Perks ~= nil and perk == Perks.Sprinting
end

local function intOf(level)
    if type(level) == "number" then return level end
    local ok, value = pcall(function() return level:intValue() end)
    return (ok and type(value) == "number") and value or 0
end

--- Die Schrift des Tooltips (ISToolTip.GetFont, vom Spieler einstellbar);
-- darin wird gemessen, sonst liefe die Quelle bei grosser Schrift in den
-- Wert. Dieselbe Wahl wie TF_Tooltip.
local function tooltipFont()
    if ISToolTip and type(ISToolTip.GetFont) == "function" then
        local ok, font = pcall(ISToolTip.GetFont)
        if ok and font then return font end
    end
    return UIFont and UIFont.NewSmall or nil
end

--- Abstand zwischen Wert und Quelle im Tooltip, in Pixeln bei kleiner Schrift.
local TOOLTIP_GAP = 12

--- Die Rechnung zur Startstufe, als Zeilen in zwei Spalten.
--
-- "Fitness 6" sagt nicht, dass Fitness Instructor +3 und Out of Shape -2
-- darin stecken (Entscheidung 12.09.2026, Mockup major-skills-tooltip,
-- Variante A): je Quelle eine Zeile mit Vorzeichen, Plus gruen, Minus rot,
-- die Quelle lila; bei Fitness und Strength davor die Basis 5, sonst geht
-- die Rechnung nicht auf; darunter die Summe in Weiss. Der Wert steht
-- rechtsbuendig, die Quellen fluchten.
-- @param contributions  Liste von { name, level, tag } aus TF.xpSources;
--                       `tag` ist gesetzt fuer einen fremden Trait und wird
--                       als eigenes Segment in der Farbe seines Mods
--                       angehaengt - nie an den Namen geklebt, sonst stuende
--                       das Kuerzel in der Farbe der Quelle.
local function breakdown(perk, level, contributions)
    local unit = TF.fmt.text("UI_TF_unit_levels")
    local rows = {}
    if isPassive(perk) then
        rows[#rows + 1] = { vorn = TF.fmt.num(PASSIVE_BASE, 0) .. " " .. unit, farbe = "value",
                            text = TF.fmt.text("UI_TF_xp_base_level"), color = "note" }
    end
    for _, c in ipairs(contributions) do
        local n = intOf(c.level)
        if n ~= 0 then
            local row = { vorn = (n > 0 and "+" or "") .. TF.fmt.num(n, 0) .. " " .. unit,
                          farbe = n > 0 and "good" or "bad" }
            if c.tag then
                row.runs = { { text = TF.fmt.plain(c.name), color = "source" },
                             { text = c.tag, color = TF.fmt.tagKey(c.tag) } }
            else
                row.text, row.color = TF.fmt.plain(c.name), "source"
            end
            rows[#rows + 1] = row
        end
    end
    -- Die Stufe bleibt zwischen 0 und 10 (checkXPBoost klemmt). Ohne eigene
    -- Zeile ginge die Rechnung nicht auf: 5 - 4 - 2 stuende als "0 lvl" da
    -- (Audit 12.09.2026).
    local raw = isPassive(perk) and PASSIVE_BASE or 0
    for _, c in ipairs(contributions) do raw = raw + intOf(c.level) end
    if raw ~= level then
        local d = level - raw
        rows[#rows + 1] = { vorn = (d > 0 and "+" or "") .. TF.fmt.num(d, 0) .. " " .. unit,
                            farbe = "note", text = TF.fmt.text("UI_TF_xp_clamp"), color = "note" }
    end
    rows[#rows + 1] = { vorn = TF.fmt.num(level, 0) .. " " .. unit, farbe = "label",
                        text = TF.fmt.text("UI_TF_xp_start"), color = "label" }

    local font = tooltipFont()
    local valueW = 0
    for _, r in ipairs(rows) do valueW = math.max(valueW, TF.fmt.measure(r.vorn, font)) end
    -- Ganze Pixel: <SETX:> bekommt die Zahl als Text. SAFETY zieht
    -- TF.fmt.columns beim Umbruch wieder ab, so bricht der Wert nie um.
    valueW = math.floor(valueW + TF.fmt.SAFETY)
    local gap = math.floor(TOOLTIP_GAP * TF.fmt.uiScale(font) + 0.5)
    local lines = {}
    for _, r in ipairs(rows) do
        local quelle = r.runs and { runs = r.runs, x = valueW + gap }
            or { text = r.text, color = r.color, x = valueW + gap }
        lines[#lines + 1] = TF.fmt.columns({
            { text = r.vorn, color = r.farbe, align = "right", x = 0, width = valueW },
            quelle,
        }, nil, font)
    end
    return lines
end

--- Baut den Tooltip fuer einen Eintrag der Startskill-Liste.
-- @param perk  PerkFactory.Perk
-- @param level Startlevel aus checkXPBoost (0 bis 10)
-- @param contributions  optional, Liste von { name, level }: woher die Stufe
--                       kommt (TF.xpSources); dann steht die Rechnung vorn
-- @return string|nil
function TF.xpTooltip(perk, level, contributions)
    if type(level) ~= "number" then return nil end
    local hasSources = type(contributions) == "table" and #contributions > 0

    local lines = {}

    if isPassive(perk) then
        -- checkXPBoost rechnet fuer Fitness und Strength +5 auf die Summe der
        -- Boni, wie applyTraits in der Engine. Steht dort genau 5 und weiss
        -- niemand von einer Quelle, hat weder Trait noch Beruf etwas
        -- veraendert, und es gibt nichts zu sagen. Mit Quellen (+3 und -3)
        -- lohnt die Rechnung trotzdem.
        --
        -- Bei allem anderen lohnt der Satz: wer Athletic nimmt, sieht Fitness
        -- auf 9 steigen und koennte annehmen, der Skill lerne nun schneller.
        -- Er tut es nicht, Fitness steht in beiden Ausschlusslisten.
        if level == PASSIVE_BASE and not hasSources then return nil end
        if hasSources then
            for _, line in ipairs(breakdown(perk, level, contributions)) do
                lines[#lines + 1] = line
            end
        end
        lines[#lines + 1] = TF.fmt.line(TF.fmt.text("UI_TF_xp_speed"),
            TF.fmt.text("UI_TF_xp_normal"), TF.fmt.text("UI_TF_xp_note_passive"))
    else
        -- Die gespeicherte Boost-Stufe ist auf 3 gedeckelt:
        -- getXPBoostMap().put(perkType, Math.min(3, level))
        local tier = level
        if tier > 3 then tier = 3 end
        if tier < 0 then tier = 0 end

        local mult = LADDER[tier]
        local base = NO_BOOST

        -- Sprinting ist an zwei Stellen ein Sonderfall, aber nur an zweien.
        -- Es steht in isSkillExcludedFromSpeedReduction, laeuft ohne Boost also
        -- auf 1.0 statt 0.25 - das ist der Vergleichswert. Und die Engine hat
        -- eine eigene Regel fuer Stufe 1: Sprinting mit Boost-Stufe 1
        -- bekommt den Faktor 1.25.
        -- Ab Stufe 2 gilt die normale Leiter, denn
        -- isSkillExcludedFromSpeedIncrease fuehrt nur Fitness und Strength.
        if isSprinting(perk) then
            base = 1.0
            if tier == 0 then
                mult = 1.0
            elseif tier == 1 then
                mult = 1.25
            end
        end

        -- Stufe 0 heisst: kein Boost. In der Startskill-Liste taucht ein
        -- solcher Skill normalerweise nicht auf, und falls doch, gaebe es
        -- nichts zu berichten.
        if tier == 0 then return nil end

        if hasSources then
            for _, line in ipairs(breakdown(perk, level, contributions)) do
                lines[#lines + 1] = line
            end
        end
        lines[#lines + 1] = TF.fmt.line(TF.fmt.text("UI_TF_xp_tier"),
            TF.fmt.text("UI_TF_xp_tier_value", tostring(tier)))
        if mult > base then
            -- Der Faktor ist ohne Bezugsgroesse nichts wert, deshalb steht sie
            -- als Fussnote dabei. Sprinting hat eine eigene, weil es der
            -- Senkung entgeht und deshalb von 1.0 aus vergleicht.
            local note = isSprinting(perk) and "UI_TF_xp_note_sprint" or "UI_TF_xp_note_base"
            lines[#lines + 1] = TF.fmt.line(TF.fmt.text("UI_TF_xp_speed"),
                TF.fmt.text("UI_TF_xp_speed_value", TF.fmt.num(mult / base, 2)),
                TF.fmt.text(note))
        end
    end

    if #lines == 0 then return nil end
    -- Ohne Kopf und Build-Stempel (Layout A+): die Rechnung beginnt in der
    -- ersten Zeile. Eine Warnung bei abweichendem Spiel-Build gab es nie,
    -- also faellt hier auch keine weg.
    return table.concat(lines, NL)
end

--- Boost-Stufe und Lerntempo gegenueber einem Skill ohne Boost.
--
-- Dieselbe Rechnung wie in TF.xpTooltip, fuer die Zeile der Liste.
-- @return number, number|nil  Boost-Stufe 0 bis 3, Faktor oder nil, wenn es
--                             nichts zu sagen gibt (Fitness/Strength, kein Boost)
function TF.xpSpeed(perk, level)
    if type(level) ~= "number" or isPassive(perk) then return 0, nil end
    local tier = math.max(0, math.min(3, level))
    if tier == 0 then return 0, nil end
    local mult, base = LADDER[tier], NO_BOOST
    if isSprinting(perk) then
        base = 1.0
        if tier == 1 then mult = 1.25 end
    end
    if mult <= base then return tier, nil end
    return tier, mult / base
end

--- Die Boosts eines Berufs oder Traits als Lua-Tabelle, oder nil.
local function boostsOf(obj)
    local ok, map = pcall(function()
        local raw = obj and obj:getXpBoosts()
        if raw == nil then return nil end
        return transformIntoKahluaTable(raw)
    end)
    if ok and type(map) == "table" then return map end
    return nil
end

--- Woher jeder Skill-Boost kommt: Beruf zuerst, dann die Traits in der
-- Reihenfolge der Auswahl. Dieselben Quellen, die checkXPBoost summiert.
-- @param items       listboxTraitSelected.items (item.item = CharacterTraitDefinition)
-- @param profession  CharacterProfessionDefinition oder nil
-- @return table, table  Perk -> "Blacksmith, Handy TOC" fuer die Zeile der
--                       Liste (das Kuerzel eines fremden Traits steht als
--                       Text mit an, nur zum Messen und Umbrechen); Perk ->
--                       { { name, level, tag }, ... } fuer die Rechnung im
--                       Tooltip und, ueber tag, fuer das Kaestchen der Liste
--                       (TF.drawXpItem) - `tag` bleibt nil fuer Vanilla, nie
--                       aus dem Namen geraten.
function TF.xpSources(items, profession)
    local detail = {}
    local function collect(obj, name, tag)
        if not name or name == "" then return end
        local map = boostsOf(obj)
        if not map then return end
        for perk, level in pairs(map) do
            local n = intOf(level)
            if n ~= 0 then
                detail[perk] = detail[perk] or {}
                -- Doppelt ist nur, was gleich heisst und gleich herkommt (wie
                -- in TF.Summary.merge): die Berufs-Fassung eines Vanilla-
                -- Traits zaehlt einmal, ein gleichnamiger Trait eines Mods
                -- (anderes Kuerzel) bleibt eine eigene Quelle. Bis 0.3.3 fiel
                -- er weg, und die Summe im Tooltip ging nicht auf (Review
                -- 15.09.2026).
                local seen = false
                for _, known in ipairs(detail[perk]) do
                    if known.name == name and known.tag == tag then seen = true break end
                end
                if not seen then
                    table.insert(detail[perk], { name = name, level = n, tag = tag })
                end
            end
        end
    end
    if profession then
        local ok, name = pcall(function() return profession:getUIName() end)
        collect(profession, ok and name and tostring(name) or nil, nil)
    end
    for _, entry in ipairs(items or {}) do
        local def = entry.item
        local ok, name = pcall(function() return def:getLabel() end)
        name = ok and name and tostring(name) or nil
        local mod = name and TF.Mods and TF.Mods.traitMod and TF.Mods.traitMod(def) or nil
        collect(def, name, mod and mod.tag or nil)
    end
    local out = {}
    for perk, list in pairs(detail) do
        local parts = {}
        for _, c in ipairs(list) do
            parts[#parts + 1] = c.tag and (c.name .. " " .. c.tag) or c.name
        end
        out[perk] = table.concat(parts, ", ")
    end
    return out, detail
end

--- Was eine Zeile der Liste zeigt.
-- @return table  { value = "4 lvl", color = Palettenname, tier = 0..3,
--                  note = "6.64x as fast" | nil }
function TF.xpRow(perk, level)
    level = type(level) == "number" and level or 0
    local row = { tier = 0, value = TF.fmt.num(level, 0) .. " " .. TF.fmt.text("UI_TF_unit_levels") }
    if isPassive(perk) then
        -- Fitness und Strength: gemessen an der Grundstufe 5. Darunter rot,
        -- sonst faellt ein Overweight-Build mit Fitness 4 nicht auf. Kein
        -- Tempo-Hinweis: Boosts aendern hier das Lerntempo nicht (Messung
        -- XP-Leiter 12.09.2026), und "base 5" war neben Wert und Herkunft
        -- doppelt (bis 0.1.17).
        row.color = (level > PASSIVE_BASE and "good") or (level < PASSIVE_BASE and "bad") or "value"
    else
        local tier, factor = TF.xpSpeed(perk, level)
        row.tier = tier
        row.color = level > 0 and "good" or "value"
        if factor then row.note = TF.fmt.text("UI_TF_xp_asfast", TF.fmt.num(factor, 2)) end
    end
    return row
end

--- Reihenfolge: Skills mit Boost nach Stufe, bei Gleichstand nach Namen;
-- Fitness und Strength am Ende. Vanilla sortiert nur nach Namen.
function TF.xpSort(items)
    table.sort(items, function(a, b)
        local pa, pb = isPassive(a.item.perk), isPassive(b.item.perk)
        if pa ~= pb then return pb end
        local la, lb = a.item.level or 0, b.item.level or 0
        if la ~= lb then return la > lb end
        return tostring(a.text) < tostring(b.text)
    end)
end

local ARROW_ON = "media/ui/TraitFacts/tf_arrow_on.png"
local ARROW_OFF = "media/ui/TraitFacts/tf_arrow_off.png"
local textures = {}
local function texture(path)
    if textures[path] == nil then
        textures[path] = (getTexture and getTexture(path)) or false
    end
    return textures[path] or nil
end

local function rgb(name)
    local set = TF.fmt.rgb or {}
    return set[name] or set.value or { 1, 1, 1 }
end

local PAD, GAP, SCROLLBAR = 8, 10, 13

--- Die Spalten der Liste: Stufe | Skill | Herkunft | Pfeile | Tempo.
--
-- Jede Spalte hat ein festes x, so breit wie ihr breitester Inhalt. Bis 0.1.16
-- flossen Herkunft, Pfeile und Tempo in einer Zelle hintereinander, und die
-- Pfeile standen bei "Angler" weiter rechts als bei "Chef" (Hinweis
-- 12.09.2026 nach dem ersten Blick im Spiel). Reicht der Platz nicht, gibt
-- die Herkunft nach und bricht in ihrer Spalte um; Pfeile und Tempo bleiben
-- stehen. Wird bei jeder neuen Fuellung (decorateXpBoost) verworfen.
--- Luft je Seite eines Kuerzel-Kaestchens in der Herkunft: TF.fmt.tagBox
-- zieht den Rahmen 2 px links und rechts vom Text. Ohne diese Luft frass
-- der Rahmen 2 px vom Leerzeichen vor dem Kaestchen (es klebte am Namen,
-- anders als in der Uebersicht mit ihrem <SPACE>), und das Komma dahinter
-- stand im rechten Rahmenrand (Wunsch 15.09.2026).
local TAG_PAD = 2

local function columnsFor(list, font)
    -- Gemerkt nur fuer die Breite, fuer die gerechnet wurde: prerender setzt
    -- die Liste in jedem Frame auf ihre echte Breite, und die weicht von der
    -- beim Befuellen ab (create() rechnet mit der vollen Breite; seit 0.3.2
    -- wird Spalte 3 zudem breiter). Ohne den Vergleich blieb die Aufteilung
    -- bis zum naechsten Trait-Wechsel bei der alten Breite stehen.
    if list.tfCols and list.tfCols.width == list.width then return list.tfCols end
    local lineH = list.fontHgt or 19
    local valueW, labelW, sourceW, noteW, arrows = 0, 0, 0, 0, false
    for _, entry in ipairs(list.items or {}) do
        local data = entry.item
        if type(data) == "table" then
            local row = TF.xpRow(data.perk, data.level)
            valueW = math.max(valueW, TF.fmt.measure(row.value, font))
            labelW = math.max(labelW, TF.fmt.measure(tostring(entry.text), font))
            if data.tfSources and data.tfSources ~= "" then
                local tags = 0
                for _, src in ipairs(data.tfSourceList or {}) do
                    if src.tag then tags = tags + 1 end
                end
                sourceW = math.max(sourceW, TF.fmt.measure(data.tfSources, font) + tags * 2 * TAG_PAD)
            end
            if row.note then noteW = math.max(noteW, TF.fmt.measure(row.note, font)) end
            if row.tier > 0 then arrows = true end
        end
    end
    local width = list.width or 0
    local ah = math.floor(lineH * 0.6)
    local step = math.floor(ah * 0.75)
    local space = TF.fmt.measure(" ", font)
    local arrowsW = arrows and (2 * step + ah + space) or 0

    local cols = { ah = ah, step = step }
    cols.valueRight = PAD + valueW
    cols.label = cols.valueRight + GAP
    -- Der Deckel von 30 % gilt nur, soweit die Herkunftsspalte den Platz
    -- braucht: sie bricht um und kommt mit MIN_SOURCE aus. Bis 0.12.7 war der
    -- Deckel fest, der Name wurde aber ungekuerzt gezeichnet; "Metallverarbeitung"
    -- lag in der schmalen Anordnung auf dem ersten Quellennamen (Bugjagd
    -- 20.09.2026). Was dann noch nicht passt, kuerzt TF.drawXpItem.
    local MIN_SOURCE = 80
    local room = width - SCROLLBAR - PAD - cols.label - GAP - arrowsW - noteW
        - (sourceW > 0 and (MIN_SOURCE + GAP) or 0)
    labelW = math.min(labelW, math.max(math.floor(width * 0.3), room))
    cols.labelW = labelW
    cols.source = cols.label + labelW + GAP
    local free = width - SCROLLBAR - PAD - cols.source - arrowsW - noteW
    if sourceW > 0 then
        cols.sourceW = math.max(40, math.min(sourceW, free - GAP))
        cols.arrows = cols.source + cols.sourceW + GAP
    else
        cols.sourceW = 0
        cols.arrows = cols.source
    end
    cols.note = cols.arrows + arrowsW
    cols.width = list.width
    list.tfCols = cols
    return cols
end

--- Zerlegt einen Text an den Leerzeichen (kein string.gmatch in Kahlua).
local function splitWords(text)
    local out, at = {}, 1
    while true do
        local a, b = string.find(text, "[^ ]+", at)
        if not a then break end
        out[#out + 1] = string.sub(text, a, b)
        at = b + 1
    end
    return out
end

--- Die Woerter der Herkunft einer Zeile, jedes mit isTag: true genau fuer
-- das Kuerzel einer Quelle, nie fuer ein Wort, das zufaellig genauso
-- aussieht. Ein Name kann mehrere Woerter haben, ein Kuerzel ist immer eins;
-- das Komma zwischen zwei Quellen haengt am letzten Wort der vorigen (Name
-- oder Kuerzel), wie bisher in "Blacksmith, Handy".
-- @param list  Liste von { name, level, tag } aus TF.xpSources (detail[perk])
local function sourceWords(list)
    local out = {}
    for index, source in ipairs(list or {}) do
        for _, w in ipairs(splitWords(source.name or "")) do
            out[#out + 1] = { text = w, isTag = false }
        end
        if source.tag then
            out[#out + 1] = { text = source.tag, isTag = true }
        end
        if index < #list and #out > 0 then
            out[#out].text = out[#out].text .. ","
        end
    end
    return out
end

--- Fuegt die Woerter zu einer Zeile zusammen, fuer die Positionsrechnung
-- unten (dieselbe Zeile, wie sie TF.fmt.wrap aus einem Text machen wuerde).
local function wordsText(list)
    local parts = {}
    for _, w in ipairs(list) do parts[#parts + 1] = w.text end
    return table.concat(parts, " ")
end

--- Bricht eine Woerterliste auf `width` um, wie TF.fmt.wrap fuer einen Text,
-- aber ohne den Umweg: die isTag-Markierung jedes Worts bleibt erhalten.
local function wrapTagged(list, width, font)
    -- pads: die Luft der Kaestchen in der Zeile (TAG_PAD), die der Text
    -- selbst nicht misst.
    local lines, current, text, pads = {}, {}, "", 0
    for _, w in ipairs(list) do
        local probe = (text == "") and w.text or (text .. " " .. w.text)
        local own = w.isTag and 2 * TAG_PAD or 0
        if TF.fmt.measure(probe, font) + pads + own <= width or #current == 0 then
            current[#current + 1] = w
            text, pads = probe, pads + own
        else
            lines[#lines + 1] = current
            current, text, pads = { w }, w.text, own
        end
    end
    if #current > 0 then lines[#lines + 1] = current end
    return lines
end

--- Zeichnet eine Zeile der Startskill-Liste; doDrawItem der Listbox.
--
-- Stufe rechtsbuendig und farbig, Skill weiss, Herkunft lila, drei Pfeile
-- nach rechts - so viele gruen gefuellt wie die Boost-Stufe, der Rest grau
-- umrandet - und das Lerntempo grau, jedes in seiner Spalte (columnsFor).
-- Bricht die Herkunft um, wird die Zeile hoeher; die Listbox uebernimmt die
-- Hoehe aus dem Rueckgabewert.
-- @return number  y der naechsten Zeile
function TF.drawXpItem(list, y, item, alt)
    local lineH = list.fontHgt or 19
    local data = item.item
    if type(data) ~= "table" then return y + (list.itemheight or lineH) end
    local font = UIFont and UIFont.Small or nil
    local row = TF.xpRow(data.perk, data.level)
    local cols = columnsFor(list, font)

    -- tfSourceList (aus TF.xpSources, detail[perk]) traegt Struktur: welches
    -- Wort ein Kuerzel ist, steht fest, bevor ueberhaupt gezeichnet wird.
    -- Fehlt sie - ein Test setzt tfSources auch direkt, ohne Struktur -,
    -- bleibt jedes Wort schlicht: kein Kuerzel wird aus dem Text geraten.
    local srcLines = {}
    if data.tfSourceList and #data.tfSourceList > 0 then
        srcLines = wrapTagged(sourceWords(data.tfSourceList), cols.sourceW, font)
    elseif data.tfSources and data.tfSources ~= "" then
        for _, line in ipairs(TF.fmt.wrap(data.tfSources, cols.sourceW, font)) do
            local ws = {}
            for _, w in ipairs(splitWords(line)) do ws[#ws + 1] = { text = w, isTag = false } end
            srcLines[#srcLines + 1] = ws
        end
    end
    local height = math.max(1, #srcLines) * lineH + 4
    local top = y + 2

    if alt then list:drawRect(0, y, list.width, height, 0.06, 1, 1, 1) end
    local c = rgb(row.color)
    list:drawTextRight(row.value, cols.valueRight, top, c[1], c[2], c[3], 1, font)
    local l = rgb("label")
    list:drawText(TF.fmt.kuerze(tostring(item.text), cols.labelW or list.width, font), cols.label, top,
        l[1], l[2], l[3], 1, font)
    local s = rgb("source")
    for index, lineWords in ipairs(srcLines) do
        local ly = top + (index - 1) * lineH
        local text = wordsText(lineWords)
        -- pad: die Luft aller Kaestchen links in dieser Zeile; alles hinter
        -- einem Kaestchen rueckt um seine beiden TAG_PAD nach rechts.
        local at, wi, pad = 1, 0, 0
        while true do
            local a, b = string.find(text, "[^ ]+", at)
            if not a then break end
            wi = wi + 1
            local word = string.sub(text, a, b)
            local bare = string.match(word, "^(.-),?$")
            local wx = cols.source + TF.fmt.measure(string.sub(text, 1, a - 1), font) + pad
            local info = lineWords[wi]
            if info and info.isTag then
                local w = TF.fmt.tagBox(list, wx + TAG_PAD, ly, bare, font)
                if bare ~= word then
                    list:drawText(",", wx + TAG_PAD + w + TAG_PAD, ly, s[1], s[2], s[3], 1, font)
                end
                pad = pad + 2 * TAG_PAD
            else
                list:drawText(word, wx, ly, s[1], s[2], s[3], 1, font)
            end
            at = b + 1
        end
    end
    if row.tier > 0 then
        local ay = top + math.floor((lineH - cols.ah) / 2)
        for i = 1, 3 do
            local full = i <= row.tier
            local tex = texture(full and ARROW_ON or ARROW_OFF)
            local tint = rgb(full and "good" or "off")
            if tex then
                list:drawTextureScaled(tex, cols.arrows + (i - 1) * cols.step, ay,
                    cols.ah, cols.ah, 1, tint[1], tint[2], tint[3])
            end
        end
    end
    if row.note then
        local n = rgb("note")
        list:drawText(row.note, cols.note, top, n[1], n[2], n[3], 1, font)
    end
    return y + height
end

--- Haengt Tooltips, Herkunft und das eigene Zeichnen an die Startskill-Liste.
local function decorateXpBoost(self)
    local list = self.listboxXpBoost
    if not list or type(list.items) ~= "table" then return end
    -- Derselbe dunklere Grund wie bei den Trait-Listen (TF_Hooks); mit
    -- Vanillas 0.7 schien die Liste durch die Rechnung.
    if TF.darkenTooltip then TF.darkenTooltip(list) end
    local sources, detail = TF.xpSources(self.listboxTraitSelected and self.listboxTraitSelected.items,
        self.profession)
    for _, item in ipairs(list.items) do
        local data = item.item
        if type(data) == "table" then
            data.tfSources = sources[data.perk]
            -- Struktur fuer das Kaestchen (TF.drawXpItem): welches Wort ein
            -- Kuerzel ist, steht hier schon fest, nicht erst beim Zeichnen.
            data.tfSourceList = detail[data.perk]
            -- Bei jedem Aufruf neu, nicht nur beim ersten: die Quellen
            -- aendern sich mit jeder Trait-Wahl, und der Tooltip rechnet
            -- sie vor (seit 0.1.19).
            item.tooltip = TF.xpTooltip(data.perk, data.level, detail[data.perk])
        end
    end
    TF.xpSort(list.items)
    list.tfCols = nil
    if not list.tfDraws then
        list.tfDraws = true
        -- Wirft das eigene Zeichnen, einmal melden und Vanilla zeichnen lassen;
        -- sonst stuende die Liste leer da, und das in jedem Bild.
        local vanilla = list.doDrawItem
        list.doDrawItem = function(box, y, item, alt)
            local ok, nextY = pcall(TF.drawXpItem, box, y, item, alt)
            if ok and type(nextY) == "number" then return nextY end
            TF.warnOnce("xpdraw", "Startskill-Liste: eigenes Zeichnen fehlgeschlagen ("
                .. tostring(nextY) .. "), Vanilla zeichnet.")
            if vanilla then return vanilla(box, y, item, alt) end
            return y + (box.itemheight or 20)
        end
    end
end

local function install()
    if not CharacterCreationProfession then return end
    if TF._orig.checkXPBoost then return end

    local original = CharacterCreationProfession.checkXPBoost
    if type(original) ~= "function" then
        TF.warn("CharacterCreationProfession.checkXPBoost nicht gefunden, "
            .. "die Startskill-Liste bleibt unveraendert.")
        return
    end

    TF._orig.checkXPBoost = original
    CharacterCreationProfession.checkXPBoost = function(self, ...)
        TF._orig.checkXPBoost(self, ...)
        TF.safe("decorate:checkXPBoost", decorateXpBoost, self)
    end
end

Events.OnGameBoot.Add(function()
    TF.safe("install:xpcolumns", install)
end)
