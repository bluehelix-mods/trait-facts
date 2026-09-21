--- Trait Facts - Konflikte mit anderen Mods.
--
-- Trait Facts und "More Description For Traits" haengen sich an dieselben
-- Funktionen der Charaktererstellung. Laufen beide, steht jede Zeile doppelt
-- im Tooltip, und die Zahlen widersprechen sich: MDFT fuehrt zwoelf belegte
-- Abweichungen von der Engine, darunter zwei Traits, die es in Build 42 nicht
-- mehr gibt (siehe Extraktionsbericht, Abschnitt 4).
--
-- Die Engine kennt in mod.info den Schluessel `incompatible`. Der verhindert
-- das Zusammenschalten im Mod-Menue, aber nur dort: eine bestehende
-- Speicherliste oder ein Server kann beide trotzdem aktivieren. Deshalb prueft
-- die Mod es zusaetzlich selbst und sagt es sichtbar, statt still doppelte
-- Zeilen zu zeigen.
--
-- `getActivatedMods()` und `getModInfoByID()` benutzt Vanilla selbst in
-- ISPauseModListUI und ServerSettingsScreen.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Conflict = TF.Conflict or {}

--- Mods, die derselben Stelle in die Quere kommen.
--
-- `kind` sagt, was passiert, und bestimmt den Text der Warnung:
--   "tooltip"      beide schreiben in dieselben Tooltips, Zeilen stehen doppelt
--   "description"  die andere Mod schreibt eigene Zahlen in die Vanilla-
--                  Beschreibungen; manche Wirkung steht dann zweimal, mit
--                  anderer Zahl
--   "screen"       die andere Mod ersetzt die Trait-Auswahl, unsere Spalte und
--                  unsere Tooltips erscheinen dort nicht
-- Alle drei sperrt mod.info zusaetzlich (check-data, Regel 16). "screen" bekam
-- bis 0.4.1 nur einen Hinweis; der stand aber im Log und in der Uebersicht,
-- und die liegt unter dem fremden Bildschirm, also sah ihn niemand. Unter
-- This Is Your Life zeigt Trait Facts gar nichts, weder Tooltips noch
-- Uebersicht noch Startskills; darum ist es eine Sperre (Befund im Spiel und
-- Entscheidung 16.09.2026). Der Hinweis bleibt fuer den Fall, dass eine
-- Speicherliste oder ein Server beide doch aktiviert.
--
-- Aufgenommen wird nur, was nachgesehen ist. Geprueft am 10.09.2026 gegen
-- die 180 hier installierten Workshop-Mods; drei fassen die Trait-Auswahl an,
-- zwei davon stehen unten. "Traits As Skills" (traitsAsSkills) haengt nur
-- eine eigene Bemerkung an die Tooltips von Deaf und Short Sighted und
-- widerspricht keiner Zahl - das ist kein Konflikt und steht deshalb nicht
-- hier. "Detailed Descriptions for Occupations and Traits" fasst keine
-- Funktion an, ersetzt aber 121 Beschreibungstexte; bei Speed Demon sagt sie
-- +15 % Hoechstgeschwindigkeit, wir +11 % (Bugjagd 10.09.2026, Fund 5).
TF.Conflict.KNOWN = {
    MoreDescriptionForTraits4219 = { name = "More Description For Traits", kind = "tooltip" },
    DetailedDescriptionsForOccupationsAndTraits = {
        name = "Detailed Descriptions for Occupations and Traits", kind = "description" },
    ThisIsYourLife = { name = "This Is Your Life", kind = "screen" },
}

--- Kennungen, bei denen schon der Anfang reicht.
--
-- Von More Description For Traits gibt es mehrere Fassungen und Fixes, jede
-- mit eigener Kennung ("...4219" ist die fuer 42.19). Eine feste Liste
-- veraltet mit der naechsten; der gemeinsame Anfang nicht.
TF.Conflict.PREFIXES = {
    { prefix = "MoreDescriptionForTraits", name = "More Description For Traits", kind = "tooltip" },
}

--- Der Eintrag zu einer Kennung, oder nil.
local function known(id)
    local entry = TF.Conflict.KNOWN[id]
    if entry then return entry end
    for _, candidate in ipairs(TF.Conflict.PREFIXES) do
        if id:sub(1, #candidate.prefix) == candidate.prefix then return candidate end
    end
    return nil
end

-- Einmal ermittelt und behalten: die Mod-Liste aendert sich zur Laufzeit nicht.
---@type { name: string, kind: string }|false|nil
local found = nil

--- Die erste laufende Mod, die uns in die Quere kommt.
-- @return string|nil, string|nil  Anzeigename und Art ("tooltip"|"screen")
function TF.Conflict.active()
    if found ~= nil then
        if found == false then return nil end
        return found.name, found.kind
    end
    found = false

    local ok = pcall(function()
        local active = getActivatedMods()
        if not active then return end
        for index = 0, active:size() - 1 do
            local id = tostring(active:get(index))
            local entry = known(id)
            if entry then
                -- Den echten Anzeigenamen nehmen, wenn die Engine ihn kennt;
                -- der Nutzer sucht im Mod-Menue nach genau diesem Namen.
                local name = entry.name
                local okInfo, info = pcall(function() return getModInfoByID(id) end)
                if okInfo and info then
                    local okName, real = pcall(function() return info:getName() end)
                    if okName and real and real ~= "" then name = tostring(real) end
                end
                found = { name = name, kind = entry.kind }
                return
            end
        end
    end)
    if not ok then
        TF.warnOnce("conflict:list", "Mod-Liste nicht lesbar, Konfliktpruefung entfaellt.")
    end

    if not found then return nil end
    return found.name, found.kind
end

--- Der Uebersetzungsschluessel zur Art des Konflikts.
function TF.Conflict.messageKey(kind)
    if kind == "screen" then return "UI_TF_conflict_screen" end
    if kind == "description" then return "UI_TF_conflict_description" end
    return "UI_TF_conflict"
end

Events.OnGameBoot.Add(function()
    TF.safe("conflict:check", function()
        local name, kind = TF.Conflict.active()
        if name then
            TF.warn(TF.fmt.text(TF.Conflict.messageKey(kind), name))
        end
    end)
end)
