import AppKit
import Darwin

/// Flou de ce qui se trouve derrière une fenêtre transparente, sans capture d'écran.
///
/// API privée de WindowServer (celle qu'utilise iTerm2), chargée dynamiquement :
/// si elle disparaît un jour, la sécheresse reste simplement sans flou.
enum WindowBlur {
    private typealias ConnectionFunction = @convention(c) () -> Int32
    private typealias BlurFunction = @convention(c) (Int32, Int32, Int32) -> Int32

    private static let connection: ConnectionFunction? = symbol(named: "CGSMainConnectionID")
    private static let setRadius: BlurFunction? = symbol(named: "CGSSetWindowBackgroundBlurRadius")

    static var isAvailable: Bool { connection != nil && setRadius != nil }

    @discardableResult
    static func apply(radius: Int, to window: NSWindow) -> Bool {
        guard let connection, let setRadius, window.windowNumber > 0 else { return false }
        return setRadius(connection(), Int32(window.windowNumber), Int32(radius)) == 0
    }

    private static func symbol<Function>(named name: String) -> Function? {
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let pointer = dlsym(defaultHandle, name) else { return nil }
        return unsafeBitCast(pointer, to: Function.self)
    }
}
