# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A phone-first party game: one player sees a Pokémon (artwork + name) and describes it; the other guesses. Setup screen filters by generation and by whether to include Pokémon that can still evolve. Play screen has "Guessed it!" / "Skip" / "Undo last"; a summary lists skipped Pokémon.

It's hosted as a static site via GitHub Pages (`main` branch root; `.nojekyll` skips Jekyll). The same files are also published as a claude.ai Artifact at https://claude.ai/artifact/7PVGoAqCBkndPsm6WbtHKE; to update that copy, republish `index.html` to that URL with the `data/*.json` files passed via `files`.

## Commands

- Rebuild data (needs network; caches CSVs and PNGs in `tools/cache/`, which is safe to delete):
  `powershell -ExecutionPolicy Bypass -File tools/build-data.ps1 [-Size 300] [-Quality 80]`
- There is no Python/Node on this machine; tooling is PowerShell 5.1 (System.Drawing) plus `curl.exe`.
- There is no build step or test suite for the page. Opening it via `file://` won't work because it `fetch()`es `data/`; serve the folder over HTTP.
- `index.html` is a complete document with its own base reset (box-sizing, safe-area padding, `[hidden]`). Keep it that way: the Artifact host tolerates the extra wrapper, but GitHub Pages needs it. `window.claude.*` calls are optional-chained and no-ops outside claude.ai.

## Architecture

- `index.html` — the entire app (vanilla JS, no libraries). Screens are `<section>`s toggled via `hidden`. Game state is `{ deck: [id], results: [{id, r: "g"|"s"}] }`; the current card is `deck[results.length]`, so undo is just `results.pop()`. Settings persist to `localStorage`; an in-progress game survives artifact republishes via `window.claude.hot`.
- `data/species.json` — `[{id, name, gen, pre}]` for all species, loaded on startup to compute per-gen counts.
- `data/art-gen<N>.json` — `{id: "data:image/jpeg;base64,..."}`, fetched lazily only for selected generations. Artwork is embedded because the Artifact CSP blocks external images, and it's packed per generation because an Artifact version allows at most ~511 files.
- `tools/build-data.ps1` — generates both from PokeAPI's CSVs (`pokemon_species.csv`, `pokemon_species_names.csv`, English = language 9) and official artwork.

## Invariants

- Artwork is flattened onto a solid colour (JPEG has no alpha). `$cardColor` in the build script must equal `--card` in `index.html` (`#f6f3ec`), or images will show a visible box.
- `pre` = some species lists this one in `evolves_from_species_id`, except `$regionalOnlyEvolution` (Farfetch'd, Mr. Mime, Qwilfish, Corsola, Linoone, Basculin): only a regional form of these evolves, and the shown default form doesn't. Update that list if new regional-only evolutions appear.
