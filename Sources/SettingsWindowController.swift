import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared = SettingsWindowController()
    private var retained: [AnyObject] = []

    private init() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 510),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "FidgetBall Settings"
        w.isReleasedWhenClosed = false
        super.init(window: w)
        w.delegate = self
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        buildUI()
        NSApp.setActivationPolicy(.regular)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSColorPanel.shared.close()
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Build

    private func buildUI() {
        retained.removeAll()
        let s = BallSettings.shared

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        let doc = NSView()
        scroll.documentView = doc

        var allRows: [(view: NSView, topGap: CGFloat)] = []

        allRows.append((header("VISUAL"), 20))
        allRows.append((sliderRow("Ball Size",    min: 10, max: 64,    value: Double(s.ballRadius),    format: "%.0f px") { BallSettings.shared.ballRadius    = CGFloat($0) }, 6))
        allRows.append((colorRow( "Ball Color",   color: s.ballColor)                                                    { BallSettings.shared.ballColor     = $0         }, 4))
        allRows.append((colorRow( "Rope Color",   color: s.ropeColor)                                                    { BallSettings.shared.ropeColor     = $0         }, 4))
        allRows.append((sliderRow("Rope Width",   min: 0.5, max: 8,   value: Double(s.ropeThickness), format: "%.1f")    { BallSettings.shared.ropeThickness = CGFloat($0) }, 4))
        allRows.append((header("PHYSICS"), 18))
        allRows.append((sliderRow("Gravity",      min: 100, max: 2000, value: Double(s.gravity),      format: "%.0f")    { BallSettings.shared.gravity       = CGFloat($0) }, 6))
        allRows.append((sliderRow("Damping",      min: 0.990, max: 0.9999, value: Double(s.damping),  format: "%.4f")    { BallSettings.shared.damping       = CGFloat($0) }, 4))
        allRows.append((sliderRow("Bounce",       min: 0.05, max: 1.0, value: Double(s.bounceE),      format: "%.2f")    { BallSettings.shared.bounceE       = CGFloat($0) }, 4))
        allRows.append((sliderRow("Floor Friction",min: 0.1, max: 1.0, value: Double(s.floorFric),    format: "%.2f")    { BallSettings.shared.floorFric     = CGFloat($0) }, 4))
        allRows.append((sliderRow("Rope Length",  min: 60, max: 500,  value: Double(s.ropeLength),    format: "%.0f px") { BallSettings.shared.ropeLength    = CGFloat($0) }, 4))
        allRows.append((sliderRow("Segments",     min: 4,  max: 32,   value: Double(s.segCount), integer: true, format: "%.0f") { BallSettings.shared.segCount = Int($0) }, 4))

        allRows.append((header("SHORTCUTS"), 18))
        allRows.append((shortcutRow("Show / Hide",
                                    currentLabel: s.showLabel,
                                    onSave: { BallSettings.shared.showKeyCode = $0; BallSettings.shared.showModifiers = $1; BallSettings.shared.showLabel = $2; HotkeyManager.shared.update() },
                                    onClear: { BallSettings.shared.showKeyCode = -1; BallSettings.shared.showLabel = ""; HotkeyManager.shared.update() }), 6))

        let btn = NSButton(title: "Reset to Defaults", target: self, action: #selector(reset))
        btn.bezelStyle = .rounded
        allRows.append((btn, 22))

        // Layout all rows in doc view with explicit constraints
        var prevBottom = doc.topAnchor
        for (row, gap) in allRows {
            doc.addSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: prevBottom, constant: gap),
                row.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 24),
                row.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -24),
            ])
            prevBottom = row.bottomAnchor
        }
        allRows.last?.view.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -24).isActive = true

        // Pin doc width to scroll clip view
        doc.translatesAutoresizingMaskIntoConstraints = false
        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            doc.topAnchor.constraint(equalTo: clip.topAnchor),
        ])

        window?.contentView = scroll
    }

    @objc private func reset() {
        BallSettings.shared.reset()
        buildUI()
    }

    // MARK: - Row factories

    private func header(_ text: String) -> NSView {
        let tf = NSTextField(labelWithString: text)
        tf.font = .systemFont(ofSize: 10, weight: .semibold)
        tf.textColor = .secondaryLabelColor
        tf.translatesAutoresizingMaskIntoConstraints = false
        let wrap = NSView()
        wrap.addSubview(tf)
        wrap.heightAnchor.constraint(equalToConstant: 20).isActive = true
        NSLayoutConstraint.activate([
            tf.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            tf.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
        ])
        return wrap
    }

    private func sliderRow(_ label: String,
                            min: Double, max: Double, value: Double,
                            integer: Bool = false, format: String,
                            onChange: @escaping (Double) -> Void) -> NSView {
        let row = NSView()
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)

        let valLbl = NSTextField(labelWithString: String(format: format, value))
        valLbl.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        valLbl.alignment = .right

        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: nil, action: nil)
        slider.controlSize = .small

        let t = SliderTarget(valLbl: valLbl, format: format, integer: integer, onChange: onChange)
        slider.target = t
        slider.action = #selector(SliderTarget.changed(_:))
        retained.append(t)

        for v in [lbl, valLbl, slider] {
            row.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
            v.centerYAnchor.constraint(equalTo: row.centerYAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.widthAnchor.constraint(equalToConstant: 110),
            valLbl.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valLbl.widthAnchor.constraint(equalToConstant: 68),
            slider.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: valLbl.leadingAnchor, constant: -8),
        ])
        return row
    }

    private func colorRow(_ label: String, color: NSColor,
                           onChange: @escaping (NSColor) -> Void) -> NSView {
        let row = NSView()
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)

        let well = NSColorWell(style: .minimal)
        well.color = color
        well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        well.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let t = ColorTarget(onChange: onChange)
        well.target = t
        well.action = #selector(ColorTarget.changed(_:))
        retained.append(t)

        for v in [lbl, well] as [NSView] {
            row.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
            v.centerYAnchor.constraint(equalTo: row.centerYAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.widthAnchor.constraint(equalToConstant: 110),
            well.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
        ])
        return row
    }

    private func shortcutRow(_ label: String, currentLabel: String,
                              onSave: @escaping (Int, NSEvent.ModifierFlags, String) -> Void,
                              onClear: @escaping () -> Void) -> NSView {
        let row = NSView()
        row.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let lbl = NSTextField(labelWithString: label)
        lbl.font = .systemFont(ofSize: 13)

        let recorder = ShortcutRecorder(currentLabel: currentLabel)
        recorder.onSave = onSave
        recorder.onClear = onClear
        retained.append(recorder)

        for v in [lbl, recorder.displayField, recorder.recordBtn, recorder.clearBtn] as [NSView] {
            row.addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
            v.centerYAnchor.constraint(equalTo: row.centerYAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.widthAnchor.constraint(equalToConstant: 110),
            recorder.displayField.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            recorder.displayField.widthAnchor.constraint(equalToConstant: 80),
            recorder.recordBtn.leadingAnchor.constraint(equalTo: recorder.displayField.trailingAnchor, constant: 8),
            recorder.clearBtn.leadingAnchor.constraint(equalTo: recorder.recordBtn.trailingAnchor, constant: 6),
        ])
        return row
    }
}

// MARK: - Action targets

private class SliderTarget: NSObject {
    let valLbl: NSTextField
    let format: String
    let integer: Bool
    let onChange: (Double) -> Void

    init(valLbl: NSTextField, format: String, integer: Bool, onChange: @escaping (Double) -> Void) {
        self.valLbl = valLbl; self.format = format; self.integer = integer; self.onChange = onChange
    }

    @objc func changed(_ sender: NSSlider) {
        let v = integer ? Double(Int(sender.doubleValue.rounded())) : sender.doubleValue
        valLbl.stringValue = String(format: format, v)
        onChange(v)
    }
}

private class ColorTarget: NSObject {
    let onChange: (NSColor) -> Void
    init(onChange: @escaping (NSColor) -> Void) { self.onChange = onChange }
    @objc func changed(_ sender: NSColorWell) { onChange(sender.color) }
}

private class ShortcutRecorder: NSObject {
    let displayField: NSTextField
    let recordBtn: NSButton
    let clearBtn: NSButton

    var onSave: ((Int, NSEvent.ModifierFlags, String) -> Void)?
    var onClear: (() -> Void)?

    private var savedLabel: String
    private var monitor: Any?

    init(currentLabel: String) {
        savedLabel = currentLabel
        displayField = NSTextField(labelWithString: currentLabel.isEmpty ? "–" : currentLabel)
        displayField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        displayField.alignment = .center

        recordBtn = NSButton(title: "Record", target: nil, action: nil)
        recordBtn.bezelStyle = .rounded
        recordBtn.controlSize = .small

        clearBtn = NSButton(title: "Clear", target: nil, action: nil)
        clearBtn.bezelStyle = .rounded
        clearBtn.controlSize = .small
        clearBtn.isHidden = currentLabel.isEmpty

        super.init()
        recordBtn.target = self; recordBtn.action = #selector(recordClicked)
        clearBtn.target  = self; clearBtn.action  = #selector(clearClicked)
    }

    deinit { if let m = monitor { NSEvent.removeMonitor(m) } }

    @objc private func recordClicked() {
        monitor != nil ? cancelRecording() : startRecording()
    }

    @objc private func clearClicked() {
        cancelRecording()
        savedLabel = ""
        displayField.stringValue = "–"
        clearBtn.isHidden = true
        onClear?()
    }

    private func startRecording() {
        displayField.stringValue = "Press shortcut…"
        recordBtn.title = "Cancel"
        clearBtn.isHidden = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            if event.keyCode == 53 { self.cancelRecording(); return nil }
            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !mods.isEmpty else { return event }
            let lbl = self.makeLabel(mods: mods, keyCode: event.keyCode,
                                     chars: event.charactersIgnoringModifiers ?? "")
            self.finishRecording(label: lbl)
            self.onSave?(Int(event.keyCode), mods, lbl)
            return nil
        }
    }

    private func cancelRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        displayField.stringValue = savedLabel.isEmpty ? "–" : savedLabel
        recordBtn.title = "Record"
        clearBtn.isHidden = savedLabel.isEmpty
    }

    private func finishRecording(label: String) {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        savedLabel = label
        displayField.stringValue = label
        recordBtn.title = "Record"
        clearBtn.isHidden = false
    }

    private func makeLabel(mods: NSEvent.ModifierFlags, keyCode: UInt16, chars: String) -> String {
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        let special: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        s += special[keyCode] ?? chars.uppercased()
        return s
    }
}
