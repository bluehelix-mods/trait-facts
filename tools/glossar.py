#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Glossar je Sprache aus den Uebersetzungen des Spiels (seit 0.12.15).

Trait Facts nennt Skills, Trait-Namen, Berufe und Koerperteile. Wie sie in
einer Sprache heissen, weiss das Spiel selbst; wer es neu erfindet, schreibt
Woerter, die der Spieler in seiner Oberflaeche nirgends findet. Das Werkzeug
liest die Uebersetzungen des Spiels und legt je Sprache eine kleine
Nachschlagedatei an, Englisch neben der Zielsprache.

    python tools/glossar.py RU CN PTBR      nur diese Sprachen
    python tools/glossar.py                 alle unter SPRACHEN

Ziel: docs/uebersetzung/glossar-<LANG>.md, dazu die Liste der Sprachen, die
das Spiel wirklich fuehrt. Die Dateien sind Arbeitsmaterial, kein Teil der Mod.
"""
import io
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ZIEL = os.path.join(ROOT, "docs", "uebersetzung")
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
import spielpfad
SPIEL = spielpfad.uebersetzungen()

# Die Sprachen, in die Trait Facts uebersetzt wird: die groessten Gruppen der
# Zomboid-Spieler ausser Englisch und Deutsch (Entscheidung 21.09.2026).
SPRACHEN = ["RU", "CN", "PTBR", "ES", "FR", "PL", "KO", "JP", "TR", "IT"]

# Was nachgeschlagen wird, je Datei des Spiels: die Praefixe der Schluessel.
QUELLEN = {
    "IG_UI.json": ("IGUI_perks_",),
    "UI.json": ("UI_trait_", "UI_profession_"),
    "Moodles.json": ("Moodles_",),
    "BodyParts.json": ("",),
}

# Begriffe, die in unseren Texten immer wieder vorkommen und im Spiel unter
# einem Schluessel stehen, den kein Praefix oben trifft.
EINZELN = {
    "UI.json": ["UI_optionscreen_goodHighlightColor", "UI_optionscreen_badHighlightColor",
                "UI_optionscreen_accessibility", "UI_characreation_traits", "UI_characreation_occupation",
                "UI_characreation_addtrait", "UI_characreation_removetrait"],
    "IG_UI.json": ["IGUI_char_Weight", "IGUI_char_Calories", "IGUI_health_Bandage",
                   "IGUI_PlayerText_Exhausted", "IGUI_PlayerText_Panic"],
}


def lies(lang, datei):
    pfad = os.path.join(SPIEL, lang, datei)
    if not os.path.isfile(pfad):
        return {}
    try:
        with io.open(pfad, encoding="utf-8", errors="replace") as handle:
            daten = json.load(handle)
    except ValueError:
        return {}
    return daten if isinstance(daten, dict) else {}


def sammeln(lang):
    """Schluessel -> Text, nur was die Sprache wirklich fuehrt."""
    out = {}
    for datei, praefixe in QUELLEN.items():
        tabelle = lies(lang, datei)
        for key, value in tabelle.items():
            if isinstance(value, str) and any(key.startswith(p) for p in praefixe):
                out[key] = value
    for datei, keys in EINZELN.items():
        tabelle = lies(lang, datei)
        for key in keys:
            if isinstance(tabelle.get(key), str):
                out[key] = tabelle[key]
    return out


def schreiben(lang):
    englisch, ziel = sammeln("EN"), sammeln(lang)
    gemeinsam = sorted(k for k in englisch if k in ziel and ziel[k] != englisch[k])
    nur_en = sorted(k for k in englisch if k not in ziel or ziel[k] == englisch[k])
    zeilen = [
        "# Glossar %s" % lang,
        "",
        "Aus den Uebersetzungen des Spiels (Build 42). **Diese Woerter genau so",
        "benutzen**: der Spieler sieht sie in seiner Oberflaeche.",
        "",
        "| Englisch | %s | Schluessel im Spiel |" % lang,
        "| --- | --- | --- |",
    ]
    for key in gemeinsam:
        zeilen.append("| %s | %s | `%s` |" % (englisch[key], ziel[key], key))
    zeilen += [
        "",
        "## Im Spiel nicht uebersetzt",
        "",
        "Diese Begriffe stehen in %s genauso da wie im Englischen. Sie bleiben" % lang,
        "deshalb auch bei uns englisch, sonst passt unser Text nicht zum Spiel.",
        "",
        ", ".join(sorted(set(englisch[k] for k in nur_en))) or "(keine)",
        "",
    ]
    os.makedirs(ZIEL, exist_ok=True)
    pfad = os.path.join(ZIEL, "glossar-%s.md" % lang)
    with io.open(pfad, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(zeilen))
    return pfad, len(gemeinsam), len(nur_en)


def main():
    if not os.path.isdir(SPIEL):
        print("Die Uebersetzungen des Spiels liegen nicht unter %s." % SPIEL)
        return 1
    langs = sys.argv[1:] or SPRACHEN
    for lang in langs:
        if not os.path.isdir(os.path.join(SPIEL, lang)):
            print("%s: das Spiel kennt diese Sprache nicht." % lang)
            continue
        pfad, treffer, offen = schreiben(lang)
        print("%-5s %3d uebersetzte Begriffe, %3d bleiben englisch  ->  %s"
              % (lang, treffer, offen, os.path.relpath(pfad, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
