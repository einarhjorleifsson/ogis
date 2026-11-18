test_that("a map with no port takes a free one, and replaces the last such map there", {
  skip_if_not_installed("httpuv")
  skip_if_not_installed("jsonlite")
  a <- og_layer("a", "vector", tiles = function(z, x, y) raw(0), style = list(list(id = "a-line", type = "line")))
  m <- og_map(og_section("g", layers = list(a)))
  app <- .og_map_app(m)
  port_of <- function(url) as.integer(sub("^http://localhost:([0-9]+)/.*$", "\\1", url))
  # the first port of the range held by another program
  first <- httpuv::randomPort(min = 20000L, max = 60000L)
  other <- httpuv::startServer("127.0.0.1", first, list(call = function(req) list(status = 200L, body = "")))
  on.exit(httpuv::stopServer(other), add = TRUE)
  p1 <- .og_serve_free("127.0.0.1", app, ports = first + 0:9)
  expect_true(p1 > first)
  # served again with no port: in the same place, the map there replaced
  expect_equal(.og_serve_free("127.0.0.1", app, ports = first + 0:9), p1)
  # a map on a port named is never replaced by one with no port
  .og_serve_last$port <- NULL
  p3 <- .og_serve_free("127.0.0.1", app, ports = first + 0:9)
  expect_true(p3 > p1)
  expect_true(all(as.character(c(p1, p3)) %in% ls(.og_maps)))
  expect_equal(sort(og_stop(c(p1, p3))), sort(c(p1, p3)))
  # a port named and taken is an error, and so is a range with none free
  expect_error(og_serve(m, port = first, open = FALSE), "Port [0-9]+ is taken: give another port, or none")
  expect_error(.og_serve_free("127.0.0.1", app, ports = first), "No port free from")
  # og_serve() with no port, as print() calls it: twice on one port
  url <- og_serve(m, open = FALSE)
  expect_equal(port_of(og_serve(m, open = FALSE)), port_of(url))
  expect_equal(og_stop(port_of(url)), port_of(url))
})

test_that("a map from data carries no port unless its first call gives one", {
  skip_if_not_installed("jsonlite")
  df <- dplyr::collect(utils::head(og_example("dansk"), 50))
  expect_null(attr(og_point(df), "port"))
  expect_null(attr(og_map(df) |> og_point(), "port"))
  expect_equal(attr(og_time(df, speed, time = "time_stamp", by = vessel_id, port = 9001), "port"), 9001L)
})
