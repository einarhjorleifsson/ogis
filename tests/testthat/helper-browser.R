# Browser checks: a page opened in headless Chrome (chromote), skipped where there is none, and on CRAN
skip_if_no_chrome <- function() {
  skip_on_cran()
  skip_if_not_installed("chromote")
  chrome <- tryCatch(chromote::find_chrome(), error = function(e) NULL)
  skip_if(is.null(chrome) || !nzchar(chrome) || !file.exists(chrome), "no Chrome for chromote")
}

# A folder served on 127.0.0.1 by httpuv's own thread (so R may wait meanwhile), stopped when the test ends
serve_dir <- function(dir, env = parent.frame()) {
  port <- httpuv::randomPort()
  s <- httpuv::startServer("127.0.0.1", port, list(staticPaths = list("/" = httpuv::staticPath(dir, indexhtml = TRUE))))
  withr::defer(s$stop(), envir = env)
  sprintf("http://127.0.0.1:%d/", port)
}

# A page opened in a new headless Chrome tab, closed when the test ends; returns the session
open_page <- function(url, width = 1100, height = 900, env = parent.frame()) {
  # Chrome may take more than chromote's 10 s to start on a busy machine or runner; one that does not start at all is
  # the machine's, not the page's: skipped with the reason
  withr::local_options(chromote.timeout = 60)
  b <- tryCatch(chromote::ChromoteSession$new(width = width, height = height),
                error = function(e) testthat::skip(paste("Chrome did not start:", conditionMessage(e))))
  withr::defer(b$close(), envir = env)
  # navigated without chromote's own wait, which turns a private event loop: a map served by this R (rr_serve())
  # answers only in the global one, which wait_until() turns
  promises::catch(b$Page$navigate(url, wait_ = FALSE), function(e) NULL) # its answer may come after the page
  if (!wait_until(function() identical(page_eval(b, "location.href !== 'about:blank' && document.readyState"), "complete"), 60)) {
    stop("The page did not load: ", url, call. = FALSE)
  }
  b
}

# A JavaScript expression's value in the page (JSON-able), or an error with the page's message
page_eval <- function(b, js) {
  r <- b$Runtime$evaluate(js, returnByValue = TRUE, awaitPromise = TRUE)
  if (!is.null(r$exceptionDetails)) stop(r$exceptionDetails$exception$description %||% r$exceptionDetails$text, call. = FALSE)
  r$result$value
}

# Waits until `f()` is TRUE, at most `seconds`; returns whether it came
wait_until <- function(f, seconds = 30) {
  t0 <- Sys.time()
  while (as.numeric(Sys.time() - t0, units = "secs") < seconds) {
    if (isTRUE(tryCatch(f(), error = function(e) FALSE))) return(TRUE)
    later::run_now(0.25) # a map served by this R (rr_serve()) answers meanwhile
  }
  FALSE
}
