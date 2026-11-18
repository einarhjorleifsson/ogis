# rr_add_layer(): an rr_layer() of your own on a map the pipe makes (rr_map(), with data or none, and the layer
# functions), in a section of its own, served and drawn as the others

# a dem layer on tiles that need no grid: each tile four bytes, its extent and zooms as rr_tiles_mbtiles() gives them
stub_dem <- function(id = "depth", bounds = c(2.5, 54.5, 13, 58.5)) {
  tiles <- structure(function(z, x, y) as.raw(1:4), bounds = bounds, minzoom = 0L, maxzoom = 6L, format = "png",
                     encoding = "terrarium", tile_size = 512L)
  rr_layer(id, "dem", label = "Depth", tiles = tiles,
           style = list(list(id = paste0(id, "-colour"), type = "color-relief")),
           colour = list(palette = "grey", opacity = 75))
}

test_that("a piped map takes an rr_layer() in a section of its own, its view, script and later layers kept", {
  skip_if_no_spatial()
  dem <- stub_dem()
  m <- rr_map(view = list(center = c(10, 56), zoom = 6), sections = list(`Sea floor` = list(open = FALSE))) |>
    rr_add_layer(dem, section = "Sea floor") |>
    rr_polygon(rr_example("dansk_harbours"), name = "Harbours") |>
    rr_script("rr.panel('Mine');")
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("depth", "harbours"))
  expect_identical(vapply(m$config$groups, `[[`, "", "title"), c("Sea floor", "Layers"))
  expect_false(m$config$groups[[1]]$open)
  expect_identical(unlist(m$config$groups[[1]]$layers), "depth")
  expect_identical(m$config$view, list(center = list(10, 56), zoom = 6))
  expect_identical(m$config$scripts[[1]]$js, "rr.panel('Mine');")
  # the layer as given: its colour, its tiles' function for the server
  dl <- m$config$layers[[1]]
  expect_identical(dl$colour$palette, "grey")
  expect_identical(dl$colour$opacity, 75)
  expect_true(is.function(m$layers$depth$tiles))
  # a layer after it keeps it, and a script before it is kept too
  m2 <- rr_map() |> rr_script("rr.panel('First');") |> rr_add_layer(dem) |> rr_point(rr_example("trawlsurvey"))
  expect_identical(vapply(m2$config$layers, `[[`, "", "id"), c("depth", "points"))
  expect_identical(vapply(m2$config$groups, `[[`, "", "title"), "Layers")
  expect_identical(m2$config$scripts[[1]]$js, "rr.panel('First');")
  # the rows decide the first view, not the tiles' extent (Iceland's positions, Denmark's depths)
  expect_lt(unlist(m2$config$view$bounds)[3], 0)
  # served: the layer's tiles answer
  get <- function(app, path) app$call(list(REQUEST_METHOD = "GET", PATH_INFO = path, QUERY_STRING = ""))
  r <- get(.rr_map_app(m), "/tiles/depth/1/1/0.png")
  expect_identical(r$status, 200L)
  expect_identical(r$body, as.raw(1:4))
})

test_that("a piped map of tiles alone fits their extent, else the world; several layers at once; ids kept apart", {
  m <- rr_map() |> rr_add_layer(stub_dem())
  expect_identical(unlist(m$config$view$bounds), c(2.5, 54.5, 13, 58.5))
  expect_identical(format(m)[2], "  layers: depth (dem)")
  point <- rr_layer("point", "geojson", data = '{"type": "Point", "coordinates": [12.6, 56.0]}',
                    style = list(list(id = "point-dot", type = "circle")))
  m <- rr_map() |> rr_add_layer(point)
  expect_identical(unlist(m$config$view$bounds), c(-180, -85, 180, 85))
  m <- rr_map() |> rr_add_layer(list(stub_dem(), point), section = "Mine")
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("depth", "point"))
  expect_identical(unlist(m$config$groups[[1]]$layers), c("depth", "point"))
  expect_error(m |> rr_add_layer(point), "Layer id \"point\" is taken")
  expect_error(rr_map() |> rr_add_layer(list(point, point)), "Layer id \"point\" is taken")
})

test_that("a layer function after an rr_add_layer() takes a free id and the map's data and choices", {
  skip_if_no_spatial()
  pos <- rr_layer("positions", "geojson", data = '{"type": "Point", "coordinates": [-20, 64]}',
                  style = list(list(id = "positions-dot", type = "circle")))
  # the map's data read by the layer function, its choices made then, with no warning
  expect_no_warning(
    m <- rr_map(rr_example("trawlsurvey"), choose = c(behaviour)) |>
      rr_add_layer(pos, section = "Mine") |>
      rr_point(name = "Positions")
  )
  expect_identical(vapply(m$config$layers, `[[`, "", "id"), c("positions", "positions_2"))
  expect_identical(vapply(m$config$choose$fields, `[[`, "", "field"), "behaviour")
  expect_identical(unlist(m$config$choose$fields[[1]]$layers), "positions_2")
})

test_that("rr_add_layer() says what it takes; a map of rr_section()s says how to add to it", {
  skip_if_no_spatial()
  dem <- stub_dem()
  expect_error(rr_add_layer(list(), dem), "`map` is an rr_map()")
  sectioned <- rr_map(rr_section("s", "S", list(dem)))
  expect_error(rr_add_layer(sectioned, stub_dem("other")), "give the layer to one of them")
  expect_error(rr_add_layer(rr_map(), list(1)), "an rr_layer\\(\\), or a list of them")
  expect_error(rr_add_layer(rr_map(), dem, section = ""), "`section` is the title")
  expect_error(rr_point(sectioned, rr_example("trawlsurvey")), "add each rr_layer\\(\\) of your own to it with rr_add_layer")
})

test_that("in the page: a layer added to the pipe is fetched and drawn under the base map's labels, the text over it", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  skip_if_not_installed("png")
  skip_if_not_installed("terra")
  skip_if_offline("tiles.basemaps.cartocdn.com") # the base map's style and fonts
  g <- expand.grid(lon = seq(10, 10.4, by = 0.02), lat = seq(56, 56.3, by = 0.01))
  g$elevation <- -20 - 100 * (g$lon - 10)
  made <- rr_tiles_dem(g)
  asked <- 0L
  tiles <- function(z, x, y) {
    asked <<- asked + 1L
    made(z, x, y)
  }
  attributes(tiles) <- attributes(made)
  depth <- rr_layer("depth", "dem", label = "Depth", tiles = tiles,
                    style = list(list(id = "depth-colour", type = "color-relief")),
                    colour = list(palette = "grey", opacity = 75))
  places <- data.frame(name = c("Alfa", "Bravo"), lon = c(10.1, 10.3), lat = c(56.1, 56.2))
  m <- rr_map(view = list(center = c(10.2, 56.15), zoom = 9)) |>
    rr_add_layer(depth, section = "Sea floor") |>
    rr_text(places, label = name, overlap = TRUE, id = "names") |>
    rr_script("window.SCRIPT_RAN = true;")
  url <- rr_serve(m, open = FALSE, wait = FALSE, routes = list(ping = function(req) list(ok = TRUE)))
  withr::defer(rr_stop(as.integer(sub(".*:([0-9]+)/$", "\\1", url))))
  b <- open_page(url)
  expect_true(wait_until(function() isTRUE(page_eval(b, paste(
    "window.SCRIPT_RAN === true && !!map.getLayer('depth-colour') && !!map.getLayer('names-text')",
    "&& map.isSourceLoaded('depth')"
  ))), 40))
  expect_gt(asked, 0L) # the page asked the server for the layer's tiles
  # the style's order: the elevations under the base map's first label, the text over them
  ids <- unlist(page_eval(b, "map.getStyle().layers.map(l => l.id)"))
  src <- unlist(page_eval(b, "map.getStyle().layers.map(l => l.source ?? '')"))
  type <- unlist(page_eval(b, "map.getStyle().layers.map(l => l.type)"))
  first_label <- which(type == "symbol" & !src %in% c("depth", "names"))[1]
  expect_false(is.na(first_label))
  expect_lt(match("depth-colour", ids), first_label)
  expect_gt(match("names-text", ids), match("depth-colour", ids))
  # its section in the sidebar, as named
  expect_match(page_eval(b, "document.body.textContent"), "Sea floor")
  b$close()
})
