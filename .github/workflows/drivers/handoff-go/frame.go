package main

import (
	"bufio"
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"

	packbin "github.com/zxsanny/packbin/go"
)

// frameFields reads the words of one line. A token that is not hex (a bad digit, an odd length), a number with other
// characters and a missing field are held as the first error and checked once per line, so no value is ever a zero or a cut.
type frameFields struct {
	w   []string
	err error
}

func (f *frameFields) word(i int) string {
	if i >= len(f.w) {
		if f.err == nil {
			f.err = fmt.Errorf("missing field %d", i)
		}
		return ""
	}
	return f.w[i]
}

func (f *frameFields) bytes(i int) []byte {
	token := f.word(i)
	if token == "-" || f.err != nil {
		return []byte{}
	}
	b, err := hex.DecodeString(token)
	if err != nil {
		f.err = fmt.Errorf("bad hex: %s", token)
		return []byte{}
	}
	return b
}

func (f *frameFields) int(i int) int {
	token := f.word(i)
	if f.err != nil {
		return 0
	}
	n, err := strconv.Atoi(token)
	if err != nil || n < 0 || strings.ContainsAny(token, "+-") {
		f.err = fmt.Errorf("bad number: %s", token)
		return 0
	}
	return n
}

func frameHex(data []byte) string {
	if len(data) == 0 {
		return "-"
	}
	return hex.EncodeToString(data)
}

func frameKind(err error) string {
	if e, ok := err.(*packbin.Error); ok {
		switch e.Kind {
		case packbin.BadValue:
			return "BadValue"
		case packbin.TooLong:
			return "TooLong"
		case packbin.BufferFull:
			return "BufferFull"
		case packbin.ShortPacket:
			return "ShortPacket"
		case packbin.TagMismatch:
			return "TagMismatch"
		}
	}
	return "error"
}

// The package takes the byte as it comes: a direction outside 1 to 3 is its BadValue to give.
func frameDirection(d int) packbin.FrameDirection {
	return packbin.FrameDirection(uint8(d))
}

// The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output buffer size.
func frameLoaded(f *frameFields) (packbin.FrameDirections, int) {
	digits, size := "123", 300
	if len(f.w) > 9 {
		digits = f.w[9]
	}
	if len(f.w) > 10 {
		size = f.int(10)
	}
	if strings.Trim(digits, "123") != "" || digits == "" {
		f.err = fmt.Errorf("bad dirs: %s", digits)
		return 0, size
	}
	var mask packbin.FrameDirections
	for _, digit := range digits {
		mask |= 1 << (digit - '1')
	}
	return mask, size
}

func frameSeal(w []string) (string, error) {
	f := &frameFields{w: w}
	key, epoch, d, tagLen := f.bytes(0), f.int(1), f.int(2), f.int(3)
	msgID, kind, ad, clear, plain := f.bytes(4), f.int(5), f.bytes(6), f.bytes(7), f.bytes(8)
	directions, size := frameLoaded(f)
	if f.err != nil {
		return "", f.err
	}
	session, err := packbin.LoadFrameSession(key, uint32(epoch),
		packbin.FrameConfig{TagLength: tagLen, Directions: directions})
	if err != nil {
		return frameKind(err), nil
	}
	out := make([]byte, size)
	n, err := session.Seal(frameDirection(d), packbin.NewMsgContext(msgID, kind), ad, clear, plain, out)
	if err != nil {
		return frameKind(err), nil
	}
	return frameHex(out[:n]), nil
}

func frameOpen(w []string) (string, error) {
	f := &frameFields{w: w}
	key, epoch, d, tagLen := f.bytes(0), f.int(1), f.int(2), f.int(3)
	msgID, kind, ad, clearLen, body := f.bytes(4), f.int(5), f.bytes(6), f.int(7), f.bytes(8)
	directions, size := frameLoaded(f)
	if f.err != nil {
		return "", f.err
	}
	session, err := packbin.LoadFrameSession(key, uint32(epoch),
		packbin.FrameConfig{TagLength: tagLen, Directions: directions})
	if err != nil {
		return frameKind(err), nil
	}
	out := make([]byte, size)
	opened, err := session.Open(frameDirection(d), packbin.NewMsgContext(msgID, kind), ad, body, clearLen, out, nil, 0)
	if err != nil {
		return frameKind(err), nil
	}
	return frameHex(out[:opened.PlainLength]), nil
}

func frameMac(w []string) (string, error) {
	f := &frameFields{w: w}
	key, epoch, label, n, message := f.bytes(0), f.int(1), f.bytes(2), f.int(3), f.bytes(4)
	if f.err != nil {
		return "", f.err
	}
	mk, err := packbin.DeriveMacKey(key, uint32(epoch), label)
	if err != nil {
		return frameKind(err), nil
	}
	tag := make([]byte, n)
	if err := mk.Tag(tag, message); err != nil {
		return frameKind(err), nil
	}
	return frameHex(tag), nil
}

func frameVerify(w []string) (string, error) {
	f := &frameFields{w: w}
	// n is field 3, not used for verify (the tag length comes from the tag)
	key, epoch, label, _, message, tag := f.bytes(0), f.int(1), f.bytes(2), f.int(3), f.bytes(4), f.bytes(5)
	if f.err != nil {
		return "", f.err
	}
	mk, err := packbin.DeriveMacKey(key, uint32(epoch), label)
	if err != nil {
		return frameKind(err), nil
	}
	if mk.Verify(tag, message) {
		return "valid", nil
	}
	return "invalid", nil
}

func frameLine(words []string) (string, error) {
	switch words[0] {
	case "seal":
		return frameSeal(words[1:])
	case "open":
		return frameOpen(words[1:])
	case "mac":
		return frameMac(words[1:])
	case "verify":
		return frameVerify(words[1:])
	case "open-skip", "verify-skip":
		return "skip", nil
	}
	return "", fmt.Errorf("unknown word %s", words[0])
}

func runFrame(args []string) int {
	if args[0] == "frame-batch" && len(args) == 2 {
		file, err := os.Open(args[1])
		if err != nil {
			return fail("frame-batch: %v", err)
		}
		defer file.Close()
		scan := bufio.NewScanner(file)
		scan.Buffer(make([]byte, 0, 1<<16), 1<<20)
		number := 0
		for scan.Scan() {
			number++
			if f := strings.Fields(scan.Text()); len(f) > 0 {
				out, err := frameLine(f)
				if err != nil {
					return fail("frame line %d: %v", number, err)
				}
				fmt.Println(out)
			}
		}
		if err := scan.Err(); err != nil {
			return fail("frame line %d: %v", number+1, err)
		}
		return 0
	}
	return 2
}
