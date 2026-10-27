package packbin

import "fmt"

// frameKeys are the keys of one (key, epoch) for the loaded directions: K_enc(d) and K_mac(d), derived once at
// load. A direction not loaded has nil slices.
type frameKeys struct {
	epoch uint32
	enc   [3][]byte
	mac   [3][]byte
}

// deriveFrameKeys is the key schedule of the contract:
// K(d, use) = HKDF(IKM = key, salt = "packbin-frame" || epoch, info = [d] || use, L = 32).
func deriveFrameKeys(key []byte, epoch uint32, directions FrameDirections) (*frameKeys, error) {
	keys := &frameKeys{epoch: epoch}
	salt := frameSalt(epoch)
	for d := 1; d <= 3; d++ {
		if directions&(1<<(d-1)) == 0 {
			continue
		}
		for _, use := range []struct {
			name string
			out  *[3][]byte
		}{{"enc", &keys.enc}, {"mac", &keys.mac}} {
			derived, err := hkdfSHA256(key, salt, append([]byte{byte(d)}, use.name...), 32)
			if err != nil {
				keys.wipe()
				return nil, fmt.Errorf("packbin: frame key schedule: %w", err)
			}
			use.out[d-1] = derived
		}
	}
	return keys, nil
}

// wipe overwrites every key slice (best effort, see FrameSession). A nil receiver is allowed.
func (k *frameKeys) wipe() {
	if k == nil {
		return
	}
	for d := range k.enc {
		wipe(k.enc[d])
		wipe(k.mac[d])
	}
}

// arrays lists the key slices (test access: a test keeps them and reads them after Close).
func (k *frameKeys) arrays() [][]byte {
	var out [][]byte
	if k == nil {
		return out
	}
	for d := range k.enc {
		if k.enc[d] != nil {
			out = append(out, k.enc[d], k.mac[d])
		}
	}
	return out
}
