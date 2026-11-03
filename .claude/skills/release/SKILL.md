---
name: release
description: Usar cuando el usuario pida publicar o sacar una versión del addon. Sube la versión en los TOC, actualiza CHANGELOG.md, crea el tag vX.Y.Z y, con confirmación, lo empuja para que el CI publique el zip.
---

# Release

1. `tools/check.sh` en verde y working tree limpio (`git status`).
2. Versión semver (fix → patch, funcionalidad → minor). Si dudas, pregunta.
3. Cambia `## Version:` en `addon/LaRutaDel60/LaRutaDel60.toc` y cópialo a `_Forever.toc`.
4. Añade al principio de `CHANGELOG.md` (créalo si no existe; en inglés): `## vX.Y.Z - YYYY-MM-DD` con viñetas a partir de `git log --oneline <tag-anterior>..HEAD`.
5. `git commit -am "chore: release vX.Y.Z"` y `git tag vX.Y.Z`.
6. Pide confirmación al usuario antes de `git push origin main --tags` (es público).
7. `.github/workflows/ci.yml` comprueba que el tag coincide con la versión del TOC y publica `LaRutaDel60-vX.Y.Z.zip` en GitHub Releases.
8. Recuerda al usuario: en Windows, `scripts\deploy.ps1 -Source release -Repo <owner>/<repo>`.
