# og_cells(): values by cell coloured per km², chosen by the cells' other columns; summed by DuckDB to about a pixel a
# zoom as the page asks, or by the browser in a bundle; the cells given, or the file named by OGIS_CELLS

# five 0.01-degree cells (corners in thousandths of a degree) off Iceland: trawl in all five, longline in one; two
# presets (two counts of the same hours), 2020 and 2021
cells_df <- function() {
  d <- expand.grid(ix = c(-23000, -22990, -22980, -22970, -22960), iy = 65000, gear = c("trawl", "longline"),
                   preset = c("haul", "flow"), year = c(2020L, 2021L), stringsAsFactors = FALSE)
  d <- d[d$gear == "trawl" | d$ix == -23000, ]
  d$hours <- ifelse(d$gear == "trawl", 2, 10) * ifelse(d$preset == "flow", 1.5, 1)
  d$kwh <- d$hours * 500
  d$n <- 3L
  d
}

# the tile over the cells at zoom z, as og_cells() makes it for the page's choices
tile_at <- function(l, z, params = list(), lon = -22.98, lat = 65.005) {
  x <- floor((lon + 180) / 360 * 2^z)
  y <- floor((1 - log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) / 2 * 2^z)
  unname(mvt_count(l$tiles(z, x, y, params))["cells"])
}

test_that("og_cells(): a grid layer of the cells' values per km², a control for each column chosen by", {
  skip_if_no_spatial()
  m <- og_cells(cells_df(), one_of = "preset", name = "Fishing effort")
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), "cells")
  expect_identical(vapply(m$config$groups, `[[`, "", "title"), "Fishing effort")
  l <- m$layers$cells
  cf <- l$config
  expect_identical(cf$kind, "grid")
  expect_identical(cf$label, "Fishing effort")
  # gear and preset as lists (all first, but for a one_of), the year as a span, the value coloured, the cells' size
  expect_identical(vapply(cf$filters, `[[`, "", "id"), c("cells_gear", "cells_preset", "cells_year", "metric", "cells_px"))
  f <- stats::setNames(cf$filters, vapply(cf$filters, `[[`, "", "id"))
  expect_identical(f$cells_gear$options[[1]]$value, "")
  expect_length(f$cells_preset$options, 0)
  expect_identical(f$cells_year$type, "range")
  expect_identical(unlist(f$cells_year$params), c("cells_year_from", "cells_year_to"))
  expect_identical(vapply(cf$metrics, `[[`, "", "field"), c("hours_km2", "kwh_km2"))
  expect_identical(vapply(cf$metrics, `[[`, "", "label"), c("hours per km²", "kwh per km²"))
  expect_identical(vapply(cf$popup$fields, `[[`, "", "field"), c("hours_km2", "kwh_km2", "n"))
  expect_identical(cf$opacity, 85)
  # where the cells lie, the map's first view
  expect_equal(unlist(cf$bounds), c(-23, 65, -22.95, 65.01))
  # the lists' values by their share of the first value, a one_of's in their own order; the years' span
  mt <- l$meta()
  expect_identical(mt$options$cells_gear$value, c("trawl", "longline"))
  expect_identical(mt$options$cells_preset$value, c("flow", "haul"))
  expect_identical(mt$ranges$cells_year, c(2020L, 2021L))
  # what the page opens with
  expect_identical(cf$start[c("palette", "stretch", "opacity")], list(palette = "magma", stretch = "even", opacity = 85))

  # the start as arguments; codes naming a column's values
  m2 <- og_cells(cells_df(), one_of = "preset", filter = list(gear = c("trawl", "longline"), year = 2021, preset = "haul"),
                 metric = "kwh", palette = "blues", opacity = 60, limits = c(0.5, 50), stretch = "equal",
                 codes = list(gear = c(trawl = "Bottom trawl (OTB)")), id = "effort", section = "Effort")
  s2 <- m2$layers$effort$config$start
  expect_identical(s2[c("palette", "stretch", "opacity", "floor", "cap", "metric")],
                   list(palette = "blues", stretch = "equal", opacity = 60, floor = 0.5, cap = 50, metric = "kwh_km2"))
  expect_identical(s2[c("effort_gear", "effort_year_from", "effort_year_to", "effort_preset")],
                   list(effort_gear = "trawl,longline", effort_year_from = "2021", effort_year_to = "2021",
                        effort_preset = "haul"))
  expect_identical(m2$layers$effort$meta()$options$effort_gear$name, c("Bottom trawl (OTB)", NA))
  # labels of the reader's own
  l3 <- og_cells(cells_df(), labels = c(gear = "Gear", hours = "Hours"))$config$layers[[1]]
  expect_identical(l3$filters[[1]]$label, "Gear")
  expect_identical(l3$metrics[[1]]$label, "Hours per km²")
  expect_error(og_cells(cells_df(), labels = "Gear"), "named character vector")
  # one value coloured: no choice of it
  expect_false("metric" %in% vapply(og_cells(cells_df(), values = "hours")$config$layers[[1]]$filters, `[[`, "", "id"))
})

test_that("a tile: the cells summed to about a pixel at its zoom, no finer than their own, the choices applied", {
  skip_if_no_spatial()
  l <- og_cells(cells_df(), one_of = "preset")$layers$cells
  # zoom 9: a pixel is 0.0014 degrees, the cells' own 0.01 the finest; zoom 1, a pixel 0.35 degrees: one cell of 0.3
  expect_identical(tile_at(l, 9), 5)
  expect_identical(tile_at(l, 1), 1)
  # zoom 3, a pixel 0.088 degrees: cells of 0.07, on whose edge the five lie
  expect_identical(tile_at(l, 3), 2)
  expect_identical(tile_at(l, 9, list(cells_gear = "longline")), 1)
  expect_identical(tile_at(l, 9, list(cells_gear = "trawl,longline", cells_year_from = "2021", cells_year_to = "2021")), 5)
  # coarser: two pixels a cell (at zoom 6, 0.011 degrees a pixel: 0.01-degree cells, then 0.02)
  expect_identical(tile_at(l, 6), 5)
  expect_identical(tile_at(l, 6, list(cells_px = "2")), 3)
  # none where there are no cells
  expect_identical(unname(mvt_count(l$tiles(9, 0, 0, list()))["cells"] %||% 0), 0)
})

test_that("served: the choices checked against the cells' own values; bundled with no word of its rows", {
  skip_if_no_spatial()
  m <- og_cells(cells_df(), one_of = "preset")
  app <- .og_map_app(m)
  get <- function(path, q = "") app$call(list(REQUEST_METHOD = "GET", PATH_INFO = path, QUERY_STRING = q,
                                              HTTP_HOST = "localhost:8811"))
  meta <- jsonlite::fromJSON(get("/meta")$body)
  expect_identical(meta$layers$cells$options$cells_gear$value, c("trawl", "longline"))
  z <- 9
  x <- floor((-22.98 + 180) / 360 * 2^z)
  y <- floor((1 - log(tan(65.005 * pi / 180) + 1 / cos(65.005 * pi / 180)) / pi) / 2 * 2^z)
  ok <- get(sprintf("/tiles/cells/%d/%d/%d.pbf", z, x, y), "cells_gear=longline&cells_preset=haul")
  expect_identical(ok$status, 200L)
  expect_identical(unname(mvt_count(ok$body)["cells"]), 1)
  expect_identical(get(sprintf("/tiles/cells/%d/%d/%d.pbf", z, x, y), "cells_gear=seine")$status, 400L)
  expect_identical(get(sprintf("/tiles/cells/%d/%d/%d.pbf", z, x, y), "cells_year_from=1990&cells_year_to=2021")$status, 400L)

  dir <- withr::local_tempdir()
  expect_no_message(og_bundle(m, dir, overwrite = TRUE), message = "Left out")
  expect_true(dir.exists(file.path(dir, "grids", "cells")))
  # the cells at sizes from 0.01 degrees up (their own here), and the c-square's 0.05, in steps of their thousandths
  expect_setequal(list.files(file.path(dir, "grids", "cells")), c("10", "20", "40", "50", "100", "200", "500"))
})

test_that("a Parquet file: read where it is, labelled by its dictionary; OGIS_CELLS when none is given", {
  skip_if_no_spatial()
  f <- withr::local_tempfile(fileext = ".parquet")
  con <- DBI::dbConnect(duckdb::duckdb())
  duckdb::duckdb_register(con, "c", cells_df()[cells_df()$preset == "haul", setdiff(names(cells_df()), "preset")])
  dict <- jsonlite::toJSON(list(columns = list(
    list(name = "gear", label = "Gear", values = list(trawl = "Botnvarpa (OTB)", longline = "Lína (LLS)")),
    list(name = "hours", label = "Hours"), list(name = "n", label = "Fixes")
  )), auto_unbox = TRUE)
  DBI::dbExecute(con, sprintf("COPY (SELECT * FROM c ORDER BY ix, iy) TO '%s' (FORMAT parquet, KV_METADATA {'data_dict': %s})",
                              f, DBI::dbQuoteString(con, dict)))
  DBI::dbDisconnect(con, shutdown = TRUE)
  m <- og_cells(f)
  cf <- m$config$layers[[1]]
  expect_identical(cf$filters[[1]]$label, "Gear")
  expect_identical(cf$metrics[[1]]$label, "Hours per km²")
  expect_identical(cf$popup$fields[[3]]$label, "Fixes")
  expect_identical(m$layers$cells$meta()$options$cells_gear$name, c("Botnvarpa (OTB)", "Lína (LLS)"))
  expect_match(m$layers$cells$meta()$v, "^[0-9.]+$")

  withr::local_envvar(OGIS_CELLS = f)
  expect_identical(suppressMessages(og_map() |> og_cells())$config$layers[[1]]$id, "cells")
  withr::local_envvar(OGIS_CELLS = NA)
  expect_error(og_cells(), "needs the cells.*OGIS_CELLS.*Renviron")
  withr::local_envvar(OGIS_CELLS = file.path(tempdir(), "no-such-cells.parquet"))
  expect_error(og_cells(), "OGIS_CELLS names .*no such file")
  expect_error(og_cells(file.path(tempdir(), "cells.csv")), "no such file")
})

test_that("og_cells(): its arguments checked", {
  skip_if_no_spatial()
  d <- cells_df()
  expect_error(og_cells(d[c("gear", "hours")]), "corners")
  expect_error(og_cells(d[c("ix", "iy", "gear")]), "no `values`")
  expect_error(og_cells(d, by = "nope"), "`by` names columns")
  expect_error(og_cells(d, filter = list(nope = 1)), "`filter` is a list")
  expect_error(og_cells(d, filter = list(year = "2020")), "first and last of a span")
  expect_error(og_cells(d, one_of = "preset", filter = list(preset = c("haul", "flow"))), "one value")
  expect_error(og_cells(d, metric = "n"), "`metric` is one of `values`")
  expect_error(og_cells(d, palette = "nonesuch"), "palettes for a grid")
  expect_error(og_cells(d, limits = c(5, 1)), "floor below the cap")
  expect_error(og_cells(d, opacity = 120), "percentage")
  expect_error(og_cells(d, d), "the cells go to `cells`")
  expect_error(og_cells(og_map(), d) |> og_cells(d, id = "more"), "one grid layer")
  expect_error(og_cells(transform(d, ix = ix + 0.5)), "whole steps of `unit`")
  names(d)[names(d) == "gear"] <- "gear type"
  expect_error(og_cells(d), "rename gear type")
  names(d)[names(d) == "gear type"] <- "px"
  expect_error(og_cells(d), "rename px")
})

test_that("in the page (a bundle): the cells drawn with the choices and colours given, the address winning", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  m <- og_map(view = list(center = c(-22.98, 65.005), zoom = 9)) |>
    og_cells(cells_df(), one_of = "preset", filter = list(gear = "longline", preset = "haul"), palette = "blues",
             limits = c(1, 100))
  og_bundle(m, dir, overwrite = TRUE)
  b <- open_page(paste0(serve_dir(dir), "index.html"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('cells') && map.loaded() && map.areTilesLoaded()")), 40))
  st <- function() page_eval(b, paste(
    "({ gear: document.getElementById('cells_gear').value, preset: document.getElementById('cells_preset').value,",
    "   palette: document.getElementById('palette').value, lo: +document.getElementById('lo').value,",
    "   hi: +document.getElementById('hi').value,",
    "   n: map.querySourceFeatures('cells', { sourceLayer: 'cells' }).length })"
  ))
  expect_true(wait_until(function() st()$n > 0, 20))
  s <- st()
  expect_identical(s[c("gear", "preset", "palette")], list(gear = "longline", preset = "haul", palette = "blues"))
  expect_equal(c(s$lo, s$hi), c(0, 2))
  # the longline's one cell, then every gear's five
  expect_identical(length(unique(unlist(page_eval(b, "map.querySourceFeatures('cells', { sourceLayer: 'cells' }).map(f => f.properties.hours_km2.toFixed(3))")))), 1L)
  page_eval(b, "(() => { const g = document.getElementById('cells_gear'); g.value = ''; g.dispatchEvent(new Event('change')); return true; })()")
  expect_true(wait_until(function() {
    v <- unlist(page_eval(b, "map.querySourceFeatures('cells', { sourceLayer: 'cells' }).map(f => f.properties.hours_km2.toFixed(3))"))
    length(unique(v)) == 2
  }, 20))
  # the address wins over what the layer starts with
  b2 <- open_page(paste0(serve_dir(dir), "index.html?cells_gear=trawl&palette=magma"))
  expect_true(wait_until(function() isTRUE(page_eval(b2, "typeof map !== 'undefined' && !!map.getLayer('cells')")), 40))
  expect_identical(page_eval(b2, "document.getElementById('cells_gear').value"), "trawl")
  expect_identical(page_eval(b2, "document.getElementById('palette').value"), "magma")
})

test_that("in the page (served): the cells drawn with the choices given, the address winning", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  # a guard (2026-11-19): a served map's `filter` was reported to open at "all" and no years, drawing nothing; it did
  # not, but nothing served tested it in a browser
  m <- og_map(view = list(center = c(-22.98, 65.005), zoom = 9)) |>
    og_cells(cells_df(), one_of = "preset", filter = list(gear = "longline", preset = "haul", year = c(2021, 2021)))
  url <- og_serve(m, open = FALSE, wait = FALSE)
  withr::defer(og_stop(as.integer(sub(".*:([0-9]+)/$", "\\1", url))))
  # hours per km² of one 0.01-degree cell at 65 N, as the tiles compute it
  per_km2 <- function(h) h / ((10 * 0.001 * 111.32 * cos(65.005 * pi / 180)) * (10 * 0.001 * 110.574))
  st <- function(b) page_eval(b, paste(
    "({ gear: document.getElementById('cells_gear').value, preset: document.getElementById('cells_preset').value,",
    "   from: document.getElementById('cells_year_from').value, to: document.getElementById('cells_year_to').value,",
    "   years: document.getElementById('cells_year_from').options.length, search: location.search,",
    "   hours: [...new Set(map.querySourceFeatures('cells', { sourceLayer: 'cells' }).map(f => f.properties.hours_km2))] })"
  ))
  drawn <- function(b) {
    wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('cells') && map.loaded() && map.areTilesLoaded()")), 40) &&
      wait_until(function() length(st(b)$hours) > 0, 20)
  }
  # the choices given: the longline's one cell in 2021, its controls set from the options /meta gave
  b <- open_page(url)
  expect_true(drawn(b))
  s <- st(b)
  expect_identical(s[c("gear", "preset", "from", "to", "years")],
                   list(gear = "longline", preset = "haul", from = "2021", to = "2021", years = 2L))
  expect_equal(unlist(s$hours), per_km2(10), tolerance = 1e-5)
  expect_match(s$search, "cells_gear=longline")
  expect_match(s$search, "cells_year_from=2021&cells_year_to=2021")
  # the address wins over the choices given: trawl in both years, the preset still the one given
  b2 <- open_page(paste0(url, "?cells_gear=trawl&cells_year_from=2020&cells_year_to=2021"))
  expect_true(drawn(b2))
  s2 <- st(b2)
  expect_identical(s2[c("gear", "preset", "from", "to")], list(gear = "trawl", preset = "haul", from = "2020", to = "2021"))
  expect_equal(unlist(s2$hours), per_km2(2 + 2), tolerance = 1e-5)
})

# ten 0.01-degree cells in a row along 65 N, from 23.00 W; vessel A in all, B in the first four, C in the first two
vessel_cells <- function() {
  d <- expand.grid(ix = seq(-23000, -22910, by = 10), iy = 65000, vid = c("A", "B", "C"), stringsAsFactors = FALSE)
  d <- d[d$vid == "A" | (d$vid == "B" & d$ix < -22960) | (d$vid == "C" & d$ix < -22980), ]
  d$hours <- 1
  d
}

test_that("the cells' size, live: about a pixel, or a size chosen (a c-square, an ICES rectangle) at every zoom", {
  skip_if_no_spatial()
  l <- og_cells(vessel_cells())$layers$cells
  f <- stats::setNames(l$config$filters, vapply(l$config$filters, `[[`, "", "id"))
  expect_identical(vapply(f$cells_px$options, `[[`, "", "value"),
                   c("1", "0.5", "2", "s0.01", "s0.05", "s0.1", "s0.5", "r1x0.5"))
  expect_match(f$cells_px$options[[5]]$label, "c-square")
  expect_match(f$cells_px$options[[8]]$label, "ICES rectangle")
  # at zoom 9 (a pixel 0.0014 degrees): the cells' own 0.01; c-squares, two of them (23.00-22.95, 22.95-22.90); 0.5
  # and the ICES rectangle, one
  expect_identical(tile_at(l, 9, lon = -22.96), 10)
  expect_identical(tile_at(l, 9, list(cells_px = "s0.05"), lon = -22.96), 2)
  expect_identical(tile_at(l, 9, list(cells_px = "s0.5"), lon = -22.96), 1)
  expect_identical(tile_at(l, 9, list(cells_px = "r1x0.5"), lon = -22.96), 1)
  # a size narrower than half a pixel is drawn at a whole number of it: 0.01 at zoom 5 (a pixel 0.022) as 0.02
  expect_identical(.og_cell_size("s0.01", 5, 0.001, 10, .og_cell_k), c(20, 20))
  expect_identical(.og_cell_size("r1x0.5", 2, 0.001, 10, .og_cell_k), c(1000, 500))
  expect_identical(.og_cell_size("1", 9, 0.001, 10, .og_cell_k), c(10, 10))
  # sizes not a whole number of the cells' own are not offered; the start chosen
  l2 <- og_cells(vessel_cells(), sizes = c(0.005, 0.05), ices = FALSE, cell = 0.05)$layers$cells
  expect_identical(vapply(l2$config$filters[[2]]$options, `[[`, "", "value"), c("1", "0.5", "2", "s0.05"))
  expect_identical(l2$config$start$cells_px, "s0.05")
  expect_identical(og_cells(vessel_cells(), cell = "ices")$layers$cells$config$start$cells_px, "r1x0.5")
  expect_error(og_cells(vessel_cells(), cell = 0.005), "`cell` is one of `sizes`")
  expect_error(og_cells(vessel_cells(), sizes = -1), "`sizes` are cell sizes")
})

test_that("at least N vessels: a control where the cells name their vessel, each cell's number of vessels on a click", {
  skip_if_no_spatial()
  m <- og_cells(vessel_cells(), min_vessels = 2)
  l <- m$layers$cells
  ids <- vapply(l$config$filters, `[[`, "", "id")
  expect_true("cells_atleast" %in% ids)
  expect_identical(l$config$start$cells_atleast, "2")
  expect_identical(vapply(l$config$popup$fields, `[[`, "", "field"), c("hours_km2", "vessels"))
  expect_identical(tile_at(l, 9, lon = -22.96), 10)
  expect_identical(tile_at(l, 9, list(cells_atleast = "2"), lon = -22.96), 4)
  expect_identical(tile_at(l, 9, list(cells_atleast = "3"), lon = -22.96), 2)
  # counted after the choices: vessel A alone, one vessel a cell
  expect_identical(tile_at(l, 9, list(cells_vid = "A", cells_atleast = "2"), lon = -22.96), 0)
  # c-squares: the first holds all three vessels
  expect_identical(tile_at(l, 9, list(cells_px = "s0.05", cells_atleast = "3"), lon = -22.96), 1)
  # none named, or none wanted: no control
  expect_false("cells_atleast" %in% vapply(og_cells(vessel_cells(), vessels = FALSE)$config$layers[[1]]$filters, `[[`, "", "id"))
  expect_false("cells_atleast" %in% vapply(og_cells(cells_df())$config$layers[[1]]$filters, `[[`, "", "id"))
  expect_error(og_cells(vessel_cells(), vessels = "boat"), "`vessels` names the column")
  expect_error(og_cells(vessel_cells(), min_vessels = 4), "1, 2, 3, 5 or 10")
})

test_that("in the page (a bundle), the sizes and the fewest vessels as the server's", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  og_bundle(og_map(view = list(center = c(-22.95, 65.005), zoom = 9)) |> og_cells(vessel_cells()), dir, overwrite = TRUE)
  expect_true("50" %in% list.files(file.path(dir, "grids", "cells")))
  b <- open_page(paste0(serve_dir(dir), "index.html"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('cells')")), 40))
  cells_now <- function(id = NULL, v = NULL) {
    if (!is.null(id)) {
      page_eval(b, sprintf("(() => { const s = document.getElementById('%s'); s.value = '%s'; s.dispatchEvent(new Event('change', { bubbles: true })); return true; })()", id, v))
    }
    Sys.sleep(0.5)
    wait_until(function() isTRUE(page_eval(b, "map.loaded() && map.areTilesLoaded()")), 20)
    unique(unlist(page_eval(b, "map.querySourceFeatures('cells', { sourceLayer: 'cells' }).map(f => [f.properties.vessels, f.properties.hours_km2.toFixed(4)].join('/'))")))
  }
  expect_true(wait_until(function() length(cells_now()) > 0, 20))
  # the 0.01-degree cells: 3, 2 and 1 vessels
  expect_setequal(sub("/.*", "", cells_now()), c("1", "2", "3"))
  expect_setequal(sub("/.*", "", cells_now("cells_atleast", "3")), "3")
  cells_now("cells_atleast", "1")
  # c-squares: two, of 3 and 1 vessels
  expect_setequal(sub("/.*", "", cells_now("cells_px", "s0.05")), c("1", "3"))
})

# H3 -------------------------------------------------------------------------------------------------------------------
skip_if_no_h3 <- function() {
  skip_if_no_spatial()
  skip_if(inherits(try(.og_h3(.og_connection()), silent = TRUE), "try-error"), "DuckDB's h3 extension is not available")
}
# vessel_cells()'s ten 0.01-degree cells, each with the resolution 9 H3 cell of its centre (edge 200 m: the ten cells,
# 470 m apart at 65 N, in ten hexagons); or the hexagons alone
hex_cells <- function(squares = TRUE) {
  d <- vessel_cells()
  con <- .og_connection()
  .og_h3(con)
  d$h3 <- DBI::dbGetQuery(con, sprintf("SELECT h3_latlng_to_cell_string(65.005, unnest([%s]), 9) AS h",
                                       paste((d$ix + 5) / 1000, collapse = ", ")))$h
  if (!squares) d$ix <- d$iy <- NULL
  d
}

test_that("H3: hexagons offered beside the squares, at a resolution following the zoom or one at every zoom", {
  skip_if_no_h3()
  l <- og_cells(hex_cells())$layers$cells
  f <- stats::setNames(l$config$filters, vapply(l$config$filters, `[[`, "", "id"))
  # the h3 column is the cells' grid, not a choice
  expect_false("cells_h3" %in% names(f))
  expect_identical(vapply(f$cells_px$options, `[[`, "", "value"),
                   c("1", "0.5", "2", "s0.01", "s0.05", "s0.1", "s0.5", "r1x0.5", "h", paste0("h", 9:2)))
  expect_match(f$cells_px$options[[10]]$label, "H3 resolution 9 \\(0.11 km²\\)")
  expect_identical(f$cells_px$default, "1")
  # ten hexagons at the cells' own resolution; one at resolution 4 (edge 26 km); the squares as before
  expect_identical(tile_at(l, 9, list(cells_px = "h9"), lon = -22.96), 10)
  expect_identical(tile_at(l, 9, list(cells_px = "h4"), lon = -22.96), 1)
  expect_identical(tile_at(l, 9, list(cells_px = "s0.05"), lon = -22.96), 2)
  # the choices and the fewest vessels as on the squares
  expect_identical(tile_at(l, 9, list(cells_px = "h9", cells_atleast = "3"), lon = -22.96), 2)
  expect_identical(tile_at(l, 9, list(cells_px = "h9", cells_vid = "C"), lon = -22.96), 2)
  # following the zoom: four pixels to an edge or more, at most the cells' own
  edge <- c(1281256, 483057, 182513, 68979, 26072, 9854, 3725, 1406, 531.4, 200.8, 75.9, 28.7)
  expect_identical(.og_h3_res("h", 9, c(-23, 64.8, -22.3, 65.2), 9, edge), 8L)
  expect_identical(.og_h3_res("h", 14, c(-23, 64.8, -22.3, 65.2), 9, edge), 9L)
  # resolution 9 asked at zoom 4 (a pixel 2.1 km at 65 N): the finest with an edge of half a pixel or more, 7
  expect_identical(.og_h3_res("h9", 4, c(-23, 64.8, -22.3, 65.2), 9, edge), 7L)
  # the start: an H3 resolution, or following the zoom
  expect_identical(og_cells(hex_cells(), cell = "h3_7")$layers$cells$config$start$cells_px, "h7")
  expect_identical(og_cells(hex_cells(), cell = "h3")$layers$cells$config$start$cells_px, "h")
  expect_error(og_cells(hex_cells(), cell = "h3_10"), "`cell` is one of")
  expect_error(og_cells(vessel_cells(), cell = "h3"), "`cell` is one of")
  # none wanted: the h3 column is then a choice like any other
  expect_true("cells_h3" %in% vapply(og_cells(hex_cells(), h3 = FALSE)$config$layers[[1]]$filters, `[[`, "", "id"))
})

test_that("H3 alone: hexagons only, following the zoom when the page opens; a bundle leaves them out", {
  skip_if_no_h3()
  m <- og_cells(hex_cells(squares = FALSE))
  l <- m$layers$cells
  f <- stats::setNames(l$config$filters, vapply(l$config$filters, `[[`, "", "id"))
  expect_identical(vapply(f$cells_px$options, `[[`, "", "value"), c("h", paste0("h", 9:2)))
  expect_identical(f$cells_px$default, "h")
  expect_equal(unlist(l$config$bounds)[c(2, 4)], c(65.005, 65.005), tolerance = 0.01)
  expect_identical(tile_at(l, 9, list(cells_px = "h9"), lon = -22.96), 10)
  expect_gt(tile_at(l, 9, list(), lon = -22.96), 0)
  expect_null(l$bundle_grid)
  dir <- withr::local_tempdir()
  expect_message(og_bundle(m, dir, overwrite = TRUE), "Left out of the bundle")
})

test_that("a bundle of cells with both grids keeps the squares and says the hexagons are left out", {
  skip_if_no_h3()
  dir <- withr::local_tempdir()
  expect_message(og_bundle(og_cells(hex_cells(), cell = "h3_8"), dir, overwrite = TRUE), "H3's hexagons left out")
  # the page's config, in its index.html: no hexagon offered, nor opened on
  page <- paste(readLines(file.path(dir, "index.html"), warn = FALSE), collapse = "\n")
  expect_false(grepl("H3 resolution", page, fixed = TRUE))
  expect_false(grepl('"cells_px":"h', page, fixed = TRUE))
  expect_true(grepl("c-square", page, fixed = TRUE))
})

test_that("in the page (served): hexagons drawn, each cell's value per km² of its own area", {
  skip_if_no_h3()
  skip_if_no_chrome()
  m <- og_map(view = list(center = c(-22.95, 65.005), zoom = 11)) |> og_cells(hex_cells(), cell = "h3_9")
  url <- og_serve(m, open = FALSE, wait = FALSE)
  withr::defer(og_stop(as.integer(sub(".*:([0-9]+)/$", "\\1", url))))
  b <- open_page(url)
  feats <- function() page_eval(b, paste(
    "map.querySourceFeatures('cells', { sourceLayer: 'cells' }).map(f =>",
    "  ({ ring: f.geometry.coordinates[0].length, hours: f.properties.hours_km2, vessels: f.properties.vessels }))"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('cells') && map.loaded() && map.areTilesLoaded()")), 40))
  expect_true(wait_until(function() length(feats()) > 0, 20))
  ff <- feats()
  # a hexagon's ring: six corners and the first again (one cut by a tile's edge may have more)
  expect_true(all(vapply(ff, `[[`, 0, "ring") >= 7))
  expect_true(any(vapply(ff, `[[`, 0, "ring") == 7))
  # the first cell's three vessels' hours (3) over its hexagon's area, about 0.1 km² at resolution 9
  h <- max(vapply(ff, `[[`, 0, "hours"))
  expect_gt(h, 3 / 0.13)
  expect_lt(h, 3 / 0.08)
  expect_identical(page_eval(b, "document.getElementById('cells_px').value"), "h9")
  # back to the squares: about a pixel at zoom 11 (0.01-degree cells, their own)
  page_eval(b, "(() => { const s = document.getElementById('cells_px'); s.value = '1'; s.dispatchEvent(new Event('change', { bubbles: true })); return true; })()")
  Sys.sleep(0.5)
  expect_true(wait_until(function() isTRUE(page_eval(b, "map.loaded() && map.areTilesLoaded()")), 20))
  expect_true(wait_until(function() all(vapply(feats(), `[[`, 0, "ring") == 5), 20))
})

# A value missing ---------------------------------------------------------------------------------------------------
test_that("a cell whose every row lacks the value is grey, served and bundled, said so in the legend and the popup", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  # vessel_cells()'s ten cells: a soak in the first five, none in the last five
  d <- vessel_cells()
  d$soak <- ifelse(d$ix < -22950, 2, NA)
  m <- og_map(view = list(center = c(-22.95, 65.005), zoom = 9)) |> og_cells(d, metric = "soak")
  look <- function(b) {
    expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('cells') && map.loaded() && map.areTilesLoaded()")), 40))
    expect_true(wait_until(function() length(page_eval(b, "map.queryRenderedFeatures({ layers: ['cells'] })")) > 0, 20))
    Sys.sleep(0.5)
    page_eval(b, paste(
      "(() => { const f = map.queryRenderedFeatures({ layers: ['cells'] });",
      "  const c = x => { const k = x.layer.paint['fill-color']; return [k.r, k.g, k.b].map(v => Math.round(v * 255)).join(','); };",
      "  return { with: f.filter(x => 'soak_km2' in x.properties).length, without: f.filter(x => !('soak_km2' in x.properties)).length,",
      "           hours: f.every(x => x.properties.hours_km2 > 0),",
      "           grey: [...new Set(f.filter(x => !('soak_km2' in x.properties)).map(c))],",
      "           coloured: [...new Set(f.filter(x => 'soak_km2' in x.properties).map(c))].length,",
      "           legend: !document.getElementById('novalue').hidden }; })()"))
  }
  # served: the server leaves a missing value out of its tile
  url <- og_serve(m, open = FALSE, wait = FALSE)
  withr::defer(og_stop(as.integer(sub(".*:([0-9]+)/$", "\\1", url))))
  b <- open_page(url)
  s <- look(b)
  expect_gt(s$with, 0)
  expect_gt(s$without, 0)
  expect_true(s$hours)
  expect_identical(unlist(s$grey), "153,153,153")
  expect_true(s$legend)
  # the popup of a cell with no soak says so, its hours given
  page_eval(b, paste(
    "(() => { const f = map.queryRenderedFeatures({ layers: ['cells'] }).find(x => !('soak_km2' in x.properties));",
    "  const c = f.geometry.coordinates[0], x = c.reduce((a, p) => a + p[0], 0) / c.length, y = c.reduce((a, p) => a + p[1], 0) / c.length;",
    "  const p = map.project([x, y]); map.fire('click', { point: p, lngLat: map.unproject(p), originalEvent: {} }); return true; })()"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "!!document.querySelector('.maplibregl-popup')")), 10))
  expect_match(page_eval(b, "document.querySelector('.maplibregl-popup').textContent"), "hours per km².*no value soak per km²")
  b$close()
  # bundled: the bundle keeps the missing sum missing (it wrote 0 before), and the browser leaves it out
  dir <- withr::local_tempdir()
  og_bundle(m, dir, overwrite = TRUE)
  b2 <- open_page(paste0(serve_dir(dir), "index.html"))
  s2 <- look(b2)
  expect_gt(s2$with, 0)
  expect_gt(s2$without, 0)
  expect_identical(unlist(s2$grey), "153,153,153")
  expect_true(s2$legend)
  # a coarser cell holding some cells with a soak and some without: the soak of those that have one, no grey
  page_eval(b2, "(() => { const s = document.getElementById('cells_px'); s.value = 's0.5'; s.dispatchEvent(new Event('change', { bubbles: true })); return true; })()")
  Sys.sleep(1)
  s3 <- look(b2)
  expect_identical(s3$without, 0L)
  expect_false(s3$legend)
})

# The fixed sizes alone ------------------------------------------------------------------------------------------------
# vessel_cells() on 0.005-degree cells: each 0.01-degree cell split in two, twenty in a row
fine_cells <- function() {
  d <- vessel_cells()
  e <- d
  e$ix <- e$ix + 5
  rbind(d, e)
}

test_that("pixel = FALSE: the fixed sizes alone, opening on the finest; a bundle carries every size offered", {
  skip_if_no_spatial()
  l <- og_cells(fine_cells(), sizes = c(0.005, 0.01, 0.05), pixel = FALSE)$layers$cells
  f <- stats::setNames(l$config$filters, vapply(l$config$filters, `[[`, "", "id"))
  expect_identical(vapply(f$cells_px$options, `[[`, "", "value"), c("s0.005", "s0.01", "s0.05", "r1x0.5"))
  expect_identical(f$cells_px$default, "s0.005")
  # a tile asked with no size: the finest, the twenty cells at zoom 9 (a pixel 0.0014 degrees)
  expect_identical(tile_at(l, 9, lon = -22.96), 20)
  expect_identical(tile_at(l, 9, list(cells_px = "s0.01"), lon = -22.96), 10)
  # the bundle's levels: every size offered, 0.005 too, under the base of 0.01 (before, no level divided it, and a
  # bundle drew 0.01-degree cells for it)
  expect_true(all(c(5, 10, 50, 500) %in% l$bundle_grid$levels))
  expect_true(5 %in% og_cells(fine_cells(), sizes = c(0.005, 0.01))$layers$cells$bundle_grid$levels)
  # about a pixel as before, by default
  expect_identical(og_cells(fine_cells())$layers$cells$config$filters[[2]]$default, "1")
  expect_error(og_cells(fine_cells(), sizes = 0.003, ices = FALSE, pixel = FALSE), "needs a size to offer")
  expect_error(og_cells(fine_cells(), pixel = NA), "TRUE or FALSE")
})

test_that("in the page (a bundle), pixel = FALSE opens on the finest size and draws it as itself", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  og_bundle(og_map(view = list(center = c(-22.95, 65.005), zoom = 9)) |>
              og_cells(fine_cells(), sizes = c(0.005, 0.01, 0.05), pixel = FALSE), dir, overwrite = TRUE)
  expect_true("5" %in% list.files(file.path(dir, "grids", "cells")))
  b <- open_page(paste0(serve_dir(dir), "index.html"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('cells') && map.loaded() && map.areTilesLoaded()")), 40))
  n <- function() length(unique(unlist(page_eval(b, "map.querySourceFeatures('cells', { sourceLayer: 'cells' }).map(f => JSON.stringify(f.geometry.coordinates))"))))
  expect_true(wait_until(function() n() > 0, 20))
  expect_identical(page_eval(b, "document.getElementById('cells_px').value"), "s0.005")
  expect_identical(n(), 20L)
})
