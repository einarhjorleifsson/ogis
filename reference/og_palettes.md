# The palettes and base maps of a map

`og_palettes()`: eighteen palettes, each marked by `use` for the grid's
colours, a depth's or both.

## Usage

``` r
og_palettes()

og_basemaps()
```

## Value

A list, each element with `id` and `label`: a palette with `source`,
`colors` and `use` (`"grid"`, `"depth"` or both); a base map with
`style` (a MapLibre style's address) or `tiles` (a raster address) with
`maxzoom` and `attribution`, and optionally `paint` (MapLibre's raster
paint, such as `raster-brightness-max`), `background` (the colour beyond
the picture's tiles), `labels` (a MapLibre style whose names are drawn
over the picture, with its fonts) and `label_layers` (a regular
expression for which of its layers: by default its symbol layers whose
id starts `place_`, `watername_` or `waterway_label`), or neither
(none). A raster address names a tile by `{z}`, `{x}` and `{y}`, or is a
WMS's GetMap in `EPSG:3857` whose box is `BBOX={bbox-epsg-3857}`;
MapLibre fills them in for each tile, and the server must allow the page
to read its pictures (CORS). Any base map may be the first, the one a
map opens on. One with neither `style` nor `labels` has no fonts of its
own: the layers' texts are drawn in the browser's. A style served by the
map's own server (a route of
[`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md)'s
`routes`) is given by a relative address, `"/x/style"`: the page may be
opened as `localhost` or as `127.0.0.1`, two origins to a browser, which
refuses the other's address. A palette of your own, given to
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)'s
`palettes`, needs `id`, `label` and `colors`; with no `use` it is
offered to the grid.

## Details

- For the grid, twelve of nine colours, light (low) to dark (high). The
  first ten change in lightness steadily (OKLab), from viridisLite
  (magma, viridis, plasma) and tidyterra (deep, scotland,
  population_dens, etopo1_bathy, colombia_bathy, gn_yl, blues); the last
  two, terrain palettes, rise and fall in lightness.

- For a depth, seven looks, the colours a dem layer offers by default
  (its `colour$palettes`), shallow to deep: `quiet`, pale cyan-grey to
  mid grey-blue, low in chroma and stopping at mid lightness, so the
  relief's shading reads through it (the default); `seabed`, sand
  shading into mud seen through the water, a look and not a substrate;
  `deep`, the grid's too; `chart`, the nautical chart's convention, the
  shallows blue and the deeps near white; `grey`, a ground for other
  layers, pulling no overlay's hue; and two daring ones, `drained`, the
  seabed as if the sea were drained (GMT's globe hypsometry, the deeps
  green lowland, the banks brown hills), and `haxby`, marine geology's
  multibeam palette, orange shallows through green to deep blue. Each
  ends at least 0.03 in OKLab from the light base maps' land, so the
  shallowest water does not read as land. They were made for a
  bathymetry map of Icelandic waters (2026-11-09): quiet, seabed, chart
  and grey designed in OKLCh, drained and haxby resampled from tidyterra
  to 17 stops at even steps in OKLab, their whitest stops dropped.

`og_basemaps()`: base maps that show the sea floor, and none: EMODnet's
sea floor (its 2020 base layer, the first and the one a map opens on),
the same darkened, EMODnet's lighter atlas (v12), and Esri's ocean,
which reaches beyond Europe's seas. Each is a picture with the place and
sea names of a Carto style over it, Positron's on the light ones and
Dark Matter's on the dark. A base map that shows a flat sea is left out:
the depth is the subject.

## Examples

``` r
vapply(og_palettes(), `[[`, "", "id")
#>  [1] "magma"           "viridis"         "plasma"          "deep"           
#>  [5] "scotland"        "population_dens" "etopo1_bathy"    "colombia_bathy" 
#>  [9] "gn_yl"           "blues"           "high_relief"     "bcyr"           
#> [13] "quiet"           "seabed"          "chart"           "grey"           
#> [17] "drained"         "haxby"          
vapply(og_basemaps(), `[[`, "", "id")
#> [1] "emodnet"       "emodnet_dark"  "emodnet_light" "ocean"        
#> [5] "none"         
```
