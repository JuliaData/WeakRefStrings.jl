using WeakRefStrings
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
#
# function countlines(io::IO, eol::Char='\n')
#     isascii(eol) || throw(ArgumentError("only ASCII line terminators are supported"))
#     aeol = UInt8(eol)
#     a = Array{UInt8}(8192)
#     nl = 0
#     while !eof(io)
#         nb = readbytes!(io, a)
#         @simd for i=1:nb
#             @inbounds nl += a[i] == aeol
#         end
#     end
#     nl
# end
#
# function countlines(io::IO, eol::Char='\n')
#     isascii(eol) || throw(ArgumentError("only ASCII line terminators are supported"))
#     aeol = UInt8(eol)
#     a = Array{UInt8}(8192)
#     nl = 0
#     while !eof(io)
#         nb = readbytes!(io, a)
#         @simd for i=1:nb
#             @inbounds nl += a[i] == aeol
#         end
#     end
#     nl
# end
#
# function countlines2(file)
#     aeol = UInt8('\n')
#     m = Mmap.mmap(file)
#     ptr = pointer(m)
#     mlen = length(m)
#     nl = 0
#     @simd for i = 1:length(m)
#         nl += unsafe_load(ptr, i) == aeol
#     end
#     return nl
# end
#
# @time countlines("/Users/jacobquinn/Downloads/bids.csv")
# @time countlines2("/Users/jacobquinn/Downloads/bids.csv")
