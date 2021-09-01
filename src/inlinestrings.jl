export InlineString, InlineStringType

"""
    InlineString

A set of custom string types of various fixed sizes. Each inline string
is a custom primitive type and can benefit from being stack friendly by
avoiding allocations/heap tracking in the GC. When used in an array,
the elements are able to be stored inline since each one has a fixed
size. Currently support inline strings from 1 byte up to 255 bytes.
"""
abstract type InlineString <: AbstractString end

for sz in (1, 4, 8, 16, 32, 64, 128, 256)
    nm = Symbol(:InlineString, max(1, sz - 1))
    @eval begin
        """
            $($nm)

        Custom fixed-size string with a fixed size of $($sz) bytes.
        1 byte is used to store the length of the string. If an
        inline string is shorter than $($sz - 1) bytes, the entire
        string still occupies the full $($sz) bytes since they are,
        by definition, fixed size. Otherwise, they can be treated
        just like normal `String` values. Note that `sizeof(x)` will
        return the # of _codeunits_ in an $($nm) like `String`, not
        the total fixed size. For the fixed size, call `sizeof($($nm))`.
        $($nm) can be constructed from an existing `String` (`$($nm)(x::String)`),
        from a byte buffer with position and length (`$($nm)(buf, pos, len)`),
        or built iteratively by starting with `x = $($nm)()` and calling
        `WeakRefStrings.addcodeunit(x, b::UInt8)` which returns a new $($nm)
        with the new codeunit `b` appended.
        """
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

function (::Type{T})(buf::AbstractVector{UInt8}, pos, len) where {T <: InlineString}
    if T === InlineString1
        len == 1 || stringtoolong(T, len)
        return Base.bitcast(InlineString1, buf[pos])
    else
        blen = length(buf)
        blen < len && buftoosmall(len)
        len < sizeof(T) || stringtoolong(T, len)
        if (blen - pos + 1) < sizeof(T)
            # if our buffer isn't long enough to hold a full T,
            # then we can't do our unsafe_load trick below because we'd be
            # unsafe_load-ing memory from beyond the end of buf
            # we need to build the InlineString byte-by-byte instead
            y = T()
            for i = pos:(pos + len - 1)
                @inbounds y, _ = addcodeunit(y, buf[i])
            end
            return y
        else
            y = GC.@preserve buf unsafe_load(convert(Ptr{T}, pointer(buf, pos)))
            sz = 8 * (sizeof(T) - len)
            return Base.or_int(Base.shl_int(Base.lshr_int(_bswap(y), sz), sz), Base.zext_int(T, UInt8(len)))
        end
    end
end

@noinline buftoosmall(n) = throw(ArgumentError("input buffer too short for requested length: $n"))
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
    ref = Ref{T}(x)
    return GC.@preserve ref begin
        ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
        Int(unsafe_write(io, ptr, reinterpret(UInt, sizeof(T))))::Int
    end
end

function Base.read(s::IO, ::Type{T}) where {T <: InlineString}
    return read!(s, Ref{T}())[]::T
end

function Base.print(io::IO, x::T) where {T <: InlineString}
    x isa InlineString1 && return print(io, Char(Base.bitcast(UInt8, x)))
    ref = Ref{T}(_bswap(x))
    return GC.@preserve ref begin
        ptr = convert(Ptr{UInt8}, Base.unsafe_convert(Ptr{T}, ref))
        unsafe_write(io, ptr, sizeof(x))
        return
    end
end

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

# Parsers.xparse
function Parsers.xparse(::Type{T}, source::Union{AbstractVector{UInt8}, IO}, pos, len, options::Parsers.Options, ::Type{S}=T)::Parsers.Result{S} where {T <: InlineString, S}
    res = Parsers.xparse(String, source, pos, len, options)
    code = res.code
    overflowed = false
    poslen = res.val
    if Parsers.invalid(code) || Parsers.sentinel(code)
        x = T()
    else
        poslen = res.val
        if T === InlineString1
            if poslen.len != 1
                overflowed = true
                x = T()
            else
                Parsers.fastseek!(source, poslen.pos)
                x = InlineString1(Parsers.peekbyte(source, poslen.pos))
                Parsers.fastseek!(source, pos + res.tlen - 1)
            end
        elseif Parsers.escapedstring(code) || !(source isa AbstractVector{UInt8})
            if poslen.len > (sizeof(T) - 1)
                overflowed = true
                x = T()
            else
                # manually build up InlineString
                i = poslen.pos
                maxi = i + poslen.len
                x = T()
                Parsers.fastseek!(source, i - 1)
                while i < maxi
                    b = Parsers.peekbyte(source, i)
                    if b == options.e
                        i += 1
                        Parsers.incr!(source)
                        b = Parsers.peekbyte(source, i)
                    end
                    x, overflowed = addcodeunit(x, b)
                    i += 1
                    Parsers.incr!(source)
                end
                Parsers.fastseek!(source, maxi)
            end
        else
            vlen = poslen.len
            if vlen > (sizeof(T) - 1)
                # @show T, vlen, sizeof(T)
                overflowed = true
                x = T()
            else
                # @show poslen.pos, vlen
                x = T(source, poslen.pos, vlen)
            end
        end
    end
    if overflowed
        code |= Parsers.OVERFLOW
    end
    return Parsers.Result{S}(code, res.tlen, x)
end
