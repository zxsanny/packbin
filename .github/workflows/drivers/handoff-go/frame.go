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

func frameBytes(token string) []byte {
	if token == "-" {
		return []byte{}
	}
	b, err := hex.DecodeString(token)
	if err != nil {
		panic(fmt.Sprintf("bad hex: %s", token))
	}
	return b
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

func frameDirection(d int) packbin.FrameDirection {
	switch d {
	case 1:
		return packbin.FrameUp
	case 2:
		return packbin.FrameDown
	case 3:
		return packbin.FrameGroup
	}
	panic(fmt.Sprintf("direction: %d", d))
}

func frameSeal(w []string) string {
	key := frameBytes(w[0])
	epoch, _ := strconv.Atoi(w[1])
	d, _ := strconv.Atoi(w[2])
	tagLen, _ := strconv.Atoi(w[3])
	msgID := frameBytes(w[4])
	kind, _ := strconv.Atoi(w[5])
	ad := frameBytes(w[6])
	clear := frameBytes(w[7])
	plain := frameBytes(w[8])
	session, err := packbin.LoadFrameSession(key, uint32(epoch),
		packbin.FrameConfig{TagLength: tagLen, Directions: packbin.FrameDirections(1 << (d - 1))})
	if err != nil {
		return frameKind(err)
	}
	out := make([]byte, 300)
	n, err := session.Seal(frameDirection(d), packbin.NewMsgContext(msgID, kind), ad, clear, plain, out)
	if err != nil {
		return frameKind(err)
	}
	return frameHex(out[:n])
}

func frameOpen(w []string) string {
	key := frameBytes(w[0])
	epoch, _ := strconv.Atoi(w[1])
	d, _ := strconv.Atoi(w[2])
	tagLen, _ := strconv.Atoi(w[3])
	msgID := frameBytes(w[4])
	kind, _ := strconv.Atoi(w[5])
	ad := frameBytes(w[6])
	clearLen, _ := strconv.Atoi(w[7])
	body := frameBytes(w[8])
	session, err := packbin.LoadFrameSession(key, uint32(epoch),
		packbin.FrameConfig{TagLength: tagLen, Directions: packbin.FrameDirections(1 << (d - 1))})
	if err != nil {
		return frameKind(err)
	}
	out := make([]byte, 300)
	opened, err := session.Open(frameDirection(d), packbin.NewMsgContext(msgID, kind), ad, body, clearLen, out, nil, 0)
	if err != nil {
		return frameKind(err)
	}
	return frameHex(out[:opened.PlainLength])
}

func frameMac(w []string) string {
	key := frameBytes(w[0])
	epoch, _ := strconv.Atoi(w[1])
	label := frameBytes(w[2])
	n, _ := strconv.Atoi(w[3])
	message := frameBytes(w[4])
	mk, err := packbin.DeriveMacKey(key, uint32(epoch), label)
	if err != nil {
		return frameKind(err)
	}
	tag := make([]byte, n)
	if err := mk.Tag(tag, message); err != nil {
		return frameKind(err)
	}
	return frameHex(tag)
}

func frameVerify(w []string) string {
	key := frameBytes(w[0])
	epoch, _ := strconv.Atoi(w[1])
	label := frameBytes(w[2])
	// n is w[3], not used for verify (tag length comes from the tag)
	message := frameBytes(w[4])
	tag := frameBytes(w[5])
	mk, err := packbin.DeriveMacKey(key, uint32(epoch), label)
	if err != nil {
		return frameKind(err)
	}
	if mk.Verify(tag, message) {
		return "valid"
	}
	return "invalid"
}

func frameLine(words []string) (string, error) {
	switch words[0] {
	case "seal":
		return frameSeal(words[1:]), nil
	case "open":
		return frameOpen(words[1:]), nil
	case "mac":
		return frameMac(words[1:]), nil
	case "verify":
		return frameVerify(words[1:]), nil
	case "open-skip", "verify-skip":
		return "skip", nil
	}
	return "", fmt.Errorf("frame line: %s", words[0])
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
		for scan.Scan() {
			if f := strings.Fields(scan.Text()); len(f) > 0 {
				out, err := frameLine(f)
				if err != nil {
					return fail("%v", err)
				}
				fmt.Println(out)
			}
		}
		return 0
	}
	return 2
}
