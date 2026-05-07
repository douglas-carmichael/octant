import Foundation
import Network

// MARK: - Wire protocol

enum WireMessage: Codable {
    case hello(name: String, playerID: UUID)
    case youAre(playerID: UUID, isAdmin: Bool)
    case lobby(players: [NetPlayer], config: NetGameConfig, status: String)
    case startCountdown(seconds: Int)
    case round(round: Int, total: Int, target: Int, bitsCount: Int, deadlineEpoch: TimeInterval)
    case finished(round: Int, time: Double, clicks: Int)
    case roundResults(round: Int, total: Int, target: Int, bitsCount: Int, scores: [PlayerScore])
    case nextRound
    case gameOver(finalStandings: [PlayerStanding])
    case configUpdate(NetGameConfig)
    case kick(playerID: UUID)
    case error(message: String)
}

extension WireMessage {
    static let serviceType = "_octant._tcp"
    static let bonjourDomain = "local."
    static let appProtocolVersion = 1
}

// MARK: - Length-prefixed framing

enum Framing {
    static let maxMessageBytes: Int = 1 << 20

    static func encode(_ data: Data) -> Data {
        var length = UInt32(data.count).bigEndian
        var out = Data(capacity: 4 + data.count)
        withUnsafeBytes(of: &length) { out.append(contentsOf: $0) }
        out.append(data)
        return out
    }
}

// MARK: - PeerConnection

final class PeerConnection {

    let id = UUID()
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "octant.peer.\(UUID().uuidString.prefix(6))")
    private var buffer = Data()
    private(set) var isOpen = false

    var onReady: (() -> Void)?
    var onMessage: ((WireMessage) -> Void)?
    var onClosed: ((Error?) -> Void)?

    var playerID: UUID?
    var playerName: String?
    var isAdmin: Bool = false

    init(connection: NWConnection) {
        self.connection = connection
    }

    convenience init(endpoint: NWEndpoint) {
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let conn = NWConnection(to: endpoint, using: params)
        self.init(connection: conn)
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            #if DEBUG
            NSLog("[PeerConnection] state: \(state)")
            #endif
            switch state {
            case .ready:
                self.isOpen = true
                self.queue.async { self.receiveLoop() }
                DispatchQueue.main.async { self.onReady?() }
            case .failed(let error):
                self.close(error: error)
            case .cancelled:
                self.close(error: nil)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    func send(_ message: WireMessage) {
        guard let data = try? JSONEncoder().encode(message) else { return }
        let framed = Framing.encode(data)
        connection.send(content: framed, completion: .contentProcessed { _ in })
    }

    func sendAndClose(_ message: WireMessage) {
        guard let data = try? JSONEncoder().encode(message) else { close(); return }
        let framed = Framing.encode(data)
        connection.send(content: framed, contentContext: .finalMessage, isComplete: true,
                        completion: .contentProcessed { [weak self] _ in
            self?.close()
        })
    }

    func close(error: Error? = nil) {
        guard isOpen || connection.state != .cancelled else { return }
        isOpen = false
        connection.cancel()
        DispatchQueue.main.async { self.onClosed?(error) }
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.buffer.append(data)
                self.drainBuffer()
            }
            if let error {
                self.close(error: error); return
            }
            if isComplete {
                self.close(error: nil); return
            }
            self.queue.async { self.receiveLoop() }
        }
    }

    private func drainBuffer() {
        while buffer.count >= 4 {
            let length = buffer.prefix(4).withUnsafeBytes { ptr -> UInt32 in
                ptr.load(as: UInt32.self).bigEndian
            }
            guard length <= Framing.maxMessageBytes else {
                close(error: NSError(domain: "Octant", code: -1,
                                     userInfo: [NSLocalizedDescriptionKey: "Frame too large"]))
                return
            }
            let total = 4 + Int(length)
            guard buffer.count >= total else { return }
            let payload = buffer.subdata(in: 4..<total)
            buffer.removeSubrange(0..<total)

            if let msg = try? JSONDecoder().decode(WireMessage.self, from: payload) {
                DispatchQueue.main.async { self.onMessage?(msg) }
            }
        }
    }
}

// MARK: - HostService

final class HostService {

    private var listener: NWListener?
    private let serviceName: String
    var onAccepted: ((PeerConnection) -> Void)?
    var onError: ((Error) -> Void)?

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func start() {
        do {
            let params = NWParameters.tcp
            params.includePeerToPeer = true
            let listener = try NWListener(using: params, on: .any)
            listener.service = NWListener.Service(
                name: serviceName,
                type: WireMessage.serviceType,
                domain: WireMessage.bonjourDomain
            )
            listener.newConnectionHandler = { [weak self] connection in
                let peer = PeerConnection(connection: connection)
                DispatchQueue.main.async { self?.onAccepted?(peer) }
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let err) = state {
                    DispatchQueue.main.async { self?.onError?(err) }
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch {
            DispatchQueue.main.async { self.onError?(error) }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
}

// MARK: - BrowserService

final class BrowserService {

    private var browser: NWBrowser?
    var onChange: (([DiscoveredHost], [String: NWEndpoint]) -> Void)?

    func start() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: WireMessage.serviceType, domain: WireMessage.bonjourDomain)
        let browser = NWBrowser(for: descriptor, using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            var hosts: [DiscoveredHost] = []
            var endpoints: [String: NWEndpoint] = [:]
            for result in results {
                if case let .service(name, _, _, _) = result.endpoint {
                    let host = DiscoveredHost(id: name, name: name)
                    hosts.append(host)
                    endpoints[name] = result.endpoint
                }
            }
            DispatchQueue.main.async { self?.onChange?(hosts, endpoints) }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }
}
