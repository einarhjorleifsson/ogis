# The page's engine in a browser: what it must survive

test_that("a click survives MapLibre's lost index: the layer's data sent again, the click tried again", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  m <- og_example("trawlsurvey") |> og_point(popup = c(vid, speed), name = "Points")
  og_bundle(m, dir, overwrite = TRUE)
  b <- open_page(paste0(serve_dir(dir), "index.html"))
  errors <- character()
  b$Runtime$enable()
  b$Runtime$exceptionThrown(callback_ = function(x) errors <<- c(errors, x$exceptionDetails$exception$description))
  expect_true(wait_until(function() isTRUE(page_eval(b, 'map.loaded() && map.queryRenderedFeatures({ layers: ["points-dot"] }).length > 0')), 30))
  # MapLibre 5's fault, as it shows: every query of the layer throws until its source is loaded again
  xy <- unlist(page_eval(b, '(() => {
    const orig = map.queryRenderedFeatures.bind(map), src = map.getSource("points"), sd = src.setData.bind(src);
    window.STALE = true; window.SENT = 0;
    src.setData = d => { window.SENT++; window.STALE = false; return sd(d); };
    map.queryRenderedFeatures = (a, b) => { const o = b ?? a;
      if (window.STALE && o?.layers?.includes("points-dot")) throw new Error("Out of bounds. Index requested n=0 can\'t be >= this._numberToString.length 0");
      return orig(a, b); };
    const f = orig({ layers: ["points-dot"] })[0], p = map.project(f.geometry.coordinates), r = map.getContainer().getBoundingClientRect();
    return [r.left + p.x, r.top + p.y];
  })()'))
  for (type in c("mouseMoved", "mousePressed", "mouseReleased")) {
    b$Input$dispatchMouseEvent(type = type, x = xy[1], y = xy[2], button = if (type == "mouseMoved") "none" else "left",
                               clickCount = if (type == "mouseMoved") 0 else 1)
  }
  expect_true(wait_until(function() isTRUE(page_eval(b, '!!document.querySelector(".maplibregl-popup")')), 20))
  expect_identical(page_eval(b, "window.SENT"), 1L)
  # the row as a table once read from the bundle's rows (a moment after the popup opens)
  expect_true(wait_until(function() grepl("speed", page_eval(b, 'document.querySelector(".maplibregl-popup")?.textContent ?? ""')), 20))
  expect_length(errors, 0)
})

test_that("every query of the page is guarded: none calls MapLibre's queryRenderedFeatures but query()", {
  page <- readLines(system.file("engine", "index.html", package = "ogis"), warn = FALSE)
  calls <- grep("map[.]queryRenderedFeatures", page, value = TRUE)
  expect_length(calls, 1) # in query() itself
  expect_match(calls, "const q = list =>", fixed = TRUE)
  # nor a layer's own mouse handler, map.on(type, layer, fn) (MapLibre queries for them, unguarded)
  expect_length(grep('map[.]on[(]"(click|mouseenter|mouseleave|mousemove|mouseover|mouseout)", *[^,()]+, ', page), 0)
})

test_that("served: a note's pin opens its note, a hover shows a label, the pointer turns over a feature", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  skip_if(!isTRUE(l10n_info()[["UTF-8"]]), "notes are written in a UTF-8 locale")
  pings <- og_example("trawlsurvey")
  at <- dplyr::collect(utils::head(dplyr::arrange(pings, time), 400))[c(1, 400), ] # a ping, and one far from it
  notes <- file.path(withr::local_tempdir(), "notes.geojson")
  og_notes_add(notes, "a note on the first ping", lon = at$lon[1], lat = at$lat[1])
  m <- pings |> og_point(popup = c(vid, speed), hover = vid, name = "Points")
  url <- og_serve(m, open = FALSE, wait = FALSE, notes = notes)
  withr::defer(og_stop(as.integer(sub(".*:([0-9]+)/$", "\\1", url))))
  b <- open_page(url)
  expect_true(wait_until(function() isTRUE(page_eval(b, 'map.loaded() && !!map.getLayer("og-notes-dot") && map.queryRenderedFeatures({ layers: ["og-notes-dot"] }).length > 0')), 30))
  px <- function(lon, lat) unlist(page_eval(b, sprintf(
    '(() => { const p = map.project([%.8f, %.8f]), r = map.getContainer().getBoundingClientRect(); return [r.left + p.x, r.top + p.y]; })()', lon, lat)))
  mouse <- function(xy, click = FALSE) {
    for (type in if (click) c("mouseMoved", "mousePressed", "mouseReleased") else "mouseMoved") {
      b$Input$dispatchMouseEvent(type = type, x = xy[1], y = xy[2], button = if (type == "mouseMoved") "none" else "left",
                                 clickCount = if (type == "mouseMoved") 0 else 1)
    }
  }
  # the pin over the point: a click opens the note, not the point's row
  page_eval(b, sprintf("map.jumpTo({ center: [%.8f, %.8f], zoom: 12 }) && true", at$lon[1], at$lat[1]))
  expect_true(wait_until(function() isTRUE(page_eval(b, "map.loaded()")), 20))
  mouse(px(at$lon[1], at$lat[1]), click = TRUE)
  expect_true(wait_until(function() grepl("a note on the first ping", page_eval(b, 'document.querySelector(".maplibregl-popup")?.textContent ?? ""')), 20))
  # over a point the pointer is a hand and the hover label names its group; off it, neither
  page_eval(b, 'document.querySelector(".maplibregl-popup-close-button")?.click() ?? true')
  page_eval(b, sprintf("map.jumpTo({ center: [%.8f, %.8f], zoom: 12 }) && true", at$lon[2], at$lat[2]))
  expect_true(wait_until(function() isTRUE(page_eval(b, "map.loaded()")), 20))
  mouse(px(at$lon[2], at$lat[2]))
  expect_true(wait_until(function() identical(page_eval(b, "map.getCanvas().style.cursor"), "pointer"), 10))
  expect_true(wait_until(function() grepl(as.character(at$vid[2]), page_eval(b, 'document.querySelector(".og-hover")?.textContent ?? "-"')), 10))
  r <- page_eval(b, "(() => { const r = map.getContainer().getBoundingClientRect(); return [r.left + 5, r.top + r.height - 5]; })()")
  mouse(unlist(r))
  expect_true(wait_until(function() identical(page_eval(b, "map.getCanvas().style.cursor"), ""), 10))
})
