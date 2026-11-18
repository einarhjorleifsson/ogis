# Base maps of one's own: a tile address, a WMS's, in the page

# A 1 x 1 picture, the one tile a test's base maps are made of
one_tile <- function(path) {
  writeBin(jsonlite::base64_dec(paste0(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  )), path)
}

test_that("a page opens on a base map given as a tile address, switches to a WMS's and back, its texts drawn", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  # the bundle and its base maps' one tile from the same folder: the tiles' addresses ask by zoom and place, and by
  # a WMS's box, each answered with the same picture
  dir <- withr::local_tempdir()
  url <- serve_dir(dir)
  bases <- list(
    list(id = "xyz", label = "Tiles", tiles = paste0(url, "tile.png?z={z}&x={x}&y={y}"), maxzoom = 8,
         attribution = "Own tiles"),
    list(id = "wms", label = "WMS", attribution = "Own WMS",
         tiles = paste0(url, "tile.png?SERVICE=WMS&REQUEST=GetMap&CRS=EPSG:3857&WIDTH=256&HEIGHT=256",
                        "&BBOX={bbox-epsg-3857}")),
    list(id = "none", label = "None")
  )
  pos <- rr_example("trawlsurvey")
  m <- rr_map(pos, basemaps = bases) |>
    rr_point(id = "positions") |>
    rr_text(label = vid, id = "ids")
  rr_bundle(m, dir, overwrite = TRUE)
  one_tile(file.path(dir, "tile.png"))
  b <- open_page(paste0(url, "index.html"))
  asked <- function(re) {
    page_eval(b, sprintf("performance.getEntriesByType('resource').filter(e => /%s/.test(e.name)).length", re))
  }
  # the base map's layers, under the others
  under <- function() setdiff(unlist(page_eval(b, "map.getStyle().layers.map(l => l.id)")), c("positions-dot", "ids-text"))
  drawn <- function() {
    wait_until(function() isTRUE(page_eval(b, "map.loaded() && map.isStyleLoaded()")), 30) &&
      wait_until(function() page_eval(b, 'map.queryRenderedFeatures({ layers: ["ids-text"] }).length') > 0, 30)
  }
  # the first base map opens the page: its tiles asked by zoom and place, the layers over it, the texts drawn though
  # no style has glyphs (MapLibre draws them in the browser's own font)
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('ids-text')")), 40))
  expect_true(drawn())
  expect_identical(under(), c("base-bg", "base"))
  expect_gt(asked("tile\\.png\\?z=\\d+&x=\\d+&y=\\d+$"), 0)
  expect_identical(page_eval(b, "document.querySelector('#bases input:checked').value"), "xyz")
  # a WMS: its box filled in for each tile, the layers kept over it
  page_eval(b, "document.querySelector('#bases input[value=wms]').click() ?? true")
  expect_true(wait_until(function() asked("BBOX=-?\\d+(\\.\\d+)?,-?\\d+(\\.\\d+)?,") > 0, 30))
  expect_true(drawn())
  expect_match(page_eval(b, "map.getSource('base').tiles[0]"), "{bbox-epsg-3857}", fixed = TRUE)
  expect_identical(under(), c("base-bg", "base"))
  # none, then the tiles again
  page_eval(b, "document.querySelector('#bases input[value=none]').click() ?? true")
  expect_true(drawn())
  expect_false(page_eval(b, "!!map.getSource('base')"))
  page_eval(b, "document.querySelector('#bases input[value=xyz]').click() ?? true")
  expect_true(drawn())
  expect_match(page_eval(b, "map.getSource('base').tiles[0]"), "z={z}", fixed = TRUE)
  # the address keeps the base map, and a page opened on it starts there
  expect_true(wait_until(function() grepl("base=wms", page_eval(b, "(document.querySelector('#bases input[value=wms]').click(), location.search)")), 10))
  b2 <- open_page(page_eval(b, "location.href"))
  expect_true(wait_until(function() isTRUE(page_eval(b2, "typeof map !== 'undefined' && map.isStyleLoaded() && /bbox-epsg-3857/.test(map.getSource('base')?.tiles[0])")), 40))
  expect_identical(page_eval(b2, "document.querySelector('#bases input:checked').value"), "wms")
})
