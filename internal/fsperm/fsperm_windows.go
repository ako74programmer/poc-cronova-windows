package fsperm

import (
	"fmt"
	"os"
	"unsafe"

	"golang.org/x/sys/windows"
)

// Owner, SYSTEM and Administrators: full control. "P" = protected (no
// inheritance from the parent); OICI makes directory entries inherit to
// children created later.
const (
	fileSDDL = "D:P(A;;FA;;;OW)(A;;FA;;;SY)(A;;FA;;;BA)"
	dirSDDL  = "D:P(A;OICI;FA;;;OW)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)"
)

func private(path string, _ os.FileMode) error {
	fi, err := os.Stat(path)
	if err != nil {
		return err
	}
	sddl := fileSDDL
	if fi.IsDir() {
		sddl = dirSDDL
	}
	sd, err := windows.SecurityDescriptorFromString(sddl)
	if err != nil {
		return fmt.Errorf("build security descriptor: %w", err)
	}
	dacl, _, err := sd.DACL()
	if err != nil {
		return fmt.Errorf("read DACL: %w", err)
	}
	if err := windows.SetNamedSecurityInfo(path, windows.SE_FILE_OBJECT,
		windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION,
		nil, nil, dacl, nil); err != nil {
		return fmt.Errorf("restrict %s: %w", path, err)
	}
	return nil
}

// isPrivate: DACL is protected and every allow ACE is for the owner, the
// OWNER RIGHTS SID, SYSTEM or Administrators.
func isPrivate(path string) (bool, error) {
	sd, err := windows.GetNamedSecurityInfo(path, windows.SE_FILE_OBJECT,
		windows.DACL_SECURITY_INFORMATION|windows.OWNER_SECURITY_INFORMATION)
	if err != nil {
		return false, err
	}
	control, _, err := sd.Control()
	if err != nil {
		return false, err
	}
	if control&windows.SE_DACL_PROTECTED == 0 {
		return false, nil
	}
	owner, _, err := sd.Owner()
	if err != nil {
		return false, err
	}
	dacl, _, err := sd.DACL()
	if err != nil || dacl == nil {
		return false, err
	}
	allowed := []*windows.SID{owner}
	for _, known := range []windows.WELL_KNOWN_SID_TYPE{windows.WinCreatorOwnerRightsSid, windows.WinLocalSystemSid, windows.WinBuiltinAdministratorsSid} {
		if sid, err := windows.CreateWellKnownSid(known); err == nil {
			allowed = append(allowed, sid)
		}
	}
	for i := uint32(0); i < uint32(dacl.AceCount); i++ {
		var ace *windows.ACCESS_ALLOWED_ACE
		if err := windows.GetAce(dacl, i, &ace); err != nil {
			return false, err
		}
		if ace.Header.AceType != windows.ACCESS_ALLOWED_ACE_TYPE {
			continue
		}
		sid := (*windows.SID)(unsafe.Pointer(&ace.SidStart))
		ok := false
		for _, a := range allowed {
			if sid.Equals(a) {
				ok = true
				break
			}
		}
		if !ok {
			return false, nil
		}
	}
	return true, nil
}
