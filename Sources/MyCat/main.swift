import Cocoa
import Vision
import CoreImage
import UniformTypeIdentifiers

// MyCat: local companion; explicit optional API generation. Passive keyDown tap never reads key codes or text.
final class PetView: NSView {
    var input = InputMotion()
    var keyboardReady = false
    var demoRunning = false
    var photo: NSImage?
    var frames: [NSImage] = []
    var cartoon = true
    var followMouse = true
    var look = NSPoint.zero
    var lookTarget = NSPoint.zero
    var previousPointer: NSPoint?
    var mouseEnergy: CGFloat = 0
    var idleSeconds: Double = 0
    var animationTime: Double = 0
    var previewFrame: Int?
    func observePointer(_ point: NSPoint, anchor: NSPoint) {
        guard followMouse else { return }
        if let previousPointer {
            let distance = hypot(point.x - previousPointer.x, point.y - previousPointer.y)
            if distance > 0.5 { idleSeconds = 0; mouseEnergy = min(1, distance / 24) }
        }
        previousPointer = point
        lookTarget = NSPoint(x: max(-1, min(1, (point.x - anchor.x) / 260)),
                             y: max(-1, min(1, (point.y - anchor.y) / 230)))
    }
    var frameIndex: Int {
        if let previewFrame { return previewFrame }
        if affection > 0.2 { return 7 }
        if typing > 0.1 { return input.frame }
        if followMouse && input.clickFeedback > 0 { return look.x < -0.18 ? 3 : 4 }
        if idleSeconds > 25 { return 6 }
        if animationTime.truncatingRemainder(dividingBy: 6) > 5.85 { return 6 }
        if followMouse {
            if look.y > 0.6 && abs(look.x) < 0.6 { return 5 }
            if look.x < -0.18 { return 3 }
            if look.x > 0.18 { return 4 }
        }
        return 0
    }
    var phase: CGFloat = 0
    var affection: CGFloat = 0
    var leftStrike: CGFloat = 0
    var rightStrike: CGFloat = 0
    var nextLeft = true
    var activeKey = -1
    var typing: CGFloat = 0
    func syncInputPose() {
        leftStrike = input.hasStroke && input.left ? 1 : 0
        rightStrike = input.hasStroke && !input.left ? 1 : 0
        activeKey = input.activeKey
        typing = input.isTyping ? 1 : 0
    }
    func keyPressed() {
        idleSeconds = 0
        affection = min(affection, 0.15) // Real input takes priority over a prior petting animation.
        input.keyDown()
        syncInputPose()
        needsDisplay = true
    }
    func mouseButton(_ button: Int, down: Bool) {
        guard followMouse else { return }
        idleSeconds = 0
        input.mouseButton(button, down: down)
        needsDisplay = true
    }
    func advance(dt: Double = 1 / 24) {
        phase += CGFloat(dt * 1.9)
        animationTime += dt
        idleSeconds += dt
        input.tick(dt)
        let ease = CGFloat(1 - exp(-dt * 20))
        look.x += (lookTarget.x - look.x) * ease
        look.y += (lookTarget.y - look.y) * ease
        mouseEnergy *= CGFloat(exp(-dt * 2.8))
        affection *= CGFloat(exp(-dt * 1.5))
        syncInputPose()
        needsDisplay = true
    }
    var dragged = false
    var start: NSPoint = .zero
    var origin: NSPoint = .zero
    var hint = "点右上角菜单导入猫"
    var popup: NSMenu?
    private var menuGesture = false
    // Injectable presenter keeps event-routing regression tests free of modal UI.
    var menuPresenter: ((NSPoint) -> Void)?
    lazy var menuButton: NSButton = {
        let button = NSButton(title: "菜单 ▾", target: self, action: #selector(openMenuButton))
        button.frame = NSRect(x: bounds.width - 74, y: bounds.height - 30, width: 66, height: 25)
        button.autoresizingMask = [.minXMargin, .minYMargin]
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.toolTip = "导入照片、开启键盘互动和退出"
        button.setAccessibilityLabel("桌宠菜单")
        return button
    }()
    func installMenuButton() {
        if menuButton.superview == nil { addSubview(menuButton) }
    }
    func presentMenu(at point: NSPoint) {
        if let menuPresenter { menuPresenter(point); return }
        guard let popup else { return }
        NSApp.activate(ignoringOtherApps: true)
        popup.popUp(positioning: nil, at: point, in: self)
    }
    @objc func openMenuButton() {
        presentMenu(at: NSPoint(x: menuButton.frame.minX, y: menuButton.frame.minY))
    }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.scaleX(by: bounds.width / 280, yBy: bounds.height / 300)
        transform.concat()
        let bounce = sin(phase) * 1.5 + affection * 4 - max(leftStrike, rightStrike) * 2
        let ink = NSColor(calibratedRed: 0.36, green: 0.29, blue: 0.25, alpha: 1)
        let cream = NSColor(calibratedRed: 0.97, green: 0.93, blue: 0.85, alpha: 1)
        // Small keyboard, mouse, and soft desk shadow. All are native drawing.
        NSColor.black.withAlphaComponent(0.10).setFill()
        NSBezierPath(ovalIn: NSRect(x: 12, y: 43, width: 254, height: 21)).fill()
        NSColor(calibratedRed: 0.69, green: 0.60, blue: 0.49, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 16, y: 47, width: 204, height: 57), xRadius: 10, yRadius: 10).fill()
        cream.setFill()
        NSBezierPath(roundedRect: NSRect(x: 16, y: 53, width: 204, height: 57), xRadius: 10, yRadius: 10).fill()
        for row in 0..<3 {
            for col in 0..<10 {
                let pressed = activeKey == col && row == 1
                let key = NSRect(x: 24 + CGFloat(col) * 18.7, y: 61 + CGFloat(row) * 14 - (pressed ? 2 : 0), width: 15, height: 10)
                (pressed ? NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.44, alpha: 1) : NSColor.white).setFill()
                NSBezierPath(roundedRect: key, xRadius: 2.5, yRadius: 2.5).fill()
            }
        }
        let mouseX: CGFloat = 240 + (typing < 0.1 ? look.x * mouseEnergy * 4 : 0)
        let click = CGFloat(input.clickFeedback)
        let mouseY: CGFloat = 74 - click * 3 + (typing < 0.1 ? sin(phase * 2) * mouseEnergy * 2 : 0)
        let wire = NSBezierPath()
        wire.move(to: NSPoint(x: mouseX, y: mouseY + 32))
        wire.curve(to: NSPoint(x: 266, y: 122), controlPoint1: NSPoint(x: mouseX - 10, y: 150), controlPoint2: NSPoint(x: 275, y: 125))
        ink.withAlphaComponent(0.55).setStroke(); wire.lineWidth = 2; wire.stroke()
        let mouseBody = NSBezierPath(roundedRect: NSRect(x: mouseX - 13, y: mouseY, width: 26, height: 38), xRadius: 13, yRadius: 13)
        (click > 0 ? NSColor(calibratedRed: 1, green: 0.77, blue: 0.61, alpha: 1) : cream).setFill(); mouseBody.fill(); ink.setStroke(); mouseBody.lineWidth = 1.4; mouseBody.stroke()
        NSColor(calibratedRed: 0.77, green: 0.63, blue: 0.49, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: mouseX - 2, y: mouseY + 23, width: 4, height: 8), xRadius: 2, yRadius: 2).fill()
        if cartoon && frames.count == 8 {
            let index = frameIndex
            let image = frames[index]
            let size = NSSize(width: 220, height: 210)
            let x = 26 + (followMouse ? look.x * 3 : 0)
            let y = 86 + bounce
            image.draw(in: NSRect(x: x, y: y, width: size.width, height: size.height))
        } else {
            let rect = NSRect(x: 28 + look.x * 3, y: 99 + bounce, width: 220, height: 183)
            if let photo {
                let scale = min(rect.width / photo.size.width, rect.height / photo.size.height)
                let size = NSSize(width: photo.size.width * scale, height: photo.size.height * scale)
                photo.draw(in: NSRect(x: rect.midX - size.width / 2, y: rect.minY, width: size.width, height: size.height))
            } else {
                ("🐱" as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: 145)])
            }
        }
        if click > 0 {
            let ring = NSBezierPath(ovalIn: NSRect(x: mouseX - 20 - (1 - click) * 8, y: mouseY - 7 - (1 - click) * 8, width: 40 + (1 - click) * 16, height: 52 + (1 - click) * 16))
            NSColor.systemOrange.withAlphaComponent(click * 0.65).setStroke()
            ring.lineWidth = 2
            ring.stroke()
        }
        let text = demoRunning ? "演示中 · 30秒输入回放" : affection > 0.2 ? "♡ 被你摸得很开心" : typing > 0.1 ? "哒哒哒 · 一起上班" : idleSeconds > 25 ? "Zzz · 你休息，我也休息" : click > 0 ? "咔哒 · 收到你的点击" : mouseEnergy > 0.1 ? "你动鼠标，我也动" : !keyboardReady ? "菜单 → 开启键盘互动" : "陪你工作 · 点我摸摸"
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attrs)
        let label = NSRect(x: (280 - size.width) / 2 - 10, y: 10, width: size.width + 20, height: 24)
        NSColor.black.withAlphaComponent(0.48).setFill()
        NSBezierPath(roundedRect: label, xRadius: 12, yRadius: 12).fill()
        (text as NSString).draw(at: NSPoint(x: label.minX + 10, y: label.minY + 5), withAttributes: attrs)
    }
    override func mouseDown(with event: NSEvent) {
        menuGesture = event.modifierFlags.contains(.control) || event.buttonNumber == 1
        if menuGesture {
            presentMenu(at: convert(event.locationInWindow, from: nil))
            return
        }
        start = NSEvent.mouseLocation
        origin = window?.frame.origin ?? .zero
        dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard !menuGesture else { return }
        let p = NSEvent.mouseLocation
        if hypot(p.x - start.x, p.y - start.y) > 3 { dragged = true }
        if dragged { window?.setFrameOrigin(NSPoint(x: origin.x + p.x - start.x, y: origin.y + p.y - start.y)) }
    }
    override func mouseUp(with event: NSEvent) {
        if menuGesture { menuGesture = false; return }
        if !dragged { affection = 1; idleSeconds = 0 }
    }
    override func rightMouseDown(with event: NSEvent) {
        presentMenu(at: convert(event.locationInWindow, from: nil))
    }
}

final class App: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var status: NSStatusItem!
    var timer: Timer?
    let pet = PetView(frame: NSRect(x: 0, y: 0, width: 280, height: 300))
    var keyboardTap: CFMachPort?
    var keyboardSource: CFRunLoopSource?
    var keyboardWanted = UserDefaults.standard.bool(forKey: "keyboardInteractionEnabled")
    var mouseMonitors: [Any] = []
    var keyEventCount = 0
    var clickEventCount = 0
    var demoItem: NSMenuItem?
    var diagnosticItem: NSMenuItem?
    var keyboardItem: NSMenuItem?
    var permissionTimer: Timer?
    var demoTimer: Timer?
    var busy = false
    @MainActor lazy var generator = GenerationWindow { [weak self] data in
        guard let self else { return }
        let frames = try CatAtlas.decode(data)
        try FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
        let versioned = self.folder.appendingPathComponent("companion-\(UUID().uuidString).png")
        try data.write(to: versioned, options: .atomic)
        try data.write(to: self.sheetURL, options: .atomic)
        self.pet.frames = frames
        self.pet.cartoon = true
        self.pet.affection = 1
        self.refreshAppearanceItems()
    }
    var cartoonItem: NSMenuItem?
    var mouseItem: NSMenuItem?
    var sheetURL: URL { folder.appendingPathComponent("companion.png") }
    func loadCompanion() {
        if let data = try? Data(contentsOf: sheetURL), let frames = try? CatAtlas.decode(data) {
            pet.frames = frames
        } else {
            pet.frames = GenericCat.frames()
        }
    }
    func refreshAppearanceItems() {
        cartoonItem?.state = pet.cartoon ? .on : .off
        mouseItem?.state = pet.followMouse ? .on : .off
    }
    @objc func toggleCartoon() { pet.cartoon.toggle(); refreshAppearanceItems() }
    @objc func toggleMouse() {
        pet.followMouse.toggle()
        pet.previousPointer = nil
        if !pet.followMouse { pet.lookTarget = .zero; pet.mouseEnergy = 0 }
        refreshAppearanceItems()
    }
    @MainActor @objc func generateCat() { generator.show() }
    let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("MyCatLocal", isDirectory: true)
    var imageURL: URL { folder.appendingPathComponent("cat.png") }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = NSPanel(contentRect: pet.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        pet.autoresizingMask = [.width, .height]
        panel.contentView = pet
        resetPosition()
        loadCompanion()
        if let image = NSImage(contentsOf: imageURL) { pet.photo = image; pet.hint = "点我摸摸 · 拖动搬家" }
        let menu = NSMenu()
        add(menu, "照片 → 生成我的 Q 版猫…", #selector(generateCat))
        add(menu, "Q 版外观（关闭可看原照片）", #selector(toggleCartoon))
        cartoonItem = menu.items.last
        add(menu, "跟着鼠标一起工作", #selector(toggleMouse))
        mouseItem = menu.items.last
        menu.addItem(.separator())
        add(menu, "导入猫照片并本地抠图…", #selector(importCutout))
        add(menu, "直接导入图片（保留透明背景）…", #selector(importPlain))
        menu.addItem(.separator())
        add(menu, "开启键盘互动…", #selector(toggleKeyboard))
        keyboardItem = menu.items.last
        add(menu, "30秒输入演示（无需权限）", #selector(demoTyping))
        demoItem = menu.items.last
        add(menu, "输入诊断…", #selector(inputDiagnostics))
        diagnosticItem = menu.items.last
        add(menu, "摸摸猫咪 ♡", #selector(petCat))
        add(menu, "调整大小", #selector(resize))
        add(menu, "鼠标穿透（菜单栏可关闭）", #selector(clickThrough))
        add(menu, "回到屏幕右下角", #selector(resetPosition))
        add(menu, "删除原照片（保留 Q 版）", #selector(clearPhoto))
        menu.addItem(.separator())
        add(menu, "隐私与使用说明", #selector(privacy))
        add(menu, "退出", #selector(quit), key: "q")
        pet.popup = menu
        pet.installMenuButton()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "🐾"
        status.menu = menu
        refreshAppearanceItems()
        panel.orderFrontRegardless()
        installMouseMonitors()
        if keyboardWanted {
            connectKeyboard()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.checkKeyboardPermission() }
        }
        refreshKeyboardStatus()
        var lastTick = ProcessInfo.processInfo.systemUptime
        let ticker = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let dt = min(0.1, max(0, now - lastTick))
            lastTick = now
            if !self.pet.demoRunning, let screenRect = self.pet.window?.convertToScreen(self.pet.bounds) {
                self.pet.observePointer(NSEvent.mouseLocation, anchor: NSPoint(x: screenRect.midX, y: screenRect.midY + 40))
            }
            self.pet.advance(dt: dt)
        }
        RunLoop.main.add(ticker, forMode: .common)
        timer = ticker
    }
    func handleMouseEvent(_ event: NSEvent) {
        let down = [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type)
        if down { clickEventCount += 1 }
        pet.mouseButton(event.buttonNumber, down: down)
    }
    func installMouseMonitors() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in self?.handleMouseEvent(event) }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }) { mouseMonitors.append(local) }
    }
    @objc func inputDiagnostics() {
        let keyboard = keyboardTap.map { CGEvent.tapIsEnabled(tap: $0) ? "已连接" : "监听暂停" } ?? "未连接（请开启键盘互动并检查输入监控授权）"
        alert("输入状态", "键盘：\(keyboard)\n本次收到按下事件：\(keyEventCount)\n鼠标监视器：\(mouseMonitors.count == 2 ? "已连接" : "未完整连接")\n本次收到鼠标点击：\(clickEventCount)\n\n计数仅保存在本次运行的内存中，不记录输入内容。演示产生的事件不计入这些数字。")
    }
    func refreshKeyboardStatus() {
        keyboardItem?.state = keyboardWanted ? .on : .off
        keyboardItem?.title = keyboardTap != nil ? "关闭键盘互动" : keyboardWanted ? "等待输入监控授权（点击取消）" : "开启键盘互动…"
        pet.keyboardReady = keyboardTap != nil
        status.button?.toolTip = keyboardTap != nil ? "MyCat · 键盘互动已连接" : "MyCat · 键盘互动未连接"
    }
    func connectKeyboard() {
        guard keyboardWanted, keyboardTap == nil, CGPreflightListenEventAccess() else { return }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: keyboardCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }
        keyboardTap = tap
        keyboardSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        refreshKeyboardStatus()
    }
    func disconnectKeyboard() {
        if let tap = keyboardTap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source = keyboardSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        keyboardSource = nil
        keyboardTap = nil
    }
    func checkKeyboardPermission() {
        if keyboardTap != nil && !CGPreflightListenEventAccess() { disconnectKeyboard() }
        connectKeyboard()
        refreshKeyboardStatus()
    }
    @objc func toggleKeyboard() {
        keyboardWanted.toggle()
        UserDefaults.standard.set(keyboardWanted, forKey: "keyboardInteractionEnabled")
        if keyboardWanted {
            if !CGPreflightListenEventAccess() {
                CGRequestListenEventAccess()
                alert("开启打字陪伴", "请在「系统设置 → 隐私与安全性 → 输入监控」中允许 MyCat。若未列出，点 + 添加当前 MyCat.app。授权后会自动重试；必要时退出重开并再次开启键盘互动。\n\n只感应按下事件，不读取按键编号或文字，不保存按键记录。密码框等安全输入环境下可能暂停响应。")
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                    NSWorkspace.shared.open(url)
                }
            }
            connectKeyboard()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.checkKeyboardPermission() }
        } else {
            permissionTimer?.invalidate()
            permissionTimer = nil
            disconnectKeyboard()
        }
        refreshKeyboardStatus()
    }
    func handleKeyPress() { keyEventCount += 1; pet.keyPressed() }
    @objc func demoTyping() {
        if demoTimer != nil { stopDemo(); return }
        pet.demoRunning = true
        demoItem?.title = "停止输入演示"
        var elapsed = 0.0
        let demo = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            elapsed += 0.1
            if elapsed < 20 { self.pet.keyPressed() }
            else {
                self.pet.observePointer(NSPoint(x: sin(elapsed * 2) * 500, y: cos(elapsed) * 180), anchor: .zero)
                if elapsed > 25 {
                    self.pet.mouseButton(0, down: Int((elapsed - 25) * 10) % 4 < 2)
                }
            }
            if elapsed >= 30 { self.stopDemo() }
        }
        RunLoop.main.add(demo, forMode: .common)
        demoTimer = demo
    }
    func stopDemo() {
        demoTimer?.invalidate()
        demoTimer = nil
        pet.demoRunning = false
        pet.input.mouseButton(0, down: false)
        pet.previousPointer = nil
        demoItem?.title = "30秒输入演示（无需权限）"
    }
    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        stopDemo()
        for monitor in mouseMonitors { NSEvent.removeMonitor(monitor) }
        mouseMonitors.removeAll()
        disconnectKeyboard()
    }
    func add(_ menu: NSMenu, _ name: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: name, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }
    @objc func resetPosition() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 800)
        panel.setFrameOrigin(NSPoint(x: screen.maxX - panel.frame.width - 32, y: screen.minY + 20))
    }
    @objc func importCutout() { choose(cutout: true) }
    @objc func importPlain() { choose(cutout: false) }
    func choose(cutout: Bool) {
        guard !busy else { return }
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        picker.allowsMultipleSelection = false
        picker.canChooseDirectories = false
        picker.message = cutout ? "选一张主体清晰的猫照片。抠图在本机完成，不上传。" : "选择猫图片，透明 PNG 效果最好。"
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let url = picker.url else { return }
        busy = true
        pet.hint = "正在本地处理…"
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let image = NSImage(contentsOf: url) else { throw self.failure("无法读取这张照片。") }
                // Normalize orientation and limit pixels before segmentation.
                let ratio = min(1, 1800 / max(image.size.width, image.size.height))
                let size = NSSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
                let normalized = NSImage(size: size)
                normalized.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: size))
                normalized.unlockFocus()
                guard let tiff = normalized.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let cg = bitmap.cgImage else { throw self.failure("照片解码失败。") }
                var result = cg
                if cutout {
                    let handler = VNImageRequestHandler(cgImage: cg)
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    try handler.perform([request])
                    guard let observation = request.results?.first, !observation.allInstances.isEmpty else { throw self.failure("没有识别到清晰主体，请换一张背景简单的照片，或直接导入已抠好的透明 PNG。") }
                    let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
                    let ci = CIImage(cvPixelBuffer: buffer)
                    guard let output = CIContext().createCGImage(ci, from: ci.extent) else { throw self.failure("抠图输出失败。") }
                    result = output
                }
                guard let png = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:]) else { throw self.failure("图片保存失败。") }
                try FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
                try png.write(to: self.imageURL, options: .atomic)
                DispatchQueue.main.async {
                    self.pet.photo = NSImage(data: png)
                    self.pet.cartoon = false
                    self.refreshAppearanceItems()
                    self.pet.hint = "点我摸摸 · 拖动搬家"
                    self.pet.affection = 1
                    self.busy = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    self.pet.hint = self.pet.photo == nil ? "点右上角菜单导入猫" : "点我摸摸 · 拖动搬家"
                    self.alert("导入没有完成", error.localizedDescription)
                }
            }
        }
    }
    func failure(_ message: String) -> NSError { NSError(domain: "MyCat", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    func alert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    @objc func petCat() { pet.affection = 1; pet.idleSeconds = 0 }
    @objc func resize() {
        let next: CGFloat = panel.frame.width < 330 ? panel.frame.width + 50 : 230
        panel.setContentSize(NSSize(width: next, height: next + 20))
    }
    @objc func clickThrough(_ sender: NSMenuItem) {
        panel.ignoresMouseEvents.toggle()
        sender.state = panel.ignoresMouseEvents ? .on : .off
    }
    @objc func clearPhoto() {
        guard !busy else { return }
        do {
            if FileManager.default.fileExists(atPath: imageURL.path) { try FileManager.default.removeItem(at: imageURL) }
            pet.photo = nil
            pet.hint = "点右上角菜单导入猫"
        } catch { alert("删除失败", error.localizedDescription) }
    }
    @objc func privacy() {
        alert("你的猫，陪你一起上班", "日常运行和本地抠图都在本机。鼠标陪伴读取指针位置与鼠标按下/松开事件，用于看向和小鼠标点击反馈；不移动真实鼠标，不保存轨迹。\n\n键盘互动需你主动开启输入监控，只感应按下事件，不读取键码或文字，不保存输入。\n\n「生成我的 Q 版猫」是可选联网功能：你选的照片会在点击生成后直传 api.openai.com，费用由你填写的 Key 对应账户承担。Key 仅在本次生成请求中使用，不写文件。生成窗口有实时草稿预览，确认后将动作图保存到 ~/Library/Application Support/MyCatLocal/；旧版以带 UUID 的文件保留。没有统计上报或自动更新。\n\n点「菜单 ▾」打开菜单。当前 Q 版为八种动作图加轻微呼吸和移动效果。")
    }
    @objc func quit() { NSApp.terminate(nil) }
}
// The callback ignores the event payload; passive tap leaves the original event untouched.
private let keyboardCallback: CGEventTapCallBack = { _, type, event, info in
    if let info {
        let owner = Unmanaged<App>.fromOpaque(info).takeUnretainedValue()
        if type == .keyDown { owner.handleKeyPress() }
        else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = owner.keyboardTap, owner.keyboardWanted { CGEvent.tapEnable(tap: tap, enable: true) }
        }
    }
    return Unmanaged.passUnretained(event)
}
let app = NSApplication.shared
let delegate = App()
if CommandLine.arguments.contains("--export-generic-atlas") {
    try GenericCat.atlasData().write(to: URL(fileURLWithPath: CommandLine.arguments.last!))
    print("PASS: exported procedural generic-cat fixture without private images")
} else if CommandLine.arguments.contains("--export-demo") {
    try exportInputDemo(view: delegate.pet, to: URL(fileURLWithPath: CommandLine.arguments.last!))
} else if CommandLine.arguments.contains("--input-test") {
    try runInputReplayChecks(view: delegate.pet, keyDown: {
        let event = CGEvent(source: nil)!
        let pointer = Unmanaged.passUnretained(delegate).toOpaque()
        _ = keyboardCallback(OpaquePointer(pointer), .keyDown, event, pointer)
    }, mouse: { down in
        let event = NSEvent.mouseEvent(with: down ? .leftMouseDown : .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: down ? 1 : 0)!
        delegate.handleMouseEvent(event)
    })
} else if CommandLine.arguments.contains("--generation-test") {
    Task { @MainActor in
        do {
            try await runGenerationChecks(assetURL: URL(fileURLWithPath: CommandLine.arguments.last!))
            exit(0)
        } catch {
            print("FAIL: generation checks: \(error.localizedDescription)")
            exit(1)
        }
    }
    app.run()
} else if CommandLine.arguments.contains("--generation-ui-test") {
    app.finishLaunching()
    try MainActor.assumeIsolated {
        try delegate.generator.renderPreview(to: URL(fileURLWithPath: CommandLine.arguments.last!))
    }
    print("PASS: generation window rendered without any network request")
} else if CommandLine.arguments.contains("--companion-test") {
    let dir = CommandLine.arguments.last!
    delegate.pet.frames = try CatAtlas.decode(GenericCat.atlasData())
    let view = delegate.pet
    precondition(view.frames.count == 8)
    view.observePointer(.zero, anchor: .zero)
    view.observePointer(NSPoint(x: -500, y: 0), anchor: .zero)
    for _ in 0..<24 { view.advance() }
    precondition(view.frameIndex == 3 && view.look.x < -0.9, "Cat must look left when cursor goes left")
    view.observePointer(NSPoint(x: 500, y: 0), anchor: .zero)
    for _ in 0..<24 { view.advance() }
    precondition(view.frameIndex == 4 && view.look.x > 0.9, "Cat must look right when cursor goes right")
    view.observePointer(NSPoint(x: 0, y: 500), anchor: .zero)
    for _ in 0..<24 { view.advance() }
    precondition(view.frameIndex == 5, "Cat must look up when the cursor is above")
    view.keyPressed()
    precondition(view.frameIndex == 1, "Typing must override cursor tracking")
    for _ in 0..<650 { view.advance() }
    precondition(view.frameIndex == 6, "Cat must sleep after idle")
    view.observePointer(NSPoint(x: 490, y: 5), anchor: .zero)
    precondition(view.idleSeconds == 0 && view.frameIndex != 6, "Cursor movement must wake cat")
    view.followMouse = false
    let target = view.lookTarget
    view.observePointer(NSPoint(x: -999, y: 0), anchor: .zero)
    precondition(view.lookTarget == target, "Disabled tracking must ignore cursor")
    print("PASS: eight sprites; mouse left/right; typing priority; sleep; movement wakes; tracking opt-out")
    // Render all eight actual states to inspect alignment and interaction objects.
    for frame in 0..<8 {
        view.previewFrame = frame
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 560, pixelsHigh: 600, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let scale = NSAffineTransform(); scale.scale(by: 2); scale.concat()
        NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.91, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 280, height: 300)).fill()
        view.mouseEnergy = 0
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: dir).appendingPathComponent("companion-state-\(frame).png"))
    }
} else if CommandLine.arguments.contains("--popup-test") {
    final class MenuProbe: NSObject, NSMenuDelegate {
        var opened = false
        func menuWillOpen(_ menu: NSMenu) { opened = true }
    }
    app.finishLaunching()
    delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    let probe = MenuProbe()
    delegate.pet.popup!.delegate = probe
    let close = Timer(timeInterval: 0.25, repeats: false) { _ in delegate.pet.popup!.cancelTracking() }
    RunLoop.main.add(close, forMode: .common)
    RunLoop.main.add(close, forMode: .eventTracking)
    delegate.pet.menuButton.performClick(nil)
    precondition(probe.opened, "The actual native menu must open from the visible button")
    close.invalidate()
    delegate.timer?.invalidate()
    delegate.panel.orderOut(nil)
    NSStatusBar.system.removeStatusItem(delegate.status)
    print("PASS: visible button opened actual native app menu (menuWillOpen observed)")
} else if CommandLine.arguments.contains("--interaction-test") {
    let view = delegate.pet
    var menuRequests = 0
    view.menuPresenter = { _ in menuRequests += 1 }
    view.installMenuButton()
    func mouse(_ type: NSEvent.EventType, control: Bool = false) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: NSPoint(x: 120, y: 150), modifierFlags: control ? [.control] : [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
    }
    view.mouseDown(with: mouse(.leftMouseDown, control: true))
    view.mouseUp(with: mouse(.leftMouseUp, control: true))
    precondition(view.affection == 0 && menuRequests == 1, "Control-click must open menu without purring")
    view.rightMouseDown(with: mouse(.rightMouseDown))
    precondition(menuRequests == 2 && view.affection == 0, "Native right-click must open menu")
    view.menuButton.performClick(nil)
    precondition(menuRequests == 3 && view.affection == 0, "Visible menu button must open menu")
    view.mouseDown(with: mouse(.leftMouseDown))
    view.mouseUp(with: mouse(.leftMouseUp))
    precondition(view.affection == 1 && menuRequests == 3, "Normal click must still pet the cat")
    view.setFrameSize(NSSize(width: 330, height: 350))
    precondition(view.bounds.contains(view.menuButton.frame), "Menu button must stay visible after resizing")
    print("PASS: Control-click, right-click, visible menu button; no accidental purring; normal petting; resize")
} else if CommandLine.arguments.contains("--self-test") {
    // Synthetic events are invoked in-process only; none are posted to the system.
    let view = delegate.pet
    func render(_ name: String) {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 560, pixelsHigh: 600,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let scale = NSAffineTransform(); scale.scale(by: 2); scale.concat()
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
    }
    let dir = CommandLine.arguments.last!
    delegate.loadCompanion()
    render(dir + "/keyboard-idle.png")
    let event = CGEvent(source: nil)!
    let pointer = Unmanaged.passUnretained(delegate).toOpaque()
    let returned = keyboardCallback(OpaquePointer(pointer), .keyDown, event, pointer)
    precondition(returned?.takeUnretainedValue() === event, "Keyboard event must pass through")
    precondition(view.leftStrike == 1 && view.rightStrike == 0 && view.activeKey >= 0 && view.activeKey < 5,
        "First keyboard event must visibly activate left paw and keyboard")
    render(dir + "/keyboard-typing.png")
    _ = keyboardCallback(OpaquePointer(pointer), .keyDown, event, pointer)
    for _ in 0..<8 { view.advance() }
    precondition(view.rightStrike == 1 && view.activeKey >= 5, "Second event must activate right paw")
    for _ in 0..<90 { view.advance() }
    precondition(view.activeKey == -1 && view.leftStrike < 0.001 && view.rightStrike < 0.001,
        "Paws and keys must return to idle when typing stops")
    _ = keyboardCallback(OpaquePointer(pointer), .keyUp, event, pointer)
    precondition(view.activeKey == -1, "Unsubscribed events must not trigger animation")
    print("PASS: keyDown → alternating paws + keyboard highlight; event unchanged; idle recovery; keyUp ignored")
} else {
    app.delegate = delegate
    app.run()
}
