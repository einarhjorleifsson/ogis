# A bundle opened from its folder (file://), as a double click opens it: no server, MapLibre and its worker read from
# the bundle's own files. Every other page test opens its page over http.

# A file's address, on any system (C:/... on Windows as file:///C:/...)
file_url <- function(path) {
  p <- normalizePath(path, winslash = "/", mustWork = TRUE)
  paste0("file://", if (startsWith(p, "/")) "" else "/", utils::URLencode(p))
}

test_that("a bundle opened from its folder draws: points, labels, outlines and contours made in the page", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  relief <- og_tiles_dem(og_example("dansk_relief"), maxzoom = 6)
  contours <- og_layer("lines", "contour", label = "Contours", tiles = relief,
                       style = list(list(id = "lines-line", type = "line", "source-layer" = "contours")),
                       contours = list(thresholds = list("5" = c(10, 50)), multiplier = -1))
  harbours <- og_example("dansk_harbours")
  m <- og_map(view = list(bounds = c(8, 54.5, 13, 58)), basemaps = list(list(id = "none", label = "None"))) |>
    og_add_layer(contours, section = "Sea floor") |>
    og_polygon(harbours, fill = NA, colour = "#b2182b", id = "harbours") |>
    og_text(harbours, label = SI_HARB, id = "ids")
  dir <- withr::local_tempdir()
  og_bundle(m, dir, overwrite = TRUE, maxzoom = 6)
  b <- open_page(file_url(file.path(dir, "index.html")))
  drawn <- function(id) page_eval(b, sprintf("map.getLayer('%s') ? map.queryRenderedFeatures({ layers: ['%s'] }).length : -1", id, id))
  expect_true(wait_until(function() {
    isTRUE(page_eval(b, "typeof map !== 'undefined' && map.loaded()")) && drawn("harbours-fill") > 0 && drawn("ids-text") > 0 &&
      drawn("lines-line") > 0
  }, 60))
  expect_identical(page_eval(b, "location.protocol"), "file:")
  expect_match(page_eval(b, "maplibregl.getVersion()"), "^6\\.")
  # the contours are drawn by maplibre-contour from the bundle's elevation tiles, in the page
  expect_gt(drawn("lines-line"), 0)
})
