# Tiles from an MBTiles file

A tile function for an
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
that reads its tiles from an MBTiles file (SQLite), such as the image
tiles of elevations a dem layer draws. The file is opened once,
read-only, and stays open while the function lives.

## Usage

``` r
og_tiles_mbtiles(file = NULL)
```

## Arguments

- file:

  An MBTiles file: a `tiles` table (`zoom_level`, `tile_column`,
  `tile_row` in the TMS order, from the south, and `tile_data`) and a
  `metadata` table of `name` and `value`. By default (`NULL`, or `""`),
  the file named by the environment variable `OGIS_DEPTH`.

## Value

A function `function(z, x, y)` (`y` from the north, as the page asks)
returning a tile's bytes, or `NULL` where the file has none; with the
file's `format`, `bounds`, `minzoom`, `maxzoom`, `encoding` and
`tile_size` as attributes where its metadata give them, which
[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)
takes for a dem layer, and `source`, the file's path, by which
[`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md)
writes the tiles of layers on one file once.

## A depth model named once

A depth model kept in its own place on each computer, such as one shared
between colleagues, can be named once in the environment variable
`OGIS_DEPTH` rather than in every script. Put a line in your `.Renviron`
(`usethis::edit_r_environ()` opens it), a path on Windows written with
forward slashes, and restart R:

    OGIS_DEPTH=D:/data/depth.mbtiles

`og_tiles_mbtiles()` with no `file` then reads that file, and says so
once a session; a `file` given wins. A script written so runs on each
computer with that computer's copy. A bundle
([`og_bundle()`](https://einarhjorleifsson.github.io/ogis/reference/og_bundle.md))
holds the tiles themselves and needs no such variable where it is
opened.

## See also

[`og_layer()`](https://einarhjorleifsson.github.io/ogis/reference/og_layer.md)

## Examples

``` r
f <- tempfile(fileext = ".mbtiles")
con <- DBI::dbConnect(RSQLite::SQLite(), f)
DBI::dbWriteTable(con, "metadata", data.frame(
  name = c("format", "encoding", "bounds", "minzoom", "maxzoom"),
  value = c("png", "terrarium", "-30,60,-5,70", "0", "1")
))
DBI::dbExecute(con, paste("CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER,",
                          "tile_row INTEGER, tile_data BLOB)"))
#> [1] 0
DBI::dbExecute(con, "INSERT INTO tiles VALUES (1, 0, 1, ?)", params = list(list(as.raw(1:4))))
#> [1] 1
DBI::dbDisconnect(con)
tiles <- og_tiles_mbtiles(f)
tiles(1, 0, 0) # the north-west tile at zoom 1, row 1 counted from the south
#> [1] 01 02 03 04
attributes(tiles)[c("format", "encoding", "bounds")]
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
