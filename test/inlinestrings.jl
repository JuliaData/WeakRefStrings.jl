using Test, WeakRefStrings, Parsers
import Parsers: SENTINEL, OK, EOF, OVERFLOW, QUOTED, DELIMITED, INVALID_QUOTED_FIELD, ESCAPED_STRING, NEWLINE, SUCCESS, peekbyte, incr!, checksentinel, checkdelim, checkcmtemptylines

@testset "InlineString basics" begin

y = "abcdef"
x = InlineString(y)
x, overflow = WeakRefStrings.addcodeunit(x, UInt8('g'))
@test !overflow
@test x == "abcdefg"
x, overflow = WeakRefStrings.addcodeunit(x, UInt8('g'))
@test overflow

x = InlineString("abc")
@test x == InlineString7(x) == InlineString15(x) == InlineString31(x) == InlineString63(x)
@test x == InlineString127(x) == InlineString255(x)
y = InlineString7(x)
@test InlineString3(y) == x
@test_throws ArgumentError InlineString3(InlineString("abcd"))
@test_throws ArgumentError InlineString1(InlineString("ab"))
x = InlineString("a")
y = InlineString7(x)
@test x == y
@test InlineString1(y) == x
@test InlineString1(x) == x

@test promote_type(InlineString1, InlineString3) === InlineString3
@test promote_type(InlineString1, InlineString255) === InlineString255
@test promote_type(InlineString31, InlineString127) === InlineString127
@test promote_type(InlineString255, InlineString7) === InlineString255
@test promote_type(InlineString63, InlineString15) === InlineString63

# Ensure we haven't caused ambiguity with Base.
# https://discourse.julialang.org/t/having-trouble-implementating-a-tables-jl-row-table-when-using-badukgoweiqitools-dataframe-tbl-no-longer-works/63622/1
@test promote_type(Union{}, String) == String

end # @testset

@testset "InlineString operations" begin
    for y in ("",  "🍕", "a", "a"^3, "a"^7, "a"^15, "a"^31, "a"^63, "a"^127, "a"^255)
        x = InlineString(y)
        @show typeof(x)
        @test codeunits(x) == codeunits(y)
        @test sizeof(x) == sizeof(y)
        @test ncodeunits(x) == ncodeunits(y)
        @test length(x) == length(y)
        @test codeunit(x) == UInt8
        @test lastindex(x) == lastindex(y)
        @test isempty(x) == isempty(y)
        @test String(x) === y
        @test Symbol(x) == Symbol(y)
        @test Vector{UInt8}(x) == Vector{UInt8}(y)
        @test Array{UInt8}(x) == Array{UInt8}(y)
        @test isascii(x) == isascii(y)
        @test x * x == y * y
        @test x^5 == y^5
        @test string(x) == string(y)
        @test join([x, x]) == join([y, y])
        @test reverse(x) == reverse(y)
        y != "" && @test startswith(x, "a") == startswith(y, "a")
        y != "" && @test endswith(x, "a") == endswith(y, "a")
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

@testset "InlineString parsing" begin
testcases = [
    ("", InlineString7(""), NamedTuple(), OK | EOF),
    (" ", InlineString7(" "), NamedTuple(), OK | EOF),
    (" \"", InlineString7(), NamedTuple(), OK | QUOTED | EOF | INVALID_QUOTED_FIELD), # invalid quoted
    (" \"\" ", InlineString7(), NamedTuple(), OK | QUOTED | EOF), # quoted
    (" \" ", InlineString7(), NamedTuple(), OK | QUOTED | INVALID_QUOTED_FIELD | EOF), # invalid quoted
    (" \" \" ", InlineString7(" "), NamedTuple(), OK | QUOTED | EOF), # quoted
    ("NA", InlineString7(), (; sentinel=["NA"]), EOF | SENTINEL), # sentinel
    ("\"\"", InlineString7(), NamedTuple(), OK | QUOTED | EOF), # same e & cq
    ("\"\",", InlineString7(), NamedTuple(), OK | QUOTED | EOF | DELIMITED), # same e & cq
    ("\"\"\"\"", InlineString7("\""), NamedTuple(), OK | QUOTED | ESCAPED_STRING | EOF), # same e & cq
    ("\"\\", InlineString7(), (; escapechar=UInt8('\\')), OK | QUOTED | INVALID_QUOTED_FIELD | EOF), # \\ e, invalid quoted
    ("\"\\\"\"", InlineString7("\""), (; escapechar=UInt8('\\')), OK | QUOTED | ESCAPED_STRING | EOF), # \\ e, valid
    ("\"\"", InlineString7(), (; escapechar=UInt8('\\')), OK | QUOTED | EOF), # diff e & cq
    ("\"a", InlineString7(), NamedTuple(), OK | QUOTED | INVALID_QUOTED_FIELD | EOF), # invalid quoted
    ("\"a\"", InlineString7("a"), NamedTuple(), OK | QUOTED | EOF), # quoted
    ("\"a\" ", InlineString7("a"), NamedTuple(), OK | QUOTED | EOF), # quoted
    ("\"a\",", InlineString7("a"), NamedTuple(), OK | QUOTED | EOF | DELIMITED), # quoted
    ("a,", InlineString7("a"), NamedTuple(), OK | EOF | DELIMITED),
    ("a__", InlineString7("a"), (; delim="__"), OK | EOF | DELIMITED),
    ("a,", InlineString7("a"), (; ignorerepeated=true), OK | EOF | DELIMITED),
    ("a__", InlineString7("a"), (; delim="__", ignorerepeated=true), OK | EOF | DELIMITED),
    ("a\n", InlineString7("a"), (; ignorerepeated=true), OK | NEWLINE | EOF),
    ("a\r", InlineString7("a"), (; ignorerepeated=true), OK | NEWLINE | EOF),
    ("a\r\n", InlineString7("a"), (; ignorerepeated=true), OK | NEWLINE | EOF),
    ("a", InlineString7("a"), (; ignorerepeated=true), OK | EOF),
    ("a,,\n", InlineString7("a"), (; ignorerepeated=true), OK | DELIMITED | NEWLINE | EOF),
    ("a\n", InlineString7("a"), (; delim="__", ignorerepeated=true), OK | NEWLINE | EOF),
    ("a\r", InlineString7("a"), (; delim="__", ignorerepeated=true), OK | NEWLINE | EOF),
    ("a\r\n", InlineString7("a"), (; delim="__", ignorerepeated=true), OK | NEWLINE | EOF),
    ("a", InlineString7("a"), (; delim="__", ignorerepeated=true), OK | EOF),
    ("a____\n", InlineString7("a"), (; delim="__", ignorerepeated=true), OK | DELIMITED | NEWLINE | EOF),
    ("a\n", InlineString7("a"), NamedTuple(), OK | NEWLINE | EOF),
    ("a\r", InlineString7("a"), NamedTuple(), OK | NEWLINE | EOF),
    ("a\r\n", InlineString7("a"), NamedTuple(), OK | NEWLINE | EOF),
    ("abcdefg", InlineString7("abcdefg"), (; delim=nothing), OK | EOF),
    ("", InlineString7(), (; sentinel=missing), SENTINEL | EOF),
]

for (i, case) in enumerate(testcases)
    println("testing case = $i")
    buf, check, opts, checkcode = case
    res = Parsers.xparse(InlineString7, buf; opts...)
    @test check === res.val
    @test checkcode == res.code
end

res = Parsers.xparse(InlineString1, "")
@test Parsers.overflow(res.code)
res = Parsers.xparse(InlineString1, "ab")
@test Parsers.overflow(res.code)
res = Parsers.xparse(InlineString1, "b")
@test res.val === InlineString("b")

end # @testset
