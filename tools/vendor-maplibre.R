# tools/vendor-maplibre.R — MapLibre GL JS into inst/engine/vendor, as classic scripts (plan 077 in fishycode)
#
# Run by hand from the package's folder, at each MapLibre update (a pinned version, never the latest by itself):
#   Rscript tools/vendor-maplibre.R 6.19.0
#
# MapLibre 6 is published only as ES modules, which a page opened from its folder (file://) cannot load, and ogis's
# bundles open by a double click. So the package's npm tarball is downloaded, checked against the registry's SHA-512,
# and its two modules are made classic scripts:
#   maplibre-gl.js         dist/maplibre-gl.mjs wrapped in a function: `import.meta.url` is the script's own address,
#                          the closing `export {...}` the global `maplibregl`; the worker given to MapLibre from the next
#   maplibre-gl-worker.js  dist/maplibre-gl-worker.mjs's code as a string (MAPLIBRE_WORKER_SRC), handed to
#                          setWorkerUrl() as a blob, which MapLibre (6.17 and later) runs on a page opened from a file
# with maplibre-gl.css and the licence unchanged. The script stops, saying what it found, if a module is not of the
# shape this relies on (an import statement, `import.meta` other than `.url`, no single export list at its end): then
# the transform is to be rewritten, or the module bundled by esbuild (which needs Node).
#
# Needs: curl, openssl, jsonlite. Writes only inst/engine/vendor/maplibre-gl{.js,-worker.js,.css} and
# LICENSE-maplibre-gl.txt.

version <- commandArgs(TRUE)[1]
if (is.na(version) || !grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", version)) {
  stop("Give the version to vendor, as Rscript tools/vendor-maplibre.R 6.19.0.", call. = FALSE)
}
vendor <- file.path("inst", "engine", "vendor")
if (!dir.exists(vendor)) stop("Run from the package's folder (inst/engine/vendor not found).", call. = FALSE)

# the tarball, checked against the registry's integrity (sha512-<base64>)
meta <- jsonlite::fromJSON(sprintf("https://registry.npmjs.org/maplibre-gl/%s", version))
want <- meta$dist$integrity
if (!is.character(want) || !startsWith(want, "sha512-")) stop("The registry gives no SHA-512 for ", version, ".", call. = FALSE)
tgz <- tempfile(fileext = ".tgz")
curl::curl_download(meta$dist$tarball, tgz, quiet = TRUE)
# the file's bytes (openssl::sha512() of a file() connection hashed something else: it did not match)
got <- paste0("sha512-", openssl::base64_encode(openssl::sha512(readBin(tgz, "raw", file.size(tgz)))))
if (!identical(got, want)) stop("The tarball's SHA-512 is not the registry's: ", got, " against ", want, call. = FALSE)
dir <- tempfile("maplibre")
inside <- c("dist/maplibre-gl.mjs", "dist/maplibre-gl-worker.mjs", "dist/maplibre-gl.css", "LICENSE.txt")
utils::untar(tgz, files = file.path("package", inside), exdir = dir)
path <- function(f) file.path(dir, "package", f)
missing <- inside[!file.exists(path(inside))]
if (length(missing)) stop("The package has no ", paste(missing, collapse = ", "), ".", call. = FALSE)

read <- function(f) {
  x <- paste(readLines(path(f), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  sub("\n//# sourceMappingURL=[^\n]*\\s*$", "\n", x, perl = TRUE)
}
shape <- function(f, code) {
  if (grepl("(^|[;}\n])\\s*import\\s*(\\{|\\*|[\"'])", code, perl = TRUE)) {
    stop(f, " imports other modules: this transform cannot make it one classic script.", call. = FALSE)
  }
  metas <- regmatches(code, gregexpr("import\\.meta(\\.[A-Za-z]+)?", code, perl = TRUE))[[1]]
  if (any(metas != "import.meta.url")) {
    stop(f, " uses ", paste(unique(metas[metas != "import.meta.url"]), collapse = ", "), ", which this transform does not replace.",
         call. = FALSE)
  }
  m <- regexpr("export\\s*\\{([^}]*)\\}\\s*;?\\s*$", code, perl = TRUE)
  if (m < 0) stop(f, " does not end in one export list.", call. = FALSE)
  m
}
stamp <- sprintf("// MapLibre GL JS %s (%%s), made a classic script by ogis's tools/vendor-maplibre.R; BSD 3-Clause, see LICENSE-maplibre-gl.txt\n",
                 version)

# the library
code <- read("dist/maplibre-gl.mjs")
m <- shape("dist/maplibre-gl.mjs", code)
# the export list as matched (substring()'s default end, character 1,000,000, falls short of a module this size)
items <- trimws(strsplit(sub("^export\\s*\\{([^}]*)\\}[\\s\\S]*$", "\\1", regmatches(code, m), perl = TRUE), ",", fixed = TRUE)[[1]])
items <- items[nzchar(items)]
if (!length(items)) stop("dist/maplibre-gl.mjs's export list names nothing.", call. = FALSE)
local <- trimws(sub("\\s+as\\s+.*$", "", items))
name <- ifelse(grepl("\\s+as\\s+", items), trimws(sub("^.*\\s+as\\s+", "", items)), local)
body <- substring(code, 1, m - 1)
n_meta <- lengths(regmatches(body, gregexpr("import.meta.url", body, fixed = TRUE)))
body <- gsub("import.meta.url", "__ogBase", body, fixed = TRUE)
lib <- paste0(
  sprintf(stamp, "dist/maplibre-gl.mjs"),
  "var maplibregl=(function(){\"use strict\";",
  "var __ogBase=(document.currentScript&&document.currentScript.src)||location.href;\n",
  body,
  "\nreturn {",
  paste(sprintf("%s:%s", vapply(name, function(n) as.character(jsonlite::toJSON(n, auto_unbox = TRUE)), ""), local), collapse = ","),
  "};})();\n",
  "// MapLibre's worker from its code in maplibre-gl-worker.js, loaded before this script\n",
  "if(window.MAPLIBRE_WORKER_SRC)maplibregl.setWorkerUrl(URL.createObjectURL(",
  "new Blob([window.MAPLIBRE_WORKER_SRC],{type:\"text/javascript\"})));\n"
)

# its worker, as a string
w <- read("dist/maplibre-gl-worker.mjs")
if (grepl("(^|[;}\n])\\s*import\\s*(\\{|\\*|[\"'])", w, perl = TRUE)) {
  stop("dist/maplibre-gl-worker.mjs imports other modules: it cannot be handed over as one blob.", call. = FALSE)
}
worker <- paste0(sprintf(stamp, "dist/maplibre-gl-worker.mjs"),
                 "window.MAPLIBRE_WORKER_SRC=", jsonlite::toJSON(w, auto_unbox = TRUE), ";\n")

write <- function(x, f) writeLines(enc2utf8(x), file.path(vendor, f), sep = "", useBytes = TRUE)
write(lib, "maplibre-gl.js")
write(worker, "maplibre-gl-worker.js")
file.copy(path("dist/maplibre-gl.css"), file.path(vendor, "maplibre-gl.css"), overwrite = TRUE)
file.copy(path("LICENSE.txt"), file.path(vendor, "LICENSE-maplibre-gl.txt"), overwrite = TRUE)
message(sprintf("MapLibre GL JS %s: %d names exported, import.meta.url replaced %d times; maplibre-gl.js %.2f MB, maplibre-gl-worker.js %.2f MB",
                version, length(name), n_meta, nchar(lib, "bytes") / 1e6, nchar(worker, "bytes") / 1e6))
