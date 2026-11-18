# script.R — a page's own script on a map: the seam a page built on rebelrebel uses, and nothing else of the page.

#' A page's own script on a map
#'
#' `rr_script()` puts a script of your own (and its styles) into the map's page, for what the layer functions do not
#' do: a panel of your own, a click that does something else, data sent again as the reader works. It runs once the
#' map's layers are added, given one object, `rr`, the whole of what it may use of the page (anything else of the
#' page, its elements and functions, may change from one version to the next):
#'
#' * `rr.map`: MapLibre's map.
#' * `rr.layer(id)`: a layer's MapLibre style ids and source, by its id ([rr_point()]'s `id` and the others'), or `null`.
#' * `rr.on("click", id, fn)`: a click on the layer's features is the script's: `fn({feature, lngLat, point, row})`,
#'   where `row()` is a promise of the clicked row's columns (those its `popup` names, each `name`, `label`, `unit`,
#'   `value`), or `null` when the reader has clicked again meanwhile; the layer's own popup is not shown.
#' * `rr.setData(id, geojson)`: a layer sent whole (`whole = TRUE`) given new data, at most once a frame.
#' * `rr.filter(id, key, expr)`: a filter of the script's on a layer (a MapLibre expression), kept with the page's own
#'   choices; `null` removes it.
#' * `rr.panel(title)`: a box in the sidebar, the script's to fill (its body element).
#' * `rr.fetch(name, init)`: the map's own route `name` ([rr_serve()]'s `routes`), as `fetch()`; after the name, a
#'   path and a query as written, for the route's `path` and `query` (`"marks/12?full=1"`; a value made safe with
#'   `encodeURIComponent()`, or the query with `URLSearchParams`). `rr.served` is `false` in a bundle, which has no
#'   server.
#' * `rr.save(name, text)`: a file handed to the reader to save, which a page in a bundle keeps in place of a server.
#'
#' A map with a script is written into a bundle ([rr_bundle()]) with it, where it runs with no R: `rr.fetch()` is
#' refused there and `rr.save()` keeps what the reader made.
#'
#' @param map An [rr_map()].
#' @param js The script: the path of a `.js` file, or the script itself as text.
#' @param css Its styles, optionally: the path of a `.css` file, or the styles as text.
#' @return The map, with the script.
#' @seealso [rr_serve()] for the map's own routes.
#' @export
#' @examples
#' \donttest{
#' # a click on a position lists its vessel and time in a panel of the script's own
#' js <- r"(
#'   const body = rr.panel("Clicked");
#'   rr.on("click", "positions", async ({ row }) => {
#'     const r = await row();
#'     if (r) body.append(Object.assign(document.createElement("div"),
#'                        { textContent: r.map(c => c.value).join(" · ") }));
#'   });
#' )"
#' m <- rr_example("trawlsurvey") |>
#'   rr_point(id = "positions", popup = c(vid, time)) |>
#'   rr_script(js)
#' }
rr_script <- function(map, js, css = NULL) {
  if (!inherits(map, "rr_map")) {
    stop("`map` is an rr_map().", call. = FALSE)
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
