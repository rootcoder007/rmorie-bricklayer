# Refuse a categorical column where a numeric 0/1 treatment is required

Refuse a categorical column where a numeric 0/1 treatment is required

## Usage

``` r
guard_binary(x, col)
```

## Arguments

- x:

  The column.

- col:

  Its name, for the message.

## Value

`TRUE`, invisibly; errors otherwise.

## Examples

``` r
guard_binary(c(0, 1, 1, 0), "treated")
```
