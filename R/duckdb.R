# duckdb.R — ogis's own DuckDB connection, the helpers that register a call's data frames and release them,
# and the extensions it loads. Copied from ramb (R/connection.R, R/trip.R) on 2026-11-10 when the map viewer moved
# ramb keeps its own for its flow.

.og_db <- new.env(parent = emptyenv())

.og_connection <- function() {
  con <- .og_db$con
  if (!is.null(con) && DBI::dbIsValid(con)) {
    return(con)
  }
  # duckdb's notice of where it keeps its extensions said once: kept out of a document's maps and the console
  con <- suppressMessages(DBI::dbConnect(duckdb::duckdb()))
  DBI::dbExecute(con, sprintf("SET memory_limit = '%s'", .og_memory_limit(con)))
  .og_db$con <- con
  con
}

.og_disconnect <- function() {
  con <- .og_db$con
  .og_db$con <- NULL
  if (!is.null(con) && DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con, shutdown = TRUE)
  }
  invisible()
}

.onUnload <- function(libpath) .og_disconnect()

# The memory ogis's instance may use: options(ogis.memory_limit), a DuckDB size such as "8GB", else a quarter of the
# machine's memory. DuckDB gives every in-memory instance 80 % of it by default, knowing nothing of the others in the
# session (duckdbfs's, the caller's), and takes no percentage, so the quarter is 5/16 of that default.
.og_memory_limit <- function(con) {
  limit <- getOption("ogis.memory_limit")
  if (!is.null(limit)) {
    return(limit)
  }
  default <- DBI::dbGetQuery(
    con,
    "SELECT current_setting('memory_limit') AS v"
  )$v
  bytes <- .og_parse_size(default)
  if (is.na(bytes)) {
    return(default)
  }
  sprintf("%.0fMiB", bytes * 5 / 16 / 2^20)
}

# A DuckDB size ("19.1 GiB", "8GB", "512 MiB") in bytes; NA if it is not one.
.og_parse_size <- function(x) {
  m <- regmatches(x, regexec("^\\s*([0-9.]+)\\s*([KMGT]i?B|bytes)?\\s*$", x))[[
    1
  ]]
  if (length(m) == 0) {
    return(NA_real_)
  }
  unit <- c(
    KiB = 2^10,
    MiB = 2^20,
    GiB = 2^30,
    TiB = 2^40,
    KB = 1e3,
    MB = 1e6,
    GB = 1e9,
    TB = 1e12,
    bytes = 1
  )
  as.numeric(m[2]) * if (m[3] == "") 1 else unit[[m[3]]]
}

# Load a DuckDB extension on `con`, installing it first if it is not there. Without access to DuckDB's repository
# there are three ways in, each tested on 2026-10-27: a file copied into the extension folder counts as installed;
# options(ogis.extension_repository) names a folder or URL laid out as DuckDB's, installed from with INSTALL ... FROM,
# which leaves the connection's settings as they were (SET custom_extension_repository would not, on a caller's
# connection); and DuckDB's downloads go through the web proxy in HTTP_PROXY. ogis loads core extensions only
# (spatial, httpfs): DuckDB 2.0 loads a copied community extension only with the .info file its install writes beside it.
.og_extension <- function(con, name) {
  load <- function() {
    !inherits(
      try(DBI::dbExecute(con, sprintf("LOAD %s", name)), silent = TRUE),
      "try-error"
    )
  }
  if (load()) {
    return(invisible(TRUE))
  }
  repo <- getOption("ogis.extension_repository")
  sql <- if (is.null(repo)) {
    sprintf("INSTALL %s", name)
  } else {
    sprintf("INSTALL %s FROM %s", name, DBI::dbQuoteString(con, repo))
  }
  got <- try(DBI::dbExecute(con, sql), silent = TRUE)
  if (!inherits(got, "try-error") && load()) {
    return(invisible(TRUE))
  }
  version <- DBI::dbGetQuery(con, "SELECT version() AS v")$v
  platform <- DBI::dbGetQuery(con, "PRAGMA platform")$platform
  dir <- DBI::dbGetQuery(
    con,
    "SELECT current_setting('extension_directory') AS v"
  )$v
  why <- if (inherits(got, "try-error")) {
    conditionMessage(attr(got, "condition"))
  } else {
    "It installed but did not load."
  }
  rlang::abort(
    c(
      sprintf(
        "DuckDB's `%s` extension could not be installed and loaded.",
        name
      ),
      x = strsplit(why, "\n")[[1]][1],
      i = "Without access to DuckDB's extension repository, any one of these works:",
      "*" = sprintf(
        "Download http://extensions.duckdb.org/%s/%s/%s.duckdb_extension.gz on another machine, unpack it and copy it into %s.",
        version,
        platform,
        name,
        file.path(dir, version, platform)
      ),
      "*" = "Set the environment variable HTTP_PROXY to your network's web proxy, if it has one.",
      "*" = sprintf(
        "Set options(ogis.extension_repository = <folder or URL>), laid out as <repository>/%s/%s/%s.duckdb_extension.",
        version,
        platform,
        name
      )
    ),
    call = NULL
  )
}

.og_con_for <- function(x, ...) {
  # the connection of the lazy inputs, which must share one; a data frame is registered in it
  lazy <- Filter(function(t) inherits(t, "tbl_lazy"), list(x, ...))
  if (length(lazy) == 0) {
    return(.og_connection())
  }
  cons <- lapply(lazy, dbplyr::remote_con)
  if (!all(vapply(cons, identical, logical(1), cons[[1]]))) {
    stop(
      "The lazy tables are on different DuckDB connections; open them on one (og_example() takes `con`).",
      call. = FALSE
    )
  }
  cons[[1]]
}

# A name for a table on `con`, numbered, not drawn from R's random numbers: a draw moves the caller's random
# stream (the maintainer's rule, 2026-10-27), and names drawn after set.seed() repeat. A name the connection
# already has (after the package is loaded again) is skipped.
.og_names <- new.env(parent = emptyenv())

.og_names$n <- 0L

.og_name <- function(con, prefix) {
  repeat {
    .og_names$n <- .og_names$n + 1L
    nm <- paste0(prefix, .og_names$n)
    if (!DBI::dbExistsTable(con, nm)) {
      return(nm)
    }
  }
}

# Data frames registered for one call, and the temporary tables it makes (.og_temp_table()), belong to that call
# (the maintainer's rule, 2026-10-27: a function leaves the caller's session as it found it, on error too). A
# function that registers calls .og_scope() first: when it exits, by return or by error, what it made is released,
# unless it handed it to its lazy result with .og_hold(), which then reads it for the rest of the session. A
# release never touches what an earlier call made, so a lazy result made before stays readable. Registered frames
# left behind in a loop accumulate.
.og_reg <- new.env(parent = emptyenv())

.og_tmp <- new.env(parent = emptyenv())

.og_scopes <- new.env(parent = emptyenv())

.og_scopes$stack <- list()

.og_register <- function(con, x, prefix = "og_in_") {
  nm <- .og_name(con, prefix)
  x <- as.data.frame(x)
  # a date-time or date stored as integer (seq() makes them) registers as INTEGER, not as a time
  for (k in names(x)) {
    if (inherits(x[[k]], c("POSIXct", "Date")) && is.integer(x[[k]])) {
      storage.mode(x[[k]]) <- "double"
    }
  }
  duckdb::duckdb_register(con, nm, x)
  assign(nm, con, envir = .og_reg)
  nm
}

.og_made <- function() c(ls(.og_reg), ls(.og_tmp))

# Open a scope in the calling function's frame; closed by an on.exit() placed there.
.og_scope <- function(env = parent.frame()) {
  before <- .og_made()
  .og_scopes$stack <- c(.og_scopes$stack, list(before))
  do.call(
    base::on.exit,
    list(substitute(.og_close_scope(b), list(b = before)), add = TRUE),
    envir = env
  )
  invisible()
}

.og_close_scope <- function(before) {
  .og_release_since(before)
  n <- length(.og_scopes$stack)
  if (n > 0) {
    .og_scopes$stack <- .og_scopes$stack[-n]
  }
}

# What the innermost open scope has made so far (everything, outside a scope).
.og_own <- function() {
  n <- length(.og_scopes$stack)
  setdiff(.og_made(), if (n > 0) .og_scopes$stack[[n]])
}

# Release the frames and drop the temporary tables made since `before`.
.og_release_since <- function(before) {
  for (nm in setdiff(ls(.og_reg), before)) {
    try(duckdb::duckdb_unregister(get(nm, envir = .og_reg), nm), silent = TRUE)
    rm(list = nm, envir = .og_reg)
  }
  for (nm in setdiff(ls(.og_tmp), before)) {
    try(
      DBI::dbExecute(
        get(nm, envir = .og_tmp),
        sprintf("DROP TABLE IF EXISTS %s", nm)
      ),
      silent = TRUE
    )
    rm(list = nm, envir = .og_tmp)
  }
}

# Release what the current call has made, once it has collected its result.
.og_unregister <- function(con) {
  .og_release_since(setdiff(.og_made(), .og_own()))
}

# Hand what the current call has made to its lazy result `out`: kept for the session, never released.
.og_hold <- function(out) {
  # forced first: `out` may register the very table it reads
  force(out)
  own <- .og_own()
  rm(list = intersect(own, ls(.og_reg)), envir = .og_reg)
  rm(list = intersect(own, ls(.og_tmp)), envir = .og_tmp)
  out
}

# A query materialised once as a temporary table, where a function reads it twice and both reads must agree.
# Dropped with the registered frames when the function collects its result; kept while a lazy result needs it.
.og_temp_table <- function(con, sql, keep = FALSE) {
  nm <- .og_name(con, "og_tmp_")
  DBI::dbExecute(con, sprintf("CREATE TEMP TABLE %s AS %s", nm, sql))
  if (!keep) {
    assign(nm, con, envir = .og_tmp)
  }
  nm
}

.og_as_lazy <- function(x, con) {
  if (inherits(x, "tbl_lazy")) {
    return(x)
  }
  dplyr::tbl(con, .og_register(con, x))
}

.og_sql <- function(x) as.character(dbplyr::sql_render(dplyr::ungroup(x)))

# A Suggests package, checked where a function needs it.
.og_need <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      sprintf(
        "This function needs the package '%s'. Install it with install.packages(\"%s\").",
        pkg,
        pkg
      ),
      call. = FALSE
    )
  }
}

