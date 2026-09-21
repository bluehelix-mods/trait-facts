# More Traits Definitive: Fundstellen je Zeile des Datenpakets

Stand 21.09.2026. Geprüft wurde jede Zeile von
`mod/42/media/lua/shared/TraitFacts/packs/TF_Pack_MoreTraits.lua` gegen den
installierten Code von More Traits Definitive (Workshop 3799050151). Die Zahlen
sind aus dessen Code gelesen, nicht gemessen.

Pfade sind relativ zum Mod-Ordner `moreTraitsDefinitive/42.0/`. Kürzel:
`S/` = `media/lua/shared/MT/`, `Tick` = `S/MT_Tick.lua`, `SBX` =
`media/sandbox-options.txt` (Zeile der Vorgabe), `DEF` =
`media/scripts/ToadTraits.txt`.

## Ergebnis

Von 129 Zeilen stimmten 95 so, wie sie dastanden. 8 waren falsch und sind seit
Trait Facts 0.13.7 berichtigt, 17 sind unklar (Zahl richtig, Fußnote oder
Bedingung ungenau), bei 9 fehlt der Hinweis auf die Sandbox-Option. Jede Zeile
hat eine Fundstelle, und jede genannte Funktion wird in der Mod wirklich
aufgerufen (verdrahtet in `Tick:153-163`, Erschaffung in
`S/MT_Creation.lua:458-460`).

Chancen: `ZombRand(0,101) <= N` ergibt (N+1) von 101. Das Paket schreibt N+1.

Nicht geprüft: ob das `damage`-Argument von OnWeaponHitCharacter der wirklich
abgezogenen Gesundheit entspricht (alle Nahkampf-Prozente beziehen sich darauf),
und die Mehrspieler-Pfade in `server/MT_ServerCommands.lua`.

### Berichtigt in 0.13.7

| Trait | Zeile | vorher | im Code | Fundstelle |
| --- | --- | --- | --- | --- |
| Pro Blade, Pro Blunt, Pro Spear | mtcrit | 5 von 100 | `ZombRand(0,101) <= 5`, also 6 von 101 | S/MT_Combat.lua:24, :57 |
| Quick Rest | mtrest | 3,3 bis 7,2 % je Spielstunde | 0.055 am Boden, 0.12 auf Möbeln, auf dem Balken 0 bis 1, je Spielminute: 5,5 und 12 % | S/MT_Rest.lua:161-168, Tick:114 |
| Expert Driver | mtengine | x3 | Motorkraft x6 | S/MT_World.lua:202 |
| Poor Driver | mtengine | x0.66 | Motorkraft x0.5; die 0.66 gehören zum Tempomat | S/MT_World.lua:211, :214 |
| Second Wind | Fußnote | einmal je 7 Spieltage | lädt nach dem ersten Mal nie wieder auf: `SecondWindRecharge` kehrt zurück, solange `secondwinddisabled` wahr ist, und nur es selbst setzte das zurück | S/MT_Rest.lua:57, :50, :71 |
| Indefatigable | Fußnote | einmal je Figur | lädt nach 7 x 24 Stunden wieder auf, auch mit One Use | S/MT_Indefatigable.lua:84-86, :94-113 |
| Bouncer | Fußnote | 5 von 100 | 6 von 101 | S/MT_State.lua:525-527 |

More Traits wurde am 17. und 18.09.2026 aktualisiert, `MTModVersion` blieb dabei
42.20. Ob das Paket bei den Fahrer-Traits und den beiden Fußnoten ältere Werte
trug, lässt sich nicht mehr prüfen. Die Versionsangabe taugt nicht als Warnung
vor Änderungen.

### Unklar, noch offen

| Trait / Zeile | Was nicht passt | Fundstelle |
| --- | --- | --- |
| scrounger / mtloot | Zahl stimmt (11 von 100). "Etwa 30 % mehr" passt nicht: es kommen `floor(Anzahl x 1.3)` Stück dazu, ab 5 Stück das Doppelte. Die wirksamen Optionen `ScroungerItemChance` und `ScroungerLootModifier` sind nicht genannt | S/MT_Containers.lua:9, :34, :62-71; SBX:135/140 |
| glassbody / mtglass | Zahl stimmt. "Noch einmal abgezogen" passt nicht: bei gelungenem Wurf wird das Doppelte der verlorenen Gesundheit abgezogen; Bruch erst über 0.33, Kratzer über 0.1 | S/MT_State.lua:34-56, :71 |
| actionhero / mtcrowd | 25,5 % ist nur das Beispiel mit fünf Zombies, es gibt keine Obergrenze; auch Zombies bis 5 und bis 10 Felder zählen; gilt für jede Waffe | S/MT_Combat.lua:151-181 |
| badteeth / mteat | 25 Punkte stimmen im Code. Offen: die Datei hängt sich zweimal an `ISEatFoodAction.complete`; liefen beide, wären es 50 | media/lua/server/MT_EatFood.lua:25-47 |
| drinker / mtpoison | 14,6 statt 14; die Optionen `AlcoholicWithdrawal` und `NonlethalAlcoholic` sind nicht genannt | S/MT_Alcohol.lua:154-191; SBX:40, :225 |
| anemic, thickblood / mtbleed | Zahlen stimmen. "Nur ohne Verband" hängt an `IsBleedingStemmed`; ob das Spiel das beim Verbinden setzt, ist nicht geprüft | S/MT_State.lua:632-647 |
| mundane / mtcritfix | setzt den Grundwert der Waffe auf 1; was das Spiel darauf rechnet, ist nicht geprüft. Mundane schaltet außerdem die Boni der drei Pro-Traits, von Action Hero und Martial ab; das steht in keiner Zeile | S/MT_Combat.lua:201-202, :22, :176, :290 |
| terminator, antigun / mtaim | Code stimmt (x2, x0.8 auf setAimingTime). Die Beschreibung der Mod sagt das Gegenteil | S/MT_Combat.lua:442, :449 |
| gourmand, ascetic / mtcook | Zahlen stimmen, gelten aber nur für Essen, das im Hauptinventar war | S/MT_Nutrition.lua:65-68, :142-145, :218-236 |
| lucky, unlucky / mtluck | die Option Luck Impact gilt nur in der Sitzung, in der die Figur erschaffen wurde; nach dem Laden steht der Faktor auf 1.0 | S/MT_Creation.lua:293-295; S/MT.lua:10 |
| butterfingers / mtdrop | Zeile stimmt. Es würfelt je Spielminute, nicht je Bild: 0,2 % je Spielminute ohne Last wären als Zahl möglich | S/MT_State.lua:216-256; Tick:100 |
| burned / mtfire | die Option Fire Aversion schaltet nur die Aktionen am Feuer ab, nicht das Verbot von Molotows und Flammenfallen | media/lua/shared/TimedActions/MT_BurnWard.lua; S/MT_Combat.lua:723-738 |

Zahl richtig, Hinweis auf die Sandbox-Option fehlt: progun/mtammo
(`ProwessGunsAmmoRestore`), martial/mtdamage (`MartialScaling`,
`MartialWeapons`), packmule und packmouse/mtcarry (`WeightPackMule`,
`WeightPackMouse`, `WeightGlobalMod`), graverobber/mtcorpse
(`GraveRobberChance`, `GraveRobberGuaranteedLoot`), incomprehensive/mtlost
(`IncomprehensiveChance`), injured/mtinjury (`InjuredBurns`),
gordanite/mtcrowbar (`GordaniteEffectiveness`), ingenuitive/mtrecipes
(`IngenuitiveLimit`, `IngenuitiveLimitAmount`).

## Fundstelle je Zeile

Kampf
- problade, problunt, prospear / mtdamage: S/MT_Combat.lua:61 (Krit verdoppelt :57-59, Waffenklassen :26-49)
- problade, problunt, prospear / mtcrit: S/MT_Combat.lua:24, :33-36, :44, :47, :57
- problade, problunt, prospear / mtrepair: S/MT_Combat.lua:63-67
- progun / mtammo: S/MT_Combat.lua:331-333, :362-368; SBX:270
- progun / mtrepair: S/MT_Combat.lua:348-352
- tavernbrawler / mtdamage: S/MT_Combat.lua:95-115
- tavernbrawler / mtrepair: S/MT_Combat.lua:96, :103, :110-111, :117-123
- actionhero / mtcrowd: S/MT_Combat.lua:151-153, :160-168, :176-181
- actionhero / mtcrit: S/MT_Combat.lua:151, :161, :164, :167, :176
- martial / mtdamage: S/MT_Combat.lua:267-271, :278-295; SBX:90, :205
- martial / mtcrit: S/MT_Combat.lua:272-276, :289
- unwavering / mtdamage: S/MT_Combat.lua:229-238, :244; SBX:200
- mundane / mtcritfix: S/MT_Combat.lua:201-202
- terminator / mtgundmg: S/MT_Combat.lua:445-446; mtrange :443; mtjam :444; mtaim :442
- terminator / mtpanic: S/MT_Combat.lua:415-417, :429; je Spielminute, Tick:107
- terminator / mtlevels: S/MT_Creation.lua:398-402
- antigun / mtrange: S/MT_Combat.lua:450; mtaim :449; mtmood :419-421, :435; mtxp S/MT_XP.lua:92-94
- batteringram / mtram: S/MT_Combat.lua:486, :496-532; mtramend :513-514, :534-535
- gordanite / mtcrowbar: S/MT_Weapons.lua:73-103; Auslöser S/MT_Combat.lua:740-748; SBX:85
- amputee / mthands: S/MT_Combat.lua:715-720, :751-762; mtarm :679-694
- burned / mtfire: media/lua/shared/TimedActions/MT_BurnWard.lua:1-15, :101-113; S/MT_Combat.lua:723-738; SBX:283
- burned / mtinjury: S/MT_Creation.lua:355-364
- leadfoot / mtstomp: S/MT_World.lua:256-257

Bewegung und Tragen
- fast / mtmove: S/MT_World.lua:138-145, :173-175; SBX:304/309/314
- gimp / mtmove: S/MT_World.lua:146-153, :169-171; SBX:319/324/329
- packmule / mtcarry: S/MT_Weight.lua:7, :13; SBX:160
- packmouse / mtcarry: S/MT_Weight.lua:9, :13; SBX:165
- fitted / mtclothw: S/MT_World.lua:308-311; mtcloths :294-307

Gesundheit
- evasive / mtdodge: S/MT_State.lua:116-119; SBX:100
- anemic / mtbleed: S/MT_State.lua:636-641, :659
- thickblood / mtbleed: S/MT_State.lua:642-647, :671
- idealweight / mtcal: S/MT_Nutrition.lua:254-261
- superimmune / mtfever: S/MT_SuperImmune.lua:31-52; SBX:240/245
- immunocompromised / mtinfect: S/MT_State.lua:182-192; SBX:265; mtwound :688, :696-702
- glassbody / mtglass: S/MT_State.lua:34-56
- selfdestructive / mtharm: S/MT_State.lua:362-366, :374
- badteeth / mteat: media/lua/server/MT_EatFood.lua:25-26
- hardy / mtreserve: S/MT_State.lua:472-475, :480-495; S/MT.lua:32-33; SBX:235
- secondwind / mtwind: S/MT_Rest.lua:12, :21, :30-33, :50; Aufladen :57-72; SBX:230
- indefatigable / mtlast: S/MT_Indefatigable.lua:9, :15-17, :27-35, :46-55, :84-86; Aufladen :89-116; SBX:75/80
- quickrest / mtrest: S/MT_Rest.lua:161, :164, :168
- restfulsleeper / mtsleep: S/MT_Rest.lua:90-96; Aufwachen :114-115
- albino / mtsun: S/MT_World.lua:74-81, :42, :51
- injured / mtinjury: S/MT_Creation.lua:306-342; SBX:15
- broke / mtinjury: S/MT_Creation.lua:344-353

Essen
- gourmand / mtcook: S/MT_Nutrition.lua:65-68; mtfood :71-120; mtfresh S/MT_Containers.lua:767, :786-787
- ascetic / mtcook: S/MT_Nutrition.lua:142-145; mtfood :152-212

Fundglück
- scrounger / mtloot: S/MT_Containers.lua:8-12, :34, :62-71; SBX:135/140
- incomprehensive / mtlost: S/MT_Containers.lua:133-135, :148, :167-186; SBX:145
- vagabond / mtbin: S/MT_Containers.lua:331-332, :347-352, :388; SBX:150/155
- antique / mtantique: S/MT_Containers.lua:225-226, :290-294; SBX:210/215
- graverobber / mtcorpse: S/MT_Containers.lua:430-443, :729-730; SBX:120/125
- lucky, unlucky / mtluck: S/MT.lua:158-165; S/MT_Creation.lua:293-295; SBX:30

Psyche
- paranoia / mtscare: S/MT_State.lua:263-276, :283-284, :301
- depressive / mtmood: S/MT_State.lua:314-325
- fearful / mtscream: S/MT_State.lua:578-605
- drinker / mtcrave: S/MT_Alcohol.lua:109-136; SBX:35; mtpoison :154-191; SBX:40; mtgear S/MT_Creation.lua:217-219; SBX:20

Lernen
- specweapons, specfood, specguns, specmove, speccrafting, specaid / mtxp: S/MT_XP.lua:5-42, :61-66, :86-89, :97; SBX:45
- gymgoer / mtxp: S/MT_XP.lua:125-138; SBX:65; mtstiff :144-222; SBX:70
- noxpshooter / mtlevels: S/MT_Creation.lua:371-373; noxptechnician :375-378; noxpfirstaid :380-382; noxpaxe :384-387; noxpmaintenance :389-391; noxpsneaky :393-396

An den Bildtakt gebunden
- noodlelegs / mttrip, mttripsprint, mttripskill: S/MT_Combat.lua:596-623
- butterfingers / mtdrop: S/MT_State.lua:216-256 (je Spielminute, Tick:100); SBX:115
- bouncer / mtbounce: S/MT_State.lua:515-551; SBX:50/55/60
- blissful / mtbliss: S/MT_State.lua:384-418

Nur Boosts
- bladetwirl DEF:99-107; blunttwirl DEF:121-129; flexible DEF:259-267; grunt DEF:338-346; olympian DEF:576-584; quiet DEF:799-807; swift DEF:961-969; tinkerer DEF:1004-1012. Keiner davon kommt im Lua der Mod vor.
- scrapper / mtboosts, mtrecipes: DEF:822-831, keine GrantedRecipes, kein Lua-Verweis; die Beschreibung verspricht Rezepte
- wildsman / mtrecipes: DEF:1047-1056

Handwerk und Start
- ingenuitive / mtrecipes: S/MT_Creation.lua:246-282, :366-369; Tick:135-138
- quickworker / mtaction: S/MT.lua:288-343; media/lua/client/MT/MT_QuickSlowWorker.lua:9-20; SBX:180
- slowworker / mtaction: S/MT.lua:305, :337-339; SBX:185
- preparedfood / mtgear: S/MT_Creation.lua:21-41; preparedammo :42-63; preparedweapon :64-68; preparedmedical :69-97; preparedrepair :98-115; preparedcamp :116-144; preparedpack :145-149; preparedcar :150-177; preparedcoordination :178-215
- deprived / mtbare: S/MT_Creation.lua:11-19; SBX:220

Fahrzeuge
- expertdriver / mtengine: S/MT_World.lua:202; mtspeed :203; mtbrake :201
- poordriver / mtengine: S/MT_World.lua:211; mtspeed :212; mtbrake :210
- Beides gilt nur am Steuer (:183) und nicht mit der Mod Driving Skill (:179).

## Traits ohne eigene Zeile

Die Mod meldet 99 Traits an, 96 davon mit Definition. Drei haben keine eigene
Zeile und lesen ihre Werte live aus dem Spiel: Gun Specialist (DEF:349-359, nur
XP-Boosts), Natural (DEF:489-498, XP-Boosts) und Generator (DEF:271-281, nur ein
Rezept). Ohne Definition und darum nicht wählbar: brooding, heavydrinker,
lightdrinker.
