# Wallpaper Engine Grid

A real **wrapping grid picker** for Wallpaper Engine on Omarchy. Replaces the horizontal carousel with a searchable, filterable grid of thumbnails — favorites, recents, tags, and keyboard navigation included.

## Features

- **Adaptive grid** with large previews and Omarchy theme colors
- **Fuzzy search** by title and tags
- **Filter chips**: All, ★ Favorites, Recent, scene/video/web, and top tags
- **Favorites** from each card or with `Ctrl+F`, persisted across sessions
- **Expanded preview** with original video playback and animated Workshop previews
- **Automatic scene clips** for scenes with a static preview, rendered in the background and cached as 4-second 720p clips
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

You need Omarchy running plus a few external tools. Install them from their upstream repos:

| Dependency | What it's for | Install from |
|---|---|---|
| **Omarchy** | Desktop shell / plugin host | https://github.com/omarchy/omarchy |
| **omarchy-we** | Wallpaper Engine CLI (`omarchy-we set`) | https://github.com/omarchy-wallpaper-engine/omarchy-we |
| **linux-wallpaperengine** | Wallpaper Engine renderer on Linux | https://github.com/turquicios/linux-wallpaperengine |
| **ImageMagick** (`magick`) | Thumbnail generation | https://imagemagick.org |
| **Qt Multimedia** with the FFmpeg backend | Video playback in the expanded preview | Arch packages `qt6-multimedia` and `qt6-multimedia-ffmpeg` |
| **Gamescope, FFmpeg, and xprop** (optional) | Automatic background capture for scenes with a static preview | Arch packages `gamescope`, `ffmpeg`, and `xorg-xprop` |
| **Steam Workshop content** | Wallpapers downloaded by Steam | https://store.steampowered.com/app/431960 |

On Arch Linux you can install most of these with:

```bash
# ImageMagick
sudo pacman -S imagemagick qt6-multimedia qt6-multimedia-ffmpeg

# Automatic scene clips
sudo pacman -S gamescope ffmpeg xorg-xprop

# Omarchy (if not already installed)
# See: https://github.com/omarchy/omarchy

# omarchy-we & linux-wallpaperengine
# See their repos above for install instructions
```

Wallpapers must be downloaded in:
`~/.local/share/Steam/steamapps/workshop/content/431960/`

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
| Open expanded preview | `Space` or `Ctrl + Space` while typing a search |
| Compare in expanded preview | arrow keys |
| Return to grid from expanded preview | `Esc` |
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
- Generated scene clips: `~/.cache/we-grid/scene-clips/`

The first time you preview a scene with a static image, the image stays visible while the clip is generated. If capture is unavailable or fails, the image remains visible.

## License

MIT
