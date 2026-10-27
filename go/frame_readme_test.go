package packbin_test

import (
	"errors"
	"testing"

	packbin "github.com/zxsanny/packbin/go"
)

// The code the README shows for frame mode. The lines between the markers are copied into the README by the docs
// task and checked by scripts/frame/readme-examples.sh; this test keeps them compiling and correct.
func TestFrameReadmeExampleLoadSealOpenWithAWindowAndTheMacOnlyCall(t *testing.T) {
	// README-BEGIN
	// A 32-byte key shared by the nodes, an epoch (0 to 0xFFFFFF) and a tag of 4, 8 or 16 bytes.
	key := make([]byte, 32) // use a random key from your key store
	node, err := packbin.LoadFrameSession(key, 1, packbin.FrameConfig{
		TagLength:  4,
		Directions: packbin.FrameDirectionsUp | packbin.FrameDirectionsDown,
	})
	if err != nil {
		panic(err)
	}
	defer node.Close() // overwrites the derived keys, best effort

	// **For one (key, epoch, direction), never seal two different messages with the same msg_id.**
	message := packbin.NewMsgContext([]byte{0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0}, 4)
	header := []byte{0, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4} // authenticated, not sent

	body := make([]byte, 255)
	length, err := node.Seal(packbin.FrameUp, message, header, nil, []byte("hello, relay"), body)
	if err != nil {
		panic(err) // *packbin.Error of kind BadValue, TooLong or BufferFull
	}
	body = body[:length] // 12 + 4 bytes here

	// The receiver keeps one ReplayWindow per sender and passes a counter that comes from authenticated bytes.
	window := &packbin.ReplayWindow{}
	plain := make([]byte, 255)
	opened, err := node.Open(packbin.FrameUp, message, header, body, 0, plain, window, 7)
	if err != nil {
		panic(err) // kind TagMismatch, Duplicate, TooOld, ShortPacket, TooLong, BufferFull or BadValue
	}
	// plain[:opened.PlainLength] is the text and opened.Slot says which key opened it
	_, again := node.Open(packbin.FrameUp, message, header, body, 0, plain, window, 7) // errors.Is(again, packbin.ErrDuplicate)

	// The MAC-only call: a 4-byte network check over a message given in parts.
	network, err := packbin.DeriveMacKey(key, 1, []byte("net"))
	if err != nil {
		panic(err)
	}
	defer network.Close()
	tag := make([]byte, 4)
	if err := network.Tag(tag, []byte{1, 2, 3, 4}, body); err != nil {
		panic(err)
	}
	valid := network.Verify(tag, []byte{1, 2, 3, 4}, body)
	// README-END

	if length != 16 {
		t.Fatalf("length %d", length)
	}
	if string(plain[:opened.PlainLength]) != "hello, relay" || opened.Slot != packbin.FrameSlotCurrent {
		t.Fatalf("opened %+v plain %q", opened, plain[:opened.PlainLength])
	}
	if !errors.Is(again, packbin.ErrDuplicate) || !valid {
		t.Fatalf("again %v valid %v", again, valid)
	}
}
