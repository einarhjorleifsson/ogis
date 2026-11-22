# script.R — a page's own script on a map: the seam a page built on ogis uses, and nothing else of the page.

#' A page's own script on a map
#'
#' `og_script()` puts a script of your own (and its styles) into the map's page, for what the layer functions do not
#' do: a panel of your own, a click that does something else, data sent again as the reader works. It runs once the
#' map's layers are added, given one object, `og`, the whole of what it may use of the page (anything else of the
#' page, its elements and functions, may change from one version to the next):
#'
#' * `og.map`: MapLibre's map.
#' * `og.layer(id)`: a layer's MapLibre style ids, source and `key`, by its id ([og_point()]'s `id` and the others'), or
#'   `null`. A layer function's features are known by their row's number (`key` `"og_row"`, MapLibre's feature id: a
#'   click's `feature.id`); a layer of your own by its [og_layer()]'s `key`.
#' * `og.state(id, key, value)`: a feature's state in MapLibre (`setFeatureState()`), by its layer and key, which its
#'   styles read as `list("feature-state", "<name>")` (given to a layer function in MapLibre's own terms, `...`): a
#'   selection drawn with no data sent again. `og.state(id, key)` reads it, `og.state(id, key, null)` clears it; it is
#'   kept through a change of base map.
#' * `og.on("click", id, fn)`: a click on the layer's features is the script's: `fn({feature, lngLat, point, row})`,
#'   where `row()` is a promise of the clicked row's columns (those its `popup` names, each `name`, `label`, `unit`,
#'   `value`), or `null` when the reader has clicked again meanwhile; the layer's own popup is not shown.
#' * `og.window()`: the time panel's window ([og_time()]), `[from, to]` in seconds since 1970 on the panel's clock (as
#'   the data hold the times, in no zone), or `null` where there is no panel, while a series loads, or for a span of no
#'   rows. `og.window([from, to])` sets it, as a drag across the chart does, and `og.window(null)` shows the group's
#'   whole span. Asked for before the panel's series has loaded, the window is set once it has, in place of the
#'   address's.
#' * `og.on("window", fn)`: `fn({window, group, span})` each time the time panel's window is drawn (a drag, a double
#'   click, a lane, another group or span, `og.window()`), with the group and the span shown; called at once with the
#'   window shown, if there is one.
#' * `og.setData(id, geojson)`: a layer sent whole (`whole = TRUE`) given new data, at most once a frame.
#' * `og.filter(id, key, expr)`: a filter of the script's on a layer (a MapLibre expression), kept with the page's own
#'   choices; `null` removes it.
#' * `og.panel(title)`: a box in the sidebar, the script's to fill (its body element).
#' * `og.fetch(name, init)`: the map's own route `name` ([og_serve()]'s `routes`), as `fetch()`; after the name, a
#'   path and a query as written, for the route's `path` and `query` (`"marks/12?full=1"`; a value made safe with
#'   `encodeURIComponent()`, or the query with `URLSearchParams`). `og.served` is `false` in a bundle, which has no
#'   server.
#' * `og.save(name, text)`: a file handed to the reader to save, which a page in a bundle keeps in place of a server.
#'
#' A map with a script is written into a bundle ([og_bundle()]) with it, where it runs with no R: `og.fetch()` is
#' refused there and `og.save()` keeps what the reader made.
#'
#' @param map An [og_map()].
#' @param js The script: the path of a `.js` file, or the script itself as text.
#' @param css Its styles, optionally: the path of a `.css` file, or the styles as text.
#' @return The map, with the script.
#' @seealso [og_serve()] for the map's own routes.
#' @export
#' @examples
#' \donttest{
#' # a click on a position lists its vessel and time in a panel of the script's own
#' js <- r"(
#'   const body = og.panel("Clicked");
#'   og.on("click", "positions", async ({ row }) => {
#'     const r = await row();
#'     if (r) body.append(Object.assign(document.createElement("div"),
#'                        { textContent: r.map(c => c.value).join(" · ") }));
#'   });
#' )"
#' m <- og_example("trawlsurvey") |>
#'   og_point(id = "positions", popup = c(vid, time)) |>
#'   og_script(js)
#' }
og_script <- function(map, js, css = NULL) {
  if (!inherits(map, "og_map")) {
    stop("`map` is an og_map().", call. = FALSE)
  }
  code <- function(x, ext, what) {
    if (is.null(x)) return(NULL)
    if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(trimws(x))) {
      stop(sprintf("`%s` is the path of a %s file, or the %s itself as text.", what, ext, what), call. = FALSE)
    }
    if (grepl(sprintf("[.]%s$", ext), x, ignore.case = TRUE) && !grepl("\n", x, fixed = TRUE)) {
      if (!file.exists(x)) stop(sprintf("No such file: %s.", x), call. = FALSE)
      x <- paste(readLines(x, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    }
    enc2utf8(x)
  }
  map$config$scripts <- c(map$config$scripts, list(Filter(Negate(is.null), list(js = code(js, "js", "js"),
                                                                                    css = code(css, "css", "css")))))
  # a map built by the layer functions keeps its state for the next layer: the script must survive it
  q <- attr(map, "quick")
  if (!is.null(q)) {
    q$scripts <- map$config$scripts
    attr(map, "quick") <- q
  }
  map
}
