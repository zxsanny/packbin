# Reasoning Chain

## Dimension: bytes on the wire

### Fact Confirmation

Protobuf's own documentation says serialized bytes are not canonical across languages (Fact #4). Kaitai can describe an existing layout, and its 0.11 compiler writes only Java and Python (Fact #5).

### Reference Comparison

`BinaryPrimitives.WriteInt32LittleEndian` writes exactly 4 bytes (Fact #8). `DataView.setInt32(..., littleEndian)` writes exactly 4 bytes (Fact #9). Neither call emits a tag.

### Conclusion

A walker that calls those primitives in field order meets the "bytes are only the fields" restriction. Protobuf and Kaitai-as-the-product do not meet it for C# and TypeScript together.

### Confidence

High. The disqualifier is the encoding or the language list, not a benchmark.

## Dimension: the golden fixture

### Fact Confirmation

The same 13-byte hex came out of Node 22 and .NET 10 (Fact #10).

### Reference Comparison

Protobuf conformance compares decoded values unless a test asks for the same wire bytes, and the project tells users not to rely on byte identity (Fact #4).

### Conclusion

Byte identity is a property of this fixed layout, and the two runtime primitives already produce it for the position fixture. It is the wrong done line for a tagged format, which is why those formats stay rejected.

### Confidence

High for this fixture. Flags, a conditional group, and a repeated group were checked as width and error outcomes in the same programs, not as a second full packet from `solution.md`.

## Dimension: speed

### Fact Confirmation

The written bar is 10 µs per round trip (Fact #3). The runs finished in 17.4 ms and 1.8 ms for 100000 trips (Fact #10), which is 0.174 µs and 0.018 µs.

### Conclusion

The floor does not force a second implementation technique. A straight walk is enough.

### Confidence

High on this machine, one core, this fixture. It is not a claim about a 1 MB buffer.
