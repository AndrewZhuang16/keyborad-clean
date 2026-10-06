import AppKit
import ApplicationServices
import CoreGraphics

/// Manages the global keyboard-suppression event tap.
///
/// When enabled, an active `CGEvent` tap is installed at the head of the
/// session event stream. Every keyboard event (`keyDown`, `keyUp`,
/// `flagsChanged`) is dropped except for the emergency restore shortcut, which
/// makes the keyboard effectively dead system-wide while the mouse keeps
/// working. Disabling (or the app quitting / crashing) tears the tap down, so
/// the keyboard is always restored automatically.
final class KeyboardCleaner: ObservableObject {

    static let shared = KeyboardCleaner()

    static let restoreShortcut = "⌃⌥⌘ Esc"

    /// True while the keyboard is being suppressed.
    @Published private(set) var isEnabled = false

    /// True when the app holds the "Accessibility" permission required for an
    /// active event tap.
    @Published private(set) var isTrusted = false

    /// Human-readable error surfaced when suppression cannot be installed even
    /// though the process is trusted.
    @Published var lastError: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Whether the process is trusted for Accessibility.
    var trusted: Bool { AXIsProcessTrusted() }

    /// The app's bundle identifier, used to help users verify which app to
    /// enable in System Settings.
    var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "未知" }

    /// Re-read the Accessibility permission. Also restores the keyboard if the
    /// permission was revoked while suppression was active.
    func refreshTrust() {
        let value = AXIsProcessTrusted()
        if value != isTrusted {
            isTrusted = value
            if value { lastError = nil }
        }
        if !value && isEnabled {
            disable()
        }
    }

    /// Show the system "would like to control this computer" prompt.
    func requestPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshTrust()
    }

    /// Open System Settings directly on the Accessibility pane.
    func openAccessibilitySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.privacy?Privacy_Accessibility",
        ]
        for raw in candidates {
            if let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
                return
            }
        }
    }

    /// Launch a fresh instance and quit this one. macOS often only picks up a
    /// newly granted Accessibility permission after the process restarts.
    func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    /// Install the suppression tap. Returns false (and prompts for permission)
    /// when Accessibility is not yet granted.
    @discardableResult
    func enable() -> Bool {
        guard AXIsProcessTrusted() else {
            requestPermission()
            return false
        }
        guard eventTap == nil else {
            isEnabled = true
            return true
        }

        // 拦截三类事件：
        // 1) keyDown / keyUp —— 普通字母、数字、以及按住 Fn 后的 F1-F12；
        // 2) flagsChanged —— 修饰键（Shift/Ctrl/Option/Cmd/CapsLock 等）；
        // 3) NX_SYSDEFINED (14) —— 系统定义按键：F1-F12 默认的亮度/音量/媒体/
        //    调度中心等特殊功能，以及电源/睡眠/锁屏等系统键。
        let systemDefinedRaw: UInt32 = 14 // NX_SYSDEFINED
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << systemDefinedRaw)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return nil }
                let cleaner = Unmanaged<KeyboardCleaner>.fromOpaque(userInfo).takeUnretainedValue()

                // Fail open if macOS disables the tap, keeping the UI in sync.
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    cleaner.disable()
                    return Unmanaged.passUnretained(event)
                }

                // Read the physical modifiers before their events are suppressed.
                let modifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand, .maskShift]
                let required: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
                if type == .keyDown,
                   event.getIntegerValueField(.keyboardEventKeycode) == 53,
                   event.flags.intersection(modifiers) == required {
                    cleaner.disable()
                }
                // Consume the restore key as well so Esc does not reach other apps.
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "已获得辅助功能权限，但创建键盘拦截失败，请重试或重启应用。"
            return false
        }

        eventTap = tap
        if let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = source
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true
        lastError = nil
        return true
    }

    /// Remove the suppression tap and restore the keyboard.
    func disable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
        isEnabled = false
        lastError = nil
    }

    /// Convenience used by the UI toggle.
    func toggle(_ on: Bool) {
        if on {
            _ = enable()
        } else {
            disable()
        }
    }
}
