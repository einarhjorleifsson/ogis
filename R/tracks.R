# tracks.R — vessel tracks as one layer function: og_tracks() draws pings (ramb's columns, or upper-case ones) as
# a track and its pings, a time panel of speed under the map (a vessel, then a trip), and the fishing effort by cell,
# which follows the vessel chosen there. A quick look at each step of a track's processing: trips, fishing, gear,
# effort. Built on og_path(), og_point(), og_time() and og_cells().

#' Vessel tracks: the track, a time panel of speed, trips, and the effort by cell
#'
#' `og_tracks()` draws vessel tracks, a row a ping, for a look at what a track's processing made of them: a time panel
#' under the map with a vessel's speed over time and lanes of what it was doing and of its trips (a vessel chosen
#' there, then one of its trips), the map showing the path and pings of the window shown on the chart, the pings
#' coloured by speed in Inferno, black the slowest, or by what the vessel was doing (in the lane's colours), and slow
#' or fast pings on top (*On top*); and the fishing effort by cell, summed from the fishing pings' hours, showing the
#' chosen vessel's, its gear's or the fleet's ([og_cells()]'s `follow`).
#'
#' The columns are found by their names: ramb's (`vid`, `time`, `lon`, `lat`, `speed`, `voyage_key` or `trip_id`,
#' `gear`, `hours`, and `behaviour` or `activity`) or upper-case ones (`VESSEL_ID`, `DATE_TIME`, `LONGITUDE`, `LATITUDE`, `SPEED`,
#' `TRIP_ID`, `ACTIVITY`, `GEAR`), or given.
#'
#' @param map A map the pipe makes ([og_map()]), or the pings, which start one.
#' @param pings The pings: a data frame, a lazy DuckDB table, or a parquet file's path; given here with no map, they
#'   start one, as in the map's place.
#' @param vessel,time,lon,lat,speed,activity,trip,gear,hours The columns, as strings, where their names are not found:
#'   the vessel, the time, the position, the speed (more than one: the first shown, the others ticked on in the panel;
#'   the first the pings' colour), what the vessel was doing (a lane, and the pings' other colour), its trip (chosen in the panel, a trip at a time), its
#'   gear, and the hours each ping stands for (the effort's).
#' @param lanes More lanes under the panel's chart, columns as strings (`c(observed = "ACTIVITY_L1")`): another
#'   method's trips, an observer's activity, ...
#' @param marks Columns that mark pings, as [og_time()]'s `marks`.
#' @param compare Two columns to hold against each other, as strings, named for their sources (`c(ramb = "trip_id",
#'   other = "TRIP_ID")`), or a list of such pairs: two methods' trips, an inferred activity against an observer's.
#'   Each is a lane, and the panel marks, each a row of its own, the pings that one has and the other has not (in a
#'   trip by one method alone), and, where the two share their values (`"fishing"` in both), the pings they give
#'   differently.
#' @param fishing The values of `activity` that are fishing, for the effort: by default those beginning "fish" (any
#'   case), or `TRUE` in a logical column.
#' @param effort The effort by cell: `TRUE`, summed from the fishing pings' `hours` by vessel, gear and year at `cell`
#'   degrees; `FALSE`, none; or a table of cells for [og_cells()].
#' @param cell The cells' side in degrees, when the effort is summed here.
#' @param time_label The clock the times are on, shown beside them in the panel ("UTC" by default; "as written" for a
#'   file whose zone is not known).
#' @param title The page's title.
#' @param ... More for [og_cells()]: `palette`, `sizes`, `follow`, ...
#' @return The map.
#' @seealso [og_time()], [og_cells()]; ramb, which makes trips, fishing and hours of a track.
#' @export
#' @examples
#' \donttest{
#' # the Danish small-scale vessels' tracks, as they come: behaviour, gear, no trips or hours
#' og_example("dansk") |>
#'   dplyr::filter(vessel_id %in% c("EX_1", "EX_12")) |>
#'   og_tracks(effort = FALSE)
#' }
og_tracks <- function(
  map = NULL, pings = NULL,
  vessel = NULL, time = NULL, lon = NULL, lat = NULL, speed = NULL, activity = NULL, trip = NULL, gear = NULL,
  hours = NULL, lanes = NULL, marks = NULL, compare = NULL, fishing = NULL, effort = TRUE, cell = 0.01, time_label = "UTC",
  title = "Tracks", ...
) {
  if (!inherits(map, "og_map")) {
    # the pings as the first argument, or by name with no map; anything else in the map's place is refused
    if (!is.null(map) && !is.null(pings)) {
      stop("og_tracks(): `map` is an og_map(); the pings go to `pings`.", call. = FALSE)
    }
    if (is.null(pings)) pings <- map
    map <- NULL
  }
  if (is.character(pings) && length(pings) == 1) pings <- .og_data(pings)
  if (!is.data.frame(pings) && !inherits(pings, "tbl_lazy")) {
    stop("og_tracks(): the pings are a data frame, a lazy table or a parquet file's path.", call. = FALSE)
  }
  cols <- colnames(pings)
  find <- function(given, usual, what, need = TRUE) {
    if (!is.null(given)) {
      if (!is.character(given) || !all(given %in% cols)) {
        stop(sprintf("og_tracks(): `%s` names columns of the pings: %s.", what, paste(setdiff(given, cols), collapse = ", ")),
             call. = FALSE)
      }
      return(given)
    }
    hit <- intersect(usual, cols)[1]
    if (is.na(hit)) {
      if (need) stop(sprintf("og_tracks(): the pings have no %s: give its column, `%s`.", what, what), call. = FALSE)
      return(NULL)
    }
    hit
  }
  vessel <- find(vessel, c("vid", "vessel_id", "VESSEL_ID", "vessel", "mmsi"), "vessel")
  time <- find(time, c("time", "time_stamp", "DATE_TIME", "timestamp"), "time")
  lon <- find(lon, c("lon", "LONGITUDE", "longitude"), "lon")
  lat <- find(lat, c("lat", "LATITUDE", "latitude"), "lat")
  speed <- find(speed, c("speed", "SPEED", "speed_kn"), "speed")
  activity <- find(activity, c("behaviour", "activity", "ACTIVITY", "fishing", "state"), "activity", need = FALSE)
  trip <- find(trip, c("voyage_key", "trip_key", "trip_id", "TRIP_ID", "trip"), "trip", need = FALSE)
  gear <- find(gear, c("gear", "GEAR", "gid", "gear_code"), "gear", need = FALSE)
  hours <- find(hours, c("hours", "HOURS"), "hours", need = FALSE)
  if (!is.null(lanes) && (!is.character(lanes) || !all(lanes %in% cols))) {
    stop("og_tracks(): `lanes` names columns of the pings, as strings.", call. = FALSE)
  }
  if (!is.numeric(cell) || length(cell) != 1 || is.na(cell) || cell <= 0) {
    stop("og_tracks(): `cell` is the cells' side in degrees, above 0.", call. = FALSE)
  }

  # the pings with the names the layer functions look for, a trip known by its vessel too where its key is not its
  # own (a vessel's trips numbered from 1): ramb's `voyage_key` ("EX_1:2018:1") carries its vessel and year
  sym <- rlang::sym
  x <- dplyr::rename(pings, vid = !!sym(vessel), time = !!sym(time), lon = !!sym(lon), lat = !!sym(lat))
  if (!is.null(trip)) {
    own <- trip %in% c("voyage_key", "trip_key")
    x <- dplyr::mutate(x, og_trip = dplyr::if_else(
      is.na(!!sym(trip)), NA_character_,
      !!(if (own) rlang::expr(as.character(!!sym(trip))) else rlang::expr(paste(as.character(!!sym("vid")), as.character(!!sym(trip)))))
    ))
  }
  # where two columns disagree (two methods' trips, an inferred activity against an observer's): a row of marks for
  # the pings one has and the other has not, and, where the two share their values, for those they give differently
  cmp_marks <- character()
  cmp_lanes <- character()
  pairs <- if (is.null(compare)) list() else if (is.list(compare)) compare else list(compare)
  for (i in seq_along(pairs)) {
    pr <- pairs[[i]]
    if (!is.character(pr) || length(pr) != 2 || !all(pr %in% colnames(x))) {
      stop("og_tracks(): `compare` is two columns of the pings, as strings (`c(ramb = \"trip_id\", other = \"TRIP_ID\")`), or a list of such pairs.",
           call. = FALSE)
    }
    lab <- if (!is.null(names(pr)) && all(nzchar(names(pr)))) names(pr) else unname(pr)
    a <- sym(pr[1])
    b <- sym(pr[2])
    vals <- function(cn) stats::na.omit(as.character(dplyr::pull(dplyr::distinct(dplyr::select(x, dplyr::all_of(cn))))))
    shared <- length(intersect(vals(pr[1]), vals(pr[2]))) > 0
    k <- paste0("og_cmp", i, c("a", "b", "d"))
    x <- dplyr::mutate(x, !!!stats::setNames(list(
      rlang::expr(dplyr::if_else(!is.na(!!a) & is.na(!!b), "only", NA_character_)),
      rlang::expr(dplyr::if_else(is.na(!!a) & !is.na(!!b), "only", NA_character_)),
      if (shared) {
        rlang::expr(dplyr::if_else(!is.na(!!a) & !is.na(!!b) & as.character(!!a) != as.character(!!b), "differs",
                                   NA_character_))
      } else {
        NA_character_
      }
    ), k))
    keep <- if (is.data.frame(x)) vapply(k, function(cn) any(!is.na(x[[cn]])), NA) else c(TRUE, TRUE, shared)
    cmp_marks <- c(cmp_marks, stats::setNames(k, c(paste(lab[1], "only"), paste(lab[2], "only"),
                                                   paste(lab[1], "\u2260", lab[2])))[keep])
    cmp_lanes <- c(cmp_lanes, stats::setNames(pr, lab)[!pr %in% c(activity, trip, lanes)])
  }
  marks <- c(if (!is.null(marks)) if (is.null(names(marks))) stats::setNames(marks, marks) else marks, cmp_marks)
  if (!length(marks)) marks <- NULL
  popup <- unique(c("vid", "time", speed, activity, trip, gear, unlist(pairs)))
  # the time panel first: it draws the chosen vessel's span (its path) itself, and the pings added after it carry its
  # vessel, so they show that vessel and span alone, on the path; the panel's own points would be the same rows. A path
  # of each vessel's whole series, as a layer of its own, ran over every span's ends and was drawn whole: on a year of a
  # vessel, a tangle over the trip chosen
  ln <- c(if (!is.null(activity)) stats::setNames(activity, activity), if (!is.null(trip)) c(trip = "og_trip"),
          if (!is.null(lanes)) if (is.null(names(lanes))) stats::setNames(lanes, lanes) else lanes, cmp_lanes)
  panel <- function(m, data = NULL) {
    og_time(m, col = !!speed, lanes = if (length(ln)) as.list(ln), marks = !!marks, data = data,
            time = "time", by = !!sym("vid"),
            span = if (!is.null(trip)) c(trip = "og_trip"), time_label = time_label, title = title,
            dots = FALSE)
  }
  m <- if (is.null(map)) panel(x) else panel(map, x)

  # the effort by cell: the fishing pings' hours, by vessel, gear and year
  if (is.data.frame(effort) || inherits(effort, "tbl_lazy") || (is.character(effort) && length(effort) == 1)) {
    m <- og_cells(m, effort, name = "Fishing effort", ...)
  } else if (isTRUE(effort)) {
    if (is.null(hours) || is.null(activity)) {
      stop("og_tracks(): the effort is summed from the fishing pings' hours: the pings need `activity` and `hours` (ramb's rb_add_effort() gives them), or `effort = FALSE`.",
           call. = FALSE)
    }
    is_fishing <- if (!is.null(fishing)) {
      rlang::expr(!!sym(activity) %in% !!fishing)
    } else {
      rlang::expr(grepl("^fish", tolower(as.character(!!sym(activity)))))
    }
    if (inherits(x, "tbl_lazy")) x_eff <- dplyr::collect(x) else x_eff <- x
    v <- x_eff[[activity]]
    keep <- if (is.logical(v) && is.null(fishing)) v %in% TRUE else rlang::eval_tidy(is_fishing, x_eff)
    steps <- round(cell / 0.001)
    e <- x_eff[keep & !is.na(x_eff[[hours]]) & !is.na(x_eff$lon) & !is.na(x_eff$lat), , drop = FALSE]
    cells <- data.frame(
      ix = floor(e$lon / cell) * steps, iy = floor(e$lat / cell) * steps, vid = as.character(e$vid),
      gear = if (!is.null(gear)) dplyr::coalesce(as.character(e[[gear]]), "unknown") else "all",
      year = as.integer(format(e$time, "%Y")), hours = as.numeric(e[[hours]]), stringsAsFactors = FALSE
    )
    if (is.null(gear)) cells$gear <- NULL
    if (!nrow(cells)) {
      message("og_tracks(): no fishing pings with hours: no effort drawn.")
    } else {
      cells <- dplyr::summarise(dplyr::group_by(cells, dplyr::across(-"hours")), hours = sum(hours), n = dplyr::n(),
                                .groups = "drop")
      m <- og_cells(m, cells, name = "Fishing effort", labels = c(vid = "Vessel", gear = "Gear", year = "Years",
                                                                  hours = "Hours", n = "Pings"), ...)
    }
  } else if (!isFALSE(effort)) {
    stop("og_tracks(): `effort` is TRUE, FALSE or a table of cells.", call. = FALSE)
  }

  # the pings coloured by speed in Inferno, black the slowest (the maintainer, 2026-11-22: "the device speed should be
  # the default colour of pings", "I mean inferno"), or by what the vessel was doing, chosen in the page: the activity
  # lane takes those colours
  og_point(m, data = if (!is.null(map)) x,
           colour = !!(if (!is.null(activity)) rlang::expr(c(!!sym(speed[1]), !!sym(activity))) else sym(speed[1])),
           palette = stats::setNames(list("inferno"), speed[1]), popup = !!popup, name = "Pings")
}
