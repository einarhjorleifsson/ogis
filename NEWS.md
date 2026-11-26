# ogis 2026.11.26.1

* **A grid cell with no value is grey**, said so in the legend ("no value", shown while such a cell is in view) and
  in its popup. Before, a cell whose every row lacked the value shown was drawn in the palette's lowest colour, as a
  small value: the page read a missing value as 0, and a bundle wrote it as 0. The user (2026-11-26), on an
  effort map where 13,441 of 148,237 cells hold hauls with no soak: "fix the no-soak colour in ogis - think we
  should user a grey colour for NA". A bundle now writes a missing sum as missing and sums only the values a cell's
  rows have, as DuckDB's `sum()` does on a served map; a coarser cell with some values is coloured by them.

# ogis 2026.11.26

* **`og_cells()` draws H3's hexagons beside the squares**: where the cells carry an H3 index (a column `h3`, or the
  one named by `h3 =`), the page's *Cells* offers hexagons at a resolution following the zoom (an edge of four pixels
  or more, a hexagon about eight across) or at one resolution at every zoom, from the cells' own to seven coarser, in
  the same list as the squares, the c-square and the ICES rectangle. DuckDB sums the cells to the H3 cell that holds
  them at the resolution drawn (`h3_cell_to_parent()`), and a value is per km² of each hexagon's own area. A table may
  carry both grids on each row (a row for each square and hexagon that meet),
  or H3 alone (`cell = "h3"` or `"h3_9"` opens on them). The user (2026-11-26), for effort maps: "We could
  both think of this as a grid level or hex (h3) level ... the C-square is just one dimension." H3 had been set
  aside for fishycode's effort map on speed (decision 220: 0.7-1.1 s a tile on 524 M cells); on another
  effort map (148,237 cells at 0.001 degrees and H3 resolution 11, served from its Parquet file) a whole view at zoom 10
  redraws in 0.25-1.0 s on every grid, H3 resolution 11's 63,460 hexagons in view included (measured in the page,
  2026-11-26). H3 needs DuckDB's community extension `h3`, installed on first use.
* **A bundle offers the squares alone**, saying the hexagons are left out: its cells are summed by the browser, which
  knows squares only. Cells with no squares are left out of a bundle.

# ogis 2026.11.22.5

* **The article *A page of your own* steps through a time panel's window**: two buttons of a page's script set the
  window to a day and the next (`og.window()`), and the script's box says which day is shown (`og.on("window")`), on
  a vessel of `og_example("dansk")` drawn by `og_tracks()`, its pings following the window, by speed, black the
  slowest. The tracks article says what the map now shows of the window, and that the pings are by speed.

# ogis 2026.11.22.4

* **`og_tracks()` colours its pings by speed, in Inferno, black the slowest**, and by what the vessel was doing as a
  choice in the page (*Colour by*), in the colours of the activity lane; before, by what it was doing alone, speed
  only where the pings had no activity, in viridis. The maintainer (2026-11-22), on a trip check: "the device speed
  should be the default colour of pings. And i am used to the inverse viridis when it comes to speed (black - low
  speed)", then "I mean inferno". Asked where in ogis: in `og_tracks()`, which knows its speed column; `og_point()`
  stays general, viridis for a number, and the time panel's own points already ran Inferno from black. With the
  pings by speed, *On top* (2026.11.22.3) draws the slow or the fast ones over the others.
* **A palette by column, for a choice of colours**: `og_point(colour = c(behaviour, speed), palette = list(speed =
  "inferno"))`, each column its own palette, a column not named keeping its default, for every layer function with
  `palette`. One palette had served every column of the choice, so a number's and a category's could not both be
  chosen.

# ogis 2026.11.22.3

* **Points coloured by a number have a switch, *On top***: the rows in their order, as before and by default, or low
  or high values on top. The maintainer (2026-11-22): "that the user can 'arrange' the pings in the plot so that e.g.
  the slowest come on top. This should be a switch in the app", for every point layer coloured by a number (asked
  whether by default or by an argument). It is under the layer's name in the page, applies at once, goes into the
  address as `<id>_ontop`, and holds over a change of base map; with a choice of colours (`colour = c(behaviour,
  speed)`) it orders by the colour shown, and a colour of categories orders nothing. It is MapLibre's
  `circle-sort-key`, read from the layer's state (`og_layer(state = )`): a point's class along the colour's scale, 32
  classes four to each of the palette's nine stops, whatever the stretch, the rows in their order within a class and
  a missing value under all. MapLibre draws each key of a tile at once, so a key for each value would be a draw call
  for each point. Measured in headless Chrome (Apple M4 Pro), a served map of 200,000 points as tiles, 166,000 in view:
  the switch re-lays the tiles, the map settled 0.22-0.25 s after it (0.13 s back to the rows' order), and a frame
  took the same time in each. A sort key given in MapLibre's terms (`og_point("circle-sort-key" = )`) replaces the
  switch.

# ogis 2026.11.22.2

* **The panel's other layers follow its window**: `og_time(follow = )`, `"window"` by default. A layer that carries
  the group and a time (`og_point()`, `og_segment()`, `og_path()`) showed the group's whole span, wherever the window
  was set, so a trip opened with a few pings either side, or a window dragged on the chart, showed more on the map
  than on the chart. A page built on the panel filtered its layers to the window itself (`og.filter()` on the
  features' time, `og_t`). The maintainer (2026-11-22): "By default I wanted only the trip window proper to appear
  both in space and time"; asked whether ogis should do it by default, the window. Those layers now show the rows of
  the window alone (a path's run where it overlaps the window, whole), and follow it each time it is set: a drag, a
  double click, a lane, `og.window()`. `follow = "span"` shows the span's, as before. Each window the reader sets is
  one filter on each such layer, laid out again in MapLibre's worker, where a span was filtered once. Measured in
  headless Chrome (Apple M4 Pro), a served map of one vessel's 200,000 pings a minute as tiles: a window of a day set
  with `og.window()`, the map settled after a median 615 ms following the window and 582 ms following the span (five
  windows each, the camera's move included), so the filter adds little to the move. `og_tracks()` takes the default.

# ogis 2026.11.22.1

* **The time panel's path lies under the map's points, and its own points are optional**: `og_time(dots = )`. The
  window's path and points were drawn over every layer, so a point layer of the same rows (`og_tracks()`' pings) lay
  under a white line and under the panel's own points, in another colour. The maintainer (2026-11-22), on a trip
  check: "The white track line should not have a point. And the pings should be on top of the white track line". The
  page there moved the panel's layers by their ids and hid its points, again after each change of base map. The
  window's path is now drawn under the lowest of the panel's point and segment layers (`og_point()`, `og_segment()`:
  those with the group and a time), over its other layers (a path), and its points, rings and hover over every layer,
  as before; the order holds when a layer's data come late and over a change of base map. `dots = FALSE` leaves out
  the panel's own points, and with them the click that marks a row's time on the chart; marked rows keep their rings.
  `og_tracks()` passes it, as its pings are the panel's rows.

# ogis 2026.11.22

* **A page's script reads and sets the time panel's window, and hears it change**: `og.window()` and
  `og.on("window", fn)`, documented in `og_script()`. A page built on the panel had to call the page's internal
  `tSetWindow()`, judge the series loaded by its internal `TS`, and poll the address's `tw` to follow the reader (a
  trip check built on ogis). `og.window()` gives the window shown,
  `[from, to]` in seconds on the panel's clock, or `null` (no panel, a series loading, a span of no rows);
  `og.window([from, to])` sets it as a drag across the chart does, and `og.window(null)` shows the whole span. Asked
  for before the series has loaded, the window is set once it has, in place of the address's. `og.on("window", fn)`
  calls `fn({window, group, span})` each time the window is drawn (a drag, a double click, a lane, another group or
  span, `og.window()`), and at once with the window shown, if there is one.

# ogis 2026.11.21.2

* **A lane takes a layer's colours whether the layer comes before the panel or after it.** In 2026.11.21.1 a lane of a
  column the map colours by took the layer's colours only when the layer was added before `og_time()`, so
  `og_tracks()`, which adds its pings after its panel (they then show the panel's vessel and span alone), drew its
  activity lane in Paired and its pings in Okabe-Ito: "Fishing" light blue in the lane, sky blue on the map. The layer's
  colours are now laid over the lanes each time the map is made, from the first layer that colours by the lane's
  column; colours named in `lane_palette` still win.

# ogis 2026.11.21.1

* **A lane's value has one colour, solid, the same in every span**: `og_time(lane_palette = )`. The lanes were
  coloured from Pastel 1, eight pale colours given to the values in the order they first came in the span shown, so
  "Fishing" could be one colour in one trip and another in the next, and the lanes read as washed out. The maintainer
  (2026-11-21), on a trip-check page: "Care to then not make the lower time panel so transparent. And use brewer pal
  12", and asked whether in ogis or in the page, "Change ogis". Each interval's colour is now set in R, by its value,
  over the lane's values in every group and span: colours named by value in `lane_palette` (`c(Fishing = "#ff7f00")`)
  first; else, for a lane of a column a layer added before the panel colours by (`og_point()`, `og_path()`), that
  layer's colour, so a value is one colour on the map and in the lane; else Brewer's Paired, its twelve colours given
  to the values in their order (numbers as numbers: 9 before 10), over and over. A palette's name or colours in
  `lane_palette` stand in for Paired. The bars are drawn solid, and a label inside one is written in white on a dark
  colour and dark on a light one, whichever has the more contrast. An interval with no label stays grey.

# ogis 2026.11.21

* **The time panel draws every row on the map**, unless told otherwise. The window's path joined only every k-th ping
  and its points were thinned alike, to about 5,000 (the documentation said the path was drawn whole). Over a vessel's
  whole series of 63,740 pings, "1 in 13 drawn on the map", the path cut corners, and a point layer beside it showed
  pings with no line through them. The maintainer (2026-11-21): "plot everything unless explicitly told not to do so";
  thinning "was only supposed to deal with the view". The new `og_time(thin = )` asks for it: `FALSE` by default, a
  number of rows (`TRUE` for 5,000) thins a window of more than that to about that many, a marked row always kept, and a
  window narrowed on the chart is thinned less, then not at all. The chart was not thinned, and is not: it is given
  every row, and uPlot's line runs, in each column of pixels, from the least value of the rows there to the most, over
  the window shown, so a drag spreads them out again. `og_tracks()` takes the default, every row drawn.
* **What it costs**, measured in headless Chrome (157, Apple M4 Pro): one vessel a ping a minute, the map settled after
  the window was set (the median of five; the camera's move left out). The whole series of 60,000 pings: 250 ms, where
  the thinned window took 33 ms; of 500,000: 2.7 s, where it took 33 ms. Most of it is in MapLibre's worker, the
  line's data ready after 0.6 s, the points' after 1.4 s and their 500,000 circles laid out by 2.6 s; the page itself
  is held once, for 0.6 s, as the window's points are handed to the worker (0.06 s at 60,000). A window of 5,000 pings: 33 ms, as before. The chart: 1.4 ms at 60,000 rows and
  11 ms at 500,000. `thin` keeps a long window quick.

# ogis 2026.11.19.1

* **`og_names()` turns a name by its `angle`**, a column of the names in degrees counter-clockwise from level, as
  `og_text()`'s `angle` (a missing angle level), the name turning with the map. A list of names lettered along their
  features (a trough, a long ground) no longer lies level. The column is how a name is drawn, not what a click shows.
  Asked by fishycode's plan 078 (ask i), for MFRI's place names carried by its internal package.

# ogis 2026.11.19

* **A served map's `og_cells(filter = )` is tested in a browser**, as a bundle's was: the page opens with the
  choices given (a gear, a preset, a span of years) set in its controls from `/meta`'s options, draws those cells
  alone, and writes them into its address; a choice in the address wins. No change to the package. A fault was reported
  on fishycode's plan 078 demo (bottom trawl, 2015-2024, on the 32-million-row Icelandic effort: "all", no years,
  nothing drawn). It did not reproduce in headless Chrome or the app's browser pane, on public data or the internal
  file, served alone or beside the other maps. The screenshots had been taken before the page's first view: the page
  sets its controls only once `/meta` has come and the map has drawn its first frame, and a map of the depth alone was
  as blank at that moment. With the layer's start ignored, the new test fails 6 of its 8 checks.

# ogis 2026.11.18.17

* **A vessel whose id has a space has its effort's cells** in a served page. The page writes the tiles' query as a
  form does (URLSearchParams), a space as `+`, and the server read the `+` as itself (`utils::URLdecode()`), so it
  refused every cells tile that named such a vessel ("the server refused tiles (HTTP 400): cells_vid is vessel 4,
  ..."), and the map stayed empty of effort. The server now reads every query as a form writes it: `+` a space, `%2B`
  a plus, the bytes as UTF-8, a value split at its first `=` only; the tiles, the time panel's series, a fit's view
  and a map's own routes alike (`og_serve(routes = )`: a `+` written in a route's query is now a space; write `%2B`).
  A bundle was not touched: its page reads its own queries.
* **`og_tracks(pings = x)` with no map starts one**, as `og_tracks(x)` does, where it stopped with "`map` is an
  og_map(); the pings go to `pings`". Something else in the map's place with `pings` given is still refused.

# ogis 2026.11.18.16

* **Vessel tracks in one line**, `og_tracks()` (preparation for the EM4SSF hackathon, Ancona, December 2026: ogis as a
  quick visual check of each step of a track's processing, ramb doing the processing). Pings, as ramb leaves them
  (`vid`, `time`, `lon`, `lat`, `speed`, `trip_id`, `gear`, `hours`, `behaviour`) or in EM4SSF's D2.1 format
  (`VESSEL_ID`, `DATE_TIME`, ...), become the track and its pings coloured by what the vessel did; a time panel of
  speed under the map, a vessel chosen there and then one of its trips, with lanes of activity, trips and any more
  given (another method's trips, an observer's labels) and marks (flags, planted faults); and the fishing effort by
  cell, summed from the fishing pings' hours by vessel, gear and year, following the vessel chosen. On ramb's `dansk`
  (395,000 pings, 14 vessels; ramb's flags, harbours, `jepol` trips and hours in 4 s) the map built in 1.7 s. On
  EM4SSF's CS1 (1,020,999 pings, 10 vessels, served on this computer only), from the raw file through ramb to the map
  in 9 s. The map has no layer of each vessel's whole path: such a path ran over every span's ends and was drawn whole,
  a year's tangle over the trip chosen; the panel draws the chosen span's path itself. `time_label` names the clock
  (`"as written (zone unknown)"` for CS1). A trip is ramb's `voyage_key` where the pings have one (one key per trip
  across vessels and years, from ramb 2026.11.18, at this viewer's wish), taken as it is; a vessel's trip numbered from
  1 is known by its vessel too. With ramb's `rb_flag_ping_clock_jump()` the clock's jumps are marks: CS1's three.
* **`og_tracks(compare = )`: where two columns disagree**, two methods' trips or an inferred activity against an
  observer's: each a lane, and the panel marks, a row each, the pings one has and the other has not and, where the
  two share their values, those they give differently. On CS1, ramb's trips (`jepol` on the hackathon's own HDBSCAN
  anchorage sites) and EM4SSF's step-01 trips (option C) differ on 15,652 of 1,020,999 pings (12,183 in ramb's alone,
  3,469 in EM4SSF's alone), gathered at Ancona's harbour mouth, where each decides a trip begins and ends.
* **`og_cells()`: the grid's resolution, live.** The page's *Cells* offers, beside about a pixel at each zoom, sizes
  fixed at every zoom: 0.01, 0.05 (a c-square), 0.1 and 0.5 degrees and the ICES statistical rectangle (1 by 0.5
  degrees), those a whole number of the cells' own (`sizes`, `ices`, `cell` for the start). A size narrower than half
  a pixel at a zoom is drawn at a whole number of it. Served and in a bundle alike (the browser sums a rectangle from
  the largest level written that divides it; the c-square's 0.05 is now written).
* **`og_cells()`: at least N vessels.** Where the cells name their vessel (`vessels`, found by name), the page hides
  the cells of fewer than 2, 3, 5 or 10 vessels on the reader's choice (none hidden by default: a look, not a rule),
  counted after the other choices, and a click shows a cell's number of vessels.
* **`og_cells()` follows a time panel's vessel** (`follow`): *Show* the panel's vessel's effort, its gear's (the gear
  of most of its hours) or the fleet's, by setting the cells' own vessel and gear choices as the panel's vessel
  changes; hidden on a map with no panel.
* **A segment with a time follows the time panel**, as a point does: a set and its haul, drawn as a segment, show the
  panel's vessel and span alone.
* **A new article, "Vessel tracks"**, on ramb's public examples: trips and effort (`dansk`), ramb's flags against
  planted faults (`dansk_planted`: 44 of 92 caught, 82 good pings flagged), an observer's labels against a speed rule
  (`ird_mg_gillnet`). The site's build installs ramb (`Config/Needs/website`).

# ogis 2026.11.18.15

* **Values by cell as one layer function**, `og_cells()` (the maintainer: "would like that the user could do similar
  thing but from within ogis", of fishycode's effort map; named for its format, not its first use, as other data have
  it). A table of cells (`ix` and `iy`, a cell's south-west corner in steps of `unit` degrees; the columns chosen by;
  the values summed) is coloured by a value per square kilometre on ogis's grid layer: the page has a control for each
  column chosen by (all, one, or several from the address; a column of years as a span; `one_of`, two counts of the
  same thing such as two definitions of fishing, one at a time) and the colours' own. As the page asks for a tile,
  DuckDB sums the cells under it to about a screen pixel at that zoom, no finer than the cells' own (read from their
  corners), finer or coarser by the page's *Cells*. The cells: a table, a Parquet file read where it is, or nothing,
  the file `OGIS_CELLS` names (as `OGIS_DEPTH`). Labels and the names of codes (a gear's id as its name) from the
  file's data dictionary, else `codes`. The starting choices and look as arguments (`filter`, `metric`, `palette`,
  `opacity`, `limits`, `stretch`), the page's address winning. `og_bundle()` carries it with no `grids` given, summed
  in the browser at 0.01 degrees and up.
  - On fishycode's 0.005-degree effort grid, its `fishing` preset alone sorted by cell (381 MB, 32 million rows): the
    map built in 1.2 s; a tile at zooms 5-8 in 0.03-0.26 s (up to 5.5 MB), at zoom 10 in 0.02 s, filtered faster;
    finer cells up to 0.9 s and 20 MB. On its whole 0.001-degree grid (5.1 GB, both presets as `one_of`): built in
    0.7 s, its lists in 0.9 s, a tile at zoom 6 in 1 s. Bundled with the place names in 9 s, 205 MB (the cells 192
    MB, at 0.01-0.5 degrees).
* **Place names as one layer function**, `og_names()` (the maintainer: a curated list of names, searched, clicked,
  "more detailed informations"; no editing). Each name from its own zoom (`min_zoom`), the larger first where they meet
  (`level`, then `n`), written beside its point where crowded; found by the page's *Find* box, the map going to its
  zoom; a click shows the rest of its row, labelled by the file's data dictionary. Its controls, folded: the names'
  colour, and the zoom they appear at (a zoom later to two earlier), as fishycode's names map has them. Where the names
  have areas, those are a layer of their own (`<id>_areas`), off when the page opens, a click inside one showing the
  same; sent whole, one file, for a few large areas (a sea's) covered so many tiles that a bundle of them as tiles took
  minutes (13,330 tiles to zoom 8 in 4.4 minutes). The names: a table, a (Geo)Parquet file, any file sf reads, or
  nothing, the file `OGIS_NAMES` names. Built on `og_text()` and `og_polygon()`, so a bundle carries them and their
  search. Fishycode's 9,139 names (1,575 with an area) as one 1.9 MB file: built and served in a second or two,
  bundled in 2.8 s (13 MB).
* **The Find box takes letters no accent makes as a keyboard without them writes them**: `ð` as `d`, `þ` as `th`, `æ`
  as `ae`, `ø` as `o` (and `œ`, `ß`, `đ`, `ł`), so `hloduvik` finds Hlöðuvík, where only accents were set aside.
* **A shape that is a collection is drawn as its parts.** DuckDB's `ST_AsMVT()` refuses a geometry collection (as
  `sf::st_make_valid()` or a union leaves some), and a tile holding one was refused whole (HTTP 500), its other
  features with it. Every layer function now takes a collection's parts of the highest dimension (`ST_CollectionExtract()`).
* **A grid's first view from R** (`start` in its config): the page opens on the choices and colours its layer gives,
  the address winning, as it already did for a dem layer's. `og_cells()` sets it.

# ogis 2026.11.18.14

* **The sea floor as two layer functions** (plan 072's step 3, at the maintainer's word: "can we not just have a ogis
  wrapper"). `og_relief()` draws a depth model's depth in colour and its relief shaded, as two layers; `og_contour()`
  its lines of equal depth, the charts' depths (`major`, by default 10, 25, 50, 100, 150, 200, 300, 400, 500, 1,000
  m and on) a little heavier and labelled, thinner lines between them spaced by depth and zoom (`minor`), as the names
  map of Icelandic waters drew them. `og_map() |> og_relief() |> og_contour()` replaces some twenty lines of
  `og_layer()`s.
  - The depth model (`tiles`): nothing, the one `OGIS_DEPTH` names; an MBTiles file; a grid (a GeoTIFF, a terra
    raster, a data frame of cells), made into tiles by `og_tiles_dem()`; or a tile function. Given first, it starts a
    map that opens on its extent.
  - The starting look as plain arguments: `palette` (by default `"grey"`, at 75 % `opacity`, quiet under the map's
    own data, as the maintainer set the names map's), `limits` (fitted to the view by default), `scale`, `shade`
    (`TRUE`, an intensity, or `FALSE`); `major`, `minor`, `labels` and `colour` for the lines.
  - A major depth shows from the zoom whose shallowest spacing it is at least; the lines are made at the common
    divisor of the spacings and the depths shown (with 25 m among them, every 5 m from zoom 7). On the Olex grid in
    headless Chrome a view settled in 2.6 s at zooms 7, 8 and 10, labels at 10-200 m. A label may bend as sharply as
    the line: at 30 or 90 degrees no label was placed on that grid's stepped lines at zoom 10.
* **No wall of contours along a grid's edge.** Elevation tiles hold 0 (sea level) beyond a grid and on land, so every
  depth between a grid's edge in open water and 0 was drawn along the edge (a box of 5-25 m lines round the Danish
  example's North Sea; on the Olex grid, whose edges lie at 1,000-3,000 m, a band of hundreds). A contour layer now
  hands maplibre-contour a value at the fit's `nodata` (0 by default) as missing, and it draws no line through a
  missing value; lines no longer stack along the coast either. The colours and the shading are as they were (the
  shading still marks the edge with a thin seam: MapLibre's hillshade has no missing values). This needs the lines
  made on the page's own thread when served, as a bundle already made them; on the Olex grid a view settled as fast.
  The test fails without it (12 lines along a flat grid's edge, against none).
* **A layer's controls can open folded** (the maintainer: the depth layer's details not shown until the reader expands
  it). A layer whose config has `fold` (as `og_relief()`'s and `og_contour()`'s have, unless `open = TRUE`) shows ▸
  beside its name, a click showing its controls; its colours' scale bar and a legend show either way.
* `og_tiles_mbtiles()` with no `file` reads the file named by the environment variable `OGIS_DEPTH`, a line in
  `.Renviron` (`OGIS_DEPTH=D:/data/depth.mbtiles`), and says so once a session; a `file` given wins. A depth model
  shared between colleagues as one MBTiles file, each keeping it where they like, is then named once on each computer
  and in no script. Errors say what to do: with neither, how to set the variable; with a path that is no file, or no
  MBTiles (SQLite) file, which path and from where, a grid pointed to `og_tiles_dem()`. `~` in a path is expanded. At
  the maintainer's word ("Yes, build it"), from the side study of the Icelandic depth model in ogis.
* RSQLite is imported, no longer suggested: `og_tiles_mbtiles()` works as soon as ogis is installed. DuckDB's own
  SQLite reader was measured and set aside: it scans the whole tiles table for each tile (110 ms a tile on a 547 MB
  file, against RSQLite's 0.2-0.7 ms), as it uses no index of the file.

# ogis 2026.11.18.13

* `og_text(endzoom = )`: where a label stops, a number (the styles' own `maxzoom`) or a column written bare, each row
  until its own, hidden from the first whole zoom at or above it (MapLibre judges a zoom in a filter at whole zooms,
  as for `minzoom`); a row with no end shows on. With `minzoom` a label shows in a band of zooms, as the names editor
  shows its names, and two layers can take turns. A search takes the map to a zoom where its label shows, before its
  end. Reported by the names session (plan 076 step 6). The Labels article shows it.
* A layer function's `minzoom` as a number now holds for a layer sent whole: its styles take it. It reached the page
  as the layer's own `minzoom`, which only a tiled layer's source uses, so `og_point(minzoom = 8)` or
  `og_text(minzoom = 10)` on a layer small enough to go whole drew at every zoom. Found writing the Labels article's
  example of two label layers taking turns.

# ogis 2026.11.18.12

* The engine's guard against MapLibre 5's lost index is gone. In 5.x a tile loaded again while an earlier load of it
  was still being read lost its index, and every query of that layer then threw "Out of bounds" until its data were
  sent again; the page caught that, sent the data again and tried a click once more. MapLibre fixed it in 6.0 and 6.3,
  and the reproduction that found it (data sent during an animated zoom, a filter reading the zoom from MapLibre's
  global state) failed 9 times in 200 on 5.24.1 and not once in 200 on 6.19.0. Queries go straight to MapLibre;
  `query()` stays as the one place that leaves out layers not on the map.

# ogis 2026.11.18.11

* MapLibre GL JS 6.19.0 in place of 5.24.1, the last of 5.x. MapLibre 6 is published only as ES modules, which a page
  opened from its folder cannot load, and a bundle opens by a double click; so its two modules are made classic
  scripts by `tools/vendor-maplibre.R` (the npm package checked against the registry's SHA-512; `import.meta.url` the
  script's own address, the export list the global `maplibregl`), its worker's code carried in
  `maplibre-gl-worker.js` and handed to MapLibre as a blob, which MapLibre 6.17 and later runs on a page opened from a
  file. The page loads that script before MapLibre; nothing else in it changed. A bundle is 0.6 MB larger.
* A test opens a bundle from its folder (`file://`), as a double click does, and checks its outlines, labels and
  contours (made in the page by maplibre-contour) are drawn; every other page test opens its page over http.
  `tools/firefox-check.R` does the same in headless Firefox, by hand at each MapLibre update.
* Checked beside 5.24.1 at the same views: lines that cross, labels past their tiles' deepest zoom and contours look
  the same; a map of 8,918 labels opens and zooms as fast. The engine's guard on queries for MapLibre 5's lost index
  stays until a reproduction shows 6 has done with it.

# ogis 2026.11.18.10

* rebelrebel is renamed **ogis**, its prefix `rr_` now `og_`: every function (`og_map()`, `og_point()`,
  `og_serve()`, ...) and class (`og_map`, `og_layer`, `og_section`), and in the page what a script of its own sees:
  the object it is given (`og`: `og.on()`, `og.state()`, `og.fetch()`, ...), the features' key (`og_row`) and the
  classes its styles may name (`.og-panel`). A map's own route header is `X-OG-Notes`. Names the engine kept from
  ramb (`rb`) are `og` too. Nothing else changed: a call made with the `rr_` names is the same call with `og_`. The
  entries below keep the names of their day.

# rebelrebel 2026.11.18.9

* Features have ids in the page: a layer function's features are known by their row's number (`rr_row`, now carried
  by every feature, with a popup or not), given to MapLibre as the source's `promoteId`; a layer of your own by
  `rr_layer(key = )`. So MapLibre's own feature state works on them: a page's script sets it with
  `rr.state(id, key, value)` (reads it with `rr.state(id, key)`, clears it with `null`) and a style reads it as
  `list("feature-state", "<name>")`, given to a layer function in MapLibre's terms. A selection is drawn with no data
  sent again (pages sent a layer's data again to show one). The script's states are set again when a style is made
  again whole, which drops MapLibre's own; a click's `feature.id` is the row's number, and `rr.layer()` gives the
  layer's `key`. "A page of your own" rings the marked positions so.

# rebelrebel 2026.11.18.8

* A search over a layer's column: `search = name` on `rr_point()`, `rr_line()`, `rr_segment()`, `rr_polygon()` and
  `rr_text()` puts a *Find* box above the sidebar's boxes. It ranks whole matches first, then values that begin with
  what is typed, then any that hold it, case and accents aside, each kind nearest the view's centre first, and says
  how many there are when not all 40 are listed. A click on one (or Enter) takes the map there, at zoom 10 or nearer
  (a text's own start zoom where it has one), turns its layer on and shows its row as a click would (a label MapLibre
  left out, its text). The column's values and each row's place (a point's own, a point on a shape, a segment's
  middle) are read by the page on its first search, from the server (`/search/<id>`) or the bundle; a layer of more
  than 500,000 rows takes none. "Get started" finds the tows by their ids.

# rebelrebel 2026.11.18.7

* `rr_point(stroke = )`: each point drawn as a ring of its colour, `stroke` pixels wide, hollow, `size` the diameter
  inside it; its legend shows rings, and a choice of colour columns paints the rings. Until now a ring took four of
  MapLibre's properties by hand ("Get started" showed them).
* `rr_polygon(fill = NA)`: an area's outline alone, in `colour`, 2 pixels wide unless `linewidth` says otherwise. The
  fill is kept, drawn clear, so a click inside an area still shows its row; its legend shows an outline.
* "Get started" shows both, and MapLibre's own terms by a dashed line.

# rebelrebel 2026.11.18.6

* `rr_map(order = )`: the order the layers are drawn in, by their ids, from the lowest up; those named first, under
  the others, which keep theirs. The sidebar keeps its own order, so a layer may be listed in one place and drawn in
  another (a coast listed last under "Reference", drawn under the rest). A map started from data names the layers its
  layer functions add later by their `id`; one never added is an error once the map is shown. A map of
  `rr_section()`s checks its `order` at once. Elevations and contours stay under the base map's labels.
* A piped map draws its layers in the order added, the later over the earlier, as "Get started" and
  `rr_add_layer()`'s help said. It drew them by their sidebar boxes, in the order the boxes were first named, so a
  layer added later in an earlier box went under one added before it in a later box.
* The page draws the layers in the map's order, not in the order their data arrive: a layer read from a file (every
  GeoJSON layer in a bundle, a served one whose count is not known) or made once a library has loaded (contours) went
  over all the others when it came, so a large layer (an 8 MB coast) could cover a small one meant over it. Each now
  goes under the first of its kind already drawn that comes after it.
* "Get started" has a section on the order of layers.

# rebelrebel 2026.11.18.5

* A base map given as a tile address, by `{z}/{x}/{y}` or a WMS's `GetMap` with `BBOX={bbox-epsg-3857}`, opens the
  page when it is the first, and the page switches to it and back; now tested in the page. Before 2026.11.12 such a
  page never loaded its style (`glyphs: undefined`, mended then with base maps written as styles), so maps of place
  names put a style first to get round it. `rr_basemaps()`'s help says how such an address is written, that its
  server must let the page read its pictures (CORS), and that a picture alone has no fonts, so the layers' texts are
  drawn in the browser's; it no longer says a route of `rr_serve()` may serve tiles (a route answers JSON or text).
  "Get started" opens a map on GEBCO's sea floor from its WMS.

# rebelrebel 2026.11.18.4

* `rr.fetch()` reaches a route's `path` and `query`, as `rr_serve()` documents them: the route's name, then a path and
  a query as written, `rr.fetch("marks/12?full=1")`. It encoded the whole name, so `?`, `=` and `/` went to the server
  as part of a name no route has (404). A name that is no route's is refused in the page. Found by a page of place
  names built on rebelrebel.
* `popup = <a variable holding column names>` no longer draws tidyselect's warning of an external vector: such a
  variable is taken as `all_of()` it, as the help says it may be given. A column of the same name still wins.
* `rr_basemaps()`'s help: a style served by the map's own routes is given by a relative address (`"/x/style"`), for
  the page may be opened as `localhost` or `127.0.0.1`, which a browser holds apart.

# rebelrebel 2026.11.18.3

* `rr_add_layer()` puts an `rr_layer()` of your own into the pipe: `rr_map() |> rr_add_layer(depth, section = "Sea
  floor") |> rr_text(...)`. Elevations, contours, tiles of your own sit beside the layer functions' layers, in a box of
  the sidebar of their own, served, bundled and knitted as the others; elevations and contours under the base map's
  labels, as before. Until now a piped map took no `rr_layer()`, and a map of `rr_section()`s takes no layer function
  (it still does not: its message now says to start with `rr_map()` and add with `rr_add_layer()`). Found rebuilding a
  map of place names on the pipe. A map whose only layers are added so fits their tiles' extent; else the rows decide
  the first view, as before. The map's data (`rr_map(data)`) are read by the first layer function, which also makes
  the map's choices then, an `rr_add_layer()` before it or not. "Get started" shows it.

# rebelrebel 2026.11.18.2

* A page of your own on a map: `rr_script()` puts a script (and its styles) into the page, run once the layers are
  added and given one object, `rr`, the whole of what it may use of the page: the MapLibre map, a layer's style ids,
  the clicks on a layer (`rr.on("click", id, fn)`, with the clicked row, `null` when a newer click came), new data for
  a layer sent whole (at most once a frame), a filter of its own kept with the page's choices, a panel in the sidebar,
  its own routes on the server (`rr.fetch()`) and a file for the reader to save (`rr.save()`). A bundle carries the
  script, which runs there with no server. rebelrebel itself edits nothing: what a page does more than show is the
  page's. A new article, "A page of your own".
* `rr_serve(routes = )`: a map's own routes, each a function answering `/x/<name>` from the page with the request (its
  method, path, query and JSON body read), its value sent back as JSON or text; answered, as the notes, only for a page
  opened from this computer. `rr_serve(wait = TRUE)`: the server keeps serving until stopped, so a script run by
  `Rscript` needs no loop of its own to keep its map up. Not the default: a script, a test or a document that serves
  a map and goes on would hang (rebelrebel's own tests did, with `wait` on by default when R was not interactive).

# rebelrebel 2026.11.18.1

* Every layer function takes `id`, the layer's id (by default made from its name, as before), which the page's address
  and a page's own script know it by, and MapLibre's own paint and layout properties by their names in `...`:
  `rr_point("circle-stroke-width" = 2, "circle-stroke-color" = "cyan")`, `rr_polygon("fill-opacity" = 0)` (an outline
  alone), `rr_text("text-halo-width" = 0)`. Each goes to the layer's styles of its kind, as paint or layout as MapLibre
  has it. A map's lists need no editing by hand to restyle a layer, nor its generated ids guessing. An argument a
  function has not still stops, as before.

# rebelrebel 2026.11.18

* `rr_text()` writes labels with a look of their own for each row: `minzoom` may be a column, each row drawn from the
  first whole zoom at or above its own (MapLibre judges a zoom in a filter at whole zooms, so a label due at 7.4 shows
  from 8: robust, and no two labels of a set placed apart at their own zooms meet); `angle` (counter-clockwise, as
  ggplot2's), `priority` (the higher placed first where two meet), `size`, `fontface` (`"plain"`, `"italic"`, `"bold"`,
  `"bold.italic"`, in the base map's own fonts for each face) and `offset` (`c(x, y)` in text heights), each a value or
  a column; `overlap = TRUE` draws every label. Text on lines is written along them, at their middle. Checked on a real
  set of 25,880 place names with start zooms, angles and priorities: built in 0.2 s, and MapLibre hid as large a share
  where they met (10 %) as the names' own page did. A new article, "Labels".
* A view and base maps given to `rr_map()` hold for a map its layer functions build (`rr_map(view = list(bounds = ))
  |> rr_polygon(areas)`); the rows' extent and every base map were taken whatever was given.

# rebelrebel 2026.11.17.1

* Clicks, hovers and the pointer survive MapLibre 5's lost index. MapLibre 5.x loses a tile's index when the tile is
  loaded again while an earlier load of it is still being read (fixed only in MapLibre 6.0 and 6.3, which load only as
  ES modules, which a page opened from its folder cannot): `queryRenderedFeatures()` then throws "Out of bounds" on
  that layer until its source is loaded again, and every click and hover on it failed. Measured on a bare MapLibre
  page: a filter reading the zoom from the global state with data sent during a zoom failed 13 times in 100, a filter
  on whole zooms never. Every query of the page now goes through one guard: a layer that throws is left out of the
  answer, its data sent again (which cured every failure seen) or a tiled layer's tiles fetched again, and a click
  tried once more when the map is idle. One click and one pointer check replace the layers' own handlers, which
  MapLibre queried unguarded. Browser tests force the failure and click.
* MapLibre GL JS 5.24.1 (from 5.24.0): attributions cleaned by an allow list, the same interface.

# rebelrebel 2026.11.17

* A map printed in a Quarto or R Markdown document, or a pkgdown article, is drawn live in the rendered page, as
  leaflet's maps are: it pans, zooms and answers clicks (`knit_print()`). It is written as a bundle and put beside the
  document as one of its dependencies, shown in an iframe; the libraries (MapLibre and the others) are one copy for all
  the maps of a document. A document must keep its files beside it, as Quarto and pkgdown do; a self-contained page says
  so where the map would be. The chunk's `out-width` and `out-height` set its size (by default the page's width and 480
  pixels). The first article, "Get started", shows three such maps.
* A map started from data opens on the rows' extent fitted to the frame it has (a window, an article's iframe), where
  it took a zoom from the extent's width alone (zoom 3 for Iceland's waters, whatever the frame). A view in the page's
  address still wins; `rr_map(view = list(bounds = ))` gives an extent to fit.
* `rr_map()` with no data starts a map whose layers each bring their own: `rr_map() |> rr_line(tows) |>
  rr_point(stations)`. It stopped, asking for sections.
* duckdb's notice of where it keeps its extensions no longer prints when a map is made (it showed in documents).

# rebelrebel 2026.11.12.2

* A trackpad's two-finger swipe pans the map, up, down and sideways, as it scrolls a page; a pinch and a mouse's wheel
  zoom, as before. MapLibre zooms on every wheel event, so a swipe zoomed and the map could not be moved without
  dragging it. A burst of events takes the kind of its first: a swipe has a sideways part or starts small in pixels; a
  wheel comes in lines, in a Mac mouse's step (4.000244140625 px, MapLibre's own test) or large. Over a popup or a
  control the wheel is theirs.

# rebelrebel 2026.11.12.1

* A popup that takes verdicts (`rr_serve(verdicts = )`) on a layer function's layer showed its title and questions
  but none of its fields: since a layer function's fields are its row, fetched on the click, the verdict popup looked
  for them in the feature, where they are not. It now fetches the row as the popup without questions does, and shows
  it under the questions.

# rebelrebel 2026.11.12

* A choice's option may name a base map, `base`, shown while that value is the one chosen (by the list, by ‹ and ›, or
  in the address, unless the address names a base map of its own): a chart's scale chosen with that chart beneath, so
  one control shows a scale's features and its chart. All, several values, or a value with none leave the base map as
  it is.
* Switching between two base maps written as styles with no glyphs did nothing: the page wrote `glyphs: undefined`
  into the new style, which fails MapLibre's validation, and MapLibre then keeps the old style without a word. The
  glyphs are now left out where neither style has them.

# rebelrebel 2026.11.11.4

* A layer function sends a small layer whole by default: `whole = NULL` sends it to the page as one GeoJSON file when
  that is at most 5 MB (some 30,000 points), else as tiles; a table of more than 50,000 rows is not tried. Up to
  there the two were equal in a browser (fishycode's whole-or-tiles study, 18 layers of real data), and a whole layer
  needs nothing more of R once read: a served map pans and zooms while R is busy. With R kept busy for 15 s, the
  survey's points settled at a new view in 0.6-0.8 s whole, and in 14.5-14.6 s as tiles, once R was free. `TRUE` and
  `FALSE` still decide; another value is an error. The example data's points, tows, paths and harbours now go whole;
  `dansk`'s 395,558 pings as tiles.
* Once a map with a layer sent whole had been served, `rr_stop()`, and so a map served again on a port, stopped with
  "values must be length 1": the layer's table, which it has none of, was listed as `NULL` among the served maps'.

# rebelrebel 2026.11.11.3

* A bundle's tiles are one file a layer: `rr_bundle()` writes a layer's tiles, vector tiles and elevation images
  alike, as one PMTiles archive (version 3) in a script, `tiles/<layer>.pmtiles.js`, in place of a script for each
  tile, read in the page by the pmtiles library (4.5.0, BSD 3-Clause, in `vendor/`). A bundle is about a dozen files
  however many tiles it holds: `dansk`'s points to zoom 14, 13 files where there were 4,302; a 50 m grid's elevation
  tiles to zoom 8, 12 where there were 623. Its tiles and their bytes are the same.
* Opened from its folder, the page reads an archive whole: for 90-141 MB of tiles, a settled screen 1-2 s later and
  300-650 MB more of Chrome's memory than a file a tile took, and `rr_bundle()` says so of an archive over 100 MB. Put
  on a web host (http or https), the page reads only what the view needs, by range requests into the same file
  (base64 decodes from any multiple of four characters): as fast and as light as a file a tile, for 1.0-1.7 times its
  bytes. A host that answers no range sends the file whole, once.
* A bundle's base64 is decoded by the browser's own `Uint8Array.fromBase64()` where it has one.

# rebelrebel 2026.11.11.2

* A map printed, or served by `rr_serve()` with no `port`, takes 8790 or, when another program holds it, the next
  free port to 8889: it stopped with "Port 8790 is taken: give another port" though no port had been given, as when
  another local service listened on 8790. Printed again, a map replaces the last one served with no port, where it
  is; a map on a port named is never replaced by one with no port. A port named and taken is still an error, and
  httpuv's own line ("createTcpServer: address already in use") is no longer printed before it. `rr_serve(port = )`
  and `rr_time(port = )` default to `NULL`; a layer function sets no port.

# rebelrebel 2026.11.11.1

* A bundle's rows are read in a tenth of a second: `rr_bundle()` writes a layer's rows as an array, row n at n - 1.
  Written as an object keyed by row number, `dansk`'s 395,558 rows (18-22 MB) took Chrome 65-71 s to read, so a
  bundle's first click waited a minute for its row; and a row numbered 100,000, 200,000 or 300,000 was keyed as R
  prints it (`1e+05`), and a click on it found no row.
* `rr_bundle()` writes a vector layer with no `maxzoom` to zoom 14, the page's own deepest for its tiles, where the
  thinning stops too: the map of a layer function (`rr_point()` and the others) stopped with "its tiles' deepest zoom
  is unknown". Past it the map draws zoom 14's tiles larger. `dansk`'s points to zoom 14 are 4,292 tiles and 90 MB;
  `maxzoom = 12` writes 751 and 53 MB.
* Checked: ramb's maps article draws its points layer, coloured by behaviour or by speed with a legend for each and a
  click's popup, in 55 lines of `rb_map_layer()`; `rr_point(colour = c(behaviour, speed), popup = c(vessel_id,
  time_stamp, speed, behaviour))` draws it in five, its points also zoomed out (thinned) where the article's needed
  `minzoom = 10`, served and as a bundle.

# rebelrebel 2026.11.11

* `rr_tiles_dem()` reads a grid where it is, through terra (now in Suggests) and GDAL: a GeoTIFF, a Cloud Optimized
  GeoTIFF or any raster GDAL reads, in any projection; a terra `SpatRaster`; or, as before, a data frame of a grid's
  cells (a lazy table of at most 10 million rows is read into R). Each tile is warped from the grid once: averaged where
  a pixel is wider than a cell, bilinear where it is narrower; a GeoTIFF's overviews read only where a pixel spans eight
  cells or more (the file opened again with GDAL's `OVERVIEW_LEVEL=NONE` for the rest, as terra hands the warp
  utility's own `-ovr` no further). The DuckDB table of cells is gone. Measured on a 50 m grid of 523 million cells (287
  million of them sea), each run a fresh R process: the first tile in under 2 s and 0.3-0.5 GB, where the table of
  cells took 23 s and 7 GB; every tile to zoom 8 in 80-86 s and 3 GB (1.7 GB from a Cloud Optimized GeoTIFF), against
  96 s and 8 GB; and the tiles three times closer to the grid at zoom 8 (0.07 m on average against 0.24 m), as the
  cells were a resampled copy.
* Elevation tiles stop at zoom 8 by default (pixels of about 130 m at 65 degrees north), or at the grid's own limit if
  it is coarser; `maxzoom` goes deeper.
* A fit made in the page: a dem or contour layer on `rr_tiles_dem()`'s tiles fits its colours, contours and shading to
  the view from the tiles in view, served or in a bundle, with no call to R (by `rr_bundle()`'s default rules, which a
  served map's config now carries). `fit = TRUE` asks the same of any elevation tiles; a function stays the server's.
* `whole` on `rr_point()`, `rr_line()`, `rr_segment()`, `rr_polygon()`, `rr_text()` and `rr_path()`: `TRUE` sends a
  layer's rows to the page as one GeoJSON file, read once by MapLibre's worker; by default, as before, as tiles.
* A tile holds the features within its margin (64 of its 4,096 units past each edge): a point just past a tile's edge
  was in neither tile's drawing, and vanished.
* A bundle opened from its folder: a tile it does not hold is empty, not an error (points were drawn twice where a
  tile was missing), and a layer's rows are read once, not at each click.
* A bundle's contours reach the grid's edge: an elevation tile it does not hold, beyond the grid or not written, is
  level at nodata, as a served map's is. maplibre-contour draws no lines in a tile with a neighbour refused, and on a
  small grid most of a view went without (6 line pieces where the served map drew 74).

# rebelrebel 2026.11.10.8

* An id is a list, not a range: in `choose`, a whole number (stored as an integer) is a list, as text is, and a
  fraction, a date or a time a range. Where the data's dictionary (data-dict.tidyverse.org's, in the parquet file's
  metadata) gives a column's type, it decides: `number(id)`, `enum`, `string` or `boolean` a list, `number`,
  `number(quantity)`, `date` or `datetime` a range. A number declared an id is coloured as categories too, and written
  whole (`1131`, not `1131.0`).
* The examples' ids are stored as integers: `trawlsurvey`'s `vid` and `trawlsurveytows`' `id.lgs`, every row and the
  files' metadata kept (`data-raw/integer_ids.R`).
* `rr_map("file.parquet")` reads the file: a path given to the map itself was not read before.
* A dictionary's YAML keeps `n`, `y`, `no`, `yes`, `on` and `off` as written: a column called `n` stopped the reader.

# rebelrebel 2026.11.10.7

* `choose` takes ranges: a number, a date or a time is a slider with two handles, over each of its values where it has
  at most 64 (years, days), else over bins between `pretty()` breaks; text, a factor or a logical stays a list, as
  colour reads them. Ranges and lists are linked by the same counts (a vessel chosen, the days' range spans its
  days), ‹ and › step one value at a time over the values with rows or move the window by its width, and the address
  holds `day=2019-03-01..2019-03-03`. A numeric id is a list once it is text: `as.character(as.integer(id))`.
* A path is split by a range's bins, so a range chosen shows whole runs of it; the view fits the combinations every
  choice leaves, and stays where it is when a range is slid.

# rebelrebel 2026.11.10.6

* Points are thinned in each tile by default (`rr_point(thin = TRUE)`): one a screen pixel, each colour (a number's in
  eight classes), each value a `choose` list picks and each group of a time panel keeping its own, so a tile of
  millions of rows reaches the page as what can be seen of it. From the layer's deepest zoom (`maxzoom`, 14 by
  default) only points that would be drawn on one spot are dropped, so every point that can be told apart can be
  clicked. On a year of national AIS pings (32.8 million), the busiest tile at zoom 6 went from 245 MB and 8.9 s to
  8.7 MB and 0.9 s; at zoom 14, from 51 MB to 3.9 MB. `thin = FALSE` keeps every point; a number of pixels thins more.
* A point's size follows the zoom by default: 2 pixels across until the zoom at which most points lie that far apart,
  then doubling with each zoom in, as a size on the ground does, up to 8. `size = c(1, 12)` sets other bounds, one
  number a size that stays. The outline shows once a point is 3 pixels across.
* `rr_tiles_table(thin = )`, the same for any table of points; a thinned tile's features in the table's order, so its
  bytes are the same every time.

# rebelrebel 2026.11.10.5

* `choose` on a layer function is that layer's own: its lists under its name in the sidebar, over it alone, linked
  as the map's are, and in the page's address under the layer's id and the field (`pings_vid=1131`). A path is split
  by its own `choose` columns too, so a choice shows whole lines. Before, a layer function that started a map gave its
  `choose` to the map; the map's lists are now given to `rr_map()` alone.
* Lists over shapes (`rr_line()`, `rr_polygon()`) take each value's extent from its shapes.

# rebelrebel 2026.11.10.4

* `choose`'s lists are linked: each offers only the values the other lists' choices leave, from the combinations the
  data hold, with their rows counted again; a choice the others no longer leave goes back to all, the last list first
  (a trip gives way to its vessel), and ‹ and › step through the values left. So `choose = c(vid, tid)` needs no
  nesting declared: a vessel chosen leaves its trips.

# rebelrebel 2026.11.10.3

* A click shows the feature's row as a table: the tiles carry the row's number and title only, and the server answers
  `/row/<layer>/<n>` with the columns `popup` names (2-3 ms a click); a bundle writes a layer's rows beside its tiles,
  up to 2 million values. Whole numbers as they are, fractions to six significant digits in the page's language, yes
  and no, a dash where missing; a web address a link, a picture's address the picture, a video's a link.
* `labels` and `codes` in every layer function: a column's name, unit and description, and a coded column's labels,
  by default from the data (a data frame's `label` and `units` attributes, or a parquet file's own dictionary in
  data-dict.tidyverse.org's format).
* `rr_path()` takes a number as its order (a sequence, a distance along a transect) as well as a time.

# rebelrebel 2026.11.10.2

* The layer functions, built with the pipe: `rr_point()`, `rr_path()` (rows joined in time, a line per `group`, one
  column or several), `rr_line()`, `rr_segment()` (a line from each row's start to its end), `rr_polygon()` and
  `rr_text()`, one internal function for all. They take their arguments in one order and words (`colour`, `fill`,
  `size`, `linewidth`, `opacity`, `label`; `palette`, `limits`, `stretch`, `legend`; `popup`, `hover`, `choose`;
  `name`, `info`, `section`, `visible`; `minzoom`, `maxzoom`). A bare name is a column, a string a value.
* `rr_map(data)` starts a map the layer functions add to; `choose` names the columns the reader picks, `sections` the
  sidebar's boxes. A layer function given data first starts a map. Data are a parquet file, folder or glob, a lazy
  DuckDB table, a data frame or an sf object.
* Colours from the data: Okabe-Ito for up to eight values, Paired for up to twelve, Glasbey's 32 beyond, the rest
  grey as "other"; viridis for ordered factors, numbers, dates and times (over the 1st to 99th percentile, or
  `limits`, stretched linearly, on a log scale or in equal shares). `palette` overrides them: a name written loosely,
  colours, colours by value, or a function of n.
* The time panel is generic: `rr_time()` takes its columns (`col`, no default) and its group (`by`) from the call or
  from the map (a path's `group` and `time`); interval tables are read by `start` and `end`, or as named; the page
  names the group's list by its column and counts rows. Points carry their time and group for it.
* The quick look at vessels' pings and tracks is no longer here: it is ramb's, as wrappers over these functions.

# rebelrebel 2026.11.10.1

* The base maps are those that show the sea floor: EMODnet's sea floor (its 2020 base
  layer), the first and the one a map opens on; the same darkened (`emodnet_dark`); EMODnet's lighter atlas (v12); and
  Esri's ocean, which reaches beyond Europe's seas; and none. Carto's Positron, Voyager and Dark Matter (a flat sea)
  and Esri's satellite tiles are no longer offered. Each picture has a Carto style's place and sea names drawn over it
  (Positron's, or Dark Matter's on the dark one), which also give the layers' own labels their fonts: a base map's
  `labels`, `label_layers`, `paint` and `background` in `rr_basemaps()`. The page opens on a picture base map.

# rebelrebel 2026.11.10

* The package starts as ramb's map viewer, moved here unchanged but for its names:
  `rb_map()` is `rr_map()`, `rb_map_layer()` `rr_layer()`, `rb_map_group()` `rr_section()`, `rb_map_serve()` and
  `rb_map_stop()` `rr_serve()` and `rr_stop()`, `rb_map_bundle()` `rr_bundle()`, the tile makers `rr_tiles_table()`,
  `rr_tiles_dem()` and `rr_tiles_mbtiles()`, `rr_palettes()`, `rr_basemaps()`, `rr_notes()`, `rr_notes_add()`,
  `rr_verdicts()` and `rr_time()`; ramb's `rb_read_example()` is `rr_example()`, with five of ramb's datasets
  (`dansk`, `dansk_harbours`, `dansk_relief`, `trawlsurvey`, `trawlsurveytows`). `rb_map_pings()` and
  `rb_map_track()` are internal until `rr_point()` and `rr_path()` take their place.
* The page's libraries are in the package (`inst/engine/vendor`): MapLibre GL JS 5.24.0, maplibre-contour 0.1.1 and
  uPlot 1.6.30, served by `rr_serve()` at `/vendor/` and copied into a bundle's `vendor` folder, so a map draws with no
  network but the base map's.
