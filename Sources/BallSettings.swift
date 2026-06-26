import AppKit

final class BallSettings {
    static let shared = BallSettings()
    private init() {}

    private let ud = UserDefaults.standard
    static let changed = Notification.Name("BallSettingsChanged")

    private func post() {
        NotificationCenter.default.post(name: Self.changed, object: nil)
    }

    // MARK: - Visual

    var ballRadius: CGFloat {
        get { ud.optDouble("ballRadius").map { CGFloat($0) } ?? 28 }
        set { ud.set(Double(newValue), forKey: "ballRadius"); post() }
    }

    var ballColor: NSColor {
        get { ud.archivedColor("ballColor") ?? NSColor(red: 0.28, green: 0.55, blue: 0.98, alpha: 1) }
        set { ud.archiveColor(newValue, key: "ballColor"); post() }
    }

    var ropeColor: NSColor {
        get { ud.archivedColor("ropeColor") ?? NSColor(white: 0.80, alpha: 0.92) }
        set { ud.archiveColor(newValue, key: "ropeColor"); post() }
    }

    var ropeThickness: CGFloat {
        get { ud.optDouble("ropeThickness").map { CGFloat($0) } ?? 2.5 }
        set { ud.set(Double(newValue), forKey: "ropeThickness"); post() }
    }

    // MARK: - Physics

    var gravity: CGFloat {
        get { ud.optDouble("gravity").map { CGFloat($0) } ?? 700 }
        set { ud.set(Double(newValue), forKey: "gravity"); post() }
    }

    var damping: CGFloat {
        get { ud.optDouble("damping").map { CGFloat($0) } ?? 0.9994 }
        set { ud.set(Double(newValue), forKey: "damping"); post() }
    }

    var bounceE: CGFloat {
        get { ud.optDouble("bounceE").map { CGFloat($0) } ?? 0.65 }
        set { ud.set(Double(newValue), forKey: "bounceE"); post() }
    }

    var floorFric: CGFloat {
        get { ud.optDouble("floorFric").map { CGFloat($0) } ?? 0.80 }
        set { ud.set(Double(newValue), forKey: "floorFric"); post() }
    }

    var ropeLength: CGFloat {
        get { ud.optDouble("ropeLength").map { CGFloat($0) } ?? 220 }
        set { ud.set(Double(newValue), forKey: "ropeLength"); post() }
    }

    var ropeElasticity: CGFloat {
        get { ud.optDouble("ropeElasticity").map { CGFloat($0) } ?? 0.35 }
        set { ud.set(Double(newValue), forKey: "ropeElasticity"); post() }
    }

    var breakSpeed: CGFloat {
        get { ud.optDouble("breakSpeed").map { CGFloat($0) } ?? 4000 }
        set { ud.set(Double(newValue), forKey: "breakSpeed"); post() }
    }

    var breakRatio: CGFloat {
        get { ud.optDouble("breakRatio").map { CGFloat($0) } ?? 3.0 }
        set { ud.set(Double(newValue), forKey: "breakRatio"); post() }
    }

    var segCount: Int {
        get { ud.object(forKey: "segCount") == nil ? 16 : ud.integer(forKey: "segCount") }
        set { ud.set(newValue, forKey: "segCount"); post() }
    }

    // MARK: - Shortcuts

    var showKeyCode: Int {
        get { ud.object(forKey: "showKeyCode") == nil ? -1 : ud.integer(forKey: "showKeyCode") }
        set { ud.set(newValue, forKey: "showKeyCode"); post() }
    }
    var showModifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: UInt(ud.integer(forKey: "showModifiers"))) }
        set { ud.set(Int(newValue.rawValue), forKey: "showModifiers"); post() }
    }
    var showLabel: String {
        get { ud.string(forKey: "showLabel") ?? "" }
        set { ud.set(newValue, forKey: "showLabel"); post() }
    }

    var resetKeyCode: Int {
        get { ud.object(forKey: "resetKeyCode") == nil ? -1 : ud.integer(forKey: "resetKeyCode") }
        set { ud.set(newValue, forKey: "resetKeyCode"); post() }
    }
    var resetModifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: UInt(ud.integer(forKey: "resetModifiers"))) }
        set { ud.set(Int(newValue.rawValue), forKey: "resetModifiers"); post() }
    }
    var resetLabel: String {
        get { ud.string(forKey: "resetLabel") ?? "" }
        set { ud.set(newValue, forKey: "resetLabel"); post() }
    }

    // MARK: - Reset

    func reset() {
        ["ballRadius", "ballColor", "ropeColor", "ropeThickness",
         "gravity", "damping", "bounceE", "floorFric", "ropeLength", "ropeElasticity", "breakSpeed", "breakRatio", "segCount",
         "showKeyCode", "showModifiers", "showLabel",
         "resetKeyCode", "resetModifiers", "resetLabel"]
            .forEach { ud.removeObject(forKey: $0) }
        post()
    }
}

// MARK: - UserDefaults helpers

private extension UserDefaults {
    func optDouble(_ key: String) -> Double? {
        object(forKey: key) == nil ? nil : double(forKey: key)
    }

    func archivedColor(_ key: String) -> NSColor? {
        guard let data = data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    }

    func archiveColor(_ color: NSColor, key: String) {
        let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
        set(data, forKey: key)
    }
}
