# cells.R — values summed by cell as one layer function: og_cells() colours a table of cells (each row a cell's corner,
# the values of the columns a reader chooses by, and the values summed) by a value per square kilometre. DuckDB sums
# the cells to about a screen pixel at each zoom as the page asks for a tile, the reader's choices applied; the
# colours, the histogram and the fit are the grid layer's. Given once, or named once on each computer by OGIS_CELLS.
# fishycode's effort map (decision 220) on ogis's grid layer.

#' Values by cell: fishing effort and the like, chosen by gear, year or any column
#'
#' `og_cells()` colours a table of cells by a value per square kilometre, such as hours of fishing, summed by cell, gear
#' and year. The page has a control for each column the cells are chosen by (all of a gear, one, or several from the
#' address; a span of years), and the colours' own: the palette, the stretch, the floor and the cap on a histogram of
#' the cells in view, fitted to the view. As the page asks for a tile, DuckDB sums the cells under it to about a screen
#' pixel at that zoom (finer or coarser by the page's *Cells*), the reader's choices applied; a cell's value is its sum
#' over its area, so a colour holds across zooms. A click on a cell shows its values.
#'
#' The arguments are the starting look and choices; the page's controls change them, and a value in the page's address
#' wins over both.
#'
#' @section The cells: `cells` is a table with a row for each cell and combination of the columns chosen by, one of:
#'   * nothing (`NULL`): the file named by the environment variable `OGIS_CELLS`, a line in `.Renviron`
#'     (`OGIS_CELLS=D:/data/effort.parquet`), so a script shared between colleagues carries no path;
#'   * the path of a Parquet file (or several, a glob), read where it is: a file sorted by the cell's corner reads
#'     fastest;
#'   * a data frame, or a lazy table on DuckDB.
#'
#'   Its columns:
#'   * `ix` and `iy` (or `x` and `y`): the cell's south-west corner, in whole steps of `unit` degrees of longitude and
#'     latitude (thousandths of a degree by default). The cells' own size is read from the corners: a table of
#'     0.005-degree cells is drawn no finer than that;
#'   * `values`: the columns summed, each coloured per square kilometre; by default every column of fractions;
#'   * `count`: a column of whole numbers summed and shown on a click, not coloured (`n`, the records, by default);
#'   * `by`: the columns the reader chooses by, the others by default: each a list of its values ("all" first, then
#'     the values by their share of the first value, the largest first), or for a column of years (`range`) a span of
#'     two.
#'
#'   Labels come from the file's data dictionary (data-dict.tidyverse.org's, in the Parquet file's metadata) where it
#'   has one: a column's `label` names its control or its value, and its `values` name a code (a gear's id as its
#'   name); else from `codes`, else the column's own name.
#'
#' @param map A map the pipe makes ([og_map()], with data or none, and any layer functions). Given the cells instead
#'   (or nothing), a map is started for them.
#' @param cells The cells (see *The cells*).
#' @param values,count,by The columns summed and coloured, the count summed, and those chosen by (see *The cells*).
#' @param one_of Columns of `by` whose values are ways of counting the same thing, not parts of it (two definitions of
#'   fishing, say): one value shown at a time, the first by default, with no "all".
#' @param range Columns of `by` chosen as a span of two values, from and to: `"year"` by default, where there is one.
#' @param unit The degrees of one step of `ix` and `iy`.
#' @param filter The choices when the page opens, by column: `list(gid = 6, year = c(2015, 2020))`, a value or several
#'   of a list (several, comma-separated in the address), the first and last of a span. Those not given: all, the
#'   whole span, or the first of `one_of`.
#' @param metric The value coloured when the page opens, one of `values`.
#' @param palette The colours, one of the map's palettes for a grid ([og_palettes()]): `"magma"` by default.
#' @param opacity The cells' opacity, 0-100.
#' @param limits The values per square kilometre the palette's ends stand at, `c(floor, cap)`; by default fitted to the
#'   view (the 2nd and 98th percentiles of the cells in view), until the reader sets them.
#' @param stretch How the values are spread over the palette: `"even"` on a log scale, or `"equal"`, each colour an
#'   equal share of the cells in view.
#' @param labels The columns' names as the page shows them, where the file's dictionary has none: a named character
#'   vector, column to label (`c(gid = "Gear", h = "Hours")`); a value's is followed by "per km²".
#' @param codes The names of codes in the columns chosen by, where the file's dictionary has none: a named list by
#'   column, each a named vector, code to name (`list(gid = c("6" = "Bottom trawl (OTB)"))`).
#' @param name,info The layer's name in the sidebar and the text behind its ⓘ.
#' @param id The layer's id, its key in the page's address, and the start of its controls' keys (`<id>_<column>`).
#' @param section The sidebar's box the layer sits in, by its title.
#' @param visible Whether the cells are on when the page opens.
#' @return The map, with the layer. A map has one such layer at most. [og_bundle()] carries it with no further word,
#'   summed by the browser from the cells at sizes from 0.01 degrees up.
#' @seealso [og_layer()]'s `"grid"`, which it makes; [og_relief()] and [og_names()], for a sea floor and its names
#'   under it.
#' @export
#' @examples
#' # hours by 0.01-degree cell, gear and year
#' set.seed(1)
#' cells <- expand.grid(ix = seq(-24000, -22000, by = 10), iy = seq(65000, 66000, by = 10),
#'                      gear = c("trawl", "longline"), year = 2020:2022)
#' cells$hours <- rexp(nrow(cells)) * ifelse(cells$gear == "trawl", 3, 1)
#' og_cells(cells, labels = c(gear = "Gear", year = "Years", hours = "Hours"), name = "Fishing effort")
#'
#' # trawls in 2021 alone, coloured from 0.5 to 50 hours a km², in blues
#' og_cells(cells, filter = list(gear = "trawl", year = c(2021, 2021)), limits = c(0.5, 50),
#'          palette = "blues")
#'
#' # cells named once, by OGIS_CELLS in .Renviron, over the sea floor:
#' # og_map() |> og_relief() |> og_cells(name = "Fishing effort", one_of = "preset")
og_cells <- function(
  map = NULL, cells = NULL,
  values = NULL, count = "n", by = NULL, one_of = NULL, range = "year", unit = 0.001,
  filter = list(), metric = NULL, palette = "magma", opacity = 85, limits = NULL, stretch = c("even", "equal"),
  labels = NULL, codes = NULL, name = "Cells", id = "cells", info = NULL, section = name, visible = TRUE
) {
  stretch <- match.arg(stretch)
  s <- .og_cells_start(map, cells)
  map <- s$map
  .og_seafloor_common(TRUE, visible, "og_cells")
  if (!is.numeric(unit) || length(unit) != 1 || is.na(unit) || unit <= 0) {
    stop("og_cells(): `unit` is the degrees of one step of the cells' corners, above 0.", call. = FALSE)
  }
  if (!is.numeric(opacity) || length(opacity) != 1 || is.na(opacity) || opacity < 0 || opacity > 100) {
    stop("og_cells(): `opacity` is a percentage, 0 to 100.", call. = FALSE)
  }
  if (!is.null(limits) && (!is.numeric(limits) || length(limits) != 2 || anyNA(limits) || limits[1] <= 0 ||
                           limits[1] >= limits[2])) {
    stop("og_cells(): `limits` is c(floor, cap), above 0, the floor below the cap.", call. = FALSE)
  }
  pals <- Filter(function(p) is.null(p$use) || "grid" %in% p$use, .og_or(map$config$palettes, og_palettes()))
  if (!is.character(palette) || length(palette) != 1 || !palette %in% vapply(pals, `[[`, "", "id")) {
    stop(sprintf("og_cells(): `palette` is one of the map's palettes for a grid: %s.",
                 paste(vapply(pals, `[[`, "", "id"), collapse = ", ")), call. = FALSE)
  }

  d <- .og_cells_data(s$cells)
  con <- d$con
  src <- d$src
  ty <- DBI::dbGetQuery(con, sprintf("DESCRIBE SELECT * FROM %s s", src))
  types <- stats::setNames(toupper(ty$column_type), ty$column_name)
  cols <- names(types)
  whole <- grepl("^(TINYINT|SMALLINT|INTEGER|BIGINT|HUGEINT|UTINYINT|USMALLINT|UINTEGER|UBIGINT)$", types)
  fraction <- grepl("^(FLOAT|DOUBLE|REAL|DECIMAL)", types)
  names(whole) <- names(fraction) <- cols
  xy <- if (all(c("ix", "iy") %in% cols)) c("ix", "iy") else if (all(c("x", "y") %in% cols)) c("x", "y")
  if (is.null(xy) || !all(whole[xy] | fraction[xy])) {
    stop("og_cells(): the cells need their corners as numbers of steps, `ix` and `iy` (or `x` and `y`).", call. = FALSE)
  }
  need <- function(v, what) {
    if (!is.null(v) && (!is.character(v) || !all(v %in% cols))) {
      stop(sprintf("og_cells(): `%s` names columns of the cells: %s.", what,
                   paste(setdiff(v, cols), collapse = ", ")), call. = FALSE)
    }
  }
  need(values, "values")
  need(by, "by")
  need(one_of, "one_of")
  count <- if (!is.null(count) && count %in% cols && whole[[count]]) count
  if (is.null(values)) {
    values <- setdiff(cols[fraction], c(xy, count, by))
  }
  if (!length(values) || !all(fraction[values] | whole[values])) {
    stop("og_cells(): the cells have no `values` to sum: columns of numbers.", call. = FALSE)
  }
  if (is.null(by)) {
    by <- setdiff(cols, c(xy, values, count))
  }
  by <- union(by, one_of)
  range <- intersect(intersect(range, by), cols[whole])
  named <- c(by, values, count)
  if (length(bad <- named[!grepl("^[A-Za-z][A-Za-z0-9_]*$", named) | named == "px"])) {
    stop(sprintf("og_cells(): a column of the cells' is named with letters, digits and _, and not px (their size): rename %s.",
                 paste(bad, collapse = ", ")), call. = FALSE)
  }
  if (!is.null(metric) && !(is.character(metric) && length(metric) == 1 && metric %in% values)) {
    stop("og_cells(): `metric` is one of `values`.", call. = FALSE)
  }
  if (!is.list(filter) || (length(filter) && (is.null(names(filter)) || !all(names(filter) %in% by)))) {
    stop(sprintf("og_cells(): `filter` is a list of choices by the columns chosen by: %s.",
                 paste(by, collapse = ", ")), call. = FALSE)
  }

  if (!is.null(labels) && (!is.character(labels) || is.null(names(labels)))) {
    stop("og_cells(): `labels` is a named character vector, a column's name to its label: c(gid = \"Gear\").",
         call. = FALSE)
  }
  dict <- .og_dict_parquet(con, src)
  label <- function(cn) if (cn %in% names(labels)) labels[[cn]] else .og_or(dict[[cn]]$label, cn)
  code_names <- function(cn) {
    cd <- .og_or(codes[[cn]], dict[[cn]]$codes)
    if (!is.null(cd)) stats::setNames(as.character(cd), names(cd))
  }
  fid <- function(cn) paste0(id, "_", cn)
  q <- function(v) as.character(DBI::dbQuoteIdentifier(con, v))

  # the cells' own size, read from a sample of their corners, and their extent (all but the farthest few)
  smp <- DBI::dbGetQuery(con, sprintf("SELECT %s AS x, %s AS y FROM %s s USING SAMPLE 20000 ROWS",
                                      q(xy[1]), q(xy[2]), src))
  if (!nrow(smp)) stop("og_cells(): the cells are none.", call. = FALSE)
  steps <- Filter(function(k) all(smp$x %% k == 0 & smp$y %% k == 0), .og_cell_k)
  if (!length(steps)) {
    stop(sprintf("og_cells(): the cells' corners are whole steps of `unit` (%s degrees): %s and %s.", format(unit),
                 xy[1], xy[2]), call. = FALSE)
  }
  finest <- max(steps)
  ext <- c(stats::quantile(smp$x, 0.005), stats::quantile(smp$y, 0.005),
           stats::quantile(smp$x, 0.995) + finest, stats::quantile(smp$y, 0.995) + finest) * unit
  ext <- pmin(pmax(unname(ext), c(-180, -85, -180, -85)), c(180, 85, 180, 85))

  # the controls: a list of each column's values (all first, but for one_of), a span for a range, the value coloured,
  # and the cells' size
  filters <- lapply(by, function(cn) {
    if (cn %in% range) {
      return(list(id = fid(cn), type = "range", label = label(cn), params = paste0(fid(cn), c("_from", "_to"))))
    }
    list(id = fid(cn), label = label(cn), meta = TRUE,
         options = if (cn %in% one_of) list() else list(list(value = "", label = "all")))
  })
  if (length(values) > 1) {
    filters <- c(filters, list(list(id = "metric", type = "metric", label = "Value")))
  }
  px_id <- fid("px")
  filters <- c(filters, list(list(
    id = px_id, label = "Cells", default = "1",
    options = list(list(value = "0.5", label = "finer (heavy)", tip = "Each cell about half a screen pixel"),
                   list(value = "1", label = "fine"), list(value = "2", label = "coarser"))
  )))
  metrics <- lapply(values, function(v) list(field = paste0(v, "_km2"), label = paste(label(v), "per km\u00b2")))
  popup <- list(fields = c(
    lapply(metrics, function(m) list(field = m$field, label = m$label, format = "value")),
    if (!is.null(count)) list(list(field = count, label = label(count), format = "count"))
  ))

  # the first of each one_of, a tile's choice where none is given; the lists' values, by their share of the first
  # value (a one_of's in their own order, the first its default); the ranges' ends
  first <- new.env(parent = emptyenv())
  meta <- function() {
    options <- list()
    for (cn in setdiff(by, range)) {
      o <- DBI::dbGetQuery(con, sprintf(
        "SELECT CAST(%1$s AS VARCHAR) AS value FROM %2$s s WHERE %1$s IS NOT NULL GROUP BY %1$s ORDER BY %3$s",
        q(cn), src, if (cn %in% one_of) sprintf("min(%s)", q(cn)) else sprintf("sum(%s) DESC NULLS LAST", q(values[1]))
      ))
      nm <- code_names(cn)
      if (!is.null(nm)) o$name <- unname(nm[o$value])
      options[[fid(cn)]] <- o
      if (cn %in% one_of) assign(cn, o$value[1], envir = first)
    }
    ranges <- list()
    for (cn in range) {
      r <- DBI::dbGetQuery(con, sprintf("SELECT min(%1$s) AS a, max(%1$s) AS b FROM %2$s s", q(cn), src))
      ranges[[fid(cn)]] <- c(r$a, r$b)
    }
    list(options = options, ranges = ranges, v = d$v())
  }

  sizes <- .og_cell_k[.og_cell_k %% finest == 0]
  lit <- function(cn, v) {
    if (whole[[cn]] || fraction[[cn]]) {
      n <- suppressWarnings(as.numeric(v))
      if (anyNA(n)) stop("not a number", call. = FALSE)
      format(n, scientific = FALSE, trim = TRUE)
    } else {
      as.character(DBI::dbQuoteString(con, v))
    }
  }
  tiles <- function(z, x, y, params) {
    px <- suppressWarnings(as.numeric(.og_or(params[[px_id]], "1")))
    if (is.na(px) || px <= 0) px <- 1
    target <- 360 / 2^z / 512 * px / unit
    k <- max(sizes[sizes <= max(target, finest)])
    n2 <- 2^z
    lat <- function(t) atan(sinh(pi * (1 - 2 * t / n2))) * 180 / pi
    b <- c(x / n2 * 360 - 180, lat(y + 1), (x + 1) / n2 * 360 - 180, lat(y)) / unit
    where <- sprintf("%1$s >= %3$.0f AND %1$s < %4$.0f AND %2$s >= %5$.0f AND %2$s < %6$.0f", q(xy[1]), q(xy[2]),
                     floor(b[1] / k) * k - k, ceiling(b[3] / k) * k + k, floor(b[2] / k) * k - k, ceiling(b[4] / k) * k + k)
    for (cn in by) {
      if (cn %in% range) {
        a <- params[[paste0(fid(cn), "_from")]]
        e <- params[[paste0(fid(cn), "_to")]]
        if (!is.null(a) && !is.null(e)) {
          where <- c(where, sprintf("%s BETWEEN %s AND %s", q(cn), lit(cn, a), lit(cn, e)))
        }
        next
      }
      v <- params[[fid(cn)]]
      if ((is.null(v) || !nzchar(v)) && cn %in% one_of) {
        if (is.null(first[[cn]])) meta()
        v <- first[[cn]]
      }
      if (!is.null(v) && nzchar(v)) {
        vs <- strsplit(v, ",", fixed = TRUE)[[1]]
        where <- c(where, sprintf("CAST(%s AS VARCHAR) IN (%s)", q(cn), paste(DBI::dbQuoteString(con, vs), collapse = ", ")))
      }
    }
    sums <- paste(c(sprintf("sum(%1$s) AS %1$s", vapply(values, q, "")),
                    if (!is.null(count)) sprintf("CAST(sum(%1$s) AS BIGINT) AS %1$s", q(count))), collapse = ", ")
    fields <- paste(c(sprintf("'%s_km2': CAST(%s / km2 AS FLOAT)", values, vapply(values, q, "")),
                      if (!is.null(count)) sprintf("'%s': %s", count, q(count))), collapse = ", ")
    sql <- sprintf("
      WITH c AS (
        SELECT floor(%1$s / %3$d) AS cx, floor(%2$s / %3$d) AS cy, %4$s FROM %5$s s WHERE %6$s GROUP BY ALL),
      g AS (SELECT *, cx * %3$d * %7$.10g AS lon0, (cx + 1) * %3$d * %7$.10g AS lon1,
                      cy * %3$d * %7$.10g AS lat0, (cy + 1) * %3$d * %7$.10g AS lat1 FROM c),
      m AS (
        SELECT *, (%3$d * %7$.10g * 111.32 * cos(radians((lat0 + lat1) / 2))) * (%3$d * %7$.10g * 110.574) AS km2,
               ST_MakeEnvelope(radians(lon0) * 6378137, ln(tan(pi() / 4 + radians(lat0) / 2)) * 6378137,
                               radians(lon1) * 6378137, ln(tan(pi() / 4 + radians(lat1) / 2)) * 6378137) AS env
        FROM g)
      SELECT ST_AsMVT({'geometry': ST_AsMVTGeom(env, ST_Extent(ST_TileEnvelope(%8$d, %9$d, %10$d)), 4096, 64, true), %11$s},
                      'cells', 4096) AS tile
      FROM m", q(xy[1]), q(xy[2]), as.integer(k), sums, src, paste(where, collapse = " AND "), unit,
      as.integer(z), as.integer(x), as.integer(y), fields)
    r <- DBI::dbGetQuery(con, sql)$tile[[1]]
    if (is.null(r)) raw(0) else r
  }

  layer <- og_layer(
    id, "grid", label = name, info = info, visible = visible, tiles = tiles, meta = meta, filters = filters,
    metrics = metrics, popup = popup, source_layer = "cells", minzoom = 2, maxzoom = 12, opacity = opacity
  )
  # where the cells lie, for the map's first view
  layer$config$bounds <- as.list(ext)
  # the first view: the choices and the colours given, the page's address winning
  start <- list(palette = palette, stretch = stretch, opacity = opacity)
  if (!is.null(metric)) start$metric <- paste0(metric, "_km2")
  if (!is.null(limits)) start[c("floor", "cap")] <- as.list(limits)
  for (cn in names(filter)) {
    v <- filter[[cn]]
    if (cn %in% range) {
      if (!is.numeric(v) || !length(v) || anyNA(v)) {
        stop(sprintf("og_cells(): `filter$%s` is the first and last of a span: c(2015, 2020).", cn), call. = FALSE)
      }
      start[paste0(fid(cn), c("_from", "_to"))] <- as.list(as.character(range(v)))
    } else {
      if (!length(v) || anyNA(v)) stop(sprintf("og_cells(): `filter$%s` is a value or several.", cn), call. = FALSE)
      if (cn %in% one_of && length(v) > 1) {
        stop(sprintf("og_cells(): `filter$%s` is one value: its values are shown one at a time.", cn), call. = FALSE)
      }
      start[[fid(cn)]] <- paste(v, collapse = ",")
    }
  }
  layer$config$start <- start
  # a bundle's: the cells summed by the browser, at sizes from 0.01 degrees up
  base <- finest * max(1, ceiling(0.01 / unit / finest))
  layer$bundle_grid <- list(
    rows = d$tbl, unit = unit, levels = base * c(1, 2, 4, 10, 20, 50), x = xy[1], y = xy[2],
    columns = stats::setNames(by, vapply(by, fid, "")), sums = c(values, count),
    fields = c(stats::setNames(lapply(values, function(v) c(v, "km2")), paste0(values, "_km2")),
               if (!is.null(count)) stats::setNames(list(count), count)),
    px = px_id
  )
  og_add_layer(map, layer, section = section)
}

# A cell's side, in steps of the corners' unit: a few round sizes, from which a tile takes the one nearest a screen
# pixel at its zoom that is a whole number of the cells' own (fishycode's effort map's)
.og_cell_k <- c(1, 2, 3, 4, 5, 7, 10, 15, 20, 30, 40, 50, 70, 100, 150, 200, 300, 500, 1000)

# The map and the cells: a map given first, or the cells (or nothing), which start one
.og_cells_start <- function(map, cells) {
  if (inherits(map, "og_map")) {
    return(list(map = map, cells = cells))
  }
  if (!is.null(map) && !is.null(cells)) {
    stop("og_cells(): `map` is an og_map(); the cells go to `cells`.", call. = FALSE)
  }
  list(map = og_map(), cells = if (is.null(map)) cells else map)
}

# The cells as a query on ogis's DuckDB (`src`, a subquery in brackets), a lazy table of it (`tbl`, for a bundle), and
# their version (`v`, a file's time, else when they were read): one given, or the file given or named by OGIS_CELLS
.og_cells_data <- function(x) {
  con <- .og_connection()
  .og_extension(con, "spatial")
  started <- format(as.numeric(Sys.time()), digits = 15)
  if (inherits(x, "tbl_lazy")) {
    if (!identical(dbplyr::remote_con(x), con)) {
      stop("og_cells(): a lazy table of cells is on ogis's own DuckDB, or given as its file or a data frame.",
           call. = FALSE)
    }
    return(list(con = con, src = sprintf("(%s)", dbplyr::sql_render(x)), tbl = x, v = function() started))
  }
  if (is.data.frame(x)) {
    nm <- .og_name(con, "og_cells_")
    duckdb::duckdb_register(con, nm, as.data.frame(x))
    return(list(con = con, src = sprintf("(SELECT * FROM %s)", nm), tbl = dplyr::tbl(con, nm), v = function() started))
  }
  from_env <- is.null(x)
  if (from_env) {
    x <- Sys.getenv("OGIS_CELLS")
    if (!nzchar(x)) {
      stop(paste0(
        "og_cells() needs the cells, `cells`: a table, or the path of a Parquet file of them; or the file named once ",
        "on this computer by OGIS_CELLS: a line `OGIS_CELLS=<path>` in your .Renviron (usethis::edit_r_environ()), ",
        "then restart R."
      ), call. = FALSE)
    }
  }
  if (!is.character(x) || length(x) != 1 || is.na(x) || !nzchar(x)) {
    stop("og_cells(): `cells` is a table, or the path of a Parquet file of cells.", call. = FALSE)
  }
  x <- path.expand(x)
  whose <- if (from_env) sprintf("The environment variable OGIS_CELLS names %s", x) else sprintf("`cells` (%s)", x)
  glob <- grepl("[*?]", x)
  if (!glob && (!file.exists(x) || dir.exists(x))) {
    stop(sprintf("%s: no such file.", whose), call. = FALSE)
  }
  if (!grepl("[.]parquet$", x, ignore.case = TRUE)) {
    stop(sprintf("%s: not a Parquet file.", whose), call. = FALSE)
  }
  if (!glob) x <- normalizePath(x, winslash = "/")
  if (from_env) {
    rlang::inform(sprintf("Cells from %s (OGIS_CELLS).", x), .frequency = "once", .frequency_id = paste0("ogis_cells:", x))
  }
  read <- sprintf("SELECT * FROM read_parquet(%s)", DBI::dbQuoteString(con, x))
  list(con = con, src = sprintf("(%s)", read), tbl = dplyr::tbl(con, dplyr::sql(read)),
       v = function() format(max(as.numeric(file.mtime(Sys.glob(x)))), digits = 15))
}
