import ARKit
import AVFoundation

protocol ARKitHandlerDelegate: AnyObject {
    func arkitHandler(_ handler: ARKitHandler, didUpdateFaceAnchor faceAnchor: ARFaceAnchor)
    func arkitHandler(_ handler: ARKitHandler, didFailWithError error: Error)
}

class ARKitHandler: NSObject {
    
    weak var delegate: ARKitHandlerDelegate?
    
    private var arSession: ARSession?
    private var faceTrackingConfiguration: ARFaceTrackingConfiguration?
    
    override init() {
        super.init()
        setupConfiguration()
    }
    
    private func setupConfiguration() {
        guard ARFaceTrackingConfiguration.isSupported else {
            return
        }
        
        faceTrackingConfiguration = ARFaceTrackingConfiguration()
        faceTrackingConfiguration?.isLightEstimationEnabled = false
        faceTrackingConfiguration?.providesAudioData = false
        faceTrackingConfiguration?.maximumNumberOfTrackedFaces = 1
    }
    
    func startSession() throws {
        guard let configuration = faceTrackingConfiguration else {
            throw GazeKitError.unsupportedDevice
        }
        
        guard checkCameraPermission() else {
            throw GazeKitError.cameraPermissionDenied
        }
        
        arSession = ARSession()
        arSession?.delegate = self
        
        arSession?.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func stopSession() {
        arSession?.pause()
        arSession = nil
    }
    
    private func checkCameraPermission() -> Bool {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthorizationStatus {
        case .authorized:
            return true
        case .notDetermined:
            var permissionGranted = false
            let semaphore = DispatchSemaphore(value: 0)
            
            AVCaptureDevice.requestAccess(for: .video) { granted in
                permissionGranted = granted
                semaphore.signal()
            }
            
            semaphore.wait()
            return permissionGranted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

extension ARKitHandler: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let faceAnchor = anchor as? ARFaceAnchor {
                delegate?.arkitHandler(self, didUpdateFaceAnchor: faceAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        delegate?.arkitHandler(self, didFailWithError: error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        delegate?.arkitHandler(self, didFailWithError: GazeKitError.arkitSessionFailed)
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        guard let configuration = faceTrackingConfiguration else { return }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}