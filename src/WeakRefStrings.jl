VERSION >= v"0.4.0-dev+6521" && __precompile__(true)
module WeakRefStrings

export WeakRefString

"""
A custom "weakref" string type that only stores a Ptr{UInt8} and len::Int.
Allows for extremely efficient string parsing/movement in certain data processing tasks.

**Please note that no original reference is kept to the parent string/memory, so `WeakRefString` becomes unsafe
once the parent object goes out of scope (i.e. loses a reference to it)**
"""
immutable WeakRefString{T} <: AbstractString
    ptr::Ptr{T}
    len::Int
end

const NULLSTRING = WeakRefString(Ptr{UInt8}(0), 0)
const NULLSTRING16 = WeakRefString(Ptr{UInt16}(0), 0)
const NULLSTRING32 = WeakRefString(Ptr{UInt32}(0), 0)
Base.endof(x::WeakRefString) = x.len
Base.length(x::WeakRefString) = x.len
Base.next(x::WeakRefString, i::Int) = (Char(unsafe_load(x.ptr, i)),i+1)

Base.show{T}(io::IO, ::Type{WeakRefString{T}}) = print(io, "WeakRefString{$T}")
Base.show(io::IO, x::WeakRefString{UInt16}) = print(io, x == NULLSTRING16 ? "\"\"" : "\"$(utf16(x.ptr, x.len))\"")
Base.show(io::IO, x::WeakRefString{UInt32}) = print(io, x == NULLSTRING32 ? "\"\"" : "\"$(utf32(x.ptr, x.len))\"")
Base.string(x::WeakRefString{UInt16}) = x == NULLSTRING16 ? utf16("") : utf16(x.ptr, x.len)
Base.string(x::WeakRefString{UInt32}) = x == NULLSTRING32 ? utf32("") : utf32(x.ptr, x.len)
Base.convert(::Type{WeakRefString{UInt16}}, x::UTF16String) = WeakRefString(pointer(x.data), length(x))
Base.convert(::Type{WeakRefString{UInt32}}, x::UTF32String) = WeakRefString(pointer(x.data), length(x))
Base.String(x::WeakRefString) = string(x)

if !isdefined(Core, :String)
    Base.convert(::Type{ASCIIString}, x::WeakRefString) = convert(ASCIIString, string(x))
    Base.convert(::Type{UTF8String}, x::WeakRefString) = convert(UTF8String, string(x))
    Base.string(x::WeakRefString) = x == NULLSTRING ? utf8("") : utf8(x.ptr, x.len)
	Base.show(io::IO, x::WeakRefString) = print(io, x == NULLSTRING ? "\"\"" : "\"$(utf8(x.ptr, x.len))\"")
    Base.convert(::Type{WeakRefString{UInt8}}, x::UTF8String) = WeakRefString(pointer(x.data), length(x))
    Base.convert(::Type{WeakRefString{UInt8}}, x::ASCIIString) = WeakRefString(pointer(x.data), length(x))
else
    Base.convert(::Type{WeakRefString{UInt8}}, x::String) = WeakRefString(pointer(x.data), length(x))
    Base.convert(::Type{String}, x::WeakRefString) = convert(String, string(x))
	Base.string(x::WeakRefString) = x == NULLSTRING ? "" : unsafe_string(x.ptr, x.len)
	Base.show(io::IO, x::WeakRefString) = print(io, x == NULLSTRING ? "\"\"" : "\"$(unsafe_wrap(String, x.ptr, x.len))\"")
end


end # module
