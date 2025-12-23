import Foundation
import Darwin

class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {
    private var browser = NetServiceBrowser()
    @Published var services: [NetService] = []
    @Published var discoveredPCs: [String: URL] = [:] // name to URL

    func startBrowsing() {
        browser.stop()
        browser = NetServiceBrowser()
        browser.includesPeerToPeer = true
        browser.delegate = self
        services.removeAll()
        discoveredPCs.removeAll()
        browser.searchForServices(ofType: "_pairing._tcp.", inDomain: "")
        browser.searchForServices(ofType: "_pairing._tcp.", inDomain: "local.")
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

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Service browser failed: \(errorDict)")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        DispatchQueue.main.async {
            self.discoveredPCs.removeValue(forKey: service.name)
        }
    }

    // NetServiceDelegate
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }

        // Prefer IPv4; fall back to IPv6 with proper formatting
        let urls = addresses
            .compactMap { makeURL(from: $0, port: Int(sender.port)) }
            .sorted(by: preferIPv4)

        if let bestURL = urls.first {
            print("Resolved \(sender.name) to \(bestURL)")
            DispatchQueue.main.async {
                self.discoveredPCs[sender.name] = bestURL
            }
        }
        DispatchQueue.main.async {
            self.services.append(sender)
        }
    }

    private func makeURL(from data: Data, port: Int) -> URL? {
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

    private func preferIPv4(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsIsV4 = lhs.host?.contains(":") == false
        let rhsIsV4 = rhs.host?.contains(":") == false
        if lhsIsV4 == rhsIsV4 { return true }
        return lhsIsV4 && !rhsIsV4
    }
}