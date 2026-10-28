# Space Lord

Stylized 3D space strategy game (work in progress).

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

### Shipping an update

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
