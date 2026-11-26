# A page of your own

ogis draws maps; it does not edit data. A page that lets a reader do
something more (mark features, write a verdict of your own, move a
label) is yours, built on the map with two calls:
[`og_script()`](https://einarhjorleifsson.github.io/ogis/reference/og_script.md)
puts your script into the page, and `og_serve(routes = )` gives it
routes of its own on the server. The script is given one object, `og`,
the whole of what it may use of the page (the help of
[`og_script()`](https://einarhjorleifsson.github.io/ogis/reference/og_script.md)
lists it):

| `og.` | gives |
|----|----|
| `map` | MapLibre’s map |
| `layer(id)` | a layer’s MapLibre style ids, source and key |
| `on("click", id, fn)` | a click on a layer’s features, its row as [`row()`](https://rdrr.io/r/base/row.html) |
| `window([from, to])` | the time panel’s window ([`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md)) set, in seconds, or `null` for the whole span; read with no argument |
| `on("window", fn)` | the time panel’s window each time it is drawn, with its group and span |
| `state(id, key, value)` | a feature’s state in MapLibre, which its styles read |
| `setData(id, geojson)` | new data for a layer sent whole |
| `filter(id, key, expr)` | a filter of your own, kept with the page’s choices |
| `panel(title)` | a box in the sidebar, yours to fill |
| `fetch(name, init)` | your route `name` on the server, a path and a query after it if any (`"marks/12?full=1"`); `og.served` is false in a bundle |
| `save(name, text)` | a file handed to the reader |

## A list of marked positions

A click on a position adds its vessel and time to a list in a panel, and
rings it on the map; a button saves the list. On a server, the list goes
to the route `marks`; in a bundle, which has no server (as on this
page), the reader is handed a file.

The ring is MapLibre’s own feature state. Each feature of a layer
function is known by its row’s number, the `feature.id` of a click;
`og.state()` sets a state on it, and the layer’s style reads it as
`feature-state`, given in MapLibre’s own terms. Nothing is sent again,
and the state stays through a change of base map.

``` r

library(ogis)

js <- r"(
  const body = og.panel("Marked");
  const list = document.createElement("ol"), save = document.createElement("button");
  save.textContent = "Save the list";
  body.append(list, save);
  const marks = [];
  og.on("click", "positions", async ({ feature, row }) => {
    og.state("positions", feature.id, { marked: true });
    const r = await row();
    if (!r) return;                       // clicked again meanwhile
    const v = Object.fromEntries(r.map(c => [c.name, c.value]));
    marks.push(v);
    list.append(Object.assign(document.createElement("li"),
                              { textContent: `${v.vid} at ${v.time}` }));
  });
  save.onclick = () => og.served
    ? og.fetch("marks", { method: "POST", body: JSON.stringify(marks) })
    : og.save("marks.csv", "vid,time\n" + marks.map(m => `${m.vid},${m.time}`).join("\n"));
)"

marked <- function(yes, no) {
  list("case", list("boolean", list("feature-state", "marked"), FALSE), yes, no)
}
m <- og_example("trawlsurvey") |>
  og_point(colour = behaviour, popup = c(vid, time), id = "positions",
           name = "Positions",
           "circle-stroke-width" = marked(3, 0),
           "circle-stroke-color" = marked("#000000", "#ffffff")) |>
  og_script(js)
m
```

Click a few positions, then *Save the list*.

## Its route on the server

Served from R, the route writes what the page sends to a file, a row a
mark, never rewriting it. A route’s function is given the request
(`method`, `path`, `query`, `body`, a JSON body read into R) and returns
what goes back: a list as JSON. Keep it fast: the server answers one
request at a time.

``` r

file <- "marks.csv"
og_serve(m, routes = list(marks = function(req) {
  write.table(req$body, file, sep = ",", row.names = FALSE,
              col.names = !file.exists(file), append = file.exists(file))
  list(saved = nrow(req$body))
}))
```

In a script run by `Rscript`, give `og_serve(..., wait = TRUE)`: it
keeps serving until stopped (Ctrl-C). In RStudio it answers while the
console is idle. The page’s writes are answered only for a page opened
from this computer.

## The time panel’s window

A map with a time panel
([`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md),
[`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md))
shows a window of a group’s span: the chart’s time axis, and on the map
the rows in it. `og.window()` reads it and sets it, as a drag across the
chart does, in seconds since 1970 on the panel’s clock;
`og.on("window", fn)` hears each window drawn, the reader’s or the
script’s. Here two buttons step through a vessel’s track a day at a
time, and the panel’s box says which day is shown:

``` r

js_days <- r"(
  const body = og.panel("Day by day");
  const said = document.createElement("div");
  const back = document.createElement("button"), on = document.createElement("button");
  back.textContent = "‹ day"; on.textContent = "day ›";
  body.append(said, back, on);
  const day = 86400, iso = s => new Date(s * 1000).toISOString().slice(0, 16).replace("T", " ");
  og.on("window", ({ window: w, group }) => { said.textContent = `${group}: ${iso(w[0])} to ${iso(w[1])}`; });
  // a window of one day steps a day either way; any other first shows the day it starts in
  const step = k => {
    const w = og.window();
    if (!w) return;
    const d0 = Math.floor(w[0] / day) * day, one = Math.abs(w[0] - d0) < 1 && Math.abs(w[1] - w[0] - day) < 1;
    const a = d0 + (one ? k : 0) * day;
    og.window([a, a + day]);
  };
  back.onclick = () => step(-1);
  on.onclick = () => step(1);
)"
og_example("dansk") |>
  dplyr::filter(vessel_id == "EX_12") |>
  dplyr::collect() |>
  dplyr::slice(seq(1, dplyr::n(), by = 3)) |>
  og_tracks(effort = FALSE, title = "Day by day") |>
  og_script(js_days)
```

The map’s pings show the window’s rows alone, as the chart does
(`og_time(follow = )`), coloured by speed, black the slowest; *On top*
under *Pings* draws the slow or the fast ones over the others.
