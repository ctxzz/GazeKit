import UIKit
import ARKit
import GazeKit

class GazeTrackingViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let arView = ARSCNView()
    private var gazeTracker: GazeTracker?
    
    // メインアプリとして動作（戻るボタンなし）
    
    // 視線追跡表示
    private let gazeDotView = UIView()
    private let crossHairView = UIView()
    
    // ステータス表示
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let instructionLabel = UILabel()
    
    // コントロールボタン
    private let controlStackView = UIStackView()
    private let startButton = UIButton(type: .system)
    private let calibrationButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    
    // 情報表示
    private let infoStackView = UIStackView()
    private let trackingStatusLabel = UILabel()
    private let calibrationStatusLabel = UILabel()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupARView()
        // setupNavigationUI() // メインアプリなので不要
        setupGazeVisualization()
        setupStatusUI()
        setupControlButtons()
        setupInfoDisplay()
        setupConstraints()
        
        initializeGazeTracker()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gazeTracker?.stopTracking()
    }
    
    // MARK: - Setup Methods
    
    private func setupARView() {
        arView.translatesAutoresizingMaskIntoConstraints = false
        arView.isHidden = true
        view.addSubview(arView)
    }
    
    // メインアプリとして動作するため、ナビゲーションUIは不要
    
    private func setupGazeVisualization() {
        // 視線ドット
        gazeDotView.frame.size = CGSize(width: 24, height: 24)
        gazeDotView.backgroundColor = .systemRed.withAlphaComponent(0.8)
        gazeDotView.layer.cornerRadius = 12
        gazeDotView.layer.borderWidth = 2
        gazeDotView.layer.borderColor = UIColor.white.cgColor
        gazeDotView.layer.shadowColor = UIColor.black.cgColor
        gazeDotView.layer.shadowOffset = CGSize(width: 0, height: 2)
        gazeDotView.layer.shadowOpacity = 0.3
        gazeDotView.layer.shadowRadius = 4
        gazeDotView.isHidden = true
        view.addSubview(gazeDotView)
        
        // 中央の十字線（参考用）
        setupCrossHair()
    }
    
    private func setupCrossHair() {
        crossHairView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        crossHairView.center = view.center
        crossHairView.backgroundColor = .clear
        crossHairView.layer.borderWidth = 1
        crossHairView.layer.borderColor = UIColor.systemGray.withAlphaComponent(0.5).cgColor
        crossHairView.layer.cornerRadius = 20
        crossHairView.isHidden = true
        
        // 十字線を描画
        let horizontalLine = UIView(frame: CGRect(x: 10, y: 19, width: 20, height: 2))
        horizontalLine.backgroundColor = .systemGray.withAlphaComponent(0.5)
        crossHairView.addSubview(horizontalLine)
        
        let verticalLine = UIView(frame: CGRect(x: 19, y: 10, width: 2, height: 20))
        verticalLine.backgroundColor = .systemGray.withAlphaComponent(0.5)
        crossHairView.addSubview(verticalLine)
        
        view.addSubview(crossHairView)
    }
    
    private func setupStatusUI() {
        // タイトル
        titleLabel.text = "GazeKit"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // ステータス
        statusLabel.text = "Initializing..."
        statusLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .systemBlue
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // 説明
        instructionLabel.text = """
        iPad ARKit Eye Tracking Demo
        
        Use the buttons below to start tracking
        and run calibration.
        The red dot shows your gaze position.
        """
        instructionLabel.font = .systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.textColor = .secondaryLabel
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)
    }
    
    private func setupControlButtons() {
        // スタックビューの設定
        controlStackView.axis = .vertical
        controlStackView.spacing = 16
        controlStackView.distribution = .fillEqually
        controlStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlStackView)
        
        // 開始ボタン
        setupButton(startButton, title: "🎯 Start Tracking", color: .systemGreen, action: #selector(startButtonTapped))
        
        // キャリブレーションボタン
        setupButton(calibrationButton, title: "🎲 Calibration", color: .systemBlue, action: #selector(calibrationButtonTapped))
        calibrationButton.isEnabled = false
        
        // リセットボタン
        setupButton(resetButton, title: "🔄 Reset", color: .systemOrange, action: #selector(resetButtonTapped))
        resetButton.isEnabled = false
        
        controlStackView.addArrangedSubview(startButton)
        controlStackView.addArrangedSubview(calibrationButton)
        controlStackView.addArrangedSubview(resetButton)
    }
    
    private func setupButton(_ button: UIButton, title: String, color: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 6
        button.addTarget(self, action: action, for: .touchUpInside)
        
        // ボタン押下時のアニメーション効果
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    private func setupInfoDisplay() {
        // 情報表示スタックビュー
        infoStackView.axis = .vertical
        infoStackView.spacing = 8
        infoStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoStackView)
        
        // トラッキング状態
        trackingStatusLabel.text = "📊 Tracking: Stopped"
        trackingStatusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        trackingStatusLabel.textColor = .secondaryLabel
        
        // キャリブレーション状態
        calibrationStatusLabel.text = "🎯 Calibration: Not Performed"
        calibrationStatusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        calibrationStatusLabel.textColor = .secondaryLabel
        
        infoStackView.addArrangedSubview(trackingStatusLabel)
        infoStackView.addArrangedSubview(calibrationStatusLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ARView
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // タイトル
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // ステータス
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // 説明
            instructionLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            // コントロールボタン
            controlStackView.bottomAnchor.constraint(equalTo: infoStackView.topAnchor, constant: -30),
            controlStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            controlStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            controlStackView.heightAnchor.constraint(equalToConstant: 180),
            
            // 情報表示
            infoStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            infoStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            infoStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
    }
    
    // MARK: - Initialization
    
    private func initializeGazeTracker() {
        do {
            gazeTracker = try GazeTracker(arView: arView)
            gazeTracker?.delegate = self
            
            DispatchQueue.main.async {
                self.statusLabel.text = "✅ Initialization Complete"
                self.statusLabel.textColor = .systemGreen
                self.instructionLabel.text = """
                Ready!
                Press "Start Tracking" button to
                begin eye tracking.
                """
                self.startButton.isEnabled = true
            }
        } catch {
            DispatchQueue.main.async {
                self.statusLabel.text = "❌ Initialization Error"
                self.statusLabel.textColor = .systemRed
                self.instructionLabel.text = "Error: \(error.localizedDescription)"
                self.showErrorAlert(message: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Button Actions
    
    // メインアプリとして動作するため、戻るボタンのアクションは不要
    
    @objc private func startButtonTapped() {
        gazeTracker?.startTracking()
        
        statusLabel.text = "🟢 Tracking Started"
        statusLabel.textColor = .systemGreen
        instructionLabel.text = """
        Eye tracking has started.
        We recommend running calibration
        to improve accuracy.
        """
        
        calibrationButton.isEnabled = true
        resetButton.isEnabled = true
        gazeDotView.isHidden = false
        crossHairView.isHidden = false
        
        trackingStatusLabel.text = "📊 Tracking: Running"
        trackingStatusLabel.textColor = .systemGreen
    }
    
    @objc private func calibrationButtonTapped() {
        statusLabel.text = "🎯 Calibrating..."
        statusLabel.textColor = .systemBlue
        instructionLabel.text = """
        Calibration in progress
        Look directly at the red dots
        displayed on the screen.
        """
        calibrationButton.isEnabled = false
        
        gazeTracker?.startCalibration { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.statusLabel.text = "✅ Calibration Complete"
                    self?.statusLabel.textColor = .systemGreen
                    self?.instructionLabel.text = """
                    Calibration completed!
                    The red dot will now show
                    your gaze position more accurately.
                    """
                    self?.calibrationButton.setTitle("🎲 Recalibrate", for: .normal)
                    self?.calibrationStatusLabel.text = "🎯 Calibration: Complete"
                    self?.calibrationStatusLabel.textColor = .systemGreen
                } else {
                    self?.statusLabel.text = "❌ Calibration Failed"
                    self?.statusLabel.textColor = .systemRed
                    self?.instructionLabel.text = """
                    Calibration failed.
                    Face the device directly and
                    try again.
                    """
                    self?.calibrationStatusLabel.text = "🎯 Calibration: Failed"
                    self?.calibrationStatusLabel.textColor = .systemRed
                }
                self?.calibrationButton.isEnabled = true
            }
        }
    }
    
    @objc private func resetButtonTapped() {
        gazeTracker?.stopTracking()
        gazeTracker?.resetCalibration()
        
        statusLabel.text = "🔄 Reset Complete"
        statusLabel.textColor = .systemOrange
        instructionLabel.text = """
        All data has been reset.
        Start again with "Start Tracking".
        """
        
        calibrationButton.isEnabled = false
        resetButton.isEnabled = false
        gazeDotView.isHidden = true
        crossHairView.isHidden = true
        
        calibrationButton.setTitle("🎲 Calibration", for: .normal)
        
        trackingStatusLabel.text = "📊 Tracking: Stopped"
        trackingStatusLabel.textColor = .secondaryLabel
        calibrationStatusLabel.text = "🎯 Calibration: Not Performed"
        calibrationStatusLabel.textColor = .secondaryLabel
    }
    
    @objc private func buttonTouchDown(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonTouchUp(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = .identity
        }
    }
    
    // MARK: - Helper Methods
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - GazeTrackerDelegate

extension GazeTrackingViewController: GazeTrackerDelegate {
    
    func gazeTracker(didUpdateGazePoint gazePoint: CGPoint) {
        DispatchQueue.main.async {
            // 視線ドットの位置を更新
            self.gazeDotView.center = gazePoint
            
            // 画面外の場合は透明度を下げる
            let screenBounds = self.view.bounds
            let isInBounds = screenBounds.contains(gazePoint)
            self.gazeDotView.alpha = isInBounds ? 0.8 : 0.3
        }
    }
    
    func gazeTracker(didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusLabel.text = "❌ Error Occurred"
            self.statusLabel.textColor = .systemRed
            self.instructionLabel.text = "Error: \(error.localizedDescription)"
            self.showErrorAlert(message: error.localizedDescription)
            
            self.trackingStatusLabel.text = "📊 Tracking: Error"
            self.trackingStatusLabel.textColor = .systemRed
        }
    }
}