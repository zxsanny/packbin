package packbin

// flagBitRef is one bit of a flag byte, with the values of the row its field reads (inside a group,
// the group's own values).
type flagBitRef struct {
	bit    int
	field  *node
	values map[string]any
}

// collectFlagBits finds the bits of the flag byte tag among fields, at any depth of the scope (a
// round is a scope of its own, so its bits belong to a byte read in it).
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
// given (its values are a map of their own, so a member can be given only with it), or when a member
// is on without a value (a times whose count is above 0). A when is on when
// its condition holds on what pack has written so far and its body holds a value; a times when its
// count is above 0 (a count that was not written is no round; a count of 0 refuses a list of values);
// a repeat when a round holds a value; a u2 when any slot has a value. A member that is on and cannot
// be written in full fails when it is packed.
func bitOn(f *node, values, wrote map[string]any) (bool, error) {
	switch f.kind {
	case kindBool:
		on, _ := values[f.name].(bool)
		return on, nil
	case kindGroup:
		if len(f.fields) == 0 {
			on, _ := values[f.name].(bool)
			return on, nil
		}
		if _, ok := values[f.name]; ok {
			return true, nil
		}
		// Not given, it holds no value, but a times in it whose count is above 0 still writes rounds.
		return anyBitOn(f.fields, nil, wrote)
	case kindFlags, kindU2:
		return anyBitOn(f.fields, values, wrote)
	case kindFlagBit:
		return bitOn(f.field, values, wrote)
	case kindWhen:
		if !sameValue(written(wrote, f.ref), f.eqValue) {
			return false, nil
		}
		return anyBitOn(f.fields, values, wrote)
	case kindTimes:
		if _, ok := wrote[f.ref]; !ok {
			return false, nil
		}
		count, err := borrowedCount(f, 0, wrote)
		if err != nil {
			return false, err
		}
		if count == 0 {
			if err := refuseLongLists(f.shape, values, 0); err != nil {
				return false, err
			}
			if err := refuseLoneBuffers(f.shape, values); err != nil {
				return false, err
			}
		}
		return count > 0, nil
	case kindRepeat:
		return roundCount(f.shape, values) > 0, nil
	case kindFlagByte:
		return false, nil
	}
	_, ok := values[f.name]
	return ok, nil
}

func anyBitOn(fields []*node, values, wrote map[string]any) (bool, error) {
	for _, child := range fields {
		on, err := bitOn(child, values, wrote)
		if on || err != nil {
			return on, err
		}
	}
	return false, nil
}

// heldField is the first field under f that holds a value, at any depth; nil when none does. A round
// holds one when it has a round, or a lone buffer that would reach every round.
func heldField(f *node, values map[string]any) *node {
	switch f.kind {
	case kindBool:
		if on, _ := values[f.name].(bool); on {
			return f
		}
		return nil
	case kindGroup:
		v, ok := values[f.name]
		if on, _ := v.(bool); ok && (len(f.fields) > 0 || on) {
			return f
		}
		return nil
	case kindFlags, kindWhen, kindU2:
		return firstHeld(f.fields, values)
	case kindRepeat, kindTimes:
		lone := false
		for _, n := range f.shape.buffers {
			_, given := values[n.name]
			lone = lone || given
		}
		if roundCount(f.shape, values) > 0 || lone {
			return firstHeld(f.fields, values)
		}
		return nil
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

// countNeverWritten reports a times in the scope of f (itself, or under groups, flags, flag bits and
// a when whose condition holds) that holds a value although its count was never written.
func countNeverWritten(f *node, values, wrote map[string]any) bool {
	switch f.kind {
	case kindTimes:
		_, ok := wrote[f.ref]
		return !ok && heldField(f, values) != nil
	case kindWhen:
		if !sameValue(written(wrote, f.ref), f.eqValue) {
			return false
		}
		return anyNeverWritten(f.fields, values, wrote)
	case kindGroup:
		return anyNeverWritten(f.fields, groupValues(values, f), wrote)
	case kindFlags:
		return anyNeverWritten(f.fields, values, wrote)
	case kindFlagBit:
		return countNeverWritten(f.field, values, wrote)
	}
	return false
}

func anyNeverWritten(fields []*node, values, wrote map[string]any) bool {
	for _, child := range fields {
		if countNeverWritten(child, values, wrote) {
			return true
		}
	}
	return false
}

// droppedBody: a flag byte decides a bit as it stands (a split byte where it is read). When the bit
// came out clear but the member holds a value that a later look would write (its when condition now
// holds, its times count is now known), or that waits for a count no field ever wrote, the value would
// be dropped: it returns the field that holds it, else nil. A when whose condition is false stays a
// silent skip.
func droppedBody(f *node, values, wrote map[string]any) (*node, error) {
	held := heldField(f, values)
	if held == nil {
		return nil, nil
	}
	on, err := bitOn(f, values, wrote)
	if err != nil {
		return nil, err
	}
	if on || countNeverWritten(f, values, wrote) {
		return held, nil
	}
	return nil, nil
}

// flagValueFor is the byte a split flag byte writes: a bit for each member on where the byte sits.
func flagValueFor(root scopeRoot, tag *flagTag, wrote map[string]any) (byte, error) {
	var flags byte
	for _, b := range collectFlagBits(root.fields, tag, root.values, nil) {
		on, err := bitOn(b.field, b.values, wrote)
		if err != nil {
			return 0, err
		}
		if on {
			flags |= 1 << b.bit
		}
	}
	return flags, nil
}
