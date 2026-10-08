//go:build !windows

package fsperm

import "os"

func private(path string, mode os.FileMode) error {
	return os.Chmod(path, mode)
}

func isPrivate(path string) (bool, error) {
	fi, err := os.Stat(path)
	if err != nil {
		return false, err
	}
	return fi.Mode().Perm()&0o077 == 0, nil
}
