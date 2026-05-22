import Cocoa
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var slider: NSSlider!
    private var intensityLabel: NSTextField!
    private var enabledItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var hotKeyRef: EventHotKeyRef?

    private let defaults = UserDefaults.standard
    private let intensityKey = "intensity"
    private let enabledKey = "enabled"
    private let defaultIntensity = 0.4

    private var intensity: Double {
        get { defaults.object(forKey: intensityKey) as? Double ?? defaultIntensity }
        set { defaults.set(newValue, forKey: intensityKey) }
    }

    private var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        buildMenu()
        applyGamma()
        registerHotKey()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        CGDisplayRestoreColorSyncSettings()
    }

    @objc private func displaysChanged() { applyGamma() }

    // MARK: - UI

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Vell")
            button.image?.isTemplate = true
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Header: Vell — @bovmii
        let header = NSMenuItem()
        let attr = NSMutableAttributedString(
            string: "Vell ",
            attributes: [.font: NSFont.menuBarFont(ofSize: 0).withSize(13)]
        )
        attr.append(NSAttributedString(
            string: "— @bovmii",
            attributes: [
                .font: NSFont.menuFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        header.attributedTitle = attr
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        enabledItem = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "b")
        enabledItem.keyEquivalentModifierMask = [.command, .option]
        enabledItem.target = self
        menu.addItem(enabledItem)
        menu.addItem(.separator())

        // Intensity slider
        intensityLabel = NSTextField(labelWithString: "")
        intensityLabel.font = NSFont.menuFont(ofSize: 11)
        intensityLabel.textColor = .secondaryLabelColor
        slider = NSSlider(value: intensity * 100, minValue: 0, maxValue: 90,
                          target: self, action: #selector(sliderChanged(_:)))
        slider.isContinuous = true
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 50))
        intensityLabel.frame = NSRect(x: 14, y: 28, width: 192, height: 16)
        slider.frame = NSRect(x: 14, y: 6, width: 192, height: 20)
        container.addSubview(intensityLabel)
        container.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = container
        menu.addItem(sliderItem)

        // Presets
        let presets = NSMenuItem(title: "Préréglages", action: nil, keyEquivalent: "")
        let presetMenu = NSMenu()
        for (label, value) in [("Léger (30 %)", 0.30), ("Moyen (55 %)", 0.55), ("Fort (80 %)", 0.80)] {
            let item = NSMenuItem(title: label, action: #selector(applyPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            presetMenu.addItem(item)
        }
        presets.submenu = presetMenu
        menu.addItem(presets)

        let reset = NSMenuItem(title: "Réinitialiser", action: #selector(resetIntensity), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "À propos…", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quitter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        refreshMenuTitles()
    }

    private func refreshMenuTitles() {
        enabledItem.title = isEnabled ? "✓ Activé" : "Activé"
        intensityLabel.stringValue = "Intensité : \(Int(intensity * 100)) %"
        loginItem.title = isLoginItemEnabled() ? "✓ Lancer au démarrage" : "Lancer au démarrage"
        slider.doubleValue = intensity * 100
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        applyGamma()
        refreshMenuTitles()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        intensity = sender.doubleValue / 100.0
        applyGamma()
        refreshMenuTitles()
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        intensity = value
        if !isEnabled { isEnabled = true }
        applyGamma()
        refreshMenuTitles()
    }

    @objc private func resetIntensity() {
        intensity = defaultIntensity
        applyGamma()
        refreshMenuTitles()
    }

    @objc private func toggleLoginItem() {
        do {
            if isLoginItemEnabled() {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Login item toggle failed: \(error)")
        }
        refreshMenuTitles()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Vell"
        alert.informativeText = """
        Réduit l'intensité du point blanc de l'écran, à la manière de l'option d'accessibilité d'iOS.

        Créé par @bovmii
        GitHub : github.com/bovmii
        Instagram : @bovmii

        Un bug, une idée ? Écrivez-moi sur Instagram ou ouvrez une issue sur GitHub.

        Open source — MIT.
        """
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Ouvrir GitHub")
        alert.addButton(withTitle: "Ouvrir Instagram")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/bovmii")!)
        } else if response == .alertThirdButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://instagram.com/bovmii")!)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Gamma

    private func applyGamma() {
        let cap: Float = isEnabled ? Float(1.0 - intensity) : 1.0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &displays, &count) == .success else { return }
        for i in 0..<Int(count) {
            CGSetDisplayTransferByFormula(
                displays[i],
                0.0, cap, 1.0,
                0.0, cap, 1.0,
                0.0, cap, 1.0
            )
        }
    }

    // MARK: - Login item

    private func isLoginItemEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Global hotkey (⌥⌘B)

    private func registerHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { delegate.toggleEnabled() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        let hotKeyID = EventHotKeyID(signature: OSType(0x56454C4C), id: 1) // 'VELL'
        RegisterEventHotKey(UInt32(kVK_ANSI_B),
                            UInt32(cmdKey | optionKey),
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }
}
