# og_relief() and og_contour(): the sea floor from a depth model, its controls folded in the page

# an MBTiles file of one tile, zoom 1's north-west, as og_tiles_mbtiles() reads it
relief_mbtiles <- function() {
  f <- tempfile(fileext = ".mbtiles")
  con <- DBI::dbConnect(RSQLite::SQLite(), f)
  DBI::dbWriteTable(con, "metadata", data.frame(
    name = c("format", "encoding", "bounds", "minzoom", "maxzoom"),
    value = c("png", "terrarium", "-30,60,-5,70", "0", "1")
  ))
  DBI::dbExecute(con, "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)")
  DBI::dbExecute(con, "INSERT INTO tiles VALUES (1, 0, 1, ?)", params = list(list(as.raw(1:4))))
  DBI::dbDisconnect(con)
  f
}

test_that("og_relief() draws the depth in colour and its relief, as two layers folded in a section of their own", {
  f <- relief_mbtiles()
  withr::defer(unlink(f))
  m <- og_map() |> og_relief(f)
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("depth", "depth_relief"))
  expect_identical(vapply(m$config$groups, `[[`, "", "title"), "Sea floor")
  d <- m$config$layers[[1]]
  expect_identical(d$colour[c("of", "palette", "opacity")], list(of = "depth", palette = "grey", opacity = 75))
  expect_identical(d$fit, "page")
  expect_true(d$fold)
  expect_true(m$config$layers[[2]]$fold)
  expect_identical(m$config$layers[[2]]$style[[1]]$type, "hillshade")
  # the map opens on the model's extent
  expect_equal(unlist(m$config$view$bounds), c(-30, 60, -5, 70))

  # the starting look as arguments: fixed limits stop the fit following the view; a fixed intensity; no relief
  m2 <- og_relief(f, palette = "seabed", opacity = 50, limits = c(5, 300), scale = "log", shade = 0.3, open = TRUE)
  d2 <- m2$config$layers[[1]]
  expect_identical(d2$colour[c("palette", "floor", "cap", "scale", "auto")],
                   list(palette = "seabed", floor = 5, cap = 300, scale = "log", auto = FALSE))
  expect_identical(m2$config$layers[[2]]$shade[c("exaggeration", "auto")], list(exaggeration = 0.3, auto = FALSE))
  expect_null(d2$fold)
  expect_identical(vapply(og_relief(f, shade = FALSE)$config$layers, `[[`, "", "id"), "depth")
  expect_identical(vapply(og_relief(f, id = "olex", name = "Olex")$config$layers, `[[`, "", "id"), c("olex", "olex_relief"))

  expect_error(og_relief(f, limits = c(300, 5)), "floor below the cap")
  expect_error(og_relief(f, shade = 2), "intensity from 0 to 1")
  expect_error(og_relief(f, palette = c("grey", "seabed")), "one of the map's palettes")
  expect_error(og_map() |> og_relief(f, palette = "nonesuch"), "palette")
  expect_error(og_relief(og_map(), f, open = NA), "`open` is TRUE or FALSE")
})

test_that("og_contour(): the major depths heavier and labelled, thinner lines between, at intervals that make them", {
  f <- relief_mbtiles()
  withr::defer(unlink(f))
  k <- (og_map() |> og_contour(f))$config$layers[[1]]
  expect_identical(k$id, "contours")
  expect_identical(k$contours$multiplier, -1)
  expect_false(k$contours$auto)
  expect_true(k$fold)
  # 25 m among the major depths makes the lines every 5 m from zoom 7; at zoom 3 the deep isobaths alone
  expect_identical(unlist(k$contours$thresholds), c(`3` = 500, `5` = 25, `7` = 5, `8` = 5, `9` = 5, `10` = 5, `11` = 5))
  types <- vapply(k$style, `[[`, "", "type")
  expect_identical(sum(types == "line"), 7L)
  expect_identical(sum(types == "symbol"), 7L)
  line7 <- k$style[[which(vapply(k$style, `[[`, "", "id") == "contours-line-7")]]
  expect_identical(line7$paint$`line-width`[[1]], "case")
  expect_identical(unlist(line7$paint$`line-width`[[2]][[3]][[2]]),
                   c(10, 25, 50, 100, 150, 200, 300, 400, 500, 1000, 1500, 2000, 2500, 3000, 4000, 5000))

  # the major depths alone, unlabelled, the lines made at their own common divisor
  k2 <- (og_map() |> og_contour(f, major = c(500, 100, 200), minor = FALSE, labels = FALSE))$config$layers[[1]]
  # (at zoom 3 the major depths of 500 m and more alone)
  expect_identical(unlist(k2$contours$thresholds)[c("3", "5", "11")], c(`3` = 500, `5` = 100, `11` = 100))
  expect_true(all(vapply(k2$style, `[[`, "", "type") == "line"))
  expect_identical(k2$style[[1]]$filter[[1]], "all")
  expect_identical((og_map() |> og_contour(f, of = "elevation"))$config$layers[[1]]$contours$multiplier, 1)

  expect_error(og_contour(f, major = c(10, -5)), "whole metres above 0")
  expect_error(og_contour(f, minor = "yes"), "`minor` is TRUE or FALSE")
  expect_error(og_contour(f, colour = "red"), "#rrggbb")
})

test_that("the depth model: OGIS_DEPTH when none is given, a path by its kind, a map started for one given first", {
  f <- relief_mbtiles()
  withr::defer(unlink(f))
  withr::local_envvar(OGIS_DEPTH = f)
  m <- suppressMessages(og_relief() |> og_contour())
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("depth", "depth_relief", "contours"))
  expect_equal(attr(m$layers$depth$tiles, "source"), normalizePath(f))
  # one tile function given to both is used as it is
  t <- og_tiles_mbtiles(f)
  m2 <- og_map() |> og_relief(t) |> og_contour(t)
  expect_identical(m2$layers$depth$tiles, t)

  withr::local_envvar(OGIS_DEPTH = NA)
  expect_error(og_relief(), "needs the depth model.*OGIS_DEPTH.*Renviron")
  expect_error(og_contour(file.path(tempdir(), "no-such.tif")), "no such file")
  withr::local_envvar(OGIS_DEPTH = file.path(tempdir(), "no-such-depth.mbtiles"))
  expect_error(og_relief(), "OGIS_DEPTH names .*no such file")
  expect_error(og_relief(og_map(), f, f), "palette") # the third is `palette`
  expect_error(og_relief(f, f), "the depth model goes to `tiles`")
})

test_that("a grid is made into tiles by og_tiles_dem()", {
  skip_if_not_installed("png")
  skip_if_not_installed("terra")
  m <- og_map() |> og_relief(og_example("dansk_relief")) |> og_contour(og_example("dansk_relief"))
  expect_identical(attr(m$layers$depth$tiles, "fit"), "page")
  expect_identical(attr(m$layers$contours$tiles, "fit"), "page")
})

test_that("in the page the layers open folded, their scale bar shown, and unfold with a click", {
  skip_if_no_chrome()
  skip_if_not_installed("png")
  skip_if_not_installed("terra")
  depth <- og_tiles_dem(og_example("dansk_relief"), maxzoom = 4)
  d <- tempfile("relief_")
  withr::defer(unlink(d, recursive = TRUE))
  m <- og_map(view = list(bounds = c(2.5, 54.5, 13, 58.5))) |> og_relief(depth) |> og_contour(depth)
  og_bundle(m, d)
  b <- open_page(paste0(serve_dir(d), "index.html"))
  expect_true(wait_until(function() isTRUE(page_eval(b, "!!window.og?.map?.getLayer('contours-label-5')"))))
  st <- function() page_eval(b, paste(
    "({ folded: [...document.querySelectorAll('.layer.folded')].map(e => e.id),",
    "   palette: getComputedStyle(document.getElementById('depth-cpal').closest('.row')).display,",
    "   bar: getComputedStyle(document.getElementById('depth-cbar')).display,",
    "   expanded: document.getElementById('depth-fold').getAttribute('aria-expanded') })"
  ))
  s <- st()
  # the contours too, whose lines can follow the view on a grid's tiles (on an MBTiles file's they have no control)
  expect_identical(unlist(s$folded), c("lyr-depth", "lyr-depth_relief", "lyr-contours"))
  expect_identical(s$palette, "none")
  expect_false(identical(s$bar, "none"))
  expect_identical(s$expanded, "false")
  page_eval(b, "document.getElementById('depth-fold').click(); 0")
  s <- st()
  expect_identical(unlist(s$folded), c("lyr-depth_relief", "lyr-contours"))
  expect_identical(s$palette, "flex")
  expect_identical(s$expanded, "true")
})

test_that("no lines along a grid's edge in open water: its nodata is no elevation to the contours", {
  skip_if_no_chrome()
  skip_if_not_installed("png")
  skip_if_not_installed("terra")
  # a flat sea floor at 30 m, and one sloping from 10 to 60 m: with the sea beyond the edge at 0, the flat one drew
  # every line from 5 to 25 m along its edge
  g <- expand.grid(lon = seq(10, 11, by = 0.01), lat = seq(56, 57, by = 0.01))
  lines_drawn <- function(elevation) {
    g$elevation <- elevation
    d <- tempfile("edge_")
    withr::defer(unlink(d, recursive = TRUE), envir = parent.frame())
    m <- og_map(view = list(center = c(10.5, 56.5), zoom = 8)) |> og_contour(og_tiles_dem(g, maxzoom = 8), labels = FALSE)
    og_bundle(m, d)
    b <- open_page(paste0(serve_dir(d, env = parent.frame()), "index.html"), env = parent.frame())
    expect_true(wait_until(function() isTRUE(page_eval(b, "!!window.og?.map?.loaded() && og.map.areTilesLoaded()")), 60))
    Sys.sleep(1)
    wait_until(function() FALSE, 2) # the page's own work meanwhile
    page_eval(b, "og.map.querySourceFeatures('contours', { sourceLayer: 'contours' }).length")
  }
  expect_identical(lines_drawn(-30), 0L)
  expect_gt(lines_drawn(-10 - 50 * (g$lon - 10)), 0)
})
