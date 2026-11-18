# tracks.R — vessel tracks as one layer function: og_tracks() draws pings (ramb's columns, or EM4SSF's D2.1 format's) as
# a track and its pings, a time panel of speed under the map (a vessel, then a trip), and the fishing effort by cell,
# which follows the vessel chosen there. A quick look at each step of a track's processing: trips, fishing, gear,
# effort. Built on og_path(), og_point(), og_time() and og_cells().

#' Vessel tracks: the track, a time panel of speed, trips, and the effort by cell
#'
#' `og_tracks()` draws vessel tracks, a row a ping, for a look at what a track's processing made of them: each
#' vessel's track and pings (coloured by what the vessel was doing), a time panel under the map with its speed over
#' time and lanes of what it was doing and of its trips (a vessel chosen there, then one of its trips, the map
#' following), and the fishing effort by cell, summed from the fishing pings' hours, showing the chosen vessel's, its
#' gear's or the fleet's ([og_cells()]'s `follow`).
#'
#' The columns are found by their names: ramb's (`vid`, `time`, `lon`, `lat`, `speed`, `trip_id`, `gear`, `hours`, and
#' `behaviour` or `activity`) or EM4SSF's D2.1 format's (`VESSEL_ID`, `DATE_TIME`, `LONGITUDE`, `LATITUDE`, `SPEED`,
#' `TRIP_ID`, `ACTIVITY`, `GEAR`), or given.
#'
#' @param map A map the pipe makes ([og_map()]), or the pings, which start one.
#' @param pings The pings: a data frame, a lazy DuckDB table, or a parquet file's path.
#' @param vessel,time,lon,lat,speed,activity,trip,gear,hours The columns, as strings, where their names are not found:
#'   the vessel, the time, the position, the speed (more than one: the first shown, the others ticked on in the panel),
#'   what the vessel was doing (a lane, and the pings' colour), its trip (chosen in the panel, a trip at a time), its
#'   gear, and the hours each ping stands for (the effort's).
#' @param lanes More lanes under the panel's chart, columns as strings (`c(observed = "ACTIVITY_L1")`): another
#'   method's trips, an observer's activity, ...
#' @param marks Columns that mark pings, as [og_time()]'s `marks`.
#' @param fishing The values of `activity` that are fishing, for the effort: by default those beginning "fish" (any
#'   case), or `TRUE` in a logical column.
#' @param effort The effort by cell: `TRUE`, summed from the fishing pings' `hours` by vessel, gear and year at `cell`
#'   degrees; `FALSE`, none; or a table of cells for [og_cells()].
#' @param cell The cells' side in degrees, when the effort is summed here.
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
  hours = NULL, lanes = NULL, marks = NULL, fishing = NULL, effort = TRUE, cell = 0.01, title = "Tracks", ...
) {
  if (!inherits(map, "og_map")) {
    if (!is.null(pings)) stop("og_tracks(): `map` is an og_map(); the pings go to `pings`.", call. = FALSE)
    pings <- map
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
  trip <- find(trip, c("trip_key", "trip_id", "TRIP_ID", "trip"), "trip", need = FALSE)
  gear <- find(gear, c("gear", "GEAR", "gid", "gear_code"), "gear", need = FALSE)
  hours <- find(hours, c("hours", "HOURS"), "hours", need = FALSE)
  if (!is.null(lanes) && (!is.character(lanes) || !all(lanes %in% cols))) {
    stop("og_tracks(): `lanes` names columns of the pings, as strings.", call. = FALSE)
  }
  if (!is.numeric(cell) || length(cell) != 1 || is.na(cell) || cell <= 0) {
    stop("og_tracks(): `cell` is the cells' side in degrees, above 0.", call. = FALSE)
  }

  # the pings with the names the layer functions look for, a trip known by its vessel too (a vessel's trips are
  # numbered from 1)
  sym <- rlang::sym
  x <- dplyr::rename(pings, vid = !!sym(vessel), time = !!sym(time), lon = !!sym(lon), lat = !!sym(lat))
  if (!is.null(trip)) {
    x <- dplyr::mutate(x, og_trip = dplyr::if_else(is.na(!!sym(trip)), NA_character_,
                                                    paste(as.character(!!sym("vid")), as.character(!!sym(trip)))))
  }
  popup <- unique(c("vid", "time", speed, activity, trip, gear))
  m <- if (is.null(map)) og_map(x, title = title) else map

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

  m <- og_path(m, group = !!sym("vid"), time = !!sym("time"), name = "Track")
  m <- og_point(m, colour = !!(if (!is.null(activity)) sym(activity) else sym(speed[1])),
                popup = !!popup, name = "Pings")
  ln <- c(if (!is.null(activity)) stats::setNames(activity, activity), if (!is.null(trip)) c(trip = "og_trip"),
          if (!is.null(lanes)) if (is.null(names(lanes))) stats::setNames(lanes, lanes) else lanes)
  og_time(m, col = !!speed, lanes = if (length(ln)) as.list(ln), marks = !!marks,
          span = if (!is.null(trip)) c(trip = "og_trip"))
}
