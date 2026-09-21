--- Trait Facts - Build als Text: kopieren und einfuegen.
--
-- Ein Build ist Beruf plus gekaufte Traits. Als eine Zeile Text laesst er
-- sich in Discord, Reddit oder eine Notiz legen und von dort wieder holen
-- (Wunsch 20.09.2026; jeder Web-Planer wirbt mit genau dem, Audit
-- 20.09.2026, Abschnitt 6).
--
--   TF=k3Pq0Zx81mWc4
--
-- Bis zur Veroeffentlichung ohne Formatnummer (Entscheidung 20.09.2026): es
-- gibt noch keine Texte in fremder Hand, also nichts, was eine Nummer
-- auseinanderhalten muesste. Mit dem Release wird daraus "TF1="; ein Text
-- mit Nummer gilt dieser Fassung deshalb schon jetzt als "braucht ein
-- neueres Trait Facts" und wird nicht geraten.
--
-- So kurz wie moeglich, lesbar muss es nicht sein (Wunsch 20.09.2026): nach
-- "TF=" je Eintrag drei Zeichen aus 0-9, A-Z, a-z, ohne
-- Trenner, zuerst der Beruf, dann die Traits. Die drei Zeichen sind eine
-- Pruefsumme der vollen Registry-ID ("base:strong", "toadtraits:problade"),
-- kein Platz in einer Liste: eine Liste aenderte sich mit jedem Patch und
-- jeder Mod-Liste, die Pruefsumme einer ID nie. Zehn Traits sind damit 37
-- Zeichen statt rund 100.
--
-- 238321 moegliche Werte auf ein paar hundert IDs: dass zwei dieselbe
-- Pruefsumme tragen, ist selten, aber moeglich. Beim Kopieren wird deshalb
-- gegen alle bekannten IDs geprueft; teilt sich eine ihre Pruefsumme mit
-- einer anderen, steht sie ausgeschrieben in Klammern im Text, "(ns:pfad)".
--
-- Was aus einem Mod stammt, steht hinter der Kennung seines Mods in eckigen
-- Klammern, einmal je Mod, die Eintraege selbst bleiben Pruefsummen (Wunsch
-- 20.09.2026):
--
--   TF=dlgWSK[moreTraitsDefinitive]a1Bc2D
--
-- Die Klammer gilt fuer alles, was folgt, bis zur naechsten; "[]" schaltet
-- zurueck auf Vanilla (noetig nur, wenn schon der Beruf aus einem Mod kommt).
-- Zum Einfuegen braucht es sie nicht, die Pruefsumme steht fuer die volle ID.
-- Sie ist fuer den Fall da, dass das Mod fehlt: dann passt die Pruefsumme auf
-- keine ID dieses Spiels, der Rest des Builds wird trotzdem gesetzt, und der
-- Hinweis nennt das fehlende Mod beim Namen aus der Klammer. Die Kennung ist
-- die Mod-ID, nach der man im Workshop und in der Mod-Liste sucht; kennt
-- Trait Facts zum Namensraum kein Mod, steht dort der Namensraum. Ein Trait,
-- den es gibt, der aber von einem anderen des Builds ausgeschlossen wird,
-- steht weiter mit seinem Namen im Hinweis.
--
-- Hinter der Mod-ID steht, mit "#" getrennt, die Workshop-ID des Mods, wenn
-- es aus dem Workshop kommt: "[moreTraitsDefinitive#3799050151]". Fehlt das
-- Mod beim Einfuegen, oeffnet sich ein kleines Fenster mit einem Knopf je
-- fehlendem Mod, der dessen Workshop-Seite aufschlaegt (Wunsch 20.09.2026);
-- ohne Workshop-ID fuehrt er auf die Workshop-Suche nach der Mod-ID.
--
-- Gelesen wird auch eine Zeile ganz ohne Kopf: volle IDs mit ";" getrennt,
-- "base:" darf fehlen. Das ist, was Vanilla in saved_builds.txt ablegt
-- ("fireofficer;Strong;Brave;"). Gross- und Kleinschreibung zaehlen dort
-- nicht, in den Pruefsummen schon. Vom Beruf gewaehrte Traits stehen nicht im
-- Text: die bringt der Beruf beim Einfuegen selbst mit, wie bei Vanillas
-- gespeicherten Builds (saveBuildStep2, isFree).
--
-- Eingefuegt wird auf Vanillas eigenem Weg (loadBuild): resetBuild, Beruf
-- waehlen, dann jeden Trait in seiner Vorratsliste markieren und ueber
-- onOptionMouseDown hinzufuegen. Damit gelten Ausschluesse und Punkte wie von
-- Hand; ein Trait, den ein anderer des Builds ausschliesst oder den es in
-- dieser Mod-Liste nicht gibt, bleibt weg und wird genannt.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF.Build = TF.Build or {}

local PREFIX = "TF="

local DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
-- Groesste Primzahl unter 62^3, damit jede Pruefsumme in drei Zeichen passt.
local MODULUS = 238321

--- Drei Zeichen zu einer ID. Ohne Bit-Operationen, die Kahlua nicht hat;
-- die Zwischenwerte bleiben weit unter 2^53.
function TF.Build.code(id)
    local h = 7
    for i = 1, #id do
        h = (h * 131 + string.byte(id, i)) % MODULUS
    end
    local out = ""
    for _ = 1, 3 do
        local d = h % 62
        out = string.sub(DIGITS, d + 1, d + 1) .. out
        h = (h - d) / 62
    end
    return out
end

--- Volle ID einer Berufs- oder Trait-Definition, kleingeschrieben.
-- Fuer Berufe gilt dasselbe wie fuer Traits: CharacterProfession.toString ist
-- im Bytecode von 42.20.4 Registries.CHARACTER_PROFESSION.getLocation(this)
-- .toString(), also "base:fireofficer" (nachgesehen 20.09.2026 mit
-- tools/jar-disassemble.py, Befehl fuer Befehl gleich CharacterTrait.toString).
local function fullId(def)
    if not def then return nil end
    local id = TF.traitId(def)
    if id then return id end
    local ok, name = pcall(function() return def:getType():getName() end)
    if ok and name then return "base:" .. string.lower(tostring(name)) end
    return nil
end

--- "base:strong" -> "strong"; alles andere bleibt.
local function short(id)
    if string.sub(id, 1, 5) == "base:" then return string.sub(id, 6) end
    return id
end

--- "strong" -> "base:strong"; " ToadTraits:ProBlade " -> "toadtraits:problade".
local function long(word)
    local w = string.lower((string.gsub(word, "%s", "")))
    if w == "" then return nil end
    if not string.find(w, ":", 1, true) then w = "base:" .. w end
    return w
end

--- Der Build eines Bildschirms als Text.
-- @return string|nil
function TF.Build.export(screen)
    if not (screen and screen.getSelectedProf) then return nil end
    local prof = fullId(screen:getSelectedProf())
    if not prof then return nil end
    local codes = TF.Build.codes(screen)
    local function piece(id)
        local code = TF.Build.code(id)
        local owners = codes[code]
        -- Eindeutig, oder gar nicht bekannt (dann gibt es nichts, womit sie
        -- zu verwechseln waere): die Pruefsumme. Sonst ausgeschrieben.
        if owners and #owners > 1 then return "(" .. id .. ")" end
        return code
    end
    -- Vanilla zuerst, danach je Mod eine Gruppe, in der Reihenfolge, in der
    -- die Mods in der Auswahl auftauchen.
    local vanilla, groups, order = {}, {}, {}
    local chosen = screen.listboxTraitSelected
    -- Nach ID sortiert, nicht in der Reihenfolge der Liste: die haengt an der
    -- Reihenfolge des Anklickens und an der Sprache des Spiels. Derselbe
    -- Build soll immer denselben Text ergeben (Test im Spiel 20.09.2026:
    -- Strong und Brave standen vertauscht).
    local ids = {}
    for _, item in ipairs((chosen and chosen.items) or {}) do
        local def = item.item
        local okFree, free = pcall(function() return def:isFree() end)
        if def and not (okFree and free) then
            local id = fullId(def)
            if id then ids[#ids + 1] = id end
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local label = TF.Build.modLabel(id)
        if label == "" then
            vanilla[#vanilla + 1] = piece(id)
        else
            if not groups[label] then
                groups[label] = {}
                order[#order + 1] = label
            end
            table.insert(groups[label], piece(id))
        end
    end
    table.sort(order)
    local out = PREFIX
    local profLabel = TF.Build.modLabel(prof)
    if profLabel ~= "" then out = out .. "[" .. profLabel .. "]" end
    out = out .. piece(prof)
    -- Die Eintraege des Mods, aus dem der Beruf kommt, gleich dahinter: das
    -- spart eine zweite Klammer.
    if groups[profLabel] then
        out = out .. table.concat(groups[profLabel])
        groups[profLabel] = nil
    end
    if #vanilla > 0 then
        if profLabel ~= "" then out = out .. "[]" end
        out = out .. table.concat(vanilla)
    end
    for _, label in ipairs(order) do
        if groups[label] then out = out .. "[" .. label .. "]" .. table.concat(groups[label]) end
    end
    return out
end

--- Wie das Mod einer ID im Text heisst: seine Mod-ID, sonst der Namensraum;
-- "" fuer Vanilla. Nur Zeichen, die in der Klammer nichts durcheinander
-- bringen.
function TF.Build.modLabel(id)
    local ns = string.match(id, "^([^:]+):")
    if not ns or ns == "base" then return "" end
    local label = ns
    local mod = TF.Mods and TF.Mods.modFor and TF.safe("build:mod", TF.Mods.modFor, ns) or nil
    local workshop = nil
    if mod and mod.id then
        label = tostring(mod.id)
        -- Wie TF.Panel.workshopId: nur Mods aus dem Workshop haben eine.
        local ok, id = pcall(function() return getModInfoByID(mod.id):getWorkshopID() end)
        if ok and id ~= nil and string.match(tostring(id), "^%d+$") then workshop = tostring(id) end
    end
    label = string.gsub(label, "[^%w_%.%-]", "")
    if label == "" then label = "mod" end
    if workshop then label = label .. "#" .. workshop end
    return label
end

--- Wohin der Knopf zu einem fehlenden Mod fuehrt: seine Workshop-Seite, ohne
-- Workshop-ID die Workshop-Suche nach seiner Kennung (App 108600).
function TF.Build.modUrl(label)
    local name, workshop = string.match(label, "^([^#]*)#(%d+)$")
    if workshop then
        return "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. workshop, name, workshop
    end
    -- Der Name kommt aus dem eingefuegten Text: fuer die Adresse nur die
    -- Zeichen, die modLabel beim Export auch durchlaesst.
    local clean = string.gsub(label, "[^%w_%.%-]", "")
    return "https://steamcommunity.com/workshop/browse/?appid=108600&searchtext=" .. clean, clean
end

--- Alle bekannten IDs je Pruefsumme: die Berufe und Traits der Listen des
-- Bildschirms und alle Traits der Registry. Die Listen allein reichen nicht,
-- ein ausgeschlossener Trait steht in keiner von ihnen.
-- @return table  Pruefsumme -> Liste von IDs
function TF.Build.codes(screen)
    local codes, seen = {}, {}
    local function add(def)
        local id = fullId(def)
        if id and not seen[id] then
            seen[id] = true
            local code = TF.Build.code(id)
            codes[code] = codes[code] or {}
            table.insert(codes[code], id)
        end
    end
    for _, name in ipairs({ "listboxProf", "listboxTrait", "listboxBadTrait", "listboxTraitSelected" }) do
        local list = screen and screen[name]
        for _, item in ipairs((list and list.items) or {}) do
            if item and item.item then pcall(add, item.item) end
        end
    end
    pcall(function()
        local all = CharacterTraitDefinition.getTraits()
        for i = 0, all:size() - 1 do pcall(add, all:get(i)) end
    end)
    return codes
end

--- Passt eine ID zu der Klammer, hinter der ihr Eintrag steht?
--
-- Die Pruefsumme allein reicht nicht (Bugjagd 20.09.2026): fehlt beim
-- Empfaenger das Mod, kann dessen Pruefsumme zufaellig auf eine seiner
-- anderen IDs passen, und es stuende still ein falscher Trait da. Hart ist
-- die Grenze Vanilla gegen Mod: ohne Klammer kommen nur base-IDs in Frage,
-- hinter einer Klammer nie. Innerhalb der Mods gilt Mod-ID oder Namensraum,
-- ohne "#..." und ohne Gross- und Kleinschreibung, denn Absender und
-- Empfaenger beschriften dasselbe Mod verschieden, je nachdem, ob Trait
-- Facts es zuordnen konnte ("toadtraits" gegen "moreTraitsDefinitive#123").
local function fits(id, label)
    local ns = string.match(id, "^([^:]+):") or "base"
    if label == "" then return ns == "base" end
    if ns == "base" then return false end
    local want = string.lower((string.gsub(label, "#.*$", "")))
    if string.lower(ns) == want then return true end
    local own = string.lower((string.gsub(TF.Build.modLabel(id), "#.*$", "")))
    return own == want
end

--- Die Beschriftung zu einer ausgeschriebenen ID aus eingefuegtem Text, vor
-- der keine Klammer steht.
--
-- TF.Build.modLabel fragt TF.Mods.modFor, und das legt zu jedem Namensraum
-- einen Eintrag samt Kuerzel in den sitzungsweiten Mod-Speicher. Fuer IDs aus
-- dem Spiel ist das richtig, fuer Text aus der Zwischenablage nicht (Bugjagd
-- 20.09.2026): "TF=dlg(foo:bar)" legte ein Phantom-Mod "foo" an, das im
-- Fehlerbericht stand und die Farbraenge der Kuerzel verschob. Deshalb geht
-- nur ein Namensraum, den dieses Spiel schon kennt, durch modLabel; jeder
-- andere wird nur gelesen und gesaeubert wie dort.
local function labelFromText(inner, codes)
    local ns = string.match(inner, "^([^:]+):")
    if not ns or ns == "base" then return "" end
    for _, ids in pairs(codes) do
        for _, id in ipairs(ids) do
            if string.match(id, "^([^:]+):") == ns then return TF.Build.modLabel(inner) end
        end
    end
    ns = string.gsub(ns, "[^%w_%.%-]", "")
    if ns == "" then ns = "mod" end
    return ns
end

--- Zerlegt den Rumpf hinter "TF=" in IDs. Nachsichtig: ein Text, der durch
-- einen Chat gegangen ist, kommt selten heil an.
--
--   - eine offene "[" am Ende (abgeschnitten) zaehlt als Ende des Textes;
--   - bleiben am Ende ein oder zwei Zeichen uebrig, ist das ein Eintrag, der
--     sich nicht lesen laesst, kein Grund, den Rest zu verwerfen;
--   - eine unbekannte Pruefsumme steht als "?" plus dem Mod aus der Klammer
--     in der Liste, fuer den Hinweis; ebenso eine ausgeschriebene ID
--     "(ns:pfad)", die es in diesem Spiel nicht gibt (Bugjagd 20.09.2026:
--     sie galt sonst als "ausgeschlossen" statt als fehlendes Mod).
-- @return table  Liste der IDs, moeglicherweise leer
-- @return number wie viele davon unlesbar sind ("?...")
local function decode(body, codes)
    local words, at, label, unreadable = {}, 1, "", 0
    local function push(word)
        words[#words + 1] = word
        if string.sub(word, 1, 1) == "?" then unreadable = unreadable + 1 end
    end
    while at <= #body do
        local ch = string.sub(body, at, at)
        if ch == "[" then
            local close = string.find(body, "]", at, true)
            if not close then break end
            label = string.sub(body, at + 1, close - 1)
            at = close + 1
        elseif ch == "(" then
            local close = string.find(body, ")", at, true)
            -- Ohne schliessende Klammer ist es der Rest des Textes.
            local inner = string.lower(string.sub(body, at + 1, (close or (#body + 1)) - 1))
            if inner ~= "" then
                local known = false
                for _, id in ipairs(codes[TF.Build.code(inner)] or {}) do
                    if id == inner then known = true end
                end
                if known then
                    push(inner)
                else
                    push("?" .. (label ~= "" and label or labelFromText(inner, codes)))
                end
            end
            at = (close or #body) + 1
        elseif ch == "]" or ch == ")" then
            at = at + 1
        else
            local code = string.match(string.sub(body, at, at + 2), "^%w+") or ""
            if #code == 3 then
                -- Nur IDs, die zur Klammer passen. Bleibt genau eine, ist sie
                -- es; keine oder mehrere lassen sich nicht sicher zuordnen.
                local hits = {}
                for _, id in ipairs(codes[code] or {}) do
                    if fits(id, label) then hits[#hits + 1] = id end
                end
                push(#hits == 1 and hits[1] or ("?" .. label))
                at = at + 3
            else
                -- Ein angebrochener Eintrag vor einer Klammer oder am Ende.
                push("?")
                at = at + math.max(1, #code)
            end
        end
    end
    return words, unreadable
end

--- Einmal jede ID, in der Reihenfolge des Textes; unlesbare Eintraege ("?...")
-- bleiben einzeln stehen, sie werden gezaehlt.
local function unique(words)
    local traits, seen = {}, {}
    for i = 2, #words do
        local unknown = string.sub(words[i], 1, 1) == "?"
        if unknown or not seen[words[i]] then
            seen[words[i]] = true
            traits[#traits + 1] = words[i]
        end
    end
    return { prof = words[1], traits = traits }
end

--- Zerlegt einen Text in Beruf und Traits.
--
-- Gelesen wird, was sich irgendwie lesen laesst (Wunsch 20.09.2026):
-- Leerzeichen und Zeilenumbrueche an beliebiger Stelle, Anfuehrungszeichen,
-- Backticks, Sternchen und spitze Klammern aus Chat und Markdown, Text vor
-- dem Kopf ("my build: TF=..."), "tf = ..." und "TF:..." statt "TF=...",
-- Satzzeichen am Ende, ein abgeschnittenes Ende, und die Pruefsummen ganz
-- ohne Kopf. Was sich nicht retten laesst, bekommt einen Grund:
--   "empty"    nichts in der Zwischenablage
--   "invalid"  kein Build zu erkennen
--   "damaged"  ein Build, aber mit Zeichen mittendrin, die nicht hineingehoeren;
--              stillschweigend weglassen verschoebe die Dreiergruppen, und es
--              kaemen falsche Traits heraus
--   "newer"    ein Kopf mit Formatnummer
-- @return table|nil  { prof = "base:...", traits = { "base:...", ... } }
-- @return string|nil der Grund, wenn nichts Brauchbares dasteht
function TF.Build.parse(text, screen)
    if type(text) ~= "string" then return nil, "empty" end
    local s = string.gsub(text, "[%c\"'`%*<>]", " ")
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    if s == "" then return nil, "empty" end
    if #s > 4000 then return nil, "invalid" end

    -- Der Kopf, wo immer er steht; davor darf beliebiger Text stehen. Das
    -- Zeichen vor "TF" darf kein Buchstabe sein, sonst faende sich der Kopf
    -- mitten in einem Wort.
    local version, rest
    local from = 1
    while true do
        local a, b, v = string.find(s, "[Tt][Ff]%s*(%d*)%s*[=:]", from)
        if not a then break end
        if a == 1 or not string.find(string.sub(s, a - 1, a - 1), "%a") then
            version, rest = v, string.sub(s, b + 1)
            break
        end
        from = b + 1
    end

    if version then
        -- Eine Nummer traegt erst das Format der Veroeffentlichung.
        if version ~= "" then return nil, "newer" end
        -- Der Export schreibt nie Leerraum. Steht welcher im Text, ist es
        -- ein Zeilenumbruch des Chats mitten im Code, oder dahinter geht der
        -- Satz weiter ("TF=dlgWSK1Rj, try it"). Deshalb stueckweise: das
        -- erste Stueck zaehlt immer und wird streng geprueft; jedes weitere
        -- nur, wenn es den Code fortsetzt, also kein fremdes Zeichen traegt
        -- und die Zahl der unlesbaren Eintraege nicht erhoeht. Beim ersten,
        -- das das nicht tut, ist der Code zu Ende, und der Rest ist Prosa
        -- (Bugjagd 20.09.2026: sie galt als "beschaedigt" oder zaehlte als
        -- unlesbare Eintraege). "dlgWS" + "K1Rj" heilt so weiter (unlesbar
        -- 1 -> 0), "try" an einem heilen Code beendet ihn (0 -> 1).
        local codes = TF.Build.codes(screen)
        local body, unreadable
        local at = 1
        while true do
            local a, b = string.find(rest, "%S+", at)
            if not a then break end
            -- Satzzeichen am Ende gehoeren zum Satz drumherum.
            local piece = string.gsub(string.sub(rest, a, b), "[^%w%]%)]+$", "")
            local foreign = string.find(piece, "[^%w_%.%-:#%(%)%[%]]") ~= nil
            if body == nil then
                if piece ~= "" then
                    if foreign then return nil, "damaged" end
                    body = piece
                    local _, n = decode(body, codes)
                    unreadable = n
                end
            else
                if foreign or piece == "" then break end
                local _, n = decode(body .. piece, codes)
                if n > unreadable then break end
                body, unreadable = body .. piece, n
            end
            at = b + 1
        end
        if not body then return nil, "invalid" end
        local words = decode(body, codes)
        if #words == 0 then return nil, "invalid" end
        -- Laesst sich kein einziger Eintrag lesen, ist der Text kaputt; die
        -- Auswahl dafuer zu leeren, waere das Falsche.
        local readable = false
        for _, word in ipairs(words) do
            if string.sub(word, 1, 1) ~= "?" then readable = true end
        end
        if not readable then return nil, "damaged" end
        return unique(words)
    end

    -- Ohne Kopf: zuerst als Liste voller IDs, wie Vanilla sie ablegt
    -- ("fireofficer;Strong;Brave;").
    local codes = TF.Build.codes(screen)
    -- Der Name eines gespeicherten Builds darf alles enthalten; geprueft wird,
    -- was nach ihm kommt.
    local checked = s
    local nameEnd = string.find(s, ":", 1, true)
    local listStart = string.find(s, "[;,]")
    -- Ist der erste Eintrag samt seinem ":" schon eine bekannte ID
    -- ("toadtraits:drifter;strong"), ist das davor ein Namensraum, kein Name.
    local firstWhole = listStart and long(string.sub(s, 1, listStart - 1)) or nil
    local firstKnown = false
    for _, owners in pairs(codes) do
        for _, known in ipairs(owners) do
            if known == firstWhole then firstKnown = true end
        end
    end
    if nameEnd and listStart and nameEnd < listStart and not firstKnown then
        checked = string.sub(s, nameEnd + 1)
    end
    if string.find(checked, "[^%w_%.%-:;,%s]") then return nil, "invalid" end
    if checked ~= s then
        -- Nur wenn der Rest wirklich mit einem Beruf beginnt, ist das davor
        -- ein Name und kein Namensraum.
        local head = string.match(checked, "^%s*([^;,]+)")
        local id = head and long(head)
        local okHead = false
        for _, owners in pairs(codes) do
            for _, known in ipairs(owners) do
                if known == id then okHead = true end
            end
        end
        if id and not okHead then
            local path = string.match(id, "^base:(.+)$")
            for _, owners in pairs(codes) do
                for _, known in ipairs(owners) do
                    if path and string.match(known, ":(.+)$") == path then okHead = true end
                end
            end
        end
        -- Ein Mod-Beruf mit Namensraum vorn ("toadtraits:drifter;strong")
        -- geht denselben Weg: sein Pfad findet ihn unten wieder.
        if okHead then s = checked end
        if string.find(s, "[^%w_%.%-:;,%s]") then return nil, "invalid" end
    end
    if not string.find(s, "[;,:]") then
        -- Kein Trenner: vielleicht die Pruefsummen ohne ihren Kopf. Nur, wenn
        -- der Beruf darin zu erkennen ist; sonst ist es irgendein Wort.
        local body = string.gsub(s, "%s", "")
        if #body >= 3 then
            local words = decode(body, codes)
            if #words > 0 and string.sub(words[1], 1, 1) ~= "?" then return unique(words) end
        end
    end
    -- Alle bekannten IDs, und je Pfad die IDs, die ihn tragen: Vanilla legt
    -- in saved_builds.txt nur getName() ab, also den Pfad ohne Namensraum.
    -- "problade" ist dort ein Trait von More Traits, und Vanillas loadBuild
    -- laedt ihn; als "base:problade" gelesen galt er als nicht vorhanden
    -- (Bugjagd 20.09.2026).
    local knownIds, byPath = {}, {}
    for _, owners in pairs(codes) do
        for _, id in ipairs(owners) do
            knownIds[id] = true
            local path = string.match(id, ":(.+)$")
            if path then
                byPath[path] = byPath[path] or {}
                table.insert(byPath[path], id)
            end
        end
    end
    local function split(text)
        local words, at = {}, 1
        while true do
            local a, b = string.find(text, "[^;,]+", at)
            if not a then break end
            local id = long(string.sub(text, a, b))
            if id then
                -- Ohne Namensraum im Text: erst Vanilla, sonst der eine
                -- Mod-Trait dieses Pfads. Bei zweien wird nicht geraten.
                local path = string.match(id, "^base:(.+)$")
                local plain = not string.find(string.sub(text, a, b), ":", 1, true)
                if plain and path and not knownIds[id] and byPath[path] and #byPath[path] == 1 then
                    id = byPath[path][1]
                end
                words[#words + 1] = id
            end
            at = b + 1
        end
        return words
    end
    local words = split(s)
    if #words == 0 then return nil, "invalid" end
    -- Eine ganze Zeile aus saved_builds.txt traegt den Namen des Builds vorn
    -- ("Lumberjack:lumberjack;strong;"). Ist der erste Eintrag unbekannt und
    -- steht ein ":" darin, gilt, was dahinter kommt (Bugjagd 20.09.2026).
    if not knownIds[words[1]] then
        local colon = string.find(s, ":", 1, true)
        local firstEnd = string.find(s, "[;,]") or (#s + 1)
        if colon and colon < firstEnd then
            local retry = split(string.sub(s, colon + 1))
            if #retry > 0 and knownIds[retry[1]] then words = retry end
        end
    end
    -- Eine Liste ist es nur, wenn ihr erster Eintrag ein Beruf ist, den es
    -- gibt: sonst loeschte jeder kopierte Satz ohne Sonderzeichen die Auswahl.
    if not knownIds[words[1]] then return nil, "invalid" end
    -- Beginnt die Liste mit einem Trait statt mit einem Beruf ("Strong;Brave"),
    -- sind es nur Traits: der Beruf bleibt, wie resetBuild ihn setzt.
    local isProf = false
    for _, item in ipairs((screen and screen.listboxProf and screen.listboxProf.items) or {}) do
        if item and item.item and fullId(item.item) == words[1] then isProf = true end
    end
    if not isProf then table.insert(words, 1, false) end
    local build = unique(words)
    if build.prof == false then build.prof = nil end
    return build
end

local function findIn(list, id)
    for index, item in ipairs((list and list.items) or {}) do
        if item and item.item and fullId(item.item) == id then return index end
    end
    return nil
end

--- Setzt den Build auf dem Bildschirm.
-- @return table  { missing = { Kennungen, die nicht gesetzt werden konnten } }
function TF.Build.apply(screen, build)
    -- missing: gibt es hier, liess sich aber nicht setzen (ausgeschlossen).
    -- unknown: eine Pruefsumme, zu der dieses Spiel keine ID kennt, also der
    -- Trait oder Beruf eines Mods, das hier fehlt.
    -- mods: je fehlendem Mod, wie viele Eintraege es betrifft.
    local missing, unknown, mods, modOrder = {}, 0, {}, {}
    local function lost(id)
        if string.sub(id, 1, 1) == "?" then
            local label = string.sub(id, 2)
            if label == "" then
                unknown = unknown + 1
            else
                if not mods[label] then
                    mods[label] = 0
                    modOrder[#modOrder + 1] = label
                end
                mods[label] = mods[label] + 1
            end
        else
            missing[#missing + 1] = short(id)
        end
    end
    screen:resetBuild()
    local profIndex = build.prof and findIn(screen.listboxProf, build.prof) or nil
    if not build.prof then
        -- Eine Liste nur aus Traits: kein Beruf verlangt, keiner vermisst.
    elseif profIndex then
        screen.listboxProf.selected = profIndex
        screen:onSelectProf(screen:getSelectedProf())
        -- Die Liste zeigt sonst weiter ihren Anfang, und der geladene Beruf
        -- steht irgendwo darunter (Bildschirmlauf 20.09.2026).
        if screen.listboxProf.ensureVisible then
            pcall(function() screen.listboxProf:ensureVisible(profIndex) end)
        end
    else
        lost(build.prof)
    end
    local lists = {
        { box = screen.listboxTrait, internal = "ADDTRAIT", button = screen.addTraitBtn },
        { box = screen.listboxBadTrait, internal = "ADDBADTRAIT", button = screen.addBadTraitBtn },
    }
    for _, id in ipairs(build.traits) do
        local done = false
        -- Schon da, weil der Beruf ihn gewaehrt: kein Fehlbestand.
        if findIn(screen.listboxTraitSelected, id) then done = true end
        for _, entry in ipairs(lists) do
            if not done then
                -- Jedes Mal neu suchen: nach jedem Hinzufuegen baut Vanilla
                -- die Vorratslisten um (der Trait und seine Ausschluesse
                -- fallen heraus).
                local index = findIn(entry.box, id)
                if index then
                    entry.box.selected = index
                    screen:onOptionMouseDown(entry.button or { internal = entry.internal })
                    done = findIn(screen.listboxTraitSelected, id) ~= nil
                end
            end
        end
        if not done then lost(id) end
    end
    if screen.checkXPBoost then screen:checkXPBoost() end
    local modList, modLinks = {}, {}
    for _, label in ipairs(modOrder) do
        local url, name, workshop = TF.Build.modUrl(label)
        modList[#modList + 1] = name .. " (" .. mods[label] .. ")"
        modLinks[#modLinks + 1] = { name = name, url = url, count = mods[label], workshop = workshop }
    end
    return { missing = missing, unknown = unknown, mods = modList, links = modLinks }
end

local function openUrl_(url)
    if isSteamOverlayEnabled and isSteamOverlayEnabled() and activateSteamOverlayToWebPage then
        activateSteamOverlayToWebPage(url)
    elseif openUrl then
        openUrl(url)
    end
end

--- Schliesst das Fenster der fehlenden Mods. @return boolean  ob eines offen war
function TF.Build.closeMissing(screen)
    local popup = screen and screen.tfMissingPopup
    if not popup then return false end
    screen.tfMissingPopup = nil
    popup:setVisible(false)
    if popup.tfTopLevel and popup.removeFromUIManager then
        popup:removeFromUIManager()
    elseif screen.removeChild then
        screen:removeChild(popup)
    end
    return true
end

--- Das Fenster nach dem Einfuegen, wenn Mods fehlen: je Mod eine Zeile mit
-- Namen, Zahl der betroffenen Eintraege und einem Knopf zu seiner
-- Workshop-Seite. Gebaut wie das Zahnrad-Fenster (TF_Panel), unter dem Knopf
-- "Build einfuegen". Es bleibt stehen, bis man es schliesst: der Hinweis im
-- Panel verschwindet nach fuenf Sekunden, und bis dahin hat niemand einen
-- Link angeklickt.
function TF.Build.showMissing(screen, links, extra)
    TF.Build.closeMissing(screen)
    if not (ISPanel and ISButton and screen and screen.addChild) or #links == 0 then return nil end
    local font = UIFont.Small
    local manager = getTextManager and getTextManager()
    local lh = (manager and manager.getFontHeight and manager:getFontHeight(font)) or 19
    local pad, rowH = 10, lh + 8
    local title = TF.fmt.text("UI_TF_build_missing_title")
    local lead = TF.fmt.text("UI_TF_build_missing_lead")
    local BADGE = lh + 4
    local rows, textW, buttonW = {}, math.max(TF.fmt.measure(title, font) + BADGE + 8, TF.fmt.measure(lead, font)), 0
    -- Was der Hinweis sonst noch gemeldet haette (ausgeschlossene oder
    -- unlesbare Eintraege), steht hier im Fenster: geht es auf, erscheint
    -- kein eigener Hinweis mehr, die beiden lagen uebereinander und sagten
    -- dasselbe (Mockup-Durchsicht 20.09.2026).
    local extraLines = {}
    if type(extra) == "string" and extra ~= "" and TF.Panel and TF.Panel.wrapToast then
        extraLines = TF.Panel.wrapToast(extra, math.max(textW + 16 + 120, 360), font)
        for _, line in ipairs(extraLines) do textW = math.max(textW, TF.fmt.measure(line, font) - 16 - 120) end
    end
    for i, link in ipairs(links) do
        if i > 8 then break end
        local text = TF.fmt.text(link.count == 1 and "UI_TF_build_missing_row_one" or "UI_TF_build_missing_row",
            link.name, tostring(link.count))
        -- Name und Workshop-ID stammen beide aus dem eingefuegten Text. Die ID
        -- steht deshalb dabei: wohin der Knopf fuehrt, soll man sehen, bevor
        -- man ihn drueckt (Bugjagd 20.09.2026: ein praeparierter Text koennte
        -- eine fremde Seite mit einem vertrauten Namen beschriften).
        if link.workshop then text = text .. " " .. TF.fmt.text("UI_TF_build_missing_id", link.workshop) end
        local caption = TF.fmt.text(link.workshop and "UI_TF_build_missing_open" or "UI_TF_build_missing_search")
        rows[#rows + 1] = { text = text, caption = caption, url = link.url }
        textW = math.max(textW, TF.fmt.measure(text, font))
        buttonW = math.max(buttonW, TF.fmt.measure(caption, font) + 24)
    end
    local closeText = TF.fmt.text("UI_TF_opt_close")
    local closeW = TF.fmt.measure(closeText, font) + 24
    pad = 14
    local w = pad + textW + 16 + buttonW + pad
    local top = pad + BADGE + 6 + lh + 10
    local extraTop = top + #rows * (rowH + 4) + 4
    local h = extraTop + #extraLines * lh + (#extraLines > 0 and 6 or 0) + 2 + lh + 6 + pad
    local popup = ISPanel:new(0, 0, w, h)
    popup:initialise()
    -- Als Warnung zu erkennen (Test im Spiel 20.09.2026: "nicht als Fehler
    -- erkennbar"): Rahmen und Titel in der Warnfarbe der Mod, davor ein
    -- Kaestchen mit "!". Darunter ein Satz, was geladen wurde und was fehlt.
    local o = (TF.fmt.rgb and TF.fmt.rgb.stale) or { 0.88, 0.63, 0.31 }
    -- Deckend: durch 0.98 schien der Text der Listen darunter durch.
    popup.backgroundColor = { r = 0.03, g = 0.03, b = 0.03, a = 1 }
    popup.borderColor = { r = o[1], g = o[2], b = o[3], a = 1 }
    local baseRender = popup.render
    popup.render = function(p)
        if baseRender then baseRender(p) end
        p:drawRectBorder(1, 1, w - 2, h - 2, 1, o[1], o[2], o[3])
        if TF.Panel and TF.Panel.drawBadge then
            TF.Panel.drawBadge(p, pad, pad, BADGE, "warn")
        else
            p:drawRect(pad, pad, BADGE, BADGE, 1, o[1], o[2], o[3])
            p:drawText("!", pad + (BADGE - TF.fmt.measure("!", font)) / 2, pad + 2, 0.05, 0.03, 0, 1, font)
        end
        p:drawText(title, pad + BADGE + 8, pad + 2, o[1], o[2], o[3], 1, font)
        p:drawText(lead, pad, pad + BADGE + 6, 0.62, 0.62, 0.62, 1, font)
        for i, row in ipairs(rows) do
            p:drawText(row.text, pad, top + (i - 1) * (rowH + 4) + 4, 0.85, 0.85, 0.85, 1, font)
        end
        for i, line in ipairs(extraLines) do
            p:drawText(line, pad, extraTop + (i - 1) * lh, 0.62, 0.62, 0.62, 1, font)
        end
    end
    -- Ein eigenes Fenster ganz oben, kein Kind des Bildschirms (Bildschirmlauf
    -- 20.09.2026): Vanilla zeichnet seine Beschriftungen ("Major Skills") in
    -- render, also nach den Kindern, und die Schrift stand ueber dem Fenster.
    -- So macht es Vanilla selbst mit seinen Rueckfragen (ISModalDialog:
    -- addToUIManager, setAlwaysOnTop). Ohne UI-Manager (Test) bleibt es ein Kind.
    if popup.addToUIManager then
        popup:addToUIManager()
        if popup.setAlwaysOnTop then popup:setAlwaysOnTop(true) end
        popup.tfTopLevel = true
    else
        screen:addChild(popup)
    end
    for i, row in ipairs(rows) do
        local b = ISButton:new(w - pad - buttonW, top + (i - 1) * (rowH + 4), buttonW, rowH, row.caption, screen,
            function() TF.safe("build:open", openUrl_, row.url) end)
        b:initialise()
        popup:addChild(b)
    end
    local close = ISButton:new(w - pad - closeW, h - pad - lh - 6, closeW, lh + 6, closeText, screen,
        function(target) TF.Build.closeMissing(target) end)
    close:initialise()
    popup:addChild(close)
    -- Mittig im Bildschirm (Test im Spiel 20.09.2026: unter dem Knopf in der
    -- Ecke ging es unter), und je Bild neu ausgerichtet, damit es einer
    -- geaenderten Fenstergroesse folgt. Bis 0.12.0 hing es unter dem
    -- Einfuegen-Knopf, der in der schmalen Anordnung verschwinden kann
    -- (Bugjagd 20.09.2026).
    local function place(pop)
        -- Als eigenes Fenster in Bildschirmkoordinaten, als Kind in denen des
        -- Bildschirms; die Charaktererstellung fuellt den ganzen Bildschirm
        -- nicht immer aus (Vanilla: 75 % der Breite, mindestens 768 px).
        local core = pop.tfTopLevel and getCore and getCore() or nil
        local sw = core and core:getScreenWidth() or (screen.getWidth and screen:getWidth()) or (w + 16)
        local sh = core and core:getScreenHeight() or (screen.getHeight and screen:getHeight()) or (h + 16)
        local x, y = (sw - w) / 2, (sh - h) / 2
        if x + w > sw - 8 then x = sw - 8 - w end
        if y + h > sh - 8 then y = sh - 8 - h end
        pop:setX(math.max(4, math.floor(x)))
        pop:setY(math.max(4, math.floor(y)))
    end
    local basePrerender = popup.prerender
    popup.prerender = function(pop)
        -- Als eigenes Fenster ueberlebte es sonst den Bildschirm: mit "Back"
        -- oder "Next" verschwindet die Charaktererstellung, das Fenster geht mit.
        local alive = true
        if pop.tfTopLevel and screen.isReallyVisible then
            local ok, visible = pcall(function() return screen:isReallyVisible() end)
            alive = not ok or visible
        end
        if not alive then
            TF.Build.closeMissing(screen)
            return
        end
        TF.safe("build:place", place, pop)
        if basePrerender then basePrerender(pop) end
    end
    place(popup)
    if popup.bringToTop then popup:bringToTop() end
    screen.tfMissingPopup = popup
    popup.tfRows, popup.tfExtra = rows, extraLines
    return popup
end

--- Schliesst die Rueckfrage. @return boolean  ob eine offen war
function TF.Build.closeAsk(screen)
    local popup = screen and screen.tfAskPopup
    if not popup then return false end
    screen.tfAskPopup = nil
    popup:setVisible(false)
    if popup.tfTopLevel and popup.removeFromUIManager then
        popup:removeFromUIManager()
    elseif screen.removeChild then
        screen:removeChild(popup)
    end
    return true
end

--- Antwort auf die Rueckfrage: Ja laedt den Build, Nein laesst alles stehen.
function TF.Build.answer(screen, yes)
    local popup = screen and screen.tfAskPopup
    if not popup then return end
    local build = popup.tfBuild
    TF.Build.closeAsk(screen)
    if yes and build then TF.safe("build:load", TF.Build.load, screen, build) end
end

--- Die Rueckfrage, bevor ein Build die jetzige Auswahl ersetzt.
--
-- Bis 0.12.11 Vanillas ISModalDialog mit fester Groesse 300 x 130: der Satz
-- lief links und rechts aus dem Fenster, der Grund schien durch, und es stand
-- in der Mitte des ganzen Bildschirms statt dort, wo die Hinweise stehen
-- (Befund im Spiel 21.09.2026). Jetzt gebaut wie die Hinweise und das
-- Warnfenster: Kaestchen mit Fragezeichen, doppelter Rand, Text umbrochen, an
-- der Stelle der Hinweise. Ein eigenes Fenster ganz oben, das Klicks faengt
-- (setCapture), wie Vanillas Rueckfragen. Esc heisst Nein.
-- @return boolean  ob gefragt wird; false heisst, der Aufrufer laedt selbst
function TF.Build.ask(screen, build)
    if not (ISPanel and ISButton and screen and screen.addChild and TF.Panel and TF.Panel.toastSize) then
        return false
    end
    TF.Build.closeAsk(screen)
    local font = UIFont.Small
    local pad, gap = 14, 8
    local text = TF.fmt.text("UI_TF_build_replace")
    local core = getCore and getCore()
    local sw = core and core:getScreenWidth() or (screen.getWidth and screen:getWidth()) or 1200
    local sh = core and core:getScreenHeight() or (screen.getHeight and screen:getHeight()) or 800
    local manager = getTextManager and getTextManager()
    local lh = (manager and manager.getFontHeight and manager:getFontHeight(font)) or 19
    local BADGE = lh + 4
    local lines = TF.Panel.wrapToast(text, math.max(200, math.min(440, sw - 80)), font)
    local textW = 0
    for _, line in ipairs(lines) do textW = math.max(textW, TF.fmt.measure(line, font)) end
    local function label(key, fallback)
        local t = getText and getText(key) or key
        return (t == nil or t == key) and fallback or t
    end
    local yesText, noText = label("UI_Yes", "Yes"), label("UI_No", "No")
    local buttonW = math.max(TF.fmt.measure(yesText, font), TF.fmt.measure(noText, font)) + 40
    local buttonH = lh + 8
    local w = math.max(pad + BADGE + gap + textW + pad, pad * 2 + buttonW * 2 + gap)
    local textH = math.max(BADGE, #lines * lh)
    local h = pad + textH + 12 + buttonH + pad
    local popup = ISPanel:new(0, 0, w, h)
    popup:initialise()
    local o = TF.Panel.statusColor("ask")
    popup.backgroundColor = { r = 0.03, g = 0.03, b = 0.03, a = 1 }
    popup.borderColor = { r = o[1], g = o[2], b = o[3], a = 1 }
    local c = (TF.fmt.rgb and TF.fmt.rgb.value) or { 0.85, 0.85, 0.85 }
    local baseRender = popup.render
    popup.render = function(p)
        if baseRender then baseRender(p) end
        p:drawRectBorder(1, 1, w - 2, h - 2, 1, o[1], o[2], o[3])
        TF.Panel.drawBadge(p, pad, pad, BADGE, "ask")
        local textY = pad + ((#lines == 1) and math.floor((BADGE - lh) / 2) or 0)
        for i, line in ipairs(lines) do
            p:drawText(line, pad + BADGE + gap, textY + (i - 1) * lh, c[1], c[2], c[3], 1, font)
        end
    end
    if popup.addToUIManager then
        popup:addToUIManager()
        if popup.setAlwaysOnTop then popup:setAlwaysOnTop(true) end
        if popup.setCapture then popup:setCapture(true) end
        popup.tfTopLevel = true
    else
        screen:addChild(popup)
    end
    local by = pad + textH + 12
    local no = ISButton:new(w - pad - buttonW, by, buttonW, buttonH, noText, screen,
        function(target) TF.safe("build:no", TF.Build.answer, target, false) end)
    no:initialise()
    popup:addChild(no)
    local yes = ISButton:new(w - pad - buttonW * 2 - gap, by, buttonW, buttonH, yesText, screen,
        function(target) TF.safe("build:yes", TF.Build.answer, target, true) end)
    yes:initialise()
    local good = (TF.fmt.rgb and TF.fmt.rgb.good) or { 0.45, 0.72, 0.48 }
    yes.borderColor = { r = good[1], g = good[2], b = good[3], a = 1 }
    popup:addChild(yes)
    -- Wo die Hinweise stehen: mittig, im oberen Drittel. Je Bild neu, damit
    -- es einer geaenderten Fenstergroesse folgt; mit dem Bildschirm geht es weg.
    local function place(pop)
        local cw = core and core:getScreenWidth() or sw
        local ch = core and core:getScreenHeight() or sh
        local x, y = (cw - w) / 2, math.floor(ch * 0.30)
        if not pop.tfTopLevel then
            x = ((screen.getWidth and screen:getWidth()) or cw) / 2 - w / 2
            y = math.floor(((screen.getHeight and screen:getHeight()) or ch) * 0.30)
        end
        pop:setX(math.max(4, math.floor(x)))
        pop:setY(math.max(4, math.floor(y)))
    end
    local basePrerender = popup.prerender
    popup.prerender = function(pop)
        local alive = true
        if pop.tfTopLevel and screen.isReallyVisible then
            local ok, visible = pcall(function() return screen:isReallyVisible() end)
            alive = not ok or visible
        end
        if not alive then
            TF.Build.closeAsk(screen)
            return
        end
        TF.safe("build:askplace", place, pop)
        if basePrerender then basePrerender(pop) end
    end
    place(popup)
    if popup.bringToTop then popup:bringToTop() end
    popup.tfBuild, popup.tfLines = build, lines
    screen.tfAskPopup = popup
    return true
end

--- Hinweis mittig im Bildschirm (TF.Panel.showToast). Der Text steht
-- zusaetzlich am Bildschirm selbst: ohne TF_Panel (und im Test) bleibt er so
-- lesbar.
local function toast(screen, text, kind)
    if not screen then return end
    screen.tfBuildNote, screen.tfBuildNoteKind = text, kind
    if TF.Panel and TF.Panel.showToast then
        TF.safe("build:toast", TF.Panel.showToast, screen, text, kind, kind == "warn" and 8000 or 5000)
    end
end

--- Knopf "kopieren": der Build in die Zwischenablage.
function TF.Build.copy(screen)
    local text = TF.Build.export(screen)
    if not (text and Clipboard and Clipboard.setClipboard) then return nil end
    Clipboard.setClipboard(text)
    toast(screen, TF.fmt.text("UI_TF_build_copied"), "ok")
    return text
end

--- Setzt einen zerlegten Build und meldet, was dabei herauskam.
function TF.Build.load(screen, build)
    TF.Build.closeMissing(screen)
    local ok, result = pcall(TF.Build.apply, screen, build)
    if not ok then
        TF.warnOnce("build:apply", "Build einfuegen fehlgeschlagen: " .. tostring(result))
        toast(screen, TF.fmt.text("UI_TF_build_invalid"), "error")
        return nil
    end
    local notes, other = {}, {}
    if #result.missing > 0 then
        notes[#notes + 1] = TF.fmt.text("UI_TF_build_pasted_missing", table.concat(result.missing, ", "))
        other[#other + 1] = notes[#notes]
    end
    if #result.mods > 0 then
        notes[#notes + 1] = TF.fmt.text("UI_TF_build_pasted_mods", table.concat(result.mods, ", "))
    end
    if result.unknown > 0 then
        notes[#notes + 1] = TF.fmt.text(result.unknown == 1 and "UI_TF_build_pasted_unknown_one"
            or "UI_TF_build_pasted_unknown", tostring(result.unknown))
        other[#other + 1] = notes[#notes]
    end
    -- Fehlen Mods, sagt das Fenster alles; ein Hinweis daneben laege ueber ihm.
    -- Der Text bleibt am Bildschirm stehen (tfBuildNote), gezeigt wird er nicht.
    if #result.links > 0 then
        local shown = TF.safe("build:missing", TF.Build.showMissing, screen, result.links, table.concat(other, "; "))
        if shown then
            screen.tfBuildNote = TF.fmt.text("UI_TF_build_pasted") .. ": " .. table.concat(notes, "; ")
            screen.tfBuildNoteKind = "warn"
            if screen.tfToast and screen.tfToast.setVisible then screen.tfToast:setVisible(false) end
            return result
        end
    end
    if #notes > 0 then
        toast(screen, TF.fmt.text("UI_TF_build_pasted") .. ": " .. table.concat(notes, "; "), "warn")
    else
        toast(screen, TF.fmt.text("UI_TF_build_pasted"), "ok")
    end
    return result
end

--- Wie viele Traits die Figur gerade gekauft hat (ohne die des Berufs).
local function boughtTraits(screen)
    local n = 0
    local chosen = screen and screen.listboxTraitSelected
    for _, item in ipairs((chosen and chosen.items) or {}) do
        local def = item.item
        local okFree, free = pcall(function() return def:isFree() end)
        if def and not (okFree and free) then n = n + 1 end
    end
    return n
end

--- Knopf "einfuegen": der Build aus der Zwischenablage.
--
-- Erst lesen, dann fragen: ist der Text kein Build, bleibt alles, wie es ist,
-- und es gibt nichts zu fragen. Sind schon Traits gekauft, fragt ein Dialog
-- nach, bevor die Auswahl ersetzt wird (seit 0.12.0; ein Fehlklick mit einem
-- alten Text in der Zwischenablage loeschte sonst den halb fertigen Build).
-- Gebaut wie Vanillas Rueckfrage vor dem Loeschen eines gespeicherten Builds
-- (deleteBuildStep1). Ohne ISModalDialog wird ohne Frage geladen.
function TF.Build.paste(screen)
    if not (Clipboard and Clipboard.getClipboard) then return nil end
    local build, problem = TF.Build.parse(Clipboard.getClipboard(), screen)
    if not build then
        local keys = { newer = "UI_TF_build_newer", damaged = "UI_TF_build_damaged",
                       empty = "UI_TF_build_empty" }
        toast(screen, TF.fmt.text(keys[problem] or "UI_TF_build_invalid"), "error")
        return nil, problem
    end
    if boughtTraits(screen) == 0 or not TF.Build.ask(screen, build) then
        return TF.Build.load(screen, build)
    end
    return nil, "asked"
end
