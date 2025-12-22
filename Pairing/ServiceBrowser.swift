import Foundation
import Darwin

class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {
    private var browser = NetServiceBrowser()
    @Published var services: [NetService] = []
    @Published var discoveredPCs: [String: URL] = [:] // name to URL

    func startBrowsing() {
        browser.delegate = self
        browser.searchForServices(ofType: "_pairing._tcp.", inDomain: "")
    }

    func stopBrowsing() {
        browser.stop()
    }

    // NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Found service: \(service.name)")
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        discoveredPCs.removeValue(forKey: service.name)
    }

    // NetServiceDelegate
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }

        // Prefer IPv4; fall back to IPv6 with proper formatting
        if let bestURL = addresses.compactMap(makeURL(from:sender.port)).first {
            print("Resolved \(sender.name) to \(bestURL)")
            discoveredPCs[sender.name] = bestURL
        }
        services.append(sender)
    }

    private func makeURL(from data: Data, port: Int32) -> URL? {
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> URL? in
            let sockaddrPtr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let family = Int32(sockaddrPtr.pointee.sa_family)

            if getnameinfo(sockaddrPtr, socklen_t(data.count), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) != 0 {
                return nil
            }

            var host = String(cString: hostBuffer)

            // Strip scope ID for link-local IPv6 to avoid URL parsing issues
            if let percentRange = host.range(of: "%") {
                host.removeSubrange(percentRange.lowerBound..<host.endIndex)
            }

            if family == AF_INET6 {
                host = "[\(host)]"
            }

            return URL(string: "http://\(host):\(port)")
        }
    }
}