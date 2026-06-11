import Foundation

enum Keccak {
    static func sha3_256(_ data: Data) -> Data {
        digest(data, rate: 136, outputLength: 32)
    }

    static func sha3_512(_ data: Data) -> Data {
        digest(data, rate: 72, outputLength: 64)
    }

    private static let roundConstants: [UInt64] = [
        0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
        0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
        0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
        0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
        0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
        0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
    ]

    private static let rotationOffsets: [Int] = [
        0, 1, 62, 28, 27, 36, 44, 6, 55, 20, 3, 10, 43,
        25, 39, 41, 45, 15, 21, 8, 18, 2, 61, 56, 14,
    ]

    private static func digest(_ data: Data, rate: Int, outputLength: Int) -> Data {
        var state = [UInt64](repeating: 0, count: 25)
        let bytes = [UInt8](data)

        var offset = 0
        while bytes.count - offset >= rate {
            absorb(bytes, from: offset, count: rate, into: &state)
            keccakF(&state)
            offset += rate
        }

        var block = [UInt8](repeating: 0, count: rate)
        block.replaceSubrange(0..<(bytes.count - offset), with: bytes[offset...])
        block[bytes.count - offset] ^= 0x06
        block[rate - 1] ^= 0x80
        absorb(block, from: 0, count: rate, into: &state)
        keccakF(&state)

        var output = [UInt8](repeating: 0, count: outputLength)
        for i in 0..<outputLength {
            output[i] = UInt8(truncatingIfNeeded: state[i / 8] >> (8 * (i % 8)))
        }
        return Data(output)
    }

    private static func absorb(_ bytes: [UInt8], from offset: Int, count: Int, into state: inout [UInt64]) {
        for i in 0..<(count / 8) {
            var lane: UInt64 = 0
            for j in 0..<8 {
                lane |= UInt64(bytes[offset + i * 8 + j]) << (8 * j)
            }
            state[i] ^= lane
        }
    }

    private static func keccakF(_ a: inout [UInt64]) {
        for round in 0..<24 {
            var c = [UInt64](repeating: 0, count: 5)
            for x in 0..<5 {
                c[x] = a[x] ^ a[x + 5] ^ a[x + 10] ^ a[x + 15] ^ a[x + 20]
            }
            for x in 0..<5 {
                let d = c[(x + 4) % 5] ^ rotl(c[(x + 1) % 5], 1)
                for y in stride(from: 0, to: 25, by: 5) {
                    a[x + y] ^= d
                }
            }

            var b = [UInt64](repeating: 0, count: 25)
            for x in 0..<5 {
                for y in 0..<5 {
                    b[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(a[x + 5 * y], rotationOffsets[x + 5 * y])
                }
            }

            for y in stride(from: 0, to: 25, by: 5) {
                for x in 0..<5 {
                    a[y + x] = b[y + x] ^ (~b[y + (x + 1) % 5] & b[y + (x + 2) % 5])
                }
            }

            a[0] ^= roundConstants[round]
        }
    }

    private static func rotl(_ value: UInt64, _ amount: Int) -> UInt64 {
        amount == 0 ? value : (value << amount) | (value >> (64 - amount))
    }
}
