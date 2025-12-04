import Foundation
import OSLog

/// Centralized logging utility using OSLog for structured logging
enum AppLogger {

    // MARK: - Logger Instances

    /// Logger for video recording operations
    static let video = Logger(subsystem: subsystem, category: "video")

    /// Logger for network/API operations
    static let network = Logger(subsystem: subsystem, category: "network")

    /// Logger for AI/Gemini operations
    static let ai = Logger(subsystem: subsystem, category: "ai")

    /// Logger for data/storage operations
    static let data = Logger(subsystem: subsystem, category: "data")

    /// Logger for UI/view operations
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Logger for general app operations
    static let general = Logger(subsystem: subsystem, category: "general")

    // MARK: - Configuration

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tenniscoach"

    // MARK: - Convenience Methods

    /// Log a debug message
    static func debug(_ message: String, category: Logger = general) {
        category.debug("\(message)")
    }

    /// Log an info message
    static func info(_ message: String, category: Logger = general) {
        category.info("\(message)")
    }

    /// Log a warning message
    static func warning(_ message: String, category: Logger = general) {
        category.warning("\(message)")
    }

    /// Log an error message
    static func error(_ message: String, category: Logger = general) {
        category.error("\(message)")
    }

    /// Log an error with the error object
    static func error(_ message: String, error: Error, category: Logger = general) {
        category.error("\(message): \(error.localizedDescription)")
    }

    /// Log a critical/fault message
    static func critical(_ message: String, category: Logger = general) {
        category.critical("\(message)")
    }

    // MARK: - Specialized Logging

    /// Log network request
    static func logRequest(url: URL, method: String) {
        network.debug("[\(method)] \(url.absoluteString)")
    }

    /// Log network response
    static func logResponse(url: URL, statusCode: Int, duration: TimeInterval) {
        let durationMs = Int(duration * 1000)
        if (200...299).contains(statusCode) {
            network.info("[\(statusCode)] \(url.absoluteString) (\(durationMs)ms)")
        } else {
            network.error("[\(statusCode)] \(url.absoluteString) (\(durationMs)ms)")
        }
    }

    /// Log video operation
    static func logVideoOperation(_ operation: String, url: URL? = nil, duration: TimeInterval? = nil) {
        var message = operation
        if let url = url {
            message += " - \(url.lastPathComponent)"
        }
        if let duration = duration {
            message += " (\(String(format: "%.1f", duration))s)"
        }
        video.info("\(message)")
    }

    /// Log AI analysis
    static func logAIOperation(_ operation: String, tokens: Int? = nil) {
        var message = operation
        if let tokens = tokens {
            message += " (\(tokens) tokens)"
        }
        ai.info("\(message)")
    }

    /// Log data operation
    static func logDataOperation(_ operation: String, recordCount: Int? = nil) {
        var message = operation
        if let count = recordCount {
            message += " (\(count) records)"
        }
        data.info("\(message)")
    }

    // MARK: - Performance Logging

    /// Measure and log execution time of an async operation
    static func measureAsync<T>(
        _ operation: String,
        category: Logger = general,
        block: () async throws -> T
    ) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        category.info("\(operation) completed in \(String(format: "%.2f", duration * 1000))ms")
        return result
    }

    /// Measure and log execution time of a synchronous operation
    static func measure<T>(
        _ operation: String,
        category: Logger = general,
        block: () throws -> T
    ) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        category.info("\(operation) completed in \(String(format: "%.2f", duration * 1000))ms")
        return result
    }
}

// MARK: - Debug Extensions

#if DEBUG
extension AppLogger {
    /// Print to console in debug builds (in addition to OSLog)
    static func debugPrint(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("[\(fileName):\(line)] \(function) - \(message)")
    }
}
#endif
