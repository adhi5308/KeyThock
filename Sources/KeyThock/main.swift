import AppKit
import ApplicationServices
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = KeyboardMonitor()
    private let soundEngine = MechanicalSoundEngine()
    private var statusItem: NSStatusItem!
    private var enabledItem: NSMenuItem!
    private var permissionItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        print("KeyThock is running. Use the ⌨ menu-bar item to control it.")
        monitor.onKeyDown = { [weak self] interval, keyCode in
            self?.soundEngine.play(interval: interval, keyCode: keyCode)
        }
        makeMenu()
        refreshPermissionState()
        if !monitor.hasPermission { monitor.requestPermission() }
    }

    private func makeMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // A text fallback keeps the control visible if the SF Symbol cannot load.
        statusItem.button?.title = "⌨"
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyThock")

        let menu = NSMenu()
        menu.addItem(withTitle: "KeyThock", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        enabledItem = menu.addItem(withTitle: "Enable key sounds", action: #selector(toggleEnabled), keyEquivalent: "e")
        enabledItem.target = self

        let profileMenu = NSMenu()
        for (index, profile) in soundEngine.packs.enumerated() {
            let item = profileMenu.addItem(withTitle: profile.name, action: #selector(selectProfile(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = index == soundEngine.selectedPackIndex ? .on : .off
        }
        if soundEngine.packs.isEmpty {
            let item = profileMenu.addItem(withTitle: "No SoundPacks folder found", action: nil, keyEquivalent: "")
            item.isEnabled = false
        }
        let profileItem = NSMenuItem(title: "Sound pack", action: nil, keyEquivalent: "")
        profileItem.submenu = profileMenu
        menu.addItem(profileItem)

        let sensitivityMenu = NSMenu()
        for value in [0.7, 1.0, 1.35] {
            let title = value == 0.7 ? "Gentle" : value == 1.0 ? "Balanced" : "Responsive"
            let item = sensitivityMenu.addItem(withTitle: title, action: #selector(selectSensitivity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = value == 1.0 ? .on : .off
        }
        let sensitivityItem = NSMenuItem(title: "Hardness sensitivity", action: nil, keyEquivalent: "")
        sensitivityItem.submenu = sensitivityMenu
        menu.addItem(sensitivityItem)

        menu.addItem(withTitle: "Test sound", action: #selector(testSound), keyEquivalent: "t").target = self
        permissionItem = menu.addItem(withTitle: "Grant Accessibility permission…", action: #selector(requestPermission), keyEquivalent: "")
        permissionItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit KeyThock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func refreshPermissionState() {
        let hasPermission = monitor.hasPermission
        permissionItem.title = hasPermission ? "Accessibility permission granted" : "Grant Accessibility permission…"
        permissionItem.isEnabled = !hasPermission
        if hasPermission { monitor.start() }
    }

    @objc private func toggleEnabled() {
        monitor.isEnabled.toggle()
        enabledItem.state = monitor.isEnabled ? .on : .off
    }

    @objc private func requestPermission() {
        monitor.requestPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refreshPermissionState() }
    }

    @objc private func selectProfile(_ sender: NSMenuItem) {
        guard soundEngine.selectPack(at: sender.tag) else { return }
        sender.menu?.items.forEach { $0.state = ($0 === sender) ? .on : .off }
        soundEngine.play(interval: 0.05, keyCode: 0)
    }

    @objc private func selectSensitivity(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? Double else { return }
        soundEngine.sensitivity = value
        sender.menu?.items.forEach { $0.state = ($0 === sender) ? .on : .off }
    }

    @objc private func testSound() { soundEngine.play(interval: 0.045, keyCode: 0) }
}

@main
@MainActor
struct KeyThockMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

private final class KeyboardMonitor {
    var onKeyDown: ((TimeInterval, CGKeyCode) -> Void)?
    var isEnabled = true
    private var eventTap: CFMachPort?
    private var lastKeyTime: TimeInterval = 0

    var hasPermission: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        // The imported C global is mutable under Swift 6's strict concurrency
        // checks. This is its documented string value.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start() {
        guard eventTap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, context in
                guard type == .keyDown, let context else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
                monitor.receivedKeyDown(keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)))
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let eventTap else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func receivedKeyDown(keyCode: CGKeyCode) {
        guard isEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let interval = lastKeyTime == 0 ? 0.22 : now - lastKeyTime
        lastKeyTime = now
        onKeyDown?(interval, keyCode)
    }
}

private struct SoundPackManifest: Decodable {
    let name: String
    let groups: [String: [String: [String]]]
}

private struct SoundPack {
    let name: String
    let rootURL: URL
    let groups: [String: [String: [String]]]
}

private enum SoundPackLibrary {
    static func load() -> [SoundPack] {
        // A packaged app reads its bundled packs; `swift run` reads the folder
        // beside Package.swift during development.
        let bundledRoot = Bundle.main.resourceURL?
            .appendingPathComponent("SoundPacks", isDirectory: true)
        let developmentRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("SoundPacks", isDirectory: true)
        let root = (bundledRoot.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil })
            ?? developmentRoot
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return [] }

        return folders.compactMap { folder in
            let manifestURL = folder.appendingPathComponent("pack.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(SoundPackManifest.self, from: data)
            else { return nil }
            return SoundPack(name: manifest.name, rootURL: folder, groups: manifest.groups)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

private final class MechanicalSoundEngine {
    let packs = SoundPackLibrary.load()
    private(set) var selectedPackIndex = 0
    var sensitivity: Double = 1.0
    private let engine = AVAudioEngine()
    private let players = (0..<12).map { _ in AVAudioPlayerNode() }
    private var nextPlayerIndex = 0
    private var files: [URL: AVAudioFile] = [:]

    init() {
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: nil)
            player.play()
        }
        engine.mainMixerNode.outputVolume = 0.72
        try? engine.start()
    }

    func selectPack(at index: Int) -> Bool {
        guard packs.indices.contains(index) else { return false }
        selectedPackIndex = index
        return true
    }

    func play(interval: TimeInterval, keyCode: CGKeyCode) {
        guard packs.indices.contains(selectedPackIndex) else { return }
        let speed = max(0, min(1, (0.24 - interval) / 0.20))
        let weightedSpeed = pow(speed, sensitivity)
        let level = weightedSpeed < 0.25 ? "soft" : weightedSpeed < 0.55 ? "medium" : weightedSpeed < 0.82 ? "hard" : "slam"
        guard let url = sampleURL(in: packs[selectedPackIndex], group: keyGroup(for: keyCode), level: level),
              let file = audioFile(at: url) else { return }

        let player = players[nextPlayerIndex]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        player.stop()
        player.volume = Float(0.50 + 0.50 * weightedSpeed)
        player.scheduleFile(file, at: nil)
        player.play()
    }

    private func audioFile(at url: URL) -> AVAudioFile? {
        if let cached = files[url] { return cached }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        files[url] = file
        return file
    }

    private func sampleURL(in pack: SoundPack, group: String, level: String) -> URL? {
        let samples = pack.groups[group]?[level]
            ?? pack.groups["alpha"]?[level]
            ?? pack.groups["alpha"]?["medium"]
            ?? pack.groups.values.first?.values.first
        guard let relativePath = samples?.randomElement() else { return nil }
        return pack.rootURL.appendingPathComponent(relativePath)
    }

    private func keyGroup(for code: CGKeyCode) -> String {
        switch code {
        case 49: return "space"
        case 36, 76: return "enter"
        case 51, 117: return "delete"
        case 54, 55, 56, 58, 59, 60, 61, 62, 63: return "modifier"
        case 123, 124, 125, 126: return "arrow"
        case 96, 97, 98, 99, 100, 101, 103, 109, 111, 118, 120, 122: return "function"
        default: return "alpha"
        }
    }
}
