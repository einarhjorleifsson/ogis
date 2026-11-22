# ogis — agent notes

*Seeded 2026-11-18 by Claude (AI), from ogis’s code, NEWS and git log,
its Claude memories and fishycode’s records; not yet read by the
maintainer. What is true now: keep it short and current, and change it
in the same commit as the fact it records.*

## What ogis is

Interactive maps for marine data, drawn in the browser by MapLibre GL
JS. The data stay in DuckDB and reach the page as vector tiles, so a map
of millions of rows stays fast. A map is served from R on the local
machine
([`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md))
or written as a folder that opens from its `index.html` with no R
([`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md)).
It is a general package, in the company of leaflet, mapview and tmap:
generic, not Icelandic, not for fishing alone.

There are three doors to a map (fishycode plan 072):

- the layer functions in the pipe, named after ggplot2’s geoms
  (`og_map() |> og_point() |> og_path()`);
- a layer in MapLibre’s own terms
  ([`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md),
  [`og_add_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_add_layer.md));
- one-line maps of a known kind
  ([`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md),
  [`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md),
  [`og_names()`](https://einarhjorleifsson.github.io/ogis/reference/og_names.md),
  [`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md),
  [`og_contour()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md)).

`og_view()` is still to come. ogis began as ramb’s map viewer
(`rb_map*()`). It moved out as rebelrebel (`rr_`) on 2026-11-10 and was
renamed ogis (`og_`) on 2026-11-18 (fishycode decision 327). Older NEWS
entries and fishycode’s plans keep the names of their day.

## Where things are

| Path | Holds |
|----|----|
| `R/map.R` | [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md), [`og_section()`](https://einarhjorleifsson.github.io/ogis/reference/og_section.md), [`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md), the page’s config. `.og_map_engine` (now 7) must equal `ENGINE` in the page; change both together whenever the page and the server stop fitting each other. |
| `R/serve.R` | [`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md), [`og_stop()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md), the server (`.og_map_app()`): `/config.json`, `/meta`, `/time`, `/fit`, `/row`, `/search`, `/data`, `/tiles`, `/notes`, `/verdicts`, and a map’s own routes under `/x/`. `.og_map_query()` reads every query the way a form writes it (`+` is a space). |
| `R/layers.R` | The layer functions: [`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md), [`og_path()`](https://einarhjorleifsson.github.io/ogis/reference/og_path.md), [`og_line()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md), [`og_segment()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md), [`og_polygon()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md), [`og_text()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md). |
| `R/time.R`, `R/tracks.R` | [`og_time()`](https://einarhjorleifsson.github.io/ogis/reference/og_time.md), the time panel under the map; [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md), vessel tracks in one line. |
| `R/cells.R`, `R/names.R`, `R/relief.R` | [`og_cells()`](https://einarhjorleifsson.github.io/ogis/reference/og_cells.md), [`og_names()`](https://einarhjorleifsson.github.io/ogis/reference/og_names.md), [`og_relief()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md), [`og_contour()`](https://einarhjorleifsson.github.io/ogis/reference/og_relief.md). |
| `R/tiles.R`, `R/pmtiles.R`, `R/bundle.R` | Tile makers ([`og_tiles_table()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_table.md), [`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md), [`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)), the PMTiles writer, [`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md). |
| `R/notes.R`, `R/script.R`, `R/quick.R` | Readers’ notes and verdicts; [`og_script()`](https://einarhjorleifsson.github.io/ogis/reference/og_script.md), a page’s own script; [`og_add_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_add_layer.md). |
| `R/colours.R`, `R/palettes.R`, `R/duckdb.R`, `R/example.R` | Colours, palettes and base maps; DuckDB connections; [`og_example()`](https://einarhjorleifsson.github.io/ogis/reference/og_example.md). |
| `inst/engine/index.html` | The page: one file (~2,950 lines) of HTML, CSS and JavaScript, served and bundled alike. |
| `inst/engine/vendor/` | MapLibre GL JS 6.19.0 repackaged as classic scripts, pmtiles.js, maplibre-contour and uPlot, each with its licence (`inst/COPYRIGHTS`). |
| `inst/extdata/` | The example parquet files, stored with Git LFS ([`og_example()`](https://einarhjorleifsson.github.io/ogis/reference/og_example.md)). |
| `tests/testthat/` | Tests. Helpers: `helper-browser.R` (headless Chrome through chromote: `open_page()`, `page_eval()`, `wait_until()`, `serve_dir()`), `helper-spatial.R` (`skip_if_no_spatial()`, `mvt_count()`), `helper-pmtiles.R`. |
| `vignettes/articles/` | Quarto articles with live maps (`ogis`, `labels`, `own-page`, `tracks`), built into the pkgdown site. |
| `tools/` | Run by hand at each MapLibre update: `vendor-maplibre.R <version>`, then `firefox-check.R`. |
| `data-raw/` | How the example files were changed. |
| `.github/workflows/` | R CMD check on macOS, Windows and Ubuntu; the pkgdown site, rebuilt on every push to `main`. |

## How a change lands

1.  **Work in a worktree on a branch** (`git worktree add`) when another
    session may be using `~/R/Pakkar/ogis`: one may hold uncommitted
    work there, or serve maps from it. Never switch that checkout’s
    branch.
2.  **A test that fails before the change and passes after it.** A
    change to the page also gets a headless-Chrome test: served
    (`og_serve(wait = FALSE)` and `open_page()`), or bundled
    ([`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md)
    and `serve_dir()`).
3.  **Bump the version** in `DESCRIPTION` with each change: `YYYY.MM.DD`
    for the day’s first, then `.1`, `.2`.
4.  **Add a NEWS.md entry** under a heading `# ogis <version>` at the
    top: bullets with a bold lead, what changed and why, the
    maintainer’s words where the choice was theirs, and measured
    numbers.
5.  **Run R under `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`.** R in Claude’s
    shell does not start in UTF-8. There, `devtools::document()` writes
    `<U+00F6>` into other Rd files (revert those), and eight notes and
    verdicts tests skip.
6.  **Check**: `devtools::test()`. It sets `NOT_CRAN`; without it the
    Chrome tests skip. Two tests run only against the installed ogis: a
    Quarto document’s maps, and `og_serve(wait = TRUE)` from Rscript.
    Then `devtools::check()`, and
    [`pkgdown::build_article()`](https://pkgdown.r-lib.org/reference/build_articles.html)
    for an article. The change is done when CI passes on all three
    systems.
7.  **Commit message**: what changed, with the version in brackets,
    e.g. `og_cells() and og_names(): ... (2026.11.18.15)`. Commit as
    work lands; push only when asked, since each push to `main` rebuilds
    the public site.
8.  **Install** from a clone with LFS:
    `remotes::install_git("https://github.com/einarhjorleifsson/ogis", git = "external", force = TRUE)`.
    `install_github()` installs the LFS pointers instead of the data,
    and over such an install, from the same commit, remotes skips
    without `force = TRUE`. `packageDescription("ogis")` says what is
    installed; `RemoteSha` is empty after an install from the local
    tree.

## Rules

- **The repository and the site are public.** Never put Icelandic
  internal data into the package, its tests, articles or site: the depth
  model, the effort cells, the place names, vessel data, or anything
  made from them. Each of these reaches ogis as one file, named by
  `OGIS_DEPTH`, `OGIS_CELLS` or `OGIS_NAMES` in `.Renviron`. Articles
  use public data:
  [`og_example()`](https://einarhjorleifsson.github.io/ogis/reference/og_example.md)
  (ramb’s `dansk`, the 2019 March survey), EMODnet, GEBCO.
- **Platform independent** (the maintainer, 2026-11-17): Linux, macOS
  and Windows alike. Use
  [`file.path()`](https://rdrr.io/r/base/file.path.html) and
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html), never `/tmp` or
  a shell call. Write files as UTF-8 explicitly. Tests that need Chrome
  skip where there is none.
- **Articles are the feedback loop** (2026-11-17): each feature lands
  with an article that builds a real map with it. Code that is long or
  awkward in an article, or needs `:::`, means the functions are wrong.
- **ogis does not depend on ramb.** ramb is installed only for the
  site’s tracks article (`Config/Needs/website`).
- **ogis views; it does not edit** (2026-11-17, fishycode plan 076). A
  page that edits builds on ogis’s documented surface:
  [`og_script()`](https://einarhjorleifsson.github.io/ogis/reference/og_script.md),
  `og_serve(routes = )`, and in the page `og.on()`, `og.state()`,
  `og.fetch()`. It uses no `:::` and no copied page. A fault such a page
  finds is fixed in ogis, with a test.
- **Keep it simple** (2026-11-11): options studied and set aside are not
  built unasked. These include MLT, GeoArrow with deck.gl, DuckDB-WASM,
  FlatGeobuf, and a `.duckdb` file as the store (parquet stays the
  store).
- **MapLibre is pinned.** It changes only at a chosen version, through
  `tools/vendor-maplibre.R`, checked in Chrome (the suite), Firefox
  (`tools/firefox-check.R`) and Safari (fishycode plan 077, decision
  328).

## Records

ogis keeps no plans or decisions of its own. NEWS.md says what changed,
and fishycode (`~/stasi/fishycode`) holds the designs and choices:

- **plans**: 072 (the package), 076 (a foundation for pages built on
  it), 077 (MapLibre 6);
- **decisions**: 327 (the rename), 328 (MapLibre 6.19), 329 (the
  Icelandic example data for ramb and ogis);
- **TODO** item 198;
- **from ramb’s map viewer**: decisions 220, 228 and 277-281, and plans
  046, 063 and 064.

The studies are under `$FISHYDATA/archive/` (`2026-11-11-rebelrebel-*`
and others).

## State (2026-11-19)

- **`main`** is at 2026.11.19.1 and on GitHub (pushed 2026-11-19 at the
  maintainer’s word): fd28f37,
  [`og_names()`](https://einarhjorleifsson.github.io/ogis/reference/og_names.md)
  turning a name by an `angle` column (fishycode’s plan 078 ask i), with
  a test. Its push ran no CI, the newest commit carrying the skip
  marker, nor did an empty commit quoting it (c27cc9e); 0bf40a8, empty,
  ran both: R CMD check passed on Ubuntu, Windows and macOS, and the
  site was built (its build at 8fddee3 had failed installing R on the
  runner, not in ogis). Before it, 2026.11.19 (cf66ca5, a test of a
  served map’s `og_cells(filter = )`) and 2026.11.18.17 (c6f3bcf,
  0c4ed35); the side sessions that built 2026.11.18.14-17 are closed,
  their record fishycode’s decision 330.
- **Installed**: 2026.11.19.1, from the local `main` at fd28f37
  (`remotes::install_git("file:///Users/einarhj/R/Pakkar/ogis", git = "external", force = TRUE)`:
  a bare path loses its leading slash; `RemoteSha` fd28f37, the LFS
  example data whole, byte for byte the tree’s). The tests that run only
  against an installed ogis (test-knit.R’s renders) pass against it, 34
  of 34. Before it, 2026.11.19 from GitHub at 79017ff.
- **Open**: a vessel id with a comma is still refused by the effort’s
  cells, since the server splits a filter’s values at commas (fishycode
  TODO 203); a tile address for dem and contour layers, the S3 route for
  the Icelandic depth model (TODO 204).
- **Next**: the EM4SSF hackathon in Ancona, 1-4 December 2026. There,
  [`og_tracks()`](https://einarhjorleifsson.github.io/ogis/reference/og_tracks.md)
  is a quick visual check of each step of a track’s processing, with
  ramb doing the processing.
