package packbin

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// AC-8: go.mod declares go 1.26 and requires at most golang.org/x/crypto; no cgo; MIT license.
// go vet and gofmt -l run beside the tests in the same command.
func TestAC8GoModDeclaresGo126AndOneDependencyAtMost(t *testing.T) {
	// Arrange
	raw, err := os.ReadFile("go.mod")
	if err != nil {
		t.Fatal(err)
	}
	mod := string(raw)

	// Act
	requires := regexp.MustCompile(`(?m)^\s*(?:require\s+)?([a-z0-9.\-]+\.[a-z]+/[^\s]+)\s+v[0-9]`).FindAllStringSubmatch(mod, -1)

	// Assert
	if !regexp.MustCompile(`(?m)^module github\.com/zxsanny/packbin/go$`).MatchString(mod) {
		t.Fatalf("module line: %s", mod)
	}
	if !regexp.MustCompile(`(?m)^go 1\.26$`).MatchString(mod) {
		t.Fatalf("go line: %s", mod)
	}
	if len(requires) > 1 || (len(requires) == 1 && requires[0][1] != "golang.org/x/crypto") {
		t.Fatalf("requires: %v", requires)
	}
}

func TestAC8NoCgoFiles(t *testing.T) {
	// Arrange
	files, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatal(err)
	}
	cgo := regexp.MustCompile(`(?m)^\s*import\s+"C"\s*$`)

	for _, f := range files {
		// Act
		raw, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}

		// Assert
		if cgo.Match(raw) {
			t.Fatalf("%s imports C", f)
		}
	}
}

func TestAC8LicenseIsMIT(t *testing.T) {
	// Act
	raw, err := os.ReadFile("LICENSE")

	// Assert
	if err != nil {
		t.Fatal(err)
	}
	text := string(raw)
	if !strings.HasPrefix(text, "MIT License") || !strings.Contains(text, "Permission is hereby granted, free of charge") {
		t.Fatalf("not MIT: %.80s", text)
	}
}
