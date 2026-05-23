import Foundation

enum RuntimeEnvironment {
    nonisolated static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    nonisolated static var isUnitTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil && !isUITesting
    }

    nonisolated static var isAnyTesting: Bool {
        isUITesting || isUnitTesting
    }
}
