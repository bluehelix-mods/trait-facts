--- Trait Facts - Schicht 2: Messung zur Laufzeit und Selbstpruefung.
--
-- Die hinterlegten Werte sind ein Foto von Build 42.20.4. Aendert ein Patch
-- etwas, zeigte die Mod ohne diese Schicht weiter die alte Zahl - still und
-- ohne Warnung. Genau der Fehler, gegen den sie gebaut ist.
--
-- Deshalb misst sie, was sich messen laesst, und vergleicht:
--
--   baseline  = f(ohne Traits)
--   withTrait = f(nur dieser Trait)
--
--   kind = "mult"  ->  withTrait / baseline
--   kind = "pct"   ->  (withTrait / baseline - 1) * 100
--   kind = "flat"  ->  withTrait - baseline
--
-- Weicht die Messung vom hinterlegten Wert ab, gewinnt die Messung, die Zeile
-- wird markiert und es wird einmalig geloggt.
--
-- Dieser Messruecken braucht **keine Spielfigur**. CharacterTraits laesst sich
-- aus Lua erzeugen (im Spiel bestaetigt, SPEC offene Frage 1), und die drei hier
-- benutzten Getter sind reine Rechnungen ohne Nebenwirkungen. Es wird also
-- nichts am laufenden Charakter angefasst.
--
-- Messungen, die eine Figur brauchen (Grapple, Tragekapazitaet,
-- Erkennungsradius, Faellgeschwindigkeit, Hoerweite), fehlen noch; ihre
-- Eintraege bleiben solange auf dem hinterlegten Wert.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Probe = TF.Probe or {}
TF.Probed = TF.Probed or {}

--- Die messbaren Groessen. `read` bekommt einen CharacterTraits-Container.
--
-- Alle drei stehen in zombie/characters/traits/CharacterTraits und sind
-- parameterlose Getter ohne Nebenwirkungen.
TF.Probes = {
    damageDealt = {
        read = function(container) return container:getTraitDamageDealtReductionModifier() end,
    },
    enduranceLoss = {
        read = function(container) return container:getTraitEnduranceLossModifier() end,
    },
    weatherPenalty = {
        read = function(container) return container:getTraitWeatherPenaltyModifier() end,
    },
}

-- Keine Konstanten-Schicht mehr. CharacterTraits fuehrt Kletter-, Erkennungs-
-- und Fallschadenwerte als `public static final`, und der Plan war, zwanzig
-- Eintraege ohne Spielfigur dagegen zu lesen. Im Spiel liefert Lua fuer jedes
-- dieser Felder nil (console.txt 09.09.2026: "Konstanten aus CharacterTraits:
-- 0 von 20 lesbar"); die Schicht hat also nie etwas geprueft und ist fuer 1.0
-- entfernt. Diese Eintraege stehen wie die uebrigen aus dem Spielcode,
-- mit Versionsstempel.

-- Registry-Typ je normalisiertem Trait-Schluessel, einmal aufgebaut.
local typeByKey = nil

local function traitTypes()
    if typeByKey ~= nil then return typeByKey end
    typeByKey = {}
    local ok = pcall(function()
        local all = CharacterTraitDefinition.getTraits()
        for i = 0, all:size() - 1 do
            local def = all:get(i)
            local key = TF.traitKey(def)
            -- Nur Vanilla: gemessen wird, was TF_Static hinterlegt, und das
            -- gilt nur fuer base. Ein fremder Trait mit demselben Pfad
            -- ("xyz:emaciated") verdraengte sonst den Vanilla-Typ, die
            -- Messung lief an ihm und markierte die Vanilla-Zeile als
            -- abweichend (Review und Bugjagd 15.09.2026).
            if key and TF.traitNamespace(def) == "base" then typeByKey[key] = def:getType() end
        end
    end)
    if not ok then
        TF.warnOnce("probe:registry", "Trait-Registry nicht lesbar, Messungen entfallen.")
    end
    return typeByKey
end

--- Rechnet eine Messung in die Darstellung eines Eintrags um.
-- @return number|nil  nil, wenn sich nichts Sinnvolles ergibt
local function toKind(kind, baseline, withTrait)
    if type(baseline) ~= "number" or type(withTrait) ~= "number" then return nil end
    if kind == "flat" then
        return withTrait - baseline
    end
    -- Schutz vor Division durch Null: lieber keine Messung als eine erfundene.
    if baseline == 0 then return nil end
    if kind == "mult" then
        return withTrait / baseline
    elseif kind == "pct" then
        return (withTrait / baseline - 1) * 100
    end
    return nil
end

--- Misst einen einzelnen Wert fuer einen Trait.
-- @return number|nil, string|nil  Messwert und, bei Fehlschlag, der Grund
local function measure(traitType, probeName, kind)
    local probe = TF.Probes[probeName]
    if not probe then return nil, "unbekannte Messung" end

    local value, reason
    local ok, err = pcall(function()
        -- Baseline und Messwert im selben Durchgang auf demselben frisch
        -- erzeugten Container: nur die Differenz zaehlt, nie der Absolutwert.
        local container = CharacterTraits.new()
        local baseline = probe.read(container)
        container:add(traitType)
        local withTrait = probe.read(container)
        value = toKind(kind, baseline, withTrait)
        if value == nil then reason = "Baseline 0 oder unbekannter kind" end
    end)
    if not ok then return nil, tostring(err) end
    return value, reason
end

--- Misst alles, was in TF_Static ein `probe` traegt, und prueft es gegen.
--
-- Ergebnis liegt danach in TF.Probed[traitKey][entryId] als
-- { value = Zahl, status = "probed"|"stale"|"unmeasurable", static = Zahl }.
function TF.Probe.run()
    -- Eine neue Messung kann Tooltip-Zeilen aendern; die fertigen Bloecke
    -- gelten ab hier nicht mehr.
    if TF.Tooltip and TF.Tooltip.forget then TF.Tooltip.forget() end
    local types = traitTypes()
    local counted, stale = 0, 0

    for key, entries in pairs(TF.Static) do
        for _, entry in ipairs(entries) do
            if entry.probe and TF.Probes[entry.probe] then
                local traitType = types[key]
                local record
                if type(entry.value) ~= "number" then
                    -- Ein Eintrag mit Spanne (range, fromto) traegt eine Tabelle.
                    -- Ohne diese Pruefung wuerde math.abs darauf werfen, und
                    -- weil TF.Probe.run in TF.safe laeuft, waeren *alle*
                    -- Messungen still weg - samt der Selbstpruefung, fuer die
                    -- es die Schicht ueberhaupt gibt.
                    record = { status = TF.STATUS.UNMEASURABLE,
                        reason = "Wert ist keine Zahl, Messung nicht vergleichbar" }
                    TF.warnOnce("probe:kind:" .. key .. ":" .. tostring(entry.id),
                        string.format("Messung %s bei %s / %s uebersprungen: kind '%s' hat keinen Zahlenwert.",
                            tostring(entry.probe), key, tostring(entry.id), tostring(entry.kind)))
                elseif not traitType then
                    record = { status = TF.STATUS.UNMEASURABLE, reason = "Trait nicht in der Registry" }
                else
                    local value, reason = measure(traitType, entry.probe, entry.kind)
                    if value == nil then
                        record = { status = TF.STATUS.UNMEASURABLE, reason = reason }
                    else
                        -- Toleranz: ein halbes Prozent des hinterlegten Werts,
                        -- mindestens 0.01. Float-Rundung soll nichts melden.
                        local static = entry.value
                        local tol = math.max(0.005 * math.abs(static or 0), 0.01)
                        local matches = type(static) == "number"
                            and math.abs(value - static) <= tol
                        record = {
                            value = value,
                            static = static,
                            status = matches and TF.STATUS.PROBED or TF.STATUS.STALE,
                        }
                        if not matches then
                            stale = stale + 1
                            TF.warnOnce("stale:" .. key .. ":" .. tostring(entry.id),
                                string.format(
                                    "Messung weicht ab bei %s / %s: gemessen %s, hinterlegt %s. "
                                    .. "Die Messung gilt; die hinterlegten Werte gehoeren nachgeprueft.",
                                    key, tostring(entry.id), tostring(value), tostring(static)))
                        end
                    end
                end
                TF.Probed[key] = TF.Probed[key] or {}
                TF.Probed[key][entry.id] = record
                counted = counted + 1
            end
        end
    end

    TF.log(string.format("%d Messungen ausgefuehrt, %d Abweichungen.", counted, stale))
    return counted, stale
end

--- Das Messergebnis zu einem Eintrag, oder nil.
function TF.Probe.get(traitKey, entryId)
    local perTrait = TF.Probed[traitKey]
    if not perTrait then return nil end
    return perTrait[entryId]
end

--- Konsolenhilfe: Messung gegen hinterlegt, mit Differenz.
-- Aufruf in der Lua-Konsole:  TF.Probe.dump()
function TF.Probe.dump()
    local rows = 0
    for key, entries in pairs(TF.Probed) do
        for id, record in pairs(entries) do
            rows = rows + 1
            if record.status == TF.STATUS.UNMEASURABLE then
                TF.log(string.format("%-18s %-14s nicht messbar (%s)",
                    key, id, tostring(record.reason)))
            else
                TF.log(string.format("%-18s %-14s gemessen %-10s hinterlegt %-10s %s",
                    key, id, tostring(record.value), tostring(record.static), record.status))
            end
        end
    end
    if rows == 0 then TF.log("Keine Messungen vorhanden.") end
    return rows
end

Events.OnGameBoot.Add(function()
    TF.safe("probe:run", TF.Probe.run)
end)
