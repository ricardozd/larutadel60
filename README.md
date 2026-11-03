# La Ruta del 60

Addon **gratuito** para **World of Warcraft: Forever** (cliente 1.60.1) que te guía paso a paso de nivel 1 a 60 por la ruta más rápida, sea cual sea tu personaje.

> **Estado: en desarrollo (v0.1.0).** Por ahora el addon carga, detecta WoW Forever y responde a `/ruta`. La primera ruta jugable, no-muerto del 1 al 20 (Claros de Tirisfal y Bosque de Argénteos), está en camino.

## Qué hará

- Una ventana con el paso actual y los siguientes, que avanza sola al aceptar, completar o entregar quests.
- Una flecha en pantalla que apunta al siguiente objetivo, con la distancia.
- Elige sola la ruta según tu facción, raza y nivel. También puedes cambiarla a mano.
- Textos en inglés y en español.

Todas las rutas son propias: no se copia contenido de otros addons ni de guías de pago.

## Instalación en Windows

### Opción A: descarga manual (la más sencilla)

1. Descarga la última versión desde [Releases](../../releases): el archivo `LaRutaDel60-vX.Y.Z.zip`.
   Si todavía no hay ninguna release, pulsa **Code → Download ZIP** en esta página.
2. Abre la carpeta de WoW Forever. Normalmente es `C:\Program Files (x86)\World of Warcraft\_forever_\`. El nombre exacto de la carpeta `_forever_` puede variar.
3. Entra en `Interface\AddOns\`. Si no existe, créala.
4. Copia ahí la carpeta **`LaRutaDel60`**:
   - del zip de la release, tal cual;
   - del ZIP del repositorio, la que está en `addon\LaRutaDel60`.

   Tiene que quedar así: `...\_forever_\Interface\AddOns\LaRutaDel60\LaRutaDel60.toc`.
5. Arranca el juego. En la pantalla de personajes, pulsa **AddOns** y comprueba que **La Ruta del 60** está activado.

### Opción B: con el script de instalación (se actualiza con un comando)

Requiere [Git para Windows](https://git-scm.com/download/win).

```powershell
git clone https://github.com/ricardozd/larutadel60.git
cd larutadel60
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
```

El script busca la carpeta de WoW Forever, descarga los últimos cambios y copia el addon. Si no encuentra el juego, indícale dónde está:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1 -WowPath "D:\Juegos\World of Warcraft\_forever_"
```

Para actualizar, vuelve a ejecutar el mismo comando. Si el juego estaba abierto, escribe `/reload` en el chat.

## Uso

- Al entrar con un personaje verás en el chat: `La Ruta del 60: Cargado. Escribe /ruta para más info.`
- `/ruta` muestra la versión y cuántas guías hay cargadas.

## Desarrollo

El addon se desarrolla íntegramente con IA (Claude Code) en macOS. Las reglas del proyecto, los comandos y la estructura están en [`CLAUDE.md`](CLAUDE.md). Para preparar el entorno, ejecuta `tools/setup.sh`; `tools/check.sh` lanza todas las verificaciones.
