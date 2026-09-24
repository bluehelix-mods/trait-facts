#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Mechanische Pruefung einer Uebersetzung gegen EN (seit 0.12.15).

Was eine Maschine entscheiden kann, entscheidet sie hier; was Sprachgefuehl
braucht, steht in docs/uebersetzung/anleitung.md und liest ein Mensch oder ein
Pruefer-Agent. Geprueft wird:

  1. Die Datei ist gueltiges JSON, ein Objekt, UTF-8, mit LF und einer
     Leerzeile am Ende.
  2. Derselbe Schluesselsatz wie EN, nichts fehlt, nichts steht zu viel.
  3. Jeder Platzhalter aus EN (%1 bis %9) steht auch in der Uebersetzung,
     genau so oft. Ein verlorenes %1 zeigt im Spiel eine leere Stelle.
  4. Jedes einzelne Prozentzeichen ist als %% geschrieben (Build 42.20.1).
  5. Keine Geviert- oder Halbgeviertstriche.
  6. Kein Schluessel traegt noch den englischen Text, ausser den Zeichen und
     Einheiten, die in jeder Sprache gleich sind (SELBE_TEXTE).
  7. Kein Text ist mehr als LAENGE_FAKTOR mal so lang wie der englische; die
     Spalten der Uebersicht sind schmal. Nur ein Hinweis, kein Fehler.
  8. Keine schliessende spitze Klammer: ISRichTextPanel liest "<...>" als
     Befehl und frisst dann den halben Text.
  9. Nennt der englische Text einen Skill als Skill, traegt die Uebersetzung
     das Wort, mit dem das Spiel diesen Skill beschriftet (nur wenn die
     Uebersetzungen des Spiels auf dieser Maschine liegen).

Aufruf:  python tools/uebersetzung-pruefen.py            alle Sprachen
         python tools/uebersetzung-pruefen.py RU CN      nur diese
         python tools/uebersetzung-pruefen.py --normalisieren RU
                 schreibt die Datei kanonisch (sortiert, zwei Leerzeichen
                 Einrueckung, LF, UTF-8 ohne BOM) und prueft danach
Rueckgabe: 0 wenn sauber, 1 bei Befunden.
"""
import io
import json
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRANSLATE = os.path.join(ROOT, "mod", "42", "media", "lua", "shared", "Translate")

# Texte, die in jeder Sprache gleich stehen duerfen: Zeichen, Einheiten und
# Muster, die keine Woerter sind.
SELBE_TEXTE = {
    "UI_TF_build_missing_id", "UI_TF_bullet", "UI_TF_legend_tagsample", "UI_TF_search_why",
    "UI_TF_sum_title", "UI_TF_sym_deg", "UI_TF_sym_gain", "UI_TF_sym_lose", "UI_TF_sym_open",
    "UI_TF_unit_hp", "UI_TF_unit_pct", "UI_TF_xp_speed_value", "UI_TF_fmt_range",
    "UI_TF_fmt_pct", "UI_TF_fmt_mult", "UI_TF_fmt_plus", "UI_TF_decimalsep",
    "UI_TF_sep", "UI_TF_charTab",
    # "lvl" und "normal" stehen in vielen Sprachen genauso da; ob die eigene
    # eines davon uebersetzt, entscheidet der Uebersetzer.
    "UI_TF_unit_levels", "UI_TF_unit_levels_one", "UI_TF_xp_normal",
    # "min" ist in vielen Sprachen das Einheitensymbol der Minute und steht
    # dort ohne Punkt (im Spanischen fuehrt die RAE es unter den Symbolen).
    "UI_TF_unit_minutes", "UI_TF_unit_minutes_one",
}
LAENGE_FAKTOR = 2.2
# Unter dieser Laenge sagt ein Faktor nichts: aus "Yes" wird schnell etwas
# Dreifaches, ohne dass eine Spalte darunter litte.
LAENGE_AB = 12


def lies(pfad):
    with io.open(pfad, encoding="utf-8", newline="") as handle:
        return handle.read()


def platzhalter(text):
    return sorted(re.findall(r"%\d", text))


def pruefe(lang, englisch, roh):
    """@return (fehler, hinweise)"""
    fehler, hinweise = [], []
    if "\r\n" in roh:
        fehler.append("die Datei hat Windows-Zeilenenden; LF verwenden.")
    if not roh.endswith("\n"):
        hinweise.append("am Ende fehlt der Zeilenumbruch.")
    try:
        tabelle = json.loads(roh)
    except ValueError as fehlermeldung:
        return ["kein gueltiges JSON: %s" % fehlermeldung], hinweise
    if not isinstance(tabelle, dict):
        return ["die Datei ist kein JSON-Objekt, sondern %s." % type(tabelle).__name__], hinweise

    fehlt = sorted(set(englisch) - set(tabelle))
    zuviel = sorted(set(tabelle) - set(englisch))
    for key in fehlt:
        fehler.append('der Schluessel "%s" fehlt.' % key)
    for key in zuviel:
        fehler.append('der Schluessel "%s" steht in EN nicht.' % key)

    gleich = []
    for key in sorted(set(englisch) & set(tabelle)):
        quelle, ziel = englisch[key], tabelle[key]
        if not isinstance(ziel, str):
            fehler.append('%s: der Wert ist kein Text.' % key)
            continue
        if ziel.strip() == "":
            fehler.append("%s: der Text ist leer." % key)
            continue
        if platzhalter(quelle) != platzhalter(ziel):
            fehler.append('%s: Platzhalter %s statt %s ("%s").'
                          % (key, platzhalter(ziel) or "keine", platzhalter(quelle) or "keine", ziel))
        if "%" in re.sub(r"%%|%\d", " ", ziel):
            fehler.append('%s: unmaskiertes Prozentzeichen ("%s"). Ein einzelnes %% als %%%% schreiben.' % (key, ziel))
        if "—" in ziel or "–" in ziel:
            fehler.append("%s: Geviert- oder Halbgeviertstrich; Bindestrich nehmen." % key)
        if ">" in ziel or "<" in ziel:
            fehler.append('%s: spitze Klammer ("%s"); der Rich-Text des Spiels liest sie als Befehl.' % (key, ziel))
        if ziel == quelle and key not in SELBE_TEXTE:
            gleich.append(key)
        if len(quelle) >= LAENGE_AB and len(ziel) > len(quelle) * LAENGE_FAKTOR:
            hinweise.append("%s: %d statt %d Zeichen, mehr als das %.1f-fache (Spaltenbreite)."
                            % (key, len(ziel), len(quelle), LAENGE_FAKTOR))
    if gleich:
        fehler.append("%d Schluessel tragen noch den englischen Text: %s%s"
                      % (len(gleich), ", ".join(gleich[:10]), " ..." if len(gleich) > 10 else ""))
    return fehler, hinweise


# --------------------------------------------------- Treue zum Glossar
#
# Nennt der englische Text einen Skill als Skill ("at Carpentry level 0"),
# muss die Uebersetzung das Wort tragen, mit dem das Spiel diesen Skill in
# dieser Sprache beschriftet. Sonst sucht der Spieler es in seiner Oberflaeche
# vergeblich.
#
# Zwei Fallen, beide am 21.09.2026 in die Pruefung geflossen:
#   - Russisch und Polnisch beugen das Wort ("Сила" -> "Силы"). Verglichen wird
#     deshalb ein Stamm, nicht das ganze Wort.
#   - Das Spiel fuehrt fuer einen Skill mehrere Schluessel mit demselben
#     englischen Wort (IGUI_perks_Carpentry und IGUI_perks_Woodwork heissen
#     beide "Carpentry", auf Koreanisch aber 목공 und 목공예). Angezeigt wird,
#     was PerkFactory.AddPerk als Uebersetzungsnamen nennt; welcher das ist,
#     steht hier nicht fest. Es zaehlt deshalb jede Schreibweise des Spiels.
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
import spielpfad
SPIEL = spielpfad.uebersetzungen()


def spieltexte(lang, datei):
    pfad = os.path.join(SPIEL, lang, datei)
    if not os.path.isfile(pfad):
        return {}
    try:
        with io.open(pfad, encoding="utf-8", errors="replace") as handle:
            daten = json.load(handle)
    except ValueError:
        return {}
    return daten if isinstance(daten, dict) else {}


def stamm(wort):
    """Der Anfang des laengsten Wortes, lang genug zum Wiedererkennen."""
    wort = re.sub(r"^\d+\.\s*", "", wort).strip()
    teile = wort.split()
    kern = max(teile, key=len) if teile else wort
    return kern[:max(3, int(len(kern) * 0.65))].lower()


def nennt_skill(text, name):
    """Nennt `text` den Skill `name` als Skill, nicht als gewoehnliches Wort?

    "Aiming delay" meint das Zielen, nicht den Skill; "at Aiming level 0"
    meint den Skill. Gesucht werden nur die Wendungen, in denen ein Skill als
    Skill steht, sonst meldet die Pruefung lauter Scheinfunde.
    """
    n = re.escape(name)
    muster = r"\b%s level\b|\bper %s\b|\bin %s\b|\bwith %s \d|\b%s skill\b" % (n, n, n, n, n)
    return re.search(muster, text) is not None


def glossartreue(lang, englisch, tabelle):
    """@return (geprueft, [Befunde]); (0, []) ohne die Dateien des Spiels."""
    en_spiel = spieltexte("EN", "IG_UI.json")
    zi_spiel = spieltexte(lang, "IG_UI.json")
    if not en_spiel or not zi_spiel:
        return 0, []
    # Englisches Wort -> alle Schreibweisen, die das Spiel in der Zielsprache fuehrt.
    formen = {}
    for key, wort in en_spiel.items():
        reiner_name = (key.startswith("IGUI_perks_") and "_Description" not in key
                       and isinstance(wort, str) and 3 < len(wort) < 25 and "." not in wort)
        if reiner_name:
            ziel = zi_spiel.get(key)
            if isinstance(ziel, str) and ziel and ziel != wort:
                formen.setdefault(wort, set()).add(ziel)
    geprueft, befunde = 0, []
    for key in sorted(set(englisch) & set(tabelle)):
        for wort, zielformen in formen.items():
            if not nennt_skill(englisch[key], wort):
                continue
            geprueft += 1
            unten = tabelle[key].lower()
            if not any(stamm(z) in unten for z in zielformen):
                befunde.append('%s: nennt den Skill "%s"; das Spiel schreibt ihn %s, der Text sagt "%s".'
                               % (key, wort, " oder ".join(sorted('"%s"' % z for z in zielformen)), tabelle[key]))
    return geprueft, befunde


def normalisiere(pfad):
    """Schreibt die Datei kanonisch. @return None oder der Fehler als Text."""
    try:
        tabelle = json.loads(lies(pfad))
    except ValueError as fehler:
        return "kein gueltiges JSON: %s" % fehler
    if not isinstance(tabelle, dict):
        return "kein JSON-Objekt"
    text = json.dumps(dict(sorted(tabelle.items())), ensure_ascii=False, indent=2)
    with io.open(pfad, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text + "\n")
    return None


def main():
    englisch = json.loads(lies(os.path.join(TRANSLATE, "EN", "UI.json")))
    langs = [a for a in sys.argv[1:] if a != "--normalisieren"]
    normal = "--normalisieren" in sys.argv[1:]
    if not langs:
        langs = sorted(name for name in os.listdir(TRANSLATE) if name != "EN"
                       and os.path.isfile(os.path.join(TRANSLATE, name, "UI.json")))
    schlecht = 0
    for lang in langs:
        pfad = os.path.join(TRANSLATE, lang, "UI.json")
        if not os.path.isfile(pfad):
            print("%-5s FEHLT  %s" % (lang, os.path.relpath(pfad, ROOT)))
            schlecht += 1
            continue
        if normal:
            kaputt = normalisiere(pfad)
            if kaputt:
                print("%-5s FEHLT  %s" % (lang, kaputt))
                schlecht += 1
                continue
        fehler, hinweise = pruefe(lang, englisch, lies(pfad))
        treue = ""
        try:
            tabelle = json.loads(lies(pfad))
        except ValueError:
            tabelle = None
        if isinstance(tabelle, dict):
            geprueft, befunde = glossartreue(lang, englisch, tabelle)
            fehler.extend(befunde)
            treue = ", %d/%d Skill-Nennungen wie im Spiel" % (geprueft - len(befunde), geprueft) if geprueft else ""
        zeichen = "OK   " if not fehler else "FEHLT"
        print("%-5s %s %d Fehler, %d Hinweise%s" % (lang, zeichen, len(fehler), len(hinweise), treue))
        for text in fehler[:40]:
            print("        FEHLER: " + text)
        if len(fehler) > 40:
            print("        ... und %d weitere Fehler." % (len(fehler) - 40))
        for text in hinweise[:10]:
            print("        Hinweis: " + text)
        if len(hinweise) > 10:
            print("        ... und %d weitere Hinweise." % (len(hinweise) - 10))
        if fehler:
            schlecht += 1
    print("")
    print("%d von %d Sprachen sauber." % (len(langs) - schlecht, len(langs)))
    return 1 if schlecht else 0


if __name__ == "__main__":
    sys.exit(main())
