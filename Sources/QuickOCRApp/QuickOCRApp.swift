import AppKit
import QuickOCR

@main
struct QuickOCRApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
