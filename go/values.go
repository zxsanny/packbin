package packbin

import (
	"math"
	"reflect"
)

// normalize turns a value given for a field into the form pack works on: a nil interface, nil pointer
// or nil slice is no value (false); a pointer is read through; a named integer, float, bool or byte
// slice type becomes its builtin type. Any other value is kept as it is, and the field that reads it
// refuses it.
func normalize(v any) (any, bool) {
	switch x := v.(type) {
	case nil:
		return nil, false
	case uint8, uint16, uint32, uint64, uint, int8, int16, int32, int64, int, float32, float64, bool:
		return v, true
	case []byte:
		return x, x != nil
	case *uint8:
		return derefOf(x)
	case *uint16:
		return derefOf(x)
	case *uint32:
		return derefOf(x)
	case *uint64:
		return derefOf(x)
	case *uint:
		return derefOf(x)
	case *int8:
		return derefOf(x)
	case *int16:
		return derefOf(x)
	case *int32:
		return derefOf(x)
	case *int64:
		return derefOf(x)
	case *int:
		return derefOf(x)
	case *float32:
		return derefOf(x)
	case *float64:
		return derefOf(x)
	case *bool:
		return derefOf(x)
	}
	return normalizeReflect(reflect.ValueOf(v))
}

func derefOf[V any](p *V) (any, bool) {
	if p == nil {
		return nil, false
	}
	return *p, true
}

func normalizeReflect(rv reflect.Value) (any, bool) {
	switch rv.Kind() {
	case reflect.Pointer, reflect.Interface:
		if rv.IsNil() {
			return nil, false
		}
		return normalize(rv.Elem().Interface())
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return rv.Int(), true
	case reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return rv.Uint(), true
	case reflect.Float32:
		return float32(rv.Float()), true
	case reflect.Float64:
		return rv.Float(), true
	case reflect.Bool:
		return rv.Bool(), true
	case reflect.Slice:
		if rv.IsNil() {
			return nil, false
		}
		if rv.Type().Elem().Kind() == reflect.Uint8 {
			return rv.Bytes(), true
		}
	case reflect.Map, reflect.Func, reflect.Chan:
		if rv.IsNil() {
			return nil, false
		}
	}
	return rv.Interface(), true
}

// num is an exact integer of any Go integer type: -mag when neg, else mag. Zero is never neg.
type num struct {
	neg bool
	mag uint64
}

func asInt(v any) (num, bool) {
	switch x := v.(type) {
	case uint8:
		return num{mag: uint64(x)}, true
	case uint16:
		return num{mag: uint64(x)}, true
	case uint32:
		return num{mag: uint64(x)}, true
	case uint64:
		return num{mag: x}, true
	case uint:
		return num{mag: uint64(x)}, true
	case int8:
		return signedNum(int64(x)), true
	case int16:
		return signedNum(int64(x)), true
	case int32:
		return signedNum(int64(x)), true
	case int64:
		return signedNum(x), true
	case int:
		return signedNum(int64(x)), true
	}
	return num{}, false
}

func signedNum(x int64) num {
	if x < 0 {
		return num{neg: true, mag: uint64(-(x + 1)) + 1}
	}
	return num{mag: uint64(x)}
}

// fits reports whether n is in the range of an integer of size bytes.
func (n num) fits(size int, signed bool) bool {
	bits := uint(size * 8)
	if !signed {
		return !n.neg && (bits == 64 || n.mag < 1<<bits)
	}
	limit := uint64(1) << (bits - 1)
	if n.neg {
		return n.mag <= limit
	}
	return n.mag < limit
}

// bits is n as two's complement, 64 bits wide.
func (n num) bits() uint64 {
	if n.neg {
		return -n.mag
	}
	return n.mag
}

func (n num) float() float64 {
	if n.neg {
		return -float64(n.mag)
	}
	return float64(n.mag)
}

// asNumber is any Go integer or float as a float64, for a comparison by value.
func asNumber(v any) (float64, bool) {
	switch x := v.(type) {
	case float32:
		return float64(x), true
	case float64:
		return x, true
	}
	if n, ok := asInt(v); ok {
		return n.float(), true
	}
	return 0, false
}

// sameValue is the eq comparison: two integers compare exactly, an integer and a float by value
// (a whole 5.0 is 5), a bool only with a bool; an absent value (nil) never matches.
func sameValue(seen, want any) bool {
	if seen == nil || want == nil {
		return false
	}
	if a, ok := asInt(seen); ok {
		if b, ok := asInt(want); ok {
			return a == b
		}
	}
	if a, ok := asNumber(seen); ok {
		b, ok := asNumber(want)
		return ok && a == b
	}
	if a, ok := seen.(bool); ok {
		b, ok := want.(bool)
		return ok && a == b
	}
	return false
}

// f32Overflow is the smallest magnitude that rounds to an infinity as a float32: halfway between
// math.MaxFloat32 and 2^128.
const f32Overflow = 0x1p128 - 0x1p103

// asFloat is a value a float field takes: a float or any Go integer.
func asFloat(v any) (float64, bool) {
	return asNumber(v)
}

func overflowsF32(x float64) bool {
	return !math.IsInf(x, 0) && !math.IsNaN(x) && math.Abs(x) >= f32Overflow
}
