# GazeKit for iPad

**GazeKit** is a Swift library for real-time eye gaze tracking on iPad using TrueDepth camera and ARKit.

It provides high-precision calibration and a simple API, making it easy to integrate eye tracking functionality into apps, research projects, and usability testing.

<img src="https://user-images.githubusercontent.com/assets/3565251/258529323-b14a806c-8208-4623-b32c-a25c56d7729f.png" width="600">

---

## ✨ Key Features

* **ARKit-based High-Precision Tracking**: Leverages TrueDepth camera for stable gaze detection
* **Simple API**: Start and stop eye tracking with just a few lines of code
* **Calibration System**: Built-in calibration process to correct user-specific offsets and improve accuracy
* **Screen Coordinate Output**: Gaze data is provided directly as iPad screen coordinates (`CGPoint`)
* **Swift Package Manager Support**: Easy integration into your projects

---

## 📋 Requirements

* iOS 18.0 or later
* iPad with TrueDepth camera (iPad Pro, etc.)
* Xcode 16.0 or later
* Swift 5.0

---

## 📦 Installation

Easily add to your Xcode project using Swift Package Manager.

1.  Open your project in Xcode and select "File" > "Add Packages..."
2.  Paste this repository URL in the search field:
    ```
    https://github.com/ctxzz/GazeKit.git
    ```
3.  Click "Add Package" to complete the installation.

---

## 🚀 Usage

### 1. Import and Setup GazeKit

`GazeTracker` requires an `ARSCNView`. Set it up in your View Controller.

```swift
import UIKit
import ARKit
import GazeKit

class GazeTrackingViewController: UIViewController {

    private let arView = ARSCNView()
    private var gazeTracker: GazeTracker?
    private let gazeDotView = UIView() // View to visualize gaze point

    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupGazeDotView()

        do {
            gazeTracker = try GazeTracker(arView: arView)
            gazeTracker?.delegate = self
        } catch {
            // Error handling: show alert, etc.
            print("Failed to initialize GazeKit: \(error.localizedDescription)")
            // self.showErrorAlert(message: "This device does not support eye tracking.")
        }
    }
    
    // Helper methods for UI setup
    private func setupARView() {
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)
        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupGazeDotView() {
        gazeDotView.frame.size = CGSize(width: 20, height: 20)
        gazeDotView.backgroundColor = .red.withAlphaComponent(0.5)
        gazeDotView.layer.cornerRadius = 10
        view.addSubview(gazeDotView)
    }
}
```

### 2. Run Calibration

Execute calibration before starting tracking for more accurate coordinates.

```swift
// Button action to start calibration
@objc func startCalibration() {
    // Update UI to show calibration instructions to user
    // self.showCalibrationInstructions()
    
    gazeTracker?.startCalibration { [weak self] success in
        guard let self = self else { return }
        
        DispatchQueue.main.async {
            if success {
                print("Calibration successful!")
                self.gazeTracker?.startTracking()
            } else {
                print("Calibration failed.")
                // self.showErrorAlert(message: "Calibration failed. Please try again.")
            }
        }
    }
}
```

### 3. Receive Gaze Point Data

Implement the `GazeTrackerDelegate` protocol to receive real-time gaze point data.

```swift
extension GazeTrackingViewController: GazeTrackerDelegate {
    
    func gazeTracker(didUpdateGazePoint gazePoint: CGPoint) {
        // Delegate may be called from background thread, so update UI on main thread
        DispatchQueue.main.async {
            // Use the obtained screen coordinates to update UI
            self.gazeDotView.center = gazePoint
        }
    }
    
    func gazeTracker(didFailWithError error: Error) {
        print("Error occurred during tracking: \(error)")
    }
}
```

---

## 🧠 Gaze Estimation Algorithm

GazeKit implements a sophisticated gaze estimation pipeline that combines ARKit's face tracking with advanced signal processing techniques to provide accurate and stable eye tracking.

### Core Algorithm Overview

```
ARKit Face Tracking → Eye Position Extraction → 3D Gaze Vector → Screen Intersection → Filtering → Calibration → Final Gaze Point
```

### 1. Face Tracking with ARKit

GazeKit leverages ARKit's `ARFaceTrackingConfiguration` to detect facial features and extract eye position data:

```swift
// Extract eye transforms from ARFaceAnchor
let leftEyeTransform = faceAnchor.leftEyeTransform
let rightEyeTransform = faceAnchor.rightEyeTransform
```

- **Input**: TrueDepth camera data (infrared dot projector + infrared camera)
- **Output**: 3D positions and orientations of both eyes in device coordinate system
- **Frequency**: ~60 FPS tracking updates

### 2. Gaze Vector Calculation

The algorithm computes 3D gaze direction vectors from eye transform matrices:

```swift
// Extract gaze direction from transform matrix
let gazeDirection = SIMD3<Float>(
    eyeTransform.columns.2.x,  // Forward vector X
    eyeTransform.columns.2.y,  // Forward vector Y  
    eyeTransform.columns.2.z   // Forward vector Z
)
```

- **Coordinate System**: ARKit uses right-handed coordinate system
- **Gaze Vector**: Extracted from transform matrix's forward direction (Z-axis)
- **Binocular Fusion**: Combines left and right eye data for improved accuracy

### 3. Screen Intersection Geometry

The algorithm projects the 3D gaze vector onto the screen plane using ray-plane intersection:

```swift
// Ray-plane intersection calculation
let planeDistance: Float = 0.6  // Distance to screen plane (meters)
let t = -planeDistance / eyeDirection.z
let intersectionX = eyePosition.x + t * eyeDirection.x
let intersectionY = eyePosition.y + t * eyeDirection.y
```

- **Screen Model**: Assumes flat screen plane at fixed distance
- **Projection**: Uses parametric ray equation for intersection
- **Coordinate Transform**: Converts from ARKit 3D space to UIKit 2D screen coordinates

### 4. Signal Processing & Filtering

Multiple filtering stages ensure stable and accurate gaze estimates:

#### 4.1 Outlier Detection
```swift
// Remove sudden jumps and invalid points
if distance > maxGazeJumpThreshold {
    let dampingFactor: CGFloat = 0.3
    filteredPoint = lastPoint + (currentPoint - lastPoint) * dampingFactor
}
```

#### 4.2 Temporal Smoothing
```swift
// Moving average filter for noise reduction
let smoothedX = gazeHistory.map { $0.x }.reduce(0, +) / CGFloat(gazeHistory.count)
let smoothedY = gazeHistory.map { $0.y }.reduce(0, +) / CGFloat(gazeHistory.count)
```

#### 4.3 Statistical Filtering (MAD-based)
```swift
// Median Absolute Deviation for robust outlier removal
let median = calculateMedianPoint(from: gazeData)
let madDistance = calculateMAD(from: gazeData, median: median)
let threshold = madDistance * 3.0  // 3-sigma rule
```

### 5. Calibration System

The calibration process corrects for individual differences and improves accuracy:

#### 5.1 Data Collection
- **Target Points**: 7 calibration targets across screen (corners, center, intermediate)
- **Collection Duration**: 3 seconds per target with 0.8s warmup
- **Quality Assessment**: Confidence scoring based on data consistency

#### 5.2 Transform Calculation
```swift
// Calculate offset and scale transformation
offsetX = screenCenterX - rawCenterX * scaleX
offsetY = screenCenterY - rawCenterY * scaleY
scaleX = screenRange / rawRange  // Computed per axis
```

#### 5.3 Quality Control
- **Minimum Samples**: Requires ≥15 high-quality samples per target
- **Confidence Threshold**: Filters low-confidence data points
- **Retry Logic**: Automatically retries failed calibration points

### 6. Head Motion Compensation

Advanced algorithm compensates for head movement during tracking:

```swift
// Apply head motion compensation
let compensatedDirection = referenceHeadTransform.inverse * currentHeadTransform * gazeDirection
```

- **Reference Frame**: Establishes baseline head position during calibration
- **Dynamic Correction**: Adjusts gaze vectors based on head movement
- **Stability**: Maintains accuracy even with natural head motion

### Technical Specifications

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Tracking Frequency** | ~60 FPS | ARKit face tracking update rate |
| **Accuracy** | 1-3° | Typical gaze estimation accuracy |
| **Latency** | <50ms | End-to-end processing latency |
| **Working Distance** | 30-80cm | Optimal distance from device |
| **Head Movement** | ±30° | Supported head rotation range |
| **Calibration Points** | 7 targets | Distributed across screen area |

### Algorithm Advantages

1. **Real-time Performance**: Optimized for 60 FPS with minimal latency
2. **Robust Filtering**: Multiple filtering stages handle noise and outliers
3. **Personalization**: Calibration adapts to individual eye characteristics
4. **Motion Tolerance**: Head motion compensation maintains accuracy
5. **Quality Control**: Built-in data validation ensures reliable results

---

## 📱 Running the Demo App

This repository includes a demo app to try out **GazeKit** features.

1.  Clone the repository:
    ```bash
    git clone https://github.com/ctxzz/GazeKit.git
    cd GazeKit
    ```
2.  If you haven't installed [XcodeGen](https://github.com/yonaskolb/XcodeGen), install it via Homebrew:
    ```bash
    brew install xcodegen
    ```
3.  In the directory containing `project.yml`, run the following command to generate the Xcode project file:
    ```bash
    xcodegen generate
    ```
4.  Open the generated `GazeKitProject.xcodeproj` in Xcode.
5.  Select the `GazeKitDemo` scheme and run on **an iPad device with TrueDepth camera**.
    (Does not work in Simulator)
