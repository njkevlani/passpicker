import AppKit

// MARK: - Floating Panel
class FloatingPanel: NSPanel {
    weak var appController: AppController?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // Esc (53) -> Cancel
            if event.keyCode == 53 {
                appController?.cancel()
                return
            }

            // Return / Enter (36) or Keypad Enter (76)
            if event.keyCode == 36 || event.keyCode == 76 {
                // Ignore any Enter event queued before or during window launch (e.g. from Terminal/Spotlight)
                if let readyTime = appController?.windowReadyTime, ProcessInfo.processInfo.systemUptime < readyTime {
                    return
                }
                let isOption = event.modifierFlags.contains(.option)
                appController?.acceptSelection(withOtp: isOption)
                return
            }

            // Down Arrow (125) or Ctrl+N (keyCode 45 with control)
            if event.keyCode == 125 || (event.keyCode == 45 && event.modifierFlags.contains(.control)) {
                appController?.moveSelection(offset: 1)
                return
            }

            // Up Arrow (126) or Ctrl+P (keyCode 35 with control)
            if event.keyCode == 126 || (event.keyCode == 35 && event.modifierFlags.contains(.control)) {
                appController?.moveSelection(offset: -1)
                return
            }

            // Page Down (121)
            if event.keyCode == 121 {
                appController?.moveSelection(offset: 8)
                return
            }

            // Page Up (116)
            if event.keyCode == 116 {
                appController?.moveSelection(offset: -8)
                return
            }

            // Command + 1..9 shortcuts
            if event.modifierFlags.contains(.command),
               let chars = event.charactersIgnoringModifiers,
               let num = Int(chars), num >= 1 && num <= 9 {
                let isOption = event.modifierFlags.contains(.option)
                appController?.acceptIndex(num - 1, withOtp: isOption)
                return
            }
        }

        super.sendEvent(event)
    }
}

// MARK: - Custom Table Row View (Selection Styling)
class CustomTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            let selectionRect = bounds.insetBy(dx: 4, dy: 1)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 6, yRadius: 6)
            if isEmphasized {
                NSColor.selectedContentBackgroundColor.setFill()
            } else {
                NSColor.unemphasizedSelectedContentBackgroundColor.setFill()
            }
            path.fill()
        }
    }
}

// MARK: - Custom Table Cell View
class ItemCellView: NSTableCellView {
    let iconView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let badgeLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .secondaryLabelColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.textColor = .labelColor

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        badgeLabel.textColor = .tertiaryLabelColor
        badgeLabel.alignment = .right

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -8),

            badgeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateColors()
        }
    }

    private func updateColors() {
        let isSelected = (backgroundStyle == .emphasized)
        if isSelected {
            titleLabel.textColor = .selectedControlTextColor
            iconView.contentTintColor = .selectedControlTextColor
            badgeLabel.textColor = .selectedControlTextColor.withAlphaComponent(0.8)
        } else {
            titleLabel.textColor = .labelColor
            iconView.contentTintColor = .secondaryLabelColor
            badgeLabel.textColor = .tertiaryLabelColor
        }
    }

    func configure(text: String, shortcutIndex: Int?) {
        titleLabel.stringValue = text
        updateColors()

        // Icon based on item content
        if text.hasPrefix("+") {
            if #available(macOS 11.0, *) {
                iconView.image = NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: nil)
            }
        } else if text.contains("OTP") {
            if #available(macOS 11.0, *) {
                iconView.image = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)
            }
        } else if text.contains("Generate") || text.contains("Edit") {
            if #available(macOS 11.0, *) {
                iconView.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
            }
        } else if text.contains("Delete") {
            if #available(macOS 11.0, *) {
                iconView.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            }
        } else if text.contains("Show") {
            if #available(macOS 11.0, *) {
                iconView.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
            }
        } else if text.contains("Copy") {
            if #available(macOS 11.0, *) {
                iconView.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            }
        } else {
            if #available(macOS 11.0, *) {
                iconView.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: nil)
            }
        }

        // Shortcut indicator (Maccy-style numbered shortcuts)
        if let idx = shortcutIndex, idx >= 0 && idx < 9 {
            badgeLabel.stringValue = "⌘\(idx + 1)"
        } else {
            badgeLabel.stringValue = ""
        }
    }
}

// MARK: - AppController
class AppController: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    let promptTitle: String
    let promptMessage: String
    let allItems: [String]
    var filteredItems: [String] = []

    var window: FloatingPanel!
    var searchField: NSSearchField!
    var tableView: NSTableView!
    var scrollView: NSScrollView!
    var countLabel: NSTextField!
    var windowReadyTime: TimeInterval = 0

    init(prompt: String, message: String, items: [String]) {
        self.promptTitle = prompt
        self.promptMessage = message
        self.allItems = items
        self.filteredItems = items
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupUI()
        positionWindow()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windowReadyTime = ProcessInfo.processInfo.systemUptime + 0.15
    }

    private func setupUI() {
        let width: CGFloat = 520
        let height: CGFloat = 380

        window = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.appController = self
        window.delegate = self
        window.isFloatingPanel = true
        window.level = .floating
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.hasShadow = true
        window.backgroundColor = .clear

        // Vibrant background
        let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .popover
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true
        visualEffect.layer?.borderColor = NSColor.separatorColor.cgColor
        visualEffect.layer?.borderWidth = 1
        window.contentView = visualEffect

        // Header view
        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(headerView)

        let titleLabel = NSTextField(labelWithString: promptTitle)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .labelColor
        headerView.addSubview(titleLabel)

        var messageLabel: NSTextField?
        if !promptMessage.isEmpty {
            let msg = NSTextField(labelWithString: promptMessage)
            msg.translatesAutoresizingMaskIntoConstraints = false
            msg.font = NSFont.systemFont(ofSize: 11, weight: .regular)
            msg.textColor = .secondaryLabelColor
            headerView.addSubview(msg)
            messageLabel = msg
        }

        countLabel = NSTextField(labelWithString: "\(allItems.count) entries")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = .tertiaryLabelColor
        countLabel.alignment = .right
        headerView.addSubview(countLabel)

        // Search field (uses delegate only, no rogue action triggering)
        searchField = NSSearchField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search entries or type to create..."
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.focusRingType = .none
        searchField.delegate = self
        visualEffect.addSubview(searchField)

        // Table View & Scroll View
        tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.selectionHighlightStyle = .regular
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.doubleAction = #selector(rowDoubleClicked)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("MainColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = tableView
        visualEffect.addSubview(scrollView)

        // Bottom hint footer
        let footerLabel = NSTextField(labelWithString: "↵ Select   ⌥↵ Copy OTP   ⌘1-9 Quick Pick   ⎋ Cancel")
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        footerLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.alignment = .center
        visualEffect.addSubview(footerLabel)

        // Layout constraints
        var constraints = [
            headerView.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),

            countLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            searchField.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 14),
            searchField.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -14),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -6),

            footerLabel.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -6),
            footerLabel.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -16)
        ]

        if let msg = messageLabel {
            constraints.append(contentsOf: [
                msg.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
                msg.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                msg.trailingAnchor.constraint(lessThanOrEqualTo: countLabel.leadingAnchor, constant: -8),
                msg.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
            ])
        } else {
            constraints.append(titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor))
        }

        NSLayoutConstraint.activate(constraints)

        window.initialFirstResponder = searchField
        searchField.becomeFirstResponder()

        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    private func positionWindow() {
        let mousePos = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first { NSMouseInRect(mousePos, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        let screenFrame = screen.visibleFrame
        let winSize = window.frame.size

        // Position window horizontally centered at mouse, vertically centered near mouse
        var x = mousePos.x - winSize.width / 2
        var y = mousePos.y - winSize.height / 2

        // Keep inside screen visible frame with margin
        x = max(screenFrame.minX + 16, min(x, screenFrame.maxX - winSize.width - 16))
        y = max(screenFrame.minY + 16, min(y, screenFrame.maxY - winSize.height - 16))

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Filtering
    @objc func searchChanged() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.isEmpty {
            filteredItems = allItems
        } else {
            // Rank items: starts-with query first, then contains query
            let startsWith = allItems.filter { $0.lowercased().hasPrefix(query) }
            let contains = allItems.filter { !$0.lowercased().hasPrefix(query) && $0.lowercased().contains(query) }
            filteredItems = startsWith + contains
        }

        countLabel.stringValue = "\(filteredItems.count) of \(allItems.count)"
        tableView.reloadData()

        if !filteredItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        searchChanged()
    }

    // MARK: - Actions
    func moveSelection(offset: Int) {
        guard !filteredItems.isEmpty else { return }
        let current = tableView.selectedRow
        var next = (current < 0 ? 0 : current) + offset
        if next < 0 { next = 0 }
        if next >= filteredItems.count { next = filteredItems.count - 1 }

        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    func acceptIndex(_ index: Int, withOtp: Bool) {
        guard index >= 0 && index < filteredItems.count else { return }
        let item = filteredItems[index]
        finish(selection: item, withOtp: withOtp)
    }

    func acceptSelection(withOtp: Bool) {
        let selectedRow = tableView.selectedRow
        if selectedRow >= 0 && selectedRow < filteredItems.count {
            let item = filteredItems[selectedRow]
            finish(selection: item, withOtp: withOtp)
            return
        }

        let typed = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            finish(selection: typed, withOtp: withOtp)
            return
        }

        cancel()
    }

    @objc func rowClicked() {
        guard tableView.clickedRow >= 0 && tableView.clickedRow < filteredItems.count else { return }
        // Single click selects the row and keeps the popup open, waiting for Enter
        tableView.selectRowIndexes(IndexSet(integer: tableView.clickedRow), byExtendingSelection: false)
    }

    @objc func rowDoubleClicked() {
        guard tableView.clickedRow >= 0 && tableView.clickedRow < filteredItems.count else { return }
        let isOption = NSEvent.modifierFlags.contains(.option)
        acceptIndex(tableView.clickedRow, withOtp: isOption)
    }

    private func finish(selection: String, withOtp: Bool) {
        let output = withOtp ? "\(selection) !otp" : selection
        print(output)
        fflush(stdout)
        exit(0)
    }

    func cancel() {
        exit(1)
    }

    func windowDidResignKey(_ notification: Notification) {
        // Dismiss if user clicks away
        cancel()
    }

    // MARK: - Table View Data Source & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredItems.count
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("CustomRowView")
        var rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? CustomTableRowView
        if rowView == nil {
            rowView = CustomTableRowView()
            rowView?.identifier = identifier
        }
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ItemCell")
        var cell = tableView.makeView(withIdentifier: identifier, owner: self) as? ItemCellView
        if cell == nil {
            cell = ItemCellView()
            cell?.identifier = identifier
        }

        let item = filteredItems[row]
        cell?.configure(text: item, shortcutIndex: row < 9 ? row : nil)
        return cell
    }
}

// MARK: - Main Entry Point
func parseArguments() -> (prompt: String, message: String) {
    var prompt = "pass"
    var message = ""

    let args = CommandLine.arguments
    var i = 1
    while i < args.count {
        switch args[i] {
        case "-p", "--prompt":
            if i + 1 < args.count {
                prompt = args[i + 1]
                i += 1
            }
        case "-m", "--message":
            if i + 1 < args.count {
                message = args[i + 1]
                i += 1
            }
        default:
            break
        }
        i += 1
    }
    return (prompt, message)
}

func readItemsFromStdin() -> [String] {
    var items: [String] = []
    while let line = readLine(strippingNewline: true) {
        let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
        if !trimmed.isEmpty {
            items.append(trimmed)
        }
    }
    return items
}

let (prompt, message) = parseArguments()
let items = readItemsFromStdin()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController(prompt: prompt, message: message, items: items)
app.delegate = controller
app.run()
