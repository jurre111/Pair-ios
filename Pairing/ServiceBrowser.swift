import Foundation
import Darwin

class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {
    private var browser = NetServiceBrowser()
    @Published var services: [NetService] = []
    @Published var discoveredPCs: [String: URL] = [:] // name to URL

    func startBrowsing() {
        print("🔍 Starting mDNS service discovery...")
        print("   Current discoveredPCs count: \(discoveredPCs.count)")
        browser.stop()
        browser = NetServiceBrowser()
        browser.includesPeerToPeer = true
        browser.delegate = self
        services.removeAll()
        
        DispatchQueue.main.async {
            self.discoveredPCs.removeAll()
        }
        
        // Search in both default and local domains for maximum compatibility
        print("   Searching for: _pairing._tcp.")
        print("   NOTE: If you haven't granted Local Network permission, this won't find anything.")
        browser.searchForServices(ofType: "_pairing._tcp.", inDomain: "")
        print("   Browser started, waiting for services...")
        
        // Add timeout to stop searching indicator after reasonable time
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.discoveredPCs.isEmpty {
                print("⏱️ 10 second discovery timeout - no services found")
                print("   This usually means:")
                print("   1. Local Network permission was denied")
                print("   2. No servers are advertising on the network")
                print("   3. Router is blocking mDNS multicast")
            }
        }
    }

    func stopBrowsing() {
        browser.stop()
    }

    // NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("✓ Found service: \(service.name) (domain: \(service.domain), type: \(service.type))")
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("✗ Service browser failed to search: \(errorDict)")
        if let errorCode = errorDict[NetService.errorCode] {
            print("   Error code: \(errorCode)")
        }
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("⚠️ Service browser stopped searching")
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("▶️ Service browser will start searching")
        print("   ✓ Local Network permission granted (or this callback wouldn't fire)")
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
            print("✓ Resolved \(sender.name) to \(bestURL)")
            DispatchQueue.main.async {
                self.discoveredPCs[sender.name] = bestURL
            }
        } else {
            print("✗ Could not create URL for \(sender.name)")
        }
        DispatchQueue.main.async {
            self.services.append(sender)
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("✗ Failed to resolve \(sender.name): \(errorDict)")
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