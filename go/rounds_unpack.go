package packbin

import "reflect"

// reachKey is a round and the row it is read into, so a round in each item of a list or dict, and in
// each nested row, is told apart. A row is a map made for one place, so its address names it.
type reachKey struct {
	row uintptr
	r   *node
}

func reachOf(values map[string]any, r *node) reachKey {
	return reachKey{row: reflect.ValueOf(values).Pointer(), r: r}
}

// unreadable is the error of a count that is absent, negative or too large to read: the counted
// field, nothing more needed, the bytes left where it starts.
func (r *reader) unreadable(id int, name string) *Error {
	return shortErr(id, name, 0, len(r.buf)-r.off)
}

// chargeRound charges the round of f that starts next, round number i (counted from 0) of its field:
// a round past MaxRounds, or one that would take the slots of the call past MaxSlots, is refused with
// the bytes left where it would start, before it allocates anything.
func (r *reader) chargeRound(f *node, i int) error {
	id, name := roundMember(f)
	if i >= r.lim.MaxRounds {
		return tooMany(id, name, len(r.buf)-r.off, "round %d is above the limit of %d rounds", i+1, r.lim.MaxRounds)
	}
	if width := f.shape.width; width > r.lim.MaxSlots-r.slots {
		return tooMany(id, name, len(r.buf)-r.off, "the rounds would hold %d slots, above the limit of %d slots",
			r.slots+width, r.lim.MaxSlots)
	}
	r.slots += f.shape.width
	return nil
}

// readCount is the count f reads from the scope plus bias; false when the count field was not read
// (a clear bit, a false when) or the count is negative or too large.
func (r *reader) readCount(f *node, bias int) (int, bool) {
	n, ok := asInt(r.seen[f.ref])
	if !ok {
		return 0, false
	}
	return countOf(n, bias)
}

// counted reads a sized, bits, packed, u2, repeat or times field.
func (r *reader) counted(f *node, values map[string]any) error {
	switch f.kind {
	case kindSized:
		count, ok := r.readCount(f, 0)
		if !ok {
			return r.unreadable(f.id, f.name)
		}
		b, err := r.take(f, count)
		if err != nil {
			return err
		}
		r.put(values, f.name, append([]byte{}, b...))
	case kindBits, kindPacked:
		width := 1
		if f.kind == kindPacked {
			width = f.width
		}
		count, ok := r.readCount(f, f.bias)
		if !ok {
			return r.unreadable(f.id, f.name)
		}
		b, err := r.take(f, itemBytes(width, count))
		if err != nil {
			return err
		}
		items := make([]byte, count)
		mask := byte(1)<<width - 1
		for i := range items {
			items[i] = b[i*width/8] >> (i * width % 8) & mask
		}
		r.put(values, f.name, items)
	case kindU2:
		b, err := r.take(f, (len(f.fields)+3)/4)
		if err != nil {
			return err
		}
		for i, slot := range f.fields {
			r.put(values, slot.name, b[i>>2]>>((i&3)*2)&3)
		}
	case kindRepeat:
		return r.rounds(f, -1, values)
	case kindTimes:
		count, ok := r.readCount(f, 0)
		if !ok {
			id, name := roundMember(f)
			return r.unreadable(id, name)
		}
		return r.rounds(f, count, values)
	}
	return nil
}

// rounds reads the rounds of f: count of them, or for a repeat (count < 0) until the buffer ends. Each
// round is read into a row and a scope of its own; then every name a round can hold gets one entry a
// round, nil where the round skipped it (none when there was no round).
func (r *reader) rounds(f *node, count int, values map[string]any) error {
	if r.reached == nil {
		r.reached = map[reachKey]bool{}
	}
	r.reached[reachOf(values, f)] = true
	savedSeen, savedSplit := r.seen, r.split
	defer func() { r.seen, r.split = savedSeen, savedSplit }()
	var rows []map[string]any
	for i := 0; count < 0 || i < count; i++ {
		if count < 0 && r.off >= len(r.buf) {
			break
		}
		// A round starts here: the one place the round limits charge it, before any of its bytes.
		if err := r.chargeRound(f, i); err != nil {
			return err
		}
		before := r.off
		one := make(map[string]any, len(f.shape.names))
		r.enter(f.inner, one)
		if err := r.fields(f.fields, one); err != nil {
			return err
		}
		if r.off == before {
			if count >= 0 {
				// A times round that reads nothing would repeat up to count times for no input.
				id, name := roundMember(f)
				return r.unreadable(id, name)
			}
			// A repeat round that reads nothing ends the repeat; the bytes left are trailing.
			rows = append(rows, one)
			break
		}
		rows = append(rows, one)
	}
	if len(rows) == 0 {
		return nil
	}
	for _, n := range f.shape.names {
		list := make([]any, len(rows))
		for i, one := range rows {
			list[i] = one[n.name]
		}
		if count < 0 {
			appendList(values, n.name, list)
		} else {
			values[n.name] = list
		}
	}
	return nil
}
