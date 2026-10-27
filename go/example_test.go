package packbin_test

import (
	"fmt"

	packbin "github.com/zxsanny/packbin/go"
)

// Position is the typed row of the README example.
type Position struct {
	Sid      uint16
	Lat      int32
	Lon      int32
	Profile  uint8
	Heading  *uint16
	Speed    *uint8
	Altitude *int16
}

// Run by `go test`: the output is the hex of the README (fixtures/golden.hex, with spaces).
func ExamplePack_typed() {
	position, err := packbin.NewScheme(0x40,
		packbin.Bind(packbin.U16(0, "sid"), func(r *Position) uint16 { return r.Sid }, func(r *Position, v uint16) { r.Sid = v }),
		packbin.Bind(packbin.I32(1, "lat"), func(r *Position) int32 { return r.Lat }, func(r *Position, v int32) { r.Lat = v }),
		packbin.Bind(packbin.I32(2, "lon"), func(r *Position) int32 { return r.Lon }, func(r *Position, v int32) { r.Lon = v }),
		packbin.Bind(packbin.U8(3, "profile"), func(r *Position) uint8 { return r.Profile }, func(r *Position, v uint8) { r.Profile = v }),
		packbin.Flags(4,
			packbin.Bind(packbin.U16(4, "heading"), func(r *Position) *uint16 { return r.Heading }, func(r *Position, v *uint16) { r.Heading = v }),
			packbin.Bind(packbin.U8(5, "speed"), func(r *Position) *uint8 { return r.Speed }, func(r *Position, v *uint8) { r.Speed = v }),
			packbin.Bind(packbin.I16(6, "altitude"), func(r *Position) *int16 { return r.Altitude }, func(r *Position, v *int16) { r.Altitude = v }),
		),
	)
	if err != nil {
		panic(err)
	}

	raw, err := packbin.Pack(position, &Position{Sid: 1, Lat: 500_000_000, Lon: 300_000_000, Profile: 1})
	if err != nil {
		panic(err)
	}
	fmt.Printf("% x\n", raw)

	row, err := packbin.Unpack(raw, position)
	if err != nil {
		panic(err)
	}
	got := row.(*Position)
	fmt.Println(got.Lat, got.Heading == nil)
	// Output:
	// 40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
	// 500000000 true
}

func ExamplePack_map() {
	position, err := packbin.NewScheme(0x40,
		packbin.U16(0, "sid"),
		packbin.I32(1, "lat"),
		packbin.I32(2, "lon"),
		packbin.U8(3, "profile"),
		packbin.Flags(4,
			packbin.U16(4, "heading"),
			packbin.U8(5, "speed"),
			packbin.I16(6, "altitude")),
	)
	if err != nil {
		panic(err)
	}

	raw, err := packbin.Pack(position, map[string]any{"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1})
	if err != nil {
		panic(err)
	}
	fmt.Printf("% x\n", raw)

	withHeading, err := packbin.Pack(position, map[string]any{"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1, "heading": 90})
	if err != nil {
		panic(err)
	}
	fmt.Printf("% x\n", withHeading)

	row, err := packbin.UnpackMap(withHeading, position)
	if err != nil {
		panic(err)
	}
	fmt.Printf("%T %v\n", row["heading"], row["heading"])
	_, hasSpeed := row["speed"]
	fmt.Println(hasSpeed)
	// Output:
	// 40 01 00 00 65 cd 1d 00 a3 e1 11 01 00
	// 40 01 00 00 65 cd 1d 00 a3 e1 11 01 01 5a 00
	// uint16 90
	// false
}

func ExamplePack_groupMaps() {
	scheme, err := packbin.NewScheme(1, packbin.U8(0, "a"), packbin.Group(1, "g", packbin.U8(1, "b")))
	if err != nil {
		panic(err)
	}
	raw, err := packbin.Pack(scheme, map[string]any{"a": 1, "g": map[string]any{"b": 2}})
	if err != nil {
		panic(err)
	}
	fmt.Printf("% x\n", raw)

	_, err = packbin.Pack(scheme, map[string]any{"a": 1, "b": 2})
	fmt.Println(err != nil)

	rounds, err := packbin.NewScheme(1, packbin.Repeat(0, packbin.U8(0, "k"), packbin.Group(1, "mark", packbin.U8(1, "v"))))
	if err != nil {
		panic(err)
	}
	perRound, err := packbin.Pack(rounds, map[string]any{
		"k":    []any{1, 2},
		"mark": []any{map[string]any{"v": 7}, map[string]any{"v": 8}},
	})
	if err != nil {
		panic(err)
	}
	fmt.Printf("% x\n", perRound)
	// Output:
	// 01 01 02
	// true
	// 01 01 07 02 08
}

func ExampleNested() {
	scheme, err := packbin.NewScheme(1, packbin.U8(0, "mode"), packbin.Nested("in", packbin.U8(0, "mode"), packbin.U8(1, "x")))
	if err != nil {
		panic(err)
	}
	raw, err := packbin.Pack(scheme, map[string]any{"mode": 1, "in": map[string]any{"mode": 2, "x": 3}})
	if err != nil {
		panic(err)
	}
	fmt.Printf("% x\n", raw)
	// Output:
	// 01 01 02 03
}

func ExampleScheme_WithLimits() {
	scheme, err := packbin.NewScheme(1, packbin.Repeat(0, packbin.U8(0, "k")))
	if err != nil {
		panic(err)
	}
	limits := packbin.DefaultLimits()
	limits.MaxSlots = 16_000_000
	raised, err := scheme.WithLimits(limits)
	if err != nil {
		panic(err)
	}
	fmt.Println(raised.Limits())

	_, err = scheme.WithLimits(packbin.Limits{MaxRounds: 200_000})
	fmt.Println(err != nil)
	// Output:
	// {65535 16000000 16777216}
	// true
}
