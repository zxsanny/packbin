/// Message error correction (contract `message-ecc.md` v1.0.0): a Reed-Solomon code over GF(256) with the
/// field polynomial 0x11D, alpha = 2 and generator roots alpha^0 ... alpha^(n-1). The code covers one byte
/// that is not sent, the clear length, placed before the clear message.
enum Ecc {
    /// The most parity bytes a scheme declares.
    static let maxParity = 32
    /// Sent bytes: the code word is 255, one byte of it (the clear length) is not sent.
    static let maxBlock = 254

    /// `exp[i]` is alpha^i, twice around the cycle so a sum of two logs needs no reduction.
    private static let exp: [Int] = field.exp
    /// `log[x]` is the power of alpha that gives `x` (`log[0]` is unused).
    private static let log: [Int] = field.log

    private static let field: (exp: [Int], log: [Int]) = {
        var exp = [Int](repeating: 0, count: 512)
        var log = [Int](repeating: 0, count: 256)
        var x = 1
        for i in 0..<255 {
            exp[i] = x
            log[x] = i
            x <<= 1
            if x & 0x100 != 0 { x ^= 0x11D }
        }
        for i in 255..<512 {
            exp[i] = exp[i - 255]
        }
        return (exp, log)
    }()

    /// The generator of each parity count 0...32, monic, highest degree first.
    private static let generators: [[Int]] = (0...maxParity).map { n in
        var g = [1]
        for i in 0..<n {
            var next = [Int](repeating: 0, count: g.count + 1)
            for (j, c) in g.enumerated() {
                next[j] ^= c
                next[j + 1] ^= mul(c, exp[i])
            }
            g = next
        }
        return g
    }

    private static func mul(_ a: Int, _ b: Int) -> Int {
        a == 0 || b == 0 ? 0 : exp[log[a] + log[b]]
    }

    /// The inverse of a non-zero `a`.
    private static func inv(_ a: Int) -> Int { exp[255 - log[a]] }

    static func checkParity(_ n: Int) throws {
        guard (0...maxParity).contains(n) else {
            throw PackbinError.scheme(nil, "parity", "parity: expected 0..\(maxParity) parity bytes, got \(n)")
        }
    }

    static func checkLimit(_ t: Int, _ n: Int) throws {
        guard (0...(n / 2)).contains(t) else {
            throw PackbinError.scheme(nil, "limit", "correction limit: expected 0..\(n / 2) for \(n) parity bytes, got \(t)")
        }
    }

    /// The parity every scheme of one unpack declares: schemes with different counts could not share one
    /// repair. `limit` is checked against it, before any byte is read.
    static func sharedParity(_ schemes: [Scheme], limit: Int) throws -> Int {
        let n = schemes.first?.parity ?? 0
        if let other = schemes.first(where: { $0.parity != n }) {
            throw PackbinError.scheme(nil, "parity",
                "schemes declare \(n) and \(other.parity) parity bytes; they must declare the same count")
        }
        try checkLimit(limit, n)
        return n
    }

    /// A clear message above 254 - n bytes is refused, naming its length and the limit.
    static func checkSize(_ length: Int, _ n: Int) throws {
        guard n > 0, length > maxBlock - n else { return }
        throw PackbinError.pack(nil, "", "the packet would be \(length) bytes, above the limit of \(maxBlock - n) bytes "
            + "for \(n) parity bytes")
    }

    /// The clear message followed by its `n` parity bytes (`n` already checked, 0...32).
    static func protect(_ clear: [UInt8], parity n: Int) throws -> [UInt8] {
        guard n > 0 else { return clear }
        try checkSize(clear.count, n)
        let g = generators[n]
        let size = clear.count
        var rem = [Int](repeating: 0, count: size + 1 + n)
        rem[0] = size
        for i in 0..<size {
            rem[i + 1] = Int(clear[i])
        }
        for i in 0...size where rem[i] != 0 {
            let lc = log[rem[i]]
            for j in 1...n where g[j] != 0 {
                rem[i + j] ^= exp[log[g[j]] + lc]
            }
        }
        var out = clear
        out.reserveCapacity(size + n)
        for i in (size + 1)..<(size + 1 + n) {
            out.append(UInt8(truncatingIfNeeded: rem[i]))
        }
        return out
    }

    /// The syndromes of the code word: the clear length (word length minus n), then the word.
    private static func syndromes(_ word: [UInt8], _ n: Int) -> [Int] {
        let length = word.count - n
        var out = [Int](repeating: 0, count: n)
        for i in 0..<n {
            var s = length
            for b in word {
                s = (s == 0 ? 0 : exp[log[s] + i]) ^ Int(b)
            }
            out[i] = s
        }
        return out
    }

    /// `p` (lowest degree first) at `x`.
    private static func evaluate(_ p: [Int], _ x: Int) -> Int {
        var y = 0
        for c in p.reversed() {
            y = mul(y, x) ^ c
        }
        return y
    }

    /// Berlekamp-Massey: the error locator, lowest degree first, trimmed.
    private static func locator(_ synd: [Int], _ n: Int) -> [Int] {
        var lam = [1]
        var prev = [1]
        var l = 0
        var m = 1
        var b = 1
        for r in 0..<n {
            var d = synd[r]
            for i in stride(from: 1, through: l, by: 1) where i < lam.count && r - i >= 0 {
                d ^= mul(lam[i], synd[r - i])
            }
            if d == 0 {
                m += 1
                continue
            }
            let before = lam
            let coef = mul(d, inv(b))
            while lam.count < prev.count + m {
                lam.append(0)
            }
            for (i, c) in prev.enumerated() {
                lam[i + m] ^= mul(coef, c)
            }
            if 2 * l <= r {
                l = r + 1 - l
                prev = before
                b = d
                m = 1
            } else {
                m += 1
            }
        }
        while lam.count > 1, lam[lam.count - 1] == 0 {
            lam.removeLast()
        }
        return lam
    }

    /// Checks `received` against `n` parity bytes and repairs up to `t` wrong bytes; `n` and `t` are the
    /// caller's and are checked first (`sharedParity`). Never traps on hostile bytes: a message that cannot
    /// be read throws a `PackbinError` (`.short`, `.tooMany`, `.uncorrectable`). The input is never written.
    static func repair(_ received: [UInt8], parity n: Int, limit t: Int) throws -> (clear: [UInt8], repaired: Int) {
        guard n > 0 else { return (received, 0) }
        let size = received.count
        if size > maxBlock {
            throw PackbinError(.tooMany, field: nil, left: size,
                               reason: "the message is \(size) bytes, above the limit of \(maxBlock) bytes")
        }
        if size < n { throw PackbinError.shortPacket(nil, "parity", needed: n, left: size) }
        let synd = syndromes(received, n)
        if synd.allSatisfy({ $0 == 0 }) { return (Array(received[0..<(size - n)]), 0) }
        guard t > 0 else { throw PackbinError.uncorrectable }
        let lam = locator(synd, n)
        let degree = lam.count - 1
        guard degree >= 1, degree <= t else { throw PackbinError.uncorrectable }
        // Position p (0 = first byte sent) has locator X = alpha^(size-1-p); the unsent length byte is one
        // place before it, and a root there makes the count differ.
        var roots: [Int] = []
        for p in 0..<size where evaluate(lam, exp[(255 - (size - 1 - p)) % 255]) == 0 {
            roots.append(p)
        }
        guard roots.count == degree else { throw PackbinError.uncorrectable }
        // The error evaluator omega = (synd * lam) mod x^n, lowest degree first.
        var omega = [Int](repeating: 0, count: n)
        for i in 0..<n {
            for (j, c) in lam.enumerated() where i + j < n {
                omega[i + j] ^= mul(synd[i], c)
            }
        }
        // The derivative in characteristic 2 keeps the odd-degree terms.
        var dlam: [Int] = []
        for i in 1..<lam.count {
            dlam.append(i % 2 == 1 ? lam[i] : 0)
        }
        var word = received
        for p in roots {
            let x = exp[(size - 1 - p) % 255]
            let xi = inv(x)
            let den = evaluate(dlam, xi)
            guard den != 0 else { throw PackbinError.uncorrectable }
            word[p] ^= UInt8(truncatingIfNeeded: mul(x, mul(evaluate(omega, xi), inv(den))))
        }
        guard syndromes(word, n).allSatisfy({ $0 == 0 }) else { throw PackbinError.uncorrectable }
        return (Array(word[0..<(size - n)]), degree)
    }
}
