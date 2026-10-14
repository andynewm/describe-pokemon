# Describe the Pokémon

A phone-first party game. One player holds the phone and describes the Pokémon on screen; the other guesses its name. Tap **Guessed it!** or **Skip**, then see the score and the skipped Pokémon at the end.

The setup screen lets you choose generations (I–IX) and whether to include Pokémon that can still evolve.

## Running locally

It's a static site, but it loads `data/*.json` with `fetch()`, so open it through any local web server rather than as a file.

## Rebuilding the data

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-data.ps1
```

This downloads species data and official artwork from [PokeAPI](https://pokeapi.co) and writes `data/species.json` and `data/art-gen<N>.json`.

## Hosting

Push to GitHub and enable **Settings → Pages → Deploy from a branch → `main` / root**.

---

Unofficial fan project, not affiliated with or endorsed by Nintendo, Game Freak or The Pokémon Company. Pokémon names and artwork © their respective owners.
