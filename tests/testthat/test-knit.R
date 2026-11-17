# A map printed in R Markdown, Quarto or a pkgdown article: a bundle as a dependency, shown live in an iframe

knit_map <- function(m, options = list(fig.width = 7)) {
  out <- knitr::knit_print(m, options = options)
  list(out = out, html = as.character(out), deps = attr(out, "knit_meta"))
}

test_that("a printed map is an iframe, its bundle a dependency, the libraries one shared copy", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("htmltools")
  skip_if_no_spatial()
  m <- rr_example("trawlsurveytows") |> rr_line(name = "Tows")
  k <- knit_map(m)
  expect_s3_class(k$out, "knit_asis")
  expect_match(k$html, '^<iframe class="rr-map" data-rr-map="rr-map-[0-9a-f]{12}"')
  expect_match(k$html, "width:100%;height:480px")
  expect_length(k$deps, 2)
  vendor <- k$deps[[1]]
  map <- k$deps[[2]]
  expect_identical(vendor$name, "rebelrebel-vendor")
  expect_identical(vendor$version, as.character(utils::packageVersion("rebelrebel")))
  expect_true(file.exists(file.path(vendor$src$file, "maplibre-gl.js")))
  expect_identical(map$script, "rr-locate.js")
  expect_true(isTRUE(map$all_files))
  # the bundle carries no libraries of its own, and its page reads the shared copy beside it
  expect_false(dir.exists(file.path(map$src$file, "vendor")))
  page <- paste(readLines(file.path(map$src$file, "index.html"), warn = FALSE), collapse = "\n")
  shared <- sprintf("../rebelrebel-vendor-%s/", vendor$version)
  expect_match(page, paste0('src="', shared, "maplibre-gl.js"), fixed = TRUE)
  expect_no_match(page, '"vendor/', fixed = TRUE)
  # the locator names its map's iframe
  expect_match(paste(readLines(file.path(map$src$file, "rr-locate.js")), collapse = "\n"), map$name, fixed = TRUE)
})

test_that("a map's name follows its content, and the chunk's size is the map's", {
  skip_if_not_installed("knitr")
  skip_if_not_installed("htmltools")
  skip_if_no_spatial()
  a <- knit_map(rr_example("trawlsurveytows") |> rr_line(name = "Tows"))
  b <- knit_map(rr_example("trawlsurveytows") |> rr_line(name = "Tows"))
  c <- knit_map(rr_example("trawlsurveytows") |> rr_line(name = "The tows"))
  expect_identical(a$deps[[2]]$name, b$deps[[2]]$name)
  expect_false(identical(a$deps[[2]]$name, c$deps[[2]]$name))
  # knitr's default width (the figures', 7 in at 96 px) is the page's; a size given is kept
  s <- knit_map(rr_example("trawlsurveytows") |> rr_line(), options = list(fig.width = 7, out.width = 672, out.height = 300))
  expect_match(s$html, "width:100%;height:300px")
  s <- knit_map(rr_example("trawlsurveytows") |> rr_line(), options = list(fig.width = 7, out.width = "60%", out.height = "20em"))
  expect_match(s$html, "width:60%;height:20em")
})

test_that("a map started from data opens on its rows' extent, and a view may be an extent", {
  skip_if_no_spatial()
  m <- rr_example("trawlsurveytows") |> rr_line()
  b <- unlist(m$config$view$bounds)
  expect_length(b, 4)
  expect_true(b[1] < b[3] && b[2] < b[4])
  v <- rr_map(rr_section("s", "S", list()), view = list(bounds = c(-25, 63, -13, 67)))$config$view
  expect_equal(unlist(v$center), c(-19, 65))
  expect_equal(unlist(v$bounds), c(-25, 63, -13, 67))
})

render_doc <- function(dir, self_contained = FALSE) {
  writeLines(c(
    "---", "title: Two maps", "output:", "  html_document:", sprintf("    self_contained: %s", tolower(self_contained)), "---",
    "", "```{r}", "library(rebelrebel)", 'rr_example("trawlsurvey") |> rr_point(colour = behaviour)', "```",
    "", "```{r, out.height = 300}", 'rr_example("trawlsurveytows") |> rr_line(name = "Tows")', "```"
  ), file.path(dir, "doc.Rmd"))
  # rendered in a fresh R, with this rebelrebel (installed, or the one loaded for the tests)
  rmarkdown::render(file.path(dir, "doc.Rmd"), quiet = TRUE, envir = new.env())
}

test_that("a document's maps draw in the rendered page, fitted to their frames", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "no pandoc")
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  render_doc(dir)
  deps <- list.files(file.path(dir, "doc_files"))
  expect_true(paste0("rebelrebel-vendor-", utils::packageVersion("rebelrebel")) %in% deps)
  expect_equal(sum(grepl("^rr-map-[0-9a-f]{12}-1$", deps)), 2)
  b <- open_page(paste0(serve_dir(dir), "doc.html"), height = 1400)
  js <- '(() => [...document.querySelectorAll("iframe.rr-map")].map(f => { const w = f.contentWindow;
    const own = JSON.parse(w.document.getElementById("config").textContent).layers.map(l => l.id);
    const ids = w.eval("map.getStyle().layers.map(l => l.id)").filter(id => own.some(o => id.startsWith(o + "-")));
    return { zoom: w.eval("map.getZoom()"), loaded: w.eval("map.loaded()"),
             n: ids.length ? w.eval("map.queryRenderedFeatures({ layers: " + JSON.stringify(ids) + " }).length") : 0 }; }))()'
  expect_true(wait_until(function() {
    v <- page_eval(b, js)
    length(v) == 2 && all(vapply(v, function(x) isTRUE(x$loaded) && x$n > 0, logical(1)))
  }, 60))
  v <- page_eval(b, js)
  expect_equal(v[[1]]$n, 8918) # every point of the survey drawn
  expect_gt(v[[2]]$n, 580) # every tow, some in two tiles' pieces
  # fitted to the frame: Iceland's waters fill it (the old rule gave zoom 3 whatever the frame)
  expect_gt(v[[1]]$zoom, 4)
})

test_that("a self-contained document says where its maps went", {
  skip_if_not_installed("rmarkdown")
  skip_if_not(rmarkdown::pandoc_available(), "no pandoc")
  skip_if_no_spatial()
  skip_if_no_chrome()
  dir <- withr::local_tempdir()
  render_doc(dir, self_contained = TRUE)
  # file:///C:/... on Windows, file:///tmp/... elsewhere
  b <- open_page(paste0("file:///", sub("^/", "", normalizePath(file.path(dir, "doc.html"), winslash = "/"))))
  expect_true(wait_until(function() {
    all(grepl("self_contained", unlist(page_eval(b, '[...document.querySelectorAll("iframe.rr-map")].map(f => f.srcdoc)'))))
  }, 20))
})

test_that("rr_map() alone starts a map whose layers bring their own data", {
  skip_if_no_spatial()
  m <- rr_map() |>
    rr_line(rr_example("trawlsurveytows"), name = "Tows") |>
    rr_point(rr_example("trawlsurvey"), colour = behaviour, name = "Positions", visible = FALSE)
  expect_identical(vapply(m$config$layers, function(l) l$id, ""), c("tows", "positions"))
  expect_length(unlist(m$config$view$bounds), 4)
  expect_error(rr_map() |> rr_point(), "has no data")
})

test_that("a Quarto document's maps draw in the rendered page", {
  skip_if_no_spatial()
  skip_if_no_chrome()
  skip_if(!nzchar(Sys.which("quarto")), "no Quarto")
  # Quarto runs R in a process of its own, which loads the installed rebelrebel: only this one will do
  installed <- tryCatch(utils::packageDescription("rebelrebel", lib.loc = .libPaths())$Version, error = function(e) "")
  skip_if(!identical(installed, as.character(utils::packageVersion("rebelrebel"))),
          "the installed rebelrebel is not the one tested (Quarto's R loads the installed one)")
  dir <- withr::local_tempdir()
  writeLines(c(
    "---", "title: Two maps", "format: html", "---", "",
    "```{r}", "library(rebelrebel)", 'rr_example("trawlsurveytows") |> rr_line(name = "Tows")', "```", "",
    "```{r}", "#| out-height: 300px", 'rr_example("trawlsurvey") |> rr_point(colour = behaviour)', "```"
  ), file.path(dir, "doc.qmd"))
  res <- system2(Sys.which("quarto"), c("render", shQuote(file.path(dir, "doc.qmd")), "--quiet"), stdout = TRUE, stderr = TRUE)
  expect_true(file.exists(file.path(dir, "doc.html")), info = paste(res, collapse = "\n"))
  b <- open_page(paste0(serve_dir(dir), "doc.html"), height = 1200)
  js <- '[...document.querySelectorAll("iframe.rr-map")].map(f => f.contentWindow.eval("map.loaded() && map.queryRenderedFeatures().length > 0"))'
  expect_true(wait_until(function() {
    v <- unlist(page_eval(b, js))
    length(v) == 2 && all(v)
  }, 60))
  expect_match(paste(readLines(file.path(dir, "doc.html"), warn = FALSE), collapse = ""), "height:300px", fixed = TRUE)
})
