import Foundation

enum AppEnvironment {
    static var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
