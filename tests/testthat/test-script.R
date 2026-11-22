# The seam: a page's own script (og_script()) and its own routes (og_serve(routes = ))

# a request to a map's app as httpuv makes it, from the map's page opened on this computer
route_call <- function(app, method, path, query = "", body = NULL, host = "localhost:8811", page = TRUE, json = TRUE) {
  req <- list(REQUEST_METHOD = method, PATH_INFO = path, QUERY_STRING = query, HTTP_HOST = host)
  if (page) req$HTTP_X_OG_NOTES <- "1"
  if (!is.null(body)) {
    req$rook.input <- list(read = function(...) charToRaw(enc2utf8(body)))
    if (json) req$CONTENT_TYPE <- "application/json"
  }
  app$call(req)
}

test_that("og_script() puts a script and its styles on the map, before or after its layers", {
  skip_if_no_spatial()
  pos <- og_example("trawlsurvey")
  f <- withr::local_tempfile(fileext = ".js")
  writeLines("og.panel('From a file');", f)
  a <- og_map(pos) |> og_script("og.panel('Text');", css = ".og-panel { color: red; }") |> og_point(id = "positions")
  expect_identical(a$config$scripts[[1]]$js, "og.panel('Text');")
  expect_identical(a$config$scripts[[1]]$css, ".og-panel { color: red; }")
  b <- og_map(pos) |> og_point(id = "positions") |> og_script(f) |> og_path(group = vid, time = time)
  expect_identical(b$config$scripts[[1]]$js, "og.panel('From a file');")
  expect_length(b$config$layers, 2)
  expect_error(og_script(b, "missing.js"), "No such file")
  expect_error(og_script(list(), "x"), "og_map")
  # a bundle carries it
  dir <- withr::local_tempdir()
  og_bundle(b, dir, overwrite = TRUE)
  expect_match(paste(readLines(file.path(dir, "index.html"), warn = FALSE), collapse = "\n"), "From a file", fixed = TRUE)
})

test_that("a map's own routes answer from its page, as the function returns", {
  skip_if_no_spatial()
  m <- og_example("trawlsurvey") |> og_point()
  seen <- NULL
  app <- .og_map_app(m, routes = list(
    echo = function(req) { seen <<- req; list(method = req$method, path = req$path, a = req$query$a, body = req$body) },
    text = function(req) "plain text",
    none = function(req) NULL,
    fail = function(req) stop("no such feature\nmore")
  ))
  r <- route_call(app, "GET", "/x/echo/one/two", query = "a=1")
  expect_identical(r$status, 200L)
  expect_identical(jsonlite::fromJSON(r$body), list(method = "GET", path = "/one/two", a = "1", body = NULL))
  # the query as a form writes it (URLSearchParams): "+" a space, "%2B" a plus
  r <- route_call(app, "GET", "/x/echo", query = "a=vessel+4%2B1")
  expect_identical(jsonlite::fromJSON(r$body)$a, "vessel 4+1")
  r <- route_call(app, "POST", "/x/echo", body = '{"vid": 1131, "names": ["a", "b"]}')
  expect_identical(r$status, 200L)
  expect_identical(seen$body, list(vid = 1131L, names = c("a", "b")))
  expect_identical(route_call(app, "GET", "/x/text")$body, "plain text")
  expect_identical(route_call(app, "GET", "/x/none")$status, 404L)
  r <- route_call(app, "GET", "/x/fail")
  expect_identical(r$status, 500L)
  expect_identical(r$body, "no such feature")
  expect_identical(route_call(app, "GET", "/x/nosuch")$status, 404L)
  # from elsewhere, or a write not from the page: refused
  expect_identical(route_call(app, "GET", "/x/echo", host = "example.org")$status, 403L)
  expect_identical(route_call(app, "POST", "/x/echo", body = "{}", page = FALSE)$status, 403L)
  # a map with no routes has none
  expect_identical(route_call(.og_map_app(m), "GET", "/x/echo")$status, 404L)
  expect_error(og_serve(m, routes = list(function(req) 1), open = FALSE, wait = FALSE), "named list")
  expect_error(og_serve(m, routes = list(Bad = function(req) 1), open = FALSE, wait = FALSE), "named list")
})

test_that("in the page: a script's click reads the row, its route keeps what it sends, its filter and data hold", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  marks <- integer()
  js <- r"(
    const body = og.panel("Marks");
    og.on("click", "positions", async ({ row }) => {
      const r = await row();
      if (!r) return;
      const vid = r.find(c => c.name === "vid").value;
      const res = await og.fetch("mark", { method: "POST", body: JSON.stringify({ vid }) });
      const j = await res.json();
      body.textContent = `marked ${vid}, ${j.n} in all`;
    });
    window.SCRIPT_RAN = true;
  )"
  m <- og_example("trawlsurvey") |>
    og_point(id = "positions", popup = c(vid, time)) |>
    og_script(js)
  url <- og_serve(m, open = FALSE, wait = FALSE,
                  routes = list(mark = function(req) { marks <<- c(marks, as.integer(req$body$vid)); list(n = length(marks)) },
                                echo = function(req) list(path = req$path, a = req$query$a, b = req$query$b)))
  withr::defer(og_stop(as.integer(sub(".*:([0-9]+)/$", "\\1", url))))
  b <- open_page(url)
  expect_true(wait_until(function() isTRUE(page_eval(b, "window.SCRIPT_RAN === true && map.loaded() && map.queryRenderedFeatures({ layers: ['positions-dot'] }).length > 0")), 40))
  expect_identical(page_eval(b, "og.served"), TRUE)
  expect_identical(unlist(page_eval(b, 'og.layer("positions").styles')), "positions-dot")
  # a click on a position: the script's, not the popup's
  xy <- unlist(page_eval(b, '(() => { const f = map.queryRenderedFeatures({ layers: ["positions-dot"] })[0], p = map.project(f.geometry.coordinates), r = map.getContainer().getBoundingClientRect(); return [r.left + p.x, r.top + p.y]; })()'))
  for (type in c("mouseMoved", "mousePressed", "mouseReleased")) {
    b$Input$dispatchMouseEvent(type = type, x = xy[1], y = xy[2], button = if (type == "mouseMoved") "none" else "left",
                               clickCount = if (type == "mouseMoved") 0 else 1)
  }
  expect_true(wait_until(function() grepl("in all", page_eval(b, 'document.querySelector(".og-panel .body").textContent')), 20))
  expect_length(marks, 1)
  expect_match(page_eval(b, 'document.querySelector(".og-panel .body").textContent'), sprintf("marked %d, 1 in all", marks))
  expect_false(page_eval(b, '!!document.querySelector(".maplibregl-popup")'))
  # a route's path and query, after its name as written; anything else no route's. The promise is kept in the page
  # and polled, as the server answers only while R's own loop runs (chromote's await would hold it)
  fetched <- function(name) {
    page_eval(b, sprintf(paste0("window.GOT = undefined; og.fetch(%s).then(r => r.json())",
                                ".then(v => window.GOT = { v }, e => window.GOT = { e: String(e) }) && true"), name))
    wait_until(function() isTRUE(page_eval(b, "window.GOT !== undefined")), 20)
    page_eval(b, "window.GOT")
  }
  expect_identical(fetched('"echo/one/two?a=1&b=" + encodeURIComponent("x y&z")')$v,
                   list(path = "/one/two", a = "1", b = "x y&z"))
  expect_identical(fetched('"echo?a=2"')$v, list(path = "", a = "2", b = NULL))
  expect_match(fetched('"Echo"')$e, "is no route")
  expect_match(fetched('"../notes"')$e, "is no route")
  # a filter of the script's, then none
  page_eval(b, 'og.filter("positions", "none", ["==", ["get", "og_row"], -1]) ?? true')
  expect_true(wait_until(function() identical(page_eval(b, 'map.queryRenderedFeatures({ layers: ["positions-dot"] }).length'), 0L), 20))
  page_eval(b, 'og.filter("positions", "none", null) ?? true')
  expect_true(wait_until(function() page_eval(b, 'map.queryRenderedFeatures({ layers: ["positions-dot"] }).length') > 0, 20))
  # new data for a whole layer, its count beside its name kept
  page_eval(b, 'og.setData("positions", { type: "FeatureCollection", features: [{ type: "Feature", properties: { og_row: 1 }, geometry: { type: "Point", coordinates: map.getCenter().toArray() } }] }) ?? true')
  expect_true(wait_until(function() identical(page_eval(b, 'map.queryRenderedFeatures({ layers: ["positions-dot"] }).length'), 1L), 20))
  expect_match(page_eval(b, 'document.getElementById("positionsinfo").textContent'), "^1 ")
  expect_error(page_eval(b, 'og.on("hover", "positions", () => 0)'), "click")
  # a map with no time panel has no window
  expect_null(page_eval(b, "og.window()"))
  expect_error(page_eval(b, "og.window([1, 2])"), "no time panel")
  expect_error(page_eval(b, 'og.on("window", () => 0)'), "has none")
  # in a bundle the script runs with no server
  dir <- withr::local_tempdir()
  og_bundle(m, dir, overwrite = TRUE)
  b2 <- open_page(paste0(serve_dir(dir), "index.html"))
  expect_true(wait_until(function() isTRUE(page_eval(b2, "window.SCRIPT_RAN === true")), 30))
  expect_identical(page_eval(b2, "og.served"), FALSE)
})

test_that("og_serve(wait = TRUE) keeps a map served from Rscript up", {
  skip_on_cran()
  skip_if_no_spatial()
  skip_if_not_installed("processx")
  installed <- tryCatch(utils::packageDescription("ogis", lib.loc = .libPaths())$Version, error = function(e) "")
  skip_if(!identical(installed, as.character(utils::packageVersion("ogis"))),
          "the installed ogis is not the one tested (the child R loads the installed one)")
  port <- httpuv::randomPort()
  code <- sprintf(paste0("library(ogis); m <- og_example(\"trawlsurveytows\") |> og_line(); ",
                         "og_serve(m, port = %d, open = FALSE, wait = TRUE); cat(\"returned\\n\")"), port)
  p <- processx::process$new(file.path(R.home("bin"), "Rscript"), c("-e", code), stdout = "|", stderr = "|")
  withr::defer(p$kill())
  got <- NULL
  for (i in 1:120) {
    got <- tryCatch(suppressWarnings(readLines(sprintf("http://127.0.0.1:%d/config.json", port), warn = FALSE)),
                    error = function(e) NULL)
    if (length(got)) break
    Sys.sleep(0.5)
  }
  expect_match(paste(got, collapse = ""), '"title"')
  expect_true(p$is_alive()) # still serving, not returned
})
