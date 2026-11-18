# og_text(): labels with a start zoom by row, an angle, a priority, a face and an offset

names_data <- function() {
  data.frame(
    lon = c(-20, -19, -18, -17, -21), lat = c(64, 64.5, 65, 65.5, 63.6),
    name = c("Alfa", "Bravó", "Charlie", "Delta", "Echo"),
    z = c(3, 5.4, 7, 9.2, 15.5), rot = c(0, 30, -15, 90, 0), imp = c(1, 4, 2, 3, 5),
    face = c("plain", "italic", "bold", "bold.italic", "plain"), dy = c(0, 1, -1, 0, 0)
  )
}

test_that("og_text() writes its aesthetics in MapLibre's terms", {
  skip_if_no_spatial()
  m <- og_map() |>
    og_text(names_data(), label = name, minzoom = z, angle = rot, priority = imp, fontface = face, offset = c(0, dy),
            size = 15, name = "Names")
  st <- m$config$layers[[1]]$style
  expect_length(st, 1)
  expect_identical(st[[1]]$filter, list(">=", list("zoom"), list("to-number", list("get", "z"))))
  lay <- st[[1]]$layout
  expect_identical(lay[["text-rotate"]], list("*", -1, list("to-number", list("get", "rot")))) # counter-clockwise
  expect_identical(lay[["symbol-sort-key"]], list("*", -1, list("to-number", list("get", "imp")))) # higher first
  expect_identical(lay[["text-rotation-alignment"]], "map")
  expect_identical(lay[["text-size"]], 15)
  expect_identical(st[[1]]$og_face, list("get", "face"))
  off <- lay[["text-offset"]]
  expect_identical(off[[1]], "match")
  expect_true("0.000|1.000" %in% unlist(off)) # a row a line up: y up, MapLibre's down
  i <- which(vapply(off, identical, logical(1), "0.000|1.000"))
  expect_equal(off[[i + 1]][[2]], c(0, -1))
  # the features carry what the style reads
  feats <- jsonlite::fromJSON(.og_map_geojson(m$layers[[1]]), simplifyVector = FALSE)$features
  expect_true(all(c("z", "rot", "imp", "face", "og_off", "name") %in% names(feats[[1]]$properties)))
  # values in place of columns
  v <- (og_map() |> og_text(names_data(), label = name, angle = 20, fontface = "italic", offset = c(0.5, 1),
                            minzoom = 6, overlap = TRUE))$config$layers[[1]]
  expect_identical(v$style[[1]]$layout[["text-rotate"]], -20)
  expect_identical(v$style[[1]]$layout[["text-offset"]], c(0.5, -1))
  expect_true(v$style[[1]]$layout[["text-allow-overlap"]])
  expect_identical(v$style[[1]]$og_face, "italic")
  expect_identical(v$minzoom, 6)
  expect_error(og_map() |> og_text(names_data(), label = name, fontface = "heavy"), "fontface")
  expect_error(og_map() |> og_text(names_data(), label = name, offset = c(0, "up")), "offset")
  expect_error(og_map() |> og_text(names_data(), label = name, overlap = NA), "overlap")
})

test_that("text on lines is written along them, text at points as before", {
  skip_if_no_spatial()
  tows <- og_example("trawlsurveytows")
  m <- og_map() |> og_text(tows, label = id.lgs, name = "Tow ids")
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
    m <- og_map() |>
      og_text(names_data(), label = name, minzoom = z, fontface = face, overlap = TRUE, whole = whole, name = "Names")
    og_bundle(m, dir, overwrite = TRUE)
    b <- open_page(paste0(serve_dir(dir), "index.html"))
    d <- names_data()
    # whether a name is drawn with the view on it at a zoom: asked once MapLibre is idle (its tiles loaded and its
    # labels placed, their fade done); a fixed wait after map.loaded() came too soon on a slower runner (Ubuntu, CI)
    shown <- function(name, zoom) {
      i <- match(name, d$name)
      page_eval(b, sprintf(paste0("(window.IDLE = false, map.once('idle', () => window.IDLE = true), ",
                                  "map.jumpTo({ center: [%f, %f], zoom: %s }), map.triggerRepaint(), true)"),
                           d$lon[i], d$lat[i], zoom))
      expect_true(wait_until(function() isTRUE(page_eval(b, "window.IDLE")), 30), info = paste(name, zoom))
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

test_that("a view and base maps given to og_map() hold for its layer functions' map", {
  skip_if_no_spatial()
  bases <- og_basemaps()[c(4, 1)]
  m <- og_map(view = list(bounds = c(8, 54.5, 13, 58)), basemaps = bases) |>
    og_polygon(og_example("dansk_harbours"))
  expect_equal(unlist(m$config$view$bounds), c(8, 54.5, 13, 58))
  expect_identical(vapply(m$config$basemaps, `[[`, "", "id"), vapply(bases, `[[`, "", "id"))
  m <- og_map(og_example("trawlsurvey"), view = list(center = c(-20, 65), zoom = 6)) |> og_point()
  expect_equal(unlist(m$config$view$center), c(-20, 65))
  expect_null(m$config$view$bounds)
  # none given: the rows' extent and every base map, as before
  m <- og_map(og_example("trawlsurvey")) |> og_point()
  expect_length(unlist(m$config$view$bounds), 4)
  expect_identical(length(m$config$basemaps), length(og_basemaps()))
})

test_that("endzoom: a row's own end in the filter, one for all as the styles' maxzoom, a row with none shown on", {
  skip_if_no_spatial()
  d <- data.frame(lon = c(-20, -19), lat = c(64, 65), name = c("A", "B"), z = c(3, 5.4), e = c(6, NA))
  st <- (og_map() |> og_text(d, label = name, minzoom = z, endzoom = e, id = "t"))$config$layers[[1]]$style[[1]]
  expect_identical(st$filter, list("all",
    list(">=", list("zoom"), list("to-number", list("get", "z"))),
    list("<", list("zoom"), list("to-number", list("coalesce", list("get", "e"), 99)))))
  expect_null(st$maxzoom)
  st <- (og_map() |> og_text(d, label = name, endzoom = 9, id = "t"))$config$layers[[1]]$style[[1]]
  expect_identical(st$maxzoom, 9)
  expect_null(st$filter)
  # an end alone, as a column
  st <- (og_map() |> og_text(d, label = name, endzoom = e, id = "t"))$config$layers[[1]]$style[[1]]
  expect_identical(st$filter[[1]], "<")
  expect_error(og_map() |> og_text(d, label = name, minzoom = 8, endzoom = 6), "after `minzoom`")
  expect_error(og_map() |> og_text(d, label = name, endzoom = 30), "a zoom from 0 to 24")
  expect_error(og_map() |> og_text(d, label = name, endzoom = c(z, e)), "one column")
  # a search knows each row's end
  f <- (og_map() |> og_text(d, label = name, minzoom = z, endzoom = e, search = name, id = "t"))$layers$t$search
  expect_equal(f$e, c(6, NA))
})

test_that("in the page, a row's text shows until the first whole zoom at or above its own end, whole and as tiles", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  d <- data.frame(lon = c(-20, -19, -18), lat = c(64, 64.5, 65), name = c("Alfa", "Bravó", "Charlie"),
                  z = c(3, NA, 4), e = c(6, 7.4, NA))
  for (whole in c(TRUE, FALSE)) {
    w <- paste("whole:", whole)
    dir <- withr::local_tempdir()
    m <- og_map(basemaps = list(list(id = "none", label = "None"))) |>
      og_text(d, label = name, minzoom = z, endzoom = e, overlap = TRUE, whole = whole, search = name, id = "names")
    og_bundle(m, dir, overwrite = TRUE)
    b <- open_page(paste0(serve_dir(dir), "index.html"))
    expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && map.loaded() && !!map.getLayer('names-text')")), 30), info = w)
    shown <- function(name, zoom) {
      i <- match(name, d$name)
      page_eval(b, sprintf(paste0("(window.IDLE = false, map.once('idle', () => window.IDLE = true), ",
                                  "map.jumpTo({ center: [%f, %f], zoom: %s }), map.triggerRepaint(), true)"), d$lon[i], d$lat[i], zoom))
      expect_true(wait_until(function() isTRUE(page_eval(b, "window.IDLE")), 30), info = paste(w, name, zoom))
      name %in% unlist(page_eval(b, 'map.queryRenderedFeatures({ layers: ["names-text"] }).map(f => f.properties.name)'))
    }
    expect_true(shown("Alfa", 5.9), info = w)       # from 3, to 6
    expect_false(shown("Alfa", 6), info = w)
    expect_true(shown("Bravó", 7.9), info = w)      # no start, to 7.4: through zoom 7
    expect_false(shown("Bravó", 8), info = w)
    expect_true(shown("Charlie", 12), info = w)     # from 4, no end
    # a search takes the map to a zoom where the label shows: before its end, from a deeper view
    page_eval(b, "(map.jumpTo({ center: [-18, 65], zoom: 13 }), true)")
    page_eval(b, "(() => { const q = document.getElementById('find-q'); q.value = 'Alfa'; q.dispatchEvent(new Event('input')); return true; })()")
    expect_true(wait_until(function() page_eval(b, "document.querySelectorAll('#find-hits li').length") > 0, 20), info = w)
    page_eval(b, "document.querySelector('#find-hits li:not(.muted)').click() ?? true")
    expect_true(wait_until(function() isTRUE(page_eval(b, "!!document.querySelector('.maplibregl-popup')")), 20), info = w)
    expect_identical(page_eval(b, "map.getZoom()"), 5L, info = w)
    b$close()
  }
})

test_that("in the page, a layer's minzoom as a number holds for a layer sent whole, as for one in tiles", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  d <- data.frame(lon = c(-20, -19.9), lat = c(64, 64.05), name = c("Alfa", "Bravó"))
  for (whole in c(TRUE, FALSE)) {
    w <- paste("whole:", whole)
    dir <- withr::local_tempdir()
    m <- og_map(basemaps = list(list(id = "none", label = "None"))) |>
      og_point(d, minzoom = 8, whole = whole, id = "dots") |>
      og_text(d, label = name, minzoom = 9, endzoom = 11, overlap = TRUE, whole = whole, id = "names")
    og_bundle(m, dir, overwrite = TRUE)
    b <- open_page(paste0(serve_dir(dir), "index.html"))
    expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && map.loaded() && !!map.getLayer('names-text')")), 30), info = w)
    drawn <- function(layer, zoom) {
      page_eval(b, sprintf(paste0("(window.IDLE = false, map.once('idle', () => window.IDLE = true), ",
                                  "map.jumpTo({ center: [-19.95, 64.025], zoom: %s }), map.triggerRepaint(), true)"), zoom))
      expect_true(wait_until(function() isTRUE(page_eval(b, "window.IDLE")), 30), info = paste(w, layer, zoom))
      page_eval(b, sprintf("map.queryRenderedFeatures({ layers: ['%s'] }).length", layer))
    }
    expect_identical(drawn("dots-dot", 7.5), 0L, info = w)
    expect_gt(drawn("dots-dot", 8), 0, label = w)
    expect_identical(drawn("names-text", 8.5), 0L, info = w)
    expect_gt(drawn("names-text", 9), 0, label = w)
    expect_gt(drawn("names-text", 10.9), 0, label = w)
    expect_identical(drawn("names-text", 11), 0L, info = w)
    b$close()
  }
})
