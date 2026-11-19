# ogis

Fast interactive maps in R, drawn in the browser by MapLibre GL JS, with the sea in mind: tracks, stations, gridded
values, areas and labels over the sea floor. In the company of leaflet, mapview and tmap, ogis keeps the data
in DuckDB: a parquet file of millions of rows reaches the page as vector tiles, so the map stays fast, and its colours,
legend and choices change in the page without asking R again.

A map is built with the pipe, a layer at a time, in the words of ggplot2:

```r
library(ogis)

og_map(og_example("trawlsurvey"), title = "A survey") |>
  og_path(group = vid, time = time, colour = behaviour) |>
  og_point(colour = speed, popup = c(vid, time, speed), minzoom = 8, visible = FALSE)
```

Printed at the console, the map opens in the viewer, served from your machine. `og_bundle()` writes it as a folder
that opens from its `index.html`, with no R and no network but the base map's.

## What there is

- **Layers:** `og_point()`, `og_path()` (rows joined in time, a line per group), `og_line()`, `og_segment()` (a
  line from each row's start to its end), `og_polygon()`, `og_text()`; and `og_layer()` for a layer in MapLibre's
  own terms.
- **Data:** a parquet file, folder or glob, a lazy DuckDB table, a data frame or an sf object. A bare name is a
  column, a string a value: `colour = speed` or `colour = "#c0392b"`.
- **Colours from the data:** Okabe-Ito for up to eight values, Paired for up to twelve, Glasbey's 32 beyond; viridis
  for numbers, dates and ordered values; any palette by name, by colours or by value with `palette`.
- **The sea floor:** base maps that show it (EMODnet's, light and dark, Esri's ocean), and depth, relief and
  contours from your own grid (`og_tiles_dem()`, `og_tiles_mbtiles()`).
- **In the page:** popups, hover labels, a choice of colouring, choices of what to show, a time panel under the map
  (`og_time()`), notes and verdicts written by readers, and the whole view in the page's address.

## Installation

The example data are Git LFS objects, so install from a clone that fetches them, with Git and Git LFS on the machine
(Git for Windows has both; in R, `Sys.which("git")` should give a path):

```r
# install.packages("remotes")
remotes::install_git("https://github.com/einarhjorleifsson/ogis", git = "external", force = TRUE)
```

`remotes::install_github()` would install the LFS pointers instead of the data; `og_example()` then stops and says
so. `force = TRUE` installs over such an install: without it remotes sees the same commit and skips the install.

## Status

Young, and changing: the layer functions are new, and a one-call `og_view()`, cells (`og_grid()`), depth
(`og_relief()`, `og_contour()`) and figures saved at a chosen size and resolution (`og_save()`) are to come. The
package began as the map viewer of the R package [ramb](https://github.com/einarhjorleifsson/ramb).
