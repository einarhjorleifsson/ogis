# The order the layers are drawn in: the pipe's, og_map()'s `order`; in the page, whatever order their data come in

ids_of <- function(m) vapply(m$config$layers, `[[`, "", "id")
box_of <- function(m) lapply(m$config$groups, function(g) unlist(g$layers))

test_that("a piped map draws its layers in the order added, the sidebar by its boxes; `order` names those drawn first", {
  skip_if_no_spatial()
  pos <- og_example("trawlsurvey")
  tows <- og_example("trawlsurveytows")
  # a box named again later: its layer drawn over the one before it, though listed with the first box's
  m <- og_map(pos) |>
    og_point(id = "a", section = "One") |>
    og_line(tows, id = "b", section = "Two") |>
    og_point(id = "c", section = "One")
  expect_identical(ids_of(m), c("a", "b", "c"))
  expect_identical(box_of(m), list(c("a", "c"), "b"))
  # `order`, from the lowest up: those named first, the others after in theirs; the boxes as they were
  m <- og_map(pos, order = c("c", "b")) |>
    og_point(id = "a", section = "One") |>
    og_line(tows, id = "b", section = "Two") |>
    og_point(id = "c", section = "One")
  expect_identical(ids_of(m), c("c", "b", "a"))
  expect_identical(box_of(m), list(c("a", "c"), "b"))
  # og_map() with no data, and a layer of one's own added
  dem <- og_layer("depth", "dem", label = "Depth", tiles = function(z, x, y) raw(0),
                  style = list(list(id = "depth-colour", type = "color-relief")))
  m <- og_map(order = "tows") |>
    og_point(pos, id = "positions") |>
    og_add_layer(dem, section = "Sea floor") |>
    og_line(tows, id = "tows")
  expect_identical(ids_of(m), c("tows", "positions", "depth"))
  # a layer `order` names that the pipe has not added (yet): the map is made, and refused once it is shown
  m <- og_map(pos, order = c("a", "nosuch")) |> og_point(id = "a")
  expect_identical(ids_of(m), "a")
  expect_error(og_bundle(m, withr::local_tempdir(), overwrite = TRUE), "`order` names no layer of the map: nosuch")
  expect_error(.og_map_app(m), "`order` names no layer of the map: nosuch")
  expect_error(og_map(order = c("a", "a")), "each once")
  expect_error(og_map(pos, order = 1), "each once")
  expect_error(og_map(order = NA_character_), "each once")
})

test_that("a map of og_section()s draws its sections' layers in order, unless `order` says otherwise", {
  lay <- function(id) {
    og_layer(id, "vector", label = id, tiles = function(z, x, y) raw(0),
             style = list(list(id = paste0(id, "-fill"), type = "fill", "source-layer" = "features")))
  }
  s1 <- og_section("s1", "One", list(lay("x"), lay("y")))
  s2 <- og_section("s2", "Two", list(lay("z")))
  expect_identical(ids_of(og_map(s1, s2)), c("x", "y", "z"))
  m <- og_map(s1, s2, order = c("z", "y"))
  expect_identical(ids_of(m), c("z", "y", "x"))
  expect_identical(box_of(m), list(c("x", "y"), "z"))
  # refused at once: the layers are all there
  expect_error(og_map(s1, s2, order = "w"), "`order` names no layer of the map: w")
})

test_that("in the page, the layers are drawn in the map's order, not in the order their data arrive", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  pos <- og_example("trawlsurvey")
  styles <- function(b) {
    setdiff(unlist(page_eval(b, "map.getStyle().layers.filter(l => !/^(base|place_|water)/.test(l.id)).map(l => l.id)")), character())
  }
  # the points' file is larger than the texts' and comes later in a bundle; then `order` turns them about
  for (order in list(NULL, c("ids"))) {
    dir <- withr::local_tempdir()
    m <- og_map(pos, order = order) |>
      og_point(id = "positions", popup = c(vid, time, speed, behaviour)) |>
      og_text(label = vid, id = "ids", section = "Labels") |>
      og_line(og_example("trawlsurveytows"), id = "tows")
    og_bundle(m, dir, overwrite = TRUE)
    b <- open_page(paste0(serve_dir(dir), "index.html"))
    expect_true(wait_until(function() {
      isTRUE(page_eval(b, "typeof map !== 'undefined' && ['positions-dot', 'ids-text', 'tows-line'].every(id => !!map.getLayer(id))"))
    }, 40))
    want <- if (is.null(order)) c("positions-dot", "ids-text", "tows-line") else c("ids-text", "positions-dot", "tows-line")
    expect_identical(styles(b), want, info = paste("order:", paste(order, collapse = ",")))
    # and so after another base map
    page_eval(b, "document.querySelector('#bases input[value=none]').click() ?? true")
    expect_true(wait_until(function() identical(styles(b), want), 20))
    b$close()
  }
})
