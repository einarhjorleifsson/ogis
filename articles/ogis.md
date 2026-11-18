# Get started

ogis draws maps on [MapLibre](https://maplibre.org) from data that stay
in DuckDB: a parquet file, a lazy table, a data frame or an sf object. A
map is built with the pipe, a layer at a time, and every map below is
live: pan it, zoom it, click a point.

## A first map

The example data are the positions of four vessels on the Icelandic
groundfish survey in March 2019, one row a position, with whether a tow
was on.

``` r

library(ogis)
positions <- og_example("trawlsurvey")
positions |> og_point(colour = behaviour)
```

`colour` takes a column written bare. Its values get a colour each and a
legend; the map opens on the rows’ extent.

## Layers with the pipe

[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
starts a map from data, and each layer function adds a layer over the
ones before. Here a line per vessel in the order of time, and the
positions over it: two columns to colour by (the first shown; the other
is a choice in the page), and a click that shows the row.

``` r

og_map(positions) |>
  og_path(group = vid, time = time, name = "Tracks") |>
  og_point(
    colour = c(behaviour, speed),
    popup = c(vid, time, speed, behaviour),
    name = "Positions"
  )
```

[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
with no data starts a map whose layers bring their own. The survey’s
tows are lines, one a row:

``` r

og_map() |>
  og_line(og_example("trawlsurveytows"), name = "Tows") |>
  og_point(positions, colour = behaviour, name = "Positions",
           visible = FALSE)
```

`visible = FALSE` leaves a layer off when the page opens; its box in the
sidebar turns it on.

## Rings and outlines

`stroke` draws each point as a ring of its colour, `stroke` pixels wide,
hollow, `size` across; `fill = NA` an area’s outline alone. A click
inside either still shows its row. Here the positions faster than 12
knots ringed over the others:

``` r

fast <- dplyr::filter(positions, speed > 12)
og_map(positions) |>
  og_point(colour = behaviour, name = "Positions") |>
  og_point(fast, colour = "#00a5c8", size = 14, stroke = 2,
           name = "Over 12 knots")
```

## In MapLibre’s own terms

Every layer function takes MapLibre’s paint and layout properties by
their own names, in quotes, for what its own arguments do not reach; and
`id`, the name a page’s address and a script know the layer by. Here the
tows dashed:

``` r

og_map() |>
  og_line(og_example("trawlsurveytows"), colour = "#4a5560", name = "Tows",
          "line-dasharray" = list(2, 1))
```

## The order of layers

Each layer is drawn over the ones before it, whatever box of the sidebar
it sits in (`section`). `order` in
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
draws the layers it names first, by their `id`, under the others; the
sidebar keeps its own order. Here the tows, listed last under
*Reference*, drawn under the positions:

``` r

og_map(positions, order = "tows") |>
  og_point(colour = behaviour, name = "Positions") |>
  og_line(og_example("trawlsurveytows"), colour = "#4a5560", id = "tows",
          name = "Tows", section = "Reference")
```

## Finding a row

`search` names a column whose values the page’s *Find* box, above the
sidebar’s boxes, looks through: whole matches first, then values that
begin with what is typed, then any that hold it, case and accents aside,
each kind nearest the view’s centre first. A click on one takes the map
there and shows its row. Here the tows by their id; type `4906`:

``` r

og_map() |>
  og_line(og_example("trawlsurveytows"), popup = id.lgs, search = id.lgs,
          name = "Tows")
```

## The sea floor

[`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
draws a depth model’s depth in colour and its relief shaded;
[`og_contour()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
the lines of equal depth, the charts’ depths a little heavier and
labelled, thinner lines between. Here the Danish waters’ depths, made
into tiles once by
[`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md)
and given to both, under the harbours:

``` r

depth <- og_tiles_dem(og_example("dansk_relief"), maxzoom = 6)
og_map(view = list(bounds = c(2.5, 54.5, 13, 58.5))) |>
  og_relief(depth) |>
  og_contour(depth) |>
  og_polygon(og_example("dansk_harbours"), fill = NA, colour = "#b2182b",
             name = "Harbours")
```

The arguments are where the map starts; the page’s controls, folded
under ▸ beside each layer’s name, change the colours, the shading and
the lines. The depth is grey at 75 % by default, quiet under the map’s
own data; a map whose subject is the sea floor might start otherwise:

``` r

og_relief(depth, palette = "seabed", opacity = 100, limits = c(5, 60), shade = 0.8)
og_contour(depth, major = c(10, 20, 30, 50), minor = FALSE)
```

A depth model kept as an MBTiles file in its own place on each computer
can be named once there, by a line in `.Renviron`
(`usethis::edit_r_environ()` opens it), so a script shared between
colleagues carries no path:

    OGIS_DEPTH=D:/data/depth.mbtiles

``` r

og_map() |> og_relief() |> og_contour() # the model OGIS_DEPTH names
```

## Values by cell

[`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md)
colours a table of cells by a value per square kilometre, such as hours
of fishing by cell, gear and year; the page has a control for each of
the table’s other columns, and the colours’ own. As the page asks for a
tile, DuckDB sums the cells under it to about a screen pixel at that
zoom, the reader’s choices applied. Here the survey’s positions counted
by 0.02-degree cell (each corner in thousandths of a degree), vessel and
what it was doing; choose a vessel, or hauling:

``` r

by_cell <- positions |>
  dplyr::mutate(ix = floor(lon * 50) * 20, iy = floor(lat * 50) * 20, one = 1) |>
  dplyr::count(vid, behaviour, ix, iy, wt = one, name = "positions")
og_map() |>
  og_cells(by_cell, name = "Positions by cell",
           labels = c(vid = "Vessel", behaviour = "Doing", positions = "Positions"))
```

`labels` names the columns where the file’s data dictionary does not, as
it can a gear’s code (`codes`). A column of years is chosen as a span,
from and to; `one_of` names a column whose values are ways of counting
the same thing (two definitions of fishing), shown one at a time. The
arguments are where the map starts:

``` r

og_cells(effort, filter = list(gid = 6, year = c(2015, 2020)), one_of = "preset",
         palette = "blues", opacity = 60, limits = c(0.5, 300), name = "Fishing effort")
```

## Place names

[`og_names()`](https://einarhjorleifsson.github.io/ogis/reference/og_names.md)
writes a list of place names, each from its own zoom (`min_zoom`), the
larger first where they meet (`level`); the page’s *Find* box looks
through them, accents aside and `ð` as `d`, and a click on one shows
what else the table holds. Its controls, folded under ▸, set the names’
colour and the zoom they appear at; where the names have areas, those
are a layer of their own. Here a few of Iceland’s bays and banks, at
rough places:

``` r

places <- data.frame(
  name = c("Faxaflói", "Breiðafjörður", "Ísafjarðardjúp", "Húnaflói", "Skagafjörður",
           "Eyjafjörður", "Skjálfandi", "Þistilfjörður", "Vopnafjörður", "Selvogsbanki"),
  lon = c(-22.6, -23.1, -22.8, -20.6, -19.6, -18.3, -17.5, -15.4, -14.6, -21.6),
  lat = c(64.4, 65.25, 66.12, 65.8, 65.95, 65.95, 66.12, 66.2, 65.8, 63.6),
  min_zoom = c(5, 5, 6, 5, 6, 6, 6, 6, 7, 6), level = c(1, 1, 2, 1, 2, 2, 2, 2, 3, 2),
  kind = c("bay", "bay", "fjord", "bay", "fjord", "fjord", "bay", "fjord", "fjord",
           "bank")
)
og_map() |>
  og_cells(by_cell, name = "Positions by cell",
           labels = c(vid = "Vessel", behaviour = "Doing", positions = "Positions")) |>
  og_names(places)
```

Type `thistil` in *Find*. A list of names kept as a file in its own
place on each computer is named once, as the depth model is; and the
cells too:

    OGIS_NAMES=D:/data/ornefni.parquet
    OGIS_CELLS=D:/data/effort.parquet

``` r

og_map() |>
  og_relief() |> og_contour() |> og_cells(name = "Fishing effort") |> og_names()
```

## A layer of your own

What the layer functions do not draw, an
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
does, in MapLibre’s own terms: a style of your own on elevations,
contours or tiles of your own.
[`og_add_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_add_layer.md)
puts one into the pipe, in a box of the sidebar of its own. Here the
Danish depths again, in colour by a layer written out in full, as
[`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
writes it:

``` r

own <- og_layer(
  "depth", "dem", label = "Depth",
  tiles = og_tiles_dem(og_example("dansk_relief"), maxzoom = 6),
  style = list(list(id = "depth-colour", type = "color-relief")),
  colour = list(palette = "seabed", opacity = 75)
)
og_map(view = list(bounds = c(2.5, 54.5, 13, 58.5))) |>
  og_add_layer(own, section = "Sea floor") |>
  og_polygon(og_example("dansk_harbours"), fill = NA, colour = "#b2182b",
             name = "Harbours")
```

The harbours, their outlines alone, reach from Greenland to the Black
Sea, so `view` opens the map on the grid’s box. Elevations and contours
go under the base map’s place names, whatever their order in the pipe;
the box *Depth* has the colours’ controls.

## A base map of your own

A base map is a MapLibre style, or a picture’s tiles by address: by zoom
and place (`{z}/{x}/{y}`), or a WMS’s `GetMap` with each tile’s box
(`{bbox-epsg-3857}`). The first given is the one the map opens on, the
others choices under *Base map*. Here GEBCO’s shaded sea floor from its
WMS, which reaches past Europe’s seas, then ogis’s own:

``` r

gebco <- list(
  id = "gebco", label = "Sea floor (GEBCO)",
  attribution = "Imagery reproduced from the GEBCO Grid, GEBCO Compilation Group",
  tiles = paste0(
    "https://wms.gebco.net/mapserv?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap",
    "&LAYERS=GEBCO_LATEST&STYLES=&FORMAT=image/png&CRS=EPSG:3857",
    "&WIDTH=256&HEIGHT=256&BBOX={bbox-epsg-3857}"
  )
)
og_map(positions, basemaps = c(list(gebco), og_basemaps())) |>
  og_point(colour = behaviour, name = "Positions")
```

A picture alone has no place names, and the layers’ texts are drawn in
the browser’s own font. `labels`, a style’s address, puts that style’s
names over it with its fonts, as on
[`og_basemaps()`](https://einarhjorleifsson.github.io/ogis/reference/og_palettes.md)’s,
which take Carto’s.

## Showing and sharing

- **In R**, printing a map serves it on this computer and opens it in
  RStudio’s Viewer or a browser.
- **In a document** (Quarto, R Markdown, a pkgdown article like this
  one), a printed map is drawn live in the page.
- **As a folder**, `og_bundle(map, "my-map")` writes the map with its
  data, to open with a double click on any computer, with no R and no
  server.
