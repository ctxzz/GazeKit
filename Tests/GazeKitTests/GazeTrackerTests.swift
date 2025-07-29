import XCTest
import ARKit
@testable import GazeKit

class GazeTrackerTests: XCTestCase {
    
    var arView: ARSCNView!
    var gazeTracker: GazeTracker!
    
    override func setUp() {
        super.setUp()
        arView = ARSCNView()
        
        if ARFaceTrackingConfiguration.isSupported {
            do {
                gazeTracker = try GazeTracker(arView: arView)
            } catch {
                XCTFail("Failed to initialize GazeTracker: \(error)")
            }
        }
    }
    
    override func tearDown() {
        gazeTracker?.stopTracking()
        gazeTracker = nil
        arView = nil
        super.tearDown()
    }
    
    func testGazeTrackerInitialization() throws {
        guard ARFaceTrackingConfiguration.isSupported else {
            throw XCTSkip("Face tracking not supported on this device")
        }
        XCTAssertNotNil(gazeTracker)
        XCTAssertTrue(gazeTracker.isCalibrationRequired)
    }
    
    func testStartStopTracking() throws {
        guard ARFaceTrackingConfiguration.isSupported else {
            throw XCTSkip("Face tracking not supported on this device")
        }
        gazeTracker.startTracking()
        gazeTracker.stopTracking()
    }
    
    func testCalibrationRequired() throws {
        guard ARFaceTrackingConfiguration.isSupported else {
            throw XCTSkip("Face tracking not supported on this device")
        }
        XCTAssertTrue(gazeTracker.isCalibrationRequired)
        
        let expectation = XCTestExpectation(description: "Calibration completion")
        
        gazeTracker.startCalibration { success in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testResetCalibration() throws {
        guard ARFaceTrackingConfiguration.isSupported else {
            throw XCTSkip("Face tracking not supported on this device")
        }
        gazeTracker.resetCalibration()
        XCTAssertTrue(gazeTracker.isCalibrationRequired)
    }
    
    func testErrorHandling() {
        let unsupportedARView = ARSCNView()
        
        do {
            _ = try GazeTracker(arView: unsupportedARView)
        } catch let error as GazeKitError {
            switch error {
            case .unsupportedDevice:
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

class MockGazeTrackerDelegate: GazeTrackerDelegate {
    var gazePointUpdates: [CGPoint] = []
    var errors: [Error] = []
    
    func gazeTracker(didUpdateGazePoint gazePoint: CGPoint) {
        gazePointUpdates.append(gazePoint)
    }
    
    func gazeTracker(didFailWithError error: Error) {
        errors.append(error)
    }
}

class GazeTrackerDelegateTests: XCTestCase {
    
    var gazeTracker: GazeTracker!
    var mockDelegate: MockGazeTrackerDelegate!
    
    override func setUp() {
        super.setUp()
        
        guard ARFaceTrackingConfiguration.isSupported else {
            return
        }
        
        let arView = ARSCNView()
        mockDelegate = MockGazeTrackerDelegate()
        
        do {
            gazeTracker = try GazeTracker(arView: arView)
            gazeTracker.delegate = mockDelegate
        } catch {
            XCTFail("Failed to initialize GazeTracker: \(error)")
        }
    }
    
    override func tearDown() {
        gazeTracker?.stopTracking()
        gazeTracker = nil
        mockDelegate = nil
        super.tearDown()
    }
    
    func testDelegateGazePointUpdates() throws {
        guard gazeTracker != nil else {
            throw XCTSkip("GazeTracker not available")
        }
        
        let testPoint = CGPoint(x: 100, y: 200)
        
        gazeTracker.delegate?.gazeTracker(didUpdateGazePoint: testPoint)
        
        XCTAssertEqual(mockDelegate.gazePointUpdates.count, 1)
        XCTAssertEqual(mockDelegate.gazePointUpdates.first, testPoint)
    }
    
    func testDelegateErrorHandling() throws {
        guard gazeTracker != nil else {
            throw XCTSkip("GazeTracker not available")
        }
        
        let testError = GazeKitError.trackingNotStarted
        
        gazeTracker.delegate?.gazeTracker(didFailWithError: testError)
        
        XCTAssertEqual(mockDelegate.errors.count, 1)
        XCTAssertEqual(mockDelegate.errors.first as? GazeKitError, testError)
    }
}