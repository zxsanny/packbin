package packbin

// flagBitRef is one bit of a flag byte, with the values of the row its field reads (inside a group,
// the group's own values).
type flagBitRef struct {
	bit    int
	field  *node
	values map[string]any
}

// collectFlagBits finds the bits of the flag byte tag among fields, at any depth.
func collectFlagBits(fields []*node, tag *flagTag, values map[string]any, out []flagBitRef) []flagBitRef {
	for _, f := range fields {
		switch f.kind {
		case kindFlagBit:
			if f.tag == tag {
				out = append(out, flagBitRef{bit: f.bit, field: f.field, values: values})
			}
			out = collectFlagBits([]*node{f.field}, tag, values, out)
		case kindWhen:
			out = collectFlagBits(f.fields, tag, values, out)
		case kindGroup:
			out = collectFlagBits(f.fields, tag, groupValues(values, f), out)
		}
	}
	return out
}

// groupValues is the map a group's members read, nil when the group is not given.
func groupValues(values map[string]any, g *node) map[string]any {
	sub, _ := values[g.name].(map[string]any)
	return sub
}

// bitOn reports whether a flag bit's member holds a value at any depth. A bool or an empty group is a
// mark with no bytes of its own, and only true sets its bit. A group with members is on when it is
// given (its values are a map of their own, so a member can be given only with it). A when is on when its condition holds on what pack
// has written so far and its body holds a value. A member that is on and cannot be written in full
// fails when it is packed.
func bitOn(f *node, values, wrote map[string]any) bool {
	switch f.kind {
	case kindBool:
		on, _ := values[f.name].(bool)
		return on
	case kindGroup:
		if len(f.fields) == 0 {
			on, _ := values[f.name].(bool)
			return on
		}
		_, ok := values[f.name]
		return ok
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
	case kindGroup:
		if bitOn(f, values, nil) {
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
func flagValueFor(root scopeRoot, tag *flagTag, wrote map[string]any) byte {
	var flags byte
	for _, b := range collectFlagBits(root.fields, tag, root.values, nil) {
		if bitOn(b.field, b.values, wrote) {
			flags |= 1 << b.bit
		}
	}
	return flags
}
