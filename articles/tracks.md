# Vessel tracks

[`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
draws vessel tracks, a row a ping, for a quick look at what a step of
their processing made of them: a time panel of speed under the map (a
vessel chosen there, then one of its trips), lanes of what the vessel
was doing and of its trips, the chosen span’s path and pings on the map,
and the fishing effort by cell, which follows the vessel chosen. The
processing is [ramb](https://github.com/einarhjorleifsson/ramb)’s:
flags, harbours, trips, fishing and effort. ogis only draws, so a step’s
output, ramb’s or another workflow’s, can be looked at as soon as it is
made.

``` r

library(ogis)
library(dplyr)
```

## Trips and effort

Two Danish small-scale vessels, a gillnetter and a trawler, a ping a
minute: ramb flags the pings that cannot be right, finds those in a
harbour, cuts the track into trips there (the ICES workshop’s rule,
`"jepol"`), and gives each ping the hours it stands for.

``` r

h <- ramb::rb_read_example("dansk_harbours") |> collect()
harbours <- sf::st_sf(
  port_id = h$SI_HARB,
  geometry = sf::st_as_sfc(structure(h$geometry, class = "WKB"), crs = 4326)
)
pings <- ramb::rb_read_example("dansk") |>
  collect() |>
  filter(vessel_id %in% c("EX_6", "EX_12")) |>
  rename(vid = vessel_id, time = time_stamp) |>
  arrange(vid, time) |>
  group_by(vid) |>
  slice(seq(1, n(), by = 6)) |>
  ungroup() |>
  ramb::rb_flag_ping_invalid() |>
  ramb::rb_flag_ping_impossible(method = "clean") |>
  filter(is.na(ping_flag)) |>
  ramb::rb_flag_ping_port(harbours)
pings <- pings |>
  ramb::rb_add_voyages(ramb::rb_create_voyages(pings, method = "jepol")) |>
  ramb::rb_add_effort()
og_tracks(pings, title = "Danish vessels")
```

What to look at:

- **The trips.** Under *Time*, choose a vessel, then a trip: the map and
  the panel show that trip alone. The lane *trip* shows where each trip
  begins and ends against the speed: a trip should leave a harbour and
  come back to one. A trip is known by its vessel and ramb’s number for
  it, which starts again each year.
- **What the vessel was doing.** The lane *behaviour* and the pings’
  colours: fishing at slow, steady speed, steaming fast between.
- **The effort.** *Show* follows the panel’s vessel: its own effort, its
  gear’s, or the whole fleet’s. *Cells* sets their size, live: about a
  pixel at each zoom, or 0.01 to 0.5 degrees at every zoom, a c-square
  (0.05) or an ICES rectangle (1 by 0.5), so the picture’s dependence on
  the grid is seen. *Vessels, at least* hides the cells of fewer
  vessels, as a confidentiality rule would; a click on a cell shows its
  number.

## Flags against the truth

A flagging step is checked against faults known to be there. ramb’s
`dansk_planted` is a vessel’s track with faults planted in it (a ping
moved, its time shifted, …). The panel marks both, the planted faults
and the pings ramb flags, each a row of ticks along the chart’s top and
a ring on the map:

``` r

planted <- ramb::rb_read_example("dansk_planted") |>
  collect() |>
  filter(vid == first(vid)) |>
  arrange(time) |>
  ramb::rb_flag_ping_impossible(method = "clean")
count(planted, planted = !is.na(fault), flagged = !is.na(ping_flag))
#> # A tibble: 4 × 3
#>   planted flagged     n
#>   <lgl>   <lgl>   <int>
#> 1 FALSE   FALSE    3746
#> 2 FALSE   TRUE       82
#> 3 TRUE    FALSE      54
#> 4 TRUE    TRUE       44
og_tracks(planted, activity = "fishing",
          marks = c(planted = "fault", flagged = "ping_flag"),
          effort = FALSE, title = "Planted faults")
```

The map opens on the whole track, a line across the Baltic among it: a
ping moved a thousand kilometres east, as one of the planted faults
does. A planted fault with no flag is one the step missed; a flag with
no planted fault, a good ping it took for a bad one. Drag across the
chart where they cluster, to see them on the map.

## What an observer saw, against a rule

An observer’s labels, ping by ping, against what a rule infers from the
track: here Malagasy small-scale gillnet trips (ramb’s
`ird_mg_gillnet`). The observer’s labels say when the net was set or
hauled; a speed rule says fishing where the boat is slow. `compare`
holds the two against each other: each is a lane, and the panel marks
the pings they give differently, a row of ticks along the chart’s top.
The observer’s own labels are a lane too, and show their state (the same
activity spelled three ways).

``` r

gillnet <- ramb::rb_read_example("ird_mg_gillnet") |>
  collect() |>
  mutate(
    rule = if_else(speed < 1.5, "fishing", "other"),
    observer = case_when(
      label %in% c("Pose_filet", "Remonter_filet",
                   "Remonter_filet_collecte") ~ "fishing",
      !is.na(label) ~ "other"
    )
  )
og_tracks(gillnet, activity = "rule", trip = "trip", lanes = c(label = "label"),
          compare = c(rule = "rule", observer = "observer"),
          effort = FALSE, title = "Gillnet trips")
```

Choose a trip and drag across a cluster of marks: the rule calls fishing
where the boat drifts, or misses the net’s setting where the boat moves
faster.

## Another workflow’s output

[`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
finds its columns by name: ramb’s, or those of the EM4SSF project’s
track format (D2.1: `VESSEL_ID`, `DATE_TIME`, `LONGITUDE`, `LATITUDE`,
`SPEED`, `TRIP_ID`, `ACTIVITY`, `GEAR`), or those given. A file written
by any step of such a workflow is looked at in one line, another
method’s trips held against it:

``` r

og_tracks("trips_step01.parquet", compare = c(ramb = "trip_key", EM4SSF = "TRIP_ID"), effort = FALSE)
```

A set and its haul, drawn as a segment with a time
([`og_segment()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)),
follow the panel as the pings do: a static gear’s soak is checked on the
map beside the track that made it.
