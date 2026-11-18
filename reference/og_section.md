# A group of layers in a map's sidebar

A group of layers in a map's sidebar

## Usage

``` r
og_section(id, title = id, layers, open = TRUE)
```

## Arguments

- id:

  The group's name.

- title:

  Its title in the sidebar: a key of the map's `texts`, or the text
  itself.

- layers:

  A list of
  [`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)s,
  in the order they are listed and drawn (the later over the earlier).

- open:

  Whether the group is unfolded when the page opens.

## Value

An `og_section`, for
[`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md).

## Examples

``` r
point <- og_layer(
  "point", "geojson", label = "A point",
  data = '{"type": "Point", "coordinates": [12.6, 56.0]}',
  style = list(list(id = "point-dot", type = "circle"))
)
ref <- og_section("ref", "Reference", list(point), open = FALSE)
ref$title
#> [1] "Reference"
```
