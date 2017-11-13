__precompile__(true)
module WeakRefStrings

export WeakRefString, WeakRefStringArray

using Nulls

"""
A custom "weakref" string type that only points to external string data.
Allows for the creation of a "string" instance without copying data,
which allows for more efficient string parsing/movement in certain data processing tasks.

**Please note that no original reference is kept to the parent string/memory, so `WeakRefString` becomes unsafe
once the parent object goes out of scope (i.e. loses a reference to it)**

Internally, a `WeakRefString{T}` holds:

  * `ptr::Ptr{T}`: a pointer to the string data (code unit size is parameterized on `T`)
  * `len::Int`: the number of code units in the string data
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
Base.endof(x::WeakRefString) = endof(string(x))
Base.length(x::WeakRefString) = length(string(x))
Base.next(x::WeakRefString, i::Int) = (Char(unsafe_load(x.ptr, i)), i + 1)

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
if VERSION < v"0.7-DEV"
    Base.strwidth(s::WeakRefString) = strwidth(string(s))
else
    Base.textwidth(s::WeakRefString) = textwidth(string(s))
end

chompnull(x::WeakRefString{T}) where {T} = unsafe_load(x.ptr, x.len) == T(0) ? x.len - 1 : x.len

Base.string(x::WeakRefString) = x == NULLSTRING ? "" : unsafe_string(x.ptr, x.len)
Base.string(x::WeakRefString{UInt16}) = x == NULLSTRING16 ? "" : String(transcode(UInt8, unsafe_wrap(Array, x.ptr, chompnull(x))))
Base.string(x::WeakRefString{UInt32}) = x == NULLSTRING32 ? "" : String(transcode(UInt8, unsafe_wrap(Array, x.ptr, chompnull(x))))

Base.convert(::Type{WeakRefString{UInt8}}, x::String) = WeakRefString(pointer(x), sizeof(x))
Base.convert(::Type{String}, x::WeakRefString) = convert(String, string(x))
Base.String(x::WeakRefString) = string(x)
Base.Symbol(x::WeakRefString{UInt8}) = ccall(:jl_symbol_n, Ref{Symbol}, (Ptr{UInt8}, Int), x.ptr, x.len)

struct WeakRefStringArray{T, N} <: AbstractArray{T, N}
    data::Vector{Any}
    elements::Array{T, N}
end

WeakRefStringArray(data::Vector{UInt8}, ::Type{T}, rows::Integer) where {T <: WeakRefString} = WeakRefStringArray(Any[data], zeros(T, rows))
WeakRefStringArray(data::Vector{UInt8}, ::Type{Union{Null, T}}, rows::Integer) where {T} = WeakRefStringArray(Any[data], Vector{Union{Null, T}}(rows))
WeakRefStringArray(data::Vector{UInt8}, A::Array{T}) where {T <: Union{WeakRefString, Null}} = WeakRefStringArray(Any[data], A)

wk(w::WeakRefString) = string(w)
wk(::Null) = null

Base.size(A::WeakRefStringArray) = size(A.elements)
Base.getindex(A::WeakRefStringArray, i::Int) = wk(A.elements[i])
Base.getindex(A::WeakRefStringArray{T, N}, I::Vararg{Int, N}) where {T, N} = wk.(A.elements[I...])
Base.setindex!(A::WeakRefStringArray{T, N}, v::Null, i::Int) where {T, N} = setindex!(A.elements, v, i)
Base.setindex!(A::WeakRefStringArray{T, N}, v::Null, I::Vararg{Int, N}) where {T, N} = setindex!(A.elements, v, I...)
Base.setindex!(A::WeakRefStringArray{T, N}, v::WeakRefString, i::Int) where {T, N} = setindex!(A.elements, v, i)
Base.setindex!(A::WeakRefStringArray{T, N}, v::WeakRefString, I::Vararg{Int, N}) where {T, N} = setindex!(A.elements, v, I...)
Base.setindex!(A::WeakRefStringArray{T, N}, v::String, i::Int) where {T, N} = (push!(A.data, Vector{UInt8}(v)); setindex!(A.elements, v, i))
Base.setindex!(A::WeakRefStringArray{T, N}, v::String, I::Vararg{Int, N}) where {T, N} = (push!(A.data, Vector{UInt8}(v)); setindex!(A.elements, v, I...))
Base.resize!(A::WeakRefStringArray, i) = resize!(A.elements, i)

Base.push!(a::WeakRefStringArray{T, 1}, v::Null) where {T} = (push!(a.elements, v); a)
Base.push!(a::WeakRefStringArray{T, 1}, v::WeakRefString) where {T} = (push!(a.elements, v); a)
function Base.push!(A::WeakRefStringArray{T, 1}, v::String) where T
    push!(A.data, Vector{UInt8}(v))
    push!(A.elements, v)
    return A
end

function Base.append!(a::WeakRefStringArray{T, 1}, b::WeakRefStringArray{T, 1}) where {T}
    append!(a.data, b.data)
    append!(a.elements, b.elements)
    return a
end

import Base.vcat
function Base.vcat(a::WeakRefStringArray{T, 1}, b::WeakRefStringArray{T, 1}) where T
    WeakRefStringArray(Any[a.data, b.data], vcat(a.elements, b.elements))
end

end # module
