# Wallpaper Engine Grid

A real **wrapping grid picker** for Wallpaper Engine on Omarchy. Replaces the horizontal carousel with a searchable, filterable grid of thumbnails — favorites, recents, tags, and keyboard navigation included.

## Features

- **Grid layout** (not a horizontal carousel) with 3–7 adaptive columns
- **Fuzzy search** by title and tags
- **Filter chips**: All, ★ Favorites, Recent, scene/video/web, and top tags (Anime, Game, Cyberpunk, etc.)
- **Favorites** with `Ctrl+F`, persisted across sessions
- **Recents** sorted by last use
- **Apply wallpaper** with `Enter` using `omarchy-we set`
- **Stop live wallpaper** with `Delete`
- **Random wallpaper** with `Ctrl+R`
- **Live badge** on the currently active wallpaper
- **Selection highlight** with accent border on the focused card
- **Hover effects** on cards and chips
- **Empty state** and loading indicators
- **Themed colors** — adapts to your Omarchy theme
- **Close** with `Esc`, `SUPER+W`, the ✕ button, or clicking outside

## Requirements

- **Omarchy** installed and running
- **omarchy-we** CLI (Omarchy's official Wallpaper Engine plugin)
- **linux-wallpaperengine** with Steam Workshop wallpapers
- **Steam Workshop** content downloaded in `~/.local/share/Steam/steamapps/workshop/content/431960/`
- **ImageMagick** (`magick` command) for thumbnail generation

## Installation

```bash
# 1. Clone into your Omarchy plugins folder
git clone https://github.com/Angel-p-v/wallpaper-grid.git \
  ~/.config/omarchy/plugins/coronel.wallpaper-grid

# 2. Enable the plugin
omarchy plugin enable coronel.wallpaper-grid

# 3. Generate thumbnails (first run, may take a while)
~/.config/omarchy/plugins/coronel.wallpaper-grid/we-grid-data thumbs

# 4. Open the picker
omarchy-shell shell summon coronel.wallpaper-grid '{}'
```

## Keyboard shortcut (recommended)

Add this to your `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + Z", "Wallpaper Engine grid", "omarchy-shell shell summon coronel.wallpaper-grid '{}'")
```

## Shortcuts inside the grid

| Action | Key |
|--------|-----|
| Open grid | `SUPER + SHIFT + Z` |
| Close grid | `SUPER + W` / `Esc` / ✕ / click outside |
| Search | type title or tag |
| Navigate | arrow keys / mouse |
| Apply wallpaper | `Enter` |
| Favorite / Unfavorite | `Ctrl + F` |
| Random wallpaper | `Ctrl + R` |
| Stop live wallpaper | `Delete` |

## What is NOT touched

- Nothing in `/usr/share/omarchy/` (system untouched)
- Nothing in `~/omarchy-wallpaper-engine/` (original plugin unmodified)
- The `linux-wallpaperengine` renderer, autostart, and theme-follow hook remain unchanged

## Limitations

- **Linux only** — depends on `linux-wallpaperengine` and Steam Workshop paths
- Requires **Omarchy** + `omarchy-we`
- Thumbnails are generated locally with ImageMagick (`magick`)

## Data & state

- Favorites & history: `~/.local/state/we-grid/`
- Thumbnails: `~/.cache/we-grid/thumbs/`

## License

MIT
