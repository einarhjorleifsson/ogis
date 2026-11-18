# Serve a map

Starts a server for an
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
in the background of this R session, on `host` only (`127.0.0.1`: this
computer), and opens the page. It answers while the console is idle: a
map waits while R runs something else. `og_stop()` stops it. A grid's
`meta` and a geojson layer's `data` are read once, when the server
starts.

## Usage

``` r
og_serve(
  map,
  port = NULL,
  host = "127.0.0.1",
  open = interactive(),
  query = NULL,
  notes = NULL,
  verdicts = NULL,
  routes = NULL,
  wait = FALSE
)

og_stop(port = NULL)
```

## Arguments

- map:

  An
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md).

- port:

  Where the server listens: a port, or `NULL` (the default) for 8790 or,
  when another program holds it, the next free port to 8889. A map
  served with no port replaces the last one served so, as a map served
  on a port replaces the one there; the address returned says where it
  is.

- host:

  Where the server listens: `127.0.0.1`, this computer only.

- open:

  Whether to open the page: RStudio's Viewer when there is one, else a
  browser.

- query:

  Settings for the first view, in the page's address
  (`list(lang = "is", palette = "deep")`).

- notes:

  Opt-in, notes pinned on the map: the path of a `.geojson` file (in a
  folder that exists) where the server keeps them, made at the first
  note; `NULL`, none. The page then has a Notes group: "Add a note", a
  click on the map, a text, and the note is written to the file with the
  features under it; a reply joins a note's thread.
  [`og_notes()`](https://einarhjorleifsson.github.io/ogis/reference/og_notes.md)
  reads them in R and
  [`og_notes_add()`](https://einarhjorleifsson.github.io/ogis/reference/og_notes.md)
  answers. They are answered only for a page opened from this computer
  (as `localhost`, `127.0.0.1` or `host`), and never in a bundle.

- verdicts:

  Opt-in, the readers' verdicts on features: the path of a `.csv` file
  (in a folder that exists) where the server keeps them, made at the
  first verdict; `NULL`, none. A layer whose popup has a `verdict`
  ([`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md))
  then shows a button for each option in a feature's popup. Each answer
  is a row added to the file (when, the layer, the feature's value of
  the verdict's `field`, the option, the reader's line, the feature's
  title and place); a later one for the feature replaces it, and an
  empty answer withdraws it.
  [`og_verdicts()`](https://einarhjorleifsson.github.io/ogis/reference/og_verdicts.md)
  reads them. As the notes, answered only for a page opened from this
  computer, and never in a bundle.

- routes:

  Opt-in, the map's own routes, for a page's own script
  ([`og_script()`](https://einarhjorleifsson.github.io/ogis/reference/og_script.md)):
  a named list of functions, each answering `/x/<name>` (and
  `/x/<name>/...`) from the page by `og.fetch(name, init)`, the name
  followed by a path and a query if any (`og.fetch("marks/12?full=1")`).
  A function is given one request, a list of `method` (`"GET"`,
  `"POST"`, ...), `path` (what follows its name, `"/12"`), `query` (the
  address's parameters, a named list, `list(full = "1")`) and `body` (a
  JSON body read, else its text, else `NULL`); it returns a list or a
  data frame, sent as JSON, a string, sent as text, or `NULL`, not
  found; an error is sent as its message. As the notes, answered only
  for a page opened from this computer. Keep each fast: the server
  answers one request at a time, and a slow route holds the tiles behind
  it (read a file once, and again only when it changes).

- wait:

  Whether to keep serving until stopped (Ctrl-C, Esc in RStudio): `TRUE`
  in a script run by `Rscript`, whose map would otherwise go when the
  script ends. By default `FALSE`: the server answers while R is idle
  (in RStudio, while the console waits), and the call returns, so a
  script, a test or a document goes on.

## Value

The page's address, invisibly.

## Examples

``` r
# Opens a map in RStudio's Viewer (or a browser) when run by hand, e.g. by example(og_serve)
if (interactive()) {
  harbours <- og_layer(
    "harbours", "vector", label = "Harbours",
    tiles = og_tiles_table(og_example("dansk_harbours"), properties = "SI_HARB"),
    style = list(list(id = "harbours-fill", type = "fill", "source-layer" = "features",
                      paint = list("fill-color" = "#d9822b"))),
    popup = list(click = "harbours-fill", title = "SI_HARB")
  )
  m <- og_map(og_section("ref", "Reference", list(harbours)),
              title = "Danish harbours", view = list(center = c(10.5, 56), zoom = 7))
  og_serve(m)
  # again, opening on the ocean base map (it replaces the first):
  # og_serve(m, query = list(base = "ocean"))
  # with notes pinned on the map, kept in a file:
  # og_serve(m, notes = "harbour_notes.geojson"); og_notes("harbour_notes.geojson")
  # og_stop() # when done
}
```
