// Command position prints the hex of the AC-1 position row (the golden 4001000065cd1d00a3e1110100),
// as the position programs of the other packages do. publish-position.sh builds it with ring-go.sh.
package main

import (
	"encoding/hex"
	"fmt"
	"os"

	packbin "github.com/zxsanny/packbin/go"
)

func main() {
	s, err := packbin.NewScheme(0x40,
		packbin.U16(0, "sid"),
		packbin.I32(1, "lat"),
		packbin.I32(2, "lon"),
		packbin.U8(3, "profile"),
		packbin.Flags(4,
			packbin.U16(4, "heading"),
			packbin.U8(5, "speed"),
			packbin.I16(6, "altitude")))
	if err != nil {
		fmt.Fprintf(os.Stderr, "position scheme: %v\n", err)
		os.Exit(1)
	}
	raw, err := packbin.Pack(s, map[string]any{"sid": 1, "lat": 500000000, "lon": 300000000, "profile": 1})
	if err != nil {
		fmt.Fprintf(os.Stderr, "position pack: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(hex.EncodeToString(raw))
}
