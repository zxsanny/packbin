// Package packbin packs rows into bytes and unpacks them, with the same bytes as the C#, TypeScript,
// Python, Rust, C++ and Java packages. Both sides keep the same field list; the bytes are only the
// values. The first byte of a packet is the scheme's type number, and unpack picks the scheme by it.
//
// # Schemes and fields
//
// A scheme is a type number (0..255) and fields numbered by order from 0. The ids are not written: a
// gap, a repeated id, or an anchor that is not the next id fails construction. Construction returns an
// error (an *Error of kind InvalidScheme naming the field id), never a panic.
//
//	position, err := packbin.NewScheme(0x40,
//		packbin.U16(0, "sid"),
//		packbin.I32(1, "lat"),
//		packbin.I32(2, "lon"),
//		packbin.U8(3, "profile"),
//		packbin.Flags(4,
//			packbin.U16(4, "heading"),
//			packbin.U8(5, "speed"),
//			packbin.I16(6, "altitude")),
//	)
//	raw, err := packbin.Pack(position, map[string]any{"sid": 1, "lat": 500000000, "lon": 300000000, "profile": 1})
//	// raw is 40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
//
// Every field has a name: the key of its value in the map form of a row.
//
// # Rows
//
// A row is a map[string]any keyed by field name, or a typed struct bound with Bind:
//
//	type Position struct {
//		Sid     uint16
//		Heading *uint16 // nil: no value, the flag bit is clear
//	}
//	packbin.Bind(packbin.U16(0, "sid"),
//		func(r *Position) uint16 { return r.Sid },
//		func(r *Position, v uint16) { r.Sid = v })
//
// A nil value, nil pointer or nil slice is no value; a stored 0 is a value and is written; an empty
// slice is a value with 0 items. A scheme binds every value field to one row type, or none. A bound
// scheme packs a *T (or a T) and Unpack returns a *T; Pack and UnpackMap still take and give the map
// form of any scheme. In a map row an integer field takes any Go integer type that holds the value
// (or a pointer to one), a float field any Go integer or float, fixed bytes a []byte, a bool a bool.
// UnpackMap gives each value the Go type of its field (uint8 to uint64, int8 to int64, float32,
// float64, []byte, true), so a row it returned packs again to the same bytes.
//
// # Pack and unpack
//
//	func Pack(s *Scheme, row any) ([]byte, error)
//	func Unpack(buf []byte, schemes ...*Scheme) (any, error)
//	func UnpackMap(buf []byte, schemes ...*Scheme) (map[string]any, error)
//
// Unpack reads with the scheme the first byte names. Errors are values: every error is an *Error,
// whose Kind is ShortPacket (Field, Name, Needed, Left), TrailingBytes (Left), UnknownType (Actual),
// BadValue, InvalidScheme or PackRefused; errors.Is matches it against ErrShortPacket and the other
// sentinels. A refused pack returns nil bytes, never part of a packet. No input makes Pack, Unpack or
// NewScheme panic.
//
// A built Scheme is immutable and safe for concurrent Pack and Unpack from any number of goroutines.
//
// # Field constructors
//
// The whole API is listed here. The constructors marked (later) are not in this version yet; they
// keep these names and signatures when they come.
//
//	U8, U16, U32, U64, I8, I16, I32, I64(id int, name string) Field
//	                                   integers, little-endian
//	F32, F64(id int, name string) Field
//	                                   IEEE 754, little-endian; NaN and the infinities are written as
//	                                   given, a finite value too large for f32 is refused
//	Bytes(id int, name string, size int) Field
//	                                   exactly size raw bytes, no length
//	Be(f Field) Field                  that integer or float, big-endian
//	Bool(id int, name string) Field    a flag bit with no payload, set only for true; only directly
//	                                   under Flags or a flag byte's Bit
//	Flags(anchor int, members ...Field) Field
//	                                   one byte; bit i is member i; a clear bit skips the member; at
//	                                   most 8 members; the anchor is not written
//	FlagByte(name string) *FlagByteHandle
//	(*FlagByteHandle).Bit(f Field) Field
//	                                   the split form: the handle is where the byte is read, Bit puts
//	                                   a member under its next bit
//	Eq(id int, value any) Cond
//	When(anchor int, cond Cond, members ...Field) Field
//	                                   the members only when an earlier field of the same scope
//	                                   equals value; the anchor is not written
//	Bind[T, V any](f Field, get func(*T) V, set func(*T, V)) Field
//	                                   binds a field to a member of the typed row T
//	Repeat(anchor int, members ...Field) Field                (later) the members until the buffer ends
//	Times(anchor, countID int, members ...Field) Field        (later) the members count times
//	Group(anchor int, name string, members ...Field) Field    (later) several members under one bit
//	Nested(name string, members ...Field) Field               (later) a nested row, ids from 0
//	Sized(id int, name string, countID int) Field             (later) raw bytes, length an earlier integer
//	U2(slots ...Field) Field; Slot(id int, name string) Field (later) 2-bit slots, low bits first
//	Bits(id int, name string, countID int) Field              (later) a 1-bit list
//	Packed(width, id int, name string, countID, bias int) Field
//	                                                          (later) a 1-bit or 2-bit list
//	Utf8(id int, name string) Field                           (later) a u16 byte count, then UTF-8
//	List(name string, element Field) Field                    (later) a u16 count, then the elements
//	Dict(name string, element Field) Field                    (later) a u16 pair count, keys in byte order
//
// Also to come, with these names: (*Scheme).WithLimits(Limits) (*Scheme, error) with the Limits
// fields MaxRounds, MaxSlots and MaxBytes, the error kind TooMany, and PackSession (LoadSession,
// Start, Join, Pack, Unpack, UnpackMap), which a single goroutine uses at a time.
package packbin
