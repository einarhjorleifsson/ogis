# tools/firefox-check.R — a bundle opened from its folder (file://) in headless Firefox, by hand at each MapLibre
# update (plan 077 in fishycode). The test suite checks the same in Chrome (test-file.R); CI's runners may lack Firefox.
#
# Run from the package's folder:  Rscript tools/firefox-check.R [path to firefox]
# Firefox is driven over WebDriver BiDi (its remote protocol) with the R package websocket, from a fresh profile in a
# temporary folder. Prints what the map drew; stops if it drew nothing within a minute.

ff <- commandArgs(TRUE)[1]
if (is.na(ff)) {
  ff <- c("/Applications/Firefox.app/Contents/MacOS/firefox", Sys.which("firefox"),
          "C:/Program Files/Mozilla Firefox/firefox.exe")
  ff <- ff[nzchar(ff) & file.exists(ff)][1]
}
if (is.na(ff)) stop("No Firefox found: give its path, Rscript tools/firefox-check.R /path/to/firefox.", call. = FALSE)

pkgload::load_all(".", quiet = TRUE)
relief <- og_tiles_dem(og_example("dansk_relief"), maxzoom = 6)
contours <- og_layer("lines", "contour", label = "Contours", tiles = relief,
                     style = list(list(id = "lines-line", type = "line", "source-layer" = "contours")),
                     contours = list(thresholds = list("5" = c(10, 50)), multiplier = -1))
harbours <- og_example("dansk_harbours")
m <- og_map(view = list(bounds = c(8, 54.5, 13, 58)), basemaps = list(list(id = "none", label = "None"))) |>
  og_add_layer(contours, section = "Sea floor") |>
  og_polygon(harbours, fill = NA, colour = "#b2182b", id = "harbours") |>
  og_text(harbours, label = SI_HARB, id = "ids")
dir <- tempfile("ogis-firefox")
og_bundle(m, dir, maxzoom = 6)
p <- normalizePath(file.path(dir, "index.html"), winslash = "/")
url <- paste0("file://", if (startsWith(p, "/")) "" else "/", utils::URLencode(p))

port <- httpuv::randomPort()
prof <- tempfile("ffprofile"); dir.create(prof)
proc <- processx::process$new(ff, c("--headless", "--no-remote", "--profile", prof, "--remote-debugging-port", port,
                                    "--window-size=1100,800"), stdout = "|", stderr = "|")
on.exit(proc$kill(), add = TRUE)
ws <- NULL
for (i in 1:60) { # Firefox takes a few seconds to listen
  Sys.sleep(0.5)
  ws <- tryCatch({
    w <- websocket::WebSocket$new(sprintf("ws://127.0.0.1:%d/session", port), autoConnect = FALSE)
    opened <- FALSE; w$onOpen(function(e) opened <<- TRUE); w$connect()
    for (k in 1:20) { later::run_now(0.1); if (opened) break }
    if (opened) w else NULL
  }, error = function(e) NULL)
  if (!is.null(ws)) break
}
if (is.null(ws)) stop("Firefox's remote protocol did not answer.", call. = FALSE)
replies <- list(); id <- 0L
ws$onMessage(function(e) {
  m <- jsonlite::fromJSON(e$data, simplifyVector = FALSE)
  if (!is.null(m$id)) replies[[as.character(m$id)]] <<- m
})
send <- function(method, params = stats::setNames(list(), character())) {
  id <<- id + 1L; k <- as.character(id)
  ws$send(jsonlite::toJSON(list(id = id, method = method, params = params), auto_unbox = TRUE))
  for (i in 1:600) { later::run_now(0.1); if (!is.null(replies[[k]])) break }
  r <- replies[[k]]
  if (is.null(r)) stop(method, ": no answer", call. = FALSE)
  if (!is.null(r$error)) stop(method, ": ", r$error, " ", r$message %||% "", call. = FALSE)
  r$result
}
js <- function(expr) {
  r <- send("script.evaluate", list(expression = expr, target = list(context = ctx), awaitPromise = FALSE))
  if (identical(r$type, "exception")) NA else r$result$value
}
invisible(send("session.new", list(capabilities = stats::setNames(list(), character()))))
ctx <- send("browsingContext.getTree")$contexts[[1]]$context
invisible(send("browsingContext.navigate", list(context = ctx, url = url, wait = "complete")))
drawn <- "JSON.stringify(Object.fromEntries(['harbours-fill', 'ids-text', 'lines-line'].map(id => [id, map.getLayer(id) ? map.queryRenderedFeatures({ layers: [id] }).length : -1])))"
ok <- FALSE
for (i in 1:120) {
  if (isTRUE(js("typeof map !== 'undefined' && map.loaded() && map.queryRenderedFeatures({ layers: ['lines-line'] }).length > 0"))) {
    ok <- TRUE; break
  }
  Sys.sleep(0.5)
}
cat(sprintf("Firefox %s, MapLibre %s, %s: %s\n", sub("^Mozilla Firefox ", "", trimws(system2(ff, "--version", stdout = TRUE))),
            js("typeof maplibregl === 'undefined' ? 'not loaded' : maplibregl.getVersion()"), js("location.protocol"), js(drawn)))
if (!ok) stop("The map drew no contours within a minute.", call. = FALSE)
