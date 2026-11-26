# A page's own script on a map

`og_script()` puts a script of your own (and its styles) into the map's
page, for what the layer functions do not do: a panel of your own, a
click that does something else, data sent again as the reader works. It
runs once the map's layers are added, given one object, `og`, the whole
of what it may use of the page (anything else of the page, its elements
and functions, may change from one version to the next):

## Usage

``` r
og_script(map, js, css = NULL)
```

## Arguments

- map:

  An
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md).

- js:

  The script: the path of a `.js` file, or the script itself as text.

- css:

  Its styles, optionally: the path of a `.css` file, or the styles as
  text.

## Value

The map, with the script.

## Details

- `og.map`: MapLibre's map.

- `og.layer(id)`: a layer's MapLibre style ids, source and `key`, by its
  id
  ([`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md)'s
  `id` and the others'), or `null`. A layer function's features are
  known by their row's number (`key` `"og_row"`, MapLibre's feature id:
  a click's `feature.id`); a layer of your own by its
  [`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)'s
  `key`.

- `og.state(id, key, value)`: a feature's state in MapLibre
  (`setFeatureState()`), by its layer and key, which its styles read as
  `list("feature-state", "<name>")` (given to a layer function in
  MapLibre's own terms, `...`): a selection drawn with no data sent
  again. `og.state(id, key)` reads it, `og.state(id, key, null)` clears
  it; it is kept through a change of base map.

- `og.on("click", id, fn)`: a click on the layer's features is the
  script's: `fn({feature, lngLat, point, row})`, where
  [`row()`](https://rdrr.io/r/base/row.html) is a promise of the clicked
  row's columns (those its `popup` names, each `name`, `label`, `unit`,
  `value`), or `null` when the reader has clicked again meanwhile; the
  layer's own popup is not shown.

- `og.window()`: the time panel's window
  ([`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md)),
  `[from, to]` in seconds since 1970 on the panel's clock (as the data
  hold the times, in no zone), or `null` where there is no panel, while
  a series loads, or for a span of no rows. `og.window([from, to])` sets
  it, as a drag across the chart does, and `og.window(null)` shows the
  group's whole span. Asked for before the panel's series has loaded,
  the window is set once it has, in place of the address's.

- `og.on("window", fn)`: `fn({window, group, span})` each time the time
  panel's window is drawn (a drag, a double click, a lane, another group
  or span, `og.window()`), with the group and the span shown; called at
  once with the window shown, if there is one.

- `og.setData(id, geojson)`: a layer sent whole (`whole = TRUE`) given
  new data, at most once a frame.

- `og.filter(id, key, expr)`: a filter of the script's on a layer (a
  MapLibre expression), kept with the page's own choices; `null` removes
  it.

- `og.panel(title)`: a box in the sidebar, the script's to fill (its
  body element).

- `og.fetch(name, init)`: the map's own route `name`
  ([`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md)'s
  `routes`), as `fetch()`; after the name, a path and a query as
  written, for the route's `path` and `query` (`"marks/12?full=1"`; a
  value made safe with `encodeURIComponent()`, or the query with
  `URLSearchParams`). `og.served` is `false` in a bundle, which has no
  server.

- `og.save(name, text)`: a file handed to the reader to save, which a
  page in a bundle keeps in place of a server.

A map with a script is written into a bundle
([`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md))
with it, where it runs with no R: `og.fetch()` is refused there and
`og.save()` keeps what the reader made.

## See also

[`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md)
for the map's own routes.

## Examples

``` r
# \donttest{
# a click on a position lists its vessel and time in a panel of the script's own
js <- r"(
  const body = og.panel("Clicked");
  og.on("click", "positions", async ({ row }) => {
    const r = await row();
    if (r) body.append(Object.assign(document.createElement("div"),
                       { textContent: r.map(c => c.value).join(" · ") }));
  });
)"
m <- og_example("trawlsurvey") |>
  og_point(id = "positions", popup = c(vid, time)) |>
  og_script(js)
# }
```
