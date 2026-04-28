import AppKit
import Carbon.HIToolbox
import ClipTidyCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum HotKeyID: UInt32 {
        case clean = 1
        case cleanAlternate = 2
        case restore = 3
    }

    private let store = OptionsStore()
    private let service = ClipboardService(pasteboard: SystemPasteboard())
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

        hotKeys = HotKeyCenter { [weak self] id in self?.hotKeyPressed(id) }
        failedHotKeys = hotKeys.register([
            .init(id: HotKeyID.clean.rawValue, keyCode: kVK_ANSI_V, label: "⌃⌥⌘V"),
            .init(id: HotKeyID.cleanAlternate.rawValue, keyCode: kVK_Space, label: "⌃⌥⌘Space"),
            .init(id: HotKeyID.restore.rawValue, keyCode: kVK_ANSI_Z, label: "⌃⌥⌘Z"),
        ])
        if !failedHotKeys.isEmpty {
            NSLog("ClipTidy: could not register %@ (already used by another app?)", failedHotKeys.joined(separator: ", "))
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeys?.unregister()
    }

    /// A second copy would only add a duplicate icon and fight over the shortcuts.
    private func quitIfAlreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        if NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return true
        }
        return false
    }

    // MARK: actions

    private func hotKeyPressed(_ id: UInt32) {
        switch HotKeyID(rawValue: id) {
        case .clean, .cleanAlternate: cleanNow()
        case .restore: restoreNow()
        case nil: break
        }
    }

    @objc private func cleanNow() {
        switch service.clean(options: options) {
        case .cleaned, .unchanged: flash("✓")
        case .empty, .noText: flash("✗")
        }
    }

    @objc private func restoreNow() {
        flash(service.restore() ? "↩" : "✗")
    }

    private func flash(_ mark: String) {
        guard let button = statusItem.button else { return }
        button.title = " \(mark)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { button.title = "" }
    }

    // MARK: menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(item("Clean Clipboard", #selector(cleanNow)))
        let restore = item("Restore Original", #selector(restoreNow))
        restore.isEnabled = service.canRestore
        menu.addItem(restore)
        let hint = NSMenuItem(title: hotKeyHint(), action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let presets = NSMenu()
        for name in CleanOptions.presetNames {
            let preset = item(name.capitalized, #selector(selectPreset(_:)))
            preset.representedObject = name
            preset.state = options.matchingPreset == name ? .on : .off
            presets.addItem(preset)
        }
        let presetItem = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
        presetItem.submenu = presets
        menu.addItem(presetItem)

        let toggles = NSMenu()
        for toggle in OptionToggle.allCases {
            let entry = item(toggle.title, #selector(toggleOption(_:)))
            entry.representedObject = toggle.rawValue
            entry.state = toggle.isOn(in: options) ? .on : .off
            toggles.addItem(entry)
        }
        let optionsItem = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
        optionsItem.submenu = toggles
        menu.addItem(optionsItem)

        menu.addItem(.separator())
        let login = item("Launch at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(item("About ClipTidy", #selector(showAbout)))
        menu.addItem(NSMenuItem(title: "Quit ClipTidy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    private func hotKeyHint() -> String {
        switch failedHotKeys.count {
        case 0: return "Clean ⌃⌥⌘V · Restore ⌃⌥⌘Z"
        case 3: return "Shortcuts unavailable: used by another app"
        default: return "Not available (used by another app): \(failedHotKeys.joined(separator: ", "))"
        }
    }

    @objc private func selectPreset(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let preset = CleanOptions.preset(named: name) else { return }
        options = preset
        store.save(options)
    }

    @objc private func toggleOption(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let toggle = OptionToggle(rawValue: raw) else { return }
        options = toggle.toggled(options)
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
            alert.informativeText = "\(error.localizedDescription)\n\nInstall the app in /Applications or ~/Applications first."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
