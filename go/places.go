package packbin

import "fmt"

// place is one row of a scheme: the top level, a group, or the row of one round. Its members are the
// value fields, the groups and the rounds at any depth in it (under flags, flag bits, when and u2)
// outside a group or round of its own, in scheme order. A group's or round's own members are its
// inner place; in a map row the names of a round's members are names of the place around it.
type place struct {
	members []*node
	// rounds are the repeat and times members.
	rounds []*node
	// marks are the bools and empty groups whose name no other kind of field of the place declares:
	// a map row gives each of them a bool.
	marks []*node
	// rows are the groups with members whose name no other kind of field of the place declares: a
	// map row gives each of them a map[string]any.
	rows []*node
	// nested: a group with members stands in this place.
	nested bool
	// foreign are the names declared only inside a group of this place (at any depth, in a round's
	// group too), in scheme order, with the groups from this place to them: a map row that gives one
	// flat while a group on its path is not given is refused (owner decision Go-4).
	foreign []foreignName
}

type foreignName struct {
	member *node
	path   []*node
}

// buildPlace collects the place of nodes, as pack and unpack walk them (a flags by its flag bits).
// It sets the inner place of each group; the groups are this scheme's own copies.
func buildPlace(nodes []*node) *place {
	pl := &place{}
	pl.collect(nodes)
	classes := map[string]int{}
	for _, n := range pl.members {
		if !isRound(n) {
			classes[n.name] |= memberClass(n)
		}
	}
	for _, n := range pl.members {
		if isRound(n) || classes[n.name] != memberClass(n) {
			continue // a name a when branch declares as another kind: its value is checked where it is written
		}
		switch {
		case isMark(n):
			pl.marks = append(pl.marks, n)
		case n.kind == kindGroup:
			pl.rows = append(pl.rows, n)
		}
	}
	pl.foreign = foreignNames(pl)
	return pl
}

func (pl *place) collect(nodes []*node) {
	for _, n := range nodes {
		switch n.kind {
		case kindInt, kindFloat, kindBytes, kindBool, kindSized, kindBits, kindPacked, kindSlot:
			pl.members = append(pl.members, n)
		case kindU2:
			pl.collect(n.fields)
		case kindRepeat, kindTimes:
			// Its row and shape were made when its references were bound.
			pl.members = append(pl.members, n)
			pl.rounds = append(pl.rounds, n)
		case kindGroup:
			if len(n.fields) > 0 {
				n.inner = buildPlace(n.fields)
				pl.nested = true
			}
			pl.members = append(pl.members, n)
		case kindFlagBit:
			pl.collect([]*node{n.field})
		case kindWhen:
			pl.collect(n.fields)
		case kindFlags:
			pl.collect(n.flat)
		}
	}
}

const (
	classValue = 1 << iota
	classMark
	classRow
)

func memberClass(n *node) int {
	switch {
	case isMark(n):
		return classMark
	case n.kind == kindGroup:
		return classRow
	}
	return classValue
}

// checkBinding returns the accessor of a typed scheme (every member of the top level bound to one row
// type, and every member of a bound group to the type of that group), nil for a map scheme (none
// bound), and refuses a mix.
func checkBinding(top *place) (*accessor, error) {
	first, err := placeBinding(top)
	if err != nil {
		return nil, err
	}
	return first, checkGroupBindings(top)
}

// placeBinding: the members of one place are bound to one row type, or none is.
func placeBinding(pl *place) (*accessor, error) {
	var first *accessor
	var unbound *node
	for _, n := range pl.members {
		if n.acc == nil {
			if unbound == nil {
				unbound = n
			}
			continue
		}
		if first == nil {
			first = n.acc
			continue
		}
		if n.acc.rowType != first.rowType {
			return nil, schemeErr(n.id, n.name, "bound to row type %v, but an earlier field is bound to %v",
				n.acc.rowType, first.rowType)
		}
	}
	if first != nil && unbound != nil {
		return nil, schemeErr(unbound.id, unbound.name,
			"not bound to row type %v; bind every value field of a scheme, or none", first.rowType)
	}
	return first, nil
}

// checkGroupBindings: a bound group's members are bound to the group's row type; an unbound group's
// members are not bound.
func checkGroupBindings(pl *place) error {
	for _, g := range pl.members {
		if g.inner == nil {
			continue
		}
		inner, err := placeBinding(g.inner)
		if err != nil {
			return err
		}
		switch {
		case g.acc == nil && inner != nil:
			at := firstBound(g.inner)
			return schemeErr(at.id, at.name, "bound to row type %v, but its %s is not bound", inner.rowType, ownerLabel(g))
		case g.acc != nil && inner == nil && len(g.inner.members) > 0:
			at := g.inner.members[0]
			return schemeErr(at.id, at.name, "not bound to row type %v (the row of %s); bind every value field "+
				"of a scheme, or none", g.acc.childType, ownerLabel(g))
		case g.acc != nil && inner != nil && inner.rowType != g.acc.childType:
			at := firstBound(g.inner)
			return schemeErr(at.id, at.name, "bound to row type %v, but its %s is bound to %v",
				inner.rowType, ownerLabel(g), g.acc.childType)
		}
		if err := checkGroupBindings(g.inner); err != nil {
			return err
		}
	}
	return nil
}

func firstBound(pl *place) *node {
	for _, n := range pl.members {
		if n.acc != nil {
			return n
		}
	}
	return pl.members[0]
}

// ownerLabel names a group (group g) or a round (repeat 0) in a message.
func ownerLabel(n *node) string {
	if isRound(n) {
		return fmt.Sprintf("%s %d", kindLabel(n), n.id)
	}
	return "group " + n.name
}

// foreignNames lists the names declared inside the groups of pl (and of its rounds) that pl itself
// does not declare.
func foreignNames(pl *place) []foreignName {
	own := map[string]bool{}
	var groups []*node
	for _, n := range pl.members {
		if !isRound(n) {
			own[n.name] = true
			if n.kind == kindGroup && n.inner != nil {
				groups = append(groups, n)
			}
			continue
		}
		for _, m := range n.inner.members {
			own[m.name] = true
			if m.kind == kindGroup && m.inner != nil {
				groups = append(groups, m)
			}
		}
	}
	var out []foreignName
	seen := map[string]bool{}
	var walk func(g *node, path []*node)
	walk = func(g *node, path []*node) {
		path = append(path[:len(path):len(path)], g)
		for _, m := range g.inner.members {
			names := []*node{m}
			if isRound(m) {
				names = m.inner.members
			}
			for _, x := range names {
				if !own[x.name] && !seen[x.name] {
					seen[x.name] = true
					out = append(out, foreignName{member: x, path: path})
				}
				if x.kind == kindGroup && x.inner != nil {
					walk(x, path)
				}
			}
		}
	}
	for _, g := range groups {
		walk(g, nil)
	}
	return out
}
