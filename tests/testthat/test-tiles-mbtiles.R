# og_tiles_mbtiles() with no file: the depth model named once, by the environment variable OGIS_DEPTH (a line in
# .Renviron), so a script shared between colleagues carries no path

# an MBTiles file of one tile, at zoom 1 in the north-west, holding `bytes`
one_tile_mbtiles <- function(bytes) {
  f <- tempfile(fileext = ".mbtiles")
  con <- DBI::dbConnect(RSQLite::SQLite(), f)
  DBI::dbWriteTable(con, "metadata", data.frame(
    name = c("format", "encoding", "bounds", "minzoom", "maxzoom"),
    value = c("png", "terrarium", "-30,60,-5,70", "0", "1")
  ))
  DBI::dbExecute(con, "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)")
  DBI::dbExecute(con, "INSERT INTO tiles VALUES (1, 0, 1, ?)", params = list(list(bytes)))
  DBI::dbDisconnect(con)
  f
}

test_that("with no file it reads the one OGIS_DEPTH names, and says so; a file given wins", {
  a <- one_tile_mbtiles(as.raw(1:4))
  b <- one_tile_mbtiles(as.raw(5:8))
  withr::defer(unlink(c(a, b)))
  withr::local_envvar(OGIS_DEPTH = a)
  expect_message(tiles <- og_tiles_mbtiles(), "OGIS_DEPTH")
  expect_identical(tiles(1, 0, 0), as.raw(1:4))
  expect_equal(attr(tiles, "source"), normalizePath(a))
  expect_identical(suppressMessages(og_tiles_mbtiles(""))(1, 0, 0), as.raw(1:4))
  expect_no_message(given <- og_tiles_mbtiles(b))
  expect_identical(given(1, 0, 0), as.raw(5:8))
})

test_that("with no file and no OGIS_DEPTH, or one naming no MBTiles file, the error says what to do", {
  withr::local_envvar(OGIS_DEPTH = NA)
  expect_error(og_tiles_mbtiles(), "`file`.*OGIS_DEPTH.*Renviron")
  withr::local_envvar(OGIS_DEPTH = file.path(tempdir(), "no-such-depth.mbtiles"))
  expect_error(og_tiles_mbtiles(), "OGIS_DEPTH names .*no such file")
  # a GeoTIFF's first bytes: refused before SQLite meets it, pointed to og_tiles_dem()
  tif <- tempfile(fileext = ".tif")
  withr::defer(unlink(tif))
  writeBin(as.raw(c(0x49, 0x49, 0x2a, 0x00, rep(0, 12))), tif)
  withr::local_envvar(OGIS_DEPTH = tif)
  expect_error(og_tiles_mbtiles(), "OGIS_DEPTH names .*not an MBTiles file.*og_tiles_dem")
  expect_error(og_tiles_mbtiles(tif), "`file` .*not an MBTiles file")
  expect_error(og_tiles_mbtiles(tempfile()), "`file` .*no such file")
  expect_error(og_tiles_mbtiles(1), "path of an MBTiles file")
})

test_that("a bundle made on OGIS_DEPTH's file holds its tiles and needs no variable where it opens", {
  a <- one_tile_mbtiles(as.raw(1:4))
  d <- tempfile("bundle_")
  withr::defer(unlink(c(a, d), recursive = TRUE))
  withr::local_envvar(OGIS_DEPTH = a)
  depth <- og_layer("depth", "dem", tiles = suppressMessages(og_tiles_mbtiles()),
                    style = list(list(id = "d", type = "hillshade")))
  out <- og_bundle(og_map(og_section("g", "G", list(depth))), d, maxzoom = 1)
  expect_equal(attr(out, "tiles"), 1L)
  expect_equal(list.files(file.path(d, "tiles")), "depth.pmtiles.js")
  expect_false(any(grepl(basename(a), readLines(file.path(d, "index.html"), warn = FALSE), fixed = TRUE)))
})
