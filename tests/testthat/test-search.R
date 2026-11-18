# A search over a layer's text column (search = ): its index, served and bundled; in the page, the Find box

places <- function() {
  data.frame(
    lon = c(-20, -14, -21, -18, -22.5, -19.5),
    lat = c(64.2, 65.2, 64.0, 65.6, 65.4, 63.5),
    name = c("Ey", "Ey", "Eyja", "Stóra Ey", "Hvalfjörður", "Éyjar"),
    kind = c("isle", "isle", "isle", "isle", "fjord", "isle"),
    z = c(4, 6.3, 5, 7.5, 3, NA)
  )
}

test_that("search = a column: each row's text, place and number, with a text's own start zoom", {
  skip_if_no_spatial()
  m <- rr_map() |> rr_point(places(), popup = c(name, kind), search = name, id = "p")
  l <- m$layers$p
  expect_true(m$config$layers[[1]]$search)
  expect_identical(l$search$column, "name")
  expect_identical(l$search$t, places()$name)
  expect_equal(l$search$x, places()$lon)
  expect_equal(l$search$y, places()$lat)
  expect_identical(l$search$r, 1:6)
  expect_null(l$search$z)
  # the rows carry their number, so the page finds the one it went to; a text too, which has no popup
  m <- rr_map() |> rr_text(places(), label = name, minzoom = z, search = name, id = "t")
  expect_identical(m$layers$t$search$r, 1:6)
  expect_equal(m$layers$t$search$z, c(4, 6.3, 5, 7.5, 3, NA)) # none: drawn at every zoom (MapLibre reads it as 0)
  expect_match(paste(.rr_map_geojson(m$layers$t), collapse = ""), '"rr_row":1', fixed = TRUE)
  # a shape: a point on it; a number's values as text
  h <- rr_map() |> rr_polygon(rr_example("dansk_harbours"), search = SI_HARB, id = "h")
  f <- h$layers$h$search
  expect_type(f$t, "character")
  expect_true(all(f$x > -60 & f$x < 40 & f$y > 20 & f$y < 75)) # Greenland to the Black Sea, the Canaries to Svalbard
  expect_length(f$r, h$config$layers[[1]]$features)
  # no search, none
  expect_null((rr_map() |> rr_point(places()))$config$layers[[1]]$search)
  expect_error(rr_map() |> rr_point(places(), search = c(name, kind)), "`search` is one column")
  expect_error(rr_map() |> rr_point(places(), search = nosuch))
})

test_that("a search's index is served at /search/<id> and bundled beside the layer's data", {
  skip_if_no_spatial()
  m <- rr_map() |>
    rr_point(places(), search = name, id = "p") |>
    rr_point(places(), id = "q")
  app <- .rr_map_app(m)
  r <- app$call(list(REQUEST_METHOD = "GET", PATH_INFO = "/search/p", QUERY_STRING = "", HTTP_HOST = "localhost:8811"))
  expect_identical(r$status, 200L)
  j <- jsonlite::fromJSON(r$body)
  expect_identical(j$t, places()$name)
  expect_identical(j$r, 1:6)
  expect_identical(app$call(list(REQUEST_METHOD = "GET", PATH_INFO = "/search/q", QUERY_STRING = "",
                                 HTTP_HOST = "localhost:8811"))$status, 404L)
  # one row: still arrays
  one <- rr_map() |> rr_point(places()[1, ], search = name, id = "one")
  expect_match(.rr_search_json(one$layers$one$search), '"t":["Ey"]', fixed = TRUE)
  dir <- withr::local_tempdir()
  rr_bundle(m, dir, overwrite = TRUE)
  expect_true(file.exists(file.path(dir, "data", "p_search.js")))
  expect_false(file.exists(file.path(dir, "data", "q_search.js")))
})

test_that("in the page, the Find box ranks whole matches, then beginnings, then any, nearest first, and goes to one", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  m <- rr_map(view = list(center = c(-20, 64.2), zoom = 5)) |>
    rr_point(places(), popup = c(name, kind), search = name, id = "p", name = "Places") |>
    rr_point(places(), id = "plain", name = "Plain", visible = FALSE)
  rr_bundle(m, dir, overwrite = TRUE)
  b <- open_page(paste0(serve_dir(dir), "index.html"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && map.loaded() && !!map.getLayer('p-dot')")), 40))
  expect_false(page_eval(b, "document.getElementById('find').hidden"))
  expect_identical(page_eval(b, "document.getElementById('find-q').placeholder"), "Find…")
  hits <- function(text) {
    page_eval(b, sprintf("(() => { const q = document.getElementById('find-q'); q.value = %s; q.dispatchEvent(new Event('input')); return true; })()",
                         jsonlite::toJSON(text, auto_unbox = TRUE)))
    wait_until(function() page_eval(b, "document.querySelectorAll('#find-hits li').length") > 0, 20)
    unlist(page_eval(b, "[...document.querySelectorAll('#find-hits li')].map(li => li.textContent)"))
  }
  # "ey": the two whole matches nearest the centre first (here, then 280 km east), then those it begins, then any;
  # case and accents aside (Éyjar), the fjord not at all
  h <- hits("ey")
  expect_length(h, 5)
  expect_match(h[1], "^Ey · here$")
  expect_match(h[2], "^Ey · [0-9]+ km E$")
  expect_match(h[3], "^Eyja · ")
  expect_match(h[4], "^Éyjar · ")
  expect_match(h[5], "^Stóra Ey · ")
  expect_identical(hits("fjord")[1], "none found")
  expect_identical(hits("FJÖRÐ"), hits("fjorð"))
  # Enter in the box: the first hit
  hits("Eyja")
  page_eval(b, "document.getElementById('find-q').dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' })) ?? true")
  expect_true(wait_until(function() isTRUE(page_eval(b, "!!document.querySelector('.maplibregl-popup')")), 20))
  expect_equal(unlist(page_eval(b, "map.getCenter().toArray()")), c(-21, 64), tolerance = 1e-4)
  # a click on one: the map goes there, at zoom 10 or nearer, and its row shows in a popup
  hits("fjör")
  page_eval(b, "[...document.querySelectorAll('#find-hits li')].find(li => li.textContent.startsWith('Hvalfj')).click() ?? true")
  expect_true(wait_until(function() isTRUE(page_eval(b, "!!document.querySelector('.maplibregl-popup')")), 20))
  expect_equal(unlist(page_eval(b, "map.getCenter().toArray()")), c(-22.5, 65.4), tolerance = 1e-4)
  expect_identical(page_eval(b, "map.getZoom()"), 10L)
  expect_true(wait_until(function() grepl("fjord", page_eval(b, "document.querySelector('.maplibregl-popup').textContent")), 20))
})
