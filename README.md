# Trait Facts

**What your traits actually do.** A Project Zomboid mod for Build 42 that shows,
in the character creation screen, the real effect of every trait: the numbers the
game uses, with unit and base, and an overview of what your whole build adds up to.

Trait descriptions in the game say "faster" or "less". Trait Facts says by how
much, and where the number comes from.

- **Steam Workshop:** *link follows with the release*
- **Evidence wiki:** every value, where it comes from and how it was checked:
  <https://bluehelix-mods.github.io/trait-facts/>
- **Languages:** English, German, Russian, Simplified Chinese, Brazilian
  Portuguese, Spanish, French, Polish, Korean, Japanese, Turkish, Italian

## Where the numbers come from

Every value carries one of three sources, and the mod tells you which:

| Source | How | Example |
| --- | --- | --- |
| Live | read from the game while it runs | exclusions, granted traits, recipes, foraging, starting levels |
| Measured | measured in the running game with a test mod, trait on against trait off | walking speed, panic, endurance, sleep, fall damage, colds |
| Code | read from the game code of Build 42.20.4, stamped with that version | tree scratches, being spotted, hit chance |

If the game runs a different build than the stored values, the overview warns.
A few stored values are also measured each time the game starts; if a measurement
disagrees with the stored value, the measurement wins and the row is marked.

The values are for single player. Some differ in multiplayer, also when
hosting, for example Ax-pert's chopping, Handy's instant builds and the sleep
traits. Vanilla values assume the default sandbox settings; the Rising preset
turns off fractures, failed climbs and fence lunges, so those rows do not apply
there.

Along the way the measurements turned up behaviour the game does not describe,
from traits that do nothing to values that apply twice. The wiki lists them.

## Translations

English is the source and German is written by hand. The other ten languages
were translated with AI help and checked mechanically: every skill and trait name
uses the exact word the game itself uses in that language. No native speaker has
read them yet.
**Corrections are very welcome**: open an issue, or change
`mod/42/media/lua/shared/Translate/<LANG>/UI.json` and send a pull request.
`python tools/uebersetzung-pruefen.py <LANG>` checks a file before you send it.

## For mod authors

Trait Facts can show values for traits from other mods. A mod registers a data
package through a small public API; see [`docs/api.md`](docs/api.md). Values for
*More Traits Definitive* ship with Trait Facts as an example.

## Repository

| Folder | What |
| --- | --- |
| `mod/` | the mod as it ships |
| `docs/wiki/` | the wiki as published, one page |
| `docs/befunde/` | the evidence database behind the wiki |
| `docs/messungen/` | raw test logs, with a reading guide in English |
| `docs/api.md` | how another mod hands its numbers to Trait Facts |
| `docs/uebersetzung/` | the game's own words per language, for translators |
| `docs/workshop/` | the images of the Workshop page |
| `tools/` | the translation check, the test mod, a demo data pack |

Comments in the code and the evidence database are in German; the wiki shows
the same content in English.

## Made with AI help

I built this mod together with Claude. The measurements ran in my game, and where I
could I checked results by hand.

## License

Data and code: [CC BY-NC-SA 4.0](LICENSE). In short: copy, change and share the mod
or its numbers, with credit to "Trait Facts by Bluehelix", not commercially, and
under the same license.

Project Zomboid is the property of The Indie Stone. This mod is not affiliated
with or endorsed by them. The game sources read during development
stay local and are not part of this repository; it holds lists of trait names,
costs and IDs, and the reports quote a few lines of game code where a finding
depends on them.
