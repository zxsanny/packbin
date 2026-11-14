module probe

go 1.26.0

require github.com/zxsanny/packbin/go v0.0.0

require (
	golang.org/x/crypto v0.58.0 // indirect
	golang.org/x/sys v0.49.0 // indirect
)

// The package of this checkout, where run.sh mounts it in the container; with a local go, run.sh
// points the copy it builds at the go/ folder of the checkout instead.
replace github.com/zxsanny/packbin/go => /src/go
