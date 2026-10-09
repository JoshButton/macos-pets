# Contributing

## Raising a PR

1. Branch from `main`: `git checkout -b <type>/<short-name>` —
   `feat/`, `fix/`, or `docs/` (e.g. `feat/butterfly-pet`, `fix/ball-stuck`).
2. Build and check locally before pushing:
   ```bash
   swift build
   ./.build/debug/macos-pets --selftest
   ./.build/debug/macos-pets --selftest --verify-catches
   ./.build/debug/macos-pets --render-check
   ```
   All four must pass. Add checks alongside behaviour changes — a fix without
   a regression check will be asked for one.
3. Push and open the PR against `main`. Keep it small and describe the
   user-visible change first; CI runs the same checks plus a bundle assembly.
4. Releases are cut by tagging: `git tag vX.Y.Z && git push origin vX.Y.Z`.
   The tag workflow attaches the built `.app` to the GitHub release.

Notes:

- Don't modify anything under `Assets/vscode-pets/` — it's verbatim upstream
  artwork under CC BY-ND 4.0 (see `Assets/vscode-pets/ATTRIBUTION.md`).
- Commits are authored by their human author with an
  `Co-authored-by: <agent/model>` trailer when AI-assisted.

## Coming later

A dev flow with dev builds (nightly installs colleagues can run without
building) — not set up yet.
