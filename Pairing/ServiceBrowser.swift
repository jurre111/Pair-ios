import Foundation
import Darwin

class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {
    private var browser = NetServiceBrowser()
    @Published var services: [NetService] = []
    @Published var discoveredPCs: [String: URL] = [:] // name to URL
    @Published var debugLogs: [String] = []
    @Published var hasPermission: Bool = false
    @Published var searchFailed: Bool = false

    func startBrowsing() {
        let log = "🔍 Starting mDNS service discovery..."
        print(log)
        addLog(log)
        
        browser.stop()
        browser = NetServiceBrowser()
        browser.includesPeerToPeer = true
        browser.delegate = self
        services.removeAll()
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
        addLog("Attempting to resolve address...")
        service.delegate = self
        
        // Start resolution
        service.resolve(withTimeout: 10.0)
        
        // Workaround: If resolution takes too long, try scanning local network
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            // If still not resolved after 3 seconds, try common local IPs
            if self.discoveredPCs[service.name] == nil {
                self.addLog("⚠️ Resolution slow, trying direct connection scan...")
                self.tryScanLocalNetwork(for: service.name)
            }
        }
    }
    
    private func tryScanLocalNetwork(for serviceName: String) {
        // Get device's local IP to determine network
        guard let localIP = getLocalIPAddress() else {
            addLog("✗ Could not determine local IP address")
            return
        }
        
        // Extract network prefix (e.g., "192.168.2" from "192.168.2.15")
        let components = localIP.split(separator: ".")
        guard components.count == 4 else { return }
        
        let networkPrefix = "\(components[0]).\(components[1]).\(components[2])"
        addLog("Scanning network: \(networkPrefix).x")
        
        // Try common host IPs in parallel
        let commonHosts = [1, 10, 100, 254] // Common router/server IPs
        for host in commonHosts {
            let testIP = "\(networkPrefix).\(host)"
            testConnection(ip: testIP, serviceName: serviceName)
        }
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                let interface = ptr?.pointee
                let addrFamily = interface?.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: (interface?.ifa_name)!)
                    if name == "en0" || name.starts(with: "wlan") {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface?.ifa_addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!),
                                  &hostname, socklen_t(hostname.count),
                                  nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
    
    private func testConnection(ip: String, serviceName: String) {
        guard let url = URL(string: "http://\(ip):5000/mdns_status") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                self.addLog("✓ Found server at \(ip):5000")
                if let baseURL = URL(string: "http://\(ip):5000") {
                    DispatchQueue.main.async {
                        self.discoveredPCs[serviceName] = baseURL
                    }
                }
            }
        }.resume()
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
        
        guard let addresses = sender.addresses else {
            addLog("✗ No addresses in resolved service")
            return
        }

        // Prefer IPv4; fall back to IPv6 with proper formatting
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
            let log = "✗ Could not create URL from \(addresses.count) address(es)"
            print(log)
            addLog(log)
        }
        DispatchQueue.main.async {
            self.services.append(sender)
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        let errorCode = errorDict[NetService.errorCode]?.intValue ?? -1
        let log = "✗ Failed to resolve \(sender.name) (error: \(errorCode))"
        print(log)
        addLog(log)
        
        // Workaround: Try to construct URL using common mDNS pattern
        // Service is likely at {hostname}.local:5000
        if let hostName = sender.name.components(separatedBy: ".").first {
            let possibleURL = URL(string: "http://\(sender.hostName ?? sender.name):5000")
            if let url = possibleURL {
                addLog("⚠️ Attempting fallback URL: \(url.absoluteString)")
                DispatchQueue.main.async {
                    self.discoveredPCs[sender.name] = url
                }
            }
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