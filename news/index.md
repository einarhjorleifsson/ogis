# Changelog

## ogis 2026.11.18.11

- MapLibre GL JS 6.19.0 in place of 5.24.1, the last of 5.x. MapLibre 6
  is published only as ES modules, which a page opened from its folder
  cannot load, and a bundle opens by a double click; so its two modules
  are made classic scripts by `tools/vendor-maplibre.R` (the npm package
  checked against the registry’s SHA-512; `import.meta.url` the script’s
  own address, the export list the global `maplibregl`), its worker’s
  code carried in `maplibre-gl-worker.js` and handed to MapLibre as a
  blob, which MapLibre 6.17 and later runs on a page opened from a file.
  The page loads that script before MapLibre; nothing else in it
  changed. A bundle is 0.6 MB larger.
- A test opens a bundle from its folder (`file://`), as a double click
  does, and checks its outlines, labels and contours (made in the page
  by maplibre-contour) are drawn; every other page test opens its page
  over http. `tools/firefox-check.R` does the same in headless Firefox,
  by hand at each MapLibre update.
- Checked beside 5.24.1 at the same views: lines that cross, labels past
  their tiles’ deepest zoom and contours look the same; a map of 8,918
  labels opens and zooms as fast. The engine’s guard on queries for
  MapLibre 5’s lost index stays until a reproduction shows 6 has done
  with it.

## ogis 2026.11.18.10

- rebelrebel is renamed **ogis**, its prefix `rr_` now `og_`: every
  function
  ([`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
  [`og_point()`](https://einarhjorleifsson.github.io/ogis/reference/og_point.md),
  [`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md),
  …) and class (`og_map`, `og_layer`, `og_section`), and in the page
  what a script of its own sees: the object it is given (`og`:
  `og.on()`, `og.state()`, `og.fetch()`, …), the features’ key
  (`og_row`) and the classes its styles may name (`.og-panel`). A map’s
  own route header is `X-OG-Notes`. Names the engine kept from ramb
  (`rb`) are `og` too. Nothing else changed: a call made with the `rr_`
  names is the same call with `og_`. The entries below keep the names of
  their day.
