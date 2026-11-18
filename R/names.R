# names.R — a list of place names as one layer function: og_names() writes each name where it belongs, from its own
# zoom, finds it in the page's Find box and shows what is known of it on a click; its area, where it has one, as a
# layer of its own. Given once, or named once on each computer by OGIS_NAMES. Built on og_text() and og_polygon(),
# with the page's controls (colour, the zoom the names appear at) as the labels' state.

#' Place names: labels, their areas, the Find box and what is known of each
#'
#' `og_names()` writes a list of place names on the map, each from its own zoom, the larger names first where they
#' meet; the page's *Find* box looks through them (accents aside), and a click on a name, or a name found, shows its
#' row. Where the names have areas, these are a layer of their own, off when the page opens, a click inside one
#' showing the same.
#'
#' The arguments are the starting look; the page's controls, folded under ▸ beside the layer's name, change the
#' names' colour and the zoom they appear at.
#'
#' @section The list of names: `names` is a table with a row for each name (a name of several places, a row for
#'   each), one of:
#'   * nothing (`NULL`): the file named by the environment variable `OGIS_NAMES`, a line in `.Renviron`
#'     (`OGIS_NAMES=D:/data/ornefni.parquet`), so a script shared between colleagues carries no path;
#'   * the path of a (Geo)Parquet file; or of a GeoPackage, GeoJSON or any file sf reads;
#'   * a data frame, an sf object, or a lazy table on DuckDB.
#'
#'   Its columns, all but `name` optional:
#'   * `name`: the name, as written on the map and found;
#'   * `label_lon`, `label_lat` (or `lon`, `lat`): where the name is written; else on its area;
#'   * a geometry column (`geometry`, `geom`): the name's area, a line or a point, drawn as the layer `<id>_areas`;
#'   * `min_zoom`: the zoom the name shows from (every zoom where it is missing);
#'   * `level`: its rank, 1 to 4, 1 the largest: the text's size, and the order names are placed in where they meet;
#'   * `n`: within a rank, the larger placed first (how often a name is used, say);
#'   * the others: what a click shows, labelled by the file's data dictionary (data-dict.tidyverse.org's, in the
#'     Parquet file's metadata), else by their names.
#'
#' @param map A map the pipe makes ([og_map()], with data or none, and any layer functions). Given the names instead
#'   (or nothing), a map is started for them.
#' @param names The place names (see *The list of names*).
#' @param colour The names' colour when the page opens, `"#rrggbb"`; the page offers dark blue (the default), black,
#'   white, red and yellow.
#' @param early How many zooms before its own each name appears when the page opens: -1 (a zoom later), 0, 1 or 2;
#'   the page has the same choice.
#' @param areas Whether the names' areas show when the page opens.
#' @param popup The columns a click shows, by name; by default every column but the name's place, zoom, rank, `n`
#'   and area.
#' @param open Whether the layer's controls show when the page opens; folded by default.
#' @param name,info The layer's name in the sidebar (the areas' is "Areas of the names") and the text behind its ⓘ.
#' @param id The layer's id, its key in the page's address; the areas' is `<id>_areas`.
#' @param section The sidebar's box the layers sit in, by its title.
#' @param visible Whether the names are on when the page opens.
#' @return The map, with the layers.
#' @seealso [og_text()] and [og_polygon()], which draw them, for labels and areas of your own.
#' @export
#' @examples
#' # four names, each from its own zoom
#' places <- data.frame(
#'   name = c("Skagen", "Hirtshals", "Frederikshavn", "Læsø"),
#'   lon = c(10.59, 9.96, 10.54, 11.0), lat = c(57.72, 57.59, 57.44, 57.27),
#'   min_zoom = c(5, 6, 6, 5), level = c(1, 2, 2, 1),
#'   kind = c("town", "harbour", "harbour", "island")
#' )
#' og_names(places)
#'
#' # a list of names named once, by OGIS_NAMES in .Renviron:
#' # og_map() |> og_relief() |> og_names()
og_names <- function(
  map = NULL, names = NULL,
  colour = "#0b3954", early = 0, areas = FALSE, popup = NULL, open = FALSE,
  name = "Place names", id = "names", info = NULL, section = "Reference", visible = TRUE
) {
  s <- .og_names_start(map, names)
  map <- s$map
  .og_seafloor_common(open, visible, "og_names")
  if (!isTRUE(areas) && !isFALSE(areas)) stop("og_names(): `areas` is TRUE or FALSE.", call. = FALSE)
  if (!is.character(colour) || length(colour) != 1 || !grepl("^#[0-9A-Fa-f]{6}$", colour)) {
    stop("og_names(): `colour` is a colour as \"#rrggbb\".", call. = FALSE)
  }
  if (!is.numeric(early) || length(early) != 1 || !early %in% -1:2) {
    stop("og_names(): `early` is -1, 0, 1 or 2 zooms.", call. = FALSE)
  }
  x <- .og_names_data(s$names)
  cols <- colnames(x)
  if (!"name" %in% cols) {
    stop("og_names(): the names have no column `name`.", call. = FALSE)
  }
  geom <- intersect(c("geometry", "geom", "wkb_geometry", "the_geom"), cols)[1]
  at <- if (all(c("label_lon", "label_lat") %in% cols)) c("label_lon", "label_lat") else
    if (all(c("lon", "lat") %in% cols)) c("lon", "lat")
  if (is.null(at) && is.na(geom)) {
    stop("og_names(): the names have no place: columns `label_lon` and `label_lat` (or `lon` and `lat`), or a geometry.",
         call. = FALSE)
  }
  zoomed <- "min_zoom" %in% cols
  inner <- c("label_lon", "label_lat", "lon", "lat", "min_zoom", "level", "n", if (!is.na(geom)) geom)
  if (is.null(popup)) {
    popup <- setdiff(cols, inner)
  } else if (!is.character(popup) || !all(popup %in% cols)) {
    stop(sprintf("og_names(): `popup` names columns of the names: %s.", paste(setdiff(popup, cols), collapse = ", ")),
         call. = FALSE)
  }
  areas_id <- paste0(id, "_areas")

  # the areas, under the names: those that have one, drawn by their shape (lon and lat, a point's, left out); sent
  # whole, one file the page reads once, for a few large areas (a sea's) cover so many tiles that a bundle of them as
  # tiles took minutes (fishycode's 1,575 areas: 13,330 tiles to zoom 8 in 4.4 minutes, against one 7.7 MB file)
  if (!is.na(geom)) {
    a <- if (inherits(x, "sf")) x[!sf::st_is_empty(x), ] else dplyr::filter(x, !is.na(!!rlang::sym(geom)))
    a <- dplyr::select(a, -dplyr::any_of(c("lon", "lat")))
    map <- og_polygon(map, a, colour = "#1f5f8b", fill = "#1f5f8b", opacity = 0.08, linewidth = 0.8, legend = FALSE,
                      whole = TRUE,
                      popup = !!popup, name = "Areas of the names", id = areas_id, section = section, visible = areas)
  }

  # the names: their size and order by rank, then by n
  lv <- if ("level" %in% cols) {
    dplyr::mutate(x, og_size = dplyr::case_when(level == 1 ~ 19, level == 2 ~ 17, level == 3 ~ 15.5, .default = 14))
  } else {
    dplyr::mutate(x, og_size = 14)
  }
  lv <- dplyr::mutate(lv, og_priority = !!(if ("n" %in% cols) quote(dplyr::coalesce(as.numeric(n), 0)) else 0) -
                        100000 * !!(if ("level" %in% cols) quote(dplyr::coalesce(as.numeric(level), 4)) else 4))
  if (!is.null(at)) {
    if (inherits(lv, "sf")) {
      lv <- sf::st_drop_geometry(lv)
    } else if (!is.na(geom)) {
      lv <- dplyr::select(lv, -dplyr::all_of(geom))
    }
    lv <- dplyr::filter(lv, !is.na(!!rlang::sym(at[1])), !is.na(!!rlang::sym(at[2])))
  }
  map <- og_text(
    map, lv, lon = at[1], lat = at[2], label = !!rlang::sym("name"), size = !!rlang::sym("og_size"),
    priority = !!rlang::sym("og_priority"), minzoom = !!(if (zoomed) rlang::sym("min_zoom")),
    colour = !!colour, search = !!rlang::sym("name"), popup = !!popup,
    name = name, id = id, info = info, section = section, visible = visible,
    # a name crowded at its point is written beside it
    "text-variable-anchor" = list("center", "top", "bottom", "left", "right", "top-left", "top-right", "bottom-left",
                                  "bottom-right"),
    "text-radial-offset" = 0.4, "text-justify" = "auto"
  )
  .og_quick_edit(map, id, function(l) .og_fold(.og_names_state(l, colour, early, zoomed), open))
}

# The names' controls as the labels' state: their colour, and with a zoom of their own, the zoom they appear at
.og_names_state <- function(l, colour, early, zoomed) {
  id <- l$config$id
  key <- function(k) list("global-state", paste0(id, "_", k))
  st <- l$config$style[[1]]
  st$paint[["text-color"]] <- key("colour")
  if (zoomed) {
    # from the first whole zoom at or above its own, less the zooms early
    st$filter <- list(">=", list("zoom"), list("-", list("to-number", list("get", "min_zoom")), key("early")))
  }
  l$config$style[[1]] <- st
  colours <- c("#0b3954" = "dark blue", "#000000" = "black", "#ffffff" = "white", "#b2182b" = "red",
               "#ffd92f" = "yellow")
  colour <- tolower(colour)
  if (!colour %in% names(colours)) colours <- c(stats::setNames(colour, colour), colours)
  state <- list(list(
    id = "colour", label = "Colour", default = colour,
    options = unname(Map(function(v, t) list(value = v, label = t), names(colours), colours))
  ))
  if (zoomed) {
    state[[2]] <- list(
      id = "early", label = "Names appear", default = early,
      options = list(list(value = -1, label = "a zoom later"), list(value = 0, label = "at their own zoom"),
                     list(value = 1, label = "a zoom earlier"), list(value = 2, label = "two zooms earlier"))
    )
  }
  l$config$state <- .og_map_state(state, id, l$config$kind, l$config$style)
  l
}

# A layer of a map the pipe makes, changed in place: the map made again from its layers
.og_quick_edit <- function(map, id, fn) {
  q <- attr(map, "quick")
  i <- which(vapply(q$layers, function(l) l$config$id, "") == id)
  q$layers[[i]] <- fn(q$layers[[i]])
  .og_quick_map(list(state = q))
}

# The map and the names: a map given first, or the names (or nothing), which start one
.og_names_start <- function(map, names) {
  if (inherits(map, "og_map")) {
    return(list(map = map, names = names))
  }
  if (!is.null(map) && !is.null(names)) {
    stop("og_names(): `map` is an og_map(); the place names go to `names`.", call. = FALSE)
  }
  list(map = og_map(), names = if (is.null(map)) names else map)
}

# The names as a table the layer functions read: one given; else the file given, or named by OGIS_NAMES, a Parquet
# file as a lazy table on ogis's DuckDB, any other read by sf
.og_names_data <- function(x) {
  if (is.data.frame(x) || inherits(x, "tbl_lazy")) {
    return(x)
  }
  from_env <- is.null(x)
  if (from_env) {
    x <- Sys.getenv("OGIS_NAMES")
    if (!nzchar(x)) {
      stop(paste0(
        "og_names() needs the place names, `names`: a table, or the path of a file of them; or the file named once ",
        "on this computer by OGIS_NAMES: a line `OGIS_NAMES=<path>` in your .Renviron (usethis::edit_r_environ()), ",
        "then restart R."
      ), call. = FALSE)
    }
  }
  if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
    stop("og_names(): `names` is a table, or the path of a file of place names.", call. = FALSE)
  }
  x <- path.expand(x)
  whose <- if (from_env) sprintf("The environment variable OGIS_NAMES names %s", x) else sprintf("`names` (%s)", x)
  if (!file.exists(x) || dir.exists(x)) {
    stop(sprintf("%s: no such file.", whose), call. = FALSE)
  }
  x <- normalizePath(x, winslash = "/")
  if (from_env) {
    rlang::inform(sprintf("Place names from %s (OGIS_NAMES).", x), .frequency = "once",
                  .frequency_id = paste0("ogis_names:", x))
  }
  if (grepl("[.]parquet$", x, ignore.case = TRUE)) {
    con <- .og_connection()
    .og_extension(con, "spatial")
    return(dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM read_parquet(%s)", DBI::dbQuoteString(con, x)))))
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop(sprintf("%s: a file other than Parquet is read by sf, which is not installed.", whose), call. = FALSE)
  }
  sf::st_read(x, quiet = TRUE)
}
