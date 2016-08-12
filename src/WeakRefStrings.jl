VERSION >= v"0.4.0-dev+6521" && __precompile__(true)
module WeakRefStrings

using LegacyStrings

export WeakRefString

"""
A custom "weakref" string type that only stores a Ptr{UInt8} and len::Int.
Allows for extremely efficient string parsing/movement in certain data processing tasks.

**Please note that no original reference is kept to the parent string/memory, so `WeakRefString` becomes unsafe
once the parent object goes out of scope (i.e. loses a reference to it)**
"""
immutable WeakRefString{T} <: AbstractString
    ptr::Ptr{T}
    len::Int # of **code units**
    ind::Int
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
Base.string(x::WeakRefString{UInt16}) = x == NULLSTRING16 ? utf16("") : utf16(x.ptr, x.len)
Base.string(x::WeakRefString{UInt32}) = x == NULLSTRING32 ? utf32("") : utf32(x.ptr, x.len)
Base.convert(::Type{WeakRefString{UInt16}}, x::UTF16String) = WeakRefString(pointer(x.data), length(x))
Base.convert(::Type{WeakRefString{UInt32}}, x::UTF32String) = WeakRefString(pointer(x.data), length(x))

if !isdefined(Core, :String)
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
