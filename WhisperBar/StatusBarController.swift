import Cocoa

/// Owns the NSStatusItem, builds the menu, and handles model selection.
final class StatusBarController: NSObject {

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var modelMenuItems: [NSMenuItem] = []

    private let prefs = PreferencesStore.shared

    override init() {
        super.init()
        setupStatusItem()
        buildMenu()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        if let img = NSImage(systemSymbolName: "mic.circle.fill", accessibilityDescription: "WhisperBar") {
            img.isTemplate = true
            button.image = img
        } else {
            button.title = "🎙"
        }
        button.toolTip = "WhisperBar"
        statusItem.menu = menu
    }

    // MARK: - Menu

    private func buildMenu() {
        // ── Model submenu ──────────────────────────────────────────────
        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        let modelSubmenu = NSMenu(title: "Model")

        for modelName in prefs.availableModels {
            let item = NSMenuItem(
                title: modelName.capitalized,
                action: #selector(selectModel(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = modelName
            item.state = (modelName == prefs.selectedModel) ? .on : .off
            modelSubmenu.addItem(item)
            modelMenuItems.append(item)
        }
        modelItem.submenu = modelSubmenu
        menu.addItem(modelItem)

        // ── Separator ─────────────────────────────────────────────────
        menu.addItem(.separator())

        // ── Settings ──────────────────────────────────────────────────
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        // ── Quit ──────────────────────────────────────────────────────
        let quitItem = NSMenuItem(
            title: "Quit WhisperBar",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func selectModel(_ sender: NSMenuItem) {
        guard let model = sender.representedObject as? String else { return }
        prefs.selectedModel = model
        modelMenuItems.forEach { $0.state = ($0.representedObject as? String == model) ? .on : .off }
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow(nil)
    }
}
