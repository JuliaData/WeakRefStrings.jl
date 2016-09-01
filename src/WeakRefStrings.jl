__precompile__(true)
module WeakRefStrings

if !isdefined(Base, :transcode)
    transcode(T, bytes) = Base.encode_to_utf8(eltype(bytes), bytes, length(bytes)).data
else
    transcode = Base.transcode
end

if !isdefined(Base, :unsafe_wrap)
    unsafe_wrap{A<:Array}(::Type{A}, ptr, len) = pointer_to_array(ptr, len, false)
end

export WeakRefString

"""
A custom "weakref" string type that only points to external string data.
Allows for the creation of a "string" instance without copying data,
which allows for more efficient string parsing/movement in certain data processing tasks.

**Please note that no original reference is kept to the parent string/memory, so `WeakRefString` becomes unsafe
once the parent object goes out of scope (i.e. loses a reference to it)**

Internally, a `WeakRefString{T}` holds:

  * `ptr::Ptr{T}`: a pointer to the string data (code unit size is parameterized on `T`)
  * `len::Int`: the number of code units in the string data
  * `ind::Int`: a field that can be used to store an integer, like an index into an array; this can be helpful
                in certain cases when the underlying source may need to move around (which would invalidate
                the WeakRefString's `ptr` field), a new WeakRefString can created using the same offset into
                the parent data as the old one.
"""
immutable WeakRefString{T} <: AbstractString
    ptr::Ptr{T}
    len::Int # of code units
    ind::Int # used to keep track of a string data index
end

WeakRefString{T}(ptr::Ptr{T}, len) = WeakRefString(ptr, Int(len), 0)

const NULLSTRING = WeakRefString(Ptr{UInt8}(0), 0)
const NULLSTRING16 = WeakRefString(Ptr{UInt16}(0), 0)
const NULLSTRING32 = WeakRefString(Ptr{UInt32}(0), 0)
Base.endof(x::WeakRefString) = x.len
Base.length(x::WeakRefString) = x.len
Base.next(x::WeakRefString, i::Int) = (Char(unsafe_load(x.ptr, i)), i + 1)

import Base: ==
function ==(x::WeakRefString{UInt8}, y::WeakRefString{UInt8})
    x.len == y.len && (x.ptr == y.ptr || ccall(:memcmp, Cint, (Ptr{UInt8}, Ptr{UInt8}, Csize_t),
                                           x.ptr, y.ptr, x.len) == 0)
end

function Base.hash(s::WeakRefString{UInt8}, h::UInt)
    h += Base.memhash_seed
    ccall(Base.memhash, UInt, (Ptr{UInt8}, Csize_t, UInt32), s.ptr, s.len, h % UInt32) + h
end

Base.show{T}(io::IO, ::Type{WeakRefString{T}}) = print(io, "WeakRefString{$T}")
function Base.show{T}(io::IO, x::WeakRefString{T})
    print(io, '"')
    for c in x
        print(io, c)
    end
    print(io, '"')
    return
end

chompnull{T}(x::WeakRefString{T}) = unsafe_load(x.ptr, x.len) == T(0) ? x.len - 1 : x.len

Base.string(x::WeakRefString{UInt16}) = x == NULLSTRING16 ? "" : String(transcode(UInt8, unsafe_wrap(Array, x.ptr, chompnull(x))))
Base.string(x::WeakRefString{UInt32}) = x == NULLSTRING32 ? "" : String(transcode(UInt8, unsafe_wrap(Array, x.ptr, chompnull(x))))

if !isdefined(Core, :String)
    using LegacyStrings
    typealias String UTF8String

    Base.convert(::Type{WeakRefString{UInt16}}, x::UTF16String) = WeakRefString(pointer(x.data), length(x))
    Base.convert(::Type{WeakRefString{UInt32}}, x::UTF32String) = WeakRefString(pointer(x.data), length(x))

    Base.convert(::Type{ASCIIString}, x::WeakRefString) = convert(ASCIIString, string(x))
    Base.convert(::Type{UTF8String}, x::WeakRefString) = convert(UTF8String, string(x))
    Base.string(x::WeakRefString) = x == NULLSTRING ? utf8("") : utf8(x.ptr, x.len)
    Base.convert(::Type{WeakRefString{UInt8}}, x::UTF8String) = WeakRefString(pointer(x.data), length(x))
    Base.convert(::Type{WeakRefString{UInt8}}, x::ASCIIString) = WeakRefString(pointer(x.data), length(x))
else
    Base.convert(::Type{WeakRefString{UInt8}}, x::String) = WeakRefString(pointer(x.data), length(x))
    Base.convert(::Type{String}, x::WeakRefString) = convert(String, string(x))
	Base.string(x::WeakRefString) = x == NULLSTRING ? "" : unsafe_string(x.ptr, x.len)
    Base.String(x::WeakRefString) = string(x)
end

end # module
