# Features known by a key (MapLibre's promoteId), and a feature's state set by a page's script (rr.state())

test_that("a layer function's features carry their row's number, the layer's key", {
  skip_if_no_spatial()
  pos <- rr_example("trawlsurvey")
  m <- rr_map(pos) |> rr_point(popup = FALSE, id = "p") |> rr_text(label = vid, id = "t")
  expect_identical(vapply(m$config$layers, `[[`, "", "key"), c("rr_row", "rr_row"))
  # no popup, no search: still numbered, whole and as tiles
  expect_match(paste(.rr_map_geojson(m$layers$t), collapse = ""), '"rr_row":1[,}]')
  tiled <- rr_map(pos) |> rr_point(popup = FALSE, whole = FALSE, id = "p")
  expect_identical(tiled$config$layers[[1]]$kind, "vector")
  expect_identical(tiled$config$layers[[1]]$key, "rr_row")
  # a layer of one's own: its key as given, for vector and geojson layers only
  own <- rr_layer("h", "vector", tiles = function(z, x, y) raw(0), key = "code",
                  style = list(list(id = "h-fill", type = "fill", "source-layer" = "features")))
  expect_identical(own$config$key, "code")
  expect_null(rr_layer("h", "vector", tiles = function(z, x, y) raw(0),
                       style = list(list(id = "h-fill", type = "fill", "source-layer" = "features")))$config$key)
  expect_error(rr_layer("d", "dem", tiles = function(z, x, y) raw(0), key = "x",
                        style = list(list(id = "d-colour", type = "color-relief"))), "vector or geojson")
  expect_error(rr_layer("h", "geojson", data = "{}", key = c("a", "b"),
                        style = list(list(id = "h-fill", type = "fill"))), "one property")
})

test_that("in the page, rr.state() sets a feature's state, its style reads it, kept through a base map's change", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  pos <- rr_example("trawlsurvey")
  ring <- list("case", list("boolean", list("feature-state", "picked"), FALSE), 6, 0)
  for (whole in c(TRUE, FALSE)) {
    w <- paste("whole:", whole)
    dir <- withr::local_tempdir()
    m <- rr_map(pos, basemaps = list(list(id = "plain", label = "Plain", background = "#ffffff"), list(id = "none", label = "None"))) |>
      rr_point(id = "positions", whole = whole, "circle-stroke-width" = ring)
    rr_bundle(m, dir, overwrite = TRUE, maxzoom = 6) # the tiles to zoom 6: a bundle to 14 takes 40 s
    b <- open_page(paste0(serve_dir(dir), "index.html"))
    expect_true(wait_until(function() {
      isTRUE(page_eval(b, "typeof rr !== 'undefined' && map.loaded() && map.queryRenderedFeatures({ layers: ['positions-dot'] }).length > 0"))
    }, 40), info = w)
    expect_identical(page_eval(b, "rr.layer('positions').key"), "rr_row", info = w)
    # a feature drawn: its id its row's number; its state set by the script, read back, and seen by the query
    key <- page_eval(b, "map.queryRenderedFeatures({ layers: ['positions-dot'] })[0].id")
    expect_identical(key, page_eval(b, "map.queryRenderedFeatures({ layers: ['positions-dot'] })[0].properties.rr_row"), info = w)
    page_eval(b, sprintf("rr.state('positions', %d, { picked: true }) ?? true", key))
    page_eval(b, sprintf("rr.state('positions', %d, { other: 1 }) ?? true", key))
    expect_identical(page_eval(b, sprintf("rr.state('positions', %d)", key)), list(picked = TRUE, other = 1L), info = w)
    picked <- function() {
      page_eval(b, sprintf("map.queryRenderedFeatures({ layers: ['positions-dot'] }).filter(f => f.id === %d && f.state.picked).length", key))
    }
    expect_true(wait_until(function() picked() > 0, 20), info = w)
    # another base map: MapLibre's diff of the styles keeps the sources, and with them the state
    page_eval(b, "document.querySelector('#bases input[value=none]').click() ?? true")
    expect_true(wait_until(function() {
      isTRUE(page_eval(b, "map.isStyleLoaded() && map.loaded() && map.getPaintProperty('base-bg', 'background-color') === '#eef0f2'"))
    }, 30), info = w)
    expect_true(wait_until(function() picked() > 0, 20), info = w)
    # a style made again whole drops MapLibre's states: the script's are set again, one set past rr.state() is not
    page_eval(b, sprintf("(map.setFeatureState({ source: 'positions', id: %d%s }, { direct: true }), true)", key + 1,
                         if (whole) "" else ", sourceLayer: 'features'"))
    page_eval(b, "window.LOADS = 0; map.on('style.load', () => window.LOADS++) && true")
    page_eval(b, "(map.setStyle(map.getStyle(), { diff: false }), true)")
    expect_true(wait_until(function() isTRUE(page_eval(b, "window.LOADS > 0 && map.isStyleLoaded() && map.loaded()")), 30), info = w)
    expect_identical(page_eval(b, sprintf("rr.state('positions', %d).picked", key)), TRUE, info = w)
    expect_null(page_eval(b, sprintf("rr.state('positions', %d).direct", key + 1)), info = w)
    expect_true(wait_until(function() picked() > 0, 20), info = w)
    # cleared
    page_eval(b, sprintf("rr.state('positions', %d, null) ?? true", key))
    expect_identical(page_eval(b, sprintf("rr.state('positions', %d)", key)), setNames(list(), character()), info = w)
    expect_error(page_eval(b, "rr.state('nosuch', 1, { a: 1 })"), "not a layer whose features have a key")
    b$close()
  }
})
