import Foundation
import os.log

enum WatchLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.vicente.losmooscles.watch"

    static let connectivity = Logger(subsystem: subsystem, category: "connectivity")
    static let workout = Logger(subsystem: subsystem, category: "workout")
    static let health = Logger(subsystem: subsystem, category: "health")
}
