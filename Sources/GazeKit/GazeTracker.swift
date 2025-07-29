import UIKit
import ARKit
import SceneKit
import simd

// MARK: - Helper Classes

/// 視線の計算とフィルタリングを担当するクラス
internal class GazeCalculator {
    
    // MARK: - Properties
    
    /// 平滑化フィルタ用の履歴データ
    private var gazeHistory: [CGPoint] = []
    private let maxHistorySize = 5
    
    /// 異常値検出用のデータ
    private var lastValidGazePoint: CGPoint?
    private let maxGazeJumpThreshold: CGFloat = 200.0
    
    // MARK: - Public Methods
    
    /// ARKitの目の位置・方向から画面座標を計算
    func calculateScreenPoint(
        eyePosition: SIMD3<Float>,
        eyeDirection: SIMD3<Float>
    ) -> CGPoint {
        let screenBounds = UIScreen.main.bounds
        
        let planeDistance: Float = 0.6
        let t = -planeDistance / eyeDirection.z
        
        let intersectionX = eyePosition.x + t * eyeDirection.x
        let intersectionY = eyePosition.y + t * eyeDirection.y
        
        // ARKitの座標系からUIKitの座標系への変換
        let screenX = screenBounds.width / 2 - CGFloat(intersectionX * 1000)
        let screenY = screenBounds.height / 2 + CGFloat(intersectionY * 1000)
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    /// 異常値をフィルタリング
    func filterOutliers(_ point: CGPoint) -> CGPoint {
        let screenBounds = UIScreen.main.bounds
        
        // 画面範囲外の異常値をクリップ
        let clampedX = max(-screenBounds.width * 0.2, min(screenBounds.width * 1.2, point.x))
        let clampedY = max(-screenBounds.height * 0.2, min(screenBounds.height * 1.2, point.y))
        let clampedPoint = CGPoint(x: clampedX, y: clampedY)
        
        // 前回の有効な点との距離をチェック
        if let lastPoint = lastValidGazePoint {
            let distance = sqrt(pow(clampedPoint.x - lastPoint.x, 2) + pow(clampedPoint.y - lastPoint.y, 2))
            
            // 急激な変化の場合は前回の値に近づける
            if distance > maxGazeJumpThreshold {
                let dampingFactor: CGFloat = 0.3
                let filteredX = lastPoint.x + (clampedPoint.x - lastPoint.x) * dampingFactor
                let filteredY = lastPoint.y + (clampedPoint.y - lastPoint.y) * dampingFactor
                let filteredPoint = CGPoint(x: filteredX, y: filteredY)
                
                lastValidGazePoint = filteredPoint
                return filteredPoint
            }
        }
        
        lastValidGazePoint = clampedPoint
        return clampedPoint
    }
    
    /// 移動平均による平滑化フィルタを適用
    func applySmoothingFilter(to point: CGPoint) -> CGPoint {
        gazeHistory.append(point)
        
        // 履歴のサイズ制限
        if gazeHistory.count > maxHistorySize {
            gazeHistory.removeFirst()
        }
        
        // 移動平均による平滑化
        let averageX = gazeHistory.map { $0.x }.reduce(0, +) / CGFloat(gazeHistory.count)
        let averageY = gazeHistory.map { $0.y }.reduce(0, +) / CGFloat(gazeHistory.count)
        
        return CGPoint(x: averageX, y: averageY)
    }
    
    /// フィルタの状態をリセット
    func resetFilters() {
        gazeHistory.removeAll()
        lastValidGazePoint = nil
    }
}

/// 頭の動きを補正して視線追跡の精度を向上させるクラス
internal class HeadMotionCompensator {
    
    // MARK: - Properties
    
    /// 基準となる頭の変換行列
    private var referenceHeadTransform: simd_float4x4?
    
    /// 頭の変換履歴
    private var headTransformHistory: [simd_float4x4] = []
    private let maxHeadHistorySize = 10
    
    /// 補正の強さ
    private let compensationFactor: Float = 0.8
    
    // MARK: - Public Methods
    
    /// 頭の変換行列を更新
    func updateHeadTransform(_ headTransform: simd_float4x4) {
        // 基準姿勢が設定されていない場合は初期化
        if referenceHeadTransform == nil {
            referenceHeadTransform = headTransform
        }
        
        // 頭の変換履歴を更新
        headTransformHistory.append(headTransform)
        if headTransformHistory.count > maxHeadHistorySize {
            headTransformHistory.removeFirst()
        }
        
        // 頭の動きが安定している場合は基準姿勢を更新
        if shouldUpdateHeadReference() {
            updateHeadReferenceIfStable()
        }
    }
    
    /// 頭の動きを考慮した視線計算
    func calculateCompensatedGaze(
        eyePosition: SIMD3<Float>,
        eyeDirection: SIMD3<Float>,
        headTransform: simd_float4x4,
        gazeCalculator: GazeCalculator
    ) -> CGPoint {
        // 基準姿勢が設定されていない場合は従来の計算
        guard let referenceTransform = referenceHeadTransform else {
            return gazeCalculator.calculateScreenPoint(
                eyePosition: eyePosition,
                eyeDirection: eyeDirection
            )
        }
        
        // 頭の回転変化と位置変化を計算
        let headRotationDelta = extractRotationDelta(from: referenceTransform, to: headTransform)
        let headPositionDelta = extractPositionDelta(from: referenceTransform, to: headTransform)
        
        // 視線方向と位置を補正
        let compensatedEyeDirection = compensateForHeadRotation(
            eyeDirection: eyeDirection,
            headRotationDelta: headRotationDelta
        )
        let compensatedEyePosition = eyePosition - headPositionDelta
        
        // 補正済みの値で画面座標を計算
        return gazeCalculator.calculateScreenPoint(
            eyePosition: compensatedEyePosition,
            eyeDirection: compensatedEyeDirection
        )
    }
    
    /// 基準姿勢をリセット
    func resetHeadReference() {
        referenceHeadTransform = nil
        headTransformHistory.removeAll()
    }
    
    /// 現在の姿勢を基準姿勢として設定
    func setHeadReference() {
        if let currentTransform = headTransformHistory.last {
            referenceHeadTransform = currentTransform
        }
    }
    
    // MARK: - Private Methods
    
    /// 頭の回転変化を抽出
    private func extractRotationDelta(from reference: simd_float4x4, to current: simd_float4x4) -> SIMD3<Float> {
        let referenceRotation = simd_quaternion(reference)
        let currentRotation = simd_quaternion(current)
        
        let deltaRotation = currentRotation * referenceRotation.inverse
        let axis = deltaRotation.axis
        let angle = deltaRotation.angle
        
        return axis * angle
    }
    
    /// 頭の位置変化を抽出
    private func extractPositionDelta(from reference: simd_float4x4, to current: simd_float4x4) -> SIMD3<Float> {
        let referencePosition = SIMD3<Float>(reference.columns.3.x, reference.columns.3.y, reference.columns.3.z)
        let currentPosition = SIMD3<Float>(current.columns.3.x, current.columns.3.y, current.columns.3.z)
        
        return currentPosition - referencePosition
    }
    
    /// 頭の回転による視線方向の補正
    private func compensateForHeadRotation(eyeDirection: SIMD3<Float>, headRotationDelta: SIMD3<Float>) -> SIMD3<Float> {
        let compensatedDirection = SIMD3<Float>(
            eyeDirection.x - headRotationDelta.y * compensationFactor, // ヨー回転
            eyeDirection.y + headRotationDelta.x * compensationFactor, // ピッチ回転
            eyeDirection.z
        )
        
        return normalize(compensatedDirection)
    }
    
    /// 基準姿勢を更新すべきかどうかを判定
    private func shouldUpdateHeadReference() -> Bool {
        return headTransformHistory.count >= maxHeadHistorySize
    }
    
    /// 頭の動きが安定している場合に基準姿勢を更新
    private func updateHeadReferenceIfStable() {
        guard headTransformHistory.count >= 3 else { return }
        
        let recentTransforms = Array(headTransformHistory.suffix(3))
        let positionVariation = calculatePositionVariation(recentTransforms)
        let rotationVariation = calculateRotationVariation(recentTransforms)
        
        let positionThreshold: Float = 0.01 // 1cm
        let rotationThreshold: Float = 0.05 // 約5度
        
        if positionVariation < positionThreshold && rotationVariation < rotationThreshold {
            referenceHeadTransform = headTransformHistory.last
        }
    }
    
    /// 位置の変動を計算
    private func calculatePositionVariation(_ transforms: [simd_float4x4]) -> Float {
        guard transforms.count > 1 else { return 0 }
        
        let positions = transforms.map { transform in
            SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
        
        var maxDistance: Float = 0
        for i in 0..<positions.count {
            for j in (i+1)..<positions.count {
                let distance = length(positions[i] - positions[j])
                maxDistance = max(maxDistance, distance)
            }
        }
        
        return maxDistance
    }
    
    /// 回転の変動を計算
    private func calculateRotationVariation(_ transforms: [simd_float4x4]) -> Float {
        guard transforms.count > 1 else { return 0 }
        
        let quaternions = transforms.map { simd_quaternion($0) }
        
        var maxAngle: Float = 0
        for i in 0..<quaternions.count {
            for j in (i+1)..<quaternions.count {
                let deltaQuat = quaternions[i] * quaternions[j].inverse
                let angle = abs(deltaQuat.angle)
                maxAngle = max(maxAngle, angle)
            }
        }
        
        return maxAngle
    }
}

// MARK: - Main GazeTracker Class

/// 視線追跡の状態を通知するデリゲート
public protocol GazeTrackerDelegate: AnyObject {
    func gazeTracker(didUpdateGazePoint gazePoint: CGPoint)
    func gazeTracker(didFailWithError error: Error)
}

/// 視線追跡のメインクラス
/// ARKitを使用して顔追跡を行い、視線位置を計算する
public class GazeTracker: NSObject {
    
    // MARK: - Public Properties
    
    public weak var delegate: GazeTrackerDelegate?
    
    public var isCalibrationRequired: Bool {
        return !isCalibrated
    }
    
    // MARK: - Private Properties
    
    private let arView: ARSCNView
    private let arkitHandler: ARKitHandler
    private let calibration: Calibration
    private let gazeCalculator: GazeCalculator
    private let headMotionCompensator: HeadMotionCompensator
    
    /// 追跡とキャリブレーションの状態
    private var isTracking = false
    private var isCalibrated = false
    private var isCalibrating = false
    
    // MARK: - Initialization
    
    public init(arView: ARSCNView) throws {
        guard ARFaceTrackingConfiguration.isSupported else {
            throw GazeKitError.unsupportedDevice
        }
        
        self.arView = arView
        self.arkitHandler = ARKitHandler()
        self.calibration = Calibration()
        self.gazeCalculator = GazeCalculator()
        self.headMotionCompensator = HeadMotionCompensator()
        
        super.init()
        
        setupComponents()
    }
    
    // MARK: - Public Methods
    
    /// 視線追跡を開始
    public func startTracking() {
        do {
            try arkitHandler.startSession()
            isTracking = true
        } catch {
            delegate?.gazeTracker(didFailWithError: error)
        }
    }
    
    /// 視線追跡を停止
    public func stopTracking() {
        arkitHandler.stopSession()
        isTracking = false
    }
    
    /// キャリブレーションを開始
    public func startCalibration(completion: @escaping (Bool) -> Void) {
        // トラッキングが開始されていない場合は自動で開始
        if !isTracking {
            startTracking()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startCalibration(completion: completion)
            }
            return
        }
        
        isCalibrating = true
        calibration.startCalibration { [weak self] success in
            self?.isCalibrating = false
            self?.isCalibrated = success
            completion(success)
        }
    }
    
    /// キャリブレーションをリセット
    public func resetCalibration() {
        calibration.resetCalibration()
        isCalibrated = false
        isCalibrating = false
        headMotionCompensator.resetHeadReference()
        gazeCalculator.resetFilters()
    }
    
    /// 頭の基準姿勢を手動で設定
    public func setHeadReference() {
        headMotionCompensator.setHeadReference()
    }
    
    /// 頭の基準姿勢をリセット
    public func resetHeadReference() {
        headMotionCompensator.resetHeadReference()
    }
    
    // MARK: - Private Methods
    
    /// コンポーネントの初期設定
    private func setupComponents() {
        arkitHandler.delegate = self
        arView.session.delegate = arkitHandler
        arView.isHidden = true
    }
}

// MARK: - ARKitHandlerDelegate

extension GazeTracker: ARKitHandlerDelegate {
    
    func arkitHandler(_ handler: ARKitHandler, didUpdateFaceAnchor faceAnchor: ARFaceAnchor) {
        guard isTracking && faceAnchor.isTracked else { return }
        
        // 頭の変換情報を更新
        headMotionCompensator.updateHeadTransform(faceAnchor.transform)
        
        // 左右の目の情報を取得
        let leftEyeTransform = faceAnchor.leftEyeTransform
        let rightEyeTransform = faceAnchor.rightEyeTransform
        
        let leftEyePosition = extractPosition(from: leftEyeTransform)
        let rightEyePosition = extractPosition(from: rightEyeTransform)
        let leftEyeDirection = normalize(extractDirection(from: leftEyeTransform))
        let rightEyeDirection = normalize(extractDirection(from: rightEyeTransform))
        
        // 両目の平均を計算
        let averageEyePosition = (leftEyePosition + rightEyePosition) / 2
        let averageEyeDirection = normalize((leftEyeDirection + rightEyeDirection) / 2)
        
        // 頭の動きを補正した視線計算
        let screenIntersection = headMotionCompensator.calculateCompensatedGaze(
            eyePosition: averageEyePosition,
            eyeDirection: averageEyeDirection,
            headTransform: faceAnchor.transform,
            gazeCalculator: gazeCalculator
        )
        
        // 異常値をフィルタリング
        let filteredPoint = gazeCalculator.filterOutliers(screenIntersection)
        
        // キャリブレーション中は生データを送信
        if isCalibrating {
            calibration.addRawGazePoint(filteredPoint)
        }
        
        // キャリブレーション済みの場合は補正を適用
        let gazePoint = isCalibrated ? 
            calibration.applyCalibration(to: filteredPoint) :
            filteredPoint
        
        // 平滑化フィルタを適用
        let smoothedGazePoint = gazeCalculator.applySmoothingFilter(to: gazePoint)
        
        // デリゲートに結果を通知
        delegate?.gazeTracker(didUpdateGazePoint: smoothedGazePoint)
    }
    
    func arkitHandler(_ handler: ARKitHandler, didFailWithError error: Error) {
        delegate?.gazeTracker(didFailWithError: error)
    }
    
    // MARK: - Helper Methods
    
    private func extractPosition(from transform: simd_float4x4) -> SIMD3<Float> {
        return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
    
    private func extractDirection(from transform: simd_float4x4) -> SIMD3<Float> {
        return SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
    }
}