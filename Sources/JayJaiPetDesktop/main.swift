import AppKit

private enum PetMood {
    case idle
    case happy
    case sleepy
    case walking

    var ticksPerFrame: Int {
        switch self {
        case .idle:
            return 5
        case .happy:
            return 2
        case .sleepy:
            return 8
        case .walking:
            return 2
        }
    }

    var drawScale: CGFloat {
        switch self {
        case .idle, .happy:
            return 0.8
        case .sleepy:
            return 0.6
        case .walking:
            return 1
        }
    }
}

private enum PetLayout {
    static let size = NSSize(width: 180, height: 180)
    static let walkStep: CGFloat = 1.5
    static let walkDurationRange = 2.0...4.0
    static let nextWalkDelayRange = 5.0...10.0
}

private final class PetWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct PetSprites {
    let idle: [NSImage]
    let happy: [NSImage]
    let sleepy: [NSImage]
    let walking: [NSImage]

    var hasFrames: Bool {
        !idle.isEmpty && !happy.isEmpty && !sleepy.isEmpty
    }

    static func load() -> PetSprites {
        let assetDirectory = assetDirectory()

        return PetSprites(
            idle: loadFrames(named: "idle", from: assetDirectory),
            happy: loadFrames(named: "happy", from: assetDirectory),
            sleepy: loadFrames(named: "sleepy", from: assetDirectory),
            walking: loadFrames(named: "walk", from: assetDirectory)
        )
    }

    private static func assetDirectory() -> URL {
        if let resourceURL = Bundle.main.resourceURL {
            let bundledAssets = resourceURL
                .appendingPathComponent("Assets")
                .appendingPathComponent("Pet")

            if FileManager.default.fileExists(atPath: bundledAssets.path) {
                return bundledAssets
            }
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets")
            .appendingPathComponent("Pet")
    }

    func frames(for mood: PetMood) -> [NSImage] {
        switch mood {
        case .idle:
            return idle
        case .happy:
            return happy
        case .sleepy:
            return sleepy
        case .walking:
            return walking.isEmpty ? idle : walking
        }
    }

    private static func loadFrames(named state: String, from directory: URL) -> [NSImage] {
        (0..<8).compactMap { index in
            let url = directory.appendingPathComponent(String(format: "%@_%02d.png", state, index))
            return NSImage(contentsOf: url)
        }
    }
}

private final class PetView: NSView {
    private let sprites = PetSprites.load()
    private var mood: PetMood = .idle
    private var frameIndex = 0
    private var tickIndex = 0
    private var lastInteraction = Date()
    private var dragOffset = NSPoint.zero
    private(set) var isDragging = false
    private(set) var isFacingLeft = true
    var canAutoWalk: Bool {
        !isDragging && mood != .happy && mood != .sleepy
    }

    var onResetPosition: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: NSRect(origin: .zero, size: PetLayout.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    func tick() {
        tickIndex += 1
        if tickIndex >= mood.ticksPerFrame {
            tickIndex = 0
            frameIndex += 1
        }

        if Date().timeIntervalSince(lastInteraction) > 30 {
            mood = .sleepy
        } else if mood == .happy && Date().timeIntervalSince(lastInteraction) > 2 {
            mood = .idle
        }

        needsDisplay = true
    }

    func setWalking(direction: CGFloat) {
        guard mood != .happy && mood != .sleepy else {
            return
        }

        mood = .walking
        isFacingLeft = direction < 0
    }

    func stopWalking() {
        guard mood == .walking else {
            return
        }

        mood = .idle
        tickIndex = 0
    }

    override func mouseDown(with event: NSEvent) {
        lastInteraction = Date()
        mood = .happy
        tickIndex = 0

        if let window {
            let pointInWindow = event.locationInWindow
            dragOffset = NSPoint(
                x: pointInWindow.x,
                y: window.frame.height - pointInWindow.y
            )
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else {
            return
        }

        lastInteraction = Date()
        mood = .happy
        tickIndex = 0
        isDragging = true

        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(
            x: mouse.x - dragOffset.x,
            y: mouse.y - (window.frame.height - dragOffset.y)
        )

        let visibleFrame = NSScreen.screens
            .map(\.visibleFrame)
            .reduce(NSScreen.main?.visibleFrame ?? window.frame) { $0.union($1) }
        origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - window.frame.width)
        origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - window.frame.height)

        window.setFrameOrigin(origin)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Reset Position",
                action: #selector(resetPosition),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func resetPosition() {
        onResetPosition?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSGraphicsContext.current?.imageInterpolation = .high

        if drawSpriteFrame() {
            return
        }

        let bounce = CGFloat(sin(Double(frameIndex) * 0.22)) * bounceAmount
        let earWiggle = CGFloat(sin(Double(frameIndex) * 0.32)) * 4
        let blink = frameIndex % 96 > 88 || mood == .sleepy

        let floorY: CGFloat = 34
        let centerX = bounds.midX
        let bodyRect = NSRect(x: centerX - 92, y: floorY + bounce, width: 184, height: 132)
        let headRect = NSRect(x: centerX - 86, y: floorY + 86 + bounce, width: 172, height: 142)

        drawSoftShadow(under: bodyRect)
        drawStickerShape(bodyRect: bodyRect, headRect: headRect, earWiggle: earWiggle)
        drawBody(in: bodyRect)
        drawHead(in: headRect, earWiggle: earWiggle)
        drawFace(in: headRect, blink: blink)

        if mood == .happy {
            drawTongue(in: headRect)
        }

        if mood == .sleepy {
            drawSleepBubble(near: headRect)
        }
    }

    private func drawSpriteFrame() -> Bool {
        guard sprites.hasFrames else {
            return false
        }

        let frames = sprites.frames(for: mood)
        guard let image = frames[safe: frameIndex % frames.count] else {
            return false
        }

        if mood == .walking && isFacingLeft {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: bounds.maxX, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            draw(image, in: spriteRect)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            draw(image, in: spriteRect)
        }

        return true
    }

    private var spriteRect: NSRect {
        let scale = mood.drawScale
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)

        return NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.minY,
            width: size.width,
            height: size.height
        )
    }

    private func draw(_ image: NSImage, in rect: NSRect) {
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    private var bounceAmount: CGFloat {
        switch mood {
        case .idle:
            return 3
        case .happy:
            return 9
        case .sleepy:
            return 1
        case .walking:
            return 2
        }
    }

    private func drawSoftShadow(under bodyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.18).setFill()
        NSBezierPath(ovalIn: NSRect(
            x: bodyRect.minX + 18,
            y: bodyRect.minY - 16,
            width: bodyRect.width - 36,
            height: 26
        )).fill()
    }

    private func drawStickerShape(bodyRect: NSRect, headRect: NSRect, earWiggle: CGFloat) {
        NSColor.white.setFill()

        let outline = NSBezierPath(roundedRect: bodyRect.insetBy(dx: -16, dy: -14), xRadius: 54, yRadius: 54)
        outline.appendOval(in: headRect.insetBy(dx: -14, dy: -14))
        outline.append(earPath(left: true, headRect: headRect, inset: -14, wiggle: earWiggle))
        outline.append(earPath(left: false, headRect: headRect, inset: -14, wiggle: -earWiggle))
        outline.fill()
    }

    private func drawBody(in rect: NSRect) {
        NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 48, yRadius: 48).fill()

        NSColor.black.withAlphaComponent(0.88).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.maxX - 74, y: rect.midY - 10, width: 56, height: 44)).fill()

        drawPaw(at: NSPoint(x: rect.minX + 30, y: rect.minY + 6))
        drawPaw(at: NSPoint(x: rect.maxX - 56, y: rect.minY + 6))
    }

    private func drawPaw(at origin: NSPoint) {
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: origin.x, y: origin.y, width: 42, height: 30), xRadius: 16, yRadius: 16).fill()

        NSColor(calibratedRed: 0.56, green: 0.40, blue: 0.36, alpha: 0.45).setFill()
        for index in 0..<3 {
            NSBezierPath(ovalIn: NSRect(x: origin.x + 9 + CGFloat(index * 9), y: origin.y + 19, width: 6, height: 7)).fill()
        }
    }

    private func drawHead(in rect: NSRect, earWiggle: CGFloat) {
        NSColor.black.setFill()
        earPath(left: true, headRect: rect, inset: 0, wiggle: earWiggle).fill()
        earPath(left: false, headRect: rect, inset: 0, wiggle: -earWiggle).fill()

        NSBezierPath(ovalIn: rect).fill()

        NSColor(calibratedWhite: 0.78, alpha: 0.25).setStroke()
        let forehead = NSBezierPath()
        forehead.lineWidth = 5
        forehead.move(to: NSPoint(x: rect.midX - 18, y: rect.maxY - 38))
        forehead.curve(
            to: NSPoint(x: rect.midX + 24, y: rect.maxY - 40),
            controlPoint1: NSPoint(x: rect.midX - 6, y: rect.maxY - 54),
            controlPoint2: NSPoint(x: rect.midX + 10, y: rect.maxY - 22)
        )
        forehead.stroke()
    }

    private func earPath(left: Bool, headRect: NSRect, inset: CGFloat, wiggle: CGFloat) -> NSBezierPath {
        let direction: CGFloat = left ? -1 : 1
        let baseX = left ? headRect.minX + 30 : headRect.maxX - 30
        let path = NSBezierPath()
        path.move(to: NSPoint(x: baseX, y: headRect.maxY - 28))
        path.curve(
            to: NSPoint(x: baseX + direction * (44 - inset) + wiggle, y: headRect.maxY + 64 - inset),
            controlPoint1: NSPoint(x: baseX + direction * 8, y: headRect.maxY + 14),
            controlPoint2: NSPoint(x: baseX + direction * 18 + wiggle, y: headRect.maxY + 54)
        )
        path.curve(
            to: NSPoint(x: baseX + direction * (72 - inset), y: headRect.maxY - 48),
            controlPoint1: NSPoint(x: baseX + direction * 68 + wiggle, y: headRect.maxY + 52),
            controlPoint2: NSPoint(x: baseX + direction * 76, y: headRect.maxY + 2)
        )
        path.close()
        return path
    }

    private func drawFace(in rect: NSRect, blink: Bool) {
        drawEye(center: NSPoint(x: rect.midX - 38, y: rect.midY + 24), blink: blink)
        drawEye(center: NSPoint(x: rect.midX + 38, y: rect.midY + 24), blink: blink)

        NSColor(calibratedWhite: 0.64, alpha: 1).setFill()
        let muzzle = NSBezierPath(roundedRect: NSRect(x: rect.midX - 48, y: rect.midY - 44, width: 96, height: 58), xRadius: 32, yRadius: 28)
        muzzle.fill()

        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: rect.midX - 21, y: rect.midY - 10, width: 42, height: 28), xRadius: 16, yRadius: 13).fill()

        NSColor.black.withAlphaComponent(0.65).setStroke()
        let mouth = NSBezierPath()
        mouth.lineWidth = 4
        mouth.move(to: NSPoint(x: rect.midX, y: rect.midY - 34))
        mouth.curve(
            to: NSPoint(x: rect.midX - 28, y: rect.midY - 30),
            controlPoint1: NSPoint(x: rect.midX - 8, y: rect.midY - 46),
            controlPoint2: NSPoint(x: rect.midX - 24, y: rect.midY - 44)
        )
        mouth.move(to: NSPoint(x: rect.midX, y: rect.midY - 34))
        mouth.curve(
            to: NSPoint(x: rect.midX + 28, y: rect.midY - 30),
            controlPoint1: NSPoint(x: rect.midX + 8, y: rect.midY - 46),
            controlPoint2: NSPoint(x: rect.midX + 24, y: rect.midY - 44)
        )
        mouth.stroke()
    }

    private func drawEye(center: NSPoint, blink: Bool) {
        if blink {
            NSColor(calibratedWhite: 0.25, alpha: 1).setStroke()
            let path = NSBezierPath()
            path.lineWidth = 5
            path.move(to: NSPoint(x: center.x - 16, y: center.y))
            path.curve(
                to: NSPoint(x: center.x + 16, y: center.y),
                controlPoint1: NSPoint(x: center.x - 8, y: center.y - 6),
                controlPoint2: NSPoint(x: center.x + 8, y: center.y - 6)
            )
            path.stroke()
            return
        }

        NSColor(calibratedRed: 0.08, green: 0.06, blue: 0.05, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)).fill()
        NSColor.white.withAlphaComponent(0.86).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x + 4, y: center.y + 5, width: 9, height: 9)).fill()
    }

    private func drawTongue(in rect: NSRect) {
        NSColor(calibratedRed: 0.86, green: 0.49, blue: 0.58, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: rect.midX - 17, y: rect.midY - 76, width: 34, height: 48), xRadius: 17, yRadius: 18).fill()
    }

    private func drawSleepBubble(near rect: NSRect) {
        NSColor.white.withAlphaComponent(0.86).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.maxX - 14, y: rect.maxY + 12, width: 26, height: 20)).fill()
        NSBezierPath(ovalIn: NSRect(x: rect.maxX + 20, y: rect.maxY + 34, width: 16, height: 13)).fill()
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petWindow: PetWindow?
    private var petView: PetView?
    private var timer: Timer?
    private var statusItem: NSStatusItem?
    private var walkDirection: CGFloat = -1
    private var walkTicksRemaining = 0
    private var nextWalkAt = Date().addingTimeInterval(Double.random(in: PetLayout.nextWalkDelayRange))

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createStatusItem()
        createPetWindow()
        startAnimation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func createPetWindow() {
        let size = PetLayout.size
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 48,
            y: screenFrame.minY + 48
        )

        let window = PetWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false
        window.ignoresMouseEvents = false

        let view = PetView()
        view.onResetPosition = { [weak self] in
            self?.resetPosition()
        }
        window.contentView = view
        window.orderFrontRegardless()

        petWindow = window
        petView = view
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "J"
        item.button?.toolTip = "JayJai Pet"

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Reset Position",
                action: #selector(resetPosition),
                keyEquivalent: "r"
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        item.menu = menu

        statusItem = item
    }

    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            self?.petView?.tick()
            self?.advancePetPosition()
        }
    }

    private func advancePetPosition() {
        guard let window = petWindow, let petView else {
            return
        }

        guard petView.canAutoWalk else {
            walkTicksRemaining = 0
            scheduleNextWalk()
            return
        }

        if walkTicksRemaining <= 0 {
            petView.stopWalking()

            guard Date() >= nextWalkAt else {
                return
            }

            startRandomWalk()
        }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var origin = window.frame.origin
        origin.x += PetLayout.walkStep * walkDirection

        if origin.x <= screenFrame.minX {
            origin.x = screenFrame.minX
            walkDirection = 1
        } else if origin.x >= screenFrame.maxX - window.frame.width {
            origin.x = screenFrame.maxX - window.frame.width
            walkDirection = -1
        }

        petView.setWalking(direction: walkDirection)
        window.setFrameOrigin(origin)
        walkTicksRemaining -= 1

        if walkTicksRemaining <= 0 {
            petView.stopWalking()
            scheduleNextWalk()
        }
    }

    private func startRandomWalk() {
        walkDirection = Bool.random() ? -1 : 1
        walkTicksRemaining = Int(Double.random(in: PetLayout.walkDurationRange) * 12)
    }

    private func scheduleNextWalk() {
        nextWalkAt = Date().addingTimeInterval(Double.random(in: PetLayout.nextWalkDelayRange))
    }

    @objc private func resetPosition() {
        guard let window = petWindow else {
            return
        }

        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.maxX - window.frame.width - 48,
            y: screenFrame.minY + 48
        )
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
    }
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
