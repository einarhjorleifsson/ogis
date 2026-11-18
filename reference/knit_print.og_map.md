# A map in R Markdown, Quarto and pkgdown articles

A map printed in a chunk of an R Markdown or Quarto document, or of a
pkgdown article, is shown live in the rendered page: it pans, zooms and
answers clicks, as in a browser. It is written as a bundle
([`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md))
and put beside the document as one of its dependencies, as htmlwidgets
put theirs, and shown in an iframe; the libraries it needs (MapLibre and
the others) are one copy for all the maps of a document or a site.
Nothing is served: a map's tiles and data are files in the bundle, so a
document's maps want small data (a bundle over 25 MB says so). A layer
whose tiles only a server can make is left out, as in
[`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md).

## Usage

``` r
# S3 method for class 'og_map'
knit_print(x, ..., options = NULL)
```

## Arguments

- x:

  An
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md).

- ...:

  Not used.

- options:

  The chunk's options, given by knitr.

## Value

The page's code for the map, with its dependencies, for knitr.

## Details

The chunk options `out.width` and `out.height` set the map's size in the
page (by default the page's width and 480 pixels). The document must
keep its files beside it, as pkgdown and Quarto do and R Markdown does
with `self_contained: false`; a self-contained page says so where the
map would be.

## See also

[`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md),
[`print.og_map()`](https://einarhjorleifsson.github.io/ogis/reference/print.og_map.md)
