---
name: export-github-pages
description: Export this Godot 4.7 game to docs/ and push main so GitHub Pages updates. Use when the user asks to deploy, update the live site, export Web, publish Pages, or says the live site is stale.
---

# Export GitHub Pages

GitHub Pages serves **`docs/`**, not the Godot source. Pushing `.gd` / `.tscn` does not change https://idylpicklei.github.io/Mikes-Well-Driller/. A GitHub "build" also does not compile Godot.

After gameplay changes that should go live: export Web into `docs/`, commit those files, push `main`.

## Do this now

1. Run the helper (preferred). It finds or installs Godot 4.7.1, installs Web templates if missing, **writes `version.txt` build stamp**, and exports.

```bash
bash tools/export_web.sh
```

On Windows PowerShell from the repo root:

```powershell
bash tools/export_web.sh
```

If `bash` is unavailable, run the Godot command in [Manual export](#manual-export) after writing the stamp yourself (see [Build stamp](#build-stamp)).

2. Commit **only** the export artifacts (+ regenerated stamp), then push `main`:

```bash
git add docs/index.html docs/index.pck docs/index.js docs/index.wasm docs/index.png docs/index.icon.png docs/index.apple-touch-icon.png docs/index.audio.worklet.js docs/index.audio.position.worklet.js docs/version.txt version.txt
git status
git commit -m "Publish a fresh Web export for GitHub Pages."
git push origin main
```

Do **not** commit `.godot/` editor cache, `docs/*.import`, or unrelated files.

3. Tell the user to wait a minute for Pages, then hard-refresh (Ctrl+Shift+R). `docs/coi-serviceworker.js` can keep an old `.pck` until then. Confirm the start-menu build stamp matches the commit you exported.

## Build stamp

Web builds have no git. Every Pages export **must** regenerate a stamp the game can read:

- Path: repo-root `version.txt` (also copied to `docs/version.txt` for inspection)
- Contents: short SHA + UTC date, e.g. `cc0f564  2026-08-18`
- `tools/export_web.sh` writes this **before** Godot export so it packs into `docs/index.pck` (`export_presets.cfg` `include_filter=version.txt`)
- Start menu reads `res://version.txt`; if missing, shows `dev` (local editor without an export stamp)
- **Do not hardcode a SHA in the scene.** Standing order: every future `docs/` export regenerates this stamp.

## Manual export

Preset name is `Web`. Output path is `docs/index.html` (`export_presets.cfg`).

```bash
SHA="$(git rev-parse --short HEAD)"
DATE="$(date -u +%Y-%m-%d)"
printf '%s  %s\n' "$SHA" "$DATE" > version.txt
"$GODOT" --headless --path "$(pwd)" --export-release "Web" "docs/index.html"
cp version.txt docs/version.txt
```

Resolve `$GODOT` in this order:

1. `GODOT` env var
2. `godot` on `PATH`
3. Linux: `Godot_v4.7.1-stable_linux.x86_64` if already downloaded
4. Windows (this machine has used): `C:\Users\kdroo\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`

Project version is **4.7.1**. Templates must exist or export fails:

- Linux: `~/.local/share/godot/export_templates/4.7.1.stable/web_nothreads_release.zip`
- Windows: `%APPDATA%\Godot\export_templates\4.7.1.stable/web_nothreads_release.zip`

Need `web_nothreads_debug.zip`, `web_nothreads_release.zip`, and `version.txt` containing `4.7.1.stable`.

Official templates archive:

`https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz`

Extract only the `templates/web_nothreads_*.zip` files (the `.tpz` is a zip). `tools/export_web.sh` does this.

## Rules

- Export from the same commit you intend to publish.
- Always regenerate the build stamp with the export (never hand-edit a SHA into the start menu).
- If export fails with "No export template found", install templates; do not edit `docs/` by hand.
- If `git push origin main` returns 403, the GitHub user cannot write this repo. Ask the user to push with an account that can.
- Do not rewrite `docs/coi-serviceworker.js` unless the export changed it.
- Do not add a GitHub Action that downloads the full templates zip on every push unless the user asks for CI.
