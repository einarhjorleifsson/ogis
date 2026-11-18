# Show a map

At an interactive console a map is served when printed
([`og_serve()`](https://einarhjorleifsson.github.io/ogis/reference/og_serve.md),
on the port the call that started it gave, else on 8790 or the next free
port) and opens in RStudio's Viewer or a browser; elsewhere, as when a
document is knitted, its title and layers are printed.

## Usage

``` r
# S3 method for class 'og_map'
print(x, ...)

# S3 method for class 'og_map'
format(x, ...)
```

## Arguments

- x:

  An
  [`og_map()`](https://einarhjorleifsson.github.io/ogis/reference/og_map.md).

- ...:

  Not used.

## Value

`x`, invisibly.
