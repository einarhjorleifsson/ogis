# og_names(): place names from their own zoom, found by the Find box, what is known of each on a click, their areas a
# layer of their own; the names given, or the file named by OGIS_NAMES

names_df <- function() {
  data.frame(
    name = c("Hlöðuvík", "Hlöðuvík", "Djúpáll", "Kolaport"),
    label_lon = c(-22.5, -21.1, -23.6, -24.4), label_lat = c(66.4, 65.6, 66.4, 64.9),
    min_zoom = c(7, 8, 5, 6), level = c(3, 4, 1, 2), n = c(3, 1, 1331, 40),
    terrain = c("bay", "bay", "deep", "bank"), depth_m = c(73, 20, 167, 90)
  )
}

# the columns a click on a layer shows, as its row reader gives them
popup_cols <- function(l) vapply(l$row(1)$cols, `[[`, "", "name")

# the names as a GeoParquet file: two of them with an area (one a collection, as a repaired union leaves some), and a
# data dictionary that labels the popup's columns
names_parquet <- function(env = parent.frame()) {
  f <- withr::local_tempfile(fileext = ".parquet", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, "LOAD spatial")
  duckdb::duckdb_register(con, "n", names_df())
  dict <- paste("columns:", "  - {name: terrain, label: Terrain}", "  - {name: depth_m, label: Depth, units: m}",
                sep = "\n")
  DBI::dbExecute(con, sprintf(
    "COPY (SELECT *, CASE
       WHEN name = 'Djúpáll' THEN ST_GeomFromText('GEOMETRYCOLLECTION(POLYGON((-24 66.2, -23.2 66.2, -23.2 66.6, -24 66.6, -24 66.2)), LINESTRING(-24 66, -23 66))')
       WHEN name = 'Kolaport' THEN ST_GeomFromText('POLYGON((-24.6 64.8, -24.2 64.8, -24.2 65, -24.6 65, -24.6 64.8))')
     END AS geometry FROM n) TO '%s' (FORMAT parquet, KV_METADATA {'data_dict': %s})",
    f, DBI::dbQuoteString(con, dict)
  ))
  f
}

test_that("og_names(): the names from their own zoom, by rank, found and shown on a click, their controls folded", {
  skip_if_no_spatial()
  m <- og_names(names_df())
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), "names")
  l <- m$config$layers[[1]]
  expect_true(l$search)
  expect_true(l$fold)
  expect_identical(vapply(m$config$groups, `[[`, "", "title"), "Reference")
  st <- l$style[[1]]
  # the colour and the zoom they appear at are the page's controls (MapLibre's global state)
  expect_identical(st$paint$`text-color`, list("global-state", "names_colour"))
  expect_identical(st$filter, list(">=", list("zoom"), list("-", list("to-number", list("get", "min_zoom")),
                                                            list("global-state", "names_early"))))
  expect_identical(vapply(l$state, `[[`, "", "id"), c("colour", "early"))
  expect_identical(l$state[[1]]$default, "#0b3954")
  expect_identical(l$state[[2]]$default, 0)
  # the larger first where they meet: rank, then n
  expect_identical(st$layout$`symbol-sort-key`, list("*", -1, list("to-number", list("get", "og_priority"))))
  gj <- jsonlite::fromJSON(paste(.og_map_geojson(m$layers$names), collapse = ""))
  p <- gj$features$properties
  expect_identical(p$og_size, c(15.5, 14, 19, 17))
  expect_identical(p$og_priority, c(3, 1, 1331, 40) - 1e5 * c(3, 4, 1, 2))
  # written where the label goes; found by name, the page going to its own zoom
  expect_equal(gj$features$geometry$coordinates[[1]], c(-22.5, 66.4))
  expect_identical(m$layers$names$search$t, names_df()$name)
  expect_equal(m$layers$names$search$z, c(7, 8, 5, 6))
  # the popup: every column but the name's place, zoom, rank and n
  expect_identical(popup_cols(m$layers$names), c("name", "terrain", "depth_m"))
  expect_identical(l$popup$title, "name")

  # the starting look as arguments
  m2 <- og_map() |> og_names(names_df(), colour = "#123456", early = 2, open = TRUE, popup = "terrain", id = "ornefni",
                             name = "Örnefni", section = "Names", visible = FALSE)
  l2 <- m2$config$layers[[1]]
  expect_identical(l2$id, "ornefni")
  expect_identical(l2$label, "Örnefni")
  expect_false(l2$visible)
  expect_null(l2$fold)
  expect_identical(l2$style[[1]]$paint$`text-color`, list("global-state", "ornefni_colour"))
  # a colour of the reader's own is offered first, beside the page's five
  expect_identical(l2$state[[1]]$default, "#123456")
  expect_identical(vapply(l2$state[[1]]$options, `[[`, "", "value"),
                   c("#123456", "#0b3954", "#000000", "#ffffff", "#b2182b", "#ffd92f"))
  expect_identical(l2$state[[2]]$default, 2)
  expect_identical(popup_cols(m2$layers$ornefni), "terrain")

  # with no zoom of their own: every zoom, no control for it; no rank: one size; lon and lat for the label
  d <- names_df()[c("name", "terrain")]
  d$lon <- names_df()$label_lon
  d$lat <- names_df()$label_lat
  l3 <- og_names(d)$config$layers[[1]]
  expect_null(l3$style[[1]]$filter)
  expect_identical(vapply(l3$state, `[[`, "", "id"), "colour")
})

test_that("og_names(): a name turned by its `angle`, counter-clockwise as og_text()'s, a missing one level", {
  skip_if_no_spatial()
  x <- names_df()
  x$angle <- c(30, NA, -45, 0)
  m <- og_names(x)
  st <- m$config$layers[[1]]$style[[1]]
  expect_identical(st$layout[["text-rotate"]], list("*", -1, list("to-number", list("get", "angle"))))
  expect_identical(st$layout[["text-rotation-alignment"]], "map")
  p <- jsonlite::fromJSON(paste(.og_map_geojson(m$layers$names), collapse = ""))$features$properties
  expect_identical(p$angle, c(30, 0, -45, 0))
  # the angle is how the name is drawn, not what a click shows
  expect_false("angle" %in% popup_cols(m$layers$names))
  # and none without the column
  expect_null(og_names(names_df())$config$layers[[1]]$style[[1]]$layout[["text-rotate"]])
})

test_that("a file of names: their areas a layer of their own, off when the page opens, labelled by its dictionary", {
  skip_if_no_spatial()
  f <- names_parquet()
  m <- og_names(f)
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("names_areas", "names"))
  a <- m$config$layers[[1]]
  expect_false(a$visible)
  expect_identical(a$label, "Areas of the names")
  # the two areas only, sent whole (a sea's area would cover thousands of tiles), a click on one showing the name's
  # row as on its label
  expect_identical(a$kind, "geojson")
  expect_equal(a$features, 2)
  expect_identical(popup_cols(m$layers$names_areas), c("name", "terrain", "depth_m"))
  # the dictionary's labels and units, the name's own column where it gives none
  cl <- m$layers$names$row(1)$cols
  expect_identical(vapply(cl, function(x) .og_or(x$label, x$name), ""), c("name", "Terrain", "Depth"))
  expect_identical(cl[[3]]$unit, "m")
  expect_true((og_names(f, areas = TRUE))$config$layers[[1]]$visible)
  # a name with no label place is written on its area; with neither, an error
  d <- names_df()
  d$label_lon[1] <- NA
  expect_identical(length(og_names(d)$layers$names$search$t), 3L)
  expect_error(og_names(data.frame(name = "x", terrain = "bay")), "the names have no place")
})

test_that("a collection (a repaired union's) is drawn as its areas, where a tile with one was refused", {
  skip_if_no_spatial()
  con <- .og_connection()
  x <- dplyr::tbl(con, dplyr::sql(
    "SELECT 1 AS id, ST_GeomFromText('GEOMETRYCOLLECTION(POLYGON((10 56, 11 56, 11 57, 10 57, 10 56)), LINESTRING(10 55, 11 55))') AS geometry"
  ))
  tl <- og_tiles_table(x, properties = "id")
  expect_identical(unname(mvt_count(tl(6, 33, 19))["features"]), 1)
})

test_that("the names: OGIS_NAMES when none is given, a path by its kind, a map started for them given first", {
  skip_if_no_spatial()
  f <- names_parquet()
  withr::local_envvar(OGIS_NAMES = f)
  m <- suppressMessages(og_names())
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("names_areas", "names"))
  m2 <- suppressMessages(og_map() |> og_names())
  expect_identical(vapply(m2$config$layers, `[[`, "", "id"), c("names_areas", "names"))
  expect_message(og_names(f), NA) # a file given: no word of OGIS_NAMES

  withr::local_envvar(OGIS_NAMES = NA)
  expect_error(og_names(), "needs the place names.*OGIS_NAMES.*Renviron")
  expect_error(og_names(file.path(tempdir(), "no-such.parquet")), "no such file")
  withr::local_envvar(OGIS_NAMES = file.path(tempdir(), "no-such-names.parquet"))
  expect_error(og_names(), "OGIS_NAMES names .*no such file")
  expect_error(og_names(names_df(), names_df()), "the place names go to `names`")
  expect_error(og_names(data.frame(place = "x", lon = 1, lat = 2)), "no column `name`")
  expect_error(og_names(names_df(), colour = "red"), "#rrggbb")
  expect_error(og_names(names_df(), early = 3), "-1, 0, 1 or 2")
  expect_error(og_names(names_df(), areas = NA), "`areas` is TRUE or FALSE")
  expect_error(og_names(names_df(), popup = c("terrain", "nope")), "nope")
  expect_error(og_names(names_df(), open = "yes"), "`open` is TRUE or FALSE")
})

test_that("in the page, the Find box finds a name typed without its letters (ð as d, þ as th, æ as ae)", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  d <- names_df()
  d$name[3] <- "Þverá við Æðey"
  og_bundle(og_map(view = list(center = c(-22.5, 66), zoom = 6)) |> og_names(d), dir, overwrite = TRUE)
  b <- open_page(paste0(serve_dir(dir), "index.html"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && map.loaded() && !!map.getLayer('names-text')")), 40))
  hits <- function(text) {
    page_eval(b, sprintf("(() => { const q = document.getElementById('find-q'); q.value = %s; q.dispatchEvent(new Event('input')); return true; })()",
                         jsonlite::toJSON(text, auto_unbox = TRUE)))
    wait_until(function() page_eval(b, "document.querySelectorAll('#find-hits li').length") > 0, 20)
    unlist(page_eval(b, "[...document.querySelectorAll('#find-hits li')].map(li => li.textContent)"))
  }
  expect_length(grep("^Hlöðuvík · ", hits("hloduvik")), 2)
  expect_match(hits("thvera vid aedey")[1], "^Þverá við Æðey · ")
  expect_identical(hits("HLÖÐU"), hits("hlodu"))
  # the controls, folded, then shown: the colour applies as it changes
  expect_identical(page_eval(b, "document.getElementById('names-fold').getAttribute('aria-expanded')"), "false")
  page_eval(b, "(() => { const s = document.getElementById('names-s-colour'); s.value = '#b2182b'; s.dispatchEvent(new Event('change')); return true; })()")
  expect_identical(page_eval(b, "map.getGlobalState().names_colour"), "#b2182b")
})
