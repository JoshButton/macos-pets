# macOS Pets

Pixel pets that live on top of your desktop — over any app, across all your
monitors — plus a ball you can throw between screens for them to chase.

Artwork is from [vscode-pets](https://github.com/tonybaloney/vscode-pets),
used verbatim with attribution (see `Assets/vscode-pets/ATTRIBUTION.md`).

## Install

Requires macOS 13+ and a Swift toolchain (`xcode-select --install` is enough).

```bash
git clone git@github.com:JoshButton/macos-pets.git
cd macos-pets
./install.sh
open "/Applications/macOS Pets.app"
```

The app lives in the menu bar (no Dock icon) — look for the pets icon up top.

> First launch: the app is ad-hoc signed, so Gatekeeper may block it.
> Right-click it in Finder → **Open** → **Open** to allow it once.

## Use

- **Menu bar menu** — add or remove any of the 30 pets, throw the ball, clear
  them all, quit.
- **The ball** — grab it (cursor turns to a hand), drag, release to fling. It
  bounces off floors, ceilings, and the outer edges of your monitor setup, and
  travels across displays. Pets chase it, catch it, show it off, then drop it
  on the next throw. **Place Ball at Cursor** puts a fresh ball on your pointer.
- **Pets** — wander, run, sit, sleep, climb walls (totoro), and migrate between
  monitors on their own.

## Raycast (optional)

```bash
./install.sh --raycast-scripts
```

Adds one command per pet and action (add, remove, throw, place, hide, show…).
One manual step remains — Raycast offers no API for it: Settings →
**Extensions** → **Script Commands** → **Add Directories**, then in the picker
press **Cmd+Shift+G** and paste `~/.config/raycast/scripts` (it's hidden, so
it won't browse there). Commands appear under the **macOS Pets** group; run
**Reload Script Commands** if they don't show.

The same actions work from any terminal: `macos-pets send <add|remove|throw|
place|hide|show|toggle|…>` — see `macos-pets send` usage. The app must be
running (scripts queue into `~/.config/macos-pets/commands/`).

## Develop

```bash
swift build                                    # debug build
.build/debug/macos-pets --selftest             # behavioural checks
.build/debug/macos-pets --selftest --verify-catches  # proves the checks catch regressions
.build/debug/macos-pets --render-check         # offscreen pixel assertions
./install.sh --bundle-only ./dist              # assemble the .app without installing
```

CI (`.github/workflows/build.yml`) runs all of the above on every push and
uploads the bundle as an artifact.

Layout: `Sources/MacOSPetsKit` is pure logic (geometry, physics, behaviour —
no AppKit, so it runs headless in checks); `Sources/macos-pets` is the AppKit
layer (per-display overlays, clickable ball window, menu).

Licence: MIT for our code (see `LICENSE`), except `Assets/vscode-pets/`,
which is upstream artwork under CC BY-ND 4.0 — shipped byte-identical, never
modified in place.
