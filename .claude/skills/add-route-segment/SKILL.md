---
name: add-route-segment
description: Usar cuando el usuario pida añadir o rehacer un tramo de ruta de leveo (p. ej. "ruta humano 1-10", "Horda 30-40 en Stranglethorn"). Orquesta investigar → JSON crudo → optimizar → validar → compilar → commit.
---

# Añadir un tramo de ruta

Entrada: facción, raza o clase (si aplica), rango de niveles y zonas.

1. **Plan:** decide el id (`<faccion>-<zona>-<min>-<max>`), la ruta anterior (para su `next`) y las quests arrastradas.
2. **Investigar:** agente `route-researcher` por zona → `data/raw/<zona>.json`. Comprueba que cada quest tenga `source`.
3. **Optimizar:** agente `route-optimizer` → `data/routes/<faccion>/<id>.json`. Actualiza el `next` de la ruta anterior.
4. **Validar:** agente `route-validator`. Si hay problemas, vuelve al paso 3 con el informe (máx. 3 vueltas; si siguen, informa al usuario).
5. **Compilar:** `python3 tools/compile_guides.py` y `tools/check.sh` en verde.
6. **Commit:** `git add data/ addon/LaRutaDel60/Guides && git commit -m "feat(routes): <id>"` (con el trailer `Co-Authored-By`).
7. Informa al usuario en castellano: niveles cubiertos, nº de pasos, quests con `"forever": false`, y pide que lo pruebe en el juego.

No inventes datos: lo que falte se marca en el informe, nunca se rellena.
