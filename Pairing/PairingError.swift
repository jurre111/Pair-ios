import Foundation

enum PairingError: LocalizedError {
    case noServerSelected
    case invalidServerURL
    case networkError(Error)
    case serverError(String)
    case usbRequired
    case usbTimeout
    case fileWriteFailed
    case invalidResponse
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .noServerSelected:
            return "No PC selected"
        case .invalidServerURL:
            return "Invalid server address"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .usbRequired:
            return "USB connection required"
        case .usbTimeout:
            return "USB pairing timed out. Please try again."
        case .fileWriteFailed:
            return "Failed to save pairing file"
        case .invalidResponse:
            return "Invalid response from server"
        case .cancelled:
            return "Pairing cancelled"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noServerSelected:
            return "Select a PC from the list or enter an IP address manually."
        case .invalidServerURL:
            return "Check the IP address and try again."
        case .networkError:
            return "Make sure you're on the same network as the PC."
        case .serverError:
            return "Make sure the pairing server is running on your PC."
        case .usbRequired:
            return "Connect your iPhone to the PC with a USB cable and tap 'Trust' when prompted."
        case .usbTimeout:
            return "Make sure your iPhone is connected to the PC via USB and you've tapped 'Trust'."
        case .fileWriteFailed:
            return "Try again or check available storage."
        case .invalidResponse:
            return "Make sure the pairing server is up to date."
        case .cancelled:
            return nil
        }
    }
}
