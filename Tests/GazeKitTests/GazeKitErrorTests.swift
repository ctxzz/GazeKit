import XCTest
@testable import GazeKit

class GazeKitErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        let errors: [GazeKitError] = [
            .unsupportedDevice,
            .cameraPermissionDenied,
            .arkitSessionFailed,
            .calibrationFailed,
            .trackingNotStarted,
            .invalidConfiguration
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }
    
    func testUnsupportedDeviceError() {
        let error = GazeKitError.unsupportedDevice
        XCTAssertEqual(error.errorDescription, "This device does not support face tracking. A TrueDepth camera is required.")
    }
    
    func testCameraPermissionDeniedError() {
        let error = GazeKitError.cameraPermissionDenied
        XCTAssertEqual(error.errorDescription, "Camera permission is required for eye tracking functionality.")
    }
    
    func testARKitSessionFailedError() {
        let error = GazeKitError.arkitSessionFailed
        XCTAssertEqual(error.errorDescription, "Failed to start ARKit session for face tracking.")
    }
    
    func testCalibrationFailedError() {
        let error = GazeKitError.calibrationFailed
        XCTAssertEqual(error.errorDescription, "Calibration process failed. Please try again.")
    }
    
    func testTrackingNotStartedError() {
        let error = GazeKitError.trackingNotStarted
        XCTAssertEqual(error.errorDescription, "Eye tracking has not been started. Call startTracking() first.")
    }
    
    func testInvalidConfigurationError() {
        let error = GazeKitError.invalidConfiguration
        XCTAssertEqual(error.errorDescription, "Invalid configuration for eye tracking.")
    }
    
    func testErrorEquality() {
        XCTAssertEqual(GazeKitError.unsupportedDevice, GazeKitError.unsupportedDevice)
        XCTAssertNotEqual(GazeKitError.unsupportedDevice, GazeKitError.cameraPermissionDenied)
    }
}