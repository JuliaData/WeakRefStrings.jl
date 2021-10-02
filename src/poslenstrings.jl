@noinline function escapedcodeunits(d, p, e)
    maxpos = Int(p.pos + p.len - 1)
    return [Int(x) for x = p.pos:maxpos if !((x == p.pos && d[x] == e) || (x > p.pos && d[x - 1] != e && d[x] == e))]
end

"""
    PosLenString(buf::Vector{UInt8}, poslen::PosLen, e::UInt8)

A custom string representation that takes a byte buffer (`buf`), `poslen`, and
`e` escape character, and lazily allows treating a region of the `buf` as a string.
Can be used most efficiently as part of a [`PosLenStringVector`](@ref) which only stores
an array of `PosLen` (inline) along with a single `buf` and `e` and returns `PosLenString`
when indexing individual elements.
"""
struct PosLenString <: AbstractString
    data::Vector{UInt8}
    poslen::PosLen
    e::UInt8
    inds::Vector{Int} # only for escaped strings
    
    @inline function PosLenString(d::Vector{UInt8}, p::PosLen, e::UInt8)
        if p.escapedvalue
            return new(d, p, e, escapedcodeunits(d, p, e))
        else
            return new(d, p, e)
        end
    end
end

pos(x::PosLenString) = Int(x.poslen.pos)
len(x::PosLenString) = Int(x.poslen.len)
escaped(x::PosLenString) = x.poslen.escapedvalue

Base.codeunits(x::PosLenString) =
    escaped(x) ? view(x.data, x.inds) : view(x.data, pos(x):(pos(x) + len(x) - 1))

Base.ncodeunits(x::PosLenString) = !escaped(x) ? len(x) : length(x.inds)
Base.codeunit(::PosLenString) = UInt8
Base.@propagate_inbounds function Base.codeunit(x::PosLenString, i::Int)
    @boundscheck checkbounds(Bool, x, i) || throw(BoundsError(x, i))
    poslen = x.poslen
    return @inbounds poslen.escapedvalue ? x.data[x.inds[i]] : x.data[poslen.pos + i - 1]
end

Base.pointer(x::PosLenString, i::Integer=1) = pointer(x.data, pos(x) + i - 1)

# Base.string(x::PosLenString) = x
PosLenString(x::PosLenString) = x
_unsafe_string(p, len) = ccall(:jl_pchar_to_string, Ref{String}, (Ptr{UInt8}, Int), p, len)
Base.String(x::PosLenString) =
    !escaped(x) ? _unsafe_string(pointer(x), len(x)) : String(codeunits(x))
Base.Vector{UInt8}(x::PosLenString) =
    !escaped(x) ? x.data[pos(x):(pos(x) + len(x) - 1)] : copy(codeunits(x))
Base.Array{UInt8}(x::PosLenString) = Vector{UInt8}(x)
Base.Symbol(x::PosLenString) =
    escaped(x) ? Symbol(String(x)) : ccall(:jl_symbol_n, Ref{Symbol}, (Ptr{UInt8}, Int), pointer(x), len(x))

function ==(x::PosLenString, y::PosLenString)
    l = ncodeunits(x)
    l == ncodeunits(y) || return false
    if !escaped(x) && !escaped(y)
        return ccall(:memcmp, Cint, (Ptr{UInt8}, Ptr{UInt8}, Csize_t),
                     pointer(x), pointer(y), l) == 0
    end
    # escaped string path
    for i = 1:l
        codeunit(x, i) == codeunit(y, i) || return false
    end
    return true
end

function ==(x::String, y::PosLenString)
    sizeof(x) == sizeof(y) || return false
    if !escaped(y)
        ccall(:memcmp, Cint, (Ptr{UInt8}, Ptr{UInt8}, Csize_t),
              pointer(x), pointer(y), sizeof(x)) == 0
    end
    # escaped string path
    for i = 1:sizeof(y)
        codeunit(x, i) == codeunit(y, i) || return false
    end
    return true
end
==(y::PosLenString, x::String) = x == y

function Base.cmp(a::PosLenString, b::PosLenString)
    al, bl = len(a), len(b)
    if !escaped(a) && !escaped(b)
        c = ccall(:memcmp, Int32, (Ptr{UInt8}, Ptr{UInt8}, Csize_t),
                  pointer(a), pointer(b), min(al, bl))
        return c < 0 ? -1 : c > 0 ? +1 : cmp(al, bl)
    end
    # TODO: could be faster by looping directly through codeunits
    return cmp(codeunits(a), codeunits(b))
end

function Base.hash(s::PosLenString, h::UInt)
    h += Base.memhash_seed
    if !escaped(s)
        ccall(Base.memhash, UInt, (Ptr{UInt8}, Csize_t, UInt32), pointer(s), len(s), h % UInt32) + h
    else
        # TODO: this is expensive, even for rare escaped PosLenString
        # this makes it about 4x slower than hash(::String)
        # alternative is to maybe take what's needed from MurmurHash3.jl to operate by codeunit
        x = copy(codeunits(s))
        ccall(Base.memhash, UInt, (Ptr{UInt8}, Csize_t, UInt32), pointer(x), sizeof(x), h % UInt32) + h
    end
end

function Base.write(io::IO, x::PosLenString)
    if !escaped(x)
        return GC.@preserve x Int(unsafe_write(io, pointer(x), reinterpret(UInt, sizeof(x))))::Int
    end
    len = ncodeunits(x)
    for i = 1:len
        @inbounds write(io, codeunit(x, i))
    end
    return len
end

# optimize IOBuffer case; modified copy/paste from iobuffer.jl
function Base.write(io::IOBuffer, x::PosLenString)
    if !escaped(x)
        return GC.@preserve x Int(unsafe_write(io, pointer(x), reinterpret(UInt, sizeof(x))))::Int
    end
    nb = ncodeunits(x)
    Base.ensureroom(io, nb)
    ptr = (io.append ? io.size+1 : io.ptr)
    written = Int(min(nb, Int(length(io.data))::Int - ptr + 1))
    iowrite = written
    d = io.data
    p = 1
    while iowrite > 0
        @inbounds d[ptr] = codeunit(x, p)
        ptr += 1
        p += 1
        iowrite -= 1
    end
    io.size = max(io.size, ptr - 1)
    if !io.append
        io.ptr += written
    end
    return written
end
Base.print(io::IO, s::PosLenString) = (write(io, s); nothing)

# copy/pasted from substring.jl
function Base.reverse(s::PosLenString)
    # Read characters forwards from `s` and write backwards to `out`
    out = Base._string_n(sizeof(s))
    offs = sizeof(s) + 1
    for c in s
        offs -= ncodeunits(c)
        Base.__unsafe_string!(out, c, offs)
    end
    return out
end

@inline function Base.__unsafe_string!(out, s::PosLenString, offs::Integer)
    n = sizeof(s)
    if !escaped(s)
        GC.@preserve s out unsafe_copyto!(pointer(out, offs), pointer(s), n)
    else
        for i = 1:n
            @inbounds unsafe_store!(pointer(out, offs + i - 1), codeunit(s, i))
        end
    end
    return n
end

const BaseStrs = Union{Char, String, SubString{String}}
Base.string(a::PosLenString) = String(a)
Base.string(a::PosLenString...) = _string(a...)
Base.string(a::BaseStrs, b::PosLenString) = _string(a, b)
Base.string(a::BaseStrs, b::BaseStrs, c::PosLenString) = _string(a, b, c)
@inline function _string(a::Union{BaseStrs, PosLenString}...)
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

function Base.repeat(s::PosLenString, r::Integer)
    r < 0 && throw(ArgumentError("can't repeat a string $r times"))
    r == 0 && return ""
    r == 1 && return s
    n = sizeof(s)
    out = Base._string_n(n * r)
    if n == 1 # common case: repeating a single-byte string
        @inbounds b = codeunit(s, 1)
        ccall(:memset, Ptr{Cvoid}, (Ptr{UInt8}, Cint, Csize_t), out, b, r)
    else
        for i = 0:r-1
            if !escaped(s)
                GC.@preserve s out unsafe_copyto!(pointer(out, i * n + 1), pointer(s), n)
            else
                for j = 1:n
                    @inbounds unsafe_store!(pointer(out, i * n + j), codeunit(s, j))
                end
            end
        end
    end
    return out
end

# copy/pasted from strings/util.jl
function Base.startswith(a::PosLenString, b::Union{String, SubString{String}, PosLenString})
    cub = ncodeunits(b)
    if ncodeunits(a) < cub
        false
    elseif !escaped(a) && Base._memcmp(a, b, sizeof(b)) == 0
        nextind(a, cub) == cub + 1
    elseif escaped(a)
        for i = 1:cub
            codeunit(a, i) == codeunit(b, i) || return false
        end
        return true
    else
        false
    end
end

function Base.endswith(a::PosLenString, b::Union{String, SubString{String}, PosLenString})
    cub = ncodeunits(b)
    astart = ncodeunits(a) - ncodeunits(b) + 1
    if astart < 1
        false
    elseif !escaped(a) && GC.@preserve(a, Base._memcmp(pointer(a, astart), b, sizeof(b))) == 0
        thisind(a, astart) == astart
    elseif escaped(a)
        for (j, i) = enumerate(astart:cub)
            codeunit(a, i) == codeunit(b, j) || return false
        end
        return true
    else
        false
    end
end

Base.match(r::Regex, s::PosLenString, i::Integer) = match(r, String(s), i)

@static if VERSION >= v"1.7"
    const lpadlen = textwidth
else
    const lpadlen = length
end

function Base.lpad(s::PosLenString, n::Integer, p::Union{AbstractChar, AbstractString, PosLenString}=' ')
    n = Int(n)::Int
    m = signed(n) - Int(lpadlen(s))::Int
    m ≤ 0 && return s
    l = lpadlen(p)
    q, r = divrem(m, l)
    r == 0 ? string(p^q, s) : string(p^q, first(p, r), s)
end

function Base.rpad(s::PosLenString, n::Integer, p::Union{AbstractChar, AbstractString, PosLenString}=' ')
    n = Int(n)::Int
    m = signed(n) - Int(lpadlen(s))::Int
    m ≤ 0 && return s
    l = lpadlen(p)
    q, r = divrem(m, l)
    r == 0 ? string(s, p^q) : string(s, p^q, first(p, r))
end

# the rest of these methods are copy/pasted from Base strings/string.jl file
# for efficiency
Base.@propagate_inbounds function Base.isvalid(x::PosLenString, i::Int)
    @boundscheck checkbounds(Bool, x, i) || throw(BoundsError(x, i))
    return @inbounds thisind(x, i) == i
end

Base.@propagate_inbounds function Base.thisind(s::PosLenString, i::Int)
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

Base.@propagate_inbounds function Base.nextind(s::PosLenString, i::Int)
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

Base.@propagate_inbounds function Base.iterate(s::PosLenString, i::Int=firstindex(s))
    (i % UInt) - 1 < ncodeunits(s) || return nothing
    b = @inbounds codeunit(s, i)
    u = UInt32(b) << 24
    Base.between(b, 0x80, 0xf7) || return reinterpret(Char, u), i+1
    return iterate_continued(s, i, u)
end

function iterate_continued(s::PosLenString, i::Int, u::UInt32)
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

Base.@propagate_inbounds function Base.getindex(s::PosLenString, i::Int)
    b = codeunit(s, i)
    u = UInt32(b) << 24
    Base.between(b, 0x80, 0xf7) || return reinterpret(Char, u)
    return getindex_continued(s, i, u)
end

function getindex_continued(s::PosLenString, i::Int, u::UInt32)
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

Base.length(s::PosLenString) = length_continued(s, 1, ncodeunits(s), ncodeunits(s))

Base.@propagate_inbounds function Base.length(s::PosLenString, i::Int, j::Int)
    @boundscheck begin
        0 < i ≤ ncodeunits(s)+1 || throw(BoundsError(s, i))
        0 ≤ j < ncodeunits(s)+1 || throw(BoundsError(s, j))
    end
    j < i && return 0
    @inbounds i, k = thisind(s, i), i
    c = j - i + (i == k)
    length_continued(s, i, j, c)
end

@inline function length_continued(s::PosLenString, i::Int, n::Int, c::Int)
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

# custom array type that returns PosLenStrings on index
# copy:
  # calcs total len of all strings in poslens
  # allocates fresh data byte buffer for total len
  # loops through and copies each strings data into new buffer, recalcs poslen
"""
    PosLenStringVector{T}(data, poslens, e=UInt8('\\'))

Custom array 
"""
struct PosLenStringVector{T} <: AbstractVector{T}
    data::Vector{UInt8}
    poslens::Vector{PosLen}
    e::UInt8
end

Base.IndexStyle(::Type{PosLenStringVector}) = Base.IndexLinear()
Base.size(x::PosLenStringVector) = (length(x.poslens),)

Base.@propagate_inbounds function Base.getindex(x::PosLenStringVector{T}, i::Int) where {T}
    @boundscheck checkbounds(x, i)
    @inbounds poslen = x.poslens[i]
    T === Union{Missing, PosLenString} && poslen.missingvalue && return missing
    return PosLenString(x.data, poslen, x.e)
end

Base.isassigned(x::PosLenStringVector, i::Int) = true

Base.@propagate_inbounds function Base.getindex(x::PosLenStringVector{T}, inds::AbstractVector) where {T}
    A = PosLenStringVector{T}(x.data, x.poslens[inds], x.e)
    return A
end

Base.@propagate_inbounds function Base.setindex!(x::PosLenStringVector, v::PosLenString, i::Int)
    @boundscheck checkbounds(x, i)
    @assert x.data === v.data
    @inbounds x.poslens[i] = v.poslen
    return v
end

Base.@propagate_inbounds function Base.setindex!(x::PosLenStringVector, v::Missing, i::Int)
    @boundscheck checkbounds(x, i)
    @inbounds x.poslens[i] = MISSING_BIT
    return v
end

Base.similar(x::PosLenStringVector{T}) where {T} = similar(x, T, length(x))
Base.similar(x::PosLenStringVector{T}, len::Base.DimOrInd) where {T} = similar(x, T, len)
function Base.similar(x::PosLenStringVector{T}, ::Type{S}, len::Base.DimOrInd) where {T, S}
    @assert S == PosLenString || S == Union{Missing, PosLenString}
    poslens = Vector{PosLen}(undef, len)
    return PosLenStringVector{S}(x.data, poslens, x.e)
end

Base.copyto!(dest::PosLenStringVector, src::AbstractVector) =
    copyto!(dest, 1, src, 1, length(src))
Base.copyto!(dest::PosLenStringVector, doffs::Union{Signed, Unsigned}, src::AbstractVector) =
    copyto!(dest, doffs, src, 1, length(src))
Base.copyto!(dest::PosLenStringVector, doffs::Union{Signed, Unsigned}, src::AbstractVector, soffs::Union{Signed, Unsigned}) =
    copyto!(dest, doffs, src, soffs, length(src) - soffs + 1)

@noinline mismatchedbuffers() = throw(ArgumentError("dest data buffer must be same buffer as source PosLenStrings"))

function Base.copyto!(dest::PosLenStringVector{T}, doffs::Union{Signed, Unsigned},
    src::Union{AbstractVector{PosLenString}, AbstractVector{Union{Missing, PosLenString}}},
    soffs::Union{Signed, Unsigned}, n::Union{Signed, Unsigned}) where {T}
    (doffs > 0 && (doffs + n - 1) <= length(dest) &&
    soffs > 0 && (soffs + n - 1) <= length(src)) || throw(BoundsError("copyto! on PosLenStringVector"))
    data = dest.data
    poslens = dest.poslens
    @inbounds for i = 1:n
        s = src[soffs + i - 1]
        if s === missing
            poslens[doffs + i - 1] = MISSING_BIT
        else
            s.data === data || mismatchedbuffers()
            poslens[doffs + i - 1] = s.poslen
        end
    end
    return dest
end
