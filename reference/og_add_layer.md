# A layer of your own on a map the pipe makes

`og_add_layer()` adds an
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
to a map the pipe makes
([`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
with data or none, and the layer functions), for what the layer
functions do not draw: elevations as relief and colours (`"dem"`),
contours made in the page (`"contour"`), tiles of your own (`"vector"`,
`"grid"`), features as GeoJSON with a style of your own. It sits in the
sidebar's box `section` with the others and is drawn in the order added,
the later over the earlier, whatever their boxes (or as
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)'s
`order` says); elevations, contours and a grid go under the base map's
labels, as in any map.

## Usage

``` r
og_add_layer(map, layer, section = "Layers")
```

## Arguments

- map:

  A map the pipe makes:
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md),
  with data or none, and any layer functions after it. A map made of
  [`og_section()`](https://einarhjorleifsson.github.io/ogis/reference/og_section.md)s
  takes its layers in them instead.

- layer:

  An
  [`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md),
  or a list of them, added in their order.

- section:

  The sidebar's box the layer sits in, by its title, as the layer
  functions' `section`; whether it is open when the page opens, by
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)'s
  `sections`.

## Value

The map, with the layer.

## Details

The first view covers the rows of the map's layer functions; a map with
none fits the layers' tiles (their `bounds`, which
[`og_tiles_dem()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_dem.md)
and
[`og_tiles_mbtiles()`](https://einarhjorleifsson.github.io/ogis/reference/og_tiles_mbtiles.md)
give), unless `og_map(view = )` is given. The layer is served, bundled
and knitted as the others are; its `id` must not be another layer's.

## See also

[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md);
[`og_section()`](https://einarhjorleifsson.github.io/ogis/reference/og_section.md)
and
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md)
for a map whose every layer is an
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md).

## Examples

``` r
# the seabed's depth in colour, as tiles made from a grid, under the harbours
# \donttest{
if (requireNamespace("png", quietly = TRUE) && requireNamespace("terra", quietly = TRUE)) {
  depth <- og_layer(
    "depth", "dem", label = "Depth",
    tiles = og_tiles_dem(og_example("dansk_relief"), maxzoom = 6),
    style = list(list(id = "depth-colour", type = "color-relief")),
    colour = list(palette = "seabed", opacity = 75)
  )
  m <- og_map(view = list(bounds = c(2.5, 54.5, 13, 58.5))) |>
    og_add_layer(depth, section = "Sea floor") |>
    og_polygon(og_example("dansk_harbours"), name = "Harbours")
  m
}
#> <og_map> Map
#>   layers: depth (dem), harbours (geojson)
# }
```
