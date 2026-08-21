//go:build darwin

package dmenu

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// ShowMenu displays a choose(1) menu with the given prompt and items.
// Typing "<entry> !otp" copies the OTP directly.
func ShowMenu(prompt string, items []string, message string) (Result, error) {
	if message != "" {
		prompt = prompt + " — " + message
	}

	cmd := exec.Command("choose", "-m", "-e", "-n", "20", "-p", prompt)
	cmd.Stdin = strings.NewReader(strings.Join(items, "\n"))

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		if _, ok := err.(*exec.ExitError); !ok {
			return Result{}, fmt.Errorf("failed to run choose: %w (stderr: %q)", err, stderr.String())
		}
		return Result{Action: ActionCancel}, nil // Escape
	}

	return parseSelection(stdout.String()), nil
}

// ShowPasswordPrompt displays a hidden-answer input dialog.
func ShowPasswordPrompt(prompt string) (string, error) {
	return dialogInput(prompt, "", true)
}

// ShowInputPrompt displays a generic text input dialog.
func ShowInputPrompt(prompt string, defaultVal string) (string, error) {
	return dialogInput(prompt, defaultVal, false)
}

func dialogInput(prompt, defaultVal string, hidden bool) (string, error) {
	hiddenClause := ""
	if hidden {
		hiddenClause = " with hidden answer"
	}
	script := fmt.Sprintf(`on run argv
	set r to display dialog (item 1 of argv) default answer (item 2 of argv)%s with title "gopassrofi"
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
	display dialog (item 1 of argv) buttons {"OK"} default button 1 with title "gopassrofi"
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
