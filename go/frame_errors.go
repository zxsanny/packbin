package packbin

import "fmt"

// The error values of frame mode: every one is an *Error of the kinds BadValue, TooLong, BufferFull, ShortPacket,
// TagMismatch, Duplicate or TooOld (errors.Is matches the Err sentinels).

func frameBad(format string, args ...any) *Error {
	return &Error{Kind: BadValue, Field: NoField, Reason: fmt.Sprintf(format, args...)}
}

func frameTooLong(what string, length int) *Error {
	return &Error{Kind: TooLong, Field: NoField, Left: length,
		Reason: fmt.Sprintf("%s is %d bytes, above the limit of %d bytes", what, length, FrameMaxBody)}
}
