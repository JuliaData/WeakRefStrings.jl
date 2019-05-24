
# WeakRefStrings

*Utilities for efficiently working with String data in Julia*

[![][travis-img]][travis-url]
[![][appveyor-img]][appveyor-url]
[![][codecov-img]][codecov-url]

## Installation

The package is registered in the [General](https://github.com/JuliaRegistries/General/) registry.

```julia
pkg> add WeakRefStrings
```

## Project Status

The package is tested against Julia `1.0` and nightly on Linux, OS X, and Windows.

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

## Usage

Usage of `WeakRefString`s and `StringArray` is discouraged for general users. `StringArray`s are used primarily in the data ecosystem for IO optimization, avoiding unnecessary string allocations, and efficient binary storage. Upon indexing a `StringArray`, a proper Julia `String` type is materialized for safe, correct string processing.

Additional documentation is available at the REPL for `?StringArray` and `?WeakRefString`.