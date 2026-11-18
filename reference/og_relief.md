# The sea floor: depth in colour, its relief, and depth contours

`og_relief()` draws a depth model as two layers: the depth in colour,
and its relief shaded. `og_contour()` draws lines of equal depth from
the same model: the chart depths (`major`) a little heavier and
labelled, thinner lines between them, spaced by depth and zoom. Both are
made in the page from the model's tiles of elevations, so the reader
changes the colours, the shading and the lines with nothing asked of R;
a bundle
([`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md))
carries them with no R at all. Each draws under the base map's place
names, whatever its place in the pipe.

## Usage

``` r
og_relief(
  map = NULL,
  tiles = NULL,
  palette = "grey",
  opacity = 75,
  limits = NULL,
  scale = NULL,
  shade = TRUE,
  of = c("depth", "elevation"),
  open = FALSE,
  name = "Depth",
  id = "depth",
  info = NULL,
  section = "Sea floor",
  visible = TRUE
)

og_contour(
  map = NULL,
  tiles = NULL,
  major = c(10, 25, 50, 100, 150, 200, 300, 400, 500, 1000, 1500, 2000, 2500, 3000, 4000,
    5000),
  minor = TRUE,
  labels = TRUE,
  colour = "#1b2a3a",
  of = c("depth", "elevation"),
  open = FALSE,
  name = "Contours",
  id = "contours",
  info = NULL,
  section = "Sea floor",
  visible = TRUE
)
```

## Arguments

- map:

  A map the pipe makes
  ([`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
  with data or none, and any layer functions). Given the depth model
  instead (or nothing), a map is started for it, opening on the model's
  extent.

- tiles:

  The depth model (see *The depth model*).

- palette:

  The colours' look, one of the map's palettes: by default `"grey"`,
  quiet under the map's own data; `"quiet"`, `"seabed"`, `"deep"`,
  `"chart"`, `"drained"` and `"haxby"` are the other depth looks
  ([`og_palettes()`](https://einarhjorleifsson.github.io/ogis/reference/og_palettes.md)).

- opacity:

  The colours' opacity, 0-100.

- limits:

  The depths (or heights) the palette's ends stand at, `c(floor, cap)`
  in metres from 1 to 10,000; by default fitted to the view, again each
  time the map settles (the 2nd and 98th percentiles of the values in
  view), until the reader sets them.

- scale:

  How the values are spread over the palette: `"log"`, `"linear"`, or
  `"equal"` (each colour an equal share of the values in view); by
  default equal shares.

- shade:

  The relief shaded, as a layer of its own: `TRUE`, at an intensity that
  follows the view; a number from 0 to 1, that intensity; or `FALSE`,
  none.

- of:

  `"depth"` (below sea level, what is above left clear) or `"elevation"`
  (on land).

- open:

  Whether the layers' controls show when the page opens; folded by
  default.

- name, info:

  The layer's name in the sidebar (the relief's is "Relief") and the
  text behind its ⓘ.

- id:

  The layer's id, its key in the page's address; the relief's is
  `<id>_relief`.

- section:

  The sidebar's box the layers sit in, by its title.

- visible:

  Whether the layers are on when the page opens.

- major:

  The depths (or heights) of the heavier, labelled lines, in metres; by
  default the charts' isobaths from 10 to 5,000 m. Each shows from the
  zoom at which the thinner lines are no wider apart than it is deep.

- minor:

  Whether thinner lines are drawn between the major ones: every 25 m on
  the shelf at zoom 5, every 5 m from zoom 10, wider apart in deeper
  water (bands at 50, 200 and 1,000 m) and further out.

- labels:

  Whether the major lines carry their depth.

- colour:

  The lines' and labels' colour, `"#rrggbb"`.

## Value

The map, with the layers.

## Details

The arguments are the starting look; the page's controls change it. They
open folded under the layer's name, a click on ▸ showing them
(`open = TRUE` shows them from the start); the colours' scale bar shows
either way.

## The depth model

`tiles` is the depth model, one of:

- nothing (`NULL`): the file named by the environment variable
  `OGIS_DEPTH`, a line in `.Renviron`
  (`OGIS_DEPTH=D:/data/depth.mbtiles`;
  [`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)
  says more), so a script shared between colleagues carries no path;

- the path of an MBTiles file of elevation tiles, read by
  [`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md);

- a grid: the path of a GeoTIFF or any grid GDAL reads, a terra
  `SpatRaster`, or a data frame of cells, made into tiles by
  [`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md)
  (to zoom 8 by default);

- a tile function already made, by
  [`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)
  or
  [`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md);
  give the same one to both functions for a grid in a data frame, so a
  bundle holds its tiles once.

Elevations are metres, negative below sea level, as both tile functions
give them.

## See also

[`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)
and
[`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md)
for the depth model;
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
for a layer in MapLibre's own terms.

## Examples

``` r
# \donttest{
if (requireNamespace("png", quietly = TRUE) && requireNamespace("terra", quietly = TRUE)) {
  # the Danish waters' depth, its relief and contours, under the harbours
  depth <- og_tiles_dem(og_example("dansk_relief"), maxzoom = 6)
  og_map(view = list(bounds = c(2.5, 54.5, 13, 58.5))) |>
    og_relief(depth) |>
    og_contour(depth) |>
    og_polygon(og_example("dansk_harbours"), fill = NA, name = "Harbours")

  # a depth model named once, by OGIS_DEPTH in .Renviron:
  # og_map() |> og_relief() |> og_contour()
}
#> <og_map> Map
#>   layers: depth (dem), depth_relief (dem), contours (contour), harbours (geojson)
# }
```
