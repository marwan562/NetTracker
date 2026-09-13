import Foundation

struct UsageSnapshot: Codable, Equatable {
    var sessionUploadBytes: UInt64 = 0
    var sessionDownloadBytes: UInt64 = 0
    var todayUploadBytes: UInt64 = 0
    var todayDownloadBytes: UInt64 = 0
    var currentUploadRate: UInt64 = 0
    var currentDownloadRate: UInt64 = 0

    static let empty = UsageSnapshot()
}

struct DailyUsage: Codable, Identifiable, Equatable {
    var id: String { date }
    var date: String
    var label: String
    var uploadBytes: UInt64
    var downloadBytes: UInt64
    var isToday: Bool

    enum CodingKeys: String, CodingKey {
        case date, label
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
        case isToday = "is_today"
    }
}

enum NetworkStatus: Equatable {
    case connected(String)
    case disconnected
    case unknown
}

enum AgentConnection: Equatable {
    case connected
    case connecting
    case disconnected(String)
}
