import UIKit

class Calibration {
    
    // MARK: - Data Structures
    
    private struct CalibrationPoint {
        let screenPoint: CGPoint
        let rawGazePoint: CGPoint
        let quality: Float // 0.0-1.0 でデータ品質を表す
        let timestamp: Date
    }
    
    private struct GazeDataPoint {
        let point: CGPoint
        let timestamp: Date
        let confidence: Float // 視線データの信頼度
    }
    
    // MARK: - Configuration
    
    private struct CalibrationConfig {
        static let targetPoints: [CGPoint] = [
            CGPoint(x: 0.15, y: 0.15),  // 左上（より内側）
            CGPoint(x: 0.85, y: 0.15),  // 右上
            CGPoint(x: 0.5, y: 0.5),    // 中央
            CGPoint(x: 0.15, y: 0.85),  // 左下
            CGPoint(x: 0.85, y: 0.85),  // 右下
            CGPoint(x: 0.3, y: 0.3),    // 追加点1
            CGPoint(x: 0.7, y: 0.7)     // 追加点2（より多くのデータポイント）
        ]
        
        static let targetDisplayDuration: TimeInterval = 1.5  // 目標表示時間を短縮
        static let dataCollectionDuration: TimeInterval = 3.0 // データ収集時間
        static let warmupDuration: TimeInterval = 0.8        // ウォームアップ時間
        static let minRequiredSamples = 15                   // 最小必要サンプル数
        static let maxAllowedSamples = 60                    // 最大サンプル数
        static let confidenceThreshold: Float = 0.6         // 信頼度閾値
        static let qualityThreshold: Float = 0.3            // 品質閾値
        static let overallQualityThreshold: Float = 0.4     // 全体品質閾値
        
        static let targetViewTag = 9999
        static let pulseRingTag = 9998
        static let centerDotTag = 9997
        
        static let maxReasonableDistance: CGFloat = 300.0
        static let madMultiplier: CGFloat = 3.0
    }
    
    // MARK: - Properties
    
    private var calibrationPoints: [CalibrationPoint] = []
    private var offsetX: CGFloat = 0
    private var offsetY: CGFloat = 0
    private var scaleX: CGFloat = 1.0
    private var scaleY: CGFloat = 1.0
    
    private var currentCalibrationIndex = 0
    private var calibrationCompletion: ((Bool) -> Void)?
    private var calibrationTimer: Timer?
    private var dataCollectionTimer: Timer?
    private var rawGazeData: [GazeDataPoint] = []
    
    // MARK: - Public API
    
    func startCalibration(completion: @escaping (Bool) -> Void) {
        print("Calibration: Starting robust calibration process")
        calibrationCompletion = completion
        calibrationPoints.removeAll()
        currentCalibrationIndex = 0
        
        showNextCalibrationPoint()
    }
    
    func resetCalibration() {
        calibrationPoints.removeAll()
        offsetX = 0
        offsetY = 0
        scaleX = 1.0
        scaleY = 1.0
        
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        dataCollectionTimer?.invalidate()
        dataCollectionTimer = nil
        calibrationCompletion = nil
        currentCalibrationIndex = 0
        rawGazeData.removeAll()
    }
    
    func addRawGazePoint(_ point: CGPoint) {
        guard dataCollectionTimer != nil else { return }
        
        let confidence = calculatePointConfidence(point)
        let dataPoint = GazeDataPoint(
            point: point,
            timestamp: Date(),
            confidence: confidence
        )
        
        rawGazeData.append(dataPoint)
        
        if rawGazeData.count > CalibrationConfig.maxAllowedSamples {
            rawGazeData.removeFirst()
        }
        
        if rawGazeData.count % 10 == 0 {
            print("Calibration: Collected \(rawGazeData.count) gaze samples")
        }
    }
    
    func applyCalibration(to rawPoint: CGPoint) -> CGPoint {
        let calibratedX = rawPoint.x * scaleX + offsetX
        let calibratedY = rawPoint.y * scaleY + offsetY
        
        return CGPoint(x: calibratedX, y: calibratedY)
    }
    
    // MARK: - Calibration Flow
    
    private func showNextCalibrationPoint() {
        guard currentCalibrationIndex < CalibrationConfig.targetPoints.count else {
            print("Calibration: All calibration points completed, calculating parameters")
            calculateCalibrationParameters()
            return
        }
        
        let targetPoint = CalibrationConfig.targetPoints[currentCalibrationIndex]
        let screenBounds = UIScreen.main.bounds
        let screenPoint = CGPoint(
            x: targetPoint.x * screenBounds.width,
            y: targetPoint.y * screenBounds.height
        )
        
        print("Calibration: Showing calibration point \(currentCalibrationIndex + 1)/\(CalibrationConfig.targetPoints.count) at \(screenPoint)")
        
        showImprovedCalibrationTarget(at: screenPoint)
        rawGazeData.removeAll()
        
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: CalibrationConfig.warmupDuration, repeats: false) { [weak self] _ in
            self?.startDataCollection(for: screenPoint)
        }
    }
    
    // MARK: - Target Display
    
    private func showImprovedCalibrationTarget(at point: CGPoint) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        removeExistingTargets(from: window)
        
        let targetView = createMainTarget(at: point)
        let pulseRing = createPulseRing(at: point)
        let centerDot = createCenterDot(at: point)
        
        window.addSubview(pulseRing)
        window.addSubview(targetView)
        window.addSubview(centerDot)
        
        animateTargetAppearance(views: [pulseRing, targetView, centerDot], pulseRing: pulseRing)
    }
    
    private func removeExistingTargets(from window: UIWindow) {
        window.subviews.filter { $0.tag >= CalibrationConfig.centerDotTag && $0.tag <= CalibrationConfig.targetViewTag }.forEach { $0.removeFromSuperview() }
    }
    
    private func createMainTarget(at point: CGPoint) -> UIView {
        let targetView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        targetView.backgroundColor = .systemRed
        targetView.layer.cornerRadius = 25
        targetView.center = point
        targetView.tag = CalibrationConfig.targetViewTag
        return targetView
    }
    
    private func createPulseRing(at point: CGPoint) -> UIView {
        let pulseRing = UIView(frame: CGRect(x: 0, y: 0, width: 70, height: 70))
        pulseRing.backgroundColor = .clear
        pulseRing.layer.borderWidth = 3
        pulseRing.layer.borderColor = UIColor.systemRed.cgColor
        pulseRing.layer.cornerRadius = 35
        pulseRing.center = point
        pulseRing.tag = CalibrationConfig.pulseRingTag
        pulseRing.alpha = 0.7
        return pulseRing
    }
    
    private func createCenterDot(at point: CGPoint) -> UIView {
        let centerDot = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
        centerDot.backgroundColor = .white
        centerDot.layer.cornerRadius = 6
        centerDot.center = point
        centerDot.tag = CalibrationConfig.centerDotTag
        return centerDot
    }
    
    private func animateTargetAppearance(views: [UIView], pulseRing: UIView) {
        views.forEach { $0.alpha = 0 }
        
        UIView.animate(withDuration: 0.5, animations: {
            views.forEach { $0.alpha = $0 == pulseRing ? 0.7 : 1.0 }
        }) { _ in
            self.startPulseAnimation(for: pulseRing)
        }
    }
    
    private func startPulseAnimation(for view: UIView) {
        UIView.animate(withDuration: 1.0,
                      delay: 0,
                      options: [.repeat, .autoreverse, .allowUserInteraction],
                      animations: {
            view.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            view.alpha = 0.3
        })
    }
    
    private func hideCalibrationTarget() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let targetViews = window.subviews.filter { $0.tag >= CalibrationConfig.centerDotTag && $0.tag <= CalibrationConfig.targetViewTag }
        
        UIView.animate(withDuration: 0.3, animations: {
            targetViews.forEach { $0.alpha = 0 }
        }) { _ in
            targetViews.forEach { $0.removeFromSuperview() }
        }
    }
    
    // MARK: - Data Collection
    
    private func startDataCollection(for screenPoint: CGPoint) {
        print("Calibration: Starting data collection for point \(currentCalibrationIndex + 1)")
        
        dataCollectionTimer = Timer.scheduledTimer(withTimeInterval: CalibrationConfig.dataCollectionDuration, repeats: false) { [weak self] _ in
            self?.finishDataCollection(for: screenPoint)
        }
    }
    
    private func finishDataCollection(for screenPoint: CGPoint) {
        dataCollectionTimer?.invalidate()
        hideCalibrationTarget()
        
        print("Calibration: Collected \(rawGazeData.count) data points for point \(currentCalibrationIndex + 1)")
        
        let processedData = processCollectedData()
        
        guard processedData.count >= CalibrationConfig.minRequiredSamples else {
            print("Calibration: Insufficient quality data (\(processedData.count) < \(CalibrationConfig.minRequiredSamples)), retrying point")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showNextCalibrationPoint()
            }
            return
        }
        
        let averagePoint = calculateWeightedAverage(from: processedData)
        let dataQuality = calculateDataQuality(from: processedData)
        
        let calibrationPoint = CalibrationPoint(
            screenPoint: screenPoint,
            rawGazePoint: averagePoint,
            quality: dataQuality,
            timestamp: Date()
        )
        
        calibrationPoints.append(calibrationPoint)
        print("Calibration: Point \(currentCalibrationIndex + 1) completed with quality: \(dataQuality)")
        
        currentCalibrationIndex += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showNextCalibrationPoint()
        }
    }
    
    // MARK: - Data Processing
    
    private func processCollectedData() -> [GazeDataPoint] {
        let sortedData = rawGazeData.sorted { $0.timestamp < $1.timestamp }
        guard sortedData.count > 4 else { return sortedData }
        
        let timeFilteredData = applyTimeBasedFiltering(to: sortedData)
        let confidenceFilteredData = timeFilteredData.filter { $0.confidence >= CalibrationConfig.confidenceThreshold }
        
        return removeStatisticalOutliers(from: confidenceFilteredData)
    }
    
    private func applyTimeBasedFiltering(to data: [GazeDataPoint]) -> [GazeDataPoint] {
        let startIndex = max(1, Int(Double(data.count) * 0.2))
        let endIndex = min(data.count - 1, Int(Double(data.count) * 0.9))
        return Array(data[startIndex..<endIndex])
    }
    
    private func removeStatisticalOutliers(from data: [GazeDataPoint]) -> [GazeDataPoint] {
        guard data.count > 4 else { return data }
        
        let median = calculateMedianPoint(from: data)
        let madDistance = calculateMAD(from: data, median: median)
        let threshold = madDistance * CalibrationConfig.madMultiplier
        
        let filteredData = data.filter { point in
            let distance = sqrt(pow(point.point.x - median.x, 2) + pow(point.point.y - median.y, 2))
            return distance <= threshold
        }
        
        return filteredData.isEmpty ? [data[data.count / 2]] : filteredData
    }
    
    private func calculateMedianPoint(from data: [GazeDataPoint]) -> CGPoint {
        let sortedX = data.map { $0.point.x }.sorted()
        let sortedY = data.map { $0.point.y }.sorted()
        
        return CGPoint(
            x: sortedX[sortedX.count / 2],
            y: sortedY[sortedY.count / 2]
        )
    }
    
    private func calculateMAD(from data: [GazeDataPoint], median: CGPoint) -> CGFloat {
        let distances = data.map { point in
            sqrt(pow(point.point.x - median.x, 2) + pow(point.point.y - median.y, 2))
        }
        let sortedDistances = distances.sorted()
        return sortedDistances[sortedDistances.count / 2]
    }
    
    // MARK: - Quality Calculation
    
    private func calculateWeightedAverage(from data: [GazeDataPoint]) -> CGPoint {
        guard !data.isEmpty else { return .zero }
        
        var weightedSumX: Float = 0
        var weightedSumY: Float = 0
        var totalWeight: Float = 0
        
        for dataPoint in data {
            let weight = dataPoint.confidence
            weightedSumX += Float(dataPoint.point.x) * weight
            weightedSumY += Float(dataPoint.point.y) * weight
            totalWeight += weight
        }
        
        guard totalWeight > 0 else { return .zero }
        
        return CGPoint(
            x: CGFloat(weightedSumX / totalWeight),
            y: CGFloat(weightedSumY / totalWeight)
        )
    }
    
    private func calculateDataQuality(from data: [GazeDataPoint]) -> Float {
        guard data.count > 1 else { return 0.0 }
        
        let averageConfidence = data.map { $0.confidence }.reduce(0, +) / Float(data.count)
        let consistency = calculateConsistency(from: data)
        let sampleWeight = min(1.0, Float(data.count) / Float(CalibrationConfig.maxAllowedSamples))
        
        return (averageConfidence * 0.4 + consistency * 0.4 + sampleWeight * 0.2)
    }
    
    private func calculateConsistency(from data: [GazeDataPoint]) -> Float {
        let points = data.map { $0.point }
        let centerX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let centerY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        
        let variance = points.map { point in
            pow(point.x - centerX, 2) + pow(point.y - centerY, 2)
        }.reduce(0, +) / CGFloat(points.count)
        
        return variance > 0 ? Float(1.0 / (1.0 + variance * 0.001)) : 1.0
    }
    
    private func calculatePointConfidence(_ point: CGPoint) -> Float {
        let screenBounds = UIScreen.main.bounds
        
        let isInBounds = screenBounds.contains(point)
        var confidence: Float = isInBounds ? 0.8 : 0.3
        
        if let lastData = rawGazeData.last {
            let distance = sqrt(pow(point.x - lastData.point.x, 2) + pow(point.y - lastData.point.y, 2))
            
            if distance < CalibrationConfig.maxReasonableDistance {
                confidence += 0.2
            } else {
                confidence *= 0.5
            }
        }
        
        return min(1.0, confidence)
    }
    
    // MARK: - Calibration Parameters
    
    private func calculateCalibrationParameters() {
        print("Calibration: Calculating parameters with \(calibrationPoints.count) calibration points")
        
        let qualityPoints = calibrationPoints.filter { $0.quality >= CalibrationConfig.qualityThreshold }
        
        guard qualityPoints.count >= 3 else {
            print("Calibration: Insufficient quality calibration points (\(qualityPoints.count) < 3), failing")
            calibrationCompletion?(false)
            return
        }
        
        let (screenCenter, rawCenter) = calculateWeightedCenters(from: qualityPoints)
        let (scaleFactors, offsets) = calculateTransformationParameters(from: qualityPoints, screenCenter: screenCenter, rawCenter: rawCenter)
        
        scaleX = scaleFactors.x
        scaleY = scaleFactors.y
        offsetX = offsets.x
        offsetY = offsets.y
        
        let overallQuality = qualityPoints.map { $0.quality }.reduce(0, +) / Float(qualityPoints.count)
        
        print("Calibration: Parameters calculated - scaleX: \(scaleX), scaleY: \(scaleY), offsetX: \(offsetX), offsetY: \(offsetY)")
        print("Calibration: Overall quality: \(overallQuality), using \(qualityPoints.count)/\(calibrationPoints.count) points")
        
        calibrationCompletion?(overallQuality >= CalibrationConfig.overallQualityThreshold)
    }
    
    private func calculateWeightedCenters(from points: [CalibrationPoint]) -> (screen: CGPoint, raw: CGPoint) {
        var weightedScreenSum = (x: Float(0), y: Float(0))
        var weightedRawSum = (x: Float(0), y: Float(0))
        var totalWeight: Float = 0
        
        for point in points {
            let weight = point.quality
            weightedScreenSum.x += Float(point.screenPoint.x) * weight
            weightedScreenSum.y += Float(point.screenPoint.y) * weight
            weightedRawSum.x += Float(point.rawGazePoint.x) * weight
            weightedRawSum.y += Float(point.rawGazePoint.y) * weight
            totalWeight += weight
        }
        
        let screenCenter = CGPoint(x: CGFloat(weightedScreenSum.x / totalWeight), y: CGFloat(weightedScreenSum.y / totalWeight))
        let rawCenter = CGPoint(x: CGFloat(weightedRawSum.x / totalWeight), y: CGFloat(weightedRawSum.y / totalWeight))
        
        return (screenCenter, rawCenter)
    }
    
    private func calculateTransformationParameters(from points: [CalibrationPoint], screenCenter: CGPoint, rawCenter: CGPoint) -> (scale: CGPoint, offset: CGPoint) {
        var weightedScreenRange = (x: Float(0), y: Float(0))
        var weightedRawRange = (x: Float(0), y: Float(0))
        
        for point in points {
            let weight = point.quality
            let screenDelta = (x: Float(point.screenPoint.x - screenCenter.x), y: Float(point.screenPoint.y - screenCenter.y))
            let rawDelta = (x: Float(point.rawGazePoint.x - rawCenter.x), y: Float(point.rawGazePoint.y - rawCenter.y))
            
            weightedScreenRange.x += abs(screenDelta.x) * weight
            weightedScreenRange.y += abs(screenDelta.y) * weight
            weightedRawRange.x += abs(rawDelta.x) * weight
            weightedRawRange.y += abs(rawDelta.y) * weight
        }
        
        let scaleX = weightedRawRange.x > 0 ? CGFloat(weightedScreenRange.x / weightedRawRange.x) : 1.0
        let scaleY = weightedRawRange.y > 0 ? CGFloat(weightedScreenRange.y / weightedRawRange.y) : 1.0
        
        let offsetX = screenCenter.x - rawCenter.x * scaleX
        let offsetY = screenCenter.y - rawCenter.y * scaleY
        
        return (CGPoint(x: scaleX, y: scaleY), CGPoint(x: offsetX, y: offsetY))
    }
}