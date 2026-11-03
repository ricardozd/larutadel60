---
name: debug-in-game
description: Use when the user pastes an in-game error (BugSack/BugGrabber, chat message, Lua error) or their SavedVariables, or says something in the addon does not work in WoW. Turns the failure into an acceptance test that reproduces it and then fixes it.
---

# Debug an in-game failure

Also use `superpowers:systematic-debugging`.

1. Ask for whatever is missing: the full error with stack (in BugSack, copy it), addon version (`/ruta`), what they were doing and, if it is a data problem, `WTF\Account\<ACCOUNT>\SavedVariables\LaRutaDel60.lua`.
2. Locate the `file:line` of the stack inside `addon/LaRutaDel60`. If the error is in Blizzard code, find which call of ours triggers it.
3. "attempt to call a nil value" on a WoW API = API does not exist in Forever → `wow-api-expert` agent.
4. Write an acceptance test in `tests/acceptance/` that reproduces what the player saw. If needed, extend the emulation in `tests/support/` with the real observed behavior and document it in `docs/api/forever-api.md`. Only NEW test files (`*_spec.lua`) are added and `tests/support/` is only extended additively (new emulated functions or APIs) without changing existing behavior. Any change in `tests/support/` requires explicit user approval, because `lua-reviewer` treats it as critical. Never modify existing tests or emulations; if one looks wrong, STOP and ask the user. It must fail. Commit in red and tell the user that test is now frozen.
5. If the failure shows that an existing frozen test encodes incorrect behavior, STOP, explain it to the user and wait for their approval before touching that test.
6. Fix it, leave `tools/check.sh` green and commit `fix: ...`.
7. Ask the user to verify it in the game (`scripts\deploy.ps1` + `/reload`).
8. Reply to the user in Spanish; everything written to the repo is in English.
