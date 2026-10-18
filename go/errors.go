package packbin

import "fmt"

// Kind says what went wrong. Its String form is the outcome name of the shared hostile vectors
// (fixtures/hostile/README.md).
type Kind int

const (
	// ShortPacket: the buffer ends inside a field. Field, Name, Needed and Left are set.
	ShortPacket Kind = iota + 1
	// TrailingBytes: bytes are left after the scheme's last field. Left is set.
	TrailingBytes
	// UnknownType: the first byte names no scheme of the call. Actual is set.
	UnknownType
	// BadValue: unpack read a value it cannot use.
	BadValue
	// InvalidScheme: a scheme, a field or an unpack call's scheme list is refused.
	InvalidScheme
	// PackRefused: pack cannot write the row; it returns nil bytes.
	PackRefused
	// TooMany: unpack refuses a repeat or times round past the scheme's MaxRounds or MaxSlots when
	// the round would start, before its bytes are read. Field and Name are the round's first member,
	// Needed is 0 and Left the bytes left where the round would start.
	TooMany
	// Uncorrectable: a protected message has more wrong bytes than the correction limit allows (or, with
	// the limit 0, any wrong byte). It names no field and unpack returns no row.
	Uncorrectable
	// TooLong: unpack refuses a protected message of more than 254 bytes. It names no field, Left is the
	// length and Reason names the length and the limit.
	TooLong
)

// NoField is the Field of an error that belongs to no field: trailing bytes, an unknown type
// number, an empty buffer, a split flag byte (which has no id).
const NoField = -1

func (k Kind) String() string {
	switch k {
	case ShortPacket:
		return "short_packet"
	case TrailingBytes:
		return "trailing_bytes"
	case UnknownType:
		return "type_mismatch"
	case BadValue:
		return "bad_value"
	case InvalidScheme:
		return "scheme_error"
	case PackRefused:
		return "pack_error"
	case TooMany:
		return "too_many"
	case Uncorrectable:
		return "uncorrectable"
	case TooLong:
		return "too_long"
	}
	return fmt.Sprintf("kind(%d)", int(k))
}

// Error is every error the package returns. Test its kind with errors.Is against the Err
// sentinels, or read the fields with errors.As.
type Error struct {
	Kind Kind
	// Field is the field id (the anchor for flags and when), or NoField.
	Field int
	// Name is the field's name, or "".
	Name string
	// Needed and Left are the bytes a short field needed and the bytes that were left; Left is
	// also the count of trailing bytes.
	Needed int
	Left   int
	// Actual is the first byte of a packet whose type number no scheme has.
	Actual int
	// Reason says why a value, a row or a scheme is refused.
	Reason string
}

// Sentinels for errors.Is: an *Error matches the sentinel of its Kind.
var (
	ErrShortPacket   = &Error{Kind: ShortPacket, Field: NoField}
	ErrTrailingBytes = &Error{Kind: TrailingBytes, Field: NoField}
	ErrUnknownType   = &Error{Kind: UnknownType, Field: NoField}
	ErrBadValue      = &Error{Kind: BadValue, Field: NoField}
	ErrInvalidScheme = &Error{Kind: InvalidScheme, Field: NoField}
	ErrPackRefused   = &Error{Kind: PackRefused, Field: NoField}
	ErrTooMany       = &Error{Kind: TooMany, Field: NoField}
	ErrUncorrectable = &Error{Kind: Uncorrectable, Field: NoField}
	ErrTooLong       = &Error{Kind: TooLong, Field: NoField}
)

// Is reports whether target is an *Error of the same Kind.
func (e *Error) Is(target error) bool {
	t, ok := target.(*Error)
	return ok && t != nil && e != nil && t.Kind == e.Kind
}

func (e *Error) Error() string {
	at := e.where()
	switch e.Kind {
	case ShortPacket:
		return fmt.Sprintf("packbin: short packet%s: needed %d, left %d", at, e.Needed, e.Left)
	case TrailingBytes:
		return fmt.Sprintf("packbin: %d trailing bytes", e.Left)
	case UnknownType:
		return fmt.Sprintf("packbin: unknown type number %d", e.Actual)
	case BadValue:
		return fmt.Sprintf("packbin: bad value%s: %s", at, e.Reason)
	case InvalidScheme:
		return fmt.Sprintf("packbin: invalid scheme%s: %s", at, e.Reason)
	case PackRefused:
		return fmt.Sprintf("packbin: pack refused%s: %s", at, e.Reason)
	case TooMany:
		return fmt.Sprintf("packbin: too many%s: %s", at, e.Reason)
	case Uncorrectable:
		return "packbin: uncorrectable: " + e.Reason
	case TooLong:
		return "packbin: too long: " + e.Reason
	}
	return fmt.Sprintf("packbin: %v%s: %s", e.Kind, at, e.Reason)
}

func (e *Error) where() string {
	switch {
	case e.Field != NoField && e.Name != "":
		return fmt.Sprintf(" at field %d (%s)", e.Field, e.Name)
	case e.Field != NoField:
		return fmt.Sprintf(" at field %d", e.Field)
	case e.Name != "":
		return fmt.Sprintf(" at %s", e.Name)
	}
	return ""
}

func schemeErr(id int, name, format string, args ...any) *Error {
	return &Error{Kind: InvalidScheme, Field: id, Name: name, Reason: fmt.Sprintf(format, args...)}
}

func packErr(id int, name, format string, args ...any) *Error {
	return &Error{Kind: PackRefused, Field: id, Name: name, Reason: fmt.Sprintf(format, args...)}
}

func shortErr(id int, name string, needed, left int) *Error {
	return &Error{Kind: ShortPacket, Field: id, Name: name, Needed: needed, Left: left}
}

func tooMany(id int, name string, left int, format string, args ...any) *Error {
	return &Error{Kind: TooMany, Field: id, Name: name, Left: left, Reason: fmt.Sprintf(format, args...)}
}
