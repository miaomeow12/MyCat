import Cocoa

/// Original procedural sample, independent of any user photo or generated private artwork.
/// Keeping this drawable in source also makes a clean checkout work without downloading assets.
enum GenericCat {
    static func frames() -> [NSImage] {
        (0..<8).map { pose in
            let image = NSImage(size: NSSize(width: 256, height: 256))
            image.lockFocus()
            draw(pose)
            image.unlockFocus()
            return image
        }
    }
    static func atlasData() -> Data {
        let sheet = NSImage(size: NSSize(width: 1024, height: 512))
        sheet.lockFocus()
        for (index, image) in frames().enumerated() {
            image.draw(in: NSRect(x: (index % 4) * 256, y: (1 - index / 4) * 256, width: 256, height: 256))
        }
        sheet.unlockFocus()
        return NSBitmapImageRep(data: sheet.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    }
    private static func draw(_ pose: Int) {
        let ink = NSColor(calibratedRed: 0.25, green: 0.25, blue: 0.34, alpha: 1)
        let fur = NSColor(calibratedRed: 0.62, green: 0.65, blue: 0.77, alpha: 1)
        let pale = NSColor(calibratedRed: 0.88, green: 0.89, blue: 0.95, alpha: 1)
        let pink = NSColor(calibratedRed: 0.94, green: 0.64, blue: 0.70, alpha: 1)
        func shape(_ path: NSBezierPath, _ color: NSColor, line: CGFloat = 3) {
            color.setFill(); path.fill()
            ink.setStroke(); path.lineWidth = line; path.lineJoinStyle = .round; path.stroke()
        }
        func oval(_ rect: NSRect, _ color: NSColor, line: CGFloat = 3) {
            shape(NSBezierPath(ovalIn: rect), color, line: line)
        }
        func stroke(_ from: NSPoint, _ to: NSPoint, width: CGFloat = 2.5) {
            let path = NSBezierPath(); path.move(to: from); path.line(to: to)
            ink.setStroke(); path.lineWidth = width; path.lineCapStyle = .round; path.stroke()
        }
        // Tail and small seated body.
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: 182, y: 42))
        tail.curve(to: NSPoint(x: 220, y: 120), controlPoint1: NSPoint(x: 248, y: 20), controlPoint2: NSPoint(x: 244, y: 131))
        ink.setStroke(); tail.lineWidth = 22; tail.lineCapStyle = .round; tail.stroke()
        fur.setStroke(); tail.lineWidth = 16; tail.stroke()
        oval(NSRect(x: 61, y: 24, width: 137, height: 135), fur)
        oval(NSRect(x: 90, y: 30, width: 78, height: 90), pale, line: 0)
        // A generic violet-gray cat, not a recreation of any user's markings.
        for right in [false, true] {
            let ear = NSBezierPath()
            let x: CGFloat = right ? 162 : 39
            ear.move(to: NSPoint(x: x, y: 161))
            ear.line(to: NSPoint(x: x + 5, y: 235))
            ear.line(to: NSPoint(x: x + 57, y: 192))
            ear.close(); shape(ear, fur)
            let inner = NSBezierPath()
            inner.move(to: NSPoint(x: x + 12, y: 186))
            inner.line(to: NSPoint(x: x + 13, y: 219))
            inner.line(to: NSPoint(x: x + 40, y: 193))
            inner.close(); pink.setFill(); inner.fill()
        }
        let dx: CGFloat = pose == 3 ? -6 : pose == 4 ? 6 : 0
        let dy: CGFloat = pose == 5 ? 4 : pose == 6 ? -6 : 0
        oval(NSRect(x: 32 + dx, y: 103 + dy, width: 192, height: 116), fur)
        oval(NSRect(x: 79 + dx, y: 112 + dy, width: 98, height: 48), pale, line: 0)
        for x: CGFloat in [91, 165] {
            if pose == 6 || pose == 7 {
                let eye = NSBezierPath()
                eye.move(to: NSPoint(x: x - 12 + dx, y: 165 + dy))
                eye.curve(to: NSPoint(x: x + 12 + dx, y: 165 + dy), controlPoint1: NSPoint(x: x - 4 + dx, y: pose == 7 ? 176 + dy : 157 + dy), controlPoint2: NSPoint(x: x + 4 + dx, y: pose == 7 ? 176 + dy : 157 + dy))
                ink.setStroke(); eye.lineWidth = 4; eye.lineCapStyle = .round; eye.stroke()
            } else {
                oval(NSRect(x: x - 14 + dx, y: 151 + dy, width: 28, height: 36), .white, line: 2)
                let gaze: CGFloat = pose == 3 ? -5 : pose == 4 ? 5 : 0
                oval(NSRect(x: x - 8 + dx + gaze, y: 157 + dy + (pose == 5 ? 5 : 0), width: 16, height: 23), NSColor(calibratedRed: 0.28, green: 0.58, blue: 0.55, alpha: 1), line: 1)
                oval(NSRect(x: x - 3 + dx + gaze, y: 159 + dy + (pose == 5 ? 5 : 0), width: 7, height: 18), ink, line: 0)
                oval(NSRect(x: x - 5 + dx + gaze, y: 171 + dy, width: 5, height: 6), .white, line: 0)
            }
        }
        oval(NSRect(x: 122 + dx, y: 139 + dy, width: 12, height: 8), pink, line: 1.5)
        stroke(NSPoint(x: 128 + dx, y: 139 + dy), NSPoint(x: 128 + dx, y: 132 + dy))
        stroke(NSPoint(x: 128 + dx, y: 132 + dy), NSPoint(x: 120 + dx, y: 128 + dy))
        stroke(NSPoint(x: 128 + dx, y: 132 + dy), NSPoint(x: 136 + dx, y: 128 + dy))
        for side: CGFloat in [-1, 1] {
            for delta: CGFloat in [-5, 4] {
                stroke(NSPoint(x: 128 + side * 54 + dx, y: 143 + delta + dy), NSPoint(x: 128 + side * 88 + dx, y: 145 + delta * 2 + dy), width: 1.5)
            }
        }
        if pose == 7 {
            pink.withAlphaComponent(0.65).setFill()
            NSBezierPath(ovalIn: NSRect(x: 63 + dx, y: 137 + dy, width: 23, height: 12)).fill()
            NSBezierPath(ovalIn: NSRect(x: 171 + dx, y: 137 + dy, width: 23, height: 12)).fill()
        }
        for (index, x) in [CGFloat(80), CGFloat(149)].enumerated() {
            let raised = pose == index + 1
            let y: CGFloat = raised ? 78 : 21
            oval(NSRect(x: x, y: y, width: 42, height: 34), pale)
            for offset: CGFloat in [12, 22, 32] {
                stroke(NSPoint(x: x + offset, y: y + 3), NSPoint(x: x + offset, y: y + 10), width: 1.4)
            }
        }
    }
}
