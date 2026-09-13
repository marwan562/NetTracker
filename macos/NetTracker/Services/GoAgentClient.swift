import Foundation

enum LifecycleEvent: String {
    case networkChanged = "network_changed"
    case sleep
    case wake
}

protocol GoAgentClientProtocol {
    func getSnapshot() async throws -> UsageSnapshot
    func getHistory(days: Int) async throws -> [DailyUsage]
    func reset() async throws
    func sendLifecycleEvent(_ event: LifecycleEvent) async throws
}

struct AgentRequest: Codable {
    var version: Int = 1
    var type: String
    var days: Int?
}

struct AgentResponse: Codable {
    var version: Int
    var type: String
    var session: BytesPair?
    var today: BytesPair?
    var uploadRate: UInt64?
    var downloadRate: UInt64?
    var days: [DailyUsage]?
    var ok: Bool?
    var error: String?

    enum CodingKeys: String, CodingKey {
        case version, type, session, today, days, ok, error
        case uploadRate = "upload_rate"
        case downloadRate = "download_rate"
    }
}

struct BytesPair: Codable {
    var uploadBytes: UInt64
    var downloadBytes: UInt64

    enum CodingKeys: String, CodingKey {
        case uploadBytes = "upload_bytes"
        case downloadBytes = "download_bytes"
    }
}

final class GoAgentClient: GoAgentClientProtocol, @unchecked Sendable {
    private let socketPath: String

    init(socketPath: String? = nil) {
        if let socketPath {
            self.socketPath = socketPath
        } else if let env = ProcessInfo.processInfo.environment["NETTRACKER_SOCKET"], !env.isEmpty {
            self.socketPath = env
        } else {
            let base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/NetTracker").path
            self.socketPath = (base as NSString).appendingPathComponent("agent.sock")
        }
    }

    func getSnapshot() async throws -> UsageSnapshot {
        let resp: AgentResponse = try await send(AgentRequest(type: "snapshot"))
        return UsageSnapshot(
            sessionUploadBytes: resp.session?.uploadBytes ?? 0,
            sessionDownloadBytes: resp.session?.downloadBytes ?? 0,
            todayUploadBytes: resp.today?.uploadBytes ?? 0,
            todayDownloadBytes: resp.today?.downloadBytes ?? 0,
            currentUploadRate: resp.uploadRate ?? 0,
            currentDownloadRate: resp.downloadRate ?? 0
        )
    }

    func getHistory(days: Int) async throws -> [DailyUsage] {
        let resp: AgentResponse = try await send(AgentRequest(type: "history", days: days))
        return resp.days ?? []
    }

    func reset() async throws {
        let resp: AgentResponse = try await send(AgentRequest(type: "reset"))
        if resp.error != nil { throw AgentError.server(resp.error!) }
    }

    func sendLifecycleEvent(_ event: LifecycleEvent) async throws {
        let resp: AgentResponse = try await send(AgentRequest(type: event.rawValue))
        if resp.error != nil { throw AgentError.server(resp.error!) }
    }

    private func send<T: Decodable>(_ request: AgentRequest) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try self.sendSync(request)
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    cont.resume(returning: decoded)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func sendSync(_ request: AgentRequest) throws -> Data {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw AgentError.connection("socket() failed") }
        defer { close(fd) }

        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = socketPath
        guard path.utf8.count < MemoryLayout.size(ofValue: addr.sun_path) else {
            throw AgentError.connection("socket path too long")
        }
        _ = path.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { dest in
                dest.withMemoryRebound(to: CChar.self, capacity: path.utf8.count + 1) { buf in
                    strcpy(buf, ptr)
                }
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                Darwin.connect(fd, sptr, len)
            }
        }
        guard connResult == 0 else { throw AgentError.connection("agent not running") }
        var payload = try JSONEncoder().encode(request)
        payload.append(0x0A)
        try payload.withUnsafeBytes { buf in
            var sent = 0
            while sent < payload.count {
                let n = Darwin.send(fd, buf.baseAddress!.advanced(by: sent), payload.count - sent, 0)
                if n <= 0 { throw AgentError.connection("send failed") }
                sent += n
            }
        }
        var out = Data()
        var byte = [UInt8](repeating: 0, count: 1)
        while true {
            let n = Darwin.recv(fd, &byte, 1, 0)
            if n <= 0 { break }
            if byte[0] == 0x0A { break }
            out.append(byte[0])
            if out.count > 1024 * 1024 { throw AgentError.server("response too large") }
        }
        guard !out.isEmpty else { throw AgentError.connection("empty response") }
        return out
    }
}

enum AgentError: LocalizedError {
    case connection(String)
    case server(String)
    var errorDescription: String? {
        switch self {
        case .connection(let m): return m
        case .server(let m): return m
        }
    }
}

final class MockGoAgentClient: GoAgentClientProtocol {
    func getSnapshot() async throws -> UsageSnapshot {
        UsageSnapshot(sessionUploadBytes: 23_000_000, sessionDownloadBytes: 184_000_000,
                      todayUploadBytes: 284_000_000, todayDownloadBytes: 1_520_000_000,
                      currentUploadRate: 48_000, currentDownloadRate: 1_240_000)
    }
    func getHistory(days: Int) async throws -> [DailyUsage] {
        var out: [DailyUsage] = []
        for i in 0..<days {
            let up = UInt64(100_000_000 + i * 10_000_000)
            let down = UInt64(800_000_000 - i * 50_000_000)
            let label = i == 0 ? "Today" : "Sep \(13 - i)"
            out.append(DailyUsage(date: "2026-09-\(13 - i)", label: label,
                                  uploadBytes: up, downloadBytes: down, isToday: i == 0))
        }
        return out
    }
    func reset() async throws {}
    func sendLifecycleEvent(_ event: LifecycleEvent) async throws {}
}
