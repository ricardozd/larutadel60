---
name: add-route-segment
description: Use when the user asks to add or redo a leveling route segment (e.g. "human route 1-10", "Horde 30-40 in Stranglethorn"). Orchestrates research → raw JSON → optimize → validate → compile → commit.
---

# Add a route segment

Input: faction, race or class (if applicable), level range and zones.

1. **Plan:** decide the id (`<faction>-<zone>-<min>-<max>`), the previous route (for its `next`) and the carried quests.
2. **Research:** `route-researcher` agent per zone → `data/raw/<zone>.json`. Check that every quest has `source`.
3. **Optimize:** `route-optimizer` agent → `data/routes/<faction>/<id>.json`. Update the `next` of the previous route.
4. **Validate:** `route-validator` agent. If there are problems, go back to step 3 with the report (max. 3 rounds; if they persist, inform the user).
5. **Compile:** `python3 tools/compile_guides.py` and `tools/check.sh` green.
6. **Commit:** `git add data/ addon/LaRutaDel60/Guides && git commit -m "feat(routes): <id>"` (with the `Co-Authored-By` trailer).
7. Reply to the user in Spanish; everything written to the repo is in English. Report: levels covered, number of steps, quests with `"forever": false`, and ask them to test it in the game.

Do not invent data: whatever is missing is flagged in the report, never filled in.
