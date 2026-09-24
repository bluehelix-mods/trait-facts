--- Trait Facts - Kern.
-- Namespace, Versionsstempel, Statuskonstanten, Logging, Trait-Schluessel.
--
-- Ladereihenfolge: shared/ vor client/, innerhalb eines Ordners alphabetisch.
-- TF_Core kommt damit vor TF_Format und TF_Static. Trotzdem legt jede Datei den
-- Namespace defensiv selbst an, damit eine geaenderte Reihenfolge nie zum
-- Ladefehler wird.
--
-- Der Namespace heisst global TraitFacts, in jeder Datei lokal TF. Bis 0.11.0
-- war TF selbst das Global: zwei Buchstaben, die sich jeder andere Mod ebenso
-- nehmen kann, und ein fremdes TF, das keine Tabelle ist, haette jede unserer
-- Dateien beim Laden scheitern lassen (Audit 20.09.2026). Von aussen, etwa in
-- der Lua-Konsole, also TraitFacts.Live.dumpRecipes(...). Die oeffentliche
-- Schnittstelle fuer andere Mods ist und bleibt TraitFactsAPI.

TraitFacts = TraitFacts or {}
local TF = TraitFacts

-- Noch nicht veroeffentlicht: 0.x bis zum ersten Workshop-Upload, dann 1.0.0.
-- Jede Aenderung unter mod/ zaehlt hoch, zusammen mit modversion in
-- mod.info (check-data, Regeln 21 und 23). Fehler und berichtigte Werte
-- zaehlen die letzte Stelle, neue Wirkungen oder Funktionen die mittlere.
TF.VERSION = "0.14.8"

--- Build, aus dem die hinterlegten Werte (Schicht 3) stammen.
-- Steht im Log und im Fehlerbericht; laeuft ein anderer Build, warnt die
-- Uebersicht (TF.buildMismatch).
TF.DATA_BUILD = "42.20.4"

--- Die Versionsnummer aus einer Angabe wie "42.20.4" oder "42.20.4 b0bbce05d5".
local function buildNumber(text)
    if type(text) ~= "string" then return nil end
    return string.match(text, "%d+%.%d+%.%d+") or string.match(text, "%d+%.%d+")
end

---@type string|false|nil
local runningBuild = nil

--- Der laufende Spiel-Build als "42.20.4", oder nil, wenn er nicht lesbar ist.
-- Einmal gelesen und behalten. getCore gibt es nur im Client; auf dem Server
-- und bei einem Lesefehler bleibt es bei nil, und es wird nicht gewarnt.
function TF.gameBuild()
    if runningBuild == nil then
        runningBuild = false
        pcall(function()
            runningBuild = buildNumber(tostring(getCore():getVersion())) or false
        end)
    end
    return runningBuild or nil
end

--- Laeuft ein anderer Build als der, aus dem die hinterlegten Werte stammen?
-- Bis 0.10.3 stand DATA_BUILD nur im Log: nach einem Patch zeigten alle
-- Zeilen ausser den fuenf gemessenen still den alten Stand (Audit 20.09.2026).
-- @return string|nil, string|nil  hinterlegter und laufender Build bei Abweichung
function TF.buildMismatch()
    local running = TF.gameBuild()
    if not running or running == buildNumber(TF.DATA_BUILD) then return nil end
    return TF.DATA_BUILD, running
end

--- Herkunft einer gerenderten Zeile.
TF.STATUS = {
    LIVE         = "live",          -- direkt aus der Registry gelesen
    PROBED       = "probed",        -- Messung erfolgreich, Messwert wird gezeigt
    STATIC       = "static",        -- keine Messung moeglich, hinterlegter Wert
    STALE        = "stale",         -- Messung widerspricht dem hinterlegten Wert
    UNMEASURABLE = "unmeasurable",  -- Messung vorgesehen, aber fehlgeschlagen
}

--- Zulaessige Werte fuer das Feld `kind` eines Eintrags.
TF.KINDS = {
    pct   = true,   -- Prozentaenderung, z. B. 40 -> "+40%"
    mult  = true,   -- Faktor, z. B. 1.5 -> "x1.5"
    flat  = true,   -- absolute Aenderung, z. B. 20 -> "+20"
    -- Anzahl ohne Vorzeichen, z. B. 15 -> "15". Fuer Dinge, die man hat und
    -- nicht veraendert: freie Rezepte, bekannte Anbauzeiten.
    count = true,
    range = true,   -- Spanne, value = { min, max }
    -- Spanne einer Prozentaenderung, value = { von, bis }: "+13 to +16%". Mit
    -- Vorzeichen und damit gefaerbt wie pct (seit 0.12.6; Adrenaline Junkie
    -- stand als "13 to 16%" neutral neben einem gruenen "+8%").
    pctrange = true,
    -- Vorher/Nachher auf einer 0-100-Skala, value = { ohne, mit }: "from 5% to
    -- 10%". Fuer Wirkungen, die die Engine addiert statt multipliziert. Ein
    -- "+5%" waere dort falsch (relativ gelesen), "+5 Prozentpunkte" war
    -- richtig, aber eine zweite Prozent-Schreibweise im selben Tooltip.
    fromto = true,
    bool  = true,   -- ja/nein
    -- Wirkung ist belegt, laesst sich aber nicht beziffern: die Zeile besteht
    -- nur aus dem Text, ohne Wert. Sunday Driver etwa veraendert Zielwerte der
    -- Motordrehzahl in CharacterTraits - real, aber kein Prozentsatz. Lieber
    -- sagen, was passiert, als eine Zahl zu erfinden.
    info  = true,
}

local PREFIX = "[TraitFacts] "

function TF.log(msg)
    print(PREFIX .. tostring(msg))
end

function TF.warn(msg)
    print(PREFIX .. "WARN: " .. tostring(msg))
end

TF._warned = TF._warned or {}

--- Warnt genau einmal je Schluessel und Sitzung.
-- Die Hooks laufen bei jedem Oeffnen der Trait-Liste; ohne Drosselung wuerde
-- ein einzelner Fehler die Konsole fluten.
function TF.warnOnce(key, msg)
    if TF._warned[key] then return end
    TF._warned[key] = true
    TF.warn(msg)
end

TF._logged = TF._logged or {}

--- Schreibt genau einmal je Schluessel und Sitzung ins Log, ohne WARN.
-- Fuer Hinweise, die bei der Fehlersuche helfen, aber keine Stoerung sind
-- (die Aufteilung der vier Spalten). Als WARN stand das bis 0.1.20 bei jedem
-- Spielstart im Log, und eine echte Warnung ging daneben unter.
function TF.logOnce(key, msg)
    if TF._logged[key] then return end
    TF._logged[key] = true
    TF.log(msg)
end

--- Ruft fn geschuetzt auf und schluckt Fehler.
-- Oberste Anforderung der Mod: die Charaktererstellung darf niemals an uns
-- scheitern. Jeder Fehler wird einmalig geloggt, der Aufrufer bekommt nil und
-- faellt auf die unveraenderte Vanilla-Darstellung zurueck.
function TF.safe(context, fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    TF.warnOnce("err:" .. context, context .. " fehlgeschlagen: " .. tostring(result))
    return nil
end

--- Hook-Gesundheit (seit 0.12.2): jede unserer Huellen meldet, dass sie lief.
--
-- Ein anderer Mod, der dieselbe Vanilla-Funktion ersetzt, ohne das Original
-- zu rufen, schaltet uns stumm ab: kein Fehler, kein Log, nur fehlt etwas. Ob
-- eine Funktion "noch unsere" ist, laesst sich nicht vergleichen, sobald ein
-- dritter Mod sie sauber umhuellt hat; ob sie LIEF, schon. Wer die
-- Charaktererstellung offen hatte, hat create, prerender, render und
-- checkXPBoost durchlaufen. Fehlt davon eine, hat sie jemand ersetzt. Der Text
-- von "Fehler melden" nennt sie, der Mess-Mod prueft sie im Menue-Lauf.
TF._ran = TF._ran or {}
TF.HOOKS_EVERY_SCREEN = { "panel:create", "panel:prerender", "panel:render", "panel:checkXPBoost",
                          "populateTraitList", "populateBadTraitList" }

function TF.ran(key)
    TF._ran[key] = (TF._ran[key] or 0) + 1
end

--- @return table  Schluessel der Hooks, die jede offene Charaktererstellung
--                 durchlaeuft und die trotzdem nie liefen; leer, solange die
--                 Charaktererstellung noch nie offen war.
function TF.hooksNeverRun()
    local out, any = {}, false
    for _, key in ipairs(TF.HOOKS_EVERY_SCREEN) do
        if (TF._ran[key] or 0) > 0 then any = true end
    end
    if not any then return out end
    for _, key in ipairs(TF.HOOKS_EVERY_SCREEN) do
        if (TF._ran[key] or 0) == 0 then out[#out + 1] = key end
    end
    return out
end

--- @return table  was TF.safe seit dem Start abgefangen hat (Kontexte), sortiert
function TF.caughtErrors()
    local out = {}
    for key in pairs(TF._warned or {}) do
        if string.sub(key, 1, 4) == "err:" then out[#out + 1] = string.sub(key, 5) end
    end
    table.sort(out)
    return out
end

--- Normalisiert einen Namen zu einem Schluessel.
--
-- Kleingeschrieben und ohne Sonderzeichen: aus "Strong", "STRONG" und
-- "Very_Underweight" wird "strong" bzw. "veryunderweight". Damit ist es egal,
-- in welcher Schreibweise die Engine den Namen fuehrt - genau die Unsicherheit,
-- die in der SPEC noch offen stand.
--
-- Auch das Foraging-System fuehrt seine Traits unter eigenen Schreibweisen
-- ("WildernessKnowledge", "Herbalist_Prof"); nach der Normalisierung passen
-- beide Seiten aufeinander.
function TF.normalize(name)
    if name == nil then return nil end
    return (tostring(name):lower():gsub("[^%a%d]", ""))
end

--- Normalisierter Schluessel eines Traits, abgeleitet aus der Registry.
-- @param traitDef CharacterTraitDefinition
-- @return string|nil
function TF.traitKey(traitDef)
    if not traitDef then return nil end
    local ok, name = pcall(function() return traitDef:getType():getName() end)
    if not ok or not name then return nil end
    return TF.normalize(name)
end

--- Zerlegt eine rohe ID in Namensraum und Pfad, beide kleingeschrieben.
--
-- Voller Abgleich mit Endanker: nur "ns:pfad" ganz aus erlaubten Zeichen
-- zaehlt. Ein Stub-Typ ohne eigenes tostring liefert die Standard-Lua-
-- Darstellung "table: 0x...", und ohne den Endanker waere "table" darin
-- faelschlich ein Namensraum (das Leerzeichen danach passt nicht in die
-- erlaubte Zeichenklasse, der volle Abgleich lehnt es darum ab).
--
-- Eine Stelle fuer diese Regel: TF.traitId und TF_Live.traitNames muessen
-- bei derselben rohen ID auf denselben Namensraum kommen.
-- @return string|nil, string|nil  ns, pfad; beide nil, wenn raw nicht passt
function TF.parseTraitId(raw)
    if type(raw) ~= "string" then return nil end
    return string.match(string.lower(raw), "^([%w_%.%-]+):([%w_%.%-]+)$")
end

--- Volle ID eines Traits, kleingeschrieben: "base:strong", "toc:amputee_hand".
--
-- getName() liefert nur den Pfad (Registry.getLocation(...).getPath(), Bytecode
-- CharacterTrait.getName), toString() die volle ID. Ueber den Pfad allein trug
-- ein fremder "xyz:resilient" die Vanilla-Werte von Resilient (Spec
-- 2026-09-14-fremde-traits). Sieht toString nicht wie eine ID aus, gilt der
-- Namensraum base; so bleiben aeltere Engine-Fassungen und Stubs lauffaehig.
function TF.traitId(traitDef)
    if not traitDef then return nil end
    local ok, raw = pcall(function() return tostring(traitDef:getType()) end)
    if ok then
        local ns, path = TF.parseTraitId(raw)
        if ns then return ns .. ":" .. path end
    end
    local key = TF.traitKey(traitDef)
    return key and ("base:" .. key) or nil
end

--- Namensraum eines Traits ("base", "toc", ...), oder nil.
function TF.traitNamespace(traitDef)
    local id = TF.traitId(traitDef)
    return id and string.match(id, "^([^:]+):") or nil
end

--- Unsere hinterlegten Werte. Sie gelten nur fuer Vanilla (Namensraum base).
-- @return table  Liste von Eintraegen, leer fuer fremde Traits
function TF.staticFor(traitDef)
    if TF.traitNamespace(traitDef) ~= "base" then return {} end
    local key = TF.traitKey(traitDef)
    return (key and TF.Static and TF.Static[key]) or {}
end
