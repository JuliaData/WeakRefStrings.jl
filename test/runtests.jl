using WeakRefStrings, Base.Test, Nulls

@testset "WeakRefString{UInt8}" begin
    data = Vector{UInt8}("hey there sailor")

    str = WeakRefString(pointer(data), 3)

    @test length(str) == 3
    for (i,c) in enumerate(str)
        @test data[i] == c % UInt8
    end
    @test string(str) == "hey"
    @test String(str) == "hey"

    io = IOBuffer()
    show(io, str)
    @test String(take!(io)) == "\"hey\""

    show(io, typeof(str))
    @test String(take!(io)) == "WeakRefString{UInt8}"
end

@testset "WeakRefString{UInt16}" begin
    # simulate UTF16 data
    data = [0x0068, 0x0065, 0x0079]

    str = WeakRefString(pointer(data), 3)
    @test typeof(str) == WeakRefString{UInt16}
    @test String(str) == "hey"
    @test length(str) == 3
    for (i,c) in enumerate(str)
        @test data[i] == c % UInt8
    end
end

@testset "WeakRefString{UInt32}" begin
    # simulate UTF32 data with trailing null byte
    data = [0x00000068, 0x00000065, 0x00000079, 0x00000000]

    str = WeakRefString(pointer(data), 4)
    @test typeof(str) == WeakRefString{UInt32}
    @test String(str) == "hey"
    @test length(str) == 4
    for (i,c) in enumerate(str)
        @test data[i] == c % UInt8
    end
end

@testset "WeakRefArray" begin
    data = Vector{UInt8}("hey there sailor")
    str = WeakRefString(pointer(data), 3)
    C = WeakRefStringArray(data, [str])
    @test length(C) == 1

    A = WeakRefStringArray(UInt8[], WeakRefString{UInt8}, 10)
    @test size(A) == (10,)
    @test A[1] == ""
    @test A[1, 1] == ""
    A[1] = "hey"
    A[1, 1] = "hey"
    @test A[1] == "hey"
    resize!(A, 5)
    @test size(A) == (5,)
    push!(A, str)
    @test size(A) == (6,)
    @test A[end] == str
    push!(A, "hi")
    @test length(A) == 7
    @test A[end] == convert(WeakRefString{UInt8}, "hi")

    B = WeakRefStringArray(UInt8[], WeakRefString{UInt8}, 10)
    B[1] = "ho"
    append!(A, B)
    @test size(A) == (17,)

    D = WeakRefStringArray(UInt8[], Union{Null, WeakRefString{UInt8}}, 0)
    push!(D, "hey")
    push!(D, str)
    push!(D, null)
    @test length(D) == 3
    @test D[2] == str
    @test D[3] === null
    D[2] = null
    @test D[2] === null
end
