# Space Lord

Stylized 3D space strategy game (work in progress), built with
**Godot 4.5+** (GDScript) and **Blender**.

## Getting started

1. Install [Git LFS](https://git-lfs.com) once: `git lfs install`
2. `git clone https://github.com/Littlebutta/Space-Lord.git`
3. Open Godot, click **Import**, pick `Space-Lord/godot/project.godot`,
   then press **F5** to run.

## Repo layout

```
godot/                Godot project (open this folder in Godot)
  scenes/             main.tscn, map/, combat/, ship_editor/
  scripts/autoload/   GameClock: pausable, fast-forward game time
  scripts/map/        StarSystem: procedural planets, belts, orbits
  scripts/ships/      ShipModule, ShipDesign, ShipStats, ShipView
  scripts/ship_editor/ grid ship builder (press B on the map)
  scripts/economy/    Storage: every resource needs cargo capacity
  scripts/procgen/    ShipGenerator: random ships to fight/salvage
  scripts/camera/     RTS-style camera for map and battles
  data/modules/       module stats as .tres (no code per part)
  assets/             exported .glb models, textures, audio, fonts
art/                  Blender .blend source files (Git LFS)
launcher/             auto-updating launcher (below)
```

Model in Blender, save the `.blend` in `art/`, then
**File > Export > glTF 2.0 (.glb)** into `godot/assets/models/`.
Images, audio, fonts and models are stored with Git LFS
(see `.gitattributes`).

## Building a release

CI (`.github/workflows/game.yml`) imports the project, checks that it
boots, and exports Windows and Linux builds on every change to
`godot/`. Pushing a tag like `v0.1.0` also zips the builds as
`SpaceLord-<os>.zip` (+ `.sha256`) and publishes a GitHub Release,
which the launcher picks up automatically:

```
git tag v0.1.0 && git push origin v0.1.0
```

To export locally instead, install export templates in Godot
(**Editor > Manage Export Templates**) and use **Project > Export**;
builds land in `build/<os>/`.

## Auto-update on boot

Players start the game through **SpaceLordLauncher**, a tiny Go program
in [`launcher/`](launcher). It works with any engine's build output.

On every launch it:

1. Asks GitHub for the latest release of the repo in `launcher.json`.
2. Compares the release tag with `game/version.txt`.
3. If newer, downloads `SpaceLord-<os>.zip`, checks it against
   `SpaceLord-<os>.zip.sha256` when that file is attached, unpacks it
   to `game.new/` and swaps it in (the old build is restored on error).
4. Starts the game. If offline or anything fails, it just starts the
   build already installed.

### Player folder layout

```
SpaceLordLauncher.exe
launcher.json
game/            <- unzipped build + version.txt
```

### Shipping an update by hand

CI does this for you on `v*` tags (see above). Manually:

1. Zip the packaged game so the exe sits at the zip root, e.g.
   `SpaceLord-windows.zip` (`linux`, `darwin` for other OSes).
2. Optional: `sha256sum SpaceLord-windows.zip > SpaceLord-windows.zip.sha256`.
3. Create a GitHub Release with a new tag (e.g. `v0.2.0`) and attach both.

Friends' launchers pick it up the next time they start the game.
The release API only works without a login on a **public** repo, so
either make this repo public or publish releases from a public one and
point `repo` in `launcher.json` at it.

### Building the launcher

```
cd launcher && go test ./... && GOOS=windows go build -o SpaceLordLauncher.exe .
```

CI (`.github/workflows/launcher.yml`) tests and builds Windows, Linux
and macOS binaries on every change to `launcher/`.
