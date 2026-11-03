# La Ruta del 60

A **free** addon for **World of Warcraft: Forever** (client 1.60.1) that guides any character from level 1 to 60 along the fastest route, step by step.

> **Status: in development (v0.1.0).** The addon currently loads, detects WoW Forever and answers `/ruta`. The first playable route, Undead 1-20 (Tirisfal Glades and Silverpine Forest), is in progress.

## Planned features

- A step window showing the current and upcoming steps. It advances on its own when you accept, complete or turn in quests.
- An on-screen arrow pointing to the next objective, with the distance.
- Automatic route selection by faction, race and level, with manual switching.
- English and Spanish texts.

All routes are original work. Nothing is copied from other addons or paid guides.

## Installation on Windows

### Option A: manual download (simplest)

1. Download `LaRutaDel60-vX.Y.Z.zip` from the latest [release](../../releases).
   If there is no release yet, click **Code → Download ZIP** on this page.
2. Open your WoW Forever folder, usually `C:\Program Files (x86)\World of Warcraft\_forever_\`. The exact name of the `_forever_` folder may differ.
3. Go into `Interface\AddOns\`, and create it if it doesn't exist.
4. Copy the **`LaRutaDel60`** folder there:
   - from a release zip, copy the `LaRutaDel60` folder as it is;
   - from the repository ZIP, copy the one inside `addon\LaRutaDel60`.

   The result must look like this: `...\_forever_\Interface\AddOns\LaRutaDel60\LaRutaDel60.toc`.
5. Start the game. On the character screen, click **AddOns** and make sure **La Ruta del 60** is enabled.

### Option B: install script (one command to update)

Requires [Git for Windows](https://git-scm.com/download/win).

```powershell
git clone https://github.com/ricardozd/larutadel60.git
cd larutadel60
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
```

The script finds your WoW Forever folder, pulls the latest changes and copies the addon. If it can't find the game, tell it where it is:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -WowPath "D:\Games\World of Warcraft\_forever_"
```

To update, run the same command again. If the game was open, type `/reload` in chat.

## Usage

- When you log in, the chat shows `La Ruta del 60: Loaded. Type /ruta for info.` (in Spanish on Spanish clients).
- `/ruta` shows the version and the number of loaded guides.

## Development

The addon is developed entirely with AI (Claude Code) on macOS. Project rules, commands and structure are in [`CLAUDE.md`](CLAUDE.md). Run `tools/setup.sh` to set up the environment and `tools/check.sh` to run every check.
