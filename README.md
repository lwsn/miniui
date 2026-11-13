# miniui

A personal World of Warcraft interface in one addon, with no in-game setup.
Layout and behaviour are hardcoded: there are no options panels or saved
settings.

## What it replaces

- **Unit frames** (player, target), built on oUF: health coloured by health
  percentage, power, cast bar with spell icon, target auras.
- **Player buffs and debuffs**: a standalone block at the top right.
- **Action bars 1–3**, the **stance bar**, and **combo points**. Keybinds
  come from the standard Blizzard bindings, so existing keys carry over.
- **Minimap**: square, at the bottom centre, with zone, clock and
  coordinates. Right-click opens tracking.
- **Bags**, **XP and reputation bars**, and an **FPS meter**.

Blizzard's versions of these, and the micro menu, are hidden.

## Commands

- `/rl`: reload the UI
- `/mfonts`: font sampler (development)
- `/mtest`: unit frame colour test grid (development)

## Third-party components

- [oUF](https://github.com/oUF-wow/oUF) (MIT), in `embeds/oUF`
- [IBM Plex Sans Condensed](https://github.com/IBM/plex) (SIL Open Font
  License 1.1), in `media/fonts/IBM_Plex_Sans_Condensed`

## License

MIT for miniui's own code; see [LICENSE](LICENSE). Third-party components
keep their own licenses.
