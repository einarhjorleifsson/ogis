# Vessel tracks: the track, a time panel of speed, trips, and the effort by cell

`og_tracks()` draws vessel tracks, a row a ping, for a look at what a
track's processing made of them: a time panel under the map with a
vessel's speed over time and lanes of what it was doing and of its trips
(a vessel chosen there, then one of its trips), the map showing the path
and pings of the window shown on the chart, the pings coloured by speed
in Inferno, black the slowest, or by what the vessel was doing (in the
lane's colours), and slow or fast pings on top (*On top*); and the
fishing effort by cell, summed from the fishing pings' hours, showing
the chosen vessel's, its gear's or the fleet's
([`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md)'s
`follow`).

## Usage

``` r
og_tracks(
  map = NULL,
  pings = NULL,
  vessel = NULL,
  time = NULL,
  lon = NULL,
  lat = NULL,
  speed = NULL,
  activity = NULL,
  trip = NULL,
  gear = NULL,
  hours = NULL,
  lanes = NULL,
  marks = NULL,
  compare = NULL,
  fishing = NULL,
  effort = TRUE,
  cell = 0.01,
  time_label = "UTC",
  title = "Tracks",
  ...
)
```

## Arguments

- map:

  A map the pipe makes
  ([`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)),
  or the pings, which start one.

- pings:

  The pings: a data frame, a lazy DuckDB table, or a parquet file's
  path; given here with no map, they start one, as in the map's place.

- vessel, time, lon, lat, speed, activity, trip, gear, hours:

  The columns, as strings, where their names are not found: the vessel,
  the time, the position, the speed (more than one: the first shown, the
  others ticked on in the panel; the first the pings' colour), what the
  vessel was doing (a lane, and the pings' other colour), its trip
  (chosen in the panel, a trip at a time), its gear, and the hours each
  ping stands for (the effort's).

- lanes:

  More lanes under the panel's chart, columns as strings
  (`c(observed = "ACTIVITY_L1")`): another method's trips, an observer's
  activity, ...

- marks:

  Columns that mark pings, as
  [`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md)'s
  `marks`.

- compare:

  Two columns to hold against each other, as strings, named for their
  sources (`c(ramb = "trip_id", other = "TRIP_ID")`), or a list of such
  pairs: two methods' trips, an inferred activity against an observer's.
  Each is a lane, and the panel marks, each a row of its own, the pings
  that one has and the other has not (in a trip by one method alone),
  and, where the two share their values (`"fishing"` in both), the pings
  they give differently.

- fishing:

  The values of `activity` that are fishing, for the effort: by default
  those beginning "fish" (any case), or `TRUE` in a logical column.

- effort:

  The effort by cell: `TRUE`, summed from the fishing pings' `hours` by
  vessel, gear and year at `cell` degrees; `FALSE`, none; or a table of
  cells for
  [`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md).

- cell:

  The cells' side in degrees, when the effort is summed here.

- time_label:

  The clock the times are on, shown beside them in the panel ("UTC" by
  default; "as written" for a file whose zone is not known).

- title:

  The page's title.

- ...:

  More for
  [`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md):
  `palette`, `sizes`, `follow`, ...

## Value

The map.

## Details

The columns are found by their names: ramb's (`vid`, `time`, `lon`,
`lat`, `speed`, `voyage_key` or `trip_id`, `gear`, `hours`, and
`behaviour` or `activity`) or upper-case ones (`VESSEL_ID`, `DATE_TIME`,
`LONGITUDE`, `LATITUDE`, `SPEED`, `TRIP_ID`, `ACTIVITY`, `GEAR`), or
given.

## See also

[`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md),
[`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md);
ramb, which makes trips, fishing and hours of a track.

## Examples

``` r
# \donttest{
# the Danish small-scale vessels' tracks, as they come: behaviour, gear, no trips or hours
og_example("dansk") |>
  dplyr::filter(vessel_id %in% c("EX_1", "EX_12")) |>
  og_tracks(effort = FALSE)
#> <og_map> Tracks
#>   layers: pings (geojson)
#>   time panel: speed over time, 2 groups; lanes: behaviour
# }
```
