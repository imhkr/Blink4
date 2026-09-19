import Cocoa

let intervalChoices: [Double] = [4, 5, 10, 20, 60]
let defaultInterval: Double = 4

let idleAlpha: CGFloat = 0.16
let blinkAlpha: CGFloat = 0.92
let hoverAlpha: CGFloat = 1.0

let fadeIn = 0.12
let lidTime = 0.28
let fadeOut = 0.65

let eyeW: CGFloat = 26, eyeH: CGFloat = 15

final class BlinkView: NSView {
    var interval = defaultInterval
    var paused = false {
        didSet {
            paused ? countdown?.invalidate() : schedule()
            eye.path = eyePath(lid: paused ? 1 : 0)
            irisMask.path = eye.path
        }
    }

    private let plate = CALayer()
    private let eye = CAShapeLayer()
    private let iris = CAShapeLayer()
    private let irisMask = CAShapeLayer()
    private var countdown: Timer?
    private var hovering = false
    private var blinking = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(plate)
        plate.cornerRadius = 11
        plate.opacity = Float(idleAlpha)
        plate.addSublayer(eye)
        plate.addSublayer(iris)
        iris.mask = irisMask
        eye.fillColor = nil
        eye.lineWidth = 1.8
        eye.lineJoin = .round
        applyColors()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        plate.frame = bounds
        eye.frame = bounds
        iris.frame = bounds
        eye.path = eyePath(lid: paused ? 1 : 0)
        irisMask.frame = bounds
        irisMask.path = eye.path
        let r = eyeH / 2 * 0.6
        iris.path = CGPath(ellipseIn: CGRect(x: bounds.midX - r, y: bounds.midY - r,
                                             width: r * 2, height: r * 2), transform: nil)
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() { applyColors() }

    private func applyColors() {
        NSAppearance.currentDrawing().performAsCurrentDrawingAppearance {
            plate.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
            eye.strokeColor = NSColor.labelColor.cgColor
            iris.fillColor = NSColor.labelColor.cgColor
        }
    }

    private func eyePath(lid: CGFloat) -> CGPath {
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let hh = eyeH / 2 * max(0.04, 1 - lid)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x - eyeW / 2, y: c.y))
        p.addCurve(to: CGPoint(x: c.x + eyeW / 2, y: c.y),
                   control1: CGPoint(x: c.x - eyeW / 4, y: c.y + hh * 2),
                   control2: CGPoint(x: c.x + eyeW / 4, y: c.y + hh * 2))
        p.addCurve(to: CGPoint(x: c.x - eyeW / 2, y: c.y),
                   control1: CGPoint(x: c.x + eyeW / 4, y: c.y - hh * 2),
                   control2: CGPoint(x: c.x - eyeW / 4, y: c.y - hh * 2))
        return p
    }

    func start() { schedule() }

    private func schedule() {
        countdown?.invalidate()
        guard !paused else { return }
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in self?.blink() }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        countdown = t
    }

    private func blink() {
        schedule()
        blinking = true

        let up = max(blinkAlpha, hovering ? hoverAlpha : 0)
        fade(to: up, duration: fadeIn)

        let lid = CABasicAnimation(keyPath: "path")
        lid.fromValue = eyePath(lid: 0)
        lid.toValue = eyePath(lid: 1)
        lid.duration = lidTime / 2
        lid.autoreverses = true
        lid.beginTime = CACurrentMediaTime() + fadeIn
        lid.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        eye.add(lid, forKey: "lid")

        irisMask.add(lid, forKey: "lid")

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeIn + lidTime) { [weak self] in
            guard let self else { return }
            self.blinking = false
            self.fade(to: self.hovering ? hoverAlpha : idleAlpha, duration: fadeOut)
        }
    }

    private func fade(to a: CGFloat, duration: Double) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        plate.opacity = Float(a)
        CATransaction.commit()
    }

    func watchHover() {
        let h: (NSEvent) -> Void = { [weak self] _ in self?.updateHover() }
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: h)
        NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { e in h(e); return e }
    }

    private func updateHover() {
        guard let f = window?.frame else { return }
        let inside = f.insetBy(dx: -6, dy: -6).contains(NSEvent.mouseLocation)
        guard inside != hovering else { return }
        hovering = inside
        guard !blinking else { return }
        fade(to: inside ? hoverAlpha : idleAlpha, duration: 0.18)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { paused.toggle(); return }
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        for s in intervalChoices {
            let item = NSMenuItem(title: "Every \(Int(s))s" + (s == defaultInterval ? "  (natural blink rate)" : ""),
                                  action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = s
            item.state = (abs(s - interval) < 0.01) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let pauseItem = NSMenuItem(title: paused ? "Resume" : "Pause",
                                   action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(NSMenuItem(title: "Quit Blink4", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func pick(_ sender: NSMenuItem) {
        interval = sender.representedObject as? Double ?? defaultInterval
        UserDefaults.standard.set(interval, forKey: "interval")
        schedule()
    }

    @objc private func togglePause() { paused.toggle() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let frame = NSRect(x: 0, y: 0, width: 44, height: 34)
        panel = NSPanel(contentRect: frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true

        let view = BlinkView(frame: frame)
        view.autoresizingMask = [.width, .height]
        let saved = UserDefaults.standard.double(forKey: "interval")
        view.interval = saved > 0 ? saved : defaultInterval

        panel.contentView = view
        panel.setFrameAutosaveName("Blink4Pop")
        panel.setContentSize(frame.size)
        if panel.frame.origin == .zero, let s = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: s.visibleFrame.maxX - 72, y: s.visibleFrame.maxY - 58))
        }
        clampOnScreen()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.clampOnScreen()
        }
        panel.orderFrontRegardless()
        view.start()
        view.watchHover()
    }

    private func clampOnScreen() {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ?? NSScreen.main
        guard let v = screen?.visibleFrame else { return }
        var f = panel.frame
        f.origin.x = min(max(f.minX, v.minX), v.maxX - f.width)
        f.origin.y = min(max(f.minY, v.minY), v.maxY - f.height)
        if f != panel.frame { panel.setFrame(f, display: true) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
