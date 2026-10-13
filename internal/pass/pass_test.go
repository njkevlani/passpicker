package pass

import (
	"os/exec"
	"testing"
)

func TestGetPasswordsLive(t *testing.T) {
	if _, err := exec.LookPath("pass"); err != nil {
		t.Skip("pass not found in PATH")
	}

	pwds, err := GetPasswords()
	if err != nil {
		t.Skipf("skipping live test because password store is not initialized or accessible: %v", err)
	}

	if len(pwds) == 0 {
		t.Skip("skipping live test because password store is empty")
	}

	t.Logf("Found %d passwords from live store", len(pwds))
}
