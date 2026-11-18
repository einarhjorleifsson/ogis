# Points, lines, areas, segments and text

A layer of a map, one mark for each row of the data. `og_point()` draws
a circle at each row's position (pings, stations, catches); `og_line()`
draws rows that are lines (tows, transects, cables); `og_segment()`
draws a line from each row's start to its end (a tow from shooting to
hauling); `og_polygon()` draws areas, filled and outlined; `og_text()`
writes a column's values at the rows' positions (place names, station
ids). Each is piped onto a map,
`og_map(data) |> og_point(colour = speed)`, or given the data first,
`data |> og_point()`, which starts a map. The data stay in DuckDB and
reach the page as vector tiles, so a map of millions of rows stays fast
and its colours change in the page.

## Usage

``` r
og_point(
  map,
  data = NULL,
  lon = NULL,
  lat = NULL,
  colour = NULL,
  size = NULL,
  stroke = NULL,
  opacity = NULL,
  whole = NULL,
  thin = TRUE,
  palette = NULL,
  limits = NULL,
  stretch = NULL,
  legend = TRUE,
  popup = TRUE,
  labels = NULL,
  codes = NULL,
  hover = NULL,
  choose = NULL,
  search = NULL,
  name = NULL,
  id = NULL,
  info = NULL,
  section = "Layers",
  visible = TRUE,
  minzoom = NULL,
  maxzoom = NULL,
  ...
)

og_line(
  map,
  data = NULL,
  colour = NULL,
  linewidth = NULL,
  opacity = NULL,
  whole = NULL,
  palette = NULL,
  limits = NULL,
  stretch = NULL,
  legend = TRUE,
  popup = TRUE,
  labels = NULL,
  codes = NULL,
  hover = NULL,
  choose = NULL,
  search = NULL,
  name = NULL,
  id = NULL,
  info = NULL,
  section = "Layers",
  visible = TRUE,
  minzoom = NULL,
  maxzoom = NULL,
  ...
)

og_segment(
  map,
  data = NULL,
  lon = NULL,
  lat = NULL,
  lon_end,
  lat_end,
  colour = NULL,
  linewidth = NULL,
  opacity = NULL,
  whole = NULL,
  palette = NULL,
  limits = NULL,
  stretch = NULL,
  legend = TRUE,
  popup = TRUE,
  labels = NULL,
  codes = NULL,
  hover = NULL,
  choose = NULL,
  search = NULL,
  name = NULL,
  id = NULL,
  info = NULL,
  section = "Layers",
  visible = TRUE,
  minzoom = NULL,
  maxzoom = NULL,
  ...
)

og_polygon(
  map,
  data = NULL,
  colour = NULL,
  fill = NULL,
  linewidth = NULL,
  opacity = NULL,
  whole = NULL,
  palette = NULL,
  limits = NULL,
  stretch = NULL,
  legend = TRUE,
  popup = TRUE,
  labels = NULL,
  codes = NULL,
  hover = NULL,
  choose = NULL,
  search = NULL,
  name = NULL,
  id = NULL,
  info = NULL,
  section = "Layers",
  visible = TRUE,
  minzoom = NULL,
  maxzoom = NULL,
  ...
)

og_text(
  map,
  data = NULL,
  lon = NULL,
  lat = NULL,
  colour = NULL,
  size = NULL,
  opacity = NULL,
  whole = NULL,
  label,
  angle = NULL,
  priority = NULL,
  fontface = NULL,
  offset = NULL,
  overlap = FALSE,
  palette = NULL,
  limits = NULL,
  stretch = NULL,
  legend = FALSE,
  popup = FALSE,
  labels = NULL,
  codes = NULL,
  hover = NULL,
  choose = NULL,
  search = NULL,
  name = NULL,
  id = NULL,
  info = NULL,
  section = "Layers",
  visible = TRUE,
  minzoom = NULL,
  maxzoom = NULL,
  ...
)
```

## Arguments

- map:

  An
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
  or the data, which start a map.

- data:

  The rows, if not the map's: a parquet file, folder or glob, a lazy
  DuckDB table, a data frame or an sf object (points, or lines and areas
  for `og_line()` and `og_polygon()`; a table's shapes in a column
  `geometry` as DuckDB's GEOMETRY or WKB).

- lon, lat:

  The position's columns, by default `lon` and `lat`; for `og_segment()`
  its start.

- colour:

  The marks' colour (an area's outline): a colour (`"#c0392b"`), or a
  column written bare (`colour = speed`), coloured by `palette`; several
  columns, `c(behaviour, speed)`, are a choice in the page, the first
  shown. A column's colours by default: Okabe-Ito for up to eight
  values, Paired for up to twelve, Glasbey's 32 beyond, the rest grey as
  "other"; viridis for an ordered factor and for numbers, dates and
  times. `color` is the same.

- size:

  A point's diameter, a text's size (a number, or for text a column
  written bare), in pixels. For points, by default, a size that follows
  the zoom: the least, 2 pixels, until the zoom at which most points lie
  that far apart, then doubling with each zoom in, as a size on the
  ground does, up to the most, 8; `size = c(1, 12)` gives other bounds,
  one number a size that stays.

- stroke:

  For `og_point()`, a ring: its width in pixels. Each point is drawn as
  a ring of its colour, hollow, `size` the diameter inside it; a click
  on it or inside it shows the row.

- opacity:

  The marks' opacity, 0-1.

- whole:

  How the rows reach the page: `TRUE`, whole, as one GeoJSON file read
  once (no further fetching as the reader zooms and pans, nothing cut at
  a tile's edge, one file in a bundle); `FALSE`, as vector tiles cut by
  DuckDB as the page asks for them, which keep a page light however many
  rows there are. By default (`NULL`) whole when its GeoJSON is at most
  5 MB (some 30,000 points; a table of more than 50,000 rows is not
  tried), else as tiles: measured on layers of real data, the two are
  equal in a browser up to about 5 MB, and a whole layer needs nothing
  more of R once read, so a served map pans and zooms while R is busy.
  Above it a whole layer is slower and heavier (about 50 MB of a
  browser's memory for each MB of GeoJSON).

- thin:

  For points: in each tile, one point for each screen pixel, `TRUE`
  (each colour, each value a `choose` list picks and each group of a
  time panel keeping its own), so a tile of millions of rows reaches the
  page as what can be seen of them; a number of pixels for coarser
  cells; `FALSE` keeps every point. At the layer's deepest zoom
  (`maxzoom`, 14 by default) and beyond, only points that would be drawn
  on one spot are dropped.

- palette:

  The colours for a column, in place of the default: a palette's name
  (from
  [`og_palettes()`](https://einarhjorleifsson.github.io/ogis/reference/og_palettes.md),
  [`palette.pals()`](https://rdrr.io/r/grDevices/palette.html) or
  [`hcl.pals()`](https://rdrr.io/r/grDevices/palettes.html), written
  loosely: `"set1"` is Set 1), colours, colours named by value
  (`c(Fishing = "#c0392b")`), or a function of n
  ([`viridisLite::mako`](https://sjmgarnier.github.io/viridisLite/reference/viridis.html)).

- limits, stretch:

  For a numeric column: the values the palette's ends stand at (by
  default its 1st and 99th percentile), and how the colours spread
  between them, `"linear"`, `"log"` or `"equal"` (equal shares of the
  values).

- legend:

  Whether the layer has a legend.

- popup:

  The columns a click shows, written bare, or a variable holding their
  names; `TRUE`, every column; `FALSE`, no popup. A click shows the row
  as a table, read from the server (a bundle carries the rows): a
  column's name, its unit beside it and its description behind it, where
  the data's dictionary or `labels` give them.

- labels:

  The columns' names as the popup shows them, in place of the data's:
  `c(speed = "Speed (knots)")`. By default a data frame's column
  attributes (`label`, `units`) or a parquet file's own dictionary (an
  entry of data-dict.tidyverse.org's format in its metadata, as
  [`og_example()`](https://einarhjorleifsson.github.io/ogis/reference/og_example.md)'s
  files hold), else the column's name.

- codes:

  The labels of a coded column's values, shown beside each code: a named
  list by column, each a named vector (`c("6" = "bottom trawl")`) or a
  table of code and label; by default the dictionary's, where it has
  them.

- hover:

  A column whose value is shown beside the pointer.

- choose:

  The columns, written bare, whose values the reader picks to show of
  this layer alone, each under the layer's name: text, a factor, a
  logical or a whole number (an id, a code) as a list (chips for up to
  12 values, else a list to show one at a time), a fraction, a date or a
  time as a range with two handles, unless the data's dictionary
  declares otherwise (as for
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md));
  ‹ and › step through either. Several are linked: each offers only the
  values the others leave. For choices that drive every layer with the
  column, give `choose` to
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md).

- search:

  A column written bare (`search = name`), its values as text, for the
  page's *Find* box: whole matches first, then values it begins, then
  any holding it, case and accents aside, each kind nearest the view's
  centre first, with their count; a click on one takes the map there, at
  zoom 10 or nearer (a text's own start zoom where it has one), turns
  its layer on and shows its row. The column's texts and places go to
  the page on its first search (a bundle carries them); a layer of more
  than 500,000 rows takes none.

- name, id, info:

  The layer's name in the sidebar, its id, and the text behind its ⓘ.
  The id (lower-case letters, digits and \_) is the key the page's
  address and a page's own script know the layer by, its styles
  `<id>-dot`, `<id>-line`, `<id>-fill` and `<id>-text`; by default made
  from the name.

- section:

  The sidebar's box the layer sits in, by its title. The layer is drawn
  over those added before it, whatever their boxes, unless
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)'s
  `order` says otherwise.

- visible:

  Whether the layer is on when the page opens.

- minzoom, maxzoom:

  The zoom the layer is drawn from, and its tiles' deepest (14 by
  default), past which the map draws that zoom's tiles larger. For
  `og_text()`, `minzoom` may be a column written bare: each row from its
  own zoom, from the first whole zoom at or above it (MapLibre judges a
  zoom in a filter at whole zooms), so a text due at 7.4 shows from 8.

- ...:

  MapLibre's own paint and layout properties for the layer's styles, by
  MapLibre's names in quotes: `"circle-stroke-color" = "white"` (a ring
  of another colour round a filled point),
  `"line-dasharray" = list(2, 1)`, `"text-halo-width" = 0`. Each goes to
  the styles of its kind (circle, line, fill; text, icon and symbol on a
  text's), as paint or layout as MapLibre has it; an expression is a
  list, `list("get", "size")`. `color` is taken for `colour`.

- linewidth:

  A line's width (an area's outline), in pixels.

- lon_end, lat_end:

  For `og_segment()`, the columns of its end.

- fill:

  For `og_polygon()`, the areas' colour, as `colour` is for the other
  marks; `NA`, none: the outline alone, in `colour`, 2 pixels wide
  unless `linewidth` says otherwise, a click inside an area still
  showing its row.

- label:

  For `og_text()`, the column whose values are written, bare. On a line
  (data whose shapes are lines), the text is written along it, at its
  middle.

- angle, priority, fontface, offset, overlap:

  For `og_text()`, each a value or a column written bare: `angle`, the
  text turned that many degrees counter-clockwise, as ggplot2's;
  `priority`, which text is placed first where two would meet, the
  higher (within a tile, as MapLibre places); `fontface`, `"plain"`,
  `"italic"`, `"bold"` or `"bold.italic"`, in the base map's own fonts
  for that face; `offset`, `c(x, y)` in text heights, x to the right and
  y up (a column takes at most 256 pairs of values); `overlap`, `TRUE`
  to draw every text where others meet (MapLibre leaves out the later).
  A turned text keeps the upright box round it clear of others.

## Value

An
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
with the layer added.

## See also

[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md);
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
for a layer in MapLibre's own terms.

## Examples

``` r
# \donttest{
m <- og_example("dansk") |>
  og_point(colour = c(behaviour, speed), popup = c(vessel_id, time_stamp, speed))
format(m)
#> [1] "<og_map> Map"              "  layers: points (vector)"
og_map(og_example("trawlsurveytows")) |> og_line(name = "Tows") |> format()
#> [1] "<og_map> Map"             "  layers: tows (geojson)"
og_example("dansk_harbours") |> og_polygon(fill = "#d9822b", popup = SI_HARB) |> format()
#> [1] "<og_map> Map"              "  layers: areas (geojson)"
# }
```
