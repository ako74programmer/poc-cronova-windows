package fsperm

import (
	"os"
	"path/filepath"
	"testing"
)

func TestPrivateFileAndDir(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "secret-dir")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(dir, "secret.txt")
	if err := os.WriteFile(file, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if ok, err := IsPrivate(file); err != nil || ok {
		t.Fatalf("fresh file IsPrivate = %v, %v; want false (inherits a broad ACL)", ok, err)
	}
	if err := Private(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := Private(file, 0o600); err != nil {
		t.Fatal(err)
	}
	for _, p := range []string{dir, file} {
		if ok, err := IsPrivate(p); err != nil || !ok {
			t.Fatalf("IsPrivate(%s) = %v, %v; want true", p, ok, err)
		}
	}
	// still readable and writable by the owner
	if err := os.WriteFile(file, []byte("y"), 0o600); err != nil {
		t.Fatalf("owner lost write access: %v", err)
	}
	if b, err := os.ReadFile(file); err != nil || string(b) != "y" {
		t.Fatalf("owner lost read access: %q %v", b, err)
	}
}
