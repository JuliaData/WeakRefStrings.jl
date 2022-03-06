using WeakRefStrings, Test, Random, Parsers, InlineStrings
using DataAPI: refarray, refvalue

include("poslenstrings.jl")

@testset "WeakRefString{UInt8}" begin
    data = codeunits("hey there sailor")

    str = WeakRefStrings.WeakRefString(pointer(data), 3)

    @test str.len == 3
    @test string(str) == "hey"
    @test String(str) == "hey"
    @test str[1] === 'h'
    @test str[2] === 'e'
    @test str[3] === 'y'

    io = IOBuffer()
    show(io, str)
    @test String(take!(io)) == "\"hey\""

    show(io, typeof(str))
    @test String(take!(io)) == "WeakRefString{UInt8}"
end

@testset "WeakRefString{UInt16}" begin
    # simulate UTF16 data
    data = [0x0068, 0x0065, 0x0079]

    str = WeakRefStrings.WeakRefString(pointer(data), 3)
    @test typeof(str) == WeakRefStrings.WeakRefString{UInt16}
    @test String(str) == "hey"
    @test str.len == 3
end

@testset "WeakRefString{UInt32}" begin
    # simulate UTF32 data with trailing null byte
    data = [0x00000068, 0x00000065, 0x00000079, 0x00000000]

    str = WeakRefStrings.WeakRefString(pointer(data), 4)
    @test typeof(str) == WeakRefStrings.WeakRefString{UInt32}
    @test String(str) == "hey"
    @test str.len == 4
end

@testset "StringVector" begin
    s = "Julia is a name without special letters such as æ, ø, and å. Such letters require more than a single byte when encoded in UTF8"
    @testset "split on $splits" for splits in (['.'], [',', '.', ' '])
        sa     = split(s, splits)
        svinit = StringVector{WeakRefString{UInt8}}(sa)
        @testset "version" for sv in (copy(svinit),
                                   copyto!(similar(svinit), svinit),
                                   convert(StringVector{String}, sa),
                                   StringVector{WeakRefString{UInt8}}(sa))
            @test sa == sv
            @test sort(sa) == sort(sv)
            @test sortperm(sa) == sortperm(sv)
            @test sort!(copy(sa)) == sort(sv)
            @test copy(sv) == sv

            @testset "setindex with WeakRefString" begin
                # important to start with end because of special branch when
                # lengths are empty and setting last element
                tmp = sv[end]
                sv[end] = "🍕"
                @test sv[end] == "🍕"

                sv[end] = tmp
                sv[1]   = sv[1]
                @test sa == sv
            end

            @testset "setindex with String" begin
                sv[1]   = String(sa[1])
                sv[end] = String(sa[end])
                @test sa == sv
            end

            @testset "setindex with missing" begin
                sv1 = StringVector{String}(["foo", "bar"])
                @test_throws MethodError setindex!(sv1, missing, 1)
                sv1 = StringVector{Union{String, Missing}}(["foo", "bar"])
                sv1[1] = missing
                @test sv1[1] === missing
            end

            push!(sv, "🍕") == push!(copy(sa), "🍕")
            @test length(empty!(sv)) == 0
        end
    end

    @testset "resize+index" begin
        sv = StringVector(["JuliaDB", "TextParse"])
        @test resize!(sv, 1)[1] == "JuliaDB"
    end

    @testset "filter regex" begin
        sv = StringVector(["TextParse", "TextParse", "JuliaDB", "TextParse", "TextParse", "TextParse", "TextParse", "JuliaDB", "JuliaDB"])
        sv[end] = "Dagger"
        sv[1] = "Dagger"
        @test length(filter(x->occursin(r"JuliaDB", x), sv)) == 2
    end

    @testset "test WeakRefString element type constructor" begin
        @test eltype(StringVector{WeakRefString}(undef, 1)) <: WeakRefString
    end

    @testset "StringVector constructors" begin
        @test length(StringVector()) == 0
        @test length(StringVector{WeakRefString{UInt8}}()) == 0
        a = StringVector{WeakRefString{UInt8}}(undef, 10)
        @test length(a) == 10
        a = StringVector(undef, 10)
        @test length(a) == 10
        data = Vector{UInt8}("hey there sailor")
        a = StringVector{String}(data, 3)
        a[1] = WeakRefString(pointer(data), 3)
        a[2] = WeakRefString(pointer(data), 3)
        a[3] = WeakRefString(pointer(data), 3)
        @test length(a) == 3
        @test a[1] == "hey"
        @test length(a.buffer) == 16
    end

    @testset "test permute!" begin
        sv = StringVector(["TextParse", "TextParse", "JuliaDB", "TextParse", "TextParse", "TextParse", "TextParse", "JuliaDB", "JuliaDB"])
        permute!(sv, reverse!([1:length(sv);]))
        @test sv[1] == "JuliaDB"
        @test sv[end] == "TextParse"
    end

    @testset "vcat" begin
        sv1 = StringVector{String}(unsafe_wrap(Array, pointer(randstring(1024)), 1024), UInt64[1:10:1000;], ones(UInt32,100)*9);
        sv2 = StringVector{String}(unsafe_wrap(Array, pointer(randstring(1024)), 1024), UInt64[1:10:1000;], ones(UInt32,100)*9);
        sv3 = vcat(sv1, sv2)
        @test length(sv3) == length(sv1) + length(sv2)
    end

    @testset "append!" begin
        sv1 = StringVector{WeakRefString{UInt8}}(["foo", "bar"])
        sv2 = StringVector{String}(["baz", "qux"])

        append!(sv1, sv2)
        @test sv1 == ["foo", "bar", "baz", "qux"]

        append!(sv2, ["yep", "nope"])
        @test sv2 == ["baz", "qux", "yep", "nope"]
    end

    @testset "deleteat!" begin
        sv1 = StringVector{WeakRefString{UInt8}}(["foo", "bar"])
        @test deleteat!(copy(sv1), 1) == ["bar"]
        @test deleteat!(copy(sv1), [1,2]) == []
        @test deleteat!(copy(sv1), 1:2) == []

        sv2 = StringVector{String}(["baz", "qux"])
        @test deleteat!(copy(sv2), 1) == ["qux"]
        @test deleteat!(copy(sv2), [1,2]) == []
        @test deleteat!(copy(sv2), 1:2) == []
    end

    @testset "resize!" begin
        sv1 = StringVector{WeakRefString{UInt8}}(["foo", "bar"])
        resize!(sv1, 0)
        @test length(sv1) == 0
        resize!(sv1, 10)
        @test length(sv1) == 10
    end

    @testset "push!" begin
        sv1 = StringVector{String}(["foo", "bar"])
        push!(sv1, "hey")
        @test length(sv1) == 3
        @test sv1[end] == "hey"
        @test_throws MethodError push!(sv1, missing)
        sv1 = StringVector{Union{String, Missing}}(["foo", "bar"])
        push!(sv1, missing)
        @test length(sv1) == 3
        @test sv1[end] === missing
    end

    @testset "insert!" begin
        sv1 = StringVector{String}(["foo", "bar"])
        insert!(sv1, 2, "hey")
        @test length(sv1) == 3
        @test sv1[2] == "hey"
        @test sv1[3] == "bar"
        @test_throws MethodError insert!(sv1, 2, missing)
        sv1 = StringVector{Union{String, Missing}}(["foo", "bar"])
        insert!(sv1, 2, missing)
        @test sv1[2] === missing
        @test length(sv1) == 3
    end

    @testset "splice!" begin
        sv1 = StringVector{String}(["foo", "bar"])
        v = splice!(sv1, 2)
        @test v == "bar"
        @test length(sv1) == 1
        push!(sv1, "bar")
        v = splice!(sv1, 1:2)
        @test v[1] == "foo"
        @test v[2] == "bar"
        @test length(sv1) == 0
        sv1 = StringVector{String}(["foo", "bar"])
        v = splice!(sv1, 1:2, ["bar", "foo"])
        @test sv1 == reverse(v)
        sv1 = StringVector{String}(["foo", "bar"])
        v = splice!(sv1, 2, ["foo", "foo", "bar"])
        @test length(sv1) == 4
        @test sv1[end] == "bar"
    end

    @testset "prepend!/pushfirst!/pop!/popfirst!" begin
        sv1 = StringVector{String}(["foo", "bar"])
        prepend!(sv1, ["hey", "there"])
        @test length(sv1) == 4
        @test sv1[1] == "hey"
        @test sv1[2] == "there"
        pushfirst!(sv1, "sailor")
        @test length(sv1) == 5
        @test sv1[1] == "sailor"
        v = popfirst!(sv1)
        @test v == "sailor"
        @test length(sv1) == 4
        v = pop!(sv1)
        @test v == "bar"
        @test length(sv1) == 3
    end

    @testset "isassigned" begin
        sv = StringVector{Union{String,Missing}}(undef, 3)
        sv[1] = "foo"
        sv[2] = "bar"
        @test isassigned(sv, 1)
        @test isassigned(sv, 2)
        @test !isassigned(sv, 3)
    end

    @testset "DataAPI" begin
        a = StringVector(["a", "b", "c"])
        v = refarray(a)
        @test all(v .== a)
        @test eltype(v) == WeakRefString{UInt8}
        for i in 1:3
            @test isequal(refvalue(a, v[i]), a[i])
        end

        b = StringVector(["a", "b", missing])
        w = refarray(b)
        @test w[1] == "a"
        @test w[2] == "b"
        @test ismissing(w[3])
        @test eltype(w) == Union{WeakRefString{UInt8}, Missing}
        for i in 1:3
            @test isequal(refvalue(b, w[i]), b[i])
        end
    end
end
