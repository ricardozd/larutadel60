---
name: guide-format
description: Usar al crear, editar o leer rutas de leveo (data/routes/**/*.json) o al trabajar con las guías compiladas (addon/LaRutaDel60/Guides). Define el esquema JSON de una ruta, sus reglas de validación y cómo se compila a Lua.
---

# Formato de guía

Las rutas son DATOS. Fuente: `data/routes/<alliance|horde|both>/<id>.json`. Se compilan a `addon/LaRutaDel60/Guides/<id>.lua` + `Guides.xml`, que nunca se editan a mano.

## Ruta
| Campo | Tipo | Regla |
|---|---|---|
| id | string | kebab-case; igual al nombre del archivo; único |
| name | {enUS, esES?} | enUS obligatorio |
| faction | string | Alliance, Horde o Both |
| races, classes | string[] | opcional (p. ej. "Human", "Warrior") |
| minLevel, maxLevel | int | 1..60, min <= max |
| next | string | opcional, id de una ruta existente |
| carriedQuests | int[] | quests aceptadas en rutas anteriores |
| steps | Step[] | no vacía |

## Step
| type | Obligatorio | Significado |
|---|---|---|
| accept | questId | aceptar la quest |
| complete | questId (aceptada antes o en carriedQuests) | completar objetivos |
| turnin | questId (aceptada antes o en carriedQuests) | entregar |
| goto | coords | ir a un punto |
| hearth | — | usar la piedra de hogar |
| fly | — | volar (destino en text/coords) |
| train | — | entrenar clase o profesión |
| note | text | instrucción libre |

Opcionales en cualquier paso: `npcId` (int > 0), `coords {mapId, x, y}` (x e y en 0-100; mapId = uiMapID), `text {enUS, esES?}`, `source` (URL).

Claves desconocidas o `null` → error.

## En Lua
`ns.Guides["<id>"]` contiene exactamente los mismos datos que el JSON (lo garantiza un test de aceptación de ida y vuelta).

## Comandos
- Validar: `python3 tools/validate_routes.py`
- Compilar: `python3 tools/compile_guides.py` (`--check` en CI)
El hook post-edición valida al guardar cualquier JSON de data/routes.

## Ejemplo
`data/routes/alliance/alliance-northshire-example.json`.
