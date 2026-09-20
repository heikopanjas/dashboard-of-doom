import Foundation
import Synchronization

/// A simple and fast logging facility with support for different log levels and detailed timestamps.
public final class Trace: Sendable {
    /// Represents different log levels
    public enum Level: String, Sendable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"

        /// ANSI color codes for terminal output
        var colorCode: String {
            switch self {
                case .debug: return "\u{001B}[37m"  // Light gray
                case .info: return "\u{001B}[32m"  // Green
                case .warning: return "\u{001B}[33m"  // Yellow
                case .error: return "\u{001B}[31m"  // Red
            }
        }
    }

    /// Minimum log level to display
    private let minimumLevel: Level

    /// Whether to show colors in console output
    private let showColors: Bool

    private struct OutputState {
        let dateFormatter: DateFormatter
        var fileHandle: FileHandle?
    }

    private let output: Mutex<OutputState>

    /// Creates a new Logger instance
    /// - Parameters:
    ///   - minimumLevel: Minimum level of logs to display
    ///   - showColors: Whether to use ANSI colors in console output
    ///   - dateFormat: Format string for timestamps (default: "yyyy-MM-dd HH:mm:ss.SSS")
    ///   - logFile: Path to file for writing logs (optional)
    public init(
        minimumLevel: Level = .debug,
        showColors: Bool = true,
        dateFormat: String = "yyyy-MM-dd HH:mm:ss.SSS",
        logFile: String? = nil
    ) {
        self.minimumLevel = minimumLevel
        self.showColors = showColors

        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        var handle: FileHandle?
        if let logFile = logFile {
            let url = URL(fileURLWithPath: logFile)
            if FileManager.default.fileExists(atPath: logFile) == false {
                _ = FileManager.default.createFile(atPath: logFile, contents: nil)
            }
            do {
                handle = try FileHandle(forWritingTo: url)
                handle?.seekToEndOfFile()
            }
            catch {
                print("Error opening log file: \(error)")
            }
        }
        self.output = Mutex(OutputState(dateFormatter: formatter, fileHandle: handle))
    }

    deinit {
        self.output.withLock { state in
            state.fileHandle?.closeFile()
        }
    }

    /// Log a message with the specified level
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    ///   - file: Source file name (automatically provided)
    ///   - function: Function name (automatically provided)
    ///   - line: Line number (automatically provided)
    public func log(
        _ level: Level,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level.rawValue >= self.minimumLevel.rawValue else { return }

        self.output.withLock { state in
            let timestamp = state.dateFormatter.string(from: Date())
            let fileName = URL(fileURLWithPath: file).lastPathComponent

            let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line) \(function)] \(message)"

            // Console output
            if self.showColors == true {
                print("\(level.colorCode)\(logMessage)\u{001B}[0m")
            }
            else {
                print(logMessage)
            }

            // File output
            if let fileHandle = state.fileHandle {
                if let data = (logMessage + "\n").data(using: .utf8) {
                    fileHandle.write(data)
                }
            }
        }

    }

    /// Log a debug message
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.debug, message, file: file, function: function, line: line)
    }

    /// Log a debug message with format string
    public func debug(_ format: String, _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.debug, String(format: format, arguments: args), file: file, function: function, line: line)
    }

    /// Log an info message
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.info, message, file: file, function: function, line: line)
    }

    /// Log an info message with format string
    public func info(_ format: String, _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.info, String(format: format, arguments: args), file: file, function: function, line: line)
    }

    /// Log a warning message
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.warning, message, file: file, function: function, line: line)
    }

    /// Log a warning message with format string
    public func warning(_ format: String, _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.warning, String(format: format, arguments: args), file: file, function: function, line: line)
    }

    /// Log an error message
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.error, message, file: file, function: function, line: line)
    }

    /// Log an error message with format string
    public func error(_ format: String, _ args: CVarArg..., file: String = #file, function: String = #function, line: Int = #line) {
        self.log(.error, String(format: format, arguments: args), file: file, function: function, line: line)
    }
}

// MARK: - Example usage

// Create a logger instance
//let trace = Trace(
//    minimumLevel: .debug,
//    showColors: true,
//    dateFormat: "yyyy-MM-dd HH:mm:ss.SSS",
//    logFile: "app.log" // Optional: Remove this parameter to log only to console
//)

public let trace = Trace(
    minimumLevel: .debug,
    showColors: false,
    dateFormat: "yyyy-MM-dd HH:mm:ss"
)

// Log messages at different levels
//logger.debug("This is a debug message")
//logger.info("This is an info message")
//logger.warning("This is a warning message")
//logger.error("This is an error message")

// Log messages with format string
//logger.debug("User %@ logged in from IP %@", "john_doe", "192.168.1.1")
//logger.info("Process completed in %.2f seconds with %d items", 3.14159, 42)
//logger.warning("Memory usage at %.1f%% - approaching threshold", 85.5)
//logger.error("Failed with error code %d: %@", 500, "Internal Server Error")
