
# WeakRefStrings

*An alternative string storage format for Julia*

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

[travis-img]: https://travis-ci.org/quinnj/WeakRefStrings.jl.svg?branch=master
[travis-url]: https://travis-ci.org/quinnj/WeakRefStrings.jl

[appveyor-img]: https://ci.appveyor.com/api/projects/status/h227adt6ovd1u3sx/branch/master?svg=true
[appveyor-url]: https://ci.appveyor.com/project/quinnj/documenter-jl/branch/master

[codecov-img]: https://codecov.io/gh/quinnj/WeakRefStrings.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/quinnj/WeakRefStrings.jl

[issues-url]: https://github.com/quinnj/WeakRefStrings.jl/issues

[pkg-0.6-img]: http://pkg.julialang.org/badges/WeakRefStrings_0.6.svg
[pkg-0.6-url]: http://pkg.julialang.org/?pkg=WeakRefStrings

## Usage

A custom "weakref" string type that only points to external string data.
Allows for the creation of a "string" instance without copying data,
which allows for more efficient string parsing/movement in certain data processing tasks.

**Please note that no original reference is kept to the parent string/memory, so `WeakRefString` becomes unsafe
once the parent object goes out of scope (i.e. loses a reference to it)**

Internally, a `WeakRefString{T}` holds:

  * `ptr::Ptr{T}`: a pointer to the string data (code unit size is parameterized on `T`)
  * `len::Int`: the number of code units in the string data


```julia
data = Vector{UInt8}("hey there sailor")

str = WeakRefString(pointer(data), 3)
@test length(str) == 3
for (i,c) in enumerate(str)
    @test data[i] == c % UInt8
end
@test string(str) == "hey"
```

To facilitate using WeakRefStrings, a `WeakRefStringArray` type is provided that can simultaneously act as an `Array{WeakRefString{T}, N}` while also holding on to data references that the WeakRefStrings point to. Usage, is simple:
```julia
WeakRefStringArray(data::Vector{UInt8}, ::Type{T}, rows) => WeakRefStringArray{T, 1}
WeakRefStringArray(data::Vector{UInt8}, A::Array{WeakRefString{T}, N}) => WeakRefStringArray{T, N}
```
In both cases, the first argument passed is the data that should be held in reference. An "empty" WeakRefString can be constructed by passing the WeakRefString element type and a number of rows, or an already constructed Array of WeakRefStrings can be passed in directly.