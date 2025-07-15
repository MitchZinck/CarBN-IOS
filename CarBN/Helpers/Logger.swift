import os
import Foundation

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

final class Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.carbn"
    private static let osLog = OSLog(subsystem: subsystem, category: "CarBN")
    
    static func debug(_ message: String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(message)"
        os_log(.debug, log: osLog, "%{public}@", logMessage)
        #endif
    }
    
    static func info(_ message: String, file: String = #file, line: Int = #line) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(message)"
        os_log(.info, log: osLog, "%{public}@", logMessage)
    }
    
    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(message)"
        os_log(.error, log: osLog, "%{public}@", logMessage)
    }
    
    static func error(_ message: String, file: String = #file, line: Int = #line) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        let logMessage = "[\(fileName):\(line)] \(message)"
        os_log(.fault, log: osLog, "%{public}@", logMessage)
    }
}
