# A time panel under the map: one group's rows over time, linked to the map

`og_time()` adds a panel under a map, or starts a map with it, that
shows one group's rows over time (a vessel's, a float's, an animal's:
the values of `by`):

- a column or several as lines, the first shown and the others ticked on
  in the panel;

- marks where a column says so (a flag), on the chart and on the map;

- lanes of intervals under the chart (visits, legs, phases), a click on
  one setting the window to it.

## Usage

``` r
og_time(
  x,
  col,
  marks = NULL,
  lanes = NULL,
  lane_palette = NULL,
  span = NULL,
  max_gap_s = NULL,
  span_max = 3e+06,
  time_label = "UTC",
  thin = FALSE,
  data = NULL,
  lon = NULL,
  lat = NULL,
  time = NULL,
  by = NULL,
  title = "Track",
  port = NULL
)
```

## Arguments

- x:

  Rows: a data frame or lazy DuckDB table with `lon` and `lat` (WGS 84),
  or an sf object of points; or a map, whose rows, time and group (from
  [`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md))
  the panel takes.

- col:

  The numeric columns drawn over time, a name, a string or
  [`c()`](https://rdrr.io/r/base/c.html) of them; the first shown.

- marks:

  Columns that mark rows, as `col`: a logical column marks its `TRUE`
  rows, any other its values that are not missing (such as a flag's
  label). Each column is a row of ticks along the chart's top and a ring
  on the map in a colour of its own, named in the sidebar;
  `c(truth = "wrong", clean = "flag")` names them.

- lanes:

  Intervals drawn as lanes under the chart: a named list (the names are
  the lanes' labels), each

  - a column of the rows, as a string: its runs of one value (a phase, a
    leg), missing values left out and a run broken by a silence longer
    than `max_gap_s`;

  - a table of intervals with the group's column (`by`), and its start
    and end in `start` and `end`;

  - or `list(data = , start = , end = , label = )`, naming the columns,
    `label` a column that names each interval.

- lane_palette:

  The lanes' colours, a value's the same in every span: by default
  Brewer's Paired, its twelve colours given to each lane's values in
  their order (numbers as numbers), over and over. Colours named by
  value, `c(Fishing = "#ff7f00")`, give those values theirs in every
  lane, the others keeping their default; a palette's name or colours,
  as for
  [`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)'s
  `palette`, are used in place of Paired. A lane of a column that a
  layer of the map colours by
  ([`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  [`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md);
  the first such, added before the panel or after it) takes that layer's
  colours, so a value is one colour on the map and in the lane; colours
  named here win. A label is written in white on a dark colour, in black
  on a light one. An interval with no label is grey.

- span:

  Units the page holds one at a time, chosen besides the whole series: a
  column of the rows that names them, as a string (a leg, a deployment:
  `"leg"`, or `c(leg = "leg_id")` to name the list), one span per value
  from its first row to its last; or a table of intervals, or
  `list(data = , start = , end = , label = )`, as for `lanes`, named as
  a column is with `list(legs = <table>)`. A span holds every row of its
  group from its start to its end, those whose value is missing too.
  Spans that overlap are reported: a state that comes and goes, such as
  behaviour, belongs in `lanes`. `NULL`, the default, offers the whole
  series alone.

- max_gap_s:

  A silence between two rows longer than this many seconds breaks the
  panel's line, on the chart and on the map, and a lane's run of one
  value. By default a path's
  ([`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md)'s
  `max_gap_s`) when the map has one already, else `Inf`: nothing broken,
  so no gap is hidden.

- span_max:

  The most rows the page holds at once: a group with more is offered by
  its spans, else by month. The browser holds far more than the default
  is likely to meet: a series of 2.2 million rows loaded in about 8
  seconds, most of it the transfer.

- time_label:

  The clock the times are on, shown beside them.

- thin:

  `FALSE`, the default: the map draws every row of the window, its path
  through each and a point at each. A number thins a window of more rows
  than that, for display only: every k-th row is drawn, so about that
  many, a marked row always, a path's ends at a silence kept; a narrower
  window, as the reader narrows it on the chart, is thinned less, and
  one of that many rows or fewer not at all. The panel's readout says "1
  in k drawn on the map" while it thins. `TRUE` is 5,000. The chart is
  not thinned.

- data:

  Rows for this panel, in place of the map's.

- lon, lat, time:

  The position and time columns: by default the map's, else `"lon"`,
  `"lat"` and `"time"`.

- by:

  The column whose values each have a series, a name or a string: by
  default the map's (a path's `group`), else one series of all the rows.

- title, port:

  The page's title, and where the map is served when printed: set by the
  call that starts it.

## Value

An
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
with the time panel.

## Details

The panel and the map are linked. A drag across the chart sets the time
window, and a double click goes back to the whole span. The map draws
the window's path and points, and fits to them. A hover on the chart
marks that row on the map, and a click on a point of the window marks
its time on the chart. The group, the span and the window go into the
page's address.

The page holds one group's span at a time: by default its whole series;
with `span`, also each of its intervals, chosen under *Span*. A group
with more than `span_max` rows is offered by its spans only, or by month
where there are none. The map's other layers that carry the group and a
time
([`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md),
[`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md))
show only the chosen group and span; a path's line that runs over a
span's start or end is shown whole.

Every row is drawn. The window's path on the map joins every row of the
window, and each row is a point, unless `thin` asks for fewer. The chart
is given every row of the span; where more rows than pixels share the
time axis, its line runs, in each column of pixels, from the least of
their values to the most, so no value is left out, and a drag that
narrows the window spreads the rows out again until each has its own.

Times are shown as the data hold them, in no time zone, labelled by
`time_label`.

## See also

[`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md)
and
[`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
the layers it pairs with;
[`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md),
which writes the panel's series beside the page.

## Examples

``` r
# \donttest{
d <- dplyr::filter(dplyr::collect(og_example("dansk")), vessel_id %in% c("EX_1", "EX_12"))
m <- og_map(d) |>
  og_path(group = vessel_id, time = time_stamp) |>
  og_time(speed, lanes = list(behaviour = "behaviour"))
format(m)
#> [1] "<og_map> Map"                                             
#> [2] "  layers: paths (geojson)"                                
#> [3] "  time panel: speed over time, 2 groups; lanes: behaviour"
# m  # printed at the console, the map opens with the panel under it
# }
```
