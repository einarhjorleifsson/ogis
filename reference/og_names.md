# Place names: labels, their areas, the Find box and what is known of each

`og_names()` writes a list of place names on the map, each from its own
zoom, the larger names first where they meet; the page's *Find* box
looks through them (accents aside), and a click on a name, or a name
found, shows its row. Where the names have areas, these are a layer of
their own, off when the page opens, a click inside one showing the same.

## Usage

``` r
og_names(
  map = NULL,
  names = NULL,
  colour = "#0b3954",
  early = 0,
  areas = FALSE,
  popup = NULL,
  open = FALSE,
  name = "Place names",
  id = "names",
  info = NULL,
  section = "Reference",
  visible = TRUE
)
```

## Arguments

- map:

  A map the pipe makes
  ([`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
  with data or none, and any layer functions). Given the names instead
  (or nothing), a map is started for them.

- names:

  The place names (see *The list of names*).

- colour:

  The names' colour when the page opens, `"#rrggbb"`; the page offers
  dark blue (the default), black, white, red and yellow.

- early:

  How many zooms before its own each name appears when the page opens:
  -1 (a zoom later), 0, 1 or 2; the page has the same choice.

- areas:

  Whether the names' areas show when the page opens.

- popup:

  The columns a click shows, by name; by default every column but the
  name's place, zoom, rank, `n` and area.

- open:

  Whether the layer's controls show when the page opens; folded by
  default.

- name, info:

  The layer's name in the sidebar (the areas' is "Areas of the names")
  and the text behind its ⓘ.

- id:

  The layer's id, its key in the page's address; the areas' is
  `<id>_areas`.

- section:

  The sidebar's box the layers sit in, by its title.

- visible:

  Whether the names are on when the page opens.

## Value

The map, with the layers.

## Details

The arguments are the starting look; the page's controls, folded under ▸
beside the layer's name, change the names' colour and the zoom they
appear at.

## The list of names

`names` is a table with a row for each name (a name of several places, a
row for each), one of:

- nothing (`NULL`): the file named by the environment variable
  `OGIS_NAMES`, a line in `.Renviron`
  (`OGIS_NAMES=D:/data/ornefni.parquet`), so a script shared between
  colleagues carries no path;

- the path of a (Geo)Parquet file; or of a GeoPackage, GeoJSON or any
  file sf reads;

- a data frame, an sf object, or a lazy table on DuckDB.

Its columns, all but `name` optional:

- `name`: the name, as written on the map and found;

- `label_lon`, `label_lat` (or `lon`, `lat`): where the name is written;
  else on its area;

- a geometry column (`geometry`, `geom`): the name's area, a line or a
  point, drawn as the layer `<id>_areas`;

- `min_zoom`: the zoom the name shows from (every zoom where it is
  missing);

- `level`: its rank, 1 to 4, 1 the largest: the text's size, and the
  order names are placed in where they meet;

- `n`: within a rank, the larger placed first (how often a name is used,
  say);

- the others: what a click shows, labelled by the file's data dictionary
  (data-dict.tidyverse.org's, in the Parquet file's metadata), else by
  their names.

## See also

[`og_text()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
and
[`og_polygon()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
which draw them, for labels and areas of your own.

## Examples

``` r
# four names, each from its own zoom
places <- data.frame(
  name = c("Skagen", "Hirtshals", "Frederikshavn", "Læsø"),
  lon = c(10.59, 9.96, 10.54, 11.0), lat = c(57.72, 57.59, 57.44, 57.27),
  min_zoom = c(5, 6, 6, 5), level = c(1, 2, 2, 1),
  kind = c("town", "harbour", "harbour", "island")
)
og_names(places)
#> <og_map> Map
#>   layers: names (geojson)

# a list of names named once, by OGIS_NAMES in .Renviron:
# og_map() |> og_relief() |> og_names()
```
