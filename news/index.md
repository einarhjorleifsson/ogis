# Changelog

## ogis 2026.11.26.3

- **Documentation only.**
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)’
  help, its error for `compare`, a test’s name and the tracks article
  call its second set of column names upper-case ones (`VESSEL_ID`,
  `DATE_TIME`, …), and the `compare` example’s second source `other`;
  the older entries here are worded alike. Text only: nothing behaves
  differently but the error’s wording.

## ogis 2026.11.26.2

- **`og_cells(pixel = FALSE)`: the fixed sizes alone, opening on the
  finest.** The user (2026-11-26), on an effort map of 0.001-degree
  cells: “there is no difference between grid - about a pixel, fine
  (heavy), coarser and 0.001 degrees. suggest we just”start” at 0.001”.
  Where the cells’ own size is about a pixel at the zooms they are
  looked at, the three choices draw the finest size; with
  `pixel = FALSE` *Cells* lists the sizes (and H3’s) alone.
  `pixel = TRUE`, as before, by default.
- **A bundle carries every size offered.** Its levels started at 0.01
  degrees, so a size offered under it (0.005, 0.001) found no level and
  a bundle drew another size for it; the effort map had passed the finer
  levels to `og_bundle(grids = )` by hand.

## ogis 2026.11.26.1

- **A grid cell with no value is grey**, said so in the legend (“no
  value”, shown while such a cell is in view) and in its popup. Before,
  a cell whose every row lacked the value shown was drawn in the
  palette’s lowest colour, as a small value: the page read a missing
  value as 0, and a bundle wrote it as 0. The user (2026-11-26), on an
  effort map where 13,441 of 148,237 cells hold hauls with no soak: “fix
  the no-soak colour in ogis - think we should user a grey colour for
  NA”. A bundle now writes a missing sum as missing and sums only the
  values a cell’s rows have, as DuckDB’s
  [`sum()`](https://rdrr.io/r/base/sum.html) does on a served map; a
  coarser cell with some values is coloured by them.

## ogis 2026.11.26

- **[`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md)
  draws H3’s hexagons beside the squares**: where the cells carry an H3
  index (a column `h3`, or the one named by `h3 =`), the page’s *Cells*
  offers hexagons at a resolution following the zoom (an edge of four
  pixels or more, a hexagon about eight across) or at one resolution at
  every zoom, from the cells’ own to seven coarser, in the same list as
  the squares, the c-square and the ICES rectangle. DuckDB sums the
  cells to the H3 cell that holds them at the resolution drawn
  (`h3_cell_to_parent()`), and a value is per km² of each hexagon’s own
  area. A table may carry both grids on each row (a row for each square
  and hexagon that meet), or H3 alone (`cell = "h3"` or `"h3_9"` opens
  on them). The user (2026-11-26), for effort maps: “We could both think
  of this as a grid level or hex (h3) level … the C-square is just one
  dimension.” H3 had been set aside for fishycode’s effort map on speed
  (decision 220: 0.7-1.1 s a tile on 524 M cells); on another effort map
  (148,237 cells at 0.001 degrees and H3 resolution 11, served from its
  Parquet file) a whole view at zoom 10 redraws in 0.25-1.0 s on every
  grid, H3 resolution 11’s 63,460 hexagons in view included (measured in
  the page, 2026-11-26). H3 needs DuckDB’s community extension `h3`,
  installed on first use.
- **A bundle offers the squares alone**, saying the hexagons are left
  out: its cells are summed by the browser, which knows squares only.
  Cells with no squares are left out of a bundle.

## ogis 2026.11.22.5

- **The article *A page of your own* steps through a time panel’s
  window**: two buttons of a page’s script set the window to a day and
  the next (`og.window()`), and the script’s box says which day is shown
  (`og.on("window")`), on a vessel of `og_example("dansk")` drawn by
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md),
  its pings following the window, by speed, black the slowest. The
  tracks article says what the map now shows of the window, and that the
  pings are by speed.

## ogis 2026.11.22.4

- **[`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
  colours its pings by speed, in Inferno, black the slowest**, and by
  what the vessel was doing as a choice in the page (*Colour by*), in
  the colours of the activity lane; before, by what it was doing alone,
  speed only where the pings had no activity, in viridis. The maintainer
  (2026-11-22), on a trip check: “the device speed should be the default
  colour of pings. And i am used to the inverse viridis when it comes to
  speed (black - low speed)”, then “I mean inferno”. Asked where in
  ogis: in
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md),
  which knows its speed column;
  [`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
  stays general, viridis for a number, and the time panel’s own points
  already ran Inferno from black. With the pings by speed, *On top*
  (2026.11.22.3) draws the slow or the fast ones over the others.
- **A palette by column, for a choice of colours**:
  `og_point(colour = c(behaviour, speed), palette = list(speed = "inferno"))`,
  each column its own palette, a column not named keeping its default,
  for every layer function with `palette`. One palette had served every
  column of the choice, so a number’s and a category’s could not both be
  chosen.

## ogis 2026.11.22.3

- **Points coloured by a number have a switch, *On top***: the rows in
  their order, as before and by default, or low or high values on top.
  The maintainer (2026-11-22): “that the user can ‘arrange’ the pings in
  the plot so that e.g. the slowest come on top. This should be a switch
  in the app”, for every point layer coloured by a number (asked whether
  by default or by an argument). It is under the layer’s name in the
  page, applies at once, goes into the address as `<id>_ontop`, and
  holds over a change of base map; with a choice of colours
  (`colour = c(behaviour, speed)`) it orders by the colour shown, and a
  colour of categories orders nothing. It is MapLibre’s
  `circle-sort-key`, read from the layer’s state (`og_layer(state = )`):
  a point’s class along the colour’s scale, 32 classes four to each of
  the palette’s nine stops, whatever the stretch, the rows in their
  order within a class and a missing value under all. MapLibre draws
  each key of a tile at once, so a key for each value would be a draw
  call for each point. Measured in headless Chrome (Apple M4 Pro), a
  served map of 200,000 points as tiles, 166,000 in view: the switch
  re-lays the tiles, the map settled 0.22-0.25 s after it (0.13 s back
  to the rows’ order), and a frame took the same time in each. A sort
  key given in MapLibre’s terms (`og_point("circle-sort-key" = )`)
  replaces the switch.

## ogis 2026.11.22.2

- **The panel’s other layers follow its window**: `og_time(follow = )`,
  `"window"` by default. A layer that carries the group and a time
  ([`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  [`og_segment()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  [`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md))
  showed the group’s whole span, wherever the window was set, so a trip
  opened with a few pings either side, or a window dragged on the chart,
  showed more on the map than on the chart. A page built on the panel
  filtered its layers to the window itself (`og.filter()` on the
  features’ time, `og_t`). The maintainer (2026-11-22): “By default I
  wanted only the trip window proper to appear both in space and time”;
  asked whether ogis should do it by default, the window. Those layers
  now show the rows of the window alone (a path’s run where it overlaps
  the window, whole), and follow it each time it is set: a drag, a
  double click, a lane, `og.window()`. `follow = "span"` shows the
  span’s, as before. Each window the reader sets is one filter on each
  such layer, laid out again in MapLibre’s worker, where a span was
  filtered once. Measured in headless Chrome (Apple M4 Pro), a served
  map of one vessel’s 200,000 pings a minute as tiles: a window of a day
  set with `og.window()`, the map settled after a median 615 ms
  following the window and 582 ms following the span (five windows each,
  the camera’s move included), so the filter adds little to the move.
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
  takes the default.

## ogis 2026.11.22.1

- **The time panel’s path lies under the map’s points, and its own
  points are optional**: `og_time(dots = )`. The window’s path and
  points were drawn over every layer, so a point layer of the same rows
  ([`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)’
  pings) lay under a white line and under the panel’s own points, in
  another colour. The maintainer (2026-11-22), on a trip check: “The
  white track line should not have a point. And the pings should be on
  top of the white track line”. The page there moved the panel’s layers
  by their ids and hid its points, again after each change of base map.
  The window’s path is now drawn under the lowest of the panel’s point
  and segment layers
  ([`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  [`og_segment()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md):
  those with the group and a time), over its other layers (a path), and
  its points, rings and hover over every layer, as before; the order
  holds when a layer’s data come late and over a change of base map.
  `dots = FALSE` leaves out the panel’s own points, and with them the
  click that marks a row’s time on the chart; marked rows keep their
  rings.
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
  passes it, as its pings are the panel’s rows.

## ogis 2026.11.22

- **A page’s script reads and sets the time panel’s window, and hears it
  change**: `og.window()` and `og.on("window", fn)`, documented in
  [`og_script()`](https://einarhjorleifsson.github.io/ogis/reference/og_script.md).
  A page built on the panel had to call the page’s internal
  `tSetWindow()`, judge the series loaded by its internal `TS`, and poll
  the address’s `tw` to follow the reader (a trip check built on ogis).
  `og.window()` gives the window shown, `[from, to]` in seconds on the
  panel’s clock, or `null` (no panel, a series loading, a span of no
  rows); `og.window([from, to])` sets it as a drag across the chart
  does, and `og.window(null)` shows the whole span. Asked for before the
  series has loaded, the window is set once it has, in place of the
  address’s. `og.on("window", fn)` calls `fn({window, group, span})`
  each time the window is drawn (a drag, a double click, a lane, another
  group or span, `og.window()`), and at once with the window shown, if
  there is one.

## ogis 2026.11.21.2

- **A lane takes a layer’s colours whether the layer comes before the
  panel or after it.** In 2026.11.21.1 a lane of a column the map
  colours by took the layer’s colours only when the layer was added
  before
  [`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md),
  so
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md),
  which adds its pings after its panel (they then show the panel’s
  vessel and span alone), drew its activity lane in Paired and its pings
  in Okabe-Ito: “Fishing” light blue in the lane, sky blue on the map.
  The layer’s colours are now laid over the lanes each time the map is
  made, from the first layer that colours by the lane’s column; colours
  named in `lane_palette` still win.

## ogis 2026.11.21.1

- **A lane’s value has one colour, solid, the same in every span**:
  `og_time(lane_palette = )`. The lanes were coloured from Pastel 1,
  eight pale colours given to the values in the order they first came in
  the span shown, so “Fishing” could be one colour in one trip and
  another in the next, and the lanes read as washed out. The maintainer
  (2026-11-21), on a trip-check page: “Care to then not make the lower
  time panel so transparent. And use brewer pal 12”, and asked whether
  in ogis or in the page, “Change ogis”. Each interval’s colour is now
  set in R, by its value, over the lane’s values in every group and
  span: colours named by value in `lane_palette`
  (`c(Fishing = "#ff7f00")`) first; else, for a lane of a column a layer
  added before the panel colours by
  ([`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  [`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md)),
  that layer’s colour, so a value is one colour on the map and in the
  lane; else Brewer’s Paired, its twelve colours given to the values in
  their order (numbers as numbers: 9 before 10), over and over. A
  palette’s name or colours in `lane_palette` stand in for Paired. The
  bars are drawn solid, and a label inside one is written in white on a
  dark colour and dark on a light one, whichever has the more contrast.
  An interval with no label stays grey.

## ogis 2026.11.21

- **The time panel draws every row on the map**, unless told otherwise.
  The window’s path joined only every k-th ping and its points were
  thinned alike, to about 5,000 (the documentation said the path was
  drawn whole). Over a vessel’s whole series of 63,740 pings, “1 in 13
  drawn on the map”, the path cut corners, and a point layer beside it
  showed pings with no line through them. The maintainer (2026-11-21):
  “plot everything unless explicitly told not to do so”; thinning “was
  only supposed to deal with the view”. The new `og_time(thin = )` asks
  for it: `FALSE` by default, a number of rows (`TRUE` for 5,000) thins
  a window of more than that to about that many, a marked row always
  kept, and a window narrowed on the chart is thinned less, then not at
  all. The chart was not thinned, and is not: it is given every row, and
  uPlot’s line runs, in each column of pixels, from the least value of
  the rows there to the most, over the window shown, so a drag spreads
  them out again.
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
  takes the default, every row drawn.
- **What it costs**, measured in headless Chrome (157, Apple M4 Pro):
  one vessel a ping a minute, the map settled after the window was set
  (the median of five; the camera’s move left out). The whole series of
  60,000 pings: 250 ms, where the thinned window took 33 ms; of 500,000:
  2.7 s, where it took 33 ms. Most of it is in MapLibre’s worker, the
  line’s data ready after 0.6 s, the points’ after 1.4 s and their
  500,000 circles laid out by 2.6 s; the page itself is held once, for
  0.6 s, as the window’s points are handed to the worker (0.06 s at
  60,000). A window of 5,000 pings: 33 ms, as before. The chart: 1.4 ms
  at 60,000 rows and 11 ms at 500,000. `thin` keeps a long window quick.

## ogis 2026.11.19.1

- **[`og_names()`](https://einarhjorleifsson.github.io/ogis/reference/og_names.md)
  turns a name by its `angle`**, a column of the names in degrees
  counter-clockwise from level, as
  [`og_text()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)’s
  `angle` (a missing angle level), the name turning with the map. A list
  of names lettered along their features (a trough, a long ground) no
  longer lies level. The column is how a name is drawn, not what a click
  shows. Asked by fishycode’s plan 078 (ask i), for MFRI’s place names
  carried by its internal package.

## ogis 2026.11.19

- **A served map’s `og_cells(filter = )` is tested in a browser**, as a
  bundle’s was: the page opens with the choices given (a gear, a preset,
  a span of years) set in its controls from `/meta`’s options, draws
  those cells alone, and writes them into its address; a choice in the
  address wins. No change to the package. A fault was reported on
  fishycode’s plan 078 demo (bottom trawl, 2015-2024, on the
  32-million-row Icelandic effort: “all”, no years, nothing drawn). It
  did not reproduce in headless Chrome or the app’s browser pane, on
  public data or the internal file, served alone or beside the other
  maps. The screenshots had been taken before the page’s first view: the
  page sets its controls only once `/meta` has come and the map has
  drawn its first frame, and a map of the depth alone was as blank at
  that moment. With the layer’s start ignored, the new test fails 6 of
  its 8 checks.

## ogis 2026.11.18.17

- **A vessel whose id has a space has its effort’s cells** in a served
  page. The page writes the tiles’ query as a form does
  (URLSearchParams), a space as `+`, and the server read the `+` as
  itself
  ([`utils::URLdecode()`](https://rdrr.io/r/utils/URLencode.html)), so
  it refused every cells tile that named such a vessel (“the server
  refused tiles (HTTP 400): cells_vid is vessel 4, …”), and the map
  stayed empty of effort. The server now reads every query as a form
  writes it: `+` a space, `%2B` a plus, the bytes as UTF-8, a value
  split at its first `=` only; the tiles, the time panel’s series, a
  fit’s view and a map’s own routes alike (`og_serve(routes = )`: a `+`
  written in a route’s query is now a space; write `%2B`). A bundle was
  not touched: its page reads its own queries.
- **`og_tracks(pings = x)` with no map starts one**, as `og_tracks(x)`
  does, where it stopped with “`map` is an og_map(); the pings go to
  `pings`”. Something else in the map’s place with `pings` given is
  still refused.

## ogis 2026.11.18.16

- **Vessel tracks in one line**,
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
  (ogis as a quick visual check of each step of a track’s processing,
  ramb doing the processing). Pings, as ramb leaves them (`vid`, `time`,
  `lon`, `lat`, `speed`, `trip_id`, `gear`, `hours`, `behaviour`) or
  with upper-case names (`VESSEL_ID`, `DATE_TIME`, …), become the track
  and its pings coloured by what the vessel did; a time panel of speed
  under the map, a vessel chosen there and then one of its trips, with
  lanes of activity, trips and any more given (another method’s trips,
  an observer’s labels) and marks (flags, planted faults); and the
  fishing effort by cell, summed from the fishing pings’ hours by
  vessel, gear and year, following the vessel chosen. On ramb’s `dansk`
  (395,000 pings, 14 vessels; ramb’s flags, harbours, `jepol` trips and
  hours in 4 s) the map built in 1.7 s. On about a million pings (10
  vessels, served on this computer only), from the raw file through ramb
  to the map in 9 s. The map has no layer of each vessel’s whole path:
  such a path ran over every span’s ends and was drawn whole, a year’s
  tangle over the trip chosen; the panel draws the chosen span’s path
  itself. `time_label` names the clock (`"as written (zone unknown)"`
  where it is not known). A trip is ramb’s `voyage_key` where the pings
  have one (one key per trip across vessels and years, from ramb
  2026.11.18, at this viewer’s wish), taken as it is; a vessel’s trip
  numbered from 1 is known by its vessel too. With ramb’s
  `rb_flag_ping_clock_jump()` the clock’s jumps are marks.
- **`og_tracks(compare = )`: where two columns disagree**, two methods’
  trips or an inferred activity against an observer’s: each a lane, and
  the panel marks, a row each, the pings one has and the other has not
  and, where the two share their values, those they give differently. On
  the million pings, two methods’ trips differ on about 1.5 % of them,
  gathered at a harbour mouth, where each decides a trip begins and
  ends.
- **[`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md):
  the grid’s resolution, live.** The page’s *Cells* offers, beside about
  a pixel at each zoom, sizes fixed at every zoom: 0.01, 0.05 (a
  c-square), 0.1 and 0.5 degrees and the ICES statistical rectangle (1
  by 0.5 degrees), those a whole number of the cells’ own (`sizes`,
  `ices`, `cell` for the start). A size narrower than half a pixel at a
  zoom is drawn at a whole number of it. Served and in a bundle alike
  (the browser sums a rectangle from the largest level written that
  divides it; the c-square’s 0.05 is now written).
- **[`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md):
  at least N vessels.** Where the cells name their vessel (`vessels`,
  found by name), the page hides the cells of fewer than 2, 3, 5 or 10
  vessels on the reader’s choice (none hidden by default: a look, not a
  rule), counted after the other choices, and a click shows a cell’s
  number of vessels.
- **[`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md)
  follows a time panel’s vessel** (`follow`): *Show* the panel’s
  vessel’s effort, its gear’s (the gear of most of its hours) or the
  fleet’s, by setting the cells’ own vessel and gear choices as the
  panel’s vessel changes; hidden on a map with no panel.
- **A segment with a time follows the time panel**, as a point does: a
  set and its haul, drawn as a segment, show the panel’s vessel and span
  alone.
- **A new article, “Vessel tracks”**, on ramb’s public examples: trips
  and effort (`dansk`), ramb’s flags against planted faults
  (`dansk_planted`: 44 of 92 caught, 82 good pings flagged), an
  observer’s labels against a speed rule (`ird_mg_gillnet`). The site’s
  build installs ramb (`Config/Needs/website`).

## ogis 2026.11.18.15

- **Values by cell as one layer function**,
  [`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md)
  (the maintainer: “would like that the user could do similar thing but
  from within ogis”, of fishycode’s effort map; named for its format,
  not its first use, as other data have it). A table of cells (`ix` and
  `iy`, a cell’s south-west corner in steps of `unit` degrees; the
  columns chosen by; the values summed) is coloured by a value per
  square kilometre on ogis’s grid layer: the page has a control for each
  column chosen by (all, one, or several from the address; a column of
  years as a span; `one_of`, two counts of the same thing such as two
  definitions of fishing, one at a time) and the colours’ own. As the
  page asks for a tile, DuckDB sums the cells under it to about a screen
  pixel at that zoom, no finer than the cells’ own (read from their
  corners), finer or coarser by the page’s *Cells*. The cells: a table,
  a Parquet file read where it is, or nothing, the file `OGIS_CELLS`
  names (as `OGIS_DEPTH`). Labels and the names of codes (a gear’s id as
  its name) from the file’s data dictionary, else `codes`. The starting
  choices and look as arguments (`filter`, `metric`, `palette`,
  `opacity`, `limits`, `stretch`), the page’s address winning.
  [`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md)
  carries it with no `grids` given, summed in the browser at 0.01
  degrees and up.
  - On fishycode’s 0.005-degree effort grid, its `fishing` preset alone
    sorted by cell (381 MB, 32 million rows): the map built in 1.2 s; a
    tile at zooms 5-8 in 0.03-0.26 s (up to 5.5 MB), at zoom 10 in 0.02
    s, filtered faster; finer cells up to 0.9 s and 20 MB. On its whole
    0.001-degree grid (5.1 GB, both presets as `one_of`): built in 0.7
    s, its lists in 0.9 s, a tile at zoom 6 in 1 s. Bundled with the
    place names in 9 s, 205 MB (the cells 192 MB, at 0.01-0.5 degrees).
- **Place names as one layer function**,
  [`og_names()`](https://einarhjorleifsson.github.io/ogis/reference/og_names.md)
  (the maintainer: a curated list of names, searched, clicked, “more
  detailed informations”; no editing). Each name from its own zoom
  (`min_zoom`), the larger first where they meet (`level`, then `n`),
  written beside its point where crowded; found by the page’s *Find*
  box, the map going to its zoom; a click shows the rest of its row,
  labelled by the file’s data dictionary. Its controls, folded: the
  names’ colour, and the zoom they appear at (a zoom later to two
  earlier), as fishycode’s names map has them. Where the names have
  areas, those are a layer of their own (`<id>_areas`), off when the
  page opens, a click inside one showing the same; sent whole, one file,
  for a few large areas (a sea’s) covered so many tiles that a bundle of
  them as tiles took minutes (13,330 tiles to zoom 8 in 4.4 minutes).
  The names: a table, a (Geo)Parquet file, any file sf reads, or
  nothing, the file `OGIS_NAMES` names. Built on
  [`og_text()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)
  and
  [`og_polygon()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  so a bundle carries them and their search. Fishycode’s 9,139 names
  (1,575 with an area) as one 1.9 MB file: built and served in a second
  or two, bundled in 2.8 s (13 MB).
- **The Find box takes letters no accent makes as a keyboard without
  them writes them**: `ð` as `d`, `þ` as `th`, `æ` as `ae`, `ø` as `o`
  (and `œ`, `ß`, `đ`, `ł`), so `hloduvik` finds Hlöðuvík, where only
  accents were set aside.
- **A shape that is a collection is drawn as its parts.** DuckDB’s
  `ST_AsMVT()` refuses a geometry collection (as
  [`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html)
  or a union leaves some), and a tile holding one was refused whole
  (HTTP 500), its other features with it. Every layer function now takes
  a collection’s parts of the highest dimension
  (`ST_CollectionExtract()`).
- **A grid’s first view from R** (`start` in its config): the page opens
  on the choices and colours its layer gives, the address winning, as it
  already did for a dem layer’s.
  [`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md)
  sets it.

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
