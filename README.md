# passpicker

A Golang-based tool that integrates the standard Unix Password Store (`pass`) with a graphical launcher to provide a rich, interactive graphical password manager: `rofi` (in `dmenu` mode) on Linux, [`choose`](https://github.com/chipsenkbeil/choose) on macOS.

## Features

- **Select Passwords**: Fuzzy search and select your passwords using `rofi`.
- `Enter` on an entry opens the **Other Options**
  submenu (`Copy Password` is the first item, so `Enter`, `Enter` copies).
  As a shortcut, typing `<entry> !otp` copies the OTP in one step.
- **Other Options Submenu**:
  - Copy Password
  - Copy OTP
  - Show Password (displays in a `rofi` pop-up dialog)
  - Show Full Entry (displays the password file metadata/additional lines)
  - Generate New Password (prompts for length and overwrites the entry)
  - Edit Password Manually (prompts securely for a custom password)
  - Delete Password (safely deletes the password from the store)
- **Create New Password**:
  - Selection of `+ Create New Password` (or typing a name that does not exist and pressing Enter) prompts to create a new password.
  - Choose between generating a random password (16, 24, or 32 characters) or entering one manually.
- **Desktop Notifications**: Uses `notify-send` to confirm when passwords/OTPs are copied or created.

## Installation

### Prerequisites

1. **Golang**: Ensure Go is installed (version 1.16+ recommended).
2. **Password Store**: Make sure `pass` is installed and initialized (plus `pass-otp` for OTP support).
3. **Menu**:
   - Linux: `rofi`.
   - macOS: `brew install choose-gui`. Dialogs and notifications use the built-in `osascript`.
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

Install the binary somewhere on your `PATH`, then install the launcher app bundle:

```bash
go build -o ~/.local/bin/passpicker main.go
cp -R "resources/Pass Picker.app" /Applications/
```
GPG needs a graphical pinentry to unlock the key from a GUI launch: `brew install pinentry-mac`
and add `pinentry-program /opt/homebrew/bin/pinentry-mac` to `~/.gnupg/gpg-agent.conf`.

## Project Structure

- `internal/pass/`: Handles interacting with the `pass` CLI, parsing the output tree, and managing passwords/OTPs.
  - [pass.go](file:///home/njkevlani/git/passpicker/internal/pass/pass.go): Exported library APIs.
  - [parser.go](file:///home/njkevlani/git/passpicker/internal/pass/parser.go): Tree-parsing functions.
  - [parser_test.go](file:///home/njkevlani/git/passpicker/internal/pass/parser_test.go): Tests for parser correctness.
- `internal/dmenu/`: Wraps menu execution and inputs. Same API per platform, selected by build tag.
  - `dmenu.go`: Shared `Result`/`ActionType` types and query-suffix parsing.
  - `dmenu_rofi.go`: `rofi` implementation (non-darwin).
  - `dmenu_choose.go`: `choose` + `osascript` implementation (darwin).
- [main.go](file:///home/njkevlani/git/passpicker/main.go): Core orchestrator loop.
