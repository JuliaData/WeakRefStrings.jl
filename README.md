
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

The package is tested against Julia `0.6` and nightly on Linux, OS X, and Windows.

## Contributing and Questions

Contributions are very welcome, as are feature requests and suggestions. Please open an
[issue][issues-url] if you encounter any problems or would just like to ask a question.

[codecov-img]: https://codecov.io/gh/JuliaData/WeakRefStrings.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaData/WeakRefStrings.jl

[issues-url]: https://github.com/JuliaData/WeakRefStrings.jl/issues

## Usage

Usage of `WeakRefString`s is discouraged for general users. Currently, a `WeakRefString` purposely _does not_ implement many Base Julia String interface methods due to many recent changes to Julia's builtin String interface, as well as the complexity to do so correctly. As such, `WeakRefString`s are used primarily in the data ecosystem as an IO optimization and nothing more. Upon indexing a `WeakRefStringArray`, a proper Julia `String` type is materialized for safe, correct string processing. In the future, it may be possible to implement safe operations on `WeakRefString` itself, but for now, they must be converted to a `String` for any real work.

Additional documentation is available at the REPL for `?WeakRefStringArray` and `?WeakRefString`.