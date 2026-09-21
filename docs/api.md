# Trait Facts: data API for mod authors

Trait Facts shows what traits actually do in Project Zomboid Build 42. If your
mod adds a custom trait, or changes what a vanilla trait does, you can hand
Trait Facts a small data package and it will show your numbers the same way
it shows its own: in the trait tooltip, in the build overview, and in the
Major Skills list.

You do not need Trait Facts as a dependency and your mod does not fail if
Trait Facts is missing or loads in any order relative to yours. If Trait
Facts is not installed, your package is simply never read.

## A complete example

```lua
TraitFactsAPI = TraitFactsAPI or { queue = {} }
table.insert(TraitFactsAPI.queue, {
    format  = 1,                        -- required
    source  = "My Trait Mod",           -- required, shown in the tooltip
    modId   = "MyTraitMod",             -- optional, for activation and the version check
    version = "1.3",                    -- optional, your mod's version for the values below
    tag     = "MTM",                    -- optional, 2 to 4 letters/digits; best your mod's own tag (see "Tags")
    traits  = {
        -- "namespace:traitname": the namespace your mod registers its
        -- traits under, which is not always your modId (see below).
        ["mytraitmod:packmule"] = {
            { id = "carry", kind = "flat", value = 2, text = "UI_MTM_carry",
              unit = "UI_MTM_unit_kg", better = "up", group = "movement" },
        },
        ["base:strong"] = {
            { replace = "knockback", kind = "pct", value = 30 },
            { remove  = "carryweight" },
        },
    },
})
```

The trait key is the trait's full registry ID, lower case. To find it, print
`tostring(traitDefinition:getType())` for one of your traits, or look at
the name you pass when registering it. The namespace is whatever your mod
registers under, and it can differ from your `modId`: More Traits Definitive
has the mod ID `moreTraitsDefinitive` but registers its traits as
`ToadTraits:...`.

`replace` and `remove` name the `id` of an existing row. For vanilla traits
those are Trait Facts' own ids: Strong has `knockback`, `carryweight` and
`grapple`. A target that does not exist is skipped with a warning (see the
validation table).

Give a `flat` value a `unit`. A bare "+2" tells the player nothing; "+2 kg"
does.

Copy this block, change `source`, `modId`, `version`, `tag` and `traits` to
match your mod, and register it from any `shared/` Lua file. Load order does
not matter: create the table if it is missing, and push your package onto
the queue. Trait Facts reads new packages from the queue every time it
builds a tooltip or the overview, so it does not matter whether your file
loads before or after Trait Facts, and a package added later still shows up
in the next tooltip.

Once Trait Facts has loaded, the table also carries two fields of its own:

- `TraitFactsAPI.register(package)` pushes a package onto the queue, the
  same as `table.insert(TraitFactsAPI.queue, package)`. It only exists
  after Trait Facts has loaded; if your file may load first, use
  `table.insert` as in the example, or check `if TraitFactsAPI.register then`.
- `TraitFactsAPI.format` is the package format the installed Trait Facts
  reads, currently `1`. You do not need to check it: a package with any
  other `format` is skipped with a warning.

## Package fields

| Field | Required | Meaning |
| --- | --- | --- |
| `format` | yes | Package format version. Currently `1`. A package with any other value is skipped so an old package never shows the wrong shape of data. |
| `source` | yes | Name shown as the origin of your values, for example at the top of your trait's tooltip ("values from *source* *version*"). |
| `modId` | no | Your mod's ID, as `getActivatedMods()` reports it. Case and anything other than letters and digits do not matter (`theonlycure` matches `TheOnlyCure`). If set, the package is only read while your mod is active. Also used for the version check below and for sharing your mod's tag (see "Tags"). |
| `version` | no | Your mod's version, for the version check below. Only meaningful together with `modId`. |
| `tag` | no | 2 to 4 letters and digits: the tag for what this package supplies (see "Tags" below). If omitted, Trait Facts derives one from `source` the same way it derives a mod's tag from the mod's name. |
| `traits` | no | Table keyed by full trait ID (`"namespace:traitname"`; case does not matter, Trait Facts lower cases it), each value a list of rows. A key without a `namespace:` prefix is skipped with a warning. |

## Tags

Trait Facts marks what comes from another mod with a short tag in a small
box, for example `TOC` for The Only Cure. There are two kinds:

- **Your mod's tag** stands after your mod's traits: in the trait lists,
  the build overview, the Major Skills list and the tooltip. It always
  comes from your mod's name: the initials of its words, in capitals, up to
  four ("More Traits" is `MT`); a one-word name uses its first three
  letters. A package never renames it.
- **Your package's tag** (`tag`) stands after the rows your package adds to
  or changes on vanilla traits (for example "Strong MT"), at the top of
  that vanilla trait's tooltip together with your `source`, and in the key
  line under the overview.

In a trait's tooltip, everything about the origin stands at the top, under
the trait's own description: for a trait of your mod, your mod's tag and
name, then one line per package with values for it ("values from *source*
*version*"), or "No numbers for this mod yet" if there is none. "Excludes" and
"Also grants" list one trait per line, each foreign trait with its tag.

If your package's `tag` equals your mod's tag and `modId` points at that
mod, the two share the tag: your traits and your rows on vanilla traits
carry the same tag, and hovering it in the overview names your mod. We
recommend exactly that: set `tag` to your mod's tag, or leave `tag` out if
`source` is your mod's name (the derived tag is then the same). A different
`tag` keeps working as a separate tag for the package.

Two mods or packages that would get the same tag do not share it: the one
that comes second gets an extra letter from the last word of its name or,
failing that, a digit.

## Row fields

Each entry in a trait's row list is a table with these fields:

| Field | Meaning |
| --- | --- |
| `id` | Identifier of this row within the trait, for example `"carry"`. Required for a new row (see the validation table); used by other packages' `replace`/`remove` to target this row. |
| `kind` | One of `pct`, `mult`, `flat`, `count`, `range`, `pctrange`, `fromto`, `bool`, `info` (see below). Required for a new row unless `replace` is set. |
| `value` | The number (or, for `range`/`pctrange`/`fromto`, a `{ min, max }` table, or, for `bool`, `true`/`false`) that `kind` formats. Not required for `info` rows, and not required when `replace` is set. |
| `text` | Translation key for the row's label, shown in Trait Facts' style. Required for a new row. If the key has no translation, the string is shown literally as plain text, and this does not raise the "translation key missing" warning. |
| `unit` | Translation key for the unit after the value (Trait Facts' own `UI_TF_unit_*` keys are free to reuse), or plain text. |
| `note` | Translation key or plain text for a note next to the row. |
| `hint` | Translation key or plain text for a side remark specific to this trait's own tooltip; dropped when several traits' rows are merged into the build overview. |
| `condition` | Translation key or plain text stating when the value applies exactly; unlike `hint`, this survives the merge into the build overview. |
| `dead` | `true` if the number exists in the game's code but never actually takes effect (the row is then shown greyed out with `note` explaining why). |
| `better` | `"up"`, `"down"` or `"open"`: which direction of the value is good, for the green/red coloring. Only applies the first time Trait Facts sees this `text`; a text Trait Facts already knows keeps its own direction. |
| `group` | One of Trait Facts' overview topics: `combat`, `movement`, `health`, `mind`, `food`, `sleep`, `senses`, `learning`, `crafting`, `vehicles`, `foraging`. Puts a row with a `text` Trait Facts does not already know into that topic of the build overview. Without `group`, an unknown `text` defaults to the `"crafting"` topic. Ignored for a `text` Trait Facts already knows, which keeps its own topic. Any other value is ignored with a warning; the row stays and is placed as if `group` were not set. |
| `replace` | `id` of an existing row (yours or Trait Facts' own) to replace, as a non-empty string. The new row inherits the other row's fields except what it sets itself, so a `replace` row can omit `value`, `kind` and `text` to only change, say, `unit` or `note`. |
| `remove` | `id` of an existing row to remove, as a non-empty string. No other field is read on a `remove` row. |

`probe` is accepted but ignored; it is reserved for Trait Facts' own runtime
measurement and never read from a package.

`text`, `note`, `unit`, `hint` and `condition` are all translation keys the
same way: none of them needs a translation, and a value without one is kept
and shown as plain text without any warning. Each of them must be a string
if set; any other type skips the row with a warning.

### The `kind` values

| `kind` | `value` | Rendered as |
| --- | --- | --- |
| `pct` | number | Percent change, `40` to `"+40%"` |
| `mult` | number | Factor, shown as the percent change it amounts to: `1.5` to `"+50%"`, `0.7` to `"-30%"`. Use `mult` when the game multiplies, so that the overview multiplies too. |
| `flat` | number | Absolute change, `20` to `"+20"` |
| `count` | number | Count with no sign, `15` to `"15x"` |
| `range` | `{ min, max }` | A span, `{ 2, 5 }` to `"2 to 5"` |
| `pctrange` | `{ min, max }` | A signed percent span, coloured like `pct`: `{ 13, 16 }` to `"+13 to +16%"` |
| `fromto` | `{ before, after }` | Before/after on a 0-100 scale, `{ 5, 10 }` to `"5% to 10%"` |
| `bool` | `true`/`false` | Yes/no |
| `info` | none | Text only, no number: the effect is real but cannot be given a value |

## Validation rules

Every row and package is checked before use. A rejected row or package is
skipped; nothing else is affected, and the game never fails because of a bad
package. Each distinct warning is logged once per session (see "What
appears in the log" below).

In the Log column, `...` stands for `Paket "<source>": <trait>: Zeile "<row>"`,
where `<row>` is the row's `id`, or else its `replace`/`remove` value, or
else its position in the trait's list (1, 2, ...).

| Case | Result | Log |
| --- | --- | --- |
| a row is not a table (for example a string slipped into the list) | that row skipped | none |
| `format` missing or not `1` | package skipped | `Paket "<source>": Format <N> unbekannt (Trait Facts kennt 1), Paket uebersprungen. Trait Facts aktualisieren.` |
| `source` missing or empty | package skipped | `Paket ohne source, uebersprungen.` |
| `modId` set, that mod not active | package skipped | `Paket "<source>": Mod "<modId>" nicht aktiv, Paket nicht gelesen.` (a notice, not a warning: the normal case for a package meant for your own mod) |
| trait key without a `namespace:` prefix | that trait's rows skipped | `Paket "<source>": Trait "<key>" ohne Namensraum (erwartet z. B. "modname:<key>"), uebersprungen.` |
| `remove` set but not a non-empty string | that row skipped | `...: remove muss ein Text sein, uebersprungen.` |
| `replace` set but not a non-empty string | that row skipped | `...: replace muss ein Text sein, uebersprungen.` |
| `text`, `note`, `unit`, `hint` or `condition` set but not a string | that row skipped | `...: <field> muss ein Text sein, uebersprungen.` |
| new row (no `replace`, no `remove`) without `id` | that row skipped | `... ohne id, uebersprungen.` |
| new row without `text` | that row skipped | `... ohne text, uebersprungen.` |
| `kind` set but not one of the allowed values | that row skipped | `... hat kind "<kind>" (erlaubt: pct, mult, flat, count, range, pctrange, fromto, bool, info), uebersprungen.` |
| new row without a valid `kind` | that row skipped | `... ohne kind, uebersprungen.` |
| new row (no `replace`) whose `kind` is not `info`, and `value` does not fit that `kind` | that row skipped | `...: Wert passt nicht zu kind "<kind>", uebersprungen.` |
| `replace` row that sets both `kind` and `value`, and they do not fit | that row skipped | same as above |
| `replace` row that sets `value` without `kind`, and the value does not fit the target row's `kind` | that row skipped when the tooltip is built | same as above |
| `value` is not a finite number (NaN, infinity) | that row skipped | same as above |
| `replace` row without `value` | accepted; it changes only the fields it sets (for example `text`, `unit`, `note`) | none |
| `group` set but not one of the overview topics | row kept, `group` ignored | `...: group "<group>" unbekannt (erlaubt: combat, movement, health, mind, food, sleep, senses, learning, crafting, vehicles, foraging), group ignoriert.` |
| `replace` or `remove` targets an `id` that does not exist on that trait | that row skipped | `Paket "<source>", <trait>: replace "<target>" trifft keine Zeile, uebersprungen.` (or `remove` in place of `replace`) |
| two packages set the same row on the same trait | both are kept; the one registered later wins | `<trait>, Zeile "<id>": "<later source>" ersetzt den Wert aus "<earlier source>" (zuletzt angemeldet gewinnt).` (a notice, not a warning) |

In short: a brand-new row always needs `id`, `text` and a valid `kind`, and
(unless `kind` is `info`) a `value` that matches that `kind`. A `replace` row
only needs to set the fields it wants to change; `value` is optional there.

## Version check

If your package sets both `modId` and `version`, and the mod that is
actually active reports a different version through `getModVersion()`, every
row from your package is marked as possibly outdated. Trailing `.0` parts, a
leading `v` and upper or lower case do not count: `1.0`, `v1.0` and `1.0.0`
are the same version. The values themselves
are still shown unchanged:

- In a trait's tooltip, a line at the top says "values for *your
  version*; *installed version* is installed, may be outdated" in orange.
  The value of each of those rows is orange, and its note starts with "may
  be outdated", followed by the row's own note.
- In the build overview, the value is orange and the row says "may be
  outdated".
- Hovering the tag in the overview shows "*installed version* is installed;
  values may be outdated" in orange.

This is logged once per package: `Paket "<source>" <version>: installiert
ist <installed>, Zeilen als moeglicherweise veraltet markiert.`

## What appears in the log

Trait Facts prefixes every line with `[TraitFacts] `. Two kinds of lines can
come from your package:

- `WARN: ...` for anything in the validation table above that causes a
  package, trait or row to be skipped or a `group` to be ignored, and for a
  package that raises a Lua error while being read:
  `WARN: Paket Nr. <n> nicht lesbar: <error>`. That error is caught and does
  not affect any other package or the game. Each distinct problem (by
  package, trait and row) is only logged once per game session, so a broken
  package will not flood the console.
- Plain log lines (no `WARN:`) for things that are not errors but are useful
  to know: the version check above, two packages setting the same row (the
  "zuletzt angemeldet gewinnt" notice above), and a package whose `modId`
  is not active. Also logged once per case.

The log lines are in German. The words that matter: `uebersprungen` means
skipped, `trifft keine Zeile` means the target row does not exist, `ohne`
means missing, `unbekannt` means unknown, `nicht aktiv` means not active.

## Reusing Trait Facts' own labels

If your trait changes something a vanilla trait also changes, use Trait
Facts' own translation key as `text` (and the same `unit` and `note`, or
none). Rows with the same `text`, `unit` and `note` are the same stat, and
the build overview combines them: your "+12%" melee damage and a vanilla
"-20%" become one line instead of two. The keys are in
`media/lua/shared/Translate/EN/UI.json` of Trait Facts, all starting with
`UI_TF_eff_` (for example `UI_TF_eff_meleedamage`, `UI_TF_eff_carry`,
`UI_TF_eff_xp`, `UI_TF_eff_enduranceloss`); units start with `UI_TF_unit_`.

The reverse also holds: if your value only applies in a narrower case than
the vanilla one (one weapon class, one vehicle type), say so in `note`.
Different notes keep the rows apart, and nothing is summed that the game
does not sum.

## Testing your package

1. Enable your mod and Trait Facts, start the game and open the character
   creation screen (Solo, any mode).
2. Hover one of your traits: your rows appear under "values from *source*
   *version*". Pick the trait: its rows appear in the build overview on the
   right.
3. Open `Zomboid/console.txt` and search for `[TraitFacts]`. Every skipped
   package, trait or row is listed there once, with the reason.

Trait Facts reads the queue again for every tooltip, so nothing needs a
particular load order. Lua files are only reloaded with the game, so restart
after a change.

## Compatibility promise

`format = 1` stays readable. New optional fields may be added to format 1;
a field listed above will not change its meaning or be removed. If the shape
of the data ever has to change, that will be `format = 2`, and Trait Facts
will keep reading format 1 packages next to it. Fields not listed in this
document are internal and may change without notice.

What the promise does not cover:

- **How a row looks.** Colours, order, how rows are merged in the overview,
  footnotes and truncation may change in any version. The promise is about
  the data you register, not about its rendering.
- **The game itself.** A game update can rename a trait or change a value, and
  a package that was right becomes wrong. Trait Facts marks such rows as "may
  be outdated" (see above), it cannot repair them.

Should a listed field ever have to go after all, Trait Facts will first log a
warning for it for at least one version before it stops reading the field.
