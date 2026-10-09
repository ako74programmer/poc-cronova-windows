//go:build !windows

package fsperm

// Cronova is a Windows-only product (Windows services, PowerShell task
// runtime, Job Objects, ACLs). Building for another OS fails here on purpose.
const _ = cronova_supports_windows_only
