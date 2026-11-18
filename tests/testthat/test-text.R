# rr_text(): labels with a start zoom by row, an angle, a priority, a face and an offset

names_data <- function() {
  data.frame(
    lon = c(-20, -19, -18, -17, -21), lat = c(64, 64.5, 65, 65.5, 63.6),
    name = c("Alfa", "Bravó", "Charlie", "Delta", "Echo"),
    z = c(3, 5.4, 7, 9.2, 15.5), rot = c(0, 30, -15, 90, 0), imp = c(1, 4, 2, 3, 5),
    face = c("plain", "italic", "bold", "bold.italic", "plain"), dy = c(0, 1, -1, 0, 0)
  )
}

test_that("rr_text() writes its aesthetics in MapLibre's terms", {
  skip_if_no_spatial()
  m <- rr_map() |>
    rr_text(names_data(), label = name, minzoom = z, angle = rot, priority = imp, fontface = face, offset = c(0, dy),
            size = 15, name = "Names")
  st <- m$config$layers[[1]]$style
  expect_length(st, 1)
  expect_identical(st[[1]]$filter, list(">=", list("zoom"), list("to-number", list("get", "z"))))
  lay <- st[[1]]$layout
  expect_identical(lay[["text-rotate"]], list("*", -1, list("to-number", list("get", "rot")))) # counter-clockwise
  expect_identical(lay[["symbol-sort-key"]], list("*", -1, list("to-number", list("get", "imp")))) # higher first
  expect_identical(lay[["text-rotation-alignment"]], "map")
  expect_identical(lay[["text-size"]], 15)
  expect_identical(st[[1]]$rr_face, list("get", "face"))
  off <- lay[["text-offset"]]
  expect_identical(off[[1]], "match")
  expect_true("0.000|1.000" %in% unlist(off)) # a row a line up: y up, MapLibre's down
  i <- which(vapply(off, identical, logical(1), "0.000|1.000"))
  expect_equal(off[[i + 1]][[2]], c(0, -1))
  # the features carry what the style reads
  feats <- jsonlite::fromJSON(.rr_map_geojson(m$layers[[1]]), simplifyVector = FALSE)$features
  expect_true(all(c("z", "rot", "imp", "face", "rr_off", "name") %in% names(feats[[1]]$properties)))
  # values in place of columns
  v <- (rr_map() |> rr_text(names_data(), label = name, angle = 20, fontface = "italic", offset = c(0.5, 1),
                            minzoom = 6, overlap = TRUE))$config$layers[[1]]
  expect_identical(v$style[[1]]$layout[["text-rotate"]], -20)
  expect_identical(v$style[[1]]$layout[["text-offset"]], c(0.5, -1))
  expect_true(v$style[[1]]$layout[["text-allow-overlap"]])
  expect_identical(v$style[[1]]$rr_face, "italic")
  expect_identical(v$minzoom, 6)
  expect_error(rr_map() |> rr_text(names_data(), label = name, fontface = "heavy"), "fontface")
  expect_error(rr_map() |> rr_text(names_data(), label = name, offset = c(0, "up")), "offset")
  expect_error(rr_map() |> rr_text(names_data(), label = name, overlap = NA), "overlap")
})

test_that("text on lines is written along them, text at points as before", {
  skip_if_no_spatial()
  tows <- rr_example("trawlsurveytows")
  m <- rr_map() |> rr_text(tows, label = id.lgs, name = "Tow ids")
  st <- m$config$layers[[1]]$style
  expect_identical(vapply(st, `[[`, "", "id"), c("tow_ids-text", "tow_ids-text-line"))
  expect_identical(st[[2]]$layout[["symbol-placement"]], "line-center")
})

test_that("in the page, a row's text shows from the first whole zoom at or above its own, whole and as tiles", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  skip_if_offline("tiles.basemaps.cartocdn.com") # the base map's fonts
  for (whole in c(TRUE, FALSE)) {
    dir <- withr::local_tempdir()
    m <- rr_map() |>
      rr_text(names_data(), label = name, minzoom = z, fontface = face, overlap = TRUE, whole = whole, name = "Names")
    rr_bundle(m, dir, overwrite = TRUE)
    b <- open_page(paste0(serve_dir(dir), "index.html"))
    d <- names_data()
    # whether a name is drawn with the view on it at a zoom
    shown <- function(name, zoom) {
      i <- match(name, d$name)
      page_eval(b, sprintf("map.jumpTo({ center: [%f, %f], zoom: %s }) && true", d$lon[i], d$lat[i], zoom))
      wait_until(function() isTRUE(page_eval(b, "map.loaded()")), 20)
      later::run_now(0.3)
      wait_until(function() isTRUE(page_eval(b, "map.loaded()")), 20)
      name %in% unlist(page_eval(b, 'map.queryRenderedFeatures({ layers: ["names-text"] }).map(f => f.properties.name)'))
    }
    expect_true(wait_until(function() isTRUE(page_eval(b, 'map.loaded() && !!map.getLayer("names-text")')), 30))
    w <- paste("whole:", whole)
    expect_true(shown("Alfa", 3), info = w)
    expect_false(shown("Bravó", 5.9), info = w) # due at 5.4: from 6
    expect_true(shown("Bravó", 6), info = w)
    expect_false(shown("Delta", 9.99), info = w) # 9.2: from 10
    expect_true(shown("Delta", 10), info = w)
    # past the tiles' deepest zoom (14) the start still holds: 15.5, from 16
    expect_false(shown("Echo", 15.9), info = w)
    expect_true(shown("Echo", 16), info = w)
    # each face in the base map's own fonts for it
    font <- jsonlite::toJSON(page_eval(b, 'map.getLayoutProperty("names-text", "text-font")'), auto_unbox = TRUE)
    expect_match(font, "Italic")
    b$close()
  }
})

test_that("a view and base maps given to rr_map() hold for its layer functions' map", {
  skip_if_no_spatial()
  bases <- rr_basemaps()[c(4, 1)]
  m <- rr_map(view = list(bounds = c(8, 54.5, 13, 58)), basemaps = bases) |>
    rr_polygon(rr_example("dansk_harbours"))
  expect_equal(unlist(m$config$view$bounds), c(8, 54.5, 13, 58))
  expect_identical(vapply(m$config$basemaps, `[[`, "", "id"), vapply(bases, `[[`, "", "id"))
  m <- rr_map(rr_example("trawlsurvey"), view = list(center = c(-20, 65), zoom = 6)) |> rr_point()
  expect_equal(unlist(m$config$view$center), c(-20, 65))
  expect_null(m$config$view$bounds)
  # none given: the rows' extent and every base map, as before
  m <- rr_map(rr_example("trawlsurvey")) |> rr_point()
  expect_length(unlist(m$config$view$bounds), 4)
  expect_identical(length(m$config$basemaps), length(rr_basemaps()))
})
