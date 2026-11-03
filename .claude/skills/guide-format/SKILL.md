---
name: guide-format
description: Use when creating, editing or reading leveling routes (data/routes/**/*.json) or working with the compiled guides (addon/LaRutaDel60/Guides). Defines a route's JSON schema, its validation rules and how it compiles to Lua.
---

# Guide format

Routes are DATA. Source: `data/routes/<alliance|horde|both>/<id>.json`. They are compiled to `addon/LaRutaDel60/Guides/<id>.lua` + `Guides.xml`, which are never edited by hand.

## Route
| Field | Type | Rule |
|---|---|---|
| id | string | kebab-case; equal to the file name; unique |
| name | {enUS, esES?} | enUS required |
| faction | string | Alliance, Horde or Both |
| races, classes | string[] | optional (e.g. "Human", "Warrior") |
| minLevel, maxLevel | int | 1..60, min <= max |
| next | string | optional, id of an existing route |
| carriedQuests | int[] | quests accepted in earlier routes |
| steps | Step[] | non-empty |

## Step
| type | Required | Meaning |
|---|---|---|
| accept | questId | accept the quest |
| complete | questId (accepted earlier or in carriedQuests) | complete objectives |
| turnin | questId (accepted earlier or in carriedQuests) | turn in |
| goto | coords | go to a point |
| hearth | — | use the hearthstone |
| fly | — | fly (destination in text/coords) |
| train | — | train class or profession |
| note | text | free-form instruction |

Optional on any step: `npcId` (int > 0), `coords {mapId, x, y}` (x and y in 0-100; mapId = uiMapID), `text {enUS, esES?}`, `source` (URL).

Unknown keys or `null` → error.

## In Lua
`ns.Guides["<id>"]` contains exactly the same data as the JSON (guaranteed by a round-trip acceptance test).

## Commands
- Validate: `python3 tools/validate_routes.py`
- Compile: `python3 tools/compile_guides.py` (`--check` in CI)
The post-edit hook validates any data/routes JSON on save.

## Example
`data/routes/alliance/alliance-northshire-example.json`.
