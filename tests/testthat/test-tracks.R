# og_tracks(): pings as a track, a time panel of speed (a vessel, then a trip), and the effort by cell following the
# vessel chosen there; ramb's columns or EM4SSF's D2.1 format's

# two vessels off Jutland, a ping every 10 minutes: A two gillnet trips, B one trawl trip; fishing in each trip's middle
track_pings <- function() {
  one <- function(vid, trip, gear, t0, lon0) {
    n <- 36
    data.frame(
      vid = vid, time = as.POSIXct(t0, tz = "UTC") + (seq_len(n) - 1) * 600,
      lon = lon0 + seq_len(n) * 0.004, lat = 56.5 + sin(seq_len(n) / 6) * 0.02,
      speed = c(rep(8, 10), rep(2.5, 16), rep(8, 10)), behaviour = c(rep("Other", 10), rep("Fishing", 16), rep("Other", 10)),
      trip_id = trip, gear = c(rep(NA, 10), rep(gear, 16), rep(NA, 10)), hours = 1 / 6, stringsAsFactors = FALSE
    )
  }
  rbind(one("A", 1, "GN", "2020-05-01 04:00", 10.0), one("A", 2, "GN", "2020-05-03 04:00", 10.1),
        one("B", 1, "OTB", "2020-05-02 04:00", 10.3))
}

test_that("og_tracks(): the track, the pings by what the vessel did, a panel of speed with its trips, the effort", {
  skip_if_no_spatial()
  m <- og_tracks(track_pings())
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("cells", "pings"))
  tp <- m$config$time
  expect_identical(vapply(tp$vessels, `[[`, "", "value"), c("A", "B"))
  # a vessel's trips, known by the vessel too
  lab <- vapply(tp$vessels[[1]]$spans, function(s) .og_or(s$label, ""), "")[-1]
  expect_identical(substr(lab, 1, 16), c("A 1 \u00b7 2020-05-01", "A 2 \u00b7 2020-05-03"))
  expect_setequal(vapply(tp$lanes, `[[`, "", "label"), c("behaviour", "trip"))
  # the pings are the panel's rows: its own points are not drawn over them
  expect_false(tp$dots)
  # the effort: the fishing pings' hours by cell, vessel, gear and year, following the panel's vessel
  cl <- m$layers$cells
  expect_identical(cl$config$follow, list(id = "cells_follow", vessel = "cells_vid", gear = "cells_gear"))
  expect_identical(cl$config$start[["cells_px"]], NULL)
  mt <- cl$meta()
  expect_identical(mt$follow, list(A = "GN", B = "OTB"))
  expect_setequal(mt$options$cells_gear$value, c("GN", "OTB"))
  # no effort; the effort given; the arguments passed on to og_cells()
  expect_identical(vapply(og_tracks(track_pings(), effort = FALSE)$config$layers, `[[`, "", "id"), "pings")
  expect_identical(og_tracks(track_pings(), palette = "blues")$layers$cells$config$start$palette, "blues")
})

test_that("ramb's voyage_key is a trip's key as it is, taken before its trip_id", {
  skip_if_no_spatial()
  d <- track_pings()
  d$voyage_key <- paste0(d$vid, ":2020:", d$trip_id)
  lab <- vapply(og_tracks(d, effort = FALSE)$config$time$vessels[[1]]$spans, function(s) .og_or(s$label, ""), "")[-1]
  expect_identical(substr(lab, 1, 8), c("A:2020:1", "A:2020:2"))
})

test_that("EM4SSF's D2.1 names are found; what is missing said", {
  skip_if_no_spatial()
  d <- track_pings()
  names(d) <- c("VESSEL_ID", "DATE_TIME", "LONGITUDE", "LATITUDE", "SPEED", "ACTIVITY", "TRIP_ID", "GEAR", "hours")
  d$OBSERVED <- d$ACTIVITY
  m <- og_tracks(d, lanes = c(observed = "OBSERVED"))
  expect_identical(vapply(m$config$time$vessels, `[[`, "", "value"), c("A", "B"))
  expect_setequal(vapply(m$config$time$lanes, `[[`, "", "label"), c("ACTIVITY", "trip", "observed"))
  expect_error(og_tracks(d[c("DATE_TIME", "LONGITUDE", "LATITUDE", "SPEED")]), "no vessel")
  expect_error(og_tracks(d[setdiff(names(d), "hours")]), "need `activity` and `hours`")
  expect_error(og_tracks(d, lanes = "NOPE"), "`lanes` names columns")
  expect_error(og_tracks(d, cell = 0), "`cell` is the cells' side")
})

test_that("a segment with a time follows the panel, as a point does", {
  skip_if_no_spatial()
  sets <- data.frame(vid = c("A", "B"), time = as.POSIXct(c("2020-05-01 06:00", "2020-05-02 06:00"), tz = "UTC"),
                     lon = c(10.02, 10.32), lat = c(56.5, 56.5), lon_end = c(10.06, 10.36), lat_end = c(56.51, 56.51))
  m <- og_tracks(track_pings(), effort = FALSE) |>
    og_segment(sets, lon_end = "lon_end", lat_end = "lat_end", name = "Sets", id = "sets")
  expect_true("sets" %in% vapply(m$config$time$layers, `[[`, "", "id"))
})

test_that("in the page (a bundle), the effort follows the panel's vessel: its own, its gear's, the fleet's", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  og_bundle(og_tracks(track_pings()), dir, overwrite = TRUE)
  b <- open_page(paste0(serve_dir(dir), "index.html?tv=B"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "typeof map !== 'undefined' && !!map.getLayer('cells') && !!document.getElementById('t-vessel').value")), 40))
  st <- function() page_eval(b, paste(
    "({ vessel: document.getElementById('t-vessel').value, vid: document.getElementById('cells_vid').value,",
    "   gear: document.getElementById('cells_gear').value })"))
  set <- function(id, v) page_eval(b, sprintf("(() => { const s = document.getElementById('%s'); s.value = '%s'; s.dispatchEvent(new Event('change', { bubbles: true })); return true; })()", id, v))
  expect_identical(st(), list(vessel = "B", vid = "B", gear = ""))
  set("cells_follow", "gear")
  expect_identical(st(), list(vessel = "B", vid = "", gear = "OTB"))
  set("t-vessel", "A")
  expect_identical(st(), list(vessel = "A", vid = "", gear = "GN"))
  set("cells_follow", "fleet")
  expect_identical(st(), list(vessel = "A", vid = "", gear = ""))
})

test_that("compare: two columns as lanes, and marks where one has a ping the other has not, or gives it otherwise", {
  skip_if_no_spatial()
  d <- track_pings()
  # another method's trips: the first trip two pings later, B's none
  d$other_trip <- ifelse(d$vid == "B", NA, d$trip_id)
  d$other_trip[1:2] <- NA
  # an observer's activity: fishing two pings earlier on A's first trip
  d$observed <- d$behaviour
  d$observed[9:10] <- "Fishing"
  m <- og_tracks(d, compare = list(c(ramb = "trip_id", other = "other_trip"),
                                   c(rule = "behaviour", observer = "observed")), effort = FALSE)
  tp <- m$config$time
  expect_setequal(vapply(tp$lanes, `[[`, "", "label"), c("behaviour", "trip", "other", "observer"))
  # trips: B's and A's first two pings in ramb's alone, none in the other's alone (left out), the values of two id
  # systems not compared; activity: two pings given differently, none missing on either side
  expect_setequal(vapply(tp$marks, `[[`, "", "label"), c("ramb only", "rule ≠ observer"))
  expect_setequal(vapply(tp$marks, `[[`, "", "field"), c("og_cmp1a", "og_cmp2d"))
  expect_error(og_tracks(d, compare = c("trip_id", "nope")), "`compare` is two columns")
  expect_error(og_tracks(d, compare = "trip_id"), "`compare` is two columns")
})

test_that("the pings named, with no map, start one; something else in the map's place is refused", {
  skip_if_no_spatial()
  m <- og_tracks(pings = track_pings(), effort = FALSE)
  expect_s3_class(m, "og_map")
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), "pings")
  expect_identical(vapply(m$config$time$vessels, `[[`, "", "value"), c("A", "B"))
  expect_error(og_tracks(track_pings(), pings = track_pings()), "`map` is an og_map\\(\\); the pings go to `pings`")
})

test_that("served: a vessel's id with a space or a plus reaches the effort's tiles and the panel's series", {
  skip_if_no_spatial()
  d <- track_pings()
  d$vid <- unname(c(A = "vessel 4", B = "A+B 7")[d$vid])
  m <- og_tracks(d)
  app <- .og_map_app(m)
  get <- function(path, q = "") app$call(list(REQUEST_METHOD = "GET", PATH_INFO = path, QUERY_STRING = q,
                                              HTTP_HOST = "localhost:8811"))
  z <- 9
  x <- floor((10.1 + 180) / 360 * 2^z)
  y <- floor((1 - log(tan(56.5 * pi / 180) + 1 / cos(56.5 * pi / 180)) / pi) / 2 * 2^z)
  tile <- function(q) get(sprintf("/tiles/cells/%d/%d/%d.pbf", z, x, y), q)
  # the page writes the tiles' query as a form does (URLSearchParams): a space as "+", a plus as "%2B"
  r <- tile("cells_vid=vessel+4")
  expect_identical(r$status, 200L)
  expect_gt(unname(mvt_count(r$body)["cells"]), 0)
  expect_identical(tile("cells_vid=vessel%204")$status, 200L)
  expect_identical(tile("cells_vid=A%2BB+7")$status, 200L)
  expect_identical(tile("cells_vid=vessel+5")$status, 400L)
  # the panel's series: the page's %20, and a form's "+"
  vs <- m$config$time$vessels
  span <- utils::URLencode(vs[[1]]$spans[[2]]$value, reserved = TRUE)
  expect_identical(get("/time", paste0("v=vessel%204&span=", span))$status, 200L)
  expect_identical(get("/time", paste0("v=vessel+4&span=", span))$status, 200L)
  expect_identical(get("/time", paste0("v=A%2BB%207&span=", utils::URLencode(vs[[2]]$spans[[2]]$value, reserved = TRUE)))$status, 200L)
})

test_that("in the page (served), the effort's tiles come for a vessel whose id has a space", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  d <- track_pings()
  d$vid <- unname(c(A = "vessel 4", B = "vessel 7")[d$vid])
  url <- og_serve(og_tracks(d), open = FALSE, wait = FALSE)
  withr::defer(og_stop(as.integer(sub(".*:([0-9]+)/$", "\\1", url))))
  b <- open_page(paste0(url, "?tv=vessel%204"))
  # the page asks for the vessel's cells as a form writes it (cells_vid=vessel+4); refused, it draws none (its status
  # says so only until the next reload of the tiles)
  drawn <- function() isTRUE(page_eval(b, paste(
    "typeof map !== 'undefined' && !!map.getSource('cells') && map.getSource('cells').tiles[0].includes('cells_vid=vessel+4')",
    "&& map.areTilesLoaded() && map.queryRenderedFeatures({ layers: ['cells'] }).length > 0")))
  expect_true(wait_until(drawn, 40))
  expect_identical(page_eval(b, "document.getElementById('cells_vid').value"), "vessel 4")
})
