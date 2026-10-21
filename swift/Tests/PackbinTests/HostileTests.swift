import Packbin
import Testing

/// AC-1 and AC-2 (SW-4, scenario S2): the shared hostile vectors of fixtures/hostile/cases.txt replayed
/// by Swift, each scheme written by hand from fixtures/hostile/README.md (ADR-001: no shared walker).
/// Every case gives one of its outcome terms with the rule `hostileRules` pins; a trap ends the process,
/// so each case is named on the output before it runs. The suite runs one case at a time, so the time of
/// an unpack is its own.
@Suite(.serialized) struct HostileTests {
    @Test(arguments: try hostileCases("unpack"))
    func unpackCase_givesAnAllowedErrorWithItsRuleAndNoRow(_ c: HostileCase) {
        #expect(checkHostileUnpack(c, hostileUnpackSchemes[c.id], hostileRules) == nil)
    }

    @Test(arguments: try hostileCases("limit"))
    func limitCase_isRefusedWhenTheRoundPastTheLowLimitWouldStart(_ c: HostileCase) {
        #expect(checkHostileLimit(c, hostileLimitSchemes[c.id], hostileRules) == nil)
    }

    @Test(arguments: try hostileCases("construct"))
    func constructCase_isRefusedWithItsRule(_ c: HostileCase) {
        #expect(checkHostileConstruct(c, hostileConstructs[c.id]) == nil)
    }

    @Test(arguments: try hostileCases("pack"))
    func packCase_givesItsBytesOrIsRefusedWithItsRule(_ c: HostileCase) {
        #expect(checkHostilePack(c, hostilePacks[c.id], hostileRules) == nil)
    }

    /// The four tables hold exactly the cases of their stage, and a rule for exactly the cases that end
    /// in an error, so no case is skipped and no stale entry stays.
    @Test func tables_holdEveryCaseOnceAndNoOther() throws {
        // Arrange
        let cases = try hostileCases()
        let tables: [String: Set<String>] = [
            "unpack": Set(hostileUnpackSchemes.keys),
            "limit": Set(hostileLimitSchemes.keys),
            "construct": Set(hostileConstructs.keys),
            "pack": Set(hostilePacks.keys),
        ]
        let refused = cases.filter { $0.stage != "construct" && $0.expected != ["bytes"] }.map(\.id)

        // Act
        let stages = Dictionary(grouping: cases, by: \.stage).mapValues { Set($0.map(\.id)) }

        // Assert
        #expect(cases.count == 72)
        #expect(Set(cases.map(\.id)).count == cases.count)
        #expect(stages.mapValues(\.count) == ["unpack": 15, "limit": 2, "construct": 15, "pack": 40])
        #expect(stages == tables)
        #expect(Set(hostileRules.keys) == Set(refused) && hostileRules.count == refused.count)
    }

    /// AZ-2418 AC-1 as for the other packages: a rule table with one wrong entry cannot pass, and the
    /// failure names the case. The wrong entries are built here; nothing on disk changes.
    @Test func packCaseWithAWrongRuleEntry_failsNamingTheCase() throws {
        // Arrange
        let c = try #require(try hostileCases("pack").first { $0.id == "pack_slots_over_limit" })
        var wrong = hostileRules
        wrong[c.id] = hostileRules["pack_repeat_over_limit"]

        // Act
        let failure = checkHostilePack(c, hostilePacks[c.id], wrong)

        // Assert
        #expect(failure?.hasPrefix("pack_slots_over_limit: refused by another rule") == true, "\(String(describing: failure))")
    }

    @Test func constructCaseWithAWrongRuleEntry_failsNamingTheCase() throws {
        // Arrange
        let c = try #require(try hostileCases("construct").first { $0.id == "construct_empty_times_body" })
        let right = try #require(hostileConstructs[c.id])
        let wrong = HostileConstruct(build: right.build,
                                     rule: try #require(hostileConstructs["construct_empty_repeat_body"]).rule)

        // Act
        let failure = checkHostileConstruct(c, wrong)

        // Assert
        #expect(failure?.hasPrefix("construct_empty_times_body: refused by another rule") == true, "\(String(describing: failure))")
    }

    @Test func unpackCaseWithAWrongRuleEntry_failsNamingTheCase() throws {
        // Arrange
        let c = try #require(try hostileCases("unpack").first { $0.id == "oversize_count_times" })
        var wrong = hostileRules
        wrong[c.id] = hostileRules["oversize_list_count"]

        // Act
        let failure = checkHostileUnpack(c, hostileUnpackSchemes[c.id], wrong)

        // Assert
        #expect(failure?.hasPrefix("oversize_count_times: refused by another rule") == true, "\(String(describing: failure))")
    }
}
