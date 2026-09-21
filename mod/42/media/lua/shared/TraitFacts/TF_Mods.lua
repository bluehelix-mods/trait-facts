--- Trait Facts - Traits aus anderen Mods: Pakete, Mod-Namen, Kuerzel.
--
-- Ein Paket sind reine Daten, angemeldet ueber die globale Warteschlange
-- TraitFactsAPI.queue. Die legt an, wer zuerst laedt; die Reihenfolge der
-- Mods ist damit egal, und ein fremdes Mod braucht Trait Facts nicht.
-- Verarbeitet wird erst beim ersten Aufbau eines Tooltips oder der
-- Uebersicht (TF.Mods.drain), danach nur, was neu dazukam. Spec:
-- docs/specs/2026-09-14-fremde-traits-design.md, Abschnitte 4-6.
--
-- Dateiname: TF_Mods, nicht TF_Api. Das Spiel laedt shared/ alphabetisch,
-- und TF_Api kaeme vor TF_Core.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Mods = TF.Mods or {}
TF.Mods.FORMAT = 1

--- Die Farben der Kuerzel (Entscheidung 14.09.2026, Mockup
-- docs/mockups/trait-auswahl-mod-farben-2026-09-14.html, Zustand 2): aqua,
-- ocker, pfirsich, mint, koralle; nach fuenf von vorn. Reihenfolge
-- (Nachtrag 14.09.2026, im Mockup ist das Mod TOC aqua): erst die
-- Mod-Kuerzel in der Reihenfolge der aktiven Mod-Liste, dann Kuerzel eines
-- Namensraums ohne aktives Mod, zuletzt die reinen Paket-Kuerzel in der
-- Reihenfolge der Anmeldung (colorRank). Ein geteiltes Kuerzel (Paket-
-- Kuerzel gleich dem seines Mods) gehoert dem Mod. Das Rich-Text-Tag steht
-- fertig daneben: eine Zahl selbst als Text zu setzen, hinge an der
-- Zahlendarstellung der Engine.
TF.Mods.TAG_COLORS = {
    { rgb = { 0.53, 0.83, 0.85 }, rich = " <RGB:0.53,0.83,0.85> " }, -- aqua     #88D3D8
    { rgb = { 0.86, 0.73, 0.42 }, rich = " <RGB:0.86,0.73,0.42> " }, -- ocker    #DBBB6C
    { rgb = { 0.95, 0.79, 0.70 }, rich = " <RGB:0.95,0.79,0.70> " }, -- pfirsich #F2C9B3
    { rgb = { 0.62, 0.97, 0.60 }, rich = " <RGB:0.62,0.97,0.60> " }, -- mint     #9FF799
    { rgb = { 0.89, 0.65, 0.64 }, rich = " <RGB:0.89,0.65,0.64> " }, -- koralle  #E3A7A4
}

TraitFactsAPI = TraitFactsAPI or {}
TraitFactsAPI.queue = TraitFactsAPI.queue or {}
TraitFactsAPI.format = TF.Mods.FORMAT
--- Meldet ein Paket an; gleichwertig zu table.insert(TraitFactsAPI.queue, paket).
function TraitFactsAPI.register(paket)
    TraitFactsAPI.queue[#TraitFactsAPI.queue + 1] = paket
end

local ALLOWED = "pct, mult, flat, count, range, pctrange, fromto, bool, info"

--- Setzt den verarbeiteten Stand zurueck. Nur fuer Tests.
function TF.Mods.reset()
    TF.Mods.done = 0
    TF.Mods.packages = {}
    TF.Mods.rows = {}
    TF.Mods.literal = {}
    TF.Mods.tagOwner = {}
    TF.Mods.modCache = {}
    TF.Mods.tagSlot = {}
    TF.Mods.slots = 0
    TF.Mods.colorRank = nil
    TF.Mods.primed = nil
    -- Verwirft, was die Trait-Listen je Zeile gemerkt haben (TF_Hooks).
    TF.Mods.epoch = (TF.Mods.epoch or 0) + 1
    TraitFactsAPI.queue = {}
end
if TF.Mods.done == nil then
    TF.Mods.done = 0
    TF.Mods.packages = {}
    TF.Mods.rows = {}
    TF.Mods.literal = {}
    TF.Mods.tagOwner = {}
    TF.Mods.modCache = {}
end
-- Laufende Nummer der ersten Belegung je Kuerzel; ordnet die reinen
-- Paket-Kuerzel (Anmeldereihenfolge) und entscheidet Gleichstaende.
-- Eigens vorbelegt: ein Stand ohne sie, etwa nach einem Neuladen der Datei
-- mitten in der Sitzung, soll nicht an nil scheitern.
TF.Mods.tagSlot = TF.Mods.tagSlot or {}
TF.Mods.slots = TF.Mods.slots or 0

local function isText(s) return type(s) == "string" and s ~= "" end

--- Woerter eines Namens (Buchstaben und Ziffern); ohne string.gmatch,
-- das es in Kahlua nicht gibt.
local function words(s)
    local out, at = {}, 1
    while true do
        local a, b = string.find(s, "[%w]+", at)
        if not a then break end
        out[#out + 1] = string.sub(s, a, b)
        at = b + 1
    end
    return out
end

local function initials(name)
    local out = ""
    for _, w in ipairs(words(name or "")) do out = out .. string.sub(w, 1, 1) end
    return out
end

local function activeMods()
    local out = {}
    pcall(function()
        local list = getActivatedMods()
        for i = 0, list:size() - 1 do out[#out + 1] = tostring(list:get(i)) end
    end)
    return out
end

--- Die ID des aktiven Mods zu einer modId, oder nil. Verglichen wird
-- normalisiert wie in modFor ("theonlycure" findet "TheOnlyCure"); zurueck
-- kommt die Schreibweise der Engine, damit getModInfoByID sie findet.
local function activeId(id)
    local want = TF.normalize(id)
    for _, active in ipairs(activeMods()) do
        if TF.normalize(active) == want then return active end
    end
    return nil
end

local function modInfo(id, method)
    local ok, value = pcall(function() return getModInfoByID(id)[method](getModInfoByID(id)) end)
    if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
    return nil
end

--- Kuerzel aus einem Namen: Anfangsbuchstaben der Woerter (hoechstens vier),
-- bei einem Wort dessen erste drei Buchstaben; gross.
function TF.Mods.deriveTag(name)
    local ws = words(name or "")
    if #ws >= 2 then
        local out = ""
        for i = 1, math.min(4, #ws) do out = out .. string.sub(ws[i], 1, 1) end
        return string.upper(out)
    end
    return string.upper(string.sub(ws[1] or "MOD", 1, 3))
end

--- Belegt ein Kuerzel fuer einen Besitzer; bei Kollision ein Buchstabe mehr
-- aus dem letzten Wort, notfalls eine Ziffer.
local function claimTag(base, owner, name)
    local candidates = { base }
    local ws = words(name or "")
    local last = ws[#ws]
    if last and #last > 1 and #base < 4 then
        candidates[#candidates + 1] = base .. string.upper(string.sub(last, 2, 2))
    end
    for n = 2, 9 do candidates[#candidates + 1] = string.sub(base, 1, 3) .. n end
    -- Sind auch die belegt (zehn Besitzer in derselben Familie), zwei Ziffern
    -- hinter den ersten zwei Buchstaben; vier Zeichen bleiben die Grenze.
    for n = 10, 99 do candidates[#candidates + 1] = string.sub(base, 1, 2) .. n end
    for _, tag in ipairs(candidates) do
        local held = TF.Mods.tagOwner[tag]
        if not held or held == owner then
            TF.Mods.tagOwner[tag] = owner
            -- Ein neues Kuerzel: Nummer merken und die Farbreihenfolge neu
            -- rechnen lassen (colorRank). Wer ein Kuerzel erneut belegt
            -- (derselbe Besitzer), aendert nichts.
            --
            -- Ein schon gebauter Tooltip-Block traegt die alte Farbe fest im
            -- Text (Rich-Text-Tag), nicht als Verweis auf colorRank; ohne
            -- TF.Tooltip.forget bliebe er dabei, auch wenn das neue Kuerzel
            -- die Reihenfolge aller anderen verschiebt (Review 15.09.2026).
            -- TF_Mods ist shared und laedt vor TF_Tooltip (client); zur
            -- Laufzeit steht es laengst, deshalb nur die uebliche Absicherung,
            -- kein eigener Ladezeitpunkt-Test.
            if not TF.Mods.tagSlot[tag] then
                TF.Mods.slots = TF.Mods.slots + 1
                TF.Mods.tagSlot[tag] = TF.Mods.slots
                TF.Mods.colorRank = nil
                if TF.Tooltip and TF.Tooltip.forget then TF.Tooltip.forget() end
            end
            return tag
        end
    end
    -- Nichts frei: das Kuerzel wird geteilt. Bis 0.3.3 geschah das still
    -- (Bugjagd 15.09.2026). TF.warnOnce, nicht warnPkg: das steht erst weiter
    -- unten und waere hier nil.
    TF.warnOnce("tag:full:" .. base .. ":" .. tostring(owner), "Kuerzel " .. base
        .. ": alle Ausweich-Kuerzel belegt, " .. tostring(owner) .. " teilt es mit "
        .. tostring(TF.Mods.tagOwner[base]) .. ".")
    return base
end

--- Namensraeume, die zu keiner Kennung ihres Mods passen.
--
-- modFor sucht ueber Mod-ID, Namen und Anfangsbuchstaben. More Traits
-- Definitive registriert seine 96 Traits aber unter "ToadTraits", und die
-- Mod heisst moreTraitsDefinitive ("More Traits Definitive"); ohne Eintrag
-- stuende in Listen und Uebersicht das Kuerzel TOA und als Quelle
-- "toadtraits" (Befund 16.09.2026, Workshop 3799050151).
--
-- Gepflegt wie TF.Conflict.KNOWN: aufgenommen wird nur, was nachgesehen ist.
-- Ein Paket ueber TraitFactsAPI mit modId bleibt der genauere Weg; diese
-- Liste ist fuer Mods, die selbst keines anmelden.
TF.Mods.NAMESPACES = {
    toadtraits = "moreTraitsDefinitive",
}

--- Die modIds aller angemeldeten Pakete, normalisiert, roh aus der
-- Warteschlange: prime() fragt modFor, bevor accept() ein Paket gelesen hat.
local function queuedModIds()
    local out = {}
    local queue = TraitFactsAPI and TraitFactsAPI.queue
    if type(queue) ~= "table" then return out end
    for _, pkg in ipairs(queue) do
        if type(pkg) == "table" and isText(pkg.modId) then out[TF.normalize(pkg.modId)] = true end
    end
    return out
end

--- Das Mod zu einem Namensraum: ueber Mod-ID, Mod-Namen oder dessen
-- Anfangsbuchstaben ("toc" ist "The Only Cure"). Einmal je Sitzung.
--
-- Rangfolge ueber alle aktiven Mods: exakte ID vor exaktem Namen vor den
-- Anfangsbuchstaben. Bis 0.3.3 gewann der erste Treffer jeder Art; ein
-- frueher geladenes "Tactical Ops Core" nahm so The Only Cure den
-- Namensraum toc samt Kuerzel (Bugjagd 15.09.2026). Passen mehrere nur ueber
-- die Anfangsbuchstaben, entscheidet ein Paket, das genau eines davon als
-- modId nennt; sonst keines, lieber kein Mod als das falsche.
function TF.Mods.modFor(ns)
    if not isText(ns) or ns == "base" then return nil end
    local cached = TF.Mods.modCache[ns]
    if cached then return cached end
    local want = TF.normalize(ns)
    -- Eine nachgesehene Zuordnung zaehlt wie die exakte ID.
    local mapped = TF.Mods.NAMESPACES[want]
    mapped = mapped and TF.normalize(mapped) or nil
    local byId, byName, byInitials = nil, nil, {}
    for _, id in ipairs(activeMods()) do
        local name = modInfo(id, "getName") or id
        local key = TF.normalize(id)
        if key == want or (mapped and key == mapped) then
            byId = byId or { id = id, name = name }
        elseif TF.normalize(name) == want then
            byName = byName or { id = id, name = name }
        elseif TF.normalize(initials(name)) == want then
            byInitials[#byInitials + 1] = { id = id, name = name }
        end
    end
    local found = byId or byName
    if not found and #byInitials == 1 then
        found = byInitials[1]
    elseif not found and #byInitials > 1 then
        local named, hits = queuedModIds(), {}
        for _, m in ipairs(byInitials) do
            if named[TF.normalize(m.id)] then hits[#hits + 1] = m end
        end
        if #hits == 1 then
            found = hits[1]
        else
            TF.logOnce("mod:ambiguous:" .. ns, "Namensraum \"" .. ns .. "\": " .. #byInitials
                .. " Mods passen nur ueber die Anfangsbuchstaben, keines zugeordnet.")
        end
    end
    if found then found.version = modInfo(found.id, "getModVersion") end
    found = found or { name = ns }
    found.tag = claimTag(TF.Mods.deriveTag(found.name), found.id or ("ns:" .. ns), found.name)
    TF.Mods.modCache[ns] = found
    return found
end

--- Das Mod eines Traits, oder nil fuer Vanilla.
function TF.Mods.traitMod(traitDef)
    local ns = TF.traitNamespace(traitDef)
    if not ns or ns == "base" then return nil end
    return TF.Mods.modFor(ns)
end

local function warnPkg(source, what)
    TF.warnOnce("pkg:" .. tostring(source) .. ":" .. what,
        "Paket \"" .. tostring(source) .. "\": " .. what)
end

--- Eine endliche Zahl. NaN und unendlich kamen bis 0.10.3 als Zahl durch und
-- standen dann als "nan%" in Tooltip und Summe.
local function finite(value)
    -- Ohne math.huge: unendlich minus unendlich ist NaN, und NaN ist nie
    -- gleich 0. Haengt so an keiner Konstante, die eine Laufzeit vielleicht
    -- nicht fuehrt (ein nil haette hier das ganze Paket gekostet).
    return type(value) == "number" and value - value == 0
end

local function validValue(kind, value)
    if kind == "info" then return true end
    if kind == "bool" then return type(value) == "boolean" end
    if kind == "range" or kind == "fromto" or kind == "pctrange" then
        return type(value) == "table" and finite(value[1]) and finite(value[2])
    end
    return finite(value)
end

local function remember(id, entry, info)
    TF.Mods.rows[id] = TF.Mods.rows[id] or {}
    local list = TF.Mods.rows[id]
    list[#list + 1] = { entry = entry, pkg = info }
end

local TEXT_FIELDS = { "text", "note", "unit", "hint", "condition" }

--- Ob ein Thema der Uebersicht existiert (TF.Summary.ORDER). Ohne geladene
-- Uebersicht gilt jedes als bekannt; dann liest es ohnehin niemand.
local function knownGroup(group)
    if not (TF.Summary and TF.Summary.ORDER) then return true end
    for _, name in ipairs(TF.Summary.ORDER) do
        if name == group then return true end
    end
    return false
end

local function acceptRow(info, id, row, index)
    if type(row) ~= "table" then return end
    local where = id .. ": Zeile \"" .. tostring(row.id or row.replace or row.remove or index) .. "\""
    -- Falsche Typen fallen hier auf, nicht erst beim Aufbau: ein
    -- replace = true kam sonst durch und warf in entriesFor bei jedem Tooltip
    -- und jeder Uebersicht (Abschlussreview 14.09.2026, Fund 6). Ein Fehler
    -- kostet hoechstens diese Zeile (Spec 4.2).
    if row.remove ~= nil and not isText(row.remove) then
        warnPkg(info.source, where .. ": remove muss ein Text sein, uebersprungen.")
        return
    end
    if isText(row.remove) then
        remember(id, { remove = row.remove }, info)
        return
    end
    if row.replace ~= nil and not isText(row.replace) then
        warnPkg(info.source, where .. ": replace muss ein Text sein, uebersprungen.")
        return
    end
    for _, field in ipairs(TEXT_FIELDS) do
        if row[field] ~= nil and type(row[field]) ~= "string" then
            warnPkg(info.source, where .. ": " .. field .. " muss ein Text sein, uebersprungen.")
            return
        end
    end
    if not isText(row.replace) then
        if not isText(row.id) then warnPkg(info.source, where .. " ohne id, uebersprungen.") return end
        if not isText(row.text) then warnPkg(info.source, where .. " ohne text, uebersprungen.") return end
    end
    if row.kind ~= nil and not TF.KINDS[row.kind] then
        warnPkg(info.source, where .. " hat kind \"" .. tostring(row.kind) .. "\" (erlaubt: "
            .. ALLOWED .. "), uebersprungen.")
        return
    end
    if not isText(row.replace) and not TF.KINDS[row.kind or ""] then
        warnPkg(info.source, where .. " ohne kind, uebersprungen.")
        return
    end
    -- Ohne replace muss der Wert zum kind passen, auch wenn er ganz fehlt
    -- (nil ist bei jedem kind ausser info kein brauchbarer Wert). Ein replace
    -- erbt kind und Wert seiner Zielzeile, und welche das ist, steht erst in
    -- entriesFor fest; dort prueft validValue die gemischte Zeile. Bis 0.3.3
    -- galt hier fuer replace ohne kind "pct": ein Zahlenwert auf einer
    -- fromto-Zeile kam durch und liess die Uebersicht werfen, die richtige
    -- Spanne { 20, 25 } lehnte die Pruefung ab (Bugjagd 15.09.2026).
    if not isText(row.replace) or (row.kind ~= nil and row.value ~= nil) then
        if not validValue(row.kind, row.value) then
            warnPkg(info.source, where .. ": Wert passt nicht zu kind \"" .. tostring(row.kind) .. "\", uebersprungen.")
            return
        end
    end
    -- Ein unbekanntes Thema liess die Zeile sonst still aus der Uebersicht
    -- fallen (sie sammelt nur die Themen aus TF.Summary.ORDER). So steht sie
    -- im Standardthema, und das Log sagt warum.
    local group = row.group
    if group ~= nil and not (isText(group) and knownGroup(group)) then
        warnPkg(info.source, where .. ": group \"" .. tostring(group) .. "\" unbekannt (erlaubt: "
            .. table.concat((TF.Summary and TF.Summary.ORDER) or {}, ", ") .. "), group ignoriert.")
        group = nil
    end
    local entry = {}
    for k, v in pairs(row) do entry[k] = v end
    entry.probe = nil
    -- Interne Felder, die die Uebersicht ungeprueft liest: ein items = "x"
    -- warf in TF.Summary.merge, und die ganze Uebersicht blieb stehen (Audit
    -- 20.09.2026). Falscher Typ kostet nur das Feld, nicht die Zeile.
    if entry.items ~= nil and type(entry.items) ~= "table" then entry.items = nil end
    for _, field in ipairs({ "case", "scope" }) do
        if entry[field] ~= nil and type(entry[field]) ~= "string" then entry[field] = nil end
    end
    if entry.textArg ~= nil and type(entry.textArg) ~= "string" and type(entry.textArg) ~= "number" then
        entry.textArg = nil
    end
    entry.measuredStale, entry.dead = nil, (entry.dead == true) or nil
    entry.group = group
    for _, field in ipairs(TEXT_FIELDS) do
        if isText(entry[field]) and getTextOrNull(entry[field]) == nil then
            TF.Mods.literal[entry[field]] = true
        end
    end
    if isText(entry.text) and TF.Summary then
        if (entry.better == "up" or entry.better == "down" or entry.better == "open")
                and TF.Summary.BETTER and TF.Summary.BETTER[entry.text] == nil then
            TF.Summary.BETTER[entry.text] = entry.better
        end
        if isText(entry.group) and TF.Summary.GROUP and TF.Summary.GROUP[entry.text] == nil then
            TF.Summary.GROUP[entry.text] = entry.group
        end
    end
    remember(id, entry, info)
end

--- Dieselbe Fassung? "1.0" und "1.0.0" sind es, ebenso "v2.4" und "2.4":
-- bis 0.10.3 entschied die reine Textgleichheit, und ein Paket fuer "1.0"
-- stand neben einem Mod "1.0.0" komplett orange (Audit 20.09.2026).
local function sameVersion(a, b)
    local function plain(v)
        v = string.lower(tostring(v))
        v = string.gsub(v, "%s", "")
        v = string.gsub(v, "^v", "")
        local before
        repeat
            before = v
            v = string.gsub(v, "%.0+$", "")
        until v == before
        return v
    end
    return plain(a) == plain(b)
end

--- Prueft ein Paket und merkt sich seine Zeilen.
function TF.Mods.accept(pkg)
    if type(pkg) ~= "table" then return end
    if pkg.format ~= TF.Mods.FORMAT then
        warnPkg(pkg.source, "Format " .. tostring(pkg.format) .. " unbekannt (Trait Facts kennt "
            .. TF.Mods.FORMAT .. "), Paket uebersprungen. Trait Facts aktualisieren.")
        return
    end
    if not isText(pkg.source) then
        TF.warnOnce("pkg:nosource", "Paket ohne source, uebersprungen.")
        return
    end
    -- modId normalisiert wie in modFor. Ein nicht aktives Mod ist der
    -- Normalfall fuer ein Paket, das nur mit seinem Mod gelten soll: keine
    -- Warnung, nur eine Logzeile, damit ein Tippfehler in der modId
    -- auffindbar bleibt.
    local modActive = nil
    if isText(pkg.modId) then
        modActive = activeId(pkg.modId)
        if not modActive then
            TF.logOnce("pkg:inactive:" .. pkg.source, "Paket \"" .. pkg.source .. "\": Mod \""
                .. pkg.modId .. "\" nicht aktiv, Paket nicht gelesen.")
            return
        end
    end
    local info = { source = pkg.source, modId = pkg.modId,
                   version = isText(pkg.version) and pkg.version or nil }
    if modActive and info.version then
        local installed = modInfo(modActive, "getModVersion")
        if installed and not sameVersion(installed, info.version) then
            info.stale, info.installed = true, installed
            TF.logOnce("pkg:stale:" .. pkg.source, "Paket \"" .. pkg.source .. "\" " .. info.version
                .. ": installiert ist " .. installed .. ", Zeilen als moeglicherweise veraltet markiert.")
        end
    end
    local wanted = (type(pkg.tag) == "string" and string.match(pkg.tag, "^%w%w%w?%w?$"))
        and string.upper(pkg.tag) or TF.Mods.deriveTag(pkg.source)
    -- Entscheidung 14.09.2026 (Review Important 4): das Kuerzel eines Mods
    -- kommt immer aus seinem Namen, ein Paket-Kuerzel benennt nur, was das
    -- Paket liefert. Ist es gleich dem Kuerzel seines eigenen Mods, teilen
    -- sich beide eines: das Paket belegt es fuer denselben Besitzer wie
    -- modFor (die ID des aktiven Mods), statt das Mod auf ein laengeres
    -- Kuerzel zu draengen ("MTR" statt "MT"). Wer zuerst belegt, ist egal.
    local owner = "pkg:" .. pkg.source
    if modActive then
        local modName = modInfo(modActive, "getName") or modActive
        if wanted == TF.Mods.deriveTag(modName) then
            owner, info.modName = modActive, modName
        end
    end
    info.tag = claimTag(wanted, owner, pkg.source)
    TF.Mods.packages[#TF.Mods.packages + 1] = info
    if type(pkg.traits) ~= "table" then return end
    for rawId, list in pairs(pkg.traits) do
        local id = type(rawId) == "string" and string.lower(rawId) or nil
        if not id or not string.match(id, "^[%w_%.%-]+:[%w_%.%-]+$") then
            warnPkg(pkg.source, "Trait \"" .. tostring(rawId) .. "\" ohne Namensraum (erwartet z. B. \"modname:"
                .. tostring(rawId) .. "\"), uebersprungen.")
        elseif type(list) == "table" then
            for index, row in ipairs(list) do acceptRow(info, id, row, index) end
        end
    end
end

--- Belegt einmal je Sitzung die Kuerzel aller fremden Mods, deren Traits in
-- der Registry stehen (CharacterTraitDefinition.getTraits).
--
-- Die Farbe eines Mod-Kuerzels haengt an seinem Platz in der Mod-Liste
-- unter allen belegten Mod-Kuerzeln. Kaeme ein Mod erst spaeter dazu (sein
-- erster Trait wird spaeter gebaut) und stuende es in der Liste weiter vorn,
-- verschoebe es die Farben schon gebauter Tooltips. Darum stehen alle
-- Mod-Kuerzel fest, bevor die erste Farbe vergeben wird: beim ersten Lesen
-- der Pakete (drain) und vor der Farbreihenfolge (colorRank). Nebenbei
-- bekommen die Mods ihre Kuerzel vor den Paketen, also aus ihrem Namen.
-- Wirft ein Eintrag, faellt nur er weg; ohne Registry bleibt es beim
-- Belegen nach Bedarf.
function TF.Mods.prime()
    if TF.Mods.primed then return end
    TF.Mods.primed = true
    local ok, all = pcall(function() return CharacterTraitDefinition.getTraits() end)
    if not ok or all == nil then return end
    local okSize, size = pcall(function() return all:size() end)
    if not okSize or type(size) ~= "number" then return end
    for i = 0, size - 1 do
        pcall(function()
            local ns = TF.traitNamespace(all:get(i))
            if ns and ns ~= "base" then TF.Mods.modFor(ns) end
        end)
    end
end

--- Verarbeitet neu angemeldete Pakete. @return boolean  true, wenn etwas dazukam
function TF.Mods.drain()
    TF.Mods.prime()
    local queue = TraitFactsAPI and TraitFactsAPI.queue
    if type(queue) ~= "table" then return false end
    local changed = false
    while TF.Mods.done < #queue do
        TF.Mods.done = TF.Mods.done + 1
        local ok, err = pcall(TF.Mods.accept, queue[TF.Mods.done])
        if not ok then
            TF.warnOnce("pkg:err:" .. TF.Mods.done, "Paket Nr. " .. TF.Mods.done
                .. " nicht lesbar: " .. tostring(err))
        end
        changed = true
    end
    if changed and TF.Tooltip and TF.Tooltip.forget then TF.Tooltip.forget() end
    return changed
end

local function copyOf(entry)
    local out = {}
    for k, v in pairs(entry) do out[k] = v end
    return out
end

--- Die Zeilen eines Traits: Vanilla (nur base), dann die Pakete in der
-- Reihenfolge der Anmeldung. replace ersetzt eine Zeile und erbt ihre
-- uebrigen Felder, remove nimmt sie heraus, sonst kommt sie dazu; setzen zwei
-- Pakete dieselbe Zeile, gewinnt das spaetere.
function TF.Mods.entriesFor(traitDef)
    TF.Mods.drain()
    local out = {}
    for _, entry in ipairs(TF.staticFor(traitDef)) do
        local copy = copyOf(entry)
        copy.origin = "static"
        out[#out + 1] = copy
    end
    local id = TF.traitId(traitDef)
    for _, held in ipairs((id and TF.Mods.rows[id]) or {}) do
        local row, info = held.entry, held.pkg
        local target = row.replace or row.remove
        local at = nil
        local want = target or row.id
        -- Eine neue Zeile (ohne replace/remove) trifft nur Zeilen anderer
        -- Pakete: setzen zwei dieselbe, gewinnt die spaetere (Spec 5.1). Eine
        -- Vanilla-Zeile gleicher id ersetzte sie bis 0.3.3 still, obwohl das
        -- nur replace darf (Spec 4.3, Bugjagd 15.09.2026); jetzt kommt die
        -- neue dazu, und das Log nennt die gleiche id.
        for i, e in ipairs(out) do
            if e.id == want and (target or e.origin == "package") then at = i break end
        end
        if not target and not at then
            for _, e in ipairs(out) do
                if e.id == want then
                    TF.logOnce("pkg:static:" .. id .. ":" .. tostring(want), id .. ", Zeile \"" .. tostring(want)
                        .. "\": \"" .. info.source .. "\" traegt dieselbe id wie eine Vanilla-Zeile;"
                        .. " beide stehen da (ersetzen nur mit replace).")
                    break
                end
            end
        end
        if target and not at then
            TF.warnOnce("pkg:" .. info.source .. ":" .. id .. ":" .. target,
                "Paket \"" .. info.source .. "\", " .. id .. ": " .. (row.remove and "remove" or "replace")
                .. " \"" .. target .. "\" trifft keine Zeile, uebersprungen.")
        elseif row.remove then
            table.remove(out, at)
        else
            local merged = at and target and copyOf(out[at]) or {}
            for k, v in pairs(row) do
                if k ~= "replace" then merged[k] = v end
            end
            if target then merged.id = target end
            merged.probe = nil
            -- Erst die gemischte Zeile hat ihr kind (geerbt von der Zielzeile,
            -- siehe acceptRow). Passt der Wert nicht, bleibt die Zielzeile:
            -- ein Fehler kostet nur die Paketzeile, nicht die Uebersicht.
            if not validValue(merged.kind, merged.value) then
                warnPkg(info.source, id .. ": Zeile \"" .. tostring(merged.id) .. "\": Wert passt nicht zu kind \""
                    .. tostring(merged.kind) .. "\", uebersprungen.")
            else
                if at and out[at].origin == "package" then
                    TF.logOnce("pkg:clash:" .. id .. ":" .. tostring(merged.id), id .. ", Zeile \""
                        .. tostring(merged.id) .. "\": \"" .. info.source .. "\" ersetzt den Wert aus \""
                        .. tostring(out[at].pkg and out[at].pkg.source) .. "\" (zuletzt angemeldet gewinnt).")
                end
                merged.origin, merged.pkg = "package", info
                if at then out[at] = merged else out[#out + 1] = merged end
            end
        end
    end
    return out
end

--- Ob ein Trait Zeilen aus einem Paket hat.
function TF.Mods.hasPackageRows(traitDef)
    for _, entry in ipairs(TF.Mods.entriesFor(traitDef)) do
        if entry.origin == "package" then return true end
    end
    return false
end

--- Ob ein Text ein vergebenes Kuerzel ist.
function TF.Mods.isTag(text)
    return type(text) == "string" and TF.Mods.tagOwner[text] ~= nil
end

--- Die Farbreihenfolge: Kuerzel -> Platz (1, 2, ...), siehe TAG_COLORS.
--
-- Gruppe 1 sind die Kuerzel aktiver Mods, geordnet nach ihrem Platz in
-- getActivatedMods(); ein geteiltes Kuerzel gehoert seinem Mod (sein
-- Besitzer ist die Mod-ID, siehe TF.Mods.accept). Gruppe 2 die Kuerzel
-- eines Namensraums ohne aktives Mod, Gruppe 3 die reinen Paket-Kuerzel
-- (Besitzer "pkg:..."); beide nach der Reihenfolge ihrer Belegung, bei den
-- Paketen ist das die der Anmeldung. So haengt die Farbe nicht daran, ob
-- die Pakete vor dem ersten modFor gelesen wurden. Gerechnet wird, wenn
-- ein neues Kuerzel dazukam, nicht bei jedem Zeichnen.
local function colorRank()
    if TF.Mods.colorRank then return TF.Mods.colorRank end
    TF.Mods.prime()
    local position = {}
    for i, id in ipairs(activeMods()) do
        if position[id] == nil then position[id] = i end
    end
    local list = {}
    for tag, slot in pairs(TF.Mods.tagSlot or {}) do
        local owner = TF.Mods.tagOwner[tag]
        local group, key = 2, slot
        if type(owner) == "string" and string.sub(owner, 1, 4) == "pkg:" then
            group = 3
        elseif owner ~= nil and position[owner] then
            group, key = 1, position[owner]
        end
        list[#list + 1] = { tag = tag, group = group, key = key, slot = slot }
    end
    table.sort(list, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        if a.key ~= b.key then return a.key < b.key end
        return a.slot < b.slot
    end)
    local rank = {}
    for i, item in ipairs(list) do rank[item.tag] = i end
    TF.Mods.colorRank = rank
    return rank
end

--- Der Farbeintrag eines Kuerzels aus TF.Mods.TAG_COLORS, oder nil fuer ein
-- Kuerzel, das nie belegt wurde.
local function colorEntry(tag)
    if type(tag) ~= "string" or not (TF.Mods.tagSlot and TF.Mods.tagSlot[tag]) then return nil end
    local at = colorRank()[tag]
    if not at then return nil end
    local list = TF.Mods.TAG_COLORS
    return list[((at - 1) % #list) + 1]
end

--- Die Farbe eines Kuerzels als { r, g, b } (Werte 0 bis 1), fuer alles, was
-- selbst zeichnet: Kaestchen in den Listen und der Uebersicht, der Hover.
-- Ein unbekanntes Kuerzel steht im Grau der Fussnote wie bisher.
function TF.Mods.tagColor(tag)
    local entry = colorEntry(tag)
    if entry then return entry.rgb end
    return (TF.fmt and TF.fmt.rgb and (TF.fmt.rgb.tag or TF.fmt.rgb.note)) or { 0.55, 0.55, 0.55 }
end

--- Dieselbe Farbe als Rich-Text-Tag (" <RGB:r,g,b> "), oder nil fuer ein
-- unbekanntes Kuerzel; TF.fmt.paint setzt dann das Grau der Palette.
function TF.Mods.tagRich(tag)
    local entry = colorEntry(tag)
    return entry and entry.rich or nil
end

--- Was hinter einem Kuerzel steht, fuer den Hover in der Uebersicht.
--
-- Ein Mod-Kuerzel beschreibt das Mod. Daten hat es, sobald eine Paketzeile
-- in einem seiner Namensraeume steht (Zeilenschluessel "ns:...") oder ein
-- Paket dasselbe Kuerzel traegt (geteiltes Kuerzel, Entscheidung
-- 14.09.2026); nur ohne beides heisst es "keine Daten hinterlegt". Vorher
-- sagte jedes Mod-Kuerzel das, auch mit Daten (Abschlussreview 14.09.2026,
-- Fund 3). Ein reines Paket-Kuerzel beschreibt sein Paket.
--
-- Ein Mod-Kuerzel nennt die Fassung des installierten Mods (version) und
-- in packages alle liefernden Pakete in Anmeldereihenfolge; jedes traegt
-- seine eigene Fassung und seinen Stand "veraltet". Vorher ueberschrieb die
-- Fassung des einen gewaehlten Pakets die des Mods, und mit einem frischen
-- und einem veralteten Paket stand im Hover "TheOnlyCure 2.3.0", obwohl
-- 2.4.0 installiert war (Befund im Spiel 14.09.2026). stale und installed
-- bleiben fuer die Rueckwaertsvertraeglichkeit: die des ersten veralteten
-- Pakets.
-- @return table|nil  { name, id, version, nodata, stale, installed,
--                      packages = { info, ... } nur beim Mod-Kuerzel }
function TF.Mods.describeTag(tag)
    local mod, seen = nil, {}
    for ns, entry in pairs(TF.Mods.modCache) do
        if entry.tag == tag then
            mod = mod or entry
            local prefix = string.lower(ns) .. ":"
            for id, list in pairs(TF.Mods.rows) do
                if string.sub(id, 1, #prefix) == prefix then
                    for _, held in ipairs(list) do seen[held.pkg] = true end
                end
            end
        end
    end
    local pick, list = nil, {}
    for _, info in ipairs(TF.Mods.packages) do
        if seen[info] or info.tag == tag then
            list[#list + 1] = info
            if not pick or (info.stale and not pick.stale) then pick = info end
        end
    end
    if mod then
        local d = { name = mod.name, id = mod.id, version = mod.version, packages = list }
        if not pick then
            d.nodata = true
        else
            d.stale, d.installed = pick.stale, pick.installed
        end
        return d
    end
    if pick then
        return { name = pick.modName or pick.source, id = pick.modId, version = pick.version,
                 stale = pick.stale, installed = pick.installed }
    end
    return nil
end
