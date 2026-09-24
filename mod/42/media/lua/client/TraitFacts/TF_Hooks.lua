--- Trait Facts - Einhaengepunkte.
--
-- Disziplin beim Ueberschreiben, damit andere Mods weiter funktionieren:
--  1. Original in einem eigenen Namensraum sichern.
--  2. Gegen doppeltes Umhaengen absichern.
--  3. Das Original immer zuerst aufrufen und nur das Ergebnis anreichern.
--
-- Angehaengt wird an `item.tooltip` der Listbox. Vanilla setzt den Tooltip in
-- populateTraitList / populateBadTraitList ueber den dritten Parameter von
-- ISScrollingListBox:addItem; wir haengen danach an, statt ihn zu ersetzen.

TraitFacts = TraitFacts or {}
local TF = TraitFacts
TF._orig = TF._orig or {}

--- Zusaetzlicher Grund hinter dem Tooltip der Trait-Listen.
--
-- Vanilla zeichnet den Tooltip-Grund in ISToolTip:render mit fester Deckung
-- 0.7. Ueber dem Spaltentext der Uebersicht dahinter war das zu wenig: der
-- Text darunter schien durch. Ein zweites Rechteck darueber mit 0.75 bringt
-- die Deckung auf 1 - 0.25 * 0.3 = 0.93: fast dicht, ein Rest Durchsicht
-- bleibt, damit der Tooltip noch schwebt. Voll deckendes Schwarz war am
-- 09.09.2026 ausprobiert und zu schwer; 0.85 zu wenig fuer den grauen Text
-- der Fussnoten (Entscheidung vom 10.09.2026).
local BACKDROP = { r = 0.05, g = 0.05, b = 0.05, a = 0.75 }

--- Zeichnet das Rechteck ueber den Vanilla-Grund, unter den Text.
--
-- Vor renderContents, nicht in prerender und nicht nach render:
-- ISToolTip:render verschiebt den Tooltip erst (weg von der Maus,
-- Ausweichen vor der Liste), zeichnet dann Grund und Rahmen und ruft zuletzt
-- renderContents auf, das den Text des descriptionPanel malt. Ein Rechteck
-- aus prerender stand an der alten Position, als Geist neben dem Tooltip;
-- eines nach render lag ueber dem Text und dunkelte ihn ab (beides
-- Screenshots vom 09.09.2026). Ein Pixel Rand bleibt frei, damit der
-- Vanilla-Rahmen nicht abgedunkelt wird.
local function drawBackdrop(tip)
    tip:drawRect(1, 1, tip.width - 2, tip.height - 2,
        BACKDROP.a, BACKDROP.r, BACKDROP.g, BACKDROP.b)
end

--- Kaestchen um die Kuerzel im Beschreibungstext des Tooltips.
--
-- Dieselbe Mechanik wie in der Uebersicht (TF.Panel.tagBoxes + TF.fmt.tagBox,
-- TF_Panel.lua): das descriptionPanel ist ein ganz gewoehnliches
-- ISRichTextPanel, nur dass ISToolTip es selbst zeichnet statt es als Kind
-- einzuhaengen (renderContents, ISToolTip.lua ~222-236: setzt X/Y auf die
-- absolute Position und ruft prerender/render direkt auf). lineX/lineY/lines
-- stehen laengst, wenn diese Funktion laeuft: ISToolTip:prerender ruft
-- doLayout -> layoutContents -> descriptionPanel:paginate() vor jedem
-- render() auf, renderContents laeuft danach.
--
-- Die Schrift ist panel.font: ISRichTextPanel:paginate setzt sie am Anfang
-- auf self.defaultFont (Z. 412), und ISToolTip:layoutContents setzt
-- defaultFont zuvor auf ISToolTip.GetFont() (Z. 191) - die Schrift, die der
-- Spieler in den Optionen waehlen kann. Dieselbe Schrift, in der das Panel
-- eben gemessen und gezeichnet hat; messen wir in einer anderen, saessen die
-- Kaestchen daneben.
--
-- TF.Panel steht erst nach TF_Panel.lua (Ladereihenfolge: TF_Hooks vor
-- TF_Panel); zum Zeichnen - lange nach dem Laden, beim ersten Mouseover - ist
-- die Datei sicher da. Deshalb wird hier bei jedem Aufruf nachgesehen statt
-- die Funktion einmal beim Laden in eine Ortsvariable zu legen (Entscheidung
-- 15.09.2026).
local function drawTagBoxes(tip)
    local panel = tip and tip.descriptionPanel
    if not panel or type(panel.lines) ~= "table" then return end
    if not (TF.Panel and TF.Panel.tagBoxes) then return end
    local font = panel.font or panel.defaultFont or (UIFont and UIFont.NewSmall)
    for _, box in ipairs(TF.Panel.tagBoxes(panel)) do
        TF.fmt.tagBox(panel, box.x, box.y, box.tag, font)
    end
end

--- Streifen hinter den Wertzeilen des Tooltips (seit 0.14.8), wie in der
-- Uebersicht. ISToolTip:renderContents ruft descriptionPanel:prerender()
-- und render() von Hand, nachdem es das Panel an seine Stelle gesetzt hat;
-- im prerender liegen die Streifen ueber dem Grund (drawBackdrop lief davor)
-- und unter dem Text. Die Instanz bekommt eine Huelle, die das Original
-- zuerst ruft, einmal je Panel. Was gestreift wird, entscheidet
-- TF.Tooltip.drawStripes; ein Tooltip ohne Trait-Facts-Block (Startskill-
-- Liste) bleibt, wie er ist.
local function stripeTooltip(tip)
    local panel = tip.descriptionPanel
    if type(panel) ~= "table" or panel.tfStriped or type(panel.prerender) ~= "function" then return end
    panel.tfStriped = true
    local prerender = panel.prerender
    panel.prerender = function(p, ...)
        local ergebnis = prerender(p, ...)
        TF.safe("tooltip:stripes", function()
            if TF.Tooltip and TF.Tooltip.drawStripes then TF.Tooltip.drawStripes(tip, p) end
        end)
        return ergebnis
    end
end

--- Dunkelt den Tooltip genau dieser Liste ab und rahmt seine Kuerzel.
--
-- Der Tooltip entsteht erst beim ersten Mouseover, in
-- ISScrollingListBox:updateTooltip. Deshalb wird die Methode an der einen
-- Liste umhuellt, nicht an der Klasse, und danach render an dem einen
-- Tooltip: die Tooltips anderer Listen bleiben, wie sie sind.
--
-- Oeffentlich, weil die Startskill-Liste (TF_XpColumns) denselben Grund
-- braucht: seit ihr Tooltip die Stufe vorrechnet, schien die Liste durch
-- (Screenshot 12.09.2026). Aus demselben Grund bekommt ihr Tooltip hier auch
-- die Kaestchen um Kuerzel mit (Entscheidung 15.09.2026: Kaestchen auch im
-- Tooltip, gezeichnet ueber dem descriptionPanel in renderContents).
function TF.darkenTooltip(list)
    if list.tfTooltipHooked then return end
    local original = list.updateTooltip
    if type(original) ~= "function" then return end
    list.tfTooltipHooked = true
    list.updateTooltip = function(self, ...)
        original(self, ...)
        local tip = self.tooltipUI
        if tip and not tip.tfDarkened and type(tip.renderContents) == "function"
                and type(tip.drawRect) == "function" then
            tip.tfDarkened = true
            local renderContents = tip.renderContents
            tip.renderContents = function(t, ...)
                drawBackdrop(t)
                local ergebnis = renderContents(t, ...)
                TF.safe("tooltip:tags", drawTagBoxes, t)
                return ergebnis
            end
            stripeTooltip(tip)
        end
    end
end

--- Kostenspalte einer Trait-Liste: Vanilla zeichnet die Kosten rechtsbuendig
-- bei self:getWidth() - UI_BORDER_SPACING*2 (drawTraitMap,
-- CharacterCreationProfession.lua:1031). UI_BORDER_SPACING ist dort eine
-- Datei-lokale Variable (10, wie schon in TF_Panel.placePanel begruendet),
-- hier also derselbe Wert von Hand.
local UI_BORDER_SPACING = 10

--- Abstand zwischen zwei benachbarten Stuecken der Zeile: Kaestchen und
-- Kostenspalte, und Name und Kaestchen. Eine einzige Luecke fuer beide
-- Stellen, 6 px, mit der Schriftgroesse skaliert wie jedes andere Pixelmass
-- hier (TF.fmt.uiScale) - Entscheidung 15.09.2026, Mockup
-- trait-listen-kuerzelspalte-2026-09-15, Zustand "eigene Spalte".
local function gapPx(font)
    return math.floor(6 * TF.fmt.uiScale(font) + 0.5)
end

--- Misst die Kostenspalte einer Liste neu: list.tfCostWidth ist die Breite
-- des breitesten Kostentexts dieser Liste (getRightLabel). Ohne verwertbare
-- Kosten 0; drawTag zeichnet trotzdem, nur ohne Ausrichtung an einer Zahl.
--
-- Aufgerufen bei jedem Neuaufbau der Liste (decorate), nicht bei jedem
-- Frame: die Kosten aendern sich nur, wenn sich der Vorrat aendert (Beruf,
-- Trait hinzufuegen oder entfernen). Die linke Kante der Spalte dagegen
-- rechnet tagBoxX in jedem Frame aus der aktuellen Breite, denn die aendert
-- sich nach dem Befuellen: create() baut die Listen mit tableWidth aus der
-- vollen Breite (CharacterCreationProfession.lua:109), prerender setzt sie
-- danach in jedem Frame auf die echte (735-742). Bis 15.09.2026 stand hier
-- die fertige Kante (list.tfCostColLeft) aus der Breite beim Befuellen, und
-- die Kaestchen lagen im Spiel rechts ausserhalb der Liste, abgeschnitten.
local function layoutColumns(list)
    if not (list and type(list.items) == "table" and type(list.getWidth) == "function") then return end
    local font = UIFont and UIFont.Small or nil
    local breiteste = 0
    for _, entry in ipairs(list.items) do
        local def = entry.item
        local okLabel, label = pcall(function() return def:getRightLabel() end)
        if okLabel and label and tostring(label) ~= "" then
            local w = TF.fmt.measure(tostring(label), font)
            if w > breiteste then breiteste = w end
        end
    end
    list.tfCostWidth = breiteste
end

--- Linke Kante (Text, nicht Rahmen) des Kaestchens fuer `tag` in dieser
-- Zeile: sein rechter Rand (Text plus 2 px Rahmenpolsterung, wie
-- TF.fmt.tagBox sie zieht) liegt eine Luecke links von der Kostenspalte,
-- fuer jede Zeile derselben Liste an derselben Stelle. Die Kostenspalte
-- endet wie bei Vanilla (drawTraitMap, Zeile 1031) bei der aktuellen Breite
-- minus Rand, gelesen in jedem Aufruf, nie gemerkt.
-- @return number|nil  nil ohne gemessene Kostenspalte (layoutColumns lief
--                     noch nicht)
local function tagBoxX(list, tag, font)
    if not list.tfCostWidth then return nil end
    local costLeft = list:getWidth() - UI_BORDER_SPACING * 2 - list.tfCostWidth
    return costLeft - gapPx(font) - TF.fmt.measure(tag, font) - 2
end

--- Kuerzt `text` mit angehaengten "..." auf hoechstens `breite` Pixel
-- (TF.fmt.kuerze; bis 0.12.7 stand die Funktion hier).
local kuerzeMitPunkten = TF.fmt.kuerze

--- Baut eine Huelle um `def`: getLabel liefert `kurz`, jeder andere
-- Aufruf (getCost, getTexture, getRightLabel, ...) geht unveraendert an
-- `def` weiter.
--
-- Das Original selbst wird nie angefasst. Im Spiel ist `def` ein
-- Java-Objekt (CharacterTraitDefinition); Kahlua laesst dort kein neues
-- Feld zu, `def.getLabel = ...` wirft (Review nach e2eae3d: die Zuweisung
-- schlug im Spiel fehl, geschluckt von TF.safe, die Kuerzung blieb
-- wirkungslos - im Test unbemerkt, weil der Stub dort eine gewoehnliche
-- Lua-Tabelle ist). Eine Huelle aus einer neuen Tabelle mit Metatabelle
-- darf dagegen jeder anfassen, auch ein Java-Objekt dahinter.
local function labelProxy(def, kurz)
    return setmetatable({}, { __index = function(_, key)
        if key == "getLabel" then return function() return kurz end end
        local v = def[key]
        if type(v) == "function" then
            return function(_, ...) return v(def, ...) end
        end
        return v
    end })
end

--- Haengt fuer diesen einen Aufruf eine Huelle mit gekuerztem Namen an
-- item.item, wenn der volle Name in die Kuerzel-Spalte dieser Zeile liefe
-- (Name-Startx nach drawTraitMap: 10, oder Icon-Breite + 20).
--
-- item.item ist dieselbe Trait-Definition in jeder Zeile, die sie zeigt
-- (Vorrat, Auswahl, Beruf); getauscht wird nur der Eintrag der Zeile
-- (item.item), nie `def` selbst - ein dauerhafter Tausch an `def`
-- verstuemmelte den Namen ueberall, nicht nur in dieser Liste. Der
-- Aufrufer (wrapDraw) hat mod/tag schon aus dem echten `def` gelesen,
-- bevor diese Funktion laeuft, und setzt item.item unmittelbar nach dem
-- Vanilla-Aufruf zurueck, auch wenn er wirft.
--
-- list.tfNoShorten: wrapDraw setzt das, wenn Vanilla schon einmal an der
-- Huelle gescheitert ist (die Huelle reicht dann offenbar nicht jeden
-- Aufruf durch, den diese Liste braucht). Ab dann keine Huelle mehr fuer
-- diese Liste - lieber der volle Name als eine Zeile, die nicht zeichnet.
-- @return function|nil  Ruecksetzer, oder nil ohne Kuerzung noetig/moeglich
local function shortenLabelForRow(list, item, mod, font)
    if list.tfNoShorten then return nil end
    local def = item and item.item
    if not def then return nil end
    local kante = tagBoxX(list, mod.tag, font)
    if not kante then return nil end
    local grenze = kante - 2 - gapPx(font)
    -- Je Zeile gemerkt: Vanilla ruft doDrawItem fuer jede Zeile in jedem
    -- Bild, auch ausserhalb des sichtbaren Bereichs. Icon, Name, Messen und
    -- Kuerzen liefen mit den 96 Traits von More Traits hunderte Male je Bild
    -- und bauten jedes Mal eine neue Huelle (Audit 20.09.2026). Das Ergebnis
    -- haengt nur an der Definition und an der Kante der Kuerzel-Spalte.
    local known = item.tfShort
    if known and known.def == def and known.grenze == grenze then
        if not known.proxy then return nil end
        item.item = known.proxy
        return function() item.item = def end
    end
    item.tfShort = { def = def, grenze = grenze, proxy = false }
    local x = UI_BORDER_SPACING
    local okTex, tex = pcall(function() return def:getTexture() end)
    if okTex and tex then x = tex:getWidth() + UI_BORDER_SPACING * 2 end
    local okLabel, label = pcall(function() return def:getLabel() end)
    if not (okLabel and label) then return nil end
    label = tostring(label)
    if x + TF.fmt.measure(label, font) <= grenze then return nil end
    local kurz = kuerzeMitPunkten(label, grenze - x, font)
    if kurz == label then return nil end
    item.tfShort.proxy = labelProxy(def, kurz)
    item.item = item.tfShort.proxy
    return function() item.item = def end
end

--- Zeichnet das Kaestchen um das Kuerzel eines fremden Traits in der
-- eigenen Spalte links neben den Kosten (Entscheidung 15.09.2026, Mockup
-- trait-listen-kuerzelspalte-2026-09-15, Zustand "eigene Spalte"). Bis 0.2.0
-- stand das Kuerzel hinter dem Namen und wanderte je nach Namenslaenge selbst
-- bei gleicher Kostenbreite hin und her; jetzt eine feste Spalte, rechtsbuendig
-- gegen die Kosten, unabhaengig von der Namenslaenge.
local function drawTag(list, y, mod, font)
    local x = tagBoxX(list, mod.tag, font)
    if not x then return end
    local h = list.fontHgt or 19
    local dy = ((list.itemheight or h) - h) / 2
    TF.fmt.tagBox(list, x, y + dy, mod.tag, font)
end

--- Alle Huellen, die makeTagDraw je gebaut hat (Funktion als Schluessel).
-- wrapDraw erkennt daran, ob eine Liste schon ueber uns zeichnet - an der
-- Funktion selbst, nicht an einer Marke an der Liste. Die Marke
-- list.tfTagDraw (bis 15.09.2026) blieb stehen, wenn Vanilla die Huelle
-- danach ueberschrieb, und verhinderte jedes Neu-Einhaengen: create() setzt
-- doDrawItem der Vorratslisten erst NACH populateTraitList
-- (CharacterCreationProfession.lua 224-225, 243-244), die Kaestchen fehlten
-- dort darum im Spiel ganz. Liegt in TF, damit ein Neuladen der Datei die
-- schon gebauten Huellen weiter erkennt. Waechst nur um wenige Eintraege je
-- Charaktererstellung (Kahlua kennt keine schwachen Tabellen).
TF._tagDrawers = TF._tagDrawers or {}

--- Variante B der Suche (Entscheidung 19.09.2026): kommt der Treffer aus
-- einer Wirkung, steht sie grau hinter dem Namen, vor der Kuerzel-Spalte
-- (fremder Trait) oder den Kosten gekuerzt. Unter 30 px Platz entfaellt sie.
local function drawReason(box, y, item, match, mod, font)
    local def = item and item.item
    if not def then return end
    local okL, lbl = pcall(function() return def:getLabel() end)
    if not (okL and lbl) then return end
    local x = UI_BORDER_SPACING
    local okT, tex = pcall(function() return def:getTexture() end)
    if okT and tex then x = tex:getWidth() + UI_BORDER_SPACING * 2 end
    x = x + TF.fmt.measure(tostring(lbl), font) + gapPx(font)
    local right
    if mod then
        right = tagBoxX(box, mod.tag, font)
        if right then right = right - 2 - gapPx(font) end
    end
    if not right then
        right = box:getWidth() - UI_BORDER_SPACING * 2 - (box.tfCostWidth or 0) - gapPx(font)
    end
    if right - x < 30 then return end
    local text = kuerzeMitPunkten(TF.fmt.text("UI_TF_search_why", match.text), right - x, font)
    local h = box.fontHgt or 19
    local dy = ((box.itemheight or h) - h) / 2
    box:drawText(text, x, y + dy, 0.55, 0.55, 0.55, 1, font)
end

--- Baut die Huelle um eine Zeichenfunktion einer Trait-Liste: kuerzt fuer
-- fremde Traits noetigenfalls den Namen, ruft dann Vanilla, setzt den Namen
-- sofort danach zurueck (auch wenn Vanilla wirft) und zeichnet zuletzt das
-- Kaestchen in der Kuerzel-Spalte. Vanilla-Zeilen (kein Mod) bleiben
-- unangetastet: kein Kuerzen, kein Kaestchen, einfach der urspruengliche
-- Aufruf.
--
-- Oberste Regel des Mods: die Charaktererstellung darf nie an uns scheitern,
-- und Vanilla muss die Zeile immer zeichnen. Zwei Stellen koennten das sonst
-- gefaehrden:
--   - TF.Mods.traitMod(def) laeuft vor Vanilla und ungeschuetzt gaebe einen
--     Fehler dort direkt an den Aufrufer von doDrawItem weiter, bevor
--     Vanilla ueberhaupt drankam. Deshalb unter TF.safe: schlaegt es fehl,
--     ist die Zeile fuer diesen Aufruf einfach kein fremder Trait (mod =
--     nil), Vanilla zeichnet trotzdem, nur ohne Kaestchen.
--   - Die Huelle (labelProxy) haengt davon ab, dass Kahlua eine
--     durchgereichte Java-Methode als "function" meldet. Trifft das einmal
--     nicht zu, scheitert Vanillas eigener Aufruf an der Huelle, obwohl er
--     am echten Objekt anstandslos liefe. In dem Fall: item.item zurueck auf
--     das echte Objekt, einmal warnen, die Kuerzung fuer diese Liste
--     abschalten (list.tfNoShorten, siehe shortenLabelForRow) und Vanilla
--     sofort ein zweites Mal mit dem echten Objekt versuchen. Scheitert
--     Vanilla auch daran - also unabhaengig von der Huelle -, gilt wieder
--     das alte Verhalten: warnen und den Fehler weiterreichen, denn dann
--     haette Vanilla so oder so nicht gezeichnet.
local function makeTagDraw(vanilla)
    local wrapper = function(box, y, item, alt)
        -- Trait-Suche (TF_Search): eine nicht passende Zeile gibt ihr y
        -- zurueck, ohne Vanilla zu rufen. Vanillas prerender setzt ihre Hoehe
        -- daraus auf 0 (ISScrollingListBox, v.height = y2 - y); die Liste
        -- ueberspringt solche Zeilen beim Klicken und mit dem Joypad schon
        -- selbst. Scheitert der Filter, wird die Zeile normal gezeichnet.
        local match = nil
        if TF.Search and TF.Search.filterRow then
            local okS, hide, m = pcall(TF.Search.filterRow, box, y, item)
            if not okS then
                TF.warnOnce("list:search", "Suchfilter fehlgeschlagen: " .. tostring(hide))
            elseif hide then
                return y
            else
                match = m
            end
        end
        local def = item and item.item
        local mod = nil
        if def and TF.Mods and TF.Mods.traitMod then
            -- Je Zeile gemerkt, aus demselben Grund wie in
            -- shortenLabelForRow: traitMod zerlegt sonst in jedem Bild fuer
            -- jede Zeile die ID des Traits. Das Mod eines Traits steht fuer
            -- die Sitzung fest (TF.Mods.prime); TF.Mods.reset zaehlt
            -- TF.Mods.epoch hoch und verwirft damit, was hier gemerkt ist.
            local epoch = TF.Mods.epoch or 0
            if item.tfModDef == def and item.tfModEpoch == epoch then
                mod = item.tfMod or nil
            else
                mod = TF.safe("list:mod", TF.Mods.traitMod, def)
                item.tfModDef, item.tfModEpoch, item.tfMod = def, epoch, mod or false
            end
        end
        local font = UIFont and UIFont.Small or nil
        local restore = mod and TF.safe("list:shorten", shortenLabelForRow, box, item, mod, font)
        local ok, nextY = pcall(vanilla, box, y, item, alt)
        if not ok and restore then
            restore()
            restore = nil
            TF.warnOnce("list:shortenfail", "Vanilla ist an der gekuerzten Huelle gescheitert: "
                .. tostring(nextY) .. " - Kuerzung fuer diese Liste abgeschaltet.")
            box.tfNoShorten = true
            ok, nextY = pcall(vanilla, box, y, item, alt)
        end
        local shortened = restore ~= nil
        if restore then restore() end
        if not ok then
            TF.warnOnce("list:tagdraw", "Vanilla-doDrawItem fehlgeschlagen: " .. tostring(nextY))
            error(nextY)
        end
        if mod then TF.safe("list:tag", drawTag, box, y, mod, font) end
        -- Ein gekuerzter Name laesst keinen Platz fuer den Zusatz.
        if match and match.reason == "effect" and match.text and not shortened then
            TF.safe("list:searchwhy", drawReason, box, y, item, match, mod, font)
        end
        return nextY
    end
    TF._tagDrawers[wrapper] = true
    return wrapper
end

--- Haengt die Kuerzel-Spalte vor die aktuelle Zeichenfunktion einer Liste,
-- ausser sie ist schon eine unserer Huellen. Laeuft bei jedem decorate, so
-- dass eine spaeter getauschte Zeichenfunktion (Vanilla in create(), ein
-- anderer Mod) beim naechsten Befuellen wieder umhuellt wird. Der Haupt-
-- weg ist hookDrawTraitMap; das hier ist das Netz darunter.
local function wrapDraw(list)
    local current = list.doDrawItem
    if type(current) ~= "function" or TF._tagDrawers[current] then return end
    list.doDrawItem = makeTagDraw(current)
end

--- Haengt den Zusatzblock an jeden Eintrag einer Trait-Listbox an.
--
-- Idempotent: jeder Eintrag wird je Farbschema hoechstens einmal angereichert.
-- Das ist noetig, weil dieselbe Liste aus mehreren Pfaden erreicht wird
-- (Berufswechsel, Trait hinzufuegen, Trait entfernen); ohne die Markierung
-- stuende der Block mehrfach im Tooltip. Neue Eintraege sind neue Tabellen
-- und damit unmarkiert.
--
-- Die Vanilla-Beschreibung merkt sich der Eintrag beim ersten Mal
-- (tfVanilla). Aendert sich eine Mod-Option (Farbschema, wirkungslose Werte,
-- Ausschluesse; TF_Options), baut der naechste Aufruf den Block daraus neu,
-- statt einen zweiten anzuhaengen. Bis 0.4.2 blieb die alte Farbe im Tooltip
-- stehen, bis eine Trait-Aenderung die Listen neu befuellte (Befund im Spiel
-- 16.09.2026).
local function decorate(list)
    if not list or type(list.items) ~= "table" then return end
    TF.darkenTooltip(list)
    wrapDraw(list)
    TF.safe("list:columns", layoutColumns, list)
    if TF.Options and TF.Options.sync then TF.safe("options:sync", TF.Options.sync) end
    local view = TF.viewKey()
    for _, item in ipairs(list.items) do
        if not item.tfDecorated or item.tfView ~= view then
            if not item.tfDecorated then item.tfVanilla = item.tooltip end
            -- Auch ohne Block markieren, sonst wird bei jedem Aufruf erneut
            -- gesucht, obwohl das Ergebnis feststeht.
            item.tfDecorated, item.tfView = true, view
            local block = TF.buildBlock(item.item)
            -- Der Block beginnt mit einer Leerzeile, die ihn von der
            -- Vanilla-Beschreibung absetzt. Gibt es keine, waere sie eine
            -- Luecke ueber der ersten Zeile.
            local existing = item.tfVanilla
            if block and existing and existing ~= "" then
                item.tooltip = existing .. block
            elseif block then
                item.tooltip = TF.stripLeadingGap(block)
            else
                item.tooltip = existing
            end
        end
    end
end

--- Reichert die drei Trait-Listen eines Bildschirms neu an, etwa nach einem
-- Wechsel des Farbschemas (TF_Panel, prerender). Nur Eintraege mit altem
-- Schema bekommen einen neuen Block.
function TF.redecorateTraitLists(screen)
    if not screen then return end
    decorate(screen.listboxTraitSelected)
    decorate(screen.listboxTrait)
    decorate(screen.listboxBadTrait)
end

--- Was fertige Tooltips praegt (TF.Options.view); ohne TF_Options nur das
-- Farbschema. Die Listen und der Bildschirm vergleichen damit.
function TF.viewKey()
    if TF.Options and TF.Options.view then return TF.Options.view() end
    return TF.fmt and TF.fmt.scheme
end

--- Legt einen Hook auf CharacterCreationProfession, der das Original zuerst
-- ausfuehrt und danach die Liste anreichert.
local function hookPopulate(name)
    if TF._orig[name] then return end

    local original = CharacterCreationProfession[name]
    if type(original) ~= "function" then
        TF.warn("CharacterCreationProfession." .. name
            .. " nicht gefunden, Tooltips bleiben unveraendert.")
        return
    end

    TF._orig[name] = original
    -- Alle Argumente und der Rueckgabewert gehen unveraendert durch: eine
    -- spaetere Vanilla-Fassung oder ein anderer Mod, der dieselbe Funktion
    -- umhuellt, darf sich darauf verlassen (Audit 20.09.2026).
    CharacterCreationProfession[name] = function(self, list, ...)
        TF.ran(name)
        local result = TF._orig[name](self, list, ...)
        TF.safe("decorate:" .. name, decorate, list)
        return result
    end
end

--- Hook auf eine Funktion, die die Liste der gewaehlten Traits veraendert.
--
-- Die kaufbaren Traits stehen in listboxTrait und listboxBadTrait, die
-- gewaehlten und die vom Beruf gewaehrten in listboxTraitSelected. Nur dort
-- taucht ein Berufs-Trait wie Ax-pert auf: er kostet 0 Punkte und wird von
-- populateTraitList und populateBadTraitList ausgefiltert.
--
-- Zwei Pfade fuehren dorthin, und sie sind unabhaengig voneinander:
--   onSelectProf         setzt die vom Beruf gewaehrten Traits
--   repopulateTraitLists laeuft nach addTrait und removeTrait
-- onSelectProf ruft repopulateTraitLists nicht auf, deshalb braucht es beide.
local function hookRefresh(name)
    if TF._orig[name] then return end

    local original = CharacterCreationProfession[name]
    if type(original) ~= "function" then
        TF.warn("CharacterCreationProfession." .. name
            .. " nicht gefunden, Berufs-Traits bleiben unveraendert.")
        return
    end

    TF._orig[name] = original
    -- Beide Originale geben nichts zurueck, deshalb wird kein Rueckgabewert
    -- durchgereicht.
    --
    -- Angefasst werden alle drei Listen, nicht nur die gewaehlten Traits. Beim
    -- Berufswechsel wandert ein gewaehrter Trait zurueck in den Vorrat, und das
    -- geschieht in doTestForMutuallyExclusiveTraits per addUniqueItem - ein
    -- frischer Eintrag ohne Block. onSelectProf ruft repopulateTraitLists nicht
    -- auf, also hatte diesen Fall sonst niemand abgedeckt: Keen Cook stand nach
    -- dem Wechsel von Chef zu Zimmermann ohne Zusatzzeilen im Vorrat.
    --
    -- Dass hier dreimal statt einmal geprueft wird, kostet nichts: das
    -- Anreichern ist idempotent und ueberspringt bereits behandelte Eintraege.
    CharacterCreationProfession[name] = function(self, ...)
        TF.ran(name)
        local result = TF._orig[name](self, ...)
        TF.safe("decorate:" .. name, function()
            decorate(self.listboxTraitSelected)
            decorate(self.listboxTrait)
            decorate(self.listboxBadTrait)
        end)
        -- Die Uebersicht haengt sonst nur an checkXPBoost, und "Reset
        -- Traits" ruft das nicht: resetTraits laeuft ueber removeAllTraits
        -- und onSelectProf, und onSelectProf tut bei unveraendertem Beruf
        -- nichts. Die Uebersicht zeigte dann Traits, die schon weg waren
        -- (Review 10.09.2026). Jeder Weg hierher ist eine Aenderung der
        -- Auswahl, also wird auch hier aufgefrischt; doppelt ist billig.
        if TF.Panel and TF.Panel.refresh then
            TF.safe("summary:refresh:" .. name, TF.Panel.refresh, self)
        end
        return result
    end
end

--- Hook auf resetTraits: ruft checkXPBoost nach, das Vanilla dort vergisst.
--
-- CharacterCreationProfession.lua ~613:
--   function CharacterCreationProfession:resetTraits()
--       self:onSelectProf(self.listboxProf.items[1].item);
--       self:removeAllTraits();
--       self:onSelectProf(self:getSelectedProf());
--   end
-- Nie ein Aufruf von self:checkXPBoost() - anders als ADDTRAIT, ADDBADTRAIT,
-- REMOVETRAIT (~594-611) und resetBuild (~1468-1474), die das alle tun.
-- checkXPBoost ist die einzige Stelle, die listboxXpBoost neu aufbaut; ohne
-- den Nachruf blieb die Startskill-Liste nach RESET TRAITS bei den Boosts
-- der gerade entfernten Traits stehen, obwohl Auswahl und Uebersicht schon
-- leer waren (Bugjagd 14.09.2026). Die Uebersicht selbst zieht schon ueber
-- hookRefresh("onSelectProf") nach, denn resetTraits ruft onSelectProf
-- zweimal auf - deswegen hier nur die Startskill-Liste.
local function hookReset()
    if TF._orig.resetTraits then return end

    local original = CharacterCreationProfession.resetTraits
    if type(original) ~= "function" then
        TF.warn("CharacterCreationProfession.resetTraits nicht gefunden, "
            .. "die Startskill-Liste bleibt nach Reset Traits stehen.")
        return
    end

    TF._orig.resetTraits = original
    CharacterCreationProfession.resetTraits = function(self, ...)
        TF._orig.resetTraits(self, ...)
        if type(self.checkXPBoost) == "function" then
            TF.safe("reset:checkXPBoost", self.checkXPBoost, self)
        end
    end
end

--- Umhuellt Vanillas drawTraitMap selbst, einmal beim Booten. create()
-- liest CharacterCreationProfession.drawTraitMap erst, wenn es die drei
-- Trait-Listen baut, also nach OnGameBoot - jede Liste bekommt damit von
-- Anfang an die Huelle, unabhaengig davon, wann decorate laeuft.
local function hookDrawTraitMap()
    if TF._orig.drawTraitMap then return end

    local original = CharacterCreationProfession.drawTraitMap
    if type(original) ~= "function" then
        TF.warn("CharacterCreationProfession.drawTraitMap nicht gefunden, "
            .. "die Kuerzel-Spalte haengt nur am Befuellen der Listen.")
        return
    end

    TF._orig.drawTraitMap = original
    CharacterCreationProfession.drawTraitMap = makeTagDraw(original)
end

local function install()
    if not CharacterCreationProfession then
        TF.warn("CharacterCreationProfession nicht gefunden, Tooltips bleiben unveraendert.")
        return
    end
    hookPopulate("populateTraitList")
    hookPopulate("populateBadTraitList")
    hookRefresh("onSelectProf")
    hookRefresh("repopulateTraitLists")
    hookReset()
    hookDrawTraitMap()
    -- TF.QUELLE setzt nur tools/build-workshop.py, in die Workshop-Kopie.
    -- Fehlt es, laeuft der Arbeitsstand aus dem Repo. Beide tragen dieselbe
    -- ID, und die Versionsnummer allein sagt nicht, welche Kopie geladen ist.
    TF.log("Version " .. TF.VERSION .. " geladen (" .. (TF.QUELLE or "Arbeitsstand aus dem Repo")
        .. "), hinterlegte Werte fuer Build " .. TF.DATA_BUILD .. ".")
    local stored, running = TF.buildMismatch()
    if stored then
        TF.warn("Das Spiel laeuft in Build " .. running .. ", die hinterlegten Werte stammen aus "
            .. stored .. "; sie koennen veraltet sein.")
    end
    -- Die Spaltenmasse gelten fuer NewSmall mit 19 px (TF.fmt.REFERENCE_HEIGHT);
    -- die gemessene Hoehe steht im Log, damit eine andere Schriftgroesse als
    -- Ursache fuer umgebrochene Werte sofort zu sehen ist.
    local ok, hoehe = pcall(function() return getTextManager():getFontHeight(UIFont.NewSmall) end)
    if ok and type(hoehe) == "number" then
        TF.log(string.format("Schrift NewSmall: %d px, Referenz %d px, Massstab %.2f.",
            hoehe, TF.fmt.REFERENCE_HEIGHT, hoehe / TF.fmt.REFERENCE_HEIGHT))
    end
end

-- Erst nach dem Booten einhaengen: dann steht der Vanilla-Lua-Baum sicher, egal
-- in welcher Reihenfolge Mods geladen wurden.
Events.OnGameBoot.Add(function()
    TF.safe("install", install)
end)
