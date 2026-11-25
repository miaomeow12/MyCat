import Cocoa

let companionPrompt = """
Create a production desktop-pet animation sprite sheet from the reference photo of THIS person's cat. Preserve its distinctive fur colors, markings, eye color, face shape and ears. Style: extremely cute chibi hand-drawn 2D cat sticker, oversized rounded head, small fluffy seated body, soft watercolor/cel shading, warm dark outlines. Not photographic. EXACTLY 4 columns by 2 rows, eight equal rectangular cells, one complete cat per cell. Same cat identity, same centered scale and baseline in every cell; 10% transparent padding around every cat; ears and paws never touch cell boundaries. Genuine transparent background, no shadow fringe, no grid, no text, no props, no keyboard or desk. Front-facing seated bust with front paws at lower edge. Row-major cells: 1 idle looking forward, paws down; 2 image-left paw raised for typing; 3 image-right paw raised for typing; 4 head/eyes looking image-left, right paw reaching slightly forward; 5 head/eyes looking image-right, right paw reaching slightly forward; 6 looking slightly upward, curious; 7 asleep, closed eyes and relaxed head, paws tucked; 8 happy being petted, closed smiling eyes, pink cheeks. Keep coherent proportions, cell alignment, colors and markings throughout all eight cells. Avoid vivid colored fringes or background remnants.
"""

enum ImageStreamEvent {
    case preview(Data), complete(Data)
}
struct ImageEventDecoder {
    private var lines: [String] = []
    mutating func push(_ line: String) throws -> ImageStreamEvent? {
        if line.isEmpty {
            guard !lines.isEmpty else { return nil }
            let payload = lines.joined(separator: "\n")
            lines.removeAll(keepingCapacity: true)
            if payload == "[DONE]" { return nil }
            guard let data = payload.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw GenerationError.message("生成服务返回了无法识别的数据，请重试。")
            }
            let type = object["type"] as? String ?? ""
            if type == "error" || type.hasSuffix(".failed") || object["error"] != nil {
                throw GenerationError.message("图像服务未能完成生成，请检查账户额度、模型权限后重试。")
            }
            guard type == "image_edit.partial_image" || type == "image_edit.completed" else { return nil }
            guard let base64 = object["b64_json"] as? String, base64.count < 90_000_000,
                  let image = Data(base64Encoded: base64), NSImage(data: image) != nil else {
                throw GenerationError.message("生成的图片数据不完整，请重试。")
            }
            return type == "image_edit.completed" ? .complete(image) : .preview(image)
        }
        if line.hasPrefix("data:") {
            var value = String(line.dropFirst(5))
            if value.first == " " { value.removeFirst() }
            guard value.utf8.count < 90_000_000 else { throw GenerationError.message("图片响应过大。") }
            lines.append(value)
        }
        return nil
    }
}
enum GenerationError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
private final class NoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
enum ImageAPI {
    static func request(photo: Data, key: String, model: String) throws -> URLRequest {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !key.contains("\n"), !key.contains("\r"), !model.isEmpty else {
            throw GenerationError.message("请输入有效 API Key 和模型名。")
        }
        guard photo.count <= 14_000_000, NSImage(data: photo) != nil else {
            throw GenerationError.message("请使用小于 14 MB 的有效猫照片。")
        }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 600
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "prompt": companionPrompt,
            "images": [["image_url": "data:image/png;base64," + photo.base64EncodedString()]],
            "size": "1536x1024", "quality": "high", "output_format": "png",
            "background": "transparent", "stream": true, "partial_images": 2
        ])
        return request
    }
    static func generate(photo: Data, key: String, model: String,
                         preview: @escaping (Data) async -> Void,
                         configuration: URLSessionConfiguration? = nil) async throws -> Data {
        let request = try request(photo: photo, key: key, model: model)
        let config = configuration ?? URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpShouldSetCookies = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForResource = 660
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw GenerationError.message("未收到有效响应。") }
        guard http.statusCode == 200 else {
            switch http.statusCode {
            case 401: throw GenerationError.message("API Key 无效或已失效，请重新输入。")
            case 403: throw GenerationError.message("此账户无权使用该模型，或服务区域不受支持。")
            case 429: throw GenerationError.message("账户额度不足或请求过于频繁，请检查 API 账单和限额。")
            default: throw GenerationError.message("图像服务返回 HTTP \(http.statusCode)。请检查模型名或稍后重试。")
            }
        }
        var decoder = ImageEventDecoder()
        // Preserve empty SSE separator lines. AsyncBytes.lines can skip empty lines.
        var lineData = Data()
        for try await byte in bytes {
            if byte == 10 {
                try Task.checkCancellation()
                if lineData.last == 13 { lineData.removeLast() }
                guard let line = String(data: lineData, encoding: .utf8) else {
                    throw GenerationError.message("生成流的编码无效。")
                }
                lineData.removeAll(keepingCapacity: true)
                if let event = try decoder.push(line) {
                    switch event {
                    case .preview(let data): await preview(data)
                    case .complete(let data): return data
                    }
                }
            } else {
                guard lineData.count < 90_000_000 else { throw GenerationError.message("图片响应过大。") }
                lineData.append(byte)
            }
        }
        if !lineData.isEmpty {
            if lineData.last == 13 { lineData.removeLast() }
            guard let line = String(data: lineData, encoding: .utf8) else { throw GenerationError.message("生成流的编码无效。") }
            _ = try decoder.push(line)
        }
        // Some transports end immediately after the final data line without a blank separator.
        if let event = try decoder.push(""), case .complete(let data) = event { return data }
        throw GenerationError.message("连接提前结束，尚未收到最终图片；原桌宠保持不变。可稍后重新生成。")
    }
}

private final class GenerationBackground: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()
    }
}
@MainActor
final class GenerationWindow: NSObject, NSWindowDelegate {
    private var window: NSWindow!
    private let keyField = NSSecureTextField()
    private let modelField = NSTextField(string: "gpt-image-2.5-flare")
    private let photoLabel = NSTextField(labelWithString: "尚未选择照片")
    private let progressLabel = NSTextField(wrappingLabelWithString: "选择猫照片并填写自己的 API Key。点击生成才会上传。")
    private let previewView = NSImageView()
    private var chooseButton: NSButton!
    private var generateButton: NSButton!
    private var applyButton: NSButton!
    private var cancelButton: NSButton!
    private var photo: Data?
    private var completed: Data?
    private var task: Task<Void, Never>?
    private let apply: (Data) throws -> Void
    init(apply: @escaping (Data) throws -> Void) { self.apply = apply; super.init() }
    func show() {
        if window == nil { build() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    func renderPreview(to url: URL) throws {
        show()
        window.contentView!.displayIfNeeded()
        let root = window.contentView!
        let rep = root.bitmapImageRepForCachingDisplay(in: root.bounds)!
        root.cacheDisplay(in: root.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])!.write(to: url)
        window.orderOut(nil)
    }
    private func build() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "把你的猫变成工作搭子"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.contentView = GenerationBackground(frame: NSRect(x: 0, y: 0, width: 560, height: 680))
        let root = window.contentView!
        func put(_ view: NSView, _ frame: NSRect) { view.frame = frame; root.addSubview(view) }
        let heading = NSTextField(labelWithString: "照片 → Q 版 → 陪你一起上班")
        heading.font = .systemFont(ofSize: 21, weight: .semibold)
        put(heading, NSRect(x: 24, y: 626, width: 512, height: 30))
        let privacy = NSTextField(wrappingLabelWithString: "使用你自己的 API 额度。照片仅在生成时直传 api.openai.com；Key 仅用于本次请求，不写入磁盘。生成完成后可离线陪伴。")
        privacy.font = .systemFont(ofSize: 12)
        privacy.textColor = .secondaryLabelColor
        put(privacy, NSRect(x: 24, y: 566, width: 512, height: 48))
        chooseButton = NSButton(title: "选择猫照片…", target: self, action: #selector(choosePhoto))
        put(chooseButton, NSRect(x: 24, y: 520, width: 130, height: 32))
        photoLabel.lineBreakMode = .byTruncatingMiddle
        put(photoLabel, NSRect(x: 164, y: 527, width: 372, height: 20))
        keyField.placeholderString = "OpenAI API Key（不要发到聊天里）"
        put(keyField, NSRect(x: 24, y: 477, width: 512, height: 28))
        let modelLabel = NSTextField(labelWithString: "图像模型")
        put(modelLabel, NSRect(x: 24, y: 442, width: 75, height: 20))
        put(modelField, NSRect(x: 102, y: 437, width: 434, height: 28))
        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.90, alpha: 1).cgColor
        previewView.layer?.cornerRadius = 12
        put(previewView, NSRect(x: 24, y: 142, width: 512, height: 278))
        progressLabel.font = .systemFont(ofSize: 12)
        put(progressLabel, NSRect(x: 24, y: 85, width: 512, height: 45))
        generateButton = NSButton(title: "上传并生成（使用 API 额度）", target: self, action: #selector(startGeneration))
        generateButton.bezelStyle = .rounded
        put(generateButton, NSRect(x: 24, y: 28, width: 238, height: 36))
        cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelGeneration))
        put(cancelButton, NSRect(x: 270, y: 28, width: 72, height: 36))
        applyButton = NSButton(title: "应用为桌宠", target: self, action: #selector(applyCat))
        applyButton.isEnabled = false
        put(applyButton, NSRect(x: 350, y: 28, width: 186, height: 36))
    }
    @objc private func choosePhoto() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        picker.allowsMultipleSelection = false
        guard picker.runModal() == .OK, let url = picker.url, let image = NSImage(contentsOf: url) else { return }
        let scale = min(1, 1200 / max(image.size.width, image.size.height))
        let normalized = NSImage(size: NSSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale)))
        normalized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: normalized.size))
        normalized.unlockFocus()
        guard let tiff = normalized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { return }
        photo = png
        completed = nil
        applyButton.isEnabled = false
        photoLabel.stringValue = url.lastPathComponent
        previewView.image = normalized
        progressLabel.stringValue = "已选择照片。点击生成后会上传这张照片，并使用你账户的 API 额度。"
    }
    private func setRunning(_ running: Bool) {
        chooseButton.isEnabled = !running
        generateButton.isEnabled = !running
        keyField.isEnabled = !running
        modelField.isEnabled = !running
    }
    @objc private func startGeneration() {
        guard task == nil else { return }
        guard let photo else { progressLabel.stringValue = "请先选择一张猫照片。"; return }
        let key = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !model.isEmpty else { progressLabel.stringValue = "请填写你自己的 API Key 和图像模型名。"; return }
        keyField.stringValue = ""
        completed = nil
        applyButton.isEnabled = false
        setRunning(true)
        progressLabel.stringValue = "正在上传并生成八种动作… 草稿返回后会显示预览，请稍候。"
        task = Task { [weak self] in
            guard let self else { return }
            defer { self.task = nil; self.setRunning(false) }
            do {
                let data = try await ImageAPI.generate(photo: photo, key: key, model: model) { [weak self] partial in
                    await MainActor.run {
                        self?.previewView.image = NSImage(data: partial)
                        self?.progressLabel.stringValue = "正在细化 Q 版动作… 当前为实时草稿，最终完成后可应用。"
                    }
                }
                try Task.checkCancellation()
                _ = try CatAtlas.decode(data)
                self.completed = data
                self.previewView.image = NSImage(data: data)
                self.applyButton.isEnabled = true
                self.progressLabel.stringValue = "生成完成！检查猫的花纹和动作后，点「应用为桌宠」。不满意可重新填写 Key 再生成。"
            } catch {
                if Task.isCancelled { self.progressLabel.stringValue = "已取消本机等待，原桌宠保持不变。服务端已开始的生成可能仍会计费。" }
                else { self.progressLabel.stringValue = error.localizedDescription }
            }
        }
    }
    @objc private func cancelGeneration() { task?.cancel() }
    @objc private func applyCat() {
        guard let completed else { return }
        do {
            try apply(completed)
            self.completed = nil
            applyButton.isEnabled = false
            progressLabel.stringValue = "已应用到桌宠，生成窗口可以关闭。"
        } catch { progressLabel.stringValue = "应用失败：" + error.localizedDescription }
    }
    func windowWillClose(_ notification: Notification) {
        task?.cancel()
        keyField.stringValue = ""
    }
}
