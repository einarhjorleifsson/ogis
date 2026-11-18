# serve.R — the server: a map served on 127.0.0.1 by httpuv, with fixed routes.
# Moved from ramb's R/map.R on 2026-11-10.

#' Serve a map
#'
#' Starts a server for an [rr_map()] in the background of this R session, on `host` only (`127.0.0.1`: this computer),
#' and opens the page. It answers while the console is idle: a map waits while R runs something else.
#' `rr_stop()` stops it. A grid's `meta` and a geojson layer's `data` are read once, when the server starts.
#'
#' @param map An [rr_map()].
#' @param port Where the server listens: a port, or `NULL` (the default) for 8790 or, when another program holds it,
#'   the next free port to 8889. A map served with no port replaces the last one served so, as a map served on a
#'   port replaces the one there; the address returned says where it is.
#' @param host Where the server listens: `127.0.0.1`, this computer only.
#' @param open Whether to open the page: RStudio's Viewer when there is one, else a browser.
#' @param query Settings for the first view, in the page's address (`list(lang = "is", palette = "deep")`).
#' @param notes Opt-in, notes pinned on the map: the path of a `.geojson` file (in a folder that exists) where the
#'   server keeps them, made at the first note; `NULL`, none. The page then has a Notes group: "Add a note", a click
#'   on the map, a text, and the note is written to the file with the features under it; a reply joins a note's
#'   thread. [rr_notes()] reads them in R and [rr_notes_add()] answers. They are answered only for a page
#'   opened from this computer (as `localhost`, `127.0.0.1` or `host`), and never in a bundle.
#' @param verdicts Opt-in, the readers' verdicts on features: the path of a `.csv` file (in a folder that exists) where
#'   the server keeps them, made at the first verdict; `NULL`, none. A layer whose popup has a `verdict`
#'   ([rr_layer()]) then shows a button for each option in a feature's popup. Each answer is a row added to the
#'   file (when, the layer, the feature's value of the verdict's `field`, the option, the reader's line, the feature's
#'   title and place); a later one for the feature replaces it, and an empty answer withdraws it. [rr_verdicts()]
#'   reads them. As the notes, answered only for a page opened from this computer, and never in a bundle.
#' @param routes Opt-in, the map's own routes, for a page's own script ([rr_script()]): a named list of functions,
#'   each answering `/x/<name>` (and `/x/<name>/...`) from the page by `rr.fetch(name, init)`, the name followed by a
#'   path and a query if any (`rr.fetch("marks/12?full=1")`). A function is given one request, a list of `method`
#'   (`"GET"`, `"POST"`, ...), `path` (what follows its name, `"/12"`), `query` (the address's parameters, a named
#'   list, `list(full = "1")`) and `body` (a JSON body read, else its text, else `NULL`); it returns a list or a data
#'   frame, sent as JSON, a string, sent as text, or `NULL`, not found; an error is sent as its message. As the notes,
#'   answered only for a page opened from this computer. Keep each fast: the server answers one request at a time, and
#'   a slow route holds the tiles behind it (read a file once, and again only when it changes).
#' @param wait Whether to keep serving until stopped (Ctrl-C, Esc in RStudio): `TRUE` in a script run by `Rscript`,
#'   whose map would otherwise go when the script ends. By default `FALSE`: the server answers while R is idle (in
#'   RStudio, while the console waits), and the call returns, so a script, a test or a document goes on.
#' @return The page's address, invisibly.
#' @export
#' @examples
#' # Opens a map in RStudio's Viewer (or a browser) when run by hand, e.g. by example(rr_serve)
#' if (interactive()) {
#'   harbours <- rr_layer(
#'     "harbours", "vector", label = "Harbours",
#'     tiles = rr_tiles_table(rr_example("dansk_harbours"), properties = "SI_HARB"),
#'     style = list(list(id = "harbours-fill", type = "fill", "source-layer" = "features",
#'                       paint = list("fill-color" = "#d9822b"))),
#'     popup = list(click = "harbours-fill", title = "SI_HARB")
#'   )
#'   m <- rr_map(rr_section("ref", "Reference", list(harbours)),
#'               title = "Danish harbours", view = list(center = c(10.5, 56), zoom = 7))
#'   rr_serve(m)
#'   # again, opening on the ocean base map (it replaces the first):
#'   # rr_serve(m, query = list(base = "ocean"))
#'   # with notes pinned on the map, kept in a file:
#'   # rr_serve(m, notes = "harbour_notes.geojson"); rr_notes("harbour_notes.geojson")
#'   # rr_stop() # when done
#' }
rr_serve <- function(
  map,
  port = NULL,
  host = "127.0.0.1",
  open = interactive(),
  query = NULL,
  notes = NULL,
  verdicts = NULL,
  routes = NULL,
  wait = FALSE
) {
  .rr_need("httpuv")
  if (!is.null(routes) && (!is.list(routes) || !length(routes) || is.null(names(routes)) ||
                             !all(grepl("^[a-z][a-z0-9_-]*$", names(routes))) || anyDuplicated(names(routes)) ||
                             !all(vapply(routes, is.function, logical(1))))) {
    stop("`routes` is a named list of functions, each name lower-case letters, digits, _ or -.", call. = FALSE)
  }
  if (!isTRUE(wait) && !isFALSE(wait)) {
    stop("`wait` is TRUE or FALSE.", call. = FALSE)
  }
  .rr_need("jsonlite")
  if (!inherits(map, "rr_map")) {
    stop("`map` is an rr_map().", call. = FALSE)
  }
  if (!is.null(notes)) {
    notes <- .rr_notes_path(notes)
    .rr_notes_utf8()
    .rr_notes_read(notes) # a file that is there must be notes: it is never overwritten otherwise
  }
  if (!is.null(verdicts)) {
    if (!length(.rr_map_verdict_layers(map))) {
      stop("`verdicts` serves the verdicts of a layer whose popup has a `verdict`: the map has none.", call. = FALSE)
    }
    verdicts <- .rr_verdicts_path(verdicts)
    .rr_notes_utf8()
    .rr_verdicts_read(verdicts) # a file that is there must be verdicts: it is never overwritten otherwise
  }
  app <- .rr_map_app(map, notes = notes, host = host, verdicts = verdicts, routes = routes)
  port <- if (is.null(port)) {
    .rr_serve_free(host, app)
  } else {
    .rr_serve_on(host, as.integer(port), app)
  }
  .rr_tiles$served[[as.character(port)]] <- attr(map, "tables")
  url <- sprintf(
    "http://%s:%d/",
    if (host == "127.0.0.1") "localhost" else host,
    port
  )
  if (length(query)) {
    url <- paste0(
      url,
      "?",
      paste(
        names(query),
        vapply(
          query,
          function(v) utils::URLencode(as.character(v), reserved = TRUE),
          ""
        ),
        sep = "=",
        collapse = "&"
      )
    )
  }
  if (open) {
    if (
      requireNamespace("rstudioapi", quietly = TRUE) &&
        rstudioapi::isAvailable()
    ) {
      rstudioapi::viewer(url, height = "maximize")
    } else {
      utils::browseURL(url)
    }
  }
  if (wait) {
    message(sprintf("Serving %s; Ctrl-C (Esc in RStudio) stops it.", url))
    on.exit(rr_stop(port), add = TRUE)
    repeat httpuv::service(100)
  }
  invisible(url)
}

# The port a map served with no port took last
.rr_serve_last <- new.env(parent = emptyenv())

# A map on a port named: the map there replaced, a port another program holds an error
.rr_serve_on <- function(host, port, app) {
  if (length(port) != 1 || is.na(port)) {
    stop("`port` is one port, or NULL for a free one.", call. = FALSE)
  }
  rr_stop(port)
  server <- tryCatch(httpuv::startServer(host, port, app, quiet = TRUE), error = function(e) NULL)
  if (is.null(server)) {
    stop(sprintf("Port %d is taken: give another port, or none for a free one.", port), call. = FALSE)
  }
  .rr_maps[[as.character(port)]] <- server
  port
}

# A map with no port named: on the port the last such map took, else on 8790 or the next free port. A map
# served on a port named is never replaced here: its port is skipped as another program's is
.rr_serve_free <- function(host, app, ports = 8790:8889) {
  last <- .rr_serve_last$port
  if (!is.null(last) && exists(as.character(last), envir = .rr_maps, inherits = FALSE)) {
    ports <- unique(c(last, ports))
  } else {
    last <- NULL
  }
  for (p in setdiff(ports, setdiff(as.integer(ls(.rr_maps)), last))) {
    rr_stop(p)
    server <- tryCatch(httpuv::startServer(host, p, app, quiet = TRUE), error = function(e) NULL)
    if (!is.null(server)) {
      .rr_maps[[as.character(p)]] <- server
      .rr_serve_last$port <- p
      return(p)
    }
  }
  stop(sprintf("No port free from %d to %d: give one in `port`.", min(ports), max(ports)), call. = FALSE)
}

#' @rdname rr_serve
#' @export
rr_stop <- function(port = NULL) {
  ports <- if (is.null(port)) {
    ls(.rr_maps)
  } else {
    intersect(as.character(port), ls(.rr_maps))
  }
  for (p in ports) {
    httpuv::stopServer(.rr_maps[[p]])
    rm(list = p, envir = .rr_maps)
    .rr_map_drop(p)
  }
  invisible(as.integer(ports))
}

# The temporary tables of the map served on a port, dropped when it stops or is replaced, unless a map on another
# port uses them; a map shown again makes them again (rr_tiles_table())
.rr_map_drop <- function(port) {
  old <- .rr_tiles$served[[as.character(port)]]
  .rr_tiles$served[[as.character(port)]] <- NULL
  in_use <- unlist(lapply(.rr_tiles$served, function(ts) {
    vapply(ts, `[[`, "", "name")
  }))
  for (t in old) {
    if (!t$name %in% in_use) {
      try(
        DBI::dbExecute(t$con, sprintf("DROP TABLE IF EXISTS %s", t$name)),
        silent = TRUE
      )
    }
  }
}

# The server -----------------------------------------------------------------------------------------------------------

.rr_map_json <- function(x) {
  as.character(jsonlite::toJSON(
    x,
    auto_unbox = TRUE,
    null = "null",
    na = "null",
    digits = NA
  ))
}

# The page with its config, and a bundle's own (rr_bundle()) or none; "</" escaped, so neither can close its tag.
# `vendor` is where the page finds its libraries, relative to it: its own folder `vendor/`, or a copy shared by the
# maps of an article (knit_print())
.rr_map_page <- function(config, bundle = "null", vendor = "vendor/") {
  page <- paste(
    readLines(
      system.file("engine", "index.html", package = "rebelrebel"),
      warn = FALSE,
      encoding = "UTF-8"
    ),
    collapse = "\n"
  )
  if (!identical(vendor, "vendor/")) {
    page <- gsub("\"vendor/", paste0("\"", vendor), page, fixed = TRUE)
  }
  page <- sub("__CONFIG__", gsub("</", "<\\/", config, fixed = TRUE), page, fixed = TRUE)
  sub("__BUNDLE__", gsub("</", "<\\/", bundle, fixed = TRUE), page, fixed = TRUE)
}

# Each layer's meta. A vector layer's tiles carry the server's start in their address, so a server started on other
# data on the same port is not hidden by the browser's cache (a grid carries its meta's `v`)
.rr_map_metas <- function(layers) {
  started <- format(as.numeric(Sys.time()), digits = 15)
  lapply(layers, function(l) {
    switch(
      l$config$kind,
      grid = if (is.function(l$meta)) l$meta() else l$meta,
      dem = list(count = 1L, v = started),
      contour = list(count = 1L, v = started),
      vector = list(
        count = if (is.null(attr(l$tiles, "count"))) {
          1L
        } else {
          attr(l$tiles, "count")
        },
        v = started
      ),
      NULL
    )
  })
}

# A geojson layer's data as GeoJSON text
.rr_map_geojson <- function(l) {
  d <- if (is.function(l$data)) l$data() else l$data
  if (inherits(d, "sf")) {
    f <- tempfile(fileext = ".geojson")
    on.exit(unlink(f))
    sf::st_write(
      d,
      f,
      driver = "GeoJSON",
      quiet = TRUE,
      layer_options = "COORDINATE_PRECISION=6"
    )
    d <- paste(
      readLines(f, warn = FALSE, encoding = "UTF-8"),
      collapse = "\n"
    )
  }
  d
}

# The app behind rr_serve(), a list with `call(req)` for httpuv: its routes in the header of this file
.rr_map_app <- function(map, notes = NULL, host = "127.0.0.1", verdicts = NULL, routes = NULL) {
  .rr_order_shown(map)
  json <- .rr_map_json
  if (!is.null(notes)) {
    map$config$notes <- list(file = basename(notes))
  }
  specs <- .rr_map_verdict_layers(map)
  if (!is.null(verdicts)) {
    map$config$verdicts <- list(file = basename(verdicts))
  }
  hosts <- unique(tolower(c("localhost", "127.0.0.1", "[::1]", host)))
  config <- json(map$config)
  page <- .rr_map_page(config)
  layers <- map$layers
  metas <- .rr_map_metas(layers)
  geojson <- lapply(layers, function(l) {
    if (l$config$kind != "geojson") {
      return(NULL)
    }
    .rr_map_geojson(l)
  })
  meta <- json(list(
    engine = .rr_map_engine,
    layers = Filter(Negate(is.null), metas)
  ))
  reply <- function(
    status,
    body,
    type = "text/plain; charset=utf-8",
    headers = list()
  ) {
    list(
      status = status,
      headers = c(list(`Content-Type` = type), headers),
      body = body
    )
  }
  list(call = function(req) {
    path <- req$PATH_INFO
    if (!is.null(notes) && (path == "/notes" || startsWith(path, "/notes/"))) {
      return(.rr_map_notes_reply(req, notes, hosts, reply, json))
    }
    if (!is.null(verdicts) && path == "/verdicts") {
      return(.rr_map_verdicts_reply(req, verdicts, specs, hosts, reply, json))
    }
    x <- regmatches(path, regexec("^/x/([a-z][a-z0-9_-]*)(/.*)?$", path))[[1]]
    if (length(x) == 3 && !is.null(routes)) {
      return(.rr_map_route_reply(req, routes[[x[2]]], x[3], hosts, reply, json))
    }
    if (req$REQUEST_METHOD != "GET") {
      return(reply(405L, "GET only"))
    }
    v <- regmatches(path, regexec("^/vendor/([A-Za-z0-9.-]+\\.(js|css))$", path))[[1]]
    if (length(v) == 3) {
      f <- system.file("engine", "vendor", v[2], package = "rebelrebel")
      if (!nzchar(f)) {
        return(reply(404L, "not found"))
      }
      return(reply(
        200L,
        readBin(f, "raw", file.size(f)),
        if (v[3] == "js") "text/javascript; charset=utf-8" else "text/css; charset=utf-8",
        list(`Cache-Control` = "max-age=86400")
      ))
    }
    if (path == "/") {
      return(reply(
        200L,
        page,
        "text/html; charset=utf-8",
        list(`Cache-Control` = "no-store")
      ))
    }
    if (path == "/config.json") {
      return(reply(200L, config, "application/json; charset=utf-8"))
    }
    if (path == "/time") {
      return(.rr_map_time_reply(
        map$time,
        .rr_map_query(req$QUERY_STRING),
        reply,
        json
      ))
    }
    if (path == "/meta") {
      return(reply(
        200L,
        meta,
        "application/json; charset=utf-8",
        list(`Cache-Control` = "no-store")
      ))
    }
    # a feature's row, read on a click (a layer function's popup), its columns those the call named
    rw <- regmatches(path, regexec("^/row/([a-z][a-z0-9_]*)/([0-9]+)$", path))[[1]]
    if (length(rw) == 3) {
      reader <- layers[[rw[2]]]$row
      if (!is.function(reader)) {
        return(reply(404L, "no rows for this layer"))
      }
      v <- tryCatch(.rr_row_json(reader(as.integer(rw[3]))), error = function(e) e)
      if (inherits(v, "error")) {
        return(reply(500L, sub("\n.*", "", conditionMessage(v))))
      }
      if (is.null(v)) {
        return(reply(404L, "no such row"))
      }
      return(reply(200L, json(v), "application/json; charset=utf-8"))
    }
    f <- regmatches(path, regexec("^/fit/([a-z][a-z0-9_]*)$", path))[[1]]
    if (length(f) == 2) {
      fit <- layers[[f[2]]]$fit
      if (!is.function(fit)) {
        return(reply(404L, "no fit for this layer"))
      }
      b <- suppressWarnings(as.numeric(strsplit(
        .rr_or(.rr_map_query(req$QUERY_STRING)$bbox, ""),
        ",",
        fixed = TRUE
      )[[1]]))
      if (length(b) != 4 || anyNA(b) || b[1] >= b[3] || b[2] >= b[4] || any(abs(b[c(2, 4)]) > 90)) {
        return(reply(400L, "bbox is west,south,east,north"))
      }
      v <- tryCatch(fit(b[1], b[2], b[3], b[4]), error = function(e) e)
      if (inherits(v, "error")) {
        return(reply(500L, sub("\n.*", "", conditionMessage(v))))
      }
      # c(floor, cap), or a list of any of `floor` and `cap`, `quantiles` (rising, for colours in equal shares and
      # contour levels) and `exaggeration` (0-1, a shading's intensity)
      if (is.null(v)) {
        return(reply(404L, "no values in view"))
      }
      if (!is.list(v)) {
        v <- if (length(v) == 2) list(floor = v[[1]], cap = v[[2]]) else list()
      }
      fc <- c(v$floor, v$cap)
      q <- v$quantiles
      ex <- v$exaggeration
      if ((length(fc) && (length(fc) != 2 || anyNA(fc))) || (!length(fc) && is.null(q) && is.null(ex))) {
        return(reply(404L, "no values in view"))
      }
      if (!is.null(q) && (!is.numeric(q) || anyNA(q) || is.unsorted(q))) {
        return(reply(500L, "the fit's quantiles are not rising numbers"))
      }
      if (!is.null(ex) && (!is.numeric(ex) || length(ex) != 1 || is.na(ex) || ex < 0 || ex > 1)) {
        return(reply(500L, "the fit's exaggeration is not a number from 0 to 1"))
      }
      return(reply(
        200L,
        json(Filter(Negate(is.null), list(floor = v$floor, cap = v$cap, q = if (!is.null(q)) as.list(q), exaggeration = ex))),
        "application/json; charset=utf-8",
        list(`Cache-Control` = "no-store")
      ))
    }
    d <- regmatches(
      path,
      regexec("^/data/([a-z][a-z0-9_]*)[.]geojson$", path)
    )[[1]]
    if (length(d) == 2) {
      g <- geojson[[d[2]]]
      if (is.null(g)) {
        return(reply(404L, "no such data"))
      }
      return(reply(
        200L,
        g,
        "application/geo+json; charset=utf-8",
        list(`Cache-Control` = "no-store")
      ))
    }
    m <- regmatches(
      path,
      regexec(
        "^/tiles/([a-z][a-z0-9_]*)/([0-9]+)/([0-9]+)/([0-9]+)[.](pbf|png|webp)$",
        path
      )
    )[[1]]
    if (
      length(m) != 6 ||
        is.null(layers[[m[2]]]) ||
        layers[[m[2]]]$config$kind == "geojson" ||
        m[6] !=
          (if (layers[[m[2]]]$config$kind %in% c("dem", "contour")) {
            layers[[m[2]]]$config$format
          } else {
            "pbf"
          })
    ) {
      return(reply(404L, "not found"))
    }
    z <- .rr_map_whole(m[3], 0L, 22L)
    if (is.null(z)) {
      return(reply(400L, "z is 0-22"))
    }
    x <- .rr_map_whole(m[4], 0L, 2L^z - 1L)
    y <- .rr_map_whole(m[5], 0L, 2L^z - 1L)
    if (is.null(x) || is.null(y)) {
      return(reply(400L, "x and y lie in the zoom's range"))
    }
    l <- layers[[m[2]]]
    if (l$config$kind %in% c("dem", "contour")) {
      return(.rr_map_tile_reply(
        function() l$tiles(z, x, y),
        reply,
        paste0("image/", l$config$format)
      ))
    }
    if (l$config$kind == "vector") {
      return(.rr_map_tile_reply(function() l$tiles(z, x, y), reply))
    }
    p <- .rr_map_params(
      l$config$filters,
      metas[[m[2]]],
      .rr_map_query(req$QUERY_STRING)
    )
    if (is.character(p)) {
      return(reply(400L, p))
    }
    .rr_map_tile_reply(function() l$tiles(z, x, y, p), reply)
  })
}

# A page's own route (rr_serve(routes = )): its function given the request as a list, its value sent back
.rr_map_route_reply <- function(req, fn, rest, hosts, reply, json) {
  if (is.null(fn)) {
    return(reply(404L, "no such route"))
  }
  refused <- .rr_map_local_only(req, hosts, reply, "A map's own routes", "A write to a map's own route")
  if (!is.null(refused)) {
    return(refused)
  }
  body <- NULL
  if (!is.null(req$rook.input)) {
    raw <- req$rook.input$read()
    if (length(raw)) {
      text <- rawToChar(raw)
      Encoding(text) <- "UTF-8"
      body <- if (grepl("json", .rr_or(req$CONTENT_TYPE, ""), fixed = TRUE)) {
        tryCatch(jsonlite::fromJSON(text), error = function(e) text)
      } else {
        text
      }
    }
  }
  v <- tryCatch(
    fn(list(method = req$REQUEST_METHOD, path = rest, query = .rr_map_query(req$QUERY_STRING), body = body)),
    error = function(e) e
  )
  if (inherits(v, "error")) {
    return(reply(500L, sub("\n.*", "", conditionMessage(v))))
  }
  if (is.null(v)) {
    return(reply(404L, "not found", headers = list(`Cache-Control` = "no-store")))
  }
  if (is.character(v) && length(v) == 1) {
    return(reply(200L, enc2utf8(v), headers = list(`Cache-Control` = "no-store")))
  }
  reply(200L, json(v), "application/json; charset=utf-8", list(`Cache-Control` = "no-store"))
}

# The time panel's series of one vessel's span, its vessel and span checked against the panel's first
.rr_map_time_reply <- function(tp, qs, reply, json) {
  if (is.null(tp)) {
    return(reply(404L, "this map has no time panel"))
  }
  vs <- tp$config$vessels
  i <- match(.rr_or(qs$v, NA_character_), vapply(vs, `[[`, "", "value"))
  if (is.na(i)) {
    return(reply(400L, "v is one of the panel's vessels"))
  }
  spans <- vapply(vs[[i]]$spans, `[[`, "", "value")
  if (!.rr_or(qs$span, "") %in% spans) {
    return(reply(
      400L,
      sprintf("span is one of %s", paste(spans, collapse = ", "))
    ))
  }
  body <- tryCatch(
    json(tp$series(vs[[i]]$value, qs$span)),
    error = function(e) e
  )
  if (inherits(body, "error")) {
    return(reply(500L, sub("\n.*", "", conditionMessage(body))))
  }
  reply(
    200L,
    body,
    "application/json; charset=utf-8",
    list(`Cache-Control` = "no-store")
  )
}

# A tile, or the first line of why its function failed: the page shows the reason, where the map would stay blank
.rr_map_tile_reply <- function(
  tile,
  reply,
  type = "application/vnd.mapbox-vector-tile"
) {
  body <- tryCatch(tile(), error = function(e) e)
  if (inherits(body, "error")) {
    return(reply(500L, sub("\n.*", "", conditionMessage(body))))
  }
  # an image that is not there: an empty one is no image the page can decode
  if (is.null(body) && startsWith(type, "image/")) {
    return(reply(404L, "no tile"))
  }
  reply(
    200L,
    if (is.null(body)) raw(0) else body,
    type,
    list(`Cache-Control` = "max-age=600")
  )
}

.rr_map_whole <- function(x, lo, hi) {
  if (is.null(x) || !grepl("^[0-9]+$", x)) {
    return(NULL)
  }
  v <- as.numeric(x)
  if (v < lo || v > hi) NULL else as.integer(v)
}

.rr_map_query <- function(q) {
  q <- sub("^[?]", "", if (is.null(q)) "" else q)
  if (!nzchar(q)) {
    return(list())
  }
  kv <- strsplit(strsplit(q, "&", fixed = TRUE)[[1]], "=", fixed = TRUE)
  stats::setNames(
    lapply(kv, function(x) utils::URLdecode(if (length(x) > 1) x[2] else "")),
    vapply(kv, `[`, "", 1)
  )
}

# A grid's query against its filters: a named list of the values given, or the reason it is refused. A value must be
# one of the filter's options (several of its meta options, comma separated), or a range's bounds within its meta.
.rr_map_params <- function(filters, meta, query) {
  out <- list()
  for (f in filters) {
    if (identical(f$type, "metric")) {
      next
    }
    if (identical(f$type, "range")) {
      ps <- unlist(f$params)
      v <- query[ps]
      given <- !vapply(v, is.null, logical(1))
      if (!any(given)) {
        next
      }
      if (!all(given)) {
        return(sprintf("%s are given together", paste(ps, collapse = " and ")))
      }
      r <- unlist(meta$ranges[[f$id]])
      n <- suppressWarnings(as.numeric(unlist(v)))
      if (anyNA(n) || any(n < r[1] | n > r[2])) {
        return(sprintf(
          "%s lie in %s to %s",
          paste(ps, collapse = " and "),
          r[1],
          r[2]
        ))
      }
      out[ps] <- unlist(v)
      next
    }
    v <- query[[f$id]]
    if (is.null(v) || !nzchar(v)) {
      next
    }
    allowed <- if (isTRUE(f$meta)) {
      as.character(meta$options[[f$id]]$value)
    } else {
      vapply(f$options, function(o) as.character(o$value), "")
    }
    vs <- if (isTRUE(f$meta)) strsplit(v, ",", fixed = TRUE)[[1]] else v
    if (!length(vs) || !all(vs %in% allowed)) {
      return(sprintf(
        "%s is %s",
        f$id,
        if (length(allowed) <= 12) {
          paste(allowed, collapse = ", ")
        } else {
          "one of its options"
        }
      ))
    }
    out[[f$id]] <- v
  }
  out
}

