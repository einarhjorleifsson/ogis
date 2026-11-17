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
  b <- chromote::ChromoteSession$new(width = width, height = height)
  withr::defer(b$close(), envir = env)
  loaded <- b$Page$loadEventFired(wait_ = FALSE)
  b$Page$navigate(url, wait_ = FALSE)
  b$wait_for(loaded)
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
    Sys.sleep(0.25)
  }
  FALSE
}
