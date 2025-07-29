import Foundation

public enum GazeKitError: LocalizedError {
    case unsupportedDevice
    case cameraPermissionDenied
    case arkitSessionFailed
    case calibrationFailed
    case trackingNotStarted
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedDevice:
            return "This device does not support face tracking. A TrueDepth camera is required."
        case .cameraPermissionDenied:
            return "Camera permission is required for eye tracking functionality."
        case .arkitSessionFailed:
            return "Failed to start ARKit session for face tracking."
        case .calibrationFailed:
            return "Calibration process failed. Please try again."
        case .trackingNotStarted:
            return "Eye tracking has not been started. Call startTracking() first."
        case .invalidConfiguration:
            return "Invalid configuration for eye tracking."
        }
    }
}