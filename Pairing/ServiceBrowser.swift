import Foundation
import Darwin

class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {
    private var browser = NetServiceBrowser()
    @Published var services: [NetService] = []
    @Published var discoveredPCs: [String: URL] = [:] // name to URL
    @Published var debugLogs: [String] = []
    @Published var hasPermission: Bool = false
    @Published var searchFailed: Bool = false
    
    // Keep strong references to services being resolved
    private var resolvingServices: [NetService] = []

    func startBrowsing() {
        let log = "🔍 Starting mDNS service discovery..."
        print(log)
        addLog(log)
        
        browser.stop()
        browser = NetServiceBrowser()
        browser.includesPeerToPeer = true
        browser.delegate = self
        services.removeAll()
        resolvingServices.removeAll()
        searchFailed = false
        hasPermission = false
        
        DispatchQueue.main.async {
            self.discoveredPCs.removeAll()
        }
        
        addLog("Searching for service type: _pairing._tcp.")
        browser.searchForServices(ofType: "_pairing._tcp.", inDomain: "")
        addLog("Browser started, waiting for services...")
        
        // Add timeout to show detailed logs
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self else { return }
            if self.discoveredPCs.isEmpty {
                self.addLog("⏱️ Discovery timeout after 10 seconds")
                if !self.hasPermission {
                    self.addLog("❌ Local Network permission not granted or search failed")
                } else if self.searchFailed {
                    self.addLog("❌ Search failed - check iOS Settings → Pairing → Local Network")
                } else {
                    self.addLog("⚠️ No servers found on network")
                    self.addLog("Possible causes: Server not running, different WiFi network, or router blocking mDNS")
                }
            }
        }
    }
    
    private func addLog(_ message: String) {
        DispatchQueue.main.async {
            self.debugLogs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
            if self.debugLogs.count > 20 {
                self.debugLogs.removeFirst()
            }
        }
    }

    func stopBrowsing() {
        browser.stop()
    }

    // NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let log = "✓ Found service: \(service.name)"
        print(log)
        addLog(log)
        addLog("Resolving address (timeout: 15s)...")
        
        // IMPORTANT: Keep strong reference to service while resolving
        resolvingServices.append(service)
        
        service.delegate = self
        service.resolve(withTimeout: 15.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        searchFailed = true
        let errorCode = errorDict[NetService.errorCode]?.intValue ?? -1
        let log = "✗ Search failed with error code: \(errorCode)"
        print(log)
        addLog(log)
        
        if errorCode == -72000 {
            addLog("Error -72000: Local Network permission denied")
        }
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        let log = "⚠️ Browser stopped searching"
        print(log)
        addLog(log)
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        hasPermission = true
        let log = "▶️ Search started - Local Network permission granted"
        print(log)
        addLog(log)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        DispatchQueue.main.async {
            self.discoveredPCs.removeValue(forKey: service.name)
        }
    }

    // NetServiceDelegate
    func netServiceDidResolveAddress(_ sender: NetService) {
        addLog("Resolution callback triggered for \(sender.name)")
        addLog("  hostName: \(sender.hostName ?? "nil")")
        addLog("  port: \(sender.port)")
        addLog("  addresses count: \(sender.addresses?.count ?? 0)")
        
        // Remove from resolving list
        resolvingServices.removeAll { $0 == sender }
        
        guard let addresses = sender.addresses else {
            addLog("✗ No addresses in resolved service")
            return
        }

        // Try to get URLs from addresses, preferring IPv4
        let urls = addresses
            .compactMap { makeURL(from: $0, port: Int(sender.port)) }
            .sorted(by: preferIPv4)

        if let bestURL = urls.first {
            let log = "✓ Resolved \(sender.name) → \(bestURL.host ?? "unknown"):\(sender.port)"
            print(log)
            addLog(log)
            DispatchQueue.main.async {
                self.discoveredPCs[sender.name] = bestURL
            }
        } else {
            // No IPv4 address available - log error
            let log = "✗ No IPv4 address found for \(sender.name) - server must provide IPv4"
            print(log)
            addLog(log)
        }
        DispatchQueue.main.async {
            self.services.append(sender)
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        // Remove from resolving list
        resolvingServices.removeAll { $0 == sender }
        
        let errorCode = errorDict[NetService.errorCode]?.intValue ?? -1
        let log = "✗ Failed to resolve \(sender.name) (error: \(errorCode))"
        print(log)
        addLog(log)
    }

    private func makeURL(from data: Data, port: Int) -> URL? {
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> URL? in
            let sockaddrPtr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let family = Int32(sockaddrPtr.pointee.sa_family)
            
            // Only accept IPv4 addresses for reliability
            guard family == AF_INET else {
                return nil
            }

            if getnameinfo(sockaddrPtr, socklen_t(data.count), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) != 0 {
                return nil
            }

            let host = String(cString: hostBuffer)
            return URL(string: "http://\(host):\(port)")
        }
    }

    private func preferIPv4(_ lhs: URL, _ rhs: URL) -> Bool {
        // IPv4 addresses don't contain colons, IPv6 do
        let lhsIsV4 = lhs.host?.contains(":") == false && lhs.host?.contains("[") == false
        let rhsIsV4 = rhs.host?.contains(":") == false && rhs.host?.contains("[") == false
        if lhsIsV4 == rhsIsV4 { return true }
        return lhsIsV4 && !rhsIsV4
    }
}