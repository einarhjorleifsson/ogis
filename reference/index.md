# Package index

## Start a map

A map from data, which the layer functions add to with the pipe.

- [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
  : A map: layers in groups, texts, base maps and palettes

## Layers

A mark each, one row of the data to one mark: points, paths (rows joined
in time), lines, segments, areas and text.

- [`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
  [`og_line()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
  [`og_segment()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
  [`og_polygon()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
  [`og_text()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
  : Points, lines, areas, segments and text
- [`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md)
  : Paths: rows joined in time, a line per group

## The sea floor

A depth model’s depth in colour, its relief and its contours, made in
the page from its tiles: an MBTiles file, a grid, or one named once by
OGIS_DEPTH.

- [`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
  [`og_contour()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)
  : The sea floor: depth in colour, its relief, and depth contours

## Time

A panel under the map: a group’s rows over time, linked to the map.

- [`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md)
  : A time panel under the map: one group's rows over time, linked to
  the map

## In MapLibre’s own terms

A layer, its section and its tiles made by hand, for what the layer
functions do not draw; added to the pipe by og_add_layer().

- [`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
  : A layer of a map
- [`og_add_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_add_layer.md)
  : A layer of your own on a map the pipe makes
- [`og_section()`](https://einarhjorleifsson.github.io/ogis/reference/og_section.md)
  : A group of layers in a map's sidebar
- [`og_tiles_table()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_table.md)
  : A table of geometries as vector tiles
- [`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md)
  : Tiles of elevations from a grid
- [`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)
  : Tiles from an MBTiles file

## Colours and base maps

- [`og_palettes()`](https://einarhjorleifsson.github.io/ogis/reference/og_palettes.md)
  [`og_basemaps()`](https://einarhjorleifsson.github.io/ogis/reference/og_palettes.md)
  : The palettes and base maps of a map

## A page of your own

A script of your own on the map, and routes of its own on the server:
for a page that does more than show.

- [`og_script()`](https://einarhjorleifsson.github.io/ogis/reference/og_script.md)
  : A page's own script on a map

## Show and share

A map served from R on this machine, or written as a folder that opens
with no R.

- [`print(`*`<og_map>`*`)`](https://einarhjorleifsson.github.io/ogis/reference/print.og_map.md)
  [`format(`*`<og_map>`*`)`](https://einarhjorleifsson.github.io/ogis/reference/print.og_map.md)
  : Show a map
- [`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md)
  [`og_stop()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md)
  : Serve a map
- [`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md)
  : Write a map as a folder that opens with no R and no server

## What readers write

Notes and verdicts written on a served map, kept in a file beside it.

- [`og_notes()`](https://einarhjorleifsson.github.io/ogis/reference/og_notes.md)
  [`og_notes_add()`](https://einarhjorleifsson.github.io/ogis/reference/og_notes.md)
  : Notes pinned on a served map
- [`og_verdicts()`](https://einarhjorleifsson.github.io/ogis/reference/og_verdicts.md)
  : Verdicts given on a served map

## Example data

- [`og_example()`](https://einarhjorleifsson.github.io/ogis/reference/og_example.md)
  : Read an example dataset shipped with ogis
- [`dansk`](https://einarhjorleifsson.github.io/ogis/reference/dansk.md)
  : Danish vessel tracks (AIS)
- [`dansk_harbours`](https://einarhjorleifsson.github.io/ogis/reference/dansk_harbours.md)
  : Harbour polygons for the Danish tracks
- [`dansk_relief`](https://einarhjorleifsson.github.io/ogis/reference/dansk_relief.md)
  : Seabed and land elevation around the Danish tracks
- [`trawlsurvey`](https://einarhjorleifsson.github.io/ogis/reference/trawlsurvey.md)
  : Icelandic groundfish survey, March 2019, vessel tracks
- [`trawlsurveytows`](https://einarhjorleifsson.github.io/ogis/reference/trawlsurveytows.md)
  : Icelandic groundfish survey, March 2019, tows
