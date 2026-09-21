# -*- coding: utf-8 -*-
"""Wo Project Zomboid installiert ist.

Die Werkzeuge, die in die Spieldateien sehen (Glossar, Uebersetzungspruefung,
die jar-Helfer), fragen hier nach. Reihenfolge:

  1. die Umgebungsvariable PZ_DIR,
  2. die Datei tools/spielpfad.lokal.txt (eine Zeile, nicht im Repo),
  3. der uebliche Ort einer Steam-Installation unter Windows.
"""
import os

HIER = os.path.dirname(os.path.abspath(__file__))


def spielordner():
    env = os.environ.get("PZ_DIR")
    if env:
        return env
    lokal = os.path.join(HIER, "spielpfad.lokal.txt")
    if os.path.isfile(lokal):
        with open(lokal, encoding="utf-8") as handle:
            zeile = handle.read().strip()
        if zeile:
            return zeile
    return os.path.join("C:" + os.sep, "Program Files (x86)", "Steam", "steamapps", "common", "ProjectZomboid")


def jar():
    return os.path.join(spielordner(), "projectzomboid.jar")


def uebersetzungen():
    return os.path.join(spielordner(), "media", "lua", "shared", "Translate")
