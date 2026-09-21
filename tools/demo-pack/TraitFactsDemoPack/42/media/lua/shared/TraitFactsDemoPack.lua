-- Trait Facts Demo Pack: erfundene Werte, nur zum Ansehen im Spiel.
-- Zwei Pakete fuer The Only Cure: eines zur installierten Fassung (2.4.0),
-- eines zu einer alten (2.3.0), damit die orange Darstellung erscheint. Dazu
-- ersetzt das erste eine Vanilla-Zeile von Strong. Geht nie in den Workshop.
TraitFactsAPI = TraitFactsAPI or { queue = {} }
TraitFactsAPI.queue = TraitFactsAPI.queue or {}

table.insert(TraitFactsAPI.queue, {
    format = 1, source = "Demo: The Only Cure", tag = "DEMO",
    modId = "TheOnlyCure", version = "2.4.0",
    traits = {
        ["toc:amputee_hand"] = {
            { id = "demo_twohand", kind = "pct", value = 40, text = "Time for two-handed actions",
              note = "example value", better = "down", group = "crafting" },
            { id = "demo_grip", kind = "pct", value = -30, text = "Grip strength",
              note = "example value", better = "up", group = "combat" },
        },
        ["base:strong"] = {
            { replace = "knockback", value = 30 },
        },
    },
})

table.insert(TraitFactsAPI.queue, {
    format = 1, source = "Demo: The Only Cure (old)", tag = "OLD",
    modId = "TheOnlyCure", version = "2.3.0",
    traits = {
        ["toc:amputee_forearm"] = {
            { id = "demo_climb", kind = "pct", value = 25, text = "Time to climb over fences",
              note = "example value", better = "down", group = "movement" },
        },
    },
})
