# Comparison Framework

## Selected Framework Type

Decision support, with the exact-fit dimensions required for a technical-component choice.

## Selected Dimensions

1. Option family
2. Bytes added beyond the caller's fields
3. C# and TypeScript can both pack and unpack
4. 0 mismatched bytes on a shared fixture
5. Short input returns no value
6. Speed floor (10 µs per round trip)
7. Evidence quality

## Initial Population

| Dimension | Runtime primitive walk | Protobuf | Kaitai Struct | Factual Basis |
|-----------|------------------------|----------|---------------|---------------|
| Option family | Simple baseline | Established production | Open-source | Fact #4, #5, #8 |
| Extra bytes | 0 | field tags | 0 on the wire, but the product is a compiler | Fact #4, #5 |
| Pack in C# and TypeScript | yes, both are runtime APIs | yes, and the bytes are not canonical | write is Java and Python only | Fact #4, #5, #8, #9 |
| 0 mismatches | demonstrated | not promised | not available for these two languages | Fact #4, #10 |
| Short input | demonstrated, 0 values | parsers differ by implementation | not the selected writer | Fact #6, #10 |
| Speed floor | 17.4 ms and 1.8 ms for 100000 trips | not required once extra tags fail the restriction | not applicable | Fact #3, #10 |
| Evidence | L1 API pages plus a run | L1 protobuf docs | L1 Kaitai 0.11 notes | Source #7, #9, #15, #16 |
