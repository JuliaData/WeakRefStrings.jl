using Test, WeakRefStrings

@testset "PosLenStrings" begin

# PosLen
poslen = PosLen(0, 0, true, false)
@test WeakRefStrings.missingvalue(poslen)

poslen = PosLen(0, 0, false, true)
@test WeakRefStrings.escapedvalue(poslen)

poslen = PosLen(1, 3, false, false)
@test WeakRefStrings.getpos(poslen) == 1
@test WeakRefStrings.getlen(poslen) == 3

@test_throws ArgumentError PosLen(1, 1048576, false, false)

# PosLenString
for y in ("", "hey", "🍕", "\\\\hey\\\\hey")
    x = WeakRefStrings.str(y, '\\')
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



end