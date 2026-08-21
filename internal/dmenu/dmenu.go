package dmenu

// ActionType represents how the user exited the menu.
type ActionType int

const (
	ActionAccept  ActionType = iota // Enter
	ActionCancel                    // Escape
	ActionCustom1                   // Copy OTP
	ActionCustom2                   // Other options
	ActionUnknown
)

// Result represents the selection and the action taken by the user.
type Result struct {
	Selection string
	Action    ActionType
}
