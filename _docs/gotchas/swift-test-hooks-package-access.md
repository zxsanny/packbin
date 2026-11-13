---
title: "A Swift test hook is package access, never @_spi or internal + @testable import"
applies_when: "giving Swift tests access to library members"
source: "loop 72"
---

A Swift test hook is `package` (SE-0386, tools 6.0), never `@_spi` (an unofficial door any app can open) or `internal` + `@testable import` (loop 72): `run-suite.sh` `swift_speed` builds every test file in release, where `@testable` fails with "unable to resolve module dependency 'Packbin'", and SwiftPM links all test files into one bundle, so one `@testable` file breaks the speed part. Tests reach `package` members with a plain `import Packbin`.
