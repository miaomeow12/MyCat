import Foundation

/// Event-driven visual cadence. No key codes or text are accepted or retained.
struct InputMotion {
    static let liftDuration = 0.14
    static let strokeDuration = 0.30
    private(set) var keyAge = Double.infinity
    private(set) var strokeAge = Double.infinity
    private(set) var queued = 0
    private(set) var left = true
    private var nextLeft = true
    private var heldMouseButtons = Set<Int>()
    private(set) var clickAge = Double.infinity
    var hasStroke: Bool { strokeAge < Self.strokeDuration }
    var isTyping: Bool { hasStroke || keyAge < 0.85 }
    var frame: Int { hasStroke && strokeAge < Self.liftDuration ? (left ? 1 : 2) : 0 }
    var activeKey: Int { hasStroke ? (left ? 2 : 7) : -1 }
    var isMouseHeld: Bool { !heldMouseButtons.isEmpty }
    var clickFeedback: Double { isMouseHeld ? 1 : max(0, 1 - clickAge / 0.35) }
    mutating func keyDown() {
        keyAge = 0
        if hasStroke { queued = min(queued + 1, 2) }
        else { startStroke() }
    }
    private mutating func startStroke(carry: Double = 0) {
        left = nextLeft
        nextLeft.toggle()
        strokeAge = carry
    }
    mutating func mouseButton(_ button: Int, down: Bool) {
        if down { heldMouseButtons.insert(button); clickAge = 0 }
        else { heldMouseButtons.remove(button) }
    }
    mutating func tick(_ seconds: Double) {
        let dt = max(0, seconds)
        keyAge += dt
        clickAge += dt
        if keyAge > 0.45 { queued = 0 } // Never replay a long queue after the user stops.
        if hasStroke {
            strokeAge += dt
            if strokeAge >= Self.strokeDuration, queued > 0 {
                queued -= 1
                startStroke(carry: strokeAge - Self.strokeDuration)
            }
        }
    }
}
