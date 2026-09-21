# Contributing to Trait Facts

Trait Facts is a mod for Project Zomboid, Build 42.20.

There are two ways to reach the project, and both are read. On Steam, for
everyone: the pinned discussions "Bug reports", "Translations" and "Data packs
for mod authors" on the Workshop page of Trait Facts. Here on GitHub, if you
prefer issues and pull requests: the issue forms "Bug", "Wrong number" and
"Translation", or a pull request as described below.

Do not post a whole console.txt anywhere. It contains your Windows user name.
Post only the lines that contain TraitFacts.

## Fix a translation

English is the source and German is written by hand. The other ten languages
were translated with AI help and checked by machine, but no native speaker has
read them yet.

1. Edit `mod/42/media/lua/shared/Translate/<LANG>/UI.json`. `<LANG>` is one of
   DE, RU, CN, PTBR, ES, FR, PL, KO, JP, TR, IT. A mistake in the English text
   is fixed the same way in `Translate/EN/UI.json`.
2. Keep the keys and the placeholders (`%1` to `%9`) as they are. Write a
   percent sign as `%%`. Do not use `<` or `>`. The game reads text in angle
   brackets as a command and drops the rest of the line. Do not use em dashes
   or en dashes; use a hyphen.
3. Name a skill the way the game names it in your language. The game's words
   for skills, traits, occupations and body parts are listed in
   `docs/uebersetzung/glossar-<LANG>.md` (columns: English, the game's word,
   key). There is no such list for DE.
4. Optional, if you have Python: run
   `python tools/uebersetzung-pruefen.py <LANG>`. The output is in German.
   `1 von 1 Sprachen sauber` means the file is clean; each line that starts
   with `FEHLER` names a key to fix.
   `python tools/uebersetzung-pruefen.py --normalisieren <LANG>` writes the
   file in the expected form (sorted keys, two spaces, LF, UTF-8). Without
   Python, skip this step; the maintainer runs the check before the merge.
5. Open a pull request. A pull request for a translation changes only
   `Translate/<LANG>/UI.json`, nothing else.

If you do not want to open a pull request, use the issue form "Translation".

## Write a data pack for your own mod

If your mod adds traits or changes what a vanilla trait does, it can hand
Trait Facts its numbers. Your mod does not need Trait Facts as a dependency.
The format, a complete example and the validation rules are in
[docs/api.md](docs/api.md). Questions go to the thread "Data packs for mod
authors" on the Workshop page.

## Report a wrong number

Use the issue form "Wrong number". Name the trait, the value that Trait Facts
shows and the value it should be. A report is easiest to check when it comes
with the place in the game code (class and method) or with a measurement in
the game and the steps to repeat it. Name the game version you checked.

The wiki shows where every value comes from, in this order: read live from
the running game, measured with a test mod, or taken from the game code of
42.20.4: https://bluehelix-mods.github.io/trait-facts/

## Report a bug

In character creation, press the bug icon in the header of the overview, to
the right of the gear and the two build buttons (tooltip "Report a bug"). The
button copies the version details to the clipboard and opens the Workshop
discussions. Paste the text into your report, either in the thread "Bug
reports" or in the issue form "Bug".

## License

Trait Facts is licensed under CC BY-NC-SA 4.0 (see [LICENSE](LICENSE)), credit
"Trait Facts by Bluehelix". By opening a pull request you agree that your
contribution is published under the same license.
