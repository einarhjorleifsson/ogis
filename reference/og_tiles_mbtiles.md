# Tiles from an MBTiles file

A tile function for an
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
that reads its tiles from an MBTiles file (SQLite), such as the image
tiles of elevations a dem layer draws. The file is opened once,
read-only, and stays open while the function lives.

## Usage

``` r
og_tiles_mbtiles(file)
```

## Arguments

- file:

  An MBTiles file: a `tiles` table (`zoom_level`, `tile_column`,
  `tile_row` in the TMS order, from the south, and `tile_data`) and a
  `metadata` table of `name` and `value`.

## Value

A function `function(z, x, y)` (`y` from the north, as the page asks)
returning a tile's bytes, or `NULL` where the file has none; with the
file's `format`, `bounds`, `minzoom`, `maxzoom`, `encoding` and
`tile_size` as attributes where its metadata give them, which
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
takes for a dem layer, and `source`, the file's path, by which
[`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md)
writes the tiles of layers on one file once.

## See also

[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)

## Examples

``` r
if (requireNamespace("RSQLite", quietly = TRUE)) {
  f <- tempfile(fileext = ".mbtiles")
  con <- DBI::dbConnect(RSQLite::SQLite(), f)
  DBI::dbWriteTable(con, "metadata", data.frame(
    name = c("format", "encoding", "bounds", "minzoom", "maxzoom"),
    value = c("png", "terrarium", "-30,60,-5,70", "0", "1")
  ))
  DBI::dbExecute(con, paste("CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER,",
                            "tile_row INTEGER, tile_data BLOB)"))
  DBI::dbExecute(con, "INSERT INTO tiles VALUES (1, 0, 1, ?)", params = list(list(as.raw(1:4))))
  DBI::dbDisconnect(con)
  tiles <- og_tiles_mbtiles(f)
  tiles(1, 0, 0) # the north-west tile at zoom 1, row 1 counted from the south
  attributes(tiles)[c("format", "encoding", "bounds")]
}
#> $format
#> [1] "png"
#> 
#> $encoding
#> [1] "terrarium"
#> 
#> $bounds
#> [1] -30  60  -5  70
#> 
```
