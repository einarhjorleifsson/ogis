# layers.R — the layer functions: a mark each, its data a parquet file, a lazy DuckDB
# table, a data frame or sf, piped onto a map. Their arguments come in one order (§3.4): the map and the data; where
# (lon, lat and the mark's own); how it looks (colour, fill, size, linewidth, opacity, label); its colours (palette,
# limits, stretch, legend); what the reader can do (popup, hover, choose); the sidebar (name, info, section, visible);
# its zooms (minzoom, maxzoom). A bare name is a column; a string is a value.

# A short id from a name: lower-case letters, digits and _
.og_slug <- function(x) {
  s <- gsub("_+", "_", gsub("[^a-z0-9]+", "_", tolower(iconv(x, to = "ASCII//TRANSLIT", sub = ""))))
  s <- gsub("^_|_$", "", s)
  if (!nzchar(s) || grepl("^[0-9]", s)) paste0("l_", s) else s
}

# A parquet file, folder or glob as a lazy DuckDB table; anything else as given
.og_data <- function(x) {
  if (is.character(x) && length(x) == 1 && !grepl("\n", x)) {
    path <- if (dir.exists(x)) file.path(x, "**", "*.parquet") else x
    if (!grepl("\\.parquet$", path) && !grepl("[*?]", path)) {
      stop(sprintf("\"%s\" is not a parquet file, folder or glob.", x), call. = FALSE)
    }
    con <- .og_connection()
    return(dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM read_parquet(%s)", DBI::dbQuoteString(con, path)))))
  }
  x
}

# What an aesthetic was given: NULL, a value (a string or a number), or columns (bare names, one or c() of them).
# A string that names a column and is not a colour stops: columns are written bare.
.og_aes <- function(q, cols, what, colour = FALSE) {
  if (is.null(q) || rlang::quo_is_null(q) || rlang::quo_is_missing(q)) {
    return(NULL)
  }
  e <- rlang::quo_get_expr(q)
  # numbers in c(), such as a size's bounds, are values, not columns by position
  if (rlang::is_call(e, "c") && length(rlang::call_args(e)) && all(vapply(rlang::call_args(e), is.numeric, logical(1)))) {
    e <- rlang::eval_tidy(q)
  }
  if (is.character(e) || is.numeric(e) || is.logical(e)) {
    if (is.character(e) && length(e) == 1 && e %in% cols && !.og_is_colour(e)) {
      stop(sprintf("`%1$s = \"%2$s\"` is a value; to use the column, write it bare: `%1$s = %2$s`.", what, e), call. = FALSE)
    }
    if (colour && !.og_is_colour(e)) {
      stop(sprintf("`%s = \"%s\"` is not a colour, nor a column of the data.", what, e), call. = FALSE)
    }
    return(list(value = e))
  }
  list(columns = .og_select(q, cols, what))
}

# Columns named bare, one or c() of them, or with tidyselect's helpers
.og_select <- function(q, cols, what) {
  if (is.null(q) || rlang::quo_is_null(q) || rlang::quo_is_missing(q)) {
    return(character())
  }
  e <- rlang::quo_get_expr(q)
  if (isTRUE(e)) {
    return(cols)
  }
  if (isFALSE(e)) {
    return(character())
  }
  # a variable holding the columns' names, no column itself: taken as all_of() it, as tidyselect asks (it warns of a
  # bare one)
  if (rlang::is_symbol(e) && !rlang::as_string(e) %in% cols) {
    v <- tryCatch(rlang::eval_tidy(e, env = rlang::quo_get_env(q)), error = function(err) NULL)
    if (is.character(v)) {
      q <- rlang::new_quosure(rlang::expr(tidyselect::all_of(!!v)), rlang::quo_get_env(q))
    }
  }
  pos <- tryCatch(
    tidyselect::eval_select(q, stats::setNames(as.list(seq_along(cols)), cols), allow_rename = FALSE),
    error = function(err) {
      stop(sprintf("`%s`: %s The data have %s.", what, conditionMessage(err), paste(cols, collapse = ", ")),
           call. = FALSE)
    }
  )
  names(pos)
}

# The id and the name of a new layer: the name the call gives, else the mark's, numbered where taken
.og_layer_names <- function(state, name, kind, id = NULL) {
  label <- .og_quick_label(state, .og_or(name, kind))
  taken <- vapply(state$layers, function(l) l$config$id, "")
  if (!is.null(id)) {
    if (!is.character(id) || length(id) != 1 || is.na(id) || !grepl("^[a-z][a-z0-9_]*$", id)) {
      stop("`id` is a layer's id: lower-case letters, digits and _, starting with a letter.", call. = FALSE)
    }
    if (id %in% taken) stop(sprintf("Layer id \"%s\" is taken by another layer of the map.", id), call. = FALSE)
    return(list(id = id, label = label))
  }
  id <- .og_slug(label)
  while (id %in% taken) id <- paste0(id, "_2")
  list(id = id, label = label)
}

# The marks' MapLibre layer types, the paint property each is coloured through, and its legend swatch
.og_marks <- list(
  point = list(type = "circle", paint = "circle-color", suffix = "dot", kind = "Points", count = "points"),
  line = list(type = "line", paint = "line-color", suffix = "line", kind = "Lines", count = "lines"),
  segment = list(type = "line", paint = "line-color", suffix = "line", kind = "Segments", count = "segments"),
  polygon = list(type = "fill", paint = "fill-color", suffix = "fill", kind = "Areas", count = "areas"),
  text = list(type = "symbol", paint = "text-color", suffix = "text", kind = "Text", count = "labels")
)

# A legend's swatches as the mark draws: dots for points, strokes for lines, filled boxes for areas, dots for text
.og_swatches <- function(legend, mark, outline = NULL) {
  lapply(legend, function(e) {
    col <- .og_or(e$swatch$dot, .og_or(e$swatch$fill, e$swatch$stroke))
    e$swatch <- switch(mark,
      line = , segment = list(fill = col, stroke = col),
      polygon = list(fill = col, stroke = .og_or(outline, col)),
      outline = list(fill = "transparent", stroke = outline),
      ring = list(ring = col),
      list(dot = col)
    )
    e
  })
}

# One layer of a mark, from the map (or data starting one) and the call's arguments as the exported functions take
# them; `a` holds the call's quosures and values. What differs between marks is their style; the rest is shared.
.og_mark <- function(mark, map, data, a) {
  mk <- .og_marks[[mark]]
  if (!inherits(map, "og_map")) {
    if (!is.null(data)) {
      stop(sprintf("og_%s(): give the data once, as the first argument or as `data`.", mark), call. = FALSE)
    }
    data <- map
  }
  s <- .og_quick(
    map, if (!is.null(data)) .og_data(data), a$lon, a$lat, NULL, rlang::quo(NULL), "Map", NULL,
    groups = FALSE
  )
  ctx <- s$ctx_layer
  own <- .og_own_choose(a$choose, ctx)
  con <- ctx$con
  q <- function(v) as.character(DBI::dbQuoteIdentifier(con, v))
  nm <- .og_layer_names(s$state, a$name, mk$kind, a$id)
  id <- nm$id
  data_cols <- setdiff(ctx$cols, c(ctx$lon, ctx$lat, ctx$geometry, a$lon_end, a$lat_end))

  # where: points from lon and lat (or a shape), lines and areas from a shape, a segment from two positions
  if (mark %in% c("line", "polygon") && is.null(ctx$geometry)) {
    stop(sprintf("og_%s() draws shapes: the data need a geometry column (DuckDB's GEOMETRY or WKB) or an sf object.",
                 mark), call. = FALSE)
  }
  if (mark == "segment") {
    ends <- c(a$lon_end, a$lat_end)
    .og_quick_need(ctx, ends)
  }

  # an area's outline alone (`fill = NA`), a point drawn as a ring (`stroke`)
  hollow <- mark == "polygon" && .og_is_na_arg(a$fill)
  if (hollow) a$fill <- rlang::quo(NULL)
  ring <- if (mark == "point") .og_ring_arg(a$stroke)
  # the coloured aesthetic: colour (fill for areas), a value or columns carried as properties og_c<i>
  main <- if (mark == "polygon") "fill" else "colour"
  col <- .og_aes(a[[main]], ctx$cols, main, colour = TRUE)
  cols <- col$columns
  types <- lapply(cols, function(cc) {
    .og_column_type(con, ctx$src, cc, ordered = cc %in% ctx$ordered, declared = ctx$dict[[cc]]$type)
  })
  props_sql <- vapply(seq_along(cols), function(i) {
    t <- types[[i]]
    sprintf(
      ", %s AS og_c%d",
      if (t$kind == "discrete") .og_category_sql(q(cols[i]), t)
      else if (!is.null(t$time)) sprintf("epoch(%s)", q(cols[i]))
      else sprintf("CAST(%s AS DOUBLE)", q(cols[i])),
      i
    )
  }, "")
  geo_sql <- if (mark == "segment") {
    sprintf(", ST_MakeLine(ST_Point(%s, %s), ST_Point(%s, %s)) AS og_geometry",
            q(ctx$lon), q(ctx$lat), q(a$lon_end), q(a$lat_end))
  } else ""
  # a point's time in seconds on the time panel's clock, where the map has a time, so a panel (og_time()) shows only
  # its group's span
  t_s <- if (mark == "point" && !is.null(ctx$time)) .og_time_s_sql(con, ctx$src, ctx$time)
  src <- sprintf("SELECT *%s%s%s FROM (%s)", paste(props_sql, collapse = ""), geo_sql,
                 if (is.null(t_s)) "" else sprintf(", %s AS og_t", t_s), ctx$src)
  colours <- lapply(seq_along(cols), function(i) {
    .og_colour_by(con, src, paste0("og_c", i), paste0("og_c", i), a$palette, a$limits, a$stretch, types[[i]])
  })
  default <- if (mark == "text") "#1b2a3a" else .og_okabe_ito[1]
  fixed <- if (is.null(col)) default else if (!is.null(col$value)) .og_hex(col$value)
  outline <- if (mark == "polygon") {
    oc <- .og_aes(a$colour, ctx$cols, "colour", colour = TRUE)
    if (!is.null(oc$columns)) stop("og_polygon(): `colour` is the outline's, one colour; colour areas by a column with `fill`.", call. = FALSE)
    if (is.null(oc)) "#4d4d4d" else .og_hex(oc$value)
  }

  # sizes, as values: a point's diameter, a line's width, a text's size, in pixels
  num <- function(qq, what) {
    v <- .og_aes(qq, ctx$cols, what)
    if (!is.null(v$columns)) stop(sprintf("`%s` by a column comes in a later version; give a number of pixels.", what), call. = FALSE)
    if (!is.null(v$value) && (!is.numeric(v$value) || v$value <= 0)) stop(sprintf("`%s` is a number of pixels.", what), call. = FALSE)
    v$value
  }
  size <- if (mark == "point") .og_point_size(.og_aes(a$size, ctx$cols, "size")) else if (mark != "text") num(a$size, "size")
  linewidth <- num(a$linewidth, "linewidth")
  thin_px <- if (mark == "point") .og_thin_px(a$thin)

  # text: the label's column
  lab <- if (mark == "text") {
    l <- .og_select(a$label, ctx$cols, "label")
    if (length(l) != 1) stop("og_text(): `label` is the one column whose values are written, bare.", call. = FALSE)
    l
  }
  # and its angle, priority, start zoom by row, size, face and offset, each a value or a column
  tx <- if (mark == "text") .og_text_aes(a, ctx, con, q)

  # what the reader can do
  pop <- .og_select(a$popup, data_cols, "popup")
  hov <- .og_select(a$hover, ctx$cols, "hover")
  if (length(hov) > 1) stop("`hover` is one column.", call. = FALSE)
  title <- if (length(hov)) hov else if (length(pop)) pop[1]
  fields <- lapply(setdiff(pop, title), function(f) {
    t <- .og_column_type(con, ctx$src, f, declared = ctx$dict[[f]]$type)
    Filter(Negate(is.null), list(field = f, label = f, format = if (t$kind == "continuous" && is.null(t$time)) "value"))
  })
  # what a thinning keeps apart in a pixel, so that nothing the page draws or filters is lost: each colour (a number's
  # in eight classes between its limits), each value a choose list picks, and a time panel's group by the hour
  if (!is.null(thin_px)) {
    bins <- unlist(lapply(seq_along(cols), function(i) {
      cl <- colours[[i]]
      if (cl$kind != "continuous") return(NULL)
      v <- if (identical(cl$stretch, "log")) c(sprintf("ln(greatest(og_c%d, %.17g))", i, cl$limits[1]), log(cl$limits))
           else c(sprintf("og_c%d", i), cl$limits)
      sprintf(", least(7, greatest(0, floor((%s - %.17g) / %.17g * 8))) AS og_k%d", v[1], as.numeric(v[2]),
              max(as.numeric(v[3]) - as.numeric(v[2]), 1e-12), i)
    }))
    src <- sprintf("SELECT *%s%s FROM (%s)", paste(bins, collapse = ""),
                   if (is.null(t_s)) "" else ", floor(og_t / 3600) AS og_tb", src)
    thin <- list(
      px = thin_px,
      by = unique(c(
        vapply(seq_along(cols), function(i) if (colours[[i]]$kind == "continuous") paste0("og_k", i) else paste0("og_c", i), ""),
        intersect(.og_or(s$state[["choose_fields"]], character()), ctx$cols), own$fields,
        if (!is.null(t_s)) c(ctx$by, "og_tb")
      )),
      until = a$maxzoom %||% 14
    )
  } else {
    thin <- NULL
  }
  # the rows, numbered and held for the session: a click asks the server for its row (/row/<id>/<n>), so the tiles
  # carry the number and the title, not every column, and stay small however many columns the table has
  if (length(tx$sql)) {
    src <- sprintf("SELECT *, %s FROM (%s)", tx$sql, src)
  }
  rows_nm <- .og_name(con, "og_rows_")
  DBI::dbExecute(con, sprintf("CREATE TEMP TABLE %s AS SELECT row_number() OVER () AS og_row, * FROM (%s)", rows_nm, src))
  # a search over a text column: each row's text and place, which the page reads on its first search
  find <- .og_search_index(con, rows_nm, a$search, ctx, mark, a, tx$zcol, tx$ecol)
  # every feature carries its row's number, its id in the page (MapLibre's promoteId): a click's row, a search's hit,
  # a script's feature state
  props <- unique(c(
    if (length(cols)) paste0("og_c", seq_along(cols)), "og_row", title, hov, lab,
    tx$props,
    intersect(.og_or(s$state[["choose_fields"]], character()), ctx$cols), own$fields,
    if (!is.null(t_s)) c("og_t", ctx$by)
  ))
  if (!is.null(t_s)) {
    s$state$panel_fields[[id]] <- Filter(Negate(is.null), list(by = ctx$by, t = "og_t"))
  }
  tbl <- dplyr::tbl(con, dplyr::sql(sprintf("SELECT * FROM %s", rows_nm)))
  whole <- .og_whole_arg(a$whole)
  sent <- if (mark == "segment") {
    .og_send(tbl, geometry = "og_geometry", properties = props, whole = whole, order = "og_row")
  } else if (!is.null(ctx$geometry)) {
    .og_send(tbl, geometry = ctx$geometry, properties = props, thin = thin, whole = whole, order = "og_row")
  } else {
    .og_send(tbl, lon = ctx$lon, lat = ctx$lat, properties = props, thin = thin, whole = whole, order = "og_row")
  }
  # a point's size: one that stays, or between two bounds from the zoom at which the points stop lying on one another
  radius <- if (mark == "point") {
    if (length(size) == 1) {
      size / 2
    } else {
      # at the zoom found, the points lie about a pixel apart; the least size starts where they lie that far apart
      z0 <- .og_spread_zoom(con, sprintf("SELECT * FROM %s", rows_nm), ctx$lon, ctx$lat, ctx$geometry) + log2(size[1])
      list("interpolate", list("exponential", 2), list("zoom"), z0, size[1] / 2, z0 + log2(size[2] / size[1]), size[2] / 2)
    }
  }

  # the style
  sid <- paste0(id, "-", mk$suffix)
  colour_expr <- if (length(cols)) colours[[1]]$colour else fixed
  zoomed <- function(a0, b0, c0) list("interpolate", list("linear"), list("zoom"), 3, a0, 8, b0, 13, c0)
  style <- switch(mark,
    point = list(list(id = sid, type = "circle", "source-layer" = "features",
      paint = if (is.null(ring)) {
        list("circle-color" = colour_expr, "circle-radius" = radius,
             "circle-opacity" = a$opacity %||% 0.85,
             "circle-stroke-color" = "rgba(255,255,255,0.7)", "circle-stroke-width" = .og_point_stroke(radius))
      } else {
        # a ring: the stroke in the point's colour, the inside drawn clear (and still hit by a click)
        list("circle-color" = colour_expr, "circle-radius" = radius, "circle-opacity" = 0,
             "circle-stroke-color" = colour_expr, "circle-stroke-width" = ring,
             "circle-stroke-opacity" = a$opacity %||% 0.85)
      })),
    line = , segment = list(list(id = sid, type = "line", "source-layer" = "features",
      layout = list("line-cap" = "round", "line-join" = "round"),
      paint = list("line-color" = colour_expr, "line-width" = linewidth %||% zoomed(1, 2, 4),
                   "line-opacity" = a$opacity %||% 0.9))),
    polygon = list(
      # an outline alone keeps its fill, drawn clear, so a click inside the area shows its row
      list(id = sid, type = "fill", "source-layer" = "features",
           paint = list("fill-color" = colour_expr, "fill-opacity" = if (hollow) 0 else a$opacity %||% 0.5)),
      list(id = paste0(id, "-outline"), type = "line", "source-layer" = "features",
           paint = c(list("line-color" = outline, "line-width" = linewidth %||% if (hollow) 2 else 1),
                     if (hollow) list("line-opacity" = a$opacity %||% 0.9)))),
    text = .og_text_styles(id, sid, lab, tx, !is.null(ctx$geometry), isTRUE(a$overlap),
      paint = list("text-color" = colour_expr, "text-opacity" = a$opacity %||% 1,
                   "text-halo-color" = "rgba(255,255,255,0.9)", "text-halo-width" = 1.5))
  )
  sids <- vapply(style, `[[`, "", "id") # a text's styles: at points, and along lines where the data have them
  if (mark == "polygon") sids <- sid
  # what the colour paints, and the legend's swatches: a ring's stroke, an outline alone
  paint_key <- if (!is.null(ring)) "circle-stroke-color" else mk$paint
  look <- if (!is.null(ring)) "ring" else if (hollow) "outline" else mark
  variants <- if (length(cols) > 1) {
    list(label = "Colour by", options = lapply(seq_along(cols), function(i) {
      list(value = cols[i], label = cols[i],
           paint = stats::setNames(rep(list(stats::setNames(list(colours[[i]]$colour), paint_key)), length(sids)), sids),
           legend = if (isTRUE(a$legend)) .og_swatches(colours[[i]]$legend, look, outline))
    }))
  }
  leg <- if (!isTRUE(a$legend)) NULL else if (length(cols)) .og_swatches(colours[[1]]$legend, look, outline) else
    .og_swatches(list(list(swatch = list(dot = fixed), label = nm$label)), look, outline)
  what <- switch(mark, point = "point", line = "line", segment = "line from its start to its end",
                 polygon = "area", text = "label")
  style <- .og_styles_for(.og_style_props(style, a$props, paste0("og_", mark)), sent$kind)
  layer <- og_layer(
    id, sent$kind,
    label = nm$label,
    info = .og_or(a$info, if (length(cols) == 1) sprintf("Each row a %s, coloured by %s.", what, cols) else
      if (length(cols) > 1) sprintf("Each row a %s, coloured by the column chosen below.", what) else
      sprintf("Each row a %s.", what)),
    visible = a$visible,
    tiles = sent$tiles,
    data = sent$data,
    count = list(text = paste("{1}", mk$count)),
    minzoom = if (mark == "text") tx$minzoom else a$minzoom,
    maxzoom = a$maxzoom,
    style = style,
    legend = leg,
    variants = variants,
    popup = if (!is.null(title)) {
      Filter(Negate(is.null), list(click = sids, title = title, row = if (length(pop)) TRUE,
                                   hover = if (length(hov)) TRUE))
    },
    key = "og_row"
  )
  layer$config$choose <- own$config
  layer$config$features <- attr(sent$data, "count") # sent whole, its count, so the page need not read the file
  meta <- .og_popup_meta(pop, ctx$dict, a$labels, a$codes) # checked now, not on the first click
  if (length(pop)) {
    layer$row <- .og_row_reader(con, rows_nm, pop, meta)
  }
  if (!is.null(find)) {
    layer$config$search <- TRUE
    layer$search <- find
  }
  s$state$layer_section[[id]] <- a$section
  .og_hold(.og_quick_map(s, layer, sent$table))
}

# How a layer's rows reach the page: as tiles cut by DuckDB when the page asks (og_tiles_table()), or whole, as one
# GeoJSON file the page reads once (`whole`). By default (NULL) whole when its GeoJSON is at most .og_whole_bytes,
# measured equal to tiles in a browser up to there (fishycode's whole-or-tiles study, 2026-11-11), and needs nothing
# more of R once read; a table of more rows than .og_whole_rows is not tried, as its GeoJSON would be larger. The
# layer's kind, its tiles or data, and the table a served map drops
.og_whole_rows <- 50000
.og_whole_bytes <- 5e6
.og_send <- function(x, geometry = "geometry", lon = NULL, lat = NULL, properties = NULL, thin = NULL, whole = NULL,
                     order = NULL) {
  if (!isFALSE(whole)) {
    n <- if (is.null(whole)) {
      con <- .og_con_for(x)
      DBI::dbGetQuery(con, sprintf("SELECT count(*) AS n FROM (%s)", .og_sql(.og_as_lazy(x, con))))$n
    }
    if (isTRUE(whole) || n <= .og_whole_rows) {
      data <- .og_geojson_table(x, geometry, lon, lat, properties, order)
      if (isTRUE(whole) || attr(data, "bytes") <= .og_whole_bytes) {
        return(list(kind = "geojson", tiles = NULL, data = data, table = NULL))
      }
    }
  }
  tiles <- og_tiles_table(x, geometry = geometry, lon = lon, lat = lat, properties = properties, thin = thin)
  list(kind = "vector", tiles = tiles, data = NULL, table = list(con = .og_con_for(x), name = attr(tiles, "table")))
}

# A layer's search (`search = name`): each row's text, its place (a point's own, a point on a shape, a segment's
# middle), its number and, for a text with a start zoom of its own, that zoom. Read by the page on its first search,
# so it is kept to a size a page reads at once
.og_search_rows <- 500000
.og_search_index <- function(con, rows_nm, q, ctx, mark, a, zcol = NULL, ecol = NULL) {
  col <- .og_select(q, ctx$cols, "search")
  if (!length(col)) {
    return(NULL)
  }
  if (length(col) != 1) {
    stop("`search` is one column, written bare: `search = name`.", call. = FALSE)
  }
  qi <- function(v) as.character(DBI::dbQuoteIdentifier(con, v))
  xy <- if (mark == "segment") {
    c(sprintf("(%s + %s) / 2", qi(ctx$lon), qi(a$lon_end)), sprintf("(%s + %s) / 2", qi(ctx$lat), qi(a$lat_end)))
  } else if (!is.null(ctx$geometry)) {
    p <- sprintf("ST_PointOnSurface(%s)", .og_geom_sql(con, sprintf("SELECT * FROM %s", rows_nm), ctx$geometry))
    c(sprintf("ST_X(%s)", p), sprintf("ST_Y(%s)", p))
  } else {
    c(qi(ctx$lon), qi(ctx$lat))
  }
  from <- sprintf("FROM %s WHERE %s IS NOT NULL AND %s IS NOT NULL", rows_nm, qi(col), xy[1])
  n <- DBI::dbGetQuery(con, paste("SELECT count(*) AS n", from))$n
  if (n > .og_search_rows) {
    stop(sprintf("`search`: %s rows, more than the %s a page searches at once; search a smaller table, or a column of fewer rows.",
                 format(n, big.mark = ","), format(.og_search_rows, big.mark = ",")), call. = FALSE)
  }
  d <- DBI::dbGetQuery(con, sprintf(
    "SELECT CAST(%s AS VARCHAR) AS t, round(%s, 5) AS x, round(%s, 5) AS y, og_row AS r%s%s %s ORDER BY og_row",
    qi(col), xy[1], xy[2], if (is.null(zcol)) "" else sprintf(", CAST(%s AS DOUBLE) AS z", qi(zcol)),
    if (is.null(ecol)) "" else sprintf(", CAST(%s AS DOUBLE) AS e", qi(ecol)), from
  ))
  Filter(Negate(is.null), list(column = col, t = d$t, x = d$x, y = d$y, r = as.integer(d$r), z = d$z, e = d$e))
}

# A search's index as the page reads it: arrays, one a row
.og_search_json <- function(find) {
  keys <- intersect(c("t", "x", "y", "r", "z", "e"), names(find))
  .og_map_json(lapply(find[keys], I))
}

# `fill = NA`: an argument written as NA
.og_is_na_arg <- function(q) {
  if (is.null(q) || rlang::quo_is_null(q) || rlang::quo_is_missing(q)) {
    return(FALSE)
  }
  e <- rlang::quo_get_expr(q)
  is.atomic(e) && length(e) == 1 && is.na(e)
}

# `stroke` (og_point()): a ring's width in pixels, or NULL for a filled point
.og_ring_arg <- function(stroke) {
  if (is.null(stroke)) {
    return(NULL)
  }
  if (!is.numeric(stroke) || length(stroke) != 1 || is.na(stroke) || stroke <= 0) {
    stop("`stroke` is a ring's width, a number of pixels.", call. = FALSE)
  }
  stroke
}

# `whole` as given: NULL (by size), TRUE or FALSE
.og_whole_arg <- function(whole) {
  if (!is.null(whole) && !isTRUE(whole) && !isFALSE(whole)) {
    stop("`whole` is TRUE, FALSE or NULL (whole when small, else as tiles).", call. = FALSE)
  }
  whole
}

# A layer's styles for its kind: a GeoJSON source has no source layer
.og_styles_for <- function(style, kind) {
  if (kind != "geojson") {
    return(style)
  }
  lapply(style, function(st) {
    st[["source-layer"]] <- NULL
    st
  })
}

# A point's size from `size`: one number, a diameter that stays; two, the least and the most of one that follows the
# zoom; none, 2 and 8 pixels
.og_point_size <- function(v) {
  if (!is.null(v$columns)) {
    stop("`size` by a column comes in a later version; give a number of pixels, or two, the least and the most.", call. = FALSE)
  }
  s <- .og_or(v$value, c(2, 8))
  if (!is.numeric(s) || !length(s) %in% 1:2 || anyNA(s) || any(s <= 0) || (length(s) == 2 && s[1] >= s[2])) {
    stop("`size` is a number of pixels, or two, the least and the most, the least first.", call. = FALSE)
  }
  s
}

# The outline of points: none while a point is under 3 pixels across, where it would be all outline
.og_point_stroke <- function(radius) {
  if (!is.list(radius)) {
    return(if (radius < 1.5) 0 else 0.5)
  }
  z0 <- radius[[4]] + max(0, log2(1.5 / radius[[5]]))
  list("interpolate", list("linear"), list("zoom"), z0, 0, z0 + 0.5, 0.5)
}

# `thin` as pixels a cell, or NULL for none
.og_thin_px <- function(thin) {
  if (isTRUE(thin)) {
    return(1)
  }
  if (isFALSE(thin)) {
    return(NULL)
  }
  if (is.numeric(thin) && length(thin) == 1 && is.finite(thin) && thin > 0) {
    return(thin)
  }
  stop("`thin` is TRUE (a point a screen pixel), FALSE (every point) or a number of pixels.", call. = FALSE)
}

# The zoom from which a layer's points stop lying on one another: the first at which their screen pixels (a tile
# drawn 512 wide) are at least half their spots (pixels at zoom 20), by approximate counts in one pass, so that points
# on one spot (a ship in port) count once. A point's size grows from there as a size on the ground would
.og_spread_zoom <- function(con, src, lon, lat, geometry) {
  q <- function(v) as.character(DBI::dbQuoteIdentifier(con, v))
  xy <- if (is.null(geometry)) {
    c(q(lon), q(lat))
  } else {
    g <- .og_geom_sql(con, src, geometry)
    c(sprintf("ST_X(%s)", g), sprintf("ST_Y(%s)", g))
  }
  zs <- 0:20
  counts <- vapply(zs, function(z) {
    sprintf(
      "approx_count_distinct(CAST(floor(u * %1$.0f) AS BIGINT) * 2147483648 + CAST(floor(v * %1$.0f) AS BIGINT)) AS z%2$d",
      2^(z + 9), z
    )
  }, "")
  d <- unlist(DBI::dbGetQuery(con, sprintf(
    "WITH p AS (SELECT (%1$s + 180) / 360 AS u, (1 - ln(tan(radians(%2$s)) + 1 / cos(radians(%2$s))) / pi()) / 2 AS v
                FROM (%3$s) WHERE %1$s BETWEEN -180 AND 180 AND %2$s BETWEEN -85.05 AND 85.05)
     SELECT %4$s FROM p",
    xy[1], xy[2], src, paste(counts, collapse = ", ")
  )))
  if (!length(d) || anyNA(d) || d[length(d)] == 0) {
    return(10)
  }
  zs[which(d >= 0.5 * d[length(d)])[1]]
}

# A range's bin start for each row, in SQL: the value itself where each value is a bin, else the start of the bin it
# falls in (a number as a number, a date or a time as the text the tiles carry, compared as text as the page does)
.og_range_start_sql <- function(con, f) {
  col <- as.character(DBI::dbQuoteIdentifier(con, f$field))
  if (isTRUE(f$closed)) {
    return(col)
  }
  lit <- function(v) if (is.numeric(v)) sprintf("%.17g", v) else as.character(DBI::dbQuoteString(con, v))
  x <- if (f$range == "number") sprintf("CAST(%s AS DOUBLE)", col) else sprintf("CAST(%s AS VARCHAR)", col)
  k <- length(f$bins)
  whens <- if (k > 1) {
    paste(vapply(seq_len(k - 1), function(j) {
      sprintf("WHEN %s < %s THEN %s", x, lit(f$bins[[j]]$hi), lit(f$bins[[j]]$lo))
    }, ""), collapse = " ")
  } else ""
  sprintf("CASE WHEN %s IS NULL THEN NULL %s ELSE %s END", col, whens, lit(f$bins[[k]]$lo))
}

# A layer's own `choose`: the columns it names, and their lists for the page (each value with its rows and extent,
# and each combination's), over this layer alone
.og_own_choose <- function(q, ctx) {
  if (rlang::quo_is_null(q)) {
    return(list(fields = character(), config = NULL))
  }
  fields <- unique(.og_track_cols(q, ctx$cols))
  .og_quick_need(ctx, fields)
  list(fields = fields, config = .og_quick_choose(ctx, fields))
}

# The call's arguments for .og_mark(): quosures for what may name columns, values for the rest; `color` for `colour`
.og_mark_args <- function(env, dq, fname) {
  if ("color" %in% names(dq)) {
    env$colour <- dq[["color"]]
    dq[["color"]] <- NULL
  }
  env$props <- .og_maplibre_props(dq, fname)
  env
}

# A layer function's `...`: MapLibre's paint and layout properties by their own names ("circle-stroke-width" = 2), each
# a value or an expression as a list; any other name is an argument the function has not
.og_maplibre_props <- function(dq, fname) {
  nms <- names(dq) %||% rep("", length(dq))
  bad <- nms[!grepl("^(circle|line|fill|text|icon|symbol)(-[a-z]+)+$", nms)]
  if (length(bad) || any(!nzchar(nms))) {
    stop(sprintf("%s() has no argument %s.", fname, paste(ifelse(nzchar(bad), bad, "unnamed"), collapse = ", ")),
         call. = FALSE)
  }
  lapply(dq, rlang::eval_tidy)
}

# MapLibre's properties put on a layer's styles: each on the styles of its kind (circle, line, fill, and text, icon and
# symbol on symbols), as layout or paint as MapLibre has it
.og_layout_props <- c("line-cap", "line-join", "line-miter-limit", "line-round-limit", "line-sort-key", "fill-sort-key",
                      "circle-sort-key")
.og_symbol_paint <- c(outer(c("text", "icon"), c("color", "halo-color", "halo-width", "halo-blur", "opacity", "translate",
                                                   "translate-anchor"), paste, sep = "-"))
.og_style_props <- function(style, props, fname) {
  if (!length(props)) return(style)
  kind <- function(p) switch(sub("-.*", "", p), circle = "circle", line = "line", fill = "fill", "symbol")
  for (p in names(props)) {
    k <- kind(p)
    where <- if (p %in% .og_layout_props || (k == "symbol" && !p %in% .og_symbol_paint)) "layout" else "paint"
    hit <- FALSE
    for (i in seq_along(style)) {
      if (identical(style[[i]]$type, k)) {
        style[[i]][[where]][[p]] <- props[[p]]
        hit <- TRUE
      }
    }
    if (!hit) {
      stop(sprintf("%s(): `%s` is MapLibre's for %s layers; this layer draws %s.", fname, p, k,
                   paste(unique(vapply(style, `[[`, "", "type")), collapse = " and ")), call. = FALSE)
    }
  }
  style
}

#' Points, lines, areas, segments and text
#'
#' A layer of a map, one mark for each row of the data. `og_point()` draws a circle at each row's position (pings,
#' stations, catches); `og_line()` draws rows that are lines (tows, transects, cables); `og_segment()` draws a line
#' from each row's start to its end (a tow from shooting to hauling); `og_polygon()` draws areas, filled and outlined;
#' `og_text()` writes a column's values at the rows' positions (place names, station ids). Each is piped onto a map,
#' `og_map(data) |> og_point(colour = speed)`, or given the data first, `data |> og_point()`, which starts a map. The
#' data stay in DuckDB and reach the page as vector tiles, so a map of millions of rows stays fast and its colours
#' change in the page.
#'
#' @param map An [og_map()], or the data, which start a map.
#' @param data The rows, if not the map's: a parquet file, folder or glob, a lazy DuckDB table, a data frame or an sf
#'   object (points, or lines and areas for `og_line()` and `og_polygon()`; a table's shapes in a column `geometry`
#'   as DuckDB's GEOMETRY or WKB).
#' @param lon,lat The position's columns, by default `lon` and `lat`; for `og_segment()` its start.
#' @param lon_end,lat_end For `og_segment()`, the columns of its end.
#' @param colour The marks' colour (an area's outline): a colour (`"#c0392b"`), or a column written bare (`colour =
#'   speed`), coloured by `palette`; several columns, `c(behaviour, speed)`, are a choice in the page, the first
#'   shown. A column's colours by default: Okabe-Ito for up to eight values, Paired for up to twelve, Glasbey's 32
#'   beyond, the rest grey as "other"; viridis for an ordered factor and for numbers, dates and times. `color` is the
#'   same.
#' @param fill For `og_polygon()`, the areas' colour, as `colour` is for the other marks; `NA`, none: the outline
#'   alone, in `colour`, 2 pixels wide unless `linewidth` says otherwise, a click inside an area still showing its row.
#' @param size A point's diameter, a text's size (a number, or for text a column written bare), in pixels. For points, by default, a size that follows the zoom:
#'   the least, 2 pixels, until the zoom at which most points lie that far apart, then doubling with each zoom in, as
#'   a size on the ground does, up to the most, 8; `size = c(1, 12)` gives other bounds, one number a size that
#'   stays.
#' @param search A column written bare (`search = name`), its values as text, for the page's *Find* box: whole
#'   matches first, then values it begins, then any holding it, case and accents aside, each kind nearest the view's
#'   centre first, with their count; a click on one takes the map there, at zoom 10 or nearer (a text's own start zoom
#'   where it has one), turns its layer on and shows its row. The column's texts and places go to the page on its first
#'   search (a bundle carries them); a layer of more than 500,000 rows takes none.
#' @param stroke For `og_point()`, a ring: its width in pixels. Each point is drawn as a ring of its colour, hollow,
#'   `size` the diameter inside it; a click on it or inside it shows the row.
#' @param linewidth A line's width (an area's outline), in pixels.
#' @param opacity The marks' opacity, 0-1.
#' @param whole How the rows reach the page: `TRUE`, whole, as one GeoJSON file read once (no further fetching as the
#'   reader zooms and pans, nothing cut at a tile's edge, one file in a bundle); `FALSE`, as vector tiles cut by
#'   DuckDB as the page asks for them, which keep a page light however many rows there are. By default (`NULL`) whole
#'   when its GeoJSON is at most 5 MB (some 30,000 points; a table of more than 50,000 rows is not tried), else as
#'   tiles: measured on layers of real data, the two are equal in a browser up to about 5 MB, and a whole layer needs
#'   nothing more of R once read, so a served map pans and zooms while R is busy. Above it a whole layer is slower and
#'   heavier (about 50 MB of a browser's memory for each MB of GeoJSON).
#' @param thin For points: in each tile, one point for each screen pixel, `TRUE` (each colour, each value a `choose`
#'   list picks and each group of a time panel keeping its own), so a tile of millions of rows reaches the page as
#'   what can be seen of them; a number of pixels for coarser cells; `FALSE` keeps every point. At the layer's
#'   deepest zoom (`maxzoom`, 14 by default) and beyond, only points that would be drawn on one spot are dropped.
#' @param label For `og_text()`, the column whose values are written, bare. On a line (data whose shapes are lines), the
#'   text is written along it, at its middle.
#' @param angle,priority,fontface,offset,overlap For `og_text()`, each a value or a column written bare: `angle`, the
#'   text turned that many degrees counter-clockwise, as ggplot2's; `priority`, which text is placed first where two
#'   would meet, the higher (within a tile, as MapLibre places); `fontface`, `"plain"`, `"italic"`, `"bold"` or
#'   `"bold.italic"`, in the base map's own fonts for that face; `offset`, `c(x, y)` in text heights, x to the right and y
#'   up (a column takes at most 256 pairs of values); `overlap`, `TRUE` to draw every text where others meet (MapLibre
#'   leaves out the later). A turned text keeps the upright box round it clear of others.
#' @param palette The colours for a column, in place of the default: a palette's name (from [og_palettes()],
#'   `palette.pals()` or `hcl.pals()`, written loosely: `"set1"` is Set 1), colours, colours named by value
#'   (`c(Fishing = "#c0392b")`), or a function of n (`viridisLite::mako`).
#' @param limits,stretch For a numeric column: the values the palette's ends stand at (by default its 1st and 99th
#'   percentile), and how the colours spread between them, `"linear"`, `"log"` or `"equal"` (equal shares of the
#'   values).
#' @param legend Whether the layer has a legend.
#' @param popup The columns a click shows, written bare, or a variable holding their names; `TRUE`, every column;
#'   `FALSE`, no popup. A click shows the row as a table, read from the server (a bundle carries the rows): a column's
#'   name, its unit beside it and its description behind it, where the data's dictionary or `labels` give them.
#' @param labels The columns' names as the popup shows them, in place of the data's: `c(speed = "Speed (knots)")`. By
#'   default a data frame's column attributes (`label`, `units`) or a parquet file's own dictionary (an entry of
#'   data-dict.tidyverse.org's format in its metadata, as [og_example()]'s files hold), else the column's name.
#' @param codes The labels of a coded column's values, shown beside each code: a named list by column, each a named
#'   vector (`c("6" = "bottom trawl")`) or a table of code and label; by default the dictionary's, where it has them.
#' @param hover A column whose value is shown beside the pointer.
#' @param choose The columns, written bare, whose values the reader picks to show of this layer alone, each under
#'   the layer's name: text, a factor, a logical or a whole number (an id, a code) as a list (chips for up to 12
#'   values, else a list to show one at a time), a fraction, a date or a time as a range with two handles, unless the
#'   data's dictionary declares otherwise (as for [og_map()]); ‹ and › step through either. Several are linked:
#'   each offers only the values the others leave. For choices that drive every layer with the column, give `choose`
#'   to [og_map()].
#' @param name,id,info The layer's name in the sidebar, its id, and the text behind its ⓘ. The id (lower-case letters,
#'   digits and _) is the key the page's address and a page's own script know the layer by, its styles `<id>-dot`,
#'   `<id>-line`, `<id>-fill` and `<id>-text`; by default made from the name.
#' @param section The sidebar's box the layer sits in, by its title. The layer is drawn over those added before it,
#'   whatever their boxes, unless [og_map()]'s `order` says otherwise.
#' @param visible Whether the layer is on when the page opens.
#' @param minzoom,maxzoom The zoom the layer is drawn from, and its tiles' deepest (14 by default), past which the map
#'   draws that zoom's tiles larger. For `og_text()`, `minzoom` may be a column written bare: each row from its own
#'   zoom, from the first whole zoom at or above it (MapLibre judges a zoom in a filter at whole zooms), so a text due
#'   at 7.4 shows from 8.
#' @param endzoom For `og_text()`, the zoom a label stops showing at: a number, or a column written bare, each row
#'   until its own, hidden from the first whole zoom at or above it (a text due to end at 7.4 shows through zoom 7); a
#'   row with none shows on. With `minzoom`, a label shows in a band of zooms, as a name the map has room for only
#'   between two zooms; a search (`search`) takes the map to a zoom where its label shows.
#' @param ... MapLibre's own paint and layout properties for the layer's styles, by MapLibre's names in quotes:
#'   `"circle-stroke-color" = "white"` (a ring of another colour round a filled point), `"line-dasharray" = list(2, 1)`,
#'   `"text-halo-width" = 0`. Each goes to the styles of its kind (circle, line, fill; text, icon and symbol on a text's),
#'   as paint or layout as MapLibre has it; an expression is a list, `list("get", "size")`. `color` is taken for
#'   `colour`.
#' @return An [og_map()] with the layer added.
#' @seealso [og_map()]; [og_layer()] for a layer in MapLibre's own terms.
#' @name og_point
#' @export
#' @examples
#' \donttest{
#' m <- og_example("dansk") |>
#'   og_point(colour = c(behaviour, speed), popup = c(vessel_id, time_stamp, speed))
#' format(m)
#' og_map(og_example("trawlsurveytows")) |> og_line(name = "Tows") |> format()
#' og_example("dansk_harbours") |> og_polygon(fill = "#d9822b", popup = SI_HARB) |> format()
#' }
og_point <- function(
  map, data = NULL, lon = NULL, lat = NULL,
  colour = NULL, size = NULL, stroke = NULL, opacity = NULL, whole = NULL, thin = TRUE,
  palette = NULL, limits = NULL, stretch = NULL, legend = TRUE,
  popup = TRUE, labels = NULL, codes = NULL, hover = NULL, choose = NULL, search = NULL,
  name = NULL, id = NULL, info = NULL, section = "Layers", visible = TRUE,
  minzoom = NULL, maxzoom = NULL, ...
) {
  a <- .og_mark_args(list(
    lon = lon, lat = lat, colour = rlang::enquo(colour), size = rlang::enquo(size), stroke = stroke, opacity = opacity,
    whole = whole, thin = thin,
    palette = palette, limits = limits, stretch = stretch, legend = legend, popup = rlang::enquo(popup),
    labels = labels, codes = codes, hover = rlang::enquo(hover), choose = rlang::enquo(choose), search = rlang::enquo(search), name = name, id = id, info = info, section = section,
    visible = visible, minzoom = minzoom, maxzoom = maxzoom
  ), rlang::enquos(...), "og_point")
  .og_scope()
  .og_mark("point", map, data, a)
}

#' @rdname og_point
#' @export
og_line <- function(
  map, data = NULL,
  colour = NULL, linewidth = NULL, opacity = NULL, whole = NULL,
  palette = NULL, limits = NULL, stretch = NULL, legend = TRUE,
  popup = TRUE, labels = NULL, codes = NULL, hover = NULL, choose = NULL, search = NULL,
  name = NULL, id = NULL, info = NULL, section = "Layers", visible = TRUE,
  minzoom = NULL, maxzoom = NULL, ...
) {
  a <- .og_mark_args(list(
    colour = rlang::enquo(colour), linewidth = rlang::enquo(linewidth), opacity = opacity, whole = whole,
    palette = palette, limits = limits, stretch = stretch, legend = legend, popup = rlang::enquo(popup),
    labels = labels, codes = codes, hover = rlang::enquo(hover), choose = rlang::enquo(choose), search = rlang::enquo(search), name = name, id = id, info = info, section = section,
    visible = visible, minzoom = minzoom, maxzoom = maxzoom
  ), rlang::enquos(...), "og_line")
  .og_scope()
  .og_mark("line", map, data, a)
}

#' @rdname og_point
#' @export
og_segment <- function(
  map, data = NULL, lon = NULL, lat = NULL, lon_end, lat_end,
  colour = NULL, linewidth = NULL, opacity = NULL, whole = NULL,
  palette = NULL, limits = NULL, stretch = NULL, legend = TRUE,
  popup = TRUE, labels = NULL, codes = NULL, hover = NULL, choose = NULL, search = NULL,
  name = NULL, id = NULL, info = NULL, section = "Layers", visible = TRUE,
  minzoom = NULL, maxzoom = NULL, ...
) {
  a <- .og_mark_args(list(
    lon = lon, lat = lat, lon_end = .og_one_col(rlang::enquo(lon_end), "lon_end"),
    lat_end = .og_one_col(rlang::enquo(lat_end), "lat_end"),
    colour = rlang::enquo(colour), linewidth = rlang::enquo(linewidth), opacity = opacity, whole = whole,
    palette = palette, limits = limits, stretch = stretch, legend = legend, popup = rlang::enquo(popup),
    labels = labels, codes = codes, hover = rlang::enquo(hover), choose = rlang::enquo(choose), search = rlang::enquo(search), name = name, id = id, info = info, section = section,
    visible = visible, minzoom = minzoom, maxzoom = maxzoom
  ), rlang::enquos(...), "og_segment")
  .og_scope()
  .og_mark("segment", map, data, a)
}

#' @rdname og_point
#' @export
og_polygon <- function(
  map, data = NULL,
  colour = NULL, fill = NULL, linewidth = NULL, opacity = NULL, whole = NULL,
  palette = NULL, limits = NULL, stretch = NULL, legend = TRUE,
  popup = TRUE, labels = NULL, codes = NULL, hover = NULL, choose = NULL, search = NULL,
  name = NULL, id = NULL, info = NULL, section = "Layers", visible = TRUE,
  minzoom = NULL, maxzoom = NULL, ...
) {
  a <- .og_mark_args(list(
    colour = rlang::enquo(colour), fill = rlang::enquo(fill), linewidth = rlang::enquo(linewidth),
    opacity = opacity, whole = whole, palette = palette, limits = limits, stretch = stretch, legend = legend,
    popup = rlang::enquo(popup), labels = labels, codes = codes, hover = rlang::enquo(hover),
    choose = rlang::enquo(choose), search = rlang::enquo(search), name = name, id = id,
    info = info, section = section, visible = visible, minzoom = minzoom, maxzoom = maxzoom
  ), rlang::enquos(...), "og_polygon")
  .og_scope()
  .og_mark("polygon", map, data, a)
}

#' @rdname og_point
#' @export
og_text <- function(
  map, data = NULL, lon = NULL, lat = NULL,
  colour = NULL, size = NULL, opacity = NULL, whole = NULL, label,
  angle = NULL, priority = NULL, fontface = NULL, offset = NULL, overlap = FALSE,
  palette = NULL, limits = NULL, stretch = NULL, legend = FALSE,
  popup = FALSE, labels = NULL, codes = NULL, hover = NULL, choose = NULL, search = NULL,
  name = NULL, id = NULL, info = NULL, section = "Layers", visible = TRUE,
  minzoom = NULL, endzoom = NULL, maxzoom = NULL, ...
) {
  if (!isTRUE(overlap) && !isFALSE(overlap)) stop("og_text(): `overlap` is TRUE or FALSE.", call. = FALSE)
  a <- .og_mark_args(list(
    lon = lon, lat = lat, colour = rlang::enquo(colour), size = rlang::enquo(size), opacity = opacity, whole = whole,
    label = rlang::enquo(label), angle = rlang::enquo(angle), priority = rlang::enquo(priority),
    fontface = rlang::enquo(fontface), offset = rlang::enquo(offset), overlap = overlap,
    palette = palette, limits = limits, stretch = stretch, legend = legend,
    popup = rlang::enquo(popup), labels = labels, codes = codes, hover = rlang::enquo(hover),
    choose = rlang::enquo(choose), search = rlang::enquo(search), name = name, id = id,
    info = info, section = section, visible = visible, minzoom = rlang::enquo(minzoom), endzoom = rlang::enquo(endzoom),
    maxzoom = maxzoom
  ), rlang::enquos(...), "og_text")
  .og_scope()
  .og_mark("text", map, data, a)
}

# og_text()'s faces, ggplot2's words
.og_faces <- c("plain", "italic", "bold", "bold.italic")

# og_text()'s own aesthetics, each a value or one column written bare: the start zoom by row (`minzoom`), `angle`,
# `priority`, `size`, `fontface` and `offset`. Returns the columns the features carry (`props`), the SQL of the offset's
# key (`sql`), the layout (`layout`), the styles' filter (`filter`), the face (`face`) and the layer's own minzoom
.og_text_aes <- function(a, ctx, con, q) {
  cols <- ctx$cols
  one <- function(qq, what, ok, why) {
    v <- .og_aes(qq, cols, what)
    if (is.null(v)) return(NULL)
    if (length(v$columns) > 1) stop(sprintf("og_text(): `%s` is one column or one value.", what), call. = FALSE)
    if (length(v$columns) == 1) return(list(column = v$columns))
    if (length(v$value) != 1 || !ok(v$value)) {
      stop(sprintf("og_text(): `%s` is %s, or a column written bare.", what, why), call. = FALSE)
    }
    list(value = v$value)
  }
  num <- function(x) is.numeric(x) && is.finite(x)
  get <- function(col) list("to-number", list("get", col))
  z0 <- one(a$minzoom, "minzoom", function(x) num(x) && x >= 0 && x <= 24, "a zoom from 0 to 24")
  z1 <- one(a$endzoom, "endzoom", function(x) num(x) && x > 0 && x <= 24, "a zoom from 0 to 24")
  if (!is.null(z0$value) && !is.null(z1$value) && z1$value <= z0$value) {
    stop("og_text(): `endzoom` is a zoom after `minzoom`.", call. = FALSE)
  }
  angle <- one(a$angle, "angle", num, "an angle in degrees, counter-clockwise")
  prio <- one(a$priority, "priority", num, "a number (higher placed first)")
  size <- one(a$size, "size", function(x) num(x) && x > 0, "a size in pixels")
  face <- one(a$fontface, "fontface", function(x) is.character(x) && x %in% .og_faces,
              paste0("one of ", paste0('"', .og_faces, '"', collapse = ", ")))
  off <- .og_offset(a$offset, cols, con, ctx$src, q)
  layout <- list("text-size" = if (!is.null(size$column)) get(size$column) else size$value %||% 13)
  if (!is.null(angle)) {
    # MapLibre turns text clockwise; ggplot2's angle, and this one, counter-clockwise
    layout[["text-rotate"]] <- if (!is.null(angle$column)) list("*", -1, get(angle$column)) else -angle$value
    layout[["text-rotation-alignment"]] <- "map"
  }
  if (!is.null(prio)) {
    # MapLibre places the lowest sort key first; a priority, the highest
    layout[["symbol-sort-key"]] <- if (!is.null(prio$column)) list("*", -1, get(prio$column)) else -prio$value
  }
  if (!is.null(off$layout)) layout[["text-offset"]] <- off$layout
  list(
    props = unique(c(z0$column, z1$column, angle$column, prio$column, size$column, face$column,
                     if (!is.null(off$sql)) "og_off")),
    sql = off$sql,
    layout = layout,
    # a row drawn from the first whole zoom at or above its own start, and until the first at or above its own end:
    # MapLibre judges a filter's zoom at whole zooms. A row with no end shows on (a missing value would read as 0)
    filter = .og_both(
      if (!is.null(z0$column)) list(">=", list("zoom"), get(z0$column)),
      if (!is.null(z1$column)) list("<", list("zoom"), list("to-number", list("coalesce", list("get", z1$column), 99)))
    ),
    face = if (!is.null(face$column)) list("get", face$column) else face$value,
    minzoom = z0$value,
    endzoom = z1$value,
    zcol = z0$column,
    ecol = z1$column
  )
}

# A text's offset, `c(x, y)` in text heights (x to the right, y up), each a number or a column written bare. Numbers are
# MapLibre's text-offset itself; a column's values become a key each row carries (`og_off`) and a match of the key to
# its offset, so at most 256 pairs of values (to a thousandth of a text height)
.og_offset <- function(qq, cols, con, src, q) {
  if (is.null(qq) || rlang::quo_is_null(qq) || rlang::quo_is_missing(qq)) return(NULL)
  e <- rlang::quo_get_expr(qq)
  parts <- if (is.numeric(e) && length(e) == 2) as.list(e) else if (rlang::is_call(e, "c") && length(rlang::call_args(e)) == 2) {
    rlang::call_args(e)
  }
  bad <- function() {
    stop("og_text(): `offset` is c(x, y) in text heights (x to the right, y up), each a number or a column written bare.",
         call. = FALSE)
  }
  if (is.null(parts)) bad()
  parts <- lapply(parts, function(p) {
    if (rlang::is_call(p, "-") && length(rlang::call_args(p)) == 1 && is.numeric(rlang::call_args(p)[[1]])) p <- -rlang::call_args(p)[[1]]
    if (is.numeric(p) && length(p) == 1 && is.finite(p)) return(list(value = p))
    if (rlang::is_symbol(p) && rlang::as_string(p) %in% cols) return(list(column = rlang::as_string(p)))
    bad()
  })
  if (all(vapply(parts, function(p) !is.null(p$value), logical(1)))) {
    return(list(layout = c(parts[[1]]$value, -parts[[2]]$value)))
  }
  sql <- vapply(parts, function(p) {
    if (!is.null(p$value)) sprintf("CAST(%.17g AS DOUBLE)", p$value) else sprintf("round(CAST(%s AS DOUBLE), 3)", q(p$column))
  }, "")
  pairs <- DBI::dbGetQuery(con, sprintf("SELECT DISTINCT coalesce(%s, 0) AS x, coalesce(%s, 0) AS y FROM (%s) LIMIT 257",
                                        sql[1], sql[2], src))
  if (nrow(pairs) > 256) {
    stop("og_text(): an offset by a column takes at most 256 pairs of values (to a thousandth of a text height).",
         call. = FALSE)
  }
  key <- function(x, y) sprintf("%.3f|%.3f", x, y)
  list(
    sql = sprintf("printf('%%.3f|%%.3f', coalesce(%s, 0), coalesce(%s, 0)) AS og_off", sql[1], sql[2]),
    layout = c(list("match", list("get", "og_off")),
               unlist(lapply(seq_len(nrow(pairs)), function(i) {
                 list(key(pairs$x[i], pairs$y[i]), list("literal", c(pairs$x[i], -pairs$y[i])))
               }), recursive = FALSE),
               list(list("literal", c(0, 0))))
  )
}

# MapLibre filters, all of them (NULL for none given)
.og_both <- function(...) {
  f <- Filter(Negate(is.null), list(...))
  if (!length(f)) NULL else if (length(f) == 1) f[[1]] else c(list("all"), f)
}

# A text layer's styles: at points (and in areas), and, where the data have lines, along them (MapLibre's line-center,
# a long name on a line of its own); each with the start zoom's filter
.og_text_styles <- function(id, sid, lab, tx, shapes, overlap, paint) {
  layout <- c(list("text-field" = list("to-string", list("get", lab)), "text-allow-overlap" = overlap,
                   "text-anchor" = "center"), tx$layout)
  lines <- list("in", list("geometry-type"), list("literal", list("LineString", "MultiLineString")))
  both <- .og_both
  style <- function(st_id, lay, filter) {
    Filter(Negate(is.null), list(id = st_id, type = "symbol", "source-layer" = "features", filter = filter, layout = lay,
                                 paint = paint, og_face = tx$face, maxzoom = tx$endzoom))
  }
  if (!shapes) {
    return(list(style(sid, layout, tx$filter)))
  }
  on_line <- layout[setdiff(names(layout), c("text-rotate", "text-rotation-alignment", "text-offset", "text-anchor"))]
  on_line[["symbol-placement"]] <- "line-center"
  list(
    style(sid, layout, both(list("!", lines), tx$filter)),
    style(paste0(id, "-text-line"), on_line, both(lines, tx$filter))
  )
}

# One column named bare or as a string, for an argument that is always a column (a segment's end)
.og_one_col <- function(q, what) {
  if (rlang::quo_is_missing(q)) {
    stop(sprintf("`%s` is a column of the data, written bare.", what), call. = FALSE)
  }
  e <- rlang::quo_get_expr(q)
  if (is.character(e) && length(e) == 1) e else rlang::as_name(e)
}

#' Paths: rows joined in time, a line per group
#'
#' A layer of lines made from rows joined in order of `time`, one line for each value of `group` (a float, an animal,
#' a ship, or each of its legs with `group = c(id, leg)`), as ggplot2's `geom_path()` joins rows in their order:
#' tracks of drifters, tagged animals, gliders and ships. A silence longer than `max_gap_s` seconds breaks a line. Coloured by a column, a line is cut where
#' the column's value changes, each run in its value's colour, and stays joined across the change.
#'
#' @inheritParams og_point
#' @param group The columns, written bare, whose values each have a line: one, or several, `c(id, leg)`. By default
#'   none, one line through all the rows (and the map's and the layer's `choose` columns, so a choice shows whole
#'   lines).
#' @param time The column that orders the rows, written bare: a time, or any column that orders (a distance along a
#'   transect, a sequence number). A lazy table has no order of its own, so it is needed.
#' @param max_gap_s A silence between two rows of a line longer than this many seconds breaks it, as `3600` for an
#'   hour; `Inf`, the default, for none, so no gap is hidden.
#' @param colour The lines' colour: a colour, or one column written bare, whose runs of one value cut and colour the
#'   line (Okabe-Ito and the other defaults of [og_point()]).
#' @return An [og_map()] with the layer added.
#' @export
#' @examples
#' \donttest{
#' m <- og_map(og_example("dansk")) |>
#'   og_path(group = vessel_id, time = time_stamp, colour = behaviour, max_gap_s = 3600)
#' format(m)
#' }
og_path <- function(
  map, data = NULL, lon = NULL, lat = NULL, group = NULL, time, max_gap_s = Inf,
  colour = NULL, linewidth = NULL, opacity = NULL, whole = NULL,
  palette = NULL, limits = NULL, stretch = NULL, legend = TRUE,
  popup = TRUE, labels = NULL, codes = NULL, hover = NULL, choose = NULL,
  name = NULL, id = NULL, info = NULL, section = "Layers", visible = TRUE,
  minzoom = NULL, maxzoom = NULL, ...
) {
  dq <- rlang::enquos(...)
  colour_q <- rlang::enquo(colour)
  if ("color" %in% names(dq)) {
    colour_q <- dq[["color"]]
    dq[["color"]] <- NULL
  }
  ml_props <- .og_maplibre_props(dq, "og_path") # MapLibre's paint and layout from `...`
  .og_scope()
  .og_check_gap(max_gap_s)
  if (!inherits(map, "og_map")) {
    if (!is.null(data)) stop("og_path(): give the data once, as the first argument or as `data`.", call. = FALSE)
    data <- map
  }
  tcol <- .og_one_col(rlang::enquo(time), "time")
  s <- .og_quick(
    map, if (!is.null(data)) .og_data(data), lon, lat, NULL, rlang::quo(NULL), "Map", NULL,
    groups = FALSE
  )
  ctx <- s$ctx_layer
  own <- .og_own_choose(rlang::enquo(choose), ctx)
  ctx$time <- if (tcol %in% ctx$cols) tcol # the layer's, not the map's
  grp0 <- .og_select(rlang::enquo(group), ctx$cols, "group")
  # on the map's own rows, the path's time and group are the map's too, for a time panel added after it (og_time())
  if (identical(s$state$ctx$src, ctx$src)) {
    s$state$ctx$time <- .og_or(s$state$ctx$time, ctx$time)
    s$state$ctx$by <- .og_or(s$state$ctx$by, if (length(grp0)) grp0[1])
  }
  if (!is.null(ctx$geometry)) {
    stop("og_path() joins rows with positions (lon, lat); for rows that are lines, use og_line().", call. = FALSE)
  }
  if (is.null(ctx$time) || !identical(ctx$time, tcol)) {
    stop(sprintf("og_path(): no column %s in the data to order the rows by.", tcol), call. = FALSE)
  }
  con <- ctx$con
  q <- function(v) as.character(DBI::dbQuoteIdentifier(con, v))
  nm <- .og_layer_names(s$state, name, "Paths", id)
  id <- nm$id
  grp <- .og_select(rlang::enquo(group), ctx$cols, "group")
  keys <- unique(c(grp, intersect(.og_or(s$state[["choose_fields"]], character()), ctx$cols), own$fields))
  col <- .og_aes(colour_q, ctx$cols, "colour", colour = TRUE)
  if (length(col$columns) > 1) {
    stop("og_path() is coloured by one column; for another, add another og_path().", call. = FALSE)
  }
  cc <- col$columns
  type <- if (length(cc)) .og_column_type(con, ctx$src, cc, ordered = cc %in% ctx$ordered, declared = ctx$dict[[cc]]$type)
  gap <- .og_gap_sql(max_gap_s)
  t_s <- .og_time_s_sql(con, ctx$src, ctx$time)
  .og_extension(con, "spatial")
  # a range chosen (a number, a date or a time) splits the lines by its bins, not its values: each run carries its bin's
  # start under the column's name, which the page's range compares
  ranged <- Filter(function(f) !is.null(f$range) && f$field %in% keys, c(s$state[["choose"]]$fields, own$config$fields))
  ranged <- ranged[!duplicated(vapply(ranged, `[[`, "", "field"))]
  bin_nm <- function(f) paste0("og_k_", f$field)
  run_src <- if (length(ranged)) {
    sprintf("SELECT *, %s FROM (%s)", paste(vapply(ranged, function(f) {
      sprintf("%s AS %s", .og_range_start_sql(con, f), q(bin_nm(f)))
    }, ""), collapse = ", "), ctx$src)
  } else {
    ctx$src
  }
  run_keys <- vapply(keys, function(k) {
    f <- Filter(function(f) f$field == k, ranged)
    if (length(f)) bin_nm(f[[1]]) else k
  }, "", USE.NAMES = FALSE)
  lines_src <- .og_runs_sql(
    con, run_src, ctx$lon, ctx$lat, ctx$time, run_keys,
    values = if (length(cc)) {
      if (type$kind == "discrete") .og_category_sql(q(cc), type)
      else if (!is.null(type$time)) sprintf("epoch(%s)", q(cc))
      else sprintf("CAST(%s AS DOUBLE)", q(cc))
    },
    names = "og_c1", count = "rows", t_names = c("og_t0", "og_t1"), gap = gap, t_s = t_s
  )
  if (length(ranged)) {
    lines_src <- sprintf("SELECT * EXCLUDE (%s), %s FROM (%s)",
      paste(vapply(ranged, function(f) q(bin_nm(f)), ""), collapse = ", "),
      paste(vapply(ranged, function(f) sprintf("%s AS %s", q(bin_nm(f)), q(f$field)), ""), collapse = ", "),
      lines_src)
  }
  colours <- if (length(cc)) .og_colour_by(con, lines_src, "og_c1", "og_c1", palette, limits, stretch, type)
  fixed <- if (is.null(col)) .og_okabe_ito[1] else if (!is.null(col$value)) .og_hex(col$value)
  hov <- .og_select(rlang::enquo(hover), keys, "hover")
  pop <- .og_select(rlang::enquo(popup), c(keys, if (length(cc)) cc), "popup")
  props <- unique(c(keys, if (length(cc)) "og_c1", "rows", "start", "stop", if (!is.null(t_s)) c("og_t0", "og_t1")))
  if (!is.null(t_s)) {
    s$state$panel_fields[[id]] <- list(by = .og_or(grp[1], NULL), t0 = "og_t0", t1 = "og_t1")
  }
  sent <- .og_send(dplyr::tbl(con, dplyr::sql(lines_src)), properties = props, whole = .og_whole_arg(whole))
  sid <- paste0(id, "-line")
  title <- if (length(hov)) hov else if (length(intersect(pop, keys))) intersect(pop, keys)[1] else if (length(pop)) "start"
  pm <- .og_popup_meta(unique(c(keys, cc)), ctx$dict, labels, codes)
  lab_of <- function(f) {
    m <- pm[[f]]
    paste0(.og_or(m$label, f), if (!is.null(m$unit)) sprintf(" (%s)", m$unit) else "")
  }
  coded <- function(f) {
    m <- pm[[f]]
    if (length(m$codes)) as.list(stats::setNames(paste(names(m$codes), "\u00b7", m$codes), names(m$codes)))
  }
  fields <- if (length(pop)) {
    c(
      lapply(setdiff(intersect(pop, keys), title), function(f) {
        Filter(Negate(is.null), list(field = f, label = lab_of(f), values = coded(f)))
      }),
      if (length(cc) && cc %in% pop) list(Filter(Negate(is.null), list(
        field = "og_c1", label = lab_of(cc), values = coded(cc),
        format = if (type$kind == "continuous" && is.null(type$time)) "value"
      ))),
      list(list(field = "start", label = "from"), list(field = "stop", label = "to"),
           list(field = "rows", label = "rows", format = "count"))
    )
  }
  layer <- og_layer(
    id, sent$kind,
    label = nm$label,
    info = .og_or(info, paste0(
      if (length(grp)) sprintf("The rows of each %s", paste(grp, collapse = " and ")) else "The rows",
      " joined in order of ", ctx$time,
      if (is.finite(max_gap_s)) sprintf(", broken where two are more than %s apart", .og_duration_text(max_gap_s)),
      if (length(cc)) sprintf("%s coloured by %s", if (is.finite(max_gap_s)) ", and" else " and", cc),
      "."
    )),
    visible = visible,
    tiles = sent$tiles,
    data = sent$data,
    count = list(text = "{1} lines"),
    minzoom = minzoom,
    maxzoom = maxzoom,
    style = .og_styles_for(.og_style_props(list(list(
      id = sid, type = "line", "source-layer" = "features",
      layout = list("line-cap" = "round", "line-join" = "round"),
      paint = list("line-color" = if (length(cc)) colours$colour else fixed,
                   "line-width" = .og_or(linewidth, list("interpolate", list("linear"), list("zoom"), 3, 1, 8, 2, 13, 3.5)),
                   "line-opacity" = .og_or(opacity, 0.85))
    )), ml_props, "og_path"), sent$kind),
    legend = if (!isTRUE(legend)) NULL else if (length(cc)) .og_swatches(colours$legend, "line") else
      .og_swatches(list(list(swatch = list(dot = fixed), label = nm$label)), "line"),
    popup = if (!is.null(title)) {
      Filter(Negate(is.null), list(click = sid, title = title, fields = fields, hover = if (length(hov)) TRUE))
    }
  )
  layer$config$choose <- own$config
  layer$config$features <- attr(sent$data, "count") # sent whole, its count, so the page need not read the file
  s$state$max_gap_s <- .og_or(s$state$max_gap_s, max_gap_s)
  s$state$layer_section[[id]] <- section
  .og_hold(.og_quick_map(s, layer, sent$table))
}

# Rows joined into lines, the query a path is drawn from (og_path(), and the quick look's track): a line per value of
# `keys` and stretch, a stretch broken where two rows are more than the gap apart (`gap`, .og_gap_sql()) and where any
# of `values` (SQL expressions, each kept as `names[i]`) changes; a run ends at the next run's first row, so the line
# stays joined across a change. Each line carries its rows' count (`count`), its first and last time as text (start,
# stop), and in seconds on the time panel's clock (`t_names`, from `t_s`, .og_time_s_sql()), and its geometry.
.og_runs_sql <- function(con, src, lon, lat, time, keys, values, names, count, t_names, gap, t_s) {
  q <- function(v) as.character(DBI::dbQuoteIdentifier(con, v))
  # a time's seconds, or a number as it is (a sequence, a distance along a transect), for the gaps and the text
  one <- DBI::dbGetQuery(con, sprintf("SELECT %s AS t FROM (%s) LIMIT 0", q(time), src))$t
  numeric <- is.numeric(one)
  sec <- function(x) if (numeric) sprintf("CAST(%s AS DOUBLE)", x) else sprintf("epoch(%s)", x)
  txt <- function(x) if (numeric) sprintf("CAST(%s AS VARCHAR)", x) else sprintf("strftime(%s, '%%Y-%%m-%%d %%H:%%M')", x)
  k <- length(values)
  part <- if (!length(keys)) "" else paste("PARTITION BY", paste(q(keys), collapse = ", "))
  sprintf(
    "WITH s AS (
       SELECT %1$s %2$s AS lon, %3$s AS lat, %4$s AS t, %10$s AS og_ts %8$s FROM (%7$s)
       WHERE %2$s IS NOT NULL AND %3$s IS NOT NULL AND %4$s IS NOT NULL),
     w AS (
       SELECT *, CASE WHEN %15$s - %16$s > %6$s %9$s THEN 1 ELSE 0 END AS brk,
              lead(lon) OVER o AS lon2, lead(lat) OVER o AS lat2, %17$s - %15$s AS dt_next
       FROM s WINDOW o AS (%5$s ORDER BY t)),
     g AS (SELECT *, sum(brk) OVER (%5$s ORDER BY t ROWS UNBOUNDED PRECEDING) AS stretch FROM w),
     a AS (
       SELECT %1$s %11$s count(*) AS %12$s, %18$s AS start,
              %19$s AS stop, min(og_ts) AS %13$s, max(og_ts) AS %14$s,
              list(ST_Point(lon, lat) ORDER BY t) AS pts,
              last(CASE WHEN dt_next <= %6$s THEN lon2 END ORDER BY t) AS lon2,
              last(CASE WHEN dt_next <= %6$s THEN lat2 END ORDER BY t) AS lat2
       FROM g GROUP BY %1$s stretch),
     l AS (SELECT * EXCLUDE (pts, lon2, lat2),
                  CASE WHEN lon2 IS NULL THEN pts ELSE list_append(pts, ST_Point(lon2, lat2)) END AS pts FROM a)
     SELECT * EXCLUDE (pts), ST_MakeLine(pts) AS geometry FROM l WHERE len(pts) > 1",
    if (!length(keys)) "" else paste0(paste(q(keys), collapse = ", "), ","),
    q(lon), q(lat), q(time), part, gap, src,
    paste(vapply(seq_len(k), function(i) sprintf(", %s AS v%d", values[i], i), ""), collapse = ""),
    paste(vapply(seq_len(k), function(i) sprintf(" OR v%1$d IS DISTINCT FROM lag(v%1$d) OVER o", i), ""), collapse = ""),
    .og_or(t_s, "CAST(NULL AS DOUBLE)"),
    paste(vapply(seq_len(k), function(i) sprintf("any_value(v%d) AS %s, ", i, names[i]), ""), collapse = ""),
    count, t_names[1], t_names[2],
    sec("t"), sec("lag(t) OVER o"), sec("lead(t) OVER o"), txt("min(t)"), txt("max(t)")
  )
}

# A layer's rows for a click: the columns `cols` of row `n` of the numbered table `nm` (or every row, `n = NULL`, for a
# bundle), each with its kind for the page: a number, a whole number, a logical, a date, a time or a text
.og_row_reader <- function(con, nm, cols, meta = list()) {
  q <- function(v) as.character(DBI::dbQuoteIdentifier(con, v))
  sel <- paste(vapply(cols, q, ""), collapse = ", ")
  function(n = NULL) {
    d <- DBI::dbGetQuery(con, sprintf(
      "SELECT og_row, %s FROM %s %s ORDER BY og_row", sel, nm,
      if (is.null(n)) "" else sprintf("WHERE og_row = %d", as.integer(n))
    ))
    kinds <- vapply(cols, function(cc) {
      v <- d[[cc]]
      if (inherits(v, "POSIXct")) "time" else if (inherits(v, "Date")) "date" else if (is.logical(v)) "logical"
      else if (is.integer(v)) "integer" else if (is.numeric(v)) "number" else "text"
    }, "")
    for (cc in cols) {
      if (inherits(d[[cc]], "POSIXct")) d[[cc]] <- format(d[[cc]], "%Y-%m-%d %H:%M:%S", tz = "UTC")
      else if (inherits(d[[cc]], "Date")) d[[cc]] <- format(d[[cc]])
      else if (is.factor(d[[cc]])) d[[cc]] <- as.character(d[[cc]])
      else if (is.list(d[[cc]])) d[[cc]] <- NA # a blob or a shape: not a value to read
    }
    list(cols = unname(Map(function(cc, k) {
      m <- .og_or(meta[[cc]], list())
      Filter(Negate(is.null), list(name = cc, type = k, label = m$label, unit = m$unit, description = m$description,
                                   codes = if (length(m$codes)) as.list(m$codes)))
    }, cols, kinds)), rows = d)
  }
}

# A row as the page reads it: its columns, each a name, a kind and a value (null where missing)
.og_row_json <- function(r) {
  if (!nrow(r$rows)) {
    return(NULL)
  }
  list(columns = lapply(seq_along(r$cols), function(i) {
    cc <- r$cols[[i]]
    v <- r$rows[[cc$name]][1]
    code <- if (!is.null(cc$codes) && !is.na(v)) cc$codes[[as.character(v)]]
    Filter(Negate(is.null), list(
      name = cc$name, type = cc$type, value = if (is.na(v)) NULL else v, label = cc$label, unit = cc$unit,
      description = cc$description, code = code
    ))
  }))
}

# What the data say of their columns, as a list by column of `label`, `unit`, `description` and `codes` (a named
# character vector, code to label). From a data frame's column attributes (`label`, as haven and labelled set it;
# `units`, a text):
.og_dict_attributes <- function(d) {
  out <- list()
  for (cc in names(d)) {
    a <- attributes(d[[cc]])
    lab <- if (is.character(a$label) && length(a$label) == 1) a$label
    un <- if (is.character(a$units) && length(a$units) == 1) a$units
    if (!is.null(lab) || !is.null(un)) out[[cc]] <- Filter(Negate(is.null), list(label = lab, unit = un))
  }
  out
}

# ... and from a parquet file's own dictionary: an entry of data-dict.tidyverse.org's format stored in the file's
# metadata under a key ending `data_dict` (as ogis's examples hold it), for each file the query reads
.og_dict_parquet <- function(con, src) {
  paths <- regmatches(src, gregexpr("read_parquet\\('([^']+)'", src))[[1]]
  paths <- unique(sub("^read_parquet\\('", "", sub("'$", "", paths)))
  if (!length(paths) || !requireNamespace("yaml", quietly = TRUE)) {
    return(list())
  }
  out <- list()
  for (p in paths) {
    kv <- tryCatch(DBI::dbGetQuery(con, sprintf(
      "SELECT decode(value) AS v FROM parquet_kv_metadata(%s) WHERE decode(key) LIKE '%%data_dict' LIMIT 1",
      DBI::dbQuoteString(con, p)
    ))$v, error = function(e) character())
    if (!length(kv)) next
    entry <- tryCatch(.og_yaml(enc2utf8(kv[1])), error = function(e) NULL)
    for (c in entry$columns) {
      if (is.null(c$name) || !is.null(out[[c$name]])) next
      codes <- if (is.list(c$values) && !is.null(names(c$values))) unlist(c$values)
      out[[c$name]] <- Filter(Negate(is.null), list(
        label = c$label, unit = c$units, description = if (!is.null(c$description)) trimws(c$description), type = c$type,
        codes = if (length(codes)) stats::setNames(as.character(codes), names(codes))
      ))
    }
  }
  out
}

# A dictionary's YAML read, YAML 1.1's yes, no, on, off, y and n kept as written, not made TRUE and FALSE: a column
# may be called n
.og_yaml <- function(text) {
  as_written <- function(x) x
  yaml::yaml.load(text, handlers = list("bool#yes" = as_written, "bool#no" = as_written))
}

# Two dictionaries as one, the first's entries winning, field by field
.og_dict_merge <- function(a, b) {
  for (cc in names(b)) a[[cc]] <- utils::modifyList(b[[cc]], .og_or(a[[cc]], list()))
  a
}

# A layer's columns as its popup shows them: the call's `labels` (column = label) and `codes` (column = a named vector,
# code to label, or a table of code and label) over the data's dictionary
.og_popup_meta <- function(cols, dict, labels = NULL, codes = NULL) {
  if (!is.null(labels) && (!is.character(labels) || is.null(names(labels)))) {
    stop("`labels` is a named character vector, a column's name to its label: c(speed = \"Speed (knots)\").", call. = FALSE)
  }
  if (!is.null(codes) && (!is.list(codes) || is.null(names(codes)))) {
    stop("`codes` is a named list, a column's name to its codes: a named vector (code = label) or a table of code and label.", call. = FALSE)
  }
  lapply(stats::setNames(cols, cols), function(cc) {
    m <- .og_or(dict[[cc]], list())
    if (cc %in% names(labels)) {
      m$label <- labels[[cc]]
      m$unit <- NULL # the call's label says it all
    }
    cd <- if (cc %in% names(codes)) codes[[cc]]
    if (is.data.frame(cd)) {
      if (ncol(cd) < 2) stop(sprintf("`codes$%s`: a table of two columns, the code and its label.", cc), call. = FALSE)
      cd <- stats::setNames(as.character(cd[[2]]), as.character(cd[[1]]))
    }
    if (!is.null(cd)) m$codes <- stats::setNames(as.character(cd), names(cd))
    m
  })
}
