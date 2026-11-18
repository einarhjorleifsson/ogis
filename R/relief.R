# relief.R — the sea floor as two layer functions: og_relief() (the depth in colour, and its relief shaded) and
# og_contour() (lines of equal depth, the chart depths heavier and labelled), each on a depth model given once, or
# named once on each computer by OGIS_DEPTH. The layers they make are og_layer()s, added as og_add_layer() adds them.

#' The sea floor: depth in colour, its relief, and depth contours
#'
#' `og_relief()` draws a depth model as two layers: the depth in colour, and its relief shaded. `og_contour()` draws
#' lines of equal depth from the same model: the chart depths (`major`) a little heavier and labelled, thinner lines
#' between them, spaced by depth and zoom. Both are made in the page from the model's tiles of elevations, so the
#' reader changes the colours, the shading and the lines with nothing asked of R; a bundle ([og_bundle()]) carries
#' them with no R at all. Each draws under the base map's place names, whatever its place in the pipe.
#'
#' The arguments are the starting look; the page's controls change it. They open folded under the layer's name, a
#' click on ▸ showing them (`open = TRUE` shows them from the start); the colours' scale bar shows either way.
#'
#' @section The depth model: `tiles` is the depth model, one of:
#'   * nothing (`NULL`): the file named by the environment variable `OGIS_DEPTH`, a line in `.Renviron`
#'     (`OGIS_DEPTH=D:/data/depth.mbtiles`; [og_tiles_mbtiles()] says more), so a script shared between colleagues
#'     carries no path;
#'   * the path of an MBTiles file of elevation tiles, read by [og_tiles_mbtiles()];
#'   * a grid: the path of a GeoTIFF or any grid GDAL reads, a terra `SpatRaster`, or a data frame of cells, made into
#'     tiles by [og_tiles_dem()] (to zoom 8 by default);
#'   * a tile function already made, by [og_tiles_mbtiles()] or [og_tiles_dem()]; give the same one to both functions
#'     for a grid in a data frame, so a bundle holds its tiles once.
#'
#'   Elevations are metres, negative below sea level, as both tile functions give them.
#'
#' @param map A map the pipe makes ([og_map()], with data or none, and any layer functions). Given the depth model
#'   instead (or nothing), a map is started for it, opening on the model's extent.
#' @param tiles The depth model (see *The depth model*).
#' @param palette The colours' look, one of the map's palettes: by default `"grey"`, quiet under the map's own data;
#'   `"quiet"`, `"seabed"`, `"deep"`, `"chart"`, `"drained"` and `"haxby"` are the other depth looks ([og_palettes()]).
#' @param opacity The colours' opacity, 0-100.
#' @param limits The depths (or heights) the palette's ends stand at, `c(floor, cap)` in metres from 1 to 10,000; by
#'   default fitted to the view, again each time the map settles (the 2nd and 98th percentiles of the values in view),
#'   until the reader sets them.
#' @param scale How the values are spread over the palette: `"log"`, `"linear"`, or `"equal"` (each colour an equal
#'   share of the values in view); by default equal shares.
#' @param shade The relief shaded, as a layer of its own: `TRUE`, at an intensity that follows the view; a number from
#'   0 to 1, that intensity; or `FALSE`, none.
#' @param of `"depth"` (below sea level, what is above left clear) or `"elevation"` (on land).
#' @param open Whether the layers' controls show when the page opens; folded by default.
#' @param name,info The layer's name in the sidebar (the relief's is "Relief") and the text behind its ⓘ.
#' @param id The layer's id, its key in the page's address; the relief's is `<id>_relief`.
#' @param section The sidebar's box the layers sit in, by its title.
#' @param visible Whether the layers are on when the page opens.
#' @param major The depths (or heights) of the heavier, labelled lines, in metres; by default the charts' isobaths
#'   from 10 to 5,000 m. Each shows from the zoom at which the thinner lines are no wider apart than it is deep.
#' @param minor Whether thinner lines are drawn between the major ones: every 25 m on the shelf at zoom 5, every 5 m
#'   from zoom 10, wider apart in deeper water (bands at 50, 200 and 1,000 m) and further out.
#' @param labels Whether the major lines carry their depth.
#' @param colour The lines' and labels' colour, `"#rrggbb"`.
#' @return The map, with the layers.
#' @seealso [og_tiles_mbtiles()] and [og_tiles_dem()] for the depth model; [og_layer()] for a layer in MapLibre's
#'   own terms.
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("png", quietly = TRUE) && requireNamespace("terra", quietly = TRUE)) {
#'   # the Danish waters' depth, its relief and contours, under the harbours
#'   depth <- og_tiles_dem(og_example("dansk_relief"), maxzoom = 6)
#'   og_map(view = list(bounds = c(2.5, 54.5, 13, 58.5))) |>
#'     og_relief(depth) |>
#'     og_contour(depth) |>
#'     og_polygon(og_example("dansk_harbours"), fill = NA, name = "Harbours")
#'
#'   # a depth model named once, by OGIS_DEPTH in .Renviron:
#'   # og_map() |> og_relief() |> og_contour()
#' }
#' }
og_relief <- function(
  map = NULL, tiles = NULL,
  palette = "grey", opacity = 75, limits = NULL, scale = NULL, shade = TRUE,
  of = c("depth", "elevation"), open = FALSE,
  name = "Depth", id = "depth", info = NULL, section = "Sea floor", visible = TRUE
) {
  of <- match.arg(of)
  s <- .og_seafloor_start(map, tiles, "og_relief")
  tiles <- .og_depth_tiles(s$tiles, "og_relief")
  .og_seafloor_common(open, visible, "og_relief")
  if (!is.character(palette) || length(palette) != 1 || is.na(palette)) {
    stop("og_relief(): `palette` is the id of one of the map's palettes.", call. = FALSE)
  }
  colour <- list(of = of, palette = palette, opacity = opacity, fit = TRUE)
  if (!is.null(limits)) {
    if (!is.numeric(limits) || length(limits) != 2 || anyNA(limits) || limits[1] >= limits[2]) {
      stop("og_relief(): `limits` is c(floor, cap), the floor below the cap.", call. = FALSE)
    }
    colour[c("floor", "cap", "auto")] <- list(limits[1], limits[2], FALSE)
  }
  if (!is.null(scale)) {
    colour$scale <- scale
  }
  layers <- list(.og_fold(og_layer(
    id, "dem", label = name, info = info, visible = visible, tiles = tiles,
    style = list(list(id = paste0(id, "-colour"), type = "color-relief")), colour = colour
  ), open))
  if (!isFALSE(shade)) {
    if (!isTRUE(shade) && !(is.numeric(shade) && length(shade) == 1 && !is.na(shade) && shade >= 0 && shade <= 1)) {
      stop("og_relief(): `shade` is TRUE, FALSE or an intensity from 0 to 1.", call. = FALSE)
    }
    sh <- if (isTRUE(shade)) list(fit = TRUE) else list(exaggeration = shade, fit = TRUE, auto = FALSE)
    rid <- paste0(id, "_relief")
    layers[[2]] <- .og_fold(og_layer(
      rid, "dem", label = "Relief", visible = visible, tiles = tiles,
      style = list(list(id = paste0(rid, "-shade"), type = "hillshade")), shade = sh
    ), open)
  }
  og_add_layer(s$map, layers, section = section)
}

#' @rdname og_relief
#' @export
og_contour <- function(
  map = NULL, tiles = NULL,
  major = c(10, 25, 50, 100, 150, 200, 300, 400, 500, 1000, 1500, 2000, 2500, 3000, 4000, 5000),
  minor = TRUE, labels = TRUE, colour = "#1b2a3a",
  of = c("depth", "elevation"), open = FALSE,
  name = "Contours", id = "contours", info = NULL, section = "Sea floor", visible = TRUE
) {
  of <- match.arg(of)
  s <- .og_seafloor_start(map, tiles, "og_contour")
  tiles <- .og_depth_tiles(s$tiles, "og_contour")
  .og_seafloor_common(open, visible, "og_contour")
  if (!is.numeric(major) || !length(major) || anyNA(major) || any(major <= 0) || any(major != round(major))) {
    stop("og_contour(): `major` is the depths of the heavier lines, whole metres above 0.", call. = FALSE)
  }
  for (a in c("minor", "labels")) {
    if (!isTRUE(get(a)) && !isFALSE(get(a))) stop(sprintf("og_contour(): `%s` is TRUE or FALSE.", a), call. = FALSE)
  }
  if (!is.character(colour) || length(colour) != 1 || !grepl("^#[0-9A-Fa-f]{6}$", colour)) {
    stop("og_contour(): `colour` is a colour as \"#rrggbb\".", call. = FALSE)
  }
  major <- sort(unique(major))
  spec <- .og_contour_spec(major, minor, labels, colour, id)
  og_add_layer(s$map, .og_fold(og_layer(
    id, "contour", label = name, info = info, visible = visible, tiles = tiles,
    contours = list(multiplier = if (of == "depth") -1 else 1, thresholds = spec$thresholds, auto = FALSE),
    style = spec$style
  ), open), section = section)
}

# The thinner lines' spacing, by the zoom they start at, in each band of depth (from 0, 50, 200 and 1,000 m): as the
# names map of Icelandic waters drew them (fishydata's named-features study, 2026-11-17), from zoom 3, where only the
# deep isobaths show
.og_contour_bands <- c(0, 50, 200, 1000)
.og_contour_spacing <- list(
  "3" = c(500, 500, 500, 500), "5" = c(25, 50, 100, 500), "7" = c(10, 50, 100, 500), "8" = c(10, 20, 100, 200),
  "9" = c(10, 20, 50, 200), "10" = c(5, 10, 50, 100), "11" = c(5, 10, 20, 100)
)

# A contour layer's thresholds and styles: at each zoom the lines are made at the greatest common divisor of the
# spacings and the major depths shown there (maplibre-contour makes lines at multiples of one interval), and a filter
# keeps those on a band's spacing and the major ones; a major depth shows from the zoom whose shallowest spacing it is
# at least. The major lines heavier, and labelled along the line in metres; a label may bend as sharply as the line,
# as a grid's contours step at its cells (at 30 or 90 degrees none was placed on the Olex grid's at zoom 10)
.og_contour_spec <- function(major, minor, labels, colour, id) {
  gcd <- function(a, b) if (b == 0) a else gcd(b, a %% b)
  ele <- list("get", "ele")
  is_major <- list("in", ele, list("literal", as.list(major)))
  zooms <- as.numeric(names(.og_contour_spacing))
  thresholds <- list()
  style <- list()
  for (k in seq_along(zooms)) {
    sp <- .og_contour_spacing[[k]]
    shown <- major[major >= sp[1]]
    every <- Reduce(gcd, c(if (minor) sp, if (length(shown)) shown else sp[1]))
    thresholds[[names(.og_contour_spacing)[k]]] <- every
    b <- .og_contour_bands
    on_band <- lapply(seq_along(b), function(i) {
      c(list("all", list(if (i == 1) ">" else ">=", ele, b[i])), if (i < length(b)) list(list("<", ele, b[i + 1])),
        list(list("==", list("%", ele, sp[i]), 0)))
    })
    keep_major <- list("all", is_major, list(">=", ele, sp[1]))
    kept <- if (minor) c(list("any"), on_band, list(keep_major)) else keep_major
    mz <- if (k < length(zooms)) zooms[k + 1] else 24
    style[[length(style) + 1]] <- list(
      id = sprintf("%s-line-%d", id, zooms[k]), type = "line", "source-layer" = "contours",
      minzoom = zooms[k], maxzoom = mz, filter = kept,
      layout = list("line-join" = "round"),
      paint = list("line-color" = colour, "line-opacity" = 0.6, "line-width" = list("case", is_major, 1.2, 0.5))
    )
    if (labels) {
      style[[length(style) + 1]] <- list(
        id = sprintf("%s-label-%d", id, zooms[k]), type = "symbol", "source-layer" = "contours",
        minzoom = zooms[k], maxzoom = mz, filter = list("all", kept, is_major),
        layout = list("symbol-placement" = "line", "text-size" = 11, "text-max-angle" = 180, "symbol-spacing" = 200,
                      "text-field" = list("concat", list("number-format", ele, structure(list(), names = character())), " m")),
        paint = list("text-color" = colour, "text-halo-color" = "#ffffff", "text-halo-width" = 1.5)
      )
    }
  }
  list(thresholds = thresholds, style = style)
}

# The map a sea-floor function adds to, and its depth model: a map given, or one started for a model given first
.og_seafloor_start <- function(map, tiles, fn) {
  if (inherits(map, "og_map")) {
    return(list(map = map, tiles = tiles))
  }
  if (!is.null(map) && !is.null(tiles)) {
    stop(sprintf("%s(): `map` is an og_map(); the depth model goes to `tiles`.", fn), call. = FALSE)
  }
  list(map = og_map(), tiles = if (is.null(map)) tiles else map)
}

.og_seafloor_common <- function(open, visible, fn) {
  for (a in list(list("open", open), list("visible", visible))) {
    if (!isTRUE(a[[2]]) && !isFALSE(a[[2]])) stop(sprintf("%s(): `%s` is TRUE or FALSE.", fn, a[[1]]), call. = FALSE)
  }
}

# A layer whose controls open folded under its name in the page
.og_fold <- function(layer, open) {
  if (!open) {
    layer$config$fold <- TRUE
  }
  layer
}

# A depth model as a tile function: one given; else the file or grid given, or named by OGIS_DEPTH: an MBTiles file
# (SQLite) read by og_tiles_mbtiles(), any other grid made into tiles by og_tiles_dem()
.og_depth_tiles <- function(x, fn) {
  if (is.function(x)) {
    return(x)
  }
  from_env <- is.null(x)
  if (from_env) {
    x <- Sys.getenv("OGIS_DEPTH")
    if (!nzchar(x)) {
      stop(paste0(
        fn, "() needs the depth model, `tiles`: an MBTiles file, a grid (a GeoTIFF, a terra raster, a data frame of ",
        "cells), or a path named by the environment variable OGIS_DEPTH: a line `OGIS_DEPTH=<path>` in your .Renviron ",
        "(usethis::edit_r_environ()), then restart R."
      ), call. = FALSE)
    }
  }
  if (!(is.character(x) && length(x) == 1 && !is.na(x))) {
    return(og_tiles_dem(x))
  }
  f <- path.expand(x)
  sqlite <- file.exists(f) && !dir.exists(f) &&
    identical(readBin(f, "raw", 16), c(charToRaw("SQLite format 3"), as.raw(0)))
  if (sqlite || (from_env && !file.exists(f))) {
    # og_tiles_mbtiles() says where a model named by OGIS_DEPTH came from, and that one named there is missing
    return(if (from_env) og_tiles_mbtiles() else og_tiles_mbtiles(f))
  }
  if (!file.exists(f) && !startsWith(f, "/vsi")) {
    stop(sprintf("%s(): `tiles` (%s): no such file.", fn, f), call. = FALSE)
  }
  if (from_env) {
    rlang::inform(sprintf("Depth from %s (OGIS_DEPTH).", normalizePath(f)), .frequency = "once",
                  .frequency_id = paste0("ogis_depth:", normalizePath(f)))
  }
  og_tiles_dem(f)
}
