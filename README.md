# WeakRefStrings

[![Build Status](https://travis-ci.org/quinnj/WeakRefStrings.jl.svg?branch=master)](https://travis-ci.org/quinnj/WeakRefStrings.jl)

A custom "weakref" string type that only stores a Ptr{UInt8} and len::Int.
Allows for extremely efficient string parsing/movement in certain data processing tasks.

**Please note that no original reference is kept to the parent string/memory, so `WeakRefString` becomes unsafe
once the parent object goes out of scope (i.e. loses a reference to it)**
