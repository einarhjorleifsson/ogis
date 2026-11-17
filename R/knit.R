# knit.R — a map printed in R Markdown or Quarto: written as a bundle and shown live in the page, in an iframe.

#' A map in R Markdown, Quarto and pkgdown articles
#'
#' A map printed in a chunk of an R Markdown or Quarto document, or of a pkgdown article, is shown live in the rendered
#' page: it pans, zooms and answers clicks, as in a browser. It is written as a bundle ([rr_bundle()]) and put beside
#' the document as one of its dependencies, as htmlwidgets put theirs, and shown in an iframe; the libraries it needs
#' (MapLibre and the others) are one copy for all the maps of a document or a site. Nothing is served: a map's tiles
#' and data are files in the bundle, so a document's maps want small data (a bundle over 25 MB says so). A layer
#' whose tiles only a server can make is left out, as in [rr_bundle()].
#'
#' The chunk options `out.width` and `out.height` set the map's size in the page (by default the page's width and
#' 480 pixels). The document must keep its files beside it, as pkgdown and Quarto do and R Markdown does with
#' `self_contained: false`; a self-contained page says so where the map would be.
#'
#' @param x An [rr_map()].
#' @param ... Not used.
#' @param options The chunk's options, given by knitr.
#' @return The page's code for the map, with its dependencies, for knitr.
#' @seealso [rr_bundle()], [print.rr_map()]
#' @exportS3Method knitr::knit_print
#' @keywords internal
knit_print.rr_map <- function(x, ..., options = NULL) {
  .rr_need("knitr")
  .rr_need("htmltools")
  dir <- tempfile("rr-map-")
  version <- as.character(utils::packageVersion("rebelrebel"))
  # a dependency's folder is its name and version: the shared libraries' "rebelrebel-vendor-<version>", beside the map's
  out <- .rr_bundle(x, dir, vendor = sprintf("../rebelrebel-vendor-%s/", version))
  # the map's name: its files' fingerprint, so two maps of a document never share a folder and a map knitted again
  # unchanged keeps its name
  files <- sort(list.files(dir, recursive = TRUE, full.names = TRUE))
  sums <- tempfile(fileext = ".txt")
  writeLines(paste(sub(dir, "", files, fixed = TRUE), tools::md5sum(files)), sums, useBytes = TRUE)
  name <- paste0("rr-map-", substr(unname(tools::md5sum(sums)), 1, 12))
  unlink(sums)
  # the locator: the page's own script tag says where the dependency's folder landed, and the iframe is pointed at it
  writeLines(.rr_locator(name), file.path(dir, "rr-locate.js"), useBytes = TRUE)
  mb <- attr(out, "bytes") / 1e6
  if (isTRUE(mb > 25)) {
    warning(sprintf("This map's bundle is %.0f MB, carried whole by the document and its site: smaller data, or a lower `maxzoom` in rr_bundle(), keep it light.", mb),
            call. = FALSE)
  }
  # a size as the chunk gives it: text as it is ("100%", "600px"), a number in pixels. knitr gives every chunk a width
  # in pixels from its figures' (`fig.width` times 96), which is taken as no width given: the page's
  size <- function(v, default, figure = NULL) {
    if (is.null(v) || (is.numeric(v) && isTRUE(all.equal(v, figure)))) return(default)
    if (is.numeric(v)) return(paste0(v, "px"))
    as.character(v)
  }
  title <- .rr_or(x$config$title, "Map")
  html <- sprintf(
    '<iframe class="rr-map" data-rr-map="%s" title="%s" style="width:%s;height:%s;border:1px solid #d9d9d9;border-radius:4px;display:block" loading="lazy"></iframe>',
    name, htmltools::htmlEscape(title, attribute = TRUE),
    size(options$out.width, "100%", if (is.numeric(options$fig.width)) options$fig.width * 96),
    size(options$out.height, "480px")
  )
  deps <- list(
    htmltools::htmlDependency("rebelrebel-vendor", version = version,
                              src = system.file("engine", "vendor", package = "rebelrebel"), all_files = TRUE),
    htmltools::htmlDependency(name, version = "1", src = dir, script = "rr-locate.js", all_files = TRUE)
  )
  knitr::asis_output(html, meta = deps)
}

# The locator's script: run from the map's dependency folder, it points the map's iframe at that folder's page. A
# self-contained document inlines it (no folder): the iframe then says why it is empty
.rr_locator <- function(name) {
  sprintf(
    '(function () {
  var s = document.currentScript, src = s ? s.src : "", name = "%s";
  function go() {
    var f = document.querySelectorAll(\'iframe[data-rr-map="\' + name + \'"]\');
    for (var i = 0; i < f.length; i++) {
      if (!src || src.indexOf("data:") === 0) {
        f[i].srcdoc = "<p style=\\"font:15px system-ui,sans-serif;padding:1em\\">This map is a folder beside the page: render the document with <code>self_contained: false</code> (pkgdown and Quarto keep the folders).</p>";
      } else {
        f[i].src = src.replace(/rr-locate[.]js([?#].*)?$/, "index.html");
      }
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", go); else go();
})();',
    name
  )
}
