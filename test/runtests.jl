using WeakRefStrings, Base.Test

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

A = WeakRefStringArray(data, [str])

# simulate UTF16 data
data = [0x0068, 0x0065, 0x0079]

str = WeakRefString(pointer(data), 3)
@test typeof(str) == WeakRefString{UInt16}
@test String(str) == "hey"
@test length(str) == 3
for (i,c) in enumerate(str)
    @test data[i] == c % UInt8
end

# simulate UTF32 data with trailing null byte
data = [0x00000068, 0x00000065, 0x00000079, 0x00000000]

str = WeakRefString(pointer(data), 4)
@test typeof(str) == WeakRefString{UInt32}
@test String(str) == "hey"
@test length(str) == 4
for (i,c) in enumerate(str)
    @test data[i] == c % UInt8
end

A = WeakRefStringArray(UInt8[], WeakRefString{UInt8}, 10)
@test size(A) == (10,)
@test A[1] == ""
@test A[1, 1] == ""
A[1] = "hey"
A[1, 1] = "hey"
@test A[1] == "hey"
resize!(A, 5)
@test size(A) == (5,)
B = WeakRefStringArray(UInt8[], WeakRefString{UInt8}, 10)
B[1] = "ho"
append!(A, B)
@test size(A) == (15,)
