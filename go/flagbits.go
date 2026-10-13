package packbin

type flagBitRef struct {
	bit   int
	field *node
}

// collectFlagBits finds the bits of the flag byte tag among fields, at any depth.
func collectFlagBits(fields []*node, tag *flagTag, out []flagBitRef) []flagBitRef {
	for _, f := range fields {
		switch f.kind {
		case kindFlagBit:
			if f.tag == tag {
				out = append(out, flagBitRef{bit: f.bit, field: f.field})
			}
			out = collectFlagBits([]*node{f.field}, tag, out)
		case kindWhen:
			out = collectFlagBits(f.fields, tag, out)
		}
	}
	return out
}

// bitOn reports whether a flag bit's member holds a value at any depth. A bool is a mark with no
// bytes of its own, and only true sets its bit. A when is on when its condition holds on what pack
// has written so far and its body holds a value. A member that is on and cannot be written in full
// fails when it is packed.
func bitOn(f *node, values, wrote map[string]any) bool {
	switch f.kind {
	case kindBool:
		on, _ := values[f.name].(bool)
		return on
	case kindFlags:
		return anyBitOn(f.fields, values, wrote)
	case kindFlagBit:
		return bitOn(f.field, values, wrote)
	case kindWhen:
		return sameValue(written(wrote, f.ref), f.eqValue) && anyBitOn(f.fields, values, wrote)
	case kindFlagByte:
		return false
	}
	_, ok := values[f.name]
	return ok
}

func anyBitOn(fields []*node, values, wrote map[string]any) bool {
	for _, child := range fields {
		if bitOn(child, values, wrote) {
			return true
		}
	}
	return false
}

// heldField is the first field under f that holds a value, at any depth; nil when none does.
func heldField(f *node, values map[string]any) *node {
	switch f.kind {
	case kindBool:
		if on, _ := values[f.name].(bool); on {
			return f
		}
		return nil
	case kindFlags, kindWhen:
		return firstHeld(f.fields, values)
	case kindFlagBit:
		return heldField(f.field, values)
	case kindFlagByte:
		return nil
	}
	if _, ok := values[f.name]; ok {
		return f
	}
	return nil
}

func firstHeld(fields []*node, values map[string]any) *node {
	for _, f := range fields {
		if held := heldField(f, values); held != nil {
			return held
		}
	}
	return nil
}

// droppedBody: a split flag byte decides its bits where it is read. When the bit came out clear but
// the member holds a value that a look at what is written now would write (its when condition now
// holds), the value would be dropped: it returns the field that holds it, else nil. A when whose
// condition is false stays a silent skip.
func droppedBody(f *node, values, wrote map[string]any) *node {
	held := heldField(f, values)
	if held == nil || !bitOn(f, values, wrote) {
		return nil
	}
	return held
}

// flagValueFor is the byte a split flag byte writes: a bit for each member on where the byte sits.
func flagValueFor(all []*node, tag *flagTag, values, wrote map[string]any) byte {
	var flags byte
	for _, b := range collectFlagBits(all, tag, nil) {
		if bitOn(b.field, values, wrote) {
			flags |= 1 << b.bit
		}
	}
	return flags
}
