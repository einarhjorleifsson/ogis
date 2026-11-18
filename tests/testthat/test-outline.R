# A point drawn as a ring (rr_point(stroke = )), an area's outline alone (rr_polygon(fill = NA))

paint_of <- function(m, i = 1, j = 1) m$config$layers[[i]]$style[[j]]$paint

test_that("stroke draws a point as a ring of its colour, its legend and colour choices a ring's", {
  skip_if_no_spatial()
  pos <- rr_example("trawlsurvey")
  m <- rr_map(pos) |> rr_point(colour = "#00a5c8", size = 14, stroke = 2, id = "fast")
  p <- paint_of(m)
  expect_identical(p[["circle-opacity"]], 0)
  expect_identical(p[["circle-stroke-color"]], "#00A5C8")
  expect_identical(p[["circle-stroke-width"]], 2)
  expect_identical(p[["circle-radius"]], 7)
  expect_identical(p[["circle-stroke-opacity"]], 0.85)
  expect_identical(m$config$layers[[1]]$legend[[1]]$swatch, list(ring = "#00A5C8"))
  # by columns: each choice paints the ring
  m <- rr_map(pos) |> rr_point(colour = c(behaviour, speed), stroke = 1.5, opacity = 0.6)
  l <- m$config$layers[[1]]
  expect_identical(l$style[[1]]$paint[["circle-stroke-opacity"]], 0.6)
  expect_true(all(vapply(l$variants$options, function(o) names(o$paint[[1]]) == "circle-stroke-color", NA)))
  expect_true(all(unlist(lapply(l$legend, function(e) names(e$swatch))) == "ring"))
  # MapLibre's own terms still win
  m <- rr_map(pos) |> rr_point(stroke = 2, "circle-stroke-width" = 4)
  expect_identical(paint_of(m)[["circle-stroke-width"]], 4)
  # a filled point as before
  p <- paint_of(rr_map(pos) |> rr_point(size = 6))
  expect_identical(p[["circle-opacity"]], 0.85)
  expect_identical(p[["circle-stroke-color"]], "rgba(255,255,255,0.7)")
  for (bad in list("2", -1, 0, c(1, 2), NA_real_)) {
    expect_error(rr_map(pos) |> rr_point(stroke = bad), "`stroke` is a ring's width", info = format(bad))
  }
})

test_that("fill = NA draws an area's outline alone, its fill clear so a click inside still finds it", {
  skip_if_no_spatial()
  h <- rr_example("dansk_harbours")
  m <- rr_map(h) |> rr_polygon(fill = NA, colour = "#b2182b", id = "h")
  fill <- paint_of(m, 1, 1)
  line <- paint_of(m, 1, 2)
  expect_identical(fill[["fill-opacity"]], 0)
  expect_identical(line[["line-color"]], "#B2182B")
  expect_identical(line[["line-width"]], 2)
  expect_identical(line[["line-opacity"]], 0.9)
  expect_identical(m$config$layers[[1]]$legend[[1]]$swatch, list(fill = "transparent", stroke = "#B2182B"))
  expect_identical(unlist(m$config$layers[[1]]$popup$click), "h-fill")
  # its width and opacity as given; NA as text too
  m <- rr_map(h) |> rr_polygon(fill = NA_character_, linewidth = 1, opacity = 0.5)
  expect_identical(paint_of(m, 1, 2)[["line-width"]], 1)
  expect_identical(paint_of(m, 1, 2)[["line-opacity"]], 0.5)
  # a filled area as before
  m <- rr_map(h) |> rr_polygon(fill = "#d9822b")
  expect_identical(paint_of(m, 1, 1)[["fill-opacity"]], 0.5)
  expect_identical(paint_of(m, 1, 2)[["line-width"]], 1)
  expect_null(paint_of(m, 1, 2)[["line-opacity"]])
})

test_that("in the page, a ring and an outline are drawn, and a click inside each finds its row", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  pos <- rr_example("trawlsurvey")
  dir <- withr::local_tempdir()
  m <- rr_map(view = list(center = c(-21, 64.5), zoom = 5)) |>
    rr_polygon(rr_example("dansk_harbours"), fill = NA, colour = "#b2182b", id = "harbours") |>
    rr_point(pos, colour = behaviour, size = 30, stroke = 3, id = "rings")
  rr_bundle(m, dir, overwrite = TRUE)
  b <- open_page(paste0(serve_dir(dir), "index.html"))
  expect_true(wait_until(function() {
    isTRUE(page_eval(b, "typeof map !== 'undefined' && map.loaded() && map.queryRenderedFeatures({ layers: ['rings-dot'] }).length > 0"))
  }, 40))
  # the centre of a ring: inside it, where nothing is painted, a click still finds it
  hit <- function(layer, lnglat_js) {
    page_eval(b, sprintf("map.queryRenderedFeatures(map.project(%s), { layers: ['%s'] }).length", lnglat_js, layer))
  }
  expect_gt(hit("rings-dot", "map.queryRenderedFeatures({ layers: ['rings-dot'] })[0].geometry.coordinates"), 0)
  expect_match(page_eval(b, "document.querySelector('#rings-legend i').getAttribute('style')"), "border:2px solid")
  # a harbour's middle, inside its outline
  page_eval(b, "map.jumpTo({ center: [12.6, 55.69], zoom: 12 }) && true")
  expect_true(wait_until(function() isTRUE(page_eval(b, "map.loaded() && map.queryRenderedFeatures({ layers: ['harbours-outline'] }).length > 0")), 30))
  inside <- paste0("(() => { const g = map.queryRenderedFeatures({ layers: ['harbours-fill'] })[0].geometry,",
                   " r = g.type === 'Polygon' ? g.coordinates[0] : g.coordinates[0][0];",
                   " return r.slice(0, -1).reduce((s, c) => [s[0] + c[0] / (r.length - 1), s[1] + c[1] / (r.length - 1)], [0, 0]); })()")
  expect_gt(hit("harbours-fill", inside), 0)
  expect_identical(page_eval(b, "map.getPaintProperty('harbours-fill', 'fill-opacity')"), 0L)
})
