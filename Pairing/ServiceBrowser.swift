import Foundation
import Darwin

class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {
    private var browser = NetServiceBrowser()
    @Published var services: [NetService] = []
    @Published var discoveredPCs: [String: URL] = [:]
    @Published var hasPermission: Bool = false
    @Published var searchFailed: Bool = false
    
    // Keep strong references to services being resolved
    private var resolvingServices: [NetService] = []

    func startBrowsing() {
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
        
        browser.searchForServices(ofType: Constants.serviceType, inDomain: "")
    }

    func stopBrowsing() {
        browser.stop()
    }

    // MARK: - NetServiceBrowserDelegate
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        // Keep strong reference to service while resolving
        resolvingServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: Constants.resolveTimeout)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        searchFailed = true
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        // Browser stopped
    }
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        hasPermission = true
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        DispatchQueue.main.async {
            self.discoveredPCs.removeValue(forKey: service.name)
        }
    }

    // MARK: - NetServiceDelegate
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        // Remove from resolving list
        resolvingServices.removeAll { $0 == sender }
        
        guard let addresses = sender.addresses else {
            return
        }

        // Try to get URLs from addresses, preferring IPv4
        let urls = addresses
            .compactMap { makeURL(from: $0, port: Int(sender.port)) }
            .sorted(by: preferIPv4)

        if let bestURL = urls.first {
            DispatchQueue.main.async {
                self.discoveredPCs[sender.name] = bestURL
            }
        }
        
        DispatchQueue.main.async {
            self.services.append(sender)
        }
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        resolvingServices.removeAll { $0 == sender }
    }

    // MARK: - Helpers
    
    private func makeURL(from data: Data, port: Int) -> URL? {
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> URL? in
            guard let baseAddress = ptr.baseAddress else { return nil }
            let sockaddrPtr = baseAddress.assumingMemoryBound(to: sockaddr.self)
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
        let lhsIsV4 = lhs.host?.contains(":") == false && lhs.host?.contains("[") == false
        let rhsIsV4 = rhs.host?.contains(":") == false && rhs.host?.contains("[") == false
        if lhsIsV4 == rhsIsV4 { return false } // Keep original order if same type
        return lhsIsV4 && !rhsIsV4
    }
}