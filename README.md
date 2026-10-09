# macOS Pets

A menagerie of pixel pets that live on top of your desktop, plus a ball you can
throw between your monitors.

Inspired by [vscode-pets](https://github.com/tonybaloney/vscode-pets), but not
tied to any editor: the pets are drawn in overlay windows above everything
else, so they appear over Zed, a browser, or a full-screen app.

## Install

Requires macOS 13+ and a Swift toolchain (Command Line Tools are enough).

```bash
git clone <your-repo-url> macos-pets
cd macos-pets
./install.sh
open "/Applications/macOS Pets.app"
```

It installs a menubar-only app (no Dock icon). Look for the paw icon in the
menu bar.

> First launch: the app is ad-hoc signed, so Gatekeeper may refuse to open it.
> Right-click it in Finder → Open → Open to allow it once.

## Raycast control

These are [Script Commands](https://docs.raycast.com/script-commands) —
plain shell scripts, so they work on the free tier with no store publishing.
There is no separate "v2" to worry about: script commands work in current
Raycast as long as the directory is registered (step 2 below).

```bash
./install.sh --raycast-scripts   # writes one script per action/species
```

This adds pet add/remove (per species), add-random, remove-last, clear-all,
ball throw/place, and hide/show/show-toggle commands. They talk to the running
app through `~/.config/macos-pets/commands/` — the same channel as
`macos-pets send <add|remove|throw|place|hide|show|toggle|...>` from any
terminal or script.

### One-time Raycast setup (per machine)

Raycast offers no API for registering script folders (its storage is
proprietary — checked), so this is the one manual step. The installer opens
Raycast settings for you and prints the rest:

1. Raycast Settings → **Extensions** → **Script Commands** → **Add Directories**.
2. `~/.config` is hidden so it won't appear in the picker: press
   **Cmd+Shift+G**, paste `~/.config/raycast/scripts`, Enter.
   (Alternative: Cmd+Shift+. toggles hidden files in the picker.)
3. Back in Raycast root search, the commands appear under the **macOS Pets**
   group (e.g. type "Add Crab" or "Throw Ball"). If they don't show, run the
   **Reload Script Commands** action or restart Raycast.

### Troubleshooting

- **Commands don't appear**: the directory in step 1 is the usual cause.
  Verify with `ls ~/.config/raycast/scripts/*.sh` (you should see ~60 files)
  and that they are executable (`chmod +x` is applied by the installer).
- **Command runs but nothing happens**: the macOS Pets app must be running —
  scripts queue into `~/.config/macos-pets/commands/` and the app drains that
  folder every half second. Start the app first.
- **Stale species list**: re-run `./install.sh --raycast-scripts` after
  updating; scripts embed the installed app path, so regenerate after moving
  the installation.

## Sharing

Push this directory to a Git repo; GitHub Actions (`.github/workflows/build.yml`)
builds, runs all checks, and uploads the `.app` bundle as an artifact on every
push. Colleagues can either run `./install.sh` themselves or grab the bundle
from the workflow run.

## Using it

- **Menu bar menu**: add or remove pets, throw the ball, clear them, quit.
- **Throw the ball**: click and drag the ball, then release to fling it. It
  bounces off the floor, ceiling, and the outer edges of your monitor
  arrangement, and carries across displays. Pets will chase it.
- Pets wander, sit, sleep, and migrate between monitors on their own.

## How it works

- `Sources/MacOSPetsKit` is the pure logic: geometry, ball physics, pet
  behaviour, and the sprite data. No AppKit, so it can be exercised headlessly.
- `Sources/macos-pets` is the AppKit layer: one transparent, click-through
  `NSWindow` per display at `.screenSaver` level, driven by a timer.

Because the windows ignore mouse events, the app watches the mouse globally and
only starts a drag when the press lands on the ball, so ordinary clicking is
never affected.

## Verifying it

There is no XCTest or swift-testing on this machine (Command Line Tools only),
so the checks live in the binary:

```bash
.build/release/macos-pets --selftest     # 41 behavioural checks
.build/release/macos-pets --render-check # draws offscreen, inspects the pixels
.build/release/macos-pets --selftest --verify-catches
```

`--verify-catches` is the interesting one: it reintroduces each bug and
confirms the suite fails, so the tests can't silently stop guarding anything.

Other flags:

- `--render-sheet [out.png]` — contact sheet of every sprite.
- `--preview [out.png] [species...]` — zoomed strip for judging the artwork.
- `--trace-ball`, `--trace-pets` — step-by-step simulation traces.

## Artwork

The pets are verbatim, unmodified GIF sprites from
[tonybaloney/vscode-pets](https://github.com/tonybaloney/vscode-pets)
(`Assets/vscode-pets/media/`, 369 files), used with attribution — see
`Assets/vscode-pets/ATTRIBUTION.md`.

Licence notes: the upstream *code* is MIT, but the sprite artwork is
**CC BY-ND 4.0**, which permits verbatim reproduction with attribution but not
modified copies. So the files ship byte-identical: no recolouring, no redrawn
pixels, no mirrored pixel buffers. Left/right facing is a display-time canvas
transform only, and per-species `license.txt` files are kept intact. The
original hand-drawn ASCII sprites remain in `PetCatalogue.proceduralAll` as an
offline fallback.

## Known limits

- The pets and ball are drawn at a fixed pixel scale, so they look sharp on
  Retina but chunky by design on non-Retina displays.
- Only the ball is interactive; pets can't be picked up.
- The pet AI is intentionally simple: a wander/sit/sleep state machine with
  ball-chasing layered on top.