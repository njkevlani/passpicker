package dmenu

import "strings"

// ActionType represents how the user exited the menu.
type ActionType int

const (
	ActionAccept  ActionType = iota // Enter
	ActionCancel                    // Escape
	ActionCustom1                   // Copy OTP
	ActionUnknown
)

// Result represents the selection and the action taken by the user.
type Result struct {
	Selection string
	Action    ActionType
}

// Enter is the only action on both platforms, so extra actions are typed as a
// suffix on the query instead of bound to a modifier key.
// ponytail: text suffix, revisit if both menus ever grow the same key bindings.
var suffixActions = map[string]ActionType{
	" !otp": ActionCustom1,
}

// parseSelection turns menu output into a Result, peeling off any action suffix.
func parseSelection(out string) Result {
	selection := strings.TrimSpace(out)
	if selection == "" {
		return Result{Action: ActionCancel}
	}

	for suffix, action := range suffixActions {
		if strings.HasSuffix(selection, suffix) {
			return Result{Selection: strings.TrimSpace(strings.TrimSuffix(selection, suffix)), Action: action}
		}
	}

	return Result{Selection: selection, Action: ActionAccept}
}
