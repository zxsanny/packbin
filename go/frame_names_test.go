package packbin_test

import (
	"reflect"
	"sort"
	"testing"

	packbin "github.com/zxsanny/packbin/go"
)

// AZ-3293 AC-4: the public API names the D1 types as the other four packages do (pack-session.md 3.0.0), the three
// error kinds beside the existing ones, and the operations of frame mode.
func TestAC4TheD1NamesArePublic(t *testing.T) {
	// Arrange
	types := map[string]reflect.Type{
		"FrameSession":    reflect.TypeFor[packbin.FrameSession](),
		"FrameConfig":     reflect.TypeFor[packbin.FrameConfig](),
		"FrameDirection":  reflect.TypeFor[packbin.FrameDirection](),
		"FrameDirections": reflect.TypeFor[packbin.FrameDirections](),
		"FrameSlot":       reflect.TypeFor[packbin.FrameSlot](),
		"FrameOpened":     reflect.TypeFor[packbin.FrameOpened](),
		"MsgContext":      reflect.TypeFor[packbin.MsgContext](),
		"ReplayWindow":    reflect.TypeFor[packbin.ReplayWindow](),
		"Freshness":       reflect.TypeFor[packbin.Freshness](),
		"MacKey":          reflect.TypeFor[packbin.MacKey](),
	}
	methods := map[string][]string{
		"FrameSession": {"ClearPrevious", "Close", "Epoch", "Open", "Seal", "SetPrevious", "TagLength"},
		"MacKey":       {"Close", "Epoch", "Tag", "Verify"},
		"ReplayWindow": {"Bits", "Check", "Commit", "Top"},
		"MsgContext":   {"Kind"},
	}

	for name, typ := range types {
		// Act
		got := typ.Name()
		listed := publicMethods(typ)

		// Assert
		if got != name || typ.PkgPath() != "github.com/zxsanny/packbin/go" {
			t.Fatalf("%s: %q in %s", name, got, typ.PkgPath())
		}
		if want := methods[name]; want != nil && !reflect.DeepEqual(listed, want) {
			t.Fatalf("%s methods %v, want %v", name, listed, want)
		}
	}
}

func publicMethods(typ reflect.Type) []string {
	var names []string
	for _, candidate := range []reflect.Type{typ, reflect.PointerTo(typ)} {
		for i := range candidate.NumMethod() {
			if name := candidate.Method(i).Name; !contains(names, name) && name != "String" {
				names = append(names, name)
			}
		}
	}
	sort.Strings(names)
	return names
}

func contains(list []string, name string) bool {
	for _, v := range list {
		if v == name {
			return true
		}
	}
	return false
}

func TestAC4TheFrameErrorKindsAndSentinelsAreBesideTheExistingOnes(t *testing.T) {
	// Arrange
	kinds := map[packbin.Kind]string{
		packbin.TagMismatch: "tag_mismatch", packbin.Duplicate: "duplicate", packbin.TooOld: "too_old",
		packbin.BufferFull: "buffer_full", packbin.TooLong: "too_long", packbin.BadValue: "bad_value",
		packbin.ShortPacket: "short_packet",
	}
	sentinels := []*packbin.Error{packbin.ErrTagMismatch, packbin.ErrDuplicate, packbin.ErrTooOld, packbin.ErrBufferFull}

	// Act and Assert
	for kind, name := range kinds {
		if kind.String() != name {
			t.Fatalf("%d is %s, want %s", int(kind), kind, name)
		}
	}
	for _, s := range sentinels {
		if s == nil || s.Kind == 0 {
			t.Fatal("a sentinel is missing")
		}
	}
	functions := []any{packbin.LoadFrameSession, packbin.DeriveMacKey, packbin.NewMsgContext, packbin.NewReplayWindow}
	for _, f := range functions {
		if reflect.TypeOf(f).Kind() != reflect.Func {
			t.Fatal("not a function")
		}
	}
	values := []any{packbin.FrameUp, packbin.FrameDown, packbin.FrameGroup, packbin.FrameDirectionsNone, packbin.FrameDirectionsAll,
		packbin.FrameSlotCurrent, packbin.FrameSlotPrevious, packbin.FreshnessFresh, packbin.FreshnessDuplicate, packbin.FreshnessTooOld}
	if len(values) != 10 {
		t.Fatal("values")
	}
}
