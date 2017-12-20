using WeakRefStrings, Base.Test, Missings

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
    @test length(str) == 3
    for (i,c) in enumerate(str)
        @test data[i] == c % UInt8
    end
end

@testset "WeakRefArray" begin
    data = Vector{UInt8}("hey there sailor")
    str = WeakRefString(pointer(data), 3)
    C = WeakRefStringArray(data, [str])
    @test size(C) == (1,)
    @test eltype(C) === String

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
    @test_throws MethodError setindex!(B, missing, 1)
    @test_throws MethodError push!(B, missing)

    D = WeakRefStringArray(UInt8[], Union{Missing, WeakRefString{UInt8}}, 0)
    push!(D, "hey")
    push!(D, str)
    push!(D, missing)
    @test size(D) == (3,)
    @test D[2] == str
    @test D[3] === missing
    D[2] = missing
    @test D[2] === missing
    @test_throws MethodError append!(A, D)
    @test_broken size(A) == (17,) # append!() changes the size of A

    E = WeakRefStringArray(data, [str missing])
    @test size(E) == (1, 2)
    @test eltype(E) === Union{String, Missing}

    # WeakRefStringArray only supports WeakRefString elements
    @test_throws MethodError WeakRefStringArray(UInt8[], String, 0)
    @test_throws MethodError WeakRefStringArray(UInt8[], Int, 0)
    @test_throws MethodError WeakRefStringArray(UInt8[], Union{String, Missing}, 0)
    @test_throws MethodError WeakRefStringArray(UInt8[], Union{Int, Missing}, 0)
    @test_throws MethodError WeakRefStringArray(UInt8[], [1, 2])
    @test_throws MethodError WeakRefStringArray(UInt8[], [1.0, missing])
end
