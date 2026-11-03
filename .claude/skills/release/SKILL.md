---
name: release
description: Use when the user asks to publish or cut an addon release. Bumps the version in the TOCs, updates CHANGELOG.md, creates the vX.Y.Z tag and, with confirmation, pushes it so CI publishes the zip.
---

# Release

1. `tools/check.sh` green and clean working tree (`git status`). You must be on `main` with the work already integrated (`git branch --show-current` = main) and with a remote configured (`git remote -v`); otherwise stop and tell the user.
2. Semver version (fix → patch, feature → minor). If in doubt, ask.
3. Change `## Version:` in `addon/LaRutaDel60/LaRutaDel60.toc` and copy it to `_Forever.toc`.
4. Add at the top of `CHANGELOG.md` (create it if it does not exist; in English): `## vX.Y.Z - YYYY-MM-DD` with bullets from `git log --oneline <previous-tag>..HEAD` (if it is the first release and there is no previous tag, `git log --oneline` with the whole history).
5. `git add CHANGELOG.md addon/LaRutaDel60/LaRutaDel60.toc addon/LaRutaDel60/LaRutaDel60_Forever.toc && git commit -m "chore: release vX.Y.Z"` (with the `Co-Authored-By` trailer) and `git tag vX.Y.Z`.
6. Ask the user for confirmation before `git push origin main vX.Y.Z` (it is public).
7. `.github/workflows/ci.yml` checks that the tag matches the TOC version and publishes `LaRutaDel60-vX.Y.Z.zip` to GitHub Releases.
8. Remind the user: on Windows, `scripts\deploy.ps1 -Source release -Repo <owner>/<repo>`.
9. Reply to the user in Spanish; everything written to the repo is in English.
