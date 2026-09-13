import Foundation

struct ByteFormat {
    static func string(bytes: UInt64, rate: Bool = false) -> String {
        let value = Double(bytes)
        let formatted: String
        switch value {
        case 0..<1024: formatted = String(format: "%.0f B", value)
        case 1024..<(1024*1024): formatted = String(format: "%.1f KB", value / 1024)
        case (1024*1024)..<(1024*1024*1024): formatted = String(format: "%.1f MB", value / (1024*1024))
        default: formatted = String(format: "%.2f GB", value / (1024*1024*1024))
        }
        return rate ? formatted + "/s" : formatted
    }
}
