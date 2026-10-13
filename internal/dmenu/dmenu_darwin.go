//go:build darwin

package dmenu

import (
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
)

//go:embed macmenu.swift
var macmenuSource string

func init() {
	if os.Getenv("LANG") == "" {
		_ = os.Setenv("LANG", "en_US.UTF-8")
	}

	home, _ := os.UserHomeDir()
	extraPaths := []string{
		"/opt/homebrew/bin",
		"/usr/local/bin",
		filepath.Join(home, ".local", "bin"),
		filepath.Join(home, "go", "bin"),
	}

	if exe, err := os.Executable(); err == nil {
		resourcesDir := filepath.Join(filepath.Dir(exe), "../Resources")
		if fi, err := os.Stat(resourcesDir); err == nil && fi.IsDir() {
			extraPaths = append([]string{resourcesDir}, extraPaths...)
		}
	}

	currentPath := os.Getenv("PATH")
	var toAdd []string
	for _, p := range extraPaths {
		if !strings.Contains(currentPath, p) {
			toAdd = append(toAdd, p)
		}
	}
	if len(toAdd) > 0 {
		_ = os.Setenv("PATH", strings.Join(toAdd, ":")+":"+currentPath)
	}
}

var (
	cachedMacMenuPath string
	macMenuInitOnce   sync.Once
	macMenuInitErr    error
)

// getMacMenuPath resolves the path to the native macmenu executable.
// It checks:
// 1. Next to the passpicker executable (or ../Resources/macmenu inside .app bundle)
// 2. Pre-cached in ~/Library/Caches/passpicker/macmenu
// 3. System PATH
// 4. Compiles embedded macmenu.swift via swiftc into ~/Library/Caches/passpicker/macmenu
func getMacMenuPath() (string, error) {
	macMenuInitOnce.Do(func() {
		// 1. Check relative to current executable
		if exePath, err := os.Executable(); err == nil {
			dir := filepath.Dir(exePath)
			candidates := []string{
				filepath.Join(dir, "macmenu"),
				filepath.Join(dir, "../Resources/macmenu"),
			}
			for _, c := range candidates {
				if fi, err := os.Stat(c); err == nil && !fi.IsDir() && fi.Mode()&0111 != 0 {
					cachedMacMenuPath = c
					return
				}
			}
		}

		// 2. Check user cache directory
		home, _ := os.UserHomeDir()
		cacheDir := filepath.Join(home, "Library", "Caches", "passpicker")
		userCachedBin := filepath.Join(cacheDir, "macmenu")
		if fi, err := os.Stat(userCachedBin); err == nil && !fi.IsDir() && fi.Mode()&0111 != 0 {
			cachedMacMenuPath = userCachedBin
			return
		}

		// 3. Check system PATH
		if path, err := exec.LookPath("macmenu"); err == nil {
			cachedMacMenuPath = path
			return
		}

		// 4. Compile embedded Swift source on-the-fly using swiftc
		if swiftc, err := exec.LookPath("swiftc"); err == nil {
			if err := os.MkdirAll(cacheDir, 0755); err != nil {
				macMenuInitErr = fmt.Errorf("failed to create cache dir: %w", err)
				return
			}
			swiftFile := filepath.Join(cacheDir, "macmenu.swift")
			if err := os.WriteFile(swiftFile, []byte(macmenuSource), 0644); err != nil {
				macMenuInitErr = fmt.Errorf("failed to write embedded swift source: %w", err)
				return
			}

			cmd := exec.Command(swiftc, "-O", swiftFile, "-o", userCachedBin)
			var stderr bytes.Buffer
			cmd.Stderr = &stderr
			if err := cmd.Run(); err != nil {
				macMenuInitErr = fmt.Errorf("failed to compile macmenu with swiftc: %w (stderr: %q)", err, stderr.String())
				return
			}

			cachedMacMenuPath = userCachedBin
			return
		}

		// Fallback: Check if choose exists as fallback
		if choose, err := exec.LookPath("choose"); err == nil {
			cachedMacMenuPath = choose
			return
		}

		macMenuInitErr = fmt.Errorf("native picker 'macmenu' not found, swiftc not available to compile it, and choose not found")
	})

	return cachedMacMenuPath, macMenuInitErr
}

// ShowMenu displays a native macOS floating panel (or choose fallback) with the given prompt and items.
// Enter selects the item. Option+Enter or typing "<entry> !otp" copies the OTP directly.
func ShowMenu(prompt string, items []string, message string) (Result, error) {
	menuPath, err := getMacMenuPath()
	if err != nil {
		return Result{}, err
	}

	var cmd *exec.Cmd
	if filepath.Base(menuPath) == "choose" {
		// Legacy choose fallback
		p := prompt
		if message != "" {
			p = prompt + " — " + message
		}
		cmd = exec.Command(menuPath, "-m", "-e", "-n", "20", "-p", p)
	} else {
		// Native AppKit macmenu floating panel
		args := []string{"-p", prompt}
		if message != "" {
			args = append(args, "-m", message)
		}
		cmd = exec.Command(menuPath, args...)
	}

	cmd.Stdin = strings.NewReader(strings.Join(items, "\n"))

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		if _, ok := err.(*exec.ExitError); ok {
			// Window dismissed or Esc pressed
			return Result{Action: ActionCancel}, nil
		}
		return Result{}, fmt.Errorf("failed to run picker: %w (stderr: %q)", err, stderr.String())
	}

	return parseSelection(stdout.String()), nil
}

// ShowPasswordPrompt displays a hidden-answer input dialog using osascript.
func ShowPasswordPrompt(prompt string) (string, error) {
	return dialogInput(prompt, "", true)
}

// ShowInputPrompt displays a generic text input dialog using osascript.
func ShowInputPrompt(prompt string, defaultVal string) (string, error) {
	return dialogInput(prompt, defaultVal, false)
}

func dialogInput(prompt, defaultVal string, hidden bool) (string, error) {
	hiddenClause := ""
	if hidden {
		hiddenClause = " with hidden answer"
	}
	script := fmt.Sprintf(`on run argv
	activate
	set r to display dialog (item 1 of argv) default answer (item 2 of argv)%s with title "Pass Picker"
	return text returned of r
end run`, hiddenClause)

	var stdout, stderr bytes.Buffer
	cmd := exec.Command("osascript", "-e", script, prompt, defaultVal)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		if _, ok := err.(*exec.ExitError); ok {
			return "", nil // User cancelled
		}
		return "", fmt.Errorf("failed to get input: %w (stderr: %q)", err, stderr.String())
	}

	return strings.TrimRight(stdout.String(), "\n"), nil
}

// ShowMessage displays a pop-up dialog with the given message.
func ShowMessage(msg string) error {
	script := `on run argv
	activate
	display dialog (item 1 of argv) buttons {"OK"} default button 1 with title "Pass Picker"
end run`
	return exec.Command("osascript", "-e", script, msg).Run()
}

const notifyScript = `on run argv
	display notification (item 1 of argv) with title (item 2 of argv)
end run`

// NotifyArgv returns the argv of a command that fires a desktop notification.
func NotifyArgv(title, body string) []string {
	return []string{"osascript", "-e", notifyScript, body, title}
}

// NotifySend fires a desktop notification.
func NotifySend(title, body string) {
	argv := NotifyArgv(title, body)
	_ = exec.Command(argv[0], argv[1:]...).Run()
}
