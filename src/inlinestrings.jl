import Base: ==

export InlineString, InlineStringType

abstract type InlineString <: AbstractString end

for sz in (1, 4, 8, 16, 32, 64, 128, 256)
    nm = Symbol(:InlineString, max(1, sz - 1))
    @eval begin
        primitive type $nm <: InlineString $(sz * 8) end
        export $nm
    end
end

_bswap(x::T) where {T <: InlineString} = T === InlineString1 ? x : Base.bswap_int(x)

const InlineStrings = Union{InlineString1,
                            InlineString3,
                            InlineString7,
                            InlineString15,
                            InlineString31,
                            InlineString63,
                            InlineString127,
                            InlineString255}

function Base.promote_rule(::Type{T}, ::Type{S}) where {T <: InlineString, S <: InlineString}
    T === InlineString1 && return S
    S === InlineString1 && return T
    T === InlineString3 && return S
    S === InlineString3 && return T
    T === InlineString7 && return S
    S === InlineString7 && return T
    T === InlineString15 && return S
    S === InlineString15 && return T
    T === InlineString31 && return S
    S === InlineString31 && return T
    T === InlineString63 && return S
    S === InlineString63 && return T
    T === InlineString127 && return S
    S === InlineString127 && return T
    return InlineString255
end

Base.promote_rule(::Type{T}, ::Type{String}) where {T <: InlineString} = String

Base.widen(::Type{InlineString1}) = InlineString3
Base.widen(::Type{InlineString3}) = InlineString7
Base.widen(::Type{InlineString7}) = InlineString15
Base.widen(::Type{InlineString15}) = InlineString31
Base.widen(::Type{InlineString31}) = InlineString63
Base.widen(::Type{InlineString63}) = InlineString127
Base.widen(::Type{InlineString127}) = InlineString255
Base.widen(::Type{InlineString255}) = String

Base.ncodeunits(::InlineString1) = 1
Base.ncodeunits(x::InlineString) = Int(Base.trunc_int(UInt8, x))
Base.codeunit(::InlineString) = UInt8

Base.@propagate_inbounds function Base.codeunit(x::T, i::Int) where {T <: InlineString}
    @boundscheck checkbounds(Bool, x, i) || throw(BoundsError(x, i))
    if T === InlineString1
        return Base.bitcast(UInt8, x)
    else
        return Base.trunc_int(UInt8, Base.lshr_int(x, 8 * (sizeof(T) - i)))
    end
end

function Base.String(x::T) where {T <: InlineString}
    len = ncodeunits(x)
    out = Base._string_n(len)
    if T === InlineString1
        GC.@preserve out unsafe_store!(pointer(out), codeunit(x, 1))
        return out
    end
    ref = Ref{T}(_bswap(x))
    GC.@preserve ref out begin
        ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
        unsafe_copyto!(pointer(out), ptr, len)
    end
    return out
end

function Base.Symbol(x::T) where {T <: InlineString}
    ref = Ref{T}(_bswap(x))
    return ccall(:jl_symbol_n, Ref{Symbol},
        (Ref{T}, Int), ref, sizeof(x))
end

# add a codeunit to end of string method
function addcodeunit(x::T, b::UInt8) where {T <: InlineString}
    if T === InlineString1
        return x, false
    end
    len = Base.trunc_int(UInt8, x)
    sz = Base.trunc_int(UInt8, sizeof(T))
    shf = Base.zext_int(Int16, max(0x01, sz - len - 0x01)) << 3
    x = Base.or_int(x, Base.shl_int(Base.zext_int(T, b), shf))
    return Base.add_int(x, Base.zext_int(T, 0x01)), (len + 0x01) >= sz
end

# from String
InlineString1(byte::UInt8=0x00) = Base.bitcast(InlineString1, byte)
(::Type{T})() where {T <: InlineString} = Base.zext_int(T, 0x00)

function (::Type{T})(x::AbstractString) where {T <: InlineString}
    if T === InlineString1
        sizeof(x) == 1 || stringtoolong(T, sizeof(x))
        return Base.bitcast(InlineString1, codeunit(x, 1))
    elseif typeof(x) === String && sizeof(T) <= sizeof(UInt)
        len = sizeof(x)
        len < sizeof(T) || stringtoolong(T, len)
        y = GC.@preserve x unsafe_load(convert(Ptr{T}, pointer(x)))
        sz = 8 * (sizeof(T) - len)
        return Base.or_int(Base.shl_int(Base.lshr_int(_bswap(y), sz), sz), Base.zext_int(T, UInt8(len)))
    else
        len = ncodeunits(x)
        len < sizeof(T) || stringtoolong(T, len)
        y = T()
        for i = 1:len
            @inbounds y, _ = addcodeunit(y, codeunit(x, i))
        end
        return y
    end
end

@noinline stringtoolong(T, n) = throw(ArgumentError("string too large ($n) to convert to $T"))

function InlineStringType(n::Integer)
    n > 255 && stringtoolong(InlineString, n)
    return n == 1  ? InlineString1   : n < 4  ? InlineString3  :
           n < 8   ? InlineString7   : n < 16 ? InlineString15 :
           n < 32  ? InlineString31  : n < 64 ? InlineString63 :
           n < 128 ? InlineString127 : InlineString255
end

InlineString(x::AbstractString)::InlineStrings = (InlineStringType(ncodeunits(x)))(x)

# between InlineStrings
function (::Type{T})(x::S) where {T <: InlineString, S <: InlineString}
    if T === S
        return x
    elseif T === InlineString1
        sizeof(x) == 1 || stringtoolong(T, sizeof(x))
        return Base.bitcast(InlineString1, codeunit(x, 1))
    elseif sizeof(T) < sizeof(S)
        # trying to compress
        len = sizeof(x)
        len > (sizeof(T) - 1) && stringtoolong(T, len)
        y = Base.trunc_int(T, Base.lshr_int(x, 8 * (sizeof(S) - sizeof(T))))
        return Base.add_int(y, Base.zext_int(T, UInt8(len)))
    else
        # promoting smaller InlineString to larger
        if S === InlineString1
            y = Base.shl_int(Base.zext_int(T, x), 8 * (sizeof(T) - sizeof(S)))
        else
            y = Base.shl_int(Base.zext_int(T, Base.lshr_int(x, 8)), 8 * (sizeof(T) - sizeof(S) + 1))
        end
        return Base.add_int(y, Base.zext_int(T, UInt8(sizeof(x))))
    end
end

(==)(x::T, y::T) where {T <: InlineString} = Base.eq_int(x, y)
function ==(x::String, y::T) where {T <: InlineString}
    sizeof(x) == sizeof(y) || return false
    ref = Ref{T}(_bswap(y))
    return ccall(:memcmp, Cint, (Ptr{UInt8}, Ref{T}, Csize_t),
            pointer(x), ref, sizeof(x)) == 0
end
==(y::InlineString, x::String) = x == y

function Base.hash(x::T, h::UInt) where {T <: InlineString}
    h += Base.memhash_seed
    ref = Ref{T}(_bswap(x))
    return ccall(Base.memhash, UInt,
        (Ref{T}, Csize_t, UInt32),
        ref, sizeof(x), h % UInt32) + h
end

function Base.write(io::IO, x::T) where {T <: InlineString}
    ref = Ref{T}(_bswap(x))
    return GC.@preserve ref begin
        ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
        Int(unsafe_write(io, ptr, reinterpret(UInt, sizeof(x))))::Int
    end
end

Base.print(io::IO, s::InlineString) = (write(io, s); nothing)

function Base.isascii(x::T) where {T <: InlineString}
    if T === InlineString1
        return codeunit(x, 1) < 0x80
    end
    len = ncodeunits(x)
    x = Base.lshr_int(x, 8 * (sizeof(T) - len))
    for _ = 1:len
        Base.trunc_int(UInt8, x) >= 0x80 && return false
        x = Base.lshr_int(x, 8)
    end
    return true
end

# copy/pasted from substring.jl
function Base.reverse(s::InlineString)
    # Read characters forwards from `s` and write backwards to `out`
    out = Base._string_n(sizeof(s))
    offs = sizeof(s) + 1
    for c in s
        offs -= ncodeunits(c)
        Base.__unsafe_string!(out, c, offs)
    end
    return out
end

@inline function Base.__unsafe_string!(out, x::T, offs::Integer) where {T <: InlineString}
    n = sizeof(x)
    ref = Ref{T}(_bswap(x))
    GC.@preserve ref out begin
        ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
        unsafe_copyto!(pointer(out, offs), ptr, n)
    end
    return n
end

Base.string(a::InlineString) = a
Base.string(a::InlineString...) = _string(a...)
Base.string(a::BaseStrs, b::InlineString) = _string(a, b)
Base.string(a::BaseStrs, b::BaseStrs, c::InlineString) = _string(a, b, c)
@inline function _string(a::Union{BaseStrs, InlineString}...)
    n = 0
    for v in a
        if v isa Char
            n += ncodeunits(v)
        else
            n += sizeof(v)
        end
    end
    out = Base._string_n(n)
    offs = 1
    for v in a
        offs += Base.__unsafe_string!(out, v, offs)
    end
    return out
end

function Base.repeat(x::T, r::Integer) where {T <: InlineString}
    r < 0 && throw(ArgumentError("can't repeat a string $r times"))
    r == 0 && return ""
    r == 1 && return s
    n = sizeof(x)
    out = Base._string_n(n * r)
    if n == 1 # common case: repeating a single-byte string
        @inbounds b = codeunit(x, 1)
        ccall(:memset, Ptr{Cvoid}, (Ptr{UInt8}, Cint, Csize_t), out, b, r)
    else
        for i = 0:r-1
            ref = Ref{T}(_bswap(x))
            GC.@preserve ref out begin
                ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
                unsafe_copyto!(pointer(out, i * n + 1), ptr, n)
            end
        end
    end
    return out
end

# copy/pasted from strings/util.jl
function Base.startswith(a::T, b::Union{String, SubString{String}, InlineString}) where {T <: InlineString}
    cub = ncodeunits(b)
    ncodeunits(a) < cub && return false
    ref = Ref{T}(_bswap(a))
    return GC.@preserve ref begin
        ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
        if Base._memcmp(ptr, b, sizeof(b)) == 0
            nextind(a, cub) == cub + 1
        else
            false
        end
    end
end

function Base.endswith(a::T, b::Union{String, SubString{String}, InlineString}) where {T <: InlineString}
    cub = ncodeunits(b)
    astart = ncodeunits(a) - ncodeunits(b) + 1
    astart < 1 && return false
    ref = Ref{T}(_bswap(a))
    return GC.@preserve ref begin
        ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
        if Base._memcmp(ptr + (astart - 1), b, sizeof(b)) == 0
            thisind(a, astart) == astart
        else
            false
        end
    end
end

Base.match(r::Regex, s::InlineString, i::Integer) = match(r, String(s), i)

# the rest of these methods are copy/pasted from Base strings/string.jl file
# for efficiency
Base.@propagate_inbounds function Base.isvalid(x::InlineString, i::Int)
    @boundscheck checkbounds(Bool, x, i) || throw(BoundsError(x, i))
    return @inbounds thisind(x, i) == i
end

Base.@propagate_inbounds function Base.thisind(s::InlineString, i::Int)
    i == 0 && return 0
    n = ncodeunits(s)
    i == n + 1 && return i
    @boundscheck Base.between(i, 1, n) || throw(BoundsError(s, i))
    @inbounds b = codeunit(s, i)
    (b & 0xc0 == 0x80) & (i-1 > 0) || return i
    @inbounds b = codeunit(s, i-1)
    Base.between(b, 0b11000000, 0b11110111) && return i-1
    (b & 0xc0 == 0x80) & (i-2 > 0) || return i
    @inbounds b = codeunit(s, i-2)
    Base.between(b, 0b11100000, 0b11110111) && return i-2
    (b & 0xc0 == 0x80) & (i-3 > 0) || return i
    @inbounds b = codeunit(s, i-3)
    Base.between(b, 0b11110000, 0b11110111) && return i-3
    return i
end

Base.@propagate_inbounds function Base.nextind(s::InlineString, i::Int)
    i == 0 && return 1
    n = ncodeunits(s)
    @boundscheck Base.between(i, 1, n) || throw(BoundsError(s, i))
    @inbounds l = codeunit(s, i)
    (l < 0x80) | (0xf8 ≤ l) && return i+1
    if l < 0xc0
        i′ = @inbounds thisind(s, i)
        return i′ < i ? @inbounds(nextind(s, i′)) : i+1
    end
    # first continuation byte
    (i += 1) > n && return i
    @inbounds b = codeunit(s, i)
    b & 0xc0 ≠ 0x80 && return i
    ((i += 1) > n) | (l < 0xe0) && return i
    # second continuation byte
    @inbounds b = codeunit(s, i)
    b & 0xc0 ≠ 0x80 && return i
    ((i += 1) > n) | (l < 0xf0) && return i
    # third continuation byte
    @inbounds b = codeunit(s, i)
    ifelse(b & 0xc0 ≠ 0x80, i, i+1)
end

Base.@propagate_inbounds function Base.iterate(s::InlineString, i::Int=firstindex(s))
    (i % UInt) - 1 < ncodeunits(s) || return nothing
    b = @inbounds codeunit(s, i)
    u = UInt32(b) << 24
    Base.between(b, 0x80, 0xf7) || return reinterpret(Char, u), i+1
    return iterate_continued(s, i, u)
end

function iterate_continued(s::InlineString, i::Int, u::UInt32)
    u < 0xc0000000 && (i += 1; @goto ret)
    n = ncodeunits(s)
    # first continuation byte
    (i += 1) > n && @goto ret
    @inbounds b = codeunit(s, i)
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b) << 16
    # second continuation byte
    ((i += 1) > n) | (u < 0xe0000000) && @goto ret
    @inbounds b = codeunit(s, i)
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b) << 8
    # third continuation byte
    ((i += 1) > n) | (u < 0xf0000000) && @goto ret
    @inbounds b = codeunit(s, i)
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b); i += 1
@label ret
    return reinterpret(Char, u), i
end

Base.@propagate_inbounds function Base.getindex(s::InlineString, i::Int)
    b = codeunit(s, i)
    u = UInt32(b) << 24
    Base.between(b, 0x80, 0xf7) || return reinterpret(Char, u)
    return getindex_continued(s, i, u)
end

function getindex_continued(s::InlineString, i::Int, u::UInt32)
    if u < 0xc0000000
        # called from `getindex` which checks bounds
        @inbounds isvalid(s, i) && @goto ret
        Base.string_index_err(s, i)
    end
    n = ncodeunits(s)

    (i += 1) > n && @goto ret
    @inbounds b = codeunit(s, i) # cont byte 1
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b) << 16

    ((i += 1) > n) | (u < 0xe0000000) && @goto ret
    @inbounds b = codeunit(s, i) # cont byte 2
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b) << 8

    ((i += 1) > n) | (u < 0xf0000000) && @goto ret
    @inbounds b = codeunit(s, i) # cont byte 3
    b & 0xc0 == 0x80 || @goto ret
    u |= UInt32(b)
@label ret
    return reinterpret(Char, u)
end

Base.length(s::InlineString) = length_continued(s, 1, ncodeunits(s), ncodeunits(s))

Base.@propagate_inbounds function Base.length(s::InlineString, i::Int, j::Int)
    @boundscheck begin
        0 < i ≤ ncodeunits(s)+1 || throw(BoundsError(s, i))
        0 ≤ j < ncodeunits(s)+1 || throw(BoundsError(s, j))
    end
    j < i && return 0
    @inbounds i, k = thisind(s, i), i
    c = j - i + (i == k)
    length_continued(s, i, j, c)
end

@inline function length_continued(s::InlineString, i::Int, n::Int, c::Int)
    i < n || return c
    @inbounds b = codeunit(s, i)
    @inbounds while true
        while true
            (i += 1) ≤ n || return c
            0xc0 ≤ b ≤ 0xf7 && break
            b = codeunit(s, i)
        end
        l = b
        b = codeunit(s, i) # cont byte 1
        c -= (x = b & 0xc0 == 0x80)
        x & (l ≥ 0xe0) || continue

        (i += 1) ≤ n || return c
        b = codeunit(s, i) # cont byte 2
        c -= (x = b & 0xc0 == 0x80)
        x & (l ≥ 0xf0) || continue

        (i += 1) ≤ n || return c
        b = codeunit(s, i) # cont byte 3
        c -= (b & 0xc0 == 0x80)
    end
end

# parsers
# this is mostly copy-pasta from Parsers.jl main xparse function
import Parsers: SENTINEL, OK, EOF, OVERFLOW, QUOTED, DELIMITED, INVALID_QUOTED_FIELD, ESCAPED_STRING, NEWLINE, SUCCESS, peekbyte, incr!, checksentinel, checkdelim, checkcmtemptylines

function Parsers.xparse(::Type{T}, source::Union{AbstractVector{UInt8}, IO}, pos, len, options::Parsers.Options, ::Type{S}=T)::Parsers.Result{S} where {T <: InlineString, S}
    startpos = vstartpos = vpos = pos
    sentstart = sentinelpos = 0
    code = SUCCESS
    sentinel = options.sentinel
    quoted = overflowed = false
    x = T()
    # if options.debug
    #     println("parsing $T, pos=$pos, len=$len")
    # end
    if Parsers.eof(source, pos, len)
        code = (sentinel === missing ? SENTINEL : OK) | EOF
        if T === InlineString1
            # InlineString1 must be exactly 1 byte, so for empty string
            # this is an "underflow" situation
            code |= OVERFLOW
        end
        @goto donedone
    end
    b = peekbyte(source, pos)
    # if options.debug
    #     println("string 1) parsed: '$(escape_string(string(Char(b))))'")
    # end
    # strip leading whitespace
    while b == options.wh1 || b == options.wh2
        # if options.debug
        #     println("stripping leading whitespace")
        # end
        x, overflowed = addcodeunit(x, b)
        pos += 1
        incr!(source)
        if Parsers.eof(source, pos, len)
            code |= EOF
            @goto donedone
        end
        b = peekbyte(source, pos)
        # if options.debug
        #     println("string 2) parsed: '$(escape_string(string(Char(b))))'")
        # end
    end
    # check for start of quoted field
    if options.quoted
        quoted = b == options.oq
        if quoted
            # if options.debug
            #     println("detected open quote character")
            # end
            code = QUOTED
            x = T() # start our parsed value back over
            pos += 1
            vstartpos = pos
            incr!(source)
            if Parsers.eof(source, pos, len)
                code |= INVALID_QUOTED_FIELD
                @goto donedone
            end
            b = peekbyte(source, pos)
            # if options.debug
            #     println("string 3) parsed: '$(escape_string(string(Char(b))))'")
            # end
            # ignore whitespace within quoted field
            while b == options.wh1 || b == options.wh2
                # if options.debug
                #     println("stripping whitespace within quoted field")
                # end
                x, overflowed = addcodeunit(x, b)
                pos += 1
                incr!(source)
                if Parsers.eof(source, pos, len)
                    code |= INVALID_QUOTED_FIELD | EOF
                    @goto donedone
                end
                b = peekbyte(source, pos)
                # if options.debug
                #     println("string 4) parsed: '$(escape_string(string(Char(b))))'")
                # end
            end
        end
    end
    # check for sentinel values if applicable
    if sentinel !== nothing && sentinel !== missing
        # if options.debug
        #     println("checking for sentinel value")
        # end
        sentstart = pos
        sentinelpos = checksentinel(source, pos, len, sentinel, debug)
    end
    vpos = pos
    if options.quoted
        # for quoted fields, find the closing quote character
        if quoted
            # if options.debug
            #     println("looking for close quote character")
            # end
            same = options.cq == options.e
            while true
                vpos = pos
                pos += 1
                incr!(source)
                if same && b == options.e
                    if Parsers.eof(source, pos, len)
                        code |= EOF
                        @goto donedone
                    elseif peekbyte(source, pos) != options.cq
                        break
                    end
                    code |= ESCAPED_STRING
                    b = peekbyte(source, pos)
                    pos += 1
                    incr!(source)
                elseif b == options.e
                    if Parsers.eof(source, pos, len)
                        code |= INVALID_QUOTED_FIELD | EOF
                        @goto donedone
                    end
                    code |= ESCAPED_STRING
                    b = peekbyte(source, pos)
                    pos += 1
                    incr!(source)
                elseif b == options.cq
                    if Parsers.eof(source, pos, len)
                        code |= EOF
                        @goto donedone
                    end
                    break
                end
                if Parsers.eof(source, pos, len)
                    code |= INVALID_QUOTED_FIELD | EOF
                    @goto donedone
                end
                x, overflowed = addcodeunit(x, b)
                b = peekbyte(source, pos)
                # if options.debug
                #     println("string 9) parsed: '$(escape_string(string(Char(b))))'")
                # end
            end
            b = peekbyte(source, pos)
            # if options.debug
            #     println("string 10) parsed: '$(escape_string(string(Char(b))))'")
            # end
            # ignore whitespace after quoted field
            while b == options.wh1 || b == options.wh2
                # if options.debug
                #     println("stripping trailing whitespace after close quote character")
                # end
                pos += 1
                incr!(source)
                if Parsers.eof(source, pos, len)
                    code |= EOF
                    @goto donedone
                end
                b = peekbyte(source, pos)
                # if options.debug
                #     println("string 11) parsed: '$(escape_string(string(Char(b))))'")
                # end
            end
        end
    end
    if options.delim !== nothing
        delim = options.delim
        quo = Int(!quoted)
        # now we check for a delimiter; if we don't find it, keep parsing until we do
        # if options.debug
        #     println("checking for delimiter: pos=$pos")
        # end
        while true
            if !options.ignorerepeated
                if delim isa UInt8
                    if b == delim
                        pos += 1
                        incr!(source)
                        code |= DELIMITED
                        @goto donedone
                    end
                else
                    predelimpos = pos
                    pos = checkdelim(source, pos, len, delim)
                    if pos > predelimpos
                        # found the delimiter we were looking for
                        code |= DELIMITED
                        @goto donedone
                    end
                end
            else
                if delim isa UInt8
                    matched = false
                    matchednewline = false
                    while true
                        if b == delim
                            matched = true
                            code |= DELIMITED
                            pos += 1
                            incr!(source)
                        elseif !matchednewline && b == UInt8('\n')
                            matchednewline = matched = true
                            pos += 1
                            incr!(source)
                            pos = checkcmtemptylines(source, pos, len, options)
                            code |= NEWLINE | ifelse(Parsers.eof(source, pos, len), EOF, SUCCESS)
                        elseif !matchednewline && b == UInt8('\r')
                            matchednewline = matched = true
                            pos += 1
                            incr!(source)
                            if !Parsers.eof(source, pos, len) && peekbyte(source, pos) == UInt8('\n')
                                pos += 1
                                incr!(source)
                            end
                            pos = checkcmtemptylines(source, pos, len, options)
                            code |= NEWLINE | ifelse(Parsers.eof(source, pos, len), EOF, SUCCESS)
                        else
                            break
                        end
                        if Parsers.eof(source, pos, len)
                            @goto donedone
                        end
                        b = peekbyte(source, pos)
                        # if options.debug
                        #     println("14) parsed: '$(escape_string(string(Char(b))))'")
                        # end
                    end
                    if matched
                        @goto donedone
                    end
                else
                    matched = false
                    matchednewline = false
                    while true
                        predelimpos = pos
                        pos = checkdelim(source, pos, len, delim)
                        if pos > predelimpos
                            matched = true
                            code |= DELIMITED
                        elseif !matchednewline && b == UInt8('\n')
                            matchednewline = matched = true
                            pos += 1
                            incr!(source)
                            pos = checkcmtemptylines(source, pos, len, options)
                            code |= NEWLINE | ifelse(Parsers.eof(source, pos, len), EOF, SUCCESS)
                        elseif !matchednewline && b == UInt8('\r')
                            matchednewline = matched = true
                            pos += 1
                            incr!(source)
                            if !Parsers.eof(source, pos, len) && peekbyte(source, pos) == UInt8('\n')
                                pos += 1
                                incr!(source)
                            end
                            pos = checkcmtemptylines(source, pos, len, options)
                            code |= NEWLINE | ifelse(Parsers.eof(source, pos, len), EOF, SUCCESS)
                        else
                            break
                        end
                        if Parsers.eof(source, pos, len)
                            @goto donedone
                        end
                        b = peekbyte(source, pos)
                        # if options.debug
                        #     println("14) parsed: '$(escape_string(string(Char(b))))'")
                        # end
                    end
                    if matched
                        @goto donedone
                    end
                end
            end
            # didn't find delimiter, but let's check for a newline character
            if b == UInt8('\n')
                pos += 1
                incr!(source)
                pos = checkcmtemptylines(source, pos, len, options)
                code |= NEWLINE | ifelse(Parsers.eof(source, pos, len), EOF, SUCCESS)
                @goto donedone
            elseif b == UInt8('\r')
                pos += 1
                incr!(source)
                if !Parsers.eof(source, pos, len) && peekbyte(source, pos) == UInt8('\n')
                    pos += 1
                    incr!(source)
                end
                pos = checkcmtemptylines(source, pos, len, options)
                code |= NEWLINE | ifelse(Parsers.eof(source, pos, len), EOF, SUCCESS)
                @goto donedone
            end
            # didn't find delimiter nor newline, so increment and check the next byte
            x, overflowed = addcodeunit(x, b)
            pos += 1
            vpos += quo
            incr!(source)
            if Parsers.eof(source, pos, len)
                code |= EOF
                @goto donedone
            end
            b = peekbyte(source, pos)
        end
    else
        # no delimiter, so read until EOF
        while !Parsers.eof(source, pos, len)
            b = peekbyte(source, pos)
            x, overflowed = addcodeunit(x, b)
            pos += 1
            vpos += 1
            incr!(source)
        end
        code |= EOF
    end

@label donedone
    if sentinel !== nothing && sentinel !== missing && sentstart == vstartpos && sentinelpos == vpos
        # if we matched a sentinel value that was as long or longer than our type value
        code |= SENTINEL
    elseif sentinel === missing && vstartpos == vpos
        code |= SENTINEL
    else
        code |= OK
        if T === InlineString1
            if (vpos - vstartpos) != 1
                overflowed = true
            else
                Parsers.fastseek!(source, vstartpos)
                x = InlineString1(peekbyte(source, vstartpos))
                Parsers.fastseek!(source, pos - 1)
            end
        end
    end
    if overflowed
        code |= OVERFLOW
    end
    # if options.debug
    #     println("finished parsing: $(codes(code))")
    # end
    tlen = pos - startpos
    return Parsers.Result{S}(code, tlen, x)
end
