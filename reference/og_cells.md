# Values by cell: fishing effort and the like, chosen by gear, year or any column

`og_cells()` colours a table of cells by a value per square kilometre,
such as hours of fishing, summed by cell, gear and year. The page has a
control for each column the cells are chosen by (all of a gear, one, or
several from the address; a span of years), and the colours' own: the
palette, the stretch, the floor and the cap on a histogram of the cells
in view, fitted to the view. As the page asks for a tile, DuckDB sums
the cells under it to about a screen pixel at that zoom, the reader's
choices applied; a cell's value is its sum over its area, so a colour
holds across zooms. A click on a cell shows its values.

## Usage

``` r
og_cells(
  map = NULL,
  cells = NULL,
  values = NULL,
  count = "n",
  by = NULL,
  one_of = NULL,
  range = "year",
  unit = 0.001,
  h3 = NULL,
  sizes = c(0.01, 0.05, 0.1, 0.5),
  ices = TRUE,
  pixel = TRUE,
  cell = NULL,
  vessels = NULL,
  min_vessels = 1,
  follow = "vessel",
  gear = NULL,
  filter = list(),
  metric = NULL,
  palette = "magma",
  opacity = 85,
  limits = NULL,
  stretch = c("even", "equal"),
  labels = NULL,
  codes = NULL,
  name = "Cells",
  id = "cells",
  info = NULL,
  section = name,
  visible = TRUE
)
```

## Arguments

- map:

  A map the pipe makes
  ([`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
  with data or none, and any layer functions). Given the cells instead
  (or nothing), a map is started for them.

- cells:

  The cells (see *The cells*).

- values, count, by:

  The columns summed and coloured, the count summed, and those chosen by
  (see *The cells*).

- one_of:

  Columns of `by` whose values are ways of counting the same thing, not
  parts of it (two definitions of fishing, say): one value shown at a
  time, the first by default, with no "all".

- range:

  Columns of `by` chosen as a span of two values, from and to: `"year"`
  by default, where there is one.

- unit:

  The degrees of one step of `ix` and `iy`.

- h3:

  The column of the cells' H3 index: by default `"h3"` where the cells
  have one; `FALSE`, none.

- sizes, ices:

  The cell sizes in degrees the page offers besides about a pixel, those
  that are a whole number of the cells' own; `ices`, whether the ICES
  statistical rectangle (1 by 0.5 degrees) is one of them. A bundle
  carries every size offered.

- pixel:

  Whether the page offers cells of about a screen pixel at each zoom
  (and finer and coarser) beside the fixed sizes. `FALSE`, the fixed
  sizes alone (and H3's), opening on the finest: for cells whose own
  size is already about a pixel at the zooms they are looked at, where a
  pixel's cells are the finest size's.

- cell:

  The cells' size when the page opens: `NULL`, about a pixel (the finest
  size with `pixel = FALSE`; H3 following the zoom where the cells have
  no squares); one of `sizes`; `"ices"`; `"h3"`, H3 following the zoom;
  or `"h3_<resolution>"`, such as `"h3_9"`.

- vessels:

  The column of `by` that names a vessel, for the cells' number of
  vessels: by default the first of `vid`, `vessel_id`, `VESSEL_ID`,
  `vessel` and `mmsi` there is; `FALSE`, none.

- min_vessels:

  The fewest vessels a cell shown has when the page opens: 1 (all), 2,
  3, 5 or 10.

- follow:

  On a map with a time panel
  ([`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md))
  whose groups are the cells' vessels, the cells shown follow the vessel
  chosen there: `"vessel"`, its own; `"gear"`, its gear's (the gear of
  most of its first value); or `"fleet"`, all of them. The page's *Show*
  changes it; `FALSE`, no such control. Needs `vessels`.

- gear:

  The column of `by` that names a gear, for `follow`: by default the
  first of `gear`, `gid`, `GEAR`, `gear_code` and `metier` there is.

- filter:

  The choices when the page opens, by column:
  `list(gid = 6, year = c(2015, 2020))`, a value or several of a list
  (several, comma-separated in the address), the first and last of a
  span. Those not given: all, the whole span, or the first of `one_of`.

- metric:

  The value coloured when the page opens, one of `values`.

- palette:

  The colours, one of the map's palettes for a grid
  ([`og_palettes()`](https://einarhjorleifsson.github.io/ogis/reference/og_palettes.md)):
  `"magma"` by default.

- opacity:

  The cells' opacity, 0-100.

- limits:

  The values per square kilometre the palette's ends stand at,
  `c(floor, cap)`; by default fitted to the view (the 2nd and 98th
  percentiles of the cells in view), until the reader sets them.

- stretch:

  How the values are spread over the palette: `"even"` on a log scale,
  or `"equal"`, each colour an equal share of the cells in view.

- labels:

  The columns' names as the page shows them, where the file's dictionary
  has none: a named character vector, column to label
  (`c(gid = "Gear", h = "Hours")`); a value's is followed by "per km²".

- codes:

  The names of codes in the columns chosen by, where the file's
  dictionary has none: a named list by column, each a named vector, code
  to name (`list(gid = c("6" = "Bottom trawl (OTB)"))`).

- name, info:

  The layer's name in the sidebar and the text behind its ⓘ.

- id:

  The layer's id, its key in the page's address, and the start of its
  controls' keys (`<id>_<column>`).

- section:

  The sidebar's box the layer sits in, by its title.

- visible:

  Whether the cells are on when the page opens.

## Value

The map, with the layer. A map has one such layer at most.
[`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md)
carries it with no further word, summed by the browser from the cells at
sizes from 0.01 degrees up; H3's hexagons are drawn on a served map
only, so a bundle offers the squares alone, and leaves out cells that
have no squares.

## Details

The page's *Cells* sets their size, live: about a screen pixel at each
zoom (finer or coarser), or one size at every zoom (by default 0.01,
0.05, a c-square, 0.1 and 0.5 degrees, and the ICES statistical
rectangle, 1 by 0.5 degrees), so the reader sees what a grid's
resolution does to the picture. A size narrower than half a pixel at the
zoom is drawn at a whole number of it that is not. Where the cells also
carry their H3 cell (`h3`), the same control offers H3's hexagons: at a
resolution following the zoom (about eight pixels across), or at one
resolution at every zoom, from the cells' own to coarser; a square and a
hexagon are two grids over the same values. Where the cells name their
vessel (`vessels`), the page also hides the cells of fewer than a number
of vessels chosen there (all by default), as a confidentiality rule
would, and a click shows each cell's.

The arguments are the starting look and choices; the page's controls
change them, and a value in the page's address wins over both.

## The cells

`cells` is a table with a row for each cell and combination of the
columns chosen by, one of:

- nothing (`NULL`): the file named by the environment variable
  `OGIS_CELLS`, a line in `.Renviron`
  (`OGIS_CELLS=D:/data/effort.parquet`), so a script shared between
  colleagues carries no path;

- the path of a Parquet file (or several, a glob), read where it is: a
  file sorted by the cell's corner reads fastest;

- a data frame, or a lazy table on DuckDB.

Its columns:

- `ix` and `iy` (or `x` and `y`): the cell's south-west corner, in whole
  steps of `unit` degrees of longitude and latitude (thousandths of a
  degree by default). The cells' own size is read from the corners: a
  table of 0.005-degree cells is drawn no finer than that;

- `h3` (optional, or the column named by `h3`): the cell's H3 index, as
  text or a whole number, all of one resolution, the finest drawn. A
  table may have both a square and an H3 cell on each row (a row for
  each pair that meets), or either alone. H3 needs DuckDB's community
  extension h3, installed on first use;

- `values`: the columns summed, each coloured per square kilometre; by
  default every column of fractions;

- `count`: a column of whole numbers summed and shown on a click, not
  coloured (`n`, the records, by default);

- `by`: the columns the reader chooses by, the others by default: each a
  list of its values ("all" first, then the values by their share of the
  first value, the largest first), or for a column of years (`range`) a
  span of two.

Labels come from the file's data dictionary (data-dict.tidyverse.org's,
in the Parquet file's metadata) where it has one: a column's `label`
names its control or its value, and its `values` name a code (a gear's
id as its name); else from `codes`, else the column's own name.

## See also

[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)'s
`"grid"`, which it makes;
[`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
and
[`og_names()`](https://einarhjorleifsson.github.io/ogis/reference/og_names.md),
for a sea floor and its names under it.

## Examples

``` r
# hours by 0.01-degree cell, gear and year
set.seed(1)
cells <- expand.grid(ix = seq(-24000, -22000, by = 10), iy = seq(65000, 66000, by = 10),
                     gear = c("trawl", "longline"), year = 2020:2022)
cells$hours <- rexp(nrow(cells)) * ifelse(cells$gear == "trawl", 3, 1)
og_cells(cells, labels = c(gear = "Gear", year = "Years", hours = "Hours"), name = "Fishing effort")
#> <og_map> Map
#>   layers: cells (grid)

# trawls in 2021 alone, coloured from 0.5 to 50 hours a km², in blues
og_cells(cells, filter = list(gear = "trawl", year = c(2021, 2021)), limits = c(0.5, 50),
         palette = "blues")
#> <og_map> Map
#>   layers: cells (grid)

# the same hours on H3's hexagons too, beside the squares (each row a square and the hexagon it meets)
if (FALSE) { # \dontrun{
con <- DBI::dbConnect(duckdb::duckdb())
DBI::dbExecute(con, "INSTALL h3 FROM community; LOAD h3")
duckdb::duckdb_register(con, "cells", cells)
hex <- DBI::dbGetQuery(con, "SELECT ix, iy, h3_latlng_to_cell_string((iy + 5) / 1000, (ix + 5) / 1000, 8) AS h3,
                                    gear, year, hours FROM cells")
og_cells(hex, cell = "h3_7", name = "Fishing effort")
} # }

# cells named once, by OGIS_CELLS in .Renviron, over the sea floor:
# og_map() |> og_relief() |> og_cells(name = "Fishing effort", one_of = "preset")
```
