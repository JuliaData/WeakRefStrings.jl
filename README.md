
# WeakRefStrings

*A string type for minimizing data-transfer costs in Julia*

| **PackageEvaluator**                                            | **Build Status**                                                                                |
|:---------------------------------------------------------------:|:-----------------------------------------------------------------------------------------------:|
| [![][pkg-0.6-img]][pkg-0.6-url] | [![][travis-img]][travis-url] [![][appveyor-img]][appveyor-url] [![][codecov-img]][codecov-url] |


## Installation

The package is registered in `METADATA.jl` and so can be installed with `Pkg.add`.

```julia
julia> Pkg.add("WeakRefStrings")
```

## Project Status

The package is tested against Julia `0.6` and nightly on Linux, OS X, and Windows.

## Contributing and Questions

Contributions are very welcome, as are feature requests and suggestions. Please open an
[issue][issues-url] if you encounter any problems or would just like to ask a question.

[travis-img]: https://travis-ci.org/JuliaData/WeakRefStrings.jl.svg?branch=master
[travis-url]: https://travis-ci.org/JuliaData/WeakRefStrings.jl

[appveyor-img]: https://ci.appveyor.com/api/projects/status/h227adt6ovd1u3sx/branch/master?svg=true
[appveyor-url]: https://ci.appveyor.com/project/quinnj/weakrefstrings-jl/branch/master

[codecov-img]: https://codecov.io/gh/JuliaData/WeakRefStrings.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/JuliaData/WeakRefStrings.jl

[issues-url]: https://github.com/JuliaData/WeakRefStrings.jl/issues

[pkg-0.6-img]: http://pkg.julialang.org/badges/WeakRefStrings_0.6.svg
[pkg-0.6-url]: http://pkg.julialang.org/?pkg=WeakRefStrings

## Usage

Usage of `WeakRefString`s is discouraged for general users. Currently, a `WeakRefString` purposely _does not_ implement many Base Julia String interface methods due to many recent changes to Julia's builtin String interface, as well as the complexity to do so correctly. As such, `WeakRefString`s are used primarily in the data ecosystem as an IO optimization and nothing more. Upon indexing a `WeakRefStringArray`, a proper Julia `String` type is materialized for safe, correct string processing. In the future, it may be possible to implement safe operations on `WeakRefString` itself, but for now, they must be converted to a `String` for any real work.

Additional documentation is available at the REPL for `?WeakRefStringArray` and `?WeakRefString`.