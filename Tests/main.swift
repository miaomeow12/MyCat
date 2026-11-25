import Foundation
var model = InputMotion()
model.keyDown()
model.tick(0.25)
precondition(model.hasStroke && model.activeKey >= 0, "Single input must be readable after 250ms")
model.tick(1)
precondition(!model.isTyping, "No autonomous typing after stopping")
model = InputMotion()
var covered = 0
var poses = Set<Int>()
var previous = -1
var changedAt = 0.0
var shortest = Double.infinity
for tick in 0..<1800 {
    if tick % 6 == 0 { model.keyDown() }
    model.tick(1 / 60)
    if model.isTyping { covered += 1 }
    poses.insert(model.frame)
    precondition(model.queued <= 2)
    if model.frame != previous {
        let now = Double(tick) / 60
        if previous >= 0 { shortest = min(shortest, now - changedAt) }
        changedAt = now
        previous = model.frame
    }
}
precondition(covered == 1800 && poses == Set([0, 1, 2]))
precondition(shortest >= 0.11, "Never flicker a pose for only one frame")
model.tick(1.5)
precondition(!model.isTyping && model.activeKey == -1)
model.mouseButton(0, down: true)
model.tick(2)
precondition(model.isMouseHeld && model.clickFeedback == 1)
model.mouseButton(1, down: true)
model.mouseButton(0, down: false)
precondition(model.isMouseHeld, "Releasing one button must not release another held button")
model.mouseButton(1, down: false)
model.tick(0.5)
precondition(!model.isMouseHeld && model.clickFeedback == 0)
// Frame-rate independence: key poses have the same wall-clock durations.
for rate in [24, 30, 60, 120] {
    var sample = InputMotion()
    sample.keyDown()
    for _ in 0..<Int(Double(rate) * 0.25) { sample.tick(1 / Double(rate)) }
    precondition(sample.hasStroke)
    sample.tick(1)
    precondition(!sample.isTyping)
}
print("PASS: deterministic 30s/300-key replay, readable >=133ms poses, no idle gaps, bounded queue, stop recovery, held/multiple mouse buttons, 24–120Hz timing")
