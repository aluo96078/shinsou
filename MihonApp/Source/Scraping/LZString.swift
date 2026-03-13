import Foundation

/// Swift port of lz-string's decompressFromBase64.
/// Faithfully ported from the original JavaScript: https://github.com/pieroxy/lz-string
enum LZString {
    private static let keyStr = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    private static let baseReverseDic: [Character: Int] = {
        var dic: [Character: Int] = [:]
        for (i, ch) in keyStr.enumerated() {
            dic[ch] = i
        }
        return dic
    }()

    /// Decompress a base64-encoded LZString.
    static func decompressFromBase64(_ input: String) -> String? {
        guard !input.isEmpty else { return nil }

        let chars = Array(input)
        return _decompress(length: chars.count, resetValue: 32) { index in
            if index < chars.count {
                return baseReverseDic[chars[index]] ?? 0
            }
            return 0
        }
    }

    /// Core LZ decompression — direct port of the JS `_decompress` function.
    /// Matches the original structure exactly to avoid subtle logic bugs.
    private static func _decompress(length: Int, resetValue: Int, getNextValue: (Int) -> Int) -> String? {
        var dictionary: [Int: String] = [:]
        var enlargeIn = 4
        var dictSize = 4
        var numBits = 3
        var entry = ""
        var result: [String] = []
        var w = ""

        // Bit-reading state
        var dataVal = getNextValue(0)
        var dataPosition = resetValue
        var dataIndex = 1

        /// Read `n` bits from the stream, assembled LSB-first.
        func readBits(_ n: Int) -> Int {
            var bits = 0
            var power = 1
            for _ in 0..<n {
                let resb = dataVal & dataPosition
                dataPosition >>= 1
                if dataPosition == 0 {
                    dataPosition = resetValue
                    dataVal = getNextValue(dataIndex)
                    dataIndex += 1
                }
                bits |= (resb > 0 ? 1 : 0) * power
                power <<= 1
            }
            return bits
        }

        // Initialise dictionary slots 0-2
        for i in 0..<3 {
            dictionary[i] = String(i)
        }

        // Read first entry type (2 bits)
        let firstType = readBits(2)
        let c: String
        switch firstType {
        case 0:
            c = String(UnicodeScalar(readBits(8))!)
        case 1:
            c = String(UnicodeScalar(readBits(16))!)
        case 2:
            return ""
        default:
            return nil
        }

        dictionary[3] = c
        w = c
        result.append(c)

        // Main loop — matches JS structure exactly
        while true {
            if dataIndex > length {
                return ""
            }

            var cc = readBits(numBits)

            switch cc {
            case 0:
                let ch = String(UnicodeScalar(readBits(8))!)
                dictionary[dictSize] = ch
                dictSize += 1
                cc = dictSize - 1
                enlargeIn -= 1

            case 1:
                let ch = String(UnicodeScalar(readBits(16))!)
                dictionary[dictSize] = ch
                dictSize += 1
                cc = dictSize - 1
                enlargeIn -= 1

            case 2:
                return result.joined()

            default:
                break
            }

            // Common code after switch (JS fall-through)
            if enlargeIn == 0 {
                enlargeIn = 1 << numBits
                numBits += 1
            }

            if let existing = dictionary[cc] {
                entry = existing
            } else if cc == dictSize {
                entry = w + String(w.first!)
            } else {
                return nil
            }

            result.append(entry)

            // Add w + entry[0] to dictionary
            dictionary[dictSize] = w + String(entry.first!)
            dictSize += 1
            enlargeIn -= 1

            if enlargeIn == 0 {
                enlargeIn = 1 << numBits
                numBits += 1
            }

            w = entry
        }
    }
}
