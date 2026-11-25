import Cocoa
import ImageIO
import UniformTypeIdentifiers

func runInputReplayChecks(view: PetView, keyDown: () -> Void, mouse: (Bool) -> Void) throws {
    keyDown()
    for _ in 0..<15 { view.advance(dt: 1 / 60) }
    precondition(view.leftStrike == 1 && view.activeKey >= 0, "One key must remain visually readable at 250 ms")
    for _ in 0..<60 { view.advance(dt: 1 / 60) }
    precondition(!view.input.isTyping, "One key must not start autonomous typing")
    view.input = InputMotion()
    view.syncInputPose()
    view.affection = 0
    var busyFrames = 0
    var frames = Set<Int>()
    var transitions = 0
    var previous = -1
    var lastTransition = -100.0
    var shortestPose = Double.infinity
    // 30 seconds: actual callback route receives 10 keys/sec, while the real view updates at 60 Hz.
    for tick in 0..<1800 {
        if tick % 6 == 0 { keyDown() }
        view.advance(dt: 1 / 60)
        let frame = view.frameIndex
        if view.input.isTyping { busyFrames += 1 }
        frames.insert(frame)
        if frame != previous {
            let now = Double(tick) / 60
            if previous >= 0 { shortestPose = min(shortestPose, now - lastTransition) }
            lastTransition = now
            transitions += 1
            previous = frame
        }
        precondition(view.input.queued <= 2, "High-frequency input must be coalesced into a bounded queue")
    }
    precondition(busyFrames == 1800, "Continuous typing must never drop into idle or mouse poses")
    precondition(frames == Set([0, 1, 2]), "Typing must visibly include both lifted paws and the down pose")
    precondition(shortestPose >= 0.11, "Every typing pose must last long enough to read, without one-frame flashes")
    for _ in 0..<90 { view.advance(dt: 1 / 60) }
    precondition(!view.input.isTyping && view.activeKey == -1, "Animation must settle after typing stops")
    mouse(true)
    precondition(view.input.isMouseHeld && view.input.clickFeedback == 1, "Mouse down must react immediately")
    for _ in 0..<120 { view.advance(dt: 1 / 60) }
    precondition(view.input.isMouseHeld && view.input.clickFeedback == 1, "A held click must stay visibly held")
    mouse(false)
    precondition(!view.input.isMouseHeld, "Mouse up must release immediately")
    for _ in 0..<30 { view.advance(dt: 1 / 60) }
    precondition(view.input.clickFeedback == 0, "Click feedback must clear after release")
    print("PASS: 30s input replay through actual callbacks; 300 keys; 100% typing coverage; left/down/right poses; shortest pose \(String(format: "%.3f", shortestPose))s; \(transitions) transitions; bounded queue; settles after stop; immediate mouse down/up and 2s hold")
}

/// A public demo made by replaying synthetic input through the same view animation, not by sending OS events.
func exportInputDemo(view: PetView, to url: URL) throws {
    view.frames = GenericCat.frames()
    view.keyboardReady = true
    view.demoRunning = true
    guard let gif = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 144, nil) else {
        throw NSError(domain: "MyCatDemo", code: 1)
    }
    CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    for tick in 0..<144 {
        if tick < 96 && tick % 2 == 0 { view.keyPressed() }
        if tick >= 96 {
            view.observePointer(NSPoint(x: sin(Double(tick) / 7) * 480, y: 0), anchor: .zero)
            view.mouseButton(0, down: tick % 12 < 5)
        }
        view.advance(dt: 1 / 12)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 420, pixelsHigh: 450, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let scale = NSAffineTransform(); scale.scale(by: 1.5); scale.concat()
        NSColor(calibratedRed: 0.95, green: 0.94, blue: 0.91, alpha: 1).setFill()
        NSBezierPath(rect: view.bounds).fill()
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        CGImageDestinationAddImage(gif, rep.cgImage!, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 12]] as CFDictionary)
    }
    precondition(CGImageDestinationFinalize(gif))
    print("PASS: exported 12s clearly labelled synthetic-input demo")
}
