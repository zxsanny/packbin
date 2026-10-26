// The Swift member of the cross-language ring (.github/workflows/language-pair.sh).
//
// Commands, the same as the other drivers:
//
//   pack-<kind>                 prints the hex of the kind's row and a newline, exits 0
//   unpack-<kind> <hex>         exits 0 only if the packet unpacks to the kind's row (the round kinds
//                               also repack to the same hex)
//   unpack-<kind>-short <hex>   listgroup, dictgroup and listflags only: exits 0 only if the packet is
//                               refused (a thrown PackbinError) and no row comes back
//
// Any other command, or a missing hex, exits 2; hex that is not hex exits 1 with a message. The position
// program is the `position` product of this package; ring-swift.sh builds both.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import Packbin

/// Reads "pack-user", "unpack-user" and "unpack-listgroup-short"; nil when it is none of these forms.
func splitCommand(_ cmd: String) -> (name: String, op: String, short: Bool)? {
    let op: String
    var rest: Substring
    if cmd.hasPrefix("pack-") {
        op = "pack"
        rest = cmd.dropFirst("pack-".count)
    } else if cmd.hasPrefix("unpack-") {
        op = "unpack"
        rest = cmd.dropFirst("unpack-".count)
    } else {
        return nil
    }
    let short = rest.hasSuffix("-short")
    if short { rest = rest.dropLast("-short".count) }
    return (String(rest), op, short)
}

func unpackKind(_ cmd: String, _ k: Kind, _ hex: String, short: Bool) -> Int32 {
    guard let buf = hexBytes(hex) else { return fail("\(cmd): bad hex: \(hex.debugDescription)") }
    if short {
        // A short element is refused and no row comes back.
        do {
            let row = try unpackMap(buf, k.scheme)
            return fail("\(cmd): read \(render(row)), expected a refusal")
        } catch is PackbinError {
            return 0
        } catch {
            return fail("\(cmd): \(error), expected a PackbinError")
        }
    }
    let row: [String: Any]
    do {
        row = try unpackMap(buf, k.scheme)
    } catch {
        return fail("\(cmd): \(error)")
    }
    if render(row) != render(k.want) {
        return fail("\(cmd): read \(render(row)), expected \(render(k.want))")
    }
    if k.repack {
        do {
            let again = hexString(try pack(k.scheme, row))
            if again != hex.lowercased() { return fail("\(cmd): repacked \(again), expected \(hex)") }
        } catch {
            return fail("\(cmd): repack: \(error)")
        }
    }
    return 0
}

func run(_ args: [String]) -> Int32 {
    guard let cmd = args.first else { return 2 }
    let hex = args.count > 1 ? args[1] : nil
    if cmd.hasPrefix("ecc-") { return eccCommand(args) }
    guard let (name, op, short) = splitCommand(cmd) else { return 2 }
    let found: Kind?
    do {
        found = try kind(name)
    } catch {
        return fail("\(cmd): scheme: \(error)")
    }
    guard let k = found, !short || shortKinds.contains(name) else { return 2 }
    switch op {
    case "pack" where !short:
        do {
            print(hexString(try pack(k.scheme, k.pack)))
            return 0
        } catch {
            return fail("\(cmd): \(error)")
        }
    case "unpack":
        guard let hex else { return 2 }
        return unpackKind(cmd, k, hex, short: short)
    default:
        return 2
    }
}

exit(run(Array(CommandLine.arguments.dropFirst())))
