import Foundation

public enum UITestConfig {
    public static var isUITesting: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-UITest") || args.contains("-UITest_Mode")
    }

    public static var shouldDisableAnimations: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-DisableAnimations") {
            return true
        }
        guard let value = value(for: "-UITest_DisableAnimations") else {
            return false
        }
        return ["1", "true", "yes"].contains(value.lowercased())
    }

    public static func value(for key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key),
              args.indices.contains(index + 1) else {
            return nil
        }
        return args[index + 1]
    }
}
