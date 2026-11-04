# Changelog

## v0.2.1 - 2026-11-04

- Classic Era 1.15 support, so the addon can be tested before WoW Forever launches:
  - a new `LaRutaDel60_Vanilla.toc` (Interface 11509);
  - API fallbacks for `ReadyForTurnIn` and `GetTitleForQuestID`.

  The routes are still made for Forever: Forever-only quests show as `Quest #<id>` and need Skip.
- `deploy.ps1` also finds the `_classic_era_` folder.

## v0.2.0 - 2026-11-04

First test release.

- Guide engine:
  - a movable step window with the current step and the next two, and Back, Done and Skip buttons;
  - automatic advance on quest accept, complete and turn-in, and on reaching a location;
  - catch-up past steps you have already done;
  - per-character progress that survives `/reload`.
- Waypoint arrow with the distance in yards. It is hidden in instances.
- Automatic route selection by faction, race, class and level.
- Chat subcommands: `/ruta list`, `/ruta <id>`, `/ruta reset`, `/ruta hide` and `/ruta show`, with Spanish aliases.
- Undead routes: Tirisfal Glades, then Silverpine Forest, then The Barrens. They currently reach about level 15, and the quest data is still being verified in game.
- English and Spanish texts.
- Technical base:
  - black-box acceptance tests on an emulated WoW client, frozen through the `acceptance-frozen` tag;
  - the route JSON-to-Lua pipeline;
  - CI;
  - the Windows `deploy.ps1` script.
