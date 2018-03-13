__precompile__(true)
module WeakRefStrings

export WeakRefString, WeakRefStringArray

using Missings, Compat

"""
A custom "weakref" string type that only points to external string data.
Allows for the creation of a "string" instance without copying data,
which allows for more efficient string parsing/movement in certain data processing tasks.

**Please note that no original reference is kept to the parent string/memory, so `WeakRefString` becomes unsafe
once the parent object goes out of scope (i.e. loses a reference to it)**

Internally, a `WeakRefString{T}` holds:

  * `ptr::Ptr{T}`: a pointer to the string data (code unit size is parameterized on `T`)
  * `len::Int`: the number of code units in the string data

See also [`WeakRefStringArray`](@ref)
"""
struct WeakRefString{T} <: AbstractString
    ptr::Ptr{T}
    len::Int # of code units
end

WeakRefString(ptr::Ptr{T}, len) where {T} = WeakRefString(ptr, Int(len))
WeakRefString(t::Tuple{Ptr{T}, Int}) where {T} = WeakRefString(t[1], t[2])

const NULLSTRING = WeakRefString(Ptr{UInt8}(0), 0)
const NULLSTRING16 = WeakRefString(Ptr{UInt16}(0), 0)
const NULLSTRING32 = WeakRefString(Ptr{UInt32}(0), 0)
Base.zero(::Type{WeakRefString{T}}) where {T} = WeakRefString(Ptr{T}(0), 0)

import Base: ==
function ==(x::WeakRefString{T}, y::WeakRefString{T}) where {T}
    x.len == y.len && (x.ptr == y.ptr || ccall(:memcmp, Cint, (Ptr{T}, Ptr{T}, Csize_t),
                                           x.ptr, y.ptr, x.len) == 0)
end
function ==(x::String, y::WeakRefString{T}) where {T}
    sizeof(x) == y.len && ccall(:memcmp, Cint, (Ptr{T}, Ptr{T}, Csize_t),
                                 pointer(x), y.ptr, y.len) == 0
end
==(y::WeakRefString, x::String) = x == y

function Base.hash(s::WeakRefString{T}, h::UInt) where {T}
    h += Base.memhash_seed
    ccall(Base.memhash, UInt, (Ptr{T}, Csize_t, UInt32), s.ptr, s.len, h % UInt32) + h
end

Base.show(io::IO, ::Type{WeakRefString{T}}) where {T} = print(io, "WeakRefString{$T}")
function Base.show(io::IO, x::WeakRefString{T}) where {T}
    print(io, '"')
    print(io, string(x))
    print(io, '"')
    return
end
Base.print(io::IO, s::WeakRefString) = print(io, string(s))
if isdefined(Base, :textwidth)
    Base.textwidth(s::WeakRefString) = textwidth(string(s))
else
    Base.strwidth(s::WeakRefString) = strwidth(string(s))
end

chompnull(x::WeakRefString{T}) where {T} = unsafe_load(x.ptr, x.len) == T(0) ? x.len - 1 : x.len

Base.string(x::WeakRefString) = x == NULLSTRING ? "" : unsafe_string(x.ptr, x.len)
Base.string(x::WeakRefString{UInt16}) = x == NULLSTRING16 ? "" : String(transcode(UInt8, unsafe_wrap(Array, x.ptr, chompnull(x))))
Base.string(x::WeakRefString{UInt32}) = x == NULLSTRING32 ? "" : String(transcode(UInt8, unsafe_wrap(Array, x.ptr, chompnull(x))))

Base.convert(::Type{WeakRefString{UInt8}}, x::String) = WeakRefString(pointer(x), sizeof(x))
Base.convert(::Type{String}, x::WeakRefString) = convert(String, string(x))
Base.String(x::WeakRefString) = string(x)
Base.Symbol(x::WeakRefString{UInt8}) = ccall(:jl_symbol_n, Ref{Symbol}, (Ptr{UInt8}, Int), x.ptr, x.len)

init(::Type{T}, rows) where {T} = fill(zero(T), rows)
init(::Type{Union{Missing, T}}, rows) where {T} = Vector{Union{Missing, T}}(undef, rows)

"""
A [`WeakRefString`](@ref) container.
Holds the "strong" references to the data pointed by its strings, ensuring that
the referenced memory blocks stay valid during `WeakRefStringArray` lifetime.

Upon indexing an elemnt in a `WeakRefStringArray`, the underlying `WeakRefString` is converted to a proper
Julia `String` type by copying the memory; this ensures safe string processing in the general case. If additional
optimizations are desired, the direct `WeakRefString` elements can be accessed by indexing `A.elements`, where
`A` is a `WeakRefStringArray`.
"""
struct WeakRefStringArray{T<:WeakRefString, N, U} <: AbstractArray{Union{String, U}, N}
    data::Vector{Any}
    elements::Array{Union{T, U}, N}

    WeakRefStringArray(data::Vector{Any}, A::Array{Union{T, Missing}, N}) where {T <: WeakRefString, N} =
        new{T, N, Missing}(data, A)
    WeakRefStringArray(data::Vector{Any}, A::Array{T, N}) where {T <: WeakRefString, N} =
        new{T, N, Union{}}(data, A)
end

WeakRefStringArray(data, ::Type{T}, rows::Integer) where {T} = WeakRefStringArray(Any[data], init(T, rows))
WeakRefStringArray(data, A::Array{T}) where {T <: Union{WeakRefString, Missing}} = WeakRefStringArray(Any[data], A)

wk(A, B::AbstractArray) = WeakRefStringArray(A.data, B)
wk(A, w::WeakRefString) = string(w)
wk(A, ::Missing) = missing

Base.size(A::WeakRefStringArray) = size(A.elements)
Base.getindex(A::WeakRefStringArray, I...) = wk(A, getindex(A.elements, I...))
Base.setindex!(A::WeakRefStringArray{T, N}, v::Missing, i::Int) where {T, N} = setindex!(A.elements, v, i)
Base.setindex!(A::WeakRefStringArray{T, N}, v::Missing, I::Vararg{Int, N}) where {T, N} = setindex!(A.elements, v, I...)
Base.setindex!(A::WeakRefStringArray{T, N}, v::WeakRefString, i::Int) where {T, N} = setindex!(A.elements, v, i)
Base.setindex!(A::WeakRefStringArray{T, N}, v::WeakRefString, I::Vararg{Int, N}) where {T, N} = setindex!(A.elements, v, I...)
Base.setindex!(A::WeakRefStringArray{T, N}, v::String, i::Int) where {T, N} = (push!(A.data, codeunits(v)); setindex!(A.elements, v, i))
Base.setindex!(A::WeakRefStringArray{T, N}, v::String, I::Vararg{Int, N}) where {T, N} = (push!(A.data, codeunits(v)); setindex!(A.elements, v, I...))
if VERSION < v"0.7.0-DEV.3673" # Work around incorrect ambiguity error (PR #26)
    Base.setindex!(A::WeakRefStringArray{T, 1}, v::Missing, i::Int) where {T} = setindex!(A.elements, v, i)
    Base.setindex!(A::WeakRefStringArray{T, 1}, v::WeakRefString, i::Int) where {T} = setindex!(A.elements, v, i)
    Base.setindex!(A::WeakRefStringArray{T, 1}, v::String, i::Int) where {T} = (push!(A.data, codeunits(v)); setindex!(A.elements, v, i))
end
Base.resize!(A::WeakRefStringArray, i) = resize!(A.elements, i)

Base.push!(a::WeakRefStringArray{T, 1}, v::Missing) where {T} = (push!(a.elements, v); a)
Base.push!(a::WeakRefStringArray{T, 1}, v::WeakRefString) where {T} = (push!(a.elements, v); a)
function Base.push!(A::WeakRefStringArray{T, 1}, v::String) where T
    push!(A.data, codeunits(v))
    push!(A.elements, v)
    return A
end

function Base.append!(a::WeakRefStringArray{T, 1}, b::WeakRefStringArray{T, 1}) where {T}
    append!(a.data, b.data)
    append!(a.elements, b.elements)
    return a
end

function Base.vcat(a::WeakRefStringArray{T, 1}, b::WeakRefStringArray{T, 1}) where T
    WeakRefStringArray(Any[a.data, b.data], vcat(a.elements, b.elements))
end

end # module
