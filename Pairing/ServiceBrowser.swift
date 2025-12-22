import Foundation
import Darwin

class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, ObservableObject {
    private var browser = NetServiceBrowser()
    @Published var services: [NetService] = []
    @Published var discoveredPCs: [String: URL] = [:] // name to URL

    func startBrowsing() {
        browser.delegate = self
        browser.searchForServices(ofType: "_pairing._tcp.", inDomain: "local.")
    }

    func stopBrowsing() {
        browser.stop()
    }

    // NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        services.removeAll { $0 == service }
        discoveredPCs.removeValue(forKey: service.name)
    }

    // NetServiceDelegate
    func netServiceDidResolveAddress(_ sender: NetService) {
        if let addresses = sender.addresses, let firstAddress = addresses.first {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            firstAddress.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let sockaddrPtr = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
                if getnameinfo(sockaddrPtr, socklen_t(firstAddress.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    let url = URL(string: "http://\(ip):\(sender.port)")!
                    discoveredPCs[sender.name] = url
                }
            }
        }
        services.append(sender)
    }
}