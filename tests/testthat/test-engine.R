# The page's engine in a browser: what it must survive

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
