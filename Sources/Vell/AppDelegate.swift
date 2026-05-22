import Cocoa
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Modifier helpers

private func carbonMods(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var m: UInt32 = 0
    if flags.contains(.command) { m |= UInt32(cmdKey) }
    if flags.contains(.option)  { m |= UInt32(optionKey) }
    if flags.contains(.shift)   { m |= UInt32(shiftKey) }
    if flags.contains(.control) { m |= UInt32(controlKey) }
    return m
}

private func nsMods(from carbon: UInt32) -> NSEvent.ModifierFlags {
    var f: NSEvent.ModifierFlags = []
    if carbon & UInt32(cmdKey)     != 0 { f.insert(.command) }
    if carbon & UInt32(optionKey)  != 0 { f.insert(.option) }
    if carbon & UInt32(shiftKey)   != 0 { f.insert(.shift) }
    if carbon & UInt32(controlKey) != 0 { f.insert(.control) }
    return f
}

private func displayString(mods: NSEvent.ModifierFlags, char: String) -> String {
    var s = ""
    if mods.contains(.control) { s += "⌃" }
    if mods.contains(.option)  { s += "⌥" }
    if mods.contains(.shift)   { s += "⇧" }
    if mods.contains(.command) { s += "⌘" }
    s += char.uppercased()
    return s
}

// MARK: - AppDelegate

// Copyright (c) 2026 Boumediene B. (@bovmii). All rights reserved.
// Vell is free and open source under PolyForm Noncommercial 1.0.0.
// Selling this software, or any derivative based on it, is strictly prohibited.
// Author contact: instagram.com/bovmii — github.com/bovmii
let kVellCopyright = "Vell © 2026 @bovmii — Free and noncommercial. Selling prohibited. instagram.com/bovmii"

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var hotKeyRef: EventHotKeyRef?
    private var prefsWindow: NSWindow?

    // Persistent menu item refs (so we mutate in place instead of rebuilding).
    private var menu: NSMenu!
    private var enabledItem: NSMenuItem!
    private var intensityLabel: NSTextField!
    private var slider: NSSlider!
    private var loginItem: NSMenuItem!
    private var presetSubmenu: NSMenu!

    private let defaults = UserDefaults.standard
    private let intensityKey = "intensity"
    private let enabledKey   = "enabled"
    private let defaultIntensity = 0.4

    // Preset defaults
    private let presetDefaults: [Double] = [0.30, 0.55, 0.80]
    private let presetLabels = ["Léger", "Moyen", "Fort"]

    // Stored properties

    private var intensity: Double {
        get { defaults.object(forKey: intensityKey) as? Double ?? defaultIntensity }
        set { defaults.set(newValue, forKey: intensityKey) }
    }

    private var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    private var presetValues: [Double] {
        (0..<3).map { i in
            defaults.object(forKey: "preset\(i)") as? Double ?? presetDefaults[i]
        }
    }

    private func setPreset(_ index: Int, _ value: Double) {
        let clamped = max(0, min(0.9, value))
        defaults.set(clamped, forKey: "preset\(index)")
    }

    private var hotKeyCode: UInt32 {
        UInt32(defaults.object(forKey: "hotKeyCode") as? Int ?? Int(kVK_ANSI_B))
    }
    private var hotKeyMods: UInt32 {
        UInt32(defaults.object(forKey: "hotKeyMods") as? Int ?? Int(cmdKey | optionKey))
    }
    private var hotKeyChar: String {
        defaults.string(forKey: "hotKeyChar") ?? "b"
    }
    private var hotKeyEnabled: Bool {
        defaults.object(forKey: "hotKeyEnabled") as? Bool ?? true
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("%@", kVellCopyright)
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

    // MARK: - Status bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Vell")
            button.image?.isTemplate = true
        }
    }

    // MARK: - Menu

    private func buildMenu() {
        menu = NSMenu()

        // Header: Vell  @bovmii (no dash)
        let header = NSMenuItem()
        let attr = NSMutableAttributedString(
            string: "Vell  ",
            attributes: [.font: NSFont.menuBarFont(ofSize: 0).withSize(13)]
        )
        attr.append(NSAttributedString(
            string: "@bovmii",
            attributes: [
                .font: NSFont.menuFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        header.attributedTitle = attr
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        enabledItem = NSMenuItem(title: "", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        refreshEnabledItem()
        menu.addItem(enabledItem)
        menu.addItem(.separator())

        // Slider (kept as ivar so we don't recreate it)
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
        refreshIntensityLabel()

        // Preset submenu (kept as ivar so we update titles in place)
        let presetParent = NSMenuItem(title: "Préréglages", action: nil, keyEquivalent: "")
        presetSubmenu = NSMenu()
        for i in 0..<3 {
            let item = NSMenuItem(title: "", action: #selector(applyPreset(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            presetSubmenu.addItem(item)
        }
        presetParent.submenu = presetSubmenu
        refreshPresetSubmenu()
        menu.addItem(presetParent)

        let reset = NSMenuItem(title: "Réinitialiser", action: #selector(resetIntensity), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())

        loginItem = NSMenuItem(title: "", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        refreshLoginItem()
        menu.addItem(loginItem)

        let prefs = NSMenuItem(title: "Préférences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "À propos…", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quitter", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Live menu refreshers (mutate in place, never rebuild)

    private func refreshEnabledItem() {
        enabledItem.title = isEnabled ? "✓ Activé" : "Activé"
        if hotKeyEnabled {
            enabledItem.keyEquivalent = hotKeyChar.lowercased()
            enabledItem.keyEquivalentModifierMask = nsMods(from: hotKeyMods)
        } else {
            enabledItem.keyEquivalent = ""
            enabledItem.keyEquivalentModifierMask = []
        }
    }

    private func refreshIntensityLabel() {
        intensityLabel.stringValue = "Intensité : \(Int(intensity * 100)) %"
    }

    private func refreshLoginItem() {
        loginItem.title = isLoginItemEnabled() ? "✓ Lancer au démarrage" : "Lancer au démarrage"
    }

    private func refreshPresetSubmenu() {
        let values = presetValues
        for (i, item) in presetSubmenu.items.enumerated() where i < 3 {
            item.title = "\(presetLabels[i]) (\(Int(values[i] * 100)) %)"
            item.representedObject = values[i]
        }
    }

    // MARK: - Actions

    @objc fileprivate func toggleEnabled() {
        isEnabled.toggle()
        applyGamma()
        refreshEnabledItem()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        intensity = sender.doubleValue / 100.0
        applyGamma()
        refreshIntensityLabel()
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        intensity = value
        if !isEnabled { isEnabled = true }
        slider.doubleValue = value * 100
        applyGamma()
        refreshIntensityLabel()
        refreshEnabledItem()
    }

    @objc private func resetIntensity() {
        intensity = defaultIntensity
        slider.doubleValue = defaultIntensity * 100
        applyGamma()
        refreshIntensityLabel()
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
        refreshLoginItem()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Vell"
        alert.informativeText = """
        Réduit l'intensité du point blanc de l'écran, à la manière de l'option d'accessibilité d'iOS.

        Créé par @bovmii
        GitHub : github.com/bovmii
        Instagram : @bovmii

        Vell est 100 % gratuit. Si vous payez pour cette app, vous vous êtes fait avoir.

        Un bug, une idée ? Écrivez-moi sur Instagram ou ouvrez une issue sur GitHub.

        Copyright © 2026 @bovmii.
        Licence PolyForm Noncommercial 1.0.0. Revente interdite.
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

    // MARK: - Global hotkey

    private func registerHotKey() {
        // Install handler once
        if hotKeyRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                          eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { delegate.toggleEnabled() }
                return noErr
            }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        }
        installHotKey()
    }

    private func installHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        guard hotKeyEnabled else { return }
        let hotKeyID = EventHotKeyID(signature: OSType(0x56454C4C), id: 1)
        RegisterEventHotKey(hotKeyCode,
                            hotKeyMods,
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }

    fileprivate func updateHotKey(code: UInt32, mods: UInt32, char: String) {
        defaults.set(Int(code), forKey: "hotKeyCode")
        defaults.set(Int(mods), forKey: "hotKeyMods")
        defaults.set(char, forKey: "hotKeyChar")
        installHotKey()
        refreshEnabledItem()
    }

    fileprivate func setHotKeyEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: "hotKeyEnabled")
        installHotKey()
        refreshEnabledItem()
    }

    fileprivate func updatePreset(_ index: Int, _ value: Double) {
        setPreset(index, value)
        refreshPresetSubmenu()
    }

    fileprivate func currentHotKeyDisplay() -> String {
        guard hotKeyEnabled else { return "Désactivé" }
        return displayString(mods: nsMods(from: hotKeyMods), char: hotKeyChar)
    }

    fileprivate func currentPresetValues() -> [Double] { presetValues }

    // MARK: - Preferences window

    @objc private func openPreferences() {
        if prefsWindow == nil {
            prefsWindow = PreferencesWindow(appDelegate: self)
        }
        (prefsWindow as? PreferencesWindow)?.refresh()
        NSApp.activate(ignoringOtherApps: true)
        prefsWindow?.makeKeyAndOrderFront(nil)
    }

    fileprivate func resetAll() {
        for i in 0..<3 { defaults.removeObject(forKey: "preset\(i)") }
        defaults.removeObject(forKey: "hotKeyCode")
        defaults.removeObject(forKey: "hotKeyMods")
        defaults.removeObject(forKey: "hotKeyChar")
        defaults.removeObject(forKey: "hotKeyEnabled")
        defaults.removeObject(forKey: intensityKey)
        installHotKey()
        applyGamma()
        slider.doubleValue = intensity * 100
        refreshIntensityLabel()
        refreshEnabledItem()
        refreshPresetSubmenu()
    }
}

// MARK: - Preferences window

final class PreferencesWindow: NSWindow, NSWindowDelegate, NSTextFieldDelegate {

    private weak var appDelegate: AppDelegate?
    private var fields: [NSTextField] = []
    private var recorderButton: NSButton!
    private var enabledCheckbox: NSButton!
    private var keyMonitor: Any?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = "Préférences"
        self.isReleasedWhenClosed = false
        self.center()
        self.delegate = self
        buildUI()
    }

    private func buildUI() {
        let content = NSView(frame: contentView!.bounds)
        contentView = content

        // Window height 320, Y from bottom.

        // Presets section
        let presetsTitle = NSTextField(labelWithString: "Préréglages (%)")
        presetsTitle.font = .boldSystemFont(ofSize: 13)
        presetsTitle.frame = NSRect(x: 20, y: 282, width: 360, height: 18)
        content.addSubview(presetsTitle)

        let labels = ["Léger", "Moyen", "Fort"]
        let values = appDelegate?.currentPresetValues() ?? [0.30, 0.55, 0.80]
        for i in 0..<3 {
            let y: CGFloat = 250 - CGFloat(i) * 30
            let lbl = NSTextField(labelWithString: labels[i])
            lbl.frame = NSRect(x: 20, y: y, width: 70, height: 22)
            content.addSubview(lbl)

            let field = NSTextField(frame: NSRect(x: 100, y: y, width: 70, height: 22))
            field.stringValue = String(Int(values[i] * 100))
            field.tag = i
            field.delegate = self
            fields.append(field)
            content.addSubview(field)

            let pct = NSTextField(labelWithString: "%")
            pct.frame = NSRect(x: 175, y: y, width: 20, height: 22)
            content.addSubview(pct)
        }

        // Separator
        let sep1 = NSBox(frame: NSRect(x: 20, y: 152, width: 360, height: 1))
        sep1.boxType = .separator
        content.addSubview(sep1)

        // Hotkey section
        let hkTitle = NSTextField(labelWithString: "Raccourci global")
        hkTitle.font = .boldSystemFont(ofSize: 13)
        hkTitle.frame = NSRect(x: 20, y: 124, width: 360, height: 18)
        content.addSubview(hkTitle)

        recorderButton = NSButton(frame: NSRect(x: 20, y: 90, width: 160, height: 28))
        recorderButton.bezelStyle = .rounded
        recorderButton.title = appDelegate?.currentHotKeyDisplay() ?? "⌥⌘B"
        recorderButton.target = self
        recorderButton.action = #selector(startRecording)
        content.addSubview(recorderButton)

        enabledCheckbox = NSButton(checkboxWithTitle: "Activer",
                                    target: self,
                                    action: #selector(toggleHotkeyEnabled(_:)))
        enabledCheckbox.frame = NSRect(x: 195, y: 93, width: 100, height: 22)
        enabledCheckbox.state = (appDelegate?.currentHotKeyDisplay() == "Désactivé") ? .off : .on
        content.addSubview(enabledCheckbox)

        let hkHelp = NSTextField(labelWithString: "Cliquez puis appuyez sur la combinaison souhaitée.")
        hkHelp.font = NSFont.systemFont(ofSize: 11)
        hkHelp.textColor = .secondaryLabelColor
        hkHelp.frame = NSRect(x: 20, y: 66, width: 360, height: 16)
        content.addSubview(hkHelp)

        // Bottom separator + actions
        let sep2 = NSBox(frame: NSRect(x: 20, y: 50, width: 360, height: 1))
        sep2.boxType = .separator
        content.addSubview(sep2)

        let resetButton = NSButton(frame: NSRect(x: 20, y: 12, width: 170, height: 28))
        resetButton.bezelStyle = .rounded
        resetButton.title = "Tout réinitialiser"
        resetButton.target = self
        resetButton.action = #selector(resetAllPressed)
        content.addSubview(resetButton)

        let applyButton = NSButton(frame: NSRect(x: 290, y: 12, width: 90, height: 28))
        applyButton.bezelStyle = .rounded
        applyButton.title = "Appliquer"
        applyButton.keyEquivalent = "\r"   // Enter activates Apply
        applyButton.target = self
        applyButton.action = #selector(applyPressed)
        content.addSubview(applyButton)
    }

    // Re-sync visible fields with current defaults (called when window is shown).
    func refresh() {
        let values = appDelegate?.currentPresetValues() ?? [0.30, 0.55, 0.80]
        for (i, f) in fields.enumerated() where i < values.count {
            f.stringValue = String(Int(values[i] * 100))
        }
        recorderButton?.title = appDelegate?.currentHotKeyDisplay() ?? "⌥⌘B"
        recorderButton?.isEnabled = (appDelegate?.currentHotKeyDisplay() != "Désactivé")
        enabledCheckbox?.state = (appDelegate?.currentHotKeyDisplay() == "Désactivé") ? .off : .on
    }

    @objc private func resetAllPressed() {
        let alert = NSAlert()
        alert.messageText = "Réinitialiser tous les réglages ?"
        alert.informativeText = "Les préréglages, le raccourci et l'intensité seront remis aux valeurs par défaut."
        alert.addButton(withTitle: "Réinitialiser")
        alert.addButton(withTitle: "Annuler")
        if alert.runModal() == .alertFirstButtonReturn {
            appDelegate?.resetAll()
            refresh()
        }
    }

    // Force end-editing when window closes so the field's action fires.
    func windowWillClose(_ notification: Notification) {
        self.makeFirstResponder(nil)
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
            recorderButton.title = appDelegate?.currentHotKeyDisplay() ?? "⌥⌘B"
            recorderButton.isEnabled = true
        }
    }

    // MARK: - Apply

    @objc private func applyPressed() {
        // Force any in-progress edit to commit before reading values.
        self.makeFirstResponder(nil)
        for (i, f) in fields.enumerated() {
            let raw = Double(f.stringValue) ?? 0
            let clamped = max(0, min(90, raw))
            f.stringValue = String(Int(clamped))
            appDelegate?.updatePreset(i, clamped / 100.0)
        }
    }

    // MARK: - Hotkey recording

    @objc private func startRecording() {
        // Commit any in-progress text editing so first responder is clean.
        self.makeFirstResponder(nil)
        // Make sure window + app are active so local key monitor receives events.
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)

        recorderButton.title = "Tapez la combinaison…"
        recorderButton.isEnabled = false

        // Remove any previous monitor first.
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !mods.isEmpty else {
            // require at least one modifier
            return
        }
        let char = (event.charactersIgnoringModifiers ?? "").lowercased()
        guard !char.isEmpty else { return }

        let carbon = carbonMods(from: mods)
        let code = UInt32(event.keyCode)

        appDelegate?.updateHotKey(code: code, mods: carbon, char: char)
        recorderButton.title = displayString(mods: mods, char: char)
        recorderButton.isEnabled = true
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }

    @objc private func toggleHotkeyEnabled(_ sender: NSButton) {
        appDelegate?.setHotKeyEnabled(sender.state == .on)
        recorderButton.isEnabled = sender.state == .on
    }
}
