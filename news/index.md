# Changelog

## ogis 2026.11.18.14

- **The sea floor as two layer functions** (plan 072’s step 3, at the
  maintainer’s word: “can we not just have a ogis wrapper”).
  [`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
  draws a depth model’s depth in colour and its relief shaded, as two
  layers;
  [`og_contour()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
  its lines of equal depth, the charts’ depths (`major`, by default 10,
  25, 50, 100, 150, 200, 300, 400, 500, 1,000 m and on) a little heavier
  and labelled, thinner lines between them spaced by depth and zoom
  (`minor`), as the names map of Icelandic waters drew them.
  `og_map() |> og_relief() |> og_contour()` replaces some twenty lines
  of
  [`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)s.
  - The depth model (`tiles`): nothing, the one `OGIS_DEPTH` names; an
    MBTiles file; a grid (a GeoTIFF, a terra raster, a data frame of
    cells), made into tiles by
    [`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md);
    or a tile function. Given first, it starts a map that opens on its
    extent.
  - The starting look as plain arguments: `palette` (by default
    `"grey"`, at 75 % `opacity`, quiet under the map’s own data, as the
    maintainer set the names map’s), `limits` (fitted to the view by
    default), `scale`, `shade` (`TRUE`, an intensity, or `FALSE`);
    `major`, `minor`, `labels` and `colour` for the lines.
  - A major depth shows from the zoom whose shallowest spacing it is at
    least; the lines are made at the common divisor of the spacings and
    the depths shown (with 25 m among them, every 5 m from zoom 7). On
    the Olex grid in headless Chrome a view settled in 2.6 s at zooms 7,
    8 and 10, labels at 10-200 m. A label may bend as sharply as the
    line: at 30 or 90 degrees no label was placed on that grid’s stepped
    lines at zoom 10.
- **No wall of contours along a grid’s edge.** Elevation tiles hold 0
  (sea level) beyond a grid and on land, so every depth between a grid’s
  edge in open water and 0 was drawn along the edge (a box of 5-25 m
  lines round the Danish example’s North Sea; on the Olex grid, whose
  edges lie at 1,000-3,000 m, a band of hundreds). A contour layer now
  hands maplibre-contour a value at the fit’s `nodata` (0 by default) as
  missing, and it draws no line through a missing value; lines no longer
  stack along the coast either. The colours and the shading are as they
  were (the shading still marks the edge with a thin seam: MapLibre’s
  hillshade has no missing values). This needs the lines made on the
  page’s own thread when served, as a bundle already made them; on the
  Olex grid a view settled as fast. The test fails without it (12 lines
  along a flat grid’s edge, against none).
- **A layer’s controls can open folded** (the maintainer: the depth
  layer’s details not shown until the reader expands it). A layer whose
  config has `fold` (as
  [`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)‘s
  and
  [`og_contour()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)’s
  have, unless `open = TRUE`) shows ▸ beside its name, a click showing
  its controls; its colours’ scale bar and a legend show either way.
- [`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)
  with no `file` reads the file named by the environment variable
  `OGIS_DEPTH`, a line in `.Renviron`
  (`OGIS_DEPTH=D:/data/depth.mbtiles`), and says so once a session; a
  `file` given wins. A depth model shared between colleagues as one
  MBTiles file, each keeping it where they like, is then named once on
  each computer and in no script. Errors say what to do: with neither,
  how to set the variable; with a path that is no file, or no MBTiles
  (SQLite) file, which path and from where, a grid pointed to
  [`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md).
  `~` in a path is expanded. At the maintainer’s word (“Yes, build it”),
  from the side study of the Icelandic depth model in ogis.
- RSQLite is imported, no longer suggested:
  [`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)
  works as soon as ogis is installed. DuckDB’s own SQLite reader was
  measured and set aside: it scans the whole tiles table for each tile
  (110 ms a tile on a 547 MB file, against RSQLite’s 0.2-0.7 ms), as it
  uses no index of the file.

## ogis 2026.11.18.13

- `og_text(endzoom = )`: where a label stops, a number (the styles’ own
  `maxzoom`) or a column written bare, each row until its own, hidden
  from the first whole zoom at or above it (MapLibre judges a zoom in a
  filter at whole zooms, as for `minzoom`); a row with no end shows on.
  With `minzoom` a label shows in a band of zooms, as the names editor
  shows its names, and two layers can take turns. A search takes the map
  to a zoom where its label shows, before its end. Reported by the names
  session (plan 076 step 6). The Labels article shows it.
- A layer function’s `minzoom` as a number now holds for a layer sent
  whole: its styles take it. It reached the page as the layer’s own
  `minzoom`, which only a tiled layer’s source uses, so
  `og_point(minzoom = 8)` or `og_text(minzoom = 10)` on a layer small
  enough to go whole drew at every zoom. Found writing the Labels
  article’s example of two label layers taking turns.

## ogis 2026.11.18.12

- The engine’s guard against MapLibre 5’s lost index is gone. In 5.x a
  tile loaded again while an earlier load of it was still being read
  lost its index, and every query of that layer then threw “Out of
  bounds” until its data were sent again; the page caught that, sent the
  data again and tried a click once more. MapLibre fixed it in 6.0 and
  6.3, and the reproduction that found it (data sent during an animated
  zoom, a filter reading the zoom from MapLibre’s global state) failed 9
  times in 200 on 5.24.1 and not once in 200 on 6.19.0. Queries go
  straight to MapLibre; `query()` stays as the one place that leaves out
  layers not on the map.

## ogis 2026.11.18.11

- MapLibre GL JS 6.19.0 in place of 5.24.1, the last of 5.x. MapLibre 6
  is published only as ES modules, which a page opened from its folder
  cannot load, and a bundle opens by a double click; so its two modules
  are made classic scripts by `tools/vendor-maplibre.R` (the npm package
  checked against the registry’s SHA-512; `import.meta.url` the script’s
  own address, the export list the global `maplibregl`), its worker’s
  code carried in `maplibre-gl-worker.js` and handed to MapLibre as a
  blob, which MapLibre 6.17 and later runs on a page opened from a file.
  The page loads that script before MapLibre; nothing else in it
  changed. A bundle is 0.6 MB larger.
- A test opens a bundle from its folder (`file://`), as a double click
  does, and checks its outlines, labels and contours (made in the page
  by maplibre-contour) are drawn; every other page test opens its page
  over http. `tools/firefox-check.R` does the same in headless Firefox,
  by hand at each MapLibre update.
- Checked beside 5.24.1 at the same views: lines that cross, labels past
  their tiles’ deepest zoom and contours look the same; a map of 8,918
  labels opens and zooms as fast. The engine’s guard on queries for
  MapLibre 5’s lost index stays until a reproduction shows 6 has done
  with it.

## ogis 2026.11.18.10

- rebelrebel is renamed **ogis**, its prefix `rr_` now `og_`: every
  function
  ([`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
  [`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  [`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md),
  …) and class (`og_map`, `og_layer`, `og_section`), and in the page
  what a script of its own sees: the object it is given (`og`:
  `og.on()`, `og.state()`, `og.fetch()`, …), the features’ key
  (`og_row`) and the classes its styles may name (`.og-panel`). A map’s
  own route header is `X-OG-Notes`. Names the engine kept from ramb
  (`rb`) are `og` too. Nothing else changed: a call made with the `rr_`
  names is the same call with `og_`. The entries below keep the names of
  their day.
