import Foundation
import OSLog

@MainActor
class AppLogger {
    static let shared = AppLogger()
    
    private let logger = Logger(subsystem: "com.vaizor.app", category: "general")
    private let performanceLogger = Logger(subsystem: "com.vaizor.app", category: "performance")
    private let errorLogger = Logger(subsystem: "com.vaizor.app", category: "error")
    
    private init() {
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] \(message)\n"
        
        // Console logging
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            errorLogger.error("\(message)")
        case .critical:
            errorLogger.critical("\(message)")
        }
        
        _ = logMessage
    }
    
    func logError(_ error: Error, context: String = "") {
        let message = context.isEmpty ? "\(error.localizedDescription)" : "\(context): \(error.localizedDescription)"
        log(message, level: .error)
        
        let nsError = error as NSError
        log("Error domain: \(nsError.domain), code: \(nsError.code)", level: .error)
    }
    
    func measurePerformance<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(startTime)
        
        let message = "\(operation) took \(String(format: "%.3f", duration))s"
        performanceLogger.info("\(message)")
        log(message, level: .info)
        
        if duration > 1.0 {
            log("⚠️ Slow operation detected: \(operation) took \(String(format: "%.3f", duration))s", level: .warning)
        }
        
        return result
    }
    
    func measurePerformanceAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(startTime)
        
        let message = "\(operation) took \(String(format: "%.3f", duration))s"
        performanceLogger.info("\(message)")
        log(message, level: .info)
        
        if duration > 1.0 {
            log("⚠️ Slow operation detected: \(operation) took \(String(format: "%.3f", duration))s", level: .warning)
        }
        
        return result
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}
