# macOS Pets

A menagerie of pixel pets that live on top of your desktop, plus a ball you can
throw between your monitors.

Inspired by [vscode-pets](https://github.com/tonybaloney/vscode-pets), but not
tied to any editor: the pets are drawn in overlay windows above everything
else, so they appear over Zed, a browser, or a full-screen app.

## Install

```bash
./install.sh
open "/Applications/macOS Pets.app"
```

It installs a menubar-only app (no Dock icon). Look for the paw icon in the
menu bar.

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