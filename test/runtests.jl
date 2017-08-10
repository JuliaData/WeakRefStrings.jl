using WeakRefStrings
using Base.Test

if !isdefined(Core, :String)
    const String = UTF8String
end

data = Vector{UInt8}("hey there sailor")

str = WeakRefString(pointer(data), 3)
str2 = WeakRefString(pointer(data), 3, 1)

@test length(str) == 3
for (i,c) in enumerate(str)
    @test data[i] == c % UInt8
end
@test string(str) == "hey"
@test String(str) == "hey"

@test str == str2

io = IOBuffer()
show(io, str)
@test String(take!(io)) == "\"hey\""

show(io, typeof(str))
@test String(take!(io)) == "WeakRefString{UInt8}"

# simulate UTF16 data
data = reinterpret(UInt16, [0x68, 0x00, 0x65, 0x00, 0x79, 0x00])

str = WeakRefString(pointer(data), 3)
@test typeof(str) == WeakRefString{UInt16}
@test String(str) == "hey"
@test length(str) == 3
for (i,c) in enumerate(str)
    @test data[i] == c % UInt8
end

# simulate UTF32 data with trailing null byte
data = reinterpret(UInt32, [0x68, 0x00, 0x00, 0x00, 0x65, 0x00, 0x00, 0x00, 0x79, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

str = WeakRefString(pointer(data), 4)
@test typeof(str) == WeakRefString{UInt32}
@test String(str) == "hey"
@test length(str) == 4
for (i,c) in enumerate(str)
    @test data[i] == c % UInt8
end

# Verify that the ind field works as expected (as the index in a call to pointer)
data = Vector{UInt8}("some test data")
ptr = pointer(data)
wrs = WeakRefString(ptr, 4)
@test wrs == "some"
@test pointer(data, wrs.ind) == ptr

ptr = pointer(data, 1)
wrs = WeakRefString(ptr, 4, 1)
@test wrs == "some"
@test pointer(data, wrs.ind) == ptr

ptr = pointer(data, 6)
wrs = WeakRefString(ptr, 4, 6)
@test wrs == "test"
@test pointer(data, wrs.ind) == ptr
