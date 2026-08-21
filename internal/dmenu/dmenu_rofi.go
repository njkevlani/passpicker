//go:build !darwin

package dmenu

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

// ShowMenu displays a rofi dmenu with the given prompt and items.
// Enter is the only action; typing "<entry> !otp" copies the OTP directly.
func ShowMenu(prompt string, items []string, message string) (Result, error) {
	cmd := exec.Command("rofi",
		"-dmenu",
		"-p", prompt,
		"-kb-accept-custom", "", // Clear Control+Return so Return is the only accept key
		"-i", // Case-insensitive matching
	)

	if message != "" {
		cmd.Args = append(cmd.Args, "-mesg", message)
	}

	cmd.Stdin = strings.NewReader(strings.Join(items, "\n"))

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	exitCode := 0
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			exitCode = exitError.ProcessState.ExitCode()
		} else {
			return Result{}, fmt.Errorf("failed to run rofi: %w (stderr: %q)", err, stderr.String())
		}
	}

	switch exitCode {
	case 0:
		return parseSelection(stdout.String()), nil
	case 1:
		return Result{Action: ActionCancel}, nil
	default:
		return Result{}, fmt.Errorf("rofi exited with unexpected code %d (stderr: %q)", exitCode, stderr.String())
	}
}

// ShowPasswordPrompt displays a rofi password-hidden input field.
func ShowPasswordPrompt(prompt string) (string, error) {
	cmd := exec.Command("rofi",
		"-dmenu",
		"-password",
		"-p", prompt,
	)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok && exitError.ProcessState.ExitCode() == 1 {
			return "", nil // User cancelled
		}
		return "", fmt.Errorf("failed to get password: %w (stderr: %q)", err, stderr.String())
	}

	return strings.TrimSpace(stdout.String()), nil
}

// ShowInputPrompt displays a generic rofi text input field.
func ShowInputPrompt(prompt string, defaultVal string) (string, error) {
	args := []string{"-dmenu", "-p", prompt}
	if defaultVal != "" {
		args = append(args, "-filter", defaultVal)
	}
	cmd := exec.Command("rofi", args...)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok && exitError.ProcessState.ExitCode() == 1 {
			return "", nil // User cancelled
		}
		return "", fmt.Errorf("failed to get input: %w (stderr: %q)", err, stderr.String())
	}

	return strings.TrimSpace(stdout.String()), nil
}

// ShowMessage displays a pop-up dialog with the given message using rofi -e.
func ShowMessage(msg string) error {
	cmd := exec.Command("rofi", "-e", msg)
	return cmd.Run()
}

// NotifyArgv returns the argv of a command that fires a desktop notification.
func NotifyArgv(title, body string) []string {
	return []string{"notify-send", title, body}
}

// NotifySend fires a desktop notification using notify-send.
func NotifySend(title, body string) {
	_ = exec.Command("notify-send", title, body).Run()
}
