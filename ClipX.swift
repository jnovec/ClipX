import Cocoa
import Security

// MARK: - Clipboard model

enum ClipKind {
    case text
    case link
    case image
}

final class ClipItem: NSObject {
    let id = UUID()
    let kind: ClipKind
    let createdAt: Date
    let text: String?
    let image: NSImage?

    init(text: String, kind: ClipKind = .text, createdAt: Date = Date()) {
        self.text = text
        self.kind = kind
        self.createdAt = createdAt
        self.image = nil
    }

    init(image: NSImage, createdAt: Date = Date()) {
        self.text = nil
        self.kind = .image
        self.createdAt = createdAt
        self.image = image
    }

    var title: String {
        switch kind {
        case .text: return "Text"
        case .link: return "Odkaz"
        case .image: return "Obrázek"
        }
    }

    var searchableText: String {
        text ?? title
    }
}

// MARK: - Clipboard shelf window

final class ClipXWindowController: NSWindowController, NSSearchFieldDelegate {
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let searchField = NSSearchField()
    private let countLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private var allItems: [ClipItem] = []
    var onSelect: ((ClipItem) -> Void)?

    init() {
        let frame = NSRect(x: 0, y: 0, width: 1120, height: 330)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipX"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 720, height: 280)
        if #available(macOS 10.14, *) {
            window.appearance = NSAppearance(named: .darkAqua)
        }

        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            root.topAnchor.constraint(equalTo: content.topAnchor),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])

        let top = NSStackView()
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 12
        top.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(top)

        let logo = NSTextField(labelWithString: "ClipX")
        logo.font = .systemFont(ofSize: 20, weight: .bold)
        logo.textColor = .white

        let pill = NSTextField(labelWithString: "Schránka")
        pill.font = .systemFont(ofSize: 13, weight: .semibold)
        pill.textColor = .white
        pill.alignment = .center
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 14
        pill.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.widthAnchor.constraint(greaterThanOrEqualToConstant: 95).isActive = true
        pill.heightAnchor.constraint(equalToConstant: 30).isActive = true

        searchField.placeholderString = "Hledat ve schránce"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.widthAnchor.constraint(equalToConstant: 260).isActive = true

        top.addArrangedSubview(logo)
        top.addArrangedSubview(pill)
        top.addArrangedSubview(NSView())
        top.addArrangedSubview(searchField)

        countLabel.font = .systemFont(ofSize: 12, weight: .medium)
        countLabel.textColor = .secondaryLabelColor
        top.addArrangedSubview(countLabel)

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .systemGreen
        statusLabel.stringValue = "● monitoring"
        top.addArrangedSubview(statusLabel)

        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        stackView.orientation = .horizontal
        stackView.alignment = .top
        stackView.spacing = 14
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 10, right: 4)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stackView)
        scrollView.documentView = document

        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 22),
            top.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -22),
            top.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            top.heightAnchor.constraint(equalToConstant: 34),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            scrollView.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 18),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -18),

            document.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor),
            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: document.topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor)
        ])

        showEmptyState()
    }

    func setMonitoring(_ enabled: Bool) {
        statusLabel.stringValue = enabled ? "● monitoring" : "● paused"
        statusLabel.textColor = enabled ? .systemGreen : .systemOrange
    }

    func update(items: [ClipItem]) {
        allItems = items
        applyFilter()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let visible = query.isEmpty ? allItems : allItems.filter { $0.searchableText.lowercased().contains(query) }
        render(items: visible)
    }

    private func render(items: [ClipItem]) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        countLabel.stringValue = "\(items.count) položek"

        if items.isEmpty {
            showEmptyState()
            return
        }

        for item in items {
            let card = ClipCardView(item: item)
            card.onClick = { [weak self] selected in
                self?.onSelect?(selected)
            }
            stackView.addArrangedSubview(card)
        }
    }

    private func showEmptyState() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let label = NSTextField(labelWithString: "Zkopíruj text, odkaz nebo obrázek — objeví se tady.")
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 430).isActive = true
        stackView.addArrangedSubview(label)
        countLabel.stringValue = "0 položek"
    }

    func showAndActivate() {
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

final class ClipCardView: NSView {
    let item: ClipItem
    var onClick: ((ClipItem) -> Void)?

    init(item: ClipItem) {
        self.item = item
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 230).isActive = true
        heightAnchor.constraint(equalToConstant: 190).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.88).cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        let header = NSTextField(labelWithString: item.title)
        header.font = .systemFont(ofSize: 15, weight: .bold)
        header.textColor = .white
        header.translatesAutoresizingMaskIntoConstraints = false

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let when = NSTextField(labelWithString: formatter.localizedString(for: item.createdAt, relativeTo: Date()))
        when.font = .systemFont(ofSize: 11, weight: .regular)
        when.textColor = .secondaryLabelColor
        when.translatesAutoresizingMaskIntoConstraints = false

        addSubview(header)
        addSubview(when)

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            header.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            when.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            when.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 1)
        ])

        if let image = item.image {
            let imageView = NSImageView(image: image)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 10
            imageView.layer?.masksToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                imageView.topAnchor.constraint(equalTo: when.bottomAnchor, constant: 10),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
            ])
        } else {
            let body = NSTextField(wrappingLabelWithString: item.text ?? "")
            body.font = .systemFont(ofSize: 16, weight: .regular)
            body.textColor = .labelColor
            body.maximumNumberOfLines = 5
            body.lineBreakMode = .byTruncatingTail
            body.translatesAutoresizingMaskIntoConstraints = false
            addSubview(body)
            NSLayoutConstraint.activate([
                body.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
                body.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
                body.topAnchor.constraint(equalTo: when.bottomAnchor, constant: 12),
                body.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14)
            ])
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(item)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.push()
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
        layer?.borderColor = NSColor.white.withAlphaComponent(0.08).cgColor
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let keychainService = "online.novec.clipx.pastesio"
    private let keychainAccount = "api-key"

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var enabled = true
    private var apiKey = ""
    private var lastPasteURL: URL?
    private var history: [ClipItem] = []
    private let maxHistory = 50
    private var windowController: ClipXWindowController!
    private var suppressNextClipboardEvent = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        apiKey = loadKeychain() ?? ""

        windowController = ClipXWindowController()
        windowController.onSelect = { [weak self] item in
            self?.restoreToClipboard(item)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusButton()
        buildMenu()

        timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }

        if apiKey.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.windowController.showAndActivate()
                self?.promptForAPIKey(firstLaunch: true)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.windowController.showAndActivate()
            }
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: "ClipX") {
            image.isTemplate = true
            button.image = image
        }
        button.title = " ClipX"
        button.toolTip = "ClipX — clipboard history + Pastes.io"
    }

    private func buildMenu() {
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open ClipX", action: #selector(openClipX), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        let header = NSMenuItem(title: enabled ? "Monitoring active" : "Monitoring paused", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let toggle = NSMenuItem(title: enabled ? "Pause monitoring" : "Start monitoring", action: #selector(toggleMonitoring), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let sendNow = NSMenuItem(title: "Send clipboard now", action: #selector(sendClipboardNow), keyEquivalent: "")
        sendNow.target = self
        menu.addItem(sendNow)

        let openLast = NSMenuItem(title: "Open last paste", action: #selector(openLastPaste), keyEquivalent: "")
        openLast.target = self
        openLast.isEnabled = lastPasteURL != nil
        menu.addItem(openLast)

        menu.addItem(.separator())

        let keyTitle = apiKey.isEmpty ? "Set Pastes.io API key…" : "Change Pastes.io API key…"
        let key = NSMenuItem(title: keyTitle, action: #selector(setAPIKey), keyEquivalent: "")
        key.target = self
        menu.addItem(key)

        let clear = NSMenuItem(title: "Clear local history", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit ClipX", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openClipX() { windowController.showAndActivate() }

    @objc private func toggleMonitoring() {
        enabled.toggle()
        windowController.setMonitoring(enabled)
        buildMenu()
    }

    @objc private func clearHistory() {
        history.removeAll()
        windowController.update(items: history)
    }

    @objc private func setAPIKey() { promptForAPIKey(firstLaunch: false) }

    private func promptForAPIKey(firstLaunch: Bool) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = firstLaunch ? "Welcome to ClipX" : "Pastes.io API key"
        alert.informativeText = "API key is stored securely in macOS Keychain. New copied text is sent to Pastes.io automatically. Images stay only in local history."

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 390, height: 24))
        field.placeholderString = "Pastes.io API key"
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: firstLaunch ? "Later" : "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return }
            if saveKeychain(value) {
                apiKey = value
                buildMenu()
            }
        }
    }

    private func checkClipboard() {
        guard enabled else { return }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if suppressNextClipboardEvent {
            suppressNextClipboardEvent = false
            return
        }

        if let image = readImage(from: pb) {
            addToHistory(ClipItem(image: image))
            return
        }

        guard let text = pb.string(forType: .string)?.trimmingCharacters(in: .newlines), !text.isEmpty else { return }
        let kind: ClipKind = URL(string: text)?.scheme != nil ? .link : .text
        addToHistory(ClipItem(text: text, kind: kind))

        if !apiKey.isEmpty {
            upload(text)
        }
    }

    private func readImage(from pb: NSPasteboard) -> NSImage? {
        if let data = pb.data(forType: .tiff), let image = NSImage(data: data) { return image }
        if let data = pb.data(forType: .png), let image = NSImage(data: data) { return image }
        return nil
    }

    private func addToHistory(_ item: ClipItem) {
        if let text = item.text, history.first?.text == text { return }
        history.insert(item, at: 0)
        if history.count > maxHistory { history.removeLast(history.count - maxHistory) }
        windowController.update(items: history)
    }

    private func restoreToClipboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        suppressNextClipboardEvent = true
        pb.clearContents()
        if let text = item.text {
            pb.setString(text, forType: .string)
        } else if let image = item.image, let tiff = image.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        lastChangeCount = pb.changeCount
        NSSound(named: "Pop")?.play()
    }

    @objc private func sendClipboardNow() {
        guard !apiKey.isEmpty else { promptForAPIKey(firstLaunch: false); return }
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
        upload(text)
    }

    @objc private func openLastPaste() {
        if let url = lastPasteURL { NSWorkspace.shared.open(url) }
    }

    private func upload(_ text: String) {
        guard let url = URL(string: "https://pastes.io/api/paste") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let body: [String: Any] = ["title": "ClipX \(formatter.string(from: Date()))", "content": text]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
            var pasteURL: URL?
            if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                pasteURL = Self.findPasteURL(in: object)
            }
            DispatchQueue.main.async {
                self?.lastPasteURL = pasteURL
                self?.buildMenu()
            }
        }.resume()
    }

    private static func findPasteURL(in object: [String: Any]) -> URL? {
        for key in ["paste_url", "url", "link"] {
            if let value = object[key] as? String, let url = URL(string: value), url.scheme != nil { return url }
        }
        for value in object.values {
            if let nested = value as? [String: Any], let url = findPasteURL(in: nested) { return url }
        }
        return nil
    }

    // MARK: Keychain

    private func saveKeychain(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    private func loadKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
