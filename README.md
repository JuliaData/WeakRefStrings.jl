
# WeakRefStrings

[![CI](https://github.com/JuliaData/WeakRefStrings.jl/workflows/CI/badge.svg)](https://github.com/JuliaData/WeakRefStrings.jl/actions?query=workflow%3ACI)
[![codecov](https://codecov.io/gh/JuliaData/WeakRefStrings.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaData/WeakRefStrings.jl)
[![deps](https://juliahub.com/docs/WeakRefStrings/deps.svg)](https://juliahub.com/ui/Packages/WeakRefStrings/muGbw?t=2)
[![version](https://juliahub.com/docs/WeakRefStrings/version.svg)](https://juliahub.com/ui/Packages/WeakRefStrings/muGbw)
[![pkgeval](https://juliahub.com/docs/WeakRefStrings/pkgeval.svg)](https://juliahub.com/ui/Packages/WeakRefStrings/muGbw)

*A string type for minimizing data-transfer costs in Julia*

## Installation

The package is registered in the General registry and so can be installed with `Pkg.add`.

```julia
julia> using Pkg; Pkg.add("WeakRefStrings")
```

## Project Status

CI tests Julia 1.3 (the minimum supported version), the latest release, and nightly
on Linux, and the latest release on 32-bit Windows.

## Contributing and Questions

Contributions are very welcome, as are feature requests and suggestions. Please open an
[issue][issues-url] if you encounter any problems or would just like to ask a question.

[codecov-img]: https://codecov.io/gh/JuliaData/WeakRefStrings.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaData/WeakRefStrings.jl

[issues-url]: https://github.com/JuliaData/WeakRefStrings.jl/issues

## Usage

### `InlineString`

The inline string types (`String1`, `String3`, `String7`, `String15`,
`String31`, `String63`, `String127`, `String255`) live in
[InlineStrings.jl](https://github.com/JuliaStrings/InlineStrings.jl) and are
re-exported from this package for backwards compatibility.

### `WeakRefString`

Usage of `WeakRefString`s is discouraged for general users. A `WeakRefString`
points at bytes owned by another object and does not keep that object alive, so it
becomes invalid once that object is freed. `WeakRefString`s are used primarily in
the data ecosystem as an IO optimization; convert one to `String` for any real
work. Indexing a `StringArray{String}` returns a `String`.

Additional documentation is available at the REPL for `?StringArray` and
`?WeakRefString`.
