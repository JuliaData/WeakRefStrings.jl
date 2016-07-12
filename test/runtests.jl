using WeakRefStrings, LegacyStrings
using Base.Test

data = "hey there sailor".data

str = WeakRefString(pointer(data), 3)
@test length(str) == 3
for (i,c) in enumerate(str)
    @test data[i] == c % UInt8
end
@test string(str) == "hey"
@test convert(UTF16String, str) == UTF16String("hey")
@test convert(UTF32String, str) == UTF32String("hey")
