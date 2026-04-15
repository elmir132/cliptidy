import AppKit
import Carbon.HIToolbox
import ClipTidyCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = OptionsStore()
    private let cleaner = ClipboardCleaner(pasteboard: SystemPasteboard())
    private var statusItem: NSStatusItem!
    private var hotKeys: HotKeyCenter!
    private var failedHotKeys: [String] = []
    private var options = CleanOptions.standard

    // MARK: lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if quitIfAlreadyRunning() { return }
        options = store.load()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "ClipTidy")
            button.image?.isTemplate = true
            button.toolTip = "ClipTidy"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        hotKeys = HotKeyCenter { [weak self] in self?.cleanNow() }
        failedHotKeys = hotKeys.register([
            .init(id: 1, keyCode: kVK_ANSI_V, label: "⌃⌥⌘V"),
            .init(id: 2, keyCode: kVK_Space, label: "⌃⌥⌘Space"),
        ])
        if !failedHotKeys.isEmpty {
            NSLog("ClipTidy: could not register %@ (already used by another app?)", failedHotKeys.joined(separator: ", "))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys?.unregister()
    }

    /// A second copy would fail to register the hotkeys and just add a duplicate icon.
    private func quitIfAlreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: id)
        if running.count > 1 {
            NSApp.terminate(nil)
            return true
        }
        return false
    }

    // MARK: cleaning

    @objc func cleanNow() {
        switch cleaner.run(options: options) {
        case .cleaned, .unchanged: flash("✓")
        case .empty, .noText: flash("✗")
        }
    }

    private func flash(_ mark: String) {
        guard let button = statusItem.button else { return }
        button.title = " \(mark)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { button.title = "" }
    }

    // MARK: menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clean = NSMenuItem(title: "Clean Clipboard", action: #selector(cleanNow), keyEquivalent: "")
        clean.target = self
        menu.addItem(clean)
        let hint = NSMenuItem(title: hotKeyHint(), action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let presets = NSMenu()
        for name in CleanOptions.presetNames {
            let item = NSMenuItem(title: name.capitalized, action: #selector(selectPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.state = options.matchingPreset == name ? .on : .off
            presets.addItem(item)
        }
        let presetItem = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
        presetItem.submenu = presets
        menu.addItem(presetItem)

        let custom = NSMenu()
        addToggle(to: custom, title: "Keep indentation", on: options.indentation == .keep, key: "indent")
        addToggle(to: custom, title: "Collapse repeated spaces", on: options.collapseSpaces, key: "spaces")
        addToggle(to: custom, title: "Collapse blank lines", on: options.collapseBlankLines, key: "blank")
        addToggle(to: custom, title: "Leave ``` code blocks untouched", on: options.protectCodeBlocks, key: "protect")
        addToggle(to: custom, title: "Remove ``` marker lines", on: options.stripCodeFences, key: "fences")
        addToggle(to: custom, title: "Fix odd spaces and invisible characters", on: options.normalizeUnicodeSpaces, key: "unicode")
        addToggle(to: custom, title: "Straighten curly quotes", on: options.straightenQuotes, key: "quotes")
        addToggle(to: custom, title: "Join hard-wrapped lines", on: options.unwrapParagraphs, key: "unwrap")
        let customItem = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
        customItem.submenu = custom
        menu.addItem(customItem)

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        let about = NSMenuItem(title: "About ClipTidy", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Quit ClipTidy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func hotKeyHint() -> String {
        if failedHotKeys.isEmpty { return "Shortcut: ⌃⌥⌘V or ⌃⌥⌘Space" }
        if failedHotKeys.count == 2 { return "Shortcuts unavailable: used by another app" }
        return "Shortcut \(failedHotKeys.joined(separator: ", ")) is used by another app"
    }

    private func addToggle(to menu: NSMenu, title: String, on: Bool, key: String) {
        let item = NSMenuItem(title: title, action: #selector(toggleOption(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = key
        item.state = on ? .on : .off
        menu.addItem(item)
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, let preset = CleanOptions.preset(named: name) else { return }
        options = preset
        store.save(options)
    }

    @objc private func toggleOption(_ sender: NSMenuItem) {
        switch sender.representedObject as? String {
        case "indent": options.indentation = options.indentation == .keep ? .remove : .keep
        case "spaces": options.collapseSpaces.toggle()
        case "blank": options.collapseBlankLines.toggle()
        case "protect": options.protectCodeBlocks.toggle()
        case "fences": options.stripCodeFences.toggle()
        case "unicode": options.normalizeUnicodeSpaces.toggle()
        case "quotes": options.straightenQuotes.toggle()
        case "unwrap": options.unwrapParagraphs.toggle()
        default: return
        }
        store.save(options)
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change the login item"
            alert.informativeText = "\(error.localizedDescription)\n\nThe app must be installed in /Applications or ~/Applications."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
