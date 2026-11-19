# coronel.wallpaper-grid

Selector en **cuadrícula (grid)** para Wallpaper Engine en Omarchy. Reemplaza el carrusel horizontal por un grid real con búsqueda, etiquetas, favoritos, récents y atajos de teclado.

## Requisitos previos

- **Omarchy** instalado y funcionando
- **omarchy-we** CLI (plugin oficial de Omarchy para Wallpaper Engine)
- **linux-wallpaperengine** con wallpapers de Steam Workshop
- **Steam Workshop** con contenido descargado en `~/.local/share/Steam/steamapps/workshop/content/431960/`
- **ImageMagick** (comando `magick`) para generar miniaturas

## Instalación

```bash
# 1. Clona el repo dentro de tus plugins de Omarchy
git clone https://github.com/Angel-p-v/coronel.wallpaper-grid.git \
  ~/.config/omarchy/plugins/coronel.wallpaper-grid

# 2. Habilita el plugin
omarchy plugin enable coronel.wallpaper-grid

# 3. Genera las miniaturas (primera vez, puede tardar)
~/.config/omarchy/plugins/coronel.wallpaper-grid/we-grid-data thumbs

# 4. Abre el selector
omarchy-shell shell summon coronel.wallpaper-grid '{}'
```

## Atajo de teclado sugerido

En `~/.config/hypr/bindings.lua` (o tu gestor de binds):

```lua
o.bind("SUPER + SHIFT + Z", "Wallpaper Engine grid", "omarchy-shell shell summon coronel.wallpaper-grid '{}'")
```

## Atajos dentro del grid

| Acción | Tecla |
|--------|-------|
| Abrir el grid | `SUPER + SHIFT + Z` |
| Cerrar | `SUPER + W` / `Esc` / ✕ / clic fuera |
| Buscar | escribe título o etiqueta |
| Navegar | flechas / ratón |
| Aplicar | `Enter` |
| Fav/Desfav | `Ctrl + F` |
| Aleatorio | `Ctrl + R` |
| Parar live wallpaper | `Supr` |

## Qué NO se toca

- Nada en `/usr/share/omarchy/` (sistema intacto)
- Nada en `~/omarchy-wallpaper-engine/` (plugin original sin modificar)
- El renderer `linux-wallpaperengine`, el autostart y el hook de tema-sigue siguen igual

## Limitaciones

- Solo **Linux** (depende de `linux-wallpaperengine` y rutas de Steam)
- Requiere **Omarchy** + `omarchy-we`
- Las miniaturas se generan localmente con `magick`
