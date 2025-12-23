import Foundation

enum Constants {
    /// Default server port for pairing service
    static let defaultPort = 5000
    
    /// mDNS service type for discovery
    static let serviceType = "_pairing._tcp."
    
    /// Network request timeout in seconds
    static let requestTimeout: TimeInterval = 30
    
    /// USB polling interval in seconds
    static let usbPollInterval: TimeInterval = 2.0
    
    /// Maximum USB polling attempts
    static let maxUSBPollAttempts = 30
    
    /// Service discovery timeout in seconds
    static let discoveryTimeout: TimeInterval = 10
    
    /// Service resolve timeout in seconds
    static let resolveTimeout: TimeInterval = 5
    
    /// App storage keys
    enum StorageKeys {
        static let isOnboardingComplete = "isOnboardingComplete"
        static let savedManualIPs = "savedManualIPs"
        static let lastSelectedPC = "lastSelectedPC"
        static let savedPCs = "savedPCs"
    }
}
