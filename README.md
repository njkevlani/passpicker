# passpicker

A Golang-based tool that integrates the standard Unix Password Store (`pass`) with a graphical launcher to provide a rich, interactive graphical password manager: `rofi` (in `dmenu` mode) on Linux, and a native AppKit floating panel picker (`macmenu`, inspired by Maccy) on macOS.

## Features

- **Select Passwords**: Fuzzy search and select your passwords using `rofi` (Linux) or native floating panel (macOS).
- `Enter` on an entry opens the **Other Options**
  submenu (`Copy Password` is the first item, so `Enter`, `Enter` copies).
  As a shortcut, typing `<entry> !otp` (or pressing `Option + Enter` on macOS) copies the OTP in one step.
- On macOS, number shortcuts (`⌘1`–`⌘9`) allow instantly picking visible entries without arrow keys.
- **Other Options Submenu**:
  - Copy Password
  - Copy OTP
  - Show Password (displays in a pop-up dialog)
  - Show Full Entry (displays the password file metadata/additional lines)
  - Generate New Password (prompts for length and overwrites the entry)
  - Edit Password Manually (prompts securely for a custom password)
  - Delete Password (safely deletes the password from the store)
- **Create New Password**:
  - Selection of `+ Create New Password` (or typing a name that does not exist and pressing Enter) prompts to create a new password.
  - Choose between generating a random password (16, 24, or 32 characters) or entering one manually.
- **Desktop Notifications**: Uses `notify-send` (Linux) or native notifications (macOS) to confirm when passwords/OTPs are copied or created.

## Installation

### Prerequisites

1. **Golang**: Ensure Go is installed (version 1.16+ recommended).
2. **Password Store**: Make sure `pass` is installed and initialized (plus `pass-otp` for OTP support).
3. **Menu**:
   - Linux: `rofi`.
   - macOS: Built-in native floating panel (`macmenu`). Dialogs and notifications use the built-in `osascript`. (No external menu dependencies required!)
4. **Notify Send**: (Linux, optional) For desktop notifications.

### Arch Linux (AUR)

```bash
paru -S passpicker-bin   # or: yay -S passpicker-bin
```
### Building

Initialize the module and compile the binary:

```bash
go build -o passpicker main.go
```

This will produce a `passpicker` executable in the root directory.

## Usage

Run the compiled binary:

```bash
./passpicker
```

### Integration with Window Managers

To assign `passpicker` to a global hotkey, add a configuration to your window manager:

#### i3wm / Sway
```i3
bindsym $mod+p exec --no-startup-id /path/to/passpicker
```

#### sxhkd
```sxhkdrc
super + p
    /path/to/passpicker
```

#### macOS

Download `passpicker-macos.dmg` from the [releases page](https://github.com/njkevlani/passpicker/releases),
open it, and drag **Pass Picker** to Applications. The runtime dependencies (`pass`, `gpg`) are to be installed from Homebrew.

GPG needs a graphical pinentry to unlock the key from a GUI launch: `brew install pinentry-mac`
and add `pinentry-program /opt/homebrew/bin/pinentry-mac` to `~/.gnupg/gpg-agent.conf`.

## Project Structure

- `cmd/macmenu/`: Native macOS AppKit floating panel picker (`main.swift`).
- `internal/pass/`: Handles interacting with the `pass` CLI, parsing the output tree, and managing passwords/OTPs.
  - [pass.go](file:///home/njkevlani/git/passpicker/internal/pass/pass.go): Exported library APIs.
  - [parser.go](file:///home/njkevlani/git/passpicker/internal/pass/parser.go): Tree-parsing functions.
  - [parser_test.go](file:///home/njkevlani/git/passpicker/internal/pass/parser_test.go): Tests for parser correctness.
- `internal/dmenu/`: Wraps menu execution and inputs. Same API per platform, selected by build tag.
  - `dmenu.go`: Shared `Result`/`ActionType` types and query-suffix parsing.
  - `dmenu_rofi.go`: `rofi` implementation (non-darwin).
  - `dmenu_darwin.go`: Native `macmenu` AppKit floating panel implementation (darwin).
- [main.go](file:///home/njkevlani/git/passpicker/main.go): Core orchestrator loop.
