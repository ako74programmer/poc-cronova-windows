// Package fsperm restricts files and directories that hold secrets or task
// output to their owner. On Windows, Unix mode bits are not enforced (Chmod
// only toggles the read-only attribute), so the protection is a protected DACL
// granting full control to the owner, SYSTEM and Administrators only.
package fsperm

import "os"

// Private restricts path (file or directory) to its owner. mode is applied on
// platforms that enforce Unix permission bits (0o600 files, 0o700 dirs).
func Private(path string, mode os.FileMode) error {
	return private(path, mode)
}

// IsPrivate reports whether path is restricted as Private would leave it.
func IsPrivate(path string) (bool, error) {
	return isPrivate(path)
}
