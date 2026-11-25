import Cocoa
import ImageIO

/// Atlas row order: idle, type-left, type-right, look-left, look-right, look-up, sleep, happy.
enum CatAtlas {
    static func decode(_ data: Data) throws -> [NSImage] {
        guard let rep = NSBitmapImageRep(data: data), let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil),
              cg.width >= 800, cg.height >= 400, cg.width <= 4096, cg.height <= 4096,
              Double(cg.width) / Double(cg.height) > 1.25,
              Double(cg.width) / Double(cg.height) < 2.3, rep.hasAlpha else {
            throw NSError(domain: "MyCat", code: 2, userInfo: [NSLocalizedDescriptionKey: "需要带透明背景的 4 列 × 2 行动作图。生成图片尺寸或格式不正确，请保留原桌宠并重试。"])
        }
        var frames: [NSImage] = []
        for index in 0..<8 {
            let col = index % 4, row = index / 4
            let x0 = cg.width * col / 4, x1 = cg.width * (col + 1) / 4
            let y0 = cg.height * row / 2, y1 = cg.height * (row + 1) / 2
            guard let tile = cg.cropping(to: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)) else {
                throw NSError(domain: "MyCat", code: 3)
            }
            frames.append(NSImage(cgImage: tile, size: NSSize(width: tile.width, height: tile.height)))
        }
        return frames
    }
}
