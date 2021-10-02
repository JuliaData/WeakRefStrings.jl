using Test, WeakRefStrings

# convenience constructor for testing
function str(x::Union{Missing, String}, e=nothing)
    data = Vector{UInt8}(x)
    poslen = PosLen(1, sizeof(coalesce(x, "")), x === missing, e !== nothing && UInt8(e) in data)
    return PosLenString(data, poslen, UInt8(something(e, 0x00)))
end

# convenience constructor for testing
function strs(x::Vector, e=nothing)
    len = sum(x -> sizeof(coalesce(x, "")), x)
    data = Vector{UInt8}(undef, len)
    poslens = Vector{PosLen}(undef, length(x))
    pos = 1
    anymissing = false
    for (i, s) in enumerate(x)
        if s !== missing
            slen = sizeof(s)
            bytes = codeunits(s)
            copyto!(data, pos, bytes, 1, slen)
            poslens[i] = PosLen(pos, slen, false, e !== nothing && e in bytes)
            pos += slen
        else
            anymissing = true
            poslens[i] = PosLen(pos, 0, true, false)
        end
    end
    return PosLenStringVector{anymissing ? Union{Missing, PosLenString} : PosLenString}(data, poslens, something(e, 0x00))
end

@testset "PosLenStrings" begin

# PosLen
poslen = PosLen(0, 0, false, false)
@test Base.bitcast(UInt64, poslen) == UInt64(0)

poslen = PosLen(0, 0, true, false)
@test poslen.missingvalue

poslen = PosLen(0, 0, false, true)
@test poslen.escapedvalue

poslen = PosLen(1, 3, false, false)
@test poslen.pos == 1
@test poslen.len == 3

@test_throws ArgumentError PosLen(1, 1048576, false, false)

# PosLenString
for y in ("", "hey", "🍕", "\\\\hey\\\\hey")
    x = str(y, '\\')
    y = unescape_string(y)
    @test codeunits(x) == codeunits(y)
    @test sizeof(x) == sizeof(y)
    @test ncodeunits(x) == ncodeunits(y)
    @test length(x) == length(y)
    @test codeunit(x) == UInt8
    @test lastindex(x) == lastindex(y)
    @test isempty(x) == isempty(y)
    @test String(x) == y
    @test Symbol(x) == Symbol(y)
    @test Vector{UInt8}(x) == Vector{UInt8}(y)
    @test Array{UInt8}(x) == Array{UInt8}(y)
    @test isascii(x) == isascii(y)
    @test x * x == y * y
    @test x^5 == y^5
    @test string(x) == string(y)
    @test join([x, x]) == join([y, y])
    @test reverse(x) == reverse(y)
    y != "" && @test startswith(x, x[1]) == startswith(y, x[1])
    y != "" && @test endswith(x, x[1]) == endswith(y, x[1])
    y != "" && @test findfirst(==(x[1]), x) === findfirst(==(x[1]), y)
    y != "" && @test findlast(==(x[1]), x) === findlast(==(x[1]), y)
    y != "" && @test findnext(==(x[1]), x, 1) === findnext(==(x[1]), y, 1)
    y != "" && @test findprev(==(x[1]), x, length(x)) === findprev(==(x[1]), y, length(x))
    @test lpad(x, 12) == lpad(y, 12)
    @test rpad(x, 12) == rpad(y, 12)
    y != "" && @test replace(x, x[1] => 'a') == replace(y, x[1] => 'a')
    r1 = match(Regex(x), x)
    r2 = match(Regex(y), y)
    @test r1 === r2 || r1.match == r2.match
    for i = 1:ncodeunits(x)
        @test codeunit(x, i) == codeunit(y, i)
        @test isvalid(x, i) == isvalid(y, i)
        @test thisind(x, i) == thisind(y, i)
        @test nextind(x, i) == nextind(y, i)
        @test prevind(x, i) == prevind(y, i)
        @test iterate(x, i) == iterate(y, i)
    end
    for i = 1:length(x)
        if isvalid(x, i)
            @test x[i] == y[i]
        end
    end
    @test x == x
    @test x == y
    @test y == x
    @test hash(x) == hash(y)
    @test cmp(x, x) == 0
    @test cmp(x, y) == 0
    @test cmp(y, x) == 0
end

# PosLenStringVector
x = strs(["hey", "there", "sailor", "esc\"aped"], UInt8('\\'))
@test x == ["hey", "there", "sailor", "esc\"aped"]
@test x[1] == "hey"

x = strs(["hey", "there", "sailor", "esc\"aped", missing], UInt8('\\'))
@test isequal(x, ["hey", "there", "sailor", "esc\"aped", missing])

x = strs(["hey", "there", "sailor", "esc\"aped"], UInt8('"'))
@test x == ["hey", "there", "sailor", "escaped"]
@test isassigned(x, 1)
@test x[1:3] == ["hey", "there", "sailor"]

# https://github.com/JuliaData/InlineStrings.jl/issues/2
x = str("hey")
@test typeof(string(x)) == String

end